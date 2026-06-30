-- ====================================================================
-- 07-query-design-G11.sql
-- Query Design — Campus Space Management System
-- DBMS: Microsoft SQL Server
-- ====================================================================

USE [CampusSpaceManagement];
GO

-- ====================================================================
-- QUERY 1: Upcoming approved bookings per space
-- ====================================================================
-- Business Question:
--   Which spaces have approved or checked-in bookings starting from
--   today onwards, and who are the requesters?
-- Target User(s):
--   Facility staff who need to prepare rooms before sessions.
-- Usefulness:
--   Allows staff to see a daily schedule of which spaces will be used,
--   by whom, and for what purpose, so they can prepare equipment,
--   unlock rooms, and plan cleaning.
SELECT
    s.space_code,
    s.space_name,
    u.full_name  AS requester_name,
    u.email      AS requester_email,
    b.requested_start,
    b.requested_end,
    b.purpose,
    b.expected_participants
FROM BOOKING b
INNER JOIN SPACE s ON s.space_code = b.space_code
INNER JOIN [USER] u ON u.user_id = b.requester_id
WHERE b.status IN ('approved', 'checked_in')
  AND b.requested_start >= CAST(GETDATE() AS DATETIME2)
ORDER BY b.requested_start ASC;
GO

-- ====================================================================
-- QUERY 2: Full booking audit trail (request → approval → session)
-- ====================================================================
-- Business Question:
--   What is the complete lifecycle of every booking from initial
--   request through approval to actual room usage?
-- Target User(s):
--   Facility manager, department administrator — auditing and
--   dispute resolution.
-- Usefulness:
--   Provides a single view linking the booking request, the approval
--   decision, and the physical usage session. Essential for tracing
--   what happened when a discrepancy arises (e.g., a room was approved
--   but never used).
SELECT
    b.booking_id,
    requester.full_name       AS requester,
    s.space_code,
    s.space_name,
    b.purpose,
    b.requested_start,
    b.requested_end,
    b.status                  AS booking_status,
    reviewer.full_name        AS reviewer,
    a.decision_time,
    a.decision_note,
    a.rejection_reason,
    staff_in.full_name        AS checked_in_by,
    us.actual_start_time,
    us.initial_condition,
    staff_out.full_name       AS checked_out_by,
    us.actual_end_time,
    us.final_condition,
    us.usage_notes
FROM BOOKING b
INNER JOIN SPACE s ON s.space_code = b.space_code
INNER JOIN [USER] requester ON requester.user_id = b.requester_id
LEFT JOIN APPROVAL a ON a.booking_id = b.booking_id
LEFT JOIN [USER] reviewer ON reviewer.user_id = a.reviewer_id
LEFT JOIN USAGE_SESSION us ON us.booking_id = b.booking_id
LEFT JOIN [USER] staff_in ON staff_in.user_id = us.checked_in_by
LEFT JOIN [USER] staff_out ON staff_out.user_id = us.checked_out_by
ORDER BY b.created_at DESC;
GO

-- ====================================================================
-- QUERY 3: Active maintenance issues with space and staff details
-- ====================================================================
-- Business Question:
--   Which spaces currently have unresolved maintenance issues, what
--   is the problem, and who is assigned?
-- Target User(s):
--   Facility manager monitoring workload; facility staff viewing
--   their assignments.
-- Usefulness:
--   Provides a real-time view of all active (reported/in_progress)
--   maintenance records so management can prioritise repairs and
--   communicate space unavailability to booking staff.
SELECT
    mr.maintenance_id,
    s.space_code,
    s.space_name,
    s.room_number,
    s.building,
    reporter.full_name    AS reported_by,
    assigned.full_name    AS assigned_to,
    mr.problem_category,
    mr.problem_description,
    mr.start_time,
    mr.status             AS maintenance_status
FROM MAINTENANCE_RECORD mr
INNER JOIN SPACE s ON s.space_code = mr.space_code
INNER JOIN [USER] reporter ON reporter.user_id = mr.reporter_id
LEFT JOIN [USER] assigned ON assigned.user_id = mr.assigned_staff_id
WHERE mr.status IN ('reported', 'in_progress')
ORDER BY mr.start_time DESC;
GO

-- ====================================================================
-- QUERY 4: No-show booking list
-- ====================================================================
-- Business Question:
--   Which bookings resulted in a no-show, and which users and spaces
--   were involved?
-- Target User(s):
--   Facility staff, facility manager — to identify missed bookings
--   and follow up with requesters.
-- Usefulness:
--   Provides a detailed list of all no-show bookings so the school
--   can track space wastage and inform policy decisions (e.g.,
--   contacting habitual no-show users).
SELECT
    b.booking_id,
    u.full_name           AS requester_name,
    u.email               AS requester_email,
    u.role                AS requester_role,
    s.space_code,
    s.space_name,
    b.requested_start,
    b.requested_end,
    b.purpose,
    b.expected_participants,
    b.created_at          AS request_created_at
FROM BOOKING b
INNER JOIN [USER] u ON u.user_id = b.requester_id
INNER JOIN SPACE s ON s.space_code = b.space_code
WHERE b.status = 'no_show'
ORDER BY b.requested_start DESC;
GO

-- ====================================================================
-- QUERY 5: Facility inventory per space (trackable assets +
--          non-trackable catalog quantities)
-- ====================================================================
-- Business Question:
--   What facilities are installed in each space, broken down by
--   trackable assets (individual tagged items) and non-trackable
--   quantities?
-- Target User(s):
--   Facility manager, facility staff conducting equipment audits.
-- Usefulness:
--   Implements the "Catalog vs. Asset Hybrid Pattern" by combining
--   both inventory views in one report. Staff can see both how many
--   whiteboards (non-trackable) and which individual computers
--   (trackable) exist per space.
SELECT
    s.space_code,
    s.space_name,
    fc.facility_name,
    fc.is_trackable,
    CASE
        WHEN fc.is_trackable = 0 THEN CAST(sf.quantity AS NVARCHAR(10))
        ELSE NULL
    END AS non_trackable_quantity,
    CASE
        WHEN fc.is_trackable = 1 THEN fa.asset_tag
        ELSE NULL
    END AS trackable_asset_tag,
    CASE
        WHEN fc.is_trackable = 1 THEN fa.status
        ELSE NULL
    END AS asset_status
FROM SPACE s
INNER JOIN SPACE_FACILITY sf ON sf.space_code = s.space_code
INNER JOIN FACILITY_CATALOG fc ON fc.catalog_id = sf.catalog_id
LEFT JOIN FACILITY_ASSET fa ON fa.catalog_id = sf.catalog_id
    AND fa.space_code = s.space_code
ORDER BY s.space_code, fc.facility_name, fa.asset_tag;
GO

-- ====================================================================
-- END OF QUERY DESIGN
-- ====================================================================
