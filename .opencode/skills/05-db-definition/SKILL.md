---
name: 05-db-definition
description: Write the SQL Server DDL implementation for the logical design.
compatibility: opencode
---

# Step 5 - Database Implementation

## Objective
Implement the logical design as Microsoft SQL Server DDL.

## Input Context
- Read `outputs/04-design-validation-G11.md` before writing DDL.
- Keep the logical schema from `outputs/03-logical-design-G11.md` and the hybrid assumptions from `../db-design-pipeline/SKILL.md` in view.

## Instructions & Constraints
- Save to: `outputs/05-db-definition-G11.sql`
- Instruction: Write T-SQL (Microsoft SQL Server) DDL statements to implement the logical design. You MUST strictly follow these rules:
1. Database Initialization & Drop Existing: Start the script by switching context to `master` database (`USE master; GO`). Check if the database `[CampusSpaceManagement]` already exists using `IF EXISTS (SELECT name FROM sys.databases WHERE name = N'CampusSpaceManagement')`. Inside the IF block, force-terminate all active connections using `ALTER DATABASE [CampusSpaceManagement] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;` and then execute `DROP DATABASE [CampusSpaceManagement];`. After the IF block, cleanly initialize it using `CREATE DATABASE [CampusSpaceManagement]; GO` followed by `USE [CampusSpaceManagement]; GO`.
2. Clean Setup: Include logic to drop existing tables and objects gracefully (in reverse order of foreign key dependencies) before creating new ones to avoid conflicts during repeated tests.
3. Table Definitions: Define all tables, Primary Keys, and constraints (CHECK, UNIQUE, NOT NULL).
4. Foreign Key Constraints: Except where restricted by rule 8, foreign keys on non-identity fields (like `space_code`) MUST explicitly include `ON UPDATE CASCADE`. Evaluate if `ON DELETE CASCADE` is appropriate for the business logic; if so, include it, otherwise use `ON DELETE NO ACTION`.
5. Syntax: Use standard T-SQL conventions (e.g., use `IDENTITY(1,1)` for auto-incrementing primary keys).
6. Facility Hybrid Implementation: You MUST generate the exact schema structure for `facility_catalog`, `space_facility`, and `facility_asset` as defined in the Global Forced Assumptions. Use `IDENTITY(1,1)` for surrogate keys and `ON UPDATE CASCADE` for space code foreign keys.
7. Data Integrity Trigger: You MUST write a T-SQL `AFTER INSERT, UPDATE` trigger on the `space_facility` table. The trigger logic must check: if the inserted/updated record links to a `facility_catalog` where `is_trackable = 1`, it must verify that the `quantity` value does NOT exceed the actual `COUNT(*)` of physical assets currently registered in the `facility_asset` table for that specific `space_code` and `catalog_id`. If the quantity is invalid, use `RAISERROR` to throw a clear error message and execute `ROLLBACK TRANSACTION`.
8. Resolve Multiple Cascade Paths (Error 1785): Microsoft SQL Server strictly prohibits multiple cascade paths or referential cycles. Because surrogate primary keys like `user_id` and `booking_id` use `IDENTITY(1,1)` and will never change, you MUST use `ON UPDATE NO ACTION` and `ON DELETE NO ACTION` for ALL foreign keys referencing the `[user]` table or any identity-based tables. Do NOT use `ON UPDATE CASCADE` on these columns. You may only use `ON UPDATE CASCADE` for `space_code` relationships where necessary, ensuring it does not trigger multiple cascade paths.
