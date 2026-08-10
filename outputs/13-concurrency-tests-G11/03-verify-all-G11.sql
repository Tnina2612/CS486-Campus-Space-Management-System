/* Run once after both combined session files complete. */
USE [CampusSpaceManagement];
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.concurrency_test_log_G11',N'U') IS NULL
    THROW 51312,N'Run the setup and both session files first.',1;

DECLARE @failures TABLE (
    scenario NVARCHAR(30) NOT NULL,
    failure_reason NVARCHAR(300) NOT NULL
);

DECLARE @AdvSpace INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-ADVISORY');
DECLARE @OosSpace INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-OOS');
DECLARE @RaceSpace INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-RACE');
DECLARE @EscSpace INT=(SELECT space_id FROM dbo.spaces WHERE space_code=N'CONC-ESCALATE');

/* S1 - Advisory allowed, with snapshot and normalized acknowledgement. */
DECLARE @AdvBooking INT=(SELECT booking_id FROM dbo.bookings WHERE space_id=@AdvSpace AND start_time='2030-03-02T09:00:00');
IF @AdvBooking IS NULL
   OR NOT EXISTS(SELECT 1 FROM dbo.bookings WHERE booking_id=@AdvBooking AND status=N'Approved' AND advisory_acknowledged=1 AND advisory_snapshot IS NOT NULL)
   OR NOT EXISTS(SELECT 1 FROM dbo.advisory_acknowledgements WHERE booking_id=@AdvBooking)
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S1-advisory' AND result_status=N'APPROVED')
    INSERT @failures VALUES(N'S1-advisory',N'Booking, advisory acknowledgement, snapshot, or APPROVED log is missing.');

/* S2 - OOS blocked without leaving a booking row. */
IF EXISTS(SELECT 1 FROM dbo.bookings WHERE space_id=@OosSpace AND start_time='2030-03-02T09:00:00')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S2-oos' AND result_status=N'OUT_OF_SERVICE')
    INSERT @failures VALUES(N'S2-oos',N'Out-of-service maintenance did not safely reject the booking.');

/* S3 - Exactly one auto-booking survives. */
IF (SELECT COUNT(*) FROM dbo.bookings WHERE space_id=@RaceSpace AND status=N'Approved' AND start_time<'2030-03-02T12:00:00' AND end_time>'2030-03-02T09:00:00')<>1
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S3-auto-auto' AND actor=N'auto-A' AND result_status=N'APPROVED')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S3-auto-auto' AND actor=N'auto-B' AND result_status=N'OVERLAP')
    INSERT @failures VALUES(N'S3-auto-auto',N'Expected one APPROVED and one OVERLAP result.');

/* S4 - Auto approval wins; overlapping staff approval remains Pending. */
IF (SELECT COUNT(*) FROM dbo.bookings WHERE space_id=@RaceSpace AND status=N'Approved' AND start_time<'2030-03-03T12:00:00' AND end_time>'2030-03-03T09:00:00')<>1
   OR NOT EXISTS(SELECT 1 FROM dbo.bookings WHERE space_id=@RaceSpace AND start_time='2030-03-03T10:00:00' AND status=N'Pending')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S4-auto-staff' AND actor=N'auto-A' AND result_status=N'APPROVED')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S4-auto-staff' AND actor=N'staff-B' AND result_status=N'OVERLAP')
    INSERT @failures VALUES(N'S4-auto-staff',N'Auto-vs-staff invariant failed.');

/* S5 - One of two different pending bookings is approved. */
IF (SELECT COUNT(*) FROM dbo.bookings WHERE space_id=@RaceSpace AND status=N'Approved' AND start_time<'2030-03-04T12:00:00' AND end_time>'2030-03-04T09:00:00')<>1
   OR NOT EXISTS(SELECT 1 FROM dbo.bookings WHERE space_id=@RaceSpace AND start_time='2030-03-04T10:00:00' AND status=N'Pending')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S5-staff-staff' AND actor=N'staff-A' AND result_status=N'APPROVED')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S5-staff-staff' AND actor=N'staff-B' AND result_status=N'OVERLAP')
    INSERT @failures VALUES(N'S5-staff-staff',N'Staff-vs-staff invariant failed.');

/* S6 - Same booking produces one approval row. */
DECLARE @DoubleBooking INT=(SELECT booking_id FROM dbo.bookings WHERE space_id=@RaceSpace AND start_time='2030-03-05T09:00:00');
IF NOT EXISTS(SELECT 1 FROM dbo.bookings WHERE booking_id=@DoubleBooking AND status=N'Approved')
   OR (SELECT COUNT(*) FROM dbo.approvals WHERE booking_id=@DoubleBooking)<>1
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S6-double' AND actor=N'staff-A' AND result_status=N'APPROVED')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S6-double' AND actor=N'staff-B' AND result_status=N'NOT_PENDING')
    INSERT @failures VALUES(N'S6-double',N'Double approval did not produce exactly one approval row.');

/* S7 - Escalation commits first; approval observes OOS and stays Pending. */
DECLARE @EscMaintenance INT=(SELECT maintenance_id FROM dbo.maintenance_records WHERE space_id=@EscSpace AND problem_description=N'CONC escalation target');
DECLARE @EscBooking INT=(SELECT booking_id FROM dbo.bookings WHERE space_id=@EscSpace AND start_time='2030-03-02T09:30:00');
IF NOT EXISTS(SELECT 1 FROM dbo.maintenance_records WHERE maintenance_id=@EscMaintenance AND impact_level=N'out-of-service')
   OR NOT EXISTS(SELECT 1 FROM dbo.bookings WHERE booking_id=@EscBooking AND status=N'Pending')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S7-escalation' AND actor=N'manager-A' AND result_status=N'ESCALATED')
   OR NOT EXISTS(SELECT 1 FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S7-escalation' AND actor=N'staff-B' AND result_status=N'OUT_OF_SERVICE')
    INSERT @failures VALUES(N'S7-escalation',N'Escalation-vs-approval invariant failed.');

/* S8 - Two reports map to one maintenance record; second call is deduplicated. */
DECLARE @ReportLinks INT=(SELECT COUNT(*) FROM dbo.report_consolidations rc JOIN dbo.incident_reports ir ON ir.report_id=rc.incident_report_id WHERE ir.description IN(N'CONC duplicate incident A',N'CONC duplicate incident B'));
DECLARE @MaintenanceCount INT=(SELECT COUNT(DISTINCT rc.maintenance_id) FROM dbo.report_consolidations rc JOIN dbo.incident_reports ir ON ir.report_id=rc.incident_report_id WHERE ir.description IN(N'CONC duplicate incident A',N'CONC duplicate incident B'));
IF @ReportLinks<>2 OR @MaintenanceCount<>1
   OR (SELECT COUNT(*) FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S8-consolidation' AND result_status=N'CONSOLIDATED')<>1
   OR (SELECT COUNT(*) FROM dbo.concurrency_test_log_G11 WHERE scenario=N'S8-consolidation' AND result_status IN(N'ALREADY_CONSOLIDATED',N'SAFE_DEADLOCK_REJECT'))<>1
    INSERT @failures VALUES(N'S8-consolidation',N'Concurrent consolidation did not deduplicate correctly.');

SELECT scenario,actor,result_status,detail,recorded_at
FROM dbo.concurrency_test_log_G11
ORDER BY log_id;

IF EXISTS(SELECT 1 FROM @failures)
BEGIN
    SELECT scenario,failure_reason FROM @failures ORDER BY scenario;
    THROW 51399,N'G11 COMBINED CONCURRENCY DEMO: FAIL.',1;
END;

PRINT N'============================================================';
PRINT N'G11 COMBINED CONCURRENCY DEMO: ALL 8 SCENARIOS PASS';
PRINT N'============================================================';
GO
