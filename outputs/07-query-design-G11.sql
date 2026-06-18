-- =============================================================
-- CS486 Campus Space Management System
-- Query Design — 5 meaningful business queries for SQL Server
-- =============================================================

-- =============================================================
-- QUERY 1: Find all available spaces with their facilities for a given time slot
--
-- Business Question: "Which spaces are currently available (not under maintenance,
--   not closed, not retired) and what facilities do they offer?"
-- Target Users: Facility staff, department administrators, facility manager
-- Explanation: Helps staff quickly identify bookable spaces and their amenities
--   when processing booking requests. Also useful for the booking UI.
-- =============================================================
SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    f.facility_name
FROM space s
LEFT JOIN space_facility sf ON s.space_code = sf.space_code
LEFT JOIN facility f ON sf.facility_id = f.facility_id
WHERE s.current_status = 'available'
ORDER BY s.building, s.floor, s.room_number, f.facility_name;

-- =============================================================
-- QUERY 2: Get booking history for a specific space with approval and session details
--
-- Business Question: "Show me the complete booking history for Auditorium A101,
--   including who requested it, who approved/rejected it, and actual usage data."
-- Target Users: Facility manager, facility staff, department administrator
-- Explanation: Provides a full audit trail for a space, useful for utilization
--   analysis, conflict investigation, and historical reporting.
-- =============================================================
SELECT
    br.booking_id,
    requester.full_name              AS requester_name,
    br.purpose,
    br.requested_start_time,
    br.requested_end_time,
    br.expected_participants,
    br.[status]                      AS booking_status,
    approver.full_name               AS decision_maker,
    ba.decision,
    ba.decision_time,
    ba.decision_note,
    ba.rejection_reason,
    bs.actual_start_time,
    checkin_staff.full_name          AS checkin_staff,
    bs.initial_condition,
    bs.actual_end_time,
    checkout_staff.full_name         AS checkout_staff,
    bs.final_condition,
    bs.usage_notes
FROM booking_request br
INNER JOIN [user] requester ON br.requester_id = requester.user_id
LEFT JOIN booking_approval ba ON br.booking_id = ba.booking_id
LEFT JOIN [user] approver ON ba.staff_id = approver.user_id
LEFT JOIN booking_session bs ON br.booking_id = bs.booking_id
LEFT JOIN [user] checkin_staff ON bs.checkin_by = checkin_staff.user_id
LEFT JOIN [user] checkout_staff ON bs.completed_by = checkout_staff.user_id
WHERE br.space_code = 'A101'
ORDER BY br.requested_start_time DESC;

-- =============================================================
-- QUERY 3: List spaces currently under active maintenance with issue details
--
-- Business Question: "Which spaces are currently unavailable due to maintenance,
--   what problems do they have, who is assigned, and how long have they been down?"
-- Target Users: Facility staff, facility manager
-- Explanation: Enables facility staff to monitor ongoing maintenance tasks,
--   prioritize repairs, and inform users about space unavailability.
-- =============================================================
SELECT
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    mr.maintenance_id,
    reporter.full_name               AS reporter_name,
    assigned.full_name               AS assigned_staff,
    mr.problem_type,
    mr.problem_description,
    mr.start_time,
    DATEDIFF(DAY, mr.start_time, GETDATE()) AS days_since_reported,
    mr.[status]                      AS maintenance_status,
    mr.result_note
FROM space s
INNER JOIN maintenance_record mr ON s.space_code = mr.space_code
INNER JOIN [user] reporter ON mr.reporter_id = reporter.user_id
LEFT JOIN [user] assigned ON mr.assigned_staff_id = assigned.user_id
WHERE mr.[status] IN ('reported', 'in_progress')
ORDER BY mr.start_time DESC;

-- =============================================================
-- QUERY 4: Find overlapping booking requests (potential conflicts)
--
-- Business Question: "Are there any booking requests that conflict with
--   already-approved bookings in the same space?"
-- Target Users: Facility staff, facility manager
-- Explanation: Detects scheduling conflicts that the system should prevent.
--   Useful for auditing and testing the overlap-prevention logic.
--   Self-joins booking_request to find pairs of approved bookings
--   on the same space with overlapping time ranges.
-- =============================================================
SELECT DISTINCT
    br1.booking_id      AS booking_id_1,
    u1.full_name        AS requester_1,
    br1.space_code,
    br1.requested_start_time AS start_1,
    br1.requested_end_time   AS end_1,
    br2.booking_id      AS booking_id_2,
    u2.full_name        AS requester_2,
    br2.requested_start_time AS start_2,
    br2.requested_end_time   AS end_2
FROM booking_request br1
INNER JOIN booking_request br2
    ON br1.space_code = br2.space_code
    AND br1.booking_id < br2.booking_id
    AND br1.requested_start_time < br2.requested_end_time
    AND br2.requested_start_time < br1.requested_end_time
INNER JOIN [user] u1 ON br1.requester_id = u1.user_id
INNER JOIN [user] u2 ON br2.requester_id = u2.user_id
WHERE br1.[status] IN ('approved', 'checked_in', 'completed')
  AND br2.[status] IN ('approved', 'checked_in', 'completed')
ORDER BY br1.space_code, br1.requested_start_time;

-- =============================================================
-- QUERY 5: No-show booking report
--
-- Business Question: "Which bookings resulted in no-shows, who made them,
--   for which space, and what was the purpose?"
-- Target Users: Facility manager, facility staff
-- Explanation: Identifies patterns of no-show behavior, which helps the school
--   determine whether to adjust booking policies or follow up with users who
--   habitually fail to show up for their reserved spaces.
-- =============================================================
SELECT
    br.booking_id,
    u.full_name          AS requester_name,
    u.email              AS requester_email,
    u.[role]             AS requester_role,
    br.space_code,
    s.space_name,
    s.space_type,
    br.purpose,
    br.requested_start_time,
    br.requested_end_time,
    br.expected_participants,
    br.submitted_at
FROM booking_request br
INNER JOIN [user] u ON br.requester_id = u.user_id
INNER JOIN space s ON br.space_code = s.space_code
WHERE br.[status] = 'no_show'
ORDER BY br.requested_start_time DESC;
