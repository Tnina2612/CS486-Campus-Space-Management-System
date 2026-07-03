---
name: 02-erd-design
description: Convert the requirement analysis into a conceptual ERD.
compatibility: opencode
---

# Step 2 - Conceptual Design / ERD

## Objective
Convert the requirement analysis into an ERD with clear entities, relationships, foreign keys, and participation constraints.

## Input Context
- Read `outputs/01-business-req-analysis-G11.md`.
- Keep `../db-design-pipeline/SKILL.md` open for the global hybrid-pattern assumptions.
- Reuse the business rules and entity list from Step 1 instead of reinterpreting the requirement from scratch.

## Instructions & Constraints
- Save to: `outputs/02-erd-design-G11.md`

- Instruction: Based on the output of Step 1, design an Entity-Relationship Diagram (ERD). Describe the main entities, attributes, relationships, cardinalities, and participation constraints. Provide the visual representation using Mermaid `erDiagram` syntax. Ensure the diagram visually represents the hybrid pattern: `space` has a many-to-many relationship with `facility_catalog`. Because this relationship tracks a 'quantity', represent it as an Associative Entity (`space_facility`).

- For every relationship:
    * Determine minimum participation (0 or 1).
    * Determine maximum participation (1 or many).
    * Reflect both constraints using Crow's Foot notation.
  Avoid generic cardinalities.

- **STRICT CONSISTENCY RULE**: You MUST NOT introduce any entity, attribute, relationship, subtype, associative entity, business rule, status value, or constraint that was not explicitly identified in Step 1. If information required for the ERD is missing from Step 1, DO NOT infer it. Instead, document the ambiguity in a short "Assumptions and Gaps" section.

- **Data Types**: Use conceptual data types (e.g., `string`, `integer`, `boolean`, `datetime`) instead of physical DBMS-specific types (e.g., DO NOT use `varchar`, `nvarchar`, `char`). Prioritize using `string` for all text-based attributes to maximize readability.

- **Before generating the ERD**:
    1. Extract all entities identified in Step 1.
    2. Extract all relationships identified in Step 1.
    3. Verify every entity in the ERD appears in the extracted list.
    4. Verify every relationship in the ERD appears in the extracted list.
    5. Then generate the final ERD.

- **SELF-REVIEW**: 
    1. Compare all entities and relationships against Step 1.
    2. Remove any unsupported elements before producing the final ERD.

- **CRITICAL FORMATTING CONSTRAINTS:**
    1. Do NOT include any inline comments (e.g., `%%`) inside the Mermaid diagram code, as this will break the CLI output parser.
    2. **Key Markers & Collisions**: Mermaid `erDiagram` natively supports `PK` and `FK` markers, but **does not support stacking both natively on the same attribute**. 
       - If an attribute serves as BOTH a Primary Key and a Foreign Key, **you MUST prioritize the `PK` marker natively and append the FK inside double quotes** (e.g., `string space_id PK "FK"`). 
       - For standard foreign keys, use `FK`.
       - Any other attribute constraints (e.g., UK, Candidate Key) MUST ALSO be enclosed in double quotes (e.g., `"UK"`, `"Candidate Key"`) at the end of the attribute definition.
    
- **MODEL CONSTRAINTS**: Do not include:
    1. Pure junction tables (unless they contain specific business attributes, making them Associative Entities).
    2. Database indexes.
    3. Physical database design decisions.
    4. DBMS-specific types.

- **Naming Rules**:
    1. Entity names: UPPERCASE singular nouns.
    2. Attribute names: snake_case.
    3. Relationship names: implicit through ERD connections only.
    4. Do not use spaces in entity names.

- **ERD VALIDATION CHECKLIST**: Before finalizing:
    1. Every relationship must connect exactly two entities.
    2. Every entity must have a primary identifier attribute (`PK`).
    3. Dependent entities must have foreign keys correctly labeled with `FK`.
    4. No orphan entity is allowed.
    5. No duplicate relationship is allowed.
    6. Mermaid syntax must be valid.
    7. All entity names must be uppercase singular nouns.