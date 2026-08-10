/* ============================================================================
   FILE    : 01-benchmark-before-indexing-G11.sql
   PURPOSE : Measure four critical queries before tuned indexes exist.

   DISPLAY : In SSMS, press Ctrl+M before executing this file. The final
             room-finder query then shows its Actual Execution Plan. Messages
             also show the authoritative STATISTICS IO/TIME values.
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name IN (
        N'IX_bookings_space_time', N'IX_bookings_status_time',
        N'IX_maintenance_records_space_time', N'IX_spaces_capacity_status'
    )
)
    THROW 51010, 'BEFORE benchmark requires all four tuned indexes to be absent.', 1;

IF (SELECT COUNT_BIG(*)
    FROM dbo.bookings AS b
    INNER JOIN dbo.spaces AS s ON s.space_id = b.space_id
    WHERE s.space_code LIKE N'GEN-%') < 100000
    THROW 51011, 'Benchmark fixture missing: run 00-prepare-index-demo-G11.sql first.', 1;

DROP TABLE IF EXISTS dbo.index_benchmark_results_G11;
GO

CREATE TABLE dbo.index_benchmark_results_G11 (
    result_id       INT IDENTITY(1,1) PRIMARY KEY,
    benchmark_phase VARCHAR(10) NOT NULL
        CHECK (benchmark_phase IN ('BEFORE', 'AFTER')),
    query_id        TINYINT NOT NULL,
    query_name      NVARCHAR(100) NOT NULL,
    run_number      TINYINT NOT NULL,
    result_count    BIGINT NOT NULL,
    logical_reads   BIGINT NOT NULL,
    cpu_ms          BIGINT NOT NULL,
    elapsed_us      BIGINT NOT NULL,
    captured_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_index_benchmark_G11 UNIQUE
        (benchmark_phase, query_id, run_number)
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_RunIndexBenchmarkG11
    @Phase VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Phase NOT IN ('BEFORE', 'AFTER')
        THROW 51012, 'Benchmark phase must be BEFORE or AFTER.', 1;

    DELETE FROM dbo.index_benchmark_results_G11
    WHERE benchmark_phase = @Phase;

    DECLARE @DemoSpaceID INT;
    DECLARE @ConflictStart DATETIME2;
    DECLARE @ConflictEnd DATETIME2;
    DECLARE @RoomStart DATETIME2 = '2024-06-04T11:00:00';
    DECLARE @RoomEnd DATETIME2 = '2024-06-04T12:00:00';
    /* Capacity 170 leaves 50 realistic candidates. This keeps the unindexed
       demonstration visible but short enough for a live classroom run. */
    DECLARE @MinCapacity INT = 170;
    DECLARE @SemStart DATETIME2 = '2023-01-01T00:00:00';
    DECLARE @SemEnd DATETIME2 = '2026-02-01T00:00:00';
    DECLARE @ProjectorID INT =
        (SELECT MIN(catalog_id) FROM dbo.facility_catalog
         WHERE facility_name = N'Projector');
    DECLARE @AirConditionerID INT =
        (SELECT MIN(catalog_id) FROM dbo.facility_catalog
         WHERE facility_name = N'Air Conditioner Unit');

    /* Choose a late clustered-key match so the baseline conflict scan cannot
       terminate near the beginning of the bookings table. */
    SELECT TOP (1)
           @DemoSpaceID = b.space_id,
           @ConflictStart = DATEADD(MINUTE, 15, b.start_time),
           @ConflictEnd = DATEADD(MINUTE, 45, b.start_time)
    FROM dbo.bookings AS b
    INNER JOIN dbo.spaces AS s ON s.space_id = b.space_id
    WHERE s.space_code = N'GEN-0400'
      AND b.status IN (N'Approved', N'Checked In', N'Completed')
    ORDER BY b.booking_id DESC;

    DECLARE @RequiredFacilities TABLE (
        catalog_id INT NOT NULL PRIMARY KEY
    );
    INSERT INTO @RequiredFacilities (catalog_id)
    VALUES (@ProjectorID), (@AirConditionerID);

    DECLARE @RoomResults TABLE (
        space_id INT NOT NULL,
        space_code NVARCHAR(20) NOT NULL,
        space_name NVARCHAR(100) NOT NULL,
        space_type NVARCHAR(50) NOT NULL,
        building NVARCHAR(100) NOT NULL,
        floor INT NOT NULL,
        room_number NVARCHAR(20) NOT NULL,
        capacity INT NOT NULL,
        current_status NVARCHAR(20) NOT NULL
    );

    DECLARE @Run TINYINT = 0;
    DECLARE @Rows BIGINT;
    DECLARE @Digest INT;
    DECLARE @ReadsBefore BIGINT, @ReadsAfter BIGINT;
    DECLARE @CpuBefore BIGINT, @CpuAfter BIGINT;
    DECLARE @Started DATETIME2, @Finished DATETIME2;

    /* Run 0 warms pages/plans equally. Runs 1..3 are persisted. */
    WHILE @Run <= 3
    BEGIN
        /* Q1 - booking conflict EXISTS, the correctness-critical hot path. */
        SELECT @ReadsBefore = logical_reads, @CpuBefore = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;
        SET @Started = SYSUTCDATETIME();

        SET @Rows = CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.bookings AS b WITH (UPDLOCK, HOLDLOCK)
            WHERE b.space_id = @DemoSpaceID
              AND b.status IN (N'Approved', N'Checked In', N'Completed')
              AND b.start_time < @ConflictEnd
              AND b.end_time > @ConflictStart
        ) THEN 1 ELSE 0 END;

        SET @Finished = SYSUTCDATETIME();
        SELECT @ReadsAfter = logical_reads, @CpuAfter = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;

        IF @Run > 0
            INSERT INTO dbo.index_benchmark_results_G11
                (benchmark_phase, query_id, query_name, run_number,
                 result_count, logical_reads, cpu_ms, elapsed_us)
            VALUES
                (@Phase, 1, N'Booking conflict check', @Run, @Rows,
                 @ReadsAfter - @ReadsBefore, @CpuAfter - @CpuBefore,
                 DATEDIFF_BIG(MICROSECOND, @Started, @Finished));

        /* Q2 - room finder: capacity + two facilities + no conflict/OOS. */
        DELETE FROM @RoomResults;
        SELECT @ReadsBefore = logical_reads, @CpuBefore = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;
        SET @Started = SYSUTCDATETIME();

        INSERT INTO @RoomResults
            (space_id, space_code, space_name, space_type, building, floor,
             room_number, capacity, current_status)
        SELECT s.space_id, s.space_code, s.space_name, s.space_type,
               s.building, s.floor, s.room_number, s.capacity, s.current_status
        FROM dbo.spaces AS s
        WHERE s.capacity >= @MinCapacity
          AND s.current_status NOT IN (N'Temporarily Closed', N'Retired')
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.bookings AS b
              WHERE b.space_id = s.space_id
                AND b.status IN (N'Approved', N'Checked In', N'Completed')
                AND b.start_time < @RoomEnd
                AND b.end_time > @RoomStart
          )
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.maintenance_records AS m
              WHERE m.space_id = s.space_id
                AND m.impact_level = N'out-of-service'
                AND (m.completion_time IS NULL OR m.completion_time > @RoomStart)
                AND m.start_time < @RoomEnd
          )
          AND NOT EXISTS (
              SELECT 1
              FROM @RequiredFacilities AS rf
              WHERE NOT EXISTS (
                  SELECT 1
                  FROM dbo.space_facility AS sf
                  WHERE sf.space_id = s.space_id
                    AND sf.catalog_id = rf.catalog_id
              )
          );

        SET @Rows = @@ROWCOUNT;

        SET @Finished = SYSUTCDATETIME();
        SELECT @ReadsAfter = logical_reads, @CpuAfter = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;

        IF @Run > 0
            INSERT INTO dbo.index_benchmark_results_G11
                (benchmark_phase, query_id, query_name, run_number,
                 result_count, logical_reads, cpu_ms, elapsed_us)
            VALUES
                (@Phase, 2, N'Room finder', @Run, @Rows,
                 @ReadsAfter - @ReadsBefore, @CpuAfter - @CpuBefore,
                 DATEDIFF_BIG(MICROSECOND, @Started, @Finished));

        /* Q3 - approved hours per space for the three-year window. */
        SELECT @ReadsBefore = logical_reads, @CpuBefore = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;
        SET @Started = SYSUTCDATETIME();

        SELECT @Rows = COUNT_BIG(*),
               @Digest = CHECKSUM_AGG(BINARY_CHECKSUM(
                   q.space_id, q.approved_booking_count, q.total_approved_hours))
        FROM (
            SELECT s.space_id,
                   COUNT(b.booking_id) AS approved_booking_count,
                   ISNULL(SUM(DATEDIFF(MINUTE, b.start_time, b.end_time)) / 60.0, 0)
                       AS total_approved_hours
            FROM dbo.spaces AS s
            LEFT JOIN dbo.bookings AS b
                   ON b.space_id = s.space_id
                  AND b.status IN (N'Approved', N'Checked In', N'Completed')
                  AND b.start_time >= @SemStart
                  AND b.start_time < @SemEnd
            GROUP BY s.space_id
        ) AS q;

        SET @Finished = SYSUTCDATETIME();
        SELECT @ReadsAfter = logical_reads, @CpuAfter = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;

        IF @Run > 0
            INSERT INTO dbo.index_benchmark_results_G11
                (benchmark_phase, query_id, query_name, run_number,
                 result_count, logical_reads, cpu_ms, elapsed_us)
            VALUES
                (@Phase, 3, N'Approved booking hours per space', @Run, @Rows,
                 @ReadsAfter - @ReadsBefore, @CpuAfter - @CpuBefore,
                 DATEDIFF_BIG(MICROSECOND, @Started, @Finished));

        /* Q4 - approved bookings by weekday and hour. */
        SELECT @ReadsBefore = logical_reads, @CpuBefore = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;
        SET @Started = SYSUTCDATETIME();

        SELECT @Rows = COUNT_BIG(*),
               @Digest = CHECKSUM_AGG(BINARY_CHECKSUM(
                   q.weekday_number, q.hour_of_day, q.approved_booking_count))
        FROM (
            SELECT ((@@DATEFIRST + DATEPART(WEEKDAY, b.start_time) - 2) % 7) + 1
                       AS weekday_number,
                   DATEPART(HOUR, b.start_time) AS hour_of_day,
                   COUNT_BIG(*) AS approved_booking_count
            FROM dbo.bookings AS b
            WHERE b.status IN (N'Approved', N'Checked In', N'Completed')
              AND b.start_time >= @SemStart
              AND b.start_time < @SemEnd
            GROUP BY ((@@DATEFIRST + DATEPART(WEEKDAY, b.start_time) - 2) % 7) + 1,
                     DATEPART(HOUR, b.start_time)
        ) AS q;

        SET @Finished = SYSUTCDATETIME();
        SELECT @ReadsAfter = logical_reads, @CpuAfter = cpu_time
        FROM sys.dm_exec_requests WHERE session_id = @@SPID;

        IF @Run > 0
            INSERT INTO dbo.index_benchmark_results_G11
                (benchmark_phase, query_id, query_name, run_number,
                 result_count, logical_reads, cpu_ms, elapsed_us)
            VALUES
                (@Phase, 4, N'Approved bookings by weekday/hour', @Run, @Rows,
                 @ReadsAfter - @ReadsBefore, @CpuAfter - @CpuBefore,
                 DATEDIFF_BIG(MICROSECOND, @Started, @Finished));

        SET @Run += 1;
    END;
END;
GO

EXEC dbo.usp_RunIndexBenchmarkG11 @Phase = 'BEFORE';
GO

PRINT N'============================================================';
PRINT N'BEFORE INDEXING - THREE MEASURED WARM-CACHE RUNS';
PRINT N'============================================================';

SELECT query_id, query_name,
       CAST(AVG(CAST(logical_reads AS DECIMAL(18,2))) AS DECIMAL(18,2))
           AS avg_logical_reads,
       CAST(AVG(CAST(cpu_ms AS DECIMAL(18,2))) AS DECIMAL(18,2)) AS avg_cpu_ms,
       CAST(AVG(CAST(elapsed_us AS DECIMAL(18,2))) / 1000.0 AS DECIMAL(18,3))
           AS avg_elapsed_ms,
       MIN(result_count) AS result_count
FROM dbo.index_benchmark_results_G11
WHERE benchmark_phase = 'BEFORE'
GROUP BY query_id, query_name
ORDER BY query_id;
GO

/* One visible execution with authoritative SQL Server Messages. When Actual
   Execution Plan is enabled, inspect the bookings and maintenance operators. */
PRINT N'ROOM FINDER SHOWCASE BEFORE INDEXING (expect scans and high reads)';
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

PRINT N'Next: execute 02-create-indexes-and-benchmark-after-G11.sql.';
GO
