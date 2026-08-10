# Requirement Change Analysis - G11 (Phase 2)

## 1. Requirement Change Inventory

The Facility Manager introduces three families of Phase 2 changes on top of the Phase 1 baseline (`req/business-requirement.md`, Phase 2 Extensions):

| ID | New / Changed Rule or Operating Condition | Phase 1 Element Affected | Nature of Effect | Knock-on Effects |
| :--- | :--- | :--- | :--- | :--- |
| RC-01 | Maintenance work splits into two impact levels: `out-of-service` (space unusable) and `advisory` (space usable, requester must be notified + acknowledgement recorded). | `SPACE.current_status` value set, `MAINTENANCE_RECORD`, `BOOKING` | Attribute added (`MAINTENANCE_RECORD.impact_level`), status range reduced on `SPACE.current_status`, existing rule refined. | Booking availability check logic, advisory acknowledgement storage, affected-booking identification on escalation. |
| RC-02 | A space may have several concurrently active maintenance records with different impact levels. | `MAINTENANCE_RECORD` | New allowed state (multiple open records per space). No schema conflict; operational rule. | Availability checks must consider all overlapping records, not a single status. |
| RC-03 | `impact_level` may be escalated/downgraded while maintenance is open; on escalation to `out-of-service`, already-approved overlapping bookings must be identified. | `MAINTENANCE_RECORD.impact_level`, `BOOKING.status`, `BOOKING.start_time/end_time` | New attribute update path + new reporting query. | Escalation report (approved bookings overlapped by maintenance window). |
| RC-04 | End users submit incident reports; manager/staff triage consolidates duplicate reports into one maintenance record and decides `impact_level`. | New entity `INCIDENT_REPORT`, new M:N via `REPORT_CONSOLIDATION` | New entity + relationship added. | `MAINTENANCE_RECORD.impact_level` default `advisory`; decision authority stays on maintenance, not reports. |
| RC-05 | Booking blocking must read only `MAINTENANCE_RECORD` with `impact_level = 'out-of-service'`; unresolved/duplicate `INCIDENT_REPORT` rows must be ignored for blocking. | Booking availability rule (BR-02) | Rule delegated/refined (blocking source changes). | Concurrency-safe availability check procedure. |
| RC-06 | Auto-booking for selected space types: requests satisfying usage policy auto-approved at submission. | `SPACE` (new flag), `APPROVAL` (nullable staff), `BOOKING.status` | Attribute added (`SPACE.auto_booking_enabled BIT NOT NULL DEFAULT 0`); `APPROVAL.staff_id` becomes nullable. | Automatic approval procedure, concurrency with staff approval. |
| RC-07 | Two approved bookings must never overlap on the same space even under concurrent instant-booking and staff-approval operations. | BR-01 (no-overlap rule) | Rule strengthened with concurrency requirement. | Locking/isolation strategy, transactional stored procedures. |
| RC-08 | Reporting target must be normalized: a report can target a room, a facility type within the room, or a specific tracked asset. | `SPACE_FACILITY`, `FACILITY_ASSET`, new `INCIDENT_REPORT` | `SPACE_FACILITY` gains surrogate key `space_facility_id`; `FACILITY_ASSET` re-pointed to it; `INCIDENT_REPORT` gains nullable target columns. | New FK integrity rule (`asset_id` requires matching `space_facility_id`). |

### Mandatory coverage checklist

- [x] `SPACE.current_status` no longer carries `Under Maintenance`; maintenance blocking delegated to `MAINTENANCE_RECORD` overlap where `impact_level = 'out-of-service'`.
- [x] End users submit `INCIDENT_REPORT`; manager/staff triage consolidates duplicate reports into one `MAINTENANCE_RECORD` and decides `impact_level`, defaulting to `'advisory'` unless escalated.
- [x] Reporting target normalized through a facility-instance layer (room / facility-type-in-room / specific asset).
- [x] `SPACE_FACILITY` evolves to surrogate-key entity with `space_facility_id`; `FACILITY_ASSET` references that entity; `INCIDENT_REPORT` carries nullable `space_facility_id` and `asset_id` with the rule that `asset_id` requires a non-null `space_facility_id` and a matching asset-to-facility relationship.

## 2. Affected Entities / Relationships / Attributes

| Entity | Phase 1 | Phase 2 Change | Details |
| :--- | :--- | :--- | :--- |
| `spaces` | `current_status` CHECK includes `Under Maintenance` | **Refined** — remove `Under Maintenance` from CHECK | `current_status` becomes operational-state-only: Available, In Use, Temporarily Closed, Retired. |
| `spaces` | — | **Attribute added** | `auto_booking_enabled BIT NOT NULL DEFAULT (0)`. |
| `space_facility` | Composite PK `(space_id, catalog_id)` | **Normalized** — surrogate key added | New `space_facility_id INT IDENTITY` PK; `(space_id, catalog_id)` kept as `UNIQUE`. |
| `facility_assets` | FK on `space_id`, `catalog_id` | **Re-pointed** | New `space_facility_id` FK → `space_facility(space_facility_id)`; existing data backfilled. |
| `maintenance_records` | No `impact_level` | **Attribute added** | `impact_level NVARCHAR(20) NOT NULL DEFAULT 'advisory'` CHECK IN ('advisory','out-of-service'). |
| `approvals` | `staff_id INT NOT NULL` | **Relaxed** | `staff_id` becomes `NULL`-able; auto-approvals store `NULL`. |
| `bookings` | status set | **Attribute added** | `advisory_acknowledged BIT`, `advisory_snapshot NVARCHAR(MAX)` to record notification + acknowledgement. |
| `incident_reports` | *(new)* | **Entity added** | Room/facility/asset target columns + consolidation status. |
| `report_consolidations` | *(new)* | **Entity added** | M:N between `incident_reports` and `maintenance_records` (many reports → one maintenance). |
| `advisory_acknowledgements` | *(new)* | **Entity added** | Records per-booking acknowledgement of active advisories. |

### New relationships

| Left | Cardinality | Right | Label |
| :--- | :--- | :--- | :--- |
| USER | 1:N | INCIDENT_REPORT | submits |
| INCIDENT_REPORT | M:N | MAINTENANCE_RECORD | consolidated via REPORT_CONSOLIDATION |
| SPACE | 1:N | INCIDENT_REPORT | has |
| SPACE_FACILITY | 1:N | FACILITY_ASSET | instances |
| SPACE_FACILITY | 1:N | INCIDENT_REPORT | targeted_by (optional) |
| FACILITY_ASSET | 1:N | INCIDENT_REPORT | targeted_by (optional) |
| BOOKING | 1:N | ADVISORY_ACKNOWLEDGEMENT | records |
| MAINTENANCE_RECORD | 1:N | ADVISORY_ACKNOWLEDGEMENT | acknowledged_for |

## 3. Business Rule Impact

| Rule ID (Phase 1) | Status | New Condition |
| :--- | :--- | :--- |
| BR-01 | **Strengthened** | No two approved bookings overlap on the same space — now must hold under concurrency (instant + staff approval). Enforced by DB stored procedures with locking. |
| BR-02 | **Refined** | A space cannot be booked when it is `Temporarily Closed`/`Retired`, OR when a `MAINTENANCE_RECORD` with `impact_level='out-of-service'` overlaps the requested window. Advisory maintenance does **not** block. `current_status` no longer has `Under Maintenance`. |
| BR-03 | **Refined** | Decision time + note always recorded. `staff_id` is `NULL` for automatic approvals, non-`NULL` for manual staff decisions. |
| BR-04 | Kept unchanged | Rejection reason required when rejected. |
| BR-05 | Kept unchanged | Check-in fields recorded. |
| BR-06 | Kept unchanged | Check-out fields recorded. |
| BR-07 | Kept unchanged | Historical preservation (NO ACTION on FKs). |
| BR-08 | **Extended** | Views extended: spaces under out-of-service maintenance, advisory-aware booking history, affected bookings on escalation. |
| BR-09 | Kept unchanged | 1:1 BOOKING↔APPROVAL, BOOKING↔USAGE_SESSION. |
| BR-10 | **Extended** | Facility pattern normalized with surrogate facility-instance layer. |
| BR-11 *(new)* | **Extended** | Advisory maintenance must be notified and acknowledged at booking time. |
| BR-12 *(new)* | **Delegated** | `impact_level` decision authority is maintenance triage only; end-user reports cannot set blocking level. |
| BR-13 *(new)* | **Delegated** | Auto-booking only when `auto_booking_enabled = 1` and all policy checks pass. |
| BR-14 *(new)* | **Delegated** | Incident target integrity: `asset_id` requires matching `space_facility_id`. |

## 4. Concurrency Conflict Analysis

### Conflict A — Instant-booking vs. instant-booking (double-booking)

1. T1 and T2 both read `bookings` for space S at the same window; no approved overlap found.
2. T1 inserts booking B1 → Approved. T2 inserts booking B2 → Approved.
3. Both approved records overlap on S.
- **Outcome if uncontrolled:** two approved bookings for the same space/time — violates BR-01.
- **Threatened invariant:** no overlapping approved bookings per space.

### Conflict B — Instant-booking vs. staff approval

1. Staff opens approval transaction for pending booking B1 and checks availability.
2. Concurrently, instant-booking transaction inserts B2 in the overlapping window and commits.
3. Staff then approves B1 based on stale availability read.
- **Outcome if uncontrolled:** B1 and B2 overlap — BR-01 violation.
- **Threatened invariant:** no overlapping approved bookings regardless of approval path.

### Conflict C — Duplicate incident reports + manager consolidation

1. Two users report the same broken projector within seconds → two `INCIDENT_REPORT` rows (expected: many reports → one maintenance).
2. Manager triages and creates `MAINTENANCE_RECORD` M; meanwhile a second consolidation transaction also creates maintenance record M' for the same reports.
3. **Outcome if uncontrolled:** duplicate maintenance records, reports consolidated twice, duplicated staff effort and inconsistent impact decisions.
4. **Threatened invariant:** one consolidated maintenance record per issue; `impact_level` decided exactly once by triage.

### Conflict D — Escalation vs. concurrent approval

1. A booking is in-flight (Pending) while a maintenance record escalates to `out-of-service` overlapping its window.
2. Approval reads maintenance before escalation commits; approves booking after escalation.
3. **Outcome if uncontrolled:** approved booking overlaps out-of-service window; affected-booking report misses it.
- **Threatened invariant:** no approved booking overlaps an out-of-service maintenance window (BR-02 refined).

### Conflict E — Concurrent auto-approval on the same space

1. Two requests for the same space/window both satisfy policy and both target an auto-booking space.
2. Both stored procedure calls pass the availability check before either writes.
- **Outcome if uncontrolled:** two auto-approved overlapping bookings.
- **Threatened invariant:** BR-01 + BR-13.

## 5. Assumptions & Open Questions

| ID | Type | Item |
| :--- | :--- | :--- |
| AS-01 | Assumption | `auto_booking_enabled` defaults to `0` (safe — opt-in) for all existing and new spaces. |
| AS-02 | Assumption | Advisory acknowledgement is stored via a dedicated `advisory_acknowledgements` table plus snapshot fields on `bookings`. |
| AS-03 | Assumption | A single `INCIDENT_REPORT` may be left unconsolidated (status `Open`); blocking logic ignores it entirely. |
| AS-04 | Assumption | Maintenance `status` keeps Phase 1 free-text progression; `impact_level` is a separate triage attribute. |
| AS-05 | Assumption | Incident report target defaults to room-level (`space_facility_id`/`asset_id` NULL) when nothing specific is chosen. |
| OQ-01 | Open question | Should an advisory maintenance record with a future `start_time` still block? (Assumed: only overlapping `out-of-service` blocks, per requirement wording.) |
| OQ-02 | Open question | Which space types are eligible for auto-booking? (Assumed: configurable via `auto_booking_enabled` per space, not by type.) |
| OQ-03 | Open question | Who exactly may escalate `impact_level`? (Assumed: Facility Staff/Manager triage, recorded via `assigned_staff_id` context.) |
| OQ-04 | Open question | Should rejected/cancelled bookings ever carry advisory acknowledgements? (Assumed: only approved bookings get acknowledgement rows.) |

## 6. Traceability to Phase 2 Workflow

| Pipeline Step | Uses This Analysis |
| :--- | :--- |
| 09 Updated ERD & Logical Design | RC-01, RC-04, RC-06, RC-08 |
| 10 Schema Migration | RC-01, RC-06, RC-08 (ALTER/ADD) |
| 11-12 Concurrency Design & Implementation | RC-06, RC-07, Conflict A-E |
| 13 Concurrency Tests | Conflict A-E |
| 16 Analytical Queries | RC-03, RC-08 reporting needs |
