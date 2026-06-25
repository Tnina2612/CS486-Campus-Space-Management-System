---
name: db-design-pipeline-step-03
description: Convert the ERD into a relational schema.
compatibility: opencode
---

# Step 3 - Logical Database Design

## Objective
Transform the conceptual ERD into a relational schema that can be implemented in SQL Server.

## Input Context
- Read `outputs/02-erd-design-G11.md`.
- Use `outputs/01-business-req-analysis-G11.md` when checking that each table still traces back to a business rule.
- Keep the global hybrid-pattern assumptions from `../db-design-pipeline/SKILL.md` active.

## Instructions & Constraints
- Save to: `outputs/03-logical-design-G11.md`
- Instruction: Convert the ERD from Step 2 into a Relational Schema. Clearly list all relations (tables), attributes, primary keys (PK), foreign keys (FK), candidate keys, and key constraints. Use standard notation (e.g., TableName(PK, attr1, attr2, FK)).
