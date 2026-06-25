# Database Design Validation — G11

## Phase 1: ERD vs. Relational Schema Mapping Evaluation

### 1.1 Entity-to-Table Mapping

| ERD Entity | Logical Table | Status |
|---|---|---|
| USER | user | PASS |
| SPACE | space | PASS |
| FACILITY_CATALOG | facility_catalog | PASS |
| SPACE_FACILITY | space_facility | PASS |
| FACILITY_ASSET | facility_asset | PASS |
| BOOKING_REQUEST | booking_request | PASS |
| BOOKING_DECISION | booking_decision | PASS |
| BOOKING_SESSION | booking_session | PASS |
| MAINTENANCE_RECORD | maintenance_record | PASS |

**Result:** All 9 entities map 1:1 to tables. **PASS**

### 1.2 M:N Relationship Resolution

| M:N Relationship | Junction Table | Composite PK | Status |
|---|---|---|---|
| SPACE : FACILITY_CATALOG | space_facility | (space_code, catalog_id) | PASS |

**Result:** The single M:N relationship is properly resolved. **PASS**

### 1.3 1:N Foreign Key Placement

| Relationship | FK Column | Placed On (Many side) | Status |
|---|---|---|---|
| USER → BOOKING_REQUEST | requester_id | booking_request | PASS |
| SPACE → BOOKING_REQUEST | space_code | booking_request | PASS |
| BOOKING_REQUEST → BOOKING_DECISION | booking_id | booking_decision | PASS |
| BOOKING_REQUEST → BOOKING_SESSION | booking_id | booking_session | PASS |
| USER → BOOKING_DECISION | staff_id | booking_decision | PASS |
| SPACE → MAINTENANCE_RECORD | space_code | maintenance_record | PASS |
| USER (reports) → MAINTENANCE_RECORD | reported_by | maintenance_record | PASS |
| USER (assigned to) → MAINTENANCE_RECORD | assigned_to (nullable) | maintenance_record | PASS |
| SPACE → FACILITY_ASSET | space_code | facility_asset | PASS |
| FACILITY_CATALOG → FACILITY_ASSET | catalog_id | facility_asset | PASS |

**Result:** All 1:N relationships have FKs on the correct side. **PASS**

---

## Phase 2: Business Rules Traceability Matrix

| Rule ID | Business Rule | Mapped DB Element | Constraint / Technical Logic | Status |
|---|---|---|---|---|
| BR-01 | Each user must have a unique university account | user.email | UNIQUE constraint | PASS |
| BR-02 | No overlapping approved bookings for same space | booking_request (space_code, requested_start_time, requested_end_time) | Requires cross-row validation; cannot be enforced by a simple CHECK. Must be handled via application logic or a trigger. | DELEGATED_TO_APP |
| BR-03 | Space under maintenance / closed / retired cannot be booked | space.current_status + booking_request.space_code | Application must check space.current_status before creating/approving a booking. | DELEGATED_TO_APP |
| BR-04 | Decision must log staff, time, and note | booking_decision (staff_id, decision_time, decision_note) | staff_id NOT NULL, decision_time NOT NULL, decision_note NOT NULL | PASS |
| BR-05 | Rejection reason required when decision = Rejected | booking_decision.rejection_reason | Conditional CHECK: NOT (decision = 'Rejected' AND rejection_reason IS NULL). Noted in logical design; ensure valid SQL syntax. | PASS |
| BR-06 | Check-in records actual start, who checked in, initial condition | booking_session (actual_start_time, checked_in_by, initial_condition) | actual_start_time NOT NULL, checked_in_by NOT NULL. initial_condition is nullable per logical design (allows empty value). | PASS |
| BR-07 | Check-out records actual end time, final condition, usage notes | booking_session (actual_end_time, final_condition, usage_notes) | Columns exist and are nullable (check-out may not have occurred). | PASS |
| BR-08 | Space with open maintenance cannot be booked | maintenance_record.status + space.current_status | Application must check for active maintenance records before allowing a booking. Also space.current_status should reflect this. | DELEGATED_TO_APP |
| BR-09 | Historical records must be preserved | All tables | No ON DELETE CASCADE specified; defaults to NO ACTION. Suitable for preservation. | PASS |
| ASM-01 | Booking follows linear status workflow | booking_request.status | CHECK constraint on allowed values; transition logic delegated to application. | DELEGATED_TO_APP |
| ASM-02 | Space may have multiple facility catalog entries | space_facility | Junction table resolves M:N. | PASS |
| ASM-03 | Only staff/manager can check in/out | booking_session.checked_in_by | FK to user; role enforcement delegated to application. | DELEGATED_TO_APP |
| ASM-04 | Open maintenance updates space status | maintenance_record.status + space.current_status | Application must synchronize statuses. | DELEGATED_TO_APP |
| ASM-05 | At most one decision per booking | booking_decision.PK = booking_id | PK ensures 1:1. | PASS |
| ASM-06 | At most one session per booking | booking_session.PK = booking_id | PK ensures 1:1. | PASS |

---

## Phase 3: Keys & Constraints Evaluation

### 3.1 Primary Keys

| Table | PK Column(s) | Type | Status |
|---|---|---|---|
| user | user_id (INT, IDENTITY) | Surrogate | PASS |
| space | space_code (NVARCHAR(20)) | Natural | PASS |
| facility_catalog | catalog_id (INT, IDENTITY) | Surrogate | PASS |
| space_facility | (space_code, catalog_id) | Composite Natural | PASS |
| facility_asset | asset_id (INT, IDENTITY) | Surrogate | PASS |
| booking_request | booking_id (INT, IDENTITY) | Surrogate | PASS |
| booking_decision | booking_id (INT) | Identifying FK | PASS |
| booking_session | booking_id (INT) | Identifying FK | PASS |
| maintenance_record | maintenance_id (INT, IDENTITY) | Surrogate | PASS |

**Result:** Every table has an explicit PK. **PASS**

### 3.2 Foreign Keys & Referential Integrity

| FK | Source → Target | ON DELETE (default) | Status |
|---|---|---|---|
| booking_request.requester_id → user.user_id | NO ACTION | PASS |
| booking_request.space_code → space.space_code | NO ACTION | PASS |
| booking_decision.booking_id → booking_request.booking_id | NO ACTION | PASS |
| booking_decision.staff_id → user.user_id | NO ACTION | PASS |
| booking_session.booking_id → booking_request.booking_id | NO ACTION | PASS |
| booking_session.checked_in_by → user.user_id | NO ACTION | PASS |
| space_facility.space_code → space.space_code | NO ACTION | PASS |
| space_facility.catalog_id → facility_catalog.catalog_id | NO ACTION | PASS |
| facility_asset.catalog_id → facility_catalog.catalog_id | NO ACTION | PASS |
| facility_asset.space_code → space.space_code | NO ACTION | PASS |
| maintenance_record.space_code → space.space_code | NO ACTION | PASS |
| maintenance_record.reported_by → user.user_id | NO ACTION | PASS |
| maintenance_record.assigned_to → user.user_id | NO ACTION | PASS |

**Result:** All FKs default to NO ACTION, preserving historical data. No CASCADE vulnerability. **PASS**

### 3.3 Unique Constraints

| Table | Column(s) | Status |
|---|---|---|
| user | email | PASS |
| facility_catalog | name | PASS |
| facility_asset | asset_tag | PASS |
| space | (building, floor, room_number) | **GAP: Listed as candidate key but no UNIQUE constraint defined in schema** |

**Result:** 3 of 4 unique constraints present. **MINOR GAP** on space natural key.

### 3.4 NOT NULL / Mandatory Fields

- All columns marked NOT NULL in the logical design are appropriate.
- Nullable columns (phone_number, usage_policy, description, rejection_reason, initial_condition, actual_end_time, final_condition, usage_notes, assigned_to, completion_time, result_note) correctly reflect optional business data.
- booking_decision.rejection_reason is nullable because it's only required when decision = 'Rejected'.

**Result:** **PASS**

### 3.5 Default Values

| Table | Column | Default | Status |
|---|---|---|---|
| user | account_status | 'Active' | PASS |
| space | current_status | 'Available' | PASS |
| facility_catalog | is_trackable | 0 | PASS |
| facility_asset | status | 'Working' | PASS |
| booking_request | status | 'Pending' | PASS |
| booking_request | created_at | GETUTCDATE() | PASS |
| maintenance_record | status | 'Reported' | PASS |

**Result:** All defaults are sensible. **PASS**

### 3.6 CHECK / Domain Constraints

| Table | Column | CHECK | Status |
|---|---|---|---|
| user | role | IN ('Student','Lecturer','TA','Facility Staff','Dept Admin','Facility Manager') | PASS |
| user | account_status | IN ('Active','Inactive','Suspended') | PASS |
| space | space_type | IN ('Auditorium','Classroom','Computer Laboratory','Project Laboratory','Meeting Room','Student Workspace') | PASS |
| space | floor | >= 0 | PASS |
| space | capacity | > 0 | PASS |
| space | current_status | IN ('Available','In Use','Under Maintenance','Temporarily Closed','Retired') | PASS |
| space_facility | quantity | > 0 | PASS |
| facility_asset | status | IN ('Working','Under Repair','Retired') | PASS |
| booking_request | requested_end_time | > requested_start_time | PASS |
| booking_request | purpose | IN ('Lecture','Examination','Seminar','Workshop','Meeting','Student Activity','Administrative Event') | PASS |
| booking_request | expected_participants | > 0 | PASS |
| booking_request | status | IN ('Pending','Approved','Rejected','Cancelled','Checked In','Completed','No-Show') | PASS |
| booking_decision | decision | IN ('Approved','Rejected') | PASS |
| booking_decision | rejection_reason | Conditional CHECK when decision='Rejected' | PASS |
| maintenance_record | problem_type | IN ('Broken Projector','AC Failure','Damaged Furniture','Cleaning Issue','Network Problem') | PASS |
| maintenance_record | status | IN ('Reported','In Progress','Completed') | PASS |

### 3.7 Chronological Logic Gaps

| Constraint | Status |
|---|---|
| booking_request.requested_end_time > requested_start_time | PASS |
| booking_session.actual_end_time > actual_start_time | **GAP: Not enforced** |
| maintenance_record.completion_time > start_time (when set) | **GAP: Not enforced** |

**Result:** 2 minor chronological gaps. These could be enforced via CHECK constraints when both values are non-null.

---

## Summary

| Category | PASS | DELEGATED_TO_APP | GAP |
|---|---|---|---|
| Entity-to-Table Mapping | 9/9 | — | — |
| M:N Resolution | 1/1 | — | — |
| FK Placement | 10/10 | — | — |
| Business Rules | 6/9 | 3/9 | — |
| Primary Keys | 9/9 | — | — |
| Foreign Keys | 13/13 | — | — |
| Unique Constraints | 3/4 | — | 1 |
| NOT NULL | ✓ | — | — |
| Default Values | 7/7 | — | — |
| CHECK Constraints | 15/16 | — | — |
| Chronological Logic | 1/3 | — | 2 |

---

## Recommendations for Remediation

1. **Add UNIQUE constraint on space(building, floor, room_number):** This enforces the natural key and prevents duplicate physical spaces.
2. **Add CHECK for booking_session:** `CHECK (actual_end_time IS NULL OR actual_end_time > actual_start_time)` to ensure chronological consistency during check-out.
3. **Add CHECK for maintenance_record:** `CHECK (completion_time IS NULL OR completion_time > start_time)` to ensure valid completion timestamps.
4. **No additional tables or columns required** — the Catalog vs. Asset Hybrid Pattern is fully and correctly implemented.
