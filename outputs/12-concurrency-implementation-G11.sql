/*
===============================================================================
  12-concurrency-implementation-G11.sql
  Campus Space Management System - Phase 2 Concurrency Implementation
  Group: G11
===============================================================================
  Implements the strategy from outputs/11-concurrency-design-G11.md:
    - SERIALIZABLE isolation + UPDLOCK,HOLDLOCK range locks on the space-time
      booking window (single serialization point shared by BOTH approval paths).
    - Maintenance blocking ONLY via MAINTENANCE_RECORD impact_level =
      'out-of-service' overlapping the requested window. Advisory records never
      block (BR-12). INCIDENT_REPORT is never consulted for booking blocking
      (BR-15). SPACE.current_status no longer carries maintenance semantics.
    - Automatic approvals require SPACE.AutoBookingEnabled = 1 and record
      APPROVAL.staff_id = NULL (no human actor).
    - Incident-to-maintenance triage consolidates many INCIDENT_REPORT rows into
      one MAINTENANCE_RECORD without duplication under concurrent execution.

  Script is IDEMPOTENT (DROP + CREATE guarded) and safe to re-run.
===============================================================================
*/

USE [CampusSpaceManagement];
GO

/* ----------------------------------------------------------------------------
   SECTION 1 - HELPER FUNCTION
   fn_active_out_of_service(@space_id, @start, @end)
   Returns maintenance records that block a booking: open, impact_level =
   'out-of-service', and whose [start_time, completion_time) window overlaps
   the requested [@start, @end) window.
   Used by BOTH the instant and staff approval paths so the blocking rule is
   defined in exactly one place.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.fn_active_out_of_service', N'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_active_out_of_service;
GO

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
      AND m.impact_level = 'out-of-service'
      AND m.status NOT IN ('Completed', 'Cancelled')
      AND m.start_time < @end
      AND (m.completion_time IS NULL OR m.completion_time > @start)
);
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
       'SPACE_UNAVAILABLE'    -> space operationally closed / retired.
       'CAPACITY_VIOLATION'   -> expected participants exceed capacity.
       'POLICY_VIOLATION'     -> purpose not allowed by space usage policy.
       'OVERLAP'              -> another approved booking overlaps (BR-01).
       'OUT_OF_SERVICE'       -> out-of-service maintenance overlaps (BR-11).
       'INVALID_ARGS'         -> invalid time range / purpose / participants.
   - If @result_status <> 'AUTO_APPROVED', no booking row is written.
   - CONCURRENCY: the overlap + out-of-service scans run under
     UPDLOCK + HOLDLOCK inside SERIALIZABLE, so two concurrent identical
     requests cannot both pass the check-then-act window.
   - MAINTENANCE BLOCKING: governed ONLY by MAINTENANCE_RECORD.impact_level =
     'out-of-service' overlap. Advisory levels and INCIDENT_REPORT rows are
     never blocking (BR-12, BR-15).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.sp_AutoApproveBookingRequest', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_AutoApproveBookingRequest;
GO

CREATE PROCEDURE dbo.sp_AutoApproveBookingRequest
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
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

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

        /* 3. Broad operational state only (C2). 'Under Maintenance' no longer
              exists in this domain; maintenance blocking is decided in step 7
              exclusively from MAINTENANCE_RECORD. */
        IF @current_status IN ('Temporarily Closed', 'Retired')
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

        /* 5. Usage-policy check (BR-13). A NULL/empty policy is open.
              Otherwise the purpose keyword must appear in the policy text. */
        IF @usage_policy IS NOT NULL AND LTRIM(RTRIM(@usage_policy)) <> N''
           AND CHARINDEX(@purpose, @usage_policy) = 0
        BEGIN
            SET @result_status = 'POLICY_VIOLATION';
            ROLLBACK;
            RETURN;
        END

        /* 6. SERIALIZATION POINT (BR-01): guarded overlap scan.
              UPDLOCK + HOLDLOCK on IX_bookings_space_time takes a key-range
              lock so a concurrent identical request blocks here, then re-scans
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

        /* 7. Maintenance gate: ONLY overlapping MAINTENANCE_RECORD rows with
              impact_level = 'out-of-service' block (BR-11). Advisory records
              and INCIDENT_REPORT rows never block. */
        IF EXISTS (SELECT 1 FROM dbo.fn_active_out_of_service(@space_id, @start_time, @end_time))
        BEGIN
            SET @result_status = 'OUT_OF_SERVICE';
            ROLLBACK;
            RETURN;
        END

        /* 8. Collect active advisories (informational, BR-12). */
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
               BR-14 / C7). */
        INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note)
        VALUES (@new_booking_id, NULL, SYSDATETIME(),
                N'Automatic approval (auto-booking policy, AutoBookingEnabled=1).');

        /* 11. Acknowledge each active advisory (C5 / BR-12). */
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
   regardless of which path created/approved the booking. Manual approvals
   record the deciding staff member (staff_id = @staff_id).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.sp_book_space_staff_approve', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_book_space_staff_approve;
GO

CREATE PROCEDURE dbo.sp_book_space_staff_approve
    @booking_id    INT,
    @staff_id      INT,
    @decision_note NVARCHAR(MAX) = NULL,
    @result_status NVARCHAR(40) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    DECLARE @space_id    INT;
    DECLARE @start_time  DATETIME2;
    DECLARE @end_time    DATETIME2;

    SET @result_status = 'APPROVED';

    BEGIN TRY
        BEGIN TRAN;

        /* Lock the pending booking row first (single-row guard). */
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

        /* Reject only if an overlapping out-of-service maintenance now blocks
           (BR-11). Advisory maintenance never blocks the staff path either. */
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

        /* Record the staff decision (BR-03, BR-09). Manual approval always
           records the deciding staff member. */
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
   PROCEDURE 3: sp_consolidate_incident_reports
   Manager/staff triage: consolidate one or more INCIDENT_REPORT rows into a
   single MAINTENANCE_RECORD. Many reports -> one record (C8).
   - Concurrency: incident_report_id is UNIQUE in report_consolidations, so a
     report can be merged into at most one record. Two managers triaging the
     same report concurrently -> the loser hits UNIQUE violation (2627),
     rolls back, and returns 'ALREADY_CONSOLIDATED'.
   - Impact_level authority is decided here (manager/staff), never on the
     end-user report (BR-15). Bookings never consult incident_reports.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.sp_consolidate_incident_reports', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_consolidate_incident_reports;
GO

CREATE PROCEDURE dbo.sp_consolidate_incident_reports
    @staff_id             INT,
    @space_id             INT,
    @problem_description  NVARCHAR(MAX),
    @impact_level         NVARCHAR(20) = 'out-of-service',
    @report_ids           NVARCHAR(MAX),      -- comma-separated incident report ids
    @maintenance_id       INT OUTPUT,
    @result_status        NVARCHAR(40) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    DECLARE @new_maintenance_id INT;

    SET @maintenance_id = NULL;
    SET @result_status  = 'CONSOLIDATED';

    -- Validate impact level authority input.
    IF @impact_level NOT IN ('out-of-service', 'advisory')
    BEGIN
        SET @result_status = 'INVALID_IMPACT';
        RETURN;
    END

    IF @report_ids IS NULL OR LTRIM(RTRIM(@report_ids)) = N''
    BEGIN
        SET @result_status = 'NO_REPORTS';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        /* 1. Lock the candidate incident report rows (UPDLOCK) so concurrent
              triage on the same set serializes on the row rather than racing. */
        SELECT r.report_id
        FROM dbo.incident_reports r WITH (UPDLOCK)
        INNER JOIN dbo.fn_split_ids(@report_ids) ids ON ids.value = r.report_id;

        /* 2. Re-check under lock that none of them is already consolidated. */
        IF EXISTS (
            SELECT 1
            FROM dbo.report_consolidations rc WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN dbo.fn_split_ids(@report_ids) ids ON ids.value = rc.incident_report_id
        )
        BEGIN
            SET @result_status = 'ALREADY_CONSOLIDATED';
            ROLLBACK;
            RETURN;
        END

        /* 3. Create the maintenance record (impact authority = staff/manager). */
        INSERT INTO dbo.maintenance_records
            (space_id, reporter_id, assigned_staff_id, problem_description,
             start_time, completion_time, status, result_note, impact_level)
        VALUES
            (@space_id, @staff_id, @staff_id, @problem_description,
             SYSDATETIME(), NULL, 'Open', NULL, @impact_level);

        SET @new_maintenance_id = SCOPE_IDENTITY();

        /* 4. Link every report to the new record. UNIQUE(incident_report_id)
              makes a concurrent duplicate triage fail here with 2627. */
        INSERT INTO dbo.report_consolidations
            (incident_report_id, maintenance_id, consolidated_by, consolidated_at)
        SELECT r.report_id, @new_maintenance_id, @staff_id, SYSDATETIME()
        FROM dbo.incident_reports r
        INNER JOIN dbo.fn_split_ids(@report_ids) ids ON ids.value = r.report_id
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.report_consolidations rc
            WHERE rc.incident_report_id = r.report_id
        );

        /* 5. Mark the reports triaged. */
        UPDATE dbo.incident_reports
        SET status = 'Triaged'
        WHERE report_id IN (SELECT value FROM dbo.fn_split_ids(@report_ids));

        COMMIT;

        SET @maintenance_id = @new_maintenance_id;
        SET @result_status  = 'CONSOLIDATED';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;

        IF ERROR_NUMBER() = 2627 OR ERROR_NUMBER() = 2601
        BEGIN
            SET @result_status = 'ALREADY_CONSOLIDATED';
            RETURN;
        END

        SET @result_status = N'ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------------------------
   PROCEDURE 4: sp_set_maintenance_impact
   Escalate/downgrade impact_level with row-level locking (C4). On escalation
   to out-of-service, surface affected approved bookings (C10 / report Q4) so
   staff can contact requesters.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.sp_set_maintenance_impact', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_set_maintenance_impact;
GO

CREATE PROCEDURE dbo.sp_set_maintenance_impact
    @maintenance_id INT,
    @new_impact     NVARCHAR(20),
    @result_note    NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

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

/* ----------------------------------------------------------------------------
   SECTION 2 - SUPPORTING FUNCTION
   fn_split_ids: splits a comma-separated integer list (used by triage).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.fn_split_ids', N'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_split_ids;
GO

CREATE FUNCTION dbo.fn_split_ids (@list NVARCHAR(MAX))
RETURNS TABLE
AS
RETURN
(
    SELECT CAST(value AS INT) AS value
    FROM STRING_SPLIT(@list, ',')
    WHERE LTRIM(RTRIM(value)) <> N''
);
GO

PRINT 'Phase 2 concurrency implementation applied successfully.';
GO
