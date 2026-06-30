-- ====================================================================
-- 06-sample-data-G11.sql
-- Sample Data — Campus Space Management System
-- DBMS: Microsoft SQL Server
-- ====================================================================
-- Insertion order follows FK dependencies:
--   Phase 1: Base entities (USER, SPACE, FACILITY_CATALOG)
--   Phase 2a: FACILITY_ASSET (trackable assets — inserted BEFORE
--             SPACE_FACILITY so the trigger sees matching counts)
--   Phase 2b: SPACE_FACILITY (associative with quantities)
--   Phase 3:  Transactional entities (BOOKING, APPROVAL,
--             USAGE_SESSION, MAINTENANCE_RECORD)
-- ====================================================================

USE [CampusSpaceManagement];
GO

-- ====================================================================
-- PHASE 1: BASE ENTITIES
-- ====================================================================

-- ---------------------------------------------------------------
-- 1. USERS (all 6 roles covered)
-- ---------------------------------------------------------------
-- [Testing: BR9 - Unique email per user]
INSERT INTO [USER] (full_name, email, phone, role, department, account_status)
VALUES
    ('Emily Davis',     'emily.davis@university.edu', '+1-555-0101', 'lecturer',                 'Computer Science', 'active'),
    ('James Chen',      'james.chen@university.edu',  '+1-555-0102', 'student',                  'Computer Science', 'active'),
    ('Sarah Ahmed',     'sarah.ahmed@university.edu', '+1-555-0103', 'teaching_assistant',       'Computer Science', 'active'),
    ('Michael Brown',   'michael.brown@university.edu','+1-555-0104', 'facility_staff',           'Facility Services','active'),
    ('Anna Kowalski',   'anna.kowalski@university.edu','+1-555-0105', 'department_administrator', 'Computer Science', 'active'),
    ('Robert Taylor',   'robert.taylor@university.edu','+1-555-0106', 'facility_manager',         'Facility Services','active'),
    ('Lisa Wang',       'lisa.wang@university.edu',   '+1-555-0107', 'student',                  'Computer Science', 'active'),
    ('David Kim',       'david.kim@university.edu',   '+1-555-0108', 'lecturer',                 'Computer Science', 'active'),
    ('Maria Garcia',    'maria.garcia@university.edu','+1-555-0109', 'facility_staff',           'Facility Services','active');
GO
-- User IDs: Emily=1, James=2, Sarah=3, Michael=4, Anna=5, Robert=6, Lisa=7, David=8, Maria=9

-- ---------------------------------------------------------------
-- 2. SPACES (all 5 status values covered)
-- ---------------------------------------------------------------
INSERT INTO SPACE (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES
    ('LT001', 'Alan Turing Auditorium',  'auditorium',   'A', 1, 'A101', 200, 'available',          'Lectures, seminars, exams only.'),
    ('CR101', 'Computer Lab 101',        'computer_lab', 'B', 1, 'B101',  40, 'available',          'Computer science classes and labs.'),
    ('CR102', 'Project Lab 102',         'project_lab',  'B', 2, 'B201',  25, 'available',          'Student projects and research.'),
    ('MR201', 'Meeting Room 201',        'meeting_room', 'A', 2, 'A202',  15, 'under_maintenance',   'Staff meetings only.'),
    ('CR103', 'Classroom 103',           'classroom',    'B', 1, 'B103',  50, 'in_use',              'General teaching and exams.'),
    ('WS001', 'Student Workspace',       'workspace',    'C', 1, 'C101',  30, 'available',          'Open student workspace.'),
    ('CR104', 'Classroom 104',           'classroom',    'B', 2, 'B201',  45, 'temporarily_closed',  'Currently closed for renovation.'),
    ('MR202', 'Meeting Room 202',        'meeting_room', 'A', 3, 'A301',  10, 'retired',             'No longer in service.');
GO
-- Note: MR201 = under_maintenance, CR103 = in_use, CR104 = temporarily_closed, MR202 = retired

-- ---------------------------------------------------------------
-- 3. FACILITY_CATALOG (mix of trackable and non-trackable)
-- ---------------------------------------------------------------
INSERT INTO FACILITY_CATALOG (facility_name, description, is_trackable)
VALUES
    ('Projector',              'HD multimedia projector',               1),
    ('Whiteboard',             'Standard whiteboard with markers',      0),
    ('Computer',               'Desktop computer workstation',          1),
    ('Air Conditioner',        'Split-type air conditioning unit',      0),
    ('Microphone',             'Wireless handheld microphone',          0),
    ('Livestreaming Equipment','Professional livestream camera kit',    1);
GO
-- Catalog IDs: Projector=1, Whiteboard=2, Computer=3, AC=4, Mic=5, Livestream=6

-- ====================================================================
-- PHASE 2a: FACILITY_ASSET (trackable assets — inserted first for
--            SPACE_FACILITY trigger validation)
-- ====================================================================

-- [Testing: BR6 - Trackable vs non-trackable]
-- [Testing: BR7 - Unique asset tag]

-- Projectors (catalog_id=1) — one per space that has one
INSERT INTO FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES
    (1, 'LT001', 'LT001-PROJ-001', 'available'),
    (1, 'CR101', 'CR101-PROJ-001', 'available'),
    (1, 'CR102', 'CR102-PROJ-001', 'available'),
    (1, 'MR201', 'MR201-PROJ-001', 'under_maintenance'),
    (1, 'CR103', 'CR103-PROJ-001', 'available'),
    (1, 'CR104', 'CR104-PROJ-001', 'available');
GO

-- Computers (catalog_id=3) — 40 in CR101, 15 in CR102
DECLARE @i INT = 1;
WHILE @i <= 40
BEGIN
    INSERT INTO FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
    VALUES (3, 'CR101', 'CR101-COMP-' + RIGHT('00' + CAST(@i AS VARCHAR(3)), 3), 'available');
    SET @i = @i + 1;
END;
GO

DECLARE @j INT = 1;
WHILE @j <= 15
BEGIN
    INSERT INTO FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
    VALUES (3, 'CR102', 'CR102-COMP-' + RIGHT('00' + CAST(@j AS VARCHAR(3)), 3), 'available');
    SET @j = @j + 1;
END;
GO

-- Livestreaming Equipment (catalog_id=6) — 1 in LT001
INSERT INTO FACILITY_ASSET (catalog_id, space_code, asset_tag, status)
VALUES (6, 'LT001', 'LT001-LIVE-001', 'available');
GO

-- ====================================================================
-- PHASE 2b: SPACE_FACILITY (associative — quantities must match
--            FACILITY_ASSET counts for trackable items)
-- ====================================================================

-- [Testing: BR6 - Trackable vs non-trackable quantity management]

-- LT001: Projector(1), Whiteboard(2), Microphone(2), AC(2), Livestream(1)
INSERT INTO SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('LT001', 1, 1),  -- Projector (trackable) — 1 asset
    ('LT001', 2, 2),  -- Whiteboard
    ('LT001', 5, 2),  -- Microphone
    ('LT001', 4, 2),  -- Air Conditioner
    ('LT001', 6, 1);  -- Livestreaming (trackable) — 1 asset
GO

-- CR101: Projector(1), Whiteboard(1), Computer(40), AC(2)
INSERT INTO SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('CR101', 1, 1),   -- Projector (trackable) — 1 asset
    ('CR101', 2, 1),   -- Whiteboard
    ('CR101', 3, 40),  -- Computer (trackable) — 40 assets
    ('CR101', 4, 2);   -- Air Conditioner
GO

-- CR102: Projector(1), Whiteboard(1), Computer(15), AC(1)
INSERT INTO SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('CR102', 1, 1),   -- Projector (trackable) — 1 asset
    ('CR102', 2, 1),   -- Whiteboard
    ('CR102', 3, 15),  -- Computer (trackable) — 15 assets
    ('CR102', 4, 1);   -- Air Conditioner
GO

-- MR201: Projector(1), Whiteboard(2), AC(1)
INSERT INTO SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('MR201', 1, 1),  -- Projector (trackable) — 1 asset (under maintenance)
    ('MR201', 2, 2),  -- Whiteboard
    ('MR201', 4, 1);  -- Air Conditioner
GO

-- CR103: Projector(1), Whiteboard(1), AC(2)
INSERT INTO SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('CR103', 1, 1),  -- Projector (trackable) — 1 asset
    ('CR103', 2, 1),  -- Whiteboard
    ('CR103', 4, 2);  -- Air Conditioner
GO

-- WS001: Whiteboard(2), AC(1)
INSERT INTO SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('WS001', 2, 2),  -- Whiteboard
    ('WS001', 4, 1);  -- Air Conditioner
GO

-- CR104: Projector(1), Whiteboard(1), AC(1)
INSERT INTO SPACE_FACILITY (space_code, catalog_id, quantity)
VALUES
    ('CR104', 1, 1),  -- Projector (trackable) — 1 asset
    ('CR104', 2, 1),  -- Whiteboard
    ('CR104', 4, 1);  -- Air Conditioner
GO

-- ====================================================================
-- PHASE 3: TRANSACTIONAL ENTITIES
-- ====================================================================

-- ---------------------------------------------------------------
-- 4. BOOKING + APPROVAL + USAGE_SESSION
-- ---------------------------------------------------------------

---------------------------------------------------------------
-- SCENARIO A: Full lifecycle — pending → approved → checked_in
--             → completed  (happy path)
-- [Testing: BR3 - Status lifecycle]
-- [Testing: BR4 - 1-to-1 booking ↔ approval]
-- [Testing: BR5 - 1-to-1 booking ↔ usage session]
-- [Testing: BR11 - Time validity (start < end)]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (1, 'CR103', '2026-07-01 09:00:00', '2026-07-01 11:00:00', 'lecture', 45, 'approved', '2026-06-20 08:00:00');
-- booking_id = 1

INSERT INTO APPROVAL (booking_id, reviewer_id, decision_time, decision_note, rejection_reason)
VALUES (1, 4, '2026-06-21 10:00:00', 'Approved for regular lecture slot.', NULL);

INSERT INTO USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, checked_out_by, actual_end_time, final_condition, usage_notes)
VALUES (1, 4, '2026-07-01 09:05:00', 'Clean, all equipment functional.', 4, '2026-07-01 11:10:00', 'Clean, projector turned off.', 'Lecture ended on time.');
GO

---------------------------------------------------------------
-- SCENARIO B: Rejected booking due to time overlap
-- [Testing: BR1 - No overlapping approved bookings for same space]
-- [Testing: BR4 - Booking ↔ approval with rejection_reason]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (2, 'CR103', '2026-07-01 09:30:00', '2026-07-01 11:30:00', 'examination', 30, 'rejected', '2026-06-22 14:00:00');
-- booking_id = 2 — overlaps with approved booking 1 in CR103

INSERT INTO APPROVAL (booking_id, reviewer_id, decision_time, decision_note, rejection_reason)
VALUES (2, 4, '2026-06-23 09:00:00', NULL, 'Time conflict with an existing approved lecture booking (ID=1) in the same space.');
GO

---------------------------------------------------------------
-- SCENARIO C: Pending booking (awaiting approval)
-- [Testing: BR3 - pending status]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (7, 'LT001', '2026-07-05 14:00:00', '2026-07-05 17:00:00', 'seminar', 150, 'pending', '2026-06-25 11:00:00');
-- booking_id = 3
GO

---------------------------------------------------------------
-- SCENARIO D: Cancelled booking (requester cancelled)
-- [Testing: BR3 - cancelled status]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (2, 'WS001', '2026-06-15 10:00:00', '2026-06-15 12:00:00', 'student_activity', 20, 'cancelled', '2026-06-10 09:00:00');
-- booking_id = 4
GO

---------------------------------------------------------------
-- SCENARIO E: No-show booking
-- [Testing: BR3 - no-show status]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (7, 'CR101', '2026-06-20 13:00:00', '2026-06-20 15:00:00', 'workshop', 25, 'no_show', '2026-06-15 10:00:00');
-- booking_id = 5
GO

---------------------------------------------------------------
-- SCENARIO F: Checked-in but not yet checked out
-- [Testing: BR5 - 1-to-1 usage session (partial)]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (3, 'CR102', '2026-07-02 10:00:00', '2026-07-02 12:00:00', 'lecture', 20, 'checked_in', '2026-06-28 08:30:00');
-- booking_id = 6

INSERT INTO APPROVAL (booking_id, reviewer_id, decision_time, decision_note, rejection_reason)
VALUES (6, 4, '2026-06-29 09:00:00', 'Approved for project lab session.', NULL);

INSERT INTO USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, checked_out_by, actual_end_time, final_condition, usage_notes)
VALUES (6, 4, '2026-07-02 10:10:00', 'Computers running, room tidy.', NULL, NULL, NULL, NULL);
GO

---------------------------------------------------------------
-- SCENARIO G: Booking rejected for space under maintenance
-- [Testing: BR2 - Unavailable spaces cannot be booked]
-- [Testing: BR8 - Maintenance blocks booking]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (8, 'MR201', '2026-07-10 09:00:00', '2026-07-10 11:00:00', 'meeting', 10, 'rejected', '2026-07-01 08:00:00');
-- booking_id = 7 — MR201 is under_maintenance

INSERT INTO APPROVAL (booking_id, reviewer_id, decision_time, decision_note, rejection_reason)
VALUES (7, 6, '2026-07-01 10:00:00', NULL, 'Space is currently under maintenance. Cannot approve booking.');
GO

---------------------------------------------------------------
-- SCENARIO H: Capacity at limit — expected_participants = 40
--             for CR101 (capacity=40)
-- [Testing: BR10 - Capacity check (application-level)]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (1, 'CR101', '2026-07-03 08:00:00', '2026-07-03 10:00:00', 'examination', 40, 'approved', '2026-06-30 07:00:00');
-- booking_id = 8

INSERT INTO APPROVAL (booking_id, reviewer_id, decision_time, decision_note, rejection_reason)
VALUES (8, 4, '2026-07-01 09:00:00', 'Approved — capacity matches participant count.', NULL);
GO

---------------------------------------------------------------
-- SCENARIO I: Historical booking (completed in the past)
-- [Testing: BR12 - History preservation]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (8, 'LT001', '2026-06-01 09:00:00', '2026-06-01 12:00:00', 'lecture', 180, 'completed', '2026-05-20 08:00:00');
-- booking_id = 9

INSERT INTO APPROVAL (booking_id, reviewer_id, decision_time, decision_note, rejection_reason)
VALUES (9, 4, '2026-05-21 10:00:00', 'Approved for guest lecture.', NULL);

INSERT INTO USAGE_SESSION (booking_id, checked_in_by, actual_start_time, initial_condition, checked_out_by, actual_end_time, final_condition, usage_notes)
VALUES (9, 9, '2026-06-01 09:00:00', 'Auditorium clean, AV checked.', 9, '2026-06-01 12:15:00', 'All equipment returned.', 'Guest lecture by industry speaker.');
GO

---------------------------------------------------------------
-- SCENARIO J: Admin event booking
-- [Testing: All purpose values covered — administrative_event]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (5, 'MR201', '2026-08-01 09:00:00', '2026-08-01 11:00:00', 'administrative_event', 10, 'pending', '2026-07-25 08:00:00');
-- booking_id = 10
GO

---------------------------------------------------------------
-- SCENARIO K: Booking for temporarily closed space (rejected)
-- [Testing: BR2 - Temporarily closed space cannot be booked]
---------------------------------------------------------------
INSERT INTO BOOKING (requester_id, space_code, requested_start, requested_end, purpose, expected_participants, status, created_at)
VALUES (2, 'CR104', '2026-08-15 09:00:00', '2026-08-15 11:00:00', 'workshop', 30, 'rejected', '2026-08-01 08:00:00');
-- booking_id = 11 — CR104 is temporarily_closed

INSERT INTO APPROVAL (booking_id, reviewer_id, decision_time, decision_note, rejection_reason)
VALUES (11, 4, '2026-08-02 09:00:00', NULL, 'Space is temporarily closed for renovation.');
GO

-- ====================================================================
-- 5. MAINTENANCE_RECORDS
-- ====================================================================

-- [Testing: BR8 - Maintenance blocks booking]
-- Active maintenance on MR201 (currently in_progress)
INSERT INTO MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_category, start_time, completion_time, status, result_note)
VALUES
    ('MR201', 1, 4, 'Projector lamp burnt out and air conditioner not cooling.', 'ac_failure', '2026-06-15 08:00:00', NULL, 'in_progress', NULL);
GO

-- Completed maintenance record on CR103 (historical)
INSERT INTO MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_category, start_time, completion_time, status, result_note)
VALUES
    ('CR103', 8, 9, 'Network ports not working at 3 workstations.', 'network', '2026-05-10 09:00:00', '2026-05-12 16:00:00', 'completed', 'Replaced faulty network switch. All ports functional.');
GO

-- Reported maintenance on projector in MR201 (not yet assigned)
INSERT INTO MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_category, start_time, completion_time, status, result_note)
VALUES
    ('MR201', 1, NULL, 'Projector image is flickering intermittently.', 'broken_projector', '2026-06-20 10:00:00', NULL, 'reported', NULL);
GO

-- Cancelled maintenance record on WS001
INSERT INTO MAINTENANCE_RECORD (space_code, reporter_id, assigned_staff_id, problem_description, problem_category, start_time, completion_time, status, result_note)
VALUES
    ('WS001', 7, NULL, 'Whiteboard marker stains reported.', 'cleaning', '2026-06-01 09:00:00', NULL, 'cancelled', 'Resolved by cleaning staff without formal maintenance.');
GO

-- ====================================================================
-- END OF SAMPLE DATA
-- ====================================================================
