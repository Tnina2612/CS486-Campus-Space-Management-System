-- ====================================================================
-- 05-db-definition-G11.sql
-- Database Implementation — Campus Space Management System
-- DBMS: Microsoft SQL Server
-- ====================================================================

-- ====================================================================
-- 1. DATABASE INITIALIZATION
-- ====================================================================
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

-- ====================================================================
-- 2. DROP EXISTING OBJECTS (reverse FK dependency order)
-- ====================================================================
IF OBJECT_ID('trg_space_facility_trackable_check', 'TR') IS NOT NULL
    DROP TRIGGER trg_space_facility_trackable_check;
GO

IF OBJECT_ID('USAGE_SESSION', 'U') IS NOT NULL DROP TABLE USAGE_SESSION;
IF OBJECT_ID('APPROVAL', 'U') IS NOT NULL DROP TABLE APPROVAL;
IF OBJECT_ID('BOOKING', 'U') IS NOT NULL DROP TABLE BOOKING;
IF OBJECT_ID('MAINTENANCE_RECORD', 'U') IS NOT NULL DROP TABLE MAINTENANCE_RECORD;
IF OBJECT_ID('FACILITY_ASSET', 'U') IS NOT NULL DROP TABLE FACILITY_ASSET;
IF OBJECT_ID('SPACE_FACILITY', 'U') IS NOT NULL DROP TABLE SPACE_FACILITY;
IF OBJECT_ID('FACILITY_CATALOG', 'U') IS NOT NULL DROP TABLE FACILITY_CATALOG;
IF OBJECT_ID('SPACE', 'U') IS NOT NULL DROP TABLE SPACE;
IF OBJECT_ID('[USER]', 'U') IS NOT NULL DROP TABLE [USER];
GO

-- ====================================================================
-- 3. TABLE DEFINITIONS
-- ====================================================================

-- ---------------------------------------------------------------
-- 3.1 USER
-- ---------------------------------------------------------------
CREATE TABLE [USER]
(
    user_id          INT           NOT NULL IDENTITY(1,1),
    full_name        NVARCHAR(100) NOT NULL,
    email            NVARCHAR(255) NOT NULL,
    phone            NVARCHAR(20)  NULL,
    role             NVARCHAR(50)  NOT NULL,
    department       NVARCHAR(100) NULL,
    account_status   NVARCHAR(20)  NOT NULL DEFAULT 'active',

    CONSTRAINT PK_USER PRIMARY KEY (user_id),
    CONSTRAINT UQ_USER_EMAIL UNIQUE (email),
    CONSTRAINT CK_USER_ROLE CHECK (role IN ('student','lecturer','teaching_assistant','facility_staff','department_administrator','facility_manager')),
    CONSTRAINT CK_USER_ACCOUNT_STATUS CHECK (account_status IN ('active','inactive','suspended')),
    CONSTRAINT CK_USER_EMAIL_FORMAT CHECK (email LIKE '%_@__%.__%')
);
GO

-- ---------------------------------------------------------------
-- 3.2 SPACE
-- ---------------------------------------------------------------
CREATE TABLE SPACE
(
    space_code      NVARCHAR(20)  NOT NULL,
    space_name      NVARCHAR(100) NOT NULL,
    space_type      NVARCHAR(50)  NOT NULL,
    building        NVARCHAR(100) NOT NULL,
    floor           INT           NOT NULL,
    room_number     NVARCHAR(20)  NOT NULL,
    capacity        INT           NOT NULL,
    current_status  NVARCHAR(20)  NOT NULL DEFAULT 'available',
    usage_policy    NVARCHAR(MAX) NULL,

    CONSTRAINT PK_SPACE PRIMARY KEY (space_code),
    CONSTRAINT CK_SPACE_TYPE CHECK (space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','workspace')),
    CONSTRAINT CK_SPACE_CAPACITY CHECK (capacity > 0),
    CONSTRAINT CK_SPACE_STATUS CHECK (current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired'))
);
GO

-- ---------------------------------------------------------------
-- 3.3 FACILITY_CATALOG
-- ---------------------------------------------------------------
CREATE TABLE FACILITY_CATALOG
(
    catalog_id    INT            NOT NULL IDENTITY(1,1),
    facility_name NVARCHAR(100)  NOT NULL,
    description   NVARCHAR(MAX)  NULL,
    is_trackable  BIT            NOT NULL DEFAULT 0,

    CONSTRAINT PK_FACILITY_CATALOG PRIMARY KEY (catalog_id),
    CONSTRAINT UQ_FACILITY_CATALOG_NAME UNIQUE (facility_name)
);
GO

-- ---------------------------------------------------------------
-- 3.4 SPACE_FACILITY (M:N associative table)
-- ---------------------------------------------------------------
CREATE TABLE SPACE_FACILITY
(
    space_code NVARCHAR(20) NOT NULL,
    catalog_id INT          NOT NULL,
    quantity   INT          NOT NULL,

    CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (space_code, catalog_id),
    CONSTRAINT CK_SF_QUANTITY CHECK (quantity > 0),

    CONSTRAINT FK_SF_SPACE FOREIGN KEY (space_code)
        REFERENCES SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,

    CONSTRAINT FK_SF_CATALOG FOREIGN KEY (catalog_id)
        REFERENCES FACILITY_CATALOG(catalog_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);
GO

-- ---------------------------------------------------------------
-- 3.5 FACILITY_ASSET (trackable assets)
-- ---------------------------------------------------------------
CREATE TABLE FACILITY_ASSET
(
    asset_id   INT           NOT NULL IDENTITY(1,1),
    catalog_id INT           NOT NULL,
    space_code NVARCHAR(20)  NOT NULL,
    asset_tag  NVARCHAR(50)  NOT NULL,
    status     NVARCHAR(20)  NOT NULL DEFAULT 'available',

    CONSTRAINT PK_FACILITY_ASSET PRIMARY KEY (asset_id),
    CONSTRAINT UQ_FACILITY_ASSET_TAG UNIQUE (asset_tag),
    CONSTRAINT CK_FA_STATUS CHECK (status IN ('available','in_use','under_maintenance','retired')),

    CONSTRAINT FK_FA_CATALOG FOREIGN KEY (catalog_id)
        REFERENCES FACILITY_CATALOG(catalog_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_FA_SPACE FOREIGN KEY (space_code)
        REFERENCES SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO

-- ---------------------------------------------------------------
-- 3.6 BOOKING
-- ---------------------------------------------------------------
CREATE TABLE BOOKING
(
    booking_id           INT          NOT NULL IDENTITY(1,1),
    requester_id         INT          NOT NULL,
    space_code           NVARCHAR(20) NOT NULL,
    requested_start      DATETIME2    NOT NULL,
    requested_end        DATETIME2    NOT NULL,
    purpose              NVARCHAR(50) NOT NULL,
    expected_participants INT         NOT NULL,
    status               NVARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at           DATETIME2    NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_BOOKING PRIMARY KEY (booking_id),
    CONSTRAINT CK_BOOKING_PURPOSE CHECK (purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')),
    CONSTRAINT CK_BOOKING_PARTICIPANTS CHECK (expected_participants > 0),
    CONSTRAINT CK_BOOKING_STATUS CHECK (status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')),
    CONSTRAINT CK_BOOKING_TIME_RANGE CHECK (requested_start < requested_end),

    CONSTRAINT FK_BOOKING_REQUESTER FOREIGN KEY (requester_id)
        REFERENCES [USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_BOOKING_SPACE FOREIGN KEY (space_code)
        REFERENCES SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE NO ACTION
);
GO

-- ---------------------------------------------------------------
-- 3.7 APPROVAL (1:1 with BOOKING)
-- ---------------------------------------------------------------
CREATE TABLE APPROVAL
(
    approval_id      INT           NOT NULL IDENTITY(1,1),
    booking_id       INT           NOT NULL,
    reviewer_id      INT           NOT NULL,
    decision_time    DATETIME2     NOT NULL DEFAULT GETDATE(),
    decision_note    NVARCHAR(MAX) NULL,
    rejection_reason NVARCHAR(MAX) NULL,

    CONSTRAINT PK_APPROVAL PRIMARY KEY (approval_id),
    CONSTRAINT UQ_APPROVAL_BOOKING UNIQUE (booking_id),

    CONSTRAINT FK_APPROVAL_BOOKING FOREIGN KEY (booking_id)
        REFERENCES BOOKING(booking_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_APPROVAL_REVIEWER FOREIGN KEY (reviewer_id)
        REFERENCES [USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);
GO

-- ---------------------------------------------------------------
-- 3.8 USAGE_SESSION (1:1 with BOOKING)
-- ---------------------------------------------------------------
CREATE TABLE USAGE_SESSION
(
    session_id        INT           NOT NULL IDENTITY(1,1),
    booking_id        INT           NOT NULL,
    checked_in_by     INT           NOT NULL,
    actual_start_time DATETIME2     NOT NULL,
    initial_condition NVARCHAR(MAX) NOT NULL,
    checked_out_by    INT           NULL,
    actual_end_time   DATETIME2     NULL,
    final_condition   NVARCHAR(MAX) NULL,
    usage_notes       NVARCHAR(MAX) NULL,

    CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (session_id),
    CONSTRAINT UQ_USAGE_SESSION_BOOKING UNIQUE (booking_id),
    CONSTRAINT CK_SESSION_TIME_RANGE CHECK (actual_end_time IS NULL OR actual_end_time >= actual_start_time),

    CONSTRAINT FK_US_BOOKING FOREIGN KEY (booking_id)
        REFERENCES BOOKING(booking_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_US_CHECKED_IN_BY FOREIGN KEY (checked_in_by)
        REFERENCES [USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_US_CHECKED_OUT_BY FOREIGN KEY (checked_out_by)
        REFERENCES [USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);
GO

-- ---------------------------------------------------------------
-- 3.9 MAINTENANCE_RECORD
-- ---------------------------------------------------------------
CREATE TABLE MAINTENANCE_RECORD
(
    maintenance_id     INT           NOT NULL IDENTITY(1,1),
    space_code         NVARCHAR(20)  NOT NULL,
    reporter_id        INT           NOT NULL,
    assigned_staff_id  INT           NULL,
    problem_description NVARCHAR(MAX) NOT NULL,
    problem_category   NVARCHAR(50)  NOT NULL,
    start_time         DATETIME2     NOT NULL,
    completion_time    DATETIME2     NULL,
    status             NVARCHAR(20)  NOT NULL DEFAULT 'reported',
    result_note        NVARCHAR(MAX) NULL,

    CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_id),
    CONSTRAINT CK_MR_CATEGORY CHECK (problem_category IN ('broken_projector','ac_failure','damaged_furniture','cleaning','network','other')),
    CONSTRAINT CK_MR_STATUS CHECK (status IN ('reported','in_progress','completed','cancelled')),
    CONSTRAINT CK_MR_TIME_RANGE CHECK (completion_time IS NULL OR completion_time >= start_time),

    CONSTRAINT FK_MR_SPACE FOREIGN KEY (space_code)
        REFERENCES SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,

    CONSTRAINT FK_MR_REPORTER FOREIGN KEY (reporter_id)
        REFERENCES [USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,

    CONSTRAINT FK_MR_ASSIGNED_STAFF FOREIGN KEY (assigned_staff_id)
        REFERENCES [USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);
GO

-- ====================================================================
-- 4. DATA INTEGRITY TRIGGER
--    Enforces that SPACE_FACILITY.quantity does not exceed the actual
--    asset count for trackable catalog items.
-- ====================================================================
CREATE TRIGGER trg_space_facility_trackable_check
ON SPACE_FACILITY
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN FACILITY_CATALOG fc ON fc.catalog_id = i.catalog_id
        WHERE fc.is_trackable = 1
          AND i.quantity > (
              SELECT COUNT(*)
              FROM FACILITY_ASSET fa
              WHERE fa.space_code = i.space_code
                AND fa.catalog_id = i.catalog_id
          )
    )
    BEGIN
        RAISERROR('For trackable facility types, quantity in SPACE_FACILITY must not exceed the actual number of registered assets (FACILITY_ASSET) for the given space and catalog.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- ====================================================================
-- END OF DDL SCRIPT
-- ====================================================================
