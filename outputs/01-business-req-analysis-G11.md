# Business Requirement Analysis

## Group
G11

## Business Purpose
The School of Computer Science manages shared physical spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, student workspaces). Currently, bookings are handled manually via email/phone/spreadsheets. As volume grows, this is unsustainable. The goal is to build a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization — ensuring fair allocation, preventing conflicts, and preserving usage history.

---

## Actors

| Actor | Description |
|---|---|
| Student | Requests space booking for student activities |
| Lecturer | Requests space booking for lectures, seminars |
| Teaching Assistant | Requests space booking on behalf of instructors |
| Facility Staff | Checks availability, approves/rejects bookings, performs check-in/check-out, manages maintenance |
| Department Administrator | Oversees bookings and space usage within the department |
| Facility Manager | Manages spaces, facilities, and overall booking policies |
| All Users | Have a university account; system stores their basic info |

---

## Entities & Attributes

### 1. User
| Attribute | Description |
|---|---|
| user_id | Unique identifier |
| full_name | User's full name |
| email | Email address |
| phone | Phone number |
| role | Student, Lecturer, TA, Facility Staff, Dept Admin, Facility Manager |
| department | Department/school affiliation |
| account_status | Active, inactive, suspended |

### 2. Space
| Attribute | Description |
|---|---|
| space_code | Unique space code |
| space_name | Name of the space |
| space_type | Auditorium, classroom, computer lab, project lab, meeting room, workspace |
| building | Building name/number |
| floor | Floor number |
| room_number | Room identifier |
| capacity | Maximum occupancy |
| status | Available, in_use, under_maintenance, temporarily_closed, retired |
| usage_policy | Policy text describing who may use the space |

### 3. Facility Catalog (Hybrid Pattern)
| Attribute | Description |
|---|---|
| catalog_id | Unique identifier |
| name | Facility name (e.g., 'Projector', 'Chair') |
| description | Optional description |
| is_trackable | BIT flag — if 1, each unit is tracked individually; if 0, only quantity is recorded |

### 4. Space-Facility Mapping (Hybrid Pattern)
| Attribute | Description |
|---|---|
| space_code | FK to Space |
| catalog_id | FK to Facility Catalog |
| quantity | Number of non-trackable items of this catalog in the space |

### 5. Facility Asset (Hybrid Pattern)
| Attribute | Description |
|---|---|
| asset_id | Unique identifier |
| catalog_id | FK to Facility Catalog |
| space_code | FK to Space (current location) |
| asset_tag | Unique asset tag (e.g., 'PROJ-001') |
| status | Working, under_repair, retired |

### 6. Booking
| Attribute | Description |
|---|---|
| booking_id | Unique identifier |
| space_code | FK to Space |
| requester_id | FK to User (who submitted the request) |
| requested_start | Requested start datetime |
| requested_end | Requested end datetime |
| purpose | Description of intended use |
| participants | Expected number of participants |
| booking_type | Lecture, examination, seminar, workshop, meeting, student_activity, administrative |
| status | Pending, approved, rejected, cancelled, checked_in, completed, no_show |

### 7. Booking Approval
| Attribute | Description |
|---|---|
| approval_id | Unique identifier |
| booking_id | FK to Booking |
| approver_id | FK to User (staff/manager who decided) |
| decision_time | When the decision was made |
| decision_note | Note accompanying the decision |
| rejection_reason | Reason if rejected (nullable) |

### 8. Booking Session (Check-in/Check-out)
| Attribute | Description |
|---|---|
| session_id | Unique identifier |
| booking_id | FK to Booking (1:1) |
| actual_start | Actual check-in datetime |
| checked_in_by | FK to User (staff who performed check-in) |
| initial_condition | Condition notes on arrival |
| actual_end | Actual check-out datetime |
| completed_by | FK to User (staff who performed check-out) |
| final_condition | Condition notes on departure |
| usage_notes | Additional notes about the session |

### 9. Maintenance Record
| Attribute | Description |
|---|---|
| maintenance_id | Unique identifier |
| space_code | FK to Space |
| reporter_id | FK to User (who reported the problem) |
| assigned_to | FK to User (staff assigned to fix) |
| problem_description | Description of the issue |
| problem_type | Broken projector, AC failure, damaged furniture, cleaning, network, other |
| start_time | When maintenance started |
| completion_time | When maintenance completed (nullable) |
| status | Reported, in_progress, completed, cancelled |
| result_note | Outcome notes |

---

## Relationships & Cardinalities

| Entity 1 | Relationship | Entity 2 | Cardinality | Description |
|---|---|---|---|---|
| User | submits | Booking | 1:N | A user can submit many bookings |
| Space | is booked in | Booking | 1:N | A space can have many bookings |
| Booking | is decided by | User (approver) | N:1 | A booking is approved/rejected by one staff member |
| Booking | has | Booking Approval | 1:1 | Each booking has zero or one approval record |
| Booking | has | Booking Session | 1:1 | Each booking has zero or one session record |
| User | performs check-in | Booking Session | 1:N | A user may check in many sessions |
| User | performs check-out | Booking Session | 1:N | A user may check out many sessions |
| Space | undergoes | Maintenance | 1:N | A space can have many maintenance records |
| User (reporter) | reports | Maintenance | 1:N | A user may report many maintenance issues |
| User (assignee) | is assigned to | Maintenance | 1:N | A user may be assigned to many maintenance tasks |
| Space | has | Space-Facility | 1:N | A space can have many facility catalog entries |
| Facility Catalog | appears in | Space-Facility | 1:N | A facility catalog can appear in many spaces |
| Space | contains | Facility Asset | 1:N | A space can have many tracked facility assets |
| Facility Catalog | is type of | Facility Asset | 1:N | A catalog entry can have many physical assets |

---

## Business Rules

1. **Unique User Accounts:** Each user must have a university account. User ID is unique.
2. **Unique Space Code:** Each space has a unique space code.
3. **No Overlapping Bookings:** The same space cannot have two approved bookings with overlapping time periods.
4. **Unavailable Space Cannot Be Booked:** A space that is under maintenance, temporarily closed, or retired cannot be booked.
5. **Booking Status Lifecycle:** A booking progresses through: pending → approved (or rejected/cancelled) → checked_in → completed (or no_show).
6. **Approval Recording:** When a booking is approved/rejected, the system records the staff member who decided, the decision time, and a decision note. If rejected, a rejection reason is required.
7. **Check-in Process:** Facility staff records actual start time, who checked in, and initial condition of the space.
8. **Check-out Process:** Facility staff records actual end time, final condition, and usage notes.
9. **Maintenance Prevents Booking:** A space with an active (reported/in_progress) maintenance record cannot be booked.
10. **Maintenance Recording:** Each maintenance record captures reporter, assigned staff, problem description, problem type, start time, completion time, status, and result note.
11. **Historical Records:** Booking and maintenance history must be preserved (no hard deletes of historical data).
12. **Facility Hybrid Pattern:**
    - `facility_catalog` defines item types and whether each type is trackable.
    - `space_facility` maps a catalog entry to a space with a `quantity` (for non-trackable items).
    - `facility_asset` individually tracks each physical asset for trackable items.
    - Each `facility_asset` has a unique `asset_tag`.
    - Quantity in `space_facility` for trackable items must match the count of actual assets.

---

## Assumptions

1. Time slots are precise to minute-level granularity; no concept of repeating/weekly bookings (each booking is a discrete event).
2. A booking request is submitted by one user (the requester), who may be booking on behalf of others.
3. The approval is done by facility staff or the facility manager; multiple levels of approval are not required.
4. Only one staff member handles check-in and potentially a different one handles check-out.
5. Facility assets are assumed to be located in exactly one space at a time (no transfer tracking between spaces in scope).
6. Booking can be cancelled by the requester before check-in.
7. A "no-show" status is applied when the requester does not check in by a reasonable time.

---

## Open Questions

1. Is there a maximum advance booking period (e.g., bookings only allowed up to 30 days ahead)?
2. Should recurring bookings (e.g., every Monday for a semester) be supported?
3. Is there a concept of "waitlist" if a space is already booked?
4. Should users have a booking quota (e.g., max N active bookings per user)?
5. Is there a notification system requirement (email/SMS) when booking status changes?
6. Should there be different approval workflows based on space type or requester role?
