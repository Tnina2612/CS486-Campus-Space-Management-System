-- ===============================================================================
-- Campus Space Management System - Analytical Queries
-- ===============================================================================
-- Ensure you are using the correct database context
USE [CampusSpaceManagement];
GO

-- ===============================================================================
-- SECTION 1: Nguyen Anh Dung
-- ===============================================================================

-- 1.1 Which spaces are most heavily used, and what is their booking count, total hours booked, average participants, and current status?
SELECT 
    s.space_code,
    s.space_name,
    s.current_status,
    COUNT(b.booking_id) AS booking_count,
    ISNULL(SUM(DATEDIFF(MINUTE, b.start_time, b.end_time)) / 60.0, 0) AS total_hours_booked,
    ISNULL(AVG(b.expected_participants), 0) AS avg_participants
FROM dbo.spaces s
LEFT JOIN dbo.bookings b 
    ON s.space_id = b.space_id 
    AND b.status IN ('Approved', 'Checked In', 'Completed')
GROUP BY 
    s.space_id, s.space_code, s.space_name, s.current_status
ORDER BY 
    total_hours_booked DESC;
GO

-- 1.2 What are all trackable physical assets, their current location, status, and catalog category?
SELECT 
    fa.asset_tag,
    fc.facility_name AS catalog_category,
    s.space_code,
    s.space_name AS current_location,
    fa.status AS asset_status
FROM dbo.facility_assets fa
JOIN dbo.facility_catalog fc 
    ON fa.catalog_id = fc.catalog_id
JOIN dbo.spaces s 
    ON fa.space_id = s.space_id
WHERE 
    fc.is_trackable = 1;
GO

-- 1.3 What is the approval status of all bookings, including who decided, when, and the reason (if rejected)?
SELECT 
    b.booking_id,
    b.purpose,
    b.status AS booking_status,
    u.full_name AS decided_by,
    a.decision_time,
    a.rejection_reason
FROM dbo.bookings b
LEFT JOIN dbo.approvals a 
    ON b.booking_id = a.booking_id
LEFT JOIN dbo.users u 
    ON a.staff_id = u.user_id
ORDER BY 
    a.decision_time DESC;
GO

-- 1.4 Which spaces are currently under active maintenance, what problems are reported, and how does this affect upcoming bookings?
SELECT 
    s.space_code,
    s.space_name,
    mr.problem_description,
    b.booking_id,
    b.start_time AS upcoming_booking_start,
    b.purpose
FROM dbo.maintenance_records mr
JOIN dbo.spaces s 
    ON mr.space_id = s.space_id
LEFT JOIN dbo.bookings b 
    ON s.space_id = b.space_id 
    AND b.start_time > GETDATE() 
    AND b.status IN ('Approved', 'Pending')
WHERE 
    mr.status NOT IN ('Completed', 'Cancelled')
ORDER BY 
    b.start_time ASC;
GO

-- 1.5 Which users (by role) book the most space, what purposes do they book for, and what is their approval success rate?
SELECT 
    u.role,
    COUNT(b.booking_id) AS total_bookings,
    CAST(SUM(CASE WHEN b.status IN ('Approved', 'Completed', 'Checked In') THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(b.booking_id), 0) * 100 AS approval_success_rate_pct
FROM dbo.users u
JOIN dbo.bookings b 
    ON u.user_id = b.user_id
GROUP BY 
    u.role
ORDER BY 
    total_bookings DESC;
GO

-- ===============================================================================
-- SECTION 2: Nguyen Van Le Bao
-- ===============================================================================

-- 2.1 Spaces with the highest utilization rate and capacity efficiency.
SELECT 
    s.space_code,
    s.space_name,
    s.capacity,
    COUNT(b.booking_id) AS completed_sessions,
    AVG(CAST(b.expected_participants AS FLOAT) / s.capacity) * 100 AS capacity_efficiency_pct
FROM dbo.spaces s
JOIN dbo.bookings b 
    ON s.space_id = b.space_id
WHERE 
    b.status = 'Completed'
GROUP BY 
    s.space_id, s.space_code, s.space_name, s.capacity
ORDER BY 
    capacity_efficiency_pct DESC;
GO

-- 2.2 Users with the highest rates of "no-show" for approved bookings.
SELECT 
    u.user_id,
    u.full_name,
    COUNT(b.booking_id) AS expected_attendances,
    SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END) AS no_show_count,
    CAST(SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(b.booking_id), 0) * 100 AS no_show_rate_pct
FROM dbo.users u
JOIN dbo.bookings b 
    ON u.user_id = b.user_id
WHERE 
    b.status IN ('Approved', 'Completed', 'No-show', 'Checked In')
GROUP BY 
    u.user_id, u.full_name
HAVING 
    SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END) > 0
ORDER BY 
    no_show_rate_pct DESC;
GO

-- 2.3 Average maintenance resolution time across different space types.
SELECT 
    s.space_type,
    COUNT(mr.maintenance_id) AS total_completed_maintenance,
    AVG(DATEDIFF(HOUR, mr.start_time, mr.completion_time)) AS avg_resolution_time_hours
FROM dbo.spaces s
JOIN dbo.maintenance_records mr 
    ON s.space_id = mr.space_id
WHERE 
    mr.completion_time IS NOT NULL 
    AND mr.status = 'Completed'
GROUP BY 
    s.space_type
ORDER BY 
    avg_resolution_time_hours DESC;
GO

-- 2.4 Equipment availability bottlenecks in high-demand areas.
SELECT 
    s.space_code,
    s.space_name,
    COUNT(DISTINCT b.booking_id) AS booking_volume,
    COUNT(DISTINCT fa.asset_id) AS trackable_asset_count
FROM dbo.spaces s
LEFT JOIN dbo.bookings b 
    ON s.space_id = b.space_id
LEFT JOIN dbo.facility_assets fa 
    ON s.space_id = fa.space_id
GROUP BY 
    s.space_id, s.space_code, s.space_name
ORDER BY 
    booking_volume DESC, 
    trackable_asset_count ASC;
GO

-- 2.5 Peak booking hours and most requested purpose types.
SELECT 
    DATEPART(HOUR, b.start_time) AS booking_hour,
    COUNT(b.booking_id) AS booking_volume,
    b.purpose
FROM dbo.bookings b
WHERE 
    b.status IN ('Approved', 'Checked In', 'Completed')
GROUP BY 
    DATEPART(HOUR, b.start_time), b.purpose
ORDER BY 
    booking_volume DESC;
GO

-- ===============================================================================
-- SECTION 3: Tran Dang Le Huy
-- ===============================================================================

-- 3.1 Suitable spaces for an event based on capacity, furniture/equipment, and time availability.
DECLARE @ReqCapacity INT = 30;
DECLARE @ReqCatalogId INT = 1; -- E.g., Catalog ID for Projector
DECLARE @ReqStartTime DATETIME2 = '2026-08-01 08:00:00';
DECLARE @ReqEndTime DATETIME2 = '2026-08-01 11:00:00';

SELECT 
    s.space_code, 
    s.space_name, 
    s.capacity
FROM dbo.spaces s
JOIN dbo.space_facility sf 
    ON s.space_id = sf.space_id
WHERE 
    s.capacity >= @ReqCapacity
    AND s.current_status = 'Available'
    AND sf.catalog_id = @ReqCatalogId
    AND sf.quantity >= 1
    -- Ensure no overlapping approved/active bookings
    AND NOT EXISTS (
        SELECT 1 
        FROM dbo.bookings b
        WHERE b.space_id = s.space_id
          AND b.status IN ('Approved', 'Checked In', 'Pending')
          AND (b.start_time < @ReqEndTime AND b.end_time > @ReqStartTime)
    );
GO

-- 3.2 Department with the highest classroom usage in a period.
SELECT TOP 1
    u.department,
    COUNT(b.booking_id) AS total_classroom_bookings,
    SUM(DATEDIFF(HOUR, b.start_time, b.end_time)) AS total_hours_used
FROM dbo.users u
JOIN dbo.bookings b 
    ON u.user_id = b.user_id
JOIN dbo.spaces s 
    ON b.space_id = s.space_id
WHERE 
    s.space_type = 'Classroom'
    AND b.status IN ('Completed', 'Checked In')
GROUP BY 
    u.department
ORDER BY 
    total_hours_used DESC;
GO

-- 3.3 No-show rate per user for policy or blacklist candidate detection.
SELECT 
    u.user_id,
    u.full_name,
    COUNT(b.booking_id) AS total_bookings,
    SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END) AS no_shows,
    CAST(SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(b.booking_id) * 100 AS no_show_rate_pct
FROM dbo.users u
JOIN dbo.bookings b 
    ON u.user_id = b.user_id
WHERE 
    b.status IN ('Completed', 'No-show', 'Checked In', 'Approved')
GROUP BY 
    u.user_id, u.full_name
HAVING 
    COUNT(b.booking_id) >= 5 
    AND (CAST(SUM(CASE WHEN b.status = 'No-show' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(b.booking_id)) > 0.2
ORDER BY 
    no_show_rate_pct DESC;
GO

-- 3.4 Approval turnaround time by approver.
SELECT 
    u.full_name AS approver_name,
    COUNT(a.approval_id) AS total_decisions,
    AVG(DATEDIFF(HOUR, a.decision_time, b.start_time)) AS avg_lead_time_hours_before_event
FROM dbo.approvals a
JOIN dbo.users u 
    ON a.staff_id = u.user_id
JOIN dbo.bookings b 
    ON a.booking_id = b.booking_id
GROUP BY 
    u.full_name, u.user_id
ORDER BY 
    total_decisions DESC;
GO

-- 3.5 Trackable asset types with the most related maintenance issues.
SELECT 
    fc.facility_name,
    COUNT(DISTINCT mr.maintenance_id) AS related_maintenance_issues
FROM dbo.facility_catalog fc
JOIN dbo.facility_assets fa 
    ON fc.catalog_id = fa.catalog_id
JOIN dbo.spaces s 
    ON fa.space_id = s.space_id
JOIN dbo.maintenance_records mr 
    ON s.space_id = mr.space_id
WHERE 
    fc.is_trackable = 1
GROUP BY 
    fc.facility_name
ORDER BY 
    related_maintenance_issues DESC;
GO

-- 3.6 Upcoming high-occupancy alerts for near-capacity bookings.
SELECT 
    b.booking_id,
    s.space_code,
    s.capacity,
    b.expected_participants,
    b.start_time,
    CAST(b.expected_participants AS FLOAT) / s.capacity * 100 AS occupancy_percentage
FROM dbo.bookings b
JOIN dbo.spaces s 
    ON b.space_id = s.space_id
WHERE 
    b.status = 'Approved'
    AND b.start_time > GETDATE()
    AND CAST(b.expected_participants AS FLOAT) / s.capacity >= 0.85
ORDER BY 
    b.start_time ASC;
GO

-- ===============================================================================
-- SECTION 4: Tran Thien Phuc
-- ===============================================================================

-- 4.1 What is the full lifecycle of every booking - who requested it, was it approved, did they check in?
SELECT 
    b.booking_id,
    u_requester.full_name AS requested_by,
    b.status AS current_booking_status,
    a.decision_time,
    u_approver.full_name AS approved_by,
    us.actual_start_time AS checked_in_time,
    us.actual_end_time AS checked_out_time
FROM dbo.bookings b
JOIN dbo.users u_requester 
    ON b.user_id = u_requester.user_id
LEFT JOIN dbo.approvals a 
    ON b.booking_id = a.booking_id
LEFT JOIN dbo.users u_approver 
    ON a.staff_id = u_approver.user_id
LEFT JOIN dbo.usage_sessions us 
    ON b.booking_id = us.booking_id;
GO

-- 4.2 Which spaces have the highest and lowest total booked hours?
WITH SpaceHours AS (
    SELECT 
        s.space_code,
        s.space_name,
        ISNULL(SUM(DATEDIFF(MINUTE, b.start_time, b.end_time)) / 60.0, 0) AS total_booked_hours
    FROM dbo.spaces s
    LEFT JOIN dbo.bookings b 
        ON s.space_id = b.space_id 
        AND b.status NOT IN ('Cancelled', 'Rejected')
    GROUP BY 
        s.space_code, s.space_name
)
SELECT * FROM SpaceHours
WHERE total_booked_hours = (SELECT MAX(total_booked_hours) FROM SpaceHours)
   OR total_booked_hours = (SELECT MIN(total_booked_hours) FROM SpaceHours)
ORDER BY 
    total_booked_hours DESC;
GO

-- 4.3 Which spaces have active maintenance work AND broken equipment at the same time?
SELECT DISTINCT 
    s.space_code,
    s.space_name,
    mr.problem_description AS active_maintenance_issue,
    fa.asset_tag,
    fa.status AS asset_status
FROM dbo.spaces s
JOIN dbo.maintenance_records mr 
    ON s.space_id = mr.space_id
JOIN dbo.facility_assets fa 
    ON s.space_id = fa.space_id
WHERE 
    mr.status NOT IN ('Completed', 'Cancelled')
    AND fa.status NOT IN ('Active', 'Available');
GO

-- 4.4 Which users waste bookable capacity through cancellations or no-shows?
SELECT 
    u.user_id,
    u.full_name,
    COUNT(b.booking_id) AS wasted_bookings_count,
    SUM(DATEDIFF(HOUR, b.start_time, b.end_time)) AS wasted_hours,
    STRING_AGG(b.status, ', ') AS waste_types
FROM dbo.users u
JOIN dbo.bookings b 
    ON u.user_id = b.user_id
WHERE 
    b.status IN ('No-show', 'Cancelled')
GROUP BY 
    u.user_id, u.full_name
ORDER BY 
    wasted_hours DESC;
GO

-- 4.5 What is the complete facility inventory for each space - combining catalog-level quantities with actual tracked assets?
SELECT 
    s.space_code,
    s.space_name,
    fc.facility_name,
    fc.is_trackable,
    sf.quantity AS planned_catalog_quantity,
    COUNT(fa.asset_id) AS actual_tracked_assets
FROM dbo.spaces s
JOIN dbo.space_facility sf 
    ON s.space_id = sf.space_id
JOIN dbo.facility_catalog fc 
    ON sf.catalog_id = fc.catalog_id
LEFT JOIN dbo.facility_assets fa 
    ON s.space_id = fa.space_id 
    AND fc.catalog_id = fa.catalog_id
GROUP BY 
    s.space_code, s.space_name, fc.facility_name, fc.is_trackable, sf.quantity
ORDER BY 
    s.space_code, fc.facility_name;
GO