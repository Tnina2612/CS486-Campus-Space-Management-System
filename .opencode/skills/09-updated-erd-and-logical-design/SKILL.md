---
name: 09-updated-erd-and-logical-design
description: Evolves the Phase 1 conceptual ERD and relational schema to support the Phase 2 requirement changes, additively.
compatibility: opencode
---

# 09-updated-erd-and-logical-design Skill

**Objective:**
Produce the Phase 2 versions of the conceptual ERD and the logical relational schema by applying only additive changes on top of the Phase 1 design, so the final result is traceable to both the original and the updated requirements.

**Instructions for the Agent:**
1. **Input Context**: Read `outputs/02-erd-design-G11.md` and `outputs/03-logical-design-G11.md` as the Phase 1 baseline. Read `outputs/08-requirement-change-analysis-G11.md` to know exactly which changes to incorporate. Do not read or reuse unrelated exercises.
2. **ERD Update (Conceptual)**:
   - Modify the ERD to reflect every change identified in step 8.
   - Add any new entities and clearly label which are new vs. pre-existing.
   - Add any new relationships and state their cardinality and optional/mandatory participation on each side.
   - Add any new attributes to existing entities. Distinctly mark added vs. retained attributes.
   - Explicitly include the `INCIDENT_REPORT` lifecycle (user report intake, triage linkage to `MAINTENANCE_RECORD`, and duplicate-report consolidation path).
   - Keep all Phase 1 relationships/entities that remain valid. Do not delete real ones; only preserve and extend.
   - Include an updated Mermaid `erDiagram` block showing the full updated model.
3. **Relational Schema Update (Logical)**:
   - Update every affected table schema. For each table, include the columns for `Column Name` (use strictly `snake_case`), `Data Type`, and `Constraints & Keys` (PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT, surrogate keys with `IDENTITY(1,1)` where used).
   - For any new `CHECK` constraint, explicitly define the exact logical expression or the exact enumeration values — do not just write the word "CHECK".
   - Do not invent enumeration values; reuse the exact wording from the requirements and record any inferred values as assumptions.
   - Refine the value domain/check for `SPACE.current_status` so it excludes `Under Maintenance` and document that booking eligibility is evaluated via `MAINTENANCE_RECORD impact_level = 'out-of-service'`.
   - Define how many `INCIDENT_REPORT` rows can map to one `MAINTENANCE_RECORD` and whether this linkage is nullable during triage.
   - Add a dedicated summary of referential integrity for every new or changed Foreign Key, explicitly stating the `UPDATE` and `DELETE` referential actions with their business justification.
4. **Consistency & Traceability**:
   - Provide a change-diff section listing what was **added**, **changed**, and **retained** relative to the Phase 1 design, so reviewers can see the evolution at a glance.
   - Provide an entity-to-table traceability for the updated model.
   - Cross-check that every design change requested in step 8 is present; none may be left out.
5. **Formatting Structure**: Use clear, sectioned Markdown with tables for the updated ERD entities/relationships/attributes, the updated relational schema, and the change-diff tracing every modification back to step 8.

**Output:**
Generate the updated design and write it to `outputs/09-updated-erd-and-logical-design-G11.md`.

Do NOT modify or regenerate any Phase 1 output file — this file only documents the additive Phase 2 changes on top of them.