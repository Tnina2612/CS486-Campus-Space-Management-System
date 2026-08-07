# Concurrency Tests — G11

This folder proves that the concurrency-safe booking path
(`outputs/12-concurrency-implementation-G11.sql`) prevents overlapping approved
bookings for the same space (business rule BR-01), even when two operations run
simultaneously.

## Files

| File | Purpose |
| :--- | :--- |
| `tx1_instant_booking.sql` | Represents an instant booking (09:00–11:00). |
| `tx2_staff_approval.sql` | Represents an overlapping staff-approved booking (10:00–12:00). |
| `test_concurrency.py` | Runs both operations concurrently and asserts exactly one succeeds. |
| `requirements.txt` | Python dependencies (pyodbc). |
| `README.md` | This file. |

## Prerequisites

1. SQL Server with the `CampusSpaceManagement` database.
2. Execute Phase 1 DDL (`outputs/05-db-definition-G11.sql`) and sample data
   (`outputs/06-sample-data-G11.sql`).
3. Execute the Phase 2 migration (`outputs/10-schema-migration-G11.sql`).
4. Deploy the concurrency implementation (`outputs/12-concurrency-implementation-G11.sql`).
5. ODBC Driver 17/18 for SQL Server installed on the test machine.

## Install Python dependencies

```bash
pip install -r requirements.txt
```

## Run the test

```bash
python test_concurrency.py
```

The runner opens two threads, each opening its own connection, and invokes
`usp_CreateBooking` for overlapping windows on the same space. Because the
procedure takes an `UPDLOCK, HOLDLOCK` on the space row, one transaction blocks
until the other commits; the second then sees the first's approved booking and
is rejected.

## Expected output

```
Results:
  tx1_instant_booking: SUCCESS
  tx2_staff_approval: REJECTED: Overlapping approved booking already exists.
Successful bookings: 1
PASS: concurrency control rejected the overlap.
```

## How the race is demonstrated

To observe the race **without** concurrency control, temporarily replace
`usp_CreateBooking` with a version that performs the overlap `SELECT` and the
`INSERT` in separate transactions (or without the `WITH (UPDLOCK, HOLDLOCK)`
hint). Running the same test then produces two `SUCCESS` rows for overlapping
periods — the double-booking defect described in
`outputs/11-concurrency-design-G11.md`.

## Customization

The default connection string, space id, and user ids can be overridden via
environment variables: `CS486_CONN`, `CS486_SPACE_ID`, `CS486_USER_A`,
`CS486_USER_B`. Adjust `SPACE_ID` to a space with `allows_instant_booking = 1`
in your dataset.
