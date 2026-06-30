# Business Requirement Analysis — G11

## 1. Business Purpose
The School of Computer Science wants to build a database system to manage shared campus spaces such as auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces. The system must handle booking, approval, usage sessions, maintenance, incident reporting, and facility utilization — replacing the current manual process of emails, phone calls, and spreadsheets.

## 2. Actors (User Roles)

| Role | Description |
|------|-------------|
| Student | May book spaces for activities |
| Lecturer | May book spaces for teaching, seminars |
| Teaching Assistant | May book spaces for tutorials, labs |
| Facility Staff | Checks availability, processes check-in/check-out, handles maintenance |
| Department Administrator | Oversees bookings and approvals |
| Facility Manager | Manages policies, oversees maintenance and overall operations |

## 3. Entities and Attributes

### USER

| Attribute | Description |
|-----------|-------------|
| user_id (PK) | Unique identifier (university-assigned) |
| full_name | User's full name |
| email | University email address |
| phone_number | Contact phone number |
| role | User role: student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager |
| department | Department or School affiliation |
| account_status | Account status: active, inactive, suspended |

### SPACE

| Attribute | Description |
|-----------|-------------|
| space_code (PK) | Unique code for the space |
| space_name | Descriptive name of the space |
| space_type | Type: auditorium, classroom, computer_laboratory, project_laboratory, meeting_room, student_workspace |
| building | Building where the space is located |
| floor | Floor number |
| room_number | Room identifier |
| capacity | Maximum occupancy |
| current_status | Current availability: available, in_use, under_maintenance, temporarily_closed, retired |
| usage_policy | Text describing allowed use of the space |

### FACILITY_CATALOG
The system uses a Catalog vs. Asset Hybrid Pattern. Facility types are defined in a catalog; some are tracked by quantity per space, others as individual assets.

| Attribute | Description |
|-----------|-------------|
| catalog_id (PK) | Unique identifier for the facility type |
| name | Facility name (e.g. Projector, Whiteboard, Air Conditioner) |
| description | Optional description of the facility type |
| is_trackable | BIT flag — 1 if each unit is individually tracked as a unique asset; 0 if only quantity is tracked |

### SPACE_FACILITY (M:N Associative Entity)
Maps facility types to spaces with a quantity for non-trackable items.

| Attribute | Description |
|-----------|-------------|
| space_code (FK) | References SPACE |
| catalog_id (FK) | References FACILITY_CATALOG |
| quantity | Number of non-trackable items of this type in the space |

### FACILITY_ASSET (Trackable Assets)
Individually tracked, high-value assets that have a unique identity.

| Attribute | Description |
|-----------|-------------|
| asset_id (PK) | Unique identifier |
| catalog_id (FK) | References FACILITY_CATALOG (indicates what type of asset) |
| space_code (FK) | Current location — references SPACE |
| asset_tag (UNIQUE) | Physical tag or label on the asset |
| status | Asset condition: working, damaged, under_repair, retired |

### BOOKING
Stores initial booking request data only. Lifecycle extensions (approval, usage session) are stored in separate tables.

| Attribute | Description |
|-----------|-------------|
| booking_id (PK) | Unique booking reference |
| user_id (FK) | Requester — references USER |
| space_code (FK) | Requested space — references SPACE |
| requested_start_time | Desired start date and time |
| requested_end_time | Desired end date and time |
| purpose | Free-text description of the intended use |
| expected_participants | Number of attendees |
| booking_type | Lecture, examination, seminar, workshop, meeting, student_activity, administrative_event |
| status | Pending, approved, rejected, cancelled, checked_in, completed, no_show |

### APPROVAL (1:1 with BOOKING)
Records the decision made by staff on a booking request.

| Attribute | Description |
|-----------|-------------|
| approval_id (PK) | Unique identifier |
| booking_id (FK, UNIQUE) | References BOOKING (enforces 1:1) |
| staff_id (FK) | Staff member who made the decision — references USER |
| decision | Approved or rejected |
| decision_time | Timestamp of the decision |
| decision_note | Optional note about the decision |
| rejection_reason | Required only when decision is rejected |

### USAGE_SESSION (1:1 with BOOKING)
Records actual check-in and check-out information for a booking.

| Attribute | Description |
|-----------|-------------|
| session_id (PK) | Unique identifier |
| booking_id (FK, UNIQUE) | References BOOKING (enforces 1:1) |
| actual_start_time | When the booking was checked in |
| checked_in_by (FK) | Staff member who performed the check-in — references USER |
| initial_condition | Condition of the space at check-in |
| actual_end_time | When the booking was checked out (nullable — recorded later) |
| final_condition | Condition of the space at check-out (nullable) |
| usage_notes | Optional notes from the session |

### MAINTENANCE
Records maintenance activities on spaces.

| Attribute | Description |
|-----------|-------------|
| maintenance_id (PK) | Unique identifier |
| space_code (FK) | Space being maintained — references SPACE |
| reporter_id (FK) | Person who reported the issue — references USER |
| assigned_staff_id (FK, nullable) | Staff member assigned to fix the issue — references USER |
| problem_description | Detailed description of the issue |
| problem_type | Broken projector, AC failure, damaged furniture, cleaning, network problem, other |
| start_time | When maintenance started |
| completion_time | When maintenance was completed (nullable) |
| status | Current maintenance status: reported, in_progress, completed, cancelled |
| result_note | Outcome notes (nullable) |

## 4. Relationships and Cardinalities

| Relationship | Entity 1 | Cardinality | Entity 2 | Cardinality | Description |
|-------------|----------|-------------|----------|-------------|-------------|
| Makes | USER | 1 | BOOKING | N | A user can submit many booking requests |
| Hosts | SPACE | 1 | BOOKING | N | A space can host many bookings |
| Is decided by | BOOKING | 1 | APPROVAL | 0..1 | A booking may have zero or one approval decision |
| Has session | BOOKING | 1 | USAGE_SESSION | 0..1 | A booking may have zero or one usage session |
| Decides | USER (staff) | 1 | APPROVAL | N | A staff member can decide on many bookings |
| Checks in | USER (staff) | 1 | USAGE_SESSION | N | A staff member can check in many sessions |
| Contains | SPACE | M | FACILITY_CATALOG | N | Many-to-many via SPACE_FACILITY with quantity |
| Classifies | FACILITY_CATALOG | 1 | FACILITY_ASSET | N | A catalog entry classifies many asset instances |
| Houses | SPACE | 1 | FACILITY_ASSET | N | A space houses many trackable assets |
| Undergoes | SPACE | 1 | MAINTENANCE | N | A space can have many maintenance records |
| Reports | USER | 1 | MAINTENANCE | N | A user can report many maintenance issues |
| Assigned to | USER | 1 | MAINTENANCE | N | A staff member can be assigned to many maintenance tasks |

## 5. Business Rules

1. **University Account Required:** Every user must have a registered university account to use the system.
2. **No Overlapping Bookings:** The same space cannot have two approved bookings with overlapping time periods.
3. **Unavailable Space Blocked:** A space that is under maintenance, temporarily closed, or retired cannot be booked.
4. **Booking Status Lifecycle:** pending → approved → checked_in → completed (or rejected, cancelled, no-show at applicable transitions).
5. **Approval Requires Staff Record:** When a booking is approved or rejected, the system records the staff member who decided, the decision time, and a decision note.
6. **Rejection Reason Required:** If a booking is rejected, the rejection reason must be stored.
7. **Check-In Procedure:** On arrival, facility staff records actual start time, who checked in, and initial condition of the space.
8. **Check-Out Procedure:** On completion, facility staff records actual end time, final condition, and usage notes.
9. **Maintenance Blocks Booking:** A space with active (reported or in-progress) maintenance status cannot be booked.
10. **Historical Records Preserved:** The system must retain booking and maintenance history — no hard deletes of completed or historical records.
11. **Unique Asset Tag:** Each trackable facility asset must have a globally unique asset tag.
12. **Catalog Definition:** Every facility belongs to a catalog category; non-trackable items are recorded by quantity per space; trackable items are individually tracked as assets with unique IDs.

## 6. Assumptions

- User IDs are university-assigned and globally unique.
- A booking is always associated with exactly one space (no multi-space bookings).
- Maintenance is always tied to a specific space, not to individual facility assets.
- The system time zone follows the university's local time.
- Facility staff are users with the role facility_staff or facility_manager.
- Check-in and check-out are performed by facility staff, not by the requester.
- The `is_trackable` flag on FACILITY_CATALOG determines whether items appear in SPACE_FACILITY (quantity-based, is_trackable=0) or FACILITY_ASSET (individual assets, is_trackable=1).
- Account status values (active, inactive, suspended) are system-defined and not enumerated in the original requirement.
- Maintenance status values (reported, in_progress, completed, cancelled) are system-defined and not enumerated in the original requirement.
- Facility asset status values (working, damaged, under_repair, retired) are system-defined and not enumerated in the original requirement.
- The `other` value for MAINTENANCE.problem_type allows reporting issues not covered by the listed types.
- The `decision` column on APPROVAL is added to explicitly capture the approve/reject outcome, implied but not stated as a named attribute in the requirement.

## 7. Unresolved Questions

- Should the system include a notification mechanism (email, in-app) outside the database scope?
- What is the maximum allowed booking duration?
- How far in advance can a booking request be submitted?
- Are recurring booking patterns (e.g., weekly lecture series) supported?
- Should facility assets have their own maintenance history independent of space maintenance?
- Is there a cost or charge associated with booking a space?
- Should there be a separate incident reporting entity, or is MAINTENANCE sufficient for incident tracking?
