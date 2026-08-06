---
name: 11-concurrency-design
description: Design a robust concurrency control mechanism for the Campus Space Management System.
compatibility: opencode
---

# Skill: Concurrency Control Design

## Description
This skill focuses on designing a robust concurrency control mechanism for the Campus Space Management System. It analyzes the risk of overlapping bookings occurring during simultaneous instant booking and staff approval operations, and proposes a specific Microsoft SQL Server (T-SQL) based solution to prevent these anomalies.

## Context Files to Read
- `req/business-requirement.md` (Specifically the "Concurrent Booking and Approval" section)
- `outputs/08-requirement-change-analysis-G11.md` (For identified conflicts)
- `outputs/09-updated-erd-and-logical-design-G11.md` (To understand the table structures involved)

## Instructions
1. **Identify the Core Conflict:** Explicitly describe the race condition where two concurrent transactions attempt to book the same space for overlapping time periods.
2. **Evaluate Strategies:** Compare at least two MSSQL concurrency control strategies (e.g., pessimistic locking using `WITH (UPDLOCK, HOLDLOCK)` table hints vs. optimistic concurrency using `SNAPSHOT ISOLATION` or `SERIALIZABLE` transaction isolation level).
3. **Select and Justify:** Choose the most appropriate strategy for this specific system. Justify the choice based on data integrity guarantees, performance impact, and implementation complexity in SQL Server.
4. **Design the Transaction Flow:** Outline the exact sequence of SQL steps (`BEGIN TRAN`, lock/check, insert/update, `COMMIT`/`ROLLBACK`) that a booking transaction must follow to remain safe.

## Output
Generate a Markdown document detailing the chosen concurrency architecture.
**Save output to:** `outputs/11-concurrency-design-G11.md`