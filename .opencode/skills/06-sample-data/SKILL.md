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

### 2. Data Realism (Zero Dummy Data)
* **Users:** Generate users covering MULTIPLE roles defined in the system. Use realistic international names (e.g., Emily Davis) and university email domains.
* **Spaces & Assets:** Autogenerate realistic academic spaces (e.g., Alan Turing Auditorium) and valid hardware names.
* **Timestamps:** Generate logical, chronological dates. End times MUST be strictly greater than start times.
* **Exact Variables:** You MUST extract and use the EXACT table names, column names, and ENUM values from Source 2. Do not invent column names.

### 3. Business-Rule-Driven Data Generation (The Test Suite)
Instead of random inserts, your data MUST explicitly prove that the database design handles the real-world logic.
* **Analyze:** Read EVERY Business Rule listed in Source 1.
* **Scenario Generation:** For EACH rule (e.g., overlapping bookings, role constraints, hybrid facility tracking, status lifecycles, maintenance blocks), you MUST purposefully inject specific data records designed to query/test that exact rule. Ensure you include both successful operations (happy paths) and intended edge cases (e.g., a rejected booking, a no-show).
  * **Required Data Coverage:** Ensure you include at least one `SPACE` with `current_status = 'in_use'` to cover all enum values.
  * **Trigger Testing & Error Precision:** When testing edge cases that intentionally fail triggers (e.g., overlapping bookings, unavailable space bookings, facility quantity limits), you MUST wrap the failing statement in a `BEGIN TRY ... END TRY BEGIN CATCH PRINT 'PASS: ' + ERROR_MESSAGE(); END CATCH` block so the script execution does not halt. 
  * **CRITICAL FOR TRIGGER TESTS:** The test data for a trigger MUST be perfectly valid against ALL other database constraints (e.g., valid Foreign Keys, exactly matching `ENUM`/`CHECK` string values, no duplicate Primary Keys). If you insert an invalid `purpose_type` (like 'Exam' instead of 'Examination') or a duplicate Primary Key, the `INSERT` will fail BEFORE the trigger even fires, defeating the purpose of the test. When testing `SPACE_FACILITY` quantity limits, use an `UPDATE` statement on an existing row instead of an `INSERT` to avoid Primary Key violation errors.
* **Explicit Commenting:** You MUST prepend the relevant `INSERT` blocks with a SQL comment explicitly stating which Business Rule is being tested. 
  * *Example Format:* `-- [Testing Business Rule: No Overlapping Bookings]: Inserting a rejected booking due to time conflict with an approved one.`

## Output Format Requirements
* **Target File:** Save output exactly to `outputs/06-sample-data-G11.sql`.
* **SQL Standard:** ONLY output standard, executable SQL `INSERT` statements. 
* **Column Explicitness:** NEVER use `INSERT INTO table VALUES (...)`. You MUST explicitly list column names: `INSERT INTO table_name (col1, col2) VALUES (val1, val2);`.
* **Documentation:** Add blank lines and clear `--` comments separating the hierarchical phases and the specific Business Rule test blocks.