# Large-Scale Data Generator - G11

Seeds the Campus Space Management System (Phase 1 + Phase 2 migrated schema)
with **100,000+ records** so the analytical queries
(`outputs/16-analytical-queries-G11.sql`) and the index-tuning report
(`outputs/15-index-tuning-report-G11.md`) run against a realistic workload.

## What is generated

| Table | Default volume | Notes |
| :--- | :--- | :--- |
| `users` | 3,000 | roles weighted toward Students; unique `gen.user.*@campus.edu` emails |
| `spaces` | 400 | 8 space types, unique `GEN-*` codes, Phase 2 `instant_bookable` (RC-05) |
| `facility_catalog` | 20 | mix of trackable / non-trackable facilities |
| `facility_assets` | ~1,000 | assets inserted **before** `space_facility` so the `TRG_ValidateFacilityQuantity` trigger (trackable quantity ≤ asset count) never fires |
| `space_facility` | ~1,800 | trackable quantity == asset count (trigger-safe) |
| `bookings` | 100,000 | scheduled on a **non-overlapping per-space time grid** so BR-01 (no double-booking) holds; Phase 2 advisory fields (RC-03) |
| `approvals` | ~83,000 | one per decided booking; rejection reasons for `Rejected` |
| `usage_sessions` | ~40,000 | only for `Checked In` / `Completed` bookings |
| `maintenance_records` | 8,000 | mixed `advisory` / `out-of-service` impact levels (RC-01) |

Total ≈ 235,000+ rows (bookings alone exceed 100,000).

## Prerequisites

1. Microsoft SQL Server (2016+).
2. ODBC Driver 17/18 for SQL Server.
3. Python 3.8+ and `pip install -r requirements.txt`.

## Before you run

Apply the schema, sample data and Phase 2 additions in this order
(identical to the concurrency-test workflow):

```powershell
# from the repository root
sqlcmd -S localhost -U sa -P <pwd> -i outputs/05-db-definition-G11.sql
sqlcmd -S localhost -U sa -P <pwd> -i outputs/06-sample-data-G11.sql
sqlcmd -S localhost -U sa -P <pwd> -i outputs/10-schema-migration-G11.sql
```

## Run the generator

```powershell
# Windows Authentication
$env:MSSQL_WINDOWS_AUTH="1"
python outputs/14-data-generator-G11/generate_data.py

# SQL authentication
$env:MSSQL_SERVER="localhost"
$env:MSSQL_USER="sa"
$env:MSSQL_PASSWORD="YourStrong!Passw0rd"
python outputs/14-data-generator-G11/generate_data.py --bookings 100000
```

### Options

| Flag | Default | Purpose |
| :--- | :--- | :--- |
| `--users` | `3000` | number of users |
| `--spaces` | `400` | number of spaces |
| `--bookings` | `100000` | number of bookings (drives the 100,000+ requirement) |
| `--maintenance` | `8000` | number of maintenance records |
| `--seed` | `11` | random seed for reproducible data |

The script is **re-runnable**: it records the identity baselines before
inserting, so running it twice appends rather than colliding on UNIQUE keys.

## Environment variables

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `MSSQL_SERVER` | `localhost` | SQL Server host |
| `MSSQL_DATABASE` | `CampusSpaceManagement` | Target database |
| `MSSQL_USER` | `sa` | Login (ignored with Windows auth) |
| `MSSQL_PASSWORD` | `YourStrong!Passw0rd` | Password |
| `MSSQL_DRIVER` | `ODBC Driver 17 for SQL Server` | ODBC driver name |
| `MSSQL_WINDOWS_AUTH` | `0` | Set `1` to use `Trusted_Connection` |

## Design guarantees

- **No double-booking (BR-01):** every space gets a disjoint set of time slots
  (all `(day, start-hour)` combinations visited exactly once), so no two
  bookings on one space overlap.
- **Trigger-safe facilities:** physical assets are created before the
  `space_facility` rows that reference them.
- **Phase 2 columns populated:** `spaces.instant_bookable` (RC-05),
  `bookings.advisories_acknowledged` / `advisories_snapshot` (RC-03),
  `maintenance_records.impact_level` (RC-01).

## Verification

After seeding, the analytical reports (outputs/16-analytical-queries-G11.sql)
should return meaningful rows. Quick sanity check:

```sql
SELECT COUNT(*) FROM dbo.bookings;                     -- >= 100,000
SELECT COUNT(*) FROM dbo.bookings                       -- must be 0
 WHERE status IN ('Approved','Checked In','Completed')
   AND EXISTS (SELECT 1 FROM dbo.bookings b2
               WHERE b2.space_id = dbo.bookings.space_id
                 AND b2.booking_id <> dbo.bookings.booking_id
                 AND b2.status IN ('Approved','Checked In','Completed')
                 AND b2.start_time < dbo.bookings.end_time
                 AND b2.end_time > dbo.bookings.start_time);
```
