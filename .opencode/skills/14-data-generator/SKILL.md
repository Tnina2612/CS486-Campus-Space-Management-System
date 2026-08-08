# Skill 14 — Generate Phase 2 Data

## Goal

Create:

```text
14-data-generator-G11/
```

Generate realistic and reproducible Phase 2 data for:

* Functional testing
* Analytical queries
* Index tuning
* Performance testing

## Read before starting

Read:

```text
req/business-requirement.md
```

Then read and reuse:

```text
08-requirement-change-analysis-G11.md
09-updated-erd-and-logical-design-G11.md
10-schema-migration-G11.sql
11-concurrency-design-G11.md
12-concurrency-implementation-G11.sql
13-concurrency-tests-G11/
AGENT.md
SKILL.md
```

Use the exact DBMS, schema, keys, relationships, statuses, constraints, and business rules defined in those files.

Do not redesign the schema or invent new columns, statuses, or rules.

## Required output

```text
14-data-generator-G11/
├── README.md
├── config.json
├── generate-data.py
├── requirements.txt
├── validation.sql
└── summary.sql
```

A generated data file may also be included when useful.

## Data generator

`generate-data.py` must:

* Use a fixed random seed.
* Generate realistic data.
* Support configurable dataset size through `config.json`.
* Generate enough data for analytical queries and index tuning.
* Follow all schema constraints and business rules.
* Cover important Phase 2 cases.
* Produce reproducible results.

The exact entities, distributions, time ranges, states, and special cases must be derived from the business requirements and previous deliverables.

## ID and foreign-key handling

The generator must keep generated primary keys and foreign keys consistent.

* Do not assume SQL Server `IDENTITY` values will start from `1` or match in-memory counters.
* Do not mix hard-coded IDs with automatically generated database IDs unless they are explicitly synchronized.
* If the generator creates explicit IDs in memory, insert those same IDs into the database using the DBMS-supported identity override mechanism.
* If the database generates IDs automatically, retrieve the actual generated IDs and use those values for all child records.
* Generate parent rows before dependent rows.
* Never generate a foreign key unless the referenced parent ID is known to exist.

For SQL Server, if explicit IDs are used, use:

```sql
SET IDENTITY_INSERT table_name ON;
-- insert explicit IDs
SET IDENTITY_INSERT table_name OFF;
```

where applicable.

## Reset and rerun behavior

The generator must work correctly even when the database already contains data from an earlier generator run.

If the generator is intended to recreate the synthetic dataset:

* Delete generated rows in reverse foreign-key order.
* Reset identity counters where applicable.
* Handle tables without identity columns correctly.
* Do not assume the database is empty.
* Perform the reset before building or inserting data that depends on fixed IDs.

If existing Phase 1 data must be preserved, do not delete it. In that case, use actual generated IDs from the database instead of fixed `1..N` assumptions.

## Transactions

Use a transaction for data insertion where practical.

If insertion fails:

* Roll back the transaction.
* Do not leave partially inserted generated data.
* Report a clear error.

## Python dependencies

All third-party Python libraries used by:

```text
generate-data.py
```

must be listed in:

```text
requirements.txt
```

Do not include Python standard-library modules.

Dependencies must be installable with:

```bash
pip install -r requirements.txt
```

## Validation

Create `validation.sql` to check applicable problems such as:

* Invalid values or dates
* Orphan foreign keys
* Duplicate keys
* Constraint violations
* Invalid statuses
* Business-rule violations
* Phase 2-specific integrity problems

Expected result:

```text
0 invalid rows
```

Validation rules must come from the actual schema and business requirements.

## Summary

Create `summary.sql` to report useful information such as:

* Record counts
* Important status/category distributions
* Date coverage
* Important Phase 2 data coverage

Use summaries appropriate to the actual project.

## README

Document:

* Required software
* Target DBMS
* Required Python version
* Required previous deliverables
* Dependency installation
* Configuration
* Generation command
* Import command
* Validation command
* Random seed
* Dataset size
* Reset/rerun behavior
* Known limitations

Include:

```bash
pip install -r requirements.txt
```

## Completion condition

Finish only when:

* All required files exist.
* `generate-data.py` runs successfully on both a fresh database and a previously used database according to the documented reset/preserve strategy.
* Primary keys and foreign keys remain consistent.
* The dataset is reproducible.
* Generated data follows the schema and business requirements.
* The dataset is large enough for testing and analytical queries.
* Required Phase 2 cases are represented.
* All validation checks pass.
* All Python dependencies are listed in `requirements.txt`.
