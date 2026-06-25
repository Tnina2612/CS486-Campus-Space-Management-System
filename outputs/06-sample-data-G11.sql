-- ============================================================
-- Sample Data Preparation — G11
-- DBMS: Microsoft SQL Server
-- ============================================================
USE [CampusSpaceManagement];
GO

-- ============================================================
-- 1. user (no FK dependencies)
-- ============================================================
SET IDENTITY_INSERT dbo.[user] ON;
GO

INSERT INTO dbo.[user] (user_id, full_name, email, phone_number, role, department, account_status)
VALUES
    (1, N'Nguyen Van A',   'nva@university.edu.vn',    '0901000001', 'Student',         N'Computer Science',     'Active'),
    (2, N'Tran Thi B',     'ttb@university.edu.vn',    '0901000002', 'Lecturer',         N'Computer Science',     'Active'),
    (3, N'Le Van C',       'lvc@university.edu.vn',    '0901000003', 'Facility Staff',   N'Facilities',           'Active'),
    (4, N'Pham Thi D',     'ptd@university.edu.vn',    '0901000004', 'Facility Manager', N'Facilities',           'Active'),
    (5, N'Hoang Van E',    'hve@university.edu.vn',    '0901000005', 'Student',          N'Computer Science',     'Active'),
    (6, N'Ngo Thi F',      'ntf@university.edu.vn',    '0901000006', 'Lecturer',         N'Information Systems',  'Active'),
    (7, N'Vu Van G',       'vvg@university.edu.vn',    '0901000007', 'Facility Staff',   N'Facilities',           'Active'),
    (8, N'Do Van H',       'dvh@university.edu.vn',    '0901000008', 'TA',               N'Computer Science',     'Active'),
    (9, N'Ly Thi I',       'lti@university.edu.vn',    '0901000009', 'Dept Admin',       N'Computer Science',     'Active'),
    (10, N'Tran Van K',    'tvk@university.edu.vn',    '0901000010', 'Student',          N'Computer Science',     'Inactive');

SET IDENTITY_INSERT dbo.[user] OFF;
GO

-- ============================================================
-- 2. space (no FK dependencies)
-- ============================================================
INSERT INTO dbo.space (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES
    ('A101', N'Auditorium A',      'Auditorium',        N'Building A', 1, '101', 200, 'Available',          N'Maximum capacity 200. No food or drinks.'),
    ('B201', N'Classroom B201',    'Classroom',         N'Building B', 2, '201',  50, 'Available',          N'Standard classroom. Whiteboard available.'),
    ('B202', N'Computer Lab 1',    'Computer Laboratory', N'Building B', 2, '202', 30, 'Under Maintenance',  N'30 workstations. No eating inside.'),
    ('C101', N'Meeting Room C',    'Meeting Room',      N'Building C', 1, '101',  15, 'Available',          N'Meeting room with smart TV.'),
    ('A102', N'Project Lab A',     'Project Laboratory',  N'Building A', 1, '102',  25, 'Available',        N'Student project workspace. 24/7 access.'),
    ('B101', N'Classroom B101',    'Classroom',         N'Building B', 1, '101',  40, 'Temporarily Closed', N'Under renovation.'),
    ('D201', N'Seminar Room D',    'Meeting Room',      N'Building D', 2, '201',  20, 'Retired',            N'No longer in service.');
GO

-- ============================================================
-- 3. facility_catalog
-- ============================================================
SET IDENTITY_INSERT dbo.facility_catalog ON;
GO

INSERT INTO dbo.facility_catalog (catalog_id, name, description, is_trackable)
VALUES
    (1, N'Projector',            N'HD projector for presentations',      1),
    (2, N'Whiteboard',           N'Whiteboard with markers',             0),
    (3, N'Microphone',           N'Wireless microphone system',          0),
    (4, N'Desktop Computer',     N'Desktop workstation',                 1),
    (5, N'Air Conditioner',      N'Air conditioning unit',               0),
    (6, N'Livestreaming Equipment', N'Camera and streaming setup',      1);

SET IDENTITY_INSERT dbo.facility_catalog OFF;
GO

-- ============================================================
-- 4. facility_asset (trackable items — must be BEFORE space_facility
--    because the trigger checks asset count against quantity)
-- ============================================================
SET IDENTITY_INSERT dbo.facility_asset ON;
GO

INSERT INTO dbo.facility_asset (asset_id, asset_tag, catalog_id, space_code, status)
VALUES
    -- Projectors (catalog_id=1)
    (1, 'PROJ-A101-001', 1, 'A101', 'Working'),
    (2, 'PROJ-B201-001', 1, 'B201', 'Working'),
    (3, 'PROJ-B202-001', 1, 'B202', 'Under Repair'),
    -- Desktop Computers (catalog_id=4) in B202
    (4, 'PC-B202-001', 4, 'B202', 'Working'),
    (5, 'PC-B202-002', 4, 'B202', 'Working'),
    (6, 'PC-B202-003', 4, 'B202', 'Working'),
    (7, 'PC-B202-004', 4, 'B202', 'Under Repair'),
    -- Desktop Computers (catalog_id=4) in A102
    (8, 'PC-A102-001', 4, 'A102', 'Working'),
    (9, 'PC-A102-002', 4, 'A102', 'Working'),
    (10, 'PC-A102-003', 4, 'A102', 'Working'),
    -- Livestreaming Equipment (catalog_id=6) in A101
    (11, 'LIVE-A101-001', 6, 'A101', 'Working');

SET IDENTITY_INSERT dbo.facility_asset OFF;
GO

-- ============================================================
-- 5. space_facility (M:N mapping — after facility_asset for trackable items)
--    Trackable quantities must match actual asset rows above.
-- ============================================================
INSERT INTO dbo.space_facility (space_code, catalog_id, quantity)
VALUES
    -- A101: 1 projector (trackable), 2 whiteboards, 2 microphones, 1 livestream equip (trackable)
    ('A101', 1, 1),
    ('A101', 2, 2),
    ('A101', 3, 2),
    ('A101', 6, 1),
    -- B201: 1 projector (trackable), 1 whiteboard
    ('B201', 1, 1),
    ('B201', 2, 1),
    -- B202: 1 projector (trackable), 1 whiteboard, 4 desktop computers (trackable)
    ('B202', 1, 1),
    ('B202', 2, 1),
    ('B202', 4, 4),
    -- C101: 1 whiteboard, 1 air conditioner
    ('C101', 2, 1),
    ('C101', 5, 1),
    -- A102: 2 whiteboards, 1 air conditioner, 3 desktop computers (trackable)
    ('A102', 2, 2),
    ('A102', 5, 1),
    ('A102', 4, 3);
GO

-- ============================================================
-- 6. booking_request
-- ============================================================
SET IDENTITY_INSERT dbo.booking_request ON;
GO

INSERT INTO dbo.booking_request (booking_id, requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, status, created_at)
VALUES
    (1, 1, 'B201', '2026-07-01 07:00:00', '2026-07-01 09:00:00', 'Lecture',           40, 'Approved',  '2026-06-20 08:00:00'),
    (2, 2, 'A101', '2026-07-02 14:00:00', '2026-07-02 17:00:00', 'Seminar',          120, 'Pending',   '2026-06-22 10:30:00'),
    (3, 4, 'C101', '2026-06-28 09:00:00', '2026-06-28 11:00:00', 'Meeting',           10, 'Approved',  '2026-06-25 09:00:00'),
    (4, 5, 'B202', '2026-06-30 13:00:00', '2026-06-30 16:00:00', 'Workshop',          20, 'Rejected',  '2026-06-23 14:00:00'),
    (5, 1, 'A102', '2026-07-03 08:00:00', '2026-07-03 12:00:00', 'Student Activity',  15, 'Checked In','2026-06-21 11:00:00'),
    (6, 6, 'B201', '2026-06-25 09:00:00', '2026-06-25 11:00:00', 'Examination',       35, 'Completed', '2026-06-18 07:30:00'),
    (7, 1, 'B202', '2026-07-05 10:00:00', '2026-07-05 12:00:00', 'Lecture',           25, 'Cancelled', '2026-06-24 16:00:00'),
    (8, 8, 'A102', '2026-07-04 13:00:00', '2026-07-04 15:00:00', 'Meeting',           10, 'No-Show',   '2026-06-26 09:00:00'),
    (9, 6, 'A101', '2026-07-10 08:00:00', '2026-07-10 12:00:00', 'Seminar',          150, 'Pending',   '2026-06-28 10:00:00'),
    (10, 2, 'C101','2026-07-06 14:00:00', '2026-07-06 16:00:00', 'Meeting',           12, 'Approved',  '2026-06-27 15:00:00');

SET IDENTITY_INSERT dbo.booking_request OFF;
GO

-- ============================================================
-- 7. booking_decision
-- ============================================================
INSERT INTO dbo.booking_decision (booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)
VALUES
    (1,  3, 'Approved', '2026-06-21 09:00:00', N'Approved for weekly lecture.', NULL),
    (4,  3, 'Rejected', '2026-06-24 10:00:00', N'Cannot approve.',              N'Room B202 is currently under maintenance for AC repair.'),
    (3,  4, 'Approved', '2026-06-26 08:00:00', N'Approved for faculty meeting.', NULL),
    (10, 4, 'Approved', '2026-06-28 10:00:00', N'Seminar preparation meeting.', NULL);
GO

-- ============================================================
-- 8. booking_session
-- ============================================================
INSERT INTO dbo.booking_session (booking_id, actual_start_time, checked_in_by, initial_condition, actual_end_time, final_condition, usage_notes)
VALUES
    (5, '2026-07-03 08:10:00', 3, N'Clean. All PCs working. Whiteboard clean.', NULL, NULL, NULL),
    (6, '2026-06-25 09:05:00', 3, N'Clean and organized.', '2026-06-25 11:00:00', N'All desks tidy. Whiteboard erased.', N'Examination completed on time.');
GO

-- ============================================================
-- 9. maintenance_record
-- ============================================================
SET IDENTITY_INSERT dbo.maintenance_record ON;
GO

INSERT INTO dbo.maintenance_record (maintenance_id, space_code, reported_by, assigned_to, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES
    (1, 'B202', 2, 3, N'Air conditioning not cooling. Temperature reaches 35C.', 'AC Failure', '2026-06-15 09:00:00', '2026-06-18 16:00:00', 'Completed', N'Replaced compressor. AC working normally.'),
    (2, 'B202', 1, 7, N'No internet connection in computer lab.', 'Network Problem', '2026-06-27 08:30:00', NULL, 'In Progress', N'Diagnosing network switch issue.'),
    (3, 'A101', 5, 3, N'Projector lamp flickering.', 'Broken Projector', '2026-06-28 14:00:00', NULL, 'Reported', NULL);

SET IDENTITY_INSERT dbo.maintenance_record OFF;
GO
