-- =============================================================
-- CS486 Campus Space Management System
-- Database Implementation (DDL) for Microsoft SQL Server
-- =============================================================

-- Drop tables in reverse dependency order (CASCADE is simulated
-- by dropping FK-dependent tables first).
DROP TABLE IF EXISTS maintenance_record;
DROP TABLE IF EXISTS booking_session;
DROP TABLE IF EXISTS booking_approval;
DROP TABLE IF EXISTS booking_request;
DROP TABLE IF EXISTS space_facility;
DROP TABLE IF EXISTS facility;
DROP TABLE IF EXISTS space;
DROP TABLE IF EXISTS [user];

-- =============================================================
-- 1. USER
-- =============================================================
CREATE TABLE [user] (
    user_id          INT             NOT NULL IDENTITY(1,1),
    full_name        NVARCHAR(100)   NOT NULL,
    email            NVARCHAR(255)   NOT NULL,
    phone_number     NVARCHAR(20)    NULL,
    [role]           NVARCHAR(30)    NOT NULL,
    department       NVARCHAR(100)   NOT NULL,
    account_status   NVARCHAR(20)    NOT NULL DEFAULT 'active',

    CONSTRAINT pk_user PRIMARY KEY (user_id),
    CONSTRAINT uq_user_email UNIQUE (email),
    CONSTRAINT ck_user_role CHECK ([role] IN (
        'student', 'lecturer', 'teaching_assistant',
        'facility_staff', 'department_administrator', 'facility_manager'
    )),
    CONSTRAINT ck_user_account_status CHECK (account_status IN (
        'active', 'inactive', 'suspended'
    ))
);

-- =============================================================
-- 2. SPACE
-- =============================================================
CREATE TABLE space (
    space_code       NVARCHAR(20)    NOT NULL,
    space_name       NVARCHAR(100)   NOT NULL,
    space_type       NVARCHAR(30)    NOT NULL,
    building         NVARCHAR(100)   NOT NULL,
    floor            INT             NOT NULL,
    room_number      NVARCHAR(20)    NOT NULL,
    capacity         INT             NOT NULL,
    current_status   NVARCHAR(30)    NOT NULL DEFAULT 'available',
    usage_policy     NVARCHAR(MAX)   NULL,

    CONSTRAINT pk_space PRIMARY KEY (space_code),
    CONSTRAINT uq_space_location UNIQUE (building, floor, room_number),
    CONSTRAINT ck_space_type CHECK (space_type IN (
        'auditorium', 'classroom', 'computer_lab',
        'project_lab', 'meeting_room', 'student_workspace'
    )),
    CONSTRAINT ck_space_capacity CHECK (capacity > 0),
    CONSTRAINT ck_space_current_status CHECK (current_status IN (
        'available', 'in_use', 'under_maintenance',
        'temporarily_closed', 'retired'
    ))
);

-- =============================================================
-- 3. FACILITY
-- =============================================================
CREATE TABLE facility (
    facility_id      INT             NOT NULL IDENTITY(1,1),
    facility_name    NVARCHAR(100)   NOT NULL,
    [description]    NVARCHAR(255)   NULL,

    CONSTRAINT pk_facility PRIMARY KEY (facility_id),
    CONSTRAINT uq_facility_name UNIQUE (facility_name)
);

-- =============================================================
-- 4. SPACE_FACILITY (Junction)
-- =============================================================
CREATE TABLE space_facility (
    space_code       NVARCHAR(20)    NOT NULL,
    facility_id      INT             NOT NULL,

    CONSTRAINT pk_space_facility PRIMARY KEY (space_code, facility_id),
    CONSTRAINT fk_space_facility_space FOREIGN KEY (space_code)
        REFERENCES space(space_code) ON DELETE CASCADE,
    CONSTRAINT fk_space_facility_facility FOREIGN KEY (facility_id)
        REFERENCES facility(facility_id) ON DELETE CASCADE
);

-- =============================================================
-- 5. BOOKING_REQUEST
-- =============================================================
CREATE TABLE booking_request (
    booking_id              INT             NOT NULL IDENTITY(1,1),
    requester_id            INT             NOT NULL,
    space_code              NVARCHAR(20)    NOT NULL,
    requested_start_time    DATETIME2       NOT NULL,
    requested_end_time      DATETIME2       NOT NULL,
    purpose                 NVARCHAR(30)    NOT NULL,
    expected_participants   INT             NOT NULL,
    [status]                NVARCHAR(20)    NOT NULL DEFAULT 'pending',
    submitted_at            DATETIME2       NOT NULL DEFAULT GETDATE(),

    CONSTRAINT pk_booking_request PRIMARY KEY (booking_id),
    CONSTRAINT fk_booking_request_requester FOREIGN KEY (requester_id)
        REFERENCES [user](user_id),
    CONSTRAINT fk_booking_request_space FOREIGN KEY (space_code)
        REFERENCES space(space_code),
    CONSTRAINT ck_booking_request_time CHECK (requested_end_time > requested_start_time),
    CONSTRAINT ck_booking_request_participants CHECK (expected_participants > 0),
    CONSTRAINT ck_booking_request_purpose CHECK (purpose IN (
        'lecture', 'examination', 'seminar', 'workshop',
        'meeting', 'student_activity', 'administrative_event'
    )),
    CONSTRAINT ck_booking_request_status CHECK ([status] IN (
        'pending', 'approved', 'rejected', 'cancelled',
        'checked_in', 'completed', 'no_show'
    ))
);

-- =============================================================
-- 6. BOOKING_APPROVAL
-- =============================================================
CREATE TABLE booking_approval (
    approval_id         INT             NOT NULL IDENTITY(1,1),
    booking_id          INT             NOT NULL,
    staff_id            INT             NOT NULL,
    decision            NVARCHAR(10)    NOT NULL,
    decision_time       DATETIME2       NOT NULL DEFAULT GETDATE(),
    decision_note       NVARCHAR(MAX)   NULL,
    rejection_reason    NVARCHAR(MAX)   NULL,

    CONSTRAINT pk_booking_approval PRIMARY KEY (approval_id),
    CONSTRAINT uq_booking_approval_booking UNIQUE (booking_id),
    CONSTRAINT fk_booking_approval_booking FOREIGN KEY (booking_id)
        REFERENCES booking_request(booking_id),
    CONSTRAINT fk_booking_approval_staff FOREIGN KEY (staff_id)
        REFERENCES [user](user_id),
    CONSTRAINT ck_booking_approval_decision CHECK (decision IN ('approved', 'rejected')),
    CONSTRAINT ck_booking_approval_rejection_reason CHECK (
        decision = 'rejected' AND rejection_reason IS NOT NULL
        OR decision = 'approved'
    )
);

-- =============================================================
-- 7. BOOKING_SESSION
-- =============================================================
CREATE TABLE booking_session (
    session_id          INT             NOT NULL IDENTITY(1,1),
    booking_id          INT             NOT NULL,
    actual_start_time   DATETIME2       NOT NULL,
    checkin_by          INT             NOT NULL,
    initial_condition   NVARCHAR(MAX)   NULL,
    actual_end_time     DATETIME2       NULL,
    completed_by        INT             NULL,
    final_condition     NVARCHAR(MAX)   NULL,
    usage_notes         NVARCHAR(MAX)   NULL,

    CONSTRAINT pk_booking_session PRIMARY KEY (session_id),
    CONSTRAINT uq_booking_session_booking UNIQUE (booking_id),
    CONSTRAINT fk_booking_session_booking FOREIGN KEY (booking_id)
        REFERENCES booking_request(booking_id),
    CONSTRAINT fk_booking_session_checkin FOREIGN KEY (checkin_by)
        REFERENCES [user](user_id),
    CONSTRAINT fk_booking_session_checkout FOREIGN KEY (completed_by)
        REFERENCES [user](user_id),
    CONSTRAINT ck_booking_session_end_time CHECK (
        actual_end_time IS NULL OR actual_end_time > actual_start_time
    )
);

-- =============================================================
-- 8. MAINTENANCE_RECORD
-- =============================================================
CREATE TABLE maintenance_record (
    maintenance_id      INT             NOT NULL IDENTITY(1,1),
    space_code          NVARCHAR(20)    NOT NULL,
    reporter_id         INT             NOT NULL,
    assigned_staff_id   INT             NULL,
    problem_description NVARCHAR(MAX)   NOT NULL,
    problem_type        NVARCHAR(30)    NOT NULL,
    start_time          DATETIME2       NOT NULL DEFAULT GETDATE(),
    completion_time     DATETIME2       NULL,
    [status]            NVARCHAR(20)    NOT NULL DEFAULT 'reported',
    result_note         NVARCHAR(MAX)   NULL,

    CONSTRAINT pk_maintenance_record PRIMARY KEY (maintenance_id),
    CONSTRAINT fk_maintenance_space FOREIGN KEY (space_code)
        REFERENCES space(space_code),
    CONSTRAINT fk_maintenance_reporter FOREIGN KEY (reporter_id)
        REFERENCES [user](user_id),
    CONSTRAINT fk_maintenance_assigned FOREIGN KEY (assigned_staff_id)
        REFERENCES [user](user_id),
    CONSTRAINT ck_maintenance_problem_type CHECK (problem_type IN (
        'broken_projector', 'ac_failure', 'damaged_furniture',
        'cleaning_issue', 'network_problem', 'other'
    )),
    CONSTRAINT ck_maintenance_status CHECK ([status] IN (
        'reported', 'in_progress', 'completed', 'cancelled'
    )),
    CONSTRAINT ck_maintenance_completion_time CHECK (
        completion_time IS NULL OR completion_time >= start_time
    )
);

-- =============================================================
-- INDEXES for performance
-- =============================================================

-- Index to speed up overlap checks for booking requests
CREATE INDEX ix_booking_request_space_status
    ON booking_request (space_code, [status])
    INCLUDE (requested_start_time, requested_end_time);

-- Index on maintenance by space and active status
CREATE INDEX ix_maintenance_space_active
    ON maintenance_record (space_code, [status])
    WHERE [status] IN ('reported', 'in_progress');

-- Index for booking history queries
CREATE INDEX ix_booking_request_requester
    ON booking_request (requester_id);

-- Index for approval lookups by staff
CREATE INDEX ix_booking_approval_staff
    ON booking_approval (staff_id);

-- =============================================================
-- (Optional) Triggers for business rules
-- Add these after data is populated if needed:
-- 1. trg_booking_request_no_overlap
-- 2. trg_booking_request_maintenance_check
-- 3. trg_booking_request_space_status_check
-- =============================================================
