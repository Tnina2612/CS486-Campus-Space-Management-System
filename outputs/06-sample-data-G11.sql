-- ============================================================
-- Sample Data Preparation — Campus Space Management System
-- ============================================================
-- Step 6: Sample Data
-- Target: Microsoft SQL Server (T-SQL)
-- ============================================================

USE [CampusSpaceManagement];
GO

-- ============================================================
-- PHASE 1: Base Entities
-- ============================================================

-- -------------------------------------------------------
-- USERS — one per role + extras for testing
-- -------------------------------------------------------
INSERT INTO dbo.[USER] (user_id, full_name, email, phone_number, role, department, account_status)
VALUES
    ('U001', 'Emily Davis',      'emily.davis@university.edu', '+1-555-0101', 'student',                  'Computer Science', 'active'),
    ('U002', 'James Chen',       'james.chen@university.edu', '+1-555-0102', 'lecturer',                  'Computer Science', 'active'),
    ('U003', 'Sarah Kim',        'sarah.kim@university.edu',  '+1-555-0103', 'teaching_assistant',        'Computer Science', 'active'),
    ('U004', 'Mike O''Brien',    'mike.obrien@university.edu','+1-555-0104', 'facility_staff',            'Facilities',       'active'),
    ('U005', 'Dr. Lisa Park',    'lisa.park@university.edu',  '+1-555-0105', 'department_administrator',  'Computer Science', 'active'),
    ('U006', 'Robert Tanaka',    'robert.tanaka@university.edu','+1-555-0106','facility_manager',          'Facilities',       'active'),
    ('U007', 'Anna Schmidt',     'anna.schmidt@university.edu','+1-555-0107', 'student',                  'Computer Science', 'active'),
    ('U008', 'Carlos Garcia',    'carlos.garcia@university.edu','+1-555-0108','lecturer',                  'Computer Science', 'active'),
    ('U009', 'Inactive User',    'inactive@university.edu',   NULL,           'student',                  'Computer Science', 'inactive'),
    ('U010', 'Suspended User',   'suspended@university.edu',  NULL,           'student',                  'Computer Science', 'suspended');
GO

-- -------------------------------------------------------
-- SPACES — cover all current_status values including 'in_use'
-- -------------------------------------------------------
INSERT INTO dbo.SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES
    ('AUD-101', 'Alan Turing Auditorium',   'auditorium',          'Main Hall',    1, '101', 200, 'available',          'Lectures, seminars, and examinations only.'),
    ('CL-201',  'Ada Lovelace Classroom',   'classroom',           'CS Building',  2, '201', 40,  'available',          'Teaching, tutorials, and workshops.'),
    ('LAB-B101','Innovation Lab',           'computer_laboratory', 'CS Building',  1, 'B101',30,  'available',          'Programming labs and research activities.'),
    ('LAB-B102','Robotics Lab',             'project_laboratory',  'CS Building',  1, 'B102',20,  'under_maintenance',  'Project work — currently under maintenance.'),
    ('MT-301',  'Collaboration Hub',        'meeting_room',        'Main Hall',    3, '301', 12,  'temporarily_closed', 'Meetings and group discussions — closed for renovation.'),
    ('WS-001',  'Creative Workspace',       'student_workspace',   'CS Building',  2, '001', 15,  'available',          'Student project work and study groups.'),
    ('CL-202',  'Grace Hopper Classroom',   'classroom',           'CS Building',  2, '202', 35,  'retired',            'Decommissioned — no longer used.'),
    ('AUD-102', 'Dijkstra Lecture Hall',    'auditorium',          'Main Hall',    2, '201', 100, 'in_use',             'Currently occupied — lectures in progress.');
GO

-- -------------------------------------------------------
-- FACILITY_CATALOG
-- -------------------------------------------------------
INSERT INTO dbo.FACILITY_CATALOG (catalog_id, name, description, is_trackable)
VALUES
    ('CAT-PROJ',       'Projector',          'Standard HD projector',                           0),
    ('CAT-WHITE',      'Whiteboard',         'Mounted whiteboard with markers',                 0),
    ('CAT-COMP',       'Computer',           'Desktop workstation',                             1),
    ('CAT-AC',         'Air Conditioner',    'Split-system air conditioning unit',              0),
    ('CAT-MIC',        'Microphone',         'Wireless microphone system',                      0),
    ('CAT-LIVESTREAM', 'Livestream Equipment','Camera, encoder, and streaming hardware',         1);
GO

-- ============================================================
-- PHASE 2: Associative and Child Entities
-- ============================================================

-- -------------------------------------------------------
-- SPACE_FACILITY — quantity for non-trackable items
-- -------------------------------------------------------
INSERT INTO dbo.SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('AUD-101', 'CAT-PROJ', 2),
    ('AUD-101', 'CAT-AC',   4),
    ('AUD-101', 'CAT-MIC',  3),
    ('CL-201',  'CAT-PROJ', 1),
    ('CL-201',  'CAT-WHITE',1),
    ('LAB-B101','CAT-COMP', 25),
    ('LAB-B101','CAT-AC',   2),
    ('LAB-B102','CAT-COMP', 10),
    ('LAB-B102','CAT-AC',   1),
    ('WS-001',  'CAT-WHITE',1),
    ('MT-301',  'CAT-PROJ', 1),
    ('MT-301',  'CAT-AC',   2),
    ('CL-202',  'CAT-PROJ', 1),
    ('AUD-102', 'CAT-PROJ', 1),
    ('AUD-102', 'CAT-AC',   2),
    ('AUD-102', 'CAT-MIC',  2);
GO

-- -------------------------------------------------------
-- FACILITY_ASSET — trackable assets (computers, livestream gear)
-- -------------------------------------------------------
-- Computers in Innovation Lab (LAB-B101)
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    ('CAT-COMP', 'LAB-B101', 'COMP-001', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-002', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-003', 'under_repair'),
    ('CAT-COMP', 'LAB-B101', 'COMP-004', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-005', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-006', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-007', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-008', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-009', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-010', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-011', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-012', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-013', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-014', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-015', 'damaged'),
    ('CAT-COMP', 'LAB-B101', 'COMP-016', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-017', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-018', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-019', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-020', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-021', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-022', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-023', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-024', 'working'),
    ('CAT-COMP', 'LAB-B101', 'COMP-025', 'working');
GO

-- Computers in Robotics Lab (LAB-B102) — space is under maintenance
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    ('CAT-COMP', 'LAB-B102', 'COMP-026', 'working'),
    ('CAT-COMP', 'LAB-B102', 'COMP-027', 'working'),
    ('CAT-COMP', 'LAB-B102', 'COMP-028', 'damaged'),
    ('CAT-COMP', 'LAB-B102', 'COMP-029', 'working'),
    ('CAT-COMP', 'LAB-B102', 'COMP-030', 'working');
GO

-- Livestream equipment in Auditorium (AUD-101)
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    ('CAT-LIVESTREAM', 'AUD-101', 'LIVE-001', 'working'),
    ('CAT-LIVESTREAM', 'AUD-101', 'LIVE-002', 'working');
GO

-- ============================================================
-- PHASE 3: Transactional Entities (Bookings, Approvals, Sessions, Maintenance)
-- ============================================================

-- -------------------------------------------------------
-- BOOKINGS — Covering all status values and business rules
-- -------------------------------------------------------

-- [BR-07 / BR-08: Check-in and Check-out Lifecycle]
-- Booking 1: Approved, checked in, and completed (happy path)
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U002', 'CL-201', '2026-06-10 08:00:00', '2026-06-10 10:00:00', 'Database Systems Lecture — Week 1', 35, 'lecture', 'completed');
GO

-- [BR-05 / BR-06: Approval required; rejection reason stored]
-- Booking 2: Pending — awaiting approval
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U001', 'LAB-B101', '2026-06-11 14:00:00', '2026-06-11 17:00:00', 'Python Workshop for beginners', 20, 'workshop', 'pending');
GO

-- [BR-02: Overlap prevention — rejected due to time conflict]
-- Booking 3: Rejected because it overlaps with Booking 1 in CL-201
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U008', 'CL-201', '2026-06-10 09:00:00', '2026-06-10 11:00:00', 'AI Seminar — overlapping with existing booking', 30, 'seminar', 'rejected');
GO

-- [BR-03: Unavailable space blocked — under maintenance]
-- Booking 4: Rejected — space LAB-B102 is under maintenance
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U002', 'LAB-B102', '2026-06-12 10:00:00', '2026-06-12 12:00:00', 'Robotics practical session', 15, 'examination', 'rejected');
GO

-- [BR-03: Unavailable space blocked — temporarily closed]
-- Booking 5: Rejected — space MT-301 is temporarily closed
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U007', 'MT-301', '2026-06-15 13:00:00', '2026-06-15 15:00:00', 'Student project meeting', 10, 'meeting', 'rejected');
GO

-- [BR-03: Unavailable space blocked — retired]
-- Booking 6: Rejected — space CL-202 is retired
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U008', 'CL-202', '2026-06-16 09:00:00', '2026-06-16 11:00:00', 'Legacy course review', 25, 'lecture', 'rejected');
GO

-- [BR-07 / BR-08: Full check-in and check-out lifecycle]
-- Booking 7: Checked in and completed with session data
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U002', 'AUD-101', '2026-06-08 09:00:00', '2026-06-08 12:00:00', 'CS486 Final Examination', 150, 'examination', 'completed');
GO

-- Booking 8: Another completed booking
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U002', 'CL-201', '2026-06-09 13:00:00', '2026-06-09 15:00:00', 'Database Systems Lab — Section 2', 30, 'lecture', 'completed');
GO

-- [BR-04: Cancelled booking]
-- Booking 9: Cancelled by requester
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U001', 'WS-001', '2026-06-14 10:00:00', '2026-06-14 13:00:00', 'Group study session — cancelled', 8, 'student_activity', 'cancelled');
GO

-- [BR-04: No-show booking]
-- Booking 10: No-show — requester never checked in
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U007', 'CL-201', '2026-06-12 08:00:00', '2026-06-12 10:00:00', 'Study group reservation', 15, 'student_activity', 'no_show');
GO

-- Booking 11: Approved but not yet checked in
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U003', 'LAB-B101', '2026-06-20 14:00:00', '2026-06-20 17:00:00', 'TA office hours and tutoring', 10, 'meeting', 'approved');
GO

-- Booking 12: Currently checked in
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U001', 'WS-001', '2026-06-30 09:00:00', '2026-06-30 12:00:00', 'Capstone project work session', 6, 'student_activity', 'checked_in');
GO

-- Booking 13: Another pending booking
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U008', 'AUD-101', '2026-07-01 10:00:00', '2026-07-01 12:00:00', 'Guest lecture on AI Ethics', 180, 'lecture', 'pending');
GO

-- Booking 14: Administrative event (MT-301 closed, but this tests pending on closed space)
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
VALUES ('U005', 'MT-301', '2026-07-05 09:00:00', '2026-07-05 11:00:00', 'Department staff meeting — closed room', 10, 'administrative_event', 'pending');
GO

-- -------------------------------------------------------
-- APPROVALS — decisions on bookings
-- -------------------------------------------------------

-- [BR-05: Approval with staff and decision time]
-- Approval for Booking 1 (completed booking — was approved)
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (1, 'U004', 'approved', '2026-06-09 14:30:00', 'Approved for lecture as scheduled.', NULL);
GO

-- [BR-06: Rejection with reason — overlap with Booking 1]
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (3, 'U004', 'rejected', '2026-06-09 15:00:00', 'Time conflict with existing approved booking.', 'Requested time overlaps with Booking #1 in CL-201 (08:00–10:00).');
GO

-- [BR-03: Rejection — space under maintenance]
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (4, 'U006', 'rejected', '2026-06-11 09:00:00', 'Space is currently under maintenance.', 'Robotics Lab (LAB-B102) is under maintenance until further notice.');
GO

-- [BR-03: Rejection — temporarily closed]
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (5, 'U006', 'rejected', '2026-06-14 10:00:00', 'Space is temporarily closed for renovation.', 'Collaboration Hub (MT-301) is closed for renovation.');
GO

-- [BR-03: Rejection — retired space]
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (6, 'U006', 'rejected', '2026-06-15 11:00:00', 'Space has been decommissioned.', 'Grace Hopper Classroom (CL-202) has been retired and is no longer available.');
GO

-- Approval for Booking 7 (completed examination)
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (7, 'U005', 'approved', '2026-06-05 10:00:00', 'Approved for final examination.', NULL);
GO

-- Approval for Booking 8 (completed lecture)
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (8, 'U004', 'approved', '2026-06-08 11:00:00', 'Approved as scheduled.', NULL);
GO

-- Approval for Booking 11 (approved, not yet checked in)
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (11, 'U005', 'approved', '2026-06-18 09:00:00', 'Approved for TA office hours.', NULL);
GO

-- Approval for Booking 12 (currently checked in)
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (12, 'U004', 'approved', '2026-06-28 10:00:00', 'Approved for project work.', NULL);
GO

-- -------------------------------------------------------
-- USAGE_SESSIONS — check-in/check-out records
-- -------------------------------------------------------

-- [BR-07 / BR-08: Full check-in and check-out]
-- Session for Booking 1 (completed — full lifecycle)
INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, actual_end_time, final_condition, usage_notes)
VALUES (1, 'U004', '2026-06-10 08:05:00', 'Clean and tidy. Projector and whiteboard ready.', '2026-06-10 10:00:00', 'Room tidy. Whiteboard erased. Projector off.', 'Lecture completed on time.');
GO

-- Session for Booking 7 (completed examination)
INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, actual_end_time, final_condition, usage_notes)
VALUES (7, 'U004', '2026-06-08 09:00:00', 'All desks arranged. Microphones working.', '2026-06-08 12:15:00', 'Desks returned to original layout. Minor paper waste.', 'Examination completed. 150 students attended.');
GO

-- Session for Booking 8 (completed lecture)
INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, actual_end_time, final_condition, usage_notes)
VALUES (8, 'U004', '2026-06-09 13:00:00', 'Room clean. Projector functional.', '2026-06-09 15:10:00', 'Room clean. Projector turned off.', 'Lab session finished. All equipment accounted for.');
GO

-- [BR-04: No-show — recorded as minimal session]
-- Session for Booking 10 (no-show)
INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, actual_end_time, final_condition, usage_notes)
VALUES (10, 'U004', '2026-06-12 08:00:00', 'Room prepared as requested.', NULL, NULL, 'Requester did not show up. No session held.');
GO

-- Session for Booking 12 (currently checked in — no end time yet)
INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, actual_end_time, final_condition, usage_notes)
VALUES (12, 'U004', '2026-06-30 09:00:00', 'Workspace clean. Whiteboard markers available.', NULL, NULL, NULL);
GO

-- -------------------------------------------------------
-- MAINTENANCE RECORDS
-- -------------------------------------------------------

-- [BR-03 / BR-09: Maintenance blocking and history preservation]
-- Maintenance #1: In-progress for Robotics Lab (LAB-B102 — under_maintenance)
INSERT INTO dbo.MAINTENANCE (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('LAB-B102', 'U002', 'U004', 'Robotics workstations overheating and frequent crashes. Three computers non-functional.', 'ac_failure', '2026-06-05 08:00:00', NULL, 'in_progress', NULL);
GO

-- Maintenance #2: Completed maintenance for CL-201 (projector repair)
INSERT INTO dbo.MAINTENANCE (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('CL-201', 'U003', 'U004', 'Projector bulb blown — no image output.', 'broken_projector', '2026-06-01 10:00:00', '2026-06-02 16:00:00', 'completed', 'Replaced projector bulb. Tested and working.');
GO

-- Maintenance #3: Reported but not yet assigned for WS-001
INSERT INTO dbo.MAINTENANCE (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('WS-001', 'U007', NULL, 'Broken desk in the corner near window.', 'damaged_furniture', '2026-06-28 14:00:00', NULL, 'reported', NULL);
GO

-- Maintenance #4: Cancelled maintenance for MT-301
INSERT INTO dbo.MAINTENANCE (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('MT-301', 'U005', NULL, 'Network connectivity issues reported.', 'network_problem', '2026-05-20 09:00:00', NULL, 'cancelled', 'Issue resolved externally. No action needed.');
GO

-- Maintenance #5: Completed cleaning issue for AUD-101
INSERT INTO dbo.MAINTENANCE (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('AUD-101', 'U004', 'U004', 'Stains on seats and sticky floor near stage.', 'cleaning', '2026-06-15 07:00:00', '2026-06-15 12:00:00', 'completed', 'Deep cleaning performed. Seats and floor restored to satisfactory condition.');
GO

-- ============================================================
-- EDGE CASE TESTS: Trigger validation and constraint enforcement
-- ============================================================

-- [Testing BR-11 / Trigger: SPACE_FACILITY quantity vs FACILITY_ASSET count]
-- Attempting to UPDATE SPACE_FACILITY.quantity for a trackable catalog (CAT-COMP)
-- to a value exceeding the actual asset count for LAB-B101 (25 assets exist).
-- This should TRIGGER trg_space_facility_validate_quantity and ROLLBACK.
BEGIN TRY
    UPDATE dbo.SPACE_FACILITY
    SET quantity = 999
    WHERE space_code = 'LAB-B101' AND catalog_id = 'CAT-COMP';

    PRINT 'FAIL: Trigger did not prevent invalid quantity update.';
END TRY
BEGIN CATCH
    PRINT 'PASS: Trigger correctly blocked quantity exceeding asset count. Error: ' + ERROR_MESSAGE();
END CATCH
GO

-- [Testing BR-11: Valid quantity update for trackable catalog]
-- Updating SPACE_FACILITY.quantity for CAT-COMP in LAB-B101 to 20 (less than 25 assets).
-- This should succeed.
BEGIN TRY
    UPDATE dbo.SPACE_FACILITY
    SET quantity = 20
    WHERE space_code = 'LAB-B101' AND catalog_id = 'CAT-COMP';

    PRINT 'PASS: Valid quantity update succeeded.';
END TRY
BEGIN CATCH
    PRINT 'FAIL: Valid quantity update was blocked. Error: ' + ERROR_MESSAGE();
END CATCH
GO

-- [Testing BR-02 / CHECK: Time range constraint on BOOKING]
-- Attempting to insert a booking with end time before start time.
BEGIN TRY
    INSERT INTO dbo.BOOKING (user_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status)
    VALUES ('U001', 'CL-201', '2026-07-01 14:00:00', '2026-07-01 13:00:00', 'Invalid time range test', 10, 'meeting', 'pending');

    PRINT 'FAIL: CHECK constraint did not prevent inverted time range.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked inverted time range. Error: ' + ERROR_MESSAGE();
END CATCH
GO

-- [Testing BR-06 / CHECK: Rejection without reason]
-- Attempting to insert an approval with decision='rejected' but NULL rejection_reason.
BEGIN TRY
    INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
    VALUES (2, 'U004', 'rejected', '2026-06-11 10:00:00', 'Rejected.', NULL);

    PRINT 'FAIL: CHECK constraint did not prevent rejection without reason.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked rejection without reason. Error: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT 'Sample data insertion completed successfully.';
GO
