-- Summary report for the generated dataset.
USE [CampusSpaceManagement];
GO

-- Bookings by academic year (inferred from start_time).
SELECT
    CASE
        WHEN start_time >= '2024-09-01' AND start_time < '2025-06-01' THEN '2024-2025'
        WHEN start_time >= '2025-09-01' AND start_time < '2026-06-01' THEN '2025-2026'
        WHEN start_time >= '2026-09-01' AND start_time < '2027-06-01' THEN '2026-2027'
        ELSE 'Other'
    END AS academic_year,
    COUNT(*) AS bookings
FROM dbo.bookings
GROUP BY CASE
    WHEN start_time >= '2024-09-01' AND start_time < '2025-06-01' THEN '2024-2025'
    WHEN start_time >= '2025-09-01' AND start_time < '2026-06-01' THEN '2025-2026'
    WHEN start_time >= '2026-09-01' AND start_time < '2027-06-01' THEN '2026-2027'
    ELSE 'Other'
END
ORDER BY academic_year;
GO

-- Bookings by status
SELECT status, COUNT(*) AS cnt
FROM dbo.bookings
GROUP BY status
ORDER BY status;
GO

-- Maintenance by impact level
SELECT impact_level, COUNT(*) AS cnt
FROM dbo.maintenance_records
GROUP BY impact_level;
GO

-- Acknowledgement count
SELECT COUNT(*) AS acknowledgement_count FROM dbo.advisory_acknowledgements;
GO

-- Earliest / latest booking dates
SELECT MIN(start_time) AS earliest, MAX(end_time) AS latest FROM dbo.bookings;
GO