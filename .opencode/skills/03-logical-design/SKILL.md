---
name: 03-logical-design
description: Phase 1 Task 3: Logical Database Design. Converts the ERD into a relational schema with relations, attributes, PKs, FKs, and constraints.
compatibility: opencode
---

# 03-logical-design Skill

**Objective:**
Transform the conceptual ERD into a normalized relational schema ready for SQL Server implementation.

**Instructions for the Agent:**
1. **Input Context**: Locate and read `outputs/02-erd-design-G11.md`. You may also reference `outputs/01-business-req-analysis-G11.md` to ensure all business rules are covered.
2. **Relational Schema Conversion**: 
   - Convert the ERD into a set of normalized relations (tables).
   - Explicitly resolve any many-to-many (M:N) relationships by creating associative (junction) tables.
   - Handle multi-valued attributes and 1:1 relationships appropriately.
3. **Schema Definition (Markdown Tables)**: Define each table using a Markdown table format. Include columns for:
   - `Column Name`(MUST use strictly `snake_case` for all table and column names).
   - `Data Type` (Use logical SQL Server types like INT, NVARCHAR, DATETIME2)
   - `Constraints & Keys`: Explicitly mark PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT. 
     - *Crucial:* For surrogate primary keys, explicitly state `IDENTITY(1,1)`.
     - *Crucial:* For `CHECK` constraints, you MUST explicitly define the exact logical expression rather than just writing the word "CHECK". (For example: explicitly write out the chronological boundary conditions for date/time columns, or list the exact enumeration values for status/category fields based on the business rules).
     - *Enum Fidelity:* Enum/CHECK IN values must come from Step 1 wording (casing reformatting only). Do not invent, abbreviate, or reword values. If Step 1 doesn't enumerate them, note this in Section 5 instead of inventing values.
   - **Strict Constraint Coverage (Anti-Delegation Rule):** - You MUST NOT delegate row-level business logic to the application layer. 
     - *Conditional Mandatory Fields:* If a rule dictates that a specific field becomes mandatory based on the value of another field within the *same table* (e.g., a reason is required when a specific state is reached), you MUST strictly enforce this using a `CHECK` constraint. 
     - *No Mere Notes:* Do not just leave a note saying "handled by application" for row-level constraints.
     - *Allowed Delegation:* Only cross-table dependencies or multi-row validations (e.g., time overlaps) are permitted to be deferred to application logic.
   - *Also list any Candidate Keys (CK) below each table if applicable.*
4. **Summary of Referential Integrity**: Create a dedicated table to summarize all Foreign Keys. You MUST explicitly define the referential actions for both `UPDATE` and `DELETE` (e.g., CASCADE, NO ACTION, SET NULL) based on business logic (e.g., historical records usually dictate NO ACTION on delete). 
   - *Apply consistently:* ON DELETE = NO ACTION for any audit/historical/decision table (even if structurally a "child"); CASCADE only for pure junction/mapping tables. ON UPDATE = CASCADE for FKs referencing natural keys, NO ACTION for FKs referencing surrogate keys — apply the same rule to every FK of that kind, not case-by-case.
   - Format columns: `From Table` | `From Column` | `To Table` | `To Column` | `ON UPDATE` | `ON DELETE`
5. **Traceability & Validation**:
   - Create an "Entity-to-Table Traceability" matrix mapping Step 2 entities to Step 3 tables.
   - Create a "Business Rule Enforcement" matrix explaining how key rules from Step 1 are enforced (e.g., via CHECK constraints, UNIQUE constraints, or deferred to application logic).
   - *Cross-check:* If a Step 3 column has no matching attribute in Step 2, note it in Section 5 rather than adding it silently.
6. **Formatting Structure**: Use the following exact headings:
   - `## 1. Relational Schema`
   - `## 2. Summary of Referential Integrity`
   - `## 3. Entity-to-Table Traceability`
   - `## 4. Business Rule Enforcement`
   - `## 5. Conversion Notes` (Briefly explain how you resolved M:N relationships, 1:1 relationships, and your logic behind CASCADE/NO ACTION choices).

**Output:**
Generate the design and write it to `outputs/03-logical-design-G11.md`.