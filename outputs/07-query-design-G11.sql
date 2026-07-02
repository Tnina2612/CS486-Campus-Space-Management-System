--
-- Query 1: Space Utilization Report
-- Target Users: Facility Manager, Department Administrator
-- Usefulness: Shows the booking count, total booked hours, and utilization
-- rate per space. Helps identify underutilized spaces for reallocation
-- and overutilized spaces that may need scheduling restrictions.
--
SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.capacity,
    s.current_status,
    COUNT(b.booking_id) AS total_bookings,
    COALESCE(SUM(
        DATEDIFF(HOUR, b.requested_start, b.requested_end)
    ), 0) AS total_booked_hours,
    ROUND(
        COALESCE(SUM(
            DATEDIFF(HOUR, b.requested_start, b.requested_end)
        ), 0) * 100.0 /
        NULLIF(
            DATEDIFF(HOUR,
                (SELECT MIN(requested_start) FROM dbo.BOOKING),
                (SELECT MAX(requested_end) FROM dbo.BOOKING)
            ), 0
        ),
    2) AS utilization_pct
FROM dbo.SPACE s
LEFT JOIN dbo.BOOKING b ON s.space_code = b.space_code
    AND b.status NOT IN ('Cancelled', 'Rejected')
GROUP BY
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.capacity,
    s.current_status
ORDER BY total_booked_hours DESC;
GO

--
-- Query 2: Overlapping Booking Detection
-- Target Users: Facility Staff, Facility Manager
-- Usefulness: Identifies any approved bookings that overlap in time for the
-- same space. The application layer is meant to prevent these, but this query
-- serves as an audit check to catch data integrity issues.
--
WITH booking_ranges AS (
    SELECT
        booking_id,
        space_code,
        requested_start,
        requested_end,
        status,
        user_id
    FROM dbo.BOOKING
    WHERE status IN ('Approved', 'Checked In', 'Completed')
)
SELECT
    a.booking_id AS booking_a_id,
    b.booking_id AS booking_b_id,
    a.space_code,
    u1.full_name AS requester_a,
    u2.full_name AS requester_b,
    a.requested_start AS a_start,
    a.requested_end AS a_end,
    b.requested_start AS b_start,
    b.requested_end AS b_end
FROM booking_ranges a
INNER JOIN booking_ranges b
    ON a.space_code = b.space_code
    AND a.booking_id < b.booking_id
    AND a.requested_start < b.requested_end
    AND b.requested_start < a.requested_end
INNER JOIN dbo.[USER] u1 ON a.user_id = u1.user_id
INNER JOIN dbo.[USER] u2 ON b.user_id = u2.user_id
ORDER BY a.space_code, a.requested_start;
GO

--
-- Query 3: Facility Asset Inventory by Space
-- Target Users: Facility Manager, Facility Staff
-- Usefulness: Provides a complete inventory per space showing both
-- non-trackable facility counts (from SPACE_FACILITY) and individual
-- trackable asset details (from FACILITY_ASSET) using the hybrid catalog
-- pattern. Enables auditing of physical assets vs. catalog quantities.
--
SELECT
    s.space_code,
    s.space_name,
    fc.facility_name,
    fc.is_trackable,
    CASE WHEN fc.is_trackable = 1 THEN 'Trackable Asset' ELSE 'Non-Trackable' END AS asset_category,
    sf.quantity AS catalog_quantity,
    COUNT(fa.asset_id) AS registered_assets,
    CASE
        WHEN fc.is_trackable = 1 AND sf.quantity > COUNT(fa.asset_id)
            THEN 'MISMATCH: Missing assets'
        WHEN fc.is_trackable = 1 AND sf.quantity < COUNT(fa.asset_id)
            THEN 'MISMATCH: Extra assets'
        WHEN fc.is_trackable = 1 AND sf.quantity = COUNT(fa.asset_id)
            THEN 'OK'
        ELSE 'N/A'
    END AS inventory_status
FROM dbo.SPACE s
INNER JOIN dbo.SPACE_FACILITY sf ON s.space_code = sf.space_code
INNER JOIN dbo.FACILITY_CATALOG fc ON sf.catalog_id = fc.catalog_id
LEFT JOIN dbo.FACILITY_ASSET fa
    ON fa.space_code = sf.space_code
    AND fa.catalog_id = sf.catalog_id
GROUP BY
    s.space_code,
    s.space_name,
    fc.facility_name,
    fc.is_trackable,
    sf.quantity
ORDER BY s.space_code, fc.facility_name;
GO

--
-- Query 4: Maintenance Performance Report
-- Target Users: Facility Manager, Facility Staff
-- Usefulness: Analyzes maintenance workload and efficiency. Shows the
-- number of requests by type, current open issues, and average resolution
-- time for completed work. Helps identify recurring problems and staff
-- performance.
--
SELECT
    mr.problem_type,
    COUNT(mr.maintenance_id) AS total_requests,
    SUM(CASE WHEN mr.status IN ('Reported', 'In Progress') THEN 1 ELSE 0 END) AS open_issues,
    SUM(CASE WHEN mr.status = 'Completed' THEN 1 ELSE 0 END) AS resolved_issues,
    SUM(CASE WHEN mr.status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_issues,
    AVG(
        CASE
            WHEN mr.completion_time IS NOT NULL
                THEN DATEDIFF(HOUR, mr.start_time, mr.completion_time)
            ELSE NULL
        END
    ) AS avg_resolution_hours,
    MIN(
        CASE
            WHEN mr.completion_time IS NOT NULL
                THEN DATEDIFF(HOUR, mr.start_time, mr.completion_time)
            ELSE NULL
        END
    ) AS min_resolution_hours,
    MAX(
        CASE
            WHEN mr.completion_time IS NOT NULL
                THEN DATEDIFF(HOUR, mr.start_time, mr.completion_time)
            ELSE NULL
        END
    ) AS max_resolution_hours,
    STRING_AGG(
        CASE WHEN mr.status IN ('Reported', 'In Progress') THEN s.space_code ELSE NULL END,
        ', '
    ) WITHIN GROUP (ORDER BY s.space_code) AS affected_spaces
FROM dbo.MAINTENANCE_RECORD mr
INNER JOIN dbo.SPACE s ON mr.space_code = s.space_code
GROUP BY mr.problem_type
ORDER BY total_requests DESC;
GO

--
-- Query 5: User Booking Lifecycle Report
-- Target Users: Department Administrator, Facility Manager
-- Usefulness: Provides a complete view of a user's booking history including
-- the approval decision and usage session details. Enables auditing of the
-- full booking lifecycle from request to completion for any given user.
--
DECLARE @target_user_id NVARCHAR(50) = 'STU001';

SELECT
    b.booking_id,
    u.full_name AS requester,
    u.role AS requester_role,
    s.space_code,
    s.space_name,
    b.purpose,
    b.requested_start,
    b.requested_end,
    DATEDIFF(MINUTE, b.requested_start, b.requested_end) AS requested_duration_minutes,
    b.expected_participants,
    b.status AS booking_status,
    a.decision,
    a.decision_time,
    a.decision_note,
    a.rejection_reason,
    staff.full_name AS decision_maker,
    us.actual_start,
    us.actual_end,
    us.initial_condition,
    us.final_condition,
    us.usage_notes,
    checkin_staff.full_name AS checked_in_by_name,
    CASE
        WHEN b.status = 'No-show' THEN 'User did not arrive'
        WHEN us.actual_start IS NULL AND b.status NOT IN ('Cancelled', 'Rejected', 'No-show') THEN 'Awaiting check-in'
        WHEN us.actual_start IS NOT NULL AND us.actual_end IS NULL THEN 'In progress'
        WHEN us.actual_start IS NOT NULL AND us.actual_end IS NOT NULL THEN 'Completed'
        ELSE b.status
    END AS session_status_desc
FROM dbo.BOOKING b
INNER JOIN dbo.[USER] u ON b.user_id = u.user_id
INNER JOIN dbo.SPACE s ON b.space_code = s.space_code
LEFT JOIN dbo.APPROVAL a ON b.booking_id = a.booking_id
LEFT JOIN dbo.[USER] staff ON a.staff_id = staff.user_id
LEFT JOIN dbo.USAGE_SESSION us ON b.booking_id = us.booking_id
LEFT JOIN dbo.[USER] checkin_staff ON us.checked_in_by = checkin_staff.user_id
WHERE b.user_id = @target_user_id
ORDER BY b.requested_start DESC;
GO
