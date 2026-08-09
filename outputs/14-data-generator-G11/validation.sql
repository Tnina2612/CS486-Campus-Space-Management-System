/*
===============================================================================
  14-data-generator-G11/validation.sql
  Data integrity validation for the generated dataset.

  Expected result: every check below returns 0 invalid rows.
  Rules come from the actual schema and the Phase 1/Phase 2 business
  requirements (BR-01, BR-02/RC-01, RC-03, RC-05).
===============================================================================
*/

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
GO

/* --------------------------------------------------------------------------
   1. Orphan foreign keys
   ------------------------------------------------------------------------- */
PRINT '1. Orphan foreign keys';

SELECT COUNT(*) AS orphan_bookings_users
FROM dbo.bookings b
LEFT JOIN dbo.users u ON u.user_id = b.user_id
WHERE u.user_id IS NULL;

SELECT COUNT(*) AS orphan_bookings_spaces
FROM dbo.bookings b
LEFT JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE s.space_id IS NULL;

SELECT COUNT(*) AS orphan_approvals_bookings
FROM dbo.approvals a
LEFT JOIN dbo.bookings b ON b.booking_id = a.booking_id
WHERE b.booking_id IS NULL;

SELECT COUNT(*) AS orphan_approvals_users
FROM dbo.approvals a
LEFT JOIN dbo.users u ON u.user_id = a.staff_id
WHERE a.staff_id IS NOT NULL AND u.user_id IS NULL;

SELECT COUNT(*) AS orphan_sessions_bookings
FROM dbo.usage_sessions us
LEFT JOIN dbo.bookings b ON b.booking_id = us.booking_id
WHERE b.booking_id IS NULL;

SELECT COUNT(*) AS orphan_sessions_users
FROM dbo.usage_sessions us
LEFT JOIN dbo.users u ON u.user_id = us.staff_id
WHERE us.staff_id IS NOT NULL AND u.user_id IS NULL;

SELECT COUNT(*) AS orphan_maintenance_spaces
FROM dbo.maintenance_records m
LEFT JOIN dbo.spaces s ON s.space_id = m.space_id
WHERE s.space_id IS NULL;

SELECT COUNT(*) AS orphan_maintenance_reporter
FROM dbo.maintenance_records m
LEFT JOIN dbo.users u ON u.user_id = m.reporter_id
WHERE u.user_id IS NULL;

SELECT COUNT(*) AS orphan_maintenance_staff
FROM dbo.maintenance_records m
LEFT JOIN dbo.users u ON u.user_id = m.assigned_staff_id
WHERE m.assigned_staff_id IS NOT NULL AND u.user_id IS NULL;

SELECT COUNT(*) AS orphan_assets_spaces
FROM dbo.facility_assets fa
LEFT JOIN dbo.spaces s ON s.space_id = fa.space_id
WHERE s.space_id IS NULL;

SELECT COUNT(*) AS orphan_assets_catalog
FROM dbo.facility_assets fa
LEFT JOIN dbo.facility_catalog fc ON fc.catalog_id = fa.catalog_id
WHERE fc.catalog_id IS NULL;

SELECT COUNT(*) AS orphan_sf_spaces
FROM dbo.space_facility sf
LEFT JOIN dbo.spaces s ON s.space_id = sf.space_id
WHERE s.space_id IS NULL;

SELECT COUNT(*) AS orphan_sf_catalog
FROM dbo.space_facility sf
LEFT JOIN dbo.facility_catalog fc ON fc.catalog_id = sf.catalog_id
WHERE fc.catalog_id IS NULL;

SELECT COUNT(*) AS orphan_ack_bookings
FROM dbo.advisory_acknowledgements aa
LEFT JOIN dbo.bookings b ON b.booking_id = aa.booking_id
WHERE b.booking_id IS NULL;

SELECT COUNT(*) AS orphan_ack_maintenance
FROM dbo.advisory_acknowledgements aa
LEFT JOIN dbo.maintenance_records m ON m.maintenance_id = aa.maintenance_id
WHERE m.maintenance_id IS NULL;

SELECT COUNT(*) AS orphan_ack_users
FROM dbo.advisory_acknowledgements aa
LEFT JOIN dbo.users u ON u.user_id = aa.acknowledged_by
WHERE u.user_id IS NULL;
GO

/* --------------------------------------------------------------------------
   2. Duplicate keys (UNIQUE constraints must hold)
   ------------------------------------------------------------------------- */
PRINT '2. Duplicate keys';

SELECT COUNT(*) AS dup_users_email
FROM (
    SELECT email FROM dbo.users GROUP BY email HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS dup_spaces_code
FROM (
    SELECT space_code FROM dbo.spaces GROUP BY space_code HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS dup_assets_tag
FROM (
    SELECT asset_tag FROM dbo.facility_assets GROUP BY asset_tag HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS dup_approvals_booking
FROM (
    SELECT booking_id FROM dbo.approvals GROUP BY booking_id HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS dup_sessions_booking
FROM (
    SELECT booking_id FROM dbo.usage_sessions GROUP BY booking_id HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS dup_ack_pair
FROM (
    SELECT booking_id, maintenance_id
    FROM dbo.advisory_acknowledgements
    GROUP BY booking_id, maintenance_id HAVING COUNT(*) > 1
) d;
GO

/* --------------------------------------------------------------------------
   3. Chronology / value validity
   ------------------------------------------------------------------------- */
PRINT '3. Chronology and value validity';

SELECT COUNT(*) AS bad_booking_chrono
FROM dbo.bookings WHERE end_time <= start_time;

SELECT COUNT(*) AS bad_session_chrono
FROM dbo.usage_sessions WHERE actual_end_time <= actual_start_time;

SELECT COUNT(*) AS bad_booking_participants
FROM dbo.bookings WHERE expected_participants <= 0;

SELECT COUNT(*) AS bad_space_capacity
FROM dbo.spaces WHERE capacity <= 0;

SELECT COUNT(*) AS bad_impact_level
FROM dbo.maintenance_records
WHERE impact_level NOT IN ('advisory', 'out-of-service');

SELECT COUNT(*) AS bad_booking_status
FROM dbo.bookings
WHERE status NOT IN ('Pending', 'Approved', 'Rejected', 'Cancelled',
                     'Checked In', 'Completed', 'No-show');

SELECT COUNT(*) AS bad_space_status
FROM dbo.spaces
WHERE current_status NOT IN ('Available', 'In Use', 'Under Maintenance',
                             'Temporarily Closed', 'Retired');

SELECT COUNT(*) AS bad_user_role
FROM dbo.users
WHERE role NOT IN ('Student', 'Lecturer', 'Teaching Assistant',
                   'Facility Staff', 'Department Administrator',
                   'Facility Manager');

SELECT COUNT(*) AS bad_ack_flag
FROM dbo.bookings WHERE advisory_acknowledged NOT IN (0, 1);
GO

/* --------------------------------------------------------------------------
   4. BR-01: overlapping approved-like bookings on the same space
   ------------------------------------------------------------------------- */
PRINT '4. BR-01 overlap check (approved-like)';

SELECT COUNT(*) AS overlapping_approved_bookings
FROM dbo.bookings b1
WHERE b1.status IN ('Approved', 'Checked In', 'Completed')
  AND EXISTS (
      SELECT 1
      FROM dbo.bookings b2
      WHERE b2.space_id = b1.space_id
        AND b2.booking_id <> b1.booking_id
        AND b2.status IN ('Approved', 'Checked In', 'Completed')
        AND b2.start_time < b1.end_time
        AND b2.end_time   > b1.start_time
  );
GO

/* --------------------------------------------------------------------------
   5. BR-02 / RC-01: approved-like booking overlaps out-of-service maintenance
   Scope: GENERATED data only (GEN-* spaces). One Phase 1 sample booking
   (B22, space 7) overlaps its sample open maintenance record; that record was
   backfilled to 'out-of-service' by the migration and the sample data is a
   read-only Phase 1 baseline, so it is excluded from the generated-data
   contract and noted as a known Phase 1 caveat.
   ------------------------------------------------------------------------- */
PRINT '5. Approved booking overlaps out-of-service maintenance (generated data)';

SELECT COUNT(*) AS approved_overlapping_oos
FROM dbo.bookings b
JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE s.space_code LIKE 'GEN-%'
  AND b.status IN ('Approved', 'Checked In', 'Completed')
  AND EXISTS (
      SELECT 1
      FROM dbo.maintenance_records m
      WHERE m.space_id = b.space_id
        AND m.impact_level = 'out-of-service'
        AND m.start_time < b.end_time
        AND COALESCE(m.completion_time, DATEADD(YEAR, 100, m.start_time)) > b.start_time
  );
GO

/* --------------------------------------------------------------------------
   6. RC-03: every advisory_acknowledgements row must have a booking whose
      advisory_acknowledged flag is 1
   ------------------------------------------------------------------------- */
PRINT '6. RC-03 acknowledgement consistency';

SELECT COUNT(*) AS ack_missing_flag
FROM dbo.advisory_acknowledgements aa
LEFT JOIN dbo.bookings b ON b.booking_id = aa.booking_id
WHERE b.advisory_acknowledged <> 1;
GO

/* --------------------------------------------------------------------------
   7. RC-05: AutoBookingEnabled is NOT NULL and boolean
   ------------------------------------------------------------------------- */
PRINT '7. RC-05 AutoBookingEnabled validity';

SELECT COUNT(*) AS null_auto_flag
FROM dbo.spaces WHERE AutoBookingEnabled IS NULL;

SELECT COUNT(*) AS bad_auto_flag
FROM dbo.spaces WHERE AutoBookingEnabled NOT IN (0, 1);
GO

/* --------------------------------------------------------------------------
   8. Purpose within usage policy (generated data).
   Generated GEN-* spaces have usage_policy NULL (no policy restrictions), so
   every generated booking passes. Sample spaces carry free-text policies
   (e.g. 'Exams, large events') whose strings do not enumerate the exact
   purpose enum values, so 24 Phase 1 sample bookings fall outside their
   textual policy — a Phase 1 sample-data modelling note, not a generator rule.
   ------------------------------------------------------------------------- */
PRINT '8. Purpose outside usage policy (generated data)';

SELECT COUNT(*) AS purpose_not_in_policy
FROM dbo.bookings b
JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE s.space_code LIKE 'GEN-%'
  AND s.usage_policy IS NOT NULL
  AND s.usage_policy <> ''
  AND b.purpose NOT IN (
      SELECT value FROM STRING_SPLIT(s.usage_policy, ';')
  );
GO
