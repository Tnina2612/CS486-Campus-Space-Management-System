# 04 — Database Design Validation

## Phase 1: ERD vs. Relational Schema Mapping Evaluation

### Entity-to-Table Mapping

| ERD Entity | Relational Table | Status | Notes |
|------------|-----------------|--------|-------|
| USER | USER | PASS | Direct 1:1 mapping |
| SPACE | SPACE | PASS | Direct 1:1 mapping |
| FACILITY_CATALOG | FACILITY_CATALOG | PASS | Direct 1:1 mapping |
| SPACE_FACILITY | SPACE_FACILITY | PASS | Associative entity resolved as junction table |
| FACILITY_ASSET | FACILITY_ASSET | PASS | Direct 1:1 mapping |
| BOOKING | BOOKING | PASS | Direct 1:1 mapping |
| APPROVAL | APPROVAL | PASS | Direct 1:1 mapping |
| USAGE_SESSION | USAGE_SESSION | PASS | Direct 1:1 mapping |
| MAINTENANCE_RECORD | MAINTENANCE_RECORD | PASS | Direct 1:1 mapping |

### Weak Entities

No weak entities identified in the ERD. **N/A**

### 1:1 Relationships

| Relationship | FK Table | FK Column | UNIQUE | NOT NULL | FK Placement | Status |
|-------------|----------|-----------|--------|----------|-------------|--------|
| BOOKING → APPROVAL | APPROVAL | booking_id | YES | YES | On APPROVAL (mandatory side) | PASS |
| BOOKING → USAGE_SESSION | USAGE_SESSION | booking_id | YES | YES | On USAGE_SESSION (mandatory side) | PASS |

### 1:N Relationships

| Relationship | Many-Side Table | FK Column | NOT NULL | Status |
|-------------|-----------------|-----------|----------|--------|
| USER → BOOKING | BOOKING | requester_id | YES | PASS |
| SPACE → BOOKING | BOOKING | space_code | YES | PASS |
| SPACE → SPACE_FACILITY | SPACE_FACILITY | space_code | YES | PASS |
| FACILITY_CATALOG → SPACE_FACILITY | SPACE_FACILITY | catalog_id | YES | PASS |
| FACILITY_CATALOG → FACILITY_ASSET | FACILITY_ASSET | catalog_id | YES | PASS |
| SPACE → FACILITY_ASSET | FACILITY_ASSET | space_code | YES | PASS |
| USER → APPROVAL | APPROVAL | reviewer_id | YES | PASS |
| USER → USAGE_SESSION (check-in) | USAGE_SESSION | checked_in_by | YES | PASS |
| USER → USAGE_SESSION (check-out) | USAGE_SESSION | checked_out_by | NO (null) | PASS |
| SPACE → MAINTENANCE_RECORD | MAINTENANCE_RECORD | space_code | YES | PASS |
| USER → MAINTENANCE_RECORD (reporter) | MAINTENANCE_RECORD | reporter_id | YES | PASS |
| USER → MAINTENANCE_RECORD (assigned) | MAINTENANCE_RECORD | assigned_staff_id | NO (null) | PASS |

### M:N Relationships

| Relationship | Junction Table | Composite PK | Status |
|-------------|---------------|-------------|--------|
| SPACE ⟷ FACILITY_CATALOG | SPACE_FACILITY | (space_code, catalog_id) | PASS |

### ISA / Subtyping

No ISA/subtyping relationships identified. **N/A**

---

## Phase 2: Business Rules Traceability Matrix

| Rule ID | Business Rule Description | Mapped DB Element | Constraint / Technical Logic | Status |
|---------|--------------------------|-------------------|------------------------------|--------|
| BR1 | No overlapping approved bookings | BOOKING | Application-level or trigger (filtered index on space_code + time range WHERE status = 'approved') | DELEGATED_TO_APP |
| BR2 | Unavailable spaces cannot be booked | SPACE + BOOKING | Application-level check of SPACE.current_status | DELEGATED_TO_APP |
| BR3 | Booking status lifecycle | BOOKING.status | CHECK(status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')) + app | PASS |
| BR4 | 1-to-1 booking ↔ approval | APPROVAL.booking_id | UNIQUE constraint | PASS |
| BR5 | 1-to-1 booking ↔ usage session | USAGE_SESSION.booking_id | UNIQUE constraint | PASS |
| BR6 | Trackable vs non-trackable | FACILITY_CATALOG.is_trackable | Application logic routing to SPACE_FACILITY or FACILITY_ASSET | DELEGATED_TO_APP |
| BR7 | Unique asset tag | FACILITY_ASSET.asset_tag | UNIQUE constraint | PASS |
| BR8 | Maintenance blocks booking | MAINTENANCE_RECORD | Application-level check for active maintenance on space | DELEGATED_TO_APP |
| BR9 | Unique email per user | USER.email | UNIQUE constraint | PASS |
| BR10 | Capacity check | BOOKING.expected_participants + SPACE.capacity | Application-level validation | DELEGATED_TO_APP |
| BR11 | Time validity (start < end) | BOOKING | CHECK(requested_start < requested_end) | PASS |
| BR12 | History preservation (no physical deletion) | ALL tables | ON DELETE NO ACTION on all FKs | PASS |

---

## Phase 3: Keys & Constraints Evaluation

### Primary Keys

| Table | PK Column(s) | Type | Status |
|-------|-------------|------|--------|
| USER | user_id | Surrogate (IDENTITY) | PASS |
| SPACE | space_code | Natural (NVARCHAR) | PASS |
| FACILITY_CATALOG | catalog_id | Surrogate (IDENTITY) | PASS |
| SPACE_FACILITY | (space_code, catalog_id) | Composite Natural | PASS |
| FACILITY_ASSET | asset_id | Surrogate (IDENTITY) | PASS |
| BOOKING | booking_id | Surrogate (IDENTITY) | PASS |
| APPROVAL | approval_id | Surrogate (IDENTITY) | PASS |
| USAGE_SESSION | session_id | Surrogate (IDENTITY) | PASS |
| MAINTENANCE_RECORD | maintenance_id | Surrogate (IDENTITY) | PASS |

### Foreign Keys & Deletion Strategy

| FK | From → To | ON UPDATE | ON DELETE | Status |
|----|-----------|-----------|-----------|--------|
| SPACE_FACILITY.space_code → SPACE.space_code | CASCADE | NO ACTION | PASS |
| SPACE_FACILITY.catalog_id → FACILITY_CATALOG.catalog_id | NO ACTION | NO ACTION | PASS |
| FACILITY_ASSET.catalog_id → FACILITY_CATALOG.catalog_id | NO ACTION | NO ACTION | PASS |
| FACILITY_ASSET.space_code → SPACE.space_code | CASCADE | NO ACTION | PASS |
| BOOKING.requester_id → USER.user_id | NO ACTION | NO ACTION | PASS |
| BOOKING.space_code → SPACE.space_code | CASCADE | NO ACTION | PASS |
| APPROVAL.booking_id → BOOKING.booking_id | NO ACTION | NO ACTION | PASS |
| APPROVAL.reviewer_id → USER.user_id | NO ACTION | NO ACTION | PASS |
| USAGE_SESSION.booking_id → BOOKING.booking_id | NO ACTION | NO ACTION | PASS |
| USAGE_SESSION.checked_in_by → USER.user_id | NO ACTION | NO ACTION | PASS |
| USAGE_SESSION.checked_out_by → USER.user_id | NO ACTION | NO ACTION | PASS |
| MAINTENANCE_RECORD.space_code → SPACE.space_code | CASCADE | NO ACTION | PASS |
| MAINTENANCE_RECORD.reporter_id → USER.user_id | NO ACTION | NO ACTION | PASS |
| MAINTENANCE_RECORD.assigned_staff_id → USER.user_id | NO ACTION | NO ACTION | PASS |

**Vulnerability Check:** ON UPDATE CASCADE for space_code is justified (natural key). ON DELETE NO ACTION everywhere correctly protects historical records. No vulnerabilities found. **PASS**

### Unique Constraints

| Table | Column(s) | Status | Notes |
|-------|-----------|--------|-------|
| USER | email | PASS | Business rule BR9 |
| FACILITY_CATALOG | facility_name | PASS | Prevents duplicate catalog entries |
| FACILITY_ASSET | asset_tag | PASS | Business rule BR7 |
| APPROVAL | booking_id | PASS | Enforces 1:1 with BOOKING |
| USAGE_SESSION | booking_id | PASS | Enforces 1:1 with BOOKING |

### CHECK Constraints — Domain

| Table | Column | CHECK | Status |
|-------|--------|-------|--------|
| USER | role | IN ('student','lecturer','teaching_assistant','facility_staff','department_administrator','facility_manager') | PASS |
| USER | account_status | IN ('active','inactive','suspended') | PASS |
| SPACE | space_type | IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','workspace') | PASS |
| SPACE | capacity | > 0 | PASS |
| SPACE | current_status | IN ('available','in_use','under_maintenance','temporarily_closed','retired') | PASS |
| SPACE_FACILITY | quantity | > 0 | PASS |
| FACILITY_ASSET | status | IN ('available','in_use','under_maintenance','retired') | PASS |
| BOOKING | purpose | IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event') | PASS |
| BOOKING | expected_participants | > 0 | PASS |
| BOOKING | status | IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show') | PASS |
| APPROVAL | — | No domain CHECK needed | PASS |
| USAGE_SESSION | — | No domain CHECK needed | PASS |
| MAINTENANCE_RECORD | problem_category | IN ('broken_projector','ac_failure','damaged_furniture','cleaning','network','other') | PASS |
| MAINTENANCE_RECORD | status | IN ('reported','in_progress','completed','cancelled') | PASS |

### CHECK Constraints — Format / Logic

| Table | Column | Issue | Status |
|-------|--------|-------|--------|
| USER | email | No CHECK for email format (e.g., contains '@') | WARNING |

### CHECK Constraints — Chronological Logic

| Table | Date Pair | CHECK Present | Status |
|-------|-----------|---------------|--------|
| BOOKING | requested_start < requested_end | YES (CK_booking_time_range) | PASS |
| USAGE_SESSION | actual_end_time >= actual_start_time | YES (CK_session_time_range) | PASS |
| MAINTENANCE_RECORD | completion_time >= start_time | YES (CK_maint_time_range) | PASS |

### NOT NULL Constraints

All mandatory columns from Step 1 and Step 2 correctly enforce NOT NULL. Optional columns (phone, checked_out_by, actual_end_time, final_condition, usage_notes, assigned_staff_id, completion_time, result_note, etc.) correctly allow NULL. **PASS**

### DEFAULT Constraints

| Table | Column | Default | Status |
|-------|--------|---------|--------|
| USER | account_status | 'active' | PASS |
| SPACE | current_status | 'available' | PASS |
| FACILITY_CATALOG | is_trackable | 0 | PASS |
| FACILITY_ASSET | status | 'available' | PASS |
| BOOKING | status | 'pending' | PASS |
| BOOKING | created_at | GETDATE() | PASS |
| APPROVAL | decision_time | GETDATE() | PASS |
| MAINTENANCE_RECORD | status | 'reported' | PASS |

---

## Executive Validation Summary

| Category | PASS | DELEGATED_TO_APP | FAIL/GAP |
|----------|------|------------------|----------|
| Entity Mapping | 9 / 9 | — | 0 |
| Weak Entities | N/A | — | N/A |
| 1:1 Relationships | 2 / 2 | — | 0 |
| 1:N Relationships | 12 / 12 | — | 0 |
| M:N Relationships | 1 / 1 | — | 0 |
| ISA / Subtyping | N/A | — | N/A |
| Business Rules | 7 / 12 | 5 (BR1, BR2, BR6, BR8, BR10) | 0 |
| Primary Keys | 9 / 9 | — | 0 |
| Foreign Keys | 14 / 14 | — | 0 |
| Unique Constraints | 5 / 5 | — | 0 |
| CHECK Constraints (Domain) | 13 / 13 | — | 0 |
| CHECK Constraints (Format) | 0 / 1 (WARNING) | — | 1 WARNING |
| Chronological Logic | 3 / 3 | — | 0 |

---

## Recommendations for Remediation

| Failed Phase | Entity/Table/Element | Detected Issue | Exact SQL / Markdown Fix Needed |
|-------------|---------------------|----------------|---------------------------------|
| Phase 3 — Format | USER.email | No email format validation | Consider adding: `CONSTRAINT CK_USER_EMAIL_FORMAT CHECK (email LIKE '%_@__%.__%')` (application-level recommended for complex validation) |
