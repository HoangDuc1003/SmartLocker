-- ============================================================
-- 06_demo_v2.sql  Smart Locker v2 (docs/spec/smart-locker-v2.md, section 3).
-- Run after 01..05 on the existing database. Keeps every row, safe to run again.
--   Part A  columns and tables (open method, PIN, enroll code, Fingerprint, AuthAttempt)
--   Part B  demo data changes (real box LOCKER-01 on CANT-A, 4 operators, Demo 2 minutes off)
--   Part C  procedures (Deposit_Reserve, Deposit_ExpireNoShow, Device_Authorize, Enroll_*)
-- Note: running 03_scenarios.sql or 05 again brings back the v1 Deposit_Reserve and
-- Deposit_ExpireNoShow; run this file after them.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ===== Part A. Columns and tables =====

IF COL_LENGTH('dbo.Deposit', 'open_method') IS NULL
    ALTER TABLE dbo.Deposit ADD open_method NVARCHAR(12) NOT NULL
        CONSTRAINT DF_Deposit_open_method DEFAULT N'PIN'
        CONSTRAINT CK_Deposit_open_method CHECK (open_method IN (N'PIN', N'CARD', N'FINGERPRINT'));
IF COL_LENGTH('dbo.Deposit', 'pin_code') IS NULL
    ALTER TABLE dbo.Deposit ADD pin_code CHAR(6) NULL;
IF COL_LENGTH('dbo.Deposit', 'enroll_code') IS NULL
    ALTER TABLE dbo.Deposit ADD enroll_code CHAR(6) NULL;
IF COL_LENGTH('dbo.Deposit', 'enroll_expires') IS NULL
    ALTER TABLE dbo.Deposit ADD enroll_expires DATETIME2 NULL;
GO
-- a PIN or an enroll code points to one open booking only
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Deposit_pin_open')
    CREATE UNIQUE INDEX UX_Deposit_pin_open ON dbo.Deposit(pin_code)
        WHERE pin_code IS NOT NULL AND status IN ('RESERVED', 'ACTIVE');
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Deposit_enroll_open')
    CREATE UNIQUE INDEX UX_Deposit_enroll_open ON dbo.Deposit(enroll_code)
        WHERE enroll_code IS NOT NULL AND status IN ('RESERVED', 'ACTIVE');
GO

IF COL_LENGTH('dbo.UserCard', 'deposit_amount') IS NULL
    ALTER TABLE dbo.UserCard ADD deposit_amount BIGINT NOT NULL
        CONSTRAINT DF_UserCard_deposit DEFAULT 0;
IF COL_LENGTH('dbo.UserCard', 'registered_device_id') IS NULL
    ALTER TABLE dbo.UserCard ADD registered_device_id INT NULL
        CONSTRAINT FK_UserCard_Device REFERENCES dbo.Device(device_id);
GO

-- one AS608 template slot per finger, one finger per user on each box
IF OBJECT_ID('dbo.Fingerprint', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Fingerprint (
        fp_id       INT IDENTITY PRIMARY KEY,
        user_id     INT NOT NULL REFERENCES dbo.Users,
        device_id   INT NOT NULL REFERENCES dbo.Device,
        sensor_slot INT NOT NULL CHECK (sensor_slot BETWEEN 1 AND 160),
        status      NVARCHAR(10) NOT NULL DEFAULT N'ACTIVE' CHECK (status IN (N'ACTIVE', N'DELETED')),
        created_at  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
END;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Fingerprint_slot')
    CREATE UNIQUE INDEX UX_Fingerprint_slot ON dbo.Fingerprint(device_id, sensor_slot) WHERE status = 'ACTIVE';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Fingerprint_user')
    CREATE UNIQUE INDEX UX_Fingerprint_user ON dbo.Fingerprint(device_id, user_id) WHERE status = 'ACTIVE';
GO

-- every try at a box: the lockout counter and the audit trail of failed codes
IF OBJECT_ID('dbo.AuthAttempt', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuthAttempt (
        attempt_id BIGINT IDENTITY PRIMARY KEY,
        device_id  INT NOT NULL REFERENCES dbo.Device,
        at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        method     NVARCHAR(12) NOT NULL,                -- PIN, CARD, FINGERPRINT, PHONE, ENROLL, ADMIN
        ok         BIT NOT NULL,
        reason     NVARCHAR(20) NULL,                    -- deny reason, LOCK_START or COUNTER_RESET
        deposit_id BIGINT NULL);
    CREATE INDEX IX_AuthAttempt_device_at ON dbo.AuthAttempt(device_id, at);
END;
GO

-- a command is not always for a slot (DELETE_FP), and the phone needs its own source
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.RemoteCommand') AND name = 'slot_id' AND is_nullable = 0)
    ALTER TABLE dbo.RemoteCommand ALTER COLUMN slot_id INT NULL;
IF COL_LENGTH('dbo.RemoteCommand', 'sensor_slot') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD sensor_slot INT NULL;
IF COL_LENGTH('dbo.RemoteCommand', 'source') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD source NVARCHAR(10) NULL;   -- STAFF, PHONE, SYSTEM
-- a phone UNLOCK changes its booking only when the box takes the command (RemoteCommand_TakePending)
IF COL_LENGTH('dbo.RemoteCommand', 'deposit_id') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD deposit_id BIGINT NULL;
IF COL_LENGTH('dbo.RemoteCommand', 'phase') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD phase NVARCHAR(10) NULL;     -- CHECK_IN or PICKUP
GO
-- FINGERPRINT has 11 letters
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.LockerSession') AND name = 'open_source' AND max_length < 24)
    ALTER TABLE dbo.LockerSession ALTER COLUMN open_source NVARCHAR(12) NULL;
GO

-- ===== Part B. Demo data =====
SET XACT_ABORT ON;
BEGIN TRAN;
DECLARE @sys INT = (SELECT user_id FROM dbo.Users WHERE username = N'system');

-- B1. The real box is LOCKER-01 on CANT-A (Q14). The seed bound it to LIB-A, so the code, key and firmware
--     of LOCKER-01 and LOCKER-05 swap rows. History stays with the bank it happened at.
DECLARE @cantDev INT = (SELECT b.device_id FROM dbo.LockerBank b WHERE b.bank_code = N'CANT-A');
DECLARE @oneDev INT = (SELECT device_id FROM dbo.Device WHERE device_code = N'LOCKER-01');
IF @cantDev IS NOT NULL AND @oneDev IS NOT NULL AND @cantDev <> @oneDev
BEGIN
    DECLARE @code NVARCHAR(30), @hash CHAR(64), @fw NVARCHAR(20);
    SELECT @code = device_code, @hash = api_key_hash, @fw = firmware FROM dbo.Device WHERE device_id = @cantDev;
    UPDATE dbo.Device SET device_code = N'SWAP-TMP' WHERE device_id = @cantDev;
    UPDATE t SET t.api_key_hash = @hash, t.device_code = @code, t.firmware = @fw
    FROM dbo.Device t WHERE t.device_id = @oneDev;
    UPDATE t SET t.device_code = N'LOCKER-01',
                 t.api_key_hash = LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', 'device-1-api-key'), 2)),
                 t.firmware = N'2.0'
    FROM dbo.Device t WHERE t.device_id = @cantDev;
    EXEC dbo.Audit_Append @sys, N'DEMO_V2', N'DEVICE', @cantDev, N'LOCKER-01 moved to CANT-A';
END;
SET @oneDev = (SELECT device_id FROM dbo.Device WHERE device_code = N'LOCKER-01');

-- the real box is not given a fake heartbeat by LockerMonitor; it sends one every 3 seconds
UPDATE dbo.OperatingProfile
SET params_json = N'{"demo":false,"heartbeat_sec":3,"offline_timeout_sec":90,"item_left_g":50}'
WHERE device_id = @oneDev AND params_json LIKE N'%"demo":true%';
UPDATE dbo.OperatingProfile
SET params_json = REPLACE(params_json, N'"demo":false', N'"demo":true')
WHERE device_id <> @oneDev AND params_json LIKE N'%"demo":false%';

-- B2. Demo 2 minutes is off: deposits refer to it, so it is not deleted (found by duration: 07 renames the plans)
UPDATE dbo.StoragePlan SET is_active = 0 WHERE duration_min = 2 AND is_active = 1;

-- B3. Four operators, one per locker area: operator1..4 take LIB, DOMA, CANT, GYM; the others are DISABLED
UPDATE u SET u.area_id = a.area_id, u.status = N'ACTIVE'
FROM dbo.Users u
JOIN (VALUES (N'operator1', N'LIB'), (N'operator2', N'DOMA'), (N'operator3', N'CANT'), (N'operator4', N'GYM')) v(username, area_code)
  ON v.username = u.username
JOIN dbo.LockerArea a ON a.area_code = v.area_code
WHERE ISNULL(u.area_id, 0) <> a.area_id OR ISNULL(u.status, N'') <> N'ACTIVE';

UPDATE u SET u.status = N'DISABLED'
FROM dbo.Users u
JOIN dbo.UserRole ur ON ur.user_id = u.user_id
JOIN dbo.Roles r ON r.role_id = ur.role_id AND r.role_name = N'OPERATOR'
WHERE u.username NOT IN (N'operator1', N'operator2', N'operator3', N'operator4')
  AND ISNULL(u.status, N'') <> N'DISABLED';
DECLARE @disabled INT = @@ROWCOUNT;
IF @disabled > 0
BEGIN
    DECLARE @note NVARCHAR(100) = CONCAT(@disabled, N' operators outside the 4 areas disabled');
    EXEC dbo.Audit_Append @sys, N'DEMO_V2', N'USER', 0, @note;    -- object id 0: many users, never NULL
END

-- a disabled operator can no longer hold the remote control of a device
UPDATE d SET d.control_owner = NULL
FROM dbo.Device d JOIN dbo.Users u ON u.user_id = d.control_owner
WHERE u.status <> N'ACTIVE';

-- B4. Ready-made credentials on LOCKER-01: student1 has a registered card, student3 a fingerprint in sensor slot 1.
--     Replace the UID with the one of your physical card, and enroll that finger as template 1 on the AS608.
UPDATE c SET c.registered_device_id = @oneDev
FROM dbo.UserCard c JOIN dbo.Users u ON u.user_id = c.user_id
WHERE u.username = N'student1' AND c.status = N'ACTIVE' AND c.registered_device_id IS NULL;

INSERT INTO dbo.Fingerprint (user_id, device_id, sensor_slot)
SELECT u.user_id, @oneDev, 1 FROM dbo.Users u
WHERE u.username = N'student3'
  AND NOT EXISTS (SELECT 1 FROM dbo.Fingerprint f WHERE f.device_id = @oneDev AND f.status = N'ACTIVE'
                  AND (f.user_id = u.user_id OR f.sensor_slot = 1));
COMMIT;
GO

-- ===== Part C. Procedures =====

-- price of a plan for an open method: the card is 5% off, rounded up to 100 VND (5,000 -> 4,750 -> 4,800)
CREATE OR ALTER FUNCTION dbo.fn_OpenPrice (@price BIGINT, @method NVARCHAR(12))
RETURNS BIGINT
AS
BEGIN
    RETURN CASE WHEN @method = N'CARD'
                THEN CAST(CEILING(@price * 95 / 10000.0) AS BIGINT) * 100
                ELSE @price END;
END;
GO

-- a random 6-digit code that no open booking uses as a PIN or as an enroll code
CREATE OR ALTER PROCEDURE Code_NewSix @code CHAR(6) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @try INT = 0;
    WHILE 1 = 1
    BEGIN
        SET @code = RIGHT('000000' + CONVERT(VARCHAR(6), ABS(CHECKSUM(NEWID())) % 1000000), 6);
        IF NOT EXISTS (SELECT 1 FROM Deposit WHERE status IN (N'RESERVED', N'ACTIVE')
                       AND (pin_code = @code OR enroll_code = @code))
            RETURN;
        SET @try += 1;
        IF @try > 50 THROW 50043, N'Could not create a unique code, try again', 1;
    END
END;
GO

-- demo PINs for the open bookings that were made before v2
DECLARE @id BIGINT, @c CHAR(6);
WHILE EXISTS (SELECT 1 FROM Deposit WHERE status IN (N'RESERVED', N'ACTIVE') AND open_method = N'PIN' AND pin_code IS NULL)
BEGIN
    SELECT TOP 1 @id = deposit_id FROM Deposit
    WHERE status IN (N'RESERVED', N'ACTIVE') AND open_method = N'PIN' AND pin_code IS NULL;
    EXEC Code_NewSix @c OUTPUT;
    UPDATE Deposit SET pin_code = @c WHERE deposit_id = @id;
END;
GO

-- Case 4 v2: price by open method, PIN or enroll code, and room for the first card deposit
CREATE OR ALTER PROCEDURE Deposit_Reserve
    @user_id INT, @slot_id INT, @plan_id INT, @new_id BIGINT OUTPUT, @open_method NVARCHAR(12) = N'PIN'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @open_method IS NULL OR @open_method NOT IN (N'PIN', N'CARD', N'FINGERPRINT')
        THROW 50042, N'Choose how to open the locker: PIN, card or fingerprint', 1;
    IF (SELECT COUNT(*) FROM Deposit WHERE user_id = @user_id AND status = N'NO_SHOW'
        AND reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME())) >= 3
        THROW 50031, N'Booking is blocked: 3 no-shows in the last 7 days', 1;
    IF EXISTS (SELECT 1 FROM Deposit WHERE user_id = @user_id AND status IN (N'RESERVED', N'ACTIVE'))
        THROW 50032, N'You already have a booking in progress', 1;
    IF EXISTS (SELECT 1 FROM v_LockerSlotMap WHERE slot_id = @slot_id AND device_status = N'OFFLINE')
        THROW 50035, N'The locker is offline, booking is paused', 1;

    DECLARE @device_id INT = (SELECT b.device_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
                              WHERE s.locker_slot_id = @slot_id);
    -- a card counts once it was enrolled at a box (or staff marked it so)
    DECLARE @card_id INT = (SELECT TOP 1 card_id FROM UserCard WHERE user_id = @user_id AND status = N'ACTIVE'
                            AND (registered_device_id IS NOT NULL OR deposit_amount > 0) ORDER BY card_id DESC);
    DECLARE @has_finger BIT = CASE WHEN EXISTS (SELECT 1 FROM Fingerprint WHERE user_id = @user_id
                                   AND device_id = @device_id AND status = N'ACTIVE') THEN 1 ELSE 0 END;
    DECLARE @card_deposit BIGINT = CASE WHEN @open_method = N'CARD' AND @card_id IS NULL THEN 30000 ELSE 0 END;
    DECLARE @pin CHAR(6) = NULL, @enroll CHAR(6) = NULL;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @price BIGINT;
        SELECT @price = price FROM StoragePlan WITH (UPDLOCK, HOLDLOCK)
        WHERE plan_id = @plan_id AND is_active = 1;
        IF @price IS NULL THROW 50034, N'This storage plan is not available', 1;
        IF @price < 0 THROW 50040, N'The storage plan has an invalid price', 1;
        SET @price = dbo.fn_OpenPrice(@price, @open_method);

        -- The conditional update prevents spending the same balance twice.
        -- A first card also needs the 30,000 VND deposit left in the wallet; it is taken at the box.
        UPDATE Users SET balance = balance - @price
        WHERE user_id = @user_id AND balance >= @price + @card_deposit;
        IF @@ROWCOUNT = 0
        BEGIN
            IF @card_deposit > 0 THROW 50041, N'Insufficient balance for the price and the 30,000 VND card deposit', 1;
            THROW 50030, N'Insufficient balance. Add funds before booking.', 1;
        END

        -- The WHERE clause is the lock: only one user can reserve a free slot.
        UPDATE LockerSlot SET status = N'RESERVED'
        WHERE locker_slot_id = @slot_id AND status = N'AVAILABLE';
        IF @@ROWCOUNT = 0 THROW 50033, N'This slot is no longer available', 1;

        IF @open_method = N'PIN'
            EXEC Code_NewSix @pin OUTPUT;
        IF (@open_method = N'CARD' AND @card_id IS NULL) OR (@open_method = N'FINGERPRINT' AND @has_finger = 0)
            EXEC Code_NewSix @enroll OUTPUT;

        INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, hold_until,
                             open_method, pin_code, enroll_code, enroll_expires)
        VALUES (@user_id, @slot_id, @plan_id, CASE WHEN @open_method = N'CARD' THEN @card_id END, @price, N'RESERVED',
                DATEADD(MINUTE, 15, SYSUTCDATETIME()), @open_method, @pin, @enroll,
                CASE WHEN @enroll IS NOT NULL THEN DATEADD(MINUTE, 10, SYSUTCDATETIME()) END);
        SET @new_id = SCOPE_IDENTITY();
        DECLARE @diff NVARCHAR(200) = CONCAT(N'{"price":', @price, N',"method":"', @open_method, N'"}');
        EXEC Audit_Append @user_id, N'RESERVE', N'DEPOSIT', @new_id, @diff;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- not coming before hold_until: 90% back, CEILING(10%) kept
CREATE OR ALTER PROCEDURE Deposit_ExpireNoShow
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @expired TABLE (deposit_id BIGINT, slot_id INT, user_id INT, refund BIGINT);
    DECLARE @id BIGINT, @refund BIGINT;
    BEGIN TRAN;
    UPDATE d SET d.status = N'NO_SHOW', d.ended_at = SYSUTCDATETIME()
    OUTPUT inserted.deposit_id, inserted.slot_id, inserted.user_id,
           inserted.paid_amount - CAST(CEILING(inserted.paid_amount / 10.0) AS BIGINT) INTO @expired
    FROM Deposit d
    WHERE d.status = N'RESERVED' AND d.hold_until < SYSUTCDATETIME();

    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s JOIN @expired e ON e.slot_id = s.locker_slot_id
    WHERE s.status = N'RESERVED';

    UPDATE u SET u.balance = u.balance + r.refund
    FROM Users u
    JOIN (SELECT user_id, SUM(refund) AS refund FROM @expired GROUP BY user_id) r
      ON r.user_id = u.user_id;
    WHILE EXISTS (SELECT 1 FROM @expired)
    BEGIN
        SELECT TOP 1 @id = deposit_id, @refund = refund FROM @expired;
        EXEC Audit_Append @sys, N'NO_SHOW', N'DEPOSIT', @id, @refund;
        DELETE FROM @expired WHERE deposit_id = @id;
    END
    COMMIT;
END;
GO

-- commands may have no slot (DELETE_FP); the reply carries the sensor slot and who asked.
-- A phone UNLOCK checks in or picks up only here, when the box takes it: an offline box changes nothing.
CREATE OR ALTER PROCEDURE RemoteCommand_TakePending @device_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @taken TABLE (command_id BIGINT, slot_code NVARCHAR(20), action NVARCHAR(20), sensor_slot INT,
                          source NVARCHAR(10), deposit_id BIGINT, phase NVARCHAR(10));
    DECLARE @lock_name NVARCHAR(40) = CONCAT(N'auth-device-', @device_id);
    DECLARE @dep BIGINT, @phase NVARCHAR(10), @slot NVARCHAR(20);
    BEGIN TRAN;
    EXEC sp_getapplock @Resource = @lock_name, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    -- a phone command whose booking moved on meanwhile (cancelled, expired, opened at the keypad) is dropped
    UPDATE c SET c.status = N'EXPIRED'
    FROM RemoteCommand c JOIN Deposit d WITH (UPDLOCK, HOLDLOCK) ON d.deposit_id = c.deposit_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.phase IS NOT NULL
      AND d.status <> CASE c.phase WHEN N'CHECK_IN' THEN N'RESERVED' ELSE N'ACTIVE' END;

    UPDATE c SET c.status = N'SENT', c.sent_at = SYSUTCDATETIME()
    OUTPUT inserted.command_id, s.slot_code, inserted.action, inserted.sensor_slot, inserted.source,
           inserted.deposit_id, inserted.phase INTO @taken
    FROM RemoteCommand c
    LEFT JOIN LockerSlot s ON s.locker_slot_id = c.slot_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.expires_at > SYSUTCDATETIME();

    DECLARE @work TABLE (deposit_id BIGINT, phase NVARCHAR(10), slot_code NVARCHAR(20));
    INSERT INTO @work SELECT deposit_id, phase, slot_code FROM @taken WHERE phase IS NOT NULL;
    WHILE EXISTS (SELECT 1 FROM @work)
    BEGIN
        SELECT TOP 1 @dep = deposit_id, @phase = phase, @slot = slot_code FROM @work;
        IF @phase = N'CHECK_IN' AND EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @dep AND status = N'RESERVED')
            EXEC Deposit_CheckIn @device_id, @slot;
        ELSE IF @phase = N'PICKUP' AND EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @dep AND status = N'ACTIVE')
            EXEC Deposit_Complete @device_id, @slot;
        DELETE FROM @work WHERE deposit_id = @dep;
    END
    COMMIT;
    SELECT command_id, slot_code, action, sensor_slot, source FROM @taken;
END;
GO

-- ===== Lockout: 5 wrong guesses in 5 minutes lock for 2 minutes =====
-- Two counters per box: BOX (keypad, card, finger, enroll) and PHONE (the public /k page), so a stranger
-- typing PINs on the phone page cannot block the keypad. A LOCK_START row starts a lock and a new count;
-- COUNTER_RESET (test script) clears both.

-- seconds left of a running lockout of one channel of the box, 0 when it is free
CREATE OR ALTER PROCEDURE Auth_LockCheck @device_id INT, @channel NVARCHAR(5), @retry INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @mark DATETIME2, @kind NVARCHAR(20);
    DECLARE @lock_method NVARCHAR(12) = CASE WHEN @channel = N'PHONE' THEN N'LOCK_PHONE' ELSE N'LOCK' END;
    SELECT TOP 1 @mark = at, @kind = reason FROM AuthAttempt
    WHERE device_id = @device_id
      AND (reason = N'COUNTER_RESET' OR (reason = N'LOCK_START' AND method = @lock_method))
    ORDER BY at DESC, attempt_id DESC;
    SET @retry = 0;
    IF @kind = N'LOCK_START' AND @mark > DATEADD(SECOND, -120, SYSUTCDATETIME())
    BEGIN
        SET @retry = DATEDIFF(SECOND, SYSUTCDATETIME(), DATEADD(SECOND, 120, @mark));
        IF @retry < 1 SET @retry = 1;
    END
END;
GO

-- logs one try. Only guesses (a code or a credential nobody has) count towards the lockout of its channel.
CREATE OR ALTER PROCEDURE Auth_Log
    @device_id INT, @channel NVARCHAR(5), @method NVARCHAR(12), @ok BIT, @reason NVARCHAR(20), @deposit_id BIGINT,
    @left INT OUTPUT, @retry INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME(), @mark DATETIME2, @fails INT;
    DECLARE @lock_method NVARCHAR(12) = CASE WHEN @channel = N'PHONE' THEN N'LOCK_PHONE' ELSE N'LOCK' END;
    INSERT INTO AuthAttempt (device_id, at, method, ok, reason, deposit_id)
    VALUES (@device_id, @now, @method, @ok, @reason, @deposit_id);
    SELECT @mark = MAX(at) FROM AuthAttempt
    WHERE device_id = @device_id
      AND (reason = N'COUNTER_RESET' OR (reason = N'LOCK_START' AND method = @lock_method));
    SELECT @fails = COUNT(*) FROM AuthAttempt
    WHERE device_id = @device_id AND ok = 0
      AND reason IN (N'WRONG_CODE', N'UNKNOWN_CARD', N'UNKNOWN_FINGER', N'BAD_CODE')
      AND ((@channel = N'PHONE' AND method = N'PHONE') OR (@channel <> N'PHONE' AND method <> N'PHONE'))
      AND at > DATEADD(MINUTE, -5, @now) AND at > ISNULL(@mark, '19000101');
    SET @left = CASE WHEN 5 - @fails < 0 THEN 0 ELSE 5 - @fails END;
    SET @retry = 0;
    IF @ok = 0 AND @left = 0 AND @reason IN (N'WRONG_CODE', N'UNKNOWN_CARD', N'UNKNOWN_FINGER', N'BAD_CODE')
    BEGIN
        INSERT INTO AuthAttempt (device_id, at, method, ok, reason) VALUES (@device_id, @now, @lock_method, 0, N'LOCK_START');
        SET @retry = 120;
    END
END;
GO

-- ===== Device_Authorize: one decision for the keypad, the phone page, the card and the finger =====
-- First good try: RESERVED -> ACTIVE (CHECK_IN). Next good try: ACTIVE -> COMPLETED (PICKUP).
-- @source = PHONE queues an UNLOCK instead; the booking changes when the box takes it (RemoteCommand_TakePending).
CREATE OR ALTER PROCEDURE Device_Authorize
    @device_id INT, @method NVARCHAR(12), @pin NVARCHAR(10) = NULL, @card_uid NVARCHAR(32) = NULL,
    @sensor_slot INT = NULL, @source NVARCHAR(10) = N'DEVICE'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @reason NVARCHAR(20) = NULL, @phase NVARCHAR(10) = NULL, @left INT = 5, @retry INT = 0, @command BIGINT = NULL;
    DECLARE @deposit BIGINT, @status NVARCHAR(20), @slot_id INT, @slot_code NVARCHAR(20), @user INT,
            @booked NVARCHAR(12), @hold DATETIME2, @deposit_device INT;
    DECLARE @log_method NVARCHAR(12) = CASE WHEN @source = N'PHONE' THEN N'PHONE' ELSE @method END;
    DECLARE @channel NVARCHAR(5) = CASE WHEN @source = N'PHONE' THEN N'PHONE' ELSE N'BOX' END;
    DECLARE @lock_name NVARCHAR(40) = CONCAT(N'auth-device-', @device_id);

    BEGIN TRAN;
    -- one box, one decision at a time: the counter and the booking cannot be raced
    EXEC sp_getapplock @Resource = @lock_name, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;

    EXEC Auth_LockCheck @device_id, @channel, @retry OUTPUT;
    IF @retry > 0
        SET @reason = N'LOCKED_OUT';
    ELSE IF @source = N'PHONE' AND NOT EXISTS (SELECT 1 FROM Device WHERE device_id = @device_id AND status = N'ACTIVE'
                                               AND last_seen > DATEADD(SECOND, -10, @now))
        SET @reason = N'DEVICE_OFFLINE';            -- no heartbeat for 10 s: the command would not reach the box
    ELSE IF @method = N'PIN'
    BEGIN
        SELECT TOP 1 @deposit = d.deposit_id, @user = d.user_id
        FROM Deposit d WITH (UPDLOCK, HOLDLOCK) JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
        WHERE d.pin_code = @pin AND d.status IN (N'RESERVED', N'ACTIVE') AND b.device_id = @device_id;
        IF @deposit IS NULL
        BEGIN
            -- a PIN of a booking here that ran out of hold time
            SELECT TOP 1 @deposit = d.deposit_id
            FROM Deposit d JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
            WHERE d.pin_code = @pin AND d.status = N'NO_SHOW' AND b.device_id = @device_id
              AND d.ended_at > DATEADD(HOUR, -1, @now)
            ORDER BY d.deposit_id DESC;
            SET @reason = CASE WHEN @deposit IS NULL THEN N'WRONG_CODE' ELSE N'EXPIRED' END;
        END
    END
    ELSE IF @method = N'CARD'
    BEGIN
        DECLARE @card_status NVARCHAR(20);
        SELECT @user = user_id, @card_status = status FROM UserCard WHERE card_uid = @card_uid;
        IF @user IS NULL SET @reason = N'UNKNOWN_CARD';
        ELSE IF @card_status <> N'ACTIVE' SET @reason = N'CARD_BLOCKED';
    END
    ELSE IF @method = N'FINGERPRINT'
    BEGIN
        SELECT @user = user_id FROM Fingerprint
        WHERE device_id = @device_id AND sensor_slot = @sensor_slot AND status = N'ACTIVE';
        IF @user IS NULL SET @reason = N'UNKNOWN_FINGER';
    END

    -- a card or a finger: the open booking of its owner on this box
    IF @reason IS NULL AND @method IN (N'CARD', N'FINGERPRINT')
    BEGIN
        SELECT TOP 1 @deposit = d.deposit_id
        FROM Deposit d WITH (UPDLOCK, HOLDLOCK) JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
        WHERE d.user_id = @user AND d.status IN (N'RESERVED', N'ACTIVE') AND b.device_id = @device_id;
        IF @deposit IS NULL
        BEGIN
            SELECT TOP 1 @deposit = d.deposit_id
            FROM Deposit d JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
            WHERE d.user_id = @user AND d.status = N'NO_SHOW' AND b.device_id = @device_id
              AND d.ended_at > DATEADD(HOUR, -1, @now)
            ORDER BY d.deposit_id DESC;
            SET @reason = CASE WHEN @deposit IS NULL THEN N'NO_BOOKING' ELSE N'EXPIRED' END;
        END
    END

    IF @reason IS NULL AND @deposit IS NOT NULL
    BEGIN
        SELECT @status = d.status, @slot_id = d.slot_id, @slot_code = s.slot_code, @booked = d.open_method,
               @hold = d.hold_until, @user = d.user_id
        FROM Deposit d WITH (UPDLOCK, HOLDLOCK) JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
        WHERE d.deposit_id = @deposit;
        IF @booked <> @method
            SET @reason = N'METHOD_MISMATCH';
        ELSE IF EXISTS (SELECT 1 FROM Users WHERE user_id = @user AND ISNULL(status, N'ACTIVE') <> N'ACTIVE')
            SET @reason = N'ACCOUNT_LOCKED';
        ELSE IF @status = N'RESERVED' AND @hold < @now
        BEGIN
            SET @reason = N'EXPIRED';
            EXEC Deposit_ExpireNoShow;                   -- do now what the clock job would do in a few seconds
        END
    END

    IF @reason IS NULL
    BEGIN
        SET @phase = CASE WHEN @status = N'RESERVED' THEN N'CHECK_IN' ELSE N'PICKUP' END;
        IF @source = N'PHONE'
        BEGIN
            -- a second good try before the box took the first command gets the same command
            SELECT TOP 1 @command = command_id FROM RemoteCommand
            WHERE deposit_id = @deposit AND phase = @phase AND status = N'PENDING' AND expires_at > @now;
            IF @command IS NULL
            BEGIN
                INSERT INTO RemoteCommand (device_id, slot_id, action, reason, requested_by, expires_at, source, deposit_id, phase)
                VALUES (@device_id, @slot_id, N'UNLOCK', N'Mở bằng điện thoại', @user, DATEADD(MINUTE, 2, @now), N'PHONE',
                        @deposit, @phase);
                SET @command = SCOPE_IDENTITY();
            END
        END
        ELSE IF @phase = N'CHECK_IN'
            EXEC Deposit_CheckIn @device_id, @slot_code;  -- writes the CHECK_IN audit row
        ELSE
            EXEC Deposit_Complete @device_id, @slot_code; -- writes the COMPLETE audit row, the slot is free again
        EXEC Auth_Log @device_id, @channel, @log_method, 1, NULL, @deposit, @left OUTPUT, @retry OUTPUT;
    END
    ELSE IF @reason = N'LOCKED_OUT'
    BEGIN
        INSERT INTO AuthAttempt (device_id, at, method, ok, reason) VALUES (@device_id, @now, @log_method, 0, @reason);
        SET @left = 0;
    END
    ELSE
        EXEC Auth_Log @device_id, @channel, @log_method, 0, @reason, @deposit, @left OUTPUT, @retry OUTPUT;
    COMMIT;

    SELECT CASE WHEN @reason IS NULL THEN N'UNLOCK' ELSE N'DENY' END AS result,
           @phase AS phase, @reason AS reason,
           CASE WHEN @reason IS NULL OR @reason IN (N'METHOD_MISMATCH', N'EXPIRED', N'ACCOUNT_LOCKED') THEN @deposit END AS deposit_id,
           CASE WHEN @reason IS NULL THEN @slot_code END AS slot_code,
           @left AS attempts_left, @retry AS retry_after_sec, @command AS command_id, @booked AS open_method;
END;
GO

-- ===== Enrolling a card or a finger at the box with the 6-digit code shown on the web =====

-- the open booking an enroll code belongs to on this box, or the reason it cannot be used
CREATE OR ALTER PROCEDURE Enroll_Find
    @device_id INT, @type NVARCHAR(12), @code NVARCHAR(10), @deposit BIGINT OUTPUT, @user INT OUTPUT, @reason NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @expires DATETIME2;
    SET @deposit = NULL; SET @user = NULL; SET @reason = NULL;
    SELECT TOP 1 @deposit = d.deposit_id, @user = d.user_id, @expires = d.enroll_expires
    FROM Deposit d JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
    WHERE d.enroll_code = @code AND d.open_method = @type AND d.status IN (N'RESERVED', N'ACTIVE')
      AND b.device_id = @device_id;
    IF @deposit IS NULL SET @reason = N'BAD_CODE';
    ELSE IF @expires < SYSUTCDATETIME() SET @reason = N'CODE_EXPIRED';
END;
GO

CREATE OR ALTER PROCEDURE Enroll_Start @device_id INT, @type NVARCHAR(12), @code NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @deposit BIGINT, @user INT, @reason NVARCHAR(20), @slot INT = NULL, @left INT = 5, @retry INT = 0;
    DECLARE @lock_name NVARCHAR(40) = CONCAT(N'auth-device-', @device_id);
    BEGIN TRAN;
    EXEC sp_getapplock @Resource = @lock_name, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    EXEC Auth_LockCheck @device_id, N'BOX', @retry OUTPUT;
    IF @retry > 0
        SET @reason = N'LOCKED_OUT';
    ELSE
        EXEC Enroll_Find @device_id, @type, @code, @deposit OUTPUT, @user OUTPUT, @reason OUTPUT;
    IF @reason IS NULL AND @type = N'FINGERPRINT'
    BEGIN
        -- the lowest free template slot of the AS608 (1 to 160)
        SELECT @slot = MIN(n.n) FROM (SELECT TOP 160 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.all_objects) n
        WHERE NOT EXISTS (SELECT 1 FROM Fingerprint f WHERE f.device_id = @device_id AND f.status = N'ACTIVE' AND f.sensor_slot = n.n)
          AND NOT EXISTS (SELECT 1 FROM RemoteCommand c WHERE c.device_id = @device_id AND c.action = N'DELETE_FP'
                          AND c.status = N'PENDING' AND c.sensor_slot = n.n);   -- not until the box erased it
        IF @slot IS NULL SET @reason = N'SENSOR_FULL';
    END
    IF @reason = N'LOCKED_OUT'
        SET @left = 0;
    ELSE
    BEGIN
        DECLARE @ok BIT = CASE WHEN @reason IS NULL THEN 1 ELSE 0 END;
        EXEC Auth_Log @device_id, N'BOX', N'ENROLL', @ok, @reason, @deposit, @left OUTPUT, @retry OUTPUT;
    END
    COMMIT;
    SELECT CASE WHEN @reason IS NULL THEN N'OK' ELSE N'ERROR' END AS result, @reason AS reason,
           @slot AS sensor_slot, @left AS attempts_left, @retry AS retry_after_sec;
END;
GO

-- a finger: stores the template slot. A card: stores the UID and takes the one-time 30,000 VND deposit.
CREATE OR ALTER PROCEDURE Enroll_Finish
    @device_id INT, @type NVARCHAR(12), @code NVARCHAR(10), @sensor_slot INT = NULL, @card_uid NVARCHAR(32) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @deposit BIGINT, @user INT, @reason NVARCHAR(20), @left INT = 5, @retry INT = 0, @card_id INT = NULL;
    DECLARE @lock_name NVARCHAR(40) = CONCAT(N'auth-device-', @device_id);
    BEGIN TRAN;
    EXEC sp_getapplock @Resource = @lock_name, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    EXEC Auth_LockCheck @device_id, N'BOX', @retry OUTPUT;
    IF @retry > 0
        SET @reason = N'LOCKED_OUT';
    ELSE
        EXEC Enroll_Find @device_id, @type, @code, @deposit OUTPUT, @user OUTPUT, @reason OUTPUT;

    IF @reason IS NULL AND @type = N'FINGERPRINT'
    BEGIN
        IF @sensor_slot IS NULL OR @sensor_slot NOT BETWEEN 1 AND 160
           OR EXISTS (SELECT 1 FROM Fingerprint WHERE device_id = @device_id AND sensor_slot = @sensor_slot AND status = N'ACTIVE')
           OR EXISTS (SELECT 1 FROM RemoteCommand WHERE device_id = @device_id AND action = N'DELETE_FP'
                      AND status = N'PENDING' AND sensor_slot = @sensor_slot)
            SET @reason = N'BAD_SLOT';
        ELSE
        BEGIN
            -- a second enroll replaces the old finger: the box erases its template with the next heartbeat
            INSERT INTO RemoteCommand (device_id, slot_id, action, reason, requested_by, expires_at, sensor_slot, source)
            SELECT device_id, NULL, N'DELETE_FP', N'Thay vân tay', @user, DATEADD(DAY, 7, SYSUTCDATETIME()), sensor_slot, N'SYSTEM'
            FROM Fingerprint WHERE device_id = @device_id AND user_id = @user AND status = N'ACTIVE';
            UPDATE Fingerprint SET status = N'DELETED'
            WHERE device_id = @device_id AND user_id = @user AND status = N'ACTIVE';
            INSERT INTO Fingerprint (user_id, device_id, sensor_slot) VALUES (@user, @device_id, @sensor_slot);
            EXEC Audit_Append @user, N'ENROLL_FINGER', N'DEPOSIT', @deposit, @sensor_slot;
        END
    END
    ELSE IF @reason IS NULL AND @type = N'CARD'
    BEGIN
        DECLARE @owner INT, @owner_status NVARCHAR(20);
        SELECT @card_id = card_id, @owner = user_id, @owner_status = status FROM UserCard WHERE card_uid = @card_uid;
        IF @card_uid IS NULL OR LEN(@card_uid) < 4
            SET @reason = N'BAD_UID';
        ELSE IF @owner IS NOT NULL AND (@owner <> @user OR @owner_status <> N'ACTIVE')
            SET @reason = N'CARD_IN_USE';
        ELSE
        BEGIN
            UPDATE Users SET balance = balance - 30000 WHERE user_id = @user AND balance >= 30000;
            IF @@ROWCOUNT = 0
                SET @reason = N'INSUFFICIENT_BALANCE';
            ELSE
            BEGIN
                IF @card_id IS NULL
                BEGIN
                    INSERT INTO UserCard (card_uid, user_id, deposit_amount, registered_device_id)
                    VALUES (@card_uid, @user, 30000, @device_id);
                    SET @card_id = SCOPE_IDENTITY();
                END
                ELSE
                    UPDATE UserCard SET deposit_amount = deposit_amount + 30000, registered_device_id = @device_id
                    WHERE card_id = @card_id;
                UPDATE Deposit SET card_id = @card_id WHERE deposit_id = @deposit;
                EXEC Audit_Append @user, N'ENROLL_CARD', N'USERCARD', @card_id, 30000;
            END
        END
    END
    IF @reason IS NULL
        UPDATE Deposit SET enroll_code = NULL, enroll_expires = NULL WHERE deposit_id = @deposit;

    IF @reason = N'LOCKED_OUT'
        SET @left = 0;
    ELSE
    BEGIN
        DECLARE @ok BIT = CASE WHEN @reason IS NULL THEN 1 ELSE 0 END;
        EXEC Auth_Log @device_id, N'BOX', N'ENROLL', @ok, @reason, @deposit, @left OUTPUT, @retry OUTPUT;
    END
    COMMIT;
    SELECT CASE WHEN @reason IS NULL THEN N'OK' ELSE N'ERROR' END AS result, @reason AS reason,
           @card_id AS card_id, @left AS attempts_left, @retry AS retry_after_sec;
END;
GO

-- "Tủ của tôi": a new enroll code when the old one ran out of its 10 minutes
CREATE OR ALTER PROCEDURE Enroll_NewCode @deposit_id BIGINT, @actor INT, @code CHAR(6) OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @deposit_id AND user_id = @actor
                   AND status IN (N'RESERVED', N'ACTIVE') AND enroll_code IS NOT NULL)
        THROW 50044, N'This booking has nothing to enroll', 1;
    BEGIN TRAN;
    EXEC Code_NewSix @code OUTPUT;
    UPDATE Deposit SET enroll_code = @code, enroll_expires = DATEADD(MINUTE, 10, SYSUTCDATETIME())
    WHERE deposit_id = @deposit_id;
    COMMIT;
END;
GO

-- the owner removes a finger: the box is told to delete the template with its next heartbeat
CREATE OR ALTER PROCEDURE Fingerprint_Delete @fp_id INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @device INT, @slot INT;
    SELECT @device = device_id, @slot = sensor_slot FROM Fingerprint
    WHERE fp_id = @fp_id AND user_id = @actor AND status = N'ACTIVE';
    IF @device IS NULL THROW 50045, N'Fingerprint not found or not yours', 1;
    BEGIN TRAN;
    UPDATE Fingerprint SET status = N'DELETED' WHERE fp_id = @fp_id;
    INSERT INTO RemoteCommand (device_id, slot_id, action, reason, requested_by, expires_at, sensor_slot, source)
    VALUES (@device, NULL, N'DELETE_FP', N'Xóa vân tay', @actor, DATEADD(DAY, 7, SYSUTCDATETIME()), @slot, N'SYSTEM');
    EXEC Audit_Append @actor, N'DELETE_FINGER', N'FINGERPRINT', @fp_id, @slot;
    -- an open fingerprint booking on this box can no longer be opened: give it an enroll code to register again
    DECLARE @open BIGINT = (SELECT TOP 1 d.deposit_id FROM Deposit d
                            JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
                            WHERE d.user_id = @actor AND d.open_method = N'FINGERPRINT' AND d.enroll_code IS NULL
                              AND d.status IN (N'RESERVED', N'ACTIVE') AND b.device_id = @device);
    IF @open IS NOT NULL
    BEGIN
        DECLARE @code CHAR(6);
        EXEC Code_NewSix @code OUTPUT;
        UPDATE Deposit SET enroll_code = @code, enroll_expires = DATEADD(MINUTE, 10, SYSUTCDATETIME())
        WHERE deposit_id = @open;
    END
    COMMIT;
END;
GO
