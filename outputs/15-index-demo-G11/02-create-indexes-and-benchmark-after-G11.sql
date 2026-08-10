/* ============================================================================
   FILE    : 02-create-indexes-and-benchmark-after-G11.sql (index section)
   PURPOSE : Create exactly the four indexes evaluated by report 15.
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_bookings_space_time'
                 AND object_id = OBJECT_ID(N'dbo.bookings'))
BEGIN
    CREATE INDEX IX_bookings_space_time
        ON dbo.bookings (space_id, start_time, end_time)
        INCLUDE (status);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_bookings_status_time'
                 AND object_id = OBJECT_ID(N'dbo.bookings'))
BEGIN
    CREATE INDEX IX_bookings_status_time
        ON dbo.bookings (status, start_time, end_time)
        INCLUDE (space_id);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_maintenance_records_space_time'
                 AND object_id = OBJECT_ID(N'dbo.maintenance_records'))
BEGIN
    CREATE INDEX IX_maintenance_records_space_time
        ON dbo.maintenance_records (space_id, start_time, completion_time)
        INCLUDE (impact_level, status);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_spaces_capacity_status'
                 AND object_id = OBJECT_ID(N'dbo.spaces'))
BEGIN
    CREATE INDEX IX_spaces_capacity_status
        ON dbo.spaces (capacity, current_status)
        INCLUDE (space_type, space_name);
END;
GO

UPDATE STATISTICS dbo.bookings WITH FULLSCAN;
UPDATE STATISTICS dbo.maintenance_records WITH FULLSCAN;
UPDATE STATISTICS dbo.spaces WITH FULLSCAN;
GO

PRINT N'============================================================';
PRINT N'TUNED INDEXES CREATED';
PRINT N'============================================================';

SELECT OBJECT_NAME(i.object_id) AS table_name,
       i.name AS index_name,
       c.name AS column_name,
       CASE WHEN ic.is_included_column = 1 THEN N'INCLUDE' ELSE N'KEY' END
           AS column_role,
       ic.index_column_id AS column_order
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
        ON ic.object_id = i.object_id AND ic.index_id = i.index_id
INNER JOIN sys.columns AS c
        ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.name IN (
    N'IX_bookings_space_time', N'IX_bookings_status_time',
    N'IX_maintenance_records_space_time', N'IX_spaces_capacity_status'
)
ORDER BY table_name, index_name, column_order;

PRINT N'Indexes created. Continuing with the AFTER benchmark.';
GO


/* ============================================================================
   FILE    : 02-create-indexes-and-benchmark-after-G11.sql (benchmark section)
   PURPOSE : Re-run the identical benchmark after tuned indexes are created.

   DISPLAY : In SSMS, keep Actual Execution Plan enabled. Compare the final
             room-finder plan and Messages with file 02.
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.usp_RunIndexBenchmarkG11', N'P') IS NULL
   OR OBJECT_ID(N'dbo.index_benchmark_results_G11', N'U') IS NULL
    THROW 51020, 'Run 01-benchmark-before-indexing-G11.sql first.', 1;

IF (SELECT COUNT(*) FROM sys.indexes
    WHERE name IN (
        N'IX_bookings_space_time', N'IX_bookings_status_time',
        N'IX_maintenance_records_space_time', N'IX_spaces_capacity_status'
    )) <> 4
    THROW 51021, 'All four tuned indexes must exist before AFTER benchmark.', 1;

EXEC dbo.usp_RunIndexBenchmarkG11 @Phase = 'AFTER';
GO

PRINT N'============================================================';
PRINT N'AFTER INDEXING - THREE MEASURED WARM-CACHE RUNS';
PRINT N'============================================================';

SELECT query_id, query_name,
       CAST(AVG(CAST(logical_reads AS DECIMAL(18,2))) AS DECIMAL(18,2))
           AS avg_logical_reads,
       CAST(AVG(CAST(cpu_ms AS DECIMAL(18,2))) AS DECIMAL(18,2)) AS avg_cpu_ms,
       CAST(AVG(CAST(elapsed_us AS DECIMAL(18,2))) / 1000.0 AS DECIMAL(18,3))
           AS avg_elapsed_ms,
       MIN(result_count) AS result_count
FROM dbo.index_benchmark_results_G11
WHERE benchmark_phase = 'AFTER'
GROUP BY query_id, query_name
ORDER BY query_id;
GO

PRINT N'ROOM FINDER SHOWCASE AFTER INDEXING (expect seeks and lower reads)';
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @RoomStart DATETIME2 = '2024-06-04T11:00:00';
DECLARE @RoomEnd DATETIME2 = '2024-06-04T12:00:00';
DECLARE @MinCapacity INT = 170;
DECLARE @RequiredFacilities TABLE (catalog_id INT NOT NULL PRIMARY KEY);
INSERT INTO @RequiredFacilities (catalog_id)
SELECT MIN(catalog_id) FROM dbo.facility_catalog WHERE facility_name = N'Projector'
UNION ALL
SELECT MIN(catalog_id) FROM dbo.facility_catalog WHERE facility_name = N'Air Conditioner Unit';

SELECT s.space_id, s.space_code, s.space_name, s.space_type,
       s.building, s.floor, s.room_number, s.capacity, s.current_status
FROM dbo.spaces AS s
WHERE s.capacity >= @MinCapacity
  AND s.current_status NOT IN (N'Temporarily Closed', N'Retired')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.bookings AS b
      WHERE b.space_id = s.space_id
        AND b.status IN (N'Approved', N'Checked In', N'Completed')
        AND b.start_time < @RoomEnd
        AND b.end_time > @RoomStart
  )
  AND NOT EXISTS (
      SELECT 1 FROM dbo.maintenance_records AS m
      WHERE m.space_id = s.space_id
        AND m.impact_level = N'out-of-service'
        AND (m.completion_time IS NULL OR m.completion_time > @RoomStart)
        AND m.start_time < @RoomEnd
  )
  AND NOT EXISTS (
      SELECT 1 FROM @RequiredFacilities AS rf
      WHERE NOT EXISTS (
          SELECT 1 FROM dbo.space_facility AS sf
          WHERE sf.space_id = s.space_id
            AND sf.catalog_id = rf.catalog_id
      )
  )
ORDER BY s.capacity DESC, s.space_code;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

PRINT N'Next: execute 03-compare-and-validate-G11.sql.';
GO

