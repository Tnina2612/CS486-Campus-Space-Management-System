/*
================================================================================
  12-concurrency-implementation-G11.sql
  Campus Space Management System - Phase 2 Concurrency Implementation
  Group: G11
================================================================================
  Implements the pessimistic locking strategy from outputs/11-concurrency-design-G11.md
  for the CampusSpaceManagement database (after applying outputs/10-schema-migration-G11.sql).

  Procedures:
    usp_CreateInstantBooking   -- auto-approve path (RC-05), guards BR-01/BR-02
    usp_ApproveBooking         -- staff approval path, guards BR-01/BR-02/BR-03
    usp_RejectBooking          -- staff rejection path (BR-04)
    usp_UpdateMaintenanceImpactLevel -- escalation/downgrade (RC-04), guards C2/C4
================================================================================
*/

USE [CampusSpaceManagement];
GO

/* ----------------------------------------------------------------------------
   Drop-first guards so the script is idempotent.
---------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.usp_CreateInstantBooking', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_CreateInstantBooking;
IF OBJECT_ID(N'dbo.usp_ApproveBooking', N'P') IS NOT NULL          DROP PROCEDURE dbo.usp_ApproveBooking;
IF OBJECT_ID(N'dbo.usp_RejectBooking', N'P') IS NOT NULL           DROP PROCEDURE dbo.usp_RejectBooking;
IF OBJECT_ID(N'dbo.usp_UpdateMaintenanceImpactLevel', N'P') IS NOT NULL DROP PROCEDURE dbo.usp_UpdateMaintenanceImpactLevel;
GO

/* ----------------------------------------------------------------------------
   PROCEDURE: usp_CreateInstantBooking
   Creates a booking and auto-approves it in one atomic transaction.
   SERIALIZATION POINT: guarded overlap scan with WITH (UPDLOCK, HOLDLOCK)
   against index IX_bookings_space_time (space_id, start_time, end_time).
---------------------------------------------------------------------------- */
CREATE PROCEDURE dbo.usp_CreateInstantBooking
    @user_id               INT,
    @space_id              INT,
    @start_time            DATETIME2,
    @end_time              DATETIME2,
    @purpose               NVARCHAR(50),
    @expected_participants INT = NULL,
    @system_staff_id       INT,           -- sentinel staff user id used for auto-approval audit
    @booking_id            INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @snapshot NVARCHAR(MAX);
    DECLARE @space_status NVARCHAR(20);
    DECLARE @capacity INT;
    DECLARE @instant_bookable BIT;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---- 1. Space state + capacity + instant-eligibility (RC-05) ----
           Take UPDLOCK on the space row so its status cannot change mid-flight. */
        SELECT @space_status     = s.current_status,
               @capacity         = s.capacity,
               @instant_bookable = s.instant_bookable
        FROM dbo.spaces AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.space_id = @space_id;

        IF @space_status IS NULL
        BEGIN
            THROW 50001, N'Space does not exist.', 1;
        END

        IF @space_status IN ('Under Maintenance', 'Temporarily Closed', 'Retired')
        BEGIN
            THROW 50001, N'Space is not bookable in its current status.', 1;
        END

        IF @instant_bookable = 0
        BEGIN
            THROW 50009, N'Space is not eligible for instant booking; submit a staff approval request instead.', 1;
        END

        IF @expected_participants IS NOT NULL AND @expected_participants > @capacity
        BEGIN
            THROW 50001, N'Expected participants exceed the space capacity.', 1;
        END

        /* ---- 2. SERIALIZATION POINT: overlap check (BR-01) ----
           UPDLOCK + HOLDLOCK hold a key-range lock on the candidate interval,
           so a concurrent identical request blocks here until we COMMIT. */
        IF EXISTS (
            SELECT 1
            FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND status IN ('Approved', 'Checked In', 'Completed')
              AND start_time < @end_time
              AND end_time  > @start_time
        )
        BEGIN
            THROW 50002, N'Time conflict: the space is already approved for an overlapping period.', 1;
        END

        /* ---- 3. Maintenance gate (BR-02 refined by RC-01) ----
           out-of-service maintenance overlapping the interval blocks the booking. */
        IF EXISTS (
            SELECT 1
            FROM dbo.maintenance_records
            WHERE space_id = @space_id
              AND impact_level = 'out-of-service'
              AND (completion_time IS NULL OR completion_time > @start_time)
              AND start_time < @end_time
        )
        BEGIN
            THROW 50003, N'The space is under out-of-service maintenance for this period.', 1;
        END

        /* ---- 4. Collect advisory maintenance for the acknowledgement (RC-03) ---- */
        SELECT @snapshot = STRING_AGG(
                   CONCAT('Maintenance #', m.maintenance_id, ': ', m.problem_description),
                   CHAR(10)
               )
        FROM dbo.maintenance_records AS m
        WHERE m.space_id = @space_id
          AND m.impact_level = 'advisory'
          AND (m.completion_time IS NULL OR m.completion_time > @start_time)
          AND m.start_time < @end_time;

        /* ---- 5. Insert booking ----
           advisories_acknowledged = 1 when advisory maintenance exists. */
        INSERT INTO dbo.bookings (
            user_id, space_id, start_time, end_time, purpose,
            expected_participants, status,
            advisories_acknowledged, advisories_snapshot
        )
        VALUES (
            @user_id, @space_id, @start_time, @end_time, @purpose,
            @expected_participants, 'Approved',
            CASE WHEN @snapshot IS NULL THEN 0 ELSE 1 END,
            @snapshot
        );

        SET @booking_id = SCOPE_IDENTITY();

        /* ---- 6. Auto-approval audit record (BR-03 / A-05) ---- */
        INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
        VALUES (@booking_id, @system_staff_id, SYSDATETIME(), N'Instant booking auto-approval (usage policy satisfied).', NULL);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        /* Deadlock (1205) / lock-timeout (1222): re-raise so caller can retry. */
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------------------------
   PROCEDURE: usp_ApproveBooking
   Staff approval path. Serializes against concurrent instant bookings and other
   approvals for the same space/interval, then records the decision.
---------------------------------------------------------------------------- */
CREATE PROCEDURE dbo.usp_ApproveBooking
    @booking_id   INT,
    @staff_id     INT,
    @decision_note NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @space_id INT;
    DECLARE @start_time DATETIME2;
    DECLARE @end_time DATETIME2;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Lock the booking row (UPDLOCK) so it cannot be double-approved (C3). */
        SELECT @space_id   = b.space_id,
               @start_time = b.start_time,
               @end_time   = b.end_time
        FROM dbo.bookings AS b WITH (UPDLOCK, HOLDLOCK)
        WHERE b.booking_id = @booking_id;

        IF @space_id IS NULL
            THROW 50004, N'Booking does not exist.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @booking_id AND status = 'Pending')
            THROW 50004, N'Booking is not in Pending state; it cannot be approved.', 1;

        /* ---- SERIALIZATION POINT: overlap check (BR-01), same guard as instant booking. ---- */
        IF EXISTS (
            SELECT 1
            FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND status IN ('Approved', 'Checked In', 'Completed')
              AND start_time < @end_time
              AND end_time  > @start_time
        )
        BEGIN
            THROW 50002, N'Time conflict: the space is already approved for an overlapping period.', 1;
        END

        /* ---- Maintenance gate (BR-02 refined by RC-01). ---- */
        IF EXISTS (
            SELECT 1
            FROM dbo.maintenance_records
            WHERE space_id = @space_id
              AND impact_level = 'out-of-service'
              AND (completion_time IS NULL OR completion_time > @start_time)
              AND start_time < @end_time
        )
        BEGIN
            THROW 50003, N'The space is under out-of-service maintenance for this period.', 1;
        END

        /* ---- Approve + audit. ---- */
        UPDATE dbo.bookings
        SET status = 'Approved'
        WHERE booking_id = @booking_id;

        INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
        VALUES (@booking_id, @staff_id, SYSDATETIME(), @decision_note, NULL);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------------------------
   PROCEDURE: usp_RejectBooking
   Staff rejection path (BR-04). Requires a rejection reason.
---------------------------------------------------------------------------- */
CREATE PROCEDURE dbo.usp_RejectBooking
    @booking_id       INT,
    @staff_id         INT,
    @rejection_reason NVARCHAR(MAX),
    @decision_note    NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @rejection_reason IS NULL OR LTRIM(RTRIM(@rejection_reason)) = ''
            THROW 50005, N'Rejection reason is required when a booking is rejected (BR-04).', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
            WHERE booking_id = @booking_id AND status = 'Pending'
        )
            THROW 50004, N'Booking is not in Pending state; it cannot be rejected.', 1;

        UPDATE dbo.bookings
        SET status = 'Rejected'
        WHERE booking_id = @booking_id;

        INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
        VALUES (@booking_id, @staff_id, SYSDATETIME(), @decision_note, @rejection_reason);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------------------------
   PROCEDURE: usp_UpdateMaintenanceImpactLevel
   Escalates / downgrades impact_level while a maintenance record is open (RC-04).
   - UPDLOCK on the maintenance row prevents lost updates (C4).
   - On escalation to out-of-service, returns the set of affected approved
     bookings (output 16 query) for staff contact.
---------------------------------------------------------------------------- */
CREATE PROCEDURE dbo.usp_UpdateMaintenanceImpactLevel
    @maintenance_id INT,
    @new_level      NVARCHAR(20),
    @result_note    NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @space_id INT;
    DECLARE @m_start DATETIME2;
    DECLARE @m_end DATETIME2;
    DECLARE @old_level NVARCHAR(20);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Lock the maintenance row. */
        SELECT @space_id = m.space_id,
               @m_start  = m.start_time,
               @m_end    = m.completion_time,
               @old_level = m.impact_level
        FROM dbo.maintenance_records AS m WITH (UPDLOCK, HOLDLOCK)
        WHERE m.maintenance_id = @maintenance_id;

        IF @space_id IS NULL
            THROW 50006, N'Maintenance record does not exist.', 1;

        IF @new_level NOT IN ('out-of-service', 'advisory')
            THROW 50007, N'Impact level must be ''out-of-service'' or ''advisory''.', 1;

        IF @m_end IS NOT NULL
            THROW 50008, N'Cannot change the impact level of a completed maintenance record.', 1;

        /* Serialize against concurrent booking creation (C2): take the same
           booking key-range lock the booking procedures take. */
        IF EXISTS (
            SELECT 1
            FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND status IN ('Approved', 'Checked In', 'Completed')
              AND start_time < COALESCE(@m_end, DATEADD(year, 100, @m_start))
              AND end_time  > @m_start
        )
        BEGIN
            /* Just acquire the range lock; competing instant bookings will
               re-check maintenance after we COMMIT. No action needed. */
            SELECT 1;
        END

        UPDATE dbo.maintenance_records
        SET impact_level = @new_level,
            result_note   = COALESCE(@result_note, result_note)
        WHERE maintenance_id = @maintenance_id;

        /* On escalation to out-of-service, return the affected approved bookings
           so staff can contact requesters (RC-04 / output 16). */
        IF @new_level = 'out-of-service' AND @old_level = 'advisory'
        BEGIN
            SELECT b.booking_id, u.full_name AS requester, u.email,
                   b.start_time, b.end_time, s.space_code
            FROM dbo.bookings AS b
            INNER JOIN dbo.users AS u ON u.user_id = b.user_id
            INNER JOIN dbo.spaces AS s ON s.space_id = b.space_id
            WHERE b.space_id = @space_id
              AND b.status IN ('Approved', 'Checked In', 'Completed')
              AND b.start_time < COALESCE(@m_end, DATEADD(year, 100, @m_start))
              AND b.end_time  > @m_start;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'Concurrency implementation procedures created successfully.';
GO
