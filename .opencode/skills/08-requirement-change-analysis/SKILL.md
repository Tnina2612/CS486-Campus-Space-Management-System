---
name: 08-requirement-change-analysis
description: Identifies what changes in the business requirement, which entities/relationships/business rules are affected, and the concurrency conflicts that may arise.
compatibility: opencode
---

# 08-requirement-change-analysis Skill

**Objective:**
Analyze the Phase 2 requirement changes, translate them into a structured list of affected design elements (entities, relationships, business rules, attributes), and identify the possible conflicts introduced by concurrent operations — before any design or implementation work begins.

**Instructions for the Agent:**
1. **Input Context**: Locate and read the original business requirement (`req/business-requirement.md`). Read the Phase 2 extended requirements and extract every new/changed statement. Use Phase 1 outputs (`outputs/01` to `outputs/04`) as baseline to know what already exists.
2. **Change Inventory**: Produce a concise but complete inventory of the Phase 2 requirement changes. For each change, state:
   - What the new/changed rule or operating condition is.
   - Which existing entity, attribute, relationship, or business rule in Phase 1 is affected.
   - The nature of the effect (attribute added, status range extended, new relationship needed, existing rule refined/relaxed/deferred, new negative/positive behavior).
   - Any knock-on effect on other entities or rules.
   - Mandatory coverage:
     - `SPACE.current_status` no longer carries `Under Maintenance`; maintenance blocking is delegated to `MAINTENANCE_RECORD` overlap where `impact_level = 'out-of-service'`.
     - End users submit `INCIDENT_REPORT`; manager/staff triage consolidates duplicate reports into one `MAINTENANCE_RECORD` and decides `impact_level`.
3. **Business Rule Impact**: For every affected business rule from Phase 1, state clearly whether it is:
   - **Kept unchanged**, or
   - **Refined** (its condition changes), and describe the new condition, or
   - **Extended** with new sub-rules, or
   - **Delegated** (needs application/concurrency-level handling rather than a declarative constraint).
   Never silently drop or ignore a Phase 1 rule.
4. **Concurrency Conflict Analysis**: Identify at least one realistic multi-user race condition that the new operating conditions can trigger. For each conflict, describe:
   - The exact operation sequence (two concurrent operations and the point where a check-then-act interleaving breaks correctness).
   - The undesirable outcome if not controlled (e.g., data integrity violation, lost update, double-effort, inconsistent state).
   - Which business rule / invariant is threatened.
   Include at least one conflict around duplicate `INCIDENT_REPORT` submissions and manager consolidation into a single maintenance record.
5. **Assumptions & Open Questions**:
   - Record any decision you must make that the requirement did not spell out.
   - Record any ambiguity or missing detail as an open question for confirmation.
6. **Formatting Structure**: Use clear, sectioned Markdown with tables to summarize: (1) requirement changes, (2) affected entities/relationships/attributes, (3) business rule status, (4) concurrency conflicts, (5) assumptions & open questions.

**Output:**
Generate the analysis and write it to `outputs/08-requirement-change-analysis-G11.md`.

Do NOT modify or regenerate any Phase 1 output file.