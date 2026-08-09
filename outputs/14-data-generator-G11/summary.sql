/*
===============================================================================
  14-data-generator-G11/summary.sql
  Reports the generated dataset: record counts, status/category distributions,
  date coverage and Phase 2 data coverage.
===============================================================================
*/

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
GO

PRINT '=== Record counts ===';
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM dbo.users
UNION ALL SELECT 'spaces', COUNT(*) FROM dbo.spaces
UNION ALL SELECT 'facility_catalog', COUNT(*) FROM dbo.facility_catalog
UNION ALL SELECT 'facility_assets', COUNT(*) FROM dbo.facility_assets
UNION ALL SELECT 'space_facility', COUNT(*) FROM dbo.space_facility
UNION ALL SELECT 'bookings', COUNT(*) FROM dbo.bookings
UNION ALL SELECT 'approvals', COUNT(*) FROM dbo.approvals
UNION ALL SELECT 'usage_sessions', COUNT(*) FROM dbo.usage_sessions
UNION ALL SELECT 'maintenance_records', COUNT(*) FROM dbo.maintenance_records
UNION ALL SELECT 'advisory_acknowledgements', COUNT(*) FROM dbo.advisory_acknowledgements
UNION ALL SELECT 'incident_reports', COUNT(*) FROM dbo.incident_reports
UNION ALL SELECT 'report_consolidations', COUNT(*) FROM dbo.report_consolidations
ORDER BY table_name;
GO

PRINT '=== Booking status distribution ===';
SELECT status, COUNT(*) AS n
FROM dbo.bookings
GROUP BY status
ORDER BY status;
GO

PRINT '=== Space current_status distribution ===';
SELECT current_status, COUNT(*) AS n
FROM dbo.spaces
GROUP BY current_status
ORDER BY current_status;
GO

PRINT '=== Space type distribution ===';
SELECT space_type, COUNT(*) AS n
FROM dbo.spaces
GROUP BY space_type
ORDER BY space_type;
GO

PRINT '=== Maintenance impact_level distribution (RC-01) ===';
SELECT impact_level, COUNT(*) AS n
FROM dbo.maintenance_records
GROUP BY impact_level
ORDER BY impact_level;
GO

PRINT '=== Maintenance status distribution ===';
SELECT status, COUNT(*) AS n
FROM dbo.maintenance_records
GROUP BY status
ORDER BY status;
GO

PRINT '=== User role distribution ===';
SELECT role, COUNT(*) AS n
FROM dbo.users
GROUP BY role
ORDER BY role;
GO

PRINT '=== AutoBookingEnabled spaces (RC-05) ===';
SELECT AutoBookingEnabled, COUNT(*) AS n
FROM dbo.spaces
GROUP BY AutoBookingEnabled;
GO

PRINT '=== Bookings with advisory acknowledged (RC-03) ===';
SELECT advisory_acknowledged, COUNT(*) AS n
FROM dbo.bookings
GROUP BY advisory_acknowledged;
GO

PRINT '=== Date coverage of generated bookings ===';
SELECT MIN(start_time) AS first_booking, MAX(end_time) AS last_booking,
       DATEDIFF(DAY, MIN(start_time), MAX(end_time)) AS span_days
FROM dbo.bookings;
GO

PRINT '=== Generated data date coverage (bookings per month) ===';
SELECT CONVERT(VARCHAR(7), start_time, 120) AS month, COUNT(*) AS n
FROM dbo.bookings
GROUP BY CONVERT(VARCHAR(7), start_time, 120)
ORDER BY month;
GO

PRINT '=== Phase 2 coverage: bookings overlapping an advisory (flagged) ===';
SELECT COUNT(*) AS advisory_overlapping_flagged
FROM dbo.bookings b
WHERE b.advisory_acknowledged = 1
  AND EXISTS (
      SELECT 1
      FROM dbo.maintenance_records m
      WHERE m.space_id = b.space_id
        AND m.impact_level = 'advisory'
        AND m.start_time < b.end_time
        AND COALESCE(m.completion_time, DATEADD(YEAR, 100, m.start_time)) > b.start_time
  );
GO

PRINT '=== Phase 2 coverage: acknowledgement rows per booking ===';
SELECT MIN(cnt) AS min_acks_per_booking, MAX(cnt) AS max_acks_per_booking,
       COUNT(*) AS acknowledged_bookings
FROM (
    SELECT booking_id, COUNT(*) AS cnt
    FROM dbo.advisory_acknowledgements
    GROUP BY booking_id
) a;
GO

PRINT '=== C8: incident report status distribution ===';
SELECT status, COUNT(*) AS n
FROM dbo.incident_reports
GROUP BY status
ORDER BY status;
GO

PRINT '=== C8: consolidation coverage (reports per maintenance record, top 10) ===';
SELECT TOP 10 maintenance_id, COUNT(*) AS reports_merged
FROM dbo.report_consolidations
WHERE maintenance_id IS NOT NULL
GROUP BY maintenance_id
ORDER BY reports_merged DESC;

PRINT '=== C8: maintenance records with the most merged reports ===';
SELECT COUNT(*) AS maintenance_records_with_reports
FROM (
    SELECT maintenance_id
    FROM dbo.report_consolidations
    WHERE maintenance_id IS NOT NULL
    GROUP BY maintenance_id
) m;
GO

PRINT '=== C8: consolidated vs unconsolidated incident reports ===';
SELECT
  (SELECT COUNT(*) FROM dbo.report_consolidations
   WHERE maintenance_id IS NOT NULL) AS consolidated_reports,
  (SELECT COUNT(*) FROM dbo.incident_reports
   WHERE report_id NOT IN (SELECT incident_report_id
                           FROM dbo.report_consolidations)) AS unconsolidated_reports;
GO
