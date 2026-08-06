---
name: phase2-pipeline
description: This pipeline orchestrates the automated execution of Phase 2 for the Campus Space Management System. It sequentially triggers skills `08` through `16` to handle requirement changes, schema migrations, concurrency control, large-scale data generation, and performance tuning
compatibility: opencode
---

# Phase 2 Execution Pipeline Skill

## Strict Constraints: Phase 1 Preservation
* **READ-ONLY ACCESS:** The agent MUST treat all Phase 1 files (directories `01-business-req-analysis` to `07-query-design` inside both `/.opencode/skills/` and `/outputs/`) as STRICTLY READ-ONLY.
* **NO OVERWRITING:** Do not modify, delete, or overwrite any existing Entity-Relationship Diagrams, logical schemas, or sample data generated during Phase 1.
* **ADDITIVE CHANGES ONLY:** All Phase 2 modifications must be implemented additively. Use Phase 1 outputs solely as baseline context. Any database schema changes must be written as `ALTER`, `ADD`, or `UPDATE` SQL statements inside the Phase 2 migration scripts. Do not rewrite the original DDL definitions.

## Workflow Execution Steps

The agent must execute the following steps in exact order. Do not proceed to the next step until the current step's output has been successfully generated and verified.

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
* **Output:** Generate `outputs/10-schema-migration-G11.sql` containing safe `ALTER TABLE` commands.

### Step 4: Concurrency Strategy
* **Trigger Skill:** `11-concurrency-design`
* **Output:** Generate `outputs/11-concurrency-design-G11.md` explaining the locking or transaction isolation level chosen for the system.

### Step 5: Concurrency Implementation
* **Trigger Skill:** `12-concurrency-implementation`
* **Output:** Generate `outputs/12-concurrency-implementation-G11.sql` with the transaction wrappers/functions.

### Step 6: Concurrency Testing
* **Trigger Skill:** `13-concurrency-tests`
* **Output:** Populate the `outputs/13-concurrency-tests-G11/` directory with SQL transaction files, a Python test script (`test_concurrency.py`), and a `README.md`.

### Step 7: Large-Scale Data Generation
* **Trigger Skill:** `14-data-generator`
* **Output:** Populate the `outputs/14-data-generator-G11/` directory with a Python seeder script (`generate_data.py`), `requirements.txt`, and instructions to generate 100,000+ records.

### Step 8: Analytical Queries
* **Trigger Skill:** `16-analytical-queries`
* **Output:** Generate `outputs/16-analytical-queries-G11.sql` containing the SQL for all requested Phase 2 reports.

### Step 9: Indexing and Tuning
* **Trigger Skill:** `15-index-tuning-report`
* **Context:** Use the queries from Step 8. 
* **Output:** Generate `outputs/15-index-tuning-report-G11.md` documenting the EXPLAIN plans and execution time comparisons before and after applying optimal indexes.

## Completion
Once Step 9 is completed, notify the user to compile `G11_Report_P2.pdf` and finalize the Git repository submission.