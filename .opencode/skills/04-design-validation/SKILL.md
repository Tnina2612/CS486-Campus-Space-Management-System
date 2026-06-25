---
name: db-design-pipeline-step-04
description: Validate the relational schema against the business rules.
compatibility: opencode
---

# Step 4 - Database Design Validation

## Objective
Validate that the relational schema correctly implements the ERD and satisfies the business rules.

## Input Context
- Read `outputs/03-logical-design-G11.md`.
- Compare it against `outputs/01-business-req-analysis-G11.md` and `outputs/02-erd-design-G11.md`.
- Keep the hybrid-pattern rules from `../db-design-pipeline/SKILL.md` visible while validating.

## Instructions & Constraints
- Save to: `outputs/04-design-validation-G11.md`
- Instruction: Evaluate the relational schema from Step 3 against the business rules from Step 1. Write a validation report explaining whether the schema correctly represents the ERD, satisfies all business rules (e.g., preventing overlapping bookings, maintenance checks), and uses appropriate keys and constraints.
