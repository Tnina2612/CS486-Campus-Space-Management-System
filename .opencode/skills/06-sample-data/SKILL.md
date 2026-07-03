---
name: 06-sample-data
description: Generate realistic, business-rule-driven SQL INSERT statements for sample data preparation.
compatibility: opencode
---

# Step 6 - Sample Data Preparation

## Objective
* Generate a complete, ready-to-run SQL script containing `INSERT` statements for the Campus Space Management System.
* Ensure data is highly realistic, context-appropriate, and strictly follows referential integrity (Foreign Key hierarchy).
* **Crucial:** The generated data MUST act as a comprehensive Test Suite that purposefully creates scenarios to validate ALL Business Rules defined in Step 1.

## Input Context
* **Source 1:** Read `outputs/01-business-req-analysis-G11.md` (Extract exact roles, statuses, and critically: **The Business Rules**).
* **Source 2:** Read `outputs/03-logical-design-G11.md` (This is your SINGLE SOURCE OF TRUTH for exact table names, column names, constraints, and data types).

## Execution Directives

### 1. Referential Integrity (Strict Insertion Order)
You MUST analyze the Foreign Key dependencies in Source 2 and generate `INSERT` statements in a strict hierarchical order to avoid constraint violations:
* **Phase 1:** Base Entities (e.g., Users, Spaces, Catalogs/Categories).
* **Phase 2:** Associative or Child Entities (e.g., Space-Facility relations, Physical Assets).
* **Phase 3:** Transactional Entities (e.g., Bookings, Maintenance Records).

### 2. Variable Scoping & Batch Execution (CRITICAL)
* **NO PREMATURE `GO` STATEMENTS:** In T-SQL, variables declared with `DECLARE` are destroyed at the end of a batch (when a `GO` statement is reached). You MUST NOT use `GO` statements to separate your insertion phases if variables from Phase 1 or 2 (e.g., `@Sp1`, `@Stu1`) are required in subsequent phases. Output the entire data population script as a single, continuous batch. You may use `GO` only at the very end of the population script or between isolated `TRY/CATCH` constraint tests.

### 3. Trigger Bypass for Seeding (CRITICAL)
* **CHICKEN-AND-EGG VALIDATION:** When seeding data into tables that validate against each other via triggers (e.g., `space_facility` validating quantities against `facility_assets`), the trigger will fail because the dependent data does not exist yet. 
* You MUST wrap the insertion blocks for interdependent tables with `DISABLE TRIGGER` and `ENABLE TRIGGER` commands.
  * *Example:* `DISABLE TRIGGER TRG_ValidateFacilityQuantity ON dbo.space_facility;`
    `-- INSERT INTO space_facility...`
    `-- INSERT INTO facility_assets...`
    `ENABLE TRIGGER TRG_ValidateFacilityQuantity ON dbo.space_facility;`

### 4. Data Realism (Zero Dummy Data)
* **Users:** Generate users covering MULTIPLE roles defined in the system. Use realistic international names (e.g., Emily Davis) and university email domains.
* **Spaces & Assets:** Autogenerate realistic academic spaces (e.g., Alan Turing Auditorium) and valid hardware names.
* **Timestamps:** Generate logical, chronological dates. End times MUST be strictly greater than start times. Spread bookings across multiple weeks/months — do NOT cluster everything on the same day.
* **Exact Variables:** You MUST extract and use the EXACT table names, column names, and ENUM values from Source 2. Do not invent column names.

### 5. Minimum Data Volume (MANDATORY)
You MUST generate AT LEAST the following number of rows per table category. These are minimums — generate more if needed:
* **Users:** At least 15 users, with at least 2 users per role defined in the system.
* **Spaces:** At least 8 spaces covering ALL space types (classroom, lab, auditorium, meeting room, etc.) and ALL space statuses (available, in use, under maintenance, temporarily closed, retired).
* **Facility Catalog:** At least 6 catalog entries — mix of trackable and non-trackable items.
* **Space-Facility mappings:** At least 10 rows linking spaces to facilities.
* **Facility Assets:** At least 8 physical assets for trackable items.
* **Bookings:** At least 20 bookings covering ALL booking statuses (pending, approved, rejected, cancelled, checked in, completed, no-show) and ALL purpose types.
* **Approvals:** At least 10 approval records — include both approved and rejected decisions with meaningful decision notes.
* **Usage Sessions:** At least 8 session records — include both normal completions and sessions with damage/issue notes.
* **Maintenance:** At least 6 maintenance records covering ALL maintenance statuses and different problem types.

### 6. Full Enum & Status Coverage (MANDATORY)
* For EVERY column that has a `CHECK IN (...)` constraint, you MUST generate at least one row using EACH allowed value. This ensures every status, type, and category is exercised.
* **Example:** If `booking.status` allows 7 values, you need at least 7 bookings — one per status value.

### 7. Business-Rule-Driven Data Generation (The Test Suite)
Instead of random inserts, your data MUST explicitly prove that the database design handles the real-world logic.
* **Analyze:** Read EVERY Business Rule listed in Source 1.
* **Scenario Generation:** For EACH rule (e.g., overlapping bookings, role constraints, hybrid facility tracking, status lifecycles, maintenance blocks), you MUST purposefully inject specific data records designed to query/test that exact rule. Ensure you include both successful operations (happy paths) and intended edge cases (e.g., a rejected booking, a no-show).
* **Strict Constraint Testing (MANDATORY):** In addition to business rules, you MUST write `BEGIN TRY...CATCH` blocks to explicitly test the following core database constraints:
  - **UNIQUE Constraints:** Attempt to insert a duplicate `email` or `asset_tag` to prove the `UNIQUE` constraint blocks it.
  - **FOREIGN KEY Deletions:** Attempt to `DELETE` a parent record (e.g., a User who has made a Booking, or a Space that has Facilities) to prove that the `ON DELETE NO ACTION` constraint correctly blocks the deletion of referenced data.
  * **Required Data Coverage:** Ensure you include at least one `SPACE` with `current_status = 'in_use'` to cover all enum values.
  * **Trigger Testing & Error Precision:** When testing edge cases that intentionally fail triggers (e.g., overlapping bookings, unavailable space bookings, facility quantity limits), you MUST wrap the failing statement in a `BEGIN TRY ... END TRY BEGIN CATCH PRINT 'PASS: ' + ERROR_MESSAGE(); END CATCH` block so the script execution does not halt. 
  * **CRITICAL FOR TRIGGER TESTS:** The test data for a trigger MUST be perfectly valid against ALL other database constraints (e.g., valid Foreign Keys, exactly matching `ENUM`/`CHECK` string values, no duplicate Primary Keys). If you insert an invalid `purpose_type` (like 'Exam' instead of 'Examination') or a duplicate Primary Key, the `INSERT` will fail BEFORE the trigger even fires, defeating the purpose of the test. When testing `SPACE_FACILITY` quantity limits, use an `UPDATE` statement on an existing row instead of an `INSERT` to avoid Primary Key violation errors.
* **Explicit Commenting:** You MUST prepend the relevant `INSERT` blocks with a SQL comment explicitly stating which Business Rule is being tested. 
  * *Example Format:* `-- [Testing Business Rule: No Overlapping Bookings]: Inserting a rejected booking due to time conflict with an approved one.`

## Output Format Requirements
* **Target File:** Save output exactly to `outputs/06-sample-data-G11.sql`.
* **SQL Standard:** ONLY output standard, executable SQL `INSERT` statements. 
* **Column Explicitness:** NEVER use `INSERT INTO table VALUES (...)`. You MUST explicitly list column names: `INSERT INTO table_name (col1, col2) VALUES (val1, val2);`.
* **IDENTITY Rules (CRITICAL):** Because primary keys use `IDENTITY(1,1)`, you MUST NOT insert values directly into primary key columns. Let SQL Server auto-generate them. To maintain Foreign Key relationships in this script, you MUST declare and use SQL variables (e.g., `DECLARE @UserId1 INT = SCOPE_IDENTITY();`) immediately after inserting a parent record, and use that variable when inserting child records.
* **Documentation:** Add blank lines and clear `--` comments separating the hierarchical phases and the specific Business Rule test blocks.