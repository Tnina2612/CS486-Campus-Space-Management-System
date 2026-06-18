-- =============================================================
-- CS486 Campus Space Management System
-- Sample Data Preparation
-- Insert order respects foreign key dependencies
-- =============================================================

-- =============================================================
-- USERS (8 users)
-- =============================================================
INSERT INTO [user] (full_name, email, phone_number, [role], department, account_status) VALUES
(N'Alice Johnson',    N'alice.johnson@university.edu', N'0901000001', N'student',                 N'School of Computer Science',      N'active'),
(N'Bob Smith',        N'bob.smith@university.edu',     N'0901000002', N'lecturer',                N'School of Computer Science',      N'active'),
(N'Carol White',      N'carol.white@university.edu',  N'0901000003', N'teaching_assistant',      N'School of Computer Science',      N'active'),
(N'David Brown',      N'david.brown@university.edu',  N'0901000004', N'facility_staff',          N'School of Computer Science',      N'active'),
(N'Eve Davis',        N'eve.davis@university.edu',    N'0901000005', N'facility_manager',        N'School of Computer Science',      N'active'),
(N'Frank Wilson',     N'frank.wilson@university.edu', N'0901000006', N'department_administrator', N'School of Computer Science',      N'active'),
(N'Grace Lee',        N'grace.lee@university.edu',    N'0901000007', N'student',                 N'School of Computer Science',      N'active'),
(N'Henry Taylor',     N'henry.taylor@university.edu', N'0901000008', N'lecturer',                N'Department of Mathematics',       N'active');

-- =============================================================
-- SPACES (10 spaces)
-- =============================================================
INSERT INTO space (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy) VALUES
(N'A101', N'Auditorium A101',   N'auditorium',       N'Building A', 1, N'101', 200, N'available',         N'No food or drinks. Must vacate by 22:00.'),
(N'A102', N'Classroom A102',    N'classroom',        N'Building A', 1, N'102', 50,  N'available',         N'Standard classroom policy.'),
(N'B201', N'Computer Lab B201', N'computer_lab',     N'Building B', 2, N'201', 40,  N'available',         N'Login required. No software installation.'),
(N'B202', N'Project Lab B202',  N'project_lab',      N'Building B', 2, N'202', 20,  N'available',         N'Authorized students only.'),
(N'C301', N'Meeting Room C301', N'meeting_room',     N'Building C', 3, N'301', 12,  N'available',         N'Max 2-hour booking.'),
(N'C302', N'Student Workspace', N'student_workspace',N'Building C', 3, N'302', 30,  N'available',         N'First-come first-served.'),
(N'A103', N'Classroom A103',    N'classroom',        N'Building A', 1, N'103', 35,  N'under_maintenance', N'Under renovation.'),
(N'B203', N'Computer Lab B203', N'computer_lab',     N'Building B', 2, N'203', 30,  N'temporarily_closed',N'Closed for equipment upgrade.'),
(N'C303', N'Meeting Room C303', N'meeting_room',     N'Building C', 3, N'303', 8,   N'available',         N'Small meeting room.'),
(N'D401', N'Auditorium D401',   N'auditorium',       N'Building D', 4, N'401', 150, N'retired',           N'Permanently decommissioned.');

-- =============================================================
-- FACILITIES (8 types)
-- =============================================================
INSERT INTO facility (facility_name, [description]) VALUES
(N'Projector',              N'HD projector with HDMI and VGA input'),
(N'Whiteboard',             N'Standard whiteboard with markers'),
(N'Microphone',             N'Wireless microphone system'),
(N'Computer',               N'Desktop computer with monitor'),
(N'Livestreaming Equipment',N'Camera and streaming setup'),
(N'Air Conditioner',        N'Split-type air conditioning unit'),
(N'Speaker System',         N'Surround sound speaker system'),
(N'WiFi Router',            N'High-speed wireless access point');

-- =============================================================
-- SPACE_FACILITY (associate spaces with facilities)
-- =============================================================
INSERT INTO space_facility (space_code, facility_id) VALUES
(N'A101', 1), (N'A101', 2), (N'A101', 3), (N'A101', 5), (N'A101', 6), (N'A101', 7), (N'A101', 8),
(N'A102', 1), (N'A102', 2), (N'A102', 6), (N'A102', 8),
(N'B201', 1), (N'B201', 2), (N'B201', 4), (N'B201', 6), (N'B201', 8),
(N'B202', 2), (N'B202', 4), (N'B202', 6),
(N'C301', 1), (N'C301', 2), (N'C301', 6), (N'C301', 8),
(N'C302', 2), (N'C302', 6), (N'C302', 8),
(N'C303', 2), (N'C303', 6),
(N'A103', 1), (N'A103', 2), (N'A103', 6),
(N'B203', 1), (N'B203', 4), (N'B203', 6),
(N'D401', 1), (N'D401', 6), (N'D401', 7);

-- =============================================================
-- BOOKING_REQUESTS (12 requests covering different scenarios)
-- =============================================================

-- 1. Approved and completed booking (Bob lecture in A101)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(2, N'A101', '2026-06-20 08:00:00', '2026-06-20 10:00:00', N'lecture', 150, N'completed', '2026-06-17 09:00:00');

-- 2. Approved and checked-in booking (Alice student activity in B202)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(1, N'B202', '2026-06-21 14:00:00', '2026-06-21 17:00:00', N'student_activity', 15, N'checked_in', '2026-06-18 10:30:00');

-- 3. Approved pending check-in (Carol seminar in C301)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(3, N'C301', '2026-06-22 09:00:00', '2026-06-22 11:00:00', N'seminar', 10, N'approved', '2026-06-19 14:00:00');

-- 4. Pending approval (Henry meeting in C303)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(8, N'C303', '2026-06-23 15:00:00', '2026-06-23 16:00:00', N'meeting', 6, N'pending', '2026-06-20 08:00:00');

-- 5. Rejected booking (Grace requesting A103 but it is under maintenance)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(7, N'A103', '2026-06-24 10:00:00', '2026-06-24 12:00:00', N'examination', 30, N'rejected', '2026-06-18 11:00:00');

-- 6. Rejected booking (Alice requesting B203 but it is temporarily closed)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(1, N'B203', '2026-06-25 09:00:00', '2026-06-25 12:00:00', N'workshop', 25, N'rejected', '2026-06-19 09:00:00');

-- 7. Cancelled booking (Frank cancelled his own request)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(6, N'C301', '2026-06-26 13:00:00', '2026-06-26 15:00:00', N'administrative_event', 10, N'cancelled', '2026-06-18 16:00:00');

-- 8. No-show booking (Grace never showed up)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(7, N'C302', '2026-06-19 08:00:00', '2026-06-19 10:00:00', N'student_activity', 5, N'no_show', '2026-06-15 12:00:00');

-- 9. Approved but future booking (Bob workshop in B201)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(2, N'B201', '2026-07-01 08:00:00', '2026-07-01 12:00:00', N'workshop', 35, N'approved', '2026-06-20 10:00:00');

-- 10. Pending for a space that currently has no conflict (Carol examination in A102)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(3, N'A102', '2026-07-02 09:00:00', '2026-07-02 11:00:00', N'examination', 40, N'pending', '2026-06-21 08:00:00');

-- 11. Approved and completed older booking (Bob lecture in A102 — history record)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(2, N'A102', '2026-06-10 08:00:00', '2026-06-10 10:00:00', N'lecture', 45, N'completed', '2026-06-07 09:00:00');

-- 12. Alice booking an already-retired space D401 (should be rejected at application level)
INSERT INTO booking_request (requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, [status], submitted_at) VALUES
(1, N'D401', '2026-07-03 10:00:00', '2026-07-03 12:00:00', N'lecture', 100, N'rejected', '2026-06-21 09:00:00');

-- =============================================================
-- BOOKING_APPROVALS
-- =============================================================

-- 1. Bob's lecture in A101 — approved by Eve (facility manager)
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(1, 5, N'approved', '2026-06-17 14:00:00', N'Approved. Standard lecture slot.', NULL);

-- 2. Alice's student activity in B202 — approved by David (facility staff)
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(2, 4, N'approved', '2026-06-18 15:00:00', N'Approved for student project work.', NULL);

-- 3. Carol's seminar in C301 — approved by Eve
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(3, 5, N'approved', '2026-06-19 16:00:00', N'Seminar approved.', NULL);

-- 5. Grace's exam in A103 — rejected by Eve (under maintenance)
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(5, 5, N'rejected', '2026-06-18 14:00:00', N'Space is not available.', N'Room A103 is currently under maintenance. Please choose another room.');

-- 6. Alice's workshop in B203 — rejected by David (temporarily closed)
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(6, 4, N'rejected', '2026-06-19 14:00:00', N'Room is temporarily closed.', N'B203 is closed for equipment upgrade. Expected reopening in July.');

-- 9. Bob's workshop in B201 — approved by Eve
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(9, 5, N'approved', '2026-06-20 15:00:00', N'Approved for workshop.', NULL);

-- 11. Bob's old lecture in A102 — approved by David
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(11, 4, N'approved', '2026-06-07 14:00:00', N'Approved.', NULL);

-- 12. Alice's request for retired D401 — rejected by Eve
INSERT INTO booking_approval (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason) VALUES
(12, 5, N'rejected', '2026-06-21 11:00:00', N'Space permanently decommissioned.', N'Room D401 has been retired and cannot be booked.');

-- =============================================================
-- BOOKING_SESSIONS
-- =============================================================

-- 1. Bob's A101 lecture — completed
INSERT INTO booking_session (booking_id, actual_start_time, checkin_by, initial_condition, actual_end_time, completed_by, final_condition, usage_notes) VALUES
(1, '2026-06-20 08:05:00', 4, N'Clean, all equipment functioning.', '2026-06-20 10:10:00', 4, N'Clean, projector turned off.', N'Lecture went smoothly. 148 attendees.');

-- 2. Alice's B202 activity — checked in, not yet checked out
INSERT INTO booking_session (booking_id, actual_start_time, checkin_by, initial_condition, actual_end_time, completed_by, final_condition, usage_notes) VALUES
(2, '2026-06-21 14:10:00', 4, N'Lab clean, computers on.', NULL, NULL, NULL, NULL);

-- 11. Bob's old A102 lecture — completed (historical)
INSERT INTO booking_session (booking_id, actual_start_time, checkin_by, initial_condition, actual_end_time, completed_by, final_condition, usage_notes) VALUES
(11, '2026-06-10 08:00:00', 4, N'Room tidy, whiteboard clean.', '2026-06-10 10:05:00', 4, N'Whiteboard used, otherwise fine.', N'Standard lecture. 42 students.');

-- =============================================================
-- MAINTENANCE_RECORDS
-- =============================================================

-- A103 is under maintenance — broken projector
INSERT INTO maintenance_record (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, [status], result_note) VALUES
(N'A103', 2, 4, N'Projector lamp burnt out and image is distorted.', N'broken_projector', '2026-06-14 10:00:00', NULL, N'in_progress', N'Ordered replacement lamp. Estimated arrival next week.');

-- B203 is temporarily closed — network upgrade
INSERT INTO maintenance_record (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, [status], result_note) VALUES
(N'B203', 5, 4, N'Network infrastructure upgrade for all computer lab machines.', N'network_problem', '2026-06-10 08:00:00', NULL, N'in_progress', N'Upgrade in progress. All 30 machines being reimaged.');

-- A101 AC failure (historical — now completed)
INSERT INTO maintenance_record (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, [status], result_note) VALUES
(N'A101', 1, 4, N'Air conditioner not cooling. Temperature above 30°C.', N'ac_failure', '2026-06-01 09:00:00', '2026-06-03 16:00:00', N'completed', N'AC repaired. Compressor replaced and gas refilled.');

-- C302 damaged furniture
INSERT INTO maintenance_record (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, [status], result_note) VALUES
(N'C302', 7, NULL, N'Three chairs broken and one table has a cracked surface.', N'damaged_furniture', '2026-06-18 14:00:00', NULL, N'reported', N'Awaiting inspection.');

-- C303 — cleaning issue
INSERT INTO maintenance_record (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, [status], result_note) VALUES
(N'C303', 3, 4, N'Room has unpleasant odor and trash not removed.', N'cleaning_issue', '2026-06-16 11:00:00', '2026-06-16 15:00:00', N'completed', N'Room cleaned and sanitized.');
