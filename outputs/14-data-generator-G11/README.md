# Data Generator — G11

Large-scale Phase 2 data generator for the Campus Space Management System
(SQL Server). Produces at least **100,000 bookings** across **3 academic years**
plus all supporting entities required by Phase 2.

## Files

| File | Purpose |
| :--- | :--- |
| `config.json` | All tunable generation parameters (seed, sizes, semester windows, weights). |
| `generate-data.py` | The generator script (uses `pyodbc`). |
| `validation.sql` | Integrity checks — every check must report zero invalid rows. |
| `summary.sql` | Informational counts (bookings by year/status, maintenance, acknowledgements). |
| `README.md` | This file. |

## Prerequisites

- Python 3.8+ with `pyodbc` installed: `pip install pyodbc`
- ODBC Driver 17/18 for SQL Server
- SQL Server with `CampusSpaceManagement`
- Phase 1 DDL + sample data executed (`outputs/05-db-definition-G11.sql`,
  `outputs/06-sample-data-G11.sql`)
- Phase 2 migration executed (`outputs/10-schema-migration-G11.sql`)

## Configuration

Edit `config.json`:

- `random_seed` — deterministic output (default `486`)
- `academic_years`, `target_bookings` — dataset scale (default 100,000)
- `config_semester_rows` — semester windows used to spread booking dates
- `booking_status_weights` — distribution of booking statuses
- `maintenance_impact_weights` — advisory vs out-of-service split

## Generation command

```bash
cd outputs/14-data-generator-G11
python generate-data.py
```

Override the connection string with the environment variable `CS486_CONN` if
needed:

```bash
$env:CS486_CONN="DRIVER={ODBC Driver 18 for SQL Server};SERVER=...;DATABASE=CampusSpaceManagement;Trusted_Connection=yes;"
python generate-data.py
```

## Import command

The generator inserts directly into SQL Server via `pyodbc` in batched
transactions (autocommit off, periodic `COMMIT`). No separate import step is
required.

## Validation command

Open SSMS or `sqlcmd` and run `validation.sql`. Expected result: **zero rows**
for every integrity check (checks 2–9). Check 1 is informational (record counts).

```bash
sqlcmd -S localhost -d CampusSpaceManagement -i validation.sql
```

## Summary command

```bash
sqlcmd -S localhost -d CampusSpaceManagement -i summary.sql
```

## Guarantees enforced by the generator

- Deterministic via fixed random seed
- Valid FK references (identities captured via `SCOPE_IDENTITY()`)
- `start_time < end_time` always
- No two approved/occupied bookings overlap the same space
- No approved booking overlaps `out-of-service` maintenance
- Advisory maintenance allowed; acknowledgement rows created for every affected
  approved booking
- Phase 1 data preserved

## Known limitations

- Bookings are generated sequentially (not via the concurrency-safe stored
  procedure) so that the overlap invariants hold by construction; the
  concurrency tests in `outputs/13-concurrency-tests-G11/` exercise the live
  stored procedure separately.
- Generation is single-process; for 500,000+ bookings, consider increasing
  `target_bookings` and running with a faster machine / batching more frequently.
