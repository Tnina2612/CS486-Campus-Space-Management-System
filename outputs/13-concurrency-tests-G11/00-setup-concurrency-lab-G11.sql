/* SQL Server-only concurrency lab. Run once before the combined A/B demo. */
USE [CampusSpaceManagement];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.sp_AutoApproveBookingRequest', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_book_space_staff_approve', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_consolidate_incident_reports', N'P') IS NULL
   OR OBJECT_ID(N'dbo.sp_set_maintenance_impact', N'P') IS NULL
    THROW 51300, 'Run outputs/12-concurrency-implementation-G11.sql first.', 1;

IF OBJECT_ID(N'dbo.concurrency_test_log_G11', N'U') IS NULL
CREATE TABLE dbo.concurrency_test_log_G11 (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    scenario NVARCHAR(30) NOT NULL,
    actor NVARCHAR(30) NOT NULL,
    result_status NVARCHAR(40) NOT NULL,
    detail NVARCHAR(4000) NULL,
    recorded_at DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

BEGIN TRY
BEGIN TRAN;

DELETE aa FROM dbo.advisory_acknowledgements aa JOIN dbo.bookings b ON b.booking_id = aa.booking_id JOIN dbo.spaces s ON s.space_id = b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE rc FROM dbo.report_consolidations rc JOIN dbo.incident_reports ir ON ir.report_id = rc.incident_report_id JOIN dbo.spaces s ON s.space_id = ir.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE us FROM dbo.usage_sessions us JOIN dbo.bookings b ON b.booking_id = us.booking_id JOIN dbo.spaces s ON s.space_id = b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE a FROM dbo.approvals a JOIN dbo.bookings b ON b.booking_id = a.booking_id JOIN dbo.spaces s ON s.space_id = b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE ir FROM dbo.incident_reports ir JOIN dbo.spaces s ON s.space_id = ir.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE b FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id = b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE m FROM dbo.maintenance_records m JOIN dbo.spaces s ON s.space_id = m.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE FROM dbo.spaces WHERE space_code LIKE N'CONC-%';
DELETE FROM dbo.users WHERE email LIKE N'concurrency.%@g11.local';
DELETE FROM dbo.concurrency_test_log_G11;

INSERT dbo.users (full_name,email,phone_number,role,department,account_status) VALUES
(N'Concurrency Requester A',N'concurrency.requester.a@g11.local',N'0900001301',N'Lecturer',N'Computer Science',N'Active'),
(N'Concurrency Requester B',N'concurrency.requester.b@g11.local',N'0900001302',N'Lecturer',N'Computer Science',N'Active'),
(N'Concurrency Staff A',N'concurrency.staff.a@g11.local',N'0900001303',N'Facility Staff',N'Computer Science',N'Active'),
(N'Concurrency Staff B',N'concurrency.staff.b@g11.local',N'0900001304',N'Facility Staff',N'Computer Science',N'Active');

INSERT dbo.spaces (space_code,space_name,space_type,building,floor,room_number,capacity,current_status,usage_policy,auto_booking_enabled) VALUES
(N'CONC-RACE',N'Concurrency Race Room',N'Meeting Room',N'Lab',1,N'101',30,N'Available',N'Concurrency test',1),
(N'CONC-ADVISORY',N'Concurrency Advisory Room',N'Meeting Room',N'Lab',1,N'102',30,N'Available',N'Concurrency test',1),
(N'CONC-OOS',N'Concurrency OOS Room',N'Meeting Room',N'Lab',1,N'103',30,N'Available',N'Concurrency test',1),
(N'CONC-ESCALATE',N'Concurrency Escalation Room',N'Meeting Room',N'Lab',1,N'104',30,N'Available',N'Concurrency test',1),
(N'CONC-CONSOLIDATE',N'Concurrency Consolidation Room',N'Meeting Room',N'Lab',1,N'105',30,N'Available',N'Concurrency test',1);

DECLARE @RequesterA INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.requester.a@g11.local');
DECLARE @Race INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-RACE');
DECLARE @Adv INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-ADVISORY');
DECLARE @Oos INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-OOS');
DECLARE @Esc INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-ESCALATE');
DECLARE @Con INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-CONSOLIDATE');

INSERT dbo.maintenance_records (space_id,reporter_id,assigned_staff_id,problem_description,start_time,completion_time,status,result_note,impact_level) VALUES
(@Adv,@RequesterA,NULL,N'CONC advisory','2030-03-02T09:00:00','2030-03-02T11:00:00',N'Open',NULL,N'advisory'),
(@Oos,@RequesterA,NULL,N'CONC out-of-service','2030-03-02T09:00:00','2030-03-02T11:00:00',N'Open',NULL,N'out-of-service'),
(@Esc,@RequesterA,NULL,N'CONC escalation target','2030-03-02T09:00:00','2030-03-02T11:00:00',N'Open',NULL,N'advisory');

INSERT dbo.bookings (user_id,space_id,start_time,end_time,purpose,expected_participants,status) VALUES
(@RequesterA,@Race,'2030-03-03T10:00:00','2030-03-03T12:00:00',N'Meeting',10,N'Pending'),
(@RequesterA,@Race,'2030-03-04T09:00:00','2030-03-04T11:00:00',N'Meeting',10,N'Pending'),
(@RequesterA,@Race,'2030-03-04T10:00:00','2030-03-04T12:00:00',N'Meeting',10,N'Pending'),
(@RequesterA,@Race,'2030-03-05T09:00:00','2030-03-05T11:00:00',N'Meeting',10,N'Pending'),
(@RequesterA,@Esc,'2030-03-02T09:30:00','2030-03-02T10:30:00',N'Meeting',10,N'Pending');

INSERT dbo.incident_reports (user_id,space_id,description,reported_at,status) VALUES
(@RequesterA,@Con,N'CONC duplicate incident A','2030-03-01T08:00:00',N'Open'),
(@RequesterA,@Con,N'CONC duplicate incident B','2030-03-01T08:01:00',N'Open');

COMMIT;
PRINT N'CONCURRENCY LAB READY. Run 01-run-all-session-A, then 02-run-all-session-B when Session A asks.';
END TRY
BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK;
THROW;
END CATCH;
GO
