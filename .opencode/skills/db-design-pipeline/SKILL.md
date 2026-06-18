---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, and DDL documents step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Important behavior

Before assuming anything, inspect the project:

1. Run `ls -la`.
2. Locate requirement files under `req/`, `outputs/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.

## Required output files

Create or update the following files:

- `outputs/01-business-req-analysis-G11.md`
- `outputs/02-erd-design-G11.md`
- `outputs/03-logical-design-G11.md`
- `outputs/04-design-validation-G11.md`
- `outputs/05-db-definition-G11.sql`
- `outputs/06-sample-data-G11.sql`
- `outputs/07-query-design-G11.sql`

Do not skip any Markdown file.

---

# Step 1: Business Requirement Analysis
* Save to: `outputs/01-business-req-analysis-G11.md`
* Instruction: Analyze the provided business requirement document. Identify and list the following clearly: business purpose, actors, entities, attributes, relationships, cardinalities, and all business rules.

# Step 2: Conceptual Design / ERD
* Save to: `outputs/02-erd-design-G11.md`
* Instruction: Based on the output of Step 1, design a Conceptual Entity-Relationship Diagram (ERD). Describe the main entities, attributes, relationships, cardinalities, and participation constraints. Provide the visual representation using Mermaid `erDiagram` syntax.

# Step 3: Logical Database Design
* Save to: `outputs/03-logical-design-G11.md`
* Instruction: Convert the ERD from Step 2 into a Relational Schema. Clearly list all relations (tables), attributes, primary keys (PK), foreign keys (FK), candidate keys, and key constraints. Use standard notation (e.g., TableName(PK, attr1, attr2, FK)).

# Step 4: Database Design Validation
* Save to: `outputs/04-design-validation-G11.md`
* Instruction: Evaluate the relational schema from Step 3 against the business rules from Step 1. Write a validation report explaining whether the schema correctly represents the ERD, satisfies all business rules (e.g., preventing overlapping bookings, maintenance checks), and uses appropriate keys and constraints.

# Step 5: Database Implementation
* Save to: `outputs/05-db-definition-G11.sql`
* Instruction: Write Microsoft SQL Server DDL statements to implement the design from Step 3. Include `DROP TABLE IF EXISTS` (with CASCADE). Define tables, primary keys, foreign keys, constraints (CHECK, UNIQUE, NOT NULL), and default values where appropriate.

# Step 6: Sample Data Preparation
* Save to: `outputs/06-sample-data-G11.sql`
* Instruction: Write Microsoft SQL Server `INSERT` statements to populate the tables from Step 5 with realistic sample data. Ensure correct insertion order to avoid foreign key constraint violations. Include data to test normal operations (successful bookings) and exceptional cases (maintenance, rejected bookings, no-shows).

# Step 7: Query Design
* Save to: `outputs/07-query-design-G11.sql`
* Instruction: Design and write 5 meaningful Microsoft SQL Server queries to answer business questions based on the scenario. For each of the 5 queries, use SQL comments (`--`) to document:
    1. The business question being answered.
    2. The target user(s) who would use the query.
    3. A short explanation of why the query is useful.
    4. The executable `SELECT` statement.