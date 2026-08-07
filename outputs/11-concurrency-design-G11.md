# Concurrency Design - G11

## 1. Core Conflict

The race condition arises from a classic **check-then-act** interleaving on booking availability:

- Txn A checks availability of a space → sees no approved booking → proceeds.
- Txn B checks availability of the same space → still sees no approved booking → proceeds.
- Txn A inserts an approved booking.
- Txn B inserts an approved booking (overlapping).

If A and B interleave exactly like this under Read Committed, each `SELECT` sees only committed rows that existed at its snapshot point, so both pass the overlap check and both commit → **BR-01 violated** (two approved bookings overlap the same space).

The same race applies across the two creation paths (instant auto-approval and staff approval) because both write the same `bookings` table and both rely on the same overlap check.

## 2. Strategies Evaluated

### 2.1 Pessimistic locking — `WITH (UPDLOCK, SERIALIZABLE)` on the space row

Lock the space row for the duration of the transaction before checking availability, forcing any concurrent transaction booking the same space to block until the first commits.

**Pros:** Simple, deterministic, guarantees serial execution per space; works regardless of creation path since the space row is the common serialization point.
**Cons:** Reduced concurrency for the *same* space (acceptable — popular spaces are exactly where safety matters most); blocks readers of that space row until commit.

### 2.2 Optimistic concurrency — `SNAPSHOT ISOLATION`

Readers get a snapshot; writers detect conflicts via row versioning on update. For *updates to existing rows* this prevents lost updates, **but** it does **not** prevent the phantom insert problem: two snapshot transactions can both insert overlapping bookings because neither sees the other's uncommitted insert. SNAPSHOT isolation alone cannot enforce "no overlapping inserts on the same space."

**Pros:** No blocking; good read concurrency.
**Cons:** Does not solve the specific insert-race we must prevent; requires the application to handle 3960 conflicts on a mechanism that does not even apply to pure inserts here.

### 2.3 Serializable isolation level on the overlap scan

`SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` places **range locks** on the index rows scanned during the availability check, preventing phantom inserts in that range.

**Pros:** Directly prevents the phantom.
**Cons:** Range-lock behavior depends on which indexes exist; without a suitable index it can degrade into table locks; error-prone to reason about per-query. Equivalent safety can be obtained more explicitly with row-level hints (see 2.1).

## 3. Selected Strategy: Pessimistic Locking (Row-Level `UPDLOCK, SERIALIZABLE` on SPACE)

**Chosen approach:** A single stored procedure performs, in one transaction:

1. Acquire an update lock with serializable range semantics on the **space row** (`SELECT ... FROM spaces WITH (UPDLOCK, HOLDLOCK) WHERE space_id = @space_id`). `HOLDLOCK` = `SERIALIZABLE` — it keeps the lock until commit and takes a range lock that prevents phantoms in the overlap scan that follows.
2. Re-check the overlap against approved bookings *inside* the same transaction (so the second transaction is blocked by the lock from step 1 before it can run its own check).
3. Insert the booking (with status `Approved` for instant bookings) and required advisory acknowledgements, then commit.

Because every booking path first locks the space row, all concurrent operations on the same space become serialized at the space level. The second transaction blocks on step 1 until the first commits; it then sees the newly committed approved booking and its overlap check correctly rejects the request.

**Justification:**
- **Data integrity:** strictly serializes conflicting operations per space → BR-01 guaranteed.
- **Performance:** lock scope is a single row per transaction; different spaces never block each other. Compared to SNAPSHOT (which cannot even solve the insert race), this is the correct guarantee.
- **Complexity:** a single table hint in one procedure is minimal and easy to test (Step 13).

## 4. Transaction Flow

```text
BEGIN TRAN
1. SELECT space_id FROM spaces WITH (UPDLOCK, HOLDLOCK)
     WHERE space_id = @space_id
     -- serialize on this space; HOLDLOCK (SERIALIZABLE) keeps lock till commit
2. IF EXISTS (SELECT 1 FROM bookings
              WHERE space_id = @space_id AND status = 'Approved'
                AND @end > start_time AND @start < end_time)
   --> overlap => ROLLBACK / RAISERROR (reject)
3. IF EXISTS (out-of-service maintenance overlapping)
   --> ROLLBACK (reject, refined BR-02)
4. INSERT INTO bookings (... status = case when instant then 'Approved'
                                            else 'Pending' end)
5. IF instant AND there are active advisory maintenance records:
   INSERT advisory_acknowledgements (booking, maintenance, now)
6. COMMIT
```

Error path: any check fails → `THROW` inside `TRY...CATCH` → `ROLLBACK`, no partial rows.

## 5. Concurrency Conflicts Solved

| Conflict (from Step 8) | How the design prevents it |
| :--- | :--- |
| Double-booking race (5.1) | Space-row lock serializes both transactions; second sees first's committed booking and is rejected. |
| Instant vs staff approval race (5.2) | Both paths run the same procedure → same space-row lock. |
| Maintenance escalation race (5.3) | Escalation writes via the same locking discipline; a booking procedure re-checks impact level under lock, and escalation procedure identifies affected approved bookings (Step 16 query). |
