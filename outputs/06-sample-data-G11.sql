USE [CampusSpaceManagement];
GO

-- =============================================
-- Phase 1 — Base Entities (single batch)
-- =============================================

PRINT '--- Seeding Users ---';
INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Emily Davis',       'emily.davis@uni.edu',      '555-0101', 'Student',                'Computer Science', 'Active');
DECLARE @Stu1 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Liam Chen',         'liam.chen@uni.edu',         '555-0102', 'Student',                'Computer Science', 'Active');
DECLARE @Stu2 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Sophia Martinez',   'sophia.mtz@uni.edu',        '555-0103', 'Student',                'Data Science',     'Active');
DECLARE @Stu3 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Olga Petrova',      'olga.petrova@uni.edu',      '555-0104', 'Student',                'Computer Science', 'Active');
DECLARE @Stu4 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Dr. Alan Turing',   'alan.turing@uni.edu',       '555-0201', 'Lecturer',                'Computer Science', 'Active');
DECLARE @Lect1 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Prof. Grace Hopper','grace.hopper@uni.edu',      '555-0202', 'Lecturer',                'Data Science',     'Active');
DECLARE @Lect2 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('James Kim',         'james.kim@uni.edu',         '555-0203', 'Lecturer',                'Software Eng',     'Active');
DECLARE @Lect3 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Raj Patel',         'raj.patel@uni.edu',         '555-0301', 'Teaching Assistant',      'Computer Science', 'Active');
DECLARE @TA1 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Aisha Nguyễn',      'aisha.nguyen@uni.edu',      '555-0302', 'Teaching Assistant',      'Computer Science', 'Active');
DECLARE @TA2 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Bob Wilson',        'bob.wilson@uni.edu',        '555-0401', 'Facility Staff',          'Facilities',       'Active');
DECLARE @Staff1 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Diana Ross',        'diana.ross@uni.edu',        '555-0402', 'Facility Staff',          'Facilities',       'Active');
DECLARE @Staff2 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Alice Brown',       'alice.brown@uni.edu',       '555-0501', 'Department Administrator','Computer Science', 'Active');
DECLARE @Admin1 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Carlos Garcia',     'carlos.garcia@uni.edu',     '555-0502', 'Department Administrator','Data Science',     'Active');
DECLARE @Admin2 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Fatima Okafor',     'fatima.okafor@uni.edu',     '555-0601', 'Facility Manager',        'Facilities',       'Active');
DECLARE @Mgr1 INT = SCOPE_IDENTITY();

INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
VALUES ('Yuki Tanaka',       'yuki.tanaka@uni.edu',       '555-0602', 'Facility Manager',        'Facilities',       'Active');
DECLARE @Mgr2 INT = SCOPE_IDENTITY();

-- [BR-02: Spaces with all 5 status values and various types]
PRINT '--- Seeding Spaces ---';
INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('AUD-01', 'Alan Turing Auditorium',  'Auditorium',        'Ada Lovelace Bldg', 1, '101', 200, 'Available',          'Lectures, seminars, public events');
DECLARE @Sp1 INT = SCOPE_IDENTITY();

INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('CLS-101','Classroom 101',           'Classroom',         'Ada Lovelace Bldg', 1, '102',  50, 'In Use',             'Lectures and tutorials only');
DECLARE @Sp2 INT = SCOPE_IDENTITY();

INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('LAB-01', 'Von Neumann Lab',        'Computer Laboratory','Ada Lovelace Bldg', 2, '201',  30, 'Under Maintenance',  'Programming labs');
DECLARE @Sp3 INT = SCOPE_IDENTITY();

INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('MTG-01', 'Knuth Meeting Room',     'Meeting Room',       'Knuth Bldg',        1, '001',  12, 'Temporarily Closed', 'Renovation in progress');
DECLARE @Sp4 INT = SCOPE_IDENTITY();

INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('LAB-02', 'Project Lab Alpha',      'Project Laboratory', 'Ada Lovelace Bldg', 2, '202',  20, 'Retired',            'No longer in service');
DECLARE @Sp5 INT = SCOPE_IDENTITY();

INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('CLS-102','Classroom 102',           'Classroom',         'Ada Lovelace Bldg', 1, '103',  40, 'Available',          'Lectures and workshops');
DECLARE @Sp6 INT = SCOPE_IDENTITY();

INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('WS-01',  'Student Co-Working Hub', 'Student Workspace',  'Ada Lovelace Bldg', 3, '301',  60, 'Available',          'Open student use, clubs');
DECLARE @Sp7 INT = SCOPE_IDENTITY();

INSERT INTO dbo.spaces (space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES ('AUD-02', 'Babbage Auditorium',     'Auditorium',        'Ada Lovelace Bldg', 0, 'G01', 150, 'Available',          'Exams, large events');
DECLARE @Sp8 INT = SCOPE_IDENTITY();

-- [BR-10: Facility Catalog — mix trackable/non-trackable]
PRINT '--- Seeding Facility Catalog ---';
INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES ('Projector',            1);
DECLARE @CatProj INT = SCOPE_IDENTITY();
INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES ('Whiteboard',           0);
DECLARE @CatBoard INT = SCOPE_IDENTITY();
INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES ('Microphone System',    1);
DECLARE @CatMic INT = SCOPE_IDENTITY();
INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES ('Computer Workstation', 1);
DECLARE @CatPC INT = SCOPE_IDENTITY();
INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES ('Livestreaming Kit',    1);
DECLARE @CatStream INT = SCOPE_IDENTITY();
INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES ('Air Conditioner Unit', 0);
DECLARE @CatAC INT = SCOPE_IDENTITY();
INSERT INTO dbo.facility_catalog (facility_name, is_trackable) VALUES ('Conference Phone',     1);
DECLARE @CatPhone INT = SCOPE_IDENTITY();

-- =============================================
-- Phase 2 — Associative / Child Entities
-- Disable trigger to avoid chicken-and-egg validation
-- =============================================

DISABLE TRIGGER TRG_ValidateFacilityQuantity ON dbo.space_facility;

PRINT '--- Seeding Space-Facility Mappings ---';
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp1, @CatProj,   2);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp1, @CatBoard,  4);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp1, @CatMic,    2);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp2, @CatProj,   1);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp2, @CatBoard,  1);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp3, @CatPC,     25);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp3, @CatProj,   1);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp6, @CatProj,   1);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp6, @CatBoard,  1);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp7, @CatBoard,  6);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp8, @CatProj,   1);
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity) VALUES (@Sp8, @CatStream, 1);

PRINT '--- Seeding Facility Assets ---';
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('PROJ-001-AUD1', @Sp1, @CatProj, 'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('PROJ-002-AUD1', @Sp1, @CatProj, 'Needs Repair');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('MIC-001-AUD1',  @Sp1, @CatMic,   'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('MIC-002-AUD1',  @Sp1, @CatMic,   'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('PROJ-101-CLS',  @Sp2, @CatProj,  'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('WS-001-LAB1',   @Sp3, @CatPC,    'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('WS-002-LAB1',   @Sp3, @CatPC,    'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('PROJ-102-CLS',  @Sp6, @CatProj,  'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('STRM-001-AUD2', @Sp8, @CatStream,'Good');
INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status) VALUES ('PHONE-001-MTG', @Sp4, @CatPhone, 'Good');

ENABLE TRIGGER TRG_ValidateFacilityQuantity ON dbo.space_facility;

-- =============================================
-- Phase 3 — Transactional Entities
-- =============================================

-- [BR-01, BR-03: Bookings — all 7 statuses + all 7 purposes]
PRINT '--- Seeding Bookings ---';
INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Stu1, @Sp1, '2026-09-01 09:00', '2026-09-01 11:00', 'Seminar', 80, 'Pending');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Lect1, @Sp2, '2026-09-02 10:00', '2026-09-02 12:00', 'Lecture', 45, 'Approved');
DECLARE @B2 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Lect2, @Sp1, '2026-09-03 14:00', '2026-09-03 16:00', 'Workshop', 100, 'Approved');
DECLARE @B3 INT = SCOPE_IDENTITY();

-- [BR-04: Rejected booking with rejection reason]
INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@TA1, @Sp6, '2026-09-04 09:00', '2026-09-04 10:00', 'Meeting', 10, 'Rejected');
DECLARE @B4 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@TA2, @Sp8, '2026-09-05 08:00', '2026-09-05 12:00', 'Examination', 120, 'Cancelled');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Stu2, @Sp7, '2026-09-06 15:00', '2026-09-06 18:00', 'Student Activity', 25, 'Checked In');
DECLARE @B6 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Admin1, @Sp2, '2026-09-07 10:00', '2026-09-07 11:30', 'Administrative Event', 15, 'Completed');
DECLARE @B7 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Stu3, @Sp1, '2026-09-08 09:00', '2026-09-08 11:00', 'Lecture', 60, 'No-show');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Lect1, @Sp8, '2026-09-10 13:00', '2026-09-10 15:00', 'Workshop', 80, 'Approved');
DECLARE @B9 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Lect2, @Sp6, '2026-09-11 10:00', '2026-09-11 12:00', 'Seminar', 30, 'Approved');
DECLARE @B10 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Admin2, @Sp1, '2026-09-14 09:00', '2026-09-14 10:00', 'Meeting', 8, 'Pending');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@TA1, @Sp6, '2026-09-15 08:00', '2026-09-15 10:00', 'Lecture', 35, 'Pending');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Lect1, @Sp8, '2026-10-01 09:00', '2026-10-01 12:00', 'Examination', 130, 'Approved');
DECLARE @B13 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Stu1, @Sp7, '2026-10-02 14:00', '2026-10-02 17:00', 'Student Activity', 20, 'Completed');
DECLARE @B14 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Admin2, @Sp1, '2026-10-03 09:00', '2026-10-03 11:00', 'Administrative Event', 50, 'Completed');
DECLARE @B15 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Staff1, @Sp6, '2026-10-04 13:00', '2026-10-04 14:00', 'Meeting', 6, 'Approved');
DECLARE @B16 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@TA2, @Sp1, '2026-10-05 10:00', '2026-10-05 12:00', 'Workshop', 70, 'Checked In');
DECLARE @B17 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Stu2, @Sp1, '2026-10-06 15:00', '2026-10-06 17:00', 'Seminar', 50, 'Rejected');
DECLARE @B18 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Lect2, @Sp2, '2026-10-07 10:00', '2026-10-07 12:00', 'Lecture', 40, 'Cancelled');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Admin1, @Sp6, '2026-10-08 09:00', '2026-10-08 10:00', 'Meeting', 5, 'No-show');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Stu3, @Sp8, '2026-11-01 08:00', '2026-11-01 11:00', 'Examination', 100, 'Pending');

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Stu1, @Sp7, '2026-11-02 10:00', '2026-11-02 12:00', 'Student Activity', 15, 'Checked In');
DECLARE @B22 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Admin1, @Sp6, '2026-11-03 14:00', '2026-11-03 16:00', 'Administrative Event', 20, 'Approved');
DECLARE @B23 INT = SCOPE_IDENTITY();

INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
VALUES (@Lect1, @Sp8, '2026-11-04 09:00', '2026-11-04 11:00', 'Workshop', 60, 'Completed');
DECLARE @B24 INT = SCOPE_IDENTITY();

-- [BR-03, BR-04: Approvals — include approved and rejected]
PRINT '--- Seeding Approvals ---';
INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B2,  @Mgr1, '2026-08-28 10:00', 'Approved for regular lecture schedule.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B3,  @Mgr1, '2026-08-29 11:00', 'Workshop approved. Sound check required.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B4,  @Staff1, '2026-09-03 09:00', 'Denied.', 'Room already reserved for a departmental meeting.');

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B6,  @Staff2, '2026-09-05 14:00', 'Approved for student club meetup.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B7,  @Mgr2, '2026-09-06 08:00', 'Admin event approved.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B9,  @Staff1, '2026-09-09 10:00', 'Saturday workshop approved.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B10, @Staff2, '2026-09-10 09:00', 'Seminar approved.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B13, @Mgr1, '2026-09-25 11:00', 'Final exam booking approved. Invigilator access needed.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B16, @Staff1, '2026-10-03 10:00', 'Meeting approved.', NULL);

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B18, @Mgr2, '2026-10-05 16:00', 'Capacity insufficient.', '50+ participants require the main auditorium; only 40 seats in requested room.');

INSERT INTO dbo.approvals (booking_id, staff_id, decision_time, decision_note, rejection_reason)
VALUES (@B23, @Mgr1, '2026-11-02 10:00', 'Approved for accreditation event.', NULL);

-- [BR-05, BR-06: Usage Sessions — normal + damage notes]
PRINT '--- Seeding Usage Sessions ---';
INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B2,  @Staff1, '2026-09-02 10:05', '2026-09-02 12:00', 'Clean, projector working', 'Clean', 'Finished on time.');

INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B6,  @Staff2, '2026-09-06 15:10', '2026-09-06 17:55', 'Whiteboard clean, chairs arranged', 'Markers left uncapped', 'Minor cleanup needed.');

INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B7,  @Staff1, '2026-09-07 10:00', '2026-09-07 11:25', 'Good', 'Good', 'No issues.');

INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B14, @Staff2, '2026-10-02 14:05', '2026-10-02 17:00', 'Tidy', 'Some trash on desks', 'Cleaning requested.');

INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B15, @Staff1, '2026-10-03 09:00', '2026-10-03 11:00', 'Auditorium ready', 'Clean', 'Event went smoothly.');

INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B17, @Staff2, '2026-10-05 10:10', '2026-10-05 12:00', 'Projector working', 'Bulb flickering', 'Hardware issue reported.');

INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B22, @Staff1, '2026-11-02 10:00', '2026-11-02 11:50', 'Good', 'Good', 'No issues.');

INSERT INTO dbo.usage_sessions (booking_id, staff_id, actual_start_time, actual_end_time, initial_condition, final_condition, usage_notes)
VALUES (@B24, @Staff2, '2026-11-04 09:05', '2026-11-04 11:00', 'Good', 'Good', 'Completed successfully.');

-- [BR-02: Maintenance Records]
PRINT '--- Seeding Maintenance Records ---';
INSERT INTO dbo.maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note)
VALUES (@Sp1, @Lect1, @Staff1, 'Projector bulb flickering and dim',                    '2026-10-06 14:00', '2026-10-07 10:00', 'Completed', 'Bulb replaced.');
INSERT INTO dbo.maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note)
VALUES (@Sp3, @Stu1,  @Staff2, 'Workstation WS-003 will not boot',                     '2026-10-10 09:00', NULL,               'In Progress', NULL);
INSERT INTO dbo.maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note)
VALUES (@Sp3, @TA1,   NULL,     'Air conditioning not cooling',                         '2026-10-12 08:00', NULL,               'Reported', NULL);
INSERT INTO dbo.maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note)
VALUES (@Sp2, @Admin1, @Staff1, 'Broken chair in row C, seat 12',                      '2026-10-15 11:00', '2026-10-16 09:00', 'Completed', 'Chair replaced.');
INSERT INTO dbo.maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note)
VALUES (@Sp1, @Mgr1,   @Staff2, 'Microphone feedback on left channel',                 '2026-10-20 15:00', NULL,               'Assigned', 'Staff assigned.');
INSERT INTO dbo.maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note)
VALUES (@Sp7, @Stu2,   NULL,     'Network outlet dead near window',                      '2026-10-25 10:00', NULL,               'Reported', NULL);
INSERT INTO dbo.maintenance_records (space_id, reporter_id, assigned_staff_id, problem_description, start_time, completion_time, status, result_note)
VALUES (@Sp3, @TA2,    @Staff1, 'Whiteboard surface heavily stained',                   '2026-11-01 09:00', '2026-11-02 16:00', 'Completed', 'Resurfaced.');
-- =============================================
-- Phase 4 — Constraint Tests (same batch preserves variables)
-- =============================================

PRINT '--- Test 1: UNIQUE constraint on email ---';
BEGIN TRY
    INSERT INTO dbo.users (full_name, email, phone_number, role, department, account_status)
    VALUES ('Fake User', 'emily.davis@uni.edu', '555-9999', 'Student', 'CS', 'Active');
    PRINT 'FAIL: UNIQUE on email was not enforced';
END TRY
BEGIN CATCH
    PRINT 'PASS: UNIQUE on email enforced — ' + ERROR_MESSAGE();
END CATCH

PRINT '--- Test 2: UNIQUE constraint on asset_tag ---';
BEGIN TRY
    INSERT INTO dbo.facility_assets (asset_tag, space_id, catalog_id, status)
    VALUES ('PROJ-001-AUD1', @Sp1, @CatProj, 'Good');
    PRINT 'FAIL: UNIQUE on asset_tag was not enforced';
END TRY
BEGIN CATCH
    PRINT 'PASS: UNIQUE on asset_tag enforced — ' + ERROR_MESSAGE();
END CATCH

PRINT '--- Test 3: FK NO ACTION — DELETE blocked for user with bookings ---';
BEGIN TRY
    DELETE FROM dbo.users WHERE user_id = @Stu1;
    PRINT 'FAIL: FK NO ACTION was not enforced';
END TRY
BEGIN CATCH
    PRINT 'PASS: FK NO ACTION enforced — ' + ERROR_MESSAGE();
END CATCH

PRINT '--- Test 4: Trigger — trackable quantity exceeds registered assets ---';
BEGIN TRY
    UPDATE dbo.space_facility SET quantity = 99 WHERE space_id = @Sp1 AND catalog_id = @CatProj;
    PRINT 'FAIL: TRG_ValidateFacilityQuantity did not fire';
END TRY
BEGIN CATCH
    PRINT 'PASS: Trigger blocked over-count — ' + ERROR_MESSAGE();
END CATCH

PRINT '--- Test 5: CHECK — end_time must be after start_time ---';
BEGIN TRY
    INSERT INTO dbo.bookings (user_id, space_id, start_time, end_time, purpose, expected_participants, status)
    VALUES (@Stu1, @Sp1, '2026-12-01 10:00', '2026-12-01 09:00', 'Meeting', 5, 'Pending');
    PRINT 'FAIL: Chronological CHECK was not enforced';
END TRY
BEGIN CATCH
    PRINT 'PASS: Chronological CHECK enforced — ' + ERROR_MESSAGE();
END CATCH
GO
