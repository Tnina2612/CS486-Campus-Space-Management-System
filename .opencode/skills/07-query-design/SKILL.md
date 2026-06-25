---
name: db-design-pipeline-step-07
description: Write meaningful SQL Server queries for the completed design.
compatibility: opencode
---

# Step 7 - Query Design

## Objective
Create useful SQL queries that answer business questions from the completed database design.

## Input Context
- Read `outputs/06-sample-data-G11.sql`.
- Use the final schema from `outputs/05-db-definition-G11.sql`.
- Preserve the business scope and hybrid-pattern assumptions from `../db-design-pipeline/SKILL.md`.

## Instructions & Constraints
- Save to: `outputs/07-query-design-G11.sql`
- Instruction: Design and write 5 meaningful Microsoft SQL Server queries to answer business questions based on the scenario. For each of the 5 queries, use SQL comments (`--`) to document:
1. The business question being answered.
2. The target user(s) who would use the query.
3. A short explanation of why the query is useful.
4. The executable `SELECT` statement.
