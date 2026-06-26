---
name: 06-sample-data
description: Prepare sample data for the SQL Server schema.
compatibility: opencode
---

# Step 6 - Sample Data Preparation

## Objective
Prepare realistic sample data that can be inserted after the DDL is created.

## Input Context
- Read `outputs/05-db-definition-G11.sql` first.
- Use the table order and constraints from Step 5.
- Keep the hybrid-pattern trigger behavior from `../db-design-pipeline/SKILL.md` in mind while choosing insert order.

## Instructions & Constraints
- Save to: `outputs/06-sample-data-G11.sql`
- Instruction: Write Microsoft SQL Server `INSERT` statements to populate the tables from Step 5 with realistic sample data. Ensure correct insertion order to avoid foreign key constraint violations. Include data to test normal operations (successful bookings) and exceptional cases (maintenance, rejected bookings, no-shows).
- Note for Identity Columns: Because the tables use `IDENTITY(1,1)`, if your `INSERT` statements include specific explicit values for primary key identity columns, you MUST wrap those blocks with `SET IDENTITY_INSERT [TableName] ON;` before the statements and `SET IDENTITY_INSERT [TableName] OFF;` immediately after.
- Critical Insertion Order for Facility Trigger: Because of the `trg_space_facility_quantity_validate` trigger, you MUST insert data into the `facility_asset` table BEFORE inserting data into the `space_facility` table for any trackable catalog items.
- Strict Data Consistency Rule: For trackable items (`is_trackable = 1`), the `quantity` value you insert into `space_facility` MUST EXACTLY MATCH the actual number of rows you generated in `facility_asset`. Do NOT set large quantities (like 40) if you only generate 4 asset records. Keep the quantities small (e.g., 2 to 5 items) so you can easily write the corresponding `facility_asset` rows without omitting any data.
