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
- **Save to:** `outputs/07-query-design-G11.sql`
- **Database Context (CRITICAL):** The file MUST start with the following lines to ensure the queries execute against the correct database:
  ```sql
  USE [CampusSpaceManagement];
  GO
  ```
- **Task:** Design and write exactly 5 meaningful Microsoft SQL Server queries.

- **Metadata Requirement:** For each of the 5 queries, you MUST use SQL comments (`--`) above the query to document:
  1. The business question being answered.
  2. The target user(s) who would use the query.
  3. A short explanation of why the query is useful.
  4. The executable `SELECT` statement.

- **Query Complexity & Quality:**
  - Ensure the queries demonstrate a solid understanding of relational databases. Do NOT write basic `SELECT *` queries.
  - Across the 5 queries, incorporate a variety of intermediate/advanced SQL features. Examples include: multi-table `JOIN`s, Aggregations (`COUNT`, `SUM` with `GROUP BY`), `HAVING` clauses, Subqueries, or CTEs (Common Table Expressions).

- **STRICT CONSISTENCY RULE:** - You MUST ONLY use table names, column names, and data types exactly as they are defined in `outputs/05-db-definition-G11.sql`. Do not hallucinate columns or relationships that do not exist in the DDL.

- **SELF-REVIEW:**
  1. Are there exactly 5 distinct queries?
  2. Does every query include the requested metadata as SQL comments?
  3. Do all referenced tables and columns perfectly match the Step 5 DDL?

- **CRITICAL FORMATTING CONSTRAINTS:**
  1. Do NOT wrap the SQL code in markdown fences (e.g., do NOT write ````sql` at the top and ````` at the bottom). Output the raw SQL text directly.
  2. Do NOT output any conversational text, pleasantries, or explanations outside of the SQL comments. The entire output file must be a valid, executable `.sql` script.