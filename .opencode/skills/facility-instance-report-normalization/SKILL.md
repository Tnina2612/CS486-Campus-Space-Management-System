---
name: facility-instance-report-normalization
description: Normalizes the incident-report target model so reports can reference a room, a facility instance within a room, or a specific tracked asset without ambiguity.
compatibility: opencode
---

# facility-instance-report-normalization Skill

## Objective
Make the reporting model explicitly support three target levels for incident and maintenance reporting:
1. room-level reporting (for example, a room is too hot),
2. facility-type-in-room reporting (for example, a chair in that room is broken),
3. specific tracked asset reporting (for example, projector PJ-001 is broken).

## Required Design Change
The agent must treat this as a schema evolution task that normalizes the reporting target through a dedicated facility-instance layer.

### 1. Normalize `SPACE_FACILITY` into an independent entity
- Replace the composite-key design of `SPACE_FACILITY` with an independent entity that has its own surrogate key `space_facility_id`.
- Preserve the relationship to `SPACE` and `FACILITY_CATALOG` through foreign keys.
- Keep a business unique constraint on `(space_id, catalog_id)` so the same facility type is not duplicated within the same room.
- If the Phase 1 design already used `(space_id, catalog_id)` as the primary key, the agent must evolve it additively by introducing `space_facility_id` as the new primary key and preserving the old natural key as a unique constraint.

### 2. Repoint `FACILITY_ASSET` to the normalized facility instance
- `FACILITY_ASSET` must no longer directly reference `space_id` and `catalog_id` as the reporting target.
- Add `space_facility_id` as a foreign key to `SPACE_FACILITY(space_facility_id)`.
- If the Phase 1 schema already has `space_id` and `catalog_id` columns in `FACILITY_ASSET`, the agent must migrate them to the new foreign key and preserve data by backfilling the matching `SPACE_FACILITY` row.

### 3. Extend `INCIDENT_REPORT` to support all three report target levels
- Add `space_id` as the room-level context.
- Add nullable `space_facility_id` to represent a facility type present in that room.
- Add nullable `asset_id` to represent a specific tracked asset.
- The design must support all three reporting modes:
  - Room-level: `space_id` set, `space_facility_id` = `NULL`, `asset_id` = `NULL`.
  - Facility-type-in-room: `space_id` set, `space_facility_id` set, `asset_id` = `NULL`.
  - Specific asset: `space_id` set, `space_facility_id` set, `asset_id` set.

### 4. Enforce the business rule for target integrity
- If `asset_id` is not `NULL`, then `space_facility_id` must also be non-`NULL`.
- The chosen asset must belong to the selected `space_facility_id`.
- The agent should implement this as a combination of declarative constraints and application logic where the DBMS cannot express the full rule directly.

### 5. Preserve consolidation and maintenance traceability
- The normalized target columns must be carried forward when a report is consolidated into a `MAINTENANCE_RECORD` through `REPORT_CONSOLIDATION`.
- The design must preserve the full reporting context from room-level to asset-level, so downstream maintenance processing can inherit the same target without ambiguity.

## Required Output Expectations
When the agent uses this skill, the generated design and migration artifacts must explicitly document:
- the new surrogate key on `SPACE_FACILITY`;
- the new foreign key from `FACILITY_ASSET` to `SPACE_FACILITY`;
- the new nullable report-target columns on `INCIDENT_REPORT`;
- the integrity rule connecting `asset_id` and `space_facility_id`; and
- how existing data is backfilled or preserved during migration.
