---
name: 04-design-validation
description: Validate the relational schema against the ERD, business rules, and constraints.
compatibility: opencode
---

# Step 4 - Database Design Validation

## Objective
* Critically evaluate `outputs/03-logical-design-G11.md`.
* Ensure it strictly implements the ERD from Step 2.
* Verify it correctly satisfies ALL Business Rules and Assumptions from Step 1.
* Confirm it enforces robust data integrity constraints.

## Input Context
* **Source 1:** Read `outputs/01-business-req-analysis-G11.md`. Extract ALL Business Rules, Assumptions, and Open Questions.
* **Source 2:** Read `outputs/02-erd-design-G11.md`. Analyze the Conceptual ERD.
* **Source 3:** Read `outputs/03-logical-design-G11.md`. Analyze the Logical Relational Schema.

## Execution Phases
* Generate a comprehensive validation report.
* Save the report to `outputs/04-design-validation-G11.md`.
* Divide the report into the following three specific phases:

### Phase 1: ERD vs. Relational Schema Mapping Evaluation

* **Entity-to-Table Mapping:**
  * Verify that every entity in the Conceptual ERD is correctly mapped to a table.
  * Mark as **FAIL** if any expected table is missing or if an unapproved table is invented.

* **Weak Entities :**
  * Verify that any Weak Entity from the ERD is mapped with an identifying relationship.
  * Mark as **FAIL** if the table lacks the parent's Primary Key as a Foreign Key, fails to enforce `NOT NULL` on it, or fails to include it within its own Composite Primary Key (unless a surrogate key + explicit UNIQUE/CASCADE constraints are heavily justified).

* **1:1 Relationships (One-to-One):** Validate all 1:1 implementations. Mark as **FAIL** if:
  * **[UNIQUE Constraint]:** The Foreign Key (FK) lacks a `UNIQUE` constraint.
  * **[NOT NULL / Participation]:** The FK fails to enforce `NOT NULL` for the side with mandatory participation.
  * **[FK Placement]:** The FK is placed on the suboptimal side (ideally, it should be on the mandatory side).
  * **[Split/Merge Logic]:** The decision to split or merge lacks business justification.

* **1:N Relationships (One-to-Many):**
  * **[FK Placement]:** Ensure Foreign Keys are placed correctly on the "Many" side. Mark as **FAIL** if placed on the wrong side or missing.
  * **[Participation Constraint] :** Mark as **FAIL** if the FK lacks a `NOT NULL` constraint when the "Many" side has mandatory participation in the relationship, or incorrectly forces `NOT NULL` when participation is optional.

* **Non-FK Attribute Nullability:**
  * For every non-FK column in every table, determine from Step 1 / the business requirement whether that piece of information is always known at the moment the row is created, or whether it is only filled in later as part of a lifecycle/workflow.
  * Mark as **FAIL** if a column is nullable in Step 3 but the requirement implies it must always have a value at the point the row is created.
  * Mark as **FAIL** if a column is `NOT NULL` in Step 3 but the requirement implies the value is only known or recorded at a later stage of the lifecycle (i.e. the row exists before this value is available).
  * Only report FAIL cases. Do not generate a comprehensive table for all columns.

* **M:N Relationships (Many-to-Many):**
  * Ensure a junction table exists. Must use composite Primary Keys or a Surrogate PK with a `UNIQUE` constraint on the two FKs. Mark as **FAIL** if invalid.

* **ISA / Subtyping Relationships:** Mark as **FAIL** if:
  * **[Disjoint / Overlapping]:** Fails to enforce exclusivity or overlap logic.
  * **[Completeness]:** Fails to enforce mandatory participation (missing `NOT NULL`).

### Phase 2: Business Rules Traceability Matrix

* **Action:** Output a Markdown table analyzing ONLY the Business Rules that FAIL or are DELEGATED_TO_APP. If all PASS, simply state "All business rules are successfully mapped".
* **Columns:** `[Rule ID / Name]` | `[Business Rule Description]` | `[Mapped DB Element]` | `[Constraint / Technical Logic]` | `[Status]`.
* **Status Evaluation Rules:**
  * **PASS:** The DB explicitly handles the rule via structural constraints (PK, FK, UNIQUE, CHECK).
  * **DELEGATED_TO_APP:** The rule requires complex cross-table triggers or App-layer logic. Explicitly justify this.
  * **FAIL:** The schema lacks the necessary table, column, or simple declarative constraint.

### Phase 3: Keys & Constraints Evaluation

* **Primary Keys (PK):** Ensure every table has an explicit PK. Evaluate Surrogate vs. Natural key usage.
* **Foreign Keys (FK) & Deletion/Update Strategy:**
  * **[CASCADE Violation Check (DELETE)]:** Explicitly cross-reference every `ON DELETE CASCADE` constraint in Step 3 against the historical preservation rules in Step 1. 
  * Mark as **FAIL (VULNERABILITY)** if `ON DELETE CASCADE` is applied to ANY transactional, lifecycle, or audit table (e.g., approvals, sessions, maintenance records). Do not accept "Parent-Child dependency" as an excuse for these tables; they must use `NO ACTION` or `RESTRICT`.
  * **[Natural Key Update Policy]:** Evaluate the `ON UPDATE` strategy for all Foreign Keys. Foreign Keys referencing a Natural Key (e.g., `space_code`, string-based identifiers) MUST use `ON UPDATE CASCADE` to prevent broken references if the real-world identifier is modified. Mark as **FAIL** if a Natural Key FK uses `NO ACTION`.
  * **[RESTRICT / NO ACTION]:** Verify usage to protect critical records upon deletion, and for updates involving immutable Surrogate Keys (e.g., `INT IDENTITY`).
  * **[Soft Deletion]:** Note if logical deletion (e.g., `is_deleted` flags) is used instead of physical deletion.
* **Data Integrity Constraints:**
  * **[UNIQUE]:** Scan for logically unique identifiers (e.g., `email`, `phone`, `asset_tag`). Mark as **FAIL** if missing.
  * **[NOT NULL]:** Applied to all mandatory fields.
  * **[DEFAULT]:** Applied correctly.
* **Business Logic Constraints:**
  * **[CHECK - Domain]:** Explicit safeguards for valid data ranges (e.g., `capacity > 0`).
  * **[CHECK - Format/Logic]:** Flag as **WARNING/FAIL** if text/numeric columns lack basic format or boundary validation (e.g., emails must contain `@`).
  * **[CHECK - Chronological]:** Actively scan EVERY table for ALL pairs of date/time columns. **WARNING: A single table may contain MULTIPLE chronological pairs** (e.g., a Booking table might have `requested_start`/`end` AND `check_in`/`check_out`). You MUST evaluate every single pair independently. Mark as **FAIL** if ANY pair lacks an explicit `CHECK` constraint ensuring the end time is >= the start time. Do not skip any tables.
  * **[Allowed Value Sets]:** Constrained correctly using `ENUM` or `CHECK IN (...)`.
  * **[Enum Value Fidelity]:** For every `CHECK IN (...)` or `ENUM` constraint, compare each literal value character-by-character against the exact wording used in Step 1. Mark as **FAIL** if:
    - A value is abbreviated, truncated, or reformatted compared to how Step 1 wrote it (e.g. a shortened form, an acronym, or a different word choice for the same concept).
    - A value uses a different casing or naming convention than Step 1 without that convention being explicitly stated as a project-wide rule in Step 1 or Step 3.
    - A value exists in the schema but does NOT appear anywhere in Step 1 (i.e. it was invented). This applies in particular to any status/lifecycle column whose values were not explicitly enumerated in Step 1 — flag it as **FAIL** with the note "values not traceable to Step 1; must be confirmed as an explicit assumption."
    - A value from Step 1 is missing from the schema's CHECK/ENUM list.
  * Only report FAIL cases. Do not generate a side-by-side comparison table if the values match.

## Output Format Requirements
* **Target File:** Save output to exactly `outputs/04-design-validation-G11.md`.
* **Structure:** Use clear headings for the 3 phases.
* **No Hallucination:** Do NOT invent constraints. If a constraint or column is not explicitly written in Step 3, treat it as missing.
* **Executive Summary:** Immediately after Phase 3, generate a consolidated table titled **"Executive Validation Summary"**. Columns: `[Category] | [PASS] | [DELEGATED_TO_APP] | [FAIL/GAP]`. Categories: Entity Mapping, Weak Entities, Relationships (1:1, 1:N, M:N, ISA), Business Rules, Primary Keys, Foreign Keys, Unique Constraints, CHECK Constraints, Chronological Logic.
* **Structured Remediation (UPDATED):** If any `FAIL` or `WARNING` statuses exist, you MUST append a "Recommendations for Remediation" section at the end. Use a strict Markdown table format with columns: `[Failed Phase] | [Entity/Table/Element] | [Detected Issue] | [Exact SQL / Markdown Fix Needed]`.