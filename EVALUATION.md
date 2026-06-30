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

This section asks the agent to reason freely about the outputs rather than compare against a fixed list. Run this first to surface issues the checklist below may not anticipate.

### 0A. Requirement vs. Output Gap Scan

Read `req/business-requirement.md` sentence by sentence. For each sentence that states a fact, rule, attribute, or constraint, check whether it is fully and correctly reflected somewhere in the outputs. Record any sentence that is missing, partially covered, or incorrectly represented.

| Requirement sentence (paraphrased) | Covered? | Step (01-07) | File | Issue (if any) |
|---|---|---|---|---|
| *(agent fills this in by reading the requirement)* | | | | |

**Instruction to agent:** Do not skip sentences. Every sentence in the requirement that specifies something about the system must have a corresponding entry in this table. If you find a sentence that has no coverage in any output file, mark it ❌ and identify the exact step number where it should have been covered (e.g. "Step 01" if it's a missing business rule, "Step 05" if it's a missing constraint), plus describe what is missing.

---

### 0B. Logic Consistency Scan

Read each output file and identify any internal inconsistencies — places where two parts of the same output contradict each other, without needing to compare against the requirement.

Common patterns to look for:
- A column marked NOT NULL in one place but nullable in another
- A Min value in a participation constraint table that contradicts the Notes in the same row
- A candidate key claim that would not actually be unique given the business context
- A status value listed in one section but missing from the CHECK constraint in another
- A relationship described as 1:1 in the ERD but implemented as 1:N in the schema

| Step (01-07) | File | Location (section/table/row) | Inconsistency found | Severity (❌ / ⚠️) |
|---|---|---|---|---|
| *(agent fills this in by reading each output)* | | | | |

**Instruction to agent:** Read every table, every constraint, and every note in each output file. If any two statements in the same file contradict each other, record it here regardless of whether the checklist below asks about it. Always state the step number first so the issue can be traced directly to its source.

---

### 0C. Invented Content Scan

Identify anything in the outputs that was not stated in the requirement and was not recorded as an explicit assumption.

| Step (01-07) | File | Invented element | Recorded as assumption? | Issue |
|---|---|---|---|---|
| *(agent fills this in)* | | | | |

---

## Step 01 — Business Requirement Analysis

### 1A. Requirement Traceability — Actors
Every actor named in the requirement must appear in the output.

| Requirement says | Present in output? |
|---|---|
| "A user may be a **student**" | |
| "A user may be a **lecturer**" | |
| "A user may be a **teaching assistant**" | |
| "A user may be a **facility staff**" | |
| "A user may be a **department administrator**" | |
| "A user may be a **facility manager**" | |

### 1B. Requirement Traceability — User Attributes
Every attribute stated for USER must appear in the output.

| Requirement says | Present in output? |
|---|---|
| "user ID" | |
| "full name" | |
| "email" | |
| "phone number" | |
| "role" | |
| "department" | |
| "account status" | |

### 1C. Requirement Traceability — Space Attributes
Every attribute stated for SPACE must appear in the output.

| Requirement says | Present in output? |
|---|---|
| "unique space code" | |
| "space name" | |
| "space type" | |
| "building" | |
| "floor" | |
| "room number" | |
| "capacity" | |
| "current status" | |
| "usage policy" | |

### 1D. Requirement Traceability — Space Status Values
| Requirement says | Present in output? |
|---|---|
| "available" | |
| "in use" | |
| "under maintenance" | |
| "temporarily closed" | |
| "retired" | |

### 1E. Requirement Traceability — Booking Attributes
| Requirement says | Present in output? |
|---|---|
| "selecting a space" (space reference) | |
| "requested start time" | |
| "requested end time" | |
| "purpose of use" | |
| "expected number of participants" | |

### 1F. Requirement Traceability — Booking Status Values
| Requirement says | Present in output? |
|---|---|
| "pending" | |
| "approved" | |
| "rejected" | |
| "cancelled" | |
| "checked in" | |
| "completed" | |
| "no-show" | |

### 1G. Requirement Traceability — Booking Purpose Values
| Requirement says | Present in output? |
|---|---|
| "lecture" | |
| "examination" | |
| "seminar" | |
| "workshop" | |
| "meeting" | |
| "student activity" | |
| "administrative event" | |

### 1H. Requirement Traceability — Approval Attributes
| Requirement says | Present in output? |
|---|---|
| "staff member who made the decision" | |
| "decision time" | |
| "decision note" | |
| "rejection reason" (when rejected) | |

### 1I. Requirement Traceability — Usage Session Attributes
| Requirement says | Present in output? |
|---|---|
| "actual start time" (check-in) | |
| "person who checked in the booking" | |
| "initial condition of the space" | |
| "actual end time" (check-out) | |
| "final condition of the space" | |
| "usage notes" | |

### 1J. Requirement Traceability — Maintenance Record Attributes
| Requirement says | Present in output? |
|---|---|
| "related space" | |
| "reporter" | |
| "assigned staff member" | |
| "problem description" | |
| "start time" | |
| "completion time" | |
| "status" | |
| "result note" | |

### 1K. Requirement Traceability — Business Rules
Every rule explicitly stated in the requirement must appear in the output.

| Requirement says | Present in output? |
|---|---|
| "The same space cannot have two approved bookings with overlapping time periods" | |
| "A space that is under maintenance ... cannot be booked" | |
| "A space that is ... closed ... cannot be booked" | |
| "A space that is ... retired cannot be booked" | |
| "the system records the staff member who made the decision, the decision time, and a decision note" | |
| "If the booking is rejected, the rejection reason should be stored" | |
| "facility staff can check in the booking" + records actual start time + person + initial condition | |
| "facility staff can complete the booking" + records actual end time + final condition + usage notes | |
| "A space under maintenance cannot be booked" (stated again separately — must be treated as explicit rule) | |
| "keep historical records of bookings and maintenance activities" | |

### 1L. Structural Criteria

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| L1 | No entity, attribute, or relationship is invented beyond what the requirement states. Any addition is recorded as an explicit assumption. | | |
| L2 | Assumptions section exists and lists all design decisions not directly stated in the requirement. | | |
| L3 | Unresolved questions section exists and raises genuine open questions about the requirement. | | |
| L4 | Relationships between all entity pairs are identified with correct cardinality (1-1, 1-N, N-M). | | |

---

## Step 02 — ERD Design

### 2A. Entity Coverage
Every entity from Step 01 must appear in the ERD.

| Entity from Step 01 | Present in ERD? |
|---|---|
| USER | |
| SPACE | |
| FACILITY_CATALOG (or equivalent) | |
| SPACE_FACILITY (or equivalent junction) | |
| BOOKING | |
| APPROVAL | |
| USAGE_SESSION | |
| MAINTENANCE_RECORD | |

### 2B. Relationship Coverage
Every relationship from Step 01 must be drawn in the ERD.

| Relationship | Present in ERD? |
|---|---|
| USER submits BOOKING | |
| SPACE is referenced by BOOKING | |
| BOOKING has APPROVAL | |
| BOOKING has USAGE_SESSION | |
| USER (staff) decides APPROVAL | |
| USER (staff) checks in USAGE_SESSION | |
| SPACE contains facilities (via junction or direct) | |
| USER reports MAINTENANCE_RECORD | |
| USER assigned to MAINTENANCE_RECORD | |
| SPACE undergoes MAINTENANCE_RECORD | |

### 2C. Participation Constraints Consistency
For every row in the participation constraints table: if Notes says "may have zero / may not have any", then Min must be 0. If Notes says "must have / always has", then Min must be 1.

| Relationship | Min (A side) matches Notes? | Min (B side) matches Notes? | Notes |
|---|---|---|---|
| USER → BOOKING | | | |
| SPACE → BOOKING | | | |
| BOOKING → APPROVAL | | | |
| BOOKING → USAGE_SESSION | | | |
| USER → APPROVAL (decides) | | | |
| USER → USAGE_SESSION (checks in) | | | |
| SPACE → SPACE_FACILITY | | | |
| FACILITY_CATALOG → SPACE_FACILITY | | | |
| FACILITY_CATALOG → FACILITY_ASSET | | | |
| SPACE → FACILITY_ASSET | | | |
| USER → MAINTENANCE_RECORD (reports) | | | |
| USER → MAINTENANCE_RECORD (assigned) | | | |
| SPACE → MAINTENANCE_RECORD | | | |

### 2D. Structural Criteria

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| D1 | Mermaid erDiagram syntax is valid — no missing closing braces, all FK attributes marked correctly | | |
| D2 | N-M relationships are shown as junction entities, not as direct many-to-many lines with no resolution | | |
| D3 | 1:1 relationships (BOOKING→APPROVAL, BOOKING→USAGE_SESSION) are represented distinctly from 1:N | | |
| D4 | No entity, relationship, or attribute appears in the ERD that was not in Step 01 | | |

---

## Step 03 — Logical Design

### 3A. Table Coverage
Every entity from Step 02 must have a corresponding table.

| Entity | Table exists? | PK defined? |
|---|---|---|
| USER | | |
| SPACE | | |
| FACILITY_CATALOG | | |
| SPACE_FACILITY | | |
| FACILITY_ASSET (if present in Step 02) | | |
| BOOKING | | |
| APPROVAL | | |
| USAGE_SESSION | | |
| MAINTENANCE_RECORD | | |

### 3B. Attribute Coverage
Every attribute from Step 01 must appear in its corresponding table. Check each entity:

| Entity | All Step 01 attributes present in table? | Missing attributes (if any) |
|---|---|---|
| USER | | |
| SPACE | | |
| BOOKING | | |
| APPROVAL | | |
| USAGE_SESSION | | |
| MAINTENANCE_RECORD | | |

### 3C. Foreign Key Coverage
Every relationship from Step 02 must be implemented as an FK or junction table.

| Relationship | Implemented as | Correct direction? |
|---|---|---|
| USER submits BOOKING | FK user_id in BOOKING | |
| SPACE referenced by BOOKING | FK space_code in BOOKING | |
| BOOKING has APPROVAL | FK booking_id in APPROVAL + UNIQUE | |
| BOOKING has USAGE_SESSION | FK booking_id in USAGE_SESSION + UNIQUE | |
| USER decides APPROVAL | FK staff_id in APPROVAL | |
| USER checks in USAGE_SESSION | FK checked_in_by in USAGE_SESSION | |
| SPACE–FACILITY_CATALOG (N-M) | Junction table SPACE_FACILITY | |
| USER reports MAINTENANCE_RECORD | FK reporter_id in MAINTENANCE_RECORD | |
| USER assigned MAINTENANCE_RECORD | FK assigned_staff_id in MAINTENANCE_RECORD (nullable) | |
| SPACE undergoes MAINTENANCE_RECORD | FK space_code in MAINTENANCE_RECORD | |

### 3D. Constraint Coverage
Every business rule from Step 01 that can be enforced at schema level must have a mechanism here.

| Business Rule | Mechanism in schema | Present? |
|---|---|---|
| No overlapping approved bookings | Trigger or explicit application-level note | |
| Space status blocks booking | Application-level note or CHECK | |
| Rejection reason required when rejected | CHECK or application-level note | |
| Booking end time > start time | CHECK (requested_end_time > requested_start_time) | |
| Capacity > 0 | CHECK (capacity > 0) | |
| Expected participants > 0 | CHECK (expected_participants > 0) | |
| User email unique | UNIQUE constraint on USER.email | |
| 1:1 BOOKING→APPROVAL | UNIQUE on APPROVAL.booking_id | |
| 1:1 BOOKING→USAGE_SESSION | UNIQUE on USAGE_SESSION.booking_id | |

### 3E. Structural Criteria

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| E1 | No information from Step 02 is lost — every attribute appears in some table | | |
| E2 | No unnecessary redundancy — same non-FK attribute does not appear in two tables | | |
| E3 | Candidate keys are identified where they exist (e.g. USER.email, SPACE.space_code) | | |
| E4 | NULL / NOT NULL is assigned correctly: mandatory participation → NOT NULL, optional → nullable | | |
| E5 | No table or column is invented beyond Step 02 without being recorded as an assumption | | |

---

## Step 04 — Design Validation

### 4A. ERD-to-Schema Completeness
| Check | Status | Notes |
|---|---|---|
| Every entity in ERD has a table in schema | | |
| Every relationship in ERD is represented in schema (FK or junction table) | | |
| Every attribute in ERD appears in schema | | |

### 4B. Business Rule Enforcement Audit
For each rule, the validation output must explicitly state which mechanism enforces it or flag it as unenforced.

| Business Rule | Enforcement acknowledged in Step 04? | Mechanism stated? |
|---|---|---|
| No overlapping approved bookings for same space | | |
| Space under maintenance cannot be booked | | |
| Space temporarily closed cannot be booked | | |
| Space retired cannot be booked | | |
| Rejection reason stored when rejected | | |
| Approval records decider + decision time + note | | |
| Check-in records actual start + person + initial condition | | |
| Check-out records actual end + final condition + usage notes | | |
| Historical records preserved | | |

### 4C. Status Value Audit
All enum/status values in schema must exactly match requirement.

| Column | Required values (from requirement) | Schema values match? |
|---|---|---|
| BOOKING.status | pending, approved, rejected, cancelled, checked_in, completed, no_show | |
| SPACE.current_status | available, in_use, under_maintenance, temporarily_closed, retired | |
| BOOKING.purpose | lecture, examination, seminar, workshop, meeting, student_activity, administrative_event | |
| MAINTENANCE_RECORD.status | (not specified in requirement — assumption must be stated) | |
| USER.role | student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager | |

### 4D. Structural Criteria

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| D1 | Validation explicitly confirms participation constraints (optional/mandatory) are correctly reflected as nullable/NOT NULL in schema | | |
| D2 | Validation flags any table or column with no origin in ERD | | |
| D3 | Validation does not introduce new design elements — it only evaluates existing ones | | |

---

## Step 05 — Database Implementation (DDL)

### 5A. Table Creation Coverage
| Table | CREATE TABLE present? | PK declared? |
|---|---|---|
| USER | | |
| SPACE | | |
| FACILITY_CATALOG | | |
| SPACE_FACILITY | | |
| FACILITY_ASSET | | |
| BOOKING | | |
| APPROVAL | | |
| USAGE_SESSION | | |
| MAINTENANCE_RECORD | | |

### 5B. Constraint Coverage
| Constraint | Present in DDL? |
|---|---|
| UNIQUE on USER.email | |
| CHECK on SPACE.capacity > 0 | |
| CHECK on BOOKING.requested_end_time > requested_start_time | |
| CHECK on BOOKING.expected_participants > 0 | |
| CHECK on BOOKING.status IN (all 7 values from requirement) | |
| CHECK on SPACE.current_status IN (all 5 values from requirement) | |
| CHECK on BOOKING.purpose IN (all 7 values from requirement) | |
| CHECK on USER.role IN (all 6 values from requirement) | |
| UNIQUE on APPROVAL.booking_id | |
| UNIQUE on USAGE_SESSION.booking_id | |
| DEFAULT 'Pending' on BOOKING.status | |
| DEFAULT 'Available' on SPACE.current_status | |

### 5C. Table Creation Order
Referenced tables must be created before referencing tables.

| Dependency | Correct order in DDL? |
|---|---|
| USER created before BOOKING | |
| SPACE created before BOOKING | |
| BOOKING created before APPROVAL | |
| BOOKING created before USAGE_SESSION | |
| USER created before APPROVAL | |
| USER created before USAGE_SESSION | |
| SPACE created before MAINTENANCE_RECORD | |
| USER created before MAINTENANCE_RECORD | |
| FACILITY_CATALOG created before SPACE_FACILITY | |
| SPACE created before SPACE_FACILITY | |

### 5D. Structural Criteria

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| D1 | All SQL statements end with semicolons | | |
| D2 | No column references an undefined table or column name | | |
| D3 | Composite PKs use table-level syntax PRIMARY KEY (col1, col2) | | |
| D4 | ON DELETE / ON UPDATE behavior is specified for all FKs | | |

---

## Step 06 — Sample Data

### 6A. Status Value Coverage
Sample data must contain at least one row for each required status value.

| Value | At least one row? |
|---|---|
| BOOKING.status = 'Pending' | |
| BOOKING.status = 'Approved' | |
| BOOKING.status = 'Rejected' | |
| BOOKING.status = 'Cancelled' | |
| BOOKING.status = 'Checked In' | |
| BOOKING.status = 'Completed' | |
| BOOKING.status = 'No-Show' | |
| SPACE.current_status = 'Available' | |
| SPACE.current_status = 'In Use' | |
| SPACE.current_status = 'Under Maintenance' | |
| SPACE.current_status = 'Temporarily Closed' | |
| SPACE.current_status = 'Retired' | |

### 6B. Role Coverage
| USER.role | At least one user? |
|---|---|
| Student | |
| Lecturer | |
| Teaching Assistant | |
| Facility Staff | |
| Department Administrator | |
| Facility Manager | |

### 6C. Exception Case Coverage
| Exception case | Present in sample data? |
|---|---|
| A rejected booking with rejection_reason filled | |
| A space under maintenance with a linked maintenance record | |
| A no-show booking | |
| A completed booking with actual times + conditions recorded in USAGE_SESSION | |
| A booking for a retired space does NOT exist (constraint test) | |

### 6D. Structural Criteria

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| D1 | All tables have at least some inserted rows | | |
| D2 | INSERT order respects FK dependencies (referenced rows inserted first) | | |
| D3 | No inserted row violates any CHECK, NOT NULL, UNIQUE, or FK constraint defined in Step 05 | | |

---

## Step 07 — Query Design

### 7A. Requirement Coverage
The requirement explicitly states staff must be able to answer these questions — at least one query must address each.

| Requirement says | Covered by a query? |
|---|---|
| "view booking history" | |
| "view upcoming bookings" | |
| "view spaces under maintenance" | |
| "view no-show bookings" | |

### 7B. Query Completeness
Each query must have all 4 components.

| Query # | Business question? | Target user? | Explanation? | SQL statement? |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

### 7C. Query Diversity

| Requirement | Present? |
|---|---|
| At least 5 queries total | |
| At least one query uses multi-table JOIN | |
| At least one query uses GROUP BY with aggregate (COUNT, SUM, AVG) | |
| At least one query uses WHERE with a meaningful filter (not just WHERE 1=1) | |
| No query uses SELECT * as final output | |

### 7D. Structural Criteria

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| D1 | All SQL is written for Microsoft SQL Server (T-SQL syntax) | | |
| D2 | All queries would return meaningful results when run against the sample data from Step 06 | | |
| D3 | Column names in queries match column names defined in Step 05 DDL | | |

---

## Run Summary Table

| Run | Date | Total ❌ | Total ⚠️ | Key issues found | Changes made before next run |
|-----|------|---------|---------|-----------------|------------------------------|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |

**Goal:** Total ❌ and ⚠️ counts decrease across runs. The "Changes made" column is the evidence of improvement for the Group Report.