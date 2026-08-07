---
name: 10-schema-migration
description: Phase 2 Task 10: Schema Migration. Implements the updated logical design on top of the existing Phase 1 database using additive SQL, preserving existing data.
compatibility: opencode
---

# 10-schema-migration Skill

**Objective:**
Translate the Phase 2 logical design into an executable, additive SQL Server migration script that applies all schema changes onto the existing Phase 1 database without breaking or discarding existing data.

**Instructions for the Agent:**
1. **Input Context**: Read `outputs/05-db-definition-G11.sql` to know the exact existing schema (tables, columns, constraints, keys). Read `outputs/09-updated-erd-and-logical-design-G11.md` to know exactly what must be added. Read `outputs/08-requirement-change-analysis-G11.md` for the rationale behind each change.
2. **Additive-Only Rule (STRICT)**:
   - Do NOT rewrite, drop, or recreate any existing table from Phase 1.
   - All existing tables, columns, and data must remain untouched.
   - Implement every change with `ALTER TABLE`, `ADD`, or `CREATE` statements only.
   - If a Phase 1 table needs a new column or constraint, add it; never drop the table.
3. **Migration Content**: Produce SQL for each of the following categories as applicable:
   - New tables introduced in step 9 (with full column definitions, data types, PK/FK/UNIQUE/CHECK/DEFAULT constraints, and surrogate keys where used).
   - New columns added to existing tables (with correct data types, nullability, defaults, and constraints). Choose nullability so that existing rows remain valid (e.g., allow NULL or provide a DEFAULT) unless the change genuinely requires otherwise.
   - New Foreign Keys (with explicit `UPDATE`/`DELETE` referential actions justified by the business rules).
   - New `CHECK` constraints with exact logical expressions or enumeration values matching step 9.
   - New indexes required to support the new functionality and expected query patterns.
   - Any triggers or stored procedures needed to enforce rules that cannot be expressed declaratively.
4. **Idempotency & Ordering**:
   - Order statements so that referenced objects exist before they are referenced (e.g., create referenced tables before tables with foreign keys to them).
   - Use `IF NOT EXISTS` / object-existence guards where practical so the script is safe to re-run.
   - Wrap the migration in transactions where a failure should roll back cleanly.
5. **Data Preservation**:
   - Explicitly confirm no existing data is deleted or altered.
   - If any data backfill is required for the new columns (e.g., populating a new status/level column for existing rows), include the backfill `UPDATE` and explain its default/derivation logic.
6. **Commenting**: For each statement group, add a brief comment referencing the step 9 design element it implements, so the migration is traceable.
7. **Formatting Structure**: Use clear, sectioned T-SQL with comments: (1) header stating target database and additive-only policy, (2) new tables, (3) altered tables / new columns, (4) new constraints & foreign keys, (5) indexes, (6) triggers / procedures, (7) data backfill (if any).

**Output:**
Generate the migration script and write it to `outputs/10-schema-migration-G11.sql`.

Do NOT modify or regenerate any Phase 1 output file.