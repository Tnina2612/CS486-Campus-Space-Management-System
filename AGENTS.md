# AGENTS.md — cs486-demo
CS486 database systems teaching demo. Repository is empty; expect code to be added during sessions.

## Recurring context
- Root directory: ./
- This is a demo project, not production.
- Run `ls -la` to detect new files before assuming anything exists.
- Read `req/business-requirement.md` carefully before starting.

# Database Design Agent Rules
This project transforms business requirements into database design artifacts.

---

## MODE 1 — Design Run
**Trigger:** User says "run the pipeline" or "generate outputs" or similar.

### Workflow Order
Always follow this exact order. Do not skip any step. Use the documents from prior steps as context for the later steps:
1. Analyze business requirements.
2. Produce conceptual ERD using Crow's Foot notation.
3. Logical Database Design
4. Database Design Validation
5. Database Implementation (DDL)
6. Sample Data Preparation
7. Query Design

### Execution Rules (STRICT)
- Execute each step ONE AT A TIME, in order (1→2→3→...→7)
- NEVER pre-load all skill files upfront
- NEVER read steps you have not yet reached
- For each step: open the step-specific SKILL file from `.opencode/skills/NN-step-name/SKILL.md`
- Step-specific SKILL files contain exact instructions on which prior outputs to use as context
- Complete and save the output file BEFORE moving to next step
- Do NOT skip or reorder steps
- Do NOT run evaluation in this mode — evaluation is a separate run (MODE 2)

### Required Outputs
All files MUST be saved exactly in the `outputs/` folder with the following names:
- `outputs/01-business-req-analysis-G11.md`
- `outputs/02-erd-design-G11.md`
- `outputs/03-logical-design-G11.md`
- `outputs/04-design-validation-G11.md`
- `outputs/05-db-definition-G11.sql`
- `outputs/06-sample-data-G11.sql`
- `outputs/07-query-design-G11.sql`

---

## MODE 2 — Evaluation Run
**Trigger:** User says "run evaluation" or "evaluate outputs" or similar.
**Prerequisite:** All 7 output files from MODE 1 must already exist in `outputs/`. Run `ls outputs/` to confirm before starting. If any file is missing, stop and notify the user.

### Execution Rules (STRICT)
- This is a fresh run — do NOT rely on any memory or context from the MODE 1 run
- Read each output file from disk as if seeing it for the first time
- Read `req/business-requirement.md` from disk as the source of truth
- Open `EVALUATION.md` from the root directory
- Work through Section 0 first (open-ended gap analysis), then Sections 1–7 (checklists)
- Fill in every table and every criterion — do not leave any row blank
- Save the completed evaluation to `outputs/EVALUATION.md`
- Do NOT edit any output file during evaluation — record findings only

### Required Output
- `outputs/EVALUATION.md`

---

## DBMS
Use Microsoft SQL Server unless the user specifies another DBMS.

## Design Rules
- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement → entity → relationship → table → constraint.
- Use Mermaid `erDiagram` for ERD.
- Enforce strict database constraints (PK, FK, UNIQUE, CHECK).
- Do not silently invent business rules.