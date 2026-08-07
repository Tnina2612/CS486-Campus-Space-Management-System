# Requirement Change Analysis - G11

## 1. Executive Summary

Phase 2 introduces three categories of change on top of the Phase 1 design:

1. **Maintenance impact levels** — a refinement of BR-02: maintenance is now classified as either `out-of-service` (space cannot be booked during overlapping periods) or `advisory` (space remains bookable, but the requester must be informed and acknowledge). Escalation/downgrade of the impact level must be supported.
2. **Concurrent booking and approval** — instant booking (auto-approval for selected space types) plus the existing staff approval workflow, with a hard requirement that no two approved bookings ever overlap the same space even under concurrent execution.
3. **New reporting needs** — approved booking hours, bookings by weekday/hour, room finder, and escalation-affected bookings.

This document identifies the affected entities, relationships, business rules, and the concurrency conflicts that must be controlled.

---

## 2. Change Inventory

| ID | Change (from Phase 2 requirement) | Phase 1 element affected | Nature of effect |
| :--- | :--- | :--- | :--- |
| CH-01 | Maintenance work can make a space unusable (`out-of-service`): space cannot be booked for any overlapping time period. | `MAINTENANCE_RECORD`, BR-02 | BR-02 kept but made conditional; new attribute needed on the entity |
| CH-02 | Maintenance work that affects only part of equipment/comfort (`advisory`): space remains bookable, requester must be notified and acknowledgement stored. | `MAINTENANCE_RECORD`, `BOOKING`, BR-02 | New sub-rule (notify + record acknowledgement); new entity/relationship needed |
| CH-03 | A space may have several active maintenance records at the same time, with different impact levels. | `MAINTENANCE_RECORD` ↔ `SPACE` (1:N) | Constraint relaxation — previously implicit "one active maintenance blocks booking"; now multiple coexist |
| CH-04 | Impact level may be escalated (`advisory` → `out-of-service`) or downgraded while maintenance is still open. | `MAINTENANCE_RECORD` | New behavior; history of level changes recommended |
| CH-05 | On escalation to `out-of-service`, already-approved bookings overlapping the maintenance period must be identified. | `BOOKING` ↔ `MAINTENANCE_RECORD` | New reporting/query requirement |
| CH-06 | Many users may submit booking requests concurrently at semester start; popular spaces get several overlapping requests in a short interval. | `BOOKING` insertion path | New operating condition; concurrency risk |
| CH-07 | For selected space types, requests satisfying the usage policy are approved automatically at submission. | `SPACE`, `BOOKING` (approval workflow) | New behavior — auto-approval path bypassing `APPROVAL` entity |
| CH-08 | Two approved bookings must never overlap the same space regardless of creation path (instant or staff approval), even under concurrent execution. | BR-01, `BOOKING` | BR-01 kept but must now be enforced under concurrency (previously DELEGATED_TO_APP) |
| CH-09 | New reports: approved booking hours per space; approved bookings by weekday/hour; available spaces by capacity + facility list; affected bookings on escalation. | Various | New query/reporting requirements |

---

## 3. Affected Entities, Relationships & Attributes

### 3.1 Entities affected

| Entity | Change | Phase 2 action |
| :--- | :--- | :--- |
| `MAINTENANCE_RECORD` | Needs an impact level (`out-of-service` / `advisory`) | ADD attribute |
| `MAINTENANCE_RECORD` | Needs a record of level changes over time (escalate/downgrade) | New history entity (see 3.3) |
| `MAINTENANCE_RECORD` | Should reference the affected facility (specific asset or facility type) | ADD optional relationships (design assumption, see §6) |
| `SPACE` | Needs to mark which spaces allow instant (auto) booking | ADD attribute |
| `BOOKING` | Needs to record that the requester was informed of active advisories | New relationship/entity |
| `ADVISORY_ACKNOWLEDGEMENT` | (new) Records that a requester acknowledged active advisory maintenance at booking time | NEW entity |

### 3.2 Relationships affected

| Relationship | Phase 1 | Phase 2 | Reason |
| :--- | :--- | :--- | :--- |
| `SPACE` ↔ `MAINTENANCE_RECORD` (1:N) | unchanged | unchanged (multiple active allowed) | CH-03 |
| `BOOKING` ↔ `MAINTENANCE_RECORD` (advisory ack) | none | **NEW M:N** resolved via junction `ADVISORY_ACKNOWLEDGEMENT` | CH-02 |
| `MAINTENANCE_RECORD` ↔ `FACILITY_ASSET` / `FACILITY_CATALOG` | none | **NEW optional 0..1 each** (XOR) | Design assumption (§6) |
| `MAINTENANCE_RECORD` ↔ history | none | **NEW 1:N** identifying relationship | CH-04 |

### 3.3 Attributes added

| Table | Attribute | Type | Notes |
| :--- | :--- | :--- | :--- |
| `MAINTENANCE_RECORD` | `impact_level` | string enum | `out-of-service` / `advisory`; decided by Facility Staff/Manager (assumption) |
| `MAINTENANCE_RECORD` | `facility_catalog_id` (optional FK) | int | affected facility type (non-trackable facilities) |
| `MAINTENANCE_RECORD` | `facility_asset_id` (optional FK) | int | affected specific tracked asset |
| `SPACE` | `allows_instant_booking` | bit | enables CH-07 |
| `MAINTENANCE_IMPACT_HISTORY` (new) | `maintenance_id`, `impact_level`, `changed_at` | — | CH-04 |
| `ADVISORY_ACKNOWLEDGEMENT` (new) | `booking_id`, `maintenance_id`, `acknowledged_at` | — | CH-02 |

---

## 4. Business Rule Impact

| Rule ID | Phase 1 statement | Phase 2 status | New condition / handling |
| :--- | :--- | :--- | :--- |
| BR-01 | Same space cannot have two approved bookings with overlapping periods | **KEPT + STRENGTHENED** | Must hold under concurrency for both instant and staff-approved bookings. Enforcement moved from DELEGATED_TO_APP to a concurrency-controlled database procedure (Step 12). |
| BR-02 | Space under maintenance / closed / retired cannot be booked | **REFINED** | Only `out-of-service` maintenance blocks booking for overlapping periods. `advisory` does not block; instead requester must be notified and acknowledge. Closed/retired handling unchanged. |
| BR-03 | Approval records staff, time, note | **KEPT** | Instant bookings bypass the manual approval entity — documented exception (CH-07). |
| BR-04 | Rejection reason required when rejected | **KEPT** | Unchanged (staff approval path only). |
| BR-05/06 | Check-in / check-out recording | **KEPT** | Unchanged. |
| BR-07 | Historical records preserved | **KEPT** | Unchanged; new entities also preserve history (e.g., impact history). |
| BR-08 | Staff view queries | **KEPT** | Extended by new reports (CH-09). |
| BR-09 | Strict 1:1 booking↔approval / booking↔session | **KEPT** | Instant bookings do not create an `APPROVAL` row — the 1:1 constraint remains valid for the approval path. |
| BR-10 | Hybrid facility pattern | **KEPT** | Reused to link maintenance to facilities. |
| — (new) | Requester must be informed of all active advisories and acknowledgement stored | **NEW** | Enforced by required junction rows + application flow (Step 12). |
| — (new) | Escalated `out-of-service` requires identifying affected approved bookings | **NEW** | Supported by reporting query (Step 16). |

---

## 5. Concurrency Conflict Analysis

### 5.1 Conflict 1 — Double-booking race (check-then-act)

**Scenario:** Two users submit bookings for the same popular space with overlapping time periods at nearly the same moment. Both go through availability checks before either records its result.

**Sequence of operations (undesirable interleaving):**
1. Txn A: check availability of Space X → sees no approved booking → **no overlap**.
2. Txn B: check availability of Space X → also sees no approved booking → **no overlap**.
3. Txn A: INSERT booking A (approved).
4. Txn B: INSERT booking B (approved).

**Outcome without control:** Two approved bookings overlap Space X. BR-01 is violated silently.

**Threatened invariant:** BR-01.

### 5.2 Conflict 2 — Instant approval vs staff approval path

**Scenario:** A user instantly books Space X (auto-approved), while a staff member approves another request for the same space and overlapping period. The two operations run concurrently.

**Sequence of operations:**
1. Instant Txn A: check overlap → none → insert approved booking.
2. Staff Txn B: check overlap → none → insert approval for existing pending booking.
3. Both commit.

**Outcome without control:** Overlap again; the two creation paths do not share a lock, so both pass independently.

**Threatened invariant:** BR-01.

### 5.3 Conflict 3 — Maintenance escalation race

**Scenario:** A maintenance record is escalated from `advisory` to `out-of-service` while a user is simultaneously booking the space for an overlapping period.

**Sequence of operations:**
1. Txn A (booking): check — space has only advisory → allowed → insert booking.
2. Txn B (escalation): update impact level to `out-of-service`.
3. Txn A commits an approved booking overlapping the now-blocking maintenance period.

**Outcome without control:** An approved booking exists during an `out-of-service` maintenance period (BR-02 refined rule violated).

**Threatened invariant:** Refined BR-02.

---

## 6. Assumptions

- **A-01 (impact level owner):** The impact level of a maintenance record is decided by Facility Staff or Facility Manager when creating/updating the record. The reporter only reports the problem. *(Open question OQ-01.)*
- **A-02 (facility linkage):** A maintenance record may optionally reference the affected facility — either a specific tracked asset OR a facility type (catalog entry) OR neither (whole-space issue). This is an **XOR** constraint. *(This is an extension beyond the Phase 2 text, which does not require facility-level linkage.)*
- **A-03 (report time):** Phase 1 `start_time` on `MAINTENANCE_RECORD` is interpreted as the time the problem was reported (record creation time). No separate `reported_at` column is added to preserve Phase 1 schema. *(Open question OQ-02.)*
- **A-04 (advisory aggregation):** No hard rule is imposed when many advisories accumulate on one space (e.g., "3+ advisories ⇒ block"). The requester sees all active advisories at booking time and decides. *(Open question OQ-03.)*
- **A-05 (instant booking):** The decision of which space types allow instant booking is stored per-space via a boolean flag, not derived from space type.
- **A-06 (concurrency solution):** Pessimistic locking (row-level `UPDLOCK`/`SERIALIZABLE` on the space row) is chosen over optimistic/SNAPSHOT isolation; see Step 11.

---

## 7. Open Questions

| ID | Question |
| :--- | :--- |
| OQ-01 | Who exactly decides the impact level — any Facility Staff, or only Facility Manager? |
| OQ-02 | Should the report time and the maintenance-work start time be separate columns? |
| OQ-03 | Should an aggregation of many active advisories ever block a booking? |
| OQ-04 | What are the exact academic-semester boundaries for reporting (e.g., start/end dates of each semester)? |
