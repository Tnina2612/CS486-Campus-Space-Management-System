-- ============================================================
-- Query Design — G11
-- DBMS: Microsoft SQL Server
-- ============================================================
USE [CampusSpaceManagement];
GO

-- ============================================================
-- Query 1: Available Spaces with Facilities Summary
-- ---------------------------------------------------------
-- Business Question:
--   Which spaces are currently available, and what facilities
--   (trackable and non-trackable) do they have?
-- Target Users:
--   Students, Lecturers, TA, Facility Staff
-- Why Useful:
--   Helps users quickly identify bookable spaces that meet
--   their facility requirements (e.g., a room with a projector).
-- ============================================================
SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    (
        SELECT STRING_AGG(fc.name + ' (' + CAST(sf.quantity AS NVARCHAR) + ')', ', ')
        FROM dbo.space_facility sf
        INNER JOIN dbo.facility_catalog fc ON sf.catalog_id = fc.catalog_id
        WHERE sf.space_code = s.space_code
    ) AS facility_list,
    (
        SELECT COUNT(*)
        FROM dbo.facility_asset fa
        WHERE fa.space_code = s.space_code AND fa.status = 'Working'
    ) AS working_assets
FROM dbo.space s
WHERE s.current_status = 'Available'
ORDER BY s.building, s.floor, s.room_number;
GO


-- ============================================================
-- Query 2: Weekly Booking Schedule for a Specific Space
-- ---------------------------------------------------------
-- Business Question:
--   What is the upcoming week's booking schedule for space
--   'B201', and what is the status of each booking?
-- Target Users:
--   Facility Staff, Facility Manager
-- Why Useful:
--   Enables staff to quickly see daily occupancy, avoid
--   scheduling conflicts, and prepare rooms in advance.
-- ============================================================
DECLARE @TargetSpace NVARCHAR(20) = 'B201';
DECLARE @WeekStart DATE = '2026-06-29';
DECLARE @WeekEnd DATE = '2026-07-05';

SELECT
    br.booking_id,
    u.full_name AS requester,
    br.purpose,
    br.requested_start_time,
    br.requested_end_time,
    br.status,
    bd.decision,
    CASE
        WHEN br.status = 'Checked In' THEN bs.actual_start_time
        ELSE NULL
    END AS actual_start_time,
    CASE
        WHEN br.status = 'Completed' THEN bs.actual_end_time
        ELSE NULL
    END AS actual_end_time
FROM dbo.booking_request br
INNER JOIN dbo.[user] u ON br.requester_id = u.user_id
LEFT JOIN dbo.booking_decision bd ON br.booking_id = bd.booking_id
LEFT JOIN dbo.booking_session bs ON br.booking_id = bs.booking_id
WHERE br.space_code = @TargetSpace
  AND br.requested_start_time >= @WeekStart
  AND br.requested_start_time < DATEADD(DAY, 1, @WeekEnd)
  AND br.status NOT IN ('Cancelled', 'Rejected')
ORDER BY br.requested_start_time;
GO


-- ============================================================
-- Query 3: Active Maintenance Records with Details
-- ---------------------------------------------------------
-- Business Question:
--   What maintenance issues are currently open (Reported or
--   In Progress), which space do they affect, who reported
--   them, and who is assigned?
-- Target Users:
--   Facility Staff, Facility Manager
-- Why Useful:
--   Provides a real-time view of all ongoing maintenance so
--   that managers can prioritize repairs and block affected
--   spaces from being booked.
-- ============================================================
SELECT
    mr.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    mr.problem_type,
    mr.problem_description,
    reporter.full_name AS reported_by,
    assignee.full_name  AS assigned_to,
    mr.start_time,
    mr.status,
    mr.result_note,
    DATEDIFF(DAY, mr.start_time, GETUTCDATE()) AS days_open
FROM dbo.maintenance_record mr
INNER JOIN dbo.space s ON mr.space_code = s.space_code
INNER JOIN dbo.[user] reporter ON mr.reported_by = reporter.user_id
LEFT JOIN dbo.[user] assignee ON mr.assigned_to = assignee.user_id
WHERE mr.status IN ('Reported', 'In Progress')
ORDER BY
    CASE mr.status WHEN 'Reported' THEN 0 ELSE 1 END,
    mr.start_time;
GO


-- ============================================================
-- Query 4: Booking History for a Specific User
-- ---------------------------------------------------------
-- Business Question:
--   What is the complete booking history for user 'Nguyen Van A'
--   (user_id = 1), including decision and session details?
-- Target Users:
--   Any user (students, lecturers, staff), Dept Admin
-- Why Useful:
--   Enables users to track their own booking history, check
--   approval status, review past usage, and verify any
--   no-show records that may affect future bookings.
-- ============================================================
DECLARE @TargetUser INT = 1;

SELECT
    br.booking_id,
    s.space_code,
    s.space_name,
    br.purpose,
    br.requested_start_time,
    br.requested_end_time,
    br.expected_participants,
    br.status,
    br.created_at AS submitted_at,
    bd.decision,
    bd.decision_time,
    bd.decision_note,
    bd.rejection_reason,
    staff.full_name AS decided_by,
    bs.actual_start_time,
    bs.actual_end_time,
    bs.initial_condition,
    bs.final_condition,
    bs.usage_notes
FROM dbo.booking_request br
INNER JOIN dbo.space s ON br.space_code = s.space_code
LEFT JOIN dbo.booking_decision bd ON br.booking_id = bd.booking_id
LEFT JOIN dbo.[user] staff ON bd.staff_id = staff.user_id
LEFT JOIN dbo.booking_session bs ON br.booking_id = bs.booking_id
WHERE br.requester_id = @TargetUser
ORDER BY br.requested_start_time DESC;
GO


-- ============================================================
-- Query 5: Facility Inventory by Space (Hybrid Pattern View)
-- ---------------------------------------------------------
-- Business Question:
--   What is the complete facility inventory for each space,
--   showing both catalog-level (non-trackable) quantities and
--   individual trackable assets with their status?
-- Target Users:
--   Facility Manager, Facility Staff
-- Why Useful:
--   Provides a unified inventory view combining the M:N
--   catalog mapping (for bulk items like chairs/whiteboards)
--   and individual asset tracking (for projectors, computers).
--   Essential for auditing, maintenance planning, and
--   procurement decisions.
-- ============================================================
SELECT
    s.space_code,
    s.space_name,
    fc.name AS facility_name,
    fc.is_trackable,
    CASE
        WHEN fc.is_trackable = 0 THEN CAST(sf.quantity AS NVARCHAR)
        ELSE NULL
    END AS quantity,
    CASE
        WHEN fc.is_trackable = 1 THEN fa.asset_tag
        ELSE NULL
    END AS asset_tag,
    CASE
        WHEN fc.is_trackable = 1 THEN fa.status
        ELSE NULL
    END AS asset_status
FROM dbo.space s
INNER JOIN dbo.space_facility sf ON s.space_code = sf.space_code
INNER JOIN dbo.facility_catalog fc ON sf.catalog_id = fc.catalog_id
LEFT JOIN dbo.facility_asset fa
    ON fa.catalog_id = fc.catalog_id AND fa.space_code = s.space_code
WHERE s.current_status != 'Retired'
ORDER BY s.space_code, fc.name, fa.asset_tag;
GO
