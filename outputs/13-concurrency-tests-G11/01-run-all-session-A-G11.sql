/* ============================================================================
   G11 COMBINED CONCURRENCY DEMO - SESSION A

   1. Run 00-setup-concurrency-lab-G11.sql once.
   2. Run this whole file in SSMS Window A.
   3. When the NOWAIT message asks for Session B, run the whole Session B file.
   ============================================================================ */
USE [CampusSpaceManagement];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.concurrency_test_log_G11',N'U') IS NULL
    THROW 51310,N'Run 00-setup-concurrency-lab-G11.sql first.',1;
GO

/* S1 - Advisory maintenance allows booking and records acknowledgement. */
DECLARE @space INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-ADVISORY');
DECLARE @user INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.requester.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    EXEC dbo.sp_AutoApproveBookingRequest
         @user,@space,'2030-03-02T09:00:00','2030-03-02T11:00:00',N'Seminar',10;
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S1-advisory',N'session-A',@result,@detail);
GO

/* S2 - Out-of-service maintenance blocks booking. */
DECLARE @space INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-OOS');
DECLARE @user INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.requester.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    EXEC dbo.sp_AutoApproveBookingRequest
         @user,@space,'2030-03-02T09:00:00','2030-03-02T11:00:00',N'Seminar',10;
    SET @result=N'UNEXPECTED_APPROVAL';
END TRY
BEGIN CATCH
    SET @result=N'OUT_OF_SERVICE';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S2-oos',N'session-A',@result,@detail);
GO

/* S3 - Auto vs auto. Session A deliberately wins. */
DECLARE @space INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-RACE');
DECLARE @user INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.requester.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    BEGIN TRAN;
    SELECT 1 FROM dbo.spaces WITH(UPDLOCK,HOLDLOCK) WHERE space_id=@space;
    RAISERROR(N'SESSION A READY: run 02-run-all-session-B-G11.sql now (10-second window).',10,1) WITH NOWAIT;
    WAITFOR DELAY '00:00:10';
    EXEC dbo.sp_AutoApproveBookingRequest
         @user,@space,'2030-03-02T09:00:00','2030-03-02T11:00:00',N'Seminar',10;
    COMMIT;
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S3-auto-auto',N'auto-A',@result,@detail);
GO

/* S4 - Auto vs staff approval on the next day. */
DECLARE @space INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-RACE');
DECLARE @user INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.requester.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    BEGIN TRAN;
    SELECT 1 FROM dbo.spaces WITH(UPDLOCK,HOLDLOCK) WHERE space_id=@space;
    RAISERROR(N'S4 running: auto vs staff.',10,1) WITH NOWAIT;
    WAITFOR DELAY '00:00:03';
    EXEC dbo.sp_AutoApproveBookingRequest
         @user,@space,'2030-03-03T09:00:00','2030-03-03T11:00:00',N'Seminar',10;
    COMMIT;
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S4-auto-staff',N'auto-A',@result,@detail);
GO

/* S5 - Two staff members approve different overlapping pending bookings. */
DECLARE @space INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-RACE');
DECLARE @booking INT=(SELECT booking_id FROM dbo.bookings WHERE space_id=@space AND start_time='2030-03-04T09:00:00');
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    BEGIN TRAN;
    SELECT 1 FROM dbo.spaces WITH(UPDLOCK,HOLDLOCK) WHERE space_id=@space;
    RAISERROR(N'S5 running: staff vs staff.',10,1) WITH NOWAIT;
    WAITFOR DELAY '00:00:03';
    EXEC dbo.sp_book_space_staff_approve @booking,@staff,N'Staff-vs-staff A';
    COMMIT;
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S5-staff-staff',N'staff-A',@result,@detail);
GO

/* S6 - Two staff members approve the same pending booking. */
DECLARE @booking INT=(SELECT b.booking_id FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code=N'CONC-RACE' AND b.start_time='2030-03-05T09:00:00');
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    BEGIN TRAN;
    SELECT 1 FROM dbo.bookings WITH(UPDLOCK,HOLDLOCK) WHERE booking_id=@booking;
    RAISERROR(N'S6 running: double approval.',10,1) WITH NOWAIT;
    WAITFOR DELAY '00:00:03';
    EXEC dbo.sp_book_space_staff_approve @booking,@staff,N'Double-approve A';
    COMMIT;
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S6-double',N'staff-A',@result,@detail);
GO

/* S7 - Escalation commits before an overlapping approval can continue. */
DECLARE @maintenance INT=(SELECT m.maintenance_id FROM dbo.maintenance_records m JOIN dbo.spaces s ON s.space_id=m.space_id WHERE s.space_code=N'CONC-ESCALATE' AND m.problem_description=N'CONC escalation target');
DECLARE @space INT=(SELECT space_id FROM dbo.maintenance_records WHERE maintenance_id=@maintenance);
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    BEGIN TRAN;
    SELECT 1 FROM dbo.spaces WITH(UPDLOCK,HOLDLOCK) WHERE space_id=@space;
    SELECT 1 FROM dbo.maintenance_records WITH(UPDLOCK,HOLDLOCK) WHERE maintenance_id=@maintenance;
    RAISERROR(N'S7 running: escalation vs approval.',10,1) WITH NOWAIT;
    WAITFOR DELAY '00:00:03';
    EXEC dbo.sp_set_maintenance_impact @maintenance,N'out-of-service';
    COMMIT;
    SET @result=N'ESCALATED';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S7-escalation',N'manager-A',@result,@detail);
GO

/* S8 - Two sessions consolidate the same incident reports. */
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.a@g11.local');
DECLARE @ids NVARCHAR(MAX)=(SELECT STRING_AGG(CONVERT(NVARCHAR(20),report_id),N',') FROM dbo.incident_reports WHERE description IN(N'CONC duplicate incident A',N'CONC duplicate incident B'));
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL,@rs NVARCHAR(40);
BEGIN TRY
    BEGIN TRAN;
    SELECT 1 FROM dbo.incident_reports WITH(UPDLOCK,HOLDLOCK) WHERE description IN(N'CONC duplicate incident A',N'CONC duplicate incident B');
    RAISERROR(N'S8 running: duplicate incident consolidation.',10,1) WITH NOWAIT;
    WAITFOR DELAY '00:00:03';
    EXEC dbo.sp_consolidate_incident_reports @ids,@staff,NULL,@rs OUTPUT;
    COMMIT;
    SET @result=COALESCE(@rs,N'CONSOLIDATED');
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    IF ERROR_NUMBER()=1205 SET @result=N'SAFE_DEADLOCK_REJECT';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S8-consolidation',N'triage-A',@result,@detail);
GO

RAISERROR(N'SESSION A COMPLETE. Wait for Session B, then run 03-verify-all-G11.sql.',10,1) WITH NOWAIT;
SELECT scenario,actor,result_status,detail
FROM dbo.concurrency_test_log_G11
WHERE actor IN(N'session-A',N'auto-A',N'staff-A',N'manager-A',N'triage-A')
ORDER BY log_id;
GO
