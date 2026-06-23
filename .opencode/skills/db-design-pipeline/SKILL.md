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

## Global Forced Assumptions & Business Rules Override
The original business requirement is ambiguous regarding the `Space` and `Facility` relationship. You MUST strictly adopt the "Catalog vs. Asset Hybrid Pattern" for all subsequent steps:
1. **Facility Catalog (`facility_catalog`):** A general catalog defining the category of items (e.g., 'Projector', 'Chair') and a flag `is_trackable` (BIT).
2. **Space-Facility M:N Mapping (`space_facility`):** An associative table linking a `space_code` and `catalog_id`, containing a `quantity` attribute for non-trackable items. This prevents data entry fatigue.
3. **Facility Asset 1:N Tracking (`facility_asset`):** A table for high-value, trackable assets linked to both `catalog_id` and `space_code`. It must contain an `asset_tag` (UNIQUE) and `status`.

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
* Instruction: Analyze the provided business requirement document. Identify and list the following clearly: business purpose, actors, entities, attributes, relationships, cardinalities, and all business rules. You MUST include the explicitly defined "Catalog vs. Asset Hybrid Pattern" (facility_catalog, space_facility, facility_asset) in your entities and relationships list.

# Step 2: Conceptual Design / ERD
* Save to: `outputs/02-erd-design-G11.md`
* Instruction: Based on the output of Step 1, design a Conceptual Entity-Relationship Diagram (ERD). Describe the main entities, attributes, relationships, cardinalities, and participation constraints. Provide the visual representation using Mermaid `erDiagram` syntax. Ensure the diagram visually represents the hybrid pattern: `space` has a many-to-many relationship with `facility_catalog` (resolved via `space_facility` with a quantity attribute) and a one-to-many relationship with `facility_asset` (for trackable items).

# Step 3: Logical Database Design
* Save to: `outputs/03-logical-design-G11.md`
* Instruction: Convert the ERD from Step 2 into a Relational Schema. Clearly list all relations (tables), attributes, primary keys (PK), foreign keys (FK), candidate keys, and key constraints. Use standard notation (e.g., TableName(PK, attr1, attr2, FK)).

# Step 4: Database Design Validation
* Save to: `outputs/04-design-validation-G11.md`
* Instruction: Evaluate the relational schema from Step 3 against the business rules from Step 1. Write a validation report explaining whether the schema correctly represents the ERD, satisfies all business rules (e.g., preventing overlapping bookings, maintenance checks), and uses appropriate keys and constraints.

# Step 5: Database Implementation
* Save to: `outputs/05-db-definition-G11.sql`
* Instruction: Write T-SQL (Microsoft SQL Server) DDL statements to implement the logical design. You MUST strictly follow these rules:
    1. Database Initialization & Drop Existing: Start the script by switching context to `master` database (`USE master; GO`). Check if the database `[CampusSpaceManagement]` already exists. If it exists, you MUST force-terminate all active connections using `ALTER DATABASE [CampusSpaceManagement] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;` and then execute `DROP DATABASE [CampusSpaceManagement]; GO`. After dropping, cleanly initialize it using `CREATE DATABASE [CampusSpaceManagement]; GO` followed by `USE [CampusSpaceManagement]; GO`.
    2. Clean Setup: Include logic to drop existing tables and objects gracefully (in reverse order of foreign key dependencies) before creating new ones to avoid conflicts during repeated tests.
    3. Table Definitions: Define all tables, Primary Keys, and constraints (CHECK, UNIQUE, NOT NULL).
    4. Foreign Key Constraints: Except where restricted by rule 8, foreign keys on non-identity fields (like `space_code`) MUST explicitly include `ON UPDATE CASCADE`. Evaluate if `ON DELETE CASCADE` is appropriate for the business logic; if so, include it, otherwise use `ON DELETE NO ACTION`.
    5. Syntax: Use standard T-SQL conventions (e.g., use `IDENTITY(1,1)` for auto-incrementing primary keys).
    6. Facility Hybrid Implementation: You MUST generate the exact schema structure for `facility_catalog`, `space_facility`, and `facility_asset` as defined in the Global Forced Assumptions. Use `IDENTITY(1,1)` for surrogate keys and `ON UPDATE CASCADE` for space code foreign keys.
    7. Data Integrity Trigger: You MUST write a T-SQL `AFTER INSERT, UPDATE` trigger on the `space_facility` table. The trigger logic must check: if the inserted/updated record links to a `facility_catalog` where `is_trackable = 1`, it must verify that the `quantity` value does NOT exceed the actual `COUNT(*)` of physical assets currently registered in the `facility_asset` table for that specific `space_code` and `catalog_id`. If the `quantity` is invalid, use `RAISERROR` to throw a clear error message and execute `ROLLBACK TRANSACTION`.
    8. Resolve Multiple Cascade Paths (Error 1785): Microsoft SQL Server strictly prohibits multiple cascade paths or referential cycles. Because surrogate primary keys like `user_id` and `booking_id` use `IDENTITY(1,1)` and will never change, you MUST use `ON UPDATE NO ACTION` and `ON DELETE NO ACTION` for ALL foreign keys referencing the `[user]` table or any identity-based tables. Do NOT use `ON UPDATE CASCADE` on these columns. You may only use `ON UPDATE CASCADE` for `space_code` relationships where necessary, ensuring it does not trigger multiple cascade paths.

# Step 6: Sample Data Preparation
* Save to: `outputs/06-sample-data-G11.sql`
* Instruction: Write Microsoft SQL Server `INSERT` statements to populate the tables from Step 5 with realistic sample data. Ensure correct insertion order to avoid foreign key constraint violations. Include data to test normal operations (successful bookings) and exceptional cases (maintenance, rejected bookings, no-shows).
* Note for Identity Columns: Because the tables use `IDENTITY(1,1)`, if your `INSERT` statements include specific explicit values for primary key identity columns, you MUST wrap those blocks with `SET IDENTITY_INSERT [TableName] ON;` before the statements and `SET IDENTITY_INSERT [TableName] OFF;` immediately after.
* Critical Insertion Order for Facility Trigger: Because of the `trg_space_facility_quantity_validate` trigger, you MUST insert data into the `facility_asset` table BEFORE inserting data into the `space_facility` table for any trackable catalog items.
* Strict Data Consistency Rule: For trackable items (`is_trackable = 1`), the `quantity` value you insert into `space_facility` MUST EXACTLY MATCH the actual number of rows you generated in `facility_asset`. Do NOT set large quantities (like 40) if you only generate 4 asset records. Keep the quantities small (e.g., 2 to 5 items) so you can easily write the corresponding `facility_asset` rows without omitting any data.

# Step 7: Query Design
* Save to: `outputs/07-query-design-G11.sql`
* Instruction: Design and write 5 meaningful Microsoft SQL Server queries to answer business questions based on the scenario. For each of the 5 queries, use SQL comments (`--`) to document:
    1. The business question being answered.
    2. The target user(s) who would use the query.
    3. A short explanation of why the query is useful.
    4. The executable `SELECT` statement.