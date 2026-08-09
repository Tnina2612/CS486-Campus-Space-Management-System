# Concurrency Control Design - G11 (Phase 2)

## 1. Core Conflict

At the start of each semester, multiple users and staff may simultaneously attempt to book the same popular space for overlapping time periods, either through **automatic (instant) booking** or **staff approval**.

The invariant that must never break (BR-01): *the same space cannot have two approved bookings with overlapping time periods.*

### The race condition (check-then-act)

```
T1: SELECT conflicting bookings for space S, interval I  --> returns 0 rows
T2: SELECT conflicting bookings for space S, interval I  --> returns 0 rows   (no lock held yet)
T1: INSERT booking (S, I) status='Approved'
T2: INSERT booking (S, I) status='Approved'              --> BOTH COMMIT
```

Both transactions read "no conflict" under default isolation (READ COMMITTED), neither blocks the other because each only *reads* the same data, and both then insert and commit. Result: two overlapping approved bookings — **BR-01 violated**.

Secondary races (from Step 8):
- **C2** escalation to `out-of-service` vs. concurrent booking using a stale `advisory` read → booked slot overlaps out-of-service maintenance (BR-02 / RC-04).
- **C3** two staff approving the same pending booking → `approvals.booking_id` UNIQUE conflict + possible double-approval.
- **C4** lost update on `maintenance_records.impact_level` during concurrent escalation/downgrade (RC-04).

## 2. Strategy Evaluation

### Strategy A — Optimistic concurrency (SNAPSHOT ISOLATION)

- Each transaction reads a snapshot; conflicts are detected at COMMIT via update conflicts.
- **Pros:** no blocking; high concurrency for read-heavy workloads.
- **Cons:** conflicts surface only at commit time (retry logic required in the application); SQL Server snapshot still allows a phantom to be inserted by a concurrent writer between a reader's snapshot check and its own insert, so the no-overlap invariant is **not** guaranteed by the DB alone. Overlap checking with snapshot reads cannot hold a range lock.
- **Verdict:** unsuitable as the *only* mechanism for a hard invariant like BR-01.

### Strategy B — Pessimistic locking with table hints (`WITH (UPDLOCK, HOLDLOCK)`)

- The availability scan takes an **update** lock (UPDLOCK) and holds it until end of transaction (HOLDLOCK), i.e., an S/U range lock on the candidate interval keys in `bookings` (space_id, start_time, end_time).
- A concurrent booking attempt for the same space/interval blocks at the scan, then re-evaluates after the first transaction commits/rolls back. Because the first transaction has already inserted its row before releasing the lock, the second transaction's re-scan sees the conflict and aborts.
- **Pros:** strong guarantee, no application retry logic needed, linearizable; simple and idiomatic T-SQL; works for both automatic and staff-approval booking paths.
- **Cons:** reduces concurrency on the *same space+interval* (contention is exactly what we want to serialize); requires care with index support so the range lock is taken on an index key range.

### Strategy C — SERIALIZABLE isolation level

- Automatically takes range locks on every predicate scan; identical serialization effect to B without explicit hints.
- **Pros:** declarative.
- **Cons:** also serializes *read-only* queries and unrelated predicate scans (key-range locks on all qualifying reads), increasing blocking and deadlock surface across the whole transaction; harder to reason about per-statement scope.

### Recommendation

**Adopt Strategy B (pessimistic locking with `UPDLOCK, HOLDLOCK`) inside a dedicated stored procedure** — `sp_AutoApproveBookingRequest` for the automatic path and a staff-approval procedure for the manual path — wrapped in explicit transactions. The availability scan uses the range index `IX_bookings_space_time (space_id, start_time, end_time)` created in the migration, so SQL Server locks the specific space's time-range and blocks only genuinely competing bookings.

Additional safeguards layered on top:
- **Escalation path (C2 / C4):** the maintenance update transaction locks the `maintenance_records` row (`UPDLOCK`) and takes the same booking range lock before evaluating impact; the booking procedure in turn re-reads maintenance status *after* acquiring its own locks, so stale `advisory` reads are impossible.
- **C3 (double approval):** the `approvals.booking_id` UNIQUE constraint provides a last-line atomicity backstop; the procedure also updates `bookings.status` under the same transaction so status and approval row are consistent.

## 3. Locking / Isolation Design

### 3.1 Default isolation

Database keeps the default **READ COMMITTED** (no global behavior change — least invasive to existing Phase 1 queries). Serialization is achieved per-transaction via lock hints, not by changing the database isolation level.

### 3.2 Booking / Approval procedure contract (`sp_AutoApproveBookingRequest` + staff path)

Every booking creation or approval runs inside one stored procedure that:

1. **BEGIN TRANSACTION**
2. **Check space state** — verify `spaces.current_status` is not `Under Maintenance`/`Temporarily Closed`/`Retired` and capacity ≥ expected participants (read, consistent within transaction).
3. **Check auto-booking eligibility** — for the automatic path, verify `spaces.AutoBookingEnabled = 1`; if it is `0`, the request must NOT be auto-approved (falls back to staff workflow / explicit error) — **mandatory pipeline rule**.
4. **Serialization point** — issue the guarded overlap scan:
   ```sql
   SELECT COUNT(*)
   FROM dbo.bookings WITH (UPDLOCK, HOLDLOCK)
   WHERE space_id = @space_id
     AND status IN ('Approved', 'Checked In', 'Completed')
     AND start_time < @end_time
     AND end_time  > @start_time;
   ```
   - `UPDLOCK` → the row/range locks are update locks (not shared), compatible only with other update locks on disjoint rows.
   - `HOLDLOCK` → locks persist until `COMMIT`.
   - The index `IX_bookings_space_time` guarantees a **key-range lock** on the space's interval, so a concurrent identical request blocks instead of passing the check.
5. **Check maintenance** — for the same space, read active maintenance records with `impact_level = 'out-of-service'` overlapping `[@start_time, @end_time]`; if any → reject. Gather active `advisory` records for the acknowledgement step.
6. **Write booking** — `INSERT INTO bookings (...)`, setting `advisory_acknowledged` and `advisory_snapshot` (advisory records listed) as required by RC-03.
7. **Auto-approve (automatic path)** or record staff approval — insert `approvals` row and set `bookings.status = 'Approved'`. **For the automatic path `approvals.staff_id = NULL`** (no human actor performed the decision — RC-05a); for the manual path it stores the deciding staff member's `user_id`. This is done by `sp_AutoApproveBookingRequest`.
8. **COMMIT** (or `ROLLBACK` on any violation).

### 3.3 Escalation procedure contract

1. **BEGIN TRANSACTION**
2. **Lock the maintenance record** — `SELECT ... FROM maintenance_records WITH (UPDLOCK) WHERE maintenance_id = @id` (prevents C4 lost update).
3. **Take the booking range lock** for the maintenance space + `[start_time, COALESCE(completion_time, start_time)]`.
4. Update `impact_level` (escalate/downgrade).
5. If escalating to `out-of-service`, the reporting query (output 16) identifies affected approved bookings **within the same transaction view** so the flag list is consistent.
6. **COMMIT**.

## 4. Transaction Flow (Pseudo-T-SQL)

```
BEGIN TRAN
  -- 1. Validate space availability for booking
  SELECT TOP 1 * FROM spaces WHERE space_id=@sid AND current_status='Available'
     AND capacity >= @pax
  IF @@ROWCOUNT = 0 --> ROLLBACK (BR-02 / capacity)

  -- 1b. Auto-booking gate (automatic path only)
  IF NOT EXISTS (SELECT 1 FROM spaces WHERE space_id=@sid AND AutoBookingEnabled=1)
      --> ROLLBACK with 'auto-booking disabled' status (mandatory rule)

  -- 2. SERIALIZATION POINT (Strategy B)
  IF EXISTS (
      SELECT 1 FROM bookings WITH (UPDLOCK, HOLDLOCK)
      WHERE space_id=@sid
        AND status IN ('Approved','Checked In','Completed')
        AND start_time < @end AND end_time > @start
  ) --> ROLLBACK (BR-01)

  -- 3. Maintenance gate
  IF EXISTS (
      SELECT 1 FROM maintenance_records
      WHERE space_id=@sid
        AND status <> 'Completed'
        AND impact_level='out-of-service'
        AND start_time < @end AND COALESCE(completion_time, @end) > @start
  ) --> ROLLBACK (BR-02)

  -- 4. Collect advisory records for acknowledgement
  SELECT problem_description FROM maintenance_records
   WHERE space_id=@sid AND status <> 'Completed'
     AND impact_level='advisory' AND ... overlap ...

  -- 5. INSERT bookings (with acknowledgement columns)
  -- 6. INSERT approvals (staff_id = NULL for automatic path; decision_time, note);
  --    UPDATE bookings.status = 'Approved'
COMMIT
```

## 5. Conflict → Mechanism Map

| Conflict (Step 8) | Mechanism | Enforced Where |
| :--- | :--- | :--- |
| C1 double booking (BR-01) | `UPDLOCK, HOLDLOCK` range lock on `IX_bookings_space_time` + re-scan before insert | Booking & approval procedures |
| C2 escalation vs. new booking | Booking proc re-reads maintenance under its own locks; escalation proc takes same range lock | Both procedures |
| C3 double approval of same booking | `UPDLOCK` on `bookings` row + UNIQUE `approvals.booking_id` backstop | Approval procedure + constraint |
| C4 lost escalation update | `UPDLOCK` on `maintenance_records` row | Escalation procedure |
| Auto-booking disabled space | `AutoBookingEnabled = 1` gate check inside `sp_AutoApproveBookingRequest` | Automatic-approval procedure |
| Auto-approval without actor (RC-05a) | `approvals.staff_id = NULL` written by `sp_AutoApproveBookingRequest` (column relaxed in migration 10) | Automatic-approval procedure + schema |

## 6. Performance & Complexity Notes

- **Performance:** The guard only blocks transactions contending for the *same space + overlapping interval*. Non-competing bookings (different space or disjoint time) proceed in parallel because their key ranges do not collide.
- **Complexity:** One stored procedure per booking path keeps the logic in one place; no application-side retry loop or connection-level isolation changes required.
- **Fallback for C2 edge cases:** `ROLLBACK` with an explicit, catchable error code lets callers distinguish "conflict on this space" from "maintenance blocks booking" from "auto-booking disabled".

## 7. Open Question

- OQ-P2-02: On a contested automatic booking, the procedure rejects the second requester with a conflict error (fail-soft). A waiting-list alternative would need additional schema (not requested).
