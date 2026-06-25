name: db-design-pipeline-step-04
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
* **1:1 Mapping:** Verify entity-to-table mapping. Mark as **FAIL** if any table or entity is missing or mismatched.
* **M:N Relationships:** Verify many-to-many relationships. Ensure a junction table with composite primary keys exists. Mark as **FAIL** if missing.
* **1:N Relationships:** Verify one-to-many relationships. Ensure Foreign Keys are placed correctly on the "Many" side.

### Phase 2: Business Rules Traceability Matrix
* **Action:** Output a Markdown table.
* **Scope:** Analyze EVERY single Business Rule and Assumption extracted from Step 1. Do not skip any.
* **Required Columns:** `[Rule ID / Name]` | `[Business Rule Description]` | `[Mapped DB Element]` | `[Constraint / Technical Logic]` | `[Status]`.

**Status Evaluation Rules:**
* **PASS:** Use this if the DB explicitly handles the rule via simple constraints (PK, FK, UNIQUE, CHECK).
* **DELEGATED_TO_APP:** Use this if the rule requires application-layer logic or complex cross-table triggers. Justify this choice explicitly in the Technical Logic column.
* **FAIL:** Use this if the schema should handle it natively but lacks the necessary table, column, or simple constraint.

### Phase 3: Keys & Constraints Evaluation
* **Primary Keys (PK):** Ensure every table has an explicit PK. Check if the choice (Surrogate vs. Natural keys) is appropriate.
* **Foreign Keys (FK):** Verify referential integrity. Ensure FKs use appropriate deletion behaviors (e.g., `ON DELETE NO ACTION` or `RESTRICT`). 
* **Deletion Vulnerability:** Flag `CASCADE` as a vulnerability unless explicitly justified to preserve historical data.
* **Data Integrity:** Check for correct usage of `UNIQUE` (for naturally unique fields).
* **Mandatory Fields:** Check for `NOT NULL` usage.
* **Default Values:** Check for correct usage of `DEFAULT`.
* **Domain Constraints:** You MUST explicitly check for business-logic safeguards using `CHECK`.
* **Chronological Logic:** Check time validations (e.g., end time > start time).
* **Allowed Value Sets:** Check constraints on `status`, `role`, or `type` fields.
* **Domain Failures:** Mark as **FAIL** if expected domain constraints from Step 1 are missing in Step 3.

## Output Format Requirements
* **Target File:** Save output to exactly `outputs/04-design-validation-G11.md`.
* **Structure:** Use clear headings for the 3 phases.
* **No Hallucination:** Do NOT invent constraints. If a constraint or column is not explicitly written in Step 3, treat it as missing.
* **Remediation:** If any `FAIL` statuses are found in Phase 2 or 3, append a "Recommendations for Remediation" section at the end. Detail exactly how Step 2 or Step 3 should be fixed.