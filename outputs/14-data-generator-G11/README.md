# G11 data generator — SQL Server only

The generator is one deterministic T-SQL script; it has no Python, JSON
configuration, ODBC dependency, or package installation step.

Run these files on SQL Server after `05-db-definition-G11.sql`,
`06-sample-data-G11.sql`, and `10-schema-migration-G11.sql`:

1. `01-generate-data-G11.sql`
2. `validation.sql`
3. `summary.sql`

Example:

```powershell
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/14-data-generator-G11/01-generate-data-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/14-data-generator-G11/validation.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/14-data-generator-G11/summary.sql
```

The fixed seed is `486`. Deterministic set-based arithmetic recreates 400
`GEN-*` spaces, 150,000 non-overlapping bookings from 2023-01-02 to
2026-01-16, 4,000 maintenance records, facilities/assets, approvals, usage
sessions, incident reports, report consolidations, and advisory acknowledgements.

Rerunning the generator deletes only its prior `GEN-*` rows and the two
`@g11.generator.local` users, in foreign-key-safe order. It preserves Phase 1
sample data, `CONC-*` concurrency-lab rows, and `IDX-*` indexing-demo rows.
The script runs in one transaction: a failure rolls back its reset and inserts.

`validation.sql` must show zero violations in every row. `summary.sql` shows
the generated counts and distributions.
