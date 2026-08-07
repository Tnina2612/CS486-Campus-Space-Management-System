# Index Tuning Report - G11

**Scope:** Tunes four critical queries identified in the Phase 2 spec:
1. Booking conflict check (used in `usp_CreateBooking`)
2. Room finder (capacity + facility + availability)
3. Reporting Query 1 — approved booking hours per space
4. Reporting Query 2 — approved bookings by weekday/hour

**Dataset:** ≥100,000 bookings across 3 academic years
(`outputs/14-data-generator-G11/`).

> **Note on metrics:** The tables below use representative expected improvements
> from a standard execution on the 100k dataset. Because the authoring
> environment does not host a live SQL Server, the exact `STATISTICS` numbers
> must be captured by running the provided queries and scripts on your own
> instance (per the process in §1). Every figure is marked **to-measure** until
> that run.

---

## Methodology (how to collect the real numbers)

For each query:

```sql
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;  -- fresh reads
UPDATE STATISTICS dbo.bookings;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- run query
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

Capture `Logical reads`, `CPU time`, `elapsed time`, and the visible execution
plan operators (Table Scan / Clustered Index Scan / Index Seek / Key Lookup)
and the **Subtree cost** from `SET SHOWPLAN_ALL ON` or SSMS "Include Actual
Execution Plan". Record these **before** creating indexes, then create the
indexes from §3 and measure again **after**.

---

## Query 1 — Booking Conflict Check

**Business context:** Runs on every booking creation/approval; must be subsequen
and correct under concurrency. Extremely frequent — priority for SARGability +
seek.

**Target SQL (core overlap predicate):**
```sql
SELECT 1 FROM dbo.bookings
WHERE space_id = @space_id
  AND status = 'Approved'
  AND @start_time < end_time
  AND @end_time > start_time;
```

**Predicate analysis (SARGability):** all columns compared directly to
parameters — no function wrapping → already SARGable. Good.

**Index design:**
```sql
CREATE NONCLUSTERED INDEX IX_bookings_overlap
    ON dbo.bookings (space_id, status)
    INCLUDE (start_time, end_time);
```
Equality-first columns (`space_id`, `status`) then the range columns are pulled
from the `INCLUDE` as a covering index; avoids Key Lookup and lets the optimizer
scan only matching rows.

**Before/after comparison:**

| Metric | Before (expect) | After (expect) | Improvement |
| :--- | :--- | :--- | :--- |
| Operator | Clustered Index Scan over all bookings | Index Seek on (space_id,status) | Scan → seek |
| Logical Reads | ~ (to be measured) | ~ (to-be) | large reduction |
| CPU / Elapsed (ms) | ~ | ~ | large reduction |
| Subtree Cost | ~ | ~ | high |

**DML trade-off:** each INSERT must now maintain an extra index → minor write
overhead, outweigh by the hit-rate of this hot-path query.

---

## Query 2 — Room Finder

**Business context:** complex filter (capacity + facility list + availability);
lower frequency than conflict check.

### Indexes designed:

```sql
CREATE NONCLUSTERED INDEX IX_spaces_capacity ON dbo.spaces (capacity);
CREATE NONCLUSTERED INDEX IX_sf_catalog
    ON dbo.space_facility (catalog_id, space_id);
CREATE NONCLUSTERED INDEX IX_maint_space_impact
    ON dbo.maintenance_records (space_id, impact_level)
    INCLUDE (start_time, completion_time);
```

- `spaces(capacity)`: enables efficient capacity threshold filter (`>=`).
- `space_facility(catalog_id, space_id)`: covering join for the facility
  requirement test.
- `maintenance_records(space_id, impact_level)`: fast exclusion of
  out-of-service overlaps.

**Before/After:**

| Metric | Before | After | Improvement |
| :--- | :--- | :--- | :--- |
| Operator | table scans on spaces/space_facility | Index Seeks on capacity + catalog | scan → seek |
| Logical Reads | ~ (to-be) | ~ | major |
| CPU / Elapsed (ms) | ~ | ~ | major |

---

## Query 3 — Approved booking hours per space

**Business context:** semester-level analytics; medium frequency.

**Index design:**
```sql
CREATE NONCLUSTERED INDEX IX_bookings_status_start
    ON dbo.bookings (status, start_time)
    INCLUDE (space_id, end_time);
```
`status` equality (filter to approved-status set) → `start_time` range for the
semester window → `space_id,end_time` payload for the aggregation, effectively
covering query 3 and query 4.

**Before/After:**

| Metric | Before | After | Change |
| :--- | :--- | :--- | :--- |
| Operator | Clustered scan | Index Seek + covering aggregation | Scan → seek/covering |
| Logical Reads | (to-be-me) | ~ | ~ |

---

## Query 4 — Approved bookings by weekday & hour

**Business context:** same pattern, different grouping.

**Index design:** same `IX_bookings_status_start`; start_time range + grouped by
`DATEPART(WEEKDAY/hour)` reading the same covered index.

**Before/After:**

| Metric | Before | After | Change |
| :--- | :--- | :--- | :--- |
| Operator | Clustered scan w/ sort | Index Seek range + stream aggregate | scan → seek |

---

## 10. Consolidated index catalog

```sql
-- Tune Q1 (conflict check)
CREATE NONCLUSTERED INDEX IX_bookings_overlap ON dbo.bookings
    (space_id, status) INCLUDE (start_time, end_time);

-- Tune Q2 (room finder)
CREATE NONCLUSTERED INDEX IX_spaces_capacity ON dbo.spaces (capacity);
CREATE NONCLUSTERED INDEX IX_space_facility   ON dbo.space_facility (catalog_id, space_id);
CREATE NONCLUSTERED INDEX IX_maint_space_impact ON dbo.maintenance_records
    (space_id, impact_level) INCLUDE (start_time, completion_time);

-- Tune Q3 & Q4 (reporting)
CREATE NONCLUSTERED INDEX IX_bookings_status_start ON dbo.bookings
    (status, start_time) INCLUDE (space_id, end_time);
```

## Edge-case verification checklist

- [ ] All 4 queries analyzed (measure before/after).
- [ ] CREATE INDEX syntax valid for SQL Server (INCLUDE + optional WHERE).
- [ ] Logical Reads + CPU/Elapsed reported with values after real run.
- [ ] Execution plan Scan→Seek transitions documented after real run.
- [ ] Explanation of why each index improves performance (seek covering, avoiding Key Lookup) included above.