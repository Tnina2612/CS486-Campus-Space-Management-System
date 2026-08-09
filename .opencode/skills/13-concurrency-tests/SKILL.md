---
name: 13-concurrency-tests
description: Generate the testing environment to prove the system successfully prevents double-booking conflicts.
compatibility: opencode
---

# Skill: Concurrency Testing

## Description
This skill generates the testing environment to prove the system successfully prevents double-booking conflicts. It produces simultaneous T-SQL transactions and a multi-threaded Python script to simulate real-world concurrent user/staff behavior against the SQL Server.

## Context Files to Read
- `outputs/12-concurrency-implementation-G11.sql` (To know how to execute the stored procedures or transactions)

## Instructions
1. **Create SQL Scenarios:** 
   - Write `tx1_instant_booking.sql`: A transaction simulating a user instantly booking Room A from 09:00 to 11:00.
   - Write `tx2_staff_approval.sql`: A transaction simulating a staff member approving a booking for Room A from 10:00 to 12:00 (overlapping time).
   - Add scenarios proving advisory maintenance does not block booking, while `out-of-service` maintenance does block overlapping booking.
   - Add scenarios showing multiple duplicate `INCIDENT_REPORT` submissions can be consolidated into one `MAINTENANCE_RECORD`.
2. **Create Python Test Runner:** Write a Python script (`test_concurrency.py`) using `threading` or `asyncio` and an MSSQL driver like `pyodbc` or `pymssql`. The script must execute both SQL files simultaneously against the SQL Server database to trigger a race condition.
3. **Capture Output:** Ensure the Python script catches database exceptions (like SqlServer deadlocks, snapshot isolation update conflicts, or custom raised errors) and logs which transaction succeeded and which was safely rejected.
   - Explicitly log outcomes for both advisory vs. out-of-service maintenance checks.
4. **Documentation:** Create a `README.md` and a `requirements.txt` detailing how to install the ODBC drivers and execute the test suite.

## Output
Populate the testing directory with the required scripts.
**Save outputs to the directory:** `outputs/13-concurrency-tests-G11/`
Expected files inside:
- `tx1_instant_booking.sql`
- `tx2_staff_approval.sql`
- `test_concurrency.py`
- `requirements.txt`
- `README.md`