/*
===============================================================================
  10-schema-migration-G11.sql
  Campus Space Management System - Phase 2 Additive Schema Migration
  Group: G11
===============================================================================
  POLICY: ADDITIVE-ONLY.
  This script extends the Phase 1 database (CampusSpaceManagement).
  - No Phase 1 table is dropped, recreated, or structurally rewritten.
  - Existing data is preserved. Only backfill UPDATEs for NEW columns are issued.
  - All changes implement the Phase 2 design in
    outputs/09-updated-erd-and-logical-design-G11.md
    with rationale from outputs/08-requirement-change-analysis-G11.md.
  - Every statement is guarded with IF NOT EXISTS / OBJECT_ID checks so the
    script is IDEMPOTENT and safe to re-run against an already-partially-migrated
    database.

  Implements:
    RC-01  maintenance_records.impact_level        (advisory / out-of-service)
    RC-03  bookings.advisory_acknowledged,
           bookings.advisory_snapshot
    RC-03  advisory_acknowledgements (NEW table)
    RC-05  spaces.AutoBookingEnabled               (automatic-approval gate)
    RC-05a approvals.staff_id NOT NULL -> NULL      (automatic approvals)
    RC-06  index support for concurrent overlap checks (BR-01)
===============================================================================
*/

USE [CampusSpaceManagement];
GO

BEGIN TRANSACTION;
GO

/* ----------------------------------------------------------------------------
   SECTION 2 - NEW TABLES
--------------------------------------------------------------------------- */

-- RC-03 / BR-P2-01: per-booking acknowledgement of a specific advisory
-- maintenance record. UNIQUE (booking_id, maintenance_id) enforces that each
-- advisory is acknowledged at most once per booking.
IF OBJECT_ID(N'dbo.advisory_acknowledgements', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.advisory_acknowledgements (
        acknowledgement_id INT           IDENTITY(1,1) PRIMARY KEY,
        booking_id         INT           NOT NULL,
        maintenance_id     INT           NOT NULL,
        acknowledged_by    INT           NOT NULL,
        acknowledged_at    DATETIME2     NOT NULL DEFAULT (SYSDATETIME()),

        CONSTRAINT UQ_acknowledgements_booking_maint UNIQUE (booking_id, maintenance_id),

        CONSTRAINT FK_acknowledgements_bookings
            FOREIGN KEY (booking_id) REFERENCES dbo.bookings(booking_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT FK_acknowledgements_maintenance
            FOREIGN KEY (maintenance_id) REFERENCES dbo.maintenance_records(maintenance_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT FK_acknowledgements_users
            FOREIGN KEY (acknowledged_by) REFERENCES dbo.users(user_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );
END
GO

/* ----------------------------------------------------------------------------
   SECTION 3 - ALTER TABLE / NEW COLUMNS
--------------------------------------------------------------------------- */

-- RC-03: Bookings acknowledge that the requester was informed of active
--       advisory maintenance on the space at booking time.
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.bookings')
      AND name = N'advisory_acknowledged'
)
BEGIN
    ALTER TABLE dbo.bookings
        ADD advisory_acknowledged BIT NOT NULL
            CONSTRAINT DF_bookings_advisory_acknowledged DEFAULT (0);
END
GO

-- RC-03: Snapshot of the advisory maintenance descriptions shown to the
--       requester at booking time (audit trail of what was communicated).
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.bookings')
      AND name = N'advisory_snapshot'
)
BEGIN
    ALTER TABLE dbo.bookings
        ADD advisory_snapshot NVARCHAR(MAX) NULL;
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

-- RC-05 / A-08: Space eligible for the automatic approval path.
--       Default 0 (off) so existing spaces are not silently made auto-bookable.
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.spaces')
      AND name = N'AutoBookingEnabled'
)
BEGIN
    ALTER TABLE dbo.spaces
        ADD AutoBookingEnabled BIT NOT NULL
            CONSTRAINT DF_spaces_AutoBookingEnabled DEFAULT (0);
END
GO

-- RC-05a: APPROVAL.staff_id becomes NULLABLE so that automatic approvals can be
--       recorded with staff_id = NULL (no human actor performed the decision).
--       Manual/staff approvals continue to record the deciding staff member.
--       The FK to users(user_id) is preserved; existing approval rows are kept
--       intact (data-preserving relaxation of NOT NULL).
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.approvals')
      AND name = N'staff_id'
      AND is_nullable = 0
)
BEGIN
    ALTER TABLE dbo.approvals ALTER COLUMN staff_id INT NULL;
END
GO

/* ----------------------------------------------------------------------------
   SECTION 4 - NEW CONSTRAINTS & FOREIGN KEYS
--------------------------------------------------------------------------- */

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

-- RC-03: Boolean domain check for the acknowledgement flag.
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.bookings')
      AND name = N'CK_bookings_advisory_acknowledged'
)
BEGIN
    ALTER TABLE dbo.bookings
        ADD CONSTRAINT CK_bookings_advisory_acknowledged
        CHECK (advisory_acknowledged IN (0, 1));
END
GO

/* ----------------------------------------------------------------------------
   SECTION 5 - INDEXES
   Support the concurrent overlap check (BR-01 / RC-06) and the new
   maintenance-availability checks (BR-02 / RC-01).
--------------------------------------------------------------------------- */

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

-- Acknowledgement history lookup per booking / maintenance record.
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.advisory_acknowledgements')
      AND name = N'IX_advisory_ack_booking'
)
BEGIN
    CREATE INDEX IX_advisory_ack_booking
        ON dbo.advisory_acknowledgements (booking_id)
        INCLUDE (maintenance_id, acknowledged_by, acknowledged_at);
END
GO

/* ----------------------------------------------------------------------------
   SECTION 7 - DATA BACKFILL (NEW COLUMNS ONLY)
   - maintenance_records.impact_level: existing records defaulted to
     'out-of-service' by the column DEFAULT, matching the Phase 1 rule that
     any maintenance blocked booking. Issued explicitly for clarity.
   - bookings.advisory_acknowledged: existing bookings defaulted to 0.
   - bookings.advisory_snapshot: NULL (no pre-recorded advisory context).
   - spaces.AutoBookingEnabled: existing spaces defaulted to 0 (auto-approval
     is opt-in only; never silently enabled).
   - approvals.staff_id: no backfill needed. Existing rows keep their recorded
     staff member. NULL is reserved for future automatic approvals (RC-05a).
   No existing data is modified or deleted.
--------------------------------------------------------------------------- */

UPDATE dbo.maintenance_records
SET impact_level = 'out-of-service'
WHERE impact_level IS NULL;  -- defensive; column is NOT NULL

UPDATE dbo.bookings
SET advisory_acknowledged = 0
WHERE advisory_acknowledged IS NULL;  -- defensive; column is NOT NULL

UPDATE dbo.spaces
SET AutoBookingEnabled = 0
WHERE AutoBookingEnabled IS NULL;  -- defensive; column is NOT NULL

GO

COMMIT TRANSACTION;
GO

PRINT 'Phase 2 additive schema migration completed successfully.';
GO
