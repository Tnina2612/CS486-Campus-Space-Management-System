# Database Design Validation — G11

## Phase 1: ERD vs. Relational Schema Mapping Evaluation

### Entity-to-Table Mapping

| ERD Entity (Step 2) | Relational Table (Step 3) | Status |
|--------------------|--------------------------|--------|
| USER | USER | **PASS** |
| SPACE | SPACE | **PASS** |
| FACILITY_CATALOG | FACILITY_CATALOG | **PASS** |
| SPACE_FACILITY | SPACE_FACILITY | **PASS** |
| FACILITY_ASSET | FACILITY_ASSET | **PASS** |
| BOOKING | BOOKING | **PASS** |
| APPROVAL | APPROVAL | **PASS** |
| USAGE_SESSION | USAGE_SESSION | **PASS** |
| MAINTENANCE_RECORD | MAINTENANCE_RECORD | **PASS** |

All entities map 1-to-1. No missing or unapproved tables.

### Weak Entities
No weak entities exist in the ERD. **N/A**

### 1:1 Relationships

| Relationship | FK Column | UNIQUE? | NOT NULL? | Placement | Status |
|-------------|-----------|---------|-----------|-----------|--------|
| BOOKING → APPROVAL | APPROVAL.booking_id | YES | YES | Child table (APPROVAL) — correct | **PASS** |
| BOOKING → USAGE_SESSION | USAGE_SESSION.booking_id | YES | YES | Child table (USAGE_SESSION) — correct | **PASS** |

Both 1:1 relationships are correctly enforced via UNIQUE + NOT NULL on the FK in the child table. The split is justified by the Booking Lifecycle Normalization rule.

### 1:N Relationships

| Relationship | FK Column | FK Side | NOT NULL? | Status |
|-------------|-----------|---------|-----------|--------|
| USER → BOOKING | BOOKING.user_id | Many (BOOKING) | YES | **PASS** |
| SPACE → BOOKING | BOOKING.space_code | Many (BOOKING) | YES | **PASS** |
| FACILITY_CATALOG → FACILITY_ASSET | FACILITY_ASSET.catalog_id | Many (FACILITY_ASSET) | YES | **PASS** |
| SPACE → FACILITY_ASSET | FACILITY_ASSET.space_code | Many (FACILITY_ASSET) | YES | **PASS** |
| USER → APPROVAL | APPROVAL.staff_id | Many (APPROVAL) | YES | **PASS** |
| USER → USAGE_SESSION (checked_in_by) | USAGE_SESSION.checked_in_by | Many (USAGE_SESSION) | YES | **PASS** |
| USER → USAGE_SESSION (completed_by) | USAGE_SESSION.completed_by | Many (USAGE_SESSION) | NO (nullable) | **PASS** |
| SPACE → MAINTENANCE_RECORD | MAINTENANCE_RECORD.space_code | Many (MAINTENANCE_RECORD) | YES | **PASS** |
| USER → MAINTENANCE_RECORD (reporter_id) | MAINTENANCE_RECORD.reporter_id | Many (MAINTENANCE_RECORD) | YES | **PASS** |
| USER → MAINTENANCE_RECORD (assigned_staff_id) | MAINTENANCE_RECORD.assigned_staff_id | Many (MAINTENANCE_RECORD) | NO (nullable) | **PASS** |

All FKs correctly placed on the "Many" side. Nullable columns match optional participation.

### Non-FK Attribute Nullability (Lifecycle Columns)

| Table | Column | Step 3 Nullable? | Expected Timing | Status |
|-------|--------|-----------------|-----------------|--------|
| BOOKING | status | NOT NULL (no DEFAULT) | Default should be 'Pending' at creation | **WARNING** — missing DEFAULT 'Pending' |
| APPROVAL | decision | NOT NULL | Set at decision time (row created at decision) | **PASS** |
| APPROVAL | decision_time | NOT NULL | Set at decision time | **PASS** |
| APPROVAL | decision_note | NULL | Optional at decision time | **PASS** |
| APPROVAL | rejection_reason | NULL | Conditional on 'Rejected' decision | **PASS** |
| USAGE_SESSION | checked_in_by | NOT NULL | Recorded at check-in | **PASS** |
| USAGE_SESSION | actual_start | NOT NULL | Recorded at check-in | **PASS** |
| USAGE_SESSION | initial_condition | NOT NULL | Recorded at check-in | **PASS** |
| USAGE_SESSION | actual_end | NULL | Recorded at completion | **PASS** |
| USAGE_SESSION | final_condition | NULL | Recorded at completion | **PASS** |
| USAGE_SESSION | completed_by | NULL | Recorded at completion | **PASS** |
| USAGE_SESSION | usage_notes | NULL | Optional at completion | **PASS** |
| MAINTENANCE_RECORD | completion_time | NULL | Recorded when maintenance completed | **PASS** |
| MAINTENANCE_RECORD | result_note | NULL | Optional at completion | **PASS** |

### M:N Relationships

| Entities | Junction Table | Composite PK | Status |
|----------|---------------|-------------|--------|
| SPACE ↔ FACILITY_CATALOG | SPACE_FACILITY | (space_code, catalog_id) | **PASS** |

### ISA / Subtyping Relationships
None identified. **N/A**

---

## Phase 2: Business Rules Traceability Matrix

| Rule ID | Business Rule Description | Mapped DB Element | Constraint / Technical Logic | Status |
|---------|--------------------------|------------------|------------------------------|--------|
| BR-01 | Unique space code | SPACE.space_code | PK | **PASS** |
| BR-02 | Unique asset tag | FACILITY_ASSET.asset_tag | UNIQUE constraint | **PASS** |
| BR-03 | No overlapping approved bookings for same space | BOOKING | Deferred to application logic (cross-row validation across BOOKING table) | **DELEGATED_TO_APP** |
| BR-04 | Unavailable spaces (under maintenance, closed, retired) cannot be booked | SPACE.current_status + MAINTENANCE_RECORD | Deferred to application logic (needs to check SPACE.current_status and active MAINTENANCE_RECORD rows) | **DELEGATED_TO_APP** |
| BR-05 | Strict 1-to-1 booking lifecycle | APPROVAL.booking_id, USAGE_SESSION.booking_id | UNIQUE constraint on both | **PASS** |
| BR-06 | Rejection requires reason | APPROVAL.rejection_reason | CHECK(decision <> 'Rejected' OR rejection_reason IS NOT NULL) | **PASS** |
| BR-07 | Catalog vs. Asset Hybrid Pattern | FACILITY_CATALOG, SPACE_FACILITY, FACILITY_ASSET | is_trackable BIT, quantity INT, asset_tag UNIQUE, status CHECK | **PASS** |
| BR-08 | Space under maintenance cannot be booked | MAINTENANCE_RECORD.status | Deferred to application logic (check for active maintenance records) | **DELEGATED_TO_APP** |
| BR-09 | Actual end must be after actual start | USAGE_SESSION.actual_end, actual_start | CHECK(actual_end IS NULL OR actual_end > actual_start) | **PASS** |
| BR-10 | Historical preservation of all records | All tables | ON DELETE NO ACTION on all historical tables | **PASS** |
| BR-11 | Booking status lifecycle | BOOKING.status | CHECK constraint with all valid status values | **PASS** |
| BR-12 | End time must be after start time | BOOKING.requested_start, requested_end | CHECK(requested_end > requested_start) | **PASS** |
| BR-13 | Maintenance completion after start | MAINTENANCE_RECORD.start_time, completion_time | CHECK(completion_time IS NULL OR completion_time > start_time) | **PASS** |
| BR-14 | Capacity must be positive | SPACE.capacity | CHECK(capacity > 0) | **PASS** |
| BR-15 | Expected participants must be positive | BOOKING.expected_participants | CHECK(expected_participants > 0) | **PASS** |
| BR-16 | Session completion groups all fields | USAGE_SESSION | CHECK((actual_end IS NULL AND final_condition IS NULL AND completed_by IS NULL) OR (actual_end IS NOT NULL AND final_condition IS NOT NULL AND completed_by IS NOT NULL)) | **PASS** |
| BR-17 | Unique email | USER.email | UNIQUE constraint | **PASS** |

---

## Phase 3: Keys & Constraints Evaluation

### Primary Keys
Every table has an explicit PK. Surrogate keys (INT IDENTITY) are used for FACILITY_CATALOG, FACILITY_ASSET, BOOKING, APPROVAL, USAGE_SESSION, MAINTENANCE_RECORD. Natural keys used for USER (user_id) and SPACE (space_code). SPACE_FACILITY uses a composite natural PK. **PASS**

### Foreign Keys — Deletion/Update Strategy

| FK | ON DELETE | ON UPDATE | Assessment |
|----|-----------|-----------|------------|
| SPACE_FACILITY.space_code → SPACE | CASCADE | CASCADE | Junction table — CASCADE acceptable |
| SPACE_FACILITY.catalog_id → FACILITY_CATALOG | CASCADE | NO ACTION | Junction table — CASCADE acceptable; surrogate key, NO ACTION on update |
| FACILITY_ASSET.catalog_id → FACILITY_CATALOG | NO ACTION | NO ACTION | Historical asset tracking — correct |
| FACILITY_ASSET.space_code → SPACE | NO ACTION | CASCADE | Natural key — CASCADE on update correct |
| BOOKING.user_id → USER | NO ACTION | CASCADE | Historical booking — NO ACTION on delete; natural key CASCADE on update |
| BOOKING.space_code → SPACE | NO ACTION | CASCADE | Historical booking — NO ACTION on delete; natural key CASCADE on update |
| APPROVAL.booking_id → BOOKING | NO ACTION | NO ACTION | Audit table — correct |
| APPROVAL.staff_id → USER | NO ACTION | CASCADE | Natural key CASCADE on update correct |
| USAGE_SESSION.booking_id → BOOKING | NO ACTION | NO ACTION | Audit table — correct |
| USAGE_SESSION.checked_in_by → USER | NO ACTION | CASCADE | Natural key CASCADE on update correct |
| USAGE_SESSION.completed_by → USER | NO ACTION | CASCADE | Natural key CASCADE on update correct |
| MAINTENANCE_RECORD.space_code → SPACE | NO ACTION | CASCADE | Natural key CASCADE on update correct |
| MAINTENANCE_RECORD.reporter_id → USER | NO ACTION | CASCADE | Natural key CASCADE on update correct |
| MAINTENANCE_RECORD.assigned_staff_id → USER | NO ACTION | CASCADE | Nullable FK, natural key CASCADE on update correct |

No CASCADE on delete for any transactional/lifecycle/audit table. **PASS**

### Data Integrity Constraints

**UNIQUE Constraints:** Present on USER.email, FACILITY_ASSET.asset_tag, APPROVAL.booking_id, USAGE_SESSION.booking_id. **PASS**

**NOT NULL:** Applied to all mandatory fields as verified in Phase 1. **PASS**

**DEFAULT:** BOOKING.status lacks DEFAULT 'Pending'. **FAIL**

### Business Logic Constraints

**CHECK — Domain:**
- SPACE.capacity > 0 ✓
- BOOKING.expected_participants > 0 ✓
- SPACE_FACILITY.quantity > 0 ✓

**CHECK — Format/Logic:**
- No CHECK constraint on USER.email to ensure it contains '@'. **WARNING**
- No CHECK constraint on USER.phone format. (Acceptable — phone format varies widely)

**CHECK — Chronological (All Pairs):**

| Table | Column Pair | CHECK Exists? | Status |
|-------|------------|---------------|--------|
| BOOKING | requested_start, requested_end | CHECK(requested_end > requested_start) | **PASS** |
| USAGE_SESSION | actual_start, actual_end | CHECK(actual_end IS NULL OR actual_end > actual_start) | **PASS** |
| MAINTENANCE_RECORD | start_time, completion_time | CHECK(completion_time IS NULL OR completion_time > start_time) | **PASS** |

All chronological pairs validated. **PASS**

### Enum Value Fidelity — Side-by-Side Comparison

| Column | Step 1 Values | Step 3 Schema Values | Match? |
|--------|--------------|---------------------|--------|
| USER.role | Student, Lecturer, TA, Facility Staff, Dept Admin, Facility Manager | 'Student','Lecturer','TA','Facility Staff','Dept Admin','Facility Manager' | **PASS** |
| USER.account_status | Active, Inactive, Suspended | 'Active','Inactive','Suspended' | **PASS** |
| SPACE.space_type | Auditorium, Classroom, Computer Lab, Project Lab, Meeting Room, Student Workspace | 'Auditorium','Classroom','Computer Lab','Project Lab','Meeting Room','Student Workspace' | **PASS** |
| SPACE.current_status | Available, In Use, Under Maintenance, Temporarily Closed, Retired | 'Available','In Use','Under Maintenance','Temporarily Closed','Retired' | **PASS** |
| BOOKING.purpose | Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Admin Event | 'Lecture','Examination','Seminar','Workshop','Meeting','Student Activity','Admin Event' | **PASS** |
| BOOKING.status | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-show | 'Pending','Approved','Rejected','Cancelled','Checked In','Completed','No-show' | **PASS** |
| APPROVAL.decision | Approved, Rejected | 'Approved','Rejected' | **PASS** |
| FACILITY_ASSET.status | Working, Under Repair, Retired | 'Working','Under Repair','Retired' | **PASS** |
| MAINTENANCE_RECORD.problem_type | Broken Projector, AC Failure, Damaged Furniture, Cleaning, Network Problem | 'Broken Projector','AC Failure','Damaged Furniture','Cleaning','Network Problem' | **PASS** |
| MAINTENANCE_RECORD.status | Reported, In Progress, Completed, Cancelled | 'Reported','In Progress','Completed','Cancelled' | **PASS** |

All enum values match Step 1 exactly. **PASS**

---

## Executive Validation Summary

| Category | PASS | DELEGATED_TO_APP | FAIL/GAP |
|----------|------|-----------------|----------|
| Entity Mapping | 9 | 0 | 0 |
| Weak Entities | N/A | N/A | N/A |
| Relationships (1:1) | 2 | 0 | 0 |
| Relationships (1:N) | 10 | 0 | 0 |
| Relationships (M:N) | 1 | 0 | 0 |
| Relationships (ISA) | N/A | N/A | N/A |
| Business Rules | 12 | 3 | 0 |
| Primary Keys | 9 | 0 | 0 |
| Foreign Keys | 14 | 0 | 0 |
| Unique Constraints | 3 | 0 | 0 |
| CHECK Constraints | 10 | 0 | 1 (DEFAULT) |
| Chronological Logic | 3 | 0 | 0 |

**Totals:** 73 PASS, 3 DELEGATED_TO_APP, 1 FAIL/GAP

---

## Recommendations for Remediation

| Failed Phase | Entity/Table/Element | Detected Issue | Exact SQL / Markdown Fix Needed |
|-------------|---------------------|---------------|--------------------------------|
| Phase 3 — Default Constraints | BOOKING.status | Missing DEFAULT 'Pending' on BOOKING.status — new bookings should default to 'Pending' | Add `DEFAULT 'Pending'` to the BOOKING.status column definition |
| Phase 3 — Format Validation | USER.email | No CHECK constraint ensuring email contains '@' | Add `CHECK(email LIKE '%@%.%')` (or equivalent SQL Server pattern) — or accept as WARNING since format varies |
