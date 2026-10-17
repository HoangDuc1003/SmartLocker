-- ============================================================
-- 02_sample_data.sql: Consolidated Demo Seed Data for SmartLocker
-- PRJ301 FALL2026 - Comprehensive Enterprise Demo Dataset
--
-- Features:
--   1. 100 Demo Accounts distributed across 5 roles:
--      - ADMIN: 10 accounts (Super Admin, Area Managers, Sysadmins)
--      - OPERATOR: 22 accounts (Desk Staff across 5 Campus Areas)
--      - TECHNICIAN: 22 accounts (Hardware & Sensor Maintenance Engineers)
--      - AUDITOR: 16 accounts (Compliance, Security & Financial Inspectors)
--      - END_USER: 30 accounts (Students, Faculty, Regular Members)
--      All sample accounts use password: '123456'
--   2. Multi-day Historical Spread (Past 90 days down to current time):
--      - User registrations distributed from 90 days ago to today
--      - Topup requests across 30 days (PENDING, APPROVED, REJECTED)
--      - Deposits & Bookings (COMPLETED, CANCELLED, NO_SHOW, ACTIVE, OVERDUE, RESERVED)
--      - Hardware Telemetry & Sensor Readings across past 30 days
--      - Security & Anomaly Alerts (OPEN with risk scores, RESOLVED)
--      - Maintenance Tickets assigned to various technicians
--      - Fully validated AuditLog & HashChain cryptographic SHA-256 chain
-- ============================================================

USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET XACT_ABORT ON;
GO

-- Ensure schema prerequisites
IF COL_LENGTH('dbo.Users', 'balance') IS NULL
    ALTER TABLE dbo.Users ADD balance BIGINT NOT NULL CONSTRAINT DF_Users_balance DEFAULT 0;
GO
IF COL_LENGTH('dbo.Deposit', 'paid_amount') IS NULL
    ALTER TABLE dbo.Deposit ADD paid_amount BIGINT NOT NULL DEFAULT 0;
GO
IF COL_LENGTH('dbo.RemoteCommand', 'sent_at') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD sent_at DATETIME2 NULL;
GO
IF OBJECT_ID(N'dbo.PublicSession', N'U') IS NULL
    CREATE TABLE dbo.PublicSession (
        public_id INT IDENTITY PRIMARY KEY,
        door_open_sec FLOAT, weight_delta_g FLOAT, unlock_count INT,
        rfid_ok BIT, stay_min FLOAT, label NVARCHAR(40), sent BIT DEFAULT 0);
GO
IF OBJECT_ID(N'dbo.TopupRequest', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TopupRequest (
        request_id    INT IDENTITY PRIMARY KEY,
        user_id       INT NOT NULL REFERENCES dbo.Users,
        amount        BIGINT NOT NULL CHECK (amount >= 1000),
        transfer_code NVARCHAR(80) NOT NULL UNIQUE,
        qr_url        NVARCHAR(1000) NOT NULL,
        status        NVARCHAR(20) NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
        created_at    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        approved_at   DATETIME2 NULL,
        approved_by   INT NULL REFERENCES dbo.Users,
        note          NVARCHAR(400) NULL);
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT 'Cleaning up previous demo seed data safely...';

    -- Disable append-only trigger for session cleanup
    IF OBJECT_ID(N'dbo.trg_LockerSession_AppendOnly', N'TR') IS NOT NULL
        DISABLE TRIGGER trg_LockerSession_AppendOnly ON dbo.LockerSession;

    DELETE FROM dbo.HashChain;
    DELETE FROM dbo.AuditLog;
    DELETE FROM dbo.AlertEvidence;
    DELETE FROM dbo.MaintenanceTicket;
    DELETE FROM dbo.Alert;
    DELETE FROM dbo.LockerSessionReading;
    DELETE FROM dbo.LockerSessionLabel;
    DELETE FROM dbo.RemoteCommand;
    DELETE FROM dbo.Deposit;
    DELETE FROM dbo.LockerSession;

    IF OBJECT_ID(N'dbo.trg_LockerSession_AppendOnly', N'TR') IS NOT NULL
        ENABLE TRIGGER trg_LockerSession_AppendOnly ON dbo.LockerSession;

    DELETE FROM dbo.TopupRequest;
    DELETE FROM dbo.UserCard;
    DELETE FROM dbo.Calibration;
    DELETE FROM dbo.OperatingProfile;
    DELETE FROM dbo.PublicSession;

    UPDATE dbo.Device SET control_owner = NULL;
    DELETE FROM dbo.UserRole;
    DELETE FROM dbo.Users WHERE username <> N'system';

    -- Reseed user identity so first demo user gets user_id 2
    DBCC CHECKIDENT ('dbo.Users', RESEED, 1);

    -- Reset slot and device statuses
    UPDATE dbo.LockerSlot SET status = N'AVAILABLE';
    UPDATE dbo.Device SET status = N'ACTIVE', last_seen = SYSUTCDATETIME();

    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @pwd CHAR(60) = '$2a$10$iz5TJTP.i9YQlKBSU4GzKO.rbQIU.PocHFDv24b8Xsfm8hC2Rwp3m'; -- 123456

    -- Area IDs
    DECLARE @aLib INT = (SELECT area_id FROM dbo.LockerArea WHERE area_code = N'LIB');
    DECLARE @aDom INT = (SELECT area_id FROM dbo.LockerArea WHERE area_code = N'DOMA');
    DECLARE @aCant INT = (SELECT area_id FROM dbo.LockerArea WHERE area_code = N'CANT');
    DECLARE @aGym INT = (SELECT area_id FROM dbo.LockerArea WHERE area_code = N'GYM');
    DECLARE @aOps INT = (SELECT area_id FROM dbo.LockerArea WHERE area_code = N'OPS');

    -- Role IDs
    DECLARE @rAdmin INT = (SELECT role_id FROM dbo.Roles WHERE role_name = N'ADMIN');
    DECLARE @rOper INT = (SELECT role_id FROM dbo.Roles WHERE role_name = N'OPERATOR');
    DECLARE @rTech INT = (SELECT role_id FROM dbo.Roles WHERE role_name = N'TECHNICIAN');
    DECLARE @rAudit INT = (SELECT role_id FROM dbo.Roles WHERE role_name = N'AUDITOR');
    DECLARE @rUser INT = (SELECT role_id FROM dbo.Roles WHERE role_name = N'END_USER');

    PRINT '1. Seeding 100 Users across 5 Roles with multi-day history...';

    -- Table variable to stage the 100 users
    DECLARE @rawUsers TABLE (
        username NVARCHAR(50),
        full_name NVARCHAR(80),
        role_id INT,
        area_id INT,
        phone NVARCHAR(20),
        status NVARCHAR(20),
        balance BIGINT,
        days_ago INT
    );

    -- 1.1 ADMIN: 10 accounts
    INSERT INTO @rawUsers VALUES
    (N'admin',      N'Nguyễn Hoàng Nam (Super Admin)', @rAdmin, @aOps,  N'0901000001', N'ACTIVE',   500000, 90),
    (N'admin_ops',  N'Trần Quốc Bảo',                 @rAdmin, @aOps,  N'0901000002', N'ACTIVE',   350000, 85),
    (N'admin_lib',  N'Lê Minh Tuấn',                  @rAdmin, @aLib,  N'0901000003', N'ACTIVE',   200000, 80),
    (N'admin_doma', N'Phạm Thu Trang',                @rAdmin, @aDom,  N'0901000004', N'ACTIVE',   200000, 75),
    (N'admin_cant', N'Hoàng Hải Đăng',                @rAdmin, @aCant, N'0901000005', N'ACTIVE',   150000, 70),
    (N'admin_gym',  N'Vũ Đức Anh',                    @rAdmin, @aGym,  N'0901000006', N'ACTIVE',   150000, 65),
    (N'sysadmin1',  N'Phan Trọng Khôi',               @rAdmin, @aOps,  N'0901000007', N'ACTIVE',   300000, 60),
    (N'sysadmin2',  N'Đặng Kim Long',                 @rAdmin, @aOps,  N'0901000008', N'DISABLED', 0,      55),
    (N'manager1',   N'Bùi Gia Huy',                   @rAdmin, @aOps,  N'0901000009', N'ACTIVE',   400000, 50),
    (N'manager2',   N'Đỗ Ngọc Linh',                  @rAdmin, @aOps,  N'0901000010', N'ACTIVE',   250000, 45);

    -- 1.2 OPERATOR: 22 accounts
    INSERT INTO @rawUsers VALUES
    (N'operator1',  N'Trần Thị Hoa',     @rOper, @aOps,  N'0902000001', N'ACTIVE',   100000, 60),
    (N'operator2',  N'Lê Văn Minh',      @rOper, @aOps,  N'0902000002', N'ACTIVE',   100000, 58),
    (N'operator3',  N'Phạm Hồng Nhung',  @rOper, @aLib,  N'0902000003', N'ACTIVE',    50000, 55),
    (N'operator4',  N'Hoàng Quốc Việt',  @rOper, @aLib,  N'0902000004', N'ACTIVE',    50000, 52),
    (N'operator5',  N'Vũ Thùy Chi',      @rOper, @aDom,  N'0902000005', N'ACTIVE',    80000, 50),
    (N'operator6',  N'Phan Minh Khang',  @rOper, @aDom,  N'0902000006', N'ACTIVE',    80000, 48),
    (N'operator7',  N'Đặng Bảo Trâm',    @rOper, @aCant, N'0902000007', N'ACTIVE',    60000, 45),
    (N'operator8',  N'Bùi Thanh Tùng',   @rOper, @aCant, N'0902000008', N'ACTIVE',    60000, 42),
    (N'operator9',  N'Đỗ Khánh Vy',      @rOper, @aGym,  N'0902000009', N'ACTIVE',    70000, 40),
    (N'operator10', N'Ngô Tuấn Kiệt',    @rOper, @aGym,  N'0902000010', N'ACTIVE',    70000, 38),
    (N'operator11', N'Dương Mai Anh',    @rOper, @aLib,  N'0902000011', N'ACTIVE',    50000, 35),
    (N'operator12', N'Lý Hoàng Long',    @rOper, @aDom,  N'0902000012', N'ACTIVE',    50000, 32),
    (N'operator13', N'Nguyễn Thái Sơn',  @rOper, @aCant, N'0902000013', N'ACTIVE',    50000, 30),
    (N'operator14', N'Trần Diệu Huyền',  @rOper, @aGym,  N'0902000014', N'ACTIVE',    50000, 28),
    (N'operator15', N'Lê Công Vinh',     @rOper, @aOps,  N'0902000015', N'ACTIVE',   120000, 25),
    (N'operator16', N'Phạm Hải Yến',     @rOper, @aLib,  N'0902000016', N'ACTIVE',    40000, 22),
    (N'operator17', N'Hoàng Trung Kiên', @rOper, @aDom,  N'0902000017', N'ACTIVE',    40000, 20),
    (N'operator18', N'Vũ Phương Thảo',   @rOper, @aCant, N'0902000018', N'ACTIVE',    40000, 18),
    (N'operator19', N'Phan Đình Trọng',  @rOper, @aGym,  N'0902000019', N'ACTIVE',    40000, 15),
    (N'operator20', N'Đặng Thu Thủy',    @rOper, @aOps,  N'0902000020', N'LOCKED',         0, 12),
    (N'operator21', N'Bùi Văn Tài',      @rOper, @aLib,  N'0902000021', N'ACTIVE',    30000,  8),
    (N'operator22', N'Đỗ Thị Hạnh',      @rOper, @aOps,  N'0902000022', N'DISABLED',      0,  5);

    -- 1.3 TECHNICIAN: 22 accounts
    INSERT INTO @rawUsers VALUES
    (N'tech1',  N'Phạm Quốc Bảo',   @rTech, @aOps,  N'0903000001', N'ACTIVE',   50000, 60),
    (N'tech2',  N'Võ Thị Lan',      @rTech, @aOps,  N'0903000002', N'ACTIVE',   50000, 58),
    (N'tech3',  N'Nguyễn Văn Hùng', @rTech, @aLib,  N'0903000003', N'ACTIVE',   30000, 55),
    (N'tech4',  N'Trần Đức Thịnh',  @rTech, @aLib,  N'0903000004', N'ACTIVE',   30000, 52),
    (N'tech5',  N'Lê Quang Khải',   @rTech, @aDom,  N'0903000005', N'ACTIVE',   40000, 50),
    (N'tech6',  N'Phạm Văn Đạt',    @rTech, @aDom,  N'0903000006', N'ACTIVE',   40000, 47),
    (N'tech7',  N'Hoàng Văn Toàn',  @rTech, @aCant, N'0903000007', N'ACTIVE',   30000, 45),
    (N'tech8',  N'Vũ Đình Phong',   @rTech, @aCant, N'0903000008', N'ACTIVE',   30000, 42),
    (N'tech9',  N'Phan Văn Hậu',    @rTech, @aGym,  N'0903000009', N'ACTIVE',   35000, 40),
    (N'tech10', N'Đặng Hữu Phước',  @rTech, @aGym,  N'0903000010', N'ACTIVE',   35000, 38),
    (N'tech11', N'Bùi Minh Quân',   @rTech, @aOps,  N'0903000011', N'ACTIVE',   60000, 35),
    (N'tech12', N'Đỗ Quốc Cường',   @rTech, @aLib,  N'0903000012', N'ACTIVE',   30000, 32),
    (N'tech13', N'Ngô Xuân Bắc',    @rTech, @aDom,  N'0903000013', N'ACTIVE',   30000, 30),
    (N'tech14', N'Dương Thành Đạt', @rTech, @aCant, N'0903000014', N'ACTIVE',   30000, 27),
    (N'tech15', N'Lý Minh Trí',     @rTech, @aGym,  N'0903000015', N'ACTIVE',   30000, 25),
    (N'tech16', N'Nguyễn Hữu Thắng',@rTech, @aOps,  N'0903000016', N'ACTIVE',   50000, 22),
    (N'tech17', N'Trần Văn Bình',   @rTech, @aLib,  N'0903000017', N'ACTIVE',   25000, 19),
    (N'tech18', N'Lê Văn Cường',    @rTech, @aDom,  N'0903000018', N'ACTIVE',   25000, 16),
    (N'tech19', N'Phạm Tiến Dũng',  @rTech, @aCant, N'0903000019', N'ACTIVE',   25000, 13),
    (N'tech20', N'Hoàng Đình Vũ',   @rTech, @aOps,  N'0903000020', N'LOCKED',        0, 10),
    (N'tech21', N'Vũ Văn Kiên',     @rTech, @aGym,  N'0903000021', N'ACTIVE',   20000,  7),
    (N'tech22', N'Phan Hữu Lợi',    @rTech, @aOps,  N'0903000022', N'DISABLED',     0,  3);

    -- 1.4 AUDITOR: 16 accounts
    INSERT INTO @rawUsers VALUES
    (N'auditor1',  N'Nguyễn Thanh Tùng', @rAudit, @aOps, N'0904000001', N'ACTIVE',   100000, 60),
    (N'auditor2',  N'Đỗ Thị Mai',        @rAudit, @aOps, N'0904000002', N'ACTIVE',   100000, 57),
    (N'auditor3',  N'Trần Văn Khoa',     @rAudit, @aOps, N'0904000003', N'ACTIVE',    80000, 54),
    (N'auditor4',  N'Lê Thị Tuyết',      @rAudit, @aOps, N'0904000004', N'ACTIVE',    80000, 51),
    (N'auditor5',  N'Phạm Quang Minh',   @rAudit, @aOps, N'0904000005', N'ACTIVE',    70000, 48),
    (N'auditor6',  N'Hoàng Diệu Linh',   @rAudit, @aOps, N'0904000006', N'ACTIVE',    70000, 45),
    (N'auditor7',  N'Vũ Quốc Tuấn',      @rAudit, @aOps, N'0904000007', N'ACTIVE',    60000, 42),
    (N'auditor8',  N'Phan Mỹ Duyên',     @rAudit, @aOps, N'0904000008', N'ACTIVE',    60000, 39),
    (N'auditor9',  N'Đặng Tuấn Anh',     @rAudit, @aOps, N'0904000009', N'ACTIVE',    50000, 35),
    (N'auditor10', N'Bùi Thị Hảo',       @rAudit, @aOps, N'0904000010', N'ACTIVE',    50000, 31),
    (N'auditor11', N'Ngô Hải Yến',       @rAudit, @aOps, N'0904000011', N'ACTIVE',    50000, 28),
    (N'auditor12', N'Dương Văn Thành',   @rAudit, @aOps, N'0904000012', N'ACTIVE',    40000, 24),
    (N'auditor13', N'Lý Thùy Dung',      @rAudit, @aOps, N'0904000013', N'ACTIVE',    40000, 20),
    (N'auditor14', N'Nguyễn Trọng Đại',  @rAudit, @aOps, N'0904000014', N'ACTIVE',    30000, 15),
    (N'auditor15', N'Trần Thúy Hằng',    @rAudit, @aOps, N'0904000015', N'LOCKED',         0,  9),
    (N'auditor16', N'Lê Bá Hưng',        @rAudit, @aOps, N'0904000016', N'DISABLED',      0,  4);

    -- 1.5 END_USER: 30 accounts
    INSERT INTO @rawUsers VALUES
    (N'student1',  N'Nguyễn Văn An',   @rUser, @aLib,  N'0905000001', N'ACTIVE',   100000, 60),
    (N'student2',  N'Trần Minh Châu',  @rUser, @aDom,  N'0905000002', N'ACTIVE',   200000, 58),
    (N'student3',  N'Lê Hoàng Nam',    @rUser, @aCant, N'0905000003', N'ACTIVE',   100000, 56),
    (N'student4',  N'Phạm Thu Hà',     @rUser, @aGym,  N'0905000004', N'ACTIVE',   100000, 54),
    (N'student5',  N'Đặng Quốc Huy',   @rUser, @aLib,  N'0905000005', N'ACTIVE',   100000, 52),
    (N'student6',  N'Ngô Bảo Trâm',    @rUser, @aDom,  N'0905000006', N'ACTIVE',   100000, 50),
    (N'student7',  N'Huỳnh Gia Bảo',   @rUser, @aLib,  N'0905000007', N'ACTIVE',   100000, 48),
    (N'student8',  N'Vũ Ngọc Anh',     @rUser, @aGym,  N'0905000008', N'ACTIVE',   100000, 46),
    (N'locked1',   N'Bùi Văn Khoa',    @rUser, @aDom,  N'0905000009', N'LOCKED',         0, 44),
    (N'user1',     N'Hoàng Kim Ngân',  @rUser, @aLib,  N'0905000010', N'ACTIVE',   150000, 42),
    (N'student9',  N'Nguyễn Trọng Đức',@rUser, @aDom,  N'0905000011', N'ACTIVE',    85000, 40),
    (N'student10', N'Trần Quỳnh Nga',  @rUser, @aCant, N'0905000012', N'ACTIVE',   120000, 38),
    (N'student11', N'Lê Tuấn Tú',      @rUser, @aGym,  N'0905000013', N'ACTIVE',    95000, 35),
    (N'student12', N'Phạm Thùy Linh',  @rUser, @aLib,  N'0905000014', N'ACTIVE',    45000, 32),
    (N'student13', N'Hoàng Thái Bình', @rUser, @aDom,  N'0905000015', N'ACTIVE',    90000, 30),
    (N'student14', N'Vũ Thảo Nguyên',  @rUser, @aCant, N'0905000016', N'ACTIVE',   130000, 28),
    (N'student15', N'Phan Minh Trí',   @rUser, @aGym,  N'0905000017', N'ACTIVE',   180000, 25),
    (N'student16', N'Đặng Thị Thắm',   @rUser, @aLib,  N'0905000018', N'ACTIVE',    50000, 22),
    (N'student17', N'Bùi Văn Dũng',    @rUser, @aDom,  N'0905000019', N'ACTIVE',    65000, 20),
    (N'student18', N'Đỗ Minh Quân',    @rUser, @aCant, N'0905000020', N'ACTIVE',    75000, 18),
    (N'student19', N'Ngô Thu Trang',   @rUser, @aGym,  N'0905000021', N'ACTIVE',   110000, 15),
    (N'student20', N'Dương Gia Hân',   @rUser, @aLib,  N'0905000022', N'ACTIVE',    55000, 13),
    (N'student21', N'Lý Hoàng My',     @rUser, @aDom,  N'0905000023', N'ACTIVE',    40000, 11),
    (N'student22', N'Nguyễn Phúc Lâm', @rUser, @aCant, N'0905000024', N'ACTIVE',    90000,  9),
    (N'student23', N'Trần Bảo Uyên',   @rUser, @aGym,  N'0905000025', N'ACTIVE',   150000,  7),
    (N'student24', N'Lê Hoàng Phúc',   @rUser, @aLib,  N'0905000026', N'ACTIVE',    25000,  5),
    (N'student25', N'Phạm Thị Diệu',   @rUser, @aDom,  N'0905000027', N'ACTIVE',    35000,  3),
    (N'student26', N'Hoàng Anh Dũng',  @rUser, @aCant, N'0905000028', N'ACTIVE',    10000,  2),
    (N'student27', N'Vũ Văn Phong',    @rUser, @aDom,  N'0905000029', N'DISABLED',      0,  1),
    (N'student28', N'Phan Thanh Thúy', @rUser, @aGym,  N'0905000030', N'LOCKED',         0,  0);

    -- Insert into Users table
    INSERT INTO dbo.Users (username, password_hash, full_name, email, phone, area_id, status, created_at, balance)
    SELECT u.username, @pwd, u.full_name, u.username + N'@smartlocker.edu.vn', u.phone, u.area_id, u.status,
           DATEADD(MINUTE, -(CAST(HASHBYTES('MD5', u.username) AS INT) % 1440), DATEADD(DAY, -u.days_ago, @now)),
           u.balance
    FROM @rawUsers u;

    -- Assign Roles in UserRole
    INSERT INTO dbo.UserRole (user_id, role_id)
    SELECT u.user_id, r.role_id
    FROM dbo.Users u
    JOIN @rawUsers r ON r.username = u.username;

    DECLARE @adminId INT = (SELECT user_id FROM dbo.Users WHERE username = N'admin');
    DECLARE @oper1Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'operator1');
    DECLARE @oper2Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'operator2');
    DECLARE @oper3Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'operator3');
    DECLARE @tech1Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'tech1');
    DECLARE @tech2Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'tech2');
    DECLARE @weightSensor INT = (SELECT sensor_type_id FROM dbo.SensorType WHERE name = N'WEIGHT');

    PRINT '2. Linking Hardware Devices & Calibration...';

    DECLARE @devices TABLE (n INT, code NVARCHAR(30), bank NVARCHAR(20));
    INSERT INTO @devices VALUES
        (1, N'LOCKER-01', N'LIB-A'), (2, N'LOCKER-02', N'LIB-B'),
        (3, N'LOCKER-03', N'DOMA-A'),(4, N'LOCKER-04', N'DOMA-B'),
        (5, N'LOCKER-05', N'CANT-A'),(6, N'LOCKER-06', N'GYM-A'),
        (7, N'LOCKER-07', N'GYM-B'), (8, N'LOCKER-08', N'CANT-B');

    INSERT INTO dbo.Device (device_code, location, firmware, status, last_seen, api_key_hash)
    SELECT v.code, a.location, N'1.2-enterprise', N'ACTIVE', @now,
        LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', 'device-' + CONVERT(VARCHAR(2), v.n) + '-api-key'), 2))
    FROM @devices v
    JOIN dbo.LockerBank b ON b.bank_code = v.bank
    JOIN dbo.LockerArea a ON a.area_id = b.area_id
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Device d WHERE d.device_code = v.code);

    UPDATE b SET device_id = d.device_id
    FROM dbo.LockerBank b
    JOIN @devices v ON v.bank = b.bank_code
    JOIN dbo.Device d ON d.device_code = v.code;

    UPDATE d SET status = N'ACTIVE', last_seen = @now
    FROM dbo.Device d JOIN @devices v ON v.code = d.device_code;

    -- Set demo states for devices
    UPDATE dbo.Device SET control_owner = @oper1Id WHERE device_code = N'LOCKER-02';
    UPDATE dbo.Device SET status = N'MAINTENANCE' WHERE device_code = N'LOCKER-04';
    UPDATE dbo.Device SET status = N'OFFLINE', last_seen = DATEADD(HOUR, -26, @now) WHERE device_code = N'LOCKER-07';

    INSERT INTO dbo.Calibration (device_id, sensor_type_id, offset_val, scale_val, version, valid_until, created_by)
    SELECT d.device_id, @weightSensor, 0, 1, 1, DATEADD(MONTH, 6, CAST(@now AS DATE)), @adminId
    FROM dbo.Device d JOIN @devices v ON v.code = d.device_code
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Calibration c WHERE c.device_id = d.device_id AND c.sensor_type_id = @weightSensor);

    UPDATE c SET valid_until = DATEADD(DAY, -1, CAST(@now AS DATE))
    FROM dbo.Calibration c JOIN dbo.Device d ON d.device_id = c.device_id
    WHERE d.device_code = N'LOCKER-04' AND c.sensor_type_id = @weightSensor;

    INSERT INTO dbo.OperatingProfile (device_id, params_json, updated_by, updated_at)
    SELECT d.device_id, N'{"demo":true,"heartbeat_sec":10,"offline_timeout_sec":90,"item_left_g":50}', @adminId, @now
    FROM dbo.Device d JOIN @devices v ON v.code = d.device_code
    WHERE NOT EXISTS (SELECT 1 FROM dbo.OperatingProfile p WHERE p.device_id = d.device_id);

    PRINT '3. Seeding RFID User Cards...';

    INSERT INTO dbo.UserCard (card_uid, user_id, status, issued_at)
    SELECT v.uid, u.user_id, v.st, DATEADD(DAY, -v.days, @now)
    FROM (VALUES
        (N'04A1B2C3', N'student1',  N'ACTIVE',  60),
        (N'0499AABB', N'student2',  N'ACTIVE',  58),
        (N'04C3D4E5', N'student3',  N'ACTIVE',  56),
        (N'04F5A6B7', N'student4',  N'ACTIVE',  54),
        (N'04556677', N'student5',  N'ACTIVE',  52),
        (N'04778899', N'student6',  N'ACTIVE',  50),
        (N'04112233', N'student7',  N'ACTIVE',  48),
        (N'04334455', N'student8',  N'ACTIVE',  46),
        (N'04E1F201', N'student9',  N'ACTIVE',  40),
        (N'04E1F202', N'student10', N'ACTIVE',  38),
        (N'04E1F203', N'student11', N'ACTIVE',  35),
        (N'04E1F204', N'student12', N'ACTIVE',  32),
        (N'04DE0012', N'student12', N'LOST',    34), -- older lost card
        (N'04E1F205', N'student13', N'BLOCKED', 30),
        (N'04E1F206', N'student14', N'ACTIVE',  28),
        (N'04E1F207', N'student15', N'ACTIVE',  25),
        (N'04E1F208', N'student16', N'ACTIVE',  22),
        (N'04E1F209', N'student17', N'ACTIVE',  20),
        (N'04E1F210', N'student18', N'ACTIVE',  18),
        (N'04E1F211', N'student19', N'ACTIVE',  15),
        (N'04E1F212', N'student20', N'ACTIVE',  13),
        (N'04E1F213', N'student21', N'ACTIVE',  11),
        (N'04E1F214', N'student22', N'ACTIVE',   9),
        (N'04E1F215', N'student23', N'ACTIVE',   7),
        (N'04E1F216', N'student24', N'ACTIVE',   5),
        (N'04E1F217', N'student25', N'ACTIVE',   3),
        (N'04E1F218', N'student26', N'ACTIVE',   2),
        (N'04FF0099', N'user1',     N'ACTIVE',  42)
    ) v(uid, username, st, days)
    JOIN dbo.Users u ON u.username = v.username;

    UPDATE dbo.UserCard SET lost_at = DATEADD(HOUR, -3, @now) WHERE card_uid = N'04DE0012';

    PRINT '4. Seeding 55 Multi-Day Topup Requests (Pending, Approved, Rejected)...';

    ;WITH Nums AS (
        SELECT 1 AS n UNION ALL SELECT n + 1 FROM Nums WHERE n < 55
    )
    INSERT INTO dbo.TopupRequest (user_id, amount, transfer_code, qr_url, status, created_at, approved_at, approved_by, note)
    SELECT
        u.user_id,
        CASE (n.n % 5) WHEN 0 THEN 20000 WHEN 1 THEN 50000 WHEN 2 THEN 100000 WHEN 3 THEN 200000 ELSE 500000 END AS amount,
        N'TOPUP-202610-' + RIGHT(N'000' + CONVERT(NVARCHAR(3), n.n), 3) AS transfer_code,
        N'https://img.vietqr.io/image/MB-0901000001-compact2.png' AS qr_url,
        CASE
            WHEN n.n <= 10 THEN N'PENDING'
            WHEN n.n <= 45 THEN N'APPROVED'
            ELSE N'REJECTED'
        END AS status,
        DATEADD(MINUTE, -(n.n * 73), DATEADD(DAY, -CASE WHEN n.n <= 10 THEN 0 ELSE (n.n - 8) % 28 + 1 END, @now)) AS created_at,
        CASE
            WHEN n.n <= 10 THEN NULL
            ELSE DATEADD(MINUTE, 15 + (n.n % 40), DATEADD(DAY, -(n.n - 8) % 28 - 1, @now))
        END AS approved_at,
        CASE
            WHEN n.n <= 10 THEN NULL
            WHEN n.n % 3 = 0 THEN @adminId
            WHEN n.n % 3 = 1 THEN @oper1Id
            ELSE @oper2Id
        END AS approved_by,
        CASE
            WHEN n.n <= 10 THEN N'Chờ đối soát giao dịch chuyển khoản ngân hàng'
            WHEN n.n <= 45 THEN N'Đã đối soát khớp lệnh và cộng tiền vào ví'
            ELSE N'Từ chối: nội dung chuyển khoản không khớp mã tham chiếu'
        END AS note
    FROM Nums n
    JOIN dbo.Users u ON u.username = N'student' + CONVERT(NVARCHAR(2), (n.n % 26) + 1)
    OPTION (MAXRECURSION 100);

    PRINT '5. Seeding Multi-Day Booking History & Live Locker State...';

    -- plans are looked up by duration, not by name: 07_vietnamese_data.sql renames them
    IF NOT EXISTS (SELECT 1 FROM dbo.StoragePlan WHERE duration_min = 1440)
        INSERT INTO dbo.StoragePlan (plan_name, duration_min, grace_min, price) VALUES (N'Day pass', 1440, 30, 25000);

    DECLARE @plan2h INT = (SELECT TOP 1 plan_id FROM dbo.StoragePlan WHERE duration_min = 120 ORDER BY plan_id);
    DECLARE @plan4h INT = (SELECT TOP 1 plan_id FROM dbo.StoragePlan WHERE duration_min = 240 ORDER BY plan_id);
    DECLARE @planDay INT = (SELECT TOP 1 plan_id FROM dbo.StoragePlan WHERE duration_min = 1440 ORDER BY plan_id);
    IF @plan2h IS NULL SET @plan2h = (SELECT TOP 1 plan_id FROM dbo.StoragePlan ORDER BY plan_id);
    IF @plan4h IS NULL SET @plan4h = @plan2h;
    IF @planDay IS NULL SET @planDay = @plan2h;

    -- 5.1 Historical completed bookings across past 30 days (50 rows)
    ;WITH HistNums AS (
        SELECT 1 AS n UNION ALL SELECT n + 1 FROM HistNums WHERE n < 50
    )
    INSERT INTO dbo.Deposit (user_id, slot_id, plan_id, paid_amount, status, reserved_at, hold_until, started_at, due_at, ended_at)
    SELECT
        u.user_id,
        s.locker_slot_id,
        CASE n.n % 3 WHEN 0 THEN @plan2h WHEN 1 THEN @plan4h ELSE @planDay END,
        CASE n.n % 3 WHEN 0 THEN 5000 WHEN 1 THEN 9000 ELSE 18000 END,
        N'COMPLETED',
        DATEADD(DAY, -(n.n % 28 + 2), DATEADD(HOUR, -(n.n % 12), @now)),
        DATEADD(MINUTE, 15, DATEADD(DAY, -(n.n % 28 + 2), DATEADD(HOUR, -(n.n % 12), @now))),
        DATEADD(MINUTE, 5, DATEADD(DAY, -(n.n % 28 + 2), DATEADD(HOUR, -(n.n % 12), @now))),
        DATEADD(MINUTE, 125, DATEADD(DAY, -(n.n % 28 + 2), DATEADD(HOUR, -(n.n % 12), @now))),
        DATEADD(MINUTE, 95, DATEADD(DAY, -(n.n % 28 + 2), DATEADD(HOUR, -(n.n % 12), @now)))
    FROM HistNums n
    JOIN dbo.Users u ON u.username = N'student' + CONVERT(NVARCHAR(2), (n.n % 25) + 1)
    JOIN dbo.LockerSlot s ON s.locker_slot_id = ((n.n * 3) % 80) + 1
    OPTION (MAXRECURSION 100);

    -- 5.2 Cancelled and No-Show bookings
    ;WITH VoidNums AS (
        SELECT 1 AS n UNION ALL SELECT n + 1 FROM VoidNums WHERE n < 20
    )
    INSERT INTO dbo.Deposit (user_id, slot_id, plan_id, paid_amount, status, reserved_at, hold_until, ended_at)
    SELECT
        u.user_id,
        s.locker_slot_id,
        @plan2h,
        5000,
        CASE WHEN n.n <= 12 THEN N'CANCELLED' ELSE N'NO_SHOW' END,
        DATEADD(DAY, -(n.n % 20 + 3), @now),
        DATEADD(MINUTE, 15, DATEADD(DAY, -(n.n % 20 + 3), @now)),
        DATEADD(MINUTE, CASE WHEN n.n <= 12 THEN 8 ELSE 16 END, DATEADD(DAY, -(n.n % 20 + 3), @now))
    FROM VoidNums n
    JOIN dbo.Users u ON u.username = N'student' + CONVERT(NVARCHAR(2), (n.n % 20) + 5)
    JOIN dbo.LockerSlot s ON s.locker_slot_id = (n.n * 4 % 80) + 1
    OPTION (MAXRECURSION 50);

    -- 5.3 Live Bookings (ACTIVE, OVERDUE, RESERVED)
    -- Target specific slots across different banks to demonstrate the visual map
    DECLARE @liveBookings TABLE (
        username NVARCHAR(50),
        bank_code NVARCHAR(20),
        slot_code NVARCHAR(20),
        st NVARCHAR(20),
        age_min INT,
        due_min INT,
        extend_cnt INT
    );

    INSERT INTO @liveBookings VALUES
    -- Normal ACTIVE (within valid time window)
    (N'student1',  N'LIB-A',  N'A02', N'ACTIVE',   45,  75, 0),
    (N'student2',  N'DOMA-A', N'A01', N'ACTIVE',   30,  90, 0),
    (N'student3',  N'CANT-A', N'A01', N'ACTIVE',   60,  60, 0),
    (N'student4',  N'GYM-A',  N'A01', N'ACTIVE',   15, 105, 0),
    (N'student11', N'DOMA-A', N'A05', N'ACTIVE',   90,  30, 2),
    (N'student12', N'DOMA-A', N'A06', N'ACTIVE',   25,  95, 0),
    (N'student13', N'DOMA-A', N'A07', N'ACTIVE',   20, 100, 0),
    (N'student14', N'DOMA-A', N'A08', N'ACTIVE',   40,  80, 0),
    (N'student20', N'GYM-A',  N'A04', N'ACTIVE',   10, 110, 0),
    (N'student21', N'GYM-A',  N'A05', N'ACTIVE',   30,  90, 0),

    -- OVERDUE ACTIVE (due_min < 0: triggers OVERDUE on Live Dashboard and Map!)
    (N'student5',  N'DOMA-B', N'B01', N'ACTIVE',  180, -60, 0),
    (N'student9',  N'DOMA-A', N'A04', N'ACTIVE',  170, -50, 0),
    (N'student19', N'CANT-A', N'A05', N'ACTIVE',  160, -40, 0),
    (N'student22', N'GYM-B',  N'B04', N'ACTIVE',  190, -70, 0),

    -- RESERVED (holding slot, user about to arrive)
    (N'student7',  N'LIB-A',  N'A03', N'RESERVED',  5,  10, 0),
    (N'student16', N'DOMA-A', N'A10', N'RESERVED',  3,  12, 0),
    (N'student17', N'DOMA-A', N'A11', N'RESERVED',  7,   8, 0),
    (N'student18', N'CANT-A', N'A04', N'RESERVED',  4,  11, 0);

    INSERT INTO dbo.Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, reserved_at, hold_until, started_at, due_at, extend_count)
    SELECT
        u.user_id,
        s.locker_slot_id,
        @plan2h,
        c.card_id,
        5000,
        lb.st,
        DATEADD(MINUTE, -lb.age_min, @now),
        CASE WHEN lb.st = N'RESERVED' THEN DATEADD(MINUTE, lb.due_min, @now) END,
        CASE WHEN lb.st = N'ACTIVE' THEN DATEADD(MINUTE, -lb.age_min, @now) END,
        CASE WHEN lb.st = N'ACTIVE' THEN DATEADD(MINUTE, lb.due_min, @now) END,
        lb.extend_cnt
    FROM @liveBookings lb
    JOIN dbo.Users u ON u.username = lb.username
    JOIN dbo.LockerBank b ON b.bank_code = lb.bank_code
    JOIN dbo.LockerSlot s ON s.bank_id = b.bank_id AND s.slot_code = lb.slot_code
    LEFT JOIN dbo.UserCard c ON c.user_id = u.user_id AND c.status = N'ACTIVE';

    -- Sync LockerSlot statuses with live deposits
    UPDATE s SET status = N'OCCUPIED'
    FROM dbo.LockerSlot s
    JOIN dbo.Deposit d ON d.slot_id = s.locker_slot_id
    WHERE d.status = N'ACTIVE';

    UPDATE s SET status = N'RESERVED'
    FROM dbo.LockerSlot s
    JOIN dbo.Deposit d ON d.slot_id = s.locker_slot_id
    WHERE d.status = N'RESERVED';

    -- Set 4 slots in MAINTENANCE mode for technician testing
    UPDATE s SET status = N'MAINTENANCE'
    FROM dbo.LockerSlot s
    JOIN dbo.LockerBank b ON b.bank_id = s.bank_id
    WHERE (b.bank_code = N'LIB-B' AND s.slot_code IN ('B09', 'B11', 'B15'))
       OR (b.bank_code = N'DOMA-B' AND s.slot_code = 'B04');

    PRINT '6. Seeding 150+ Telemetry Sessions across Devices & Multi-day history...';

    DECLARE @sessions TABLE (session_id BIGINT PRIMARY KEY, label NVARCHAR(40));

    -- Regular background sessions across all 7 devices over past 30 days
    ;WITH SesNums AS (
        SELECT 1 AS n UNION ALL SELECT n + 1 FROM SesNums WHERE n < 140
    )
    INSERT INTO dbo.LockerSession (device_id, device_seq, measured_at, ingested_at, door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source)
    OUTPUT inserted.session_id, N'NORMAL' INTO @sessions
    SELECT
        d.device_id,
        2000 + n.n,
        DATEADD(MINUTE, -(n.n * 35), @now),
        DATEADD(SECOND, 3, DATEADD(MINUTE, -(n.n * 35), @now)),
        3.5 + (n.n % 8),
        -(15.0 + (n.n % 120)),
        1,
        1,
        15.0 + (n.n % 90),
        s.locker_slot_id,
        c.card_uid,
        N'RFID'
    FROM SesNums n
    JOIN dbo.Device d ON d.device_code = N'LOCKER-0' + CONVERT(NVARCHAR(1), (n.n % 7) + 1)
    JOIN dbo.LockerBank b ON b.device_id = d.device_id
    CROSS APPLY (SELECT TOP 1 locker_slot_id FROM dbo.LockerSlot WHERE bank_id = b.bank_id ORDER BY slot_code) s
    LEFT JOIN dbo.UserCard c ON c.card_id = (n.n % 20) + 1
    OPTION (MAXRECURSION 200);

    -- Exceptional sessions with specific labels for AI/Rules and Alerts
    DECLARE @cases TABLE (
        n INT, bank NVARCHAR(20), slot NVARCHAR(20), label NVARCHAR(40),
        door FLOAT, weight FLOAT, unlocks INT, rfid BIT, stay FLOAT,
        card NVARCHAR(32), source NVARCHAR(10), reason NVARCHAR(200)
    );

    INSERT INTO @cases VALUES
    (1,  N'LIB-B',  N'B01', N'FORCED_OPEN',     24.0,     0.0, 4, 0,  20.0, NULL,       N'RFID',   N'Cửa mở khi RFID không hợp lệ (Cạy tủ)'),
    (2,  N'CANT-A', N'A06', N'SUSPECTED_SPOOF',  0.0,   120.0, 1, 1,  20.0, N'04E1F217', N'RFID',   N'Khối lượng thay đổi trong khi cửa báo đóng'),
    (3,  N'DOMA-A', N'A09', N'ITEM_LEFT',        7.0,   220.0, 1, 1,  20.0, N'04E1F207', N'RFID',   N'Còn vật nặng 220g sau khi lấy đồ và đóng cửa'),
    (4,  N'DOMA-A', N'A04', N'OVERDUE',          5.0,     0.0, 1, 1, 170.0, N'04E1F201', N'RFID',   N'Gửi đồ 170 phút, vượt gói 120 phút và ân hạn'),
    (5,  N'DOMA-A', N'A08', N'WRONG_USER',       5.0,     0.0, 1, 1,  20.0, N'04E1F217', N'RFID',   N'Thẻ student25 cố tình quét mở slot của student14'),
    (6,  N'DOMA-A', N'A06', N'LOST_CARD_USED',   5.0,     0.0, 1, 1,  20.0, N'04DE0012', N'RFID',   N'Thẻ đã báo mất được sử dụng lại'),
    (7,  N'DOMA-A', N'A07', N'LOST_CARD_USED',   5.0,     0.0, 1, 1,  20.0, N'04E1F205', N'RFID',   N'Thẻ bị khóa được sử dụng lại'),
    (8,  N'DOMA-B', N'B04', N'SENSOR_FAULT',     5.0,     0.0, 1, 1,  20.0, N'04E1F216', N'RFID',   N'Hiệu chuẩn cảm biến khối lượng đã hết hạn'),
    (9,  N'LIB-B',  N'B04', N'SUSPECTED_SPOOF',  6.0,     0.0, 1, 1,  20.0, NULL,       N'REMOTE', N'Mở từ xa không có lệnh hợp lệ'),
    (10, N'LIB-B',  N'B05', N'SENSOR_FAULT',     5.0,     0.0, 1, 1,  20.0, N'04E1F218', N'RFID',   N'Đồng hồ thiết bị trôi quá 15 phút so với máy chủ'),
    (11, N'LIB-B',  N'B06', N'SENSOR_FAULT',     5.0, 25000.0, 1, 1,  20.0, N'04FF0099', N'RFID',   N'Khối lượng 25000g vượt giới hạn cảm biến'),
    (12, N'GYM-A',  N'A06', N'ML_ANOMALY',      18.0,     0.0, 3, 1, 100.0, N'04E1F210', N'RFID',   N'Mô hình Machine Learning phát hiện hành vi bất thường (Điểm 0.94)');

    INSERT INTO dbo.LockerSession (device_id, device_seq, measured_at, ingested_at, door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source, command_id)
    OUTPUT inserted.session_id, N'CASE' INTO @sessions
    SELECT
        b.device_id,
        9000 + c.n,
        DATEADD(MINUTE, -c.n * 10, @now),
        DATEADD(SECOND, 2, DATEADD(MINUTE, -c.n * 10, @now)),
        c.door, c.weight, c.unlocks, c.rfid, c.stay,
        s.locker_slot_id, c.card, c.source,
        CASE WHEN c.n = 9 THEN 999999 END
    FROM @cases c
    JOIN dbo.LockerBank b ON b.bank_code = c.bank
    JOIN dbo.LockerSlot s ON s.bank_id = b.bank_id AND s.slot_code = c.slot;

    UPDATE x SET label = c.label
    FROM @sessions x
    JOIN dbo.LockerSession s ON s.session_id = x.session_id
    JOIN @cases c ON s.device_seq = 9000 + c.n;

    -- Device 4 sensor fault updates
    UPDATE x SET label = N'SENSOR_FAULT'
    FROM @sessions x
    JOIN dbo.LockerSession s ON s.session_id = x.session_id
    JOIN dbo.Device d ON d.device_id = s.device_id
    WHERE d.device_code = N'LOCKER-04' AND x.label = N'NORMAL';

    INSERT INTO dbo.LockerSessionLabel (session_id, label, labeled_by, labeled_at)
    SELECT x.session_id, x.label, @adminId, @now FROM @sessions x;

    INSERT INTO dbo.LockerSessionReading (session_id, sensor_type_id, measured_at, value)
    SELECT x.session_id, t.sensor_type_id, s.measured_at,
           CASE t.name WHEN N'DOOR' THEN s.door_open_sec WHEN N'WEIGHT' THEN s.weight_delta_g ELSE s.stay_min END
    FROM @sessions x
    JOIN dbo.LockerSession s ON s.session_id = x.session_id
    CROSS JOIN dbo.SensorType t
    WHERE t.name IN (N'DOOR', N'WEIGHT', N'STAY');

    PRINT '7. Seeding Security Alerts & Maintenance Tickets...';

    DECLARE @alerts TABLE (alert_id INT, session_id BIGINT, label NVARCHAR(40));

    -- Insert alerts from cases (OPEN and RESOLVED)
    INSERT INTO dbo.Alert (device_id, session_id, source, label, risk_score, status, created_at)
    OUTPUT inserted.alert_id, inserted.session_id, inserted.label INTO @alerts
    SELECT
        s.device_id,
        s.session_id,
        CASE c.label WHEN N'ML_ANOMALY' THEN N'ML' ELSE N'RULE' END,
        c.label,
        CASE WHEN c.label = N'ML_ANOMALY' THEN 0.94 ELSE 0.85 END,
        CASE WHEN c.label IN (N'OVERDUE', N'WRONG_USER') THEN N'RESOLVED' ELSE N'OPEN' END,
        DATEADD(MINUTE, -c.n * 10, @now)
    FROM @cases c
    JOIN dbo.LockerBank b ON b.bank_code = c.bank
    JOIN dbo.LockerSession s ON s.device_id = b.device_id AND s.device_seq = 9000 + c.n;

    INSERT INTO dbo.AlertEvidence (alert_id, item, value_text)
    SELECT a.alert_id, N'demo_case', c.reason
    FROM @alerts a
    JOIN dbo.LockerSession s ON s.session_id = a.session_id
    JOIN @cases c ON s.device_seq = 9000 + c.n;

    INSERT INTO dbo.AlertEvidence (alert_id, item, value_text)
    SELECT a.alert_id, v.item, v.value
    FROM @alerts a
    JOIN dbo.LockerSession s ON s.session_id = a.session_id
    CROSS APPLY (VALUES
        (N'door_open_sec', CONVERT(NVARCHAR(200), s.door_open_sec)),
        (N'weight_delta_g', CONVERT(NVARCHAR(200), s.weight_delta_g)),
        (N'card_uid', ISNULL(s.card_uid, N'none')),
        (N'open_source', s.open_source)
    ) v(item, value);

    -- Device Offline Alert for LOCKER-07
    DECLARE @offlineDevId INT = (SELECT device_id FROM dbo.Device WHERE device_code = N'LOCKER-07');
    INSERT INTO dbo.Alert (device_id, session_id, source, label, risk_score, status, created_at)
    OUTPUT inserted.alert_id, inserted.session_id, inserted.label INTO @alerts
    VALUES (@offlineDevId, NULL, N'RULE', N'DEVICE_OFFLINE', 0.90, N'OPEN', DATEADD(HOUR, -2, @now));

    DECLARE @offAlertId INT = (SELECT TOP 1 alert_id FROM @alerts WHERE label = N'DEVICE_OFFLINE');
    INSERT INTO dbo.AlertEvidence (alert_id, item, value_text)
    VALUES (@offAlertId, N'last_seen_utc', CONVERT(NVARCHAR(200), DATEADD(HOUR, -26, @now), 126));

    -- Maintenance Tickets
    -- 1) Open ticket for sensor fault
    INSERT INTO dbo.MaintenanceTicket (alert_id, device_id, assigned_to, note, status, opened_at)
    SELECT a.alert_id, a.device_id, @tech1Id, N'Kiểm tra và hiệu chuẩn lại cảm biến trọng lượng: ' + c.reason, N'OPEN', a.created_at
    FROM @alerts x
    JOIN dbo.Alert a ON a.alert_id = x.alert_id
    JOIN dbo.LockerSession s ON s.session_id = a.session_id
    JOIN @cases c ON s.device_seq = 9000 + c.n
    WHERE a.label = N'SENSOR_FAULT';

    -- 2) Additional open tickets assigned to various technicians
    DECLARE @tech3Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'tech3');
    DECLARE @tech5Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'tech5');
    DECLARE @tech8Id INT = (SELECT user_id FROM dbo.Users WHERE username = N'tech8');

    INSERT INTO dbo.MaintenanceTicket (device_id, assigned_to, note, status, opened_at)
    VALUES
    (1, @tech3Id, N'Bảo trì định kỳ tủ LIB-A: kiểm tra chốt solenoid các ô A01-A04', N'OPEN', DATEADD(HOUR, -5, @now)),
    (3, @tech5Id, N'Kiểm tra ăng ten đọc thẻ RFID tại sảnh Ký túc xá DOMA-A', N'OPEN', DATEADD(HOUR, -12, @now)),
    (5, @tech8Id, N'Vệ sinh cảm biến hồng ngoại và công tắc từ Bank CANT-A', N'OPEN', DATEADD(DAY, -1, @now));

    -- 3) Historical closed maintenance tickets (10 rows)
    ;WITH TktNums AS (
        SELECT 1 AS n UNION ALL SELECT n + 1 FROM TktNums WHERE n < 10
    )
    INSERT INTO dbo.MaintenanceTicket (device_id, assigned_to, note, status, opened_at, closed_at)
    SELECT
        (n.n % 7) + 1,
        CASE n.n % 2 WHEN 0 THEN @tech1Id ELSE @tech2Id END,
        N'Đã hoàn thành bảo dưỡng và kiểm tra cảm biến lần ' + CONVERT(NVARCHAR(2), n.n),
        N'CLOSED',
        DATEADD(DAY, -(n.n + 3), @now),
        DATEADD(HOUR, 2, DATEADD(DAY, -(n.n + 3), @now))
    FROM TktNums n;

    PRINT '8. Seeding Remote Commands...';

    INSERT INTO dbo.RemoteCommand (device_id, slot_id, action, reason, requested_by, status, created_at, expires_at, sent_at, done_at)
    SELECT
        b.device_id,
        s.locker_slot_id,
        N'UNLOCK',
        N'Hỗ trợ mở tủ khẩn cấp từ quầy quản trị viên lần ' + CONVERT(NVARCHAR(2), n.n),
        @oper1Id,
        CASE n.n % 4 WHEN 0 THEN N'PENDING' WHEN 1 THEN N'SENT' WHEN 2 THEN N'DONE' ELSE N'EXPIRED' END,
        DATEADD(MINUTE, -(n.n + 5), @now),
        CASE WHEN n.n % 4 IN (0, 1) THEN DATEADD(MINUTE, 60, @now) ELSE DATEADD(MINUTE, -n.n, @now) END,
        CASE WHEN n.n % 4 IN (1, 2) THEN DATEADD(MINUTE, -(n.n + 4), @now) END,
        CASE WHEN n.n % 4 = 2 THEN DATEADD(MINUTE, -n.n, @now) END
    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8)) n(n)
    JOIN dbo.LockerBank b ON b.bank_code = N'GYM-A'
    JOIN dbo.LockerSlot s ON s.bank_id = b.bank_id AND s.slot_code = N'A' + RIGHT(N'0' + CONVERT(NVARCHAR(2), 4 + n.n % 10), 2);

    PRINT '9. Seeding PublicSession Machine Learning Dataset (480 rows)...';

    ;WITH MlNums AS (
        SELECT 1 AS n UNION ALL SELECT n + 1 FROM MlNums WHERE n < 480
    )
    INSERT INTO dbo.PublicSession (door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, label, sent)
    SELECT
        CASE n.n % 6 WHEN 1 THEN 25.0 + (n.n % 9) WHEN 5 THEN 0.0 ELSE 3.0 + (n.n % 7) END,
        CASE n.n % 6 WHEN 4 THEN 150.0 + (n.n % 300) WHEN 5 THEN 100.0 + (n.n % 200) ELSE -10.0 - (n.n % 80) END,
        CASE n.n % 6 WHEN 1 THEN 4 ELSE 1 END,
        CASE n.n % 6 WHEN 1 THEN 0 ELSE 1 END,
        CASE n.n % 6 WHEN 3 THEN 180.0 + (n.n % 90) ELSE 10.0 + (n.n % 90) END,
        CASE n.n % 6
            WHEN 0 THEN N'NORMAL'
            WHEN 1 THEN N'FORCED_OPEN'
            WHEN 2 THEN N'WRONG_USER'
            WHEN 3 THEN N'OVERDUE'
            WHEN 4 THEN N'ITEM_LEFT'
            ELSE N'SUSPECTED_SPOOF'
        END,
        0
    FROM MlNums n
    OPTION (MAXRECURSION 500);

    PRINT '10. Building Cryptographic SHA-256 HashChain & Multi-day Audit Trail...';

    DECLARE @auditEvents TABLE (
        id INT IDENTITY PRIMARY KEY,
        actor INT,
        action NVARCHAR(50),
        objType NVARCHAR(50),
        objId BIGINT,
        diff NVARCHAR(MAX)
    );

    -- Sequence of audit activities across system modules
    INSERT INTO @auditEvents (actor, action, objType, objId, diff) VALUES
    (@adminId, N'SYS_INIT',       N'DATABASE',  0, N'System bootstrap and cryptographic hash chain initialized'),
    (@adminId, N'USER_CREATE',    N'USER',      2, N'Created administrator account admin'),
    (@adminId, N'ROLE_ASSIGN',    N'ROLE',      1, N'Assigned ADMIN role with permissions to administrative staff'),
    (@oper1Id, N'TOPUP_APPROVE',  N'TOPUP',     1, N'Approved TopupRequest 1 (amount 50000 VND) for student1'),
    (@oper1Id, N'TOPUP_APPROVE',  N'TOPUP',     2, N'Approved TopupRequest 2 (amount 100000 VND) for student2'),
    (@oper2Id, N'DEPOSIT_CREATE', N'DEPOSIT',   1, N'Created locker reservation slot A02 for user student1'),
    (@oper1Id, N'REMOTE_UNLOCK',  N'COMMAND',   1, N'Operator dispatched remote unlock command to slot A05'),
    (@tech1Id, N'TICKET_CLOSE',   N'TICKET',    1, N'Technician replaced solenoid lock and closed ticket 1'),
    (@adminId, N'CALIB_UPDATE',   N'DEVICE',    1, N'Calibrated loadcell sensor on LOCKER-01 Bank LIB-A');

    -- Add alerts and remaining tickets to audit log
    INSERT INTO @auditEvents (actor, action, objType, objId, diff)
    SELECT @adminId, N'ALERT_TRIGGER', N'ALERT', a.alert_id, N'Security alert triggered: ' + a.label
    FROM @alerts a;

    INSERT INTO @auditEvents (actor, action, objType, objId, diff)
    SELECT @tech1Id, N'TICKET_ASSIGN', N'MAINTENANCE', t.ticket_id, t.note
    FROM dbo.MaintenanceTicket t;

    DECLARE @currIdx INT = 1;
    DECLARE @totalIdx INT = (SELECT COUNT(*) FROM @auditEvents);
    DECLARE @evActor INT, @evAction NVARCHAR(50), @evObjType NVARCHAR(50), @evObjId BIGINT, @evDiff NVARCHAR(MAX);

    WHILE @currIdx <= @totalIdx
    BEGIN
        SELECT @evActor = actor, @evAction = action, @evObjType = objType, @evObjId = objId, @evDiff = diff
        FROM @auditEvents WHERE id = @currIdx;

        EXEC dbo.Audit_Append @evActor, @evAction, @evObjType, @evObjId, @evDiff;

        SET @currIdx = @currIdx + 1;
    END;

    EXEC dbo.Audit_Append @adminId, N'SEED', N'DATABASE', 0, N'DEMO_DATA_V3_100_USERS_5_ROLES';

    COMMIT TRANSACTION;
    PRINT '============================================================';
    PRINT 'SUCCESS: 100 Users across 5 Roles & Multi-Day Datasets loaded!';
    PRINT '============================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR during seed execution:';
    THROW;
END CATCH;
GO
