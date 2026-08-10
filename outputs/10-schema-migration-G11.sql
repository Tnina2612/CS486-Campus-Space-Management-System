/* ============================================================================
   FILE    : outputs/10-schema-migration-G11.sql
   PURPOSE : Phase 2 additive schema migration for the Campus Space Management
             System (G11). Applies ONLY ALTER/ADD/CREATE statements on top of
             the Phase 1 baseline (outputs/05-db-definition-G11.sql). No Phase 1
             table is dropped or recreated; existing data is preserved.

   DESIGN TRACEABILITY (outputs/09-updated-erd-and-logical-design-G11.md):
     - spaces.auto_booking_enabled                        (RC-06)
     - spaces.current_status domain change                (RC-01)
     - maintenance_records.impact_level                   (RC-01, RC-03)
     - bookings.advisory_acknowledged / advisory_snapshot (RC-01)
     - approvals.staff_id nullable                        (RC-06)
     - space_facility surrogate key + facility_assets     (RC-08)
     - incident_reports / report_consolidations           (RC-04, RC-08)
     - advisory_acknowledgements                          (RC-01)

   RUN    : sqlcmd -S localhost -E -C -d CampusSpaceManagement -i outputs/10-schema-migration-G11.sql
   ============================================================================ */

USE [CampusSpaceManagement];
GO

SET NOCOUNT ON;
GO

/* ============================================================================
   SECTION 1 - ADDITIVE DATA BACKFILL (done FIRST so later constraints hold)
   ============================================================================ */

/* --- 1a) maintenance_records.impact_level -----------------------------------
   Add the column as NULL, backfill legacy rows to 'advisory' (default triage
   level; escalate only when triage decides), then tighten to NOT NULL with a
   DEFAULT. Reference: 09 Step 2 MAINTENANCE_RECORD. */
IF COL_LENGTH('dbo.maintenance_records', 'impact_level') IS NULL
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD impact_level NVARCHAR(20) NULL;
END
GO

UPDATE dbo.maintenance_records
   SET impact_level = 'advisory'
 WHERE impact_level IS NULL OR LTRIM(RTRIM(impact_level)) = '';
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints dc
               WHERE dc.parent_object_id = OBJECT_ID('dbo.maintenance_records')
                 AND dc.name = 'DF_maintenance_records_impact_level')
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT DF_maintenance_records_impact_level
        DEFAULT ('advisory') FOR impact_level;
END
GO

ALTER TABLE dbo.maintenance_records
    ALTER COLUMN impact_level NVARCHAR(20) NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = 'CK_maintenance_records_impact_level'
                 AND parent_object_id = OBJECT_ID('dbo.maintenance_records'))
BEGIN
    ALTER TABLE dbo.maintenance_records
        ADD CONSTRAINT CK_maintenance_records_impact_level
        CHECK (impact_level IN ('advisory', 'out-of-service'));
END
GO

/* --- 1b) spaces.current_status data remap -----------------------------------
   Any legacy row still flagged 'Under Maintenance' is remapped to a valid
   operational status AND an out-of-service MAINTENANCE_RECORD is created (if
   none exists) so booking-block behavior is preserved through the maintenance
   layer instead of the status domain. Reference: 09 BR-02 refined, RC-01. */
INSERT INTO dbo.maintenance_records
    (space_id, reporter_id, assigned_staff_id, problem_description,
     start_time, completion_time, status, result_note, impact_level)
SELECT
    s.space_id,
    (SELECT TOP 1 user_id FROM dbo.users WHERE role = 'Facility Manager'),
    (SELECT TOP 1 user_id FROM dbo.users WHERE role = 'Facility Staff'),
    'Legacy space status migration: was ''Under Maintenance''; converted to an out-of-service maintenance record to preserve booking-block behavior.',
    DATEADD(DAY, -1, SYSDATETIME()),
    NULL,
    'In Progress',
    NULL,
    'out-of-service'
FROM dbo.spaces s
WHERE s.current_status = 'Under Maintenance'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.maintenance_records mr
      WHERE mr.space_id = s.space_id
        AND mr.impact_level = 'out-of-service'
  );
GO

-- Remap legacy status domain value to a valid operational status.
UPDATE dbo.spaces
   SET current_status = 'Temporarily Closed'
 WHERE current_status = 'Under Maintenance';
GO

/* ============================================================================
   SECTION 2 - NEW COLUMNS ON EXISTING TABLES
   ============================================================================ */

/* --- spaces.auto_booking_enabled (RC-06) ------------------------------------
   BIT NOT NULL DEFAULT (0): auto-booking disabled by default for existing and
   new spaces unless explicitly enabled. */
IF COL_LENGTH('dbo.spaces', 'auto_booking_enabled') IS NULL
BEGIN
    ALTER TABLE dbo.spaces
        ADD auto_booking_enabled BIT NOT NULL
        CONSTRAINT DF_spaces_auto_booking_enabled DEFAULT (0);
END
GO

/* --- bookings advisory fields (RC-01) ---------------------------------------
   Flag that the requester acknowledged active advisories at booking time plus
   a snapshot of the advisories that were shown. */
IF COL_LENGTH('dbo.bookings', 'advisory_acknowledged') IS NULL
BEGIN
    ALTER TABLE dbo.bookings
        ADD advisory_acknowledged BIT NOT NULL
        CONSTRAINT DF_bookings_advisory_acknowledged DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.bookings', 'advisory_snapshot') IS NULL
BEGIN
    ALTER TABLE dbo.bookings
        ADD advisory_snapshot NVARCHAR(MAX) NULL;
END
GO

/* ============================================================================
   SECTION 3 - FACILITY-INSTANCE REPORT TARGET NORMALIZATION (RC-08)
   (done before creating incident_reports, which references the new key)
   ============================================================================ */

/* --- 3a) space_facility: introduce surrogate key space_facility_id ---------
   1) Add the identity surrogate column.
   2) Drop the old composite PK (space_id, catalog_id).
   3) Promote space_facility_id to the new PK.
   4) Keep (space_id, catalog_id) as a UNIQUE natural key. */
IF COL_LENGTH('dbo.space_facility', 'space_facility_id') IS NULL
BEGIN
    ALTER TABLE dbo.space_facility
        ADD space_facility_id INT IDENTITY(1,1) NOT NULL;
END
GO

IF EXISTS (SELECT 1 FROM sys.key_constraints
           WHERE name = 'PK_space_facility'
             AND parent_object_id = OBJECT_ID('dbo.space_facility'))
BEGIN
    ALTER TABLE dbo.space_facility
        DROP CONSTRAINT PK_space_facility;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints
               WHERE name = 'PK_space_facility_id'
                 AND parent_object_id = OBJECT_ID('dbo.space_facility'))
BEGIN
    ALTER TABLE dbo.space_facility
        ADD CONSTRAINT PK_space_facility_id PRIMARY KEY (space_facility_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints
               WHERE name = 'UQ_space_facility_space_catalog'
                 AND parent_object_id = OBJECT_ID('dbo.space_facility'))
BEGIN
    ALTER TABLE dbo.space_facility
        ADD CONSTRAINT UQ_space_facility_space_catalog UNIQUE (space_id, catalog_id);
END
GO

/* --- 3b) facility_assets: re-point to space_facility instance --------------
   1) Add nullable space_facility_id.
   2) Backfill by matching (space_id, catalog_id) to the corresponding
      space_facility row. If any row cannot be matched, fail loudly so the
      mismatch is visible (data-quality guard).
   3) Tighten to NOT NULL and add the FK. */
IF COL_LENGTH('dbo.facility_assets', 'space_facility_id') IS NULL
BEGIN
    ALTER TABLE dbo.facility_assets
        ADD space_facility_id INT NULL;
END
GO

/* --- Data-quality backfill -------------------------------------------------
   Phase 1 sample data contains facility_assets rows (e.g. PHONE-001-MTG for
   MTG-01 / Conference Phone) whose (space_id, catalog_id) pair has no matching
   SPACE_FACILITY mapping. Because assets must be re-pointed to a facility
   instance, the missing SPACE_FACILITY row is created additively (quantity = 1)
   so no asset is orphaned and no existing data is discarded. Documented as a
   data-quality fix required for the RC-08 normalization. */
INSERT INTO dbo.space_facility (space_id, catalog_id, quantity)
SELECT DISTINCT fa.space_id, fa.catalog_id, 1
  FROM dbo.facility_assets fa
  LEFT JOIN dbo.space_facility sf
    ON sf.space_id = fa.space_id
   AND sf.catalog_id = fa.catalog_id
 WHERE fa.space_facility_id IS NULL
   AND sf.space_facility_id IS NULL;
GO

IF EXISTS (
    SELECT 1 FROM dbo.facility_assets fa
    WHERE fa.space_facility_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM dbo.space_facility sf
          WHERE sf.space_id = fa.space_id AND sf.catalog_id = fa.catalog_id
      )
)
BEGIN
    RAISERROR('Data-quality issue: facility_assets rows exist without a matching space_facility (space_id, catalog_id) row. Migration aborted.', 16, 1);
    RETURN;
END
GO

UPDATE fa
   SET fa.space_facility_id = sf.space_facility_id
  FROM dbo.facility_assets fa
  INNER JOIN dbo.space_facility sf
     ON sf.space_id = fa.space_id
    AND sf.catalog_id = fa.catalog_id
 WHERE fa.space_facility_id IS NULL;
GO

ALTER TABLE dbo.facility_assets
    ALTER COLUMN space_facility_id INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
               WHERE name = 'FK_facility_assets_space_facility'
                 AND parent_object_id = OBJECT_ID('dbo.facility_assets'))
BEGIN
    ALTER TABLE dbo.facility_assets
        ADD CONSTRAINT FK_facility_assets_space_facility
        FOREIGN KEY (space_facility_id) REFERENCES dbo.space_facility(space_facility_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION;
END
GO

/* ============================================================================
   SECTION 4 - NEW TABLES
   ============================================================================ */

/* --- incident_reports (RC-04, RC-08) ---------------------------------------
   End-user report intake. Target hierarchy: room (space_id) -> facility type
   (space_facility_id) -> specific asset (asset_id). BR-14: asset_id requires a
   non-null space_facility_id and a valid asset-to-facility mapping. */
IF OBJECT_ID('dbo.incident_reports', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.incident_reports (
        report_id         INT           IDENTITY(1,1) PRIMARY KEY,
        user_id           INT           NOT NULL,
        space_id          INT           NOT NULL,
        space_facility_id INT           NULL,
        asset_id          INT           NULL,
        description       NVARCHAR(MAX) NOT NULL,
        reported_at       DATETIME2     NOT NULL DEFAULT (SYSDATETIME()),
        status            NVARCHAR(20)  NOT NULL DEFAULT ('Open'),
        CONSTRAINT CK_incident_reports_status
            CHECK (status IN ('Open', 'Consolidated', 'Closed')),
        CONSTRAINT CK_incident_reports_target_integrity
            CHECK (asset_id IS NULL OR space_facility_id IS NOT NULL),
        CONSTRAINT FK_incident_reports_users
            FOREIGN KEY (user_id) REFERENCES dbo.users(user_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT FK_incident_reports_spaces
            FOREIGN KEY (space_id) REFERENCES dbo.spaces(space_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT FK_incident_reports_space_facility
            FOREIGN KEY (space_facility_id) REFERENCES dbo.space_facility(space_facility_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );
END
GO

/* --- report_consolidations (RC-04) -----------------------------------------
   M:N between incident_reports and maintenance_records. Many reports map to
   ONE maintenance record (duplicate consolidation). maintenance_id is nullable
   while a report is filed but not yet triaged. */
IF OBJECT_ID('dbo.report_consolidations', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.report_consolidations (
        consolidation_id   INT       IDENTITY(1,1) PRIMARY KEY,
        incident_report_id INT       NOT NULL,
        maintenance_id     INT       NULL,
        consolidated_by    INT       NOT NULL,
        consolidated_at    DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_consolidations_incident UNIQUE (incident_report_id),
        CONSTRAINT FK_consolidations_incidents
            FOREIGN KEY (incident_report_id) REFERENCES dbo.incident_reports(report_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT FK_consolidations_maintenance
            FOREIGN KEY (maintenance_id) REFERENCES dbo.maintenance_records(maintenance_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        CONSTRAINT FK_consolidations_staff
            FOREIGN KEY (consolidated_by) REFERENCES dbo.users(user_id)
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );
END
GO

/* --- advisory_acknowledgements (RC-01) --------------------------------------
   Records that a requester was informed of (and acknowledged) each active
   advisory maintenance record at booking time. */
IF OBJECT_ID('dbo.advisory_acknowledgements', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.advisory_acknowledgements (
        acknowledgement_id INT       IDENTITY(1,1) PRIMARY KEY,
        booking_id         INT       NOT NULL,
        maintenance_id     INT       NOT NULL,
        acknowledged_by    INT       NOT NULL,
        acknowledged_at    DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_acknowledgements_booking_maint
            UNIQUE (booking_id, maintenance_id),
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

/* ============================================================================
   SECTION 5 - BR-14 ENFORCEMENT (asset must belong to selected facility)
   ============================================================================ */

/* Unique index on facility_assets(space_facility_id, asset_id) so it can be
   the target of a composite FK from incident_reports. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UQ_facility_assets_instance_asset'
                 AND object_id = OBJECT_ID('dbo.facility_assets'))
BEGIN
    CREATE UNIQUE INDEX UQ_facility_assets_instance_asset
        ON dbo.facility_assets (space_facility_id, asset_id);
END
GO

/* Composite FK: if an incident report names an asset, the (space_facility_id,
   asset_id) pair must exist in facility_assets, i.e. the asset belongs to the
   selected facility instance. */
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
               WHERE name = 'FK_incident_reports_asset_instance'
                 AND parent_object_id = OBJECT_ID('dbo.incident_reports'))
BEGIN
    ALTER TABLE dbo.incident_reports
        ADD CONSTRAINT FK_incident_reports_asset_instance
        FOREIGN KEY (space_facility_id, asset_id)
        REFERENCES dbo.facility_assets (space_facility_id, asset_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION;
END
GO

/* ============================================================================
   SECTION 6 - approvals.staff_id becomes nullable (RC-06)
   ============================================================================
   Automatic approvals store NULL (no staff performed the approval). The FK to
   users and all existing rows are preserved. */
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.approvals')
             AND name = 'staff_id'
             AND is_nullable = 0)
BEGIN
    ALTER TABLE dbo.approvals ALTER COLUMN staff_id INT NULL;
END
GO

/* ============================================================================
   SECTION 7 - spaces.current_status CHECK domain update (RC-01)
   ============================================================================
   Drop the old CHECK that allowed 'Under Maintenance' (anonymous in Phase 1)
   and re-add a named CHECK with the reduced domain. Data was remapped in 1b. */
DECLARE @chkName sysname;
SELECT @chkName = cc.name
  FROM sys.check_constraints cc
  JOIN sys.columns col
    ON cc.parent_object_id = col.object_id
   AND cc.parent_column_id = col.column_id
 WHERE cc.parent_object_id = OBJECT_ID('dbo.spaces')
   AND col.name = 'current_status'
   AND cc.definition LIKE '%Under Maintenance%';

IF @chkName IS NOT NULL
BEGIN
    DECLARE @sqlDropCheck NVARCHAR(MAX) =
        N'ALTER TABLE dbo.spaces DROP CONSTRAINT ' + QUOTENAME(@chkName);
    EXEC(@sqlDropCheck);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = 'CK_spaces_current_status'
                 AND parent_object_id = OBJECT_ID('dbo.spaces'))
BEGIN
    ALTER TABLE dbo.spaces
        ADD CONSTRAINT CK_spaces_current_status
        CHECK (current_status IN ('Available', 'In Use', 'Temporarily Closed', 'Retired'));
END
GO

/* ============================================================================
   SECTION 8 - INDEXES FOR NEW QUERY PATTERNS
   ============================================================================ */

-- Availability + escalation checks read bookings by (space_id, start, end).
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_bookings_space_time'
                 AND object_id = OBJECT_ID('dbo.bookings'))
BEGIN
    CREATE INDEX IX_bookings_space_time
        ON dbo.bookings (space_id, start_time, end_time)
        INCLUDE (status);
END
GO

-- Semester reporting + weekday/hour aggregation scan bookings by (status, time).
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_bookings_status_time'
                 AND object_id = OBJECT_ID('dbo.bookings'))
BEGIN
    CREATE INDEX IX_bookings_status_time
        ON dbo.bookings (status, start_time, end_time)
        INCLUDE (space_id);
END
GO

-- Maintenance blocking reads by (space_id, start_time, completion_time, impact).
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_maintenance_records_space_time'
                 AND object_id = OBJECT_ID('dbo.maintenance_records'))
BEGIN
    CREATE INDEX IX_maintenance_records_space_time
        ON dbo.maintenance_records (space_id, start_time, completion_time)
        INCLUDE (impact_level, status);
END
GO

-- Escalation report + staff views scan open reports by space/status.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_incident_reports_space_status'
                 AND object_id = OBJECT_ID('dbo.incident_reports'))
BEGIN
    CREATE INDEX IX_incident_reports_space_status
        ON dbo.incident_reports (space_id, status)
        INCLUDE (user_id, reported_at);
END
GO

-- Consolidation navigation.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_consolidations_maintenance'
                 AND object_id = OBJECT_ID('dbo.report_consolidations'))
BEGIN
    CREATE INDEX IX_consolidations_maintenance
        ON dbo.report_consolidations (maintenance_id)
        INCLUDE (incident_report_id, consolidated_at);
END
GO

-- Advisory acknowledgement lookup by booking and maintenance.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_advisory_ack_booking'
                 AND object_id = OBJECT_ID('dbo.advisory_acknowledgements'))
BEGIN
    CREATE INDEX IX_advisory_ack_booking
        ON dbo.advisory_acknowledgements (booking_id)
        INCLUDE (maintenance_id, acknowledged_at);
END
GO

-- Capacity / facility search (reporting need).
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_spaces_capacity_status'
                 AND object_id = OBJECT_ID('dbo.spaces'))
BEGIN
    CREATE INDEX IX_spaces_capacity_status
        ON dbo.spaces (capacity, current_status)
        INCLUDE (space_type, space_name);
END
GO

/* ============================================================================
   SECTION 9 - VERIFICATION SNAPSHOT
   ============================================================================ */

PRINT N'Migration applied. Verification:';

DECLARE @staffNullable INT;
SELECT @staffNullable = is_nullable
  FROM sys.columns
 WHERE object_id = OBJECT_ID('dbo.approvals')
   AND name = 'staff_id';

PRINT N'  spaces.auto_booking_enabled          = ' + CAST(ISNULL(COL_LENGTH('dbo.spaces','auto_booking_enabled'),0) AS NVARCHAR(10));
PRINT N'  maintenance_records.impact_level     = ' + CAST(ISNULL(COL_LENGTH('dbo.maintenance_records','impact_level'),0) AS NVARCHAR(10));
PRINT N'  approvals.staff_id nullable          = ' + CAST(ISNULL(@staffNullable,-1) AS NVARCHAR(10));
PRINT N'  space_facility.space_facility_id     = ' + CAST(ISNULL(COL_LENGTH('dbo.space_facility','space_facility_id'),0) AS NVARCHAR(10));
PRINT N'  facility_assets.space_facility_id    = ' + CAST(ISNULL(COL_LENGTH('dbo.facility_assets','space_facility_id'),0) AS NVARCHAR(10));
PRINT N'  incident_reports table               = ' + CAST(CASE WHEN OBJECT_ID('dbo.incident_reports','U') IS NOT NULL THEN 1 ELSE 0 END AS NVARCHAR(10));
PRINT N'  report_consolidations table          = ' + CAST(CASE WHEN OBJECT_ID('dbo.report_consolidations','U') IS NOT NULL THEN 1 ELSE 0 END AS NVARCHAR(10));
PRINT N'  advisory_acknowledgements table      = ' + CAST(CASE WHEN OBJECT_ID('dbo.advisory_acknowledgements','U') IS NOT NULL THEN 1 ELSE 0 END AS NVARCHAR(10));
GO
