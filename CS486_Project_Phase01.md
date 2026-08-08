CS486 - Introduction to Database System

# PROJECT

## Campus Space Management System

### 1. Business requirement description

The School of Computer Science manages several shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. These spaces include auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces.

Currently, requests to use these spaces are handled manually. Lecturers, teaching assistants, students, and staff usually contact the school office or facility staff by email, phone, or in person. Facility staff then check spreadsheets or shared calendars to determine whether a room is available, whether the requester is allowed to use it, whether special equipment is needed, and whether the room is under maintenance.

As the number of classes, student projects, workshops, seminars, and academic events increases, the manual process has become difficult to manage. The School wants to build a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization.

The Facility Manager provides the following requirement summary:

The School wants to develop a system to manage the booking and usage of shared campus spaces such as classrooms, computer laboratories, meeting rooms, and auditoriums.

Each user must have a university account. The system stores basic user information, including user ID, full name, email, phone number, role, department, and account status. A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager.

The School manages many bookable spaces. For each space, the system stores a unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy. A space may be available, in use, under maintenance, temporarily closed, or retired.

Each space may have several facilities, such as a projector, whiteboard, microphone, computer, livestreaming equipment, or air conditioner. The system should store the list of facilities available in each space.

Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants. A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event.

Each booking request has a status, such as pending, approved, rejected, cancelled, checked in, completed, or no-show. The system must prevent conflicting bookings. The same space cannot have two approved bookings with overlapping time periods. A space that is under maintenance, closed, or retired cannot be booked.

A booking request may require approval from a facility staff member or manager. When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note. If the booking is rejected, the rejection reason should be stored.

When the requester arrives, facility staff can check in the booking. The system records the actual start time, the person who checked in the booking, and the initial condition of the space. When the session ends, facility staff can complete the booking by recording the actual end time, the final condition of the space, and any usage notes.

The system also supports basic maintenance management. A space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems. Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note. A space under maintenance cannot be booked.

The system should keep historical records of bookings and maintenance activities. Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.

The main goal of the system is to help the School manage shared campus spaces fairly, avoid overlapping bookings, prevent the use of unavailable spaces, and preserve usage history.

---

### 2. Phase 1

1. **Business Requirement Analysis:** Analyze the requirements to identify the business purpose, actors, entities, attributes, relationships, cardinalities, and business rules.
2. **Conceptual Database Design:** Design an ERD showing the main entities, attributes, relationships, cardinalities, and participation constraints.
3. **Logical Database Design:** Convert the ERD into a relational schema with relations, attributes, primary keys, foreign keys, candidate keys, and key constraints.
4. **Database Design Validation:** Evaluate whether the relational schema correctly represents the ERD, satisfies the business rules, and uses appropriate keys, relationships, and constraints.
5. **Database Implementation:** Implement the database using SQL DDL with tables, keys, constraints, checks, and default values where appropriate.
6. **Sample Data Preparation:** Insert realistic sample data to support testing of normal operations and important exceptional cases.
7. **Query Design:** Each student must design and execute at least 5 meaningful SQL queries that are valid for the database and useful for answering business questions in the given context. Each query must include:
   - Business question
   - Target user(s) that would use the query
   - Short explanation of why the query is useful
   - SQL statement

---

### 3. Required Documents

The group answer must include, but is not limited to, the following files and folders:
- `AGENT.md`
- `SKILL.md`
- `outputs/`

The `outputs/` folder must contain the following deliverables:
- `01-business-req-analysis-G11.md`
- `02-erd-design-G11.md`
- `03-logical-design-G11.md`
- `04-design-validation-G11.md`
- `05-db-definition-G11.sql`
- `06-sample-data-G11.sql`
- `07-query-design-G11.sql`