/* ============================================================================
   FILE    : 01-generate-data-G11.sql
   PURPOSE : Deterministic, SQL Server-only Phase 2 data generator.
   SCOPE   : Recreates only rows labelled GEN-* and @g11.generator.local. Phase 1
             sample data and IDX-* indexing-demo data are preserved.
   DATASET : 400 spaces, 150,000 bookings, 4,000 maintenance rows, generated
             approvals, usage sessions, incident reports, consolidations,
             facilities/assets and advisory acknowledgements.
   RUN     : sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i
             outputs/14-data-generator-G11/01-generate-data-G11.sql
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.advisory_acknowledgements', N'U') IS NULL
   OR OBJECT_ID(N'dbo.incident_reports', N'U') IS NULL
   OR COL_LENGTH(N'dbo.spaces', N'auto_booking_enabled') IS NULL
BEGIN
    THROW 51401, 'Phase 2 schema is missing. Run files 05, 06 and 10 first.', 1;
END;

DECLARE @Seed INT = 486; -- fixed seed; deterministic arithmetic below uses it.
DECLARE @StartDate DATETIME2 = '2023-01-02T00:00:00';

BEGIN TRY
    BEGIN TRAN;

    /* Delete a previous generator run in FK-safe reverse dependency order. */
    DELETE aa
      FROM dbo.advisory_acknowledgements AS aa
      JOIN dbo.bookings AS b ON b.booking_id = aa.booking_id
      JOIN dbo.spaces AS s ON s.space_id = b.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE rc
      FROM dbo.report_consolidations AS rc
      JOIN dbo.incident_reports AS ir ON ir.report_id = rc.incident_report_id
      JOIN dbo.spaces AS s ON s.space_id = ir.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE us
      FROM dbo.usage_sessions AS us
      JOIN dbo.bookings AS b ON b.booking_id = us.booking_id
      JOIN dbo.spaces AS s ON s.space_id = b.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE a
      FROM dbo.approvals AS a
      JOIN dbo.bookings AS b ON b.booking_id = a.booking_id
      JOIN dbo.spaces AS s ON s.space_id = b.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE ir
      FROM dbo.incident_reports AS ir
      JOIN dbo.spaces AS s ON s.space_id = ir.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE b
      FROM dbo.bookings AS b
      JOIN dbo.spaces AS s ON s.space_id = b.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE m
      FROM dbo.maintenance_records AS m
      JOIN dbo.spaces AS s ON s.space_id = m.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE fa
      FROM dbo.facility_assets AS fa
      JOIN dbo.spaces AS s ON s.space_id = fa.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE sf
      FROM dbo.space_facility AS sf
      JOIN dbo.spaces AS s ON s.space_id = sf.space_id
     WHERE s.space_code LIKE N'GEN-%';

    DELETE FROM dbo.spaces WHERE space_code LIKE N'GEN-%';
    DELETE FROM dbo.users WHERE email IN (N'generator.user@g11.generator.local',
                                          N'generator.staff@g11.generator.local');

    INSERT INTO dbo.users
        (full_name, email, phone_number, role, department, account_status)
    VALUES
        (N'G11 Generator User', N'generator.user@g11.generator.local',
         N'0900000486', N'Lecturer', N'Computer Science', N'Active'),
        (N'G11 Generator Staff', N'generator.staff@g11.generator.local',
         N'0900000487', N'Facility Staff', N'Computer Science', N'Active');

    DECLARE @UserID INT = (SELECT user_id FROM dbo.users
                            WHERE email = N'generator.user@g11.generator.local');
    DECLARE @StaffID INT = (SELECT user_id FROM dbo.users
                             WHERE email = N'generator.staff@g11.generator.local');

    IF NOT EXISTS (SELECT 1 FROM dbo.facility_catalog WHERE facility_name = N'Projector')
        INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES (N'Projector', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.facility_catalog WHERE facility_name = N'Air Conditioner Unit')
        INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES (N'Air Conditioner Unit', 0);

    DECLARE @ProjectorID INT = (SELECT MIN(catalog_id) FROM dbo.facility_catalog WHERE facility_name = N'Projector');
    DECLARE @AirConditionerID INT = (SELECT MIN(catalog_id) FROM dbo.facility_catalog WHERE facility_name = N'Air Conditioner Unit');

    ;WITH e1(n) AS (
        SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)
    ), e2(n) AS (
        SELECT a.n * 10 + b.n FROM e1 AS a CROSS JOIN e1 AS b
    ), e4(n) AS (
        SELECT a.n * 100 + b.n FROM e2 AS a CROSS JOIN e2 AS b
    ), n AS (
        SELECT TOP (400) ROW_NUMBER() OVER (ORDER BY e4.n) AS n
        FROM e4
    )
    INSERT INTO dbo.spaces
        (space_code, space_name, space_type, building, floor, room_number,
         capacity, current_status, usage_policy, auto_booking_enabled)
    SELECT N'GEN-' + RIGHT(N'0000' + CONVERT(NVARCHAR(10), n), 4),
           N'Generated Space ' + CONVERT(NVARCHAR(10), n),
           CASE n % 6 WHEN 0 THEN N'Auditorium' WHEN 1 THEN N'Classroom'
                      WHEN 2 THEN N'Computer Laboratory' WHEN 3 THEN N'Project Laboratory'
                      WHEN 4 THEN N'Meeting Room' ELSE N'Student Workspace' END,
           N'Generator Building', ((n - 1) % 8) + 1, CONVERT(NVARCHAR(20), 2000 + n),
           30 + ((n - 1) % 8) * 20, N'Available',
           N'Deterministic SQL Server generator (seed 486)', CASE WHEN n % 2 = 0 THEN 1 ELSE 0 END
    FROM n;

    /* Projector quantity starts at zero so the Phase 1 asset trigger is valid
       before the physical assets are inserted. */
    INSERT INTO dbo.space_facility (space_id, catalog_id, quantity)
    SELECT s.space_id, v.catalog_id, v.quantity
    FROM dbo.spaces AS s
    CROSS APPLY (VALUES (@ProjectorID, 0), (@AirConditionerID, 2)) AS v(catalog_id, quantity)
    WHERE s.space_code LIKE N'GEN-%';

    INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status, space_facility_id)
    SELECT N'GEN-PROJ-' + RIGHT(N'0000' + CONVERT(NVARCHAR(10), s.space_id), 4),
           s.space_id, @ProjectorID, N'Operational', sf.space_facility_id
    FROM dbo.spaces AS s
    JOIN dbo.space_facility AS sf ON sf.space_id = s.space_id AND sf.catalog_id = @ProjectorID
    WHERE s.space_code LIKE N'GEN-%';

    /* Now that every projector instance has one asset, expose quantity = 1. */
    UPDATE sf SET quantity = 1
    FROM dbo.space_facility AS sf
    JOIN dbo.spaces AS s ON s.space_id = sf.space_id
    WHERE s.space_code LIKE N'GEN-%' AND sf.catalog_id = @ProjectorID;

    ;WITH GenSpaces AS (
        SELECT s.space_id, ROW_NUMBER() OVER (ORDER BY s.space_code) AS rn
        FROM dbo.spaces AS s WHERE s.space_code LIKE N'GEN-%'
    )
    INSERT INTO dbo.maintenance_records
        (space_id, reporter_id, assigned_staff_id, problem_description,
         start_time, completion_time, status, result_note, impact_level)
    SELECT gs.space_id, @UserID, @StaffID, N'GEN out-of-service maintenance',
           '2024-06-04T10:00:00', '2024-06-04T14:00:00', N'Completed',
           N'Generator fixture', N'out-of-service'
    FROM GenSpaces AS gs WHERE gs.rn <= 50;

    ;WITH e1(n) AS (
        SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)
    ), e2(n) AS (
        SELECT a.n * 10 + b.n FROM e1 AS a CROSS JOIN e1 AS b
    ), e4(n) AS (
        SELECT a.n * 100 + b.n FROM e2 AS a CROSS JOIN e2 AS b
    ), n AS (
        SELECT TOP (3950) ROW_NUMBER() OVER (ORDER BY e4.n) AS n
        FROM e4
    ), GenSpaces AS (
        SELECT s.space_id, ROW_NUMBER() OVER (ORDER BY s.space_code) AS rn
        FROM dbo.spaces AS s WHERE s.space_code LIKE N'GEN-%'
    )
    INSERT INTO dbo.maintenance_records
        (space_id, reporter_id, assigned_staff_id, problem_description,
         start_time, completion_time, status, result_note, impact_level)
    SELECT gs.space_id, @UserID, @StaffID, N'GEN advisory maintenance ' + CONVERT(NVARCHAR(20), n.n),
           DATEADD(HOUR, 8, DATEADD(DAY, (n.n * 11 + @Seed) % 1090, @StartDate)),
           DATEADD(HOUR, 12, DATEADD(DAY, (n.n * 11 + @Seed) % 1090, @StartDate)),
           N'Completed', N'Generator fixture', N'advisory'
    FROM n JOIN GenSpaces AS gs ON gs.rn = ((n.n - 1) % 400) + 1;

    ;WITH e1(n) AS (
        SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)
    ), e2(n) AS (
        SELECT a.n * 10 + b.n FROM e1 AS a CROSS JOIN e1 AS b
    ), e4(n) AS (
        SELECT a.n * 100 + b.n FROM e2 AS a CROSS JOIN e2 AS b
    ),
    Numbers AS (
        SELECT TOP (150000) ROW_NUMBER() OVER (ORDER BY a.n, b.n) AS n
        FROM e4 AS a CROSS JOIN e2 AS b
    ), GenSpaces AS (
        SELECT s.space_id, ROW_NUMBER() OVER (ORDER BY s.space_code) AS rn
        FROM dbo.spaces AS s WHERE s.space_code LIKE N'GEN-%'
    ), Shape AS (
        SELECT n, ((n - 1) % 400) + 1 AS space_rn,
               ((n - 1) / 400) / 5 AS day_sequence, ((n - 1) / 400) % 5 AS slot_sequence
        FROM Numbers
    )
    INSERT INTO dbo.bookings
        (user_id, space_id, start_time, end_time, purpose, expected_participants, status,
         advisory_acknowledged, advisory_snapshot)
    SELECT @UserID, gs.space_id,
           DATEADD(HOUR, CASE sh.slot_sequence WHEN 0 THEN 8 WHEN 1 THEN 10 WHEN 2 THEN 13 WHEN 3 THEN 15 ELSE 17 END,
                   DATEADD(DAY, sh.day_sequence * 15, @StartDate)),
           DATEADD(HOUR, CASE sh.slot_sequence WHEN 0 THEN 10 WHEN 1 THEN 12 WHEN 2 THEN 15 WHEN 3 THEN 17 ELSE 19 END,
                   DATEADD(DAY, sh.day_sequence * 15, @StartDate)),
           CASE sh.n % 7 WHEN 0 THEN N'Lecture' WHEN 1 THEN N'Examination' WHEN 2 THEN N'Seminar'
                           WHEN 3 THEN N'Workshop' WHEN 4 THEN N'Meeting' WHEN 5 THEN N'Student Activity'
                           ELSE N'Administrative Event' END,
           20,
           CASE sh.n % 10 WHEN 0 THEN N'Approved' WHEN 1 THEN N'Approved' WHEN 2 THEN N'Approved'
                            WHEN 3 THEN N'Approved' WHEN 4 THEN N'Checked In' WHEN 5 THEN N'Completed'
                            WHEN 6 THEN N'No-show' WHEN 7 THEN N'Pending' WHEN 8 THEN N'Rejected' ELSE N'Cancelled' END,
           0, NULL
    FROM Shape AS sh JOIN GenSpaces AS gs ON gs.rn = sh.space_rn;

    UPDATE b SET advisory_acknowledged = 1,
                 advisory_snapshot = N'GEN advisory maintenance was shown and acknowledged.'
    FROM dbo.bookings AS b
    JOIN dbo.spaces AS s ON s.space_id = b.space_id
    WHERE s.space_code LIKE N'GEN-%'
      AND EXISTS (SELECT 1 FROM dbo.maintenance_records AS m
                  WHERE m.space_id = b.space_id AND m.impact_level = N'advisory'
                    AND b.start_time < COALESCE(m.completion_time, '9999-12-31T23:59:59')
                    AND b.end_time > m.start_time);

    INSERT INTO dbo.advisory_acknowledgements
        (booking_id, maintenance_id, acknowledged_by, acknowledged_at)
    SELECT b.booking_id, m.maintenance_id, @UserID, b.start_time
    FROM dbo.bookings AS b
    JOIN dbo.spaces AS s ON s.space_id = b.space_id
    JOIN dbo.maintenance_records AS m ON m.space_id = b.space_id AND m.impact_level = N'advisory'
    WHERE s.space_code LIKE N'GEN-%'
      AND b.start_time < COALESCE(m.completion_time, '9999-12-31T23:59:59')
      AND b.end_time > m.start_time;

    INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
    SELECT b.booking_id, CASE WHEN b.status = N'Approved' AND b.booking_id % 2 = 0 THEN NULL ELSE @StaffID END,
           b.start_time, N'Generated approval record',
           CASE WHEN b.status = N'Rejected' THEN N'Generated scheduling decision.' ELSE NULL END
    FROM dbo.bookings AS b JOIN dbo.spaces AS s ON s.space_id = b.space_id
    WHERE s.space_code LIKE N'GEN-%'
      AND b.status IN (N'Approved', N'Checked In', N'Completed', N'Rejected');

    INSERT INTO dbo.usage_sessions
        (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
    SELECT b.booking_id, @StaffID, b.start_time, b.end_time, N'Good', N'Good', N'Generated usage history'
    FROM dbo.bookings AS b JOIN dbo.spaces AS s ON s.space_id = b.space_id
    WHERE s.space_code LIKE N'GEN-%' AND b.status IN (N'Checked In', N'Completed');

    ;WITH GenSpaces AS (
        SELECT s.space_id, ROW_NUMBER() OVER (ORDER BY s.space_code) AS rn
        FROM dbo.spaces AS s WHERE s.space_code LIKE N'GEN-%'
    )
    INSERT INTO dbo.incident_reports
        (user_id, space_id, space_facility_id, asset_id, description, reported_at, status)
    SELECT @UserID, gs.space_id,
           CASE WHEN gs.rn % 3 = 0 THEN fa.space_facility_id WHEN gs.rn % 3 = 1 THEN sf.space_facility_id ELSE NULL END,
           CASE WHEN gs.rn % 3 = 0 THEN fa.asset_id ELSE NULL END,
           N'GEN incident report ' + CONVERT(NVARCHAR(10), gs.rn),
           DATEADD(DAY, gs.rn, @StartDate), CASE WHEN gs.rn <= 200 THEN N'Open' ELSE N'Closed' END
    FROM GenSpaces AS gs
    JOIN dbo.space_facility AS sf ON sf.space_id = gs.space_id AND sf.catalog_id = @ProjectorID
    JOIN dbo.facility_assets AS fa ON fa.space_id = gs.space_id AND fa.catalog_id = @ProjectorID;

    ;WITH Targets AS (
        SELECT TOP (200) ir.report_id, ir.space_id
        FROM dbo.incident_reports AS ir
        WHERE ir.description LIKE N'GEN incident report %' AND ir.status = N'Open'
        ORDER BY ir.report_id
    )
    INSERT INTO dbo.report_consolidations
        (incident_report_id, maintenance_id, consolidated_by, consolidated_at)
    SELECT t.report_id, m.maintenance_id, @StaffID, DATEADD(MINUTE, t.report_id, @StartDate)
    FROM Targets AS t
    CROSS APPLY (SELECT MIN(maintenance_id) AS maintenance_id
                 FROM dbo.maintenance_records WHERE space_id = t.space_id) AS m;

    UPDATE ir SET status = N'Consolidated'
    FROM dbo.incident_reports AS ir
    WHERE EXISTS (SELECT 1 FROM dbo.report_consolidations AS rc
                  WHERE rc.incident_report_id = ir.report_id);

    IF (SELECT COUNT_BIG(*) FROM dbo.bookings AS b JOIN dbo.spaces AS s ON s.space_id = b.space_id WHERE s.space_code LIKE N'GEN-%') <> 150000
        THROW 51402, 'Generator verification failed: expected 150,000 GEN bookings.', 1;
    IF EXISTS (SELECT 1 FROM dbo.bookings AS a JOIN dbo.bookings AS b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
               JOIN dbo.spaces AS s ON s.space_id = a.space_id
               WHERE s.space_code LIKE N'GEN-%' AND a.start_time < b.end_time AND b.start_time < a.end_time)
        THROW 51403, 'Generator verification failed: overlapping GEN bookings.', 1;
    IF EXISTS (SELECT 1 FROM dbo.bookings AS b JOIN dbo.maintenance_records AS m ON m.space_id = b.space_id
               JOIN dbo.spaces AS s ON s.space_id = b.space_id
               WHERE s.space_code LIKE N'GEN-%' AND b.status IN (N'Approved',N'Checked In',N'Completed')
                 AND m.impact_level = N'out-of-service' AND b.start_time < COALESCE(m.completion_time, '9999-12-31T23:59:59') AND b.end_time > m.start_time)
        THROW 51404, 'Generator verification failed: committed GEN booking overlaps OOS maintenance.', 1;

    COMMIT TRAN;
    PRINT N'G11 SQL-ONLY DATA GENERATOR: PASS (150,000 GEN bookings created).';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO
