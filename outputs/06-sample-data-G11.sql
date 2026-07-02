-- ============================================================
-- Sample Data: Campus Space Management System
-- DBMS: Microsoft SQL Server
-- File: outputs/06-sample-data-G11.sql
-- ============================================================
-- This script inserts realistic test data and validates
-- business rules via TRY/CATCH blocks where applicable.
-- ============================================================

USE [CampusSpaceManagement];
GO

-- ============================================================
-- PHASE 1: Base Entities
-- ============================================================

-- ---------- USERS ----------
INSERT INTO dbo.[USER] (user_id, full_name, email, phone, role, department, account_status)
VALUES
    ('MGR001', 'John Smith',     'john.smith@university.edu', '+1-555-0101', 'Facility Manager',   'School of Computer Science', 'Active'),
    ('ADM001', 'Emily Davis',    'emily.davis@university.edu', '+1-555-0102', 'Dept Admin',         'School of Computer Science', 'Active'),
    ('LEC001', 'Michael Chen',   'michael.chen@university.edu', '+1-555-0103', 'Lecturer',           'School of Computer Science', 'Active'),
    ('LEC002', 'Anna Schmidt',   'anna.schmidt@university.edu', '+1-555-0104', 'Lecturer',           'School of Computer Science', 'Active'),
    ('TA001',  'Sarah Johnson',  'sarah.johnson@university.edu', '+1-555-0105', 'TA',                'School of Computer Science', 'Active'),
    ('STU001', 'David Kim',      'david.kim@university.edu',   '+1-555-0106', 'Student',            'School of Computer Science', 'Active'),
    ('STU002', 'Lisa Martinez',  'lisa.martinez@university.edu', '+1-555-0107', 'Student',           'School of Computer Science', 'Active'),
    ('STU003', 'Ahmed Hassan',   'ahmed.hassan@university.edu', '+1-555-0108', 'Student',            'School of Computer Science', 'Active'),
    ('STF001', 'Robert Wilson',  'robert.wilson@university.edu', '+1-555-0109', 'Facility Staff',    'School of Computer Science', 'Active'),
    ('STF002', 'James Brown',    'james.brown@university.edu', '+1-555-0110', 'Facility Staff',     'School of Computer Science', 'Active');
GO

-- ---------- SPACES ----------
INSERT INTO dbo.SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES
    ('ALAN-AUD',    'Alan Turing Auditorium',       'Auditorium',       'CS Building',   '1', 'A101', 200, 'Available',         'Public lectures, seminars, examinations, academic events'),
    ('ADA-LAB',     'Ada Lovelace Computer Lab',     'Computer Lab',     'CS Building',   '2', 'B201', 40,  'Available',         'Teaching, workshops, examinations requiring computers'),
    ('BOHR-MTG',    'Niels Bohr Meeting Room',       'Meeting Room',     'CS Building',   '3', 'C301', 12,  'Under Maintenance', 'Small meetings, supervision sessions'),
    ('CURIE-WKS',   'Marie Curie Student Workspace', 'Student Workspace','CS Building',   '1', 'A105', 20,  'Available',         'Student projects, group work, self-study'),
    ('DAVINCI-PRJ', 'Da Vinci Project Lab',          'Project Lab',      'CS Building',   '2', 'B205', 16,  'In Use',            'Research projects, capstone work'),
    ('EINSTEIN-CLS','Einstein Classroom',            'Classroom',        'CS Building',   '1', 'A110', 60,  'Temporarily Closed','Lectures, tutorials, examinations'),
    ('TESLA-RM',    'Nikola Tesla Seminar Room',     'Meeting Room',     'CS Building',   '3', 'C310', 25,  'Available',         'Seminars, workshops, training sessions');
GO

-- ---------- FACILITY CATALOG ----------
INSERT INTO dbo.FACILITY_CATALOG (facility_name, is_trackable)
VALUES
    ('Chair',                  0),
    ('Whiteboard',             0),
    ('Air Conditioner',        0),
    ('Desk',                   0),
    ('Projector',              1),
    ('Computer',               1),
    ('Microphone',             1),
    ('Livestreaming Equipment', 1);
GO

-- ============================================================
-- PHASE 2: Associative & Child Entities
-- ============================================================

-- ---------- FACILITY ASSETS (insert BEFORE SPACE_FACILITY to satisfy trigger) ----------
-- Projectors (catalog_id = 5)
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    (5, 'ALAN-AUD',    'PROJ-ALAN-001', 'Working'),
    (5, 'ADA-LAB',     'PROJ-ADA-001',  'Working'),
    (5, 'BOHR-MTG',    'PROJ-BOHR-001', 'Under Repair'),
    (5, 'DAVINCI-PRJ', 'PROJ-DAV-001',  'Working'),
    (5, 'TESLA-RM',    'PROJ-TES-001',  'Working');
GO

-- Computers (catalog_id = 6)
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    (6, 'ADA-LAB',     'PC-ADA-001', 'Working'),
    (6, 'ADA-LAB',     'PC-ADA-002', 'Working'),
    (6, 'ADA-LAB',     'PC-ADA-003', 'Working'),
    (6, 'CURIE-WKS',   'PC-CUR-001', 'Working'),
    (6, 'CURIE-WKS',   'PC-CUR-002', 'Working'),
    (6, 'CURIE-WKS',   'PC-CUR-003', 'Under Repair'),
    (6, 'DAVINCI-PRJ', 'PC-DAV-001', 'Working'),
    (6, 'DAVINCI-PRJ', 'PC-DAV-002', 'Working');
GO

-- Microphones (catalog_id = 7)
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    (7, 'ALAN-AUD',    'MIC-ALAN-001', 'Working'),
    (7, 'ALAN-AUD',    'MIC-ALAN-002', 'Working');
GO

-- Livestreaming Equipment (catalog_id = 8)
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    (8, 'ALAN-AUD',    'LS-ALAN-001', 'Working');
GO

-- ---------- SPACE_FACILITY ----------
-- Quantities for non-trackable items are arbitrary.
-- For trackable items, quantity MUST NOT exceed the COUNT of FACILITY_ASSET rows for that (space, catalog).

-- ALAN-AUD: Projector(5)x1, Microphone(7)x2, Chair(1)x200, Whiteboard(2)x1, Air Conditioner(3)x2, Livestreaming(8)x1
INSERT INTO dbo.SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('ALAN-AUD', 1, 200),
    ('ALAN-AUD', 2, 1),
    ('ALAN-AUD', 3, 2),
    ('ALAN-AUD', 5, 1),
    ('ALAN-AUD', 7, 2),
    ('ALAN-AUD', 8, 1);
GO

-- ADA-LAB: Computer(6)x30, Projector(5)x1, Chair(1)x40, Desk(4)x30
-- Only 3 computers exist in FACILITY_ASSET, so quantity must be 3 or less
INSERT INTO dbo.SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('ADA-LAB', 1, 40),
    ('ADA-LAB', 4, 30),
    ('ADA-LAB', 5, 1),
    ('ADA-LAB', 6, 3);
GO

-- BOHR-MTG: Projector(5)x1, Whiteboard(2)x1, Chair(1)x12, Air Conditioner(3)x1
INSERT INTO dbo.SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('BOHR-MTG', 1, 12),
    ('BOHR-MTG', 2, 1),
    ('BOHR-MTG', 3, 1),
    ('BOHR-MTG', 5, 1);
GO

-- CURIE-WKS: Computer(6)x3, Chair(1)x20, Desk(4)x20
INSERT INTO dbo.SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('CURIE-WKS', 1, 20),
    ('CURIE-WKS', 4, 20),
    ('CURIE-WKS', 6, 3);
GO

-- DAVINCI-PRJ: Computer(6)x2, Projector(5)x1, Chair(1)x16, Desk(4)x8, Whiteboard(2)x1
INSERT INTO dbo.SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('DAVINCI-PRJ', 1, 16),
    ('DAVINCI-PRJ', 2, 1),
    ('DAVINCI-PRJ', 4, 8),
    ('DAVINCI-PRJ', 5, 1),
    ('DAVINCI-PRJ', 6, 2);
GO

-- TESLA-RM: Projector(5)x1, Chair(1)x25, Whiteboard(2)x1, Air Conditioner(3)x1
INSERT INTO dbo.SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('TESLA-RM', 1, 25),
    ('TESLA-RM', 2, 1),
    ('TESLA-RM', 3, 1),
    ('TESLA-RM', 5, 1);
GO

-- ============================================================
-- PHASE 3: Transactional Entities
-- ============================================================

-- ---------- BOOKINGS ----------

-- [Testing: Normal approved booking] Lecturer Michael Chen books Einstein Classroom for a lecture
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('LEC001', 'EINSTEIN-CLS', '2026-09-15 09:00:00', '2026-09-15 11:00:00', 'Lecture', 50, 'Approved');
GO

-- [Testing: Normal pending booking] TA Sarah Johnson books Ada Lab for a seminar
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('TA001', 'ADA-LAB', '2026-09-16 14:00:00', '2026-09-16 16:00:00', 'Seminar', 30, 'Pending');
GO

-- [Testing: Rejected booking] Student David Kim books Bohr Meeting Room (under maintenance)
-- This demonstrates a rejected booking scenario
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('STU001', 'BOHR-MTG', '2026-09-20 10:00:00', '2026-09-20 11:00:00', 'Meeting', 8, 'Rejected');
GO

-- [Testing: Cancelled booking] Student Lisa Martinez cancels a workspace booking
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('STU002', 'CURIE-WKS', '2026-09-18 09:00:00', '2026-09-18 12:00:00', 'Student Activity', 5, 'Cancelled');
GO

-- [Testing: Checked-in booking] Lecturer Chen's session checked in by Robert Wilson
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('LEC002', 'TESLA-RM', '2026-09-17 10:00:00', '2026-09-17 12:00:00', 'Workshop', 20, 'Checked In');
GO

-- [Testing: Completed booking] Full lifecycle for Alan Turing Auditorium event
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('MGR001', 'ALAN-AUD', '2026-09-14 13:00:00', '2026-09-14 17:00:00', 'Seminar', 150, 'Completed');
GO

-- [Testing: No-show booking] Student Ahmed Hassan fails to show up
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('STU003', 'CURIE-WKS', '2026-09-12 08:00:00', '2026-09-12 10:00:00', 'Student Activity', 3, 'No-show');
GO

-- [Testing: Pending booking for future date]
INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
VALUES ('STU001', 'DAVINCI-PRJ', '2026-10-01 09:00:00', '2026-10-01 15:00:00', 'Student Activity', 10, 'Pending');
GO

-- ---------- APPROVALS ----------

-- [Testing BR-06: Rejection with reason] Booking 3 (STU001, BOHR-MTG) was rejected
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (3, 'STF001', 'Rejected', '2026-09-19 09:30:00', 'Space is under maintenance', 'The Niels Bohr Meeting Room is currently under maintenance and unavailable for booking until further notice.');
GO

-- [Testing: Approval] Booking 1 (LEC001, EINSTEIN-CLS) was approved
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (1, 'ADM001', 'Approved', '2026-09-14 08:00:00', 'Approved for lecture use', NULL);
GO

-- [Testing: Approval for checked-in booking] Booking 5 (LEC002, TESLA-RM)
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (5, 'STF001', 'Approved', '2026-09-16 14:00:00', 'Workshop approved', NULL);
GO

-- [Testing: Approval for completed booking] Booking 6 (MGR001, ALAN-AUD)
INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES (6, 'MGR001', 'Approved', '2026-09-13 10:00:00', 'Approved as facility manager', NULL);
GO

-- ---------- USAGE SESSIONS ----------

-- [Testing: Checked-in session] Booking 5 — checked in but not yet completed
INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start, initial_condition)
VALUES (5, 'STF001', '2026-09-17 10:05:00', 'Clean and tidy, all equipment functional');
GO

-- [Testing: Completed session] Booking 6 — full lifecycle
INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start, initial_condition, actual_end, final_condition, completed_by, usage_notes)
VALUES (6, 'STF002', '2026-09-14 13:00:00', 'Auditorium clean, projector working, all seats arranged',
        '2026-09-14 17:15:00', 'Auditorium tidy, projector turned off, lights off', 'STF002', 'Event ran smoothly. No issues reported.');
GO

-- ---------- MAINTENANCE RECORDS ----------

-- [Testing: Reported maintenance] Projector issue in Alan Turing Auditorium
INSERT INTO dbo.MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('ALAN-AUD', 'LEC001', 'STF001', 'Projector displays flickering image during presentations. Needs urgent inspection.', 'Broken Projector', '2026-09-10 11:00:00', NULL, 'Reported', NULL);
GO

-- [Testing: In-progress maintenance] AC failure in Da Vinci Project Lab
INSERT INTO dbo.MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('DAVINCI-PRJ', 'LEC002', 'STF002', 'Air conditioning not cooling. Temperature exceeds 30 deg C.', 'AC Failure', '2026-09-11 08:00:00', NULL, 'In Progress', NULL);
GO

-- [Testing: Completed maintenance] Cleaning issue in Bohr Meeting Room
INSERT INTO dbo.MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('BOHR-MTG', 'ADM001', 'STF001', 'Carpet stained and room has unpleasant odor. Requires deep cleaning.', 'Cleaning', '2026-09-08 09:00:00', '2026-09-09 16:00:00', 'Completed', 'Room cleaned, carpet shampooed, air freshener applied.');
GO

-- [Testing: Cancelled maintenance] Network problem reported but cancelled
INSERT INTO dbo.MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES ('TESLA-RM', 'STU001', NULL, 'WiFi not connecting in seminar room.', 'Network Problem', '2026-09-07 14:00:00', NULL, 'Cancelled', 'Resolved remotely — router was unplugged.');
GO

-- ============================================================
-- BUSINESS RULE VALIDATION TESTS
-- ============================================================

PRINT '====================================================';
PRINT 'BUSINESS RULE VALIDATION TESTS';
PRINT '====================================================';
GO

-- ----------------------------------------------------------
-- [TEST BR-06: Rejection requires reason]
-- Attempt to insert an APPROVAL with decision='Rejected' and NULL rejection_reason.
-- Expected: CHECK constraint violation.
-- ----------------------------------------------------------
PRINT 'TEST BR-06: Rejection requires reason';
GO
BEGIN TRY
    INSERT INTO dbo.APPROVAL (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
    VALUES (8, 'STF001', 'Rejected', GETDATE(), 'No reason given', NULL);
    PRINT 'FAIL: Insert should have been blocked by CHECK constraint.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked rejection without reason: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-12: End time must be after start time]
-- Attempt to insert a BOOKING where requested_end <= requested_start.
-- Expected: CHECK constraint violation.
-- ----------------------------------------------------------
PRINT 'TEST BR-12: End time must be after start time';
GO
BEGIN TRY
    INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
    VALUES ('STU001', 'TESLA-RM', '2026-10-05 10:00:00', '2026-10-05 09:00:00', 'Meeting', 5, 'Pending');
    PRINT 'FAIL: Insert should have been blocked by CHECK constraint.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked invalid time range: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-13: Maintenance completion after start]
-- Attempt to insert MAINTENANCE_RECORD where completion_time <= start_time.
-- Expected: CHECK constraint violation.
-- ----------------------------------------------------------
PRINT 'TEST BR-13: Maintenance completion after start';
GO
BEGIN TRY
    INSERT INTO dbo.MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)
    VALUES ('ALAN-AUD', 'STF001', NULL, 'Test', 'Cleaning', '2026-10-01 10:00:00', '2026-10-01 09:00:00', 'Completed', 'Test');
    PRINT 'FAIL: Insert should have been blocked by CHECK constraint.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked invalid maintenance time: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-07 / SPACE_FACILITY Trigger: Quantity must not exceed asset count]
-- Attempt to UPDATE quantity beyond available assets for a trackable item.
-- Expected: Trigger raises error and rolls back.
-- ----------------------------------------------------------
PRINT 'TEST Trigger: SPACE_FACILITY quantity exceeds asset count';
GO
BEGIN TRY
    -- ALAN-AUD has 1 projector asset (PROJ-ALAN-001). Try setting quantity=2.
    UPDATE dbo.SPACE_FACILITY SET quantity = 2
    WHERE space_code = 'ALAN-AUD' AND catalog_id = 5;
    PRINT 'FAIL: Update should have been blocked by trigger.';
END TRY
BEGIN CATCH
    PRINT 'PASS: Trigger blocked over-quantity update: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-07: Valid SPACE_FACILITY update after adding an asset]
-- Add another projector asset to ALAN-AUD, then update quantity to 2.
-- Expected: Trigger passes.
-- ----------------------------------------------------------
PRINT 'TEST Trigger: Adding asset then increasing quantity (should succeed)';
GO
INSERT INTO dbo.FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES (5, 'ALAN-AUD', 'PROJ-ALAN-002', 'Working');
GO
BEGIN TRY
    UPDATE dbo.SPACE_FACILITY SET quantity = 2
    WHERE space_code = 'ALAN-AUD' AND catalog_id = 5;
    PRINT 'PASS: Update succeeded after adding second projector asset.';
END TRY
BEGIN CATCH
    PRINT 'FAIL: Update should have succeeded: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-04 / BR-08: Unavailable space cannot be booked]
-- Attempt to insert BOOKING for BOHR-MTG (Under Maintenance).
-- Note: This is a DELEGATED_TO_APP rule. The CHECK constraints
-- on SPACE.current_status and MAINTENANCE_RECORD.status cannot
-- prevent this at the DB level. The application must reject it.
-- ----------------------------------------------------------
PRINT 'TEST BR-04/BR-08: Unavailable space (Under Maintenance) — application-level check (delegated)';
GO
BEGIN TRY
    INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
    VALUES ('STU002', 'BOHR-MTG', '2026-10-10 10:00:00', '2026-10-10 11:00:00', 'Meeting', 5, 'Pending');
    PRINT 'NOTE: Insert succeeded (DB does not prevent this — application must enforce rule).';
END TRY
BEGIN CATCH
    PRINT 'PASS: Booking blocked: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-03: No overlapping bookings for same space]
-- Attempt to insert a booking that overlaps with an approved booking
-- (Booking 1: EINSTEIN-CLS on 2026-09-15 09:00-11:00).
-- Note: This is a DELEGATED_TO_APP rule. The database does not
-- enforce this (no trigger for cross-row validation).
-- ----------------------------------------------------------
PRINT 'TEST BR-03: Overlapping booking prevention — application-level check (delegated)';
GO
BEGIN TRY
    INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
    VALUES ('STU003', 'EINSTEIN-CLS', '2026-09-15 10:00:00', '2026-09-15 12:00:00', 'Meeting', 10, 'Pending');
    PRINT 'NOTE: Insert succeeded (DB does not prevent this — application must enforce rule).';
END TRY
BEGIN CATCH
    PRINT 'PASS: Overlapping booking blocked: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-14: Capacity must be positive]
-- Attempt to insert a SPACE with capacity = 0.
-- Expected: CHECK constraint violation.
-- ----------------------------------------------------------
PRINT 'TEST BR-14: Capacity must be positive';
GO
BEGIN TRY
    INSERT INTO dbo.SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
    VALUES ('INVALID', 'Test Space', 'Meeting Room', 'CS Building', '1', 'T01', 0, 'Available', 'Test');
    PRINT 'FAIL: Insert should have been blocked by CHECK constraint.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked zero capacity: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST BR-15: Expected participants must be positive]
-- Attempt to insert a BOOKING with expected_participants = 0.
-- Expected: CHECK constraint violation.
-- ----------------------------------------------------------
PRINT 'TEST BR-15: Expected participants must be positive';
GO
BEGIN TRY
    INSERT INTO dbo.BOOKING (user_id, space_code, requested_start, requested_end, purpose, expected_participants, status)
    VALUES ('STU001', 'TESLA-RM', '2026-10-15 10:00:00', '2026-10-15 11:00:00', 'Meeting', 0, 'Pending');
    PRINT 'FAIL: Insert should have been blocked by CHECK constraint.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked zero participants: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST USAGE_SESSION completion: All fields must be set together]
-- Attempt to INSERT USAGE_SESSION with actual_end but NULL completed_by.
-- Expected: CHECK constraint violation.
-- ----------------------------------------------------------
PRINT 'TEST USAGE_SESSION: All completion fields must be set together';
GO
BEGIN TRY
    INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by, actual_start, initial_condition, actual_end, final_condition, completed_by, usage_notes)
    VALUES (8, 'STF001', '2026-10-01 10:00:00', 'Clean', '2026-10-01 12:00:00', 'Clean', NULL, 'Test');
    PRINT 'FAIL: Insert should have been blocked by CHECK constraint.';
END TRY
BEGIN CATCH
    PRINT 'PASS: CHECK constraint blocked partial completion: ' + ERROR_MESSAGE();
END CATCH
GO

-- ----------------------------------------------------------
-- [TEST Unique email constraint]
-- Attempt to insert USER with duplicate email.
-- Expected: UNIQUE constraint violation.
-- ----------------------------------------------------------
PRINT 'TEST Unique email constraint';
GO
BEGIN TRY
    INSERT INTO dbo.[USER] (user_id, full_name, email, phone, role, department, account_status)
    VALUES ('DUP001', 'Duplicate User', 'john.smith@university.edu', '+1-555-9999', 'Student', 'CS', 'Active');
    PRINT 'FAIL: Insert should have been blocked by UNIQUE constraint.';
END TRY
BEGIN CATCH
    PRINT 'PASS: UNIQUE constraint blocked duplicate email: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '====================================================';
PRINT 'ALL BUSINESS RULE TESTS COMPLETED';
PRINT '====================================================';
GO
