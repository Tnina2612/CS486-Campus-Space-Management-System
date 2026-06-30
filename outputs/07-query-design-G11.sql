-- ============================================================
-- Query Design — Campus Space Management System
-- ============================================================
-- Step 7: Business Intelligence Queries
-- Target: Microsoft SQL Server (T-SQL)
-- ============================================================

USE [CampusSpaceManagement];
GO

-- ============================================================
-- Query 1: Booking History for a Specific Space
-- ============================================================
-- Business Question: What is the complete booking history for
--   a given space, including requester, approval status, and
--   actual usage session details?
-- Target User: Facility Staff, Department Administrator
-- Explanation: Staff need to review a space's past bookings to
--   identify usage patterns, verify that sessions completed as
--   expected, and audit check-in/check-out records.
-- ============================================================
SELECT
    b.booking_id,
    b.booking_type,
    b.status                                          AS booking_status,
    u.full_name                                       AS requester_name,
    u.role                                            AS requester_role,
    b.requested_start_time,
    b.requested_end_time,
    b.expected_participants,
    b.purpose,
    a.decision                                        AS approval_decision,
    a.decision_time                                   AS approval_time,
    a.rejection_reason,
    staff.full_name                                   AS approved_by,
    us.actual_start_time                              AS check_in_time,
    us.actual_end_time                                AS check_out_time,
    us.initial_condition,
    us.final_condition,
    us.usage_notes
FROM dbo.BOOKING b
INNER JOIN dbo.[USER] u ON u.user_id = b.user_id
INNER JOIN dbo.SPACE s ON s.space_code = b.space_code
LEFT JOIN dbo.APPROVAL a ON a.booking_id = b.booking_id
LEFT JOIN dbo.[USER] staff ON staff.user_id = a.staff_id
LEFT JOIN dbo.USAGE_SESSION us ON us.booking_id = b.booking_id
WHERE s.space_code = 'CL-201'
ORDER BY b.requested_start_time DESC;
GO

-- ============================================================
-- Query 2: Upcoming Approved Bookings (Next 7 Days)
-- ============================================================
-- Business Question: Which approved bookings are scheduled
--   for the next 7 days, and which spaces will be occupied?
-- Target User: Facility Staff
-- Explanation: Staff use this to prepare rooms, ensure
--   equipment availability, and plan daily operations.
-- ============================================================
SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    u.full_name                                       AS requester,
    b.booking_type,
    b.requested_start_time,
    b.requested_end_time,
    b.expected_participants,
    b.purpose
FROM dbo.BOOKING b
INNER JOIN dbo.SPACE s ON s.space_code = b.space_code
INNER JOIN dbo.[USER] u ON u.user_id = b.user_id
WHERE b.status = 'approved'
  AND b.requested_start_time >= SYSDATETIME()
  AND b.requested_start_time < DATEADD(DAY, 7, SYSDATETIME())
ORDER BY b.requested_start_time ASC;
GO

-- ============================================================
-- Query 3: Space Utilization Rate (Past 30 Days)
-- ============================================================
-- Business Question: What percentage of total available time
--   was each space actually used over the past 30 days?
-- Target User: Facility Manager
-- Explanation: Helps management identify underutilized spaces
--   and make data-driven decisions about space allocation,
--   consolidation, or re-purposing.
-- ============================================================
WITH space_hours AS (
    SELECT
        s.space_code,
        s.space_name,
        s.capacity,
        SUM(DATEDIFF(HOUR,
            CASE WHEN b.requested_start_time >= DATEADD(DAY, -30, SYSDATETIME())
                 THEN b.requested_start_time
                 ELSE DATEADD(DAY, -30, SYSDATETIME())
            END,
            CASE WHEN b.actual_end_time IS NOT NULL
                 THEN b.actual_end_time
                 ELSE b.requested_end_time
            END
        )) AS booked_hours
    FROM dbo.SPACE s
    LEFT JOIN dbo.BOOKING b ON b.space_code = s.space_code
        AND b.status IN ('completed', 'checked_in', 'approved')
        AND b.requested_end_time > DATEADD(DAY, -30, SYSDATETIME())
    GROUP BY s.space_code, s.space_name, s.capacity
)
SELECT
    space_code,
    space_name,
    capacity,
    ISNULL(booked_hours, 0)                           AS booked_hours,
    720                                               AS total_available_hours,
    ROUND(100.0 * ISNULL(booked_hours, 0) / 720.0, 1) AS utilization_pct,
    CASE
        WHEN ROUND(100.0 * ISNULL(booked_hours, 0) / 720.0, 1) < 30.0 THEN 'Underutilized'
        WHEN ROUND(100.0 * ISNULL(booked_hours, 0) / 720.0, 1) < 60.0 THEN 'Moderate'
        ELSE 'Well Utilized'
    END AS utilization_category
FROM space_hours
ORDER BY utilization_pct DESC;
GO

-- ============================================================
-- Query 4: No-Show Booking Report
-- ============================================================
-- Business Question: Which bookings resulted in no-shows,
--   who made them, and which space was reserved?
-- Target User: Facility Staff, Department Administrator
-- Explanation: Identifying no-show patterns helps the school
--   enforce booking policies and potentially penalize
--   repeat offenders to ensure fair space access.
-- ============================================================
SELECT
    b.booking_id,
    u.full_name                                       AS requester_name,
    u.email                                           AS requester_email,
    u.department                                      AS requester_department,
    s.space_code,
    s.space_name,
    b.booking_type,
    b.requested_start_time,
    b.requested_end_time,
    b.expected_participants,
    b.purpose,
    us.checked_in_by,
    us.actual_start_time                              AS attempted_check_in_time,
    us.usage_notes
FROM dbo.BOOKING b
INNER JOIN dbo.[USER] u ON u.user_id = b.user_id
INNER JOIN dbo.SPACE s ON s.space_code = b.space_code
LEFT JOIN dbo.USAGE_SESSION us ON us.booking_id = b.booking_id
WHERE b.status = 'no_show'
ORDER BY b.requested_start_time DESC;
GO

-- ============================================================
-- Query 5: Active Maintenance Overview
-- ============================================================
-- Business Question: Which spaces are currently under active
--   maintenance, what is the problem, who is assigned, and
--   how long has the space been unavailable?
-- Target User: Facility Manager, Facility Staff
-- Explanation: Provides a real-time snapshot of all ongoing
--   maintenance work so managers can prioritize resources
--   and estimate when spaces will become available again.
-- ============================================================
SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    m.problem_type,
    m.problem_description,
    reporter.full_name                                AS reported_by,
    assigned.full_name                                AS assigned_to,
    m.start_time,
    DATEDIFF(DAY, m.start_time, SYSDATETIME())        AS days_since_start,
    m.status,
    m.result_note
FROM dbo.MAINTENANCE m
INNER JOIN dbo.SPACE s ON s.space_code = m.space_code
INNER JOIN dbo.[USER] reporter ON reporter.user_id = m.reporter_id
LEFT JOIN dbo.[USER] assigned ON assigned.user_id = m.assigned_staff_id
WHERE m.status IN ('reported', 'in_progress')
ORDER BY
    CASE m.status
        WHEN 'reported' THEN 1
        WHEN 'in_progress' THEN 2
    END,
    m.start_time ASC;
GO
