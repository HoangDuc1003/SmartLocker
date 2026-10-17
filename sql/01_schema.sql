-- ============================================================
-- 01_schema.sql  Smart Locker, PRJ301 FALL2026, topic 01
-- Run the whole file in SSMS. It drops and recreates the database,
-- so run it again whenever you want a clean start.
--   Part A  database
--   Part B  the 14 shared tables of the assignment (copied from De-01, Workshop 1, step 2)
--   Part C  the 4 tables of the topic, trigger and view of the assignment
--   Part D  our additions: areas, banks, account funds, cards, plans, deposits, remote commands
--   Part E  seed data and the Audit_Append procedure
-- ============================================================

-- ===== Part A. Database =====
USE master;
GO
IF DB_ID('PRJ301_LOCKER') IS NOT NULL
BEGIN
    ALTER DATABASE PRJ301_LOCKER SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PRJ301_LOCKER;
END
GO
CREATE DATABASE PRJ301_LOCKER;
GO
USE PRJ301_LOCKER;
GO
-- filtered indexes (used below) need these two settings when rows are written
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ===== Part B. The 14 shared tables, as given in the assignment =====
CREATE TABLE Users (
    user_id       INT IDENTITY PRIMARY KEY,
    username      NVARCHAR(50) UNIQUE NOT NULL,
    password_hash CHAR(60) NOT NULL,                  -- BCrypt, always 60 characters
    full_name     NVARCHAR(80),
    status        NVARCHAR(20) DEFAULT 'ACTIVE',      -- ACTIVE, LOCKED, DISABLED
    balance       BIGINT NOT NULL CONSTRAINT DF_Users_balance DEFAULT 0,
    created_at    DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE Roles (
    role_id   INT IDENTITY PRIMARY KEY,
    role_name NVARCHAR(30) UNIQUE NOT NULL);

CREATE TABLE UserRole (
    user_id INT REFERENCES Users,
    role_id INT REFERENCES Roles,
    PRIMARY KEY (user_id, role_id));

CREATE TABLE Permissions (
    perm_id  INT IDENTITY PRIMARY KEY,
    resource NVARCHAR(40),
    action   NVARCHAR(10),                            -- READ or WRITE
    UNIQUE (resource, action));

CREATE TABLE RolePerm (
    role_id INT REFERENCES Roles,
    perm_id INT REFERENCES Permissions,
    PRIMARY KEY (role_id, perm_id));

CREATE TABLE Device (
    device_id     INT IDENTITY PRIMARY KEY,
    device_code   NVARCHAR(30) UNIQUE,
    location      NVARCHAR(80),
    firmware      NVARCHAR(20),
    status        NVARCHAR(20) DEFAULT 'ACTIVE',      -- ACTIVE, MAINTENANCE, OFFLINE
    control_owner INT NULL REFERENCES Users,
    last_seen     DATETIME2 NULL,
    api_key_hash  CHAR(64) NOT NULL);                 -- SHA-256 of the key, never the key itself

CREATE TABLE SensorType (
    sensor_type_id INT IDENTITY PRIMARY KEY,
    name      NVARCHAR(40),
    unit      NVARCHAR(20),
    min_valid FLOAT,
    max_valid FLOAT);

CREATE TABLE Calibration (
    calib_id       INT IDENTITY PRIMARY KEY,
    device_id      INT REFERENCES Device,
    sensor_type_id INT REFERENCES SensorType,
    offset_val FLOAT,
    scale_val  FLOAT,
    version    INT,
    valid_until DATE,
    created_by INT REFERENCES Users);

CREATE TABLE OperatingProfile (
    profile_id  INT IDENTITY PRIMARY KEY,
    device_id   INT REFERENCES Device,
    params_json NVARCHAR(MAX),
    updated_by  INT REFERENCES Users,
    updated_at  DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE Alert (
    alert_id   INT IDENTITY PRIMARY KEY,
    device_id  INT REFERENCES Device,
    session_id BIGINT,
    source     NVARCHAR(10),                          -- RULE or ML
    label      NVARCHAR(40),
    risk_score FLOAT NULL,
    status     NVARCHAR(20) DEFAULT 'OPEN',           -- OPEN, RESOLVED
    created_at DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE AlertEvidence (
    evidence_id INT IDENTITY PRIMARY KEY,
    alert_id    INT REFERENCES Alert,
    item        NVARCHAR(60),
    value_text  NVARCHAR(200));

CREATE TABLE MaintenanceTicket (
    ticket_id   INT IDENTITY PRIMARY KEY,
    alert_id    INT NULL REFERENCES Alert,
    device_id   INT REFERENCES Device,
    assigned_to INT REFERENCES Users,
    note        NVARCHAR(400),
    status      NVARCHAR(20) DEFAULT 'OPEN',          -- OPEN, CLOSED
    opened_at   DATETIME2 DEFAULT SYSUTCDATETIME(),
    closed_at   DATETIME2 NULL);

CREATE TABLE AuditLog (
    audit_id      BIGINT IDENTITY PRIMARY KEY,
    actor_user_id INT,
    action        NVARCHAR(50),
    object_type   NVARCHAR(50),
    object_id     BIGINT,
    diff_json     NVARCHAR(MAX),
    ts            DATETIME2(7) DEFAULT SYSUTCDATETIME(),
    row_hash      CHAR(64) NULL);

CREATE TABLE HashChain (
    anchor_id  BIGINT IDENTITY PRIMARY KEY,
    audit_id   BIGINT REFERENCES AuditLog,
    prev_hash  CHAR(64),
    chain_hash CHAR(64));
GO

-- ===== Part C. The 4 tables of the topic, as given in the assignment =====
CREATE TABLE LockerSession (
    session_id     BIGINT IDENTITY PRIMARY KEY,
    device_id      INT NOT NULL REFERENCES Device,
    device_seq     INT NOT NULL,                      -- sequence number on the device, prevents duplicates
    measured_at    DATETIME2 NOT NULL,                -- time measured on the device
    ingested_at    DATETIME2 DEFAULT SYSUTCDATETIME(),-- time received by the server
    door_open_sec  FLOAT,
    weight_delta_g FLOAT,
    unlock_count   INT,
    rfid_ok        BIT,
    stay_min       FLOAT,
    UNIQUE (device_id, device_seq));

CREATE TABLE LockerSessionLabel (
    session_id BIGINT PRIMARY KEY REFERENCES LockerSession,
    label      NVARCHAR(40) NOT NULL,                 -- NORMAL, OVERDUE, FORCED_OPEN, WRONG_USER, ITEM_LEFT, SUSPECTED_SPOOF
    labeled_by INT REFERENCES Users,
    labeled_at DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE LockerSessionReading (
    reading_id     BIGINT IDENTITY PRIMARY KEY,
    session_id     BIGINT REFERENCES LockerSession,
    sensor_type_id INT REFERENCES SensorType,
    measured_at    DATETIME2,
    value          FLOAT);

CREATE TABLE LockerSlot (
    locker_slot_id INT IDENTITY PRIMARY KEY,
    slot_code      NVARCHAR(20),
    bank_id        INT,
    size_cm        NVARCHAR(20),
    status         NVARCHAR(20),
    created_at     DATETIME2 DEFAULT SYSUTCDATETIME());
GO

-- sessions are append-only: block every update and delete
CREATE TRIGGER trg_LockerSession_AppendOnly ON LockerSession INSTEAD OF UPDATE, DELETE AS
BEGIN
    RAISERROR(N'Session records are append-only', 16, 1);
END;
GO

-- ===== Part D. Our additions =====

-- D1. Locker areas (Library, Dormitory ...) and banks (one cabinet of doors)
CREATE TABLE LockerArea (
    area_id   INT IDENTITY PRIMARY KEY,
    area_code NVARCHAR(16) UNIQUE NOT NULL,           -- LIB, DOMA, CANT, GYM, OPS
    name      NVARCHAR(80) NOT NULL,
    location  NVARCHAR(120) NULL,
    is_active BIT NOT NULL DEFAULT 1);

CREATE TABLE LockerBank (
    bank_id   INT IDENTITY PRIMARY KEY,
    bank_code NVARCHAR(20) UNIQUE NOT NULL,           -- LIB-A
    name      NVARCHAR(40) NOT NULL,                  -- Bank A
    area_id   INT NOT NULL REFERENCES LockerArea,
    device_id INT NULL REFERENCES Device,             -- NULL = drawn for illustration, no hardware
    door_rows INT NOT NULL DEFAULT 4,                 -- doors per column, used to draw the cabinet
    status    NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX UX_LockerBank_device ON LockerBank(device_id) WHERE device_id IS NOT NULL;

-- D2. Extra columns on the assignment's tables
IF COL_LENGTH('dbo.Users', 'email') IS NULL
    ALTER TABLE Users ADD email NVARCHAR(150) NULL;
IF COL_LENGTH('dbo.Users', 'phone') IS NULL
    ALTER TABLE Users ADD phone NVARCHAR(20) NULL;
IF COL_LENGTH('dbo.Users', 'area_id') IS NULL
    ALTER TABLE Users ADD area_id INT NULL CONSTRAINT FK_Users_Area REFERENCES LockerArea(area_id);
IF COL_LENGTH('dbo.Users', 'balance') IS NULL
    ALTER TABLE Users ADD balance BIGINT NOT NULL CONSTRAINT DF_Users_balance DEFAULT 0;
GO
-- a column added by ALTER cannot be used in the same batch, hence the GO above
CREATE UNIQUE INDEX UX_Users_email ON Users(email) WHERE email IS NOT NULL;

ALTER TABLE Roles ADD rank_no INT NOT NULL CONSTRAINT DF_Roles_rank DEFAULT 99;   -- 1 = highest role
GO

ALTER TABLE LockerSlot ALTER COLUMN slot_code NVARCHAR(20) NOT NULL;
ALTER TABLE LockerSlot ALTER COLUMN bank_id INT NOT NULL;
ALTER TABLE LockerSlot ALTER COLUMN status NVARCHAR(20) NOT NULL;
ALTER TABLE LockerSlot ADD size_code CHAR(1) NOT NULL CONSTRAINT DF_LockerSlot_size DEFAULT 'S';   -- S, M, L
GO
ALTER TABLE LockerSlot ADD CONSTRAINT DF_LockerSlot_status DEFAULT 'AVAILABLE' FOR status;
ALTER TABLE LockerSlot ADD CONSTRAINT FK_LockerSlot_Bank FOREIGN KEY (bank_id) REFERENCES LockerBank(bank_id);
ALTER TABLE LockerSlot ADD CONSTRAINT UQ_LockerSlot_code UNIQUE (bank_id, slot_code);
ALTER TABLE LockerSlot ADD CONSTRAINT CK_LockerSlot_status
    CHECK (status IN ('AVAILABLE', 'RESERVED', 'OCCUPIED', 'MAINTENANCE'));

-- the device tells us which slot, which card and how the door was opened
ALTER TABLE LockerSession ADD
    slot_id     INT NULL CONSTRAINT FK_LockerSession_Slot REFERENCES LockerSlot(locker_slot_id),
    card_uid    NVARCHAR(32) NULL,
    open_source NVARCHAR(10) NULL,                    -- RFID or REMOTE
    command_id  BIGINT NULL;                          -- no foreign key on purpose: a forged id must still be stored as evidence
GO

-- D3. Cards, plans, deposits, remote commands
CREATE TABLE UserCard (
    card_id   INT IDENTITY PRIMARY KEY,
    card_uid  NVARCHAR(32) UNIQUE NOT NULL,           -- RC522 uid in hex
    user_id   INT NOT NULL REFERENCES Users,
    status    NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, LOST, BLOCKED
    issued_at DATETIME2 DEFAULT SYSUTCDATETIME(),
    lost_at   DATETIME2 NULL);

-- Funds belong to the user account; an RFID card is not required.
CREATE TABLE TopupRequest (
    request_id    INT IDENTITY PRIMARY KEY,
    user_id       INT NOT NULL REFERENCES Users,
    amount        BIGINT NOT NULL CHECK (amount >= 1000),
    transfer_code NVARCHAR(80) NOT NULL UNIQUE,
    qr_url        NVARCHAR(1000) NOT NULL,
    status        NVARCHAR(20) NOT NULL DEFAULT 'PENDING'
                  CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    created_at    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    approved_at   DATETIME2 NULL,
    approved_by   INT NULL REFERENCES Users,
    note          NVARCHAR(400) NULL);

CREATE TABLE StoragePlan (
    plan_id      INT IDENTITY PRIMARY KEY,
    plan_name    NVARCHAR(40) NOT NULL,
    duration_min INT NOT NULL,
    grace_min    INT NOT NULL DEFAULT 10,
    price        INT NOT NULL DEFAULT 0,
    is_active    BIT NOT NULL DEFAULT 1);

CREATE TABLE Deposit (
    deposit_id   BIGINT IDENTITY PRIMARY KEY,
    user_id      INT NOT NULL REFERENCES Users,
    slot_id      INT NOT NULL REFERENCES LockerSlot(locker_slot_id),
    plan_id      INT NOT NULL REFERENCES StoragePlan,
    card_id      INT NULL REFERENCES UserCard,
    paid_amount  BIGINT NOT NULL DEFAULT 0,
    status       NVARCHAR(20) NOT NULL
                 CHECK (status IN ('RESERVED', 'ACTIVE', 'COMPLETED', 'NO_SHOW', 'CANCELLED')),
    reserved_at  DATETIME2 DEFAULT SYSUTCDATETIME(),
    hold_until   DATETIME2 NULL,                      -- a reservation expires here
    started_at   DATETIME2 NULL,
    due_at       DATETIME2 NULL,                      -- online extension moves this forward
    ended_at     DATETIME2 NULL,
    extend_count INT NOT NULL DEFAULT 0);
-- the database itself refuses a second open booking for one slot or one user
CREATE UNIQUE INDEX UX_Deposit_slot_open ON Deposit(slot_id) WHERE status IN ('RESERVED', 'ACTIVE');
CREATE UNIQUE INDEX UX_Deposit_user_open ON Deposit(user_id) WHERE status IN ('RESERVED', 'ACTIVE');

CREATE TABLE RemoteCommand (
    command_id   BIGINT IDENTITY PRIMARY KEY,
    device_id    INT NOT NULL REFERENCES Device,
    slot_id      INT NOT NULL REFERENCES LockerSlot(locker_slot_id),
    action       NVARCHAR(20) NOT NULL DEFAULT 'UNLOCK',
    reason       NVARCHAR(200) NOT NULL,
    requested_by INT NOT NULL REFERENCES Users,
    status       NVARCHAR(20) NOT NULL DEFAULT 'PENDING',   -- PENDING, SENT, DONE, EXPIRED
    created_at   DATETIME2 DEFAULT SYSUTCDATETIME(),
    expires_at   DATETIME2 NOT NULL,
    sent_at      DATETIME2 NULL,
    done_at      DATETIME2 NULL,
    session_id   BIGINT NULL);                              -- the session that used the command
GO

-- ===== Part E. Views =====

-- features for the machine learning step; sessions that are not user behaviour are left out
CREATE VIEW v_LockerSession_Features AS
SELECT s.session_id, s.device_id, s.door_open_sec, s.weight_delta_g, s.unlock_count, s.rfid_ok, s.stay_min, l.label
FROM LockerSession s
JOIN LockerSessionLabel l ON l.session_id = s.session_id
WHERE ISNULL(s.open_source, N'RFID') <> N'REMOTE'        -- a staff remote open is not a user
  AND NOT EXISTS (SELECT 1 FROM Alert a                  -- a broken sensor says nothing about the user
                  WHERE a.session_id = s.session_id AND a.label = N'SENSOR_FAULT');
GO

-- the colour of every door on the map, computed in one place
CREATE VIEW v_LockerSlotMap AS
SELECT s.locker_slot_id AS slot_id, s.slot_code, s.size_code, s.size_cm,
       b.bank_id, b.bank_code, b.area_id,
       v.device_id, v.status AS device_status,
       CASE
           WHEN v.status = N'OFFLINE'     THEN N'OFFLINE'
           WHEN s.status = N'MAINTENANCE' THEN N'MAINTENANCE'
           WHEN EXISTS (SELECT 1 FROM LockerSession ls JOIN Alert a ON a.session_id = ls.session_id
                        WHERE ls.slot_id = s.locker_slot_id AND a.status = N'OPEN') THEN N'ALERT'
           WHEN EXISTS (SELECT 1 FROM Deposit d
                        WHERE d.slot_id = s.locker_slot_id AND d.status = N'ACTIVE'
                          AND d.due_at < SYSUTCDATETIME()) THEN N'OVERDUE'
           ELSE s.status
       END AS display_status
FROM LockerSlot s
JOIN LockerBank b ON b.bank_id = s.bank_id
LEFT JOIN Device v ON v.device_id = b.device_id;
GO

-- ===== Part F. Audit_Append: one row of the log, chained to the row before it =====
CREATE OR ALTER PROCEDURE Audit_Append
    @actor INT, @action NVARCHAR(50), @objectType NVARCHAR(50), @objectId BIGINT, @diff NVARCHAR(MAX)
AS
BEGIN
    SET XACT_ABORT ON;
    BEGIN TRAN;
    DECLARE @id BIGINT, @ts DATETIME2(7), @prev CHAR(64), @row NVARCHAR(MAX), @hash CHAR(64);

    INSERT INTO AuditLog (actor_user_id, action, object_type, object_id, diff_json)
    VALUES (@actor, @action, @objectType, @objectId, @diff);
    SET @id = SCOPE_IDENTITY();
    SELECT @ts = ts FROM AuditLog WHERE audit_id = @id;

    -- lock the chain tail so two writers cannot fork the chain
    SELECT TOP 1 @prev = chain_hash FROM HashChain WITH (UPDLOCK, HOLDLOCK) ORDER BY anchor_id DESC;
    SET @prev = ISNULL(@prev, REPLICATE('0', 64));

    SET @row = CONCAT(@id, '|', CONVERT(NVARCHAR(33), @ts, 126), '|', @actor, '|', @action, '|',
                      @objectType, '|', @objectId, '|', ISNULL(@diff, ''), '|', @prev);
    SET @hash = LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', @row), 2));

    UPDATE AuditLog SET row_hash = @hash WHERE audit_id = @id;
    INSERT INTO HashChain (audit_id, prev_hash, chain_hash) VALUES (@id, @prev, @hash);
    COMMIT;
END;
GO

-- ===== Part G. Seed data =====

-- G1. Roles and permissions. Every resource gets a READ and a WRITE permission.
INSERT INTO Roles (role_name, rank_no) VALUES
    (N'ADMIN', 1), (N'OPERATOR', 2), (N'TECHNICIAN', 3), (N'AUDITOR', 4), (N'END_USER', 5);

INSERT INTO Permissions (resource, action)
SELECT r.res, a.act
FROM (VALUES (N'USER'), (N'ROLE'), (N'DEVICE'), (N'SENSOR_TYPE'), (N'CALIBRATION'), (N'PROFILE'),
             (N'LOCKERSESSION'), (N'LOCKERSLOT'), (N'ALERT'), (N'MAINTENANCE'), (N'AUDIT'),
             (N'MAP'), (N'AREA'), (N'LOCKERBANK'), (N'STORAGEPLAN'), (N'USERCARD'), (N'MYCARD'),
             (N'DEPOSIT'), (N'BOOKING'), (N'COMMAND'), (N'TOPUP')) r(res)
CROSS JOIN (VALUES (N'READ'), (N'WRITE')) a(act);

-- who may do what. R = READ only, RW = READ and WRITE, * = every resource.
-- Replace this table with the course-wide role rules if they differ.
INSERT INTO RolePerm (role_id, perm_id)
SELECT r.role_id, p.perm_id
FROM (VALUES
    (N'ADMIN',      N'*',             N'RW'),
    (N'OPERATOR',   N'USER',          N'RW'), (N'OPERATOR', N'ROLE',        N'R'),
    (N'OPERATOR',   N'DEVICE',        N'R'),  (N'OPERATOR', N'SENSOR_TYPE', N'R'),
    (N'OPERATOR',   N'CALIBRATION',   N'R'),  (N'OPERATOR', N'PROFILE',     N'R'),
    (N'OPERATOR',   N'LOCKERSESSION', N'R'),  (N'OPERATOR', N'LOCKERSLOT',  N'RW'),
    (N'OPERATOR',   N'ALERT',         N'RW'), (N'OPERATOR', N'MAINTENANCE', N'R'),
    (N'OPERATOR',   N'AUDIT',         N'R'),  (N'OPERATOR', N'MAP',         N'R'),
    (N'OPERATOR',   N'AREA',          N'RW'), (N'OPERATOR', N'LOCKERBANK',  N'RW'),
    (N'OPERATOR',   N'STORAGEPLAN',   N'RW'), (N'OPERATOR', N'USERCARD',    N'RW'),
    (N'OPERATOR',   N'DEPOSIT',       N'RW'), (N'OPERATOR', N'COMMAND',     N'RW'),
    (N'OPERATOR',   N'TOPUP',         N'RW'),
    (N'TECHNICIAN', N'DEVICE',        N'RW'),
    (N'TECHNICIAN', N'SENSOR_TYPE',   N'RW'), (N'TECHNICIAN', N'CALIBRATION', N'RW'),
    (N'TECHNICIAN', N'PROFILE',       N'R'),  (N'TECHNICIAN', N'LOCKERSESSION', N'R'),
    (N'TECHNICIAN', N'LOCKERSLOT',    N'R'),  (N'TECHNICIAN', N'ALERT',     N'RW'),
    (N'TECHNICIAN', N'MAINTENANCE',   N'RW'), (N'TECHNICIAN', N'MAP',       N'R'),
    (N'TECHNICIAN', N'AREA',          N'R'),  (N'TECHNICIAN', N'LOCKERBANK', N'R'),
    (N'TECHNICIAN', N'DEPOSIT',       N'R'),
    (N'AUDITOR',    N'*',             N'R'),
    (N'END_USER',   N'MAP',           N'R'),  (N'END_USER', N'BOOKING',     N'RW'),
    (N'END_USER',   N'MYCARD',        N'RW'), (N'END_USER', N'TOPUP',       N'RW')
) g(role_name, resource, mode)
JOIN Roles r ON r.role_name = g.role_name
JOIN Permissions p ON (g.resource = N'*' OR p.resource = g.resource)
                  AND (p.action = N'READ' OR g.mode = N'RW');
GO

-- G2. Areas, device, banks and slots
INSERT INTO Permissions (resource, action) VALUES (N'SLOTSTATUS', N'WRITE');
INSERT INTO RolePerm (role_id, perm_id)
SELECT r.role_id, p.perm_id FROM Roles r CROSS JOIN Permissions p
WHERE r.role_name IN (N'ADMIN', N'TECHNICIAN') AND p.resource = N'SLOTSTATUS';

INSERT INTO LockerArea (area_code, name, location) VALUES
    (N'LIB',  N'Library',     N'Library, 1st floor'),
    (N'DOMA', N'Dormitory A', N'Dorm A lobby'),
    (N'CANT', N'Canteen',     N'Next to the canteen entrance'),
    (N'GYM',  N'Sports Hall', N'Sports hall changing room'),
    (N'OPS',  N'Operations',  N'Staff office, no locker slots');

-- the one real device. Its key is device-1-api-key, only the SHA-256 is stored.
-- the key is hashed as VARCHAR (no N prefix) so SQL Server and Java hash the same bytes
INSERT INTO Device (device_code, location, firmware, api_key_hash)
VALUES (N'LOCKER-01', N'Library, 1st floor', N'1.0',
        LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', 'device-1-api-key'), 2)));

INSERT INTO LockerBank (bank_code, name, area_id, device_id, door_rows)
SELECT v.code, v.name, a.area_id, v.device_id, v.door_rows
FROM (VALUES (N'LIB-A',  N'Bank A', N'LIB',  1,    2), (N'LIB-B',  N'Bank B', N'LIB',  NULL, 4),
             (N'DOMA-A', N'Bank A', N'DOMA', NULL, 4), (N'DOMA-B', N'Bank B', N'DOMA', NULL, 4),
             (N'CANT-A', N'Bank A', N'CANT', NULL, 4),
             (N'GYM-A',  N'Bank A', N'GYM',  NULL, 4), (N'GYM-B',  N'Bank B', N'GYM',  NULL, 4)
     ) v(code, name, area_code, device_id, door_rows)
JOIN LockerArea a ON a.area_code = v.area_code;

-- 90 doors: the slot code is the bank letter and a number, A01, A02 ...
WITH n AS (SELECT TOP (20) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO LockerSlot (slot_code, bank_id, size_cm, size_code, status)
SELECT RIGHT(b.bank_code, 1) + RIGHT('0' + CAST(n.i AS VARCHAR(2)), 2), b.bank_id, N'30x30x45', 'S', N'AVAILABLE'
FROM LockerBank b
JOIN (VALUES (N'LIB-A', 4), (N'LIB-B', 16), (N'DOMA-A', 20), (N'DOMA-B', 10),
             (N'CANT-A', 15), (N'GYM-A', 16), (N'GYM-B', 9)) c(code, cnt) ON c.code = b.bank_code
JOIN n ON n.i <= c.cnt;

-- a few tall doors
UPDATE s SET size_code = 'L', size_cm = N'40x40x90'
FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE (b.bank_code = N'DOMA-B' AND s.slot_code IN ('B03', 'B06', 'B07', 'B08', 'B09', 'B10'))
   OR (b.bank_code = N'CANT-A' AND s.slot_code IN ('A03', 'A06', 'A09', 'A12', 'A15'))
   OR (b.bank_code = N'GYM-B'  AND s.slot_code IN ('B03', 'B06', 'B09'));
GO

-- G3. Users. 'system' goes first so its user_id is 1: Java uses that id for automatic actions.
-- Every sample account shares one BCrypt hash of the password 123456. Accounts created
-- through the application get their own salt, as they should.
INSERT INTO Users (username, password_hash, full_name, status)
VALUES (N'system', REPLICATE('x', 60), N'System account', N'DISABLED');   -- cannot log in

DECLARE @h CHAR(60) = '$2a$10$iz5TJTP.i9YQlKBSU4GzKO.rbQIU.PocHFDv24b8Xsfm8hC2Rwp3m';
INSERT INTO Users (username, password_hash, full_name, email, phone, area_id, status)
SELECT v.username, @h, v.full_name, v.username + N'@smartlocker.edu.vn', v.phone, a.area_id, v.status
FROM (VALUES
    (N'admin',     N'Administrator',     NULL,         N'OPS',  N'ACTIVE'),
    (N'operator1', N'Tran Thi Hoa',      N'0901000002', N'OPS',  N'ACTIVE'),
    (N'operator2', N'Le Van Minh',       N'0901000003', N'OPS',  N'ACTIVE'),
    (N'tech1',     N'Pham Quoc Bao',     NULL,         N'OPS',  N'ACTIVE'),
    (N'tech2',     N'Vo Thi Lan',        N'0901000005', N'OPS',  N'ACTIVE'),
    (N'auditor1',  N'Nguyen Thanh Tung', NULL,         N'OPS',  N'ACTIVE'),
    (N'auditor2',  N'Do Thi Mai',        N'0901000007', N'OPS',  N'ACTIVE'),
    (N'student1',  N'Nguyen Van An',     N'0901000008', N'LIB',  N'ACTIVE'),
    (N'student2',  N'Tran Minh Chau',    NULL,         N'DOMA', N'ACTIVE'),
    (N'student3',  N'Le Hoang Nam',      N'0901000010', N'CANT', N'ACTIVE'),
    (N'student4',  N'Pham Thu Ha',       N'0901000011', N'GYM',  N'ACTIVE'),
    (N'student5',  N'Dang Quoc Huy',     NULL,         N'LIB',  N'ACTIVE'),
    (N'student6',  N'Ngo Bao Tram',      N'0901000013', N'DOMA', N'ACTIVE'),
    (N'student7',  N'Huynh Gia Bao',     N'0901000014', N'LIB',  N'ACTIVE'),
    (N'student8',  N'Vu Ngoc Anh',       NULL,         N'GYM',  N'ACTIVE'),
    (N'locked1',   N'Bui Van Khoa',      N'0901000016', N'DOMA', N'LOCKED')
) v(username, full_name, phone, area_code, status)
JOIN LockerArea a ON a.area_code = v.area_code;

INSERT INTO UserRole (user_id, role_id)
SELECT u.user_id, r.role_id
FROM Users u
JOIN Roles r ON r.role_name =
     CASE WHEN u.username = N'admin'                  THEN N'ADMIN'
          WHEN u.username LIKE N'operator%'           THEN N'OPERATOR'
          WHEN u.username LIKE N'tech%'               THEN N'TECHNICIAN'
          WHEN u.username LIKE N'auditor%'            THEN N'AUDITOR'
          WHEN u.username LIKE N'student%' OR u.username = N'locked1' THEN N'END_USER' END
WHERE u.username <> N'system';
GO

-- G4. Plans, sensors, calibration, cards, two deposits
INSERT INTO StoragePlan (plan_name, duration_min, grace_min, price) VALUES
    (N'2 hours', 120, 10, 5000),
    (N'4 hours', 240, 10, 9000),
    (N'Day pass', 1440, 30, 25000),
    (N'Demo 2 minutes', 2, 1, 0);        -- makes OVERDUE appear quickly in the video

INSERT INTO SensorType (name, unit, min_valid, max_valid) VALUES
    (N'DOOR', N's', 0, 3600), (N'WEIGHT', N'g', -200, 20000), (N'STAY', N'min', 0, 10080);

-- without this row every session becomes SENSOR_FAULT
INSERT INTO Calibration (device_id, sensor_type_id, offset_val, scale_val, version, valid_until, created_by)
SELECT 1, sensor_type_id, 0, 1, 1, DATEADD(MONTH, 3, CAST(SYSUTCDATETIME() AS DATE)),
       (SELECT user_id FROM Users WHERE username = N'admin')
FROM SensorType WHERE name = N'WEIGHT';

INSERT INTO UserCard (card_uid, user_id)
SELECT v.uid, u.user_id
FROM (VALUES (N'04A1B2C3', N'student1'), (N'0499AABB', N'student2'), (N'04C3D4E5', N'student3'),
             (N'04F5A6B7', N'student4'), (N'04112233', N'student7')) v(uid, username)
JOIN Users u ON u.username = v.username;

-- student1 is using LIB-A A02, student7 has reserved LIB-A A03
INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, started_at, due_at)
SELECT u.user_id, s.locker_slot_id, 1, c.card_id, N'ACTIVE',
       DATEADD(MINUTE, -78, SYSUTCDATETIME()), DATEADD(MINUTE, 42, SYSUTCDATETIME())
FROM Users u JOIN UserCard c ON c.user_id = u.user_id
JOIN LockerBank b ON b.bank_code = N'LIB-A' JOIN LockerSlot s ON s.bank_id = b.bank_id AND s.slot_code = 'A02'
WHERE u.username = N'student1';

INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, hold_until)
SELECT u.user_id, s.locker_slot_id, 1, c.card_id, N'RESERVED', DATEADD(MINUTE, 9, SYSUTCDATETIME())
FROM Users u JOIN UserCard c ON c.user_id = u.user_id
JOIN LockerBank b ON b.bank_code = N'LIB-A' JOIN LockerSlot s ON s.bank_id = b.bank_id AND s.slot_code = 'A03'
WHERE u.username = N'student7';

UPDATE s SET status = N'OCCUPIED' FROM LockerSlot s JOIN Deposit d ON d.slot_id = s.locker_slot_id WHERE d.status = N'ACTIVE';
UPDATE s SET status = N'RESERVED' FROM LockerSlot s JOIN Deposit d ON d.slot_id = s.locker_slot_id WHERE d.status = N'RESERVED';
UPDATE s SET status = N'MAINTENANCE' FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE b.bank_code = N'LIB-B' AND s.slot_code IN ('B09', 'B11', 'B15');
GO

-- first row of the audit chain
EXEC Audit_Append 1, N'SEED', N'DATABASE', 0, N'Initial data loaded';
GO

