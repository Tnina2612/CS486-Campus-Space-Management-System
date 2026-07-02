# Logical Database Design — G11

## 1. Relational Schema

### USER
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| user_id | NVARCHAR(50) | PK |
| full_name | NVARCHAR(100) | NOT NULL |
| email | NVARCHAR(255) | NOT NULL, UNIQUE |
| phone | NVARCHAR(20) | NULL |
| role | NVARCHAR(30) | NOT NULL, CHECK(role IN ('Student','Lecturer','TA','Facility Staff','Dept Admin','Facility Manager')) |
| department | NVARCHAR(100) | NOT NULL |
| account_status | NVARCHAR(20) | NOT NULL, CHECK(account_status IN ('Active','Inactive','Suspended')) |

Candidate Keys: (email)

---

### SPACE
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| space_code | NVARCHAR(20) | PK |
| space_name | NVARCHAR(100) | NOT NULL |
| space_type | NVARCHAR(50) | NOT NULL, CHECK(space_type IN ('Auditorium','Classroom','Computer Lab','Project Lab','Meeting Room','Student Workspace')) |
| building | NVARCHAR(100) | NOT NULL |
| floor | NVARCHAR(10) | NOT NULL |
| room_number | NVARCHAR(20) | NOT NULL |
| capacity | INT | NOT NULL, CHECK(capacity > 0) |
| current_status | NVARCHAR(20) | NOT NULL, CHECK(current_status IN ('Available','In Use','Under Maintenance','Temporarily Closed','Retired')) |
| usage_policy | NVARCHAR(MAX) | NULL |

---

### FACILITY_CATALOG
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| catalog_id | INT | PK, IDENTITY(1,1) |
| facility_name | NVARCHAR(100) | NOT NULL |
| is_trackable | BIT | NOT NULL |

Candidate Keys: (facility_name)

---

### SPACE_FACILITY
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| space_code | NVARCHAR(20) | PK, FK → SPACE(space_code) |
| catalog_id | INT | PK, FK → FACILITY_CATALOG(catalog_id) |
| quantity | INT | NOT NULL, CHECK(quantity > 0) |

---

### FACILITY_ASSET
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| asset_id | INT | PK, IDENTITY(1,1) |
| catalog_id | INT | NOT NULL, FK → FACILITY_CATALOG(catalog_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| asset_tag | NVARCHAR(100) | NOT NULL, UNIQUE |
| status | NVARCHAR(20) | NOT NULL, CHECK(status IN ('Working','Under Repair','Retired')) |

Candidate Keys: (asset_tag)

---

### BOOKING
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| booking_id | INT | PK, IDENTITY(1,1) |
| user_id | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| requested_start | DATETIME2 | NOT NULL |
| requested_end | DATETIME2 | NOT NULL, CHECK(requested_end > requested_start) |
| purpose | NVARCHAR(30) | NOT NULL, CHECK(purpose IN ('Lecture','Examination','Seminar','Workshop','Meeting','Student Activity','Admin Event')) |
| expected_participants | INT | NOT NULL, CHECK(expected_participants > 0) |
| status | NVARCHAR(20) | NOT NULL, CHECK(status IN ('Pending','Approved','Rejected','Cancelled','Checked In','Completed','No-show')) |

---

### APPROVAL
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| approval_id | INT | PK, IDENTITY(1,1) |
| booking_id | INT | NOT NULL, FK → BOOKING(booking_id), UNIQUE |
| staff_id | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| decision | NVARCHAR(20) | NOT NULL, CHECK(decision IN ('Approved','Rejected')) |
| decision_time | DATETIME2 | NOT NULL |
| decision_note | NVARCHAR(MAX) | NULL |
| rejection_reason | NVARCHAR(MAX) | NULL, CHECK(decision <> 'Rejected' OR rejection_reason IS NOT NULL) |

---

### USAGE_SESSION
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| session_id | INT | PK, IDENTITY(1,1) |
| booking_id | INT | NOT NULL, FK → BOOKING(booking_id), UNIQUE |
| checked_in_by | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| actual_start | DATETIME2 | NOT NULL |
| initial_condition | NVARCHAR(MAX) | NOT NULL |
| actual_end | DATETIME2 | NULL, CHECK(actual_end IS NULL OR actual_end > actual_start) |
| final_condition | NVARCHAR(MAX) | NULL |
| completed_by | NVARCHAR(50) | NULL, FK → USER(user_id) |
| usage_notes | NVARCHAR(MAX) | NULL |
| | | CHECK((actual_end IS NULL AND final_condition IS NULL AND completed_by IS NULL) OR (actual_end IS NOT NULL AND final_condition IS NOT NULL AND completed_by IS NOT NULL)) |

---

### MAINTENANCE_RECORD
| Column Name | Data Type | Constraints & Keys |
|-------------|-----------|-------------------|
| maintenance_id | INT | PK, IDENTITY(1,1) |
| space_code | NVARCHAR(20) | NOT NULL, FK → SPACE(space_code) |
| reporter_id | NVARCHAR(50) | NOT NULL, FK → USER(user_id) |
| assigned_staff_id | NVARCHAR(50) | NULL, FK → USER(user_id) |
| problem_description | NVARCHAR(MAX) | NOT NULL |
| problem_type | NVARCHAR(50) | NOT NULL, CHECK(problem_type IN ('Broken Projector','AC Failure','Damaged Furniture','Cleaning','Network Problem')) |
| start_time | DATETIME2 | NOT NULL |
| completion_time | DATETIME2 | NULL, CHECK(completion_time IS NULL OR completion_time > start_time) |
| status | NVARCHAR(20) | NOT NULL, CHECK(status IN ('Reported','In Progress','Completed','Cancelled')) |
| result_note | NVARCHAR(MAX) | NULL |

---

## 2. Summary of Referential Integrity

| From Table | From Column | To Table | To Column | ON UPDATE | ON DELETE |
|-----------|------------|---------|-----------|-----------|-----------|
| SPACE_FACILITY | space_code | SPACE | space_code | CASCADE | CASCADE |
| SPACE_FACILITY | catalog_id | FACILITY_CATALOG | catalog_id | NO ACTION | CASCADE |
| FACILITY_ASSET | catalog_id | FACILITY_CATALOG | catalog_id | NO ACTION | NO ACTION |
| FACILITY_ASSET | space_code | SPACE | space_code | CASCADE | NO ACTION |
| BOOKING | user_id | USER | user_id | CASCADE | NO ACTION |
| BOOKING | space_code | SPACE | space_code | CASCADE | NO ACTION |
| APPROVAL | booking_id | BOOKING | booking_id | NO ACTION | NO ACTION |
| APPROVAL | staff_id | USER | user_id | CASCADE | NO ACTION |
| USAGE_SESSION | booking_id | BOOKING | booking_id | NO ACTION | NO ACTION |
| USAGE_SESSION | checked_in_by | USER | user_id | CASCADE | NO ACTION |
| USAGE_SESSION | completed_by | USER | user_id | CASCADE | NO ACTION |
| MAINTENANCE_RECORD | space_code | SPACE | space_code | CASCADE | NO ACTION |
| MAINTENANCE_RECORD | reporter_id | USER | user_id | CASCADE | NO ACTION |
| MAINTENANCE_RECORD | assigned_staff_id | USER | user_id | CASCADE | NO ACTION |

---

## 3. Entity-to-Table Traceability

| Step 2 Entity | Step 3 Table | Notes |
|--------------|-------------|-------|
| USER | USER | Direct mapping |
| SPACE | SPACE | Direct mapping |
| FACILITY_CATALOG | FACILITY_CATALOG | Direct mapping |
| SPACE_FACILITY | SPACE_FACILITY | Associative entity with quantity attribute |
| FACILITY_ASSET | FACILITY_ASSET | Direct mapping |
| BOOKING | BOOKING | Direct mapping |
| APPROVAL | APPROVAL | Direct mapping |
| USAGE_SESSION | USAGE_SESSION | Direct mapping |
| MAINTENANCE_RECORD | MAINTENANCE_RECORD | Direct mapping |

---

## 4. Business Rule Enforcement

| Business Rule | Enforcement Mechanism |
|--------------|---------------------|
| Unique space code | PK on SPACE(space_code) |
| Unique email | UNIQUE on USER(email) |
| Unique asset tag | UNIQUE on FACILITY_ASSET(asset_tag) |
| No overlapping bookings | Deferred to application logic (cross-row validation across BOOKING table) |
| Unavailable spaces cannot be booked | Deferred to application logic (checks SPACE.current_status and MAINTENANCE_RECORD.active) |
| Strict 1-to-1 BOOKING → APPROVAL | UNIQUE constraint on APPROVAL(booking_id) |
| Strict 1-to-1 BOOKING → USAGE_SESSION | UNIQUE constraint on USAGE_SESSION(booking_id) |
| End time must be after start time | CHECK(requested_end > requested_start) on BOOKING |
| Rejection requires reason | CHECK(decision <> 'Rejected' OR rejection_reason IS NOT NULL) on APPROVAL |
| Session completion requires all fields | CHECK group constraint on USAGE_SESSION (actual_end, final_condition, completed_by all NULL or all NOT NULL) |
| Check-in must precede check-out | CHECK(actual_end IS NULL OR actual_end > actual_start) on USAGE_SESSION |
| Capacity must be positive | CHECK(capacity > 0) on SPACE |
| Expected participants must be positive | CHECK(expected_participants > 0) on BOOKING |
| Quantity must be positive | CHECK(quantity > 0) on SPACE_FACILITY |
| Maintenance completion must be after start | CHECK(completion_time IS NULL OR completion_time > start_time) on MAINTENANCE_RECORD |
| Role values | CHECK constraint on USER(role) |
| Space type values | CHECK constraint on SPACE(space_type) |
| Booking purpose values | CHECK constraint on BOOKING(purpose) |
| Status value lists | CHECK constraints on all status columns |

---

## 5. Conversion Notes

- **M:N Resolution:** The M:N relationship between SPACE and FACILITY_CATALOG was resolved via the SPACE_FACILITY associative table, which carries the `quantity` attribute as required by the Catalog vs. Asset Hybrid Pattern.
- **1:1 Relationships:** BOOKING → APPROVAL and BOOKING → USAGE_SESSION are enforced as 1:1 via UNIQUE constraints on the FK column `booking_id` in the child tables. This allows at most one child per parent while keeping them as separate tables for lifecycle normalization.
- **CASCADE / NO ACTION Logic:** 
  - SPACE_FACILITY is a pure junction table, so ON DELETE CASCADE is applied to both FKs.
  - All other tables contain historical/audit data; ON DELETE NO ACTION prevents accidental data loss.
  - ON UPDATE CASCADE for FKs referencing natural keys (`space_code`, `user_id`); ON UPDATE NO ACTION for FKs referencing surrogate keys (`catalog_id`, `booking_id`).
- **Conditional Constraints:** The rejection_reason requirement and the session completion grouping are enforced via CHECK constraints within the same table, as mandated by the anti-delegation rule.
