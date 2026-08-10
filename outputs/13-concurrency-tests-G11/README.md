# G11 concurrency demo — SQL Server only

The folder contains one combined SQL Server demo. No Python, ODBC package, or
external runner is required. Eight scenarios are executed: advisory, OOS,
auto-vs-auto, auto-vs-staff, staff-vs-staff, double approval,
escalation-vs-approval, and duplicate incident consolidation.

## Prerequisites

Run these project files once on a new database:

1. `outputs/05-db-definition-G11.sql`
2. `outputs/06-sample-data-G11.sql`
3. `outputs/10-schema-migration-G11.sql`
4. `outputs/12-concurrency-implementation-G11.sql`

## Demo — only four SQL executions

1. Run `00-setup-concurrency-lab-G11.sql` in SSMS.
2. Open two SSMS windows. Run the whole `01-run-all-session-A-G11.sql` file in
   Window A.
3. When Window A prints `SESSION A READY`, immediately run the whole
   `02-run-all-session-B-G11.sql` file in Window B. Do not rerun either session
   file and do not execute selected sections.
4. Wait until both windows print `SESSION ... COMPLETE`, then run
   `03-verify-all-G11.sql` in either window.

The final file must print:

```text
G11 COMBINED CONCURRENCY DEMO: ALL 8 SCENARIOS PASS
```

The `WAITFOR` statements are deliberate. Session A obtains the production row
lock first; Session B then blocks on the same resource and continues only after
Session A commits. This follows the two-session pattern in
`Transactions_Demo.sql` and `Transactions_Demo_2.sql`.

In the consolidation race, SQL Server may choose either session as the winner.
The other session must return `ALREADY_CONSOLIDATED` or be safely selected as a
deadlock victim (`SAFE_DEADLOCK_REJECT`). Both are valid only when the verifier
confirms that the two reports still map to exactly one maintenance record.

Run `99-cleanup-concurrency-lab-G11.sql` only after the demonstration if the
temporary `CONC-*` rows are no longer needed. Setup and cleanup affect only
the dedicated concurrency fixture and preserve Phase 1, `GEN-*`, and `IDX-*`
data.
