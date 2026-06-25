# Business Requirement Analysis — G11

## 1. Business Purpose
The School of Computer Science manages several shared physical spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces) used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. Currently, booking handling is manual. The School wants a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization — ensuring fair scheduling, avoiding overlapping bookings, preventing use of unavailable spaces, and preserving usage history.

## 2. Actors

| Actor | Description |
|---|---|
| Student | A university student who may request space booking |
| Lecturer | A faculty member who may request space booking |
| Teaching Assistant | A TA who may request space booking |
| Facility Staff | Staff responsible for checking in/out bookings, processing maintenance, managing spaces |
| Department Administrator | Administrator who may oversee booking processes |
| Facility Manager | Manager who oversees facility operations and may approve/reject bookings |

## 3. Entities and Attributes

### 3.1 User (`user`)
| Attribute | Description |
|---|---|
| user_id | Primary key, unique identifier |
| full_name | User's full name |
| email | Email address |
| phone_number | Contact phone number |
| role | Student, Lecturer, TA, Facility Staff, Dept Admin, Facility Manager |
| department | Department name |
| account_status | Active, inactive, suspended |

### 3.2 Space (`space`)
| Attribute | Description |
|---|---|
| space_code | Primary key, unique code |
| space_name | Name of the space |
| space_type | Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace |
| building | Building name |
| floor | Floor number |
| room_number | Room number |
| capacity | Maximum occupancy |
| current_status | Available, In Use, Under Maintenance, Temporarily Closed, Retired |
| usage_policy | Text describing rules for using the space |

### 3.3 Facility Catalog (`facility_catalog`) — Catalog vs. Asset Hybrid Pattern
| Attribute | Description |
|---|---|
| catalog_id | Primary key, unique identifier |
| name | Name of facility type (e.g., 'Projector', 'Whiteboard') |
| description | Optional description |
| is_trackable | BIT flag: 1 = high-value/trackable asset, 0 = non-trackable |

### 3.4 Space-Facility Mapping (`space_facility`) — M:N associative
| Attribute | Description |
|---|---|
| space_code | FK → space.space_code |
| catalog_id | FK → facility_catalog.catalog_id |
| quantity | Integer count for non-trackable items |

### 3.5 Facility Asset (`facility_asset`) — Trackable assets
| Attribute | Description |
|---|---|
| asset_id | Primary key |
| asset_tag | Unique tag/identifier |
| catalog_id | FK → facility_catalog.catalog_id |
| space_code | FK → space.space_code (current location) |
| status | Working, Under Repair, Retired |

### 3.6 Booking Request (`booking_request`)
| Attribute | Description |
|---|---|
| booking_id | Primary key |
| requester_id | FK → user.user_id (who submitted) |
| space_code | FK → space.space_code |
| requested_start_time | Datetime of requested start |
| requested_end_time | Datetime of requested end |
| purpose | Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event |
| expected_participants | Number of participants |
| status | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-Show |
| created_at | Timestamp of submission |

### 3.7 Booking Decision (`booking_decision`)
| Attribute | Description |
|---|---|
| booking_id | PK & FK → booking_request.booking_id |
| staff_id | FK → user.user_id (who made decision) |
| decision | Approved or Rejected |
| decision_time | Datetime of decision |
| decision_note | Free-text note |
| rejection_reason | Required if decision is Rejected |

### 3.8 Booking Session (`booking_session`) — Check-in / Check-out
| Attribute | Description |
|---|---|
| booking_id | PK & FK → booking_request.booking_id |
| actual_start_time | Datetime when user checked in |
| checked_in_by | FK → user.user_id (staff who performed check-in) |
| initial_condition | Text describing condition at check-in |
| actual_end_time | Datetime when session ended |
| final_condition | Text describing condition at check-out |
| usage_notes | Free-text notes about the session |

### 3.9 Maintenance Record (`maintenance_record`)
| Attribute | Description |
|---|---|
| maintenance_id | Primary key |
| space_code | FK → space.space_code |
| reported_by | FK → user.user_id |
| assigned_to | FK → user.user_id (staff assigned) |
| problem_description | Description of the issue |
| problem_type | Broken Projector, AC Failure, Damaged Furniture, Cleaning Issue, Network Problem |
| start_time | Datetime reported / started |
| completion_time | Datetime completed (nullable) |
| status | Reported, In Progress, Completed |
| result_note | Result description after completion |

## 4. Relationships and Cardinalities

| Left Entity | Relationship | Right Entity | Cardinality |
|---|---|---|---|
| User | submits | Booking Request | 1:N |
| Space | is booked by | Booking Request | 1:N |
| Booking Request | has decision by | User (Staff) | N:1 |
| Booking Request | has session | Booking Session | 1:1 |
| Space | has facilities cataloged in | Facility Catalog | M:N (via space_facility) |
| Facility Catalog | is tracked by | Facility Asset | 1:N |
| Space | contains | Facility Asset | 1:N |
| Space | has | Maintenance Record | 1:N |
| User | reports | Maintenance Record | 1:N |
| User | is assigned to | Maintenance Record | 1:N |

## 5. Business Rules

1. **Unique Account:** Each user must have a university account (email identifier).
2. **No Overlap:** Two approved bookings for the same space must not have overlapping time periods.
3. **Unavailable Space Block:** A space whose status is Under Maintenance, Temporarily Closed, or Retired cannot be booked.
4. **Decision Logging:** When a booking is approved or rejected, the staff member, decision time, and note must be recorded.
5. **Rejection Reason Required:** If a booking is rejected, a rejection reason is mandatory.
6. **Check-in Recording:** Check-in records actual start time, who performed the check-in, and initial space condition.
7. **Check-out Recording:** Completion records actual end time, final space condition, and usage notes.
8. **Maintenance Blocks Booking:** While a maintenance record is open (status = Reported or In Progress), the related space cannot be booked.
9. **Historical Preservation:** The system must keep historical records (no physical deletion) of bookings and maintenance activities.

## 6. Catalog vs. Asset Hybrid Pattern (Forced Assumption)

Per the pipeline global rules, the ambiguous "facilities in each space" requirement is resolved as follows:

- **`facility_catalog`**: A general catalog of facility types with an `is_trackable` flag.
- **`space_facility`**: M:N mapping table linking space to catalog items with a `quantity` for non-trackable items (e.g., "10 chairs in room A").
- **`facility_asset`**: A 1:N table for high-value, individually trackable assets (e.g., a specific projector with a unique asset tag).

## 7. Assumptions

1. Booking status transitions follow a linear workflow: Pending → Approved → Checked In → Completed (or Rejected / Cancelled / No-Show).
2. A space can have multiple facility catalog entries via the M:N mapping.
3. Only Facility Staff or Facility Manager can perform check-in and check-out.
4. Maintenance records are linked to a specific space; if maintenance is ongoing, the space's `current_status` is updated accordingly.
5. A booking can have only one decision (approve/reject) and one session (check-in/check-out).

## 8. Open Questions

1. Should there be a recurring booking pattern (e.g., weekly lectures)?
2. Should the system support waitlisting when a space is already booked?
3. Should notifications be part of the system scope (email alerts on approval/rejection)?
