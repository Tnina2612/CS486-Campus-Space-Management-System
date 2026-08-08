---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, validation, DDL, sample data, and queries step by step.
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
The original business requirement is ambiguous regarding the `SPACE` and `FACILITY` relationship. You MUST strictly adopt the "Catalog vs. Asset Hybrid Pattern" for all subsequent steps:
1. **Facility Catalog (`FACILITY_CATALOG`):** A general catalog defining the category of items (e.g., 'Projector', 'Chair') and a flag `is_trackable` (BIT).
2. **Space-Facility M:N Mapping (`SPACE_FACILITY`):** An associative table linking a `space_code` and `catalog_id`, containing a `quantity` attribute for non-trackable items. This prevents data entry fatigue.
3. **Facility Asset 1:N Tracking (`FACILITY_ASSET`):** A table for high-value, trackable assets linked to both `catalog_id` and `space_code`. It must contain an `asset_tag` (UNIQUE) and `status`.
4. **Booking Lifecycle Normalization (Strict 1-to-1):** You MUST NOT create a flat, denormalized booking table. You MUST separate the booking lifecycle into three distinct tables representing different stages:
    * `BOOKING`: Stores ONLY the initial request data (user, space, requested times, purpose).
    * `APPROVAL`: Stores manager/staff approval decisions and notes. It MUST have a strict 1-to-1 relationship with `BOOKING` (enforced via a `UNIQUE(booking_id)` constraint).
    * `USAGE_SESSION`: Stores actual check-in/check-out times and physical condition of the room. It MUST have a strict 1-to-1 relationship with `BOOKING` (enforced via a `UNIQUE(booking_id)` constraint).

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

## Pipeline Execution
Use the step files as the step-specific entry points.

# Step 1 - Business Requirement Analysis
Open `../01-business-req-analysis/SKILL.md`, and write `outputs/01-business-req-analysis-G11.md`.

# Step 2 - Conceptual Design / ERD
Open `../02-erd-design/SKILL.md`, and write `outputs/02-erd-design-G11.md`.

# Step 3 - Logical Database Design
Open `../03-logical-design/SKILL.md`, and write `outputs/03-logical-design-G11.md`.

# Step 4 - Database Design Validation
Open `../04-design-validation/SKILL.md`, and write `outputs/04-design-validation-G11.md`.

# Step 5 - Database Implementation
Open `../05-db-definition/SKILL.md`, and write `outputs/05-db-definition-G11.sql`.

# Step 6 - Sample Data Preparation
Open `../06-sample-data/SKILL.md`, and write `outputs/06-sample-data-G11.sql`.

# Step 7 - Query Design
Open `../07-query-design/SKILL.md`, and write `outputs/07-query-design-G11.sql`.
