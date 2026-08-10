USE CampusSpaceManagement;
GO
SET XACT_ABORT ON;
BEGIN TRAN;
DELETE aa FROM dbo.advisory_acknowledgements aa JOIN dbo.bookings b ON b.booking_id=aa.booking_id JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE rc FROM dbo.report_consolidations rc JOIN dbo.incident_reports ir ON ir.report_id=rc.incident_report_id JOIN dbo.spaces s ON s.space_id=ir.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE us FROM dbo.usage_sessions us JOIN dbo.bookings b ON b.booking_id=us.booking_id JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE a FROM dbo.approvals a JOIN dbo.bookings b ON b.booking_id=a.booking_id JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE ir FROM dbo.incident_reports ir JOIN dbo.spaces s ON s.space_id=ir.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE b FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE m FROM dbo.maintenance_records m JOIN dbo.spaces s ON s.space_id=m.space_id WHERE s.space_code LIKE N'CONC-%';
DELETE FROM dbo.spaces WHERE space_code LIKE N'CONC-%';
DELETE FROM dbo.users WHERE email LIKE N'concurrency.%@g11.local';
DELETE FROM dbo.concurrency_test_log_G11;
COMMIT;
PRINT N'Concurrency-lab rows removed.';
GO
