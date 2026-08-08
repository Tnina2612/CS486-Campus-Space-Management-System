CS486 - Introduction to Database System

# PROJECT

## Campus Space Management System

### 1. Business requirement description

After the Phase 1 design was completed, the School of Computer Science piloted the space booking system for one semester. Based on the pilot, the Facility Manager announces one change to the maintenance rules and a set of new operating conditions that the system must support. Phase 2 extends the Phase 1 system accordingly.

#### 1.1. Requirement change: maintenance impact levels
In Phase 1, any space under maintenance could not be booked. The Facility Manager now refines this rule:

Some maintenance work makes a space unusable (for example, electrical repair, floor replacement, air-conditioning replacement in summer). Such maintenance has impact level **out-of-service**: the space cannot be booked for any time period that overlaps the maintenance period, exactly as in Phase 1.

Other maintenance work affects only part of the space's equipment or comfort, while the space itself remains usable (for example, a broken projector, one faulty air conditioner out of several, a damaged whiteboard). Such maintenance has impact level **advisory**: the space can still be booked, but the system must notify the requester of all active advisories on the space at booking time, and must record that the requester was informed (an acknowledgement stored with the booking).

**Additional rules:**
* A space may have several active maintenance records at the same time, with different impact levels.
* The impact level of a maintenance record may be escalated (advisory → out-of-service) or downgraded while the maintenance is still open. If an advisory maintenance is escalated to out-of-service, already-approved bookings that overlap the maintenance period must be identified so that staff can contact the requesters; the system must support finding these affected bookings.

#### 1.2. New operating conditions: concurrent booking and approval
At the beginning of each semester, many users may submit booking requests at approximately the same time. Popular spaces may therefore receive several requests for overlapping time periods within a short interval.

For selected space types, requests that satisfy the usage policy may be approved automatically at submission time. Other requests continue through the existing staff approval workflow. Because users and staff may perform booking operations concurrently, multiple operations may check the availability of the same space before any of them records its result. Without appropriate concurrency control, conflicting bookings may be approved.

The system must ensure that two approved bookings cannot use the same space during overlapping time periods, regardless of whether the bookings are created through instant booking or staff approval. This rule must remain valid even when multiple users or staff members perform booking and approval operations simultaneously.

#### 1.3. New reporting needs
With the accumulated booking and maintenance history, the Facility Manager needs the system to support the following reports:
* Total approved booking hours of each space for a given semester.
* Number of approved bookings by weekday and hour for a given semester.
* Available spaces that satisfy a required capacity and a required facility list within a given time period.
* Approved bookings affected when a maintenance record is escalated to out-of-service.

Students must implement all of these queries. Then identify suitable indexes for the booking conflict check, the room finder query, and one additional reporting query selected from the list above.

The queries should be tested on a sufficiently large generated dataset so that differences before and after indexing can be observed.

---

### 2. Phase 2

Phase 2 extends the group's Phase 1 database (and agent). Groups must update `AGENT.md` and `SKILL.md` and briefly describe the improvements made.

* **Requirement Change Analysis:** Identify the affected entities, relationships, and business rules. Determine possible conflicts caused by concurrent booking and approval operations. (08-requirement-change-analysis-G11.md)
* **Design Update:** Update the ERD and relational schema to support maintenance impact levels, advisory acknowledgements, and concurrent booking. (09-updated-erd-and-logical-design-G11.md)
* **Schema Migration:** Implement the changes on top of the Phase 1 database. Preserve existing data or document the migration approach. (10-schema-migration-G11.sql)
* **Concurrency Design and Implementation:** Identify at least one concurrency conflict and implement a suitable solution. Provide scripts demonstrating the conflict and its prevention. (11-concurrency-design-G11.md, 12-concurrency-implementation-G11.sql, 13-concurrency-tests-G11/)
* **Sample Data Generation:** Generate at least three academic years of realistic data with at least 100,000 booking records. Groups may increase the dataset to 500,000 records if necessary to demonstrate the effects of indexing. Include maintenance, cancellations, no-shows, and advisory acknowledgements. (14-data-generator-G11/)
* **Analytical Queries:** Implement all reports listed in Section 1.3. Select two reporting queries, other than the room finder, for detailed indexing and performance analysis. (15-index-tuning-report-G11.md, 16-analytical-queries-G11.sql)
* **Indexing and Query Tuning:** Tune the booking conflict check, room finder, and the two selected reporting queries. Compare their execution plans and execution times before and after indexing. (15-index-tuning-report-G11.md)
* **Normalization Validation:** Identify the functional dependencies of the database and ensure that all relations satisfy at least Third Normal Form (3NF).

---

### 3. Required documents

Update `AGENT.md`, `SKILL.md`, and add:
* `08-requirement-change-analysis-G11.md`
* `09-updated-erd-and-logical-design-G11.md`
* `10-schema-migration-G11.sql`
* `11-concurrency-design-G11.md`
* `12-concurrency-implementation-G11.sql`
* `13-concurrency-tests-G11/`
* `14-data-generator-G11/`
* `15-index-tuning-report-G11.md`
* `16-analytical-queries-G11.sql`