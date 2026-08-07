USE [CampusSpaceManagement];
GO

-- ============================================================================
-- Phase 2 Concurrency Implementation - G11
-- Implements outputs/11-concurrency-design-G11.md
-- Single entry point (stored procedure) for safe booking creation across both
-- instant-approval and staff-approval paths, plus an escalation helper.
-- Uses pessimistic row locking on the SPACE row: WITH (UPDLOCK, HOLDLOCK).
-- ============================================================================

IF OBJECT_ID(N'dbo.usp_CreateBooking', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateBooking;
GO

CREATE PROCEDURE dbo.usp_CreateBooking
    @user_id              INT,
    @space_id             INT,
    @start_time           DATETIME2,
    @end_time             DATETIME2,
    @purpose              NVARCHAR(50),
    @expected_participants INT,
    @booking_id           INT OUTPUT -- returns new booking id (or NULL on reject)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status       NVARCHAR(20);
    DECLARE @instant      BIT;
    DECLARE @now          DATETIME2 = SYSDATETIME();

    BEGIN TRY
        IF @end_time <= @start_time
            THROW 51000, 'end_time must be after start_time.', 1;
        IF @expected_participants <= 0
            THROW 51001, 'expected_participants must be positive.', 1;

        BEGIN TRANSACTION;

        -- Step 1: Serialize on the space row. HOLDLOCK (=SERIALIZABLE) keeps
        -- the lock until COMMIT and prevents phantom inserts in the overlap scan.
        SELECT @instant = s.allows_instant_booking
        FROM dbo.spaces s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.space_id = @space_id;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 51002, 'Space does not exist.', 1;
        END

        -- Step 2: reject if the space is not bookable (closed / retired)
        IF EXISTS (
            SELECT 1 FROM dbo.spaces WITH (NOLOCK)
            WHERE space_id = @space_id
              AND current_status IN ('Temporarily Closed', 'Retired')
        )
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 51003, 'Space is not available for booking.', 1;
        END

        -- Step 3: reject on overlapping APPROVED booking (BR-01, concurrency-safe)
        IF EXISTS (
            SELECT 1
            FROM dbo.bookings WITH (NOLOCK)
            WHERE space_id = @space_id
              AND status = 'Approved'
              AND @start_time < end_time
              AND @end_time   > start_time
        )
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 51004, 'Overlapping approved booking already exists.', 1;
        END

        -- Step 4: reject on overlapping OUT-OF-SERVICE maintenance (refined BR-02)
        IF EXISTS (
            SELECT 1
            FROM dbo.maintenance_records WITH (NOLOCK)
            WHERE space_id = @space_id
              AND impact_level = 'out-of-service'
              AND (completion_time IS NULL OR completion_time > @start_time)
              AND start_time < @end_time
        )
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 51005, 'Space is under out-of-service maintenance.', 1;
        END

        -- Step 5: determine target status (instant approval)
        SET @status = CASE WHEN @instant = 1 THEN 'Approved' ELSE 'Pending' END;

        -- Step 6: insert booking
        INSERT INTO dbo.bookings (
            user_id, space_id, start_time, end_time,
            purpose, expected_participants, status
        )
        VALUES (
            @user_id, @space_id, @start_time, @end_time,
            @purpose, @expected_participants, @status
        );

        SET @booking_id = SCOPE_IDENTITY();

        -- Step 7: instant bookings must acknowledge every ACTIVE advisory
        -- on the space (CH-02 / CH-07)
        IF @instant = 1
        BEGIN
            INSERT INTO dbo.advisory_acknowledgements (booking_id, maintenance_id, acknowledged_at)
            SELECT @booking_id, mr.maintenance_id, @now
            FROM dbo.maintenance_records mr WITH (NOLOCK)
            WHERE mr.space_id = @space_id
              AND mr.impact_level = 'advisory'
              AND (mr.completion_time IS NULL OR mr.completion_time > @start_time)
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.advisory_acknowledgements ack
                  WHERE ack.booking_id = @booking_id
                    AND ack.maintenance_id = mr.maintenance_id
              );
        END

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SET @booking_id = NULL;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- Escalation routine: set maintenance to out-of-service + write history +
-- (handled at query level in Step 16) identify affected approved bookings.
-- ============================================================================
IF OBJECT_ID(N'dbo.usp_SetMaintenanceImpactLevel', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SetMaintenanceImpactLevel;
GO

CREATE PROCEDURE dbo.usp_SetMaintenanceImpactLevel
    @maintenance_id INT,
    @new_level      NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @new_level NOT IN ('out-of-service', 'advisory')
            THROW 51010, 'Invalid impact_level.', 1;

        BEGIN TRANSACTION;

        DECLARE @current NVARCHAR(20);
        SELECT @current = impact_level
        FROM dbo.maintenance_records WITH (UPDLOCK, HOLDLOCK)
        WHERE maintenance_id = @maintenance_id;

        IF @current IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 51011, 'Maintenance record not found.', 1;
        END

        IF @current <> @new_level
        BEGIN
            UPDATE dbo.maintenance_records
            SET impact_level = @new_level
            WHERE maintenance_id = @maintenance_id;

            INSERT INTO dbo.maintenance_impact_history (maintenance_id, impact_level, changed_at)
            VALUES (@maintenance_id, @new_level, SYSDATETIME());
        END

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT N'Concurrency implementation deployed.';
GO