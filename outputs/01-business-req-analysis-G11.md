# Business Requirement Analysis

## Business Purpose
The School of Computer Science wants to build a database system to manage the booking and usage of shared campus spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces). The system must handle space booking, approval workflows, usage sessions, maintenance tracking, incident reporting, and facility utilization. It aims to replace the current manual process (email/phone/spreadsheets) with a structured database to prevent overlapping bookings, prevent use of unavailable spaces, and preserve usage history.

## Actors
| Actor | Description |
|---|---|
| Student | A university student who may book spaces for student projects or activities. |
| Lecturer | Academic staff who may book spaces for lectures, seminars, workshops, etc. |
| Teaching Assistant | A TA who may book spaces for tutorials or support sessions. |
| Facility Staff | Staff member responsible for checking in/out bookings and managing day-to-day space operations. |
| Department Administrator | Administrator who may manage bookings or view reports. |
| Facility Manager | Manager who oversees facility operations and may approve or reject requests. |

## Entities and Attributes

### User
- `user_id` — Unique identifier for each user (university account ID).
- `full_name` — Full name of the user.
- `email` — University email address.
- `phone_number` — Contact phone number.
- `role` — Role of the user (student, lecturer, teaching_assistant, facility_staff, department_administrator, facility_manager).
- `department` — Department the user belongs to.
- `account_status` — Account status (active, inactive, suspended).

### Space
- `space_code` — Unique code for each physical space (PK).
- `space_name` — Descriptive name of the space.
- `space_type` — Type of space (auditorium, classroom, computer_lab, project_lab, meeting_room, student_workspace).
- `building` — Building where the space is located.
- `floor` — Floor number where the space is located.
- `room_number` — Room number within the building/floor.
- `capacity` — Maximum number of people the space can hold.
- `current_status` — Current operational status (available, in_use, under_maintenance, temporarily_closed, retired).
- `usage_policy` — Text field describing rules/restrictions for using the space.

### Facility
- `facility_id` — Unique identifier for each type of facility/equipment.
- `facility_name` — Name of the facility (e.g., projector, whiteboard, microphone, computer, livestreaming_equipment, air_conditioner).
- `description` — Optional description or specification.

### Space_Facility (Associative)
Links spaces to the facilities they contain. A space may have multiple facilities; a facility type may exist in multiple spaces.

### Booking_Request
- `booking_id` — Unique identifier for each booking request (PK).
- `requester_id` — Reference to the user who made the request (FK → User).
- `space_code` — Reference to the requested space (FK → Space).
- `requested_start_time` — Desired start date and time.
- `requested_end_time` — Desired end date and time.
- `purpose` — Purpose of use (lecture, examination, seminar, workshop, meeting, student_activity, administrative_event).
- `expected_participants` — Expected number of participants.
- `status` — Current status (pending, approved, rejected, cancelled, checked_in, completed, no_show).
- `submitted_at` — Timestamp when the request was submitted.

### Booking_Approval
- `approval_id` — Unique identifier for the approval record (PK).
- `booking_id` — Reference to the booking request being decided (FK → Booking_Request).
- `staff_id` — Reference to the facility staff or manager who made the decision (FK → User).
- `decision` — Decision made (approved, rejected).
- `decision_time` — Timestamp of the decision.
- `decision_note` — Note accompanying the decision.
- `rejection_reason` — Reason for rejection (required when decision is 'rejected').

### Booking_Session
Tracks the actual usage of a booking (check-in and checkout).
- `session_id` — Unique identifier (PK).
- `booking_id` — Reference to the booking request (FK → Booking_Request).
- `actual_start_time` — Actual time the user arrived / check-in time.
- `checkin_by` — Staff member who performed check-in (FK → User).
- `initial_condition` — Description of the space condition at check-in.
- `actual_end_time` — Actual time the session ended / checkout time.
- `completed_by` — Staff member who performed checkout (FK → User).
- `final_condition` — Description of the space condition at checkout.
- `usage_notes` — Any notes about the usage session.

### Maintenance_Record
- `maintenance_id` — Unique identifier (PK).
- `space_code` — Reference to the space under maintenance (FK → Space).
- `reporter_id` — User who reported the problem (FK → User).
- `assigned_staff_id` — Staff member assigned to fix the problem (FK → User).
- `problem_description` — Detailed description of the issue.
- `problem_type` — Category of the problem (broken_projector, ac_failure, damaged_furniture, cleaning_issue, network_problem, other).
- `start_time` — When the maintenance started or was reported.
- `completion_time` — When the maintenance was completed (nullable).
- `status` — Current status (reported, in_progress, completed, cancelled).
- `result_note` — Notes about the maintenance outcome.

## Relationships and Cardinalities

| Relationship | Entity A | Entity B | Cardinality | Description |
|---|---|---|---|---|
| Submits | User | Booking_Request | 1:N | A user can submit many booking requests; each booking request belongs to one user. |
| Targets | Booking_Request | Space | N:1 | Many booking requests can target the same space; each booking request is for exactly one space. |
| Contains | Space | Space_Facility | 1:N | A space can have many facility associations. |
| Belongs_To | Facility | Space_Facility | 1:N | A facility type can be associated with many spaces. |
| Decides | Booking_Request | Booking_Approval | 1:1 | Each booking request has at most one approval decision. |
| Processes | User (Staff) | Booking_Approval | 1:N | A staff member can process many approval decisions. |
| Tracks | Booking_Request | Booking_Session | 1:1 | Each approved booking request can have at most one usage session. |
| Performs_Checkin | User (Staff) | Booking_Session | 1:N | A staff member can perform check-in for many sessions. |
| Performs_Checkout | User (Staff) | Booking_Session | 1:N | A staff member can perform checkout for many sessions. |
| Reports | User | Maintenance_Record | 1:N | A user can report many maintenance issues. |
| Assigned_To | User (Staff) | Maintenance_Record | 1:N | A staff member can be assigned to many maintenance records. |
| Affects | Space | Maintenance_Record | 1:N | A space can have many maintenance records. |

## Business Rules

1. **Unique Overlap Prevention**: The same space cannot have two approved bookings with overlapping time periods.
2. **Unavailable Space Prevention**: A space that is under maintenance, temporarily closed, or retired cannot be booked.
3. **Account Requirement**: Each user must have a valid university account.
4. **Approval Workflow**: A booking request may require approval from facility staff or manager. When approved or rejected, the system must record the decision-maker, decision time, and decision note. If rejected, a rejection reason must be stored.
5. **Check-in**: After approval, facility staff can check in the booking, recording actual start time, check-in person, and initial condition.
6. **Checkout**: After check-in, facility staff can complete the booking by recording actual end time, final condition, and usage notes.
7. **Status Lifecycle**: Booking status follows: pending → approved/rejected/cancelled → checked_in → completed/no_show.
8. **Historical Records**: The system must keep historical records of bookings and maintenance activities; no hard deletion.
9. **Maintenance Blocking**: A space with an active (reported/in_progress) maintenance record cannot be booked.
10. **Role-Based Access**: Different user roles (student, lecturer, TA, staff, admin, manager) may have different permissions.

## Assumptions

- Each booking request has exactly one space.
- A booking request that is rejected or cancelled will never have a check-in session.
- A no-show status is set manually or after a defined grace period (the mechanism is not specified, so we treat it as a manually set status).
- Facilities are types/items that can exist in multiple spaces (many-to-many relationship).
- The `usage_policy` field is free text stored with the space record.
- Composite check-in/checkout is tracked in a single Booking_Session table rather than two separate tables, since a session always has at most one check-in and one checkout.
- The same staff member or different staff members may perform check-in and checkout.

## Open Questions

1. Should there be an explicit cancellation reason stored, similar to rejection reason?
2. How is the "no-show" status determined — automatically by system or manually by staff?
3. Are there minimum/maximum booking duration constraints?
4. Should the system track recurring bookings (e.g., weekly lectures), or are they submitted individually?
5. Should facility items have quantity/condition tracking per space?
