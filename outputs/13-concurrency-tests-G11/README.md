# Concurrency Tests - G11

Proves that the Campus Space Management System **cannot double-book** a space,
even when two users/staff operate simultaneously.

## What is tested

Two concurrent transactions target the same space `TEST-ROOM-A` on
`2026-03-02`:

| File | Operation | Time window |
| :--- | :--- | :--- |
| `tx1_instant_booking.sql` | Auto booking (auto-approve) via `sp_AutoApproveBookingRequest` | 09:00–11:00 |
| `tx2_staff_approval.sql` | Staff approval of a *pending* booking via `sp_book_space_staff_approve` | 10:00–12:00 |

The windows overlap (10:00–11:00). The pessimistic locking guard
(`WITH (UPDLOCK, HOLDLOCK)`) in the stored procedures (outputs/
`12-concurrency-implementation-G11.sql`) makes exactly one of the two succeed.
The loser returns `@result_status = 'OVERLAP'` and rolls back; the runner
classifies the outcome from the returned status (each SQL file ends with a
`SELECT <status> AS result_status;` result set).

## Prerequisites

1. Microsoft SQL Server (2016+; STRING_AGG is used in the procedures).
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

## Run the test

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

`test_concurrency.py` accepts the number of rounds as an argument (default 5).

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

## What the script does

1. **Setup** — inserts a test user, staff, `TEST-ROOM-A` (with
   `AutoBookingEnabled = 1` so the auto path applies, per RC-05, and a usage
   policy permitting `Seminar`), and one `Pending` booking (10:00–12:00) that
   `tx2` approves. All generated ids are captured with the `OUTPUT INSERTED`
   clause in the **same batch** as the `INSERT`; using `SCOPE_IDENTITY()` in a
   separate pyodbc `execute()` call is unreliable (it returns the previous
   insert's identity), which can point `tx2` at a stale, pre-existing booking
   and mask the real race.
2. **Race** — spawns two threads with independent connections, synchronized on
   a barrier so both procedure calls start together.
3. **Capture** — each SQL file ends with `SELECT ISNULL(@rs, N'NO_STATUS') AS result_status;`.
   The runner compares the returned status against the expected success status
   (`AUTO_APPROVED` for tx1, `APPROVED` for tx2): a match is logged as `COMMIT`,
   anything else (e.g. `OVERLAP`) as `REJECTED`. Any ODBC error also counts as
   `REJECTED`. This avoids relying on exception propagation across pyodbc
   multi-statement batches (a trailing `THROW` after an `EXEC` that rolled back
   is not surfaced by the ODBC driver, while sqlcmd raises it correctly).
4. **Assert** — counts approved bookings on the space for the day; **exactly 1**
   must remain. Any round with 0 or 2 is reported as FAIL and the script exits
   with code 1.
5. **Teardown** — removes all test rows so rounds are independent.

## Expected output

```
--- Round 1 ---
  tx1_auto    : COMMIT
  tx2_approval: REJECTED  -> status=OVERLAP
  Approved bookings on space after race: 1  (must be exactly 1) -> PASS
```

(Which transaction wins may vary between rounds; the invariant is that exactly
one does, and the loser is rejected with `status=OVERLAP` — a real overlap
conflict, not a "booking not pending" error.)
