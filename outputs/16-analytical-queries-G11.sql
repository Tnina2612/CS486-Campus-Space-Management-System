USE [CampusSpaceManagement];
GO

-- ============================================================================
-- Phase 2 Analytical Queries - G11
-- Implements all 4 required reports from Section 1.3 of the Phase 2 spec.
--
-- Approved-status definition used throughout (aligned with Phase 1 design):
--   status IN ('Approved', 'Checked In', 'Completed', 'No-show')
--   (a booking that was approved and occupied; 'Approved' captures the current
--    state, the others are approved bookings that proceeded further.)
-- Overlap condition (shared): existing_start < candidate_end
--                             AND existing_end > candidate_start
-- Semester boundaries are parameterized (declared as variables below).
-- ============================================================================

-- ============================================================================
-- Query 1: Total approved booking hours per space for a given semester
-- ----------------------------------------------------------------------------
-- Business Question: How many approved booking hours did each space accumulate
--   during the semester?
-- Target User(s): Facility Manager, Department Administrator.
-- Input Parameters: @sem_start, @sem_end.
-- ============================================================================
DECLARE @sem_start DATETIME2 = '2025-09-01 00:00:00';
DECLARE @sem_end   DATETIME2 = '2026-01-01 00:00:00';

SELECT
    s.space_id,
    s.space_code,
    s.space_name,
    COUNT(b.booking_id)                                        AS approved_booking_count,
    COALESCE(SUM(DATEDIFF(MINUTE,
                          CASE WHEN b.start_time < @sem_start THEN @sem_start ELSE b.start_time END,
                          CASE WHEN b.end_time   > @sem_end   THEN @sem_end   ELSE b.end_time   END)
             / 60.0), 0)                                       AS approved_booking_hours
FROM dbo.spaces s
LEFT JOIN dbo.bookings b
    ON s.space_id = b.space_id
   AND b.status IN ('Approved', 'Checked In', 'Completed', 'No-show')
   AND b.start_time < @sem_end
   AND b.end_time   > @sem_start
GROUP BY s.space_id, s.space_code, s.space_name
ORDER BY approved_booking_hours DESC;

-- Assumptions: overlap with semester window is clipped at semester boundaries;
--   spaces with zero approved hours are included (LEFT JOIN).
-- Test example: for the 2025-2026-S1 window above, the query returns every space
--   with its total approved hours; spaces with no approved booking show 0.
GO


-- ============================================================================
-- Query 2: Number of approved bookings by weekday and hour for a given semester
-- ----------------------------------------------------------------------------
-- Business Question: When are approved bookings most frequent, by day-of-week
--   and starting hour?
-- Target User(s): Facility Manager.
-- Input Parameters: @sem_start, @sem_end.
-- Note: grouping is based on the booking START time.
-- ============================================================================
DECLARE @sem_start DATETIME2 = '2025-09-01 00:00:00';
DECLARE @sem_end   DATETIME2 = '2026-01-01 00:00:00';

SELECT
    DATEPART(WEEKDAY, b.start_time) AS weekday_number,   -- 1=Sunday .. 7=Saturday
    DATENAME(WEEKDAY, b.start_time) AS weekday_name,
    DATEPART(HOUR,   b.start_time)  AS start_hour,
    COUNT(*)                        AS approved_booking_count
FROM dbo.bookings b
WHERE b.status IN ('Approved', 'Checked In', 'Completed', 'No-show')
  AND b.start_time >= @sem_start
  AND b.start_time <  @sem_end
GROUP BY DATEPART(WEEKDAY, b.start_time),
         DATENAME(WEEKDAY, b.start_time),
         DATEPART(HOUR, b.start_time)
ORDER BY DATEPART(WEEKDAY, b.start_time), DATEPART(HOUR, b.start_time);
GO

-- Assumption: grouping uses booking start time (documented above). Weekday
--   numbering follows SQL Server convention (Sunday=1); a stable Monday-Sunday
--   presentation can be applied in the reporting layer by re-mapping (e.g.,
--   (DATEPART(WEEKDAY, ...) + 5) % 7) if required.
-- Expected result: a row per (weekday, hour) with the approved booking count;
--   busy lecture hours (e.g., 09:00) on weekdays show the highest counts.


-- ============================================================================
-- Query 3: Room finder — available spaces matching capacity + facility list
-- ----------------------------------------------------------------------------
-- Business Question: Which spaces are free for a given time window, have at
--   least the required capacity, and contain every required facility?
-- Target User(s): Any requester; Facility Staff.
-- Input Parameters: @req_start, @req_end, @min_capacity, required facility list.
-- ============================================================================
DECLARE @req_start     DATETIME2 = '2026-03-10 09:00:00';
DECLARE @req_end       DATETIME2 = '2026-03-10 11:00:00';
DECLARE @min_capacity  INT       = 50;
DECLARE @required_facilities TABLE (facility_name NVARCHAR(100) NOT NULL);
INSERT INTO @required_facilities (facility_name) VALUES ('Projector');
-- To test empty facility list: leave the table empty.

WITH candidates AS (
    SELECT s.space_id, s.space_code, s.space_name, s.capacity
    FROM dbo.spaces s
    WHERE s.capacity >= @min_capacity
      AND s.current_status NOT IN ('Temporarily Closed', 'Retired', 'Under Maintenance')
      AND NOT EXISTS (   -- no approved booking overlap
          SELECT 1
          FROM dbo.bookings b
          WHERE b.space_id = s.space_id
            AND b.status IN ('Approved', 'Checked In', 'Completed', 'No-show')
            AND @req_start < b.end_time
            AND @req_end   > b.start_time
      )
      AND NOT EXISTS (   -- no out-of-service maintenance overlap
          SELECT 1
          FROM dbo.maintenance_records m
          WHERE m.space_id = s.space_id
            AND m.impact_level = 'out-of-service'
            AND (m.completion_time IS NULL OR m.completion_time > @req_start)
            AND m.start_time < @req_end
      )
)
SELECT c.space_id, c.space_code, c.space_name, c.capacity
FROM candidates c
WHERE NOT EXISTS (   -- must contain EVERY required facility
    SELECT 1
    FROM @required_facilities rf
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.space_facility sf
        JOIN dbo.facility_catalog fc ON sf.catalog_id = fc.catalog_id
        WHERE sf.space_id = c.space_id
          AND fc.facility_name = rf.facility_name
    )
)
ORDER BY c.capacity ASC;

-- Assumptions: 'Under Maintenance' spaces are excluded up front only for the
--   out-of-service reason handled explicitly; advisory maintenance does NOT
--   block (per Phase 2). Empty facility list passes all otherwise-valid spaces.
-- Test example: with @min_capacity=50 and facility 'Projector', returns only
--   bookable spaces with >=50 capacity containing a projector and no conflict.
GO


-- ============================================================================
-- Query 4: Approved bookings affected by escalation to out-of-service
-- ----------------------------------------------------------------------------
-- Business Question: If a maintenance record is escalated to out-of-service,
--   which approved bookings overlap its maintenance period and need to be
--   contacted?
-- Target User(s): Facility Staff, Facility Manager.
-- Input Parameters: @maintenance_id.
-- ============================================================================
DECLARE @maintenance_id INT = 1;

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    b.start_time,
    b.end_time,
    u.full_name AS requester_name,
    u.email     AS requester_email,
    u.phone_number AS requester_phone,
    m.maintenance_id,
    m.impact_level,
    m.start_time AS maintenance_start,
    m.completion_time AS maintenance_end
FROM dbo.bookings b
JOIN dbo.maintenance_records m
    ON b.space_id = m.space_id
JOIN dbo.users u
    ON b.user_id = u.user_id
JOIN dbo.spaces s
    ON b.space_id = s.space_id
WHERE m.maintenance_id = @maintenance_id
  AND b.status IN ('Approved', 'Checked In', 'Completed', 'No-show')
  AND (m.completion_time IS NULL OR m.completion_time > b.start_time)
  AND m.start_time < b.end_time
ORDER BY b.start_time;

-- Assumption: open maintenance (completion_time NULL) is treated as ongoing;
--   affected bookings are those overlapping the maintenance window regardless
--   of whether the record is currently advisory or already out-of-service
--   (the caller passes the escalated record id).
-- Expected result: requester contact info for every approved booking that
--   overlaps the escalated maintenance period, enabling staff to notify them.
GO