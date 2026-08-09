# Requirement Change Analysis - G11 (Phase 2)

> Baseline: Phase 1 outputs `01`–`04`. Source of truth for changes: `req/business-requirement.md` § Phase 2 Extensions.
> This document only records **what changes** and **what must be designed/protected**; no design or implementation is performed here.

---

## 1. Change Inventory

| # | New/Changed Statement (from requirement) | Affected Phase 1 element | Nature of effect | Knock-on effect |
| :-- | :--- | :--- | :--- | :--- |
| C1 | Maintenance now has **impact levels**: `out-of-service` blocks overlapping bookings; `advisory` does not block but requires notification + acknowledgement. | `MAINTENANCE_RECORD` | New attribute `impact_level` on `MAINTENANCE_RECORD`; new refinement of BR-02 | Booking-blocking logic must read only `MAINTENANCE_RECORD`; `SPACE.current_status` decoupled from maintenance |
| C2 | `SPACE.current_status` no longer carries `Under Maintenance`. | `SPACE.current_status` | Status domain **shrinks**: remove `Under Maintenance` from allowed value set | All Phase 1 queries/constraints referencing `'Under Maintenance'` must be updated; existing rows must be migrated |
| C3 | A space may have **several active maintenance records** at once with different impact levels. | `MAINTENANCE_RECORD` × `SPACE` (1:N) | Existing relationship retained; no cardinality change needed, but validation no longer assumes a single active record per space | Overlap logic must evaluate **each** open record, not a single status flag |
| C4 | Impact level may be **escalated/downgraded** while the record is open. | `MAINTENANCE_RECORD.impact_level` | Attribute is mutable after insert (no longer static) | Approved bookings overlapping an escalated record must be **findable** (new report) |
| C5 | **Advisory acknowledgement**: requester must be notified of all active advisories at booking time and the acknowledgement stored with the booking. | `BOOKING` + `MAINTENANCE_RECORD` | New relationship `BOOKING` ⇄ `MAINTENANCE_RECORD` (advisory) — M:N acknowledgement history | New table (e.g., `BOOKING_ADVISORY_ACKNOWLEDGEMENT`), snapshot of advisories at booking time |
| C6 | **Auto-booking**: for selected space types, requests satisfying the usage policy may be approved automatically at submission. | `SPACE`, `BOOKING`, `APPROVAL` | New attribute `SPACE.AutoBookingEnabled BIT`; new automated approval flow | Approval no longer always requires a human; `APPROVAL.staff_id` must become nullable |
| C7 | **Approval by machine**: auto-approved requests must not record a staff member. | `APPROVAL.staff_id` | `APPROVAL.staff_id` changes from `NOT NULL` to nullable `NULL` | Existing approval rows preserved; manual approvals still record staff |
| C8 | **Incident intake separated from maintenance authority**: end users submit `INCIDENT_REPORT`; staff/manager triage consolidates duplicates into one `MAINTENANCE_RECORD` and decides `impact_level`. | New entity `INCIDENT_REPORT`; `MAINTENANCE_RECORD.reporter_id` semantics | New entity + new M:N relationship (many incident reports → one maintenance record); `impact_level` authority stays on `MAINTENANCE_RECORD` | Booking checks must ignore `INCIDENT_REPORT` entirely |
| C9 | **Concurrency**: many users submit overlapping requests at once; conflicting bookings must never both be approved. | `BOOKING` approval flow | Business rule BR-01 must hold under concurrency — requires locking/isolation strategy | `sp_AutoApproveBookingRequest` and staff-approval path must be concurrency-safe |
| C10 | **Reporting**: 4 new reports (semester hours, weekday/hour distribution, capacity+facility availability, escalation-affected bookings). | Cross-table queries | New analytical/reporting queries | Supported by indexes (Step 9) |

---

## 2. Affected Entities / Relationships / Attributes

| Element | Type | Phase 1 state | Phase 2 change |
| :--- | :--- | :--- | :--- |
| `SPACE.current_status` | Attribute | CHECK includes `'Under Maintenance'` | Remove `'Under Maintenance'` from domain; represent only broad operational state |
| `SPACE.AutoBookingEnabled` | Attribute | (absent) | New `BIT NOT NULL DEFAULT (0)` |
| `MAINTENANCE_RECORD.impact_level` | Attribute | (absent) | New `NVARCHAR` with domain `{'out-of-service','advisory'}`; mutable while open |
| `APPROVAL.staff_id` | Attribute | `NOT NULL` FK → `users` | Make nullable; keep FK; auto-approvals store `NULL` |
| `BOOKING` | Entity | lifecycle states | Add advisory-snapshot/acknowledgement linkage (C5) |
| `INCIDENT_REPORT` | Entity | (absent) | **New** entity — end-user issue submissions |
| `INCIDENT_REPORT` → `MAINTENANCE_RECORD` | Relationship | (absent) | **New** M:N consolidation (duplicates merged into one maintenance record) |
| `BOOKING` → `MAINTENANCE_RECORD` (advisory) | Relationship | (absent) | **New** M:N acknowledgement association |
| `APPROVAL` lifecycle | Business flow | Always human decision | Add machine decision path with `staff_id = NULL` |
| Booking availability check | Business logic | Reads `SPACE.current_status` | Reads `MAINTENANCE_RECORD` where `impact_level = 'out-of-service'` and time-overlap |

---

## 3. Business Rule Impact

| Phase 1 Rule | Status | Phase 2 disposition |
| :--- | :--- | :--- |
| BR-01 — No two approved bookings overlap on the same space | **Kept unchanged + hardened** | Invariant still absolute; now additionally enforced under concurrency via locking/isolation in both auto-approval and staff-approval paths |
| BR-02 — Unavailable spaces cannot be booked | **Refined** | "Under maintenance" blocking is **delegated** to `MAINTENANCE_RECORD` overlap where `impact_level = 'out-of-service'`; `advisory` maintenance does **not** block; `Temporarily Closed`/`Retired` remain blocking via `SPACE.current_status` |
| BR-03 — Approval records staff member, time, note | **Refined** | For manual approvals unchanged; for auto-approval `staff_id` is `NULL` (system is the decider); time and note still recorded |
| BR-04 — Rejection reason required when rejected | **Kept unchanged** | Unchanged |
| BR-05 / BR-06 — Check-in / check-out recording | **Kept unchanged** | Unchanged |
| BR-07 — Historical record preservation | **Kept unchanged** | New `INCIDENT_REPORT` history also preserved; consolidation must not delete reports |
| BR-08 — Staff view queries | **Extended** | New views/reports: escalation-affected bookings, available spaces by capacity+facilities |
| BR-09 — Strict 1:1 `BOOKING`↔`APPROVAL`, `BOOKING`↔`USAGE_SESSION` | **Kept unchanged** | Unchanged; auto-approval still creates exactly one `APPROVAL` row |
| BR-10 — Hybrid facility pattern | **Kept unchanged** | Unchanged; feeds capacity+facility availability report |

**New Phase 2 rules introduced:**
- **BR-11** — A space with an active `out-of-service` maintenance record cannot be booked for any overlapping time period (delegated to concurrency logic).
- **BR-12** — Advisory maintenance does not block; all active advisories must be surfaced to the requester and an acknowledgement recorded with the booking.
- **BR-13** — Auto-approval is allowed only when the target space has `SPACE.AutoBookingEnabled = 1` and the request satisfies the space usage policy; otherwise it follows staff approval.
- **BR-14** — Auto-approval must set `APPROVAL.staff_id = NULL` (no human decider).
- **BR-15** — `impact_level` authority rests solely on `MAINTENANCE_RECORD` (staff/manager triage); `INCIDENT_REPORT` rows never participate in booking blocking.

---

## 4. Concurrency Conflict Analysis

### Conflict A — Double approval of overlapping bookings (instant + staff path)
**Scenario:** Two users submit overlapping requests for the same popular space within a short interval.
- **Sequence:**
  1. Tx1 reads availability for space S (no conflicting approved booking) → no conflict.
  2. Tx2 reads availability for space S (no conflicting approved booking) → no conflict.
  3. Tx1 approves & inserts booking B1.
  4. Tx2 approves & inserts booking B2 (overlaps B1).
- **Break point:** both transactions performed the **check-then-act** (SELECT overlap → INSERT) between step 1–2 and step 3–4 with no serialization.
- **Undesirable outcome:** two approved bookings B1 and B2 overlap → BR-01 violated; room double-scheduled.
- **Invariant threatened:** BR-01 (also BR-11).

### Conflict B — Concurrent escalation of maintenance vs. in-flight booking approval
**Scenario:** A booking request is being validated while a manager concurrently escalates an advisory maintenance record to `out-of-service`.
- **Sequence:**
  1. Tx1 validates booking B against `MAINTENANCE_RECORD` (reads only advisory records) → passes.
  2. Tx2 escalates record R from `advisory` to `out-of-service` covering B's window.
  3. Tx1 commits approved booking B.
- **Break point:** validation and escalation are not isolated; the approved booking now violates the new blocking state.
- **Undesirable outcome:** an approved booking overlaps an `out-of-service` maintenance window; BR-11 violated.
- **Invariant threatened:** BR-11, BR-13.

### Conflict C — Duplicate incident reports consolidated concurrently
**Scenario:** Multiple students report the same broken projector at nearly the same time; two staff members each consolidate different subsets into different maintenance records.
- **Sequence:**
  1. Staff1 inserts `MAINTENANCE_RECORD` M1 and links incident reports R1, R2.
  2. Staff2 concurrently inserts `MAINTENANCE_RECORD` M2 and links incident reports R2, R3.
  3. R2 now maps to both M1 and M2 → duplicate/ambiguous maintenance; double work; inconsistent `impact_level` authority.
- **Break point:** consolidation link table is appended without a uniqueness/consolidation guard; two actors race on the same incident row set.
- **Undesirable outcome:** one incident contributes to two maintenance records; duplicate repair work; mixed impact levels.
- **Invariant threatened:** BR-15 (single authority) and the consolidation mapping must be 1-to-many (many incidents → one record), not many-to-many with overlap.

### Conflict D — Advisory acknowledgement lost during concurrent booking
**Scenario:** Two requesters book overlapping slots on a space with an active advisory; the acknowledgement is recorded per booking.
- **Sequence:** both transactions read the active advisory list and both insert bookings; acknowledgements are per-booking so no overlap violation — but if the advisory list read happens at a different isolation level, one requester may be notified of a stale/partial advisory set.
- **Undesirable outcome:** missed advisory notification → BR-12 partially violated.
- **Invariant threatened:** BR-12.

---

## 5. Assumptions & Open Questions

### Assumptions
- `MAINTENANCE_RECORD.impact_level` values are exactly `out-of-service` and `advisory` (per requirement wording). A `CHECK` constraint enforces this domain.
- Escalation/downgrade is implemented as an `UPDATE` of `impact_level`; no separate audit-history table for level changes is required by the requirement (a `maintenance_history` is not requested).
- `INCIDENT_REPORT` consolidation is implemented as an M:N mapping table that is **advisory-only for booking** (never read by booking checks), and consolidated to one primary `MAINTENANCE_RECORD`; a `merged_into_maintenance_id` nullable column on the mapping avoids duplicate consolidation races.
- `SPACE.AutoBookingEnabled = 0` is the safe default for all new and existing spaces; only specific space types are flipped to `1`.
- "Semester" is parameterised in the reporting queries (e.g., `@SemesterStart`, `@SemesterEnd`).
- Auto-approval policy check reuses the `SPACE.usage_policy` free-text plus structural checks (capacity vs. expected participants); detailed policy parsing is deferred to application logic.

### Open Questions
| ID | Question |
| :--- | :--- |
| OQ-P2-01 | Should `impact_level` changes be audited with timestamps (escalation history), or is an overwrite sufficient? |
| OQ-P2-02 | Which `space_type` values are eligible for auto-booking (`AutoBookingEnabled = 1`)? |
| OQ-P2-03 | When an advisory is acknowledged, must the acknowledgement be immutable even if the advisory is later escalated/downgraded? |
| OQ-P2-04 | Is there a grace period before an escalated `out-of-service` record blocks overlapping approvals (to let staff cancel affected bookings)? |
| OQ-P2-05 | Should duplicate incident reports be automatically merged by the system, or only by explicit staff action? |
| OQ-P2-06 | What is the exact definition of a "semester" date range for the reporting queries? |
