-- ============================================================
-- Database Implementation — Campus Space Management System
-- ============================================================
-- Step 5: Database Definition (DDL)
-- Target: Microsoft SQL Server (T-SQL)
-- ============================================================

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

-- ============================================================
-- Drop existing tables in reverse dependency order
-- ============================================================
IF OBJECT_ID(N'dbo.MAINTENANCE', N'U') IS NOT NULL DROP TABLE dbo.MAINTENANCE;
IF OBJECT_ID(N'dbo.USAGE_SESSION', N'U') IS NOT NULL DROP TABLE dbo.USAGE_SESSION;
IF OBJECT_ID(N'dbo.APPROVAL', N'U') IS NOT NULL DROP TABLE dbo.APPROVAL;
IF OBJECT_ID(N'dbo.BOOKING', N'U') IS NOT NULL DROP TABLE dbo.BOOKING;
IF OBJECT_ID(N'dbo.FACILITY_ASSET', N'U') IS NOT NULL DROP TABLE dbo.FACILITY_ASSET;
IF OBJECT_ID(N'dbo.SPACE_FACILITY', N'U') IS NOT NULL DROP TABLE dbo.SPACE_FACILITY;
IF OBJECT_ID(N'dbo.FACILITY_CATALOG', N'U') IS NOT NULL DROP TABLE dbo.FACILITY_CATALOG;
IF OBJECT_ID(N'dbo.SPACE', N'U') IS NOT NULL DROP TABLE dbo.SPACE;
IF OBJECT_ID(N'dbo.[USER]', N'U') IS NOT NULL DROP TABLE dbo.[USER];
GO

-- ============================================================
-- USER
-- ============================================================
CREATE TABLE dbo.[USER] (
    user_id           NVARCHAR(50)   NOT NULL,
    full_name         NVARCHAR(100)  NOT NULL,
    email             NVARCHAR(255)  NOT NULL,
    phone_number      NVARCHAR(20)   NULL,
    role              NVARCHAR(30)   NOT NULL,
    department        NVARCHAR(100)  NOT NULL,
    account_status    NVARCHAR(20)   NOT NULL DEFAULT 'active',
    CONSTRAINT pk_user PRIMARY KEY (user_id),
    CONSTRAINT uq_user_email UNIQUE (email),
    CONSTRAINT ck_user_role CHECK (role IN (
        'student','lecturer','teaching_assistant',
        'facility_staff','department_administrator','facility_manager'
    )),
    CONSTRAINT ck_user_account_status CHECK (account_status IN (
        'active','inactive','suspended'
    ))
);
GO

-- ============================================================
-- SPACE
-- ============================================================
CREATE TABLE dbo.SPACE (
    space_code        NVARCHAR(20)   NOT NULL,
    space_name        NVARCHAR(100)  NOT NULL,
    space_type        NVARCHAR(30)   NOT NULL,
    building          NVARCHAR(100)  NOT NULL,
    floor             INT            NOT NULL,
    room_number       NVARCHAR(20)   NOT NULL,
    capacity          INT            NOT NULL,
    current_status    NVARCHAR(20)   NOT NULL DEFAULT 'available',
    usage_policy      NVARCHAR(MAX)  NULL,
    CONSTRAINT pk_space PRIMARY KEY (space_code),
    CONSTRAINT uq_space_location UNIQUE (building, floor, room_number),
    CONSTRAINT ck_space_type CHECK (space_type IN (
        'auditorium','classroom','computer_laboratory',
        'project_laboratory','meeting_room','student_workspace'
    )),
    CONSTRAINT ck_space_current_status CHECK (current_status IN (
        'available','in_use','under_maintenance','temporarily_closed','retired'
    )),
    CONSTRAINT ck_space_capacity CHECK (capacity > 0)
);
GO

-- ============================================================
-- FACILITY_CATALOG
-- ============================================================
CREATE TABLE dbo.FACILITY_CATALOG (
    catalog_id        NVARCHAR(20)   NOT NULL,
    name              NVARCHAR(100)  NOT NULL,
    description       NVARCHAR(500)  NULL,
    is_trackable      BIT            NOT NULL DEFAULT 0,
    CONSTRAINT pk_facility_catalog PRIMARY KEY (catalog_id),
    CONSTRAINT uq_facility_catalog_name UNIQUE (name)
);
GO

-- ============================================================
-- SPACE_FACILITY (Associative Entity — M:N with quantity)
-- ============================================================
CREATE TABLE dbo.SPACE_FACILITY (
    space_code        NVARCHAR(20)   NOT NULL,
    catalog_id        NVARCHAR(20)   NOT NULL,
    quantity          INT            NOT NULL DEFAULT 1,
    CONSTRAINT pk_space_facility PRIMARY KEY (space_code, catalog_id),
    CONSTRAINT fk_space_facility_space FOREIGN KEY (space_code)
        REFERENCES dbo.SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_space_facility_catalog FOREIGN KEY (catalog_id)
        REFERENCES dbo.FACILITY_CATALOG(catalog_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ck_space_facility_quantity CHECK (quantity > 0)
);
GO

-- ============================================================
-- FACILITY_ASSET (Trackable assets)
-- ============================================================
CREATE TABLE dbo.FACILITY_ASSET (
    asset_id          INT            NOT NULL IDENTITY(1,1),
    catalog_id        NVARCHAR(20)   NOT NULL,
    space_code        NVARCHAR(20)   NOT NULL,
    asset_tag         NVARCHAR(50)   NOT NULL,
    status            NVARCHAR(20)   NOT NULL DEFAULT 'working',
    CONSTRAINT pk_facility_asset PRIMARY KEY (asset_id),
    CONSTRAINT uq_facility_asset_tag UNIQUE (asset_tag),
    CONSTRAINT fk_facility_asset_catalog FOREIGN KEY (catalog_id)
        REFERENCES dbo.FACILITY_CATALOG(catalog_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_facility_asset_space FOREIGN KEY (space_code)
        REFERENCES dbo.SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT ck_facility_asset_status CHECK (status IN (
        'working','damaged','under_repair','retired'
    ))
);
GO

-- ============================================================
-- BOOKING
-- ============================================================
CREATE TABLE dbo.BOOKING (
    booking_id            INT            NOT NULL IDENTITY(1,1),
    user_id               NVARCHAR(50)   NOT NULL,
    space_code            NVARCHAR(20)   NOT NULL,
    requested_start_time  DATETIME2      NOT NULL,
    requested_end_time    DATETIME2      NOT NULL,
    purpose               NVARCHAR(500)  NOT NULL,
    expected_participants INT            NOT NULL,
    booking_type          NVARCHAR(30)   NOT NULL,
    status                NVARCHAR(20)   NOT NULL DEFAULT 'pending',
    CONSTRAINT pk_booking PRIMARY KEY (booking_id),
    CONSTRAINT fk_booking_user FOREIGN KEY (user_id)
        REFERENCES dbo.[USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_booking_space FOREIGN KEY (space_code)
        REFERENCES dbo.SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT ck_booking_type CHECK (booking_type IN (
        'lecture','examination','seminar','workshop',
        'meeting','student_activity','administrative_event'
    )),
    CONSTRAINT ck_booking_status CHECK (status IN (
        'pending','approved','rejected','cancelled',
        'checked_in','completed','no_show'
    )),
    CONSTRAINT ck_booking_participants CHECK (expected_participants > 0),
    CONSTRAINT ck_booking_time_range CHECK (requested_end_time > requested_start_time)
);
GO

-- ============================================================
-- APPROVAL (1:1 with BOOKING)
-- ============================================================
CREATE TABLE dbo.APPROVAL (
    approval_id       INT            NOT NULL IDENTITY(1,1),
    booking_id        INT            NOT NULL,
    staff_id          NVARCHAR(50)   NOT NULL,
    decision          NVARCHAR(10)   NOT NULL,
    decision_time     DATETIME2      NOT NULL,
    decision_note     NVARCHAR(500)  NULL,
    rejection_reason  NVARCHAR(500)  NULL,
    CONSTRAINT pk_approval PRIMARY KEY (approval_id),
    CONSTRAINT uq_approval_booking UNIQUE (booking_id),
    CONSTRAINT fk_approval_booking FOREIGN KEY (booking_id)
        REFERENCES dbo.BOOKING(booking_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_approval_staff FOREIGN KEY (staff_id)
        REFERENCES dbo.[USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ck_approval_decision CHECK (decision IN ('approved','rejected')),
    CONSTRAINT ck_approval_rejection_reason CHECK (
        (decision = 'rejected' AND rejection_reason IS NOT NULL)
        OR (decision = 'approved')
    )
);
GO

-- ============================================================
-- USAGE_SESSION (1:1 with BOOKING)
-- ============================================================
CREATE TABLE dbo.USAGE_SESSION (
    session_id        INT            NOT NULL IDENTITY(1,1),
    booking_id        INT            NOT NULL,
    checked_in_by     NVARCHAR(50)   NOT NULL,
    actual_start_time DATETIME2      NOT NULL,
    initial_condition NVARCHAR(500)  NULL,
    actual_end_time   DATETIME2      NULL,
    final_condition   NVARCHAR(500)  NULL,
    usage_notes       NVARCHAR(500)  NULL,
    CONSTRAINT pk_usage_session PRIMARY KEY (session_id),
    CONSTRAINT uq_usage_session_booking UNIQUE (booking_id),
    CONSTRAINT fk_usage_session_booking FOREIGN KEY (booking_id)
        REFERENCES dbo.BOOKING(booking_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_usage_session_checked_in_by FOREIGN KEY (checked_in_by)
        REFERENCES dbo.[USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ck_usage_session_time_range CHECK (
        actual_end_time IS NULL OR actual_end_time > actual_start_time
    )
);
GO

-- ============================================================
-- MAINTENANCE
-- ============================================================
CREATE TABLE dbo.MAINTENANCE (
    maintenance_id    INT            NOT NULL IDENTITY(1,1),
    space_code        NVARCHAR(20)   NOT NULL,
    reporter_id       NVARCHAR(50)   NOT NULL,
    assigned_staff_id NVARCHAR(50)   NULL,
    problem_description NVARCHAR(500) NOT NULL,
    problem_type      NVARCHAR(30)   NOT NULL,
    start_time        DATETIME2      NOT NULL,
    completion_time   DATETIME2      NULL,
    status            NVARCHAR(20)   NOT NULL DEFAULT 'reported',
    result_note       NVARCHAR(500)  NULL,
    CONSTRAINT pk_maintenance PRIMARY KEY (maintenance_id),
    CONSTRAINT fk_maintenance_space FOREIGN KEY (space_code)
        REFERENCES dbo.SPACE(space_code)
        ON UPDATE CASCADE
        ON DELETE NO ACTION,
    CONSTRAINT fk_maintenance_reporter FOREIGN KEY (reporter_id)
        REFERENCES dbo.[USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_maintenance_assigned_staff FOREIGN KEY (assigned_staff_id)
        REFERENCES dbo.[USER](user_id)
        ON UPDATE NO ACTION
        ON DELETE SET NULL,
    CONSTRAINT ck_maintenance_problem_type CHECK (problem_type IN (
        'broken_projector','ac_failure','damaged_furniture',
        'cleaning','network_problem','other'
    )),
    CONSTRAINT ck_maintenance_status CHECK (status IN (
        'reported','in_progress','completed','cancelled'
    )),
    CONSTRAINT ck_maintenance_time_range CHECK (
        completion_time IS NULL OR completion_time >= start_time
    )
);
GO

-- ============================================================
-- TRIGGER: Validate SPACE_FACILITY quantity against FACILITY_ASSET
-- ============================================================
-- Ensures that for trackable facility types (is_trackable = 1),
-- the recorded quantity does not exceed the actual number of
-- physical assets registered for that space and catalog.
-- ============================================================
CREATE TRIGGER trg_space_facility_validate_quantity
ON dbo.SPACE_FACILITY
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN dbo.FACILITY_CATALOG fc ON fc.catalog_id = i.catalog_id
        WHERE fc.is_trackable = 1
          AND i.quantity > (
              SELECT COUNT(*)
              FROM dbo.FACILITY_ASSET fa
              WHERE fa.space_code = i.space_code
                AND fa.catalog_id = i.catalog_id
          )
    )
    BEGIN
        RAISERROR('Quantity exceeds the number of registered trackable assets for this space and catalog type.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

PRINT 'Database implementation completed successfully.';
GO
