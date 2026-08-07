# Skill 16 — Generate Phase 2 Analytical Queries

## Goal

Create:

```text
16-analytical-queries-G11.sql
```

Implement all mandatory Phase 2 analytical queries.

## Read before starting

The agent must read and reuse:

```text
08-requirement-change-analysis-G11.md
09-updated-erd-and-logical-design-G11.md
10-schema-migration-G11.sql
11-concurrency-design-G11.md
12-concurrency-implementation-G11.sql
14-data-generator-G11/
15-index-tuning-report-G11.md
```

Also read:

```text
AGENT.md
SKILL.md
```

Use the exact DBMS, schema, statuses, relationships, semester rules, and overlap logic defined in those files.

Do not invent table or column names.

## Required queries

### Query 1 — Approved booking hours by space

For a given semester, return:

- Space ID
- Space code
- Space name
- Approved booking count
- Total approved booking hours

Include only statuses that represent approved occupancy according to the existing design.

Prefer including spaces with zero hours.

---

### Query 2 — Approved bookings by weekday and hour

For a given semester, return:

- Weekday number
- Weekday name
- Hour
- Approved booking count

Use a stable Monday-to-Sunday order.

Document whether grouping is based on booking start time.

---

### Query 3 — Room finder

Given:

- Requested start time
- Requested end time
- Minimum capacity
- Required facility list

Return spaces that:

- Are bookable
- Have sufficient capacity
- Have every requested facility
- Have no overlapping approved booking
- Have no overlapping out-of-service maintenance

Advisory maintenance must not block the space.

When the required facility list is empty, all otherwise valid spaces should pass.

Return each space once.

---

### Query 4 — Bookings affected by maintenance escalation

Given a maintenance record ID, return approved bookings that:

- Use the same space
- Overlap the maintenance period
- Are affected after escalation to out-of-service

Include requester contact information needed by staff.

## Shared rules

Use this overlap condition:

```text
existing_start < requested_end
AND existing_end > requested_start
```

Use parameterized semester boundaries:

```text
value >= semester_start
AND value < semester_end
```

Do not use `BETWEEN` as the general overlap test.

Do not assume that only the literal status `approved` counts. Reuse the approved-status definition from the previous design.

## File requirements

For each query include:

- Business-question comment
- Target-user comment
- Input parameters
- SQL statement
- Assumptions
- Test execution example
- Expected-result explanation

Use DBMS-specific syntax and keep predicates suitable for the indexes defined in deliverable 15.

## Validation cases

At minimum, test:

- Semester boundaries
- Cancelled and rejected bookings
- Adjacent non-overlapping periods
- Empty facility list
- Room missing one required facility
- Advisory maintenance
- Out-of-service maintenance
- Open maintenance period
- Booking in another space

## Completion condition

Finish only when all four queries execute on the generated dataset, return correct boundary-case results, and are compatible with the planned index analysis.
