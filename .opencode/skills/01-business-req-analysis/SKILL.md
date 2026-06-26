---
name: 01-business-req-analysis
description: Analyze the business requirements and produce the business requirement analysis output.
compatibility: opencode
---

# Step 1 - Business Requirement Analysis

## Objective
Analyze the provided business requirement document and extract the business purpose, actors, entities, attributes, relationships, cardinalities, and business rules.

## Input Context
- Read `req/business-requirement.md` first.
- Use `../db-design-pipeline/SKILL.md` for the global assumptions and pipeline rules.
- If a newer requirement file is provided by the user, use that as the primary source and note the substitution.

## Instructions & Constraints
- Save to: `outputs/01-business-req-analysis-G11.md`
- Instruction: Analyze the provided business requirement document. Identify and list the following clearly: business purpose, actors, entities, attributes, relationships, cardinalities, and all business rules. You MUST include the explicitly defined "Catalog vs. Asset Hybrid Pattern" (FACILITY_CATALOG, SPACE_FACILITY, FACILITY_ASSET) in your entities and relationships list.
