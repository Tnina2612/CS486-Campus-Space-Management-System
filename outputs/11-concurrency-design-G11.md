# Concurrency Control Design - G11 (Phase 2)

**Scope:** Prevent conflicting approved bookings and duplicate maintenance consolidation under the Phase 2 operating conditions (instant booking + staff approval executed concurrently).

**Inputs:**
- `req/business-requirement.md` — "Concurrent Booking and Approval"
- `outputs/08-requirement-change-analysis-G11.md` — Conflicts A–D
- `outputs/09-updated-erd-and-logical-design-G11.md` — table structures

---

## 1. Core Conflict

### 1.1 The race condition (lost serialization of the overlap check)

The invariant (BR-01 / BR-11) is: **two approved bookings on the same space must never overlap**, and **no approved booking may overlap an `out-of-service` maintenance window**.

The check-then-act pattern that breaks:

| Step | Tx1 (instant booking) | Tx2 (staff approval) |
| :-- | :--- | :--- |
| 1 | `SELECT` approved bookings for space S over [t1,t2] → none | `SELECT` approved bookings for space S over [t1,t2] → none |
| 2 | *(both see "free")* | *(both see "free")* |
| 3 | `INSERT` booking B1, `INSERT` approval A1, COMMIT | `INSERT` booking B2 (overlaps B1), `INSERT` approval A2, COMMIT |

At step 1–2 both transactions hold only shared `S` locks that are released at the end of each statement (READ COMMITTED). Nothing serialises the two reads, so both pass the availability check and both commit — **double-booking**.

### 1.2 Maintenance-gating refinement

The Phase 2 availability check must now consult **both** sources, under the same serialised read:

1. **Operational state:** `spaces.current_status` must not be `'Temporarily Closed'` or `'Retired'`.
2. **Maintenance blocking:** reject only when there is a `MAINTENANCE_RECORD` with `impact_level = 'out-of-service'` whose `[start_time, completion_time)` overlaps `[t1,t2]`.
   - `advisory` records never block (BR-12); they are surfaced as notifications.
3. **Overlap:** reject when an existing approved/checked-in booking on the same space overlaps `[t1,t2]`.

The concurrency danger is that two transactions both read "no out-of-service record / no overlapping booking" and then both commit. The lock design below serialises this read set.

---

## 2. Strategy Evaluation

| Criterion | Pessimistic lock: `SERIALIZABLE` + `WITH (UPDLOCK, HOLDLOCK)` | Optimistic: `SNAPSHOT ISOLATION` | Optimistic: manual version / timestamp |
| :--- | :--- | :--- | :--- |
| Overlap safety | Guaranteed: range lock on the key range prevents phantom inserts of conflicting bookings | Not by itself — writer-writer conflicts surface as update conflicts at commit; must add a conflict-detection retry loop | Must implement app-level version columns on every read-modify path; error-prone |
| Complexity in SQL Server | Low — pure T-SQL hints + isolation level inside the stored procedure | Medium — enable `ALLOW_SNAPSHOT_ISOLATION`, add retry/`UPDATE` conflict handling | High — extra columns, app logic, no DB guarantee |
| Throughput under high concurrency on the *same* hot space | Contended (one tx at a time per space) — acceptable because popular spaces are exactly where correctness matters most | High (writers don't block readers) but requires retries; can livelock under heavy contention | High but unsafe without careful coding |
| Impact on "beginning of semester" burst | Predictable serialisation; requests queue on the same space | Retry storms on the hot space; users may see repeated `UPDATE CONFLICT` failures | Unbounded risk |
| Fits existing schema (no version columns) | Yes — no schema change beyond indexes | Yes — but needs conflict-detection SQL in every proc | Requires new columns + refactor |
| **Verdict** | **Selected** | Rejected for the write path | Rejected |

### 2.1 Why pessimistic serialization is chosen

1. **Correctness is the hard requirement.** The semester-start burst makes optimistic retries unbounded and user-visible; pessimistic serialisation converts the race into a clean queue.
2. **Contention is naturally scoped.** The lock key is the **space** (with a bounded time range), not the whole table, so different spaces still book in parallel.
3. **No schema burden.** No version/timestamp columns are required; the existing `IX_bookings_space_time` index supports the range-lock.
4. **Single code path.** Both the instant-booking path and the staff-approval path call the same guarded procedure, so both inherit the same guarantee.

---

## 3. Selected Design

### 3.1 Isolation level and lock hints

- Procedure isolation: `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;`
- Availability read on `bookings`:
  ```sql
  SELECT ... FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
  WHERE space_id = @space_id AND status IN ('Approved','Checked In')
    AND start_time < @end_time AND end_time > @start_time;
  ```
  - `UPDLOCK` → takes update locks, not shared, so a concurrent transaction's matching read blocks instead of both passing.
  - `HOLDLOCK` → holds the range lock until commit, preventing phantom conflicting bookings from being inserted between read and insert (the classic double-booking window).
- The same pattern is applied on `maintenance_records` for the `out-of-service` overlap check (with `HOLDLOCK` so an escalation to `out-of-service` committed later cannot slip past a validation that already saw only advisory records).

> The `IX_bookings_space_time (space_id, start_time, end_time)` index from the migration makes the range lock an **index key-range lock** rather than a coarse table lock.

### 3.2 Locking key: space + time range

All concurrency-sensitive operations acquire locks on the **space's booking range** before writing. This serialises conflicting requests for the same space while allowing independent spaces to proceed concurrently.

### 3.3 Transaction flow (single guaranteed template)

```
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRAN;

-- 1. Serializable availability gate (locks the space-time range)
SELECT ... FROM bookings WITH (UPDLOCK, HOLDLOCK)   -- overlapping approved/checked-in
SELECT ... FROM maintenance_records WITH (UPDLOCK, HOLDLOCK)
          WHERE impact_level = 'out-of-service' AND overlaps;  -- blocking maintenance

IF conflict_found THEN ROLLBACK / return status 'conflict';

-- 2. Collect active advisories (impact_level = 'advisory', overlapping window)
--    for the notification + acknowledgement snapshot.

-- 3. Insert booking (status depends on path: Pending for staff, Approved for instant)
-- 4. Insert/update approval (staff_id = @staff_id or NULL for auto-approval)
-- 5. Insert advisory_acknowledgements rows if advisories were surfaced
COMMIT;
```

**Invariant enforced by construction:** because every approval path (instant and staff) enters through this template, at most one transaction can hold the range lock for a given space-time overlap at a time; the second sees the first's committed booking and is rejected.

---

## 4. Incident-to-Maintenance Triage Concurrency

### 4.1 The race

Two managers concurrently consolidate overlapping duplicate incident reports into maintenance records (Conflict C):

| Step | Manager A | Manager B |
| :-- | :--- | :--- |
| 1 | Reads incident reports R1, R2, R3 | Reads incident reports R2, R3 |
| 2 | Inserts `MAINTENANCE_RECORD` M1 | Inserts `MAINTENANCE_RECORD` M2 |
| 3 | Links R1, R2 → M1 | Links R2, R3 → M2 |

R2 ends up mapped to **two** maintenance records → duplicate repair work, ambiguous impact-level authority.

### 4.2 Guard

1. **Schema-level:** `report_consolidations.incident_report_id` is `UNIQUE` (from step 9) — an incident report can be consolidated into **at most one** maintenance record. This makes the second `INSERT` of a duplicate link a PK/UNIQUE violation instead of silent duplication.
2. **Transaction-level:** the triage procedure:
   - Reads the candidate incident reports with `WITH (UPDLOCK, HOLDLOCK)` (serialisable),
   - Re-checks whether any is already consolidated,
   - Inserts the `MAINTENANCE_RECORD` and the consolidation links in one transaction.
   - On a UNIQUE-violation (a lost race), the loser catches `2627` and rolls back, returning a "report already consolidated" status.
3. **Effect:** even if two managers run the same triage concurrently, at most one consolidation row per incident report is ever committed; the other aborts cleanly.

---

## 5. Summary of Guarantees

| Guarantee | Mechanism |
| :--- | :--- |
| No overlapping approved bookings under concurrency | `SERIALIZABLE` + `UPDLOCK, HOLDLOCK` range locks on `bookings` (space-time) inside the single booking template |
| Maintenance blocking only via `out-of-service` | Same guarded read on `maintenance_records` with `impact_level = 'out-of-service'`; `advisory` never blocks |
| Escalation race closed | `HOLDLOCK` on the maintenance read prevents an `out-of-service` escalation committed mid-transaction from being missed |
| No duplicate maintenance consolidation | `UNIQUE (incident_report_id)` in `report_consolidations` + serialisable triage transaction + 2627 handling |
| Auto vs. manual approval parity | Both paths share the same template → identical correctness |
| Throughput | Locks are scoped to a space's time range, not the whole table; distinct spaces run in parallel |

---

## 6. Implementation Reference

The exact T-SQL implementing this design is in `outputs/12-concurrency-implementation-G11.sql`:
- `sp_book_space_staff_approve` — staff-approval path with serialisable overlap gate.
- `sp_AutoApproveBookingRequest` — instant/auto-approval path with the same gate plus the `spaces.AutoBookingEnabled = 1` and usage-policy checks; records `approvals.staff_id = NULL`.
- `sp_set_maintenance_impact` — escalation/downgrade helper used by triage and escalation reporting.
