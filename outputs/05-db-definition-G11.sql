-- ============================================================
-- Campus Space Management System - Database Definition (DDL)
-- Group: G11
-- DBMS: Microsoft SQL Server
-- ============================================================

-- ============================================================
-- SECTION 1: Database Initialization & Drop Existing
-- ============================================================

USE master;
GO

IF DB_ID('CampusSpaceManagement') IS NOT NULL
BEGIN
    ALTER DATABASE [CampusSpaceManagement] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [CampusSpaceManagement];
END
GO

CREATE DATABASE [CampusSpaceManagement];
GO

USE [CampusSpaceManagement];
GO

-- ============================================================
-- SECTION 2: Drop Existing Tables (Reverse FK Dependency Order)
-- ============================================================

IF OBJECT_ID('dbo.facility_asset', 'U') IS NOT NULL DROP TABLE dbo.facility_asset;
IF OBJECT_ID('dbo.space_facility', 'U') IS NOT NULL DROP TABLE dbo.space_facility;
IF OBJECT_ID('dbo.facility_catalog', 'U') IS NOT NULL DROP TABLE dbo.facility_catalog;
IF OBJECT_ID('dbo.booking_session', 'U') IS NOT NULL DROP TABLE dbo.booking_session;
IF OBJECT_ID('dbo.booking_approval', 'U') IS NOT NULL DROP TABLE dbo.booking_approval;
IF OBJECT_ID('dbo.maintenance_record', 'U') IS NOT NULL DROP TABLE dbo.maintenance_record;
IF OBJECT_ID('dbo.booking', 'U') IS NOT NULL DROP TABLE dbo.booking;
IF OBJECT_ID('dbo.space', 'U') IS NOT NULL DROP TABLE dbo.space;
IF OBJECT_ID('dbo.[user]', 'U') IS NOT NULL DROP TABLE dbo.[user];
GO

-- ============================================================
-- SECTION 3: Table Definitions
-- ============================================================

-- 3.1  user
CREATE TABLE dbo.[user]
(
    user_id         INT           NOT NULL IDENTITY(1,1),
    full_name       NVARCHAR(100) NOT NULL,
    email           NVARCHAR(255) NOT NULL,
    phone           NVARCHAR(20)  NULL,
    role            NVARCHAR(20)  NOT NULL,
    department      NVARCHAR(100) NULL,
    account_status  NVARCHAR(20)  NOT NULL DEFAULT 'Active',

    CONSTRAINT PK_user PRIMARY KEY (user_id),
    CONSTRAINT UQ_user_email UNIQUE (email),
    CONSTRAINT CK_user_role CHECK (role IN (
        'Student', 'Lecturer', 'TA', 'FacilityStaff', 'DeptAdmin', 'FacilityManager'
    )),
    CONSTRAINT CK_user_account_status CHECK (account_status IN (
        'Active', 'Inactive', 'Suspended'
    ))
);
GO

-- 3.2  space
CREATE TABLE dbo.space
(
    space_code    NVARCHAR(20)  NOT NULL,
    space_name    NVARCHAR(100) NOT NULL,
    space_type    NVARCHAR(30)  NOT NULL,
    building      NVARCHAR(100) NOT NULL,
    floor         INT           NOT NULL,
    room_number   NVARCHAR(20)  NOT NULL,
    capacity      INT           NOT NULL,
    status        NVARCHAR(30)  NOT NULL DEFAULT 'Available',
    usage_policy  NVARCHAR(MAX) NULL,

    CONSTRAINT PK_space PRIMARY KEY (space_code),
    CONSTRAINT CK_space_capacity CHECK (capacity > 0),
    CONSTRAINT CK_space_type CHECK (space_type IN (
        'Auditorium', 'Classroom', 'ComputerLab', 'ProjectLab', 'MeetingRoom', 'Workspace'
    )),
    CONSTRAINT CK_space_status CHECK (status IN (
        'Available', 'InUse', 'UnderMaintenance', 'TemporarilyClosed', 'Retired'
    ))
);
GO

-- 3.3  facility_catalog
CREATE TABLE dbo.facility_catalog
(
    catalog_id   INT           NOT NULL IDENTITY(1,1),
    name         NVARCHAR(100) NOT NULL,
    description  NVARCHAR(MAX) NULL,
    is_trackable BIT           NOT NULL DEFAULT 0,

    CONSTRAINT PK_facility_catalog PRIMARY KEY (catalog_id)
);
GO

-- 3.4  space_facility
CREATE TABLE dbo.space_facility
(
    id          INT          NOT NULL IDENTITY(1,1),
    space_code  NVARCHAR(20) NOT NULL,
    catalog_id  INT          NOT NULL,
    quantity    INT          NOT NULL DEFAULT 1,

    CONSTRAINT PK_space_facility PRIMARY KEY (id),
    CONSTRAINT UQ_space_facility UNIQUE (space_code, catalog_id),
    CONSTRAINT CK_space_facility_quantity CHECK (quantity > 0)
);
GO

-- 3.5  facility_asset
CREATE TABLE dbo.facility_asset
(
    asset_id    INT          NOT NULL IDENTITY(1,1),
    catalog_id  INT          NOT NULL,
    space_code  NVARCHAR(20) NOT NULL,
    asset_tag   NVARCHAR(50) NOT NULL,
    status      NVARCHAR(20) NOT NULL DEFAULT 'Working',

    CONSTRAINT PK_facility_asset PRIMARY KEY (asset_id),
    CONSTRAINT UQ_facility_asset_asset_tag UNIQUE (asset_tag),
    CONSTRAINT CK_facility_asset_status CHECK (status IN (
        'Working', 'UnderRepair', 'Retired'
    ))
);
GO

-- 3.6  booking
CREATE TABLE dbo.booking
(
    booking_id      INT           NOT NULL IDENTITY(1,1),
    space_code      NVARCHAR(20)  NOT NULL,
    requester_id    INT           NOT NULL,
    requested_start DATETIME2     NOT NULL,
    requested_end   DATETIME2     NOT NULL,
    purpose         NVARCHAR(MAX) NULL,
    participants    INT           NOT NULL,
    booking_type    NVARCHAR(30)  NOT NULL,
    status          NVARCHAR(20)  NOT NULL DEFAULT 'Pending',

    CONSTRAINT PK_booking PRIMARY KEY (booking_id),
    CONSTRAINT CK_booking_participants CHECK (participants > 0),
    CONSTRAINT CK_booking_time_range CHECK (requested_end > requested_start),
    CONSTRAINT CK_booking_type CHECK (booking_type IN (
        'Lecture', 'Examination', 'Seminar', 'Workshop',
        'Meeting', 'StudentActivity', 'Administrative'
    )),
    CONSTRAINT CK_booking_status CHECK (status IN (
        'Pending', 'Approved', 'Rejected', 'Cancelled',
        'CheckedIn', 'Completed', 'NoShow'
    ))
);
GO

-- 3.7  booking_approval
CREATE TABLE dbo.booking_approval
(
    approval_id     INT           NOT NULL IDENTITY(1,1),
    booking_id      INT           NOT NULL,
    approver_id     INT           NOT NULL,
    decision_time   DATETIME2     NOT NULL,
    decision_note   NVARCHAR(MAX) NULL,
    rejection_reason NVARCHAR(MAX) NULL,

    CONSTRAINT PK_booking_approval PRIMARY KEY (approval_id),
    CONSTRAINT UQ_booking_approval_booking UNIQUE (booking_id)
);
GO

-- 3.8  booking_session
CREATE TABLE dbo.booking_session
(
    session_id      INT           NOT NULL IDENTITY(1,1),
    booking_id      INT           NOT NULL,
    actual_start    DATETIME2     NOT NULL,
    checked_in_by   INT           NOT NULL,
    initial_condition NVARCHAR(MAX) NULL,
    actual_end      DATETIME2     NULL,
    completed_by    INT           NULL,
    final_condition NVARCHAR(MAX) NULL,
    usage_notes     NVARCHAR(MAX) NULL,

    CONSTRAINT PK_booking_session PRIMARY KEY (session_id),
    CONSTRAINT UQ_booking_session_booking UNIQUE (booking_id),
    CONSTRAINT CK_booking_session_time_range CHECK (
        actual_end IS NULL OR actual_end > actual_start
    )
);
GO

-- 3.9  maintenance_record
CREATE TABLE dbo.maintenance_record
(
    maintenance_id     INT           NOT NULL IDENTITY(1,1),
    space_code         NVARCHAR(20)  NOT NULL,
    reporter_id        INT           NOT NULL,
    assigned_to        INT           NULL,
    problem_description NVARCHAR(MAX) NOT NULL,
    problem_type       NVARCHAR(30)  NOT NULL,
    start_time         DATETIME2     NOT NULL,
    completion_time    DATETIME2     NULL,
    status             NVARCHAR(20)  NOT NULL DEFAULT 'Reported',
    result_note        NVARCHAR(MAX) NULL,

    CONSTRAINT PK_maintenance_record PRIMARY KEY (maintenance_id),
    CONSTRAINT CK_maintenance_problem_type CHECK (problem_type IN (
        'BrokenProjector', 'ACFailure', 'DamagedFurniture',
        'Cleaning', 'Network', 'Other'
    )),
    CONSTRAINT CK_maintenance_status CHECK (status IN (
        'Reported', 'InProgress', 'Completed', 'Cancelled'
    ))
);
GO

-- ============================================================
-- SECTION 4: Foreign Key Constraints
-- ============================================================

-- 4.1  booking foreign keys
ALTER TABLE dbo.booking
    ADD CONSTRAINT FK_booking_space
    FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
    ON UPDATE CASCADE
    ON DELETE NO ACTION;

ALTER TABLE dbo.booking
    ADD CONSTRAINT FK_booking_user
    FOREIGN KEY (requester_id) REFERENCES dbo.[user](user_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
GO

-- 4.2  booking_approval foreign keys
ALTER TABLE dbo.booking_approval
    ADD CONSTRAINT FK_booking_approval_booking
    FOREIGN KEY (booking_id) REFERENCES dbo.booking(booking_id)
    ON UPDATE NO ACTION
    ON DELETE CASCADE;

ALTER TABLE dbo.booking_approval
    ADD CONSTRAINT FK_booking_approval_approver
    FOREIGN KEY (approver_id) REFERENCES dbo.[user](user_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
GO

-- 4.3  booking_session foreign keys
ALTER TABLE dbo.booking_session
    ADD CONSTRAINT FK_booking_session_booking
    FOREIGN KEY (booking_id) REFERENCES dbo.booking(booking_id)
    ON UPDATE NO ACTION
    ON DELETE CASCADE;

ALTER TABLE dbo.booking_session
    ADD CONSTRAINT FK_booking_session_checked_in_by
    FOREIGN KEY (checked_in_by) REFERENCES dbo.[user](user_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;

ALTER TABLE dbo.booking_session
    ADD CONSTRAINT FK_booking_session_completed_by
    FOREIGN KEY (completed_by) REFERENCES dbo.[user](user_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
GO

-- 4.4  maintenance_record foreign keys
ALTER TABLE dbo.maintenance_record
    ADD CONSTRAINT FK_maintenance_space
    FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
    ON UPDATE CASCADE
    ON DELETE NO ACTION;

ALTER TABLE dbo.maintenance_record
    ADD CONSTRAINT FK_maintenance_reporter
    FOREIGN KEY (reporter_id) REFERENCES dbo.[user](user_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;

ALTER TABLE dbo.maintenance_record
    ADD CONSTRAINT FK_maintenance_assignee
    FOREIGN KEY (assigned_to) REFERENCES dbo.[user](user_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
GO

-- 4.5  space_facility foreign keys
ALTER TABLE dbo.space_facility
    ADD CONSTRAINT FK_space_facility_space
    FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

ALTER TABLE dbo.space_facility
    ADD CONSTRAINT FK_space_facility_catalog
    FOREIGN KEY (catalog_id) REFERENCES dbo.facility_catalog(catalog_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;
GO

-- 4.6  facility_asset foreign keys
ALTER TABLE dbo.facility_asset
    ADD CONSTRAINT FK_facility_asset_catalog
    FOREIGN KEY (catalog_id) REFERENCES dbo.facility_catalog(catalog_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;

ALTER TABLE dbo.facility_asset
    ADD CONSTRAINT FK_facility_asset_space
    FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
    ON UPDATE CASCADE
    ON DELETE CASCADE;
GO

-- ============================================================
-- SECTION 5: Data Integrity Trigger
--   trg_space_facility_quantity_validate
--   AFTER INSERT, UPDATE on space_facility
--   Ensures that for trackable items, quantity does not exceed
--   the actual count of registered assets.
-- ============================================================

CREATE OR ALTER TRIGGER dbo.trg_space_facility_quantity_validate
ON dbo.space_facility
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.facility_catalog fc ON i.catalog_id = fc.catalog_id
        WHERE fc.is_trackable = 1
          AND i.quantity > (
              SELECT COUNT(*)
              FROM dbo.facility_asset fa
              WHERE fa.catalog_id = i.catalog_id
                AND fa.space_code = i.space_code
          )
    )
    BEGIN
        RAISERROR('Quantity for trackable item exceeds the number of registered physical assets in this space.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

PRINT 'Campus Space Management System DDL executed successfully.';
GO
