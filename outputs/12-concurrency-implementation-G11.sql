/* ============================================================================
   FILE    : outputs/12-concurrency-implementation-G11.sql
   PURPOSE : Phase 2 concurrency control implementation for the Campus Space
             Management System (G11). Implements the pessimistic range-lock
             strategy from outputs/11-concurrency-design-G11.md.

   DELIVERABLES:
     1. sp_AutoApproveBookingRequest  - instant (auto) booking path; sets
                                        approvals.staff_id = NULL.
     2. sp_book_space_staff_approve    - staff approval path; sets
                                        approvals.staff_id = @staff_id.
     3. sp_consolidate_incident_reports - duplicate-report triage dedup.
     4. sp_set_maintenance_impact      - triage authority to escalate/downgrade
                                        impact_level (BR-12).

   CONCURRENCY GUARANTEES (from 11-concurrency-design-G11.md):
     - INV-1: no two approved bookings overlap on the same space.
     - INV-2: no approved booking overlaps an out-of-service maintenance window.
     - Booking-block checks reference ONLY MAINTENANCE_RECORD rows with
       impact_level = 'out-of-service'. Advisory maintenance and INCIDENT_REPORT
       rows never block bookings.

   RUN    : sqlcmd -S localhost -E -C -d CampusSpaceManagement -i outputs/12-concurrency-implementation-G11.sql
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
GO

/* ============================================================================
   PROCEDURE 1: sp_AutoApproveBookingRequest
   ----------------------------------------------------------------------------
   Instant-booking path. Approves a new booking only when ALL policy checks pass
   AND the target space has auto_booking_enabled = 1. On success it inserts the
   APPROVAL row with staff_id = NULL (no staff performed the approval). On any
   failure it does NOT auto-approve and raises a clear status/error.
   ============================================================================ */
IF OBJECT_ID('dbo.sp_AutoApproveBookingRequest', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_AutoApproveBookingRequest;
GO

CREATE PROCEDURE dbo.sp_AutoApproveBookingRequest
    @user_id               INT,
    @space_id              INT,
    @start_time            DATETIME2,
    @end_time              DATETIME2,
    @purpose               NVARCHAR(50),
    @expected_participants INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @space_status  NVARCHAR(20);
    DECLARE @auto_enabled  BIT;
    DECLARE @capacity      INT;
    DECLARE @usage_policy  NVARCHAR(MAX);
    DECLARE @new_booking_id INT;

    BEGIN TRY
        BEGIN TRAN;

        /* 1. Serialize on the space row (per-space triage point). */
        SELECT @space_status = s.current_status,
               @auto_enabled = s.auto_booking_enabled,
               @capacity     = s.capacity,
               @usage_policy = s.usage_policy
          FROM dbo.spaces s WITH (UPDLOCK, ROWLOCK)
         WHERE s.space_id = @space_id;

        IF @space_status IS NULL
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Booking failed: space %d does not exist.', 16, 1, @space_id);
            RETURN;
        END

        /* 2. Broad operational state only. Closed/Retired spaces cannot be
              booked. 'Under Maintenance' is no longer a status value (C2). */
        IF @space_status NOT IN ('Available', 'In Use')
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Booking failed: space %d is not available (current_status = %s).', 16, 1, @space_id, @space_status);
            RETURN;
        END

        /* 3. INV-2: block if an out-of-service maintenance overlaps the window.
              Advisory maintenance does NOT block. INCIDENT_REPORT is ignored. */
        IF EXISTS (
            SELECT 1
              FROM dbo.maintenance_records mr WITH (UPDLOCK, HOLDLOCK)
             WHERE mr.space_id = @space_id
               AND mr.impact_level = 'out-of-service'
               AND mr.start_time < @end_time
               AND (mr.completion_time IS NULL OR mr.completion_time > @start_time)
        )
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Booking failed: space %d is under out-of-service maintenance for the requested period.', 16, 1, @space_id);
            RETURN;
        END

        /* 4. INV-1: block if an approved/active booking overlaps the window. */
        IF EXISTS (
            SELECT 1
              FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
             WHERE b.space_id = @space_id
               AND b.status IN ('Approved', 'Checked In', 'Completed')
               AND b.start_time < @end_time
               AND b.end_time   > @start_time
        )
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Booking failed: space %d already has an approved booking in the requested period.', 16, 1, @space_id);
            RETURN;
        END

        /* 5. Policy checks. */
        IF @auto_enabled = 0
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Booking failed: space %d does not allow auto-booking (auto_booking_enabled = 0).', 16, 1, @space_id);
            RETURN;
        END

        IF @expected_participants IS NOT NULL AND @expected_participants > @capacity
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Booking failed: expected participants %d exceed capacity %d of space %d.', 16, 1, @expected_participants, @capacity, @space_id);
            RETURN;
        END

        IF @usage_policy IS NOT NULL AND @purpose NOT IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Booking failed: purpose %s is not permitted for space %d.', 16, 1, @purpose, @space_id);
            RETURN;
        END

        /* 6. Insert the booking as Approved. */
        INSERT INTO dbo.bookings
            (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
        VALUES
            (@user_id, @space_id, @start_time, @end_time, @purpose, @expected_participants, 'Approved');

        SET @new_booking_id = SCOPE_IDENTITY();

        /* 6b. BR-11: notify the requester of every active advisory overlapping
              the window and record the acknowledgement. Advisory rows never
              block the booking (BR-12), they are only recorded. */
        IF EXISTS (
            SELECT 1
              FROM dbo.maintenance_records mr
             WHERE mr.space_id = @space_id
               AND mr.impact_level = 'advisory'
               AND mr.start_time < @end_time
               AND (mr.completion_time IS NULL OR mr.completion_time > @start_time)
        )
        BEGIN
            INSERT INTO dbo.advisory_acknowledgements
                (booking_id, maintenance_id, acknowledged_by, acknowledged_at)
            SELECT @new_booking_id, mr.maintenance_id, @user_id, SYSDATETIME()
              FROM dbo.maintenance_records mr
             WHERE mr.space_id = @space_id
               AND mr.impact_level = 'advisory'
               AND mr.start_time < @end_time
               AND (mr.completion_time IS NULL OR mr.completion_time > @start_time);

            UPDATE dbo.bookings
               SET advisory_acknowledged = 1,
                   advisory_snapshot = (
                       SELECT STRING_AGG(CONCAT('[', mr.maintenance_id, '] ', mr.problem_description), '; ')
                         FROM dbo.maintenance_records mr
                        WHERE mr.space_id = @space_id
                          AND mr.impact_level = 'advisory'
                          AND mr.start_time < @end_time
                          AND (mr.completion_time IS NULL OR mr.completion_time > @start_time)
                   )
             WHERE booking_id = @new_booking_id;
        END

        /* 7. Record the automatic approval with staff_id = NULL. */
        INSERT INTO dbo.approvals
            (booking_id, staff_id, decision_time, decision_note, rejection_reason)
        VALUES
            (@new_booking_id, NULL, SYSDATETIME(), 'Auto-approved: all policy checks passed.', NULL);

        COMMIT TRAN;

        SELECT @new_booking_id AS booking_id,
               'Approved'      AS status,
               NULL            AS staff_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   PROCEDURE 2: sp_book_space_staff_approve
   ----------------------------------------------------------------------------
   Staff-approval path. Approves an existing Pending booking only when no
   out-of-service maintenance overlap and no approved-booking overlap exists.
   Records the approving staff member (staff_id = @staff_id, non-NULL).
   ============================================================================ */
IF OBJECT_ID('dbo.sp_book_space_staff_approve', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_book_space_staff_approve;
GO

CREATE PROCEDURE dbo.sp_book_space_staff_approve
    @booking_id   INT,
    @staff_id     INT,
    @decision_note NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @space_id   INT;
    DECLARE @start_time DATETIME2;
    DECLARE @end_time   DATETIME2;
    DECLARE @status     NVARCHAR(20);
    DECLARE @space_status NVARCHAR(20);

    BEGIN TRY
        BEGIN TRAN;

        /* 1. Lock the pending booking row. */
        SELECT @space_id   = b.space_id,
               @start_time = b.start_time,
               @end_time   = b.end_time,
               @status     = b.status
          FROM dbo.bookings b WITH (UPDLOCK, ROWLOCK)
         WHERE b.booking_id = @booking_id;

        IF @status IS NULL
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Approval failed: booking %d does not exist.', 16, 1, @booking_id);
            RETURN;
        END

        IF @status <> 'Pending'
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Approval failed: booking %d is not in Pending state (current = %s).', 16, 1, @booking_id, @status);
            RETURN;
        END

        /* 2. Lock the space row. */
        SELECT @space_status = s.current_status
          FROM dbo.spaces s WITH (UPDLOCK, ROWLOCK)
         WHERE s.space_id = @space_id;

        IF @space_status NOT IN ('Available', 'In Use')
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Approval failed: space %d is not available (current_status = %s).', 16, 1, @space_id, @space_status);
            RETURN;
        END

        /* 3. INV-2: block if out-of-service maintenance overlaps. */
        IF EXISTS (
            SELECT 1
              FROM dbo.maintenance_records mr WITH (UPDLOCK, HOLDLOCK)
             WHERE mr.space_id = @space_id
               AND mr.impact_level = 'out-of-service'
               AND mr.start_time < @end_time
               AND (mr.completion_time IS NULL OR mr.completion_time > @start_time)
        )
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Approval failed: space %d is under out-of-service maintenance for the requested period.', 16, 1, @space_id);
            RETURN;
        END

        /* 4. INV-1: block if another approved booking overlaps. */
        IF EXISTS (
            SELECT 1
              FROM dbo.bookings b WITH (UPDLOCK, HOLDLOCK)
             WHERE b.space_id = @space_id
               AND b.booking_id <> @booking_id
               AND b.status IN ('Approved', 'Checked In', 'Completed')
               AND b.start_time < @end_time
               AND b.end_time   > @start_time
        )
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Approval failed: space %d already has an approved booking in the requested period.', 16, 1, @space_id);
            RETURN;
        END

        /* 5. Approve the booking. */
        UPDATE dbo.bookings
           SET status = 'Approved'
         WHERE booking_id = @booking_id;

        /* 6. Record the staff approval with staff_id = @staff_id (non-NULL). */
        INSERT INTO dbo.approvals
            (booking_id, staff_id, decision_time, decision_note, rejection_reason)
        VALUES
            (@booking_id, @staff_id, SYSDATETIME(), @decision_note, NULL);

        COMMIT TRAN;

        SELECT @booking_id AS booking_id,
               'Approved'  AS status,
               @staff_id   AS staff_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   PROCEDURE 3: sp_consolidate_incident_reports
   ----------------------------------------------------------------------------
   Triage dedup: links a set of INCIDENT_REPORT rows to exactly ONE
   MAINTENANCE_RECORD. If any report is already linked, the existing
   maintenance record is reused (no duplicate maintenance). impact_level stays
   'advisory' unless the manager explicitly escalates afterwards via
   sp_set_maintenance_impact (BR-12).
   ============================================================================ */
IF OBJECT_ID('dbo.sp_consolidate_incident_reports', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_consolidate_incident_reports;
GO

CREATE PROCEDURE dbo.sp_consolidate_incident_reports
    @incident_report_ids NVARCHAR(MAX),   -- comma-separated list of report_ids
    @consolidated_by     INT,
    @maintenance_id      INT = NULL,      -- optional: reuse an existing maintenance record
    @result_status       NVARCHAR(40) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @chosen_maintenance_id INT = @maintenance_id;
    DECLARE @first_report_id INT;

    BEGIN TRY
        BEGIN TRAN;

        /* 1. Range-lock the candidate Open reports. */
        SELECT @first_report_id = MIN(report_id)
          FROM dbo.incident_reports WITH (UPDLOCK, HOLDLOCK)
         WHERE status = 'Open'
           AND CHARINDEX(',' + CAST(report_id AS NVARCHAR(20)) + ',', ',' + REPLACE(@incident_report_ids, ' ', '') + ',') > 0;

        IF @first_report_id IS NULL
        BEGIN
            /* Distinguish "reports already triaged" from "no such reports". */
            IF EXISTS (
                SELECT 1
                  FROM dbo.report_consolidations rc WITH (UPDLOCK, HOLDLOCK)
                 WHERE CHARINDEX(',' + CAST(rc.incident_report_id AS NVARCHAR(20)) + ',', ',' + REPLACE(@incident_report_ids, ' ', '') + ',') > 0
            )
                SET @result_status = N'ALREADY_CONSOLIDATED';
            ELSE
                SET @result_status = N'NO_OPEN_REPORTS';

            ROLLBACK TRAN;
            RETURN;
        END

        /* 2. Dedup: if ANY selected report is already consolidated, refuse to
              create a duplicate maintenance record. */
        IF EXISTS (
            SELECT 1
              FROM dbo.report_consolidations rc WITH (UPDLOCK, HOLDLOCK)
              JOIN dbo.incident_reports ir
                ON ir.report_id = rc.incident_report_id
             WHERE CHARINDEX(',' + CAST(ir.report_id AS NVARCHAR(20)) + ',', ',' + REPLACE(@incident_report_ids, ' ', '') + ',') > 0
               AND rc.maintenance_id IS NOT NULL
        )
        BEGIN
            SET @result_status = N'ALREADY_CONSOLIDATED';
            ROLLBACK TRAN;
            RETURN;
        END

        /* 3. If no existing maintenance record, create one with the default
              'advisory' impact level. */
        IF @chosen_maintenance_id IS NULL
        BEGIN
            DECLARE @space_id INT;
            SELECT TOP 1 @space_id = space_id
              FROM dbo.incident_reports
             WHERE report_id = @first_report_id;

            INSERT INTO dbo.maintenance_records
                (space_id, reporter_id, assigned_staff_id, problem_description,
                 start_time, completion_time, status, result_note, impact_level)
            VALUES
                (@space_id, @consolidated_by, NULL,
                 'Consolidated from incident report(s): ' + @incident_report_ids,
                 SYSDATETIME(), NULL, 'Reported', NULL, 'advisory');

            SET @chosen_maintenance_id = SCOPE_IDENTITY();
        END

        /* 4. Link each selected report to the single maintenance record. */
        INSERT INTO dbo.report_consolidations
            (incident_report_id, maintenance_id, consolidated_by, consolidated_at)
        SELECT report_id, @chosen_maintenance_id, @consolidated_by, SYSDATETIME()
          FROM dbo.incident_reports WITH (UPDLOCK)
         WHERE CHARINDEX(',' + CAST(report_id AS NVARCHAR(20)) + ',', ',' + REPLACE(@incident_report_ids, ' ', '') + ',') > 0
           AND status = 'Open';

        /* 5. Mark the reports as Consolidated. */
        UPDATE dbo.incident_reports
           SET status = 'Consolidated'
         WHERE CHARINDEX(',' + CAST(report_id AS NVARCHAR(20)) + ',', ',' + REPLACE(@incident_report_ids, ' ', '') + ',') > 0
           AND status = 'Open';

        SET @result_status = N'CONSOLIDATED';

        COMMIT TRAN;

        SELECT @chosen_maintenance_id AS maintenance_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   PROCEDURE 4: sp_set_maintenance_impact
   ----------------------------------------------------------------------------
   Exclusive triage authority to escalate/downgrade impact_level on an open
   maintenance record (BR-12). The booking probes read impact_level at COMMIT
   time, so an escalation committed here becomes visible to any later booking
   probe, guaranteeing INV-2.
   ============================================================================ */
IF OBJECT_ID('dbo.sp_set_maintenance_impact', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_set_maintenance_impact;
GO

CREATE PROCEDURE dbo.sp_set_maintenance_impact
    @maintenance_id INT,
    @impact_level   NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF @impact_level NOT IN ('advisory', 'out-of-service')
    BEGIN
        RAISERROR('Invalid impact_level %s. Allowed: advisory, out-of-service.', 16, 1, @impact_level);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        UPDATE dbo.maintenance_records
           SET impact_level = @impact_level
         WHERE maintenance_id = @maintenance_id;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRAN;
            RAISERROR('Maintenance record %d does not exist.', 16, 1, @maintenance_id);
            RETURN;
        END

        COMMIT TRAN;
        SELECT @maintenance_id AS maintenance_id, @impact_level AS impact_level;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   VERIFICATION BLOCK
   ============================================================================ */

PRINT N'Concurrency implementation applied. Verification:';

IF OBJECT_ID('dbo.sp_AutoApproveBookingRequest', 'P') IS NOT NULL
    PRINT N'  sp_AutoApproveBookingRequest        = present';
ELSE
    PRINT N'  sp_AutoApproveBookingRequest        = MISSING';

IF OBJECT_ID('dbo.sp_book_space_staff_approve', 'P') IS NOT NULL
    PRINT N'  sp_book_space_staff_approve         = present';
ELSE
    PRINT N'  sp_book_space_staff_approve         = MISSING';

IF OBJECT_ID('dbo.sp_consolidate_incident_reports', 'P') IS NOT NULL
    PRINT N'  sp_consolidate_incident_reports    = present';
ELSE
    PRINT N'  sp_consolidate_incident_reports    = MISSING';

IF OBJECT_ID('dbo.sp_set_maintenance_impact', 'P') IS NOT NULL
    PRINT N'  sp_set_maintenance_impact           = present';
ELSE
    PRINT N'  sp_set_maintenance_impact           = MISSING';
GO
