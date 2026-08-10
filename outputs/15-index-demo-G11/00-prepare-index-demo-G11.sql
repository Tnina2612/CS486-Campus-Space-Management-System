/* ============================================================================
   FILE    : 00-prepare-index-demo-G11.sql
   PURPOSE : Prepare the Phase 14 GEN-* dataset for a reproducible BEFORE test.
             No second 150,000-row fixture is created.
   REQUIRES: files 05, 06, 10, 12 and 14/01-generate-data-G11.sql.
   ============================================================================ */
USE [CampusSpaceManagement];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.bookings',N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance_records',N'U') IS NULL
   OR OBJECT_ID(N'dbo.advisory_acknowledgements',N'U') IS NULL
   OR COL_LENGTH(N'dbo.spaces',N'auto_booking_enabled') IS NULL
    THROW 51000,N'Phase 2 schema is missing. Run files 05, 06 and 10 first.',1;

IF (SELECT COUNT(*) FROM dbo.spaces WHERE space_code LIKE N'GEN-%')<>400
   OR (SELECT COUNT_BIG(*) FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id WHERE s.space_code LIKE N'GEN-%')<>150000
    THROW 51001,N'Phase 14 dataset is missing. Run outputs/14-data-generator-G11/01-generate-data-G11.sql first.',1;

PRINT N'============================================================';
PRINT N'G11 INDEX DEMO - PREPARING PHASE 14 DATASET';
PRINT N'============================================================';

/* Remove only temporary fixtures from earlier concurrency/index demos. GEN-*
   and Phase 1 data are preserved. This makes the total dataset deterministic. */
BEGIN TRY
    BEGIN TRAN;

    DELETE aa
      FROM dbo.advisory_acknowledgements aa
      JOIN dbo.bookings b ON b.booking_id=aa.booking_id
      JOIN dbo.spaces s ON s.space_id=b.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE rc
      FROM dbo.report_consolidations rc
      JOIN dbo.incident_reports ir ON ir.report_id=rc.incident_report_id
      JOIN dbo.spaces s ON s.space_id=ir.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE us
      FROM dbo.usage_sessions us
      JOIN dbo.bookings b ON b.booking_id=us.booking_id
      JOIN dbo.spaces s ON s.space_id=b.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE a
      FROM dbo.approvals a
      JOIN dbo.bookings b ON b.booking_id=a.booking_id
      JOIN dbo.spaces s ON s.space_id=b.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE ir
      FROM dbo.incident_reports ir
      JOIN dbo.spaces s ON s.space_id=ir.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE b
      FROM dbo.bookings b
      JOIN dbo.spaces s ON s.space_id=b.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE m
      FROM dbo.maintenance_records m
      JOIN dbo.spaces s ON s.space_id=m.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE fa
      FROM dbo.facility_assets fa
      JOIN dbo.spaces s ON s.space_id=fa.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE sf
      FROM dbo.space_facility sf
      JOIN dbo.spaces s ON s.space_id=sf.space_id
     WHERE s.space_code LIKE N'CONC-%' OR s.space_code LIKE N'IDX-%';

    DELETE FROM dbo.spaces WHERE space_code LIKE N'CONC-%' OR space_code LIKE N'IDX-%';
    DELETE FROM dbo.users WHERE email LIKE N'concurrency.%@g11.local';
    IF OBJECT_ID(N'dbo.concurrency_test_log_G11',N'U') IS NOT NULL
        DELETE FROM dbo.concurrency_test_log_G11;

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;

/* Fail-fast business-rule validation of the reused GEN-* fixture. */
IF EXISTS (
    SELECT 1
    FROM (
        SELECT b.start_time,
               MAX(b.end_time) OVER (
                   PARTITION BY b.space_id
                   ORDER BY b.start_time,b.end_time,b.booking_id
                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
               ) AS latest_prior_end
        FROM dbo.bookings b
        JOIN dbo.spaces s ON s.space_id=b.space_id
        WHERE s.space_code LIKE N'GEN-%'
    ) x
    WHERE x.start_time<x.latest_prior_end
)
    THROW 51002,N'Phase 14 validation failed: overlapping GEN booking found.',1;

IF EXISTS (
    SELECT 1
    FROM dbo.bookings b
    JOIN dbo.spaces s ON s.space_id=b.space_id
    JOIN dbo.maintenance_records m ON m.space_id=b.space_id
    WHERE s.space_code LIKE N'GEN-%'
      AND b.status IN(N'Approved',N'Checked In',N'Completed',N'No-show')
      AND m.impact_level=N'out-of-service'
      AND b.start_time<COALESCE(m.completion_time,'9999-12-31T23:59:59')
      AND b.end_time>m.start_time
)
    THROW 51003,N'Phase 14 validation failed: committed booking overlaps OOS maintenance.',1;

IF EXISTS (
    SELECT 1
    FROM dbo.bookings b
    JOIN dbo.spaces s ON s.space_id=b.space_id
    JOIN dbo.maintenance_records m ON m.space_id=b.space_id
    WHERE s.space_code LIKE N'GEN-%'
      AND m.impact_level=N'advisory'
      AND b.start_time<COALESCE(m.completion_time,'9999-12-31T23:59:59')
      AND b.end_time>m.start_time
      AND (b.advisory_acknowledged<>1 OR b.advisory_snapshot IS NULL
           OR NOT EXISTS(
               SELECT 1 FROM dbo.advisory_acknowledgements aa
               WHERE aa.booking_id=b.booking_id AND aa.maintenance_id=m.maintenance_id
           ))
)
    THROW 51004,N'Phase 14 validation failed: advisory acknowledgement is missing.',1;

/* Establish the true BEFORE baseline. PK/UNIQUE indexes remain intact. */
DROP INDEX IF EXISTS IX_bookings_space_time ON dbo.bookings;
DROP INDEX IF EXISTS IX_bookings_status_time ON dbo.bookings;
DROP INDEX IF EXISTS IX_maintenance_records_space_time ON dbo.maintenance_records;
DROP INDEX IF EXISTS IX_spaces_capacity_status ON dbo.spaces;

UPDATE STATISTICS dbo.bookings WITH FULLSCAN;
UPDATE STATISTICS dbo.maintenance_records WITH FULLSCAN;
UPDATE STATISTICS dbo.spaces WITH FULLSCAN;
UPDATE STATISTICS dbo.space_facility WITH FULLSCAN;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name IN(N'IX_bookings_space_time',N'IX_bookings_status_time',
                  N'IX_maintenance_records_space_time',N'IX_spaces_capacity_status')
)
    THROW 51005,N'Baseline preparation failed: a tuned index still exists.',1;

PRINT N'G11 INDEX DEMO DATA READY - BASELINE HAS NO TUNED INDEXES.';
SELECT COUNT(*) AS gen_spaces FROM dbo.spaces WHERE space_code LIKE N'GEN-%';
SELECT COUNT_BIG(*) AS gen_bookings,MIN(b.start_time) AS first_booking,MAX(b.end_time) AS last_booking
FROM dbo.bookings b JOIN dbo.spaces s ON s.space_id=b.space_id
WHERE s.space_code LIKE N'GEN-%';
SELECT COUNT(*) AS gen_maintenance_records
FROM dbo.maintenance_records m JOIN dbo.spaces s ON s.space_id=m.space_id
WHERE s.space_code LIKE N'GEN-%';
SELECT COUNT(*) AS gen_advisory_acknowledgements
FROM dbo.advisory_acknowledgements aa
JOIN dbo.bookings b ON b.booking_id=aa.booking_id
JOIN dbo.spaces s ON s.space_id=b.space_id
WHERE s.space_code LIKE N'GEN-%';
PRINT N'Next: execute 01-benchmark-before-indexing-G11.sql.';
GO
