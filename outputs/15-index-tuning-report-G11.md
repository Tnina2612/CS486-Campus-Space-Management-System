# Index Tuning Report — G11 (Phase 2)

**DBMS:** Microsoft SQL Server 2025, Developer Edition

**Benchmark dataset:** the clean, SQL-only fixture created by
`outputs/14-data-generator-G11/01-generate-data-G11.sql` and verified for the
benchmark by `outputs/15-index-demo-G11/00-prepare-index-demo-G11.sql`. It contains **150,000 deterministic benchmark
bookings** plus 24 Phase 1 sample bookings (**150,024 bookings total**), 408
spaces, 4,008 maintenance records, and 530 advisory acknowledgements. Booking
dates run from 2023-01-02 to 2026-01-16, spanning slightly more than three
calendar years. The fixture validates no booking overlaps, no approved-like booking
overlaps out-of-service maintenance, and every advisory overlap has an
acknowledgement and snapshot.

**Reproducibility:** execute the SQL files in
`outputs/15-index-demo-G11/README.md` in order. The final validation file must
print `G11 INDEX DEMO VALIDATION: PASS`.

## Benchmark method

1. `00-prepare-index-demo-G11.sql` checks prerequisites, validates the Phase 14 fixture, removes temporary test rows, then
   removes only the four indexes evaluated here and runs `UPDATE STATISTICS ...
   WITH FULLSCAN`. The baseline therefore retains only clustered PK and UNIQUE
   constraint indexes; SQL Server does **not** automatically create indexes for
   foreign keys.
2. `01-benchmark-before-indexing-G11.sql` runs one warm-up and three measured
   warm-cache iterations for each query. It persists result count, logical
   reads, CPU time, and elapsed time in `dbo.index_benchmark_results_G11`.
3. `02-create-indexes-and-benchmark-after-G11.sql` creates the four indexes,
   refreshes statistics, and reruns the identical workload.
4. `03-compare-and-validate-G11.sql` calculates the reported three-run averages,
   verifies that indexing did not change query results, and performs the final
   integrity checks. It also runs the exact Room Finder statement with
   `SET STATISTICS IO ON` and `SET STATISTICS TIME ON`; enable Actual Execution
   Plan in SSMS with `Ctrl+M`.
5. Estimated subtree costs below were captured separately with `SET SHOWPLAN_XML
   ON` after `UPDATE STATISTICS ... WITH FULLSCAN`, using the same predicates.

All timed iterations are warm-cache, so physical reads were 0 in the displayed
`STATISTICS IO` output. Logical reads are the primary I/O comparison; elapsed
and CPU time vary with hardware and current load.

## SARGability findings

- The two overlap probes use the SARGable half-open form
  `start_time < @end_time AND end_time > @start_time`.
- The two analytical queries filter the semester with the SARGable range
  `start_time >= @SemStart AND start_time < @SemEnd`.
- `DATEPART` in Query 4 is used only after filtering, for grouping; it is not
  applied to an indexed column in a `WHERE` predicate.
- Room Finder resolves Projector and Air Conditioner catalog IDs by
  `facility_name`, rather than incorrectly assuming a fixed catalog ID.

---

## Query 1 — Booking conflict check

### 1. Business context

This is the overlap probe used during automatic booking and staff approval. It
must quickly detect an approved-like booking that occupies the same space.

### 2. Target SQL

```sql
IF EXISTS (
    SELECT 1
    FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
    WHERE space_id = @space_id
      AND status IN ('Approved', 'Checked In', 'Completed')
      AND start_time < @end_time
      AND end_time   > @start_time
)
```

The benchmark selects the latest approved-like booking in `GEN-0400` and tests
the overlapping interval 2026-01-16 17:15..17:45. Both phases return `1`
(conflict exists).

### 3. Before/after results

| Metric | Before indexing | After indexing | Improvement |
| :--- | ---: | ---: | ---: |
| Logical reads | 1,994.00 | 6.00 | 99.70% |
| Physical reads | 0 | 0 | — |
| CPU time | 54.33 ms | 1.00 ms | 98.16% |
| Elapsed time | 46.332 ms | below timer resolution | N/A |
| Estimated subtree cost | 0.0172718 | 0.00329291 | 80.93% |
| Main operator | Clustered Index Scan | Index Seek | — |

### 4. Index and rationale

```sql
CREATE INDEX IX_bookings_space_time
    ON dbo.bookings (space_id, start_time, end_time)
    INCLUDE (status);
```

`space_id` is the equality predicate and `start_time` is the range predicate.
`end_time` and `status` complete the overlap/status test without a key lookup;
`end_time` remains a residual predicate after the start-time range.

### 5. Locking and DML trade-off

The auto-approval procedure first obtains an `UPDLOCK` on the target `spaces`
row. The staff-approval procedure first locks its pending booking, then obtains
that same per-space lock. This index does not create correctness by itself; it
makes the subsequent booking probe and its key-range locks much narrower and
faster. On the tested dataset it occupies about 7.56 MB and adds one
nonclustered-index maintenance operation to booking writes.

---

## Query 2 — Room Finder

### 1. Business context

Room Finder returns spaces satisfying capacity, required facilities, no
approved-like booking overlap, and no out-of-service maintenance overlap.

### 2. Target SQL

```sql
SELECT s.space_id, s.space_code, s.space_name, s.space_type,
       s.building, s.floor, s.room_number, s.capacity, s.current_status
FROM dbo.spaces AS s
WHERE s.capacity >= @MinCapacity
  AND s.current_status NOT IN ('Temporarily Closed', 'Retired')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.bookings AS b
      WHERE b.space_id = s.space_id
        AND b.status IN ('Approved', 'Checked In', 'Completed')
        AND b.start_time < @ReqEnd AND b.end_time > @ReqStart
  )
  AND NOT EXISTS (
      SELECT 1 FROM dbo.maintenance_records AS m
      WHERE m.space_id = s.space_id
        AND m.impact_level = 'out-of-service'
        AND (m.completion_time IS NULL OR m.completion_time > @ReqStart)
        AND m.start_time < @ReqEnd
  )
  AND NOT EXISTS (
      SELECT 1 FROM @RequiredFacilities AS rf
      WHERE NOT EXISTS (
          SELECT 1 FROM dbo.space_facility AS sf
          WHERE sf.space_id = s.space_id AND sf.catalog_id = rf.catalog_id
      )
  );
```

Parameters are capacity `170`, Projector plus Air Conditioner Unit, and window
2024-06-04 11:00..12:00. Both phases return 44 spaces.

### 3. Before/after results

| Metric | Before indexing | After indexing | Improvement |
| :--- | ---: | ---: | ---: |
| Logical reads | 106,861.00 | 690.33 | 99.35% |
| Physical reads | 0 | 0 | — |
| CPU time | 3,194.33 ms | 13.33 ms | 99.58% |
| Elapsed time | 3,197.582 ms | 13.333 ms | 99.58% |
| Estimated subtree cost | 0.569239 | 0.0626523 | 88.99% |
| Main access change | Booking/maintenance scans | Booking/maintenance seeks | — |

The visible `STATISTICS IO` Room Finder run read 102,306 pages from `bookings`
and 4,206 from `maintenance_records` before tuning; after tuning it read 255 and
104 respectively. The persisted average also includes small worktable/output
materialization costs, hence it is the value used in the comparison table.

### 4. Indexes and rationale

```sql
CREATE INDEX IX_bookings_space_time
    ON dbo.bookings (space_id, start_time, end_time)
    INCLUDE (status);

CREATE INDEX IX_maintenance_records_space_time
    ON dbo.maintenance_records (space_id, start_time, completion_time)
    INCLUDE (impact_level, status);

CREATE INDEX IX_spaces_capacity_status
    ON dbo.spaces (capacity, current_status)
    INCLUDE (space_type, space_name);
```

The first index supports a per-space booking overlap seek. The maintenance
index similarly narrows by `space_id` and `start_time`; `impact_level` and the
completion test are residual predicates. The spaces index is a small candidate
filter index for larger `spaces` tables.

### 5. Important plan observation and DML trade-off

The current fixture has only 408 spaces. SQL Server therefore still chooses a
clustered scan of `spaces` (17 logical reads); the spaces index is **not**
credited with eliminating lookups, because it does not cover `space_code`,
`building`, `floor`, or `room_number`. The measured gain comes from the booking
and maintenance probes. The index sizes are approximately 7.56 MB for the
booking index, 0.29 MB for maintenance, and 0.06 MB for spaces.

---

## Query 3 — Approved booking hours per space

### 1. Business context and target SQL

This semester/period report totals approved-like booking hours per space.

```sql
SELECT s.space_id, s.space_code, s.space_name,
       COUNT(b.booking_id) AS approved_booking_count,
       ISNULL(SUM(DATEDIFF(MINUTE, b.start_time, b.end_time)) / 60.0, 0)
           AS total_approved_hours
FROM dbo.spaces AS s
LEFT JOIN dbo.bookings AS b
       ON b.space_id = s.space_id
      AND b.status IN ('Approved', 'Checked In', 'Completed')
      AND b.start_time >= @SemStart
      AND b.start_time < @SemEnd
GROUP BY s.space_id, s.space_code, s.space_name;
```

The test window is 2023-01-01..2026-02-01. Both phases return 408 spaces.

### 2. Before/after results

| Metric | Before indexing | After indexing | Improvement |
| :--- | ---: | ---: | ---: |
| Logical reads | 2,011.00 | 594.00 | 70.46% |
| Physical reads | 0 | 0 | — |
| CPU time | 356.67 ms | 163.33 ms | 54.21% |
| Elapsed time | 352.755 ms | 161.884 ms | 54.11% |
| Estimated subtree cost | 2.4357 | 0.767761 | 68.48% |
| Main operator | Clustered Index Scan + Hash Aggregate | Index Scan + Stream Aggregate | — |

### 3. Index and trade-off

```sql
CREATE INDEX IX_bookings_status_time
    ON dbo.bookings (status, start_time, end_time)
    INCLUDE (space_id);
```

The three status values and the period predicate restrict the report to
approved-like rows. Because the benchmark window covers the whole fixture,
SQL Server correctly chooses an **Index Scan**, not a misleadingly labelled
seek; it still reads far fewer pages than the clustered booking rows. This
index has three key columns and one included column, uses about 7.50 MB, and
adds maintenance cost to booking writes.

---

## Query 4 — Approved bookings by weekday and hour

### 1. Business context and target SQL

This report supports demand planning by grouping approved-like booking starts
by weekday and hour.

```sql
WITH approved AS (
    SELECT b.start_time,
           ((@@DATEFIRST + DATEPART(WEEKDAY, b.start_time) - 2) % 7) + 1
               AS weekday_number,
           DATEPART(HOUR, b.start_time) AS hour_of_day
    FROM dbo.bookings AS b
    WHERE b.status IN ('Approved', 'Checked In', 'Completed')
      AND b.start_time >= @SemStart
      AND b.start_time < @SemEnd
)
SELECT weekday_number, hour_of_day, COUNT(*) AS approved_booking_count
FROM approved
GROUP BY weekday_number, hour_of_day;
```

The same 2023-01-01..2026-02-01 window is used. Both phases return 35
weekday/hour groups in this deterministic fixture.

### 2. Before/after results

| Metric | Before indexing | After indexing | Improvement |
| :--- | ---: | ---: | ---: |
| Logical reads | 2,006.00 | 589.00 | 70.64% |
| Physical reads | 0 | 0 | — |
| CPU time | 293.67 ms | 99.00 ms | 66.29% |
| Elapsed time | 289.452 ms | 97.943 ms | 66.16% |
| Estimated subtree cost | 2.27083 | 0.59239 | 73.91% |
| Main operator | Clustered Index Scan + Hash Aggregate | Index Seek + Hash Aggregate | — |

### 3. Reused index and trade-off

Query 4 reuses `IX_bookings_status_time`; it creates no additional index. The
included `space_id` is not required by this query, but its storage/write cost
is already paid because Query 3 needs it for the join. Reuse avoids a fourth
booking index.

---

## Index summary

| Index | Keys | INCLUDE | Primary measured use |
| :--- | :--- | :--- | :--- |
| `IX_bookings_space_time` | `(space_id, start_time, end_time)` | `status` | Q1 conflict probe; Q2 booking availability |
| `IX_bookings_status_time` | `(status, start_time, end_time)` | `space_id` | Q3 and Q4 analytical reports |
| `IX_maintenance_records_space_time` | `(space_id, start_time, completion_time)` | `impact_level, status` | Q2 maintenance availability |
| `IX_spaces_capacity_status` | `(capacity, current_status)` | `space_type, space_name` | Candidate filtering as `spaces` grows; not selected in the 408-space fixture |

## Verification checklist

- [x] Conflict check, Room Finder, and two analytical reports benchmarked.
- [x] Before/After result counts are equal for all four queries.
- [x] Logical reads, CPU, elapsed time, physical reads, plan operators, and
  estimated subtree costs are reported.
- [x] All percentage calculations use the persisted three-run averages.
- [x] Index DDL is valid SQL Server syntax and matches
  `outputs/10-schema-migration-G11.sql`.
- [x] The final SQL-only fixture validates BR-01, BR-02, and BR-11.
