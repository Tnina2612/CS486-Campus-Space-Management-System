---
name: 13-concurrency-tests
description: Generate the testing environment to prove the system successfully prevents double-booking conflicts, duplicate approvals, and escalation races.
compatibility: opencode
---

# Skill: Concurrency Testing

## Description
This skill generates the testing environment to prove the system successfully prevents double-booking conflicts, duplicate approvals, and escalation-vs-approval races. It produces simultaneous T-SQL transactions and a multi-threaded Python script to simulate real-world concurrent user/staff behavior against the SQL Server.

## Context Files to Read
- `outputs/12-concurrency-implementation-G11.sql` (To know how to execute the stored procedures or transactions)

## Instructions
1. **Create SQL Scenarios:**
   - Write `tx1_instant_booking.sql`: A transaction simulating a user instantly booking Room A from 09:00 to 11:00.
   - Write `tx2_instant_booking.sql`: A second transaction simulating another user instantly booking Room A from 10:00 to 12:00 (overlapping time) to test same-flow race conditions.
   - Write `tx2_staff_approval.sql`: A transaction simulating a staff member approving a booking for Room A from 10:00 to 12:00 (overlapping time) to test cross-flow contention with manual approval.
   - Add scenarios proving advisory maintenance does not block booking, while `out-of-service` maintenance does block overlapping booking.
   - Add scenario for **Staff vs Staff** contention (`tx5_staff_approval_b.sql`): a transaction simulating a second staff member approving a *different* pending booking that overlaps the same space+time window as the booking in `tx2_staff_approval.sql`. This tests the system's ability to prevent two staff members from independently approving two different pending bookings that would create an overlap.
   - Add scenario for **Double-approve** (`tx6_double_approve.sql`): a transaction calling `sp_book_space_staff_approve` for *the same* `@booking_id` as another concurrent thread. This tests the system records exactly one approval row per booking.
   - Add scenario for **Escalation vs Approval** (`tx7_escalate_impact.sql`): a transaction calling `sp_set_maintenance_impact` to escalate a maintenance record from `advisory` to `out-of-service`, concurrent with a booking-approval thread that targets the same space and overlapping time window. This tests that once escalation commits, the approval thread correctly detects the `out-of-service` block.
   - Add scenario showing multiple duplicate `INCIDENT_REPORT` submissions can be consolidated into one `MAINTENANCE_RECORD` **under concurrent execution** (two threads + barrier calling `sp_consolidate_incident_reports` simultaneously on the same set of reports).
2. **Create Python Test Runner:** Write a Python script (`test_concurrency.py`) using `threading` and `pyodbc`. The script must execute the following scenarios, each proving a distinct concurrency invariant:
   - **Scenario 1 (Race — BR-01):** Two threads (with barrier) — `tx1_instant_booking.sql` vs `tx2_staff_approval.sql` — to trigger race conditions between auto-booking and staff approval on overlapping windows. Run for N rounds (configurable, default 5).
   - **Scenario 2 (Advisory — BR-12):** Single thread — advisory maintenance does NOT block an auto-booking.
   - **Scenario 3 (Out-of-Service — BR-11):** Single thread — out-of-service maintenance DOES block an auto-booking.
   - **Scenario 4 (Consolidation — C8):** Two threads (with barrier) calling `sp_consolidate_incident_reports` simultaneously on the same set of reports to prove that the system creates exactly one `MAINTENANCE_RECORD` and the second thread's attempt returns `ALREADY_CONSOLIDATED`.
   - **Scenario 5 (Staff vs Staff — T3):** Two threads (with barrier) — each simulates a different staff member approving a *different* pending booking, but both bookings target the same space and overlapping time window. Invariant: exactly one approval survives; the other returns `OVERLAP`.
   - **Scenario 6 (Double-approve):** Two threads (with barrier) calling `sp_book_space_staff_approve` with *exactly the same* `@booking_id`. Invariant: after both finish, exactly one approval row exists in `dbo.approvals` for that `booking_id`.
   - **Scenario 7 (Escalation vs Approval — T4):** Two threads (with barrier) — Thread A calls `sp_set_maintenance_impact` to escalate a maintenance record from `advisory` to `out-of-service`; Thread B calls `sp_book_space_staff_approve` to approve a pending booking that overlaps the maintenance window. Invariant: if escalation commits first, the booking approval must be rejected with `OUT_OF_SERVICE`; if the booking commits first, the escalation should still succeed but the booking is already committed (surfaced as an affected booking in the escalation result set).
3. **Capture Output:** Ensure the Python script catches database exceptions (like SQL Server deadlocks, snapshot isolation update conflicts, or custom raised errors) and logs which transaction succeeded and which was safely rejected.
   - Explicitly log outcomes for both advisory vs. out-of-service maintenance checks.
   - For the Consolidation scenario: log whether each thread received `CONSOLIDATED` or `ALREADY_CONSOLIDATED` and verify exactly one `MAINTENANCE_RECORD` was created.
   - For Staff vs Staff: log both approval results and verify exactly one approved booking.
   - For Double-approve: log both results and verify exactly one `dbo.approvals` row for the booking.
   - For Escalation vs Approval: log the race outcome (which thread won) and verify the invariant holds regardless of execution order.
4. **Documentation:** Create a `README.md` and a `requirements.txt` detailing how to install the ODBC drivers and execute the test suite.

## Output
Populate the testing directory with the required scripts.
**Save outputs to the directory:** `outputs/13-concurrency-tests-G11/`
Expected files inside:
- `tx1_instant_booking.sql`
- `tx2_instant_booking.sql`
- `tx2_staff_approval.sql`
- `tx5_staff_approval_b.sql`
- `tx6_double_approve.sql`
- `tx7_escalate_impact.sql`
- `test_concurrency.py`
- `requirements.txt`
- `README.md`