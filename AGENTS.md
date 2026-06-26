# AGENTS.md — cs486-demo
CS486 database systems teaching demo. Repository is empty; expect code to be added during sessions.

## Recurring context
- Root directory: ./
- This is a demo project, not production.
- Run `ls -la` to detect new files before assuming anything exists.
- Read `req/business-requirement.md` carefully before starting.

# Database Design Agent Rules
This project transforms business requirements into database design artifacts.


## Workflow Order
Always follow this exact order. Do not skip any step. Use the documents from prior steps as context for the later steps:
1. Analyze business requirements.
2. Produce conceptual ERD using Crow's Foot notation.
3. Logical Database Design
4. Database Design Validation
5. Database Implementation (DDL)
6. Sample Data Preparation
7. Query Design

## Required Outputs
All files MUST be saved exactly in the `outputs/` folder with the following names:
- `outputs/01-business-req-analysis-G11.md`
- `outputs/02-erd-design-G11.md`
- `outputs/03-logical-design-G11.md`
- `outputs/04-design-validation-G11.md`
- `outputs/05-db-definition-G11.sql`
- `outputs/06-sample-data-G11.sql`
- `outputs/07-query-design-G11.sql`

## DBMS
Use Microsoft SQL Server unless the user specifies another DBMS.

## Design Rules
- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement → entity → relationship → table → constraint.
- Use Mermaid `erDiagram` for ERD.
- Enforce strict database constraints (PK, FK, UNIQUE, CHECK).
- Do not silently invent business rules.