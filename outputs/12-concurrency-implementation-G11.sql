/*
===============================================================================
  12-concurrency-implementation-G11.sql
  Campus Space Management System - Phase 2 Concurrency Implementation
  Group: G11
===============================================================================
  PURPOSE:
    Translates the concurrency design (outputs/11-concurrency-design-G11.md)
    into executable T-SQL. Implements Strategy B (pessimistic locking with
    UPDLOCK + HOLDLOCK) inside stored procedures so that:

    BR-01  No two approved bookings may overlap on the same space.
    BR-02  A space with overlapping out-of-service maintenance (or a closed /
           retired / under-maintenance space) cannot be booked.
    BR-P2-03 Automatic approval is granted ONLY when every policy check passes
           AND the target space has SPACE.AutoBookingEnabled = 1.
    RC-03  Advisory maintenance is surfaced to the requester and acknowledged.

  MANDATORY DELIVERABLE: sp_AutoApproveBookingRequest
    - evaluates a booking request against the space usage policy constraints,
    - auto-approves ONLY when all checks pass AND AutoBookingEnabled = 1,
    - on any failure (including auto-booking disabled) does NOT auto-approve
      and returns a clear status via an OUTPUT parameter.

  All objects are created with CREATE OR ALTER so the script is idempotent
  and safe to re-run.
===============================================================================
*/

USE [CampusSpaceManagement];
GO

/* ----------------------------------------------------------------------------
   HELPER - active out-of-service maintenance overlapping a window
   Returns maintenance records of the space that are open and
   impact_level = 'out-of-service' and overlap [@start, @end].
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.fn_active_out_of_service', N'IF') IS NULL
BEGIN
    EXEC (N'
    CREATE FUNCTION dbo.fn_active_out_of_service (
        @space_id INT,
        @start    DATETIME2,
        @end      DATETIME2
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT m.maintenance_id
        FROM dbo.maintenance_records m
        WHERE m.space_id = @space_id
          AND m.impact_level = ''out-of-service''
          AND m.status NOT IN (''Completed'', ''Cancelled'')
          AND m.start_time < @end
          AND (m.completion_time IS NULL OR m.completion_time > @start)
    );
    ');
END
GO

/* ----------------------------------------------------------------------------
   PROCEDURE 1 (MANDATORY): sp_AutoApproveBookingRequest
   ----------------------------------------------------------------------------
   Automatic booking + approval for a selected space.
   - Returns @result_status:
       'AUTO_APPROVED'        -> booking created and approved.
       'AUTO_BOOKING_DISABLED'-> space exists but AutoBookingEnabled = 0
                                 (must NOT be auto-approved; staff path only).
       'SPACE_NOT_FOUND'      -> no such space.
       'SPACE_UNAVAILABLE'    -> space closed / retired / under maintenance.
       'CAPACITY_VIOLATION'   -> expected participants exceed capacity.
       'POLICY_VIOLATION'     -> purpose not allowed by space usage policy.
       'OVERLAP'              -> another approved booking overlaps (BR-01).
       'OUT_OF_SERVICE'       -> out-of-service maintenance overlaps (BR-02).
       'INVALID_ARGS'         -> invalid time range / purpose / participants.
   - If @result_status <> 'AUTO_APPROVED', no booking row is written.
--------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_AutoApproveBookingRequest
    @user_id                   INT,
    @space_id                  INT,
    @start_time                DATETIME2,
    @end_time                  DATETIME2,
    @purpose                   NVARCHAR(50),
    @expected_participants     INT = NULL,
    @result_status             NVARCHAR(40) OUTPUT,
    @booking_id                INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @is_auto            BIT;
    DECLARE @capacity           INT;
    DECLARE @current_status     NVARCHAR(20);
    DECLARE @usage_policy       NVARCHAR(MAX);
    DECLARE @has_advisory       BIT = 0;
    DECLARE @new_booking_id     INT;

    SET @result_status = 'AUTO_APPROVED';
    SET @booking_id    = NULL;

    -- Argument validation (no transaction needed yet).
    IF @end_time <= @start_time
       OR @purpose NOT IN ('Lecture', 'Examination', 'Seminar', 'Workshop',
                           'Meeting', 'Student Activity', 'Administrative Event')
       OR (@expected_participants IS NOT NULL AND @expected_participants <= 0)
    BEGIN
        SET @result_status = 'INVALID_ARGS';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        /* 1. Lock the space row and read its state, capacity, policy, and the
              AutoBookingEnabled gate. UPDLOCK serializes concurrent readers
              of the same space row. */
        SELECT @is_auto        = s.AutoBookingEnabled,
               @capacity       = s.capacity,
               @current_status = s.current_status,
               @usage_policy   = s.usage_policy
        FROM dbo.spaces s WITH (UPDLOCK)
        WHERE s.space_id = @space_id;

        IF @is_auto IS NULL
        BEGIN
            SET @result_status = 'SPACE_NOT_FOUND';
            ROLLBACK;
            RETURN;
        END

        /* 2. MANDATORY GATE: auto-approval only when AutoBookingEnabled = 1. */
        IF @is_auto = 0
        BEGIN
            SET @result_status = 'AUTO_BOOKING_DISABLED';
            ROLLBACK;
            RETURN;
        END

        /* 3. Space availability (BR-02). */
        IF @current_status IN ('Temporarily Closed', 'Retired', 'Under Maintenance')
        BEGIN
            SET @result_status = 'SPACE_UNAVAILABLE';
            ROLLBACK;
            RETURN;
        END

        /* 4. Capacity check. */
        IF @expected_participants IS NOT NULL AND @expected_participants > @capacity
        BEGIN
            SET @result_status = 'CAPACITY_VIOLATION';
            ROLLBACK;
            RETURN;
        END

        /* 5. Usage-policy check (BR-P2-03). A NULL/empty policy is open.
              Otherwise the purpose keyword must appear in the policy text. */
        IF @usage_policy IS NOT NULL AND LTRIM(RTRIM(@usage_policy)) <> N''
           AND CHARINDEX(@purpose, @usage_policy) = 0
        BEGIN
            SET @result_status = 'POLICY_VIOLATION';
            ROLLBACK;
            RETURN;
        END

        /* 6. SERIALIZATION POINT (Strategy B): guarded overlap scan.
              UPDLOCK + HOLDLOCK on IX_bookings_space_time takes a range lock
              so a concurrent identical request blocks here, then re-scans
              after this transaction commits and sees the conflict. */
        IF EXISTS (
            SELECT 1
            FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND status IN ('Approved', 'Checked In', 'Completed')
              AND start_time < @end_time
              AND end_time   > @start_time
        )
        BEGIN
            SET @result_status = 'OVERLAP';
            ROLLBACK;
            RETURN;
        END

        /* 7. Out-of-service maintenance gate (BR-02). */
        IF EXISTS (SELECT 1 FROM dbo.fn_active_out_of_service(@space_id, @start_time, @end_time))
        BEGIN
            SET @result_status = 'OUT_OF_SERVICE';
            ROLLBACK;
            RETURN;
        END

        /* 8. Collect active advisories (informational, no lock needed). */
        IF EXISTS (
            SELECT 1
            FROM dbo.maintenance_records m
            WHERE m.space_id = @space_id
              AND m.impact_level = 'advisory'
              AND m.status NOT IN ('Completed', 'Cancelled')
              AND m.start_time < @end_time
              AND (m.completion_time IS NULL OR m.completion_time > @start_time)
        )
            SET @has_advisory = 1;

        /* 9. INSERT the booking as APPROVED (instant path). */
        INSERT INTO dbo.bookings
            (user_id, space_id, start_time, end_time, purpose,
             expected_participants, status, advisory_acknowledged, advisory_snapshot)
        VALUES
            (@user_id, @space_id, @start_time, @end_time, @purpose,
             @expected_participants, 'Approved', 0, NULL);

        SET @new_booking_id = SCOPE_IDENTITY();

        /* 10. Record the automatic decision (staff_id NULL = system actor,
               keeping approval history uniform, BR-03). */
        INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note)
        VALUES (@new_booking_id, NULL, SYSDATETIME(),
                N'Automatic approval (auto-booking policy, AutoBookingEnabled=1).');

        /* 11. Acknowledge each active advisory (RC-03 / BR-P2-01). */
        IF @has_advisory = 1
        BEGIN
            INSERT INTO dbo.advisory_acknowledgements (booking_id, maintenance_id, acknowledged_by, acknowledged_at)
            SELECT @new_booking_id, m.maintenance_id, @user_id, SYSDATETIME()
            FROM dbo.maintenance_records m
            WHERE m.space_id = @space_id
              AND m.impact_level = 'advisory'
              AND m.status NOT IN ('Completed', 'Cancelled')
              AND m.start_time < @end_time
              AND (m.completion_time IS NULL OR m.completion_time > @start_time);

            UPDATE dbo.bookings
            SET advisory_acknowledged = 1,
                advisory_snapshot = (
                    SELECT STRING_AGG(N'[' + CAST(m.maintenance_id AS NVARCHAR(20)) + N'] ' + m.problem_description, N'; ')
                    FROM dbo.maintenance_records m
                    WHERE m.space_id = @space_id
                      AND m.impact_level = 'advisory'
                      AND m.status NOT IN ('Completed', 'Cancelled')
                      AND m.start_time < @end_time
                      AND (m.completion_time IS NULL OR m.completion_time > @start_time)
                )
            WHERE booking_id = @new_booking_id;
        END

        COMMIT;

        SET @booking_id    = @new_booking_id;
        SET @result_status = 'AUTO_APPROVED';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @result_status = N'ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------------------------
   PROCEDURE 2: sp_book_space_staff_approve
   Staff-approval path. Uses the same serialization point so that BR-01 holds
   regardless of which path created/approved the booking.
--------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_book_space_staff_approve
    @booking_id    INT,
    @staff_id      INT,
    @decision_note NVARCHAR(MAX) = NULL,
    @result_status NVARCHAR(40) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @space_id    INT;
    DECLARE @start_time  DATETIME2;
    DECLARE @end_time    DATETIME2;

    SET @result_status = 'APPROVED';

    BEGIN TRY
        BEGIN TRAN;

        /* Lock the pending booking row first (single-row guard, C3). */
        SELECT @space_id = space_id, @start_time = start_time, @end_time = end_time
        FROM dbo.bookings WITH (UPDLOCK)
        WHERE booking_id = @booking_id;

        IF @space_id IS NULL
        BEGIN
            SET @result_status = 'BOOKING_NOT_FOUND';
            ROLLBACK;
            RETURN;
        END

        /* Serialize writers for this space+window and re-check overlap. */
        IF EXISTS (
            SELECT 1
            FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
            WHERE space_id = @space_id
              AND booking_id <> @booking_id
              AND status IN ('Approved', 'Checked In', 'Completed')
              AND start_time < @end_time
              AND end_time   > @start_time
        )
        BEGIN
            SET @result_status = 'OVERLAP';
            ROLLBACK;
            RETURN;
        END

        /* Reject if an out-of-service maintenance now overlaps (BR-02). */
        IF EXISTS (SELECT 1 FROM dbo.fn_active_out_of_service(@space_id, @start_time, @end_time))
        BEGIN
            SET @result_status = 'OUT_OF_SERVICE';
            ROLLBACK;
            RETURN;
        END

        /* Approve the booking. */
        UPDATE dbo.bookings
        SET status = 'Approved'
        WHERE booking_id = @booking_id;

        /* Record the staff decision (BR-03, BR-09). */
        IF EXISTS (SELECT 1 FROM dbo.approvals WHERE booking_id = @booking_id)
        BEGIN
            UPDATE dbo.approvals
            SET staff_id = @staff_id, decision_time = SYSDATETIME(),
                decision_note = ISNULL(@decision_note, decision_note)
            WHERE booking_id = @booking_id;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note)
            VALUES (@booking_id, @staff_id, SYSDATETIME(), @decision_note);
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @result_status = N'ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------------------------
   PROCEDURE 3: sp_set_maintenance_impact
   Escalate/downgrade impact_level with C4 protection (UPDLOCK on the row)
   and, on escalation to out-of-service, surface affected approved bookings
   (RC-04 / RC-10).
--------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_set_maintenance_impact
    @maintenance_id INT,
    @new_impact     NVARCHAR(20),
    @result_note    NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @space_id INT;

    BEGIN TRY
        BEGIN TRAN;

        /* Lock the maintenance row to serialize concurrent impact changes. */
        SELECT @space_id = m.space_id
        FROM dbo.maintenance_records m WITH (UPDLOCK)
        WHERE m.maintenance_id = @maintenance_id;

        IF @space_id IS NULL
        BEGIN
            RAISERROR('MAINTENANCE_NOT_FOUND: maintenance record does not exist.', 16, 1);
        END

        IF @new_impact NOT IN ('out-of-service', 'advisory')
        BEGIN
            RAISERROR('INVALID_IMPACT: impact_level must be ''out-of-service'' or ''advisory''.', 16, 1);
        END

        UPDATE dbo.maintenance_records
        SET impact_level = @new_impact,
            result_note   = ISNULL(@result_note, result_note)
        WHERE maintenance_id = @maintenance_id;

        /* If escalated to out-of-service, surface approved bookings affected. */
        IF @new_impact = 'out-of-service'
        BEGIN
            SELECT b.booking_id, b.user_id, b.space_id, b.start_time, b.end_time,
                   u.email AS requester_email
            FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN dbo.maintenance_records m
                ON m.space_id = b.space_id
            INNER JOIN dbo.users u ON u.user_id = b.user_id
            WHERE m.maintenance_id = @maintenance_id
              AND b.status IN ('Approved', 'Checked In')
              AND m.start_time < b.end_time
              AND (m.completion_time IS NULL OR m.completion_time > b.start_time)
            ORDER BY b.start_time;
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

PRINT 'Phase 2 concurrency implementation installed successfully.';
GO
