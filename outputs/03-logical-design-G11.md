# Logical Database Design

All tables use `snake_case` naming. Primary keys are underlined; foreign keys are marked with (FK).

---

## Table: `user`

| Column | Type | Constraints | Description |
|---|---|---|---|
| user_id | INT | PK, IDENTITY(1,1) | Unique system-generated identifier |
| full_name | NVARCHAR(100) | NOT NULL | User's full name |
| email | NVARCHAR(255) | NOT NULL, UNIQUE | University email address |
| phone_number | NVARCHAR(20) | NULL | Contact phone |
| role | NVARCHAR(30) | NOT NULL, CHECK(role IN (...)) | student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager |
| department | NVARCHAR(100) | NOT NULL | Department name |
| account_status | NVARCHAR(20) | NOT NULL, DEFAULT 'active', CHECK(account_status IN (...)) | active, inactive, suspended |

**Notation:** User(**user_id**, full_name, email, phone_number, role, department, account_status)  
**Candidate Keys:** email

---

## Table: `space`

| Column | Type | Constraints | Description |
|---|---|---|---|
| space_code | NVARCHAR(20) | PK | Unique short code for the space (e.g., 'A101') |
| space_name | NVARCHAR(100) | NOT NULL | Descriptive name |
| space_type | NVARCHAR(30) | NOT NULL, CHECK(space_type IN (...)) | auditorium, classroom, computer_lab, project_lab, meeting_room, student_workspace |
| building | NVARCHAR(100) | NOT NULL | Building name/code |
| floor | INT | NOT NULL | Floor number |
| room_number | NVARCHAR(20) | NOT NULL | Room identifier |
| capacity | INT | NOT NULL, CHECK(capacity > 0) | Maximum occupancy |
| current_status | NVARCHAR(30) | NOT NULL, DEFAULT 'available', CHECK(current_status IN (...)) | available, in_use, under_maintenance, temporarily_closed, retired |
| usage_policy | NVARCHAR(MAX) | NULL | Free-text policy/restrictions |

**Notation:** Space(**space_code**, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)  
**Candidate Keys:** (building, floor, room_number) — composite unique

---

## Table: `facility`

| Column | Type | Constraints | Description |
|---|---|---|---|
| facility_id | INT | PK, IDENTITY(1,1) | Unique identifier |
| facility_name | NVARCHAR(100) | NOT NULL, UNIQUE | e.g., projector, whiteboard, microphone |
| description | NVARCHAR(255) | NULL | Optional specification |

**Notation:** Facility(**facility_id**, facility_name, description)  
**Candidate Keys:** facility_name

---

## Table: `space_facility`

| Column | Type | Constraints | Description |
|---|---|---|---|
| space_code | NVARCHAR(20) | PK, FK → Space(space_code) | Reference to space |
| facility_id | INT | PK, FK → Facility(facility_id) | Reference to facility |

**Notation:** Space_Facility(**space_code**, **facility_id**)  
**Note:** Composite primary key. No additional attributes needed per the requirements.

---

## Table: `booking_request`

| Column | Type | Constraints | Description |
|---|---|---|---|
| booking_id | INT | PK, IDENTITY(1,1) | Unique identifier |
| requester_id | INT | NOT NULL, FK → User(user_id) | Who submitted the request |
| space_code | NVARCHAR(20) | NOT NULL, FK → Space(space_code) | Requested space |
| requested_start_time | DATETIME2 | NOT NULL | Desired start |
| requested_end_time | DATETIME2 | NOT NULL, CHECK(end > start) | Desired end |
| purpose | NVARCHAR(30) | NOT NULL, CHECK(purpose IN (...)) | lecture, examination, seminar, workshop, meeting, student_activity, administrative_event |
| expected_participants | INT | NOT NULL, CHECK(expected_participants > 0) | Expected headcount |
| status | NVARCHAR(20) | NOT NULL, DEFAULT 'pending', CHECK(status IN (...)) | pending, approved, rejected, cancelled, checked_in, completed, no_show |
| submitted_at | DATETIME2 | NOT NULL, DEFAULT GETDATE() | Submission timestamp |

**Notation:** Booking_Request(**booking_id**, requester_id, space_code, requested_start_time, requested_end_time, purpose, expected_participants, status, submitted_at)  
**Candidate Keys:** None beyond booking_id. Overlap prevention is enforced via CHECK or application-level (or indexed constraint using a exclusion constraint — in SQL Server, enforced via a trigger or application logic since native exclusion constraints do not exist).

---

## Table: `booking_approval`

| Column | Type | Constraints | Description |
|---|---|---|---|
| approval_id | INT | PK, IDENTITY(1,1) | Unique identifier |
| booking_id | INT | NOT NULL, UNIQUE, FK → Booking_Request(booking_id) | Which booking is being decided |
| staff_id | INT | NOT NULL, FK → User(user_id) | Staff who made the decision |
| decision | NVARCHAR(10) | NOT NULL, CHECK(decision IN ('approved','rejected')) | Decision outcome |
| decision_time | DATETIME2 | NOT NULL, DEFAULT GETDATE() | When the decision was made |
| decision_note | NVARCHAR(MAX) | NULL | Optional note |
| rejection_reason | NVARCHAR(MAX) | NULL | Required when decision = 'rejected' |

**Notation:** Booking_Approval(**approval_id**, booking_id, staff_id, decision, decision_time, decision_note, rejection_reason)  
**Candidate Keys:** booking_id (UNIQUE — one approval per booking)

---

## Table: `booking_session`

| Column | Type | Constraints | Description |
|---|---|---|---|
| session_id | INT | PK, IDENTITY(1,1) | Unique identifier |
| booking_id | INT | NOT NULL, UNIQUE, FK → Booking_Request(booking_id) | Reference to the booking |
| actual_start_time | DATETIME2 | NOT NULL | Actual check-in time |
| checkin_by | INT | NOT NULL, FK → User(user_id) | Staff who performed check-in |
| initial_condition | NVARCHAR(MAX) | NULL | Condition at check-in |
| actual_end_time | DATETIME2 | NULL | Actual checkout time (nullable until checked out) |
| completed_by | INT | NULL, FK → User(user_id) | Staff who performed checkout |
| final_condition | NVARCHAR(MAX) | NULL | Condition at checkout |
| usage_notes | NVARCHAR(MAX) | NULL | Notes on the session |

**Notation:** Booking_Session(**session_id**, booking_id, actual_start_time, checkin_by, initial_condition, actual_end_time, completed_by, final_condition, usage_notes)  
**Candidate Keys:** booking_id (UNIQUE — one session per booking)

---

## Table: `maintenance_record`

| Column | Type | Constraints | Description |
|---|---|---|---|
| maintenance_id | INT | PK, IDENTITY(1,1) | Unique identifier |
| space_code | NVARCHAR(20) | NOT NULL, FK → Space(space_code) | Affected space |
| reporter_id | INT | NOT NULL, FK → User(user_id) | Person who reported the issue |
| assigned_staff_id | INT | NULL, FK → User(user_id) | Staff assigned to fix (nullable until assigned) |
| problem_description | NVARCHAR(MAX) | NOT NULL | Description of the problem |
| problem_type | NVARCHAR(30) | NOT NULL, CHECK(problem_type IN (...)) | broken_projector, ac_failure, damaged_furniture, cleaning_issue, network_problem, other |
| start_time | DATETIME2 | NOT NULL, DEFAULT GETDATE() | When maintenance was reported/started |
| completion_time | DATETIME2 | NULL | When maintenance was completed |
| status | NVARCHAR(20) | NOT NULL, DEFAULT 'reported', CHECK(status IN (...)) | reported, in_progress, completed, cancelled |
| result_note | NVARCHAR(MAX) | NULL | Notes on outcome |

**Notation:** Maintenance_Record(**maintenance_id**, space_code, reporter_id, assigned_staff_id, problem_description, problem_type, start_time, completion_time, status, result_note)

---

## Summary of Referential Integrity

| FK Constraint | From | To | On Delete |
|---|---|---|---|
| FK_booking_request_requester | booking_request.requester_id | user.user_id | NO ACTION |
| FK_booking_request_space | booking_request.space_code | space.space_code | NO ACTION |
| FK_booking_approval_booking | booking_approval.booking_id | booking_request.booking_id | NO ACTION |
| FK_booking_approval_staff | booking_approval.staff_id | user.user_id | NO ACTION |
| FK_booking_session_booking | booking_session.booking_id | booking_request.booking_id | NO ACTION |
| FK_booking_session_checkin | booking_session.checkin_by | user.user_id | NO ACTION |
| FK_booking_session_checkout | booking_session.completed_by | user.user_id | NO ACTION |
| FK_space_facility_space | space_facility.space_code | space.space_code | CASCADE |
| FK_space_facility_facility | space_facility.facility_id | facility.facility_id | CASCADE |
| FK_maintenance_space | maintenance_record.space_code | space.space_code | NO ACTION |
| FK_maintenance_reporter | maintenance_record.reporter_id | user.user_id | NO ACTION |
| FK_maintenance_assigned | maintenance_record.assigned_staff_id | user.user_id | SET NULL |
