/*
================================================================================
  16-analytical-queries-G11.sql
  Campus Space Management System - Phase 2 Analytical Queries
  Group: G11
================================================================================
  Implements the four reporting needs from the Phase 2 requirement
  (RC-07 .. RC-10). Uses the migrated schema (outputs/10-schema-migration-G11.sql)
  and the large dataset from outputs/14-data-generator-G11/.

  Reports:
    Q1. Total approved booking hours per space for a given semester (RC-07)
    Q2. Approved bookings by weekday and hour for a given semester   (RC-08)
    Q3. Available spaces meeting required capacity + facility list
        within a given time window                                   (RC-09)
    Q4. Approved bookings affected by a maintenance escalation
        to out-of-service                                            (RC-10)
================================================================================
*/

USE [CampusSpaceManagement];
GO

/* =============================================================================
   Q1 (RC-07) — Total approved booking hours per space for a semester.
   "Approved" includes all approved-like states that reserve the space:
   Approved, Checked In, Completed. Hours use DATEDIFF with MINUTE precision
   converted to decimal hours.
============================================================================= */
DECLARE @SemStart DATETIME2 = '2026-01-05 00:00:00';  -- semester window start
DECLARE @SemEnd   DATETIME2 = '2026-04-30 23:59:59';  -- semester window end

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    COUNT(b.booking_id)                                          AS approved_bookings,
    SUM(DATEDIFF(MINUTE, b.start_time, b.end_time)) / 60.0       AS total_approved_hours
FROM dbo.spaces AS s
LEFT JOIN dbo.bookings AS b
       ON b.space_id  = s.space_id
      AND b.status    IN ('Approved', 'Checked In', 'Completed')
      AND b.start_time < @SemEnd
      AND b.end_time   > @SemStart
GROUP BY s.space_code, s.space_name, s.space_type
ORDER BY total_approved_hours DESC;
GO

/* =============================================================================
   Q2 (RC-08) — Approved bookings by weekday and hour for a semester.
   Pivots the count across the 7 weekday names x 24 hours.
============================================================================= */
WITH approved AS (
    SELECT
        b.booking_id,
        b.start_time,
        b.end_time,
        b.space_id
    FROM dbo.bookings AS b
    WHERE b.status IN ('Approved', 'Checked In', 'Completed')
      AND b.start_time < @SemEnd
      AND b.end_time   > @SemStart
)
SELECT
    DATENAME(WEEKDAY, a.start_time)                 AS weekday,
    DATEPART(HOUR, a.start_time)                    AS hour_of_day,
    COUNT(*)                                        AS booking_count,
    COUNT(DISTINCT a.space_id)                      AS distinct_spaces
FROM approved AS a
GROUP BY DATENAME(WEEKDAY, a.start_time), DATEPART(HOUR, a.start_time)
ORDER BY CASE DATENAME(WEEKDAY, a.start_time)
             WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
             WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6
             ELSE 7 END,
         DATEPART(HOUR, a.start_time);
GO

/* =============================================================================
   Q3 (RC-09) — Available spaces meeting a required capacity + facility list
   within a given time window.

   Parameters:
     @ReqCapacity INT  -- minimum capacity
     @FacilityList      -- table-valued filter of required facility catalog ids
     @WinStart/@WinEnd  -- the time window (bookings must fit entirely inside)

   A space is "available" if:
     * current_status is not Under Maintenance / Temporarily Closed / Retired
     * has no approved-like booking overlapping the window
     * has no out-of-service maintenance overlapping the window
     * capacity >= @ReqCapacity
     * possesses every required facility (existence check, not quantity)
============================================================================= */
DECLARE @ReqCapacity INT = 30;
DECLARE @WinStart DATETIME2 = '2026-03-09 09:00:00';
DECLARE @WinEnd   DATETIME2 = '2026-03-09 11:00:00';
DECLARE @RequiredFacilities TABLE (catalog_id INT PRIMARY KEY);
INSERT INTO @RequiredFacilities (catalog_id) VALUES (4);  -- Computer Workstation
-- uncomment to add more: ,(1);  -- Projector

SELECT
    s.space_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.capacity,
    s.current_status
FROM dbo.spaces AS s
WHERE s.capacity >= @ReqCapacity
  AND s.current_status NOT IN ('Under Maintenance', 'Temporarily Closed', 'Retired')
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.bookings AS b
      WHERE b.space_id = s.space_id
        AND b.status IN ('Approved', 'Checked In', 'Completed')
        AND b.start_time < @WinEnd
        AND b.end_time   > @WinStart
  )
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.maintenance_records AS m
      WHERE m.space_id = s.space_id
        AND m.impact_level = 'out-of-service'
        AND (m.completion_time IS NULL OR m.completion_time > @WinStart)
        AND m.start_time < @WinEnd
  )
  AND NOT EXISTS (
      -- every required facility must exist for this space
      SELECT 1
      FROM @RequiredFacilities AS rf
      WHERE NOT EXISTS (
          SELECT 1
          FROM dbo.space_facility AS sf
          WHERE sf.space_id = s.space_id
            AND sf.catalog_id = rf.catalog_id
      )
  )
ORDER BY s.space_type, s.space_code;
GO

/* =============================================================================
   Q4 (RC-10) — Approved bookings affected by a maintenance escalation
   to out-of-service.

   Given a maintenance record escalated to out-of-service, list every
   approved-like booking on the same space whose period overlaps the
   maintenance period. Staff use this list to contact requesters.
   (Mirrors the result set returned by usp_UpdateMaintenanceImpactLevel.)
============================================================================= */
DECLARE @MaintenanceID INT = 1;   -- the escalated maintenance record

SELECT
    m.maintenance_id,
    m.problem_description,
    m.impact_level,
    m.start_time   AS maintenance_start,
    m.completion_time AS maintenance_end,
    s.space_code,
    b.booking_id,
    u.full_name    AS requester,
    u.email        AS requester_email,
    b.start_time   AS booking_start,
    b.end_time     AS booking_end,
    b.status       AS booking_status
FROM dbo.maintenance_records AS m
INNER JOIN dbo.spaces AS s   ON s.space_id = m.space_id
INNER JOIN dbo.bookings AS b ON b.space_id = m.space_id
INNER JOIN dbo.users AS u    ON u.user_id  = b.user_id
WHERE m.maintenance_id = @MaintenanceID
  AND m.impact_level   = 'out-of-service'
  AND b.status IN ('Approved', 'Checked In', 'Completed')
  AND b.start_time < COALESCE(m.completion_time, DATEADD(year, 100, m.start_time))
  AND b.end_time   > m.start_time
ORDER BY b.start_time;
GO
