---
name: 12-concurrency-implementation
description: Translate the theoretical concurrency design into executable T-SQL scripts.
compatibility: opencode
---

# Skill: Concurrency Implementation

## Description
This skill translates the theoretical concurrency design into executable T-SQL scripts. It creates the necessary SQL transactions, stored procedures, or triggers in SQL Server that enforce the concurrency rules and prevent overlapping space bookings.

## Context Files to Read
- `outputs/09-updated-erd-and-logical-design-G11.md` (For exact table and column names)
- `outputs/10-schema-migration-G11.sql` (To ensure compatibility with the updated schema)
- `outputs/11-concurrency-design-G11.md` (For the chosen concurrency strategy and transaction flow)

## Instructions
1. **Write Transaction Scripts:** Based on the strategy defined in step 11, write the raw SQL scripts or `T-SQL` stored procedures required to handle booking insertions safely.
2. **Implement Overlap Checking:** Ensure the implementation correctly calculates time overlaps (e.g., using explicit inequality checks like `NewStart < ExistingEnd AND NewEnd > ExistingStart`, as T-SQL does not have a native `OVERLAPS` operator).
3. **Enforce the Lock/Isolation:** Embed the appropriate table hints (e.g., `WITH (UPDLOCK, SERIALIZABLE)`) or `SET TRANSACTION ISOLATION LEVEL` commands in the correct execution order.
4. **Error Handling:** Ensure the script clearly uses `TRY...CATCH` blocks to raise an exception (`THROW` / `RAISERROR`) or rolls back gracefully when a concurrent overlap or deadlock is detected.

## Output
Generate a SQL file containing the stored procedures, triggers, or transaction templates that implement the concurrency control.
**Save output to:** `outputs/12-concurrency-implementation-G11.sql`