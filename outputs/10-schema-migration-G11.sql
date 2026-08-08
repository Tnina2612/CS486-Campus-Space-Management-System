/*
================================================================================
  10-schema-migration-G11.sql
  Campus Space Management System - Phase 2 Additive Schema Migration
  Group: G11
================================================================================
  POLICY: ADDITIVE-ONLY.
  This script extends the Phase 1 database (CampusSpaceManagement).
  - No Phase 1 table is dropped, recreated, or structurally rewritten.
  - Existing data is preserved. Only backfill UPDATEs for NEW columns are issued.
  - All changes implement the Phase 2 design in
    outputs/09-updated-erd-and-logical-design-G11.md
    with rationale from outputs/08-requirement-change-analysis-G11.md.

  Implements:
    RC-01  maintenance_records.impact_level        (advisory / out-of-service)
    RC-03  bookings.advisories_acknowledged,
           bookings.advisories_snapshot
    RC-05  spaces.instant_bookable                 (instant-booking eligibility)
    RC-06  index support for concurrent overlap checks (BR-01)
================================================================================
*/

USE [CampusSpaceManagement];
GO

BEGIN TRANSACTION;
GO

/* ----------------------------------------------------------------------------
   SECTION 3 - ALTER TABLE / NEW COLUMNS
---------------------------------------------------------------------------- */

-- RC-03: Bookings acknowledge that the requester was informed of active
--       advisory maintenance on the space at booking time.
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.bookings')
      AND name = N'advisories_acknowledged'
)
BEGIN
    ALTER TABLE dbo.bookings
        ADD advisories_acknowledged BIT NOT NULL
            CONSTRAINT DF_bookings_advisories_acknowledged DEFAULT (0);
END
GO

-- RC-03: Snapshot of the advisory maintenance descriptions shown to the
--       requester at booking time (audit trail of what was communicated).
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.bookings')
      AND name = N'advisories_snapshot'
)
BEGIN
    ALTER TABLE dbo.bookings
        ADD advisories_snapshot NVARCHAR(MAX) NULL;
END
GO

-- RC-01: Maintenance impact level.
--       'out-of-service' = space cannot be booked (Phase 1 behaviour).
--       'advisory'       = space bookable but requester must be notified.
--       Default 'out-of-service' preserves Phase 1 blocking semantics for
--       pre-existing records (see Section 7 backfill).
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.maintenance_records')
      AND name = N'impact_level'
)
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD impact_level NVARCHAR(20) NOT NULL
            CONSTRAINT DF_maintenance_records_impact_level
            DEFAULT ('out-of-service');
END
GO

/* ----------------------------------------------------------------------------
   SECTION 4 - NEW CONSTRAINTS
---------------------------------------------------------------------------- */

-- RC-01: Exact enumeration for impact_level.
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.maintenance_records')
      AND name = N'CK_maintenance_records_impact_level'
)
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT CK_maintenance_records_impact_level
        CHECK (impact_level IN ('out-of-service', 'advisory'));
END
GO

-- RC-05: Space eligible for the instant auto-approval path. Default 0 (off)
--       so existing spaces are not silently made instant-bookable.
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.spaces')
      AND name = N'instant_bookable'
)
BEGIN
    ALTER TABLE dbo.spaces
        ADD instant_bookable BIT NOT NULL
            CONSTRAINT DF_spaces_instant_bookable DEFAULT (0);
END
GO

/* ----------------------------------------------------------------------------
   SECTION 5 - INDEXES
   Support the concurrent overlap check (BR-01 / RC-06) and the new
   maintenance-availability checks (BR-02 / RC-01).
---------------------------------------------------------------------------- */

-- Overlap check index: finding approved bookings on a space that intersect a
-- proposed interval. Also enables the serializable range-lock strategy used by
-- the concurrency implementation (outputs/12-concurrency-implementation-G11.sql).
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.bookings')
      AND name = N'IX_bookings_space_time'
)
BEGIN
    CREATE INDEX IX_bookings_space_time
        ON dbo.bookings (space_id, start_time, end_time)
        INCLUDE (status);
END
GO

-- Status-led queries (reporting + escalation impact checks) on bookings.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.bookings')
      AND name = N'IX_bookings_status_time'
)
BEGIN
    CREATE INDEX IX_bookings_status_time
        ON dbo.bookings (status, start_time, end_time)
        INCLUDE (space_id);
END
GO

-- Availability check index: active maintenance records per space with impact
-- level, for both the booking-time advisory check and escalation queries.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.maintenance_records')
      AND name = N'IX_maintenance_records_space_time'
)
BEGIN
    CREATE INDEX IX_maintenance_records_space_time
        ON dbo.maintenance_records (space_id, start_time, completion_time)
        INCLUDE (impact_level, status);
END
GO

-- Room-finder support index (RC-09 / report Q3 in 16): capacity filter plus
-- status filter for the "available spaces" search.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.spaces')
      AND name = N'IX_spaces_capacity_status'
)
BEGIN
    CREATE INDEX IX_spaces_capacity_status
        ON dbo.spaces (capacity)
        INCLUDE (current_status, space_type, space_name);
END
GO

/* ----------------------------------------------------------------------------
   SECTION 7 - DATA BACKFILL (NEW COLUMNS ONLY)
   - maintenance_records.impact_level: existing records defaulted to
     'out-of-service' by the column DEFAULT, matching the Phase 1 rule that
     any maintenance blocked booking. Issued explicitly for clarity.
   - bookings.advisories_acknowledged: existing bookings defaulted to 0.
   - bookings.advisories_snapshot: NULL (no pre-recorded advisory context).
   No existing data is modified or deleted.
---------------------------------------------------------------------------- */

UPDATE dbo.maintenance_records
SET impact_level = 'out-of-service'
WHERE impact_level IS NULL;  -- defensive; column is NOT NULL

UPDATE dbo.bookings
SET advisories_acknowledged = 0
WHERE advisories_acknowledged IS NULL;  -- defensive; column is NOT NULL

-- RC-05: existing spaces defaulted to not instant-bookable (0) by the DEFAULT.

GO

COMMIT TRANSACTION;
GO

PRINT 'Phase 2 additive schema migration completed successfully.';
GO
