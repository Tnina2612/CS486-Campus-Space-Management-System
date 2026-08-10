# Data Generator - G11

Generates a large, reproducible, business-rule-valid Phase 2 dataset for the
Campus Space Management System. It is the seed data used by the index-tuning
report (`15-*`) and the analytical queries (`16-*`).

## What it generates

| Table | Size (config defaults) | Notes |
| :--- | :--- | :--- |
| `users` | ~4,680 | 6 roles, `@gen.school.edu` emails |
| `spaces` | 400 | all 6 types, 4 statuses, auto-booking mix |
| `facility_catalog` | 12 (reused/added) | trackable + non-trackable |
| `space_facility` | ~1,200 | 2-5 instances per space |
| `facility_assets` | ~1,500 | trackable quantities == asset count |
| `bookings` | ~40,000+ | committed + transient, semester 2026-03-02..06-30 |
| `approvals` | ~25,000 | manual + auto (`staff_id` NULL) |
| `usage_sessions` | ~15,000 | Checked In / Completed |
| `maintenance_records` | 1,200 | advisory + out-of-service mix |
| `incident_reports` | 3,000 | room / facility / asset targets |
| `report_consolidations` | ~2,000 | many reports -> one maintenance record |
| `advisory_acknowledgements` | thousands | BR-11 trail |

## Business rules enforced by construction

- **BR-01 (no overlap):** committed bookings (Approved / Checked In /
  Completed / No-show) are placed on disjoint daily time blocks per space, so
  no two committed bookings ever overlap.
- **BR-02 (booking blocking):** a space that is Temporarily Closed / Retired
  gets no bookings; committed bookings never overlap an `out-of-service`
  maintenance window (such slots are skipped).
- **BR-11 (advisory acknowledgement):** any committed booking that overlaps an
  `advisory` maintenance window gets `advisory_acknowledged = 1`, a snapshot,
  and one `advisory_acknowledgements` row per overlapping advisory.
- **BR-12 (impact triage):** `impact_level` is `advisory` or `out-of-service`
  only; end-user incident reports never set it (consolidation reuses the
  maintenance record).
- **BR-14 (report target integrity):** asset-level reports always carry a
  matching `space_facility_id`; the pair exists in `facility_assets`.
- **Trackable quantity rule:** `space_facility.quantity` equals the number of
  registered `facility_assets` for trackable facilities, satisfying
  `TRG_ValidateFacilityQuantity`.

## Prerequisites

- Microsoft SQL Server (2016+).
- Python 3.8+ and `pip install -r requirements.txt` (only `pyodbc`).
- The Phase 1 + Phase 2 schema must exist:
  - `outputs/05-db-definition-G11.sql`
  - `outputs/10-schema-migration-G11.sql`
- Phase 1 sample data (`outputs/06-sample-data-G11.sql`) is optional but
  recommended; the generator preserves it.

## Configuration

Edit `config.json`:

```jsonc
{
  "seed": 42,                                  // fixed -> reproducible output
  "semester_start": "2026-03-02",              // booking window start
  "semester_end": "2026-06-30",                // booking window end
  "users": { "students": 4000, "lecturers": 300, ... },
  "spaces": 400,
  "maintenance_records": 1200,
  "incident_reports": 3000,
  ...
}
```

## Run

```powershell
# 1) install dependency
pip install -r requirements.txt

# 2) ensure schema is applied
sqlcmd -S localhost -E -C -d CampusSpaceManagement -i outputs/05-db-definition-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -i outputs/10-schema-migration-G11.sql

# 3) generate (preserves existing Phase 1 rows)
$env:MSSQL_WINDOWS_AUTH="1"
$env:MSSQL_TRUST_CERT="1"
python outputs/14-data-generator-G11/generate-data.py

# first run on a database that already contains GEN-* data:
python outputs/14-data-generator-G11/generate-data.py --reset
```

Environment variables are identical to the concurrency test suite:
`MSSQL_SERVER`, `MSSQL_DATABASE`, `MSSQL_USER`, `MSSQL_PASSWORD`,
`MSSQL_DRIVER`, `MSSQL_WINDOWS_AUTH`, `MSSQL_TRUST_CERT`.

## Validate and summarize

```powershell
sqlcmd -S localhost -E -C -d CampusSpaceManagement -i outputs/14-data-generator-G11/validation.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -i outputs/14-data-generator-G11/summary.sql
```

`validation.sql` must report **0 violations** for every check (chronology,
orphan FKs, BR-01 overlap, BR-02/BR-11 blocking, advisory acknowledgement,
report-target integrity, rejection reasons, coverage).

## Reset / re-run behavior

- The generator is **additive**: it never deletes pre-existing rows.
- Generated rows are tagged (`space_code LIKE 'GEN-%'`, `email LIKE
  '%@gen.school.edu'`) so `--reset` deletes only them, in reverse FK order.
- A re-run without `--reset` appends a second dataset (also valid, but the
  summary counts both). Use `--reset` for a clean reproducible dataset.
- Identities are assigned explicitly (`SET IDENTITY_INSERT`) starting at
  `MAX(id) + 1` per table, so foreign keys always point at existing parents
  regardless of prior identity seeds.

## Random seed

`seed` in `config.json` (default 42). Changing it changes the dataset; keeping
it fixed yields the identical dataset on every run (given the same starting DB
state).

## Known limitations

- Booking placement is coarse (daily 8:00-19:00 weekday blocks); evening and
  weekend bookings are not generated.
- A space's `In Use` status is not synchronized with generated bookings.
- Maintenance windows may extend a few days past the semester end by design.
