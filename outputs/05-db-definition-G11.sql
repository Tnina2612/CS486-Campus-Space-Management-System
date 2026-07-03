USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'CampusSpaceManagement')
BEGIN
    ALTER DATABASE [CampusSpaceManagement] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [CampusSpaceManagement];
END
GO

CREATE DATABASE [CampusSpaceManagement];
GO

USE [CampusSpaceManagement];
GO

-- Drop objects in reverse FK dependency order
IF OBJECT_ID(N'dbo.TRG_ValidateFacilityQuantity', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_ValidateFacilityQuantity;
IF OBJECT_ID(N'dbo.usage_sessions', N'U') IS NOT NULL        DROP TABLE dbo.usage_sessions;
IF OBJECT_ID(N'dbo.approvals', N'U') IS NOT NULL              DROP TABLE dbo.approvals;
IF OBJECT_ID(N'dbo.maintenance_records', N'U') IS NOT NULL    DROP TABLE dbo.maintenance_records;
IF OBJECT_ID(N'dbo.facility_assets', N'U') IS NOT NULL        DROP TABLE dbo.facility_assets;
IF OBJECT_ID(N'dbo.space_facility', N'U') IS NOT NULL         DROP TABLE dbo.space_facility;
IF OBJECT_ID(N'dbo.bookings', N'U') IS NOT NULL               DROP TABLE dbo.bookings;
IF OBJECT_ID(N'dbo.facility_catalog', N'U') IS NOT NULL       DROP TABLE dbo.facility_catalog;
IF OBJECT_ID(N'dbo.spaces', N'U') IS NOT NULL                 DROP TABLE dbo.spaces;
IF OBJECT_ID(N'dbo.users', N'U') IS NOT NULL                  DROP TABLE dbo.users;
GO

-- Table Definitions

CREATE TABLE dbo.users (
    user_id         INT           IDENTITY(1,1) PRIMARY KEY,
    full_name       NVARCHAR(255) NOT NULL,
    email           NVARCHAR(255) NOT NULL,
    phone_number    NVARCHAR(20)  NOT NULL,
    role            NVARCHAR(50)  NOT NULL
        CHECK (role IN (
            'Student', 'Lecturer', 'Teaching Assistant',
            'Facility Staff', 'Department Administrator', 'Facility Manager'
        )),
    department      NVARCHAR(100) NOT NULL,
    account_status  NVARCHAR(20)  NOT NULL DEFAULT 'Active',

    CONSTRAINT UQ_users_email UNIQUE (email)
);
GO

CREATE TABLE dbo.spaces (
    space_id       INT           IDENTITY(1,1) PRIMARY KEY,
    space_code     NVARCHAR(20)  NOT NULL,
    space_name     NVARCHAR(100) NOT NULL,
    space_type     NVARCHAR(50)  NOT NULL,
    building       NVARCHAR(100) NOT NULL,
    floor          INT           NOT NULL,
    room_number    NVARCHAR(20)  NOT NULL,
    capacity       INT           NOT NULL CHECK (capacity > 0),
    current_status NVARCHAR(20)  NOT NULL
        CHECK (current_status IN (
            'Available', 'In Use', 'Under Maintenance',
            'Temporarily Closed', 'Retired'
        )),
    usage_policy   NVARCHAR(MAX),

    CONSTRAINT UQ_spaces_space_code UNIQUE (space_code)
);
GO

CREATE TABLE dbo.facility_catalog (
    catalog_id    INT           IDENTITY(1,1) PRIMARY KEY,
    facility_name NVARCHAR(100) NOT NULL,
    is_trackable  BIT           NOT NULL
);
GO

CREATE TABLE dbo.bookings (
    booking_id            INT          IDENTITY(1,1) PRIMARY KEY,
    user_id               INT          NOT NULL,
    space_id              INT          NOT NULL,
    start_time            DATETIME2    NOT NULL,
    end_time              DATETIME2    NOT NULL,
    purpose               NVARCHAR(50) NOT NULL
        CHECK (purpose IN (
            'Lecture', 'Examination', 'Seminar', 'Workshop',
            'Meeting', 'Student Activity', 'Administrative Event'
        )),
    expected_participants INT          CHECK (expected_participants > 0),
    status                NVARCHAR(20) NOT NULL
        CHECK (status IN (
            'Pending', 'Approved', 'Rejected', 'Cancelled',
            'Checked In', 'Completed', 'No-show'
        )),

    CONSTRAINT CK_bookings_chrono CHECK (end_time > start_time),

    CONSTRAINT FK_bookings_users
        FOREIGN KEY (user_id)  REFERENCES dbo.users(user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_bookings_spaces
        FOREIGN KEY (space_id) REFERENCES dbo.spaces(space_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);
GO

CREATE TABLE dbo.approvals (
    approval_id      INT           IDENTITY(1,1) PRIMARY KEY,
    booking_id       INT           NOT NULL,
    staff_id         INT           NOT NULL,
    decision_time    DATETIME2     NOT NULL,
    decision_note    NVARCHAR(MAX),
    rejection_reason NVARCHAR(MAX),

    CONSTRAINT UQ_approvals_booking_id UNIQUE (booking_id),

    CONSTRAINT FK_approvals_bookings
        FOREIGN KEY (booking_id) REFERENCES dbo.bookings(booking_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_approvals_users
        FOREIGN KEY (staff_id)   REFERENCES dbo.users(user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);
GO

CREATE TABLE dbo.usage_sessions (
    session_id        INT           IDENTITY(1,1) PRIMARY KEY,
    booking_id        INT           NOT NULL,
    staff_id          INT           NULL,
    actual_start_time DATETIME2     NULL,
    actual_end_time   DATETIME2     NULL,
    initial_condition NVARCHAR(MAX),
    final_condition   NVARCHAR(MAX),
    usage_notes       NVARCHAR(MAX),

    CONSTRAINT CK_usage_sessions_chrono CHECK (actual_end_time > actual_start_time),

    CONSTRAINT UQ_usage_sessions_booking_id UNIQUE (booking_id),

    CONSTRAINT FK_usage_sessions_bookings
        FOREIGN KEY (booking_id) REFERENCES dbo.bookings(booking_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_usage_sessions_users
        FOREIGN KEY (staff_id)   REFERENCES dbo.users(user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);
GO

CREATE TABLE dbo.maintenance_records (
    maintenance_id     INT           IDENTITY(1,1) PRIMARY KEY,
    space_id           INT           NOT NULL,
    reporter_id        INT           NOT NULL,
    assigned_staff_id  INT           NULL,
    problem_description NVARCHAR(MAX) NOT NULL,
    start_time         DATETIME2     NOT NULL,
    completion_time    DATETIME2     NULL,
    status             NVARCHAR(20)  NOT NULL,
    result_note        NVARCHAR(MAX),

    CONSTRAINT FK_maintenance_records_spaces
        FOREIGN KEY (space_id) REFERENCES dbo.spaces(space_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_maintenance_records_reporter
        FOREIGN KEY (reporter_id) REFERENCES dbo.users(user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_maintenance_records_staff
        FOREIGN KEY (assigned_staff_id) REFERENCES dbo.users(user_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);
GO

CREATE TABLE dbo.space_facility (
    space_id   INT NOT NULL,
    catalog_id INT NOT NULL,
    quantity   INT NOT NULL CHECK (quantity >= 0),

    CONSTRAINT PK_space_facility PRIMARY KEY (space_id, catalog_id),

    CONSTRAINT FK_space_facility_spaces
        FOREIGN KEY (space_id)   REFERENCES dbo.spaces(space_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_space_facility_catalog
        FOREIGN KEY (catalog_id) REFERENCES dbo.facility_catalog(catalog_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);
GO

CREATE TABLE dbo.facility_assets (
    asset_id   INT          IDENTITY(1,1) PRIMARY KEY,
    asset_tag  NVARCHAR(50) NOT NULL,
    space_id   INT          NOT NULL,
    catalog_id INT          NOT NULL,
    status     NVARCHAR(50) NOT NULL,

    CONSTRAINT UQ_facility_assets_asset_tag UNIQUE (asset_tag),

    CONSTRAINT FK_facility_assets_spaces
        FOREIGN KEY (space_id)   REFERENCES dbo.spaces(space_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    CONSTRAINT FK_facility_assets_catalog
        FOREIGN KEY (catalog_id) REFERENCES dbo.facility_catalog(catalog_id)
        ON UPDATE NO ACTION ON DELETE NO ACTION
);
GO

-- Data Integrity Trigger

CREATE TRIGGER dbo.TRG_ValidateFacilityQuantity
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
              FROM dbo.facility_assets fa
              WHERE fa.space_id   = i.space_id
                AND fa.catalog_id = i.catalog_id
          )
    )
    BEGIN
        RAISERROR('Trackable facility quantity exceeds the number of registered physical assets for this space and catalog.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO
