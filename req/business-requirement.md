## Business Requirement Description

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

## Phase 2 Extensions

### Requirement Change: Maintenance Impact Levels

In Phase 1, any space under maintenance could not be booked. The Facility Manager now refines this rule: 

* Some maintenance work makes a space unusable (for example, electrical repair, floor replacement, air-conditioning replacement in summer). Such maintenance has impact level out-of-service: the space cannot be booked for any time period that overlaps the maintenance period, exactly as in Phase 1. 
* Other maintenance work affects only part of the space's equipment or comfort, while the space itself remains usable (for example, a broken projector, one faulty air conditioner out of several, a damaged whiteboard). Such maintenance has impact level advisory: the space can still be booked, but the system must notify the requester of all active advisories on the space at booking time, and must record that the requester was informed (an acknowledgement stored with the booking). 

Additional rules: 

* A space may have several active maintenance records at the same time, with different impact levels. 
* The impact level of a maintenance record may be escalated (advisory upgraded to out-of-service) or downgraded while the maintenance is still open. If an advisory maintenance is escalated to out-of-service, already-approved bookings that overlap the maintenance period must be identified so that staff can contact the requesters; the system must support finding these affected bookings. 

### New Operating Conditions: Concurrent Booking and Approval

At the beginning of each semester, many users may submit booking requests at approximately the same time. Popular spaces may therefore receive several requests for overlapping time periods within a short interval. 
For selected space types, requests that satisfy the usage policy may be approved automatically at submission time. Other requests continue through the existing staff approval workflow. Because users and staff may perform booking operations concurrently, multiple operations may check the availability of the same space before any of them records its result. Without appropriate concurrency control, conflicting bookings may be approved. 
The system must ensure that two approved bookings cannot use the same space during overlapping time periods, regardless of whether the bookings are created through instant booking or staff approval. This rule must remain valid even when multiple users or staff members perform booking and approval operations simultaneously. 

### New Reporting Needs 

With the accumulated booking and maintenance history, the Facility Manager needs the system to support the following reports:

* Total approved booking hours of each space for a given semester. 
* Number of approved bookings by weekday and hour for a given semester. 
* Available spaces that satisfy a required capacity and a required facility list within a given time period. 
* Approved bookings affected when a maintenance record is escalated to out-of-service.