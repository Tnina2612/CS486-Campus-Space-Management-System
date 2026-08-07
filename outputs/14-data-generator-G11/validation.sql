-- Validation checks for the generated dataset.
-- Each query below must return zero rows for the dataset to be valid
-- (except the informational counts section).

USE [CampusSpaceManagement];
GO

-- 1. Record counts
SELECT 'users' AS tbl, COUNT(*) AS cnt FROM dbo.users
UNION ALL SELECT 'spaces',            COUNT(*) FROM dbo.spaces
UNION ALL SELECT 'facility_catalog',  COUNT(*) FROM dbo.facility_catalog
UNION ALL SELECT 'space_facility',    COUNT(*) FROM dbo.space_facility
UNION ALL SELECT 'facility_assets',   COUNT(*) FROM dbo.facility_assets
UNION ALL SELECT 'bookings',          COUNT(*) FROM dbo.bookings
UNION ALL SELECT 'approvals',         COUNT(*) FROM dbo.approvals
UNION ALL SELECT 'usage_sessions',    COUNT(*) FROM dbo.usage_sessions
UNION ALL SELECT 'maintenance_records',COUNT(*) FROM dbo.maintenance_records
UNION ALL SELECT 'maintenance_impact_history', COUNT(*) FROM dbo.maintenance_impact_history
UNION ALL SELECT 'advisory_acknowledgements', COUNT(*) FROM dbo.advisory_acknowledgements;
GO

-- 2. Invalid dates (end <= start)
SELECT 'bookings_invalid_date' AS check_name, COUNT(*) AS bad
FROM dbo.bookings WHERE end_time <= start_time;
GO
SELECT 'sessions_invalid_date' AS check_name, COUNT(*) AS bad
FROM dbo.usage_sessions WHERE actual_end_time IS NOT NULL
  AND actual_end_time <= actual_start_time;
GO

-- 3. Orphan foreign keys (should be zero thanks to DB constraints; sanity check)
SELECT 'orphan_booking_space' AS check_name, COUNT(*) AS bad
FROM dbo.bookings b
LEFT JOIN dbo.spaces s ON b.space_id = s.space_id WHERE s.space_id IS NULL;
GO

-- 4. Duplicate keys (UNIQUE handled by DB; reports if data violates)
SELECT 'dup_ack' AS check_name, COUNT(*) AS bad
FROM dbo.advisory_acknowledgements
GROUP BY booking_id, maintenance_id HAVING COUNT(*) > 1;
GO

-- 5. Approved booking conflicts (overlapping approved bookings on same space)
SELECT 'approved_overlap' AS check_name, COUNT(*) AS bad
FROM dbo.bookings a
JOIN dbo.bookings b
  ON a.space_id = b.space_id
 AND a.booking_id < b.booking_id
 AND a.status IN ('Approved','Checked In','Completed','No-show')
 AND b.status IN ('Approved','Checked In','Completed','No-show')
 AND a.start_time < b.end_time AND a.end_time > b.start_time;
GO

-- 6. Approved bookings overlapping out-of-service maintenance
SELECT 'approved_over_oos' AS check_name, COUNT(*) AS bad
FROM dbo.bookings b
JOIN dbo.maintenance_records m
  ON b.space_id = m.space_id
 AND m.impact_level = 'out-of-service'
 AND b.status IN ('Approved','Checked In','Completed','No-show')
 AND (m.completion_time IS NULL OR m.completion_time > b.start_time)
 AND m.start_time < b.end_time;
GO

-- 7. Missing advisory acknowledgements
-- Any approved booking overlapping an active advisory must have an ack row.
SELECT 'missing_ack' AS check_name, COUNT(*) AS bad
FROM dbo.bookings b
JOIN dbo.maintenance_records m
  ON b.space_id = m.space_id
 AND m.impact_level = 'advisory'
 AND b.status IN ('Approved','Checked In','Completed','No-show')
 AND (m.completion_time IS NULL OR m.completion_time > b.start_time)
 AND m.start_time < b.end_time
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.advisory_acknowledgements a
    WHERE a.booking_id = b.booking_id AND a.maintenance_id = m.maintenance_id
);
GO

-- 8. Invalid acknowledgement links (booking/maintenance placed on other space)
SELECT 'ack_wrong_space' AS check_name, COUNT(*) AS bad
FROM dbo.advisory_acknowledgements ack
JOIN dbo.bookings b ON ack.booking_id = b.booking_id
JOIN dbo.maintenance_records m ON ack.maintenance_id = m.maintenance_id
WHERE b.space_id <> m.space_id;
GO

-- 9. Booking-status inconsistencies
-- A booking with status Rejected must have an approval with rejection reason.
SELECT 'rejected_no_reason' AS check_name, COUNT(*) AS bad
FROM dbo.bookings b
WHERE b.status = 'Rejected'
  AND NOT EXISTS (SELECT 1 FROM dbo.approvals a
                  WHERE a.booking_id = b.booking_id
                    AND a.rejection_reason IS NOT NULL);
GO