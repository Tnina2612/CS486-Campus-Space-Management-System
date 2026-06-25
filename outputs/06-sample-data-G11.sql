-- ============================================================
-- Campus Space Management System - Sample Data
-- Group: G11
-- DBMS: Microsoft SQL Server
-- ============================================================
-- Insertion order:
--   1. [user]
--   2. space
--   3. facility_catalog
--   4. facility_asset  (BEFORE space_facility — trigger constraint)
--   5. space_facility
--   6. booking
--   7. booking_approval
--   8. booking_session
--   9. maintenance_record
-- ============================================================

USE [CampusSpaceManagement];
GO

-- ============================================================
-- 1. user
-- ============================================================
SET IDENTITY_INSERT dbo.[user] ON;

INSERT INTO dbo.[user] (user_id, full_name, email, phone, role, department, account_status)
VALUES
    (1, N'Nguyễn Văn An',    'an.nguyen@university.edu.vn',  '0901111111', 'Student',        N'Computer Science',      'Active'),
    (2, N'Trần Thị Bình',     'binh.tran@university.edu.vn',  '0902222222', 'Lecturer',       N'Computer Science',      'Active'),
    (3, N'Lê Hoàng Cường',    'cuong.le@university.edu.vn',   '0903333333', 'TA',             N'Computer Science',      'Active'),
    (4, N'Phạm Minh Đức',     'duc.pham@university.edu.vn',   '0904444444', 'FacilityStaff',  N'Facilities',            'Active'),
    (5, N'Hoàng Thị Em',      'em.hoang@university.edu.vn',   '0905555555', 'DeptAdmin',      N'Computer Science',      'Active'),
    (6, N'Võ Văn Phương',     'phuong.vo@university.edu.vn',  '0906666666', 'FacilityManager',N'Facilities',            'Active');

SET IDENTITY_INSERT dbo.[user] OFF;
GO

-- ============================================================
-- 2. space
-- ============================================================
INSERT INTO dbo.space (space_code, space_name, space_type, building, floor, room_number, capacity, status, usage_policy)
VALUES
    ('AUD-101', N'Auditorium A101', 'Auditorium', N'Building A', 1, '101', 200, 'Available',
     N'Available for lectures, seminars, and examinations. Capacity: 200.'),
    ('CR-202',  N'Classroom C202',  'Classroom',  N'Building C', 2, '202', 50,  'Available',
     N'Standard classroom for teaching and tutorials. Capacity: 50.'),
    ('CL-301',  N'Computer Lab 301','ComputerLab',N'Building C', 3, '301', 40,  'Available',
     N'Computer laboratory with workstations. For programming and IT classes. Capacity: 40.'),
    ('MR-101',  N'Meeting Room M101','MeetingRoom',N'Building A',1, '101', 12, 'Available',
     N'Small meeting room for group discussions and meetings. Capacity: 12.'),
    ('PL-001',  N'Project Lab 001', 'ProjectLab', N'Building B', 1, '001', 20, 'Available',
     N'Project laboratory for student projects and research. Capacity: 20.');
GO

-- ============================================================
-- 3. facility_catalog
-- ============================================================
SET IDENTITY_INSERT dbo.facility_catalog ON;

INSERT INTO dbo.facility_catalog (catalog_id, name, description, is_trackable)
VALUES
    (1, N'Projector',          N'HD multimedia projector',          1),
    (2, N'Whiteboard',         N'Whiteboard with markers',          0),
    (3, N'Air Conditioner',    N'Split-type air conditioning unit', 0),
    (4, N'Computer',           N'Desktop workstation',              1),
    (5, N'Microphone',         N'Wireless microphone system',       0),
    (6, N'Livestream Equipment',N'Camera and streaming setup',      1);

SET IDENTITY_INSERT dbo.facility_catalog OFF;
GO

-- ============================================================
-- 4. facility_asset  (BEFORE space_facility — trigger constraint)
-- ============================================================
SET IDENTITY_INSERT dbo.facility_asset ON;

INSERT INTO dbo.facility_asset (asset_id, catalog_id, space_code, asset_tag, status)
VALUES
    -- Projectors (catalog_id = 1): 3 units
    (1, 1, 'AUD-101', 'PROJ-001', 'Working'),
    (2, 1, 'CR-202',  'PROJ-002', 'Working'),
    (3, 1, 'CL-301',  'PROJ-003', 'Working'),
    -- Computers (catalog_id = 4): 3 units in CL-301
    (4, 4, 'CL-301',  'COMP-001', 'Working'),
    (5, 4, 'CL-301',  'COMP-002', 'Working'),
    (6, 4, 'CL-301',  'COMP-003', 'Working'),
    -- Livestream Equipment (catalog_id = 6): 1 unit in AUD-101
    (7, 6, 'AUD-101', 'LIVE-001', 'Working');

SET IDENTITY_INSERT dbo.facility_asset OFF;
GO

-- ============================================================
-- 5. space_facility
--   Quantities for trackable items must match facility_asset counts.
-- ============================================================
SET IDENTITY_INSERT dbo.space_facility ON;

INSERT INTO dbo.space_facility (id, space_code, catalog_id, quantity)
VALUES
    -- AUD-101: Projector(qty=1), Whiteboard(qty=2), AC(qty=4), Microphone(qty=2), Livestream(qty=1)
    (1,  'AUD-101', 1, 1),
    (2,  'AUD-101', 2, 2),
    (3,  'AUD-101', 3, 4),
    (4,  'AUD-101', 5, 2),
    (5,  'AUD-101', 6, 1),
    -- CR-202: Projector(qty=1), Whiteboard(qty=1), AC(qty=2)
    (6,  'CR-202', 1, 1),
    (7,  'CR-202', 2, 1),
    (8,  'CR-202', 3, 2),
    -- CL-301: Projector(qty=1), Computer(qty=3), Whiteboard(qty=1), AC(qty=2)
    (9,  'CL-301', 1, 1),
    (10, 'CL-301', 4, 3),
    (11, 'CL-301', 2, 1),
    (12, 'CL-301', 3, 2),
    -- MR-101: Whiteboard(qty=1), AC(qty=1)
    (13, 'MR-101', 2, 1),
    (14, 'MR-101', 3, 1),
    -- PL-001: Whiteboard(qty=1), AC(qty=1)
    (15, 'PL-001', 2, 1),
    (16, 'PL-001', 3, 1);

SET IDENTITY_INSERT dbo.space_facility OFF;
GO

-- ============================================================
-- 6. booking
-- ============================================================
SET IDENTITY_INSERT dbo.booking ON;

INSERT INTO dbo.booking (booking_id, space_code, requester_id, requested_start, requested_end, purpose, participants, booking_type, status)
VALUES
    -- 1. Pending booking — Student for Meeting Room
    (1, 'MR-101', 1, '2026-07-01 09:00:00', '2026-07-01 11:00:00', N'Group project discussion', 6, 'Meeting', 'Pending'),
    -- 2. Approved booking — Lecturer for Auditorium
    (2, 'AUD-101', 2, '2026-06-28 08:00:00', '2026-06-28 10:00:00', N'Database systems guest lecture', 150, 'Lecture', 'Approved'),
    -- 3. Approved booking — TA for Classroom
    (3, 'CR-202', 3, '2026-06-29 13:30:00', '2026-06-29 15:30:00', N'Tutorial session', 40, 'Seminar', 'Approved'),
    -- 4. Rejected booking — Student for Computer Lab
    (4, 'CL-301', 1, '2026-06-30 14:00:00', '2026-06-30 17:00:00', N'Personal project work', 5, 'StudentActivity', 'Rejected'),
    -- 5. Checked-in booking — Lecturer for Auditorium (past, in progress)
    (5, 'AUD-101', 2, '2026-06-25 09:00:00', '2026-06-25 12:00:00', N'AI seminar', 120, 'Seminar', 'CheckedIn'),
    -- 6. Completed booking — Lecturer for Computer Lab
    (6, 'CL-301', 2, '2026-06-20 08:00:00', '2026-06-20 12:00:00', N'Python workshop', 35, 'Workshop', 'Completed'),
    -- 7. No-show booking — Student for Meeting Room
    (7, 'MR-101', 1, '2026-06-22 10:00:00', '2026-06-22 12:00:00', N'Study group meeting', 8, 'Meeting', 'NoShow'),
    -- 8. Cancelled booking — Student for Project Lab
    (8, 'PL-001', 1, '2026-07-05 13:00:00', '2026-07-05 17:00:00', N'Robot project work', 10, 'StudentActivity', 'Cancelled');

SET IDENTITY_INSERT dbo.booking OFF;
GO

-- ============================================================
-- 7. booking_approval
-- ============================================================
SET IDENTITY_INSERT dbo.booking_approval ON;

INSERT INTO dbo.booking_approval (approval_id, booking_id, approver_id, decision_time, decision_note, rejection_reason)
VALUES
    (1, 2, 4, '2026-06-26 10:00:00', N'Approved. Auditorium A101 is available.', NULL),
    (2, 3, 4, '2026-06-27 09:30:00', N'Approved. Classroom C202 is free during that time.', NULL),
    (3, 4, 4, '2026-06-28 08:00:00', N'Rejected.', N'Computer Lab 301 is reserved for a scheduled examination on that date.');

SET IDENTITY_INSERT dbo.booking_approval OFF;
GO

-- ============================================================
-- 8. booking_session
-- ============================================================
SET IDENTITY_INSERT dbo.booking_session ON;

INSERT INTO dbo.booking_session (session_id, booking_id, actual_start, checked_in_by, initial_condition, actual_end, completed_by, final_condition, usage_notes)
VALUES
    -- Checked-in (not yet completed)
    (1, 5, '2026-06-25 09:05:00', 4, N'Space clean, projector working, seating arranged.',
     NULL, NULL, NULL, NULL),
    -- Completed session
    (2, 6, '2026-06-20 08:10:00', 4, N'All computers functional, room clean.',
     '2026-06-20 12:15:00', 4, N'Room tidy, all computers shut down properly.',
     N'Workshop finished on time. One participant reported slow network, otherwise satisfactory.');

SET IDENTITY_INSERT dbo.booking_session OFF;
GO

-- ============================================================
-- 9. maintenance_record
-- ============================================================
SET IDENTITY_INSERT dbo.maintenance_record ON;

INSERT INTO dbo.maintenance_record (maintenance_id, space_code, reporter_id, assigned_to, problem_description, problem_type, start_time, completion_time, status, result_note)
VALUES
    -- Active maintenance — projector broken
    (1, 'AUD-101', 3, 4, N'Projector displays flickering image and turns off after 10 minutes.', 'BrokenProjector',
     '2026-06-24 14:00:00', NULL, 'InProgress', NULL),
    -- Active maintenance — AC failure in computer lab
    (2, 'CL-301', 2, 4, N'Air conditioner not cooling. Room temperature exceeds 35°C.', 'ACFailure',
     '2026-06-25 09:00:00', NULL, 'Reported', NULL),
    -- Completed maintenance — cleaning
    (3, 'MR-101', 5, 4, N'Meeting room floor and whiteboard need cleaning.', 'Cleaning',
     '2026-06-21 08:00:00', '2026-06-21 10:30:00', 'Completed', N'Room cleaned, whiteboard erased, trash removed.');

SET IDENTITY_INSERT dbo.maintenance_record OFF;
GO

PRINT 'Sample data inserted successfully.';
GO
