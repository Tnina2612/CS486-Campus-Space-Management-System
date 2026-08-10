/* ============================================================================
   FILE    : outputs/14-data-generator-G11/validation.sql
   PURPOSE : Validate the generated Phase 2 dataset (and the whole database).
             Every check must return 0 rows / 0 counts.  Business rules from
             req/business-requirement.md and outputs/08 / 09.
   RUN     : sqlcmd -S localhost -E -C -d CampusSpaceManagement -i validation.sql
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @genSpaceFilter NVARCHAR(400) = N'
    WHERE space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE ''GEN-%'')';

/* ---------------------------------------------------------------------------
   1. Invalid dates / chrono violations
--------------------------------------------------------------------------- */
SELECT '1.1 bookings end<=start' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings
 WHERE end_time <= start_time;

SELECT '1.2 usage_sessions end<=start' AS check_name, COUNT(*) AS violations
  FROM dbo.usage_sessions
 WHERE actual_end_time IS NOT NULL AND actual_end_time <= actual_start_time;

SELECT '1.3 bookings outside semester range' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE s.space_code LIKE 'GEN-%'
   AND (b.start_time < '2026-03-02' OR b.end_time > '2026-07-15');

/* ---------------------------------------------------------------------------
   2. Orphan foreign keys
--------------------------------------------------------------------------- */
SELECT '2.1 bookings.user_id' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b LEFT JOIN dbo.users u ON u.user_id = b.user_id
 WHERE u.user_id IS NULL;

SELECT '2.2 bookings.space_id' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b LEFT JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE s.space_id IS NULL;

SELECT '2.3 approvals.booking_id' AS check_name, COUNT(*) AS violations
  FROM dbo.approvals a LEFT JOIN dbo.bookings b ON b.booking_id = a.booking_id
 WHERE b.booking_id IS NULL;

SELECT '2.4 approvals.staff_id' AS check_name, COUNT(*) AS violations
  FROM dbo.approvals a LEFT JOIN dbo.users u ON u.user_id = a.staff_id
 WHERE a.staff_id IS NOT NULL AND u.user_id IS NULL;

SELECT '2.5 usage_sessions.booking_id' AS check_name, COUNT(*) AS violations
  FROM dbo.usage_sessions u LEFT JOIN dbo.bookings b ON b.booking_id = u.booking_id
 WHERE b.booking_id IS NULL;

SELECT '2.6 maintenance.space_id' AS check_name, COUNT(*) AS violations
  FROM dbo.maintenance_records m LEFT JOIN dbo.spaces s ON s.space_id = m.space_id
 WHERE s.space_id IS NULL;

SELECT '2.7 space_facility.space_id' AS check_name, COUNT(*) AS violations
  FROM dbo.space_facility sf LEFT JOIN dbo.spaces s ON s.space_id = sf.space_id
 WHERE s.space_id IS NULL;

SELECT '2.8 space_facility.catalog_id' AS check_name, COUNT(*) AS violations
  FROM dbo.space_facility sf LEFT JOIN dbo.facility_catalog c ON c.catalog_id = sf.catalog_id
 WHERE c.catalog_id IS NULL;

SELECT '2.9 facility_assets.space_facility_id' AS check_name, COUNT(*) AS violations
  FROM dbo.facility_assets fa LEFT JOIN dbo.space_facility sf ON sf.space_facility_id = fa.space_facility_id
 WHERE sf.space_facility_id IS NULL;

SELECT '2.10 incident_reports.user_id' AS check_name, COUNT(*) AS violations
  FROM dbo.incident_reports ir LEFT JOIN dbo.users u ON u.user_id = ir.user_id
 WHERE u.user_id IS NULL;

SELECT '2.11 incident_reports.space_id' AS check_name, COUNT(*) AS violations
  FROM dbo.incident_reports ir LEFT JOIN dbo.spaces s ON s.space_id = ir.space_id
 WHERE s.space_id IS NULL;

SELECT '2.12 incident_reports.space_facility_id' AS check_name, COUNT(*) AS violations
  FROM dbo.incident_reports ir LEFT JOIN dbo.space_facility sf ON sf.space_facility_id = ir.space_facility_id
 WHERE ir.space_facility_id IS NOT NULL AND sf.space_facility_id IS NULL;

SELECT '2.13 incident_reports.asset_id' AS check_name, COUNT(*) AS violations
  FROM dbo.incident_reports ir LEFT JOIN dbo.facility_assets fa ON fa.asset_id = ir.asset_id
 WHERE ir.asset_id IS NOT NULL AND fa.asset_id IS NULL;

SELECT '2.14 report_consolidations.incident_report_id' AS check_name, COUNT(*) AS violations
  FROM dbo.report_consolidations rc LEFT JOIN dbo.incident_reports ir ON ir.report_id = rc.incident_report_id
 WHERE ir.report_id IS NULL;

SELECT '2.15 report_consolidations.maintenance_id' AS check_name, COUNT(*) AS violations
  FROM dbo.report_consolidations rc LEFT JOIN dbo.maintenance_records m ON m.maintenance_id = rc.maintenance_id
 WHERE rc.maintenance_id IS NOT NULL AND m.maintenance_id IS NULL;

SELECT '2.16 advisory_acknowledgements.booking_id' AS check_name, COUNT(*) AS violations
  FROM dbo.advisory_acknowledgements a LEFT JOIN dbo.bookings b ON b.booking_id = a.booking_id
 WHERE b.booking_id IS NULL;

SELECT '2.17 advisory_acknowledgements.maintenance_id' AS check_name, COUNT(*) AS violations
  FROM dbo.advisory_acknowledgements a LEFT JOIN dbo.maintenance_records m ON m.maintenance_id = a.maintenance_id
 WHERE m.maintenance_id IS NULL;

/* ---------------------------------------------------------------------------
   3. Business rule BR-01: no overlapping committed bookings on the same space
      Committed = Approved / Checked In / Completed / No-show
--------------------------------------------------------------------------- */
SELECT '3.1 BR-01 overlapping committed bookings' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings a
  JOIN dbo.bookings b
    ON a.space_id = b.space_id
   AND a.booking_id < b.booking_id
 WHERE a.status IN ('Approved','Checked In','Completed','No-show')
   AND b.status IN ('Approved','Checked In','Completed','No-show')
   AND a.start_time < b.end_time
   AND b.start_time < a.end_time;

/* ---------------------------------------------------------------------------
   4. BR-02 / BR-11: no committed booking overlaps an out-of-service window.
      Scoped to generated (GEN-*) spaces: pre-existing Phase 1 bookings may
      overlap migration-created maintenance rows and are preserved as-is.
--------------------------------------------------------------------------- */
SELECT '4.1 BR-11 committed booking overlaps out-of-service (GEN-* only)' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b
  JOIN dbo.maintenance_records m
    ON m.space_id = b.space_id
   AND m.impact_level = 'out-of-service'
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE b.status IN ('Approved','Checked In','Completed','No-show')
   AND s.space_code LIKE 'GEN-%'
   AND b.start_time < ISNULL(m.completion_time, '9999-12-31')
   AND m.start_time < b.end_time;

/* ---------------------------------------------------------------------------
   5. BR-11 advisory acknowledgement: a committed booking overlapping an
      advisory window MUST be acknowledged (flag + ack row). Scoped to
      generated (GEN-*) spaces for the same reason as check 4.1.
--------------------------------------------------------------------------- */
SELECT '5.1 advisory overlap but flag=0 (GEN-* only)' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b
  JOIN dbo.maintenance_records m
    ON m.space_id = b.space_id
   AND m.impact_level = 'advisory'
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE b.status IN ('Approved','Checked In','Completed','No-show')
   AND s.space_code LIKE 'GEN-%'
   AND b.start_time < ISNULL(m.completion_time, '9999-12-31')
   AND m.start_time < b.end_time
   AND b.advisory_acknowledged = 0;

SELECT '5.2 advisory overlap but no ack row (GEN-* only)' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b
  JOIN dbo.maintenance_records m
    ON m.space_id = b.space_id
   AND m.impact_level = 'advisory'
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE b.status IN ('Approved','Checked In','Completed','No-show')
   AND s.space_code LIKE 'GEN-%'
   AND b.start_time < ISNULL(m.completion_time, '9999-12-31')
   AND m.start_time < b.end_time
   AND NOT EXISTS (
       SELECT 1 FROM dbo.advisory_acknowledgements aa
        WHERE aa.booking_id = b.booking_id
          AND aa.maintenance_id = m.maintenance_id
   );

SELECT '5.3 ack row but flag=0 (GEN-* only)' AS check_name, COUNT(*) AS violations
  FROM dbo.advisory_acknowledgements aa
  JOIN dbo.bookings b ON b.booking_id = aa.booking_id
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE b.advisory_acknowledged = 0
   AND s.space_code LIKE 'GEN-%';

/* ---------------------------------------------------------------------------
   6. BR-02: bookings on Temporarily Closed / Retired spaces
--------------------------------------------------------------------------- */
SELECT '6.1 BR-02 booking on closed/retired space' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b
  JOIN dbo.spaces s ON s.space_id = b.space_id
 WHERE s.current_status IN ('Temporarily Closed','Retired');

/* ---------------------------------------------------------------------------
   7. Facility trigger rule: trackable quantity <= registered assets.
      Scoped to generated (GEN-*) spaces: the Phase 1 sample data deliberately
      disabled the trigger while seeding, leaving pre-existing rows whose
      quantity exceeds the registered asset count. Those rows are Phase 1
      output and are preserved as-is.
--------------------------------------------------------------------------- */
SELECT '7.1 trackable quantity > assets (GEN-* only)' AS check_name, COUNT(*) AS violations
  FROM dbo.space_facility sf
  JOIN dbo.facility_catalog c ON c.catalog_id = sf.catalog_id
 WHERE c.is_trackable = 1
   AND sf.space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE 'GEN-%')
   AND sf.quantity > (
       SELECT COUNT(*) FROM dbo.facility_assets fa
        WHERE fa.space_id = sf.space_id
          AND fa.catalog_id = sf.catalog_id
   );

/* ---------------------------------------------------------------------------
   8. Phase 2 report-target integrity (BR-14)
      - asset_id requires space_facility_id
      - (space_facility_id, asset_id) must exist in facility_assets
--------------------------------------------------------------------------- */
SELECT '8.1 asset without facility instance' AS check_name, COUNT(*) AS violations
  FROM dbo.incident_reports
 WHERE asset_id IS NOT NULL AND space_facility_id IS NULL;

SELECT '8.2 asset not matching facility instance' AS check_name, COUNT(*) AS violations
  FROM dbo.incident_reports ir
 WHERE ir.asset_id IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM dbo.facility_assets fa
        WHERE fa.space_facility_id = ir.space_facility_id
          AND fa.asset_id = ir.asset_id
   );

/* ---------------------------------------------------------------------------
   9. BR-04: rejected bookings must carry a rejection reason
--------------------------------------------------------------------------- */
SELECT '9.1 BR-04 rejected without reason' AS check_name, COUNT(*) AS violations
  FROM dbo.bookings b
  LEFT JOIN dbo.approvals a ON a.booking_id = b.booking_id
 WHERE b.status = 'Rejected'
   AND (a.approval_id IS NULL OR a.rejection_reason IS NULL OR LTRIM(a.rejection_reason) = '');

/* ---------------------------------------------------------------------------
   10. Phase 2 mandatory coverage: at least one of each impact level
--------------------------------------------------------------------------- */
SELECT '10.1 no out-of-service maintenance' AS check_name, COUNT(*) AS violations
  FROM (SELECT 1 AS x) t
 WHERE NOT EXISTS (SELECT 1 FROM dbo.maintenance_records WHERE impact_level = 'out-of-service');

SELECT '10.2 no advisory maintenance' AS check_name, COUNT(*) AS violations
  FROM (SELECT 1 AS x) t
 WHERE NOT EXISTS (SELECT 1 FROM dbo.maintenance_records WHERE impact_level = 'advisory');

SELECT '10.3 no consolidated incident reports' AS check_name, COUNT(*) AS violations
  FROM (SELECT 1 AS x) t
 WHERE NOT EXISTS (SELECT 1 FROM dbo.report_consolidations WHERE maintenance_id IS NOT NULL);

SELECT '10.4 no advisory acknowledgements' AS check_name, COUNT(*) AS violations
  FROM (SELECT 1 AS x) t
 WHERE NOT EXISTS (SELECT 1 FROM dbo.advisory_acknowledgements);

/* ---------------------------------------------------------------------------
   11. Duplicate natural keys across generated data
--------------------------------------------------------------------------- */
SELECT '11.1 duplicate asset_tag' AS check_name, COUNT(*) AS violations
  FROM (SELECT asset_tag FROM dbo.facility_assets GROUP BY asset_tag HAVING COUNT(*) > 1) t;

SELECT '11.2 duplicate space_code' AS check_name, COUNT(*) AS violations
  FROM (SELECT space_code FROM dbo.spaces GROUP BY space_code HAVING COUNT(*) > 1) t;

SELECT '11.3 duplicate email' AS check_name, COUNT(*) AS violations
  FROM (SELECT email FROM dbo.users GROUP BY email HAVING COUNT(*) > 1) t;

SELECT '11.4 double consolidation (report in 2 maintenance records)' AS check_name, COUNT(*) AS violations
  FROM (SELECT incident_report_id FROM dbo.report_consolidations
         GROUP BY incident_report_id HAVING COUNT(*) > 1) t;

PRINT N'VALIDATION COMPLETE - every row above must show 0 violations.';
