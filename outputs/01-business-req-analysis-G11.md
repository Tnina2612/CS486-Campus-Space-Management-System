# 01 — Business Requirement Analysis

## 1. Business Purpose

The School of Computer Science wants to build a database system to manage the booking and usage of shared campus spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, student workspaces). The system must replace the current manual process (email, phone, spreadsheets) to avoid overlapping bookings, prevent use of unavailable spaces, and maintain a complete usage history.

## 2. Actors / User Roles

| Role | Description |
|------|-------------|
| Student | Submits booking requests for student activities. |
| Lecturer | Submits booking requests for lectures, examinations, seminars. |
| Teaching Assistant | Submits booking requests for teaching support activities. |
| Facility Staff | Approves/rejects bookings, checks in/out sessions, records maintenance. |
| Department Administrator | Manages spaces, users, and reports. |
| Facility Manager | Oversees the entire system, views analytics, manages maintenance. |

All actors have a university account.

## 3. Entities, Attributes, and Data Types

### USER
| Attribute | Type | Notes |
|-----------|------|-------|
| user_id | PK (INT) | Unique identifier |
| full_name | NVARCHAR(100) | |
| email | NVARCHAR(255) | Unique |
| phone | NVARCHAR(20) | |
| role | NVARCHAR(50) | student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager |
| department | NVARCHAR(100) | |
| account_status | NVARCHAR(20) | active, inactive, suspended |

### SPACE
| Attribute | Type | Notes |
|-----------|------|-------|
| space_code | PK (NVARCHAR(20)) | Unique identifier, e.g., "A101" |
| space_name | NVARCHAR(100) | |
| space_type | NVARCHAR(50) | auditorium, classroom, computer_lab, project_lab, meeting_room, workspace |
| building | NVARCHAR(100) | |
| floor | INT | |
| room_number | NVARCHAR(20) | |
| capacity | INT | |
| current_status | NVARCHAR(20) | available, in_use, under_maintenance, temporarily_closed, retired |
| usage_policy | NVARCHAR(MAX) | |

### FACILITY_CATALOG
| Attribute | Type | Notes |
|-----------|------|-------|
| catalog_id | PK (INT) | Unique identifier |
| facility_name | NVARCHAR(100) | e.g., 'Projector', 'Whiteboard' |
| description | NVARCHAR(MAX) | |
| is_trackable | BIT | 1 = trackable asset, 0 = non-trackable quantity-based item |

### SPACE_FACILITY (resolves SPACE ⟷ FACILITY_CATALOG M:N)
| Attribute | Type | Notes |
|-----------|------|-------|
| space_code | PK, FK (NVARCHAR(20)) | References SPACE |
| catalog_id | PK, FK (INT) | References FACILITY_CATALOG |
| quantity | INT | Number of items for non-trackable facilities |

### FACILITY_ASSET (trackable high-value assets)
| Attribute | Type | Notes |
|-----------|------|-------|
| asset_id | PK (INT) | Unique identifier |
| catalog_id | FK (INT) | References FACILITY_CATALOG |
| space_code | FK (NVARCHAR(20)) | Current location (references SPACE) |
| asset_tag | NVARCHAR(50) | UNIQUE |
| status | NVARCHAR(20) | available, in_use, under_maintenance, retired |

### BOOKING (stores only the initial request)
| Attribute | Type | Notes |
|-----------|------|-------|
| booking_id | PK (INT) | Unique identifier |
| requester_id | FK (INT) | References USER |
| space_code | FK (NVARCHAR(20)) | References SPACE |
| requested_start | DATETIME2 | |
| requested_end | DATETIME2 | |
| purpose | NVARCHAR(50) | lecture, examination, seminar, workshop, meeting, student_activity, administrative_event |
| expected_participants | INT | |
| status | NVARCHAR(20) | pending, approved, rejected, cancelled, checked_in, completed, no_show |
| created_at | DATETIME2 | |

### APPROVAL (strict 1-to-1 with BOOKING)
| Attribute | Type | Notes |
|-----------|------|-------|
| approval_id | PK (INT) | Unique identifier |
| booking_id | FK (INT), UNIQUE | References BOOKING |
| reviewer_id | FK (INT) | References USER (facility staff/manager) |
| decision_time | DATETIME2 | |
| decision_note | NVARCHAR(MAX) | |
| rejection_reason | NVARCHAR(MAX) | NULL if approved |

### USAGE_SESSION (strict 1-to-1 with BOOKING)
| Attribute | Type | Notes |
|-----------|------|-------|
| session_id | PK (INT) | Unique identifier |
| booking_id | FK (INT), UNIQUE | References BOOKING |
| checked_in_by | FK (INT) | References USER (facility staff) |
| actual_start_time | DATETIME2 | |
| initial_condition | NVARCHAR(MAX) | |
| checked_out_by | FK (INT) | References USER (facility staff), NULL if not checked out |
| actual_end_time | DATETIME2 | NULL if not checked out |
| final_condition | NVARCHAR(MAX) | NULL if not checked out |
| usage_notes | NVARCHAR(MAX) | NULL if not checked out |

### MAINTENANCE_RECORD
| Attribute | Type | Notes |
|-----------|------|-------|
| maintenance_id | PK (INT) | Unique identifier |
| space_code | FK (NVARCHAR(20)) | References SPACE |
| reporter_id | FK (INT) | References USER |
| assigned_staff_id | FK (INT) | References USER, NULL if not assigned |
| problem_description | NVARCHAR(MAX) | |
| problem_category | NVARCHAR(50) | broken_projector, ac_failure, damaged_furniture, cleaning, network, other |
| start_time | DATETIME2 | |
| completion_time | DATETIME2 | NULL if not completed |
| status | NVARCHAR(20) | reported, in_progress, completed, cancelled |
| result_note | NVARCHAR(MAX) | |

## 4. Relationships and Cardinalities

| Entity 1 | Entity 2 | Cardinality | Description |
|----------|----------|-------------|-------------|
| USER | BOOKING | 1:N | One user can make many booking requests. |
| SPACE | BOOKING | 1:N | One space can have many bookings. |
| SPACE | FACILITY_CATALOG | M:N | Via SPACE_FACILITY; a space can have many facility types, a facility type can be in many spaces. |
| FACILITY_CATALOG | FACILITY_ASSET | 1:N | One catalog entry can have many trackable assets. |
| SPACE | FACILITY_ASSET | 1:N | One space can contain many trackable assets. |
| BOOKING | APPROVAL | 1:1 | Each booking has at most one approval decision. |
| BOOKING | USAGE_SESSION | 1:1 | Each booking has at most one usage session. |
| USER | APPROVAL | 1:N | One staff/manager can approve/reject many bookings. |
| USER | USAGE_SESSION (checked_in_by) | 1:N | One staff can check in many sessions. |
| USER | USAGE_SESSION (checked_out_by) | 1:N | One staff can check out many sessions. |
| SPACE | MAINTENANCE_RECORD | 1:N | One space can have many maintenance records. |
| USER | MAINTENANCE_RECORD (reports) | 1:N | A user can report many maintenance issues. |
| USER | MAINTENANCE_RECORD (assigned) | 1:N | A staff can be assigned to many maintenance tasks. |

## 5. Business Rules

1. **Unique booking constraint:** A space cannot have two approved bookings with overlapping time periods.
2. **Availability constraint:** A space that is under maintenance, temporarily closed, or retired cannot be booked.
3. **Status lifecycle:** Booking status flows: pending → approved/rejected → (if approved) checked_in → completed/no_show.
4. **Strict 1-to-1 approval:** A booking can have at most one approval record. If rejected, a rejection_reason must be recorded.
5. **Strict 1-to-1 usage session:** A booking can have at most one usage session.
6. **Trackable vs. non-trackable:** If `is_trackable = 0`, quantity is tracked via SPACE_FACILITY. If `is_trackable = 1`, individual assets are tracked via FACILITY_ASSET.
7. **Asset tag uniqueness:** Each FACILITY_ASSET.asset_tag must be unique.
8. **Maintenance blocks booking:** A space with an active maintenance record (status = reported or in_progress) cannot be booked.
9. **User account:** All users must have a university account with a unique email.
10. **Capacity check:** The expected_participants should not exceed the space capacity (application-level enforcement).
11. **Time validity:** requested_start must be before requested_end in a booking.
12. **History preservation:** Historical booking and maintenance records must be retained (no physical deletion).

## 6. Assumptions

- The system uses Microsoft SQL Server as the DBMS.
- Only facility staff or managers can approve/reject bookings.
- Check-in and check-out are performed by facility staff, not the requester.
- A "no-show" status is set when check-in does not occur within a reasonable time after the requested start time.
- Facility categories are predefined in the FACILITY_CATALOG table.
- Space codes are human-readable identifiers (e.g., "A101").
- USER.account_status values (active, inactive, suspended) are predefined system values.
- MAINTENANCE_RECORD.status values (reported, in_progress, completed, cancelled) are predefined system values.
- FACILITY_ASSET.status values (available, in_use, under_maintenance, retired) are predefined system values.
- MAINTENANCE_RECORD.problem_category values (broken_projector, ac_failure, damaged_furniture, cleaning, network, other) are predefined categories.

## 7. Open Questions

- What is the grace period for considering a booking as "no-show"?
- Should notifications be sent when a booking is approved/rejected/cancelled?
- Should there be a recurring booking feature for regular classes?
- What is the maximum advance booking window?
- Should there be a waitlist for popular spaces?
