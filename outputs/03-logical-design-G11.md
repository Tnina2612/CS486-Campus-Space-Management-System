# Logical Database Design — G11

## 1. Relational Schema

### USER

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| user_id | NVARCHAR(50) | PK |
| full_name | NVARCHAR(100) | NOT NULL |
| email | NVARCHAR(255) | NOT NULL, UNIQUE |
| phone_number | NVARCHAR(20) | NULL |
| role | NVARCHAR(30) | NOT NULL, CHECK(role IN ('student','lecturer','teaching_assistant','facility_staff','department_administrator','facility_manager')) |
| department | NVARCHAR(100) | NOT NULL |
| account_status | NVARCHAR(20) | NOT NULL, DEFAULT 'active', CHECK(account_status IN ('active','inactive','suspended')) |

Candidate Keys: (email)

---

### SPACE

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| space_code | NVARCHAR(20) | PK |
| space_name | NVARCHAR(100) | NOT NULL |
| space_type | NVARCHAR(30) | NOT NULL, CHECK(space_type IN ('auditorium','classroom','computer_laboratory','project_laboratory','meeting_room','student_workspace')) |
| building | NVARCHAR(100) | NOT NULL |
| floor | INT | NOT NULL |
| room_number | NVARCHAR(20) | NOT NULL |
| capacity | INT | NOT NULL, CHECK(capacity > 0) |
| current_status | NVARCHAR(20) | NOT NULL, DEFAULT 'available', CHECK(current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired')) |
| usage_policy | NVARCHAR(MAX) | NULL |

Candidate Keys: (building, floor, room_number)

---

### FACILITY_CATALOG

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| catalog_id | NVARCHAR(20) | PK |
| name | NVARCHAR(100) | NOT NULL, UNIQUE |
| description | NVARCHAR(500) | NULL |
| is_trackable | BIT | NOT NULL, DEFAULT 0 |

---

### SPACE_FACILITY

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| space_code | NVARCHAR(20) | PK, FK → SPACE(space_code) |
| catalog_id | NVARCHAR(20) | PK, FK → FACILITY_CATALOG(catalog_id) |
| quantity | INT | NOT NULL, DEFAULT 1, CHECK(quantity > 0) |

---

### FACILITY_ASSET

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| asset_id | INT | PK, IDENTITY(1,1) |
| catalog_id | NVARCHAR(20) | NOT NULL, FK → FACILITY_CATALOG(catalog_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| asset_tag | NVARCHAR(50) | NOT NULL, UNIQUE |
| status | NVARCHAR(20) | NOT NULL, DEFAULT 'working', CHECK(status IN ('working','damaged','under_repair','retired')) |

---

### BOOKING

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| booking_id | INT | PK, IDENTITY(1,1) |
| user_id | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| requested_start_time | DATETIME2 | NOT NULL |
| requested_end_time | DATETIME2 | NOT NULL |
| purpose | NVARCHAR(500) | NOT NULL |
| expected_participants | INT | NOT NULL, CHECK(expected_participants > 0) |
| booking_type | NVARCHAR(30) | NOT NULL, CHECK(booking_type IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')) |
| status | NVARCHAR(20) | NOT NULL, DEFAULT 'pending', CHECK(status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')) |

Table-level CHECK: (requested_end_time > requested_start_time)

---

### APPROVAL

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| approval_id | INT | PK, IDENTITY(1,1) |
| booking_id | INT | NOT NULL, FK → BOOKING(booking_id), UNIQUE |
| staff_id | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| decision | NVARCHAR(10) | NOT NULL, CHECK(decision IN ('approved','rejected')) |
| decision_time | DATETIME2 | NOT NULL |
| decision_note | NVARCHAR(500) | NULL |
| rejection_reason | NVARCHAR(500) | NULL |

Table-level CHECK: ((decision = 'rejected' AND rejection_reason IS NOT NULL) OR (decision = 'approved'))

---

### USAGE_SESSION

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| session_id | INT | PK, IDENTITY(1,1) |
| booking_id | INT | NOT NULL, FK → BOOKING(booking_id), UNIQUE |
| checked_in_by | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| actual_start_time | DATETIME2 | NOT NULL |
| initial_condition | NVARCHAR(500) | NULL |
| actual_end_time | DATETIME2 | NULL |
| final_condition | NVARCHAR(500) | NULL |
| usage_notes | NVARCHAR(500) | NULL |

Table-level CHECK: (actual_end_time IS NULL OR actual_end_time > actual_start_time)

---

### MAINTENANCE

| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|--------------------|
| maintenance_id | INT | PK, IDENTITY(1,1) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| reporter_id | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| assigned_staff_id | NVARCHAR(50) | NULL, FK → USER(user_id) |
| problem_description | NVARCHAR(500) | NOT NULL |
| problem_type | NVARCHAR(30) | NOT NULL, CHECK(problem_type IN ('broken_projector','ac_failure','damaged_furniture','cleaning','network_problem','other')) |
| start_time | DATETIME2 | NOT NULL |
| completion_time | DATETIME2 | NULL |
| status | NVARCHAR(20) | NOT NULL, DEFAULT 'reported', CHECK(status IN ('reported','in_progress','completed','cancelled')) |
| result_note | NVARCHAR(500) | NULL |

Table-level CHECK: (completion_time IS NULL OR completion_time >= start_time)

---

## 2. Summary of Referential Integrity

| From Table | From Column | To Table | To Column | ON UPDATE | ON DELETE |
|------------|-------------|----------|-----------|-----------|-----------|
| BOOKING | user_id | USER | user_id | NO ACTION | NO ACTION |
| BOOKING | space_code | SPACE | space_code | CASCADE | NO ACTION |
| APPROVAL | booking_id | BOOKING | booking_id | NO ACTION | NO ACTION |
| APPROVAL | staff_id | USER | user_id | NO ACTION | NO ACTION |
| USAGE_SESSION | booking_id | BOOKING | booking_id | NO ACTION | NO ACTION |
| USAGE_SESSION | checked_in_by | USER | user_id | NO ACTION | NO ACTION |
| SPACE_FACILITY | space_code | SPACE | space_code | CASCADE | CASCADE |
| SPACE_FACILITY | catalog_id | FACILITY_CATALOG | catalog_id | CASCADE | NO ACTION |
| FACILITY_ASSET | catalog_id | FACILITY_CATALOG | catalog_id | CASCADE | NO ACTION |
| FACILITY_ASSET | space_code | SPACE | space_code | CASCADE | NO ACTION |
| MAINTENANCE | space_code | SPACE | space_code | CASCADE | NO ACTION |
| MAINTENANCE | reporter_id | USER | user_id | NO ACTION | NO ACTION |
| MAINTENANCE | assigned_staff_id | USER | user_id | NO ACTION | SET NULL |

## 3. Entity-to-Table Traceability

| Step-2 Entity | Step-3 Table | Notes |
|---------------|-------------|-------|
| USER | USER | Direct mapping |
| SPACE | SPACE | Direct mapping |
| FACILITY_CATALOG | FACILITY_CATALOG | Direct mapping |
| SPACE_FACILITY | SPACE_FACILITY | Associative entity — composite PK (space_code, catalog_id) |
| FACILITY_ASSET | FACILITY_ASSET | Surrogate PK (asset_id); FK to catalog and space |
| BOOKING | BOOKING | Surrogate PK (booking_id) |
| APPROVAL | APPROVAL | 1:1 with BOOKING enforced via UNIQUE(booking_id) |
| USAGE_SESSION | USAGE_SESSION | 1:1 with BOOKING enforced via UNIQUE(booking_id) |
| MAINTENANCE | MAINTENANCE | Surrogate PK (maintenance_id) |

## 4. Business Rule Enforcement

| Business Rule | Enforcement Mechanism |
|---------------|----------------------|
| Same space cannot have overlapping approved bookings | Application logic (multi-row time overlap validation across BOOKING) |
| Space under maintenance/closed/retired cannot be booked | Application logic (cross-table check on SPACE.current_status and MAINTENANCE.status at booking time) |
| User must have a university account | NOT NULL on all USER columns; PK on user_id |
| Status/type values limited to predefined set | CHECK constraints on every status and type column |
| Booking end time must be after start time | CHECK(requested_end_time > requested_start_time) on BOOKING |
| Rejection reason required when booking rejected | CHECK((decision='rejected' AND rejection_reason IS NOT NULL) OR (decision='approved')) on APPROVAL |
| Check-out end time must be after check-in start time | CHECK(actual_end_time IS NULL OR actual_end_time > actual_start_time) on USAGE_SESSION |
| Maintenance completion must be after or equal to start | CHECK(completion_time IS NULL OR completion_time >= start_time) on MAINTENANCE |
| Capacity must be positive | CHECK(capacity > 0) on SPACE |
| Expected participants positive | CHECK(expected_participants > 0) on BOOKING |
| Quantity must be positive | CHECK(quantity > 0) on SPACE_FACILITY |
| Booking lifecycle state transitions | Application logic (state machine: pending→approved→checked_in→completed) |
| Asset tag must be unique | UNIQUE constraint on FACILITY_ASSET.asset_tag |
| Email must be unique | UNIQUE constraint on USER.email |
| Only trackable catalog items can appear in FACILITY_ASSET | Application logic (cross-table: is_trackable = 1) |
| Historical records preserved (no hard deletes) | FK ON DELETE NO ACTION on BOOKING, MAINTENANCE, and most referencing tables |

## 5. Conversion Notes

- **M:N Resolution — SPACE ↔ FACILITY_CATALOG:** The many-to-many relationship was resolved by creating the SPACE_FACILITY associative table with a composite PK (space_code, catalog_id) and the business attribute `quantity`.
- **1:1 Resolution — BOOKING → APPROVAL:** The booking lifecycle was normalized into three tables. The 1:1 constraint is enforced by a UNIQUE(booking_id) on APPROVAL.
- **1:1 Resolution — BOOKING → USAGE_SESSION:** Same pattern; UNIQUE(booking_id) on USAGE_SESSION enforces 1:1.
- **CASCADE on SPACE.code update:** SPACE.space_code is a natural key. CASCADE ON UPDATE propagates changes to child tables.
- **CASCADE on FACILITY_CATALOG.catalog_id update:** Same rationale — natural key propagation.
- **NO ACTION on DELETE for historical tables:** BOOKING, MAINTENANCE, and FACILITY_ASSET use NO ACTION on DELETE to preserve history when referenced parent rows are removed.
- **CASCADE on DELETE for junction table:** SPACE_FACILITY cascades delete with SPACE because it is a pure mapping table with no independent business meaning.
- **SET NULL for assigned_staff_id:** When a user is deleted, their maintenance assignments become unassigned (SET NULL) rather than losing the entire maintenance record.
- **NO ACTION on DELETE for APPROVAL and USAGE_SESSION:** These lifecycle tables use NO ACTION (not CASCADE) to prevent silent data loss of approval decisions and session records if a BOOKING row is accidentally deleted — preserving audit trail per BR-09.
