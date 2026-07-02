-- ============================================================
-- DDL: Campus Space Management System
-- DBMS: Microsoft SQL Server
-- File: outputs/05-db-definition-G11.sql
-- ============================================================

-- Database Initialization
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

-- Drop existing tables in reverse dependency order
IF OBJECT_ID('dbo.MAINTENANCE_RECORD', 'U') IS NOT NULL DROP TABLE dbo.MAINTENANCE_RECORD;
IF OBJECT_ID('dbo.USAGE_SESSION', 'U') IS NOT NULL DROP TABLE dbo.USAGE_SESSION;
IF OBJECT_ID('dbo.APPROVAL', 'U') IS NOT NULL DROP TABLE dbo.APPROVAL;
IF OBJECT_ID('dbo.FACILITY_ASSET', 'U') IS NOT NULL DROP TABLE dbo.FACILITY_ASSET;
IF OBJECT_ID('dbo.SPACE_FACILITY', 'U') IS NOT NULL DROP TABLE dbo.SPACE_FACILITY;
IF OBJECT_ID('dbo.BOOKING', 'U') IS NOT NULL DROP TABLE dbo.BOOKING;
IF OBJECT_ID('dbo.FACILITY_CATALOG', 'U') IS NOT NULL DROP TABLE dbo.FACILITY_CATALOG;
IF OBJECT_ID('dbo.SPACE', 'U') IS NOT NULL DROP TABLE dbo.SPACE;
IF OBJECT_ID('dbo.[USER]', 'U') IS NOT NULL DROP TABLE dbo.[USER];
GO

-- ============================================================
-- 1. USER
-- ============================================================
CREATE TABLE dbo.[USER]
(
    user_id         NVARCHAR(50)    NOT NULL,
    full_name       NVARCHAR(100)   NOT NULL,
    email           NVARCHAR(255)   NOT NULL,
    phone           NVARCHAR(20)    NULL,
    role            NVARCHAR(30)    NOT NULL,
    department      NVARCHAR(100)   NOT NULL,
    account_status  NVARCHAR(20)    NOT NULL,
    CONSTRAINT PK_USER PRIMARY KEY (user_id),
    CONSTRAINT UQ_USER_EMAIL UNIQUE (email),
    CONSTRAINT CK_USER_ROLE CHECK (role IN ('Student','Lecturer','TA','Facility Staff','Dept Admin','Facility Manager')),
    CONSTRAINT CK_USER_ACCOUNT_STATUS CHECK (account_status IN ('Active','Inactive','Suspended'))
);
GO

-- ============================================================
-- 2. SPACE
-- ============================================================
CREATE TABLE dbo.SPACE
(
    space_code      NVARCHAR(20)    NOT NULL,
    space_name      NVARCHAR(100)   NOT NULL,
    space_type      NVARCHAR(50)    NOT NULL,
    building        NVARCHAR(100)   NOT NULL,
    floor           NVARCHAR(10)    NOT NULL,
    room_number     NVARCHAR(20)    NOT NULL,
    capacity        INT             NOT NULL,
    current_status  NVARCHAR(20)    NOT NULL,
    usage_policy    NVARCHAR(MAX)   NULL,
    CONSTRAINT PK_SPACE PRIMARY KEY (space_code),
    CONSTRAINT CK_SPACE_TYPE CHECK (space_type IN ('Auditorium','Classroom','Computer Lab','Project Lab','Meeting Room','Student Workspace')),
    CONSTRAINT CK_SPACE_CAPACITY CHECK (capacity > 0),
    CONSTRAINT CK_SPACE_STATUS CHECK (current_status IN ('Available','In Use','Under Maintenance','Temporarily Closed','Retired'))
);
GO

-- ============================================================
-- 3. FACILITY_CATALOG
-- ============================================================
CREATE TABLE dbo.FACILITY_CATALOG
(
    catalog_id      INT             NOT NULL IDENTITY(1,1),
    facility_name   NVARCHAR(100)   NOT NULL,
    is_trackable    BIT             NOT NULL,
    CONSTRAINT PK_FACILITY_CATALOG PRIMARY KEY (catalog_id)
);
GO

-- ============================================================
-- 4. BOOKING
-- ============================================================
CREATE TABLE dbo.BOOKING
(
    booking_id          INT             NOT NULL IDENTITY(1,1),
    user_id             NVARCHAR(50)    NOT NULL,
    space_code          NVARCHAR(20)    NOT NULL,
    requested_start     DATETIME2       NOT NULL,
    requested_end       DATETIME2       NOT NULL,
    purpose             NVARCHAR(30)    NOT NULL,
    expected_participants INT           NOT NULL,
    status              NVARCHAR(20)    NOT NULL DEFAULT 'Pending',
    CONSTRAINT PK_BOOKING PRIMARY KEY (booking_id),
    CONSTRAINT CK_BOOKING_TIME_RANGE CHECK (requested_end > requested_start),
    CONSTRAINT CK_BOOKING_PURPOSE CHECK (purpose IN ('Lecture','Examination','Seminar','Workshop','Meeting','Student Activity','Admin Event')),
    CONSTRAINT CK_BOOKING_PARTICIPANTS CHECK (expected_participants > 0),
    CONSTRAINT CK_BOOKING_STATUS CHECK (status IN ('Pending','Approved','Rejected','Cancelled','Checked In','Completed','No-show'))
);
GO

-- ============================================================
-- 5. SPACE_FACILITY
-- ============================================================
CREATE TABLE dbo.SPACE_FACILITY
(
    space_code  NVARCHAR(20)    NOT NULL,
    catalog_id  INT             NOT NULL,
    quantity    INT             NOT NULL,
    CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (space_code, catalog_id),
    CONSTRAINT CK_SPACE_FACILITY_QUANTITY CHECK (quantity > 0)
);
GO

-- ============================================================
-- 6. FACILITY_ASSET
-- ============================================================
CREATE TABLE dbo.FACILITY_ASSET
(
    asset_id    INT             NOT NULL IDENTITY(1,1),
    catalog_id  INT             NOT NULL,
    space_code  NVARCHAR(20)    NOT NULL,
    asset_tag   NVARCHAR(100)   NOT NULL,
    status      NVARCHAR(20)    NOT NULL,
    CONSTRAINT PK_FACILITY_ASSET PRIMARY KEY (asset_id),
    CONSTRAINT UQ_FACILITY_ASSET_TAG UNIQUE (asset_tag),
    CONSTRAINT CK_FACILITY_ASSET_STATUS CHECK (status IN ('Working','Under Repair','Retired'))
);
GO

-- ============================================================
-- 7. APPROVAL
-- ============================================================
CREATE TABLE dbo.APPROVAL
(
    approval_id     INT             NOT NULL IDENTITY(1,1),
    booking_id      INT             NOT NULL,
    staff_id        NVARCHAR(50)    NOT NULL,
    decision        NVARCHAR(20)    NOT NULL,
    decision_time   DATETIME2       NOT NULL,
    decision_note   NVARCHAR(MAX)   NULL,
    rejection_reason NVARCHAR(MAX)  NULL,
    CONSTRAINT PK_APPROVAL PRIMARY KEY (approval_id),
    CONSTRAINT UQ_APPROVAL_BOOKING UNIQUE (booking_id),
    CONSTRAINT CK_APPROVAL_DECISION CHECK (decision IN ('Approved','Rejected')),
    CONSTRAINT CK_APPROVAL_REJECTION_REASON CHECK (decision <> 'Rejected' OR rejection_reason IS NOT NULL)
);
GO

-- ============================================================
-- 8. USAGE_SESSION
-- ============================================================
CREATE TABLE dbo.USAGE_SESSION
(
    session_id      INT             NOT NULL IDENTITY(1,1),
    booking_id      INT             NOT NULL,
    checked_in_by   NVARCHAR(50)    NOT NULL,
    actual_start    DATETIME2       NOT NULL,
    initial_condition NVARCHAR(MAX) NOT NULL,
    actual_end      DATETIME2       NULL,
    final_condition NVARCHAR(MAX)   NULL,
    completed_by    NVARCHAR(50)    NULL,
    usage_notes     NVARCHAR(MAX)   NULL,
    CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (session_id),
    CONSTRAINT UQ_USAGE_SESSION_BOOKING UNIQUE (booking_id),
    CONSTRAINT CK_USAGE_SESSION_TIME CHECK (actual_end IS NULL OR actual_end > actual_start),
    CONSTRAINT CK_USAGE_SESSION_COMPLETION CHECK (
        (actual_end IS NULL AND final_condition IS NULL AND completed_by IS NULL)
        OR
        (actual_end IS NOT NULL AND final_condition IS NOT NULL AND completed_by IS NOT NULL)
    )
);
GO

-- ============================================================
-- 9. MAINTENANCE_RECORD
-- ============================================================
CREATE TABLE dbo.MAINTENANCE_RECORD
(
    maintenance_id      INT             NOT NULL IDENTITY(1,1),
    space_code          NVARCHAR(20)    NOT NULL,
    reporter_id         NVARCHAR(50)    NOT NULL,
    assigned_staff_id   NVARCHAR(50)    NULL,
    problem_description NVARCHAR(MAX)   NOT NULL,
    problem_type        NVARCHAR(50)    NOT NULL,
    start_time          DATETIME2       NOT NULL,
    completion_time     DATETIME2       NULL,
    status              NVARCHAR(20)    NOT NULL,
    result_note         NVARCHAR(MAX)   NULL,
    CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_id),
    CONSTRAINT CK_MAINTENANCE_PROBLEM_TYPE CHECK (problem_type IN ('Broken Projector','AC Failure','Damaged Furniture','Cleaning','Network Problem')),
    CONSTRAINT CK_MAINTENANCE_TIME CHECK (completion_time IS NULL OR completion_time > start_time),
    CONSTRAINT CK_MAINTENANCE_STATUS CHECK (status IN ('Reported','In Progress','Completed','Cancelled'))
);
GO

-- ============================================================
-- Foreign Key Constraints
-- ============================================================

-- SPACE_FACILITY
ALTER TABLE dbo.SPACE_FACILITY ADD CONSTRAINT FK_SPACE_FACILITY_SPACE
    FOREIGN KEY (space_code) REFERENCES dbo.SPACE(space_code)
    ON UPDATE CASCADE ON DELETE CASCADE;
GO

ALTER TABLE dbo.SPACE_FACILITY ADD CONSTRAINT FK_SPACE_FACILITY_CATALOG
    FOREIGN KEY (catalog_id) REFERENCES dbo.FACILITY_CATALOG(catalog_id)
    ON UPDATE NO ACTION ON DELETE CASCADE;
GO

-- FACILITY_ASSET
ALTER TABLE dbo.FACILITY_ASSET ADD CONSTRAINT FK_FACILITY_ASSET_CATALOG
    FOREIGN KEY (catalog_id) REFERENCES dbo.FACILITY_CATALOG(catalog_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

ALTER TABLE dbo.FACILITY_ASSET ADD CONSTRAINT FK_FACILITY_ASSET_SPACE
    FOREIGN KEY (space_code) REFERENCES dbo.SPACE(space_code)
    ON UPDATE CASCADE ON DELETE NO ACTION;
GO

-- BOOKING
ALTER TABLE dbo.BOOKING ADD CONSTRAINT FK_BOOKING_USER
    FOREIGN KEY (user_id) REFERENCES dbo.[USER](user_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

ALTER TABLE dbo.BOOKING ADD CONSTRAINT FK_BOOKING_SPACE
    FOREIGN KEY (space_code) REFERENCES dbo.SPACE(space_code)
    ON UPDATE CASCADE ON DELETE NO ACTION;
GO

-- APPROVAL
ALTER TABLE dbo.APPROVAL ADD CONSTRAINT FK_APPROVAL_BOOKING
    FOREIGN KEY (booking_id) REFERENCES dbo.BOOKING(booking_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

ALTER TABLE dbo.APPROVAL ADD CONSTRAINT FK_APPROVAL_STAFF
    FOREIGN KEY (staff_id) REFERENCES dbo.[USER](user_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

-- USAGE_SESSION
ALTER TABLE dbo.USAGE_SESSION ADD CONSTRAINT FK_USAGE_SESSION_BOOKING
    FOREIGN KEY (booking_id) REFERENCES dbo.BOOKING(booking_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

ALTER TABLE dbo.USAGE_SESSION ADD CONSTRAINT FK_USAGE_SESSION_CHECKED_IN_BY
    FOREIGN KEY (checked_in_by) REFERENCES dbo.[USER](user_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

ALTER TABLE dbo.USAGE_SESSION ADD CONSTRAINT FK_USAGE_SESSION_COMPLETED_BY
    FOREIGN KEY (completed_by) REFERENCES dbo.[USER](user_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

-- MAINTENANCE_RECORD
ALTER TABLE dbo.MAINTENANCE_RECORD ADD CONSTRAINT FK_MAINTENANCE_SPACE
    FOREIGN KEY (space_code) REFERENCES dbo.SPACE(space_code)
    ON UPDATE CASCADE ON DELETE NO ACTION;
GO

ALTER TABLE dbo.MAINTENANCE_RECORD ADD CONSTRAINT FK_MAINTENANCE_REPORTER
    FOREIGN KEY (reporter_id) REFERENCES dbo.[USER](user_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

ALTER TABLE dbo.MAINTENANCE_RECORD ADD CONSTRAINT FK_MAINTENANCE_ASSIGNED_STAFF
    FOREIGN KEY (assigned_staff_id) REFERENCES dbo.[USER](user_id)
    ON UPDATE NO ACTION ON DELETE NO ACTION;
GO

-- ============================================================
-- Data Integrity Trigger
-- Ensures SPACE_FACILITY.quantity does not exceed actual
-- count of FACILITY_ASSET rows for trackable catalog items
-- ============================================================
CREATE TRIGGER trg_space_facility_quantity_check
ON dbo.SPACE_FACILITY
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.FACILITY_CATALOG fc ON i.catalog_id = fc.catalog_id
        WHERE fc.is_trackable = 1
          AND i.quantity > (
              SELECT COUNT(*)
              FROM dbo.FACILITY_ASSET fa
              WHERE fa.space_code = i.space_code
                AND fa.catalog_id = i.catalog_id
          )
    )
    BEGIN
        RAISERROR('Quantity exceeds the number of registered facility assets for the given space and catalog.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO
