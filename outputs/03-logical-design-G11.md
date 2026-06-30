# 03 — Logical Database Design

## 1. Relational Schema

### USER
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| user_id | INT | PK, IDENTITY(1,1) |
| full_name | NVARCHAR(100) | NOT NULL |
| email | NVARCHAR(255) | NOT NULL, UNIQUE |
| phone | NVARCHAR(20) | NULL |
| role | NVARCHAR(50) | NOT NULL, CHECK(role IN ('student','lecturer','teaching_assistant','facility_staff','department_administrator','facility_manager')) |
| department | NVARCHAR(100) | NULL |
| account_status | NVARCHAR(20) | NOT NULL, DEFAULT('active'), CHECK(account_status IN ('active','inactive','suspended')) |

**Candidate Keys:** email

---

### SPACE
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| space_code | NVARCHAR(20) | PK |
| space_name | NVARCHAR(100) | NOT NULL |
| space_type | NVARCHAR(50) | NOT NULL, CHECK(space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','workspace')) |
| building | NVARCHAR(100) | NOT NULL |
| floor | INT | NOT NULL |
| room_number | NVARCHAR(20) | NOT NULL |
| capacity | INT | NOT NULL, CHECK(capacity > 0) |
| current_status | NVARCHAR(20) | NOT NULL, DEFAULT('available'), CHECK(current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired')) |
| usage_policy | NVARCHAR(MAX) | NULL |

---

### FACILITY_CATALOG
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| catalog_id | INT | PK, IDENTITY(1,1) |
| facility_name | NVARCHAR(100) | NOT NULL, UNIQUE |
| description | NVARCHAR(MAX) | NULL |
| is_trackable | BIT | NOT NULL, DEFAULT(0) |

**Candidate Keys:** facility_name

---

### SPACE_FACILITY (resolves SPACE ⟷ FACILITY_CATALOG M:N)
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| space_code | NVARCHAR(20) | PK, FK → SPACE(space_code) |
| catalog_id | INT | PK, FK → FACILITY_CATALOG(catalog_id) |
| quantity | INT | NOT NULL, CHECK(quantity > 0) |

---

### FACILITY_ASSET
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| asset_id | INT | PK, IDENTITY(1,1) |
| catalog_id | INT | NOT NULL, FK → FACILITY_CATALOG(catalog_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| asset_tag | NVARCHAR(50) | NOT NULL, UNIQUE |
| status | NVARCHAR(20) | NOT NULL, DEFAULT('available'), CHECK(status IN ('available','in_use','under_maintenance','retired')) |

**Candidate Keys:** asset_tag

---

### BOOKING
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| booking_id | INT | PK, IDENTITY(1,1) |
| requester_id | INT | NOT NULL, FK → USER(user_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| requested_start | DATETIME2 | NOT NULL |
| requested_end | DATETIME2 | NOT NULL |
| purpose | NVARCHAR(50) | NOT NULL, CHECK(purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')) |
| expected_participants | INT | NOT NULL, CHECK(expected_participants > 0) |
| status | NVARCHAR(20) | NOT NULL, DEFAULT('pending'), CHECK(status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')) |
| created_at | DATETIME2 | NOT NULL, DEFAULT(GETDATE()) |
| CONSTRAINT CK_booking_time_range | | CHECK(requested_start < requested_end) |

---

### APPROVAL
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| approval_id | INT | PK, IDENTITY(1,1) |
| booking_id | INT | NOT NULL, FK → BOOKING(booking_id), UNIQUE |
| reviewer_id | INT | NOT NULL, FK → USER(user_id) |
| decision_time | DATETIME2 | NOT NULL, DEFAULT(GETDATE()) |
| decision_note | NVARCHAR(MAX) | NULL |
| rejection_reason | NVARCHAR(MAX) | NULL |

**Note:** Conditionally required rejection_reason (when booking status = 'rejected') is enforced at application level.

---

### USAGE_SESSION
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| session_id | INT | PK, IDENTITY(1,1) |
| booking_id | INT | NOT NULL, FK → BOOKING(booking_id), UNIQUE |
| checked_in_by | INT | NOT NULL, FK → USER(user_id) |
| actual_start_time | DATETIME2 | NOT NULL |
| initial_condition | NVARCHAR(MAX) | NOT NULL |
| checked_out_by | INT | NULL, FK → USER(user_id) |
| actual_end_time | DATETIME2 | NULL |
| final_condition | NVARCHAR(MAX) | NULL |
| usage_notes | NVARCHAR(MAX) | NULL |
| CONSTRAINT CK_session_time_range | | CHECK(actual_end_time IS NULL OR actual_end_time >= actual_start_time) |

---

### MAINTENANCE_RECORD
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|---------------------|
| maintenance_id | INT | PK, IDENTITY(1,1) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| reporter_id | INT | NOT NULL, FK → USER(user_id) |
| assigned_staff_id | INT | NULL, FK → USER(user_id) |
| problem_description | NVARCHAR(MAX) | NOT NULL |
| problem_category | NVARCHAR(50) | NOT NULL, CHECK(problem_category IN ('broken_projector','ac_failure','damaged_furniture','cleaning','network','other')) |
| start_time | DATETIME2 | NOT NULL |
| completion_time | DATETIME2 | NULL |
| status | NVARCHAR(20) | NOT NULL, DEFAULT('reported'), CHECK(status IN ('reported','in_progress','completed','cancelled')) |
| result_note | NVARCHAR(MAX) | NULL |
| CONSTRAINT CK_maint_time_range | | CHECK(completion_time IS NULL OR completion_time >= start_time) |

---

## 2. Summary of Referential Integrity

| From Table | From Column | To Table | To Column | ON UPDATE | ON DELETE |
|------------|-------------|----------|-----------|-----------|-----------|
| SPACE_FACILITY | space_code | SPACE | space_code | CASCADE | NO ACTION |
| SPACE_FACILITY | catalog_id | FACILITY_CATALOG | catalog_id | NO ACTION | NO ACTION |
| FACILITY_ASSET | catalog_id | FACILITY_CATALOG | catalog_id | NO ACTION | NO ACTION |
| FACILITY_ASSET | space_code | SPACE | space_code | CASCADE | NO ACTION |
| BOOKING | requester_id | USER | user_id | NO ACTION | NO ACTION |
| BOOKING | space_code | SPACE | space_code | CASCADE | NO ACTION |
| APPROVAL | booking_id | BOOKING | booking_id | NO ACTION | NO ACTION |
| APPROVAL | reviewer_id | USER | user_id | NO ACTION | NO ACTION |
| USAGE_SESSION | booking_id | BOOKING | booking_id | NO ACTION | NO ACTION |
| USAGE_SESSION | checked_in_by | USER | user_id | NO ACTION | NO ACTION |
| USAGE_SESSION | checked_out_by | USER | user_id | NO ACTION | NO ACTION |
| MAINTENANCE_RECORD | space_code | SPACE | space_code | CASCADE | NO ACTION |
| MAINTENANCE_RECORD | reporter_id | USER | user_id | NO ACTION | NO ACTION |
| MAINTENANCE_RECORD | assigned_staff_id | USER | user_id | NO ACTION | NO ACTION |

**Rationale:**
- **ON UPDATE CASCADE** is used for `space_code` references because space_code is a natural key that may need updating (e.g., room renumbering). Changes will propagate to all child tables.
- **ON UPDATE NO ACTION** is used for surrogate keys (INT IDENTITY) which should never change.
- **ON DELETE NO ACTION** is used universally to enforce the business rule that historical data must be preserved. Deletion of any parent record is prevented when child records exist.

---

## 3. Entity-to-Table Traceability

| Step 2 Entity | Step 3 Table | Mapping Notes |
|---------------|-------------|---------------|
| USER | USER | Direct mapping |
| SPACE | SPACE | Direct mapping |
| FACILITY_CATALOG | FACILITY_CATALOG | Direct mapping |
| SPACE_FACILITY | SPACE_FACILITY | Associative entity resolving M:N SPACE ⟷ FACILITY_CATALOG |
| FACILITY_ASSET | FACILITY_ASSET | Direct mapping |
| BOOKING | BOOKING | Direct mapping |
| APPROVAL | APPROVAL | Direct mapping, UNIQUE(booking_id) enforces 1:1 |
| USAGE_SESSION | USAGE_SESSION | Direct mapping, UNIQUE(booking_id) enforces 1:1 |
| MAINTENANCE_RECORD | MAINTENANCE_RECORD | Direct mapping |

---

## 4. Business Rule Enforcement

| # | Business Rule | Enforcement Mechanism |
|---|---------------|----------------------|
| 1 | No overlapping approved bookings | Application-level or trigger; requires CHECK on (space_code, time range) filtered by status = 'approved' |
| 2 | Unavailable spaces cannot be booked | Application-level; check SPACE.current_status before creating BOOKING |
| 3 | Booking status lifecycle | CHECK(status IN (...)) + application logic |
| 4 | 1-to-1 booking ↔ approval | UNIQUE(booking_id) on APPROVAL table |
| 5 | 1-to-1 booking ↔ usage session | UNIQUE(booking_id) on USAGE_SESSION table |
| 6 | Trackable vs non-trackable | Application logic based on FACILITY_CATALOG.is_trackable |
| 7 | Unique asset tag | UNIQUE(asset_tag) on FACILITY_ASSET |
| 8 | Maintenance blocks booking | Application-level; check MAINTENANCE_RECORD active status before creating BOOKING |
| 9 | Unique email per user | UNIQUE(email) on USER |
| 10 | Capacity check | Application-level; compare expected_participants vs SPACE.capacity |
| 11 | requested_start < requested_end | CHECK(requested_start < requested_end) on BOOKING |
| 12 | History preservation (no physical delete) | ON DELETE NO ACTION on all FKs |

---

## 5. Conversion Notes

- **M:N Resolution:** The SPACE ⟷ FACILITY_CATALOG many-to-many relationship from the ERD is resolved via the SPACE_FACILITY associative table, which also carries a quantity attribute for non-trackable items.
- **1:1 Relationships:** The BOOKING ⟷ APPROVAL and BOOKING ⟷ USAGE_SESSION strict 1:1 relationships are enforced by placing a UNIQUE constraint on the foreign key column (booking_id) in APPROVAL and USAGE_SESSION. This restricts each booking to at most one approval and at most one usage session.
- **Surrogate Keys:** INT IDENTITY surrogate keys are used for USER, FACILITY_CATALOG, FACILITY_ASSET, BOOKING, APPROVAL, USAGE_SESSION, and MAINTENANCE_RECORD to decouple business logic from primary key values.
- **Natural Keys:** SPACE uses space_code (NVARCHAR(20)) as its natural key PK. This enables human-readable references and simplifies cascading updates.
- **CASCADE/NO ACTION:** ON UPDATE CASCADE is chosen for space_code FK references to allow space code renumbering. ON DELETE NO ACTION is chosen everywhere to prevent accidental loss of historical records.
- **Nullable Columns:** checked_out_by, actual_end_time, final_condition, usage_notes are NULLable because a session may not have been checked out yet. assigned_staff_id, completion_time, result_note are NULLable because a maintenance request may not yet be assigned or completed. initial_condition is NOT NULL because the requirement mandates its recording at check-in.
