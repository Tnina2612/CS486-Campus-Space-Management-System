# CS486 - Campus Space Management System

This project requires each group to build and improve an AI agent that reads a business requirement and generates database design artifacts - from requirement analysis to SQL query design - and then extends the database with maintenance, concurrency control, performance tuning, and analytical queries.

## 1. Install OpenCode

OpenCode installation guide: [https://opencode.ai/docs/](https://opencode.ai/docs/)

After installation, open the project folder and start OpenCode:

```bash
cd path/to/your/project
opencode
```

During setup, choose the LLM provider and model that your group will use.

> Do not commit API keys, access tokens, or private credentials to Git.

---

### Connect OpenCode to an LLM Model

After installing OpenCode, each group must connect OpenCode to at least one LLM provider before running the database design agent.

OpenCode provider guide: [https://opencode.ai/docs/providers/](https://opencode.ai/docs/providers/)  
OpenCode model guide: [https://opencode.ai/docs/models/](https://opencode.ai/docs/models/)

#### Step 1: Start OpenCode

Open the project folder in the terminal:

```bash
cd path/to/your/project
opencode
```

#### Step 2: Connect an LLM Provider

Inside OpenCode, run:

```text
/connect
```

Then select the LLM provider that your group wants to use, such as OpenAI, Anthropic, Gemini, OpenRouter, OpenCode Zen, or another supported provider.

When requested, enter the API key or login information for the selected provider.

> Do not commit API keys, access tokens, or private credentials to Git.

#### Step 3: Select an LLM Model

After connecting the provider, run:

```text
/models
```

Choose the model that your group wants to use for the project.

## 2. Project Goal

### Phase 1 - Database Design (Steps 01–07)

The agent must read the business requirement and generate the following database design artifacts:

1. Business Requirement Analysis
2. Conceptual Database Design (ERD)
3. Logical Database Design
4. Database Design Validation
5. Database Implementation (DDL)
6. Sample Data Preparation
7. Query Design

### Phase 2 - Database Extension & Tuning (Steps 08–16)

Building on the Phase 1 baseline, the agent must extend the database with:

8. Requirement Change Analysis - Analyze new maintenance and concurrency requirements.
9. Updated ERD and Logical Design - Revise the conceptual and logical models.
10. Schema Migration - Generate `ALTER`/`ADD`/`UPDATE` migration scripts (Phase 1 schemas are read-only).
11. Concurrency Design - Define locking and isolation strategies.
12. Concurrency Implementation - Implement concurrency-safe stored procedures.
13. Concurrency Tests - Python/SQL collision simulation scripts.
14. Data Generator - Large-scale mock data seeder (Python).
15. Index Tuning Report - `EXPLAIN` plans with before/after analysis.
16. Analytical Queries - Reporting SQL for business intelligence.

The group must also evaluate and improve the agent during the development process.

---

## 3. Project Structure

```text
.
├── .opencode/
│   ├── commands/
│   └── skills/
│       ├── 01-business-req-analysis/
│       ├── 02-erd-design/
│       ├── 03-logical-design/
│       ├── 04-design-validation/
│       ├── 05-db-definition/
│       ├── 06-sample-data/
│       ├── 07-query-design/
│       ├── 08-requirement-change-analysis/
│       ├── 09-updated-erd-and-logical-design/
│       ├── 10-schema-migration/
│       ├── 11-concurrency-design/
│       ├── 12-concurrency-implementation/
│       ├── 13-concurrency-tests/
│       ├── 14-data-generator/
│       ├── 15-index-tuning-report/
│       ├── 16-analytical-queries/
│       ├── db-design-pipeline/
│       └── phase2-pipeline/
├── req/
│   └── business-requirement.md
├── outputs/                              ← All generated artifacts
│   ├── 01-business-req-analysis-G11.md
│   ├── ...
│   ├── 07-query-design-G11.sql
│   ├── 08-requirement-change-analysis-G11.md
│   ├── ...
│   ├── 12-concurrency-implementation-G11.sql
│   ├── 13-concurrency-tests-G11/         ← Python test scripts + SQL transactions
│   ├── 14-data-generator-G11/            ← Python seeder + config + validation SQL
│   ├── 15-index-tuning-report-G11.md
│   └── 16-analytical-queries-G11.sql
├── AGENTS.md
├── EVALUATION.md
├── README.md
└── .gitignore
```

---

## 4. Main Files and Folders

| File / Folder | Purpose |
|---|---|
| `.opencode/` | Stores OpenCode commands, skills, and related configuration. |
| `.opencode/skills/01-*` through `07-*` | Phase 1 skill definitions - one SKILL.md per design step. |
| `.opencode/skills/08-*` through `16-*` | Phase 2 skill definitions - migration, concurrency, tuning, analytics. |
| `.opencode/skills/db-design-pipeline/` | Orchestrates the Phase 1 pipeline. |
| `.opencode/skills/phase2-pipeline/` | Orchestrates the Phase 2 pipeline. |
| `req/business-requirement.md` | Contains the input business requirement. |
| `outputs/` | Stores all generated project artifacts (Phase 1 + Phase 2). |
| `AGENTS.md` | Contains project-level instructions and mode definitions for the agent. |
| `EVALUATION.md` | Evaluation rubric and checklist for Phase 1 outputs. |
| `README.md` | Explains how to install, run, and evaluate the project. |
| `.gitignore` | Excludes private or unnecessary files from Git. |

---

## 5. How to Run the Agent

Open the project folder:

```bash
cd path/to/your/project
opencode
```

### Phase 1 - Generate database design artifacts (Steps 01–07)

```text
run phase 1 pipeline
```

### Phase 2 - Extend with migration, concurrency, tuning, and analytics (Steps 08–16)

> **Prerequisite:** All 7 Phase 1 output files must already exist in `outputs/`.

```text
run phase 2 pipeline
```

### Evaluation - Evaluate Phase 1 outputs against the rubric

```text
run evaluation
```

---

## 6. Required Output Artifacts

### Phase 1 Outputs

| # | File | Format |
|---|---|---|
| 01 | `01-business-req-analysis-G<N>.md` | Markdown |
| 02 | `02-erd-design-G<N>.md` | Markdown (Mermaid ERD) |
| 03 | `03-logical-design-G<N>.md` | Markdown |
| 04 | `04-design-validation-G<N>.md` | Markdown |
| 05 | `05-db-definition-G<N>.sql` | SQL (DDL) |
| 06 | `06-sample-data-G<N>.sql` | SQL (DML) |
| 07 | `07-query-design-G<N>.sql` | SQL |

### Phase 2 Outputs

| # | File | Format |
|---|---|---|
| 08 | `08-requirement-change-analysis-G<N>.md` | Markdown |
| 09 | `09-updated-erd-and-logical-design-G<N>.md` | Markdown (Mermaid ERD) |
| 10 | `10-schema-migration-G<N>.sql` | SQL (ALTER/ADD/UPDATE) |
| 11 | `11-concurrency-design-G<N>.md` | Markdown |
| 12 | `12-concurrency-implementation-G<N>.sql` | SQL (Stored Procedures) |
| 13 | `13-concurrency-tests-G<N>/` | Directory - Python scripts, SQL transactions, README |
| 14 | `14-data-generator-G<N>/` | Directory - Python seeder, config, validation SQL, README |
| 15 | `15-index-tuning-report-G<N>.md` | Markdown (EXPLAIN plans) |
| 16 | `16-analytical-queries-G<N>.sql` | SQL |

> Replace `<N>` with your group number (e.g., `G11` for Group 11).

---

## 7. DBMS

This project uses **Microsoft SQL Server**. All SQL scripts target T-SQL syntax.

---

## 8. Notes on LLM Model Usage and Cost Control

Using LLM models may consume tokens and API credits. To avoid unnecessary cost:

- Use a cheaper or faster model for early drafts.
- Use a stronger model only for difficult reasoning, validation, and final review.
- Do not repeatedly regenerate all files from scratch.
- Ask the agent to update only the specific file or section that needs improvement.
- Keep prompts short, clear, and specific.
- Avoid sending unnecessary files such as `node_modules/`, `.git/`, logs, or large temporary files.
- Stop the agent if it loops or repeatedly produces similar outputs.
- Never commit API keys or tokens to Git.

Good prompt example:

```text
Read req/business-requirement.md and generate only outputs/01-business-req-analysis-G11.md.
```

Better than:

```text
Read the whole project and redo everything.
```

Another good prompt example:

```text
Use outputs/02-erd-design-G11.md to generate only outputs/03-logical-design-G11.md. Do not modify other files.
```

---

## 9. Academic Integrity

Students may use AI tools to support the project, but they are responsible for reviewing, evaluating, and improving the generated outputs.

Do not submit raw AI output without understanding or validation.

Each group must be able to explain:

- How the agent was configured.
- How the agent was improved.
- Why the final database design is valid.
- How the SQL scripts and queries work.
- How concurrency control was designed and tested.
- How index tuning improved query performance.