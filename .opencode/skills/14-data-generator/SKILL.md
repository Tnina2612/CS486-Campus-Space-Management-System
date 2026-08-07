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
├── validation.sql
└── summary.sql
```

A generated SQL file may also be included when practical.

## Requirements

Generate:

- At least 3 academic years
- At least 100,000 bookings
- Optional scale up to 500,000 bookings
- Users and roles
- Spaces and space types
- Facilities and space-facility links
- All required booking statuses
- Automatic and staff approvals where supported
- Advisory and out-of-service maintenance
- Cancellations
- No-shows
- Usage sessions
- Advisory acknowledgements

## Data rules

The generator must follow all rules defined in the earlier deliverables.

At minimum:

- Use a fixed random seed
- Use realistic distributions
- Generate valid foreign-key references
- Keep start time earlier than end time
- Prevent overlapping approved bookings for the same space
- Prevent approved bookings during out-of-service maintenance
- Allow bookings during advisory maintenance
- Create acknowledgement rows for active advisories
- Preserve existing Phase 1 data unless instructed otherwise

Use this overlap condition:

```text
existing_start < candidate_end
AND existing_end > candidate_start
```

## Validation

Create `validation.sql` to check:

- Record counts
- Invalid dates
- Orphan foreign keys
- Duplicate keys
- Approved booking conflicts
- Approved bookings overlapping out-of-service maintenance
- Missing advisory acknowledgements
- Invalid acknowledgement links
- Booking-status inconsistencies

Expected result for all integrity checks: zero invalid rows.

Create `summary.sql` to report:

- Counts by table
- Bookings by academic year
- Bookings by status
- Maintenance by impact level
- Acknowledgement count
- Earliest and latest booking dates

## README

Document:

- Required software
- Target DBMS
- Required previous deliverables
- Configuration
- Generation command
- Import command
- Validation command
- Random seed
- Dataset size
- Known limitations

## Completion condition

Finish only when the generator is reproducible, generates at least 100,000 valid bookings across 3 academic years, and all validation checks pass.
