/*
===============================================================================
  16-analytical-queries-G11.sql
  Campus Space Management System - Phase 2 Analytical Queries
  Group: G11
===============================================================================
  Implements the four Phase 2 reporting requirements RC-07 .. RC-10
  (see outputs/08-requirement-change-analysis-G11.md):

    Q1  Approved booking hours by space for a semester            (RC-07)
    Q2  Approved bookings by weekday and hour for a semester  (RC-08)
    Q3  Room finder (capacity + required facilities + time)   (RC-09)
    Q4  Bookings affected by maintenance escalation           (RC-10)

  Shared rules reused throughout (outputs/09, 10, 11, 12):
    * Approved-like statuses that occupy a space:
          'Approved', 'Checked In', 'Completed'
      (matches LOCKED_STATUSES in the data generator and the concurrency
       guard in outputs/12-concurrency-implementation-G11.sql)
    * Overlap condition (never BETWEEN):
          existing_start < requested_end
      AND existing_end > requested_start
    * Semester boundaries (half-open):
          value >= semester_start
      AND value <  semester_end

  Each query is an independent batch (separated by GO) and declares all of its
  own variables / table variables, so no query depends on state from another.

  Predicates are SARGable against the indexes created in
  outputs/10-schema-migration-G11.sql and analysed in
  outputs/15-index-tuning-report-G11.md:
    IX_bookings_space_time           (space_id, start_time, end_time) INCLUDE (status)
    IX_bookings_status_time          (status, start_time, end_time)   INCLUDE (space_id)
    IX_maintenance_records_space_time (space_id, start_time, completion_time)
                                     INCLUDE (impact_level, status)
    IX_spaces_capacity_status        (capacity, current_status) INCLUDE (space_type, space_name)

   Reporting window used by Q1/Q2 below (covers the deterministic GEN-* data):
    SEMESTER_START = 2025-09-01 00:00   SEMESTER_END = 2026-02-01 00:00
===============================================================================
*/

USE [CampusSpaceManagement];
GO

-- ============================================================================
-- QUERY 1 — Approved booking hours by space for a given semester   (RC-07)
-- ============================================================================
/*
   BUSINESS QUESTION
   For a given semester, how many approved bookings does each space have and
   how many total approved booking hours do they occupy?

   TARGET USER
   Facility Manager (semester-end utilization reporting).

   INPUT PARAMETERS
     @SemStart  DATETIME2  first instant of the semester
     @SemEnd    DATETIME2  first instant AFTER the semester (half-open window)

   SQL STATEMENT
   Counts / sums bookings whose START falls inside the semester window and
   whose status represents approved occupancy. A LEFT JOIN from `spaces`
   guarantees that spaces with zero approved hours still appear (count 0,
   hours 0).

   ASSUMPTIONS
     * "Approved occupancy" = status IN ('Approved','Checked In','Completed').
     * A booking is attributed to the semester in which it STARTS
       (start_time >= @SemStart AND start_time < @SemEnd). Bookings that begin
       before the semester start or on/after the semester end are excluded.
     * Hours = SUM(end_time - start_time) in minutes / 60 (fractional allowed).

   TEST EXECUTION EXAMPLE
     EXEC the batch below unchanged: it uses the final generated semester
     2025-09-01 .. 2026-02-01 against the Phase 14 dataset.
     To run for another semester, change only @SemStart / @SemEnd.

   EXPECTED-RESULT EXPLANATION
     Every space in dbo.spaces appears exactly once. Spaces with approved
     bookings in the window show a positive count and hours; a space with none
     shows 0 / 0.0. Spaces are ordered by total approved hours descending so
     the most-used spaces appear first.
*/
DECLARE @SemStart DATETIME2 = '2025-09-01T00:00:00';
DECLARE @SemEnd   DATETIME2 = '2026-02-01T00:00:00';

SELECT s.space_id,
       s.space_code,
       s.space_name,
       COUNT(b.booking_id)                                                AS approved_booking_count,
       ISNULL(SUM(DATEDIFF(MINUTE, b.start_time, b.end_time)) / 60.0, 0)  AS total_approved_hours
FROM dbo.spaces AS s
LEFT JOIN dbo.bookings AS b
       ON b.space_id = s.space_id
      AND b.status IN ('Approved', 'Checked In', 'Completed')
      AND b.start_time >= @SemStart
      AND b.start_time <  @SemEnd
GROUP BY s.space_id, s.space_code, s.space_name
ORDER BY total_approved_hours DESC, s.space_code;
GO

-- ============================================================================
-- QUERY 2 — Approved bookings by weekday and hour for a semester   (RC-08)
-- ============================================================================
/*
   BUSINESS QUESTION
   During a given semester, which (weekday, hour) combinations carry the most
   approved bookings? Used to decide when the highest room demand occurs.

   TARGET USER
   Facility Manager (capacity planning / demand distribution analysis).

   INPUT PARAMETERS
     @SemStart  DATETIME2  first instant of the semester
     @SemEnd    DATETIME2  first instant AFTER the semester (half-open window)

   SQL STATEMENT
   Groups approved-like bookings by the weekday and the clock hour of their
   START time. Weekday number is computed with a @@DATEFIRST-independent
   formula so the result is a STABLE Monday=1 .. Sunday=7 order regardless of
   the server's DATEFIRST / language setting; the weekday NAME is derived from
   that number to avoid language-dependent DATENAME output.

   ASSUMPTIONS
     * "Approved occupancy" = status IN ('Approved','Checked In','Completed').
     * Grouping is based on the booking START time (documented per skill
       rule). A booking that spans midnight counts once, on its start day/hour.
     * Weekday number mapping: Monday=1, Tuesday=2, ..., Sunday=7.
     * Same semester window semantics as Query 1.

   TEST EXECUTION EXAMPLE
     Run the batch below unchanged against the generated dataset
     (semester 2025-09-01 .. 2026-02-01).

   EXPECTED-RESULT EXPLANATION
     One row per distinct (weekday, hour). The result is ordered Monday→Sunday
     and within a day by hour (8..17 given the seeded working hours), so the
     busiest demand slots are immediately readable. `approved_booking_count`
     is the number of approved-like bookings starting in that slot.
*/
DECLARE @SemStart DATETIME2 = '2025-09-01T00:00:00';
DECLARE @SemEnd   DATETIME2 = '2026-02-01T00:00:00';

WITH approved AS (
    SELECT b.start_time,
           ((@@DATEFIRST + DATEPART(WEEKDAY, b.start_time) - 2) % 7) + 1 AS weekday_number,
           DATEPART(HOUR, b.start_time)                                  AS hour_of_day
    FROM dbo.bookings AS b
    WHERE b.status IN ('Approved', 'Checked In', 'Completed')
      AND b.start_time >= @SemStart
      AND b.start_time <  @SemEnd
)
SELECT weekday_number,
       CASE weekday_number
           WHEN 1 THEN 'Monday'
           WHEN 2 THEN 'Tuesday'
           WHEN 3 THEN 'Wednesday'
           WHEN 4 THEN 'Thursday'
           WHEN 5 THEN 'Friday'
           WHEN 6 THEN 'Saturday'
           ELSE 'Sunday'
       END                AS weekday_name,
       hour_of_day,
       COUNT(*)           AS approved_booking_count
FROM approved
GROUP BY weekday_number, hour_of_day
ORDER BY weekday_number, hour_of_day;
GO

-- ============================================================================
-- QUERY 3 — Room finder (capacity + required facilities + free window) (RC-09)
-- ============================================================================
/*
   BUSINESS QUESTION
   A requester wants a bookable space, for a given start/end window, with at
   least a given capacity and every facility on a required list. Which spaces
   can be recommended right now?

   TARGET USER
   Students / Lecturers / Staff searching for a room; the instant-booking UI.

   INPUT PARAMETERS
     @ReqStart             DATETIME2   requested start
     @ReqEnd               DATETIME2   requested end
     @MinCapacity          INT         minimum capacity
     @RequiredFacilities   TABLE(catalog_id INT)  required facility list;
                                           EMPTY list => no facility constraint
   (The table variable must be populated in the same batch as the query.)

   SQL STATEMENT
   Returns each qualifying space exactly once (NOT EXISTS anti-semi-joins do not
   multiply rows). A space qualifies when it is:
     1. bookable (broad operational status NOT IN ('Temporarily Closed',
        'Retired'); 'Under Maintenance' no longer exists in this domain and
        maintenance blocking is handled by rule 5),
     2. large enough (capacity >= @MinCapacity),
     3. equipped with EVERY requested facility (double-NOT EXISTS over the
        required list; trivially true when the list is empty),
     4. free of any overlapping approved-like booking (BR-01),
     5. free of any overlapping OUT-OF-SERVICE maintenance (BR-02 refined by
        C1). Advisory maintenance does NOT block the space.

   ASSUMPTIONS
     * Open maintenance (completion_time IS NULL) is treated as still active,
       i.e. it blocks any window that starts after its start_time.
     * A maintenance record whose completion_time is set does not block a
       window that starts on/after that completion_time (partial overlap uses
       the half-open interval semantics of the overlap rule).
     * Approved-like statuses = 'Approved','Checked In','Completed'.
     * Capacity is an exact-fit rule: capacity >= requested minimum.

   TEST EXECUTION EXAMPLE
     The batch below searches for spaces of capacity >= 170 that are free
     2024-06-04 11:00..12:00 and have Projector plus Air Conditioner Unit.
     Their catalog IDs are resolved by name because identity values are data,
     not stable business identifiers. Remove the INSERT (leave the table
     variable empty) to test the empty-facility-list case.

   EXPECTED-RESULT EXPLANATION
     Only spaces satisfying every one of the five conditions are returned,
     ordered by capacity descending (best fit first). A space is excluded if
     it fails ANY single check: capacity, status, missing facility,
     overlapping approved booking, or overlapping out-of-service maintenance.
     No duplicate space appears even when it has multiple maintenance records
     or multiple overlapping bookings, because the anti-semi-joins only test
     for EXISTENCE.
*/
DECLARE @ReqStart    DATETIME2 = '2024-06-04T11:00:00';
DECLARE @ReqEnd      DATETIME2 = '2024-06-04T12:00:00';
DECLARE @MinCapacity INT       = 170;

DECLARE @RequiredFacilities TABLE (catalog_id INT NOT NULL PRIMARY KEY);
DECLARE @ProjectorCatalogID INT = (
    SELECT MIN(catalog_id)
    FROM dbo.facility_catalog
    WHERE facility_name = N'Projector'
);
DECLARE @AirConditionerCatalogID INT = (
    SELECT MIN(catalog_id)
    FROM dbo.facility_catalog
    WHERE facility_name = N'Air Conditioner Unit'
);

IF @ProjectorCatalogID IS NULL OR @AirConditionerCatalogID IS NULL
    THROW 51060, 'Room Finder setup failed: required facility catalog rows are missing.', 1;

INSERT INTO @RequiredFacilities (catalog_id)
VALUES (@ProjectorCatalogID), (@AirConditionerCatalogID);

SELECT DISTINCT s.space_id,
                s.space_code,
                s.space_name,
                s.space_type,
                s.building,
                s.floor,
                s.room_number,
                s.capacity,
                s.current_status
FROM dbo.spaces AS s
WHERE s.capacity >= @MinCapacity
  AND s.current_status NOT IN ('Temporarily Closed', 'Retired')
  -- no overlapping approved-like booking (BR-01)
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.bookings AS b
      WHERE b.space_id = s.space_id
        AND b.status IN ('Approved', 'Checked In', 'Completed')
        AND b.start_time < @ReqEnd
        AND b.end_time   > @ReqStart
  )
  -- no overlapping OUT-OF-SERVICE maintenance (BR-02 / RC-01); advisory is OK
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.maintenance_records AS m
      WHERE m.space_id = s.space_id
        AND m.impact_level = 'out-of-service'
        AND (m.completion_time IS NULL OR m.completion_time > @ReqStart)
        AND m.start_time < @ReqEnd
  )
  -- every required facility present (empty list passes all spaces)
  AND NOT EXISTS (
      SELECT 1
      FROM @RequiredFacilities AS rf
      WHERE NOT EXISTS (
          SELECT 1
          FROM dbo.space_facility AS sf
          WHERE sf.space_id = s.space_id
            AND sf.catalog_id = rf.catalog_id
      )
  )
ORDER BY s.capacity DESC, s.space_code;
GO

-- ============================================================================
-- QUERY 4 — Approved bookings affected by maintenance escalation   (RC-10)
-- ============================================================================
/*
   BUSINESS QUESTION
   When a maintenance record is escalated to 'out-of-service' (RC-04 /
   BR-P2-02), which already-approved bookings on the same space overlap its
   maintenance period and must be flagged so staff can contact the requesters?

   TARGET USER
   Facility Staff / Facility Manager (escalation follow-up, OQ-P2-05: contact
   requesters, do not auto-cancel).

   INPUT PARAMETERS
     @MaintenanceID  INT   the maintenance record that is / was escalated

   SQL STATEMENT
   Returns approved-like bookings on the maintenance record's space whose time
   window overlaps the maintenance period. An open maintenance record
   (completion_time IS NULL) is treated as unbounded: any booking that starts
   after the maintenance start_time overlaps it (sentinel +100 years). The
   requester's contact details (name, email, phone, department) are included
   for staff to reach out.

   ASSUMPTIONS
     * Approved-like statuses = 'Approved','Checked In','Completed'.
     * A booking is affected if its window OVERLAPS the maintenance period
       (strict half-open overlap rule); adjacent (touching) periods are NOT
       affected.
     * The query is typically executed right after the escalation UPDATE in
        dbo.sp_set_maintenance_impact (outputs/12), and returns the same
        affected set that procedure reports, plus full contact information.
     * "Affected after escalation to out-of-service" is driven by the
       maintenance period, not by the booking status history.

   TEST EXECUTION EXAMPLE
     The batch below creates an advisory maintenance record around a real
     generated approved booking, escalates it through the production procedure,
     lists the affected booking, then rolls the demo transaction back. The
     database is therefore unchanged after the example.

   EXPECTED-RESULT EXPLANATION
     Every returned booking is (a) on the same space as the maintenance record,
     (b) approved-like, and (c) overlapping the maintenance period. Together
     with the requester contact columns, this is exactly the contact list staff
     needs when an escalation makes a previously-bookable space unavailable.
     A booking on a DIFFERENT space, or one that only touches the maintenance
     window at a boundary, is not returned.
*/
DECLARE @MaintenanceID INT;
DECLARE @DemoSpaceID INT;
DECLARE @ReporterID INT;
DECLARE @DemoStart DATETIME2;
DECLARE @DemoEnd DATETIME2;

SELECT TOP (1)
       @DemoSpaceID=b.space_id,
       @ReporterID=b.user_id,
       @DemoStart=DATEADD(MINUTE,15,b.start_time),
       @DemoEnd=DATEADD(MINUTE,-15,b.end_time)
FROM dbo.bookings AS b
JOIN dbo.spaces AS s ON s.space_id=b.space_id
WHERE s.space_code LIKE N'GEN-%'
  AND b.status IN ('Approved','Checked In','Completed')
ORDER BY b.booking_id;

IF @DemoSpaceID IS NULL
    THROW 51061,'Affected-booking demo requires at least one generated approved-like booking.',1;

BEGIN TRY
    BEGIN TRAN;

    INSERT dbo.maintenance_records
        (space_id,reporter_id,assigned_staff_id,problem_description,
         start_time,completion_time,status,result_note,impact_level)
    VALUES
        (@DemoSpaceID,@ReporterID,NULL,N'Transaction-scoped escalation demo',
         @DemoStart,@DemoEnd,N'Open',NULL,N'advisory');

    SET @MaintenanceID=SCOPE_IDENTITY();
    EXEC dbo.sp_set_maintenance_impact @MaintenanceID,N'out-of-service';

SELECT b.booking_id,
       b.space_id,
       s.space_code,
       b.start_time,
       b.end_time,
       b.status,
       u.full_name    AS requester_name,
       u.email        AS requester_email,
       u.phone_number AS requester_phone,
       u.department,
       m.problem_description,
       m.impact_level
FROM dbo.maintenance_records AS m
INNER JOIN dbo.bookings AS b ON b.space_id = m.space_id
INNER JOIN dbo.users    AS u ON u.user_id  = b.user_id
INNER JOIN dbo.spaces   AS s ON s.space_id = b.space_id
WHERE m.maintenance_id = @MaintenanceID
  AND b.status IN ('Approved', 'Checked In', 'Completed')
  AND b.start_time < COALESCE(m.completion_time, DATEADD(YEAR, 100, m.start_time))
  AND b.end_time   > m.start_time
ORDER BY b.start_time;

    ROLLBACK TRAN;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO

-- ============================================================================
-- VALIDATION CASES (self-contained batches; each declares its own variables)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- V1. Semester boundaries: booking at exactly @SemStart is included; a booking
--     starting exactly at @SemEnd is excluded (half-open [start, end)).
-- ----------------------------------------------------------------------------
DECLARE @SemStart DATETIME2 = '2026-03-02T08:00:00';
DECLARE @SemEnd   DATETIME2 = '2026-06-30T18:00:00';

DECLARE @Bookings TABLE (
    booking_id INT PRIMARY KEY,
    start_time DATETIME2 NOT NULL,
    end_time   DATETIME2 NOT NULL,
    status     NVARCHAR(20) NOT NULL
);
INSERT INTO @Bookings VALUES
    (1, @SemStart, DATEADD(HOUR, 1, @SemStart), 'Approved'),                                   -- start == semester start -> IN
    (2, @SemEnd,   DATEADD(HOUR, 1, @SemEnd),   'Approved'),                                   -- start == semester end   -> OUT
    (3, DATEADD(DAY, 1, @SemStart), DATEADD(DAY, 1, DATEADD(HOUR, 1, @SemStart)), 'Approved'); -- strictly inside         -> IN

SELECT COUNT(*) AS counted_within_semester
FROM @Bookings
WHERE status IN ('Approved', 'Checked In', 'Completed')
  AND start_time >= @SemStart
  AND start_time <  @SemEnd;
-- Expected: 2 (bookings 1 and 3; booking 2 excluded by the half-open rule)
GO

-- ----------------------------------------------------------------------------
-- V2. Cancelled and rejected bookings are NOT approved occupancy and must not
--     be counted by Q1/Q2 or block a space in Q3.
-- ----------------------------------------------------------------------------
DECLARE @Bookings TABLE (
    booking_id INT PRIMARY KEY,
    start_time DATETIME2 NOT NULL,
    end_time   DATETIME2 NOT NULL,
    status     NVARCHAR(20) NOT NULL
);
INSERT INTO @Bookings VALUES
    (1, '2026-02-10T09:00:00', '2026-02-10T10:00:00', 'Cancelled'),
    (2, '2026-02-10T10:00:00', '2026-02-10T11:00:00', 'Rejected'),
    (3, '2026-02-10T11:00:00', '2026-02-10T12:00:00', 'Pending'),
    (4, '2026-02-10T12:00:00', '2026-02-10T13:00:00', 'Approved');

SELECT COUNT(*) AS approved_like_count
FROM @Bookings
WHERE status IN ('Approved', 'Checked In', 'Completed');
-- Expected: 1 (only booking 4)
GO

-- ----------------------------------------------------------------------------
-- V3. Adjacent non-overlapping periods: a booking that ends exactly when the
--     requested window starts (and vice versa) does NOT overlap.
-- ----------------------------------------------------------------------------
DECLARE @WinStart DATETIME2 = '2026-02-10T11:00:00';
DECLARE @WinEnd   DATETIME2 = '2026-02-10T12:00:00';
DECLARE @Bookings TABLE (
    booking_id INT PRIMARY KEY,
    start_time DATETIME2 NOT NULL,
    end_time   DATETIME2 NOT NULL,
    status     NVARCHAR(20) NOT NULL
);
INSERT INTO @Bookings VALUES
    (1, '2026-02-10T10:00:00', '2026-02-10T11:00:00', 'Approved'),  -- ends exactly at @WinStart
    (2, '2026-02-10T12:00:00', '2026-02-10T13:00:00', 'Approved');  -- starts exactly at @WinEnd

SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM @Bookings
    WHERE status IN ('Approved', 'Checked In', 'Completed')
      AND start_time < @WinEnd
      AND end_time   > @WinStart
) THEN 'OVERLAP' ELSE 'NO-OVERLAP' END AS result;
-- Expected: NO-OVERLAP
GO

-- ----------------------------------------------------------------------------
-- V4. Empty required-facility list: every otherwise-valid space passes the
--     facility check (the double-NOT EXISTS is true over an empty list).
-- ----------------------------------------------------------------------------
DECLARE @RequiredFacilities TABLE (catalog_id INT NOT NULL PRIMARY KEY);  -- empty list

SELECT COUNT(*) AS spaces_passing_empty_facility_list
FROM dbo.spaces AS s
WHERE s.current_status NOT IN ('Temporarily Closed', 'Retired')
  AND NOT EXISTS (
      SELECT 1
      FROM @RequiredFacilities AS rf
      WHERE NOT EXISTS (
          SELECT 1
          FROM dbo.space_facility AS sf
          WHERE sf.space_id = s.space_id
            AND sf.catalog_id = rf.catalog_id
      )
  );
-- Expected: equals the number of non-blocked spaces in dbo.spaces
GO

-- ----------------------------------------------------------------------------
-- V5. A room missing ONE required facility is excluded; a room with all of
--     them is included.
-- ----------------------------------------------------------------------------
DECLARE @RequiredFacilities TABLE (catalog_id INT NOT NULL PRIMARY KEY);
INSERT INTO @RequiredFacilities (catalog_id) VALUES (1), (2);  -- requires Projector AND Whiteboard

DECLARE @Spaces TABLE (space_id INT PRIMARY KEY);
DECLARE @SpaceFacility TABLE (space_id INT NOT NULL, catalog_id INT NOT NULL);
INSERT INTO @Spaces VALUES (100), (101);
INSERT INTO @SpaceFacility VALUES (100, 1), (101, 1), (101, 2);  -- 100 lacks facility 2

SELECT s.space_id
FROM @Spaces AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM @RequiredFacilities AS rf
    WHERE NOT EXISTS (
        SELECT 1
        FROM @SpaceFacility AS sf
        WHERE sf.space_id = s.space_id
          AND sf.catalog_id = rf.catalog_id
    )
);
-- Expected: only 101 (100 is missing facility 2)
GO

-- ----------------------------------------------------------------------------
-- V6. Advisory maintenance does NOT block a space; out-of-service maintenance
--     DOES block it (BR-02 refined by RC-01).
-- ----------------------------------------------------------------------------
DECLARE @WinStart DATETIME2 = '2026-02-10T10:00:00';
DECLARE @WinEnd   DATETIME2 = '2026-02-10T12:00:00';
DECLARE @Maint TABLE (
    space_id       INT NOT NULL,
    impact_level   NVARCHAR(20) NOT NULL,
    start_time     DATETIME2 NOT NULL,
    completion_time DATETIME2 NULL
);
INSERT INTO @Maint VALUES
    (100, 'advisory',       '2026-02-10T08:00:00', '2026-02-10T18:00:00'),
    (101, 'out-of-service', '2026-02-10T08:00:00', '2026-02-10T18:00:00');

SELECT m.space_id,
       m.impact_level,
       CASE WHEN m.impact_level = 'out-of-service'
                 AND (m.completion_time IS NULL OR m.completion_time > @WinStart)
                 AND m.start_time < @WinEnd
            THEN 'BLOCKED' ELSE 'AVAILABLE' END AS booking_outcome
FROM @Maint AS m;
-- Expected: space 100 -> AVAILABLE (advisory), space 101 -> BLOCKED
GO

-- ----------------------------------------------------------------------------
-- V7. Open maintenance period (completion_time IS NULL): blocks any future
--     window that starts after the maintenance start_time.
-- ----------------------------------------------------------------------------
DECLARE @WinStart DATETIME2 = '2026-03-01T10:00:00';
DECLARE @WinEnd   DATETIME2 = '2026-03-01T12:00:00';
DECLARE @Maint TABLE (
    space_id        INT NOT NULL,
    impact_level    NVARCHAR(20) NOT NULL,
    start_time      DATETIME2 NOT NULL,
    completion_time DATETIME2 NULL
);
INSERT INTO @Maint VALUES (100, 'out-of-service', '2026-01-05T08:00:00', NULL);  -- never completed

SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM @Maint
    WHERE space_id = 100
      AND impact_level = 'out-of-service'
      AND (completion_time IS NULL OR completion_time > @WinStart)
      AND start_time < @WinEnd
) THEN 'BLOCKED' ELSE 'AVAILABLE' END AS result;
-- Expected: BLOCKED
GO

-- ----------------------------------------------------------------------------
-- V8. A booking on ANOTHER space does not affect availability of the space
--     being searched.
-- ----------------------------------------------------------------------------
DECLARE @WinStart DATETIME2 = '2026-02-10T10:00:00';
DECLARE @WinEnd   DATETIME2 = '2026-02-10T12:00:00';
DECLARE @Bookings TABLE (
    space_id   INT NOT NULL,
    start_time DATETIME2 NOT NULL,
    end_time   DATETIME2 NOT NULL,
    status     NVARCHAR(20) NOT NULL
);
INSERT INTO @Bookings VALUES
    (100, '2026-02-10T10:30:00', '2026-02-10T11:30:00', 'Approved');  -- overlaps window, but on space 100

SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM @Bookings
    WHERE space_id = 101  -- different space
      AND status IN ('Approved', 'Checked In', 'Completed')
      AND start_time < @WinEnd
      AND end_time   > @WinStart
) THEN 'BLOCKED' ELSE 'AVAILABLE' END AS result;
-- Expected: AVAILABLE
GO
