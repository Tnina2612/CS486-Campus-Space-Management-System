# Logical Database Design - G11

## 1. Relational Schema

### TABLE: `users`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| user_id | INT | IDENTITY(1,1) PRIMARY KEY |
| full_name | NVARCHAR(255) | NOT NULL |
| email | NVARCHAR(255) | NOT NULL UNIQUE |
| phone_number | NVARCHAR(20) | NOT NULL |
| role | NVARCHAR(50) | NOT NULL CHECK (role IN ('Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager')) |
| department | NVARCHAR(100) | NOT NULL |
| account_status | NVARCHAR(20) | NOT NULL DEFAULT 'Active' |

> Candidate Key: email

---

### TABLE: `spaces`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| space_id | INT | IDENTITY(1,1) PRIMARY KEY |
| space_code | NVARCHAR(20) | NOT NULL UNIQUE |
| space_name | NVARCHAR(100) | NOT NULL |
| space_type | NVARCHAR(50) | NOT NULL |
| building | NVARCHAR(100) | NOT NULL |
| floor | INT | NOT NULL |
| room_number | NVARCHAR(20) | NOT NULL |
| capacity | INT | NOT NULL CHECK (capacity > 0) |
| current_status | NVARCHAR(20) | NOT NULL CHECK (current_status IN ('Available', 'In Use', 'Under Maintenance', 'Temporarily Closed', 'Retired')) |
| usage_policy | NVARCHAR(MAX) | |

> Candidate Key: space_code

---

### TABLE: `facility_catalog`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| catalog_id | INT | IDENTITY(1,1) PRIMARY KEY |
| facility_name | NVARCHAR(100) | NOT NULL |
| is_trackable | BIT | NOT NULL |

---

### TABLE: `space_facility`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| space_id | INT | NOT NULL PK FK REFERENCES spaces(space_id) |
| catalog_id | INT | NOT NULL PK FK REFERENCES facility_catalog(catalog_id) |
| quantity | INT | NOT NULL CHECK (quantity >= 0) |

> Primary Key: (space_id, catalog_id)

---

### TABLE: `facility_assets`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| asset_id | INT | IDENTITY(1,1) PRIMARY KEY |
| asset_tag | NVARCHAR(50) | NOT NULL UNIQUE |
| space_id | INT | NOT NULL FK REFERENCES spaces(space_id) |
| catalog_id | INT | NOT NULL FK REFERENCES facility_catalog(catalog_id) |
| status | NVARCHAR(50) | NOT NULL |

> Candidate Key: asset_tag

---

### TABLE: `bookings`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| booking_id | INT | IDENTITY(1,1) PRIMARY KEY |
| user_id | INT | NOT NULL FK REFERENCES users(user_id) |
| space_id | INT | NOT NULL FK REFERENCES spaces(space_id) |
| start_time | DATETIME2 | NOT NULL |
| end_time | DATETIME2 | NOT NULL CHECK (end_time > start_time) |
| purpose | NVARCHAR(50) | NOT NULL CHECK (purpose IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student Activity', 'Administrative Event')) |
| expected_participants | INT | CHECK (expected_participants > 0) |
| status | NVARCHAR(20) | NOT NULL CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked In', 'Completed', 'No-show')) |

---

### TABLE: `approvals`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| approval_id | INT | IDENTITY(1,1) PRIMARY KEY |
| booking_id | INT | NOT NULL UNIQUE FK REFERENCES bookings(booking_id) |
| staff_id | INT | NOT NULL FK REFERENCES users(user_id) |
| decision_time | DATETIME2 | NOT NULL |
| decision_note | NVARCHAR(MAX) | |
| rejection_reason | NVARCHAR(MAX) | |

> **Note on BR-04:** `rejection_reason` is conditionally mandatory when `bookings.status = 'Rejected'`. This is a cross-table dependency (status in `bookings`, reason in `approvals`) and is deferred to application logic.

---

### TABLE: `usage_sessions`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| session_id | INT | IDENTITY(1,1) PRIMARY KEY |
| booking_id | INT | NOT NULL UNIQUE FK REFERENCES bookings(booking_id) |
| staff_id | INT | FK REFERENCES users(user_id) |
| actual_start_time | DATETIME2 | |
| actual_end_time | DATETIME2 | CHECK (actual_end_time > actual_start_time) |
| initial_condition | NVARCHAR(MAX) | |
| final_condition | NVARCHAR(MAX) | |
| usage_notes | NVARCHAR(MAX) | |

---

### TABLE: `maintenance_records`

| Column Name | Data Type | Constraints & Keys |
| :--- | :--- | :--- |
| maintenance_id | INT | IDENTITY(1,1) PRIMARY KEY |
| space_id | INT | NOT NULL FK REFERENCES spaces(space_id) |
| reporter_id | INT | NOT NULL FK REFERENCES users(user_id) |
| assigned_staff_id | INT | FK REFERENCES users(user_id) |
| problem_description | NVARCHAR(MAX) | NOT NULL |
| start_time | DATETIME2 | NOT NULL |
| completion_time | DATETIME2 | |
| status | NVARCHAR(20) | NOT NULL |
| result_note | NVARCHAR(MAX) | |

> **Note:** Maintenance `status` has no CHECK constraint because values are not enumerated in Step 1 (see OQ-01).

---

## 2. Summary of Referential Integrity

| From Table | From Column | To Table | To Column | ON UPDATE | ON DELETE |
| :--- | :--- | :--- | :--- | :--- | :--- |
| space_facility | space_id | spaces | space_id | CASCADE | CASCADE |
| space_facility | catalog_id | facility_catalog | catalog_id | CASCADE | CASCADE |
| facility_assets | space_id | spaces | space_id | NO ACTION | NO ACTION |
| facility_assets | catalog_id | facility_catalog | catalog_id | NO ACTION | NO ACTION |
| bookings | user_id | users | user_id | NO ACTION | NO ACTION |
| bookings | space_id | spaces | space_id | NO ACTION | NO ACTION |
| approvals | booking_id | bookings | booking_id | NO ACTION | NO ACTION |
| approvals | staff_id | users | user_id | NO ACTION | NO ACTION |
| usage_sessions | booking_id | bookings | booking_id | NO ACTION | NO ACTION |
| usage_sessions | staff_id | users | user_id | NO ACTION | NO ACTION |
| maintenance_records | space_id | spaces | space_id | NO ACTION | NO ACTION |
| maintenance_records | reporter_id | users | user_id | NO ACTION | NO ACTION |
| maintenance_records | assigned_staff_id | users | user_id | NO ACTION | NO ACTION |

**Rationale:**
- `space_facility` (junction table): CASCADE — removing a parent cleans up the mapping.
- All other tables: NO ACTION — preserves historical/audit records.
- All FKs reference surrogate `INT IDENTITY` keys (immutable), so ON UPDATE NO ACTION is correct.

---

## 3. Entity-to-Table Traceability

| Step 2 Entity (ERD) | Step 3 Table |
| :--- | :--- |
| USER | users |
| SPACE | spaces |
| FACILITY_CATALOG | facility_catalog |
| SPACE_FACILITY | space_facility |
| FACILITY_ASSET | facility_assets |
| BOOKING | bookings |
| APPROVAL | approvals |
| USAGE_SESSION | usage_sessions |
| MAINTENANCE_RECORD | maintenance_records |

---

## 4. Business Rule Enforcement

| Rule ID | Description | Enforcement |
| :--- | :--- | :--- |
| BR-01 | No overlapping approved bookings | Deferred to application (cross-row validation) |
| BR-02 | Unavailable spaces cannot be booked | Deferred to application (cross-table validation) |
| BR-03 | Approval records staff, time, note | FK + NOT NULL on `approvals` enforce structural recording |
| BR-04 | Rejection reason required when rejected | Cross-table dependency — deferred to application |
| BR-05 | Check-in: start time, staff, initial condition | Columns in `usage_sessions` (filled at check-in) |
| BR-06 | Check-out: end time, final condition, notes | Columns in `usage_sessions` (filled at check-out) |
| BR-07 | Historical record preservation | ON DELETE NO ACTION on all transactional FK relationships |
| BR-08 | Staff view queries | Supported by SQL queries against the relational schema |
| BR-09 | Strict 1:1 lifecycle | UNIQUE constraint on `booking_id` in `approvals` and `usage_sessions` |
| BR-10 | Hybrid facility pattern | Separate tables: `facility_catalog`, `space_facility`, `facility_assets` |

---

## 5. Conversion Notes

- **M:N Resolution:** SPACE ↔ FACILITY_CATALOG resolved via associative table `space_facility` with business attribute `quantity`.
- **1:1 Enforcement:** BOOKING ↔ APPROVAL and BOOKING ↔ USAGE_SESSION enforced with `UNIQUE` on FK `booking_id` in child tables.
- **Surrogate Keys:** All tables use `INT IDENTITY(1,1)`. Natural keys (`space_code`, `asset_tag`, `email`) are `UNIQUE`.
- **CASCADE vs NO ACTION:** `space_facility` uses CASCADE (pure junction). All other tables use NO ACTION (historical preservation).
- **Enum Gaps:** Maintenance `status` has no CHECK (values not enumerated — see OQ-01).
- **Column Changes:** The ERD used natural keys conceptually. The logical schema replaces these with surrogate `INT IDENTITY` FKs (e.g., `space_id` replaces `space_code` as FK). No attributes were added beyond Step 2 definitions.
