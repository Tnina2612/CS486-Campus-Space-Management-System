/* ============================================================================
   FILE    : 03-compare-and-validate-G11.sql (comparison section)
   PURPOSE : Display the final reproducible BEFORE/AFTER comparison and verify
             that indexing changed access cost, not business results.
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.index_benchmark_results_G11', N'U') IS NULL
    THROW 51030, 'Benchmark results are missing. Run files 02 through 04 first.', 1;

IF (SELECT COUNT(*) FROM dbo.index_benchmark_results_G11
    WHERE benchmark_phase = 'BEFORE') <> 12
   OR
   (SELECT COUNT(*) FROM dbo.index_benchmark_results_G11
    WHERE benchmark_phase = 'AFTER') <> 12
    THROW 51031, 'Expected three measured runs for four queries in each phase.', 1;

PRINT N'============================================================';
PRINT N'G11 FINAL INDEXING COMPARISON';
PRINT N'Lower logical reads and elapsed time are better.';
PRINT N'============================================================';

;WITH averages AS (
    SELECT benchmark_phase, query_id, query_name,
           AVG(CAST(logical_reads AS DECIMAL(19,4))) AS avg_reads,
           AVG(CAST(cpu_ms AS DECIMAL(19,4))) AS avg_cpu_ms,
           AVG(CAST(elapsed_us AS DECIMAL(19,4))) / 1000.0 AS avg_elapsed_ms,
           MIN(result_count) AS min_result_count,
           MAX(result_count) AS max_result_count
    FROM dbo.index_benchmark_results_G11
    GROUP BY benchmark_phase, query_id, query_name
),
comparison AS (
    SELECT b.query_id, b.query_name,
           b.avg_reads AS before_reads,
           a.avg_reads AS after_reads,
           b.avg_cpu_ms AS before_cpu_ms,
           a.avg_cpu_ms AS after_cpu_ms,
           b.avg_elapsed_ms AS before_elapsed_ms,
           a.avg_elapsed_ms AS after_elapsed_ms,
           b.min_result_count AS before_result_count,
           a.min_result_count AS after_result_count,
           CASE WHEN b.min_result_count = b.max_result_count
                     AND a.min_result_count = a.max_result_count
                     AND b.min_result_count = a.min_result_count
                THEN N'PASS - same result'
                ELSE N'FAIL - result changed'
           END AS correctness_check
    FROM averages AS b
    INNER JOIN averages AS a
            ON a.query_id = b.query_id
           AND a.benchmark_phase = 'AFTER'
    WHERE b.benchmark_phase = 'BEFORE'
)
SELECT query_id, query_name,
       CAST(before_reads AS DECIMAL(18,2)) AS before_logical_reads,
       CAST(after_reads AS DECIMAL(18,2)) AS after_logical_reads,
       CAST(100.0 * (before_reads - after_reads) / NULLIF(before_reads, 0)
            AS DECIMAL(8,2)) AS logical_reads_improvement_pct,
       CAST(before_cpu_ms AS DECIMAL(18,2)) AS before_cpu_ms,
       CAST(after_cpu_ms AS DECIMAL(18,2)) AS after_cpu_ms,
       CAST(before_elapsed_ms AS DECIMAL(18,3)) AS before_elapsed_ms,
       CAST(after_elapsed_ms AS DECIMAL(18,3)) AS after_elapsed_ms,
       CASE WHEN after_elapsed_ms = 0 THEN NULL
            ELSE CAST(100.0 * (before_elapsed_ms - after_elapsed_ms)
                 / NULLIF(before_elapsed_ms, 0) AS DECIMAL(8,2))
       END AS elapsed_improvement_pct,
       before_result_count,
       after_result_count,
       correctness_check
FROM comparison
ORDER BY query_id;

PRINT N'============================================================';
PRINT N'RAW RUNS (evidence; timing naturally varies by machine)';
PRINT N'============================================================';

SELECT benchmark_phase, query_id, query_name, run_number,
       result_count, logical_reads, cpu_ms,
       CAST(elapsed_us / 1000.0 AS DECIMAL(18,3)) AS elapsed_ms,
       captured_at
FROM dbo.index_benchmark_results_G11
ORDER BY query_id, benchmark_phase DESC, run_number;

PRINT N'============================================================';
PRINT N'INDEX SIZE AND DEFINITION EVIDENCE';
PRINT N'============================================================';

SELECT OBJECT_NAME(i.object_id) AS table_name,
       i.name AS index_name,
       SUM(ps.used_page_count) AS used_pages,
       CAST(SUM(ps.used_page_count) * 8.0 / 1024.0 AS DECIMAL(12,2)) AS used_mb
FROM sys.indexes AS i
INNER JOIN sys.dm_db_partition_stats AS ps
        ON ps.object_id = i.object_id AND ps.index_id = i.index_id
WHERE i.name IN (
    N'IX_bookings_space_time', N'IX_bookings_status_time',
    N'IX_maintenance_records_space_time', N'IX_spaces_capacity_status'
)
GROUP BY i.object_id, i.name
ORDER BY table_name, index_name;

PRINT N'DEMO COMPLETE. Keep this result grid and the Before/After execution plans as evidence.';
GO


/* ============================================================================
   FILE    : 03-compare-and-validate-G11.sql (validation section)
   PURPOSE : Final fail-fast validation for the completed indexing demo.
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
GO

IF (SELECT COUNT_BIG(*)
    FROM dbo.bookings AS b
    INNER JOIN dbo.spaces AS s ON s.space_id = b.space_id
    WHERE s.space_code LIKE N'GEN-%') <> 150000
    THROW 51040, 'VALIDATION FAILED: expected exactly 150,000 GEN bookings.', 1;

IF EXISTS (
    SELECT 1
    FROM (
        SELECT b.start_time,
               MAX(b.end_time) OVER (
                   PARTITION BY b.space_id
                   ORDER BY b.start_time, b.end_time, b.booking_id
                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
               ) AS latest_prior_end
        FROM dbo.bookings AS b
        INNER JOIN dbo.spaces AS s ON s.space_id = b.space_id
        WHERE s.space_code LIKE N'GEN-%'
    ) AS ordered_bookings
    WHERE start_time < latest_prior_end
)
    THROW 51041, 'VALIDATION FAILED: overlapping demo booking found.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.bookings AS b
    INNER JOIN dbo.spaces AS s ON s.space_id = b.space_id
    INNER JOIN dbo.maintenance_records AS m ON m.space_id = b.space_id
    WHERE s.space_code LIKE N'GEN-%'
      AND b.status IN (N'Approved', N'Checked In', N'Completed')
      AND m.impact_level = N'out-of-service'
      AND b.start_time < COALESCE(m.completion_time, '9999-12-31T23:59:59')
      AND b.end_time > m.start_time
)
    THROW 51042, 'VALIDATION FAILED: approved booking overlaps OOS maintenance.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.bookings AS b
    INNER JOIN dbo.spaces AS s ON s.space_id = b.space_id
    INNER JOIN dbo.maintenance_records AS m ON m.space_id = b.space_id
    WHERE s.space_code LIKE N'GEN-%'
      AND m.impact_level = N'advisory'
      AND b.start_time < COALESCE(m.completion_time, '9999-12-31T23:59:59')
      AND b.end_time > m.start_time
      AND (
          b.advisory_acknowledged <> 1
          OR b.advisory_snapshot IS NULL
          OR NOT EXISTS (
              SELECT 1
              FROM dbo.advisory_acknowledgements AS aa
              WHERE aa.booking_id = b.booking_id
                AND aa.maintenance_id = m.maintenance_id
          )
      )
)
    THROW 51047, 'VALIDATION FAILED: advisory acknowledgement is missing.', 1;

IF (SELECT COUNT(*) FROM sys.indexes
    WHERE name IN (
        N'IX_bookings_space_time', N'IX_bookings_status_time',
        N'IX_maintenance_records_space_time', N'IX_spaces_capacity_status'
    )) <> 4
    THROW 51043, 'VALIDATION FAILED: one or more tuned indexes are missing.', 1;

IF OBJECT_ID(N'dbo.index_benchmark_results_G11', N'U') IS NULL
    THROW 51044, 'VALIDATION FAILED: benchmark result table is missing.', 1;

IF EXISTS (
    SELECT query_id
    FROM dbo.index_benchmark_results_G11
    GROUP BY query_id
    HAVING MIN(result_count) <> MAX(result_count)
)
    THROW 51045, 'VALIDATION FAILED: a query result changed after indexing.', 1;

DECLARE @NonImprovingQueries INT;

;WITH a AS (
    SELECT benchmark_phase, query_id,
           AVG(CAST(logical_reads AS DECIMAL(19,4))) AS avg_reads
    FROM dbo.index_benchmark_results_G11
    GROUP BY benchmark_phase, query_id
)
SELECT @NonImprovingQueries = COUNT(*)
    FROM a AS b
    INNER JOIN a AS x ON x.query_id = b.query_id
    WHERE b.benchmark_phase = 'BEFORE'
      AND x.benchmark_phase = 'AFTER'
      AND x.avg_reads >= b.avg_reads;

IF @NonImprovingQueries > 0
    THROW 51046, 'VALIDATION FAILED: an AFTER query did not reduce logical reads.', 1;

PRINT N'============================================================';
PRINT N'G11 INDEX DEMO VALIDATION: PASS';
PRINT N'  - 150,000 deterministic demo bookings present';
PRINT N'  - no overlapping demo bookings';
PRINT N'  - no approved-like booking overlaps OOS maintenance';
PRINT N'  - every advisory overlap has acknowledgement + snapshot';
PRINT N'  - all four tuned indexes present';
PRINT N'  - all Before/After result counts match';
PRINT N'  - all four queries reduced average logical reads';
PRINT N'============================================================';
GO
