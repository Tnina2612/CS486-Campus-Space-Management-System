-- ============================================================
-- Campus Space Management System - Query Design
-- Group: G11
-- DBMS: Microsoft SQL Server
-- ============================================================

USE [CampusSpaceManagement];
GO

-- ============================================================
-- Query 1: Available spaces with their facilities
-- ---------------------------------------------------------
-- Business Question: Which spaces are currently available
--   for booking, and what facilities do they have?
-- Target User(s): Facility Staff, Facility Manager
-- Explanation: Helps staff quickly identify free spaces and
--   their available equipment when responding to booking
--   requests.
-- ============================================================
SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.capacity,
    s.usage_policy,
    fc.name        AS facility_name,
    CASE WHEN fc.is_trackable = 1
        THEN CAST(COUNT(fa.asset_id) AS NVARCHAR)
        ELSE CAST(sf.quantity AS NVARCHAR)
    END            AS quantity_or_count,
    CASE WHEN fc.is_trackable = 1 THEN N'Tracked (assets)'
                               ELSE N'Non-tracked'
    END            AS tracking_type
FROM dbo.space s
INNER JOIN dbo.space_facility sf ON s.space_code = sf.space_code
INNER JOIN dbo.facility_catalog fc ON sf.catalog_id = fc.catalog_id
LEFT JOIN dbo.facility_asset fa ON fa.catalog_id = fc.catalog_id
                               AND fa.space_code = s.space_code
WHERE s.status = 'Available'
GROUP BY s.space_code, s.space_name, s.space_type, s.building,
         s.floor, s.capacity, s.usage_policy,
         fc.name, fc.is_trackable, sf.quantity
ORDER BY s.space_code, fc.name;
GO

-- ============================================================
-- Query 2: Upcoming approved bookings with time details
-- ---------------------------------------------------------
-- Business Question: What approved bookings are coming up
--   in the next 7 days, and who requested them?
-- Target User(s): Facility Staff, Department Admin
-- Explanation: Enables staff to prepare spaces before
--   scheduled sessions and anticipate room usage.
-- ============================================================
SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name                    AS requester_name,
    u.email                        AS requester_email,
    b.requested_start,
    b.requested_end,
    DATEDIFF(MINUTE, b.requested_start, b.requested_end) AS duration_minutes,
    b.purpose,
    b.participants,
    b.booking_type
FROM dbo.booking b
INNER JOIN dbo.space s ON b.space_code = s.space_code
INNER JOIN dbo.[user] u ON b.requester_id = u.user_id
WHERE b.status = 'Approved'
  AND b.requested_start >= GETDATE()
  AND b.requested_start < DATEADD(DAY, 7, GETDATE())
ORDER BY b.requested_start;
GO

-- ============================================================
-- Query 3: Spaces currently under active maintenance
-- ---------------------------------------------------------
-- Business Question: Which spaces are under maintenance and
--   therefore unavailable for booking right now?
-- Target User(s): Facility Staff, Facility Manager, all users
-- Explanation: Prevents scheduling conflicts by showing
--   spaces that cannot be booked due to active issues.
-- ============================================================
SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    m.problem_description,
    m.problem_type,
    m.status                         AS maintenance_status,
    m.start_time,
    reporter.full_name               AS reported_by,
    assignee.full_name               AS assigned_to
FROM dbo.maintenance_record m
INNER JOIN dbo.space s ON m.space_code = s.space_code
INNER JOIN dbo.[user] reporter ON m.reporter_id = reporter.user_id
LEFT JOIN dbo.[user] assignee ON m.assigned_to = assignee.user_id
WHERE m.status IN ('Reported', 'InProgress')
ORDER BY m.start_time DESC;
GO

-- ============================================================
-- Query 4: No-show booking history
-- ---------------------------------------------------------
-- Business Question: Which users have failed to show up for
--   their booked sessions?
-- Target User(s): Facility Manager, Department Admin
-- Explanation: Helps identify habitual no-shows to enforce
--   usage policies or impose booking restrictions.
-- ============================================================
SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name                 AS requester_name,
    u.email                     AS requester_email,
    u.role                      AS requester_role,
    b.requested_start,
    b.requested_end,
    b.booking_type,
    b.purpose
FROM dbo.booking b
INNER JOIN dbo.space s ON b.space_code = s.space_code
INNER JOIN dbo.[user] u ON b.requester_id = u.user_id
WHERE b.status = 'NoShow'
ORDER BY b.requested_start DESC;
GO

-- ============================================================
-- Query 5: Trackable facility asset inventory by space
-- ---------------------------------------------------------
-- Business Question: What are all the individually tracked
--   facility assets, where are they located, and what is
--   their current status?
-- Target User(s): Facility Staff, Facility Manager
-- Explanation: Provides a complete inventory of high-value
--   assets for maintenance planning, replacement budgeting,
--   and relocation decisions.
-- ============================================================
SELECT
    fa.asset_id,
    fa.asset_tag,
    fc.name                        AS catalog_name,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    fa.status                      AS asset_status,
    CASE
        WHEN fa.status = 'Working'     THEN N'In service'
        WHEN fa.status = 'UnderRepair' THEN N'Needs attention'
        WHEN fa.status = 'Retired'     THEN N'To be replaced'
    END                            AS status_description
FROM dbo.facility_asset fa
INNER JOIN dbo.facility_catalog fc ON fa.catalog_id = fc.catalog_id
INNER JOIN dbo.space s ON fa.space_code = s.space_code
ORDER BY fc.name, fa.asset_tag;
GO

PRINT 'Query design script loaded successfully.';
GO
