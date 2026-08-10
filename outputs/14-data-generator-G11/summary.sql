/* ============================================================================
   FILE    : outputs/14-data-generator-G11/summary.sql
   PURPOSE : Report on the generated Phase 2 dataset: record counts, status
             distributions, date coverage, and Phase 2 feature coverage.
   RUN     : sqlcmd -S localhost -E -C -d CampusSpaceManagement -i summary.sql
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;

PRINT N'================ DATASET SUMMARY (Campus Space Management, G11) ================';

/* --- 1. Record counts ----------------------------------------------------- */
SELECT 'users' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN u.email LIKE '%@g11.generator.local' THEN 1 ELSE 0 END) AS generated
  FROM dbo.users u;
SELECT 'spaces' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.spaces s;
SELECT 'facility_catalog' AS table_name, COUNT(*) AS total, 0 AS generated
  FROM dbo.facility_catalog;
SELECT 'space_facility' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.space_facility sf
  LEFT JOIN dbo.spaces s ON s.space_id = sf.space_id;
SELECT 'facility_assets' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.facility_assets fa
  LEFT JOIN dbo.spaces s ON s.space_id = fa.space_id;
SELECT 'bookings' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.bookings b
  LEFT JOIN dbo.spaces s ON s.space_id = b.space_id;
SELECT 'approvals' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.approvals a
  LEFT JOIN dbo.bookings b ON b.booking_id = a.booking_id
  LEFT JOIN dbo.spaces s ON s.space_id = b.space_id;
SELECT 'usage_sessions' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.usage_sessions u
  LEFT JOIN dbo.bookings b ON b.booking_id = u.booking_id
  LEFT JOIN dbo.spaces s ON s.space_id = b.space_id;
SELECT 'maintenance_records' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.maintenance_records m
  LEFT JOIN dbo.spaces s ON s.space_id = m.space_id;
SELECT 'incident_reports' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.incident_reports ir
  LEFT JOIN dbo.spaces s ON s.space_id = ir.space_id;
SELECT 'report_consolidations' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.report_consolidations rc
  LEFT JOIN dbo.incident_reports ir ON ir.report_id = rc.incident_report_id
  LEFT JOIN dbo.spaces s ON s.space_id = ir.space_id;
SELECT 'advisory_acknowledgements' AS table_name, COUNT(*) AS total,
       SUM(CASE WHEN s.space_code LIKE 'GEN-%' THEN 1 ELSE 0 END) AS generated
  FROM dbo.advisory_acknowledgements aa
  LEFT JOIN dbo.bookings b ON b.booking_id = aa.booking_id
  LEFT JOIN dbo.spaces s ON s.space_id = b.space_id;

/* --- 2. Users: role distribution ------------------------------------------ */
SELECT role, COUNT(*) AS n
  FROM dbo.users WHERE email LIKE '%@g11.generator.local'
 GROUP BY role ORDER BY n DESC;

/* --- 3. Spaces: type / status / auto-booking ------------------------------ */
SELECT space_type, COUNT(*) AS n
  FROM dbo.spaces WHERE space_code LIKE 'GEN-%'
 GROUP BY space_type ORDER BY n DESC;
SELECT current_status, COUNT(*) AS n
  FROM dbo.spaces WHERE space_code LIKE 'GEN-%'
 GROUP BY current_status ORDER BY n DESC;
SELECT auto_booking_enabled, COUNT(*) AS n
  FROM dbo.spaces WHERE space_code LIKE 'GEN-%'
 GROUP BY auto_booking_enabled;

/* --- 4. Bookings: status / purpose distributions -------------------------- */
SELECT b.status, COUNT(*) AS n
  FROM dbo.bookings b
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE s.space_code LIKE 'GEN-%'
 GROUP BY b.status ORDER BY n DESC;
SELECT b.purpose, COUNT(*) AS n
  FROM dbo.bookings b
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE s.space_code LIKE 'GEN-%'
 GROUP BY b.purpose ORDER BY n DESC;

/* --- 5. Date coverage ------------------------------------------------------ */
SELECT CONVERT(VARCHAR(10), MIN(start_time), 120) AS first_booking,
       CONVERT(VARCHAR(10), MAX(end_time), 120)   AS last_booking,
       COUNT(DISTINCT CONVERT(VARCHAR(10), start_time, 120)) AS distinct_booking_days
  FROM dbo.bookings WHERE space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%');

/* --- 6. Maintenance: impact / status distributions ------------------------ */
SELECT m.impact_level, COUNT(*) AS n
  FROM dbo.maintenance_records m
  JOIN dbo.spaces s ON s.space_id = m.space_id
 WHERE s.space_code LIKE 'GEN-%'
 GROUP BY m.impact_level ORDER BY n DESC;
SELECT m.status, COUNT(*) AS n
  FROM dbo.maintenance_records m
  JOIN dbo.spaces s ON s.space_id = m.space_id
 WHERE s.space_code LIKE 'GEN-%'
 GROUP BY m.status ORDER BY n DESC;

/* --- 7. Incident reports: status / target-level coverage ------------------- */
SELECT ir.status, COUNT(*) AS n
  FROM dbo.incident_reports ir
  JOIN dbo.spaces s ON s.space_id = ir.space_id
 WHERE s.space_code LIKE 'GEN-%'
 GROUP BY ir.status ORDER BY n DESC;
SELECT CASE
         WHEN ir.space_facility_id IS NULL AND ir.asset_id IS NULL THEN 'room'
         WHEN ir.asset_id IS NOT NULL THEN 'asset'
         ELSE 'facility'
       END AS target_level, COUNT(*) AS n
  FROM dbo.incident_reports ir
  JOIN dbo.spaces s ON s.space_id = ir.space_id
 WHERE s.space_code LIKE 'GEN-%'
 GROUP BY CASE
         WHEN ir.space_facility_id IS NULL AND ir.asset_id IS NULL THEN 'room'
         WHEN ir.asset_id IS NOT NULL THEN 'asset'
         ELSE 'facility'
       END ORDER BY n DESC;

/* --- 8. Phase 2 feature coverage ------------------------------------------ */
SELECT 'auto-approval (staff_id NULL)' AS feature,
       COUNT(*) AS n
  FROM dbo.approvals a
  JOIN dbo.bookings b ON b.booking_id = a.booking_id
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE a.staff_id IS NULL
   AND s.space_code LIKE 'GEN-%';

SELECT 'bookings with advisory snapshot' AS feature, COUNT(*) AS n
  FROM dbo.bookings b
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE b.advisory_snapshot IS NOT NULL
   AND s.space_code LIKE 'GEN-%';

SELECT 'consolidations linking reports to maintenance' AS feature, COUNT(*) AS n
  FROM dbo.report_consolidations
 WHERE maintenance_id IS NOT NULL;

PRINT N'================ END OF SUMMARY ================';
