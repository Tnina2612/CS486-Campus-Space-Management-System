USE [CampusSpaceManagement];
GO

-- Query 1
-- Business Question: What is the full lifecycle of every booking — who requested it, was it approved, did they check in?
-- Target User: Facility Manager
-- Why Useful: Single view across the three normalized lifecycle tables, enabling bottleneck detection (e.g., pending without decision) and no-show identification.
SELECT
    b.booking_id,
    u.full_name                                                      AS requester,
    u.role                                                           AS requester_role,
    s.space_code,
    s.space_name,
    b.purpose,
    b.start_time                                                     AS requested_start,
    b.end_time                                                       AS requested_end,
    b.status                                                         AS booking_status,
    a.decision_time,
    a.rejection_reason,
    us.actual_start_time,
    us.actual_end_time,
    us.initial_condition,
    us.final_condition,
    us.usage_notes
FROM dbo.bookings b
INNER JOIN dbo.users u   ON b.user_id   = u.user_id
INNER JOIN dbo.spaces s  ON b.space_id  = s.space_id
LEFT JOIN dbo.approvals a        ON b.booking_id = a.booking_id
LEFT JOIN dbo.usage_sessions us  ON b.booking_id = us.booking_id
ORDER BY b.start_time DESC;
GO

-- Query 2
-- Business Question: Which spaces have the highest and lowest total booked hours?
-- Target User: Facility Manager
-- Why Useful: Informs capacity planning — identifies overused spaces that may need scheduling caps and underused spaces that could be repurposed.
SELECT
    s.space_code,
    s.space_name,
    s.building,
    s.capacity,
    s.current_status,
    COUNT(b.booking_id)                                              AS total_bookings,
    ISNULL(SUM(DATEDIFF(HOUR, b.start_time, b.end_time)), 0)        AS total_hours_booked,
    ISNULL(AVG(DATEDIFF(HOUR, b.start_time, b.end_time)), 0)        AS avg_hours_per_booking
FROM dbo.spaces s
LEFT JOIN dbo.bookings b ON s.space_id = b.space_id
GROUP BY s.space_code, s.space_name, s.building, s.capacity, s.current_status
ORDER BY total_hours_booked DESC;
GO

-- Query 3
-- Business Question: Which spaces have active maintenance work AND broken equipment at the same time?
-- Target User: Facility Staff
-- Why Useful: Cross-references maintenance work orders with physical asset conditions, helping staff bundle repair visits and fix both room infrastructure and equipment in one trip.
WITH active_maintenance AS (
    SELECT
        mr.space_id,
        mr.maintenance_id,
        mr.problem_description,
        mr.start_time                                               AS maint_start,
        mr.status                                                   AS maint_status
    FROM dbo.maintenance_records mr
    WHERE mr.status IN ('Reported', 'Assigned', 'In Progress')
),
broken_assets AS (
    SELECT
        fa.space_id,
        fa.asset_tag,
        fa.status                                                   AS asset_status,
        fc.facility_name
    FROM dbo.facility_assets fa
    INNER JOIN dbo.facility_catalog fc ON fa.catalog_id = fc.catalog_id
    WHERE fa.status <> 'Good'
)
SELECT
    s.space_code,
    s.space_name,
    s.building,
    am.maintenance_id,
    am.problem_description,
    am.maint_status,
    ba.asset_tag,
    ba.asset_status,
    ba.facility_name
FROM dbo.spaces s
LEFT JOIN active_maintenance am ON s.space_id = am.space_id
LEFT JOIN broken_assets ba      ON s.space_id = ba.space_id
WHERE am.maintenance_id IS NOT NULL
   OR ba.asset_tag IS NOT NULL
ORDER BY s.space_code;
GO

-- Query 4
-- Business Question: Which users waste bookable capacity through cancellations or no-shows?
-- Target User: Department Administrator
-- Why Useful: Identifies repeat offenders for policy enforcement (e.g., automated reminders or booking restrictions after multiple no-shows).
SELECT
    u.user_id,
    u.full_name,
    u.role,
    u.department,
    COUNT(b.booking_id)                                                AS total_bookings,
    SUM(CASE WHEN b.status = 'Cancelled' THEN 1 ELSE 0 END)           AS cancelled_count,
    SUM(CASE WHEN b.status = 'No-show'   THEN 1 ELSE 0 END)           AS no_show_count,
    SUM(CASE WHEN b.status IN ('Cancelled', 'No-show') THEN 1 ELSE 0 END) AS wasted_total
FROM dbo.users u
INNER JOIN dbo.bookings b ON u.user_id = b.user_id
GROUP BY u.user_id, u.full_name, u.role, u.department
HAVING SUM(CASE WHEN b.status IN ('Cancelled', 'No-show') THEN 1 ELSE 0 END) > 0
ORDER BY wasted_total DESC;
GO

-- Query 5
-- Business Question: What is the complete facility inventory for each space — combining catalog-level quantities with actual tracked assets?
-- Target User: Facility Staff
-- Why Useful: Consolidates the hybrid catalog/asset pattern into a single report, showing both planned quantities and physical asset counts side by side.
SELECT
    s.space_code,
    s.space_name,
    fc.facility_name,
    fc.is_trackable,
    sf.quantity                                                     AS catalog_quantity,
    ISNULL(asset_counts.registered_assets, 0)                       AS tracked_asset_count
FROM dbo.spaces s
INNER JOIN dbo.space_facility sf ON s.space_id = sf.space_id
INNER JOIN dbo.facility_catalog fc ON sf.catalog_id = fc.catalog_id
LEFT JOIN (
    SELECT space_id, catalog_id, COUNT(*) AS registered_assets
    FROM dbo.facility_assets
    GROUP BY space_id, catalog_id
) asset_counts ON sf.space_id   = asset_counts.space_id
              AND sf.catalog_id = asset_counts.catalog_id
ORDER BY s.space_code, fc.facility_name;
GO
