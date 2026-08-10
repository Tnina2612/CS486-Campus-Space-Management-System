# Concurrency Tests - G11

Proves that the Campus Space Management System **cannot double-book** a space,
even when two users/staff operate simultaneously, and that the Phase 2
maintenance, incident, and escalation rules behave correctly under concurrency.

## What is tested

`test_concurrency.py` runs eight scenarios:

| # | Scenario | Files used | Invariant |
| :--- | :--- | :--- | :--- |
| 1 | Concurrent instant-booking vs staff approval on overlapping windows | `tx1_instant_booking.sql`, `tx2_staff_approval.sql` | exactly **one** approved booking survives (BR-01) |
| 1b | Two concurrent instant bookings on overlapping windows | `tx1_instant_booking.sql`, `tx2_instant_booking.sql` | exactly **one** approved booking survives (BR-01, same flow) |
| 2 | Advisory maintenance overlaps the requested window | `tx3_advisory_booking.sql` | booking is **auto-approved**; advisory does not block (BR-12); acknowledgement row recorded; `APPROVAL.staff_id = NULL` |
| 3 | Out-of-service maintenance overlaps the requested window | `tx4_oos_booking.sql` | booking is **blocked** with `OUT_OF_SERVICE`; no booking row written (BR-11) |
| 4 | Duplicate `INCIDENT_REPORT` submissions are consolidated concurrently | (inline) `sp_consolidate_incident_reports` | many reports -> **one** `MAINTENANCE_RECORD`; second triage returns `ALREADY_CONSOLIDATED` |
| 5 | Two staff members approve two *different* overlapping pending bookings | `tx2_staff_approval.sql`, `tx5_staff_approval_b.sql` | exactly **one** approval survives (T3) |
| 6 | Two staff members approve the *same* pending booking | `tx6_double_approve.sql` (x2 threads) | exactly **one** `dbo.approvals` row exists (double-approve guard) |
| 7 | Escalation `advisory` -> `out-of-service` races a staff approval | `tx7_escalate_impact.sql`, `tx2_staff_approval.sql` | escalation always commits to `out-of-service`; if it commits first the approval is rejected, otherwise the booking is surfaced as an affected booking (T4) |

### Race windows (Scenario 1)

Two concurrent transactions target the same space `TEST-ROOM-A` on
`2026-03-02`:

| File | Operation | Time window |
| :--- | :--- | :--- |
| `tx1_instant_booking.sql` | Auto booking (auto-approve) via `sp_AutoApproveBookingRequest` | 09:00–11:00 |
| `tx2_staff_approval.sql` | Staff approval of a *pending* booking via `sp_book_space_staff_approve` | 10:00–12:00 |

The windows overlap (10:00–11:00). The pessimistic locking guard
(`WITH (UPDLOCK, HOLDLOCK)` in the stored procedures, outputs/
`12-concurrency-implementation-G11.sql`) makes exactly one of the two succeed.
The loser is caught by its `TRY...CATCH` and mapped to `OVERLAP`; the runner
classifies the outcome from the trailing `result_status` column of each SQL
file.

## Prerequisites

1. Microsoft SQL Server (2016+; `STRING_AGG` is used in the procedures).
2. ODBC Driver for SQL Server (17 or 18):
   - Windows: install "ODBC Driver 17/18 for SQL Server".
   - Linux/macOS: `brew install msodbcsql17` or the Microsoft apt/yum packages.
3. Python 3.8+ and `pip install -r requirements.txt`.

## Before you run

Apply the Phase 1 database and the Phase 2 additions in this order:

```powershell
# from the repository root
sqlcmd -S localhost -U sa -P <pwd> -i outputs/05-db-definition-G11.sql
sqlcmd -S localhost -U sa -P <pwd> -i outputs/06-sample-data-G11.sql
sqlcmd -S localhost -U sa -P <pwd> -i outputs/10-schema-migration-G11.sql
sqlcmd -S localhost -U sa -P <pwd> -i outputs/12-concurrency-implementation-G11.sql
```

## Run the tests

```powershell
# Windows Authentication
$env:MSSQL_WINDOWS_AUTH="1"
$env:MSSQL_TRUST_CERT="1"   # required for self-signed dev certs (ODBC 18)
python outputs/13-concurrency-tests-G11/test_concurrency.py 5

# SQL authentication
$env:MSSQL_SERVER="localhost"
$env:MSSQL_USER="sa"
$env:MSSQL_PASSWORD="YourStrong!Passw0rd"
$env:MSSQL_TRUST_CERT="1"
python outputs/13-concurrency-tests-G11/test_concurrency.py 5
```

`test_concurrency.py` accepts the number of race rounds as an argument
(default 5). Scenarios 2–7 run once each; scenarios 1 and 1b run `rounds`
times.

## Environment variables

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `MSSQL_SERVER` | `localhost` | SQL Server host |
| `MSSQL_DATABASE` | `CampusSpaceManagement` | Target database |
| `MSSQL_USER` | `sa` | Login (ignored with Windows auth) |
| `MSSQL_PASSWORD` | `YourStrong!Passw0rd` | Password |
| `MSSQL_DRIVER` | `ODBC Driver 18 for SQL Server` | ODBC driver name |
| `MSSQL_WINDOWS_AUTH` | `0` | Set `1` to use `Trusted_Connection` |
| `MSSQL_TRUST_CERT` | `0` | Set `1` to add `TrustServerCertificate=yes` |

## How the script works

1. **Setup** — each scenario inserts its own test users, spaces, and rows.
   `TEST-*` spaces use `auto_booking_enabled = 1` (except where the scenario
   needs it off). Generated ids are captured with `OUTPUT INSERTED`.
2. **Race** — spawns two threads with independent connections, synchronized on
   a barrier so both procedure calls start together.
3. **Capture** — each SQL file ends with
   `SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;`. The runner scans all
   result sets for the `result_status` column (the procedures also emit
   informational SELECTs) and compares against the expected success status
   (`AUTO_APPROVED`/`APPROVED`/`ESCALATED`): a match is logged as `COMMIT`,
   anything else as `REJECTED`. Any ODBC error also counts as `REJECTED`.
4. **Assert** — each scenario verifies its invariant with a fresh connection:
   exactly one approved booking, zero bookings on a blocked space, exactly one
   `MAINTENANCE_RECORD`, exactly one approval row, etc.
5. **Teardown** — removes all test rows so scenarios/rounds are independent.

## Expected output (abridged)

```
SCENARIO 1: concurrent instant-booking vs staff approval (BR-01)
--- Round 1 ---
  tx1_auto    : COMMIT   -> AUTO_APPROVED
  tx2_approval: REJECTED -> status=OVERLAP
  Approved bookings after race: 1 (must be exactly 1) -> PASS
...
SCENARIO 2: advisory maintenance does not block booking (BR-12)
  tx3 booking   : AUTO_APPROVED -> AUTO_APPROVED
  acknowledgement rows recorded: 1 (must be >= 1) -> PASS
  approvals with staff_id NULL (auto actor): 1 (must be 1) -> PASS
SCENARIO 3: out-of-service maintenance blocks booking (BR-11)
  tx4 booking   : BLOCKED -> status=OUT_OF_SERVICE
  bookings written on blocked space: 0 (must be 0) -> PASS
SCENARIO 4: duplicate incident reports consolidate into one record (C8)
  thread A result: CONSOLIDATED
  thread B result: ALREADY_CONSOLIDATED
  distinct maintenance records for the reports: 1 (must be 1)
SCENARIO 5: staff vs staff approval of overlapping bookings (T3)
  staff A (booking X): COMMIT   -> APPROVED
  staff B (booking Y): REJECTED -> status=OVERLAP
  Approved bookings after race: 1 (must be exactly 1) -> PASS
SCENARIO 6: double-approve the same booking (one approval row)
  thread A (staff C): COMMIT   -> APPROVED
  thread B (staff D): REJECTED -> status=NOT_PENDING
  approval rows for booking X: 1 (must be 1) -> PASS
SCENARIO 7: escalation vs approval race (T4)
  escalation (advisory->out-of-service): COMMIT -> ESCALATED
  approval of pending booking           : REJECTED -> status=OVERLAP
  maintenance impact_level now          : out-of-service
  booking status                        : Pending
```

(Which transaction wins the race may vary between rounds; the invariant is
that exactly one does and the loser is safely rejected.)
