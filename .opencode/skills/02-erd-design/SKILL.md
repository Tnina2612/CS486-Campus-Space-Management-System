---
name: db-design-pipeline-step-02
description: Convert the requirement analysis into a conceptual ERD.
compatibility: opencode
---

# Step 2 - Conceptual Design / ERD

## Objective
Convert the requirement analysis into a conceptual ERD with clear entities, relationships, and participation constraints.

## Input Context
- Read `outputs/01-business-req-analysis-G11.md`.
- Keep `../db-design-pipeline/SKILL.md` open for the global hybrid-pattern assumptions.
- Reuse the business rules and entity list from Step 1 instead of reinterpreting the requirement from scratch.

## Instructions & Constraints
- Save to: `outputs/02-erd-design-G11.md`
- Instruction: Based on the output of Step 1, design a Conceptual Entity-Relationship Diagram (ERD). Describe the main entities, attributes, relationships, cardinalities, and participation constraints. Provide the visual representation using Mermaid `erDiagram` syntax. Ensure the diagram visually represents the hybrid pattern: `space` has a many-to-many relationship with `facility_catalog` (resolved via `space_facility` with a quantity attribute) and a one-to-many relationship with `facility_asset` (for trackable items).
