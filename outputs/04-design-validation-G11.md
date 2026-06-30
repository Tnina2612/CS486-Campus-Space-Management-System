# Database Design Validation — G11

## Phase 1: ERD vs. Relational Schema Mapping Evaluation

### Entity-to-Table Mapping

| Entity (Step 2) | Table (Step 3) | Status |
|-----------------|----------------|--------|
| USER | USER | PASS |
| SPACE | SPACE | PASS |
| FACILITY_CATALOG | FACILITY_CATALOG | PASS |
| SPACE_FACILITY | SPACE_FACILITY | PASS |
| FACILITY_ASSET | FACILITY_ASSET | PASS |
| BOOKING | BOOKING | PASS |
| APPROVAL | APPROVAL | PASS |
| USAGE_SESSION | USAGE_SESSION | PASS |
| MAINTENANCE | MAINTENANCE | PASS |

All 9 entities mapped to 9 tables. No extra table.

### Weak Entities
None identified in the ERD. N/A.

### 1:1 Relationships

| Relationship | FK Column | UNIQUE? | NOT NULL? | FK Side | Status |
|-------------|-----------|---------|-----------|---------|--------|
| BOOKING → APPROVAL | APPROVAL.booking_id | YES | YES | APPROVAL | PASS |
| BOOKING → USAGE_SESSION | USAGE_SESSION.booking_id | YES | YES | USAGE_SESSION | PASS |

Both 1:1 relationships properly implemented with UNIQUE constraint and NOT NULL on the FK. Both use NO ACTION on DELETE (preserving history).

### 1:N Relationships

| Relationship | FK Column | NOT NULL? | On Correct Side? | Status |
|-------------|-----------|-----------|------------------|--------|
| USER → BOOKING | BOOKING.user_id | YES | YES | PASS |
| SPACE → BOOKING | BOOKING.space_code | YES | YES | PASS |
| USER (decider) → APPROVAL | APPROVAL.staff_id | YES | YES | PASS |
| USER (check-in) → USAGE_SESSION | USAGE_SESSION.checked_in_by | YES | YES | PASS |
| FACILITY_CATALOG → SPACE_FACILITY | SPACE_FACILITY.catalog_id | YES (part of PK) | YES | PASS |
| SPACE → SPACE_FACILITY | SPACE_FACILITY.space_code | YES (part of PK) | YES | PASS |
| FACILITY_CATALOG → FACILITY_ASSET | FACILITY_ASSET.catalog_id | YES | YES | PASS |
| SPACE → FACILITY_ASSET | FACILITY_ASSET.space_code | YES | YES | PASS |
| USER (reporter) → MAINTENANCE | MAINTENANCE.reporter_id | YES | YES | PASS |
| USER (assigned staff) → MAINTENANCE | MAINTENANCE.assigned_staff_id | NO (nullable) | YES | PASS |
| SPACE → MAINTENANCE | MAINTENANCE.space_code | YES | YES | PASS |

All 1:N FK placements and nullability correct.

### M:N Relationships

| Entities | Junction Table | Composite PK? | Business Attribute | Status |
|----------|---------------|---------------|-------------------|--------|
| SPACE ↔ FACILITY_CATALOG | SPACE_FACILITY | (space_code, catalog_id) | quantity | PASS |

### Non-FK Attribute Nullability (Lifecycle Timing)

| Table | Column | Step 3 Nullable? | Expected Timing per Requirement | Status |
|-------|--------|-----------------|--------------------------------|--------|
| BOOKING | status | NOT NULL (DEFAULT) | Set at creation, updated later | PASS |
| BOOKING | requested_start_time | NOT NULL | Set at creation | PASS |
| BOOKING | requested_end_time | NOT NULL | Set at creation | PASS |
| BOOKING | purpose | NOT NULL | Set at creation | PASS |
| BOOKING | expected_participants | NOT NULL | Set at creation | PASS |
| BOOKING | booking_type | NOT NULL | Set at creation | PASS |
| APPROVAL | decision | NOT NULL | Recorded at decision time | PASS |
| APPROVAL | decision_time | NOT NULL | Recorded at decision time | PASS |
| APPROVAL | decision_note | NULL | Optional at decision time | PASS |
| APPROVAL | rejection_reason | NULL | Required only if rejected (CHECK enforced) | PASS |
| USAGE_SESSION | actual_start_time | NOT NULL | Recorded at check-in | PASS |
| USAGE_SESSION | checked_in_by | NOT NULL | Recorded at check-in | PASS |
| USAGE_SESSION | initial_condition | NULL | Recorded at check-in (optional) | PASS |
| USAGE_SESSION | actual_end_time | NULL | Recorded at check-out (later stage) | PASS |
| USAGE_SESSION | final_condition | NULL | Recorded at check-out (optional) | PASS |
| USAGE_SESSION | usage_notes | NULL | Optional notes at check-out | PASS |
| MAINTENANCE | status | NOT NULL (DEFAULT) | Set at creation, updated later | PASS |
| MAINTENANCE | problem_description | NOT NULL | Set at creation | PASS |
| MAINTENANCE | problem_type | NOT NULL | Set at creation | PASS |
| MAINTENANCE | start_time | NOT NULL | Set at creation | PASS |
| MAINTENANCE | completion_time | NULL | Recorded at completion | PASS |
| MAINTENANCE | result_note | NULL | Recorded at completion | PASS |
| MAINTENANCE | assigned_staff_id | NULL | Assigned later | PASS |

### ISA/Subtyping
None. N/A.

---

## Phase 2: Business Rules Traceability Matrix

| Rule ID | Business Rule Description | Mapped DB Element | Constraint / Technical Logic | Status |
|---------|--------------------------|-------------------|------------------------------|--------|
| BR-01 | Every user must have a registered university account | USER table | PK + NOT NULL on all required USER columns | PASS |
| BR-02 | Same space cannot have overlapping approved bookings | BOOKING | Application logic (multi-row time overlap check against approved bookings) | DELEGATED_TO_APP |
| BR-03 | Space under maintenance/closed/retired cannot be booked | SPACE + MAINTENANCE | Application logic (cross-table validation: SPACE.current_status and MAINTENANCE.status at booking time) | DELEGATED_TO_APP |
| BR-04 | Booking status lifecycle: pending→approved→checked_in→completed... | BOOKING.status | CHECK(status IN (7 values)); state transitions via application logic | DELEGATED_TO_APP |
| BR-05 | Approval requires staff, decision time, note | APPROVAL | staff_id NOT NULL, decision_time NOT NULL, decision_note NULL | PASS |
| BR-06 | Rejection requires rejection reason | APPROVAL | CHECK((decision='rejected' AND rejection_reason IS NOT NULL) OR (decision='approved')) | PASS |
| BR-07 | Check-in records actual start time, who checked in, initial condition | USAGE_SESSION | actual_start_time NOT NULL, checked_in_by NOT NULL, initial_condition NULL | PASS |
| BR-08 | Check-out records actual end time, final condition, usage notes | USAGE_SESSION | actual_end_time NULL, final_condition NULL, usage_notes NULL | PASS |
| BR-09 | No hard deletes of completed sessions/history | BOOKING, MAINTENANCE + all FK references | ON DELETE NO ACTION on BOOKING and MAINTENANCE parent FKs | PASS |
| BR-10 | Unique asset tag per trackable facility | FACILITY_ASSET.asset_tag | UNIQUE constraint | PASS |
| BR-11 | Catalog vs. Asset Hybrid Pattern | FACILITY_CATALOG + SPACE_FACILITY + FACILITY_ASSET | Three-table pattern with is_trackable flag | PASS |
| BR-12 | Maintenance blocks booking of unavailable spaces | SPACE.current_status + MAINTENANCE.status | CHECK on status values; overlap prevention delegated to app | PASS |
| A-01 | User IDs university-assigned and globally unique | USER.user_id | Natural PK | PASS |
| A-02 | Booking always for exactly one space | BOOKING.space_code | NOT NULL FK | PASS |
| A-03 | Maintenance tied to space, not individual assets | MAINTENANCE.space_code | NOT NULL FK | PASS |
| A-04 | Check-in/out performed by facility staff | USAGE_SESSION.checked_in_by | NOT NULL FK → USER | PASS |
| A-05 | is_trackable determines SPACE_FACILITY vs FACILITY_ASSET | FACILITY_CATALOG.is_trackable | BIT flag; application-level routing | DELEGATED_TO_APP |
| A-06 | Account status values system-defined | USER.account_status | CHECK(account_status IN ('active','inactive','suspended')) | PASS |
| A-07 | Maintenance status values system-defined | MAINTENANCE.status | CHECK(status IN ('reported','in_progress','completed','cancelled')) | PASS |
| A-08 | Facility asset status values system-defined | FACILITY_ASSET.status | CHECK(status IN ('working','damaged','under_repair','retired')) | PASS |
| A-09 | 'other' problem_type for uncovered issues | MAINTENANCE.problem_type | CHECK includes 'other' as allowed value | PASS |
| A-10 | Decision column captures approve/reject outcome | APPROVAL.decision | CHECK(decision IN ('approved','rejected')) | PASS |

---

## Phase 3: Keys & Constraints Evaluation

### Primary Keys

| Table | PK Column(s) | Type | Status |
|-------|-------------|------|--------|
| USER | user_id | Natural | PASS |
| SPACE | space_code | Natural | PASS |
| FACILITY_CATALOG | catalog_id | Natural | PASS |
| SPACE_FACILITY | (space_code, catalog_id) | Composite Natural | PASS |
| FACILITY_ASSET | asset_id | Surrogate IDENTITY | PASS |
| BOOKING | booking_id | Surrogate IDENTITY | PASS |
| APPROVAL | approval_id | Surrogate IDENTITY | PASS |
| USAGE_SESSION | session_id | Surrogate IDENTITY | PASS |
| MAINTENANCE | maintenance_id | Surrogate IDENTITY | PASS |

### Foreign Keys — ON DELETE Evaluation

| From Table | From Column | To Table | ON DELETE | Vulnerability? | Status |
|------------|-------------|----------|-----------|----------------|--------|
| BOOKING | user_id | USER | NO ACTION | No — preserves booking history | PASS |
| BOOKING | space_code | SPACE | NO ACTION | No — preserves booking history | PASS |
| APPROVAL | booking_id | BOOKING | NO ACTION | No — preserves approval history | PASS |
| APPROVAL | staff_id | USER | NO ACTION | No | PASS |
| USAGE_SESSION | booking_id | BOOKING | NO ACTION | No — preserves session history | PASS |
| USAGE_SESSION | checked_in_by | USER | NO ACTION | No | PASS |
| SPACE_FACILITY | space_code | SPACE | CASCADE | No — pure junction table, safe to cascade | PASS |
| SPACE_FACILITY | catalog_id | FACILITY_CATALOG | NO ACTION | No | PASS |
| FACILITY_ASSET | catalog_id | FACILITY_CATALOG | NO ACTION | No — preserves asset records | PASS |
| FACILITY_ASSET | space_code | SPACE | NO ACTION | No — preserves asset location history | PASS |
| MAINTENANCE | space_code | SPACE | NO ACTION | No — preserves maintenance history | PASS |
| MAINTENANCE | reporter_id | USER | NO ACTION | No | PASS |
| MAINTENANCE | assigned_staff_id | USER | SET NULL | No — unassigns without losing record | PASS |

All ON DELETE actions are correctly set. No CASCADE vulnerabilities on transactional/lifecycle tables.

### Foreign Keys — ON UPDATE Evaluation (Natural Key Policy)

| From Table | From Column | To Table | To Column Type | ON UPDATE | Natural Key? | Status |
|------------|-------------|----------|---------------|-----------|-------------|--------|
| BOOKING | user_id | USER | Natural (user_id) | NO ACTION | Yes | ⚠️ — user_id is a natural key; CASCADE recommended but acceptable if user IDs are immutable |
| BOOKING | space_code | SPACE | Natural (space_code) | CASCADE | Yes | PASS |
| SPACE_FACILITY | space_code | SPACE | Natural (space_code) | CASCADE | Yes | PASS |
| SPACE_FACILITY | catalog_id | FACILITY_CATALOG | Natural (catalog_id) | CASCADE | Yes | PASS |
| FACILITY_ASSET | catalog_id | FACILITY_CATALOG | Natural (catalog_id) | CASCADE | Yes | PASS |
| FACILITY_ASSET | space_code | SPACE | Natural (space_code) | CASCADE | Yes | PASS |
| MAINTENANCE | space_code | SPACE | Natural (space_code) | CASCADE | Yes | PASS |
| MAINTENANCE | reporter_id | USER | Natural (user_id) | NO ACTION | Yes | ⚠️ — Same as BOOKING.user_id; accepted if user IDs are immutable |
| MAINTENANCE | assigned_staff_id | USER | Natural (user_id) | NO ACTION | Yes | ⚠️ — Same note; SET NULL handles deletion so update is less critical |
| APPROVAL | staff_id | USER | Natural (user_id) | NO ACTION | Yes | ⚠️ — Same as BOOKING.user_id; accepted if user IDs are immutable |
| USAGE_SESSION | checked_in_by | USER | Natural (user_id) | NO ACTION | Yes | ⚠️ — Same as above |
| APPROVAL | booking_id | BOOKING | Surrogate (INT IDENTITY) | NO ACTION | No | PASS |
| USAGE_SESSION | booking_id | BOOKING | Surrogate (INT IDENTITY) | NO ACTION | No | PASS |

### UNIQUE Constraints

| Table | Column(s) | Purpose | Status |
|-------|-----------|---------|--------|
| USER | email | Ensure unique email | PASS |
| SPACE | (building, floor, room_number) | Candidate key (natural location) | PASS (listed as CK) |
| FACILITY_CATALOG | name | Ensure unique facility type name | PASS |
| FACILITY_ASSET | asset_tag | Ensure unique asset tag (BR-10) | PASS |
| APPROVAL | booking_id | Enforce 1:1 with BOOKING | PASS |
| USAGE_SESSION | booking_id | Enforce 1:1 with BOOKING | PASS |

### CHECK Constraints — Chronological Logic

| Table | Pair | CHECK Expression | Status |
|-------|------|-----------------|--------|
| BOOKING | requested_start_time, requested_end_time | requested_end_time > requested_start_time | PASS |
| USAGE_SESSION | actual_start_time, actual_end_time | actual_end_time IS NULL OR actual_end_time > actual_start_time | PASS |
| MAINTENANCE | start_time, completion_time | completion_time IS NULL OR completion_time >= start_time | PASS |

All chronological pairs covered.

### CHECK Constraints — Domain

| Table | Column | CHECK Expression | Status |
|-------|--------|-----------------|--------|
| USER | role | IN ('student','lecturer','teaching_assistant','facility_staff','department_administrator','facility_manager') | PASS |
| USER | account_status | IN ('active','inactive','suspended') | PASS |
| SPACE | space_type | IN ('auditorium','classroom','computer_laboratory','project_laboratory','meeting_room','student_workspace') | PASS |
| SPACE | current_status | IN ('available','in_use','under_maintenance','temporarily_closed','retired') | PASS |
| SPACE | capacity | > 0 | PASS |
| FACILITY_ASSET | status | IN ('working','damaged','under_repair','retired') | PASS |
| BOOKING | booking_type | IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event') | PASS |
| BOOKING | status | IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show') | PASS |
| BOOKING | expected_participants | > 0 | PASS |
| APPROVAL | decision | IN ('approved','rejected') | PASS |
| SPACE_FACILITY | quantity | > 0 | PASS |
| MAINTENANCE | problem_type | IN ('broken_projector','ac_failure','damaged_furniture','cleaning','network_problem','other') | PASS |
| MAINTENANCE | status | IN ('reported','in_progress','completed','cancelled') | PASS |

### Enum Value Fidelity (Step 1 vs Step 3)

| Column | Step 1 Values | Step 3 Schema Values | Match? |
|--------|--------------|---------------------|--------|
| USER.role | student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager | 'student','lecturer','teaching_assistant','facility_staff','department_administrator','facility_manager' | ✅ PASS — exact match |
| SPACE.space_type | auditorium, classroom, computer_laboratory, project_laboratory, meeting_room, student_workspace | 'auditorium','classroom','computer_laboratory','project_laboratory','meeting_room','student_workspace' | ✅ PASS — exact match |
| SPACE.current_status | available, in_use, under_maintenance, temporarily_closed, retired | 'available','in_use','under_maintenance','temporarily_closed','retired' | ✅ PASS — exact match |
| BOOKING.booking_type | lecture, examination, seminar, workshop, meeting, student_activity, administrative_event | 'lecture','examination','seminar','workshop','meeting','student_activity','administrative_event' | ✅ PASS — exact match |
| BOOKING.status | pending, approved, rejected, cancelled, checked_in, completed, no_show | 'pending','approved','rejected','cancelled','checked_in','completed','no_show' | ✅ PASS — exact match |
| APPROVAL.decision | (implied: approved, rejected — recorded as assumption A-10) | 'approved','rejected' | ✅ PASS — matches assumption |
| MAINTENANCE.problem_type | broken_projector, ac_failure, damaged_furniture, cleaning, network_problem, other | 'broken_projector','ac_failure','damaged_furniture','cleaning','network_problem','other' | ✅ PASS — exact match (assumption A-09) |
| MAINTENANCE.status | reported, in_progress, completed, cancelled | 'reported','in_progress','completed','cancelled' | ✅ PASS — exact match (assumption A-07) |
| FACILITY_ASSET.status | working, damaged, under_repair, retired | 'working','damaged','under_repair','retired' | ✅ PASS — exact match (assumption A-08) |
| USER.account_status | active, inactive, suspended | 'active','inactive','suspended' | ✅ PASS — exact match (assumption A-06) |

---

## Executive Validation Summary

| Category | PASS | DELEGATED_TO_APP | FAIL/GAP |
|----------|------|-----------------|----------|
| Entity Mapping | 9/9 | — | — |
| Weak Entities | N/A | — | — |
| Relationships (1:1) | 2/2 | — | — |
| Relationships (1:N) | 11/11 | — | — |
| Relationships (M:N) | 1/1 | — | — |
| Business Rules (incl. Assumptions) | 15 | 3 | — |
| Primary Keys | 9/9 | — | — |
| Foreign Keys (ON DELETE) | 13/13 | — | — |
| Foreign Keys (ON UPDATE) | 7/7 (4 ⚠️) | — | — |
| UNIQUE Constraints | 6/6 | — | — |
| CHECK Constraints (Domain) | 13/13 | — | — |
| CHECK Constraints (Chronological) | 3/3 | — | — |
| Enum Value Fidelity | 10/10 | — | — |
| Attribute Nullability (Lifecycle) | 23/23 | — | — |

## Recommendations for Remediation

| Failed Phase | Entity/Table/Element | Detected Issue | Exact SQL / Markdown Fix Needed |
|-------------|---------------------|----------------|--------------------------------|
| Phase 3 — FK UPDATE | BOOKING.user_id → USER | ON UPDATE NO ACTION on natural-key FK; consider CASCADE if user IDs can change | Optionally change to `ON UPDATE CASCADE` or document that user IDs are immutable |
| Phase 3 — FK UPDATE | APPROVAL.staff_id → USER | Same — NO ACTION on natural-key FK | Optionally change to `ON UPDATE CASCADE` or document immutability |
| Phase 3 — FK UPDATE | USAGE_SESSION.checked_in_by → USER | Same — NO ACTION on natural-key FK | Optionally change to `ON UPDATE CASCADE` or document immutability |
| Phase 3 — FK UPDATE | MAINTENANCE.reporter_id → USER | Same — NO ACTION on natural-key FK | Optionally change to `ON UPDATE CASCADE` or document immutability |
| Phase 3 — FK UPDATE | MAINTENANCE.assigned_staff_id → USER | Same — NO ACTION on natural-key FK | Optionally change to `ON UPDATE CASCADE` or document immutability |
