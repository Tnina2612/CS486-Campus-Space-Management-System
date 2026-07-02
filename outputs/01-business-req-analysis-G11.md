# Business Requirement Analysis — G11

## 1. Business Purpose
The School of Computer Science needs a database system to manage shared campus spaces (auditoriums, classrooms, computer labs, project labs, meeting rooms, student workspaces). The system must handle space booking, approval workflows, usage session tracking, maintenance management, incident reporting, and facility utilization. It aims to eliminate manual processes (email/phone/spreadsheets), prevent overlapping bookings, prevent booking of unavailable spaces, and preserve usage history.

## 2. Actors / User Roles
- **Student** — books spaces for activities, projects, events
- **Lecturer** — books spaces for teaching, seminars, workshops
- **Teaching Assistant** — books spaces on behalf of courses
- **Facility Staff** — handles check-in/check-out, records maintenance, approves/rejects bookings
- **Department Administrator** — manages users, spaces, policies
- **Facility Manager** — oversees facility catalog, approvals, maintenance assignment

## 3. Entities & Attributes

### USER
| Attribute | Description |
|-----------|-------------|
| user_id | Unique identifier (PK) |
| full_name | User's full name |
| email | University email address |
| phone | Contact phone number |
| role | Student, Lecturer, TA, Facility Staff, Dept Admin, Facility Manager |
| department | Department affiliation |
| account_status | Active, Inactive, Suspended |

### SPACE
| Attribute | Description |
|-----------|-------------|
| space_code | Unique code (PK) |
| space_name | Descriptive name |
| space_type | Auditorium, Classroom, Computer Lab, Project Lab, Meeting Room, Student Workspace |
| building | Building name/number |
| floor | Floor number |
| room_number | Room identifier |
| capacity | Maximum occupancy |
| current_status | Available, In Use, Under Maintenance, Temporarily Closed, Retired |
| usage_policy | Text describing permitted uses |

### FACILITY_CATALOG (Catalog vs. Asset Hybrid Pattern)
| Attribute | Description |
|-----------|-------------|
| catalog_id | Unique identifier (PK) |
| facility_name | Name (e.g., 'Projector', 'Chair') |
| is_trackable | BIT flag — 1 if high-value/trackable asset, 0 if non-trackable |

### SPACE_FACILITY (M:N mapping)
| Attribute | Description |
|-----------|-------------|
| space_code | FK to SPACE |
| catalog_id | FK to FACILITY_CATALOG |
| quantity | Integer for non-trackable items |

### FACILITY_ASSET (Trackable assets)
| Attribute | Description |
|-----------|-------------|
| asset_id | Unique identifier (PK) |
| catalog_id | FK to FACILITY_CATALOG |
| space_code | FK to SPACE (current location) |
| asset_tag | Unique tag/barcode (UNIQUE) |
| status | Working, Under Repair, Retired |

### BOOKING (Booking Lifecycle Normalization — Step 1)
| Attribute | Description |
|-----------|-------------|
| booking_id | Unique identifier (PK) |
| user_id | FK to USER (requester) |
| space_code | FK to SPACE |
| requested_start | Requested start datetime |
| requested_end | Requested end datetime |
| purpose | Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Admin Event |
| expected_participants | Number of participants |
| status | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-show |

### APPROVAL (Booking Lifecycle Normalization — Step 2)
| Attribute | Description |
|-----------|-------------|
| approval_id | Unique identifier (PK) |
| booking_id | FK to BOOKING (UNIQUE — strict 1-to-1) |
| staff_id | FK to USER (staff who decided) |
| decision | Approved, Rejected |
| decision_time | Datetime of decision |
| decision_note | Text note |
| rejection_reason | Required if rejected |

### USAGE_SESSION (Booking Lifecycle Normalization — Step 3)
| Attribute | Description |
|-----------|-------------|
| session_id | Unique identifier (PK) |
| booking_id | FK to BOOKING (UNIQUE — strict 1-to-1) |
| checked_in_by | FK to USER (staff who checked in) |
| actual_start | Actual start datetime |
| initial_condition | Text description of initial state |
| actual_end | Actual end datetime (nullable until completed) |
| final_condition | Text description of final state |
| completed_by | FK to USER (staff who completed) |
| usage_notes | Optional text notes |

### MAINTENANCE_RECORD
| Attribute | Description |
|-----------|-------------|
| maintenance_id | Unique identifier (PK) |
| space_code | FK to SPACE |
| reporter_id | FK to USER (who reported) |
| assigned_staff_id | FK to USER (assigned staff, nullable) |
| problem_description | Text |
| problem_type | Broken Projector, AC Failure, Damaged Furniture, Cleaning, Network Problem |
| start_time | When maintenance started |
| completion_time | Nullable — when completed |
| status | Reported, In Progress, Completed, Cancelled |
| result_note | Text (nullable) |

## 4. Relationships & Cardinalities

| Entity A | Relationship | Entity B | Cardinality |
|----------|-------------|----------|-------------|
| USER | submits | BOOKING | 1:N |
| SPACE | is booked in | BOOKING | 1:N |
| SPACE | has | FACILITY_CATALOG (via SPACE_FACILITY) | M:N |
| FACILITY_CATALOG | is tracked as | FACILITY_ASSET | 1:N |
| SPACE | contains | FACILITY_ASSET | 1:N (current location) |
| BOOKING | has | APPROVAL | 1:1 (strict) |
| BOOKING | has | USAGE_SESSION | 1:1 (strict) |
| USER | approves/rejects | APPROVAL | 1:N (staff_id) |
| USER | checks in | USAGE_SESSION | 1:N (checked_in_by) |
| USER | completes | USAGE_SESSION | 1:N (completed_by) |
| SPACE | has | MAINTENANCE_RECORD | 1:N |
| USER | reports | MAINTENANCE_RECORD | 1:N (reporter_id) |
| USER | assigned to | MAINTENANCE_RECORD | 1:N (assigned_staff_id) |

## 5. Business Rules

1. **Unique Space Code:** Each space has a unique `space_code`.
2. **Unique Asset Tag:** Each facility asset has a unique `asset_tag`.
3. **No Overlapping Bookings:** The same space cannot have two approved bookings with overlapping time periods.
4. **Unavailable Spaces Cannot Be Booked:** A space that is under maintenance, temporarily closed, or retired cannot be booked.
5. **Strict 1-to-1 Booking Lifecycle:** A booking has at most one approval record and at most one usage session (enforced via UNIQUE on `booking_id` in both APPROVAL and USAGE_SESSION).
6. **Approval Required:** A booking request may require approval. If rejected, a rejection reason must be stored.
7. **Catalog vs. Asset Pattern:** Non-trackable facilities are recorded via SPACE_FACILITY with quantity; trackable assets are individually tracked in FACILITY_ASSET.
8. **Maintenance Blocks Booking:** A space with ongoing maintenance (status = 'Reported' or 'In Progress') cannot be booked.
9. **Check-in/Check-out:** Actual start and end times are recorded at check-in and completion.
10. **Historical Preservation:** All booking, approval, usage, and maintenance records are preserved for historical reference.

## 6. Open Questions / Assumptions

- **Assumption:** The system uses the university's existing authentication; USER records are synchronized or manually maintained.
- **Assumption:** Approval may be skipped for certain space types or roles; the APPROVAL record is optional per booking.
- **Assumption:** USAGE_SESSION is created at check-in time (not at booking submission).
- **Assumption:** A booking can be cancelled by the requester before check-in.
- **Assumption:** Facility catalog items are pre-defined and managed by the Facility Manager.
- **Open Question:** Should the system support recurring bookings (e.g., weekly lectures)?
- **Open Question:** Should there be a notification/alert mechanism when maintenance is completed?
