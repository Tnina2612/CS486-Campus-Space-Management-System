# Business Requirement Analysis - G11

## 1. Business Purpose

The School of Computer Science manages shared physical spaces (auditoriums, classrooms, computer labs, project labs, meeting rooms, student workspaces). Currently, booking is manual — via email, phone, or in-person requests checked against spreadsheets. As the number of classes, projects, workshops, and events grows, this process has become unmanageable.

**System goals:**
- Centralise space booking, approval, usage sessions, maintenance, incident reporting, and facility utilisation
- Prevent overlapping bookings and use of unavailable spaces
- Preserve booking and maintenance history permanently

## 2. Actors

| Actor | Description |
| :--- | :--- |
| Student | May submit booking requests for projects/activities |
| Lecturer | Books spaces for teaching, seminars, research |
| Teaching Assistant | Books spaces for tutorials, recitations |
| Facility Staff | Manages check-in/out, approves/rejects requests, handles maintenance |
| Department Administrator | Manages departmental bookings and events |
| Facility Manager | Oversees facility operations, approves complex bookings |

## 3. Entities, Attributes & Conceptual Data Types

### Core Entities (from requirement)

**USER** — Each system user has a university account.
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| user_id | string | PK, unique identifier |
| full_name | string | |
| email | string | |
| phone_number | string | |
| role | string | Enum: Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager |
| department | string | |
| account_status | string | Not enumerated in requirement |

**SPACE** — A bookable physical location.
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| space_code | string | PK, unique |
| space_name | string | |
| space_type | string | |
| building | string | |
| floor | string | |
| room_number | string | |
| capacity | integer | |
| current_status | string | Enum: Available, In Use, Under Maintenance, Temporarily Closed, Retired |
| usage_policy | string | |

### Hybrid Facility Pattern Entities (Override — from pipeline §2)

**FACILITY_CATALOG** — Catalog defining categories of items.
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| catalog_id | string | PK |
| facility_name | string | |
| is_trackable | boolean | Flag indicating whether individual items are tracked as assets |

**SPACE_FACILITY** — Associative entity linking SPACE to FACILITY_CATALOG with quantity.
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| space_code | string | PK, FK → SPACE |
| catalog_id | string | PK, FK → FACILITY_CATALOG |
| quantity | integer | Number of items of this catalog entry in this space |

**FACILITY_ASSET** — Individually tracked high-value assets.
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| asset_tag | string | PK, unique |
| space_code | string | FK → SPACE |
| catalog_id | string | FK → FACILITY_CATALOG |
| status | string | |

### Booking Lifecycle Entities (Override — from pipeline §3)

**BOOKING** — Initial booking request.
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| booking_id | string | PK |
| user | string | FK → USER (requester) |
| space | string | FK → SPACE |
| start_time | datetime | Requested start |
| end_time | datetime | Requested end |
| purpose | string | Enum: Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event |
| expected_participants | integer | |
| status | string | Enum: Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-show |

**APPROVAL** — Decision on a booking (1:1 with BOOKING).
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| approval_id | string | PK |
| booking_id | string | FK, UNIQUE → BOOKING (1:1 enforcement) |
| staff_id | string | FK → USER (deciding staff member) |
| decision_time | datetime | |
| decision_note | string | |
| rejection_reason | string | Required when booking is rejected |

**USAGE_SESSION** — Actual check-in/out session (1:1 with BOOKING).
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| session_id | string | PK |
| booking_id | string | FK, UNIQUE → BOOKING (1:1 enforcement) |
| staff_id | string | FK → USER (person who checked in) |
| actual_start_time | datetime | Recorded at check-in |
| actual_end_time | datetime | Recorded at completion |
| initial_condition | string | Recorded at check-in |
| final_condition | string | Recorded at completion |
| usage_notes | string | Recorded at completion |

### Maintenance Entity

**MAINTENANCE_RECORD** — Problem/repair tracking for a space.
| Attribute | Conceptual Type | Notes |
| :--- | :--- | :--- |
| maintenance_id | string | PK |
| space | string | FK → SPACE |
| reporter | string | FK → USER |
| assigned_staff | string | FK → USER (nullable) |
| problem_description | string | |
| start_time | datetime | |
| completion_time | datetime | Nullable |
| status | string | Values not explicitly enumerated |
| result_note | string | Nullable |

## 4. Relationships & Cardinalities

| Left Entity | Relationship | Right Entity | Cardinality | Notes |
| :--- | :--- | :--- | :--- | :--- |
| USER | makes | BOOKING | 1:N | A user can submit many booking requests |
| SPACE | has | BOOKING | 1:N | A space can have many booking requests |
| SPACE | configured_with | SPACE_FACILITY | 1:N | A space links to many facility catalog entries |
| FACILITY_CATALOG | appears_in | SPACE_FACILITY | 1:N | A catalog entry appears in many space mappings |
| SPACE | tracks | FACILITY_ASSET | 1:N | A space may contain many tracked assets |
| FACILITY_CATALOG | classifies | FACILITY_ASSET | 1:N | A catalog entry classifies many assets |
| BOOKING | results_in | APPROVAL | 1:1 | Strict 1:1 — enforced by UNIQUE FK |
| BOOKING | results_in | USAGE_SESSION | 1:1 | Strict 1:1 — enforced by UNIQUE FK |
| SPACE | undergoes | MAINTENANCE_RECORD | 1:N | A space can have many maintenance records |
| USER (reporter) | reports | MAINTENANCE_RECORD | 1:N | A user can report many issues |
| USER (assigned) | assigned_to | MAINTENANCE_RECORD | 1:N | A user can be assigned to many records |

## 5. Statuses & Enums

| Source Column | Enum Values (exact wording from requirement) |
| :--- | :--- |
| USER.role | Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager |
| SPACE.current_status | Available, In Use, Under Maintenance, Temporarily Closed, Retired |
| BOOKING.status | Pending, Approved, Rejected, Cancelled, Checked In, Completed, No-show |
| BOOKING.purpose | Lecture, Examination, Seminar, Workshop, Meeting, Student Activity, Administrative Event |
| MAINTENANCE_RECORD.status | *(Not explicitly enumerated in the requirement — see OQ-01)* |
| USER.account_status | *(Not explicitly enumerated in the requirement — see OQ-02)* |

## 6. Business Rules

| ID | Rule | Source |
| :--- | :--- | :--- |
| BR-01 | The same space cannot have two approved bookings with overlapping time periods. | Line 15 |
| BR-02 | A space under maintenance, closed, or retired cannot be booked. | Lines 15, 18 |
| BR-03 | When a booking is approved or rejected, record the staff member who decided, the decision time, and a decision note. | Line 16 |
| BR-04 | If a booking is rejected, the rejection reason must be stored. | Line 16 |
| BR-05 | At check-in, record the actual start time, the person who checked in, and the initial condition of the space. | Line 17 |
| BR-06 | At session completion, record the actual end time, the final condition of the space, and any usage notes. | Line 17 |
| BR-07 | Historical records of bookings and maintenance must be preserved. | Line 19 |
| BR-08 | Staff should be able to view: booking history, upcoming bookings, spaces under maintenance, and no-show bookings. | Line 19 |
| BR-09 | Strict 1:1 relationship between BOOKING ↔ APPROVAL and BOOKING ↔ USAGE_SESSION. | Pipeline §3 |
| BR-10 | Hybrid facility pattern: FACILITY_CATALOG, SPACE_FACILITY, FACILITY_ASSET. | Pipeline §2 |

## 7. Assumptions

- The maintenance workflow implies a status progression (e.g., Reported → Assigned → In Progress → Completed), but these values are not explicitly listed. They are noted as an open question.
- All users have a valid university account.
- Space types include: Auditorium, Classroom, Computer Laboratory, Project Laboratory, Meeting Room, Student Workspace.
- `account_status` is assumed to have at least 'Active' as a value, with the full set unknown.

## 8. Open Questions

| ID | Question |
| :--- | :--- |
| OQ-01 | What are the exact maintenance record status values? |
| OQ-02 | What are the valid account status values for a user? |
| OQ-03 | Are there department-level access restrictions for booking spaces? |
| OQ-04 | Is there a maximum booking duration or minimum notice period? |
| OQ-05 | Who is authorised to approve — any facility staff/manager, or only specific roles? |
