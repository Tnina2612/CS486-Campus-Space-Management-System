# Concurrency Control Design - G11 (Phase 2)

## 1. Core Conflicts

### 1a. Race: Two concurrent instant-booking transactions on the same space

Two users request the same space `S` for overlapping windows `[t1,t2)` and `[t3,t4)` at nearly the same moment:

| Step | T1 (instant booking) | T2 (instant booking) |
| :--- | :--- | :--- |
| 1 | `SELECT` bookings for S, no overlap found | `SELECT` bookings for S, no overlap found |
| 2 | INSERT booking B1 → Approved | INSERT booking B2 → Approved |
| 3 | COMMIT | COMMIT |

Both transactions read availability *before* either writes, so both pass the check and both commit. Result: two approved overlapping bookings — a direct violation of BR-01.

### 1b. Race: Instant booking vs. staff approval

| Step | T1 (staff approval of pending B1) | T2 (instant booking of B2) |
| :--- | :--- | :--- |
| 1 | `SELECT` availability for B1's window → free | — |
| 2 | — | INSERT B2 (overlaps B1) → Approved, COMMIT |
| 3 | UPDATE B1 status → Approved, COMMIT | — |

The staff transaction approves B1 based on a stale availability read; B2 committed in the middle. Result: B1 and B2 overlap — BR-01 violation.

### 1c. Maintenance-gating rule incorporated

Blocking is **not** based on `SPACE.current_status` (which no longer contains `Under Maintenance`). A booking window is blocked only when there exists a `MAINTENANCE_RECORD` for the space whose time window overlaps `[requested_start, requested_end)` **and** `impact_level = 'out-of-service'`. `impact_level = 'advisory'` must never block; it only requires notification + acknowledgement.

The concurrency design must therefore protect **two invariants atomically**:
- **INV-1:** no two approved bookings overlap on the same space;
- **INV-2:** no approved booking overlaps an out-of-service maintenance window.

## 2. Evaluated Strategies

### Strategy A — Pessimistic locking with range-lock table hints
The booking procedure runs inside an explicit transaction and takes range locks on the serialization points:

```sql
BEGIN TRAN
SELECT ...
  FROM dbo.bookings
 WHERE space_id = @space_id
   AND status IN (...)
   AND start_time < @end_time
   AND end_time   > @start_time
  WITH (UPDLOCK, HOLDLOCK);   -- serializes concurrent overlapping probes
...
COMMIT
```

- **Integrity:** strong — the `UPDLOCK, HOLDLOCK` range lock blocks a concurrent overlapping probe until the first transaction commits, so the second probe sees the committed row.
- **Performance:** locks are held to the end of the transaction; contention on a hot space is possible but booking windows are short and each transaction is small.
- **Complexity:** low — no database-wide setting required; hints are local to the procedure.

### Strategy B — Optimistic concurrency (SNAPSHOT ISOLATION)
Reads use snapshot versions; conflicts are detected at write time via update conflicts.

- **Integrity:** snapshot isolation alone does **not** prevent the phantom-row anomaly that produces two overlapping bookings, because both transactions read an empty snapshot and then insert new rows (no update conflict is detected on inserted data).
- **Performance:** excellent read concurrency.
- **Complexity:** moderate (needs `READ_COMMITTED_SNAPSHOT`/`ALLOW_SNAPSHOT_ISOLATION`, retry logic in the application).
- **Limitation:** requires application-level retry loops and cannot guarantee INV-1 by itself — a phantom insert can still slip through unless serializable range locks are used.

### Strategy C — SERIALIZABLE isolation level
Elevates the whole transaction to serializable.

- **Integrity:** the overlap `SELECT` acquires range locks (key-range + next-key locks) that suppress phantoms — equivalent in effect to Strategy A's hints but applied to every statement.
- **Performance:** more locking overhead than targeted hints.
- **Complexity:** low, but locks more than necessary (e.g., the user lookup, space lookup) and raises deadlock risk on unrelated hot keys.

## 3. Selected Strategy & Justification

**Selected: Strategy A — pessimistic locking with `UPDLOCK, HOLDLOCK` range locks** inside dedicated stored procedures, wrapped in explicit transactions.

Justification:
1. **Integrity guarantee:** `UPDLOCK, HOLDLOCK` acquires update + range-stable locks on the probe scan. Two concurrent overlapping probes for the same space serialize on the same range key, so the second probe blocks until the first commits; the second then sees the committed booking and rejects. This directly prevents both Conflict 1a and 1b (INV-1), and the same mechanism protects the maintenance probe (INV-2).
2. **Deterministic:** no retry logic, no application round-trips. SQL Server guarantees the result — important for a teaching/semester spike with many concurrent submitters.
3. **Performance fit:** booking/approval transactions are tiny (a few rows), and contention is per-space-range; locks are released at commit. This matches the semester-start burst pattern well.
4. **Simplicity:** local to procedures; no `ALTER DATABASE` isolation settings, no app-side retry.

SERIALIZABLE (Strategy C) was rejected because it over-locks (space/user lookups) and increases deadlock risk without adding integrity beyond the targeted hints. SNAPSHOT (Strategy B) was rejected because it cannot, by itself, prevent phantom inserts → double-booking.

## 4. Transaction Flow Design

### 4a. Instant-booking (auto-approval path) — `sp_book_space_instant` / `sp_AutoApproveBookingRequest`

```
BEGIN TRAN
  1. Take range lock on the space row (serialize per-space triage):
       SELECT ... FROM dbo.spaces WITH (UPDLOCK, ROWLOCK)
        WHERE space_id = @space_id;
  2. Probe maintenance (INV-2) with range lock:
       SELECT ... FROM dbo.maintenance_records WITH (UPDLOCK, HOLDLOCK)
        WHERE space_id = @space_id
          AND impact_level = 'out-of-service'
          AND start_time   < @end_time
          AND completion_time IS NULL OR completion_time > @start_time;
       -> if any row: ROLLBACK, return 'blocked by out-of-service maintenance'.
  3. Probe bookings (INV-1) with range lock:
       SELECT ... FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
        WHERE space_id = @space_id
          AND status IN ('Approved','Checked In','Completed')
          AND start_time < @end_time AND end_time > @start_time;
       -> if any row: ROLLBACK, return 'conflict'.
  4. Check policy + auto-booking flag:
       IF auto_booking_enabled = 0 OR usage policy fails -> ROLLBACK, return 'not auto-approvable'.
  5. INSERT bookings row (status = 'Approved').
  6. INSERT approvals row with staff_id = NULL, decision_time = now,
     decision_note = 'Auto-approved'.
COMMIT
```

Key point: steps 2 and 3 hold `UPDLOCK, HOLDLOCK` until commit, which is what makes two concurrent overlapping probes serialize.

### 4b. Staff-approval path — `sp_book_space_staff_approve`

```
BEGIN TRAN
  1. Take range lock on space row (UPDLOCK).
  2. Probe out-of-service maintenance overlap (UPDLOCK, HOLDLOCK) -> block if found.
  3. Probe approved-booking overlap (UPDLOCK, HOLDLOCK) -> block if found.
  4. UPDATE bookings SET status = 'Approved' WHERE booking_id = @booking_id
     (guarded by optimistic WHERE status = 'Pending').
  5. INSERT approvals row with staff_id = @staff_id (non-NULL).
COMMIT
```

Because step 3 uses the same range lock as the instant path, a concurrent instant booking of an overlapping window cannot commit between this transaction's check and its insert/update.

### 4c. Locking note on the probe query

The overlap predicate must be SARG-able and cover both directions:
```sql
start_time < @end_time AND end_time > @start_time
```
The `IX_bookings_space_time` index `(space_id, start_time, end_time)` (from migration Section 8) makes this a narrow range scan, so `UPDLOCK, HOLDLOCK` locks only the relevant key range rather than the whole table.

## 5. Incident-to-Maintenance Triage Concurrency

**Problem:** Two managers triage overlapping/duplicate `INCIDENT_REPORT` sets concurrently and each creates a `MAINTENANCE_RECORD`, producing duplicate maintenance work and double consolidation.

**Design:** a dedicated procedure `sp_consolidate_incident_reports`:

```
BEGIN TRAN
  1. Range-lock the candidate report rows:
       SELECT ... FROM dbo.incident_reports WITH (UPDLOCK, HOLDLOCK)
        WHERE report_id IN (SELECT ...) AND status = 'Open';
  2. Check whether ANY of the reports is already linked to a maintenance record:
       SELECT TOP 1 maintenance_id FROM dbo.report_consolidations WITH (UPDLOCK, HOLDLOCK)
        WHERE incident_report_id IN (...);
       -> if found, reuse that maintenance_id (dedupe) and do NOT create a new one.
  3. If none: INSERT maintenance_records (impact_level DEFAULT 'advisory';
     manager may escalate later via sp_set_maintenance_impact).
  4. INSERT report_consolidations rows mapping each report -> the single maintenance_id.
  5. UPDATE incident_reports SET status = 'Consolidated'.
COMMIT
```

The `UQ_consolidations_incident UNIQUE(incident_report_id)` constraint is a second line of defense: a duplicate consolidation INSERT for the same report is rejected even if the lock window is missed. `sp_set_maintenance_impact` is a separate short transaction so escalation decisions remain the exclusive authority of triage (BR-12) and do not race with booking probes (a booking probe that starts after the escalation commit will see the new `impact_level`).

## 6. Isolation Level Summary

| Aspect | Choice |
| :--- | :--- |
| Isolation level | READ COMMITTED (default), with targeted `UPDLOCK, HOLDLOCK` range locks in procedures |
| Lock granularity | Row / key-range, scoped to the probed space + time window |
| Blocking sources | `bookings` (INV-1), `maintenance_records` `out-of-service` (INV-2) |
| Advisory maintenance | Never blocks; only notifies + acknowledges |
| Deadlock posture | Short transactions, consistent lock order (space → maintenance → bookings), single-writer pattern |
| Triage dedup | Range lock on incident_reports + UNIQUE constraint + single maintenance per report set |

## 7. Mapping to Conflicts

| Conflict (from Step 8) | Protected by |
| :--- | :--- |
| A — instant vs. instant | 4a step 3 range lock |
| B — instant vs. staff approval | 4a/4b shared probe lock order |
| C — duplicate incident + consolidation | Section 5 dedup procedure |
| D — escalation vs. concurrent approval | 4a/4b step 2 + short escalation transaction |
| E — concurrent auto-approval same space | 4a step 1 space lock + step 3 range lock |
