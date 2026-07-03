---
name: 07-query-design
description: Write meaningful SQL Server queries for the completed design.
compatibility: opencode
---

# Step 7 - Query Design

## Objective
Create useful SQL queries that answer business questions from the completed database design.

## Team Idea Workflow
- When the user provides a list of candidate ideas from multiple team members, treat them as the source pool for this step.
- Do not rank the ideas as "best" or discard them early; keep all provided ideas in the reasoning pool.
- The final output still must contain exactly 5 queries, so combine related ideas into broader queries when needed rather than selecting only the "best" 5.
- If two ideas overlap heavily, merge them into one stronger business question instead of producing two similar queries.
- Prefer a balanced set of queries across campus-space themes such as booking behavior, approval workflow, maintenance, facility assets, and utilization analysis.
- Preserve the original intent of each idea, but rewrite it into a precise business question that can be answered using only the Step 5 schema.
- Do not invent tables, columns, statuses, or relationships that are not present in `outputs/05-db-definition-G11.sql`.
- If an idea cannot be expressed safely with the available schema, replace it with the closest valid idea from the pool.
- Make sure each final query has a clear target user and a distinct analytical purpose.

## Team Idea Pool
- Nguyen Anh Dung
  - Title: Spaces most heavily used
    - Business Question: Which spaces are most heavily used, and what are their booking count, total hours booked, average participants, and current status?
    - Target User: Facility Manager, Department Administrator
    - Utility Explanation: Helps identify underutilized spaces for reallocation and overutilized spaces requiring maintenance scheduling.
  - Title: Trackable physical assets inventory
    - Business Question: What are all trackable physical assets, their current location, status, and catalog category?
    - Target User: Facility Staff, Facility Manager
    - Utility Explanation: Provides a complete inventory of high-value assets with location and maintenance context for auditing and tracking.
  - Title: Booking approval audit trail
    - Business Question: What is the approval status of all bookings, including who decided, when, and the reason if rejected?
    - Target User: Facility Staff, Facility Manager, Department Administrator
    - Utility Explanation: Provides a complete audit trail of all booking decisions for transparency and dispute resolution.
  - Title: Active maintenance impact on bookings
    - Business Question: Which spaces are currently under active maintenance, what problems are reported, and how does this affect upcoming bookings?
    - Target User: Facility Staff, Facility Manager
    - Utility Explanation: Helps prioritize maintenance tasks by showing which active issues are blocking current or upcoming bookings.
  - Title: User booking demand by role
    - Business Question: Which users by role book the most space, what purposes do they book for, and what is their approval success rate?
    - Target User: Department Administrator, Facility Manager
    - Utility Explanation: Reveals booking demand patterns by user role to inform policy decisions and detect unusual usage.
- Nguyen Van Le Bao
  - Title: Spaces with highest utilization and capacity efficiency
    - Business Question: Which spaces are most frequently booked for completed sessions, and what is their average participant fill rate compared to maximum capacity?
    - Target User: Department Administrator, Facility Manager
    - Utility Explanation: Helps identify high-demand rooms and aids in future space allocation or expansion planning by showing which room sizes are most needed.
  - Title: Users with highest no-show rates
    - Business Question: Which users frequently book spaces but fail to check in, resulting in a no-show status?
    - Target User: Department Administrator
    - Utility Explanation: Identifies users who waste campus resources, allowing administration to issue warnings or temporarily restrict booking privileges.
  - Title: Average maintenance resolution time by space type
    - Business Question: How long does it typically take to transition a maintenance record from reported to completed, categorized by space type?
    - Target User: Facility Manager
    - Utility Explanation: Evaluates the performance of the facility maintenance team and highlights which types of spaces suffer from prolonged downtimes.
  - Title: Equipment availability bottlenecks in high-demand areas
    - Business Question: Which spaces experience a high volume of bookings but possess the lowest quantity of trackable facility assets?
    - Target User: Facility Manager, Department Administrator
    - Utility Explanation: Highlights potential bottlenecks where high-demand rooms are under-equipped, guiding budget allocation for new equipment purchases.
  - Title: Peak booking hours and purpose types
    - Business Question: During which hours of the day does the campus experience the highest volume of approved bookings, and what are the primary purpose types during those peak times?
    - Target User: Department Administrator, Facility Staff
    - Utility Explanation: Provides insight into campus traffic patterns, helping optimize academic scheduling and facility staff shift planning during rush hours.
- Tran Dang Le Huy
  - Title: Suitable spaces for an event
    - Business Question: Which spaces satisfy required capacity, required facility quantity, and are conflict-free during a requested time window?
    - Target User: Student, Lecturer, Department Administrator
    - Utility Explanation: Replaces manual room screening by checking all constraints in one query.
  - Title: Department with highest classroom usage
    - Business Question: Which department uses classrooms the most in a selected time range?
    - Target User: Facility Manager, Department Administrator
    - Utility Explanation: Supports fair allocation and long-term capacity planning.
  - Title: No-show rate per user
    - Business Question: Which users have high no-show rates, especially after a minimum number of bookings?
    - Target User: Facility Manager, Department Administrator
    - Utility Explanation: Detects repeated misuse and supports policy enforcement.
  - Title: Approval turnaround time by approver
    - Business Question: How quickly does each staff member process booking approvals or rejections?
    - Target User: Facility Manager
    - Utility Explanation: Measures approval SLA and helps rebalance workload.
  - Title: Trackable asset types linked to maintenance issues
    - Business Question: Which trackable equipment types appear most often in spaces where related maintenance issues occur?
    - Target User: Facility Manager, Facility Staff
    - Utility Explanation: Flags equipment categories with high failure signals for inspection or replacement planning.
  - Title: Upcoming high-occupancy alerts
    - Business Question: Which upcoming bookings are at high occupancy, for example at least 85 percent of capacity, and need proactive preparation?
    - Target User: Facility Staff, Facility Manager
    - Utility Explanation: Creates early warning for crowd-heavy sessions so teams can prepare chairs, equipment, and support.
- Tran Thien Phuc
  - Title: Upcoming bookings for a user
    - Business Question: List all upcoming bookings for a specific user.
    - Target User: Student, Lecturer
    - Utility Explanation: Helps users track their upcoming room reservations.
  - Title: Spaces not booked in the last month
    - Business Question: Identify spaces that have not been booked in the last month.
    - Target User: Facility Manager
    - Utility Explanation: Identifies underutilized spaces for potential repurposing.
  - Title: Facility distribution per space
    - Business Question: Show facility distribution per space.
    - Target User: Facility Staff
    - Utility Explanation: Quickly inventory what facilities are in which space.
  - Title: Total booking duration per space
    - Business Question: Calculate the total booking duration in hours per space.
    - Target User: Facility Manager
    - Utility Explanation: Understands space utilization intensity.
  - Title: Spaces under maintenance and responsible staff
    - Business Question: Identify spaces under maintenance and the responsible staff.
    - Target User: Facility Manager
    - Utility Explanation: Tracks ongoing maintenance tasks.

## Input Context
- Read `outputs/06-sample-data-G11.sql`.
- Use the final schema from `outputs/05-db-definition-G11.sql`.
- Preserve the business scope and hybrid-pattern assumptions from `../db-design-pipeline/SKILL.md`.

## Instructions & Constraints
- **Save to:** `outputs/07-query-design-G11.sql`
- **Database Context (CRITICAL):** The file MUST start with the following lines to ensure the queries execute against the correct database:
  ```sql
  USE [CampusSpaceManagement];
  GO
  ```
- **Task:** Design and write exactly 5 meaningful Microsoft SQL Server queries.

- **Metadata Requirement:** For each of the 5 queries, you MUST use SQL comments (`--`) above the query to document:
  1. The business question being answered.
  2. The target user(s) who would use the query.
  3. A short explanation of why the query is useful.
  4. The executable `SELECT` statement.

- **Query Complexity & Quality:**
  - Ensure the queries demonstrate a solid understanding of relational databases. Do NOT write basic `SELECT *` queries.
  - Across the 5 queries, incorporate a variety of intermediate/advanced SQL features. Examples include: multi-table `JOIN`s, Aggregations (`COUNT`, `SUM` with `GROUP BY`), `HAVING` clauses, Subqueries, or CTEs (Common Table Expressions).

- **STRICT CONSISTENCY RULE:** - You MUST ONLY use table names, column names, and data types exactly as they are defined in `outputs/05-db-definition-G11.sql`. Do not hallucinate columns or relationships that do not exist in the DDL.

- **SELF-REVIEW:**
  1. Are there exactly 5 distinct queries?
  2. Does every query include the requested metadata as SQL comments?
  3. Do all referenced tables and columns perfectly match the Step 5 DDL?

- **CRITICAL FORMATTING CONSTRAINTS:**
  1. Do NOT wrap the SQL code in markdown fences (e.g., do NOT write ````sql` at the top and ````` at the bottom). Output the raw SQL text directly.
  2. Do NOT output any conversational text, pleasantries, or explanations outside of the SQL comments. The entire output file must be a valid, executable `.sql` script.