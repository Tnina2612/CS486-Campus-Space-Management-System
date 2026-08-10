/* ============================================================================
   G11 COMBINED CONCURRENCY DEMO - SESSION B

   Run this whole file in SSMS Window B only after Session A prints:
   "SESSION A READY". The waits between scenarios let Session A acquire the
   next production lock first; Session B then demonstrates real contention.
   ============================================================================ */
USE [CampusSpaceManagement];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.concurrency_test_log_G11',N'U') IS NULL
    THROW 51311,N'Run 00-setup-concurrency-lab-G11.sql first.',1;
GO

/* S3 - Competing auto-booking overlaps Session A. */
DECLARE @space INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-RACE');
DECLARE @user INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.requester.b@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    EXEC dbo.sp_AutoApproveBookingRequest
         @user,@space,'2030-03-02T10:00:00','2030-03-02T12:00:00',N'Seminar',10;
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    SET @result=N'OVERLAP';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S3-auto-auto',N'auto-B',@result,@detail);
WAITFOR DELAY '00:00:01';
GO

/* S4 - Staff approval overlaps Session A's auto-booking. */
DECLARE @booking INT=(SELECT b.booking_id FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code=N'CONC-RACE' AND b.start_time='2030-03-03T10:00:00');
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    EXEC dbo.sp_book_space_staff_approve @booking,@staff,N'Auto-vs-staff B';
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    SET @result=N'OVERLAP';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S4-auto-staff',N'staff-B',@result,@detail);
WAITFOR DELAY '00:00:01';
GO

/* S5 - Second staff member approves a different overlapping booking. */
DECLARE @booking INT=(SELECT b.booking_id FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code=N'CONC-RACE' AND b.start_time='2030-03-04T10:00:00');
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.b@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    EXEC dbo.sp_book_space_staff_approve @booking,@staff,N'Staff-vs-staff B';
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    SET @result=N'OVERLAP';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S5-staff-staff',N'staff-B',@result,@detail);
WAITFOR DELAY '00:00:01';
GO

/* S6 - Second staff member calls approval for the exact same booking. */
DECLARE @booking INT=(SELECT b.booking_id FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code=N'CONC-RACE' AND b.start_time='2030-03-05T09:00:00');
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.b@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    EXEC dbo.sp_book_space_staff_approve @booking,@staff,N'Double-approve B';
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    SET @result=N'NOT_PENDING';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S6-double',N'staff-B',@result,@detail);
WAITFOR DELAY '00:00:01';
GO

/* S7 - Approval waits for escalation, then observes out-of-service. */
DECLARE @booking INT=(SELECT b.booking_id FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code=N'CONC-ESCALATE' AND b.start_time='2030-03-02T09:30:00');
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.a@g11.local');
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL;
BEGIN TRY
    EXEC dbo.sp_book_space_staff_approve @booking,@staff,N'Approval racing escalation';
    SET @result=N'APPROVED';
END TRY
BEGIN CATCH
    SET @result=N'OUT_OF_SERVICE';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S7-escalation',N'staff-B',@result,@detail);
WAITFOR DELAY '00:00:01';
GO

/* S8 - Second triage session targets the same two incident reports. */
DECLARE @staff INT=(SELECT user_id FROM dbo.users WHERE email=N'concurrency.staff.b@g11.local');
DECLARE @ids NVARCHAR(MAX)=(SELECT STRING_AGG(CONVERT(NVARCHAR(20),report_id),N',') FROM dbo.incident_reports WHERE description IN(N'CONC duplicate incident A',N'CONC duplicate incident B'));
DECLARE @result NVARCHAR(40)=N'FAILED',@detail NVARCHAR(4000)=NULL,@rs NVARCHAR(40);
BEGIN TRY
    EXEC dbo.sp_consolidate_incident_reports @ids,@staff,NULL,@rs OUTPUT;
    SET @result=COALESCE(@rs,N'NO_STATUS');
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()=1205 SET @result=N'SAFE_DEADLOCK_REJECT';
    SET @detail=ERROR_MESSAGE();
END CATCH;
INSERT dbo.concurrency_test_log_G11(scenario,actor,result_status,detail)
VALUES(N'S8-consolidation',N'triage-B',@result,@detail);
GO

RAISERROR(N'SESSION B COMPLETE. Run 03-verify-all-G11.sql after Session A also completes.',10,1) WITH NOWAIT;
SELECT scenario,actor,result_status,detail
FROM dbo.concurrency_test_log_G11
WHERE actor IN(N'auto-B',N'staff-B',N'triage-B')
ORDER BY log_id;
GO
