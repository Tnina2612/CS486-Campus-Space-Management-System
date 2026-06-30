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

Read `req/business-requirement.md` sentence by sentence. For each sentence that states a fact, rule, attribute, or constraint, check whether it is fully and correctly reflected somewhere in the outputs. Record any sentence that is missing, partially covered, or incorrectly represented.

| Requirement sentence (paraphrased) | Covered? | Step (01-07) | File | Issue (if any) |
|---|---|---|---|---|
| "Each user must have a university account" | ✅ | 01 | 01-business-req-analysis-G11.md | Covered in §2 Actors: "All actors have a university account." |
| "stores user ID, full name, email, phone number, role, department, account status" | ✅ | 01 | 01-business-req-analysis-G11.md | All 7 attributes listed in USER entity (user_id, full_name, email, phone, role, department, account_status) |
| "A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager" | ✅ | 01 | 01-business-req-analysis-G11.md | All 6 roles listed in USER entity; enumerated in CHECK constraint later |
| "unique space code, space name, space type, building, floor, room number, capacity, current status, usage policy" | ✅ | 01 | 01-business-req-analysis-G11.md | All 9 attributes listed in SPACE entity |
| "A space may be available, in use, under maintenance, temporarily closed, or retired" | ✅ | 01 | 01-business-req-analysis-G11.md | All 5 status values enumerated in SPACE entity |
| "Each space may have several facilities, such as a projector, whiteboard, microphone, computer, livestreaming equipment, or air conditioner" | ✅ | 01 | 01-business-req-analysis-G11.md | Stored as FACILITY_CATALOG catalog entries; examples all present in sample data |
| "The system should store the list of facilities available in each space" | ✅ | 01 | 01-business-req-analysis-G11.md | Via SPACE_FACILITY junction and FACILITY_ASSET tables |
| "Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, expected number of participants" | ✅ | 01 | 01-business-req-analysis-G11.md | All 5 elements present as BOOKING attributes (space_code, requested_start, requested_end, purpose, expected_participants) plus requester_id |
| "A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event" | ✅ | 01 | 01-business-req-analysis-G11.md | All 7 purpose values listed in BOOKING entity |
| "Each booking request has a status, such as pending, approved, rejected, cancelled, checked in, completed, or no-show" | ✅ | 01 | 01-business-req-analysis-G11.md | All 7 status values listed (uses underscore convention: checked_in, no_show) |
| "The system must prevent conflicting bookings" | ✅ | 01 | 01-business-req-analysis-G11.md | BR1 — delegated to application-level or trigger |
| "The same space cannot have two approved bookings with overlapping time periods" | ✅ | 01 | 01-business-req-analysis-G11.md | BR1 — explicitly stated |
| "A space that is under maintenance, closed, or retired cannot be booked" | ✅ | 01 | 01-business-req-analysis-G11.md | BR2 — explicitly stated |
| "A booking request may require approval from a facility staff member or manager" | ✅ | 01 | 01-business-req-analysis-G11.md | APPROVAL entity with reviewer_id | 
| "records the staff member who made the decision, the decision time, and a decision note" | ✅ | 01 | 01-business-req-analysis-G11.md | APPROVAL: reviewer_id, decision_time, decision_note |
| "If the booking is rejected, the rejection reason should be stored" | ✅ | 01 | 01-business-req-analysis-G11.md | APPROVAL.rejection_reason (NULL if approved) |
| "facility staff can check in the booking — records actual start time, person who checked in, initial condition" | ✅ | 01 | 01-business-req-analysis-G11.md | USAGE_SESSION: actual_start_time, checked_in_by, initial_condition |
| "facility staff can complete the booking — records actual end time, final condition, usage notes" | ✅ | 01 | 01-business-req-analysis-G11.md | USAGE_SESSION: actual_end_time, final_condition, usage_notes (+ checked_out_by) |
| "basic maintenance management — problems such as broken projectors, AC failure, damaged furniture, cleaning, network" | ✅ | 01 | 01-business-req-analysis-G11.md | MAINTENANCE_RECORD with problem_category |
| "maintenance record stores related space, reporter, assigned staff, problem description, start time, completion time, status, result note" | ✅ | 01 | 01-business-req-analysis-G11.md | All attributes present in MAINTENANCE_RECORD |
| "A space under maintenance cannot be booked" | ✅ | 01 | 01-business-req-analysis-G11.md | BR8 — explicitly stated (duplicate of earlier rule) |
| "keep historical records of bookings and maintenance activities" | ✅ | 01 | 01-business-req-analysis-G11.md | BR12 — ON DELETE NO ACTION on all FKs |
| "Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings" | ✅ | 07 | 07-query-design-G11.sql | Q2 (history), Q1 (upcoming), Q3 (maintenance), Q4 (no-show) |

**Result:** All requirement sentences with system-facing constraints/attributes are fully covered in the outputs.

---

### 0B. Logic Consistency Scan

Read each output file and identify any internal inconsistencies — places where two parts of the same output contradict each other.

| Step (01-07) | File | Location (section/table/row) | Inconsistency found | Severity (❌ / ⚠️) |
|---|---|---|---|---|
| 02 | 02-erd-design-G11.md | §2 FACILITY_ASSET attributes | FACILITY_ASSET does not list catalog_id or space_code as attributes; these appear as attributes in Step 01 and Step 03 but in the ERD they are represented as relationships (FACILITY_CATALOG ⟶ FACILITY_ASSET, SPACE ⟶ FACILITY_ASSET). This is standard conceptual ERD practice — FKs are shown via relationships, not attributes. Self-review confirms "No foreign keys listed as attributes." | ⚠️ (Noted; intentional design choice, not an error) |
| 03 | 03-logical-design-G11.md | §1 APPOVAL table | APPOVAL.rejection_reason has no CHECK constraint to enforce non-NULL when booking status = 'rejected'. Step 03 note acknowledges "enforced at application level." This is a gap between stated business rule (rejection_reason required when rejected) and schema enforcement. | ⚠️ |
| 05 | 05-db-definition-G11.sql | §4 Trigger trg_space_facility_trackable_check | The trigger enforces a rule (trackable facility quantity ≤ asset count) that is not stated in the business requirement and not recorded in the assumptions. The trigger direction is SPACE_FACILITY → FACILITY_ASSET, but the business logic should arguably be the reverse. | ⚠️ |

**Result:** No hard contradictions found. All flagged items are minor design-preference issues.

---

### 0C. Invented Content Scan

Identify anything in the outputs that was not stated in the requirement and was not recorded as an explicit assumption.

| Step (01-07) | File | Invented element | Recorded as assumption? | Issue |
|---|---|---|---|---|
| 05 | 05-db-definition-G11.sql | Trigger `trg_space_facility_trackable_check` on SPACE_FACILITY | ❌ Not in assumptions | Enforces a business rule not derived from the requirement. No assumption recorded about this trigger or its logic. |
| 01 | 01-business-req-analysis-G11.md | FACILITY_CATALOG.is_trackable + trackable/non-trackable split | ⚠️ Partial (BR6 states the rule, assumptions mention "predefined categories") | Design pattern is clearly described but not explicitly called out as an invention beyond the requirement. |
| 01 | 01-business-req-analysis-G11.md | BOOKING.created_at attribute | ❌ Not recorded as assumption | `created_at` is useful but not mentioned in the requirement. A minor addition. |
| 01 | 01-business-req-analysis-G11.md | SPACE.space_type enumeration (auditorium, classroom, computer_lab, project_lab, meeting_room, workspace) | ❌ Not recorded as a separate assumption | Values are derived from the requirement text "auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces" but are not enumerated in the requirement itself. |

**Summary of Section 0:**
- **0A:** All requirement sentences covered. No gaps found. ✅
- **0B:** No hard logic inconsistencies. 3 minor notes (⚠️) about conceptual ERD conventions, application-level enforcement, and trigger direction. No ❌.
- **0C:** One clear invented element (trigger) not recorded as assumption (❌). Three partially recorded items (⚠️).

---

## Step 01 — Business Requirement Analysis

### 1A. Requirement Traceability — Actors

| Requirement says | Present in output? |
|---|---|
| "A user may be a **student**" | ✅ |
| "A user may be a **lecturer**" | ✅ |
| "A user may be a **teaching assistant**" | ✅ |
| "A user may be a **facility staff**" | ✅ |
| "A user may be a **department administrator**" | ✅ |
| "A user may be a **facility manager**" | ✅ |

### 1B. Requirement Traceability — User Attributes

| Requirement says | Present in output? |
|---|---|
| "user ID" | ✅ (user_id) |
| "full name" | ✅ (full_name) |
| "email" | ✅ (email) |
| "phone number" | ✅ (phone) |
| "role" | ✅ (role) |
| "department" | ✅ (department) |
| "account status" | ✅ (account_status) |

### 1C. Requirement Traceability — Space Attributes

| Requirement says | Present in output? |
|---|---|
| "unique space code" | ✅ (space_code, PK) |
| "space name" | ✅ (space_name) |
| "space type" | ✅ (space_type) |
| "building" | ✅ (building) |
| "floor" | ✅ (floor) |
| "room number" | ✅ (room_number) |
| "capacity" | ✅ (capacity) |
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
| "requested start time" | ✅ (requested_start) |
| "requested end time" | ✅ (requested_end) |
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
| "staff member who made the decision" | ✅ (reviewer_id FK) |
| "decision time" | ✅ (decision_time) |
| "decision note" | ✅ (decision_note) |
| "rejection reason" (when rejected) | ✅ (rejection_reason) |

### 1I. Requirement Traceability — Usage Session Attributes

| Requirement says | Present in output? |
|---|---|
| "actual start time" (check-in) | ✅ (actual_start_time) |
| "person who checked in the booking" | ✅ (checked_in_by FK) |
| "initial condition of the space" | ✅ (initial_condition) |
| "actual end time" (check-out) | ✅ (actual_end_time) |
| "final condition of the space" | ✅ (final_condition) |
| "usage notes" | ✅ (usage_notes) |

### 1J. Requirement Traceability — Maintenance Record Attributes

| Requirement says | Present in output? |
|---|---|
| "related space" | ✅ (space_code FK) |
| "reporter" | ✅ (reporter_id FK) |
| "assigned staff member" | ✅ (assigned_staff_id FK) |
| "problem description" | ✅ (problem_description) |
| "start time" | ✅ (start_time) |
| "completion time" | ✅ (completion_time) |
| "status" | ✅ (status) |
| "result note" | ✅ (result_note) |

### 1K. Requirement Traceability — Business Rules

| Requirement says | Present in output? |
|---|---|
| "The same space cannot have two approved bookings with overlapping time periods" | ✅ BR1 |
| "A space that is under maintenance ... cannot be booked" | ✅ BR2 |
| "A space that is ... closed ... cannot be booked" | ✅ BR2 |
| "A space that is ... retired cannot be booked" | ✅ BR2 |
| "the system records the staff member who made the decision, the decision time, and a decision note" | ✅ Approval entity |
| "If the booking is rejected, the rejection reason should be stored" | ✅ APPROVAL.rejection_reason |
| "facility staff can check in the booking + records actual start + person + initial condition" | ✅ USAGE_SESSION entity |
| "facility staff can complete the booking + records actual end + final condition + usage notes" | ✅ USAGE_SESSION entity |
| "A space under maintenance cannot be booked" (duplicate) | ✅ BR8 |
| "keep historical records of bookings and maintenance activities" | ✅ BR12 + ON DELETE NO ACTION |

### 1L. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| L1 | No entity, attribute, or relationship is invented beyond what the requirement states. Any addition is recorded as an explicit assumption. | ⚠️ | `created_at` on BOOKING not mentioned in requirement and not recorded as assumption. Trigger in Step 05 not recorded. |
| L2 | Assumptions section exists and lists all design decisions not directly stated in the requirement. | ✅ | §6 lists 9 assumptions covering DBMS choice, actors, status values, facility catalog, etc. |
| L3 | Unresolved questions section exists and raises genuine open questions about the requirement. | ✅ | §7 lists 5 open questions (grace period, notifications, recurring booking, advance window, waitlist). |
| L4 | Relationships between all entity pairs are identified with correct cardinality (1-1, 1-N, N-M). | ✅ | §4 lists 14 relationships with cardinalities. All are correct. |

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
| MAINTENANCE_RECORD | ✅ |

*FACILITY_ASSET from Step 01 also present* — not listed in the checklist template but exists in the ERD.

### 2B. Relationship Coverage

| Relationship | Present in ERD? |
|---|---|
| USER submits BOOKING | ✅ `USER ||--o{ BOOKING : submits` |
| SPACE is referenced by BOOKING | ✅ `SPACE ||--o{ BOOKING : hosts` |
| BOOKING has APPROVAL | ✅ `BOOKING |o--|| APPROVAL : has` |
| BOOKING has USAGE_SESSION | ✅ `BOOKING |o--|| USAGE_SESSION : records` |
| USER (staff) decides APPROVAL | ✅ `USER ||--o{ APPROVAL : reviews` |
| USER (staff) checks in USAGE_SESSION | ✅ `USER ||--o{ USAGE_SESSION : checks_in` |
| SPACE contains facilities (via junction) | ✅ `SPACE ||--o{ SPACE_FACILITY : contains` |
| USER reports MAINTENANCE_RECORD | ✅ `USER ||--o{ MAINTENANCE_RECORD : reports` |
| USER assigned to MAINTENANCE_RECORD | ✅ `USER |o--o{ MAINTENANCE_RECORD : assigned_to` |
| SPACE undergoes MAINTENANCE_RECORD | ✅ `SPACE ||--o{ MAINTENANCE_RECORD : undergoes` |

*Additional relationships*: FACILITY_CATALOG ⟷ SPACE_FACILITY, FACILITY_CATALOG ⟶ FACILITY_ASSET, SPACE ⟶ FACILITY_ASSET, USER ⟶ USAGE_SESSION (check-out). All present. ✅

### 2C. Participation Constraints Consistency

For every row in the participation constraints table: if Notes says "may have zero / may not have any", then Min must be 0. If Notes says "must have / always has", then Min must be 1.

| Relationship | Min (A side) matches Notes? | Min (B side) matches Notes? | Notes |
|---|---|---|---|
| USER → BOOKING | ✅ Min=1 "must have exactly one requester" | ✅ Min=0 "may have zero or many bookings" | |
| SPACE → BOOKING | ✅ Min=1 "must reference exactly one space" | ✅ Min=0 "may have zero or many bookings" | |
| BOOKING → APPROVAL | ✅ Min=0 "may have zero or one approval" | ✅ Min=1 "belongs to exactly one booking" | |
| BOOKING → USAGE_SESSION | ✅ Min=0 "may have zero or one usage session" | ✅ Min=1 "belongs to exactly one booking" | |
| USER → APPROVAL (decides) | ✅ Min=1 "must have exactly one reviewer" | ✅ Min=0 "may review zero or many" | |
| USER → USAGE_SESSION (checks in) | ✅ Min=1 "must have exactly one check-in staff" | ✅ Min=0 "may check in zero or many" | |
| SPACE → SPACE_FACILITY | ✅ Min=1 "belongs to exactly one space" | ✅ Min=0 "may have zero or many" | |
| FACILITY_CATALOG → SPACE_FACILITY | ✅ Min=1 "references exactly one catalog" | ✅ Min=0 "may appear in zero or many" | |
| FACILITY_CATALOG → FACILITY_ASSET | ✅ Min=1 "belongs to exactly one catalog type" | ✅ Min=0 "may have zero or many" | |
| SPACE → FACILITY_ASSET | ✅ Min=1 "located in exactly one space" | ✅ Min=0 "may contain zero or many" | |
| USER → MAINTENANCE_RECORD (reports) | ✅ Min=1 "must have one reporter" | ✅ Min=0 "may report zero or many" | |
| USER → MAINTENANCE_RECORD (assigned) | ⚠️ Min=0 "may have zero or one assigned staff" (Mermaid shows `USER |o--o{`) | ✅ Min=0 "may be assigned zero or many" | Mermaid `|o` on USER side means "zero or one" — correct for nullable assigned_staff_id |
| SPACE → MAINTENANCE_RECORD | ✅ Min=1 "references exactly one space" | ✅ Min=0 "may have zero or many" | |

### 2D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | Mermaid erDiagram syntax is valid — no missing closing braces, all FK attributes marked correctly | ✅ | Syntax is valid. No FK attributes shown (conceptual ERD convention). |
| D2 | N-M relationships are shown as junction entities, not as direct many-to-many lines with no resolution | ✅ | SPACE ⟷ FACILITY_CATALOG resolved via SPACE_FACILITY junction entity |
| D3 | 1:1 relationships (BOOKING→APPROVAL, BOOKING→USAGE_SESSION) are represented distinctly from 1:N | ✅ | `|o--||` notation used for 1:1 with optional side clearly marked |
| D4 | No entity, relationship, or attribute appears in the ERD that was not in Step 01 | ✅ | All elements traceable to Step 01 |

---

## Step 03 — Logical Design

### 3A. Table Coverage

| Entity | Table exists? | PK defined? |
|---|---|---|
| USER | ✅ | ✅ user_id (IDENTITY) |
| SPACE | ✅ | ✅ space_code (natural key) |
| FACILITY_CATALOG | ✅ | ✅ catalog_id (IDENTITY) |
| SPACE_FACILITY | ✅ | ✅ composite (space_code, catalog_id) |
| FACILITY_ASSET | ✅ | ✅ asset_id (IDENTITY) |
| BOOKING | ✅ | ✅ booking_id (IDENTITY) |
| APPROVAL | ✅ | ✅ approval_id (IDENTITY), UNIQUE(booking_id) |
| USAGE_SESSION | ✅ | ✅ session_id (IDENTITY), UNIQUE(booking_id) |
| MAINTENANCE_RECORD | ✅ | ✅ maintenance_id (IDENTITY) |

### 3B. Attribute Coverage

| Entity | All Step 01 attributes present in table? | Missing attributes (if any) |
|---|---|---|
| USER | ✅ | None |
| SPACE | ✅ | None |
| BOOKING | ✅ | None |
| APPROVAL | ✅ | None |
| USAGE_SESSION | ✅ | None |
| MAINTENANCE_RECORD | ✅ | None |

### 3C. Foreign Key Coverage

| Relationship | Implemented as | Correct direction? |
|---|---|---|
| USER submits BOOKING | FK requester_id in BOOKING → USER | ✅ |
| SPACE referenced by BOOKING | FK space_code in BOOKING → SPACE | ✅ |
| BOOKING has APPROVAL | FK booking_id in APPROVAL + UNIQUE | ✅ |
| BOOKING has USAGE_SESSION | FK booking_id in USAGE_SESSION + UNIQUE | ✅ |
| USER decides APPROVAL | FK reviewer_id in APPROVAL → USER | ✅ |
| USER checks in USAGE_SESSION | FK checked_in_by in USAGE_SESSION → USER | ✅ |
| SPACE–FACILITY_CATALOG (N-M) | Junction table SPACE_FACILITY | ✅ |
| USER reports MAINTENANCE_RECORD | FK reporter_id in MAINTENANCE_RECORD → USER | ✅ |
| USER assigned MAINTENANCE_RECORD | FK assigned_staff_id in MAINTENANCE_RECORD → USER (nullable) | ✅ |
| SPACE undergoes MAINTENANCE_RECORD | FK space_code in MAINTENANCE_RECORD → SPACE | ✅ |

### 3D. Constraint Coverage

| Business Rule | Mechanism in schema | Present? |
|---|---|---|
| No overlapping approved bookings | Application-level or trigger (noted) | ✅ (Delegated) |
| Space status blocks booking | Application-level note (noted) | ✅ (Delegated) |
| Rejection reason required when rejected | Application-level note (noted) | ⚠️ No CHECK enforcement; acknowledged |
| Booking end time > start time | CHECK (requested_start < requested_end) | ✅ |
| Capacity > 0 | CHECK (capacity > 0) on SPACE | ✅ |
| Expected participants > 0 | CHECK (expected_participants > 0) | ✅ |
| User email unique | UNIQUE constraint on USER.email | ✅ |
| 1:1 BOOKING→APPROVAL | UNIQUE on APPROVAL.booking_id | ✅ |
| 1:1 BOOKING→USAGE_SESSION | UNIQUE on USAGE_SESSION.booking_id | ✅ |

### 3E. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| E1 | No information from Step 02 is lost — every attribute appears in some table | ✅ | All ERD attributes fully mapped to logical schema columns |
| E2 | No unnecessary redundancy — same non-FK attribute does not appear in two tables | ✅ | No redundant attributes |
| E3 | Candidate keys are identified where they exist | ✅ | USER.email, SPACE.space_code, FACILITY_CATALOG.facility_name, FACILITY_ASSET.asset_tag |
| E4 | NULL / NOT NULL is assigned correctly | ✅ | Mandatory participation → NOT NULL; optional → nullable (checked_out_by, assigned_staff_id, etc.) |
| E5 | No table or column is invented beyond Step 02 without being recorded as an assumption | ✅ | All tables traceable to Step 02 entities |

---

## Step 04 — Design Validation

### 4A. ERD-to-Schema Completeness

| Check | Status | Notes |
|---|---|---|
| Every entity in ERD has a table in schema | ✅ | 9/9 entities mapped (USER, SPACE, FACILITY_CATALOG, SPACE_FACILITY, FACILITY_ASSET, BOOKING, APPROVAL, USAGE_SESSION, MAINTENANCE_RECORD) |
| Every relationship in ERD is represented in schema (FK or junction table) | ✅ | All 14 relationships implemented |
| Every attribute in ERD appears in schema | ✅ | All conceptual attributes mapped with correct data types |

### 4B. Business Rule Enforcement Audit

| Business Rule | Enforcement acknowledged in Step 04? | Mechanism stated? |
|---|---|---|
| No overlapping approved bookings for same space | ✅ | DELEGATED_TO_APP — application-level or trigger |
| Space under maintenance cannot be booked | ✅ | DELEGATED_TO_APP |
| Space temporarily closed cannot be booked | ✅ | DELEGATED_TO_APP (part of BR2) |
| Space retired cannot be booked | ✅ | DELEGATED_TO_APP (part of BR2) |
| Rejection reason stored when rejected | ✅ | Noted: "conditionally required — enforced at application level" |
| Approval records decider + decision time + note | ✅ | PASS — schema enforces via FK + NOT NULL + UNIQUE |
| Check-in records actual start + person + initial condition | ✅ | PASS — NOT NULL on all three columns |
| Check-out records actual end + final condition + usage notes | ✅ | PASS — nullable columns for optional recording |
| Historical records preserved | ✅ | PASS — ON DELETE NO ACTION on all FKs |

### 4C. Status Value Audit

| Column | Required values (from requirement) | Schema values match? |
|---|---|---|
| BOOKING.status | pending, approved, rejected, cancelled, checked_in, completed, no_show | ✅ Values match (underscore convention applied) |
| SPACE.current_status | available, in_use, under_maintenance, temporally_closed, retired | ✅ Values match (underscore convention applied) |
| BOOKING.purpose | lecture, examination, seminar, workshop, meeting, student_activity, administrative_event | ✅ Values match |
| MAINTENANCE_RECORD.status | Not specified in requirement — defined in Step 01 as: reported, in_progress, completed, cancelled | ✅ Assumption recorded in Step 01 §6 |
| USER.role | student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager | ✅ Values match |

### 4D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | Validation explicitly confirms participation constraints are correctly reflected as nullable/NOT NULL | ✅ | Every NOT NULL / nullable mapping confirmed in §1:N and 1:1 tables |
| D2 | Validation flags any table or column with no origin in ERD | ✅ | No orphan tables or columns found |
| D3 | Validation does not introduce new design elements | ✅ | Only evaluates existing design; remediation recommendations are non-binding suggestions |

---

## Step 05 — Database Implementation (DDL)

### 5A. Table Creation Coverage

| Table | CREATE TABLE present? | PK declared? |
|---|---|---|
| USER | ✅ | ✅ PK_USER (user_id) |
| SPACE | ✅ | ✅ PK_SPACE (space_code) |
| FACILITY_CATALOG | ✅ | ✅ PK_FACILITY_CATALOG (catalog_id) |
| SPACE_FACILITY | ✅ | ✅ PK_SPACE_FACILITY (space_code, catalog_id) composite |
| FACILITY_ASSET | ✅ | ✅ PK_FACILITY_ASSET (asset_id) |
| BOOKING | ✅ | ✅ PK_BOOKING (booking_id) |
| APPROVAL | ✅ | ✅ PK_APPROVAL (approval_id), UQ_APPROVAL_BOOKING |
| USAGE_SESSION | ✅ | ✅ PK_USAGE_SESSION (session_id), UQ_USAGE_SESSION_BOOKING |
| MAINTENANCE_RECORD | ✅ | ✅ PK_MAINTENANCE_RECORD (maintenance_id) |

### 5B. Constraint Coverage

| Constraint | Present in DDL? |
|---|---|
| UNIQUE on USER.email | ✅ UQ_USER_EMAIL |
| CHECK on SPACE.capacity > 0 | ✅ CK_SPACE_CAPACITY |
| CHECK on BOOKING.requested_end_time > requested_start_time | ✅ CK_BOOKING_TIME_RANGE |
| CHECK on BOOKING.expected_participants > 0 | ✅ CK_BOOKING_PARTICIPANTS |
| CHECK on BOOKING.status IN (all 7 values) | ✅ CK_BOOKING_STATUS |
| CHECK on SPACE.current_status IN (all 5 values) | ✅ CK_SPACE_STATUS |
| CHECK on BOOKING.purpose IN (all 7 values) | ✅ CK_BOOKING_PURPOSE |
| CHECK on USER.role IN (all 6 values) | ✅ CK_USER_ROLE |
| UNIQUE on APPROVAL.booking_id | ✅ UQ_APPROVAL_BOOKING |
| UNIQUE on USAGE_SESSION.booking_id | ✅ UQ_USAGE_SESSION_BOOKING |
| DEFAULT 'pending' on BOOKING.status | ✅ (line 169: DEFAULT 'pending') |
| DEFAULT 'available' on SPACE.current_status | ✅ (line 81: DEFAULT 'available') |

### 5C. Table Creation Order

Referenced tables must be created before referencing tables.

| Dependency | Correct order in DDL? |
|---|---|
| USER created before BOOKING | ✅ USER(line 51) → BOOKING(line 160) |
| SPACE created before BOOKING | ✅ SPACE(line 72) → BOOKING(line 160) |
| BOOKING created before APPROVAL | ✅ BOOKING(line 160) → APPROVAL(line 193) |
| BOOKING created before USAGE_SESSION | ✅ BOOKING(line 160) → USAGE_SESSION(line 220) |
| USER created before APPROVAL | ✅ USER(line 51) → APPROVAL(line 193) |
| USER created before USAGE_SESSION | ✅ USER(line 51) → USAGE_SESSION(line 220) |
| SPACE created before MAINTENANCE_RECORD | ✅ SPACE(line 72) → MAINTENANCE_RECORD(line 256) |
| USER created before MAINTENANCE_RECORD | ✅ USER(line 51) → MAINTENANCE_RECORD(line 256) |
| FACILITY_CATALOG created before SPACE_FACILITY | ✅ FACILITY_CATALOG(line 94) → SPACE_FACILITY(line 109) |
| SPACE created before SPACE_FACILITY | ✅ SPACE(line 72) → SPACE_FACILITY(line 109) |

### 5D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | All SQL statements end with semicolons | ✅ | All CREATE TABLE, ALTER, and DROP statements end with `;` |
| D2 | No column references an undefined table or column name | ✅ | All FK REFERENCES point to existing tables and columns |
| D3 | Composite PKs use table-level syntax PRIMARY KEY (col1, col2) | ✅ | SPACE_FACILITY: `CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (space_code, catalog_id)` |
| D4 | ON DELETE / ON UPDATE behavior is specified for all FKs | ✅ | All 14 FK constraints specify both ON UPDATE and ON DELETE |

---

## Step 06 — Sample Data

### 6A. Status Value Coverage

| Value | At least one row? |
|---|---|
| BOOKING.status = 'Pending' | ✅ Booking 3 (pending) |
| BOOKING.status = 'Approved' | ✅ Booking 1 (approved) |
| BOOKING.status = 'Rejected' | ✅ Bookings 2, 7, 11 (rejected) |
| BOOKING.status = 'Cancelled' | ✅ Booking 4 (cancelled) |
| BOOKING.status = 'Checked In' | ✅ Booking 6 (checked_in) |
| BOOKING.status = 'Completed' | ✅ Booking 9 (completed) |
| BOOKING.status = 'No-Show' | ✅ Booking 5 (no_show) |
| SPACE.current_status = 'Available' | ✅ LT001, CR101, CR102, WS001 |
| SPACE.current_status = 'In Use' | ✅ CR103 (in_use) |
| SPACE.current_status = 'Under Maintenance' | ✅ MR201 (under_maintenance) |
| SPACE.current_status = 'Temporarily Closed' | ✅ CR104 (temporarily_closed) |
| SPACE.current_status = 'Retired' | ✅ MR202 (retired) |

### 6B. Role Coverage

| USER.role | At least one user? |
|---|---|
| Student | ✅ James Chen (user 2), Lisa Wang (user 7) |
| Lecturer | ✅ Emily Davis (user 1), David Kim (user 8) |
| Teaching Assistant | ✅ Sarah Ahmed (user 3) |
| Facility Staff | ✅ Michael Brown (user 4), Maria Garcia (user 9) |
| Department Administrator | ✅ Anna Kowalski (user 5) |
| Facility Manager | ✅ Robert Taylor (user 6) |

### 6C. Exception Case Coverage

| Exception case | Present in sample data? |
|---|---|
| A rejected booking with rejection_reason filled | ✅ Bookings 2, 7, 11 — all have rejection_reason in APPROVAL |
| A space under maintenance with a linked maintenance record | ✅ MR201 (under_maintenance) has 2 maintenance records (in_progress + reported) |
| A no-show booking | ✅ Booking 5 (no_show) |
| A completed booking with actual times + conditions recorded in USAGE_SESSION | ✅ Booking 9 (completed) with USAGE_SESSION (start, end, initial_condition, final_condition, usage_notes all filled) |
| A booking for a retired space does NOT exist (constraint test) | ✅ MR202 (retired) has no bookings — implicit constraint test passed |

### 6D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | All tables have at least some inserted rows | ✅ | USER (9), SPACE (8), FACILITY_CATALOG (6), FACILITY_ASSET (63), SPACE_FACILITY (22), BOOKING (11), APPROVAL (6), USAGE_SESSION (3), MAINTENANCE_RECORD (4) |
| D2 | INSERT order respects FK dependencies (referenced rows inserted first) | ✅ | Phase 1: USER, SPACE, FACILITY_CATALOG → Phase 2a: FACILITY_ASSET → Phase 2b: SPACE_FACILITY → Phase 3: BOOKING, APPROVAL, USAGE_SESSION, MAINTENANCE_RECORD |
| D3 | No inserted row violates any CHECK, NOT NULL, UNIQUE, or FK constraint defined in Step 05 | ✅ | All rows respect defined constraints (e.g., expected_participants > 0, times are valid, FKs reference existing rows) |

---

## Step 07 — Query Design

### 7A. Requirement Coverage

| Requirement says | Covered by a query? |
|---|---|
| "view booking history" | ✅ Q2 — Full booking audit trail (request → approval → session) |
| "view upcoming bookings" | ✅ Q1 — Upcoming approved/checked-in bookings ordered by start time |
| "view spaces under maintenance" | ✅ Q3 — Active maintenance issues with space and staff details |
| "view no-show bookings" | ✅ Q4 — No-show booking list |

### 7B. Query Completeness

Each query must have all 4 components.

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
| At least one query uses multi-table JOIN | ✅ Q1 (3 tables) Q2 (7+ tables) Q3 (3 tables) Q4 (3 tables) Q5 (4 tables) |
| At least one query uses GROUP BY with aggregate (COUNT, SUM, AVG) | ❌ No query uses GROUP BY with an aggregate function |
| At least one query uses WHERE with a meaningful filter (not just WHERE 1=1) | ✅ All 5 queries have WHERE clauses with meaningful conditions |
| No query uses SELECT * as final output | ✅ All queries select explicit column lists |

### 7D. Structural Criteria

| # | Criterion | Status | Notes |
|---|---|---|---|
| D1 | All SQL is written for Microsoft SQL Server (T-SQL syntax) | ✅ | Uses GO, GETDATE(), CAST, IDENTITY — all valid T-SQL |
| D2 | All queries would return meaningful results when run against the sample data from Step 06 | ✅ | Q1 returns 3 rows (approved/checked_in future bookings), Q2 returns 11 booking rows, Q3 returns 2 active maintenance rows, Q4 returns 1 no-show row, Q5 returns multiple facility-inventory rows |
| D3 | Column names in queries match column names defined in Step 05 DDL | ✅ | All column references (b.status, s.space_code, u.full_name, mr.problem_category, etc.) match DDL definitions |

---

## Run Summary Table

| Run | Date | Total ❌ | Total ⚠️ | Key issues found | Changes made before next run |
|---|---|---|---|---|---|
| 1 | 2026-06-30 | 1 | 6 | **❌ 7C:** No GROUP BY with aggregate in Step 07 queries. **⚠️ 0C:** DDL trigger not from requirement or assumptions. **⚠️ 1L:** created_at not in requirement, not in assumptions. **⚠️ 3D:** rejection_reason NOT NULL not enforced at DB level. **⚠️ 0B:** ERD FACILITY_ASSERT attribute convention note. **⚠️ 0C:** is_trackable split and space_type enumeration not fully recorded as assumptions. **⚠️ 0C:** created_at not recorded as assumption. | TBD |
| 2 | | | | | |
| 3 | | | | | |

**Goal:** Total ❌ and ⚠️ counts decrease across runs. The "Changes made" column is the evidence of improvement for the Group Report.
