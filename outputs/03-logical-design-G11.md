# Logical Database Design — G11

## 1. Relational Schema

### 1.1 `user`
| Column | Type | Constraints |
|---|---|---|
| user_id | INT | PK, IDENTITY |
| full_name | NVARCHAR(100) | NOT NULL |
| email | NVARCHAR(255) | NOT NULL, UNIQUE |
| phone_number | NVARCHAR(20) | NULL |
| role | NVARCHAR(30) | NOT NULL, CHECK (role IN ('Student','Lecturer','TA','Facility Staff','Dept Admin','Facility Manager')) |
| department | NVARCHAR(100) | NOT NULL |
| account_status | NVARCHAR(20) | NOT NULL, CHECK (account_status IN ('Active','Inactive','Suspended')), DEFAULT 'Active' |

**Candidate keys:** email

### 1.2 `space`
| Column | Type | Constraints |
|---|---|---|
| space_code | NVARCHAR(20) | PK |
| space_name | NVARCHAR(100) | NOT NULL |
| space_type | NVARCHAR(30) | NOT NULL, CHECK (space_type IN ('Auditorium','Classroom','Computer Laboratory','Project Laboratory','Meeting Room','Student Workspace')) |
| building | NVARCHAR(100) | NOT NULL |
| floor | INT | NOT NULL, CHECK (floor >= 0) |
| room_number | NVARCHAR(20) | NOT NULL |
| capacity | INT | NOT NULL, CHECK (capacity > 0) |
| current_status | NVARCHAR(30) | NOT NULL, CHECK (current_status IN ('Available','In Use','Under Maintenance','Temporarily Closed','Retired')), DEFAULT 'Available' |
| usage_policy | NVARCHAR(MAX) | NULL |

**Candidate keys:** (building, floor, room_number)

### 1.3 `facility_catalog`
| Column | Type | Constraints |
|---|---|---|
| catalog_id | INT | PK, IDENTITY |
| name | NVARCHAR(100) | NOT NULL, UNIQUE |
| description | NVARCHAR(500) | NULL |
| is_trackable | BIT | NOT NULL, DEFAULT 0 |

**Candidate keys:** name

### 1.4 `space_facility`
| Column | Type | Constraints |
|---|---|---|
| space_code | NVARCHAR(20) | PK, FK → space(space_code) |
| catalog_id | INT | PK, FK → facility_catalog(catalog_id) |
| quantity | INT | NOT NULL, CHECK (quantity > 0) |

### 1.5 `facility_asset`
| Column | Type | Constraints |
|---|---|---|
| asset_id | INT | PK, IDENTITY |
| asset_tag | NVARCHAR(50) | NOT NULL, UNIQUE |
| catalog_id | INT | NOT NULL, FK → facility_catalog(catalog_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → space(space_code) |
| status | NVARCHAR(20) | NOT NULL, CHECK (status IN ('Working','Under Repair','Retired')), DEFAULT 'Working' |

**Candidate keys:** asset_tag

### 1.6 `booking_request`
| Column | Type | Constraints |
|---|---|---|
| booking_id | INT | PK, IDENTITY |
| requester_id | INT | NOT NULL, FK → user(user_id) |
| space_code | NVARCHAR(20) | NOT NULL, FK → space(space_code) |
| requested_start_time | DATETIME2 | NOT NULL |
| requested_end_time | DATETIME2 | NOT NULL, CHECK (requested_end_time > requested_start_time) |
| purpose | NVARCHAR(30) | NOT NULL, CHECK (purpose IN ('Lecture','Examination','Seminar','Workshop','Meeting','Student Activity','Administrative Event')) |
| expected_participants | INT | NOT NULL, CHECK (expected_participants > 0) |
| status | NVARCHAR(20) | NOT NULL, CHECK (status IN ('Pending','Approved','Rejected','Cancelled','Checked In','Completed','No-Show')), DEFAULT 'Pending' |
| created_at | DATETIME2 | NOT NULL, DEFAULT GETUTCDATE() |

### 1.7 `booking_decision`
| Column | Type | Constraints |
|---|---|---|
| booking_id | INT | PK, FK → booking_request(booking_id) |
| staff_id | INT | NOT NULL, FK → user(user_id) |
| decision | NVARCHAR(10) | NOT NULL, CHECK (decision IN ('Approved','Rejected')) |
| decision_time | DATETIME2 | NOT NULL |
| decision_note | NVARCHAR(500) | NULL |
| rejection_reason | NVARCHAR(500) | NULL, CHECK (rejection_reason IS NOT NULL WHEN decision = 'Rejected') |

### 1.8 `booking_session`
| Column | Type | Constraints |
|---|---|---|
| booking_id | INT | PK, FK → booking_request(booking_id) |
| actual_start_time | DATETIME2 | NOT NULL |
| checked_in_by | INT | NOT NULL, FK → user(user_id) |
| initial_condition | NVARCHAR(500) | NULL |
| actual_end_time | DATETIME2 | NULL |
| final_condition | NVARCHAR(500) | NULL |
| usage_notes | NVARCHAR(MAX) | NULL |

### 1.9 `maintenance_record`
| Column | Type | Constraints |
|---|---|---|
| maintenance_id | INT | PK, IDENTITY |
| space_code | NVARCHAR(20) | NOT NULL, FK → space(space_code) |
| reported_by | INT | NOT NULL, FK → user(user_id) |
| assigned_to | INT | NULL, FK → user(user_id) |
| problem_description | NVARCHAR(500) | NOT NULL |
| problem_type | NVARCHAR(30) | NOT NULL, CHECK (problem_type IN ('Broken Projector','AC Failure','Damaged Furniture','Cleaning Issue','Network Problem')) |
| start_time | DATETIME2 | NOT NULL |
| completion_time | DATETIME2 | NULL |
| status | NVARCHAR(20) | NOT NULL, CHECK (status IN ('Reported','In Progress','Completed')), DEFAULT 'Reported' |
| result_note | NVARCHAR(MAX) | NULL |

## 2. Referential Integrity Summary

| FK Constraint | From Table | From Column(s) | To Table | To Column(s) |
|---|---|---|---|---|
| FK_booking_request_requester | booking_request | requester_id | user | user_id |
| FK_booking_request_space | booking_request | space_code | space | space_code |
| FK_booking_decision_booking | booking_decision | booking_id | booking_request | booking_id |
| FK_booking_decision_staff | booking_decision | staff_id | user | user_id |
| FK_booking_session_booking | booking_session | booking_id | booking_request | booking_id |
| FK_booking_session_staff | booking_session | checked_in_by | user | user_id |
| FK_space_facility_space | space_facility | space_code | space | space_code |
| FK_space_facility_catalog | space_facility | catalog_id | facility_catalog | catalog_id |
| FK_facility_asset_catalog | facility_asset | catalog_id | facility_catalog | catalog_id |
| FK_facility_asset_space | facility_asset | space_code | space | space_code |
| FK_maintenance_space | maintenance_record | space_code | space | space_code |
| FK_maintenance_reporter | maintenance_record | reported_by | user | user_id |
| FK_maintenance_assignee | maintenance_record | assigned_to | user | user_id |

## 3. Entity-to-Table Traceability

| Step 1 Entity | Logical Table | Step 5 DDL Table |
|---|---|---|
| User | user | user |
| Space | space | space |
| Facility Catalog | facility_catalog | facility_catalog |
| Space-Facility (associative) | space_facility | space_facility |
| Facility Asset | facility_asset | facility_asset |
| Booking Request | booking_request | booking_request |
| Booking Decision | booking_decision | booking_decision |
| Booking Session | booking_session | booking_session |
| Maintenance Record | maintenance_record | maintenance_record |

## 4. Business Rule Enforcement

| # | Business Rule | Enforced By |
|---|---|---|
| 1 | Unique account (email) | UNIQUE on user.email |
| 2 | No overlapping approved bookings | Application logic / CHECK constraint on time window (can be enforced via trigger or app) |
| 3 | Unavailable space cannot be booked | Application logic checking space.current_status |
| 4 | Decision must log staff, time, note | NOT NULL columns on booking_decision |
| 5 | Rejection reason required | CHECK constraint on booking_decision |
| 6 | Check-in records | NOT NULL columns on booking_session |
| 7 | Check-out records | Columns available on booking_session |
| 8 | Maintenance blocks booking | Application logic checking maintenance_record.status |
| 9 | Historical preservation | No DELETE CASCADE on history tables; soft-delete via status |
