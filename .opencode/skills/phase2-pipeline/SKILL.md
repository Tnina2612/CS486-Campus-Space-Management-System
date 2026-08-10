---
name: phase2-pipeline
description: This pipeline orchestrates the automated execution of Phase 2 for the Campus Space Management System. It sequentially triggers skills `08` through `16` to handle requirement changes, schema migrations, concurrency control, large-scale data generation, and performance tuning.
compatibility: opencode
---

# Phase 2 Execution Pipeline Skill

## Strict Constraints: Phase 1 Preservation
* **READ-ONLY ACCESS:** The agent MUST treat all Phase 1 files (directories `01-business-req-analysis` to `07-query-design` inside both `/.opencode/skills/` and `/outputs/`) as STRICTLY READ-ONLY.
* **NO OVERWRITING:** Do not modify, delete, or overwrite any existing Entity-Relationship Diagrams, logical schemas, or sample data generated during Phase 1.
* **ADDITIVE CHANGES ONLY:** All Phase 2 modifications must be implemented additively. Use Phase 1 outputs solely as baseline context. Any database schema changes must be written as `ALTER`, `ADD`, or `UPDATE` SQL statements inside the Phase 2 migration scripts. Do not rewrite the original DDL definitions.

## Terminal Execution Autonomy (MANDATORY)
The agent must independently execute terminal commands when needed and must not require the user to run commands manually.

1. **Schema Inspection:** Use terminal SQL execution (e.g., `sqlcmd` with `SELECT` queries) to inspect existing tables, columns, constraints, and procedures before making changes.
2. **Database Changes:** Apply migration and implementation SQL by executing the generated `.sql` files from terminal.
3. **Validation Queries:** Run terminal SQL checks after migration/implementation (e.g., verify column existence/defaults, procedure existence, and key behavioral checks).
4. **Python Execution:** Run Python files/scripts from terminal for concurrency tests and data-generation validation (e.g., `python outputs/13-concurrency-tests-G11/test_concurrency.py`).
5. **Verification Evidence:** Confirm command outcomes in the workflow narrative (success/failure and what was verified). If a command fails, fix the issue and re-run validation.

## Required Phase 2 Database Additions
These additions are mandatory and must be implemented and validated during the pipeline:

1. **Decouple SPACE operational status from maintenance blocking**
   - Remove `Under Maintenance` from the allowed value set of `SPACE.current_status`.
   - `SPACE.current_status` must represent only broad operational state, not maintenance blocking logic.
   - Booking acceptance/rejection must be determined by time-window overlap with `MAINTENANCE_RECORD` rows where `impact_level = 'out-of-service'`.
   - Advisory/non-blocking maintenance levels must NOT block bookings.
2. **Incident intake separated from maintenance authority**
   - Add a new entity/table `INCIDENT_REPORT` for normal users to submit issue reports.
   - Ensure duplicate incident reports can be consolidated (many reports mapped to one `MAINTENANCE_RECORD`).
   - `impact_level` decision authority must remain on `MAINTENANCE_RECORD` (manager/staff triage), not on end-user reports.
   - `MAINTENANCE_RECORD.impact_level` must default to `'advisory'` unless triage explicitly sets another value.
   - Booking checks must read only `MAINTENANCE_RECORD` and ignore unresolved/duplicate `INCIDENT_REPORT` rows for blocking decisions.
3. **SPACE auto-booking flag**
   - Add `SPACE.auto_booking_enabled` as `BIT NOT NULL`.
   - Set a safe default of `0` (auto-booking disabled by default for existing/new spaces unless explicitly enabled).
4. **APPROVAL nullable staff assignment for automatic approvals**
   - Alter `APPROVAL.staff_id` so that it is nullable (`NULL`); it must no longer be defined as `NOT NULL`.
   - Preserve the existing data and foreign-key relationship/constraint for `staff_id` where applicable.
   - Ensure the schema migration safely changes the column from `NOT NULL` to `NULL` without losing existing approval records.
   - For requests that are automatically approved, `APPROVAL.staff_id` must be stored as `NULL`, because no staff member performed the approval.
   - Manual/staff-approved requests must continue to record the approving staff member in `APPROVAL.staff_id`.
5. **Automatic approval stored procedure**
   - Create a stored procedure named `sp_AutoApproveBookingRequest` that evaluates a booking request against applicable space usage policy constraints.
   - Approve only when all policy checks pass and the target space has `SPACE.auto_booking_enabled = 1`.
   - When the procedure automatically creates or updates the corresponding `APPROVAL` record, it must set `APPROVAL.staff_id = NULL`.
   - If checks fail (including auto-booking disabled), do not auto-approve and return/raise a clear status/error.
   - Validate that the procedure works correctly with the updated nullable `APPROVAL.staff_id` schema.
6. **Facility-instance report target normalization**
   - Normalize the reporting target model so incident reports can describe a room, a facility type inside that room, or a specific tracked asset.
   - Introduce a surrogate `SPACE_FACILITY.space_facility_id` key, re-point `FACILITY_ASSET` to that key, and add nullable `INCIDENT_REPORT.space_facility_id` and `INCIDENT_REPORT.asset_id` columns.
   - Enforce the business rule that `asset_id` requires a non-null `space_facility_id`, and the asset must belong to the selected facility instance.
 
## Workflow Execution Steps

The agent must execute the following steps in exact order. Do not proceed to the next step until the current step's output has been successfully generated and verified.

* **Supplementary Skill:** If the requirement set includes facility-instance report target normalization, the agent must also consult the dedicated `facility-instance-report-normalization` skill for the detailed entity, relationship, and migration rules before drafting the design or migration artifacts.

### Step 1: Requirement Analysis
* **Trigger Skill:** `08-requirement-change-analysis`
* **Context:** Read `req/business-requirement.md` (Phase 2 extensions).
* **Output:** Generate `outputs/08-requirement-change-analysis-G11.md` containing the impact of maintenance levels and concurrency conflicts.

### Step 2: Design Update
* **Trigger Skill:** `09-updated-erd-and-logical-design`
* **Context:** Use Phase 1 ERD as a baseline.
* **Output:** Generate `outputs/09-updated-erd-and-logical-design-G11.md` reflecting advisory acknowledgements and new relationships.

### Step 3: Schema Migration
* **Trigger Skill:** `10-schema-migration`
* **Output:** Generate `outputs/10-schema-migration-G11.sql` containing safe `ALTER TABLE` commands, including adding `SPACE.auto_booking_enabled BIT NOT NULL DEFAULT (0)`, removing `Under Maintenance` from `SPACE.current_status`, creating incident-report structures, and normalizing the facility-instance reporting target model through `SPACE_FACILITY.space_facility_id` and `INCIDENT_REPORT` target columns.
* **Execution:** Apply the migration SQL in terminal, then run validation queries to confirm the status domain update, incident schema, nullable `APPROVAL.staff_id`, and default constraints are present.

### Step 4: Concurrency Strategy
* **Trigger Skill:** `11-concurrency-design`
* **Output:** Generate `outputs/11-concurrency-design-G11.md` explaining the locking or transaction isolation level chosen for the system.

### Step 5: Concurrency Implementation
* **Trigger Skill:** `12-concurrency-implementation`
* **Output:** Generate `outputs/12-concurrency-implementation-G11.sql` with the transaction wrappers/functions, including `sp_AutoApproveBookingRequest`.
* **Execution:** Execute the SQL file in terminal and verify procedures enforce both policy checks and `SPACE.auto_booking_enabled`, while booking-block checks rely only on `MAINTENANCE_RECORD impact_level = 'out-of-service'`.

### Step 6: Concurrency Testing
* **Trigger Skill:** `13-concurrency-tests`
* **Output:** Populate the `outputs/13-concurrency-tests-G11/` directory with SQL transaction files (including both two concurrent instant-booking scripts and a staff-approval overlap script), a Python test script (`test_concurrency.py`), and a `README.md`.
* **Execution:** Run the test SQL/Python scripts in terminal and confirm: two simultaneous instant bookings for overlapping windows do not both succeed, instant-booking vs. staff-approval overlap contention is safely handled, auto-approval behavior is correct for both enabled/disabled auto-booking spaces, advisory maintenance does not block, and out-of-service maintenance blocks overlapping bookings.

### Step 7: Large-Scale Data Generation
* **Trigger Skill:** `14-data-generator`
* **Output:** Populate the `outputs/14-data-generator-G11/` directory with a Python seeder script (`generate_data.py`), `requirements.txt`, and instructions to generate 100,000+ records.
* **Execution:** Execute the Python generator from terminal and validate inserted data via SQL count/check queries.

### Step 8: Analytical Queries
* **Trigger Skill:** `16-analytical-queries`
* **Output:** Generate `outputs/16-analytical-queries-G11.sql` containing the SQL for all requested Phase 2 reports.

### Step 9: Indexing and Tuning
* **Trigger Skill:** `15-index-tuning-report`
* **Context:** Use the queries from Step 8. 
* **Output:** Generate `outputs/15-index-tuning-report-G11.md` documenting the EXPLAIN plans and execution time comparisons before and after applying optimal indexes.

## Completion
Once Step 9 is completed, notify the user to compile `G11_Report_P2.pdf` and finalize the Git repository submission.