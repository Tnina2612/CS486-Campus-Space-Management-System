# EVALUATION.md
# Campus Space Management System — Agent Output Evaluation Checklist

**Purpose:** After all 7 steps are complete, use this file to review every output against the original business requirement. Mark each item, record issues found, and use the findings to improve AGENT.md / SKILL.md before the next run.

**How to use:**
1. Run the open-ended gap analysis in Section 0 first — this catches issues the checklist may not cover
2. Then go through each step's checklist (Sections 1–7): mark ✅ / ❌ / ⚠️ Partial and write specific issues in Notes
3. Fill in the Run Summary Table at the bottom
4. Do NOT edit output files during evaluation — record findings only

---

## Section 0 — Open-Ended Gap Analysis (Run Before Any Checklist)

### 0A. Requirement vs. Output Gap Scan

| Requirement sentence (paraphrased) | Covered? | Step | File | Issue |
|---|---|---|---|---|
| "shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events" | ⚠️ | 01 | 01-business-req-analysis-G11.md | "Research activities" and "academic events" mentioned in intro but no explicit booking_type values for these |
| "spaces include auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces" | ✅ | 01,05 | All | SPACE.space_type CHECK covers all six |
| "Each user must have a university account" | ✅ | 01 | 01-business-req-analysis-G11.md | BR-01, USER entity with PK + NOT NULL |
| "stores user ID, full name, email, phone number, role, department, and account status" | ✅ | 01,03,05 | All | All 7 attributes present in USER table |
| "A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager" | ✅ | 01,03,05 | All | All 6 roles present with exact snake_case names in CHECK |
| "unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy" | ✅ | 01,03,05 | All | All 9 attributes present in SPACE table |
| "A space may be available, in use, under maintenance, temporarily closed, or retired" | ✅ | 01,03,05 | All | All 5 status values present in CHECK |
| "Each space may have several facilities, such as a projector, whiteboard, microphone, computer, livestreaming equipment, or air conditioner" | ✅ | 01,03,05 | All | FACILITY_CATALOG + SPACE_FACILITY pattern covers this |
| "The system should store the list of facilities available in each space" | ✅ | 03,05 | 03-logical-design-G11.md | SPACE_FACILITY junction table |
| "selecting a space, requested start time, requested end time, purpose of use, and expected number of participants" | ✅ | 01,03,05 | All | All attributes in BOOKING entity/table |
| "A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event" | ✅ | 01,03,05 | All | booking_type CHECK contains all 7 including 'administrative_event' |
| "Each booking request has a status, such as pending, approved, rejected, cancelled, checked in, completed, or no-show" | ✅ | 01,03,05 | All | status CHECK contains all 7 values |
| "The system must prevent conflicting bookings" | ⚠️ | 03,04 | 03-logical-design-G11.md | Delegated to application layer; no DB exclusion mechanism |
| "The same space cannot have two approved bookings with overlapping time periods" | ⚠️ | 03,04 | 03-logical-design-G11.md | Delegated to application layer |
| "A space that is under maintenance, closed, or retired cannot be booked" | ⚠️ | 03,04 | 03-logical-design-G11.md | CHECK on status values; cross-table validation delegated to app |
| "A booking request may require approval from a facility staff member or manager" | ✅ | 01,03,05 | All | APPROVAL entity with FK to USER |
| "records the staff member who made the decision, the decision time, and a decision note" | ✅ | 01,03,05 | All | APPROVAL.staff_id, .decision_time, .decision_note |
| "If the booking is rejected, the rejection reason should be stored" | ✅ | 03,05 | 03-logical-design-G11.md | CHECK enforces (decision='rejected' => rejection_reason IS NOT NULL) |
| "facility staff can check in the booking" + actual start, person, initial condition | ✅ | 01,03,05 | All | USAGE_SESSION entity |
| "facility staff can complete the booking" + actual end, final condition, usage notes | ✅ | 01,03,05 | All | USAGE_SESSION with nullable check-out columns |
| "maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems" | ⚠️ | 01 | 01-business-req-analysis-G11.md | problem_type includes 'other' which is recorded as assumption A-09 |
| "related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note" | ✅ | 01,03,05 | All | All 8 attributes present in MAINTENANCE |
| "A space under maintenance cannot be booked" (repeated) | ⚠️ | 03,04 | 03-logical-design-G11.md | Same as above; delegated to app layer |
| "keep historical records of bookings and maintenance activities" | ✅ | 03,05 | 03-logical-design-G11.md | FK actions use NO ACTION / SET NULL |
| "Staff should be able to view booking history" | ✅ | 07 | 07-query-design-G11.sql | Query 1 returns booking history for a space |
| "Staff should be able to view upcoming bookings" | ✅ | 07 | 07-query-design-G11.sql | Query 2 returns upcoming approved bookings |
| "Staff should be able to view spaces under maintenance" | ✅ | 07 | 07-query-design-G11.sql | Query 5 returns active maintenance records |
| "Staff should be able to view no-show bookings" | ✅ | 07 | 07-query-design-G11.sql | Query 4 returns no-show bookings |

### 0B. Logic Consistency Scan

| Step | File | Location | Inconsistency found | Severity |
|---|---|---|---|---|
| 07 | 07-query-design-G11.sql | Query 3 CTE, line 102 | References `b.actual_end_time` but BOOKING table has no such column — column is in USAGE_SESSION. Query would fail at runtime. | ❌ |
| 07 | 07-query-design-G11.sql | Query 3 outer SELECT | Labels `total_available_hours` as 720 (24h x 30 days) but spaces are only bookable during operational hours (not 24/7). No usage policy assumption stated. | ⚠️ |
| 06 | 06-sample-data-G11.sql | SPACE inserts | No space has `current_status = 'in_use'` — missing from sample data | ❌ |

### 0C. Invented Content Scan

| Step | File | Invented element | Recorded as assumption? | Issue |
|---|---|---|---|---|
| 01 | 01-business-req-analysis-G11.md | FACILITY_CATALOG / SPACE_FACILITY / FACILITY_ASSET hybrid with `is_trackable` | ✅ | A-05: explicitly documented |
| 01 | 01-business-req-analysis-G11.md | USER.account_status values ('active','inactive','suspended') | ✅ | A-06: explicitly documented |
| 01 | 01-business-req-analysis-G11.md | MAINTENANCE.status values ('reported','in_progress','completed','cancelled') | ✅ | A-07: explicitly documented |
| 01 | 01-business-req-analysis-G11.md | FACILITY_ASSET.status values ('working','damaged','under_repair','retired') | ✅ | A-08: explicitly documented |
| 01 | 01-business-req-analysis-G11.md | MAINTENANCE.problem_type 'other' | ✅ | A-09: explicitly documented |
| 01 | 01-business-req-analysis-G11.md | APPROVAL.decision column | ✅ | A-10: explicitly documented |

All invented elements from the first run are now recorded as explicit assumptions.

---

## Step 01 — Business Requirement Analysis

### 1A. Requirement Traceability — Actors

| Requirement says | Present in output? |
|---|---|
| "A user may be a **student**" | ✅ |
| "A user may be a **lecturer**" | ✅ |
| "A user may be a **teaching assistant**" | ✅ — Full name 'teaching_assistant' used |
| "A user may be a **facility staff**" | ✅ — Full name 'facility_staff' used |
| "A user may be a **department administrator**" | ✅ — Full name 'department_administrator' used |
| "A user may be a **facility manager**" | ✅ |

### 1B. Requirement Traceability — User Attributes

| Requirement says | Present in output? |
|---|---|
| "user ID" | ✅ (user_id) |
| "full name" | ✅ (full_name) |
| "email" | ✅ |
| "phone number" | ✅ (phone_number) |
| "role" | ✅ |
| "department" | ✅ |
| "account status" | ✅ (account_status) |

### 1C. Requirement Traceability — Space Attributes

| Requirement says | Present in output? |
|---|---|
| "unique space code" | ✅ (space_code) |
| "space name" | ✅ (space_name) |
| "space type" | ✅ (space_type) |
| "building" | ✅ |
| "floor" | ✅ |
| "room number" | ✅ (room_number) |
| "capacity" | ✅ |
| "current status" | ✅ (current_status) |
| "usage policy" | ✅ (usage_policy) |

### 1D. Requirement Traceability — Space Status Values

| Requirement says | Present in output? |
|---|---|
| "available" | ✅ |
| "in use" | ✅ (in_use) |
| "under maintenance" | ✅ (under_maintenance) |
| "temporarily closed" | ✅ (temporarily_closed) |
| "retired" | ✅ |

### 1E. Requirement Traceability — Booking Attributes

| Requirement says | Present in output? |
|---|---|
| "selecting a space" (space reference) | ✅ (space_code FK) |
| "requested start time" | ✅ (requested_start_time) |
| "requested end time" | ✅ (requested_end_time) |
| "purpose of use" | ✅ (purpose) |
| "expected number of participants" | ✅ (expected_participants) |

### 1F. Requirement Traceability — Booking Status Values

| Requirement says | Present in output? |
|---|---|
| "pending" | ✅ |
| "approved" | ✅ |
| "rejected" | ✅ |
| "cancelled" | ✅ |
| "checked in" | ✅ (checked_in) |
| "completed" | ✅ |
| "no-show" | ✅ (no_show) |

### 1G. Requirement Traceability — Booking Purpose Values

| Requirement says | Present in output? |
|---|---|
| "lecture" | ✅ |
| "examination" | ✅ |
| "seminar" | ✅ |
| "workshop" | ✅ |
| "meeting" | ✅ |
| "student activity" | ✅ (student_activity) |
| "administrative event" | ✅ (administrative_event) |

### 1H. Requirement Traceability — Approval Attributes

| Requirement says | Present in output? |
|---|---|
| "staff member who made the decision" | ✅ (staff_id FK) |
| "decision time" | ✅ (decision_time) |
| "decision note" | ✅ (decision_note) |
| "rejection reason" (when rejected) | ✅ (rejection_reason with CHECK) |

### 1I. Requirement Traceability — Usage Session Attributes

| Requirement says | Present in output? |
|---|---|
| "actual start time" (check-in) | ✅ (actual_start_time) |
| "person who checked in the booking" | ✅ (checked_in_by FK) |
| "initial condition of the space" | ✅ (initial_condition, nullable) |
| "actual end time" (check-out) | ✅ (actual_end_time, nullable) |
| "final condition of the space" | ✅ (final_condition, nullable) |
| "usage notes" | ✅ (usage_notes, nullable) |

### 1J. Requirement Traceability — Maintenance Record Attributes

| Requirement says | Present in output? |
|---|---|
| "related space" | ✅ (space_code FK) |
| "reporter" | ✅ (reporter_id FK) |
| "assigned staff member" | ✅ (assigned_staff_id FK, nullable) |
| "problem description" | ✅ (problem_description) |
| "start time" | ✅ (start_time) |
| "completion time" | ✅ (completion_time, nullable) |
| "status" | ✅ (status) |
| "result note" | ✅ (result_note, nullable) |

### 1K. Requirement Traceability — Business Rules

| Requirement says | Present in output? |
|---|---|
| "The same space cannot have two approved bookings with overlapping time periods" | ⚠️ — BR-02; delegated to application layer |
| "A space that is under maintenance ... cannot be booked" | ⚠️ — BR-03; delegated to application layer |
| "A space that is ... closed ... cannot be booked" | ⚠️ — Same as BR-03 |
| "A space that is ... retired cannot be booked" | ⚠️ — Same as BR-03 |
| "the system records the staff member who made the decision, the decision time, and a decision note" | ✅ — APPROVAL entity |
| "If the booking is rejected, the rejection reason should be stored" | ✅ — CHECK constraint enforces |
| "facility staff can check in the booking" + actual start, person, initial condition | ✅ — USAGE_SESSION entity |
| "facility staff can complete the booking" + actual end, final condition, usage notes | ✅ — USAGE_SESSION entity |
| "A space under maintenance cannot be booked" (repeated) | ⚠️ — BR-08/BR-03; delegated to app layer |
| "keep historical records of bookings and maintenance activities" | ✅ — BR-09; FK NO ACTION / SET NULL |

### 1L. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| L1 | No entity, attribute, or relationship invented beyond requirement; additions recorded as assumptions | ✅ | 6 invented elements all recorded as assumptions (A-05 through A-10) |
| L2 | Assumptions section exists | ✅ | Section 6 lists 10 assumptions covering all design decisions |
| L3 | Unresolved questions section exists | ✅ | Section 7 lists 7 genuine open questions |
| L4 | Relationships identified with correct cardinality | ✅ | All 12 relationships identified with correct 1:1, 1:N, M:N cardinalities |

---

## Step 02 — ERD Design

### 2A. Entity Coverage

| Entity from Step 01 | Present in ERD? |
|---|---|
| USER | ✅ |
| SPACE | ✅ |
| FACILITY_CATALOG | ✅ |
| SPACE_FACILITY | ✅ |
| BOOKING | ✅ |
| APPROVAL | ✅ |
| USAGE_SESSION | ✅ |
| MAINTENANCE | ✅ (named MAINTENANCE in all outputs, not MAINTENANCE_RECORD) |

### 2B. Relationship Coverage

| Relationship | Present in ERD? |
|---|---|
| USER submits BOOKING | ✅ (USER }o--|| BOOKING : makes) |
| SPACE is referenced by BOOKING | ✅ (SPACE }o--|| BOOKING : hosts) |
| BOOKING has APPROVAL | ✅ (BOOKING |o--|| APPROVAL : is_decided_by) |
| BOOKING has USAGE_SESSION | ✅ (BOOKING |o--|| USAGE_SESSION : has_session) |
| USER (staff) decides APPROVAL | ✅ (USER }o--|| APPROVAL : decides) |
| USER (staff) checks in USAGE_SESSION | ✅ (USER }o--|| USAGE_SESSION : checks_in) |
| SPACE contains facilities (via junction) | ✅ (SPACE }o--|| SPACE_FACILITY : contains) |
| USER reports MAINTENANCE | ✅ (USER }o--|| MAINTENANCE : reports) |
| USER assigned to MAINTENANCE | ✅ (USER }o--o| MAINTENANCE : assigned_to) |
| SPACE undergoes MAINTENANCE | ✅ (SPACE }o--|| MAINTENANCE : undergoes) |

### 2C. Participation Constraints Consistency

| Relationship | Min (A side) matches Notes? | Min (B side) matches Notes? | Notes |
|---|---|---|---|
| USER → BOOKING | ✅ | ✅ | USER(0,N) optional; BOOKING(1,1) mandatory |
| SPACE → BOOKING | ✅ | ✅ | SPACE(0,N) optional; BOOKING(1,1) mandatory |
| BOOKING → APPROVAL | ✅ | ✅ | BOOKING(0,1) optional; APPROVAL(1,1) mandatory |
| BOOKING → USAGE_SESSION | ✅ | ✅ | BOOKING(0,1) optional; USAGE_SESSION(1,1) mandatory |
| USER → APPROVAL (decides) | ✅ | ✅ | USER(0,N) optional; APPROVAL(1,1) mandatory |
| USER → USAGE_SESSION (checks in) | ✅ | ✅ | USER(0,N) optional; USAGE_SESSION(1,1) mandatory |
| SPACE → SPACE_FACILITY | ✅ | ✅ | SPACE(0,N) optional; SF(1,1) mandatory |
| FACILITY_CATALOG → SPACE_FACILITY | ✅ | ✅ | FC(0,N) optional; SF(1,1) mandatory |
| FACILITY_CATALOG → FACILITY_ASSET | ✅ | ✅ | FC(0,N) optional; FA(1,1) mandatory |
| SPACE → FACILITY_ASSET | ✅ | ✅ | SPACE(0,N) optional; FA(1,1) mandatory |
| USER → MAINTENANCE (reports) | ✅ | ✅ | USER(0,N) optional; MAINT(1,1) mandatory |
| USER → MAINTENANCE (assigned) | ✅ | ✅ | USER(0,N) optional; MAINT(0,1) optional |
| SPACE → MAINTENANCE | ✅ | ✅ | SPACE(0,N) optional; MAINT(1,1) mandatory |

### 2D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | Mermaid erDiagram syntax is valid | ✅ | All braces closed; all relationship lines syntactically correct; no inline comments |
| D2 | N-M relationships shown as junction entities | ✅ | SPACE ↔ FACILITY_CATALOG resolved via SPACE_FACILITY junction |
| D3 | 1:1 relationships distinctly represented | ✅ | BOOKING→APPROVAL (|o--||) and BOOKING→USAGE_SESSION (|o--||) correctly use optional-one on BOOKING side |
| D4 | No entity beyond Step 01 | ✅ | All 9 entities trace to Step 01 |

---

## Step 03 — Logical Design

### 3A. Table Coverage

| Entity | Table exists? | PK defined? |
|---|---|---|
| USER | ✅ | ✅ (user_id) |
| SPACE | ✅ | ✅ (space_code) |
| FACILITY_CATALOG | ✅ | ✅ (catalog_id) |
| SPACE_FACILITY | ✅ | ✅ (composite: space_code, catalog_id) |
| FACILITY_ASSET | ✅ | ✅ (asset_id, IDENTITY) |
| BOOKING | ✅ | ✅ (booking_id, IDENTITY) |
| APPROVAL | ✅ | ✅ (approval_id, IDENTITY) |
| USAGE_SESSION | ✅ | ✅ (session_id, IDENTITY) |
| MAINTENANCE | ✅ | ✅ (maintenance_id, IDENTITY) |

### 3B. Attribute Coverage

| Entity | All Step 01 attributes present in table? | Missing attributes (if any) |
|---|---|---|
| USER | ✅ | None |
| SPACE | ✅ | None |
| BOOKING | ✅ | None |
| APPROVAL | ✅ | None |
| USAGE_SESSION | ✅ | None |
| MAINTENANCE | ✅ | None |

### 3C. Foreign Key Coverage

| Relationship | Implemented as | Correct direction? |
|---|---|---|
| USER submits BOOKING | FK user_id in BOOKING → USER(user_id) | ✅ |
| SPACE referenced by BOOKING | FK space_code in BOOKING → SPACE(space_code) | ✅ |
| BOOKING has APPROVAL | FK booking_id in APPROVAL + UNIQUE | ✅ |
| BOOKING has USAGE_SESSION | FK booking_id in USAGE_SESSION + UNIQUE | ✅ |
| USER decides APPROVAL | FK staff_id in APPROVAL → USER(user_id) | ✅ |
| USER checks in USAGE_SESSION | FK checked_in_by in USAGE_SESSION → USER(user_id) | ✅ |
| SPACE–FACILITY_CATALOG (N-M) | Junction table SPACE_FACILITY with composite PK | ✅ |
| USER reports MAINTENANCE | FK reporter_id in MAINTENANCE → USER(user_id) | ✅ |
| USER assigned MAINTENANCE | FK assigned_staff_id in MAINTENANCE → USER(user_id) (nullable) | ✅ |
| SPACE undergoes MAINTENANCE | FK space_code in MAINTENANCE → SPACE(space_code) | ✅ |

### 3D. Constraint Coverage

| Business Rule | Mechanism in schema | Present? |
|---|---|---|
| No overlapping approved bookings | Application logic (multi-row time overlap check) | ⚠️ — Delegated to application layer |
| Space status blocks booking | Application logic (cross-table validation) | ⚠️ — Delegated to application layer |
| Rejection reason required when rejected | CHECK((decision='rejected' AND rejection_reason IS NOT NULL) OR (decision='approved')) | ✅ |
| Booking end time > start time | CHECK(requested_end_time > requested_start_time) | ✅ |
| Capacity > 0 | CHECK(capacity > 0) | ✅ |
| Expected participants > 0 | CHECK(expected_participants > 0) | ✅ |
| User email unique | UNIQUE constraint on USER.email | ✅ |
| 1:1 BOOKING→APPROVAL | UNIQUE on APPROVAL.booking_id | ✅ |
| 1:1 BOOKING→USAGE_SESSION | UNIQUE on USAGE_SESSION.booking_id | ✅ |

### 3E. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| E1 | No information from Step 02 lost | ✅ | Every attribute appears in some table |
| E2 | No unnecessary redundancy | ✅ | Non-FK attributes appear only once |
| E3 | Candidate keys identified | ✅ | USER.email, SPACE(building,floor,room_number), FACILITY_CATALOG.name, FACILITY_ASSET.asset_tag |
| E4 | NULL/NOT NULL assigned correctly | ✅ | Optional participation → nullable (actual_end_time, assigned_staff_id, etc.) |
| E5 | No table/column invented beyond Step 02 | ✅ | All tables trace to Step 01/02 |

---

## Step 04 — Design Validation

### 4A. ERD-to-Schema Completeness

| Check | Status | Notes |
|---|---|---|
| Every entity in ERD has a table in schema | ✅ | All 9 entities mapped 1:1 |
| Every relationship in ERD is represented in schema | ✅ | All 13 relationships implemented via FK/junction |
| Every attribute in ERD appears in schema | ✅ | All attributes present |

### 4B. Business Rule Enforcement Audit

| Business Rule | Enforcement acknowledged in Step 04? | Mechanism stated? |
|---|---|---|
| No overlapping approved bookings for same space | ✅ (DELEGATED_TO_APP) | Application logic |
| Space under maintenance cannot be booked | ✅ (DELEGATED_TO_APP) | Cross-table validation at booking time |
| Space temporarily closed cannot be booked | ✅ (DELEGATED_TO_APP) | Cross-table validation at booking time |
| Space retired cannot be booked | ✅ (DELEGATED_TO_APP) | Cross-table validation at booking time |
| Rejection reason stored when rejected | ✅ (PASS) | CHECK constraint on APPROVAL |
| Approval records decider + decision time + note | ✅ (PASS) | NOT NULL columns in APPROVAL |
| Check-in records actual start + person + initial condition | ✅ (PASS) | NOT NULL columns in USAGE_SESSION |
| Check-out records actual end + final condition + usage notes | ✅ (PASS) | Nullable columns in USAGE_SESSION |
| Historical records preserved | ✅ (PASS) | FK NO ACTION / SET NULL |

### 4C. Status Value Audit

| Column | Required values (from requirement) | Schema values match? |
|---|---|---|
| BOOKING.status | pending, approved, rejected, cancelled, checked_in, completed, no_show | ✅ — Exact match |
| SPACE.current_status | available, in_use, under_maintenance, temporarily_closed, retired | ✅ — Exact match |
| BOOKING.booking_type | lecture, examination, seminar, workshop, meeting, student_activity, administrative_event | ✅ — 'administrative_event' used (not 'administrative') |
| MAINTENANCE.status | (not specified — assumption A-07) | ✅ — Values match assumption |
| USER.role | student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager | ✅ — 'department_administrator' used (not 'admin') |
| MAINTENANCE.problem_type | broken_projector, ac_failure, damaged_furniture, cleaning, network | ⚠️ — 'other' present per assumption A-09 |
| FACILITY_ASSET.status | (not specified — assumption A-08) | ✅ — Values match assumption |
| USER.account_status | (not specified — assumption A-06) | ✅ — Values match assumption |

### 4D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | Participation constraints reflected as nullable/NOT NULL | ✅ | Explicitly checked in Phase 1 (23 lifecycle columns evaluated) |
| D2 | Flags any table/column with no origin in ERD | ✅ | None flagged — all traceable |
| D3 | Does not introduce new design elements | ✅ | Only evaluates existing elements |

---

## Step 05 — Database Implementation (DDL)

### 5A. Table Creation Coverage

| Table | CREATE TABLE present? | PK declared? |
|---|---|---|
| USER | ✅ | ✅ |
| SPACE | ✅ | ✅ |
| FACILITY_CATALOG | ✅ | ✅ |
| SPACE_FACILITY | ✅ | ✅ |
| FACILITY_ASSET | ✅ | ✅ |
| BOOKING | ✅ | ✅ |
| APPROVAL | ✅ | ✅ |
| USAGE_SESSION | ✅ | ✅ |
| MAINTENANCE | ✅ | ✅ |

### 5B. Constraint Coverage

| Constraint | Present in DDL? |
|---|---|
| UNIQUE on USER.email | ✅ |
| CHECK on SPACE.capacity > 0 | ✅ |
| CHECK on BOOKING.requested_end_time > requested_start_time | ✅ |
| CHECK on BOOKING.expected_participants > 0 | ✅ |
| CHECK on BOOKING.status IN (all 7 values from requirement) | ✅ |
| CHECK on SPACE.current_status IN (all 5 values from requirement) | ✅ |
| CHECK on BOOKING.booking_type IN (all 7 values from requirement) | ✅ |
| CHECK on USER.role IN (all 6 values from requirement) | ✅ |
| UNIQUE on APPROVAL.booking_id | ✅ |
| UNIQUE on USAGE_SESSION.booking_id | ✅ |
| DEFAULT 'pending' on BOOKING.status | ✅ (lowercase) |
| DEFAULT 'available' on SPACE.current_status | ✅ |

### 5C. Table Creation Order

| Dependency | Correct order in DDL? |
|---|---|
| USER created before BOOKING | ✅ |
| SPACE created before BOOKING | ✅ |
| BOOKING created before APPROVAL | ✅ |
| BOOKING created before USAGE_SESSION | ✅ |
| USER created before APPROVAL | ✅ |
| USER created before USAGE_SESSION | ✅ |
| SPACE created before MAINTENANCE | ✅ |
| USER created before MAINTENANCE | ✅ |
| FACILITY_CATALOG created before SPACE_FACILITY | ✅ |
| SPACE created before SPACE_FACILITY | ✅ |

### 5D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | All SQL statements end with semicolons | ✅ | All CREATE TABLE and ALTER statements terminated with `;` |
| D2 | No column references undefined table/column | ✅ | All FK references valid |
| D3 | Composite PKs use table-level syntax | ✅ | `CONSTRAINT pk_space_facility PRIMARY KEY (space_code, catalog_id)` |
| D4 | ON DELETE / ON UPDATE behavior specified for all FKs | ✅ | Every FK has explicit ON UPDATE and ON DELETE (CASCADE, NO ACTION, or SET NULL) |

---

## Step 06 — Sample Data

### 6A. Status Value Coverage

| Value | At least one row? |
|---|---|
| BOOKING.status = 'pending' | ✅ (Bookings 2, 13, 14) |
| BOOKING.status = 'approved' | ✅ (Booking 11) |
| BOOKING.status = 'rejected' | ✅ (Bookings 3, 4, 5, 6) |
| BOOKING.status = 'cancelled' | ✅ (Booking 9) |
| BOOKING.status = 'checked_in' | ✅ (Booking 12) |
| BOOKING.status = 'completed' | ✅ (Bookings 1, 7, 8) |
| BOOKING.status = 'no_show' | ✅ (Booking 10) |
| SPACE.current_status = 'available' | ✅ (AUD-101, CL-201, LAB-B101, WS-001) |
| SPACE.current_status = 'in_use' | ❌ — No space has status 'in_use' |
| SPACE.current_status = 'under_maintenance' | ✅ (LAB-B102) |
| SPACE.current_status = 'temporarily_closed' | ✅ (MT-301) |
| SPACE.current_status = 'retired' | ✅ (CL-202) |

### 6B. Role Coverage

| USER.role | At least one user? |
|---|---|
| Student | ✅ (U001, U007, U009, U010) |
| Lecturer | ✅ (U002, U008) |
| Teaching Assistant | ✅ (U003) |
| Facility Staff | ✅ (U004) |
| Department Administrator | ✅ (U005) |
| Facility Manager | ✅ (U006) |

### 6C. Exception Case Coverage

| Exception case | Present in sample data? |
|---|---|
| A rejected booking with rejection_reason filled | ✅ (Bookings 3, 4, 5, 6 with approval records) |
| A space under maintenance with a linked maintenance record | ✅ (LAB-B102 under_maintenance + Maintenance #1 in_progress) |
| A no-show booking | ✅ (Booking 10 with USAGE_SESSION record) |
| A completed booking with actual times + conditions recorded in USAGE_SESSION | ✅ (Bookings 1, 7, 8) |
| A booking for a retired space does NOT exist (constraint test) | ⚠️ — Booking 6 exists for CL-202 (retired) but was rejected; no approved/active booking exists for a retired space |

### 6D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | All tables have at least some inserted rows | ✅ | Every table has data |
| D2 | INSERT order respects FK dependencies | ✅ | USER → SPACE → FACILITY_CATALOG → SPACE_FACILITY + FACILITY_ASSET → BOOKING → APPROVAL + USAGE_SESSION → MAINTENANCE |
| D3 | No inserted row violates any constraint | ✅ | All values are valid against DDL CHECK, UNIQUE, FK constraints |

---

## Step 07 — Query Design

### 7A. Requirement Coverage

| Requirement says | Covered by a query? |
|---|---|
| "view booking history" | ✅ — Query 1 returns full booking history for a specific space |
| "view upcoming bookings" | ✅ — Query 2 returns upcoming approved bookings in next 7 days |
| "view spaces under maintenance" | ✅ — Query 5 returns active maintenance with space details |
| "view no-show bookings" | ✅ — Query 4 returns no-show bookings with requester and session info |

### 7B. Query Completeness

| Query # | Business question? | Target user? | Explanation? | SQL statement? |
|---|---|---|---|---|
| 1 | ✅ | ✅ | ✅ | ✅ |
| 2 | ✅ | ✅ | ✅ | ✅ |
| 3 | ✅ | ✅ | ✅ | ✅ |
| 4 | ✅ | ✅ | ✅ | ✅ |
| 5 | ✅ | ✅ | ✅ | ✅ |

### 7C. Query Diversity

| Requirement | Present? |
|---|---|
| At least 5 queries total | ✅ (5 queries) |
| At least one query uses multi-table JOIN | ✅ (all 5 use multiple JOINs: INNER JOIN, LEFT JOIN) |
| At least one query uses GROUP BY with aggregate | ✅ (Q3 uses SUM + GROUP BY) |
| At least one query uses WHERE with a meaningful filter | ✅ (all 5 have WHERE with specific conditions) |
| No query uses SELECT * as final output | ✅ |

### 7D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | All SQL is written for Microsoft SQL Server (T-SQL) | ✅ | Uses DATETIME2, SYSDATETIME(), DATEADD, DATEDIFF, CTE, CASE |
| D2 | All queries would return meaningful results against Step 06 data | ❌ | Query 3 references `b.actual_end_time` but BOOKING has no such column — column exists in USAGE_SESSION; query would fail with invalid column error |
| D3 | Column names in queries match DDL defined in Step 05 | ❌ | Q3 references `b.actual_end_time` which is not a column in BOOKING; the column `actual_end_time` is in USAGE_SESSION |

---

## Run Summary Table

| Run | Date | Total ❌ | Total ⚠️ | Key issues found | Changes made before next run |
|-----|------|---------|---------|-----------------|------------------------------|
| 1 | 2026-06-30 | 4 | 5 | Run 1 issues: Step 01 role/purpose abbreviations; Step 02 missing USER→USAGE_SESSION relationship; Step 03 inconsistent CHECK values; Step 04 FK CASCADE vulnerabilities; Step 06 missing 'checked_in', 'in_use', 'retired' statuses; Step 07 no booking history/no-show queries; Query 1 utilization formula bug | Fixed all named issues in Run 2 |
| 2 | 2026-06-30 | 2 | 2 | **New issues in Run 2:** Step 06: missing SPACE `current_status='in_use'` in sample data. Step 07 Query 3: references `b.actual_end_time` which is not a column in BOOKING (column exists in USAGE_SESSION). Q3 also assumes 720h/month but spaces have operational hours. | Add a space with `current_status='in_use'` to sample data; fix Query 3 to JOIN USAGE_SESSION and reference its `actual_end_time` column; document operational hours assumption in Step 01 |
| 3 | | | | | |

**Goal:** Total ❌ and ⚠️ counts decrease across runs. The "Changes made" column is the evidence of improvement for the Group Report.
