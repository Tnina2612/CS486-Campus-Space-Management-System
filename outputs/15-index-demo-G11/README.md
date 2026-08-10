# G11 indexing demo — combined SQL-only runbook

This folder reuses the 150,000 deterministic `GEN-*` bookings created by the
SQL Server-only Phase 14 generator. It does not create a duplicate dataset and
requires no Python or external runner.

## Safety and prerequisites

`outputs/05-db-definition-G11.sql` drops and recreates the database named
`CampusSpaceManagement`. Use this sequence only on a local/demo SQL Server.

On a new environment, run these project files first:

1. `outputs/05-db-definition-G11.sql`
2. `outputs/06-sample-data-G11.sql`
3. `outputs/10-schema-migration-G11.sql`
4. `outputs/12-concurrency-implementation-G11.sql`
5. `outputs/14-data-generator-G11/01-generate-data-G11.sql`
6. `outputs/14-data-generator-G11/validation.sql`

## Index demo — only four SQL executions

1. Run `00-prepare-index-demo-G11.sql`. It checks and validates the Phase 14
   fixture, removes temporary `CONC-*`/legacy `IDX-*` rows, removes the four
   tuned indexes, and refreshes statistics for the baseline.
2. Press **Ctrl+M** in SSMS, then run
   `01-benchmark-before-indexing-G11.sql`.
3. Keep Actual Execution Plan enabled and run
   `02-create-indexes-and-benchmark-after-G11.sql`. This creates all four
   indexes and immediately repeats the identical workload.
4. Run `03-compare-and-validate-G11.sql`. It shows the Before/After table,
   checks unchanged result counts, and must finish with:

```text
G11 INDEX DEMO VALIDATION: PASS
```

Focus on the Room Finder plans and Messages tab during the demonstration:

- Before: high logical reads; booking and maintenance probes scan.
- After: much lower logical reads; the same probes seek.
- Correctness: all four Before/After result counts are equal.

Read `VERIFIED-RESULTS.md` for the verified reference values and
`../15-index-tuning-report-G11.md` for the full analysis. Timing varies by
machine; logical reads and unchanged results are the primary evidence.

## Optional sqlcmd execution

```powershell
sqlcmd -S localhost -E -C -d master -b -i outputs/05-db-definition-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/06-sample-data-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/10-schema-migration-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/12-concurrency-implementation-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/14-data-generator-G11/01-generate-data-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/14-data-generator-G11/validation.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/15-index-demo-G11/00-prepare-index-demo-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/15-index-demo-G11/01-benchmark-before-indexing-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/15-index-demo-G11/02-create-indexes-and-benchmark-after-G11.sql
sqlcmd -S localhost -E -C -d CampusSpaceManagement -b -i outputs/15-index-demo-G11/03-compare-and-validate-G11.sql
```

The `-b` option makes `sqlcmd` return a non-zero exit code when SQL Server
reports an error.
