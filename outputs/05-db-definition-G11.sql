-- ============================================================
-- Database Definition DDL — G11
-- DBMS: Microsoft SQL Server
-- Database: CampusSpaceManagement
-- ============================================================

-- ============================================================
-- 1. Database Initialization
-- ============================================================
USE master;
GO

IF DB_ID('CampusSpaceManagement') IS NOT NULL
BEGIN
    ALTER DATABASE [CampusSpaceManagement]
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [CampusSpaceManagement];
END
GO

CREATE DATABASE [CampusSpaceManagement];
GO

USE [CampusSpaceManagement];
GO

-- ============================================================
-- 2. Drop existing tables (reverse FK dependency order)
-- ============================================================
IF OBJECT_ID('dbo.booking_session', 'U') IS NOT NULL DROP TABLE dbo.booking_session;
IF OBJECT_ID('dbo.booking_decision', 'U') IS NOT NULL DROP TABLE dbo.booking_decision;
IF OBJECT_ID('dbo.booking_request', 'U') IS NOT NULL DROP TABLE dbo.booking_request;
IF OBJECT_ID('dbo.facility_asset', 'U') IS NOT NULL DROP TABLE dbo.facility_asset;
IF OBJECT_ID('dbo.space_facility', 'U') IS NOT NULL DROP TABLE dbo.space_facility;
IF OBJECT_ID('dbo.maintenance_record', 'U') IS NOT NULL DROP TABLE dbo.maintenance_record;
IF OBJECT_ID('dbo.facility_catalog', 'U') IS NOT NULL DROP TABLE dbo.facility_catalog;
IF OBJECT_ID('dbo.space', 'U') IS NOT NULL DROP TABLE dbo.space;
IF OBJECT_ID('dbo.[user]', 'U') IS NOT NULL DROP TABLE dbo.[user];
GO

-- ============================================================
-- 3. Table Definitions
-- ============================================================

-- 3.1 user
CREATE TABLE dbo.[user]
(
    user_id         INT           NOT NULL IDENTITY(1,1),
    full_name       NVARCHAR(100) NOT NULL,
    email           NVARCHAR(255) NOT NULL,
    phone_number    NVARCHAR(20)  NULL,
    role            NVARCHAR(30)  NOT NULL,
    department      NVARCHAR(100) NOT NULL,
    account_status  NVARCHAR(20)  NOT NULL DEFAULT 'Active',

    CONSTRAINT PK_user PRIMARY KEY (user_id),
    CONSTRAINT UQ_user_email UNIQUE (email),
    CONSTRAINT CK_user_role CHECK (role IN (
        'Student', 'Lecturer', 'TA',
        'Facility Staff', 'Dept Admin', 'Facility Manager'
    )),
    CONSTRAINT CK_user_account_status CHECK (account_status IN (
        'Active', 'Inactive', 'Suspended'
    ))
);
GO

-- 3.2 space
CREATE TABLE dbo.space
(
    space_code      NVARCHAR(20)  NOT NULL,
    space_name      NVARCHAR(100) NOT NULL,
    space_type      NVARCHAR(30)  NOT NULL,
    building        NVARCHAR(100) NOT NULL,
    floor           INT           NOT NULL,
    room_number     NVARCHAR(20)  NOT NULL,
    capacity        INT           NOT NULL,
    current_status  NVARCHAR(30)  NOT NULL DEFAULT 'Available',
    usage_policy    NVARCHAR(MAX) NULL,

    CONSTRAINT PK_space PRIMARY KEY (space_code),
    CONSTRAINT UQ_space_room UNIQUE (building, floor, room_number),
    CONSTRAINT CK_space_type CHECK (space_type IN (
        'Auditorium', 'Classroom', 'Computer Laboratory',
        'Project Laboratory', 'Meeting Room', 'Student Workspace'
    )),
    CONSTRAINT CK_space_floor CHECK (floor >= 0),
    CONSTRAINT CK_space_capacity CHECK (capacity > 0),
    CONSTRAINT CK_space_current_status CHECK (current_status IN (
        'Available', 'In Use', 'Under Maintenance',
        'Temporarily Closed', 'Retired'
    ))
);
GO

-- 3.3 facility_catalog
CREATE TABLE dbo.facility_catalog
(
    catalog_id   INT            NOT NULL IDENTITY(1,1),
    name         NVARCHAR(100)  NOT NULL,
    description  NVARCHAR(500)  NULL,
    is_trackable BIT            NOT NULL DEFAULT 0,

    CONSTRAINT PK_facility_catalog PRIMARY KEY (catalog_id),
    CONSTRAINT UQ_facility_catalog_name UNIQUE (name)
);
GO

-- 3.4 space_facility (M:N associative)
CREATE TABLE dbo.space_facility
(
    space_code  NVARCHAR(20) NOT NULL,
    catalog_id  INT          NOT NULL,
    quantity    INT          NOT NULL,

    CONSTRAINT PK_space_facility PRIMARY KEY (space_code, catalog_id),
    CONSTRAINT FK_space_facility_space
        FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
        ON UPDATE CASCADE ON DELETE NO ACTION,
    CONSTRAINT FK_space_facility_catalog
        FOREIGN KEY (catalog_id) REFERENCES dbo.facility_catalog(catalog_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT CK_space_facility_quantity CHECK (quantity > 0)
);
GO

-- 3.5 facility_asset
CREATE TABLE dbo.facility_asset
(
    asset_id    INT           NOT NULL IDENTITY(1,1),
    asset_tag   NVARCHAR(50)  NOT NULL,
    catalog_id  INT           NOT NULL,
    space_code  NVARCHAR(20)  NOT NULL,
    status      NVARCHAR(20)  NOT NULL DEFAULT 'Working',

    CONSTRAINT PK_facility_asset PRIMARY KEY (asset_id),
    CONSTRAINT UQ_facility_asset_tag UNIQUE (asset_tag),
    CONSTRAINT FK_facility_asset_catalog
        FOREIGN KEY (catalog_id) REFERENCES dbo.facility_catalog(catalog_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_facility_asset_space
        FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
        ON UPDATE CASCADE ON DELETE NO ACTION,
    CONSTRAINT CK_facility_asset_status CHECK (status IN (
        'Working', 'Under Repair', 'Retired'
    ))
);
GO

-- 3.6 booking_request
CREATE TABLE dbo.booking_request
(
    booking_id              INT           NOT NULL IDENTITY(1,1),
    requester_id            INT           NOT NULL,
    space_code              NVARCHAR(20)  NOT NULL,
    requested_start_time    DATETIME2     NOT NULL,
    requested_end_time      DATETIME2     NOT NULL,
    purpose                 NVARCHAR(30)  NOT NULL,
    expected_participants   INT           NOT NULL,
    status                  NVARCHAR(20)  NOT NULL DEFAULT 'Pending',
    created_at              DATETIME2     NOT NULL DEFAULT GETUTCDATE(),

    CONSTRAINT PK_booking_request PRIMARY KEY (booking_id),
    CONSTRAINT FK_booking_request_requester
        FOREIGN KEY (requester_id) REFERENCES dbo.[user](user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_booking_request_space
        FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
        ON UPDATE CASCADE ON DELETE NO ACTION,
    CONSTRAINT CK_booking_request_time CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CK_booking_request_purpose CHECK (purpose IN (
        'Lecture', 'Examination', 'Seminar', 'Workshop',
        'Meeting', 'Student Activity', 'Administrative Event'
    )),
    CONSTRAINT CK_booking_request_participants CHECK (expected_participants > 0),
    CONSTRAINT CK_booking_request_status CHECK (status IN (
        'Pending', 'Approved', 'Rejected', 'Cancelled',
        'Checked In', 'Completed', 'No-Show'
    ))
);
GO

-- 3.7 booking_decision
CREATE TABLE dbo.booking_decision
(
    booking_id       INT            NOT NULL,
    staff_id         INT            NOT NULL,
    decision         NVARCHAR(10)   NOT NULL,
    decision_time    DATETIME2      NOT NULL,
    decision_note    NVARCHAR(500)  NULL,
    rejection_reason NVARCHAR(500)  NULL,

    CONSTRAINT PK_booking_decision PRIMARY KEY (booking_id),
    CONSTRAINT FK_booking_decision_booking
        FOREIGN KEY (booking_id) REFERENCES dbo.booking_request(booking_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_booking_decision_staff
        FOREIGN KEY (staff_id) REFERENCES dbo.[user](user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT CK_booking_decision_decision CHECK (decision IN (
        'Approved', 'Rejected'
    )),
    CONSTRAINT CK_booking_decision_rejection CHECK (
        NOT (decision = 'Rejected' AND rejection_reason IS NULL)
    )
);
GO

-- 3.8 booking_session
CREATE TABLE dbo.booking_session
(
    booking_id         INT            NOT NULL,
    actual_start_time  DATETIME2      NOT NULL,
    checked_in_by      INT            NOT NULL,
    initial_condition  NVARCHAR(500)  NULL,
    actual_end_time    DATETIME2      NULL,
    final_condition    NVARCHAR(500)  NULL,
    usage_notes        NVARCHAR(MAX)  NULL,

    CONSTRAINT PK_booking_session PRIMARY KEY (booking_id),
    CONSTRAINT FK_booking_session_booking
        FOREIGN KEY (booking_id) REFERENCES dbo.booking_request(booking_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_booking_session_staff
        FOREIGN KEY (checked_in_by) REFERENCES dbo.[user](user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT CK_booking_session_time CHECK (
        actual_end_time IS NULL OR actual_end_time > actual_start_time
    )
);
GO

-- 3.9 maintenance_record
CREATE TABLE dbo.maintenance_record
(
    maintenance_id      INT            NOT NULL IDENTITY(1,1),
    space_code          NVARCHAR(20)   NOT NULL,
    reported_by         INT            NOT NULL,
    assigned_to         INT            NULL,
    problem_description NVARCHAR(500)  NOT NULL,
    problem_type        NVARCHAR(30)   NOT NULL,
    start_time          DATETIME2      NOT NULL,
    completion_time     DATETIME2      NULL,
    status              NVARCHAR(20)   NOT NULL DEFAULT 'Reported',
    result_note         NVARCHAR(MAX)  NULL,

    CONSTRAINT PK_maintenance_record PRIMARY KEY (maintenance_id),
    CONSTRAINT FK_maintenance_space
        FOREIGN KEY (space_code) REFERENCES dbo.space(space_code)
        ON UPDATE CASCADE ON DELETE NO ACTION,
    CONSTRAINT FK_maintenance_reporter
        FOREIGN KEY (reported_by) REFERENCES dbo.[user](user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_maintenance_assignee
        FOREIGN KEY (assigned_to) REFERENCES dbo.[user](user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT CK_maintenance_problem_type CHECK (problem_type IN (
        'Broken Projector', 'AC Failure', 'Damaged Furniture',
        'Cleaning Issue', 'Network Problem'
    )),
    CONSTRAINT CK_maintenance_status CHECK (status IN (
        'Reported', 'In Progress', 'Completed'
    )),
    CONSTRAINT CK_maintenance_completion_time CHECK (
        completion_time IS NULL OR completion_time > start_time
    )
);
GO

-- ============================================================
-- 4. Data Integrity Trigger
--    Ensures that for trackable catalog items, the quantity in
--    space_facility does not exceed the actual asset count.
-- ============================================================
CREATE TRIGGER trg_space_facility_validate_quantity
ON dbo.space_facility
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.facility_catalog fc
            ON i.catalog_id = fc.catalog_id
        WHERE fc.is_trackable = 1
          AND i.quantity > (
              SELECT COUNT(*)
              FROM dbo.facility_asset fa
              WHERE fa.space_code = i.space_code
                AND fa.catalog_id = i.catalog_id
          )
    )
    BEGIN
        RAISERROR(
            'Quantity in space_facility exceeds the actual count of tracked assets for this catalog item in this space.',
            16, 1
        );
        ROLLBACK TRANSACTION;
    END
END;
GO
