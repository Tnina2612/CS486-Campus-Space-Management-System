# Skill 14 — Generate Phase 2 Data

## Goal

Create:

```text
14-data-generator-G11/
```

Generate realistic Phase 2 data for functional testing, analytical queries, and index tuning.

## Read before starting

The agent must read and reuse the results of the previous steps:

```text
08-requirement-change-analysis-G11.md
09-updated-erd-and-logical-design-G11.md
10-schema-migration-G11.sql
11-concurrency-design-G11.md
12-concurrency-implementation-G11.sql
13-concurrency-tests-G11/
```

Also read:

```text
AGENT.md
SKILL.md
```

Use the exact DBMS, table names, columns, keys, statuses, constraints, and overlap rules defined in those files.

Do not redesign the schema or invent new columns.

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

A generated SQL file may also be included when practical.

## Python dependencies

All external Python libraries used by:

```text
generate-data.py
```

must be declared in:

```text
14-data-generator-G11/requirements.txt
```

Requirements:

* Include every third-party Python package required by the generator.
* Do not include Python standard-library modules.
* Use package versions when practical to improve reproducibility.
* Keep `requirements.txt` consistent with the imports used by `generate-data.py`.
* The generator must be installable with:

```bash
pip install -r requirements.txt
```

* Avoid unnecessary dependencies when the Python standard library can reasonably perform the task.
* If the generator connects directly to the target DBMS, include the appropriate Python database driver in `requirements.txt`.
* Document installation of these dependencies in `README.md`.

## Requirements

Generate:

* At least 3 academic years
* At least 100,000 bookings
* Optional scale up to 500,000 bookings
* Users and roles
* Spaces and space types
* Facilities and space-facility links
* All required booking statuses
* Automatic and staff approvals where supported
* Advisory and out-of-service maintenance
* Cancellations
* No-shows
* Usage sessions
* Advisory acknowledgements

## Data rules

The generator must follow all rules defined in the earlier deliverables.

At minimum:

* Use a fixed random seed
* Use realistic distributions
* Generate valid foreign-key references
* Keep start time earlier than end time
* Prevent overlapping approved bookings for the same space
* Prevent approved bookings during out-of-service maintenance
* Allow bookings during advisory maintenance
* Create acknowledgement rows for active advisories
* Preserve existing Phase 1 data unless instructed otherwise

Use this overlap condition:

```text
existing_start < candidate_end
AND existing_end > candidate_start
```

## Validation

Create `validation.sql` to check:

* Record counts
* Invalid dates
* Orphan foreign keys
* Duplicate keys
* Approved booking conflicts
* Approved bookings overlapping out-of-service maintenance
* Missing advisory acknowledgements
* Invalid acknowledgement links
* Booking-status inconsistencies

Expected result for all integrity checks:

```text
0 invalid rows
```

The validation must use the actual schema, status values, constraints, and relationships obtained from the previous deliverables.

## Summary

Create `summary.sql` to report:

* Counts by table
* Bookings by academic year
* Bookings by status
* Maintenance by impact level
* Acknowledgement count
* Earliest and latest booking dates

## README

Document:

* Required software
* Target DBMS
* Required previous deliverables
* Required Python version
* Python dependencies
* Dependency installation command
* Configuration
* Generation command
* Import command
* Validation command
* Random seed
* Dataset size
* Known limitations

The README must include the dependency setup command:

```bash
pip install -r requirements.txt
```

and explain any DBMS-specific Python driver or configuration required by `generate-data.py`.

## Reproducibility

The generator must be reproducible.

At minimum:

1. Use a fixed and documented random seed.
2. Store configurable generation parameters in `config.json`.
3. Declare all third-party Python dependencies in `requirements.txt`.
4. Ensure the same configuration and random seed produce equivalent deterministic data wherever practical.
5. Do not rely on temporary manually created data.
6. Do not require undocumented Python packages or environment configuration.

## Completion condition

Finish only when:

* `14-data-generator-G11/` contains all required files.
* `generate-data.py` runs successfully using the documented configuration.
* All required third-party Python libraries are listed in `requirements.txt`.
* Dependencies can be installed using:

```bash
pip install -r requirements.txt
```

* The generator is reproducible.
* The generated dataset contains at least 100,000 valid bookings.
* The bookings cover at least 3 academic years.
* The generated data follows all Phase 1 and Phase 2 schema and business rules.
* All validation integrity checks return zero invalid rows.
