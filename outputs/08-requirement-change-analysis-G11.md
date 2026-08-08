# Requirement Change Analysis - G11 (Phase 2)

**Baseline:** Phase 1 outputs `01`–`04`. All Phase 2 changes are **additive** to the Phase 1 schema (see `10-schema-migration-G11.sql`).

---

## 1. Change Inventory

### 1.1 Maintenance Impact Levels (Refined maintenance rule)

| ID | New / Changed Statement | Affected Phase 1 Element | Nature of Effect | Knock-on Effect |
| :--- | :--- | :--- | :--- | :--- |
| RC-01 | Maintenance records now carry an **impact level**: `out-of-service` (space cannot be booked for any overlapping period, as in Phase 1) or `advisory` (space remains bookable, but requester must be notified and an acknowledgement stored with the booking). | `MAINTENANCE_RECORD` / `maintenance_records` | **Attribute added**: new column `impact_level` on `maintenance_records`. | Refines BR-02: the blanket "under maintenance → not bookable" rule now only applies to `out-of-service` records. |
| RC-02 | A space may have **several active maintenance records at the same time**, with different impact levels. | `MAINTENANCE_RECORD` (already 1:N from SPACE) | **Lifecycle extended**: multiple concurrent *open* records per space must be allowed. No cardinality change (already 1:N). | Availability checking must aggregate all active records per space instead of assuming one. |
| RC-03 | Advisory maintenance must be **communicated to the requester** at booking time; the **acknowledgement must be stored with the booking**. | `BOOKING` / `bookings` | **Attribute added**: acknowledgement flag plus a snapshot of the advisories shown. | New data capture at booking creation; new sub-rule under BR-02 (bookable-but-notified). |
| RC-04 | Impact level may be **escalated** (advisory → out-of-service) or **downgraded** while the maintenance is open. Escalation must **surface already-approved bookings that overlap** the maintenance period. | `MAINTENANCE_RECORD.impact_level`, `BOOKING` / `APPROVAL` | **Existing rule refined + new behavior**: `impact_level` becomes mutable; a reporting capability identifies affected approved bookings. | New analytical query (output `16`) + an `UPDATE` path for `impact_level`. |

### 1.2 Concurrent Booking and Approval (New operating condition)

| ID | New / Changed Statement | Affected Phase 1 Element | Nature of Effect | Knock-on Effect |
| :--- | :--- | :--- | :--- | :--- |
| RC-05 | **Instant booking**: for selected space types, requests satisfying the usage policy may be **approved automatically at submission**; other requests continue via staff approval. | `BOOKING` status flow, `APPROVAL` lifecycle | **Business rule extended**: a new origination path that bypasses the staff decision for qualifying requests. | Same no-overlap invariant applies to both paths; approval history stays uniform. |
| RC-06 | Multiple users/staff may perform booking and approval operations **concurrently** (semester start). | `BOOKING` creation, `APPROVAL` creation/update, BR-01 | **Existing rule BR-01 must be delegated to concurrency control**: the availability check is check-then-act and races without locking. | BR-01 can no longer be only an application-level scan; it needs transactional locking/serialization (outputs `11`–`13`). |

### 1.3 New Reporting Needs

| ID | New / Changed Statement | Affected Phase 1 Element | Nature of Effect | Knock-on Effect |
| :--- | :--- | :--- | :--- | :--- |
| RC-07 | Report: **total approved booking hours per space** for a given semester. | `BOOKING`, `APPROVAL` | **New positive behavior** (analytical query). | Query + supporting indexes. |
| RC-08 | Report: **approved bookings by weekday and hour** for a given semester. | `BOOKING`, `APPROVAL` | **New positive behavior** (analytical query). | None structural. |
| RC-09 | Report: **available spaces satisfying required capacity and required facility list** within a time period. | `SPACE`, `SPACE_FACILITY`, `FACILITY_CATALOG`, `MAINTENANCE_RECORD`, `BOOKING` | **New positive behavior** (analytical query). | Query must join out-of-service maintenance and approved-booking overlap checks. |
| RC-10 | Report: **approved bookings affected when a maintenance record is escalated** to out-of-service. | `BOOKING`, `APPROVAL`, `MAINTENANCE_RECORD` | **New positive behavior** (analytical query). | Directly supports RC-04. |

---

## 2. Affected Entities / Relationships / Attributes (Summary)

| Element | Change | Status |
| :--- | :--- | :--- |
| `maintenance_records` | ADD `impact_level` (NVARCHAR(20), CHECK IN ('out-of-service','advisory'), NOT NULL, DEFAULT 'out-of-service'). | ADDITIVE |
| `maintenance_records` | Lifecycle extended to allow several concurrent open records per space (no column change). | RULE-LEVEL |
| `bookings` | ADD `advisories_acknowledged` (BIT NOT NULL DEFAULT 0) and `advisories_snapshot` (NVARCHAR(MAX) NULL) storing the advisories shown at booking time. | ADDITIVE |
| `bookings` | Origination path extended with instant approval (no new status value; approval recorded in `approvals`). | RULE-LEVEL |
| `spaces` | ADD `instant_bookable` (BIT NOT NULL DEFAULT 0) — space-type driven flag used by the instant-booking path (RC-05). | ADDITIVE |
| BR-01 | No-overlap invariant: intent unchanged; enforcement moved to concurrency control (locking/isolation). | REFINED / DELEGATED |
| BR-02 | "Under maintenance → not bookable" now conditional on `impact_level = 'out-of-service'`; `advisory` → bookable-with-acknowledgement. | REFINED |
| `approvals` | No structural change; auto-approved bookings still insert an `approvals` row for uniform decision history. | UNCHANGED (usage refined) |

---

## 3. Business Rule Impact

| Rule ID (Phase 1) | Description | Phase 2 Status | New Condition / Note |
| :--- | :--- | :--- | :--- |
| BR-01 | Same space cannot have two approved bookings with overlapping time periods. | **Kept unchanged** (invariant) + **Delegated** to concurrency control | Still mandatory for instant-booked and staff-approved bookings alike (RC-06). |
| BR-02 | A space under maintenance, closed, or retired cannot be booked. | **Refined** | Only `out-of-service` maintenance blocks booking. `advisory` maintenance permits booking but requires acknowledgement (RC-01, RC-03). Temporarily Closed / Retired rules unchanged. |
| BR-03 | Approval records staff, time, note. | **Kept unchanged** | Instant booking records the acting/system staff actor in `approvals` (A-05). |
| BR-04 | Rejection reason required when rejected. | **Kept unchanged** | Unaffected by Phase 2. |
| BR-05 | Check-in records actual start, staff, initial condition. | **Kept unchanged** | Unaffected by Phase 2. |
| BR-06 | Check-out records actual end, final condition, notes. | **Kept unchanged** | Unaffected by Phase 2. |
| BR-07 | Historical records preserved. | **Kept unchanged** | All Phase 2 changes are additive; history untouched. |
| BR-08 | Staff view queries. | **Extended** | New reporting needs RC-07 … RC-10 (output `16`). |
| BR-09 | Strict 1:1 lifecycle. | **Kept unchanged** | Unaffected by Phase 2. |
| BR-10 | Hybrid facility pattern. | **Kept unchanged** | Facility lists reused by RC-09. |
| **BR-P2-01** *(new)* | Advisory maintenance must be shown to and acknowledged by the requester at booking time. | **Added** | Enforced at booking creation (flags in `bookings`). |
| **BR-P2-02** *(new)* | Impact-level escalation/downgrade supported; escalation must surface affected approved bookings. | **Added** | Supported via `impact_level` UPDATE + analytical query (RC-10). |
| **BR-P2-03** *(new)* | Instant approval for selected space types satisfying usage policy. | **Added** | Implemented in stored-procedure booking path (output `12`). |

---

## 4. Concurrency Conflict Analysis

### Conflict C1 — Double booking on a popular space (check-then-act race)

- **Operation sequence:**
  1. T1 (user A) and T2 (user B) both request space `CS-101` for 14:00–16:00 on the same day. Both pass the initial availability scan (no approved overlap yet).
  2. T1 inserts a booking row and marks it `Approved` (instant booking).
  3. T2 inserts a booking row and marks it `Approved`.
- **Interleaving break:** both transactions read "no conflict" before either commits its insert; both then commit → two overlapping approved bookings exist.
- **Undesirable outcome:** double booking for the same space/time; double-effort; fair-use breakdown.
- **Invariant threatened:** BR-01 (no overlapping approved bookings on the same space).

### Conflict C2 — Escalation vs. concurrent new booking (stale read race)

- **Operation sequence:**
  1. T1 escalates maintenance record M on `CS-101` to `out-of-service` (period P).
  2. T2 concurrently creates an instant-approved booking for `CS-101` overlapping P.
  3. T2's availability check reads M's `impact_level` as `advisory` (stale read) and permits the booking.
- **Undesirable outcome:** an approved booking overlaps an out-of-service maintenance period; space is not actually usable.
- **Invariant threatened:** BR-02 (out-of-service spaces cannot be booked) and RC-04 (escalation must capture affected bookings).

### Conflict C3 — Concurrent approval of the same pending booking

- **Operation sequence:**
  1. Two staff members open the same pending booking B for approval.
  2. Both update `bookings.status → 'Approved'` and insert `approvals` rows.
  3. The `UNIQUE` constraint on `approvals.booking_id` fails for the second insert → one transaction errors. Unless the status update + approval insert are atomic, a partial state (status Approved, no approval row) or, combined with C1, an overlapping approval results.
- **Undesirable outcome:** integrity error or inconsistent approval state.
- **Invariant threatened:** BR-01, BR-03 (single decision record).

### Conflict C4 — Lost update on maintenance `impact_level`

- **Operation sequence:**
  1. T1 escalates M to `out-of-service`.
  2. T2 downgrades M to `advisory` (reads old value, writes its own), overwriting T1's escalation without awareness.
- **Undesirable outcome:** lost escalation; staff believes the space is blocked when it is bookable.
- **Invariant threatened:** RC-04 (escalation decisions must persist).

---

## 5. Assumptions & Open Questions

### Assumptions (decisions required but not spelled out)

- **A-01 (Impact level default):** new maintenance records default to `out-of-service`, matching Phase 1 blocking behavior (safer default). Escalations/downgrades are explicit staff actions.
- **A-02 (Enum values):** exact wording `out-of-service` and `advisory` is used, stored in a CHECK-constrained column.
- **A-03 (Acknowledgement representation):** boolean `advisories_acknowledged` + `advisories_snapshot` (text of advisory descriptions and maintenance IDs shown at booking time) satisfies "record that the requester was informed".
- **A-04 (Instant booking eligibility):** the set of eligible space types is a configuration list (seeded with `Computer Laboratory` and `Meeting Room`); eligibility = space `instant_bookable` + usage policy satisfied + space available + capacity met + requester account active.
- **A-05 (Auto-approval audit):** an `approvals` row is always created — for staff decisions with `staff_id`, and for instant booking with the system/facility-manager actor — keeping reporting (BR-03) uniform.
- **A-06 (Concurrency mechanism):** SQL Server default READ COMMITTED is insufficient for the availability check; a guarded transactional insert with range locks / serializable hint or an explicit application lock is required (designed in outputs `11`–`12`, proven in `13`).
- **A-07 (Active maintenance):** a maintenance record is "active" while `status` indicates open (e.g., Reported / In Progress / Assigned) and `completion_time` is NULL.

### Open Questions

| ID | Question |
| :--- | :--- |
| OQ-P2-01 | Should the system prevent downgrading an advisory with acknowledged bookings, or allow it (informational only)? |
| OQ-P2-02 | Does instant approval fail-soft (waiting list) or hard-fail (reject with conflict error) when the slot is contested? |
| OQ-P2-03 | Are advisory acknowledgements legally binding consent or merely informational? |
| OQ-P2-04 | What is the exact set of space types eligible for instant booking? (Assumed: Computer Laboratory, Meeting Room — A-04.) |
| OQ-P2-05 | On escalation to out-of-service, should overlapping approved bookings be auto-cancelled or only flagged for staff contact? (Requirement says "contact the requesters" → only flagged.) |
| OQ-P2-06 | Should semesters in reporting be derived from date-range parameters or an explicit semester table? (Assumed: date-range parameters.) |
