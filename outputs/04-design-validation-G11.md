# Database Design Validation - G11

## Phase 1: ERD vs. Relational Schema Mapping Evaluation

### Entity-to-Table Mapping

| Entity (Step 2 ERD) | Table (Step 3 Logical) | Status |
| :--- | :--- | :--- |
| USER | users | PASS |
| SPACE | spaces | PASS |
| FACILITY_CATALOG | facility_catalog | PASS |
| SPACE_FACILITY | space_facility | PASS |
| FACILITY_ASSET | facility_assets | PASS |
| BOOKING | bookings | PASS |
| APPROVAL | approvals | PASS |
| USAGE_SESSION | usage_sessions | PASS |
| MAINTENANCE_RECORD | maintenance_records | PASS |

Result: All 9 entities map to 9 tables. No extra or missing tables. **PASS**.

### Weak Entities
No weak entities defined in the ERD. **PASS**.

### 1:1 Relationships

| Relationship | Check | Implementation | Status |
| :--- | :--- | :--- | :--- |
| BOOKING → APPROVAL | UNIQUE on FK | `approvals.booking_id`: `UNIQUE` + `NOT NULL` | PASS |
| BOOKING → USAGE_SESSION | UNIQUE on FK | `usage_sessions.booking_id`: `UNIQUE` + `NOT NULL` | PASS |
| | FK placement | FK placed on child tables (approvals, usage_sessions) — correct | PASS |
| | Split justification | Mandated by pipeline override (Booking Lifecycle Normalization) | PASS |

Both 1:1 relationships correctly implemented. **PASS**.

### 1:N Relationships

| Relationship | FK Placement | NOT NULL | Status |
| :--- | :--- | :--- | :--- |
| USER → BOOKING | `user_id` in bookings | NOT NULL (mandatory) | PASS |
| SPACE → BOOKING | `space_id` in bookings | NOT NULL (mandatory) | PASS |
| SPACE → SPACE_FACILITY | `space_id` in space_facility | NOT NULL (mandatory) | PASS |
| FACILITY_CATALOG → SPACE_FACILITY | `catalog_id` in space_facility | NOT NULL (mandatory) | PASS |
| SPACE → FACILITY_ASSETS | `space_id` in facility_assets | NOT NULL (mandatory) | PASS |
| FACILITY_CATALOG → FACILITY_ASSETS | `catalog_id` in facility_assets | NOT NULL (mandatory) | PASS |
| SPACE → MAINTENANCE_RECORDS | `space_id` in maintenance_records | NOT NULL (mandatory) | PASS |
| USER (reporter) → MAINTENANCE_RECORDS | `reporter_id` in maintenance_records | NOT NULL (mandatory) | PASS |
| USER (assigned) → MAINTENANCE_RECORDS | `assigned_staff_id` in maintenance_records | NULL (optional) | PASS |

All FKs correctly placed with appropriate nullability. **PASS**.

### Non-FK Attribute Nullability

**No FAIL cases.** Nullable columns follow lifecycle patterns:
- `approvals.rejection_reason`: Only known at rejection time
- `usage_sessions.actual_start_time`, `actual_end_time`, `initial_condition`, `final_condition`, `usage_notes`: Filled during check-in/check-out
- `maintenance_records.assigned_staff_id`, `completion_time`, `result_note`: Filled during maintenance workflow

**PASS**.

### M:N Relationships
SPACE ↔ FACILITY_CATALOG resolved by `space_facility` with composite PK `(space_id, catalog_id)` and business attribute `quantity`. **PASS**.

### ISA / Subtyping Relationships
None present. **PASS**.

---

## Phase 2: Business Rules Traceability Matrix

Only rules with FAIL or DELEGATED_TO_APP status.

| Rule ID | Description | Mapped DB Element | Constraint / Technical Logic | Status |
| :--- | :--- | :--- | :--- | :--- |
| BR-01 | No overlapping approved bookings on same space | — | Cross-row validation; requires scanning existing rows | DELEGATED_TO_APP |
| BR-02 | Unavailable spaces cannot be booked | — | Cross-table validation (booking vs space status) | DELEGATED_TO_APP |
| BR-04 | Rejection reason required when rejected | — | Cross-table dependency (status in bookings, reason in approvals) | DELEGATED_TO_APP |

All remaining business rules (BR-03, BR-05 through BR-10) are structurally enforced. **PASS**.

---

## Phase 3: Keys & Constraints Evaluation

### Primary Keys (PK)
All 9 tables have explicit primary keys. 8 use `INT IDENTITY(1,1)`. `space_facility` uses composite PK. **PASS**.

### Foreign Keys & Deletion/Update Strategy

| Check | Result |
| :--- | :--- |
| CASCADE Violation (DELETE) | `space_facility` uses CASCADE — this is a pure junction table, not transactional/audit. Acceptable. All other tables use NO ACTION. **PASS**. |
| Natural Key Update Policy | All FKs reference surrogate INT IDENTITY keys (immutable). ON UPDATE NO ACTION is correct. **PASS**. |
| Soft Deletion | Not implemented. Physical deletion prevented by FK NO ACTION. **PASS**. |

### Data Integrity Constraints

| Check | Result |
| :--- | :--- |
| UNIQUE | `users.email` ✓, `spaces.space_code` ✓, `facility_assets.asset_tag` ✓, `approvals.booking_id` ✓, `usage_sessions.booking_id` ✓. **PASS**. |
| NOT NULL | All mandatory fields correctly constrained. **PASS**. |
| DEFAULT | `users.account_status` defaults to 'Active'. **PASS**. |

### Business Logic Constraints

| Check | Result |
| :--- | :--- |
| CHECK — Domain | `capacity > 0` ✓, `quantity >= 0` ✓, `expected_participants > 0` ✓. **PASS**. |
| CHECK — Format/Logic | `users.email` lacks format check (`LIKE '%@%'`). **WARNING**. |
| CHECK — Chronological | `bookings`: `end_time > start_time` ✓. `usage_sessions`: `actual_end_time > actual_start_time` ✓. All covered. **PASS**. |
| Allowed Value Sets | All enum columns have explicit CHECK. `maintenance_records.status` has no CHECK (values not enumerated — documented in OQ-01). **PASS**. |

### Enum Value Fidelity

All enum values match Step 1 wording exactly:
- `role`: Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager ✓
- `current_status`: Available, In Use, Under Maintenance, Temporarily Closed, Retired ✓
- `status`: Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-show ✓
- `purpose`: Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event ✓

No invented, abbreviated, or missing values. **PASS**.

---

## Executive Validation Summary

| Category | PASS | DELEGATED_TO_APP | FAIL/GAP |
| :--- | :---: | :---: | :---: |
| Entity Mapping | X | | |
| Weak Entities | X | | |
| Relationships (1:1) | X | | |
| Relationships (1:N) | X | | |
| Relationships (M:N) | X | | |
| Relationships (ISA) | X | | |
| Business Rules | X | X | |
| Primary Keys | X | | |
| Foreign Keys | X | | |
| Unique Constraints | X | | |
| CHECK Constraints | X | | |
| Chronological Logic | X | | |

---

## Recommendations for Remediation

| Failed Phase | Entity/Table/Element | Detected Issue | Exact SQL / Markdown Fix Needed |
| :--- | :--- | :--- | :--- |
| Phase 3 (WARNING) | users.email | No email format CHECK constraint | `ALTER TABLE users ADD CONSTRAINT CK_users_email CHECK (email LIKE '%@%');` |

No FAIL statuses. Three DELEGATED_TO_APP rules are legitimately deferred due to cross-row (BR-01) and cross-table (BR-02, BR-04) dependencies.
