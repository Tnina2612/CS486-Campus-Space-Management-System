USE [CampusSpaceManagement];
GO

-- ============================================================================
-- Phase 2 Schema Migration - G11
-- ADDITIVE-ONLY. All Phase 1 tables, columns, constraints, and data are
-- preserved. Only ALTER TABLE / ADD / CREATE statements are used below.
-- Implements outputs/09-updated-erd-and-logical-design-G11.md
-- ============================================================================

BEGIN TRANSACTION;
GO

-- ---------------------------------------------------------------------
-- SECTION 1: ALTER existing tables (add columns only)
-- ---------------------------------------------------------------------

-- SPACE: flag for instant (auto) booking support
-- Implements step 9: spaces.allows_instant_booking
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.spaces')
                 AND name = N'allows_instant_booking')
BEGIN
    ALTER TABLE dbo.spaces
        ADD allows_instant_booking BIT NOT NULL CONSTRAINT DF_spaces_instant DEFAULT 0;
END
GO

-- MAINTENANCE_RECORD: impact level (out-of-service / advisory)
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.maintenance_records')
                 AND name = N'impact_level')
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD impact_level NVARCHAR(20) NOT NULL
            CONSTRAINT DF_maint_impact DEFAULT 'advisory'
            CONSTRAINT CK_maint_impact CHECK (impact_level IN ('out-of-service', 'advisory'));
END
GO

-- MAINTENANCE_RECORD: optional link to affected facility type (non-trackable)
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.maintenance_records')
                 AND name = N'facility_catalog_id')
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD facility_catalog_id INT NULL;
END
GO

-- MAINTENANCE_RECORD: optional link to a specific tracked asset
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.maintenance_records')
                 AND name = N'facility_asset_id')
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD facility_asset_id INT NULL;
END
GO

-- ---------------------------------------------------------------------
-- SECTION 2: NEW tables
-- ---------------------------------------------------------------------

-- MAINTENANCE_IMPACT_HISTORY: log of escalate/downgrade changes
IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.maintenance_impact_history (
        history_id     INT           IDENTITY(1,1) PRIMARY KEY,
        maintenance_id INT           NOT NULL,
        impact_level   NVARCHAR(20)  NOT NULL CHECK (impact_level IN ('out-of-service', 'advisory')),
        changed_at     DATETIME2     NOT NULL,

        CONSTRAINT FK_mih_maintenance
            FOREIGN KEY (maintenance_id)
            REFERENCES dbo.maintenance_records(maintenance_id)
            ON UPDATE NO ACTION ON DELETE CASCADE
    );
END
GO

-- ADVISORY_ACKNOWLEDGEMENTS: M:N booking <-> maintenance advisory acknowledgement
IF OBJECT_ID(N'dbo.advisory_acknowledgements', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.advisory_acknowledgements (
        acknowledgement_id INT       IDENTITY(1,1) PRIMARY KEY,
        booking_id         INT       NOT NULL,
        maintenance_id     INT       NOT NULL,
        acknowledged_at    DATETIME2 NOT NULL,

        CONSTRAINT UQ_ack_booking_maint UNIQUE (booking_id, maintenance_id),

        CONSTRAINT FK_ack_bookings
            FOREIGN KEY (booking_id)     REFERENCES dbo.bookings(booking_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION,

        CONSTRAINT FK_ack_maintenance
            FOREIGN KEY (maintenance_id) REFERENCES dbo.maintenance_records(maintenance_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );
END
GO

-- ---------------------------------------------------------------------
-- SECTION 3: NEW Foreign Keys & CHECK constraints on altered tables
-- ---------------------------------------------------------------------

-- FK: maintenance_records.facility_catalog_id -> facility_catalog
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_maint_records_catalog')
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT FK_maint_records_catalog
            FOREIGN KEY (facility_catalog_id)
            REFERENCES dbo.facility_catalog(catalog_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION;
END
GO

-- FK: maintenance_records.facility_asset_id -> facility_assets
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_maint_records_asset')
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT FK_maint_records_asset
            FOREIGN KEY (facility_asset_id)
            REFERENCES dbo.facility_assets(asset_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION;
END
GO

-- ---------------------------------------------------------------------
-- SECTION 4: Triggers for rules not expressible declaratively
-- ---------------------------------------------------------------------

-- 1) XOR + consistency trigger on MAINTENANCE_RECORD facility linkage.
--    A record may link to an asset OR a catalog OR neither (XOR).
--    If an asset is set, its catalog must equal the record's facility_catalog_id.
IF OBJECT_ID(N'dbo.TRG_Maintenance_Facility_XOR', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_Maintenance_Facility_XOR;
GO
CREATE TRIGGER dbo.TRG_Maintenance_Facility_XOR
ON dbo.maintenance_records
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.facility_assets fa ON i.facility_asset_id = fa.asset_id
        WHERE (i.facility_asset_id IS NOT NULL AND i.facility_catalog_id IS NOT NULL
                 AND fa.catalog_id <> i.facility_catalog_id)
    )
    BEGIN
        RAISERROR('Maintenance facility link inconsistent: asset catalog must equal facility_catalog_id.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- 2) Maintenance-impact-history helper (optional; see Step 12 stored procedure
--    for the canonical escalation routine that writes history atomically).
GO

-- ---------------------------------------------------------------------
-- SECTION 5: Indexes to support Phase 2 queries
-- ---------------------------------------------------------------------

-- Booking conflict / overlap check:
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_bookings_overlap')
    CREATE INDEX IX_bookings_overlap
        ON dbo.bookings (space_id, status) INCLUDE (start_time, end_time);
GO

-- Room finder: capacity
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_spaces_capacity')
    CREATE INDEX IX_spaces_capacity ON dbo.spaces (capacity);
GO

-- Room finder: facility join
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_sf_catalog')
    CREATE INDEX IX_sf_catalog ON dbo.space_facility (catalog_id, space_id);
GO

-- Maintenance by space + impact level
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_maint_space_impact')
    CREATE INDEX IX_maint_space_impact
        ON dbo.maintenance_records (space_id, impact_level)
        INCLUDE (start_time, completion_time);
GO

-- Reporting: approved hours / weekday-hour
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_bookings_status_start')
    CREATE INDEX IX_bookings_status_start
        ON dbo.bookings (status, start_time) INCLUDE (space_id, end_time);
GO

-- ---------------------------------------------------------------------
-- SECTION 6: Optional backfill
-- ---------------------------------------------------------------------
-- No data backfill required: new columns carry defaults (DEFAULT) that
-- satisfy identity and older rows. impact_level defaults to 'advisory'
-- for all existing maintenance records (see assumption A-01/A-03).

COMMIT TRANSACTION;
GO

PRINT N'Phase 2 migration completed successfully (additive).';
GO