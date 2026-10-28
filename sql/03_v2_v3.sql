﻿-- ============================================================
-- 03_v2_v3.sql  Smart Locker, PRJ301 FALL2026
-- v2 (open methods, PIN, fingerprint), Vietnamese seed names, v3 (sizes, prices, overdue) and the VNU-HCM campus.
-- Run after 02_data_v1.sql. Safe to run again; it resets the LOCKER-01 key to the public seed key (README).
-- Part 1 v2, Part 2 Vietnamese names, Part 3 v3, Part 4 campus areas.
-- Made from: 03_v2_v3.sql, 03_v2_v3.sql, 03_v2_v3.sql, 03_v2_v3.sql (same order, same statements).
-- ============================================================


-- ############################################################
-- Part 1 (was 03_v2_v3.sql)
-- ############################################################
-- ============================================================
-- 03_v2_v3.sql  Smart Locker v2 (docs/spec/smart-locker-v2.md, section 3).
-- Run after 01..05 on the existing database. Keeps every row, safe to run again.
--   Part A  columns and tables (open method, PIN, enroll code, Fingerprint, AuthAttempt)
--   Part B  demo data changes (real box LOCKER-01 on CANT-A, 4 operators, Demo 2 minutes off)
--   Part C  procedures (Deposit_Reserve, Deposit_ExpireNoShow, Device_Authorize, Enroll_*)
-- Note: running 02_data_v1.sql or 05 again brings back the v1 Deposit_Reserve and
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

-- Case 4 v2: PIN or enroll code, and room for the first card deposit (every open method costs the same)
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
    DECLARE @card_deposit BIGINT = CASE WHEN @open_method = N'CARD' AND @card_id IS NULL THEN 10000 ELSE 0 END;
    DECLARE @pin CHAR(6) = NULL, @enroll CHAR(6) = NULL;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @price BIGINT;
        SELECT @price = price FROM StoragePlan WITH (UPDLOCK, HOLDLOCK)
        WHERE plan_id = @plan_id AND is_active = 1;
        IF @price IS NULL THROW 50034, N'This storage plan is not available', 1;
        IF @price < 0 THROW 50040, N'The storage plan has an invalid price', 1;

        -- The conditional update prevents spending the same balance twice.
        -- A first card also needs the card deposit left in the wallet; it is taken at the box.
        UPDATE Users SET balance = balance - @price
        WHERE user_id = @user_id AND balance >= @price + @card_deposit;
        IF @@ROWCOUNT = 0
        BEGIN
            IF @card_deposit > 0 THROW 50041, N'Insufficient balance for the price and the card deposit', 1;
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

-- a finger: stores the template slot. A card: stores the UID and takes the one-time card deposit.
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
            UPDATE Users SET balance = balance - 10000 WHERE user_id = @user AND balance >= 10000;
            IF @@ROWCOUNT = 0
                SET @reason = N'INSUFFICIENT_BALANCE';
            ELSE
            BEGIN
                IF @card_id IS NULL
                BEGIN
                    INSERT INTO UserCard (card_uid, user_id, deposit_amount, registered_device_id)
                    VALUES (@card_uid, @user, 10000, @device_id);
                    SET @card_id = SCOPE_IDENTITY();
                END
                ELSE
                    UPDATE UserCard SET deposit_amount = deposit_amount + 10000, registered_device_id = @device_id
                    WHERE card_id = @card_id;
                UPDATE Deposit SET card_id = @card_id WHERE deposit_id = @deposit;
                EXEC Audit_Append @user, N'ENROLL_CARD', N'USERCARD', @card_id, 10000;
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

-- ############################################################
-- Part 2 (was 03_v2_v3.sql)
-- ############################################################
-- ============================================================
-- 03_v2_v3.sql  Vietnamese names for the seed data that users see.
-- Run after 01..06. Safe to run again: each UPDATE only touches a row that still has
-- the English seed text, so a name changed later by staff is kept.
-- Technical codes (area_code, bank_code, slot_code, device_code) are not changed.
-- Plans are matched by name here; scripts that need a plan look it up by duration_min.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET NOCOUNT ON;

-- Storage plans
UPDATE p SET plan_name = v.vi
FROM dbo.StoragePlan p
JOIN (VALUES (N'2 hours', N'2 giờ'), (N'4 hours', N'4 giờ'), (N'Day pass', N'Trọn ngày'),
             (N'Demo 2 minutes', N'Demo 2 phút')) v(en, vi) ON p.plan_name = v.en;

-- Areas: name and location
UPDATE a SET name = v.vi
FROM dbo.LockerArea a
JOIN (VALUES (N'LIB', N'Library', N'Thư viện'), (N'DOMA', N'Dormitory A', N'Ký túc xá A'),
             (N'CANT', N'Canteen', N'Căng tin'), (N'GYM', N'Sports Hall', N'Nhà thi đấu'),
             (N'OPS', N'Operations', N'Vận hành')) v(code, en, vi)
  ON a.area_code = v.code AND a.name = v.en;

UPDATE a SET location = v.vi
FROM dbo.LockerArea a
JOIN (VALUES (N'Library, 1st floor', N'Thư viện, tầng 1'), (N'Dorm A lobby', N'Sảnh ký túc xá A'),
             (N'Next to the canteen entrance', N'Cạnh lối vào căng tin'),
             (N'Sports hall changing room', N'Phòng thay đồ nhà thi đấu'),
             (N'Staff office, no locker slots', N'Văn phòng nhân viên, không có ngăn tủ')) v(en, vi)
  ON a.location = v.en;

-- Devices: location (the same texts as the areas)
UPDATE d SET location = v.vi
FROM dbo.Device d
JOIN (VALUES (N'Library, 1st floor', N'Thư viện, tầng 1'), (N'Dorm A lobby', N'Sảnh ký túc xá A'),
             (N'Next to the canteen entrance', N'Cạnh lối vào căng tin'),
             (N'Sports hall changing room', N'Phòng thay đồ nhà thi đấu')) v(en, vi)
  ON d.location = v.en;

-- Locker banks: "Bank A" -> "Dãy A"
UPDATE dbo.LockerBank SET name = N'Dãy ' + SUBSTRING(name, 6, 10)
WHERE name LIKE N'Bank _%';

-- The system account is shown as the actor of automatic audit rows
UPDATE dbo.Users SET full_name = N'Tài khoản hệ thống'
WHERE username = N'system' AND full_name = N'System account';

-- One seeded ticket note still says "Bank CANT-A"
UPDATE dbo.MaintenanceTicket SET note = REPLACE(note, N'Bank CANT-A', N'dãy CANT-A')
WHERE note LIKE N'%Bank CANT-A%';
GO

SELECT plan_id, plan_name, is_active FROM dbo.StoragePlan ORDER BY plan_id;
SELECT area_code, name, location FROM dbo.LockerArea ORDER BY area_id;
SELECT bank_code, name FROM dbo.LockerBank ORDER BY bank_id;
GO

-- ############################################################
-- Part 3 (was 03_v2_v3.sql)
-- ############################################################
-- ============================================================
-- 03_v2_v3.sql  Smart Locker v3 (docs/spec/smart-locker-v3.md). Run after 01..08 (or 01..07). Safe to run again.
--   Part A  config and size tables, new columns (Deposit, LockerArea, Device)
--   Part B  data: slot sizes, fake coordinates and fake IPs (replace them with real ones)
--   Part C  price functions (Java util.Pricing applies the same formulas; PricingDatabaseIntegrationTest compares)
--   Part D  booking procedures: reserve, cancel (5 minutes), no-show (no refund), extend (paid)
--   Part E  overdue: lock, late fee, escalation after 48 hours, due reminder e-mail
--   Part F  Device_Authorize, Enroll_Finish, RemoteCommand_TakePending with the overdue lock
-- Running 03, 05 or 06 again brings back older versions of these procedures: run this file after them.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

-- ===== Part A. Tables and columns =====

-- every business number of v3 lives here; the procedures read it with dbo.fn_Config, Java with AppConfigDao
IF OBJECT_ID('dbo.AppConfig', 'U') IS NULL
    CREATE TABLE dbo.AppConfig (
        config_key NVARCHAR(40) NOT NULL PRIMARY KEY,
        int_value  BIGINT NOT NULL,
        note       NVARCHAR(200) NULL);
GO
INSERT INTO dbo.AppConfig (config_key, int_value, note)
SELECT v.k, v.v, v.n
FROM (VALUES
    (N'HOLD_MIN',           15,    N'Giữ chỗ (phút) tính từ lúc đặt'),
    (N'CANCEL_FREE_MIN',    5,     N'Được hủy và hoàn 100% trong chừng này phút sau khi đặt'),
    (N'CANCEL_LATE_REFUND_PCT', 50, N'Hủy sau CANCEL_FREE_MIN phút, trước khi hết giữ chỗ: hoàn chừng này phần trăm'),
    (N'NO_SHOW_REFUND_PCT', 0,     N'Phần trăm hoàn lại khi không đến'),
    (N'BOOKING_BUFFER',     10000, N'Số dư tối thiểu còn lại sau khi đặt (đ), dự phòng phụ phí'),
    (N'OVERDUE_FEE_PCT',    150,   N'Phụ phí một giờ trễ, phần trăm của giá một giờ'),
    (N'ESCALATE_HOURS',     48,    N'Quá hạn chừng này giờ thì chuyển nhân viên xử lý'),
    (N'DUE_REMINDER_MIN',   15,    N'Gửi email nhắc trước hạn trả chừng này phút'),
    (N'CARD_DEPOSIT',       10000, N'Tiền cọc thẻ từ, thu một lần khi đăng ký thẻ tại hộp'),
    (N'CUSTOM_MAX_HOURS',   23,    N'Tự chọn theo giờ: tối đa chừng này giờ'),
    (N'CUSTOM_MAX_DAYS',    7,     N'Tự chọn theo ngày: tối đa chừng này ngày'),
    (N'CUSTOM_MULTI_DAY_PCT', 90,  N'Tự chọn 2 đến 6 ngày: mỗi ngày bằng chừng này phần trăm giá gói trọn ngày'),
    (N'CUSTOM_WEEK_PCT',    80,    N'Tự chọn từ 7 ngày: mỗi ngày bằng chừng này phần trăm giá gói trọn ngày')) v(k, v, n)
WHERE NOT EXISTS (SELECT 1 FROM dbo.AppConfig c WHERE c.config_key = v.k);
-- v5: the card deposit is 10,000 VND; a database made before still has the first default, 30,000
UPDATE dbo.AppConfig SET int_value = 10000 WHERE config_key = N'CARD_DEPOSIT' AND int_value = 30000;
GO

-- the one place for the size of a slot: measures, price factor and the items that fit (shown to the user)
IF OBJECT_ID('dbo.SlotSize', 'U') IS NULL
    CREATE TABLE dbo.SlotSize (
        size_code CHAR(1) NOT NULL PRIMARY KEY,
        size_cm   NVARCHAR(20) NOT NULL,
        price_pct INT NOT NULL CONSTRAINT CK_SlotSize_pct CHECK (price_pct BETWEEN 100 AND 500),
        items     NVARCHAR(400) NOT NULL,                 -- separated by ";"
        sort_no   INT NOT NULL);
GO
-- each step is 30% dearer than the one before: S x1.00, M x1.30, L x1.69 (spec v3, D3)
INSERT INTO dbo.SlotSize (size_code, size_cm, price_pct, items, sort_no)
SELECT v.c, v.cm, v.pct, v.items, v.n
FROM (VALUES
    ('S', N'20x20x20', 100, N'Ví;Điện thoại;Chìa khóa;Tai nghe;Sạc dự phòng;Sổ tay nhỏ', 1),
    ('M', N'40x40x40', 130, N'Laptop tới 15,6 inch;Túi xách;Balo nhỏ (dưới 40 cm);Một đôi giày;Áo khoác gấp gọn', 2),
    ('L', N'60x60x60', 169, N'Balo lớn;Vali cabin (55x40x20 cm);Mũ bảo hiểm fullface;Túi thể thao;Thùng đồ nhỏ', 3)) v(c, cm, pct, items, n)
WHERE NOT EXISTS (SELECT 1 FROM dbo.SlotSize s WHERE s.size_code = v.c);
GO

-- Deposit keeps status ACTIVE while it is overdue: the CHECK, the two unique indexes and the PIN index
-- stay valid, and the slot stays OCCUPIED so nobody else can book it. "Locked" is locked_at IS NOT NULL.
IF COL_LENGTH('dbo.Deposit', 'size_pct') IS NULL
    ALTER TABLE dbo.Deposit ADD size_pct INT NULL;                       -- price factor of the slot at booking time
IF COL_LENGTH('dbo.Deposit', 'overdue_rate') IS NULL
    ALTER TABLE dbo.Deposit ADD overdue_rate BIGINT NULL;                -- late fee of one hour, fixed at booking time
IF COL_LENGTH('dbo.Deposit', 'overdue_hours') IS NULL
    ALTER TABLE dbo.Deposit ADD overdue_hours INT NOT NULL CONSTRAINT DF_Deposit_overdue_hours DEFAULT 0;
IF COL_LENGTH('dbo.Deposit', 'overdue_fee') IS NULL
    ALTER TABLE dbo.Deposit ADD overdue_fee BIGINT NOT NULL CONSTRAINT DF_Deposit_overdue_fee DEFAULT 0;
IF COL_LENGTH('dbo.Deposit', 'locked_at') IS NULL
    ALTER TABLE dbo.Deposit ADD locked_at DATETIME2 NULL;                -- past due_at + grace_min
IF COL_LENGTH('dbo.Deposit', 'escalated_at') IS NULL
    ALTER TABLE dbo.Deposit ADD escalated_at DATETIME2 NULL;             -- handed to the staff after 48 hours
IF COL_LENGTH('dbo.Deposit', 'due_reminder_at') IS NULL
    ALTER TABLE dbo.Deposit ADD due_reminder_at DATETIME2 NULL;          -- the due reminder e-mail was sent
IF COL_LENGTH('dbo.Deposit', 'custom_min') IS NULL
    ALTER TABLE dbo.Deposit ADD custom_min INT NULL;                     -- "Tự chọn": booked minutes (NULL = the plan's)
GO

IF COL_LENGTH('dbo.LockerArea', 'latitude') IS NULL
    ALTER TABLE dbo.LockerArea ADD latitude DECIMAL(9, 6) NULL;
IF COL_LENGTH('dbo.LockerArea', 'longitude') IS NULL
    ALTER TABLE dbo.LockerArea ADD longitude DECIMAL(9, 6) NULL;
IF COL_LENGTH('dbo.Device', 'ip_address') IS NULL
    ALTER TABLE dbo.Device ADD ip_address NVARCHAR(45) NULL;            -- stored only, never used to find a place
GO

-- the reminder address is saved only after the user typed the 6-digit code sent to it (security review M1)
IF COL_LENGTH('dbo.Users', 'email_pending') IS NULL
    ALTER TABLE dbo.Users ADD email_pending NVARCHAR(150) NULL;
IF COL_LENGTH('dbo.Users', 'email_code') IS NULL
    ALTER TABLE dbo.Users ADD email_code CHAR(6) NULL;
IF COL_LENGTH('dbo.Users', 'email_code_expires') IS NULL
    ALTER TABLE dbo.Users ADD email_code_expires DATETIME2 NULL;
IF COL_LENGTH('dbo.Users', 'email_code_tries') IS NULL
    ALTER TABLE dbo.Users ADD email_code_tries INT NOT NULL CONSTRAINT DF_Users_email_code_tries DEFAULT 0;
GO

-- ===== Part B. Data =====

-- B1. Sizes by position in the column of a bank (the map fills columns top to bottom):
--     the bottom door is L, the one above it M, the rest S; a bank of 2 rows is M over L.
--     Done once (marker in AppConfig), so a size changed later by staff is kept.
IF NOT EXISTS (SELECT 1 FROM dbo.AppConfig WHERE config_key = N'V3_SIZE_LAYOUT')
BEGIN
    ;WITH pos AS (
        SELECT s.locker_slot_id, b.door_rows,
               (ROW_NUMBER() OVER (PARTITION BY s.bank_id ORDER BY s.slot_code) - 1) % b.door_rows AS r
        FROM dbo.LockerSlot s JOIN dbo.LockerBank b ON b.bank_id = s.bank_id
        WHERE b.door_rows > 0)
    UPDATE s SET s.size_code = CASE
            WHEN p.door_rows = 1 THEN 'M'
            WHEN p.r = p.door_rows - 1 THEN 'L'
            WHEN p.r = p.door_rows - 2 THEN 'M'
            ELSE 'S' END
    FROM dbo.LockerSlot s JOIN pos p ON p.locker_slot_id = s.locker_slot_id;
    INSERT INTO dbo.AppConfig (config_key, int_value, note)
    VALUES (N'V3_SIZE_LAYOUT', 1, N'Đã xếp lại cỡ ngăn theo v3 (03_v2_v3.sql chỉ làm một lần)');
END
GO
-- open bookings made before v3 were priced as size S: they keep factor 100 after the resize (once)
IF NOT EXISTS (SELECT 1 FROM dbo.AppConfig WHERE config_key = N'V3_OLD_SIZE_PCT')
BEGIN
    UPDATE dbo.Deposit SET size_pct = 100 WHERE size_pct IS NULL AND status IN (N'RESERVED', N'ACTIVE');
    INSERT INTO dbo.AppConfig (config_key, int_value, note)
    VALUES (N'V3_OLD_SIZE_PCT', 1, N'Lượt mở từ trước v3 giữ hệ số cỡ 100 (03_v2_v3.sql chỉ làm một lần)');
END
GO
-- the measures always follow SlotSize
UPDATE s SET s.size_cm = z.size_cm
FROM dbo.LockerSlot s JOIN dbo.SlotSize z ON z.size_code = s.size_code
WHERE ISNULL(s.size_cm, N'') <> z.size_cm;
GO

-- B2. FAKE coordinates around an example campus (Hoa Lac, Ha Noi). Replace them with the real places of
--     your lockers; only empty values are filled, so your own values are never overwritten.
UPDATE a SET a.latitude = v.lat, a.longitude = v.lng
FROM dbo.LockerArea a
JOIN (VALUES (N'LIB',  21.013210, 105.526540),     -- Thư viện (giả)
             (N'DOMA', 21.010850, 105.527900),     -- Ký túc xá A (giả)
             (N'CANT', 21.012300, 105.528700),     -- Căng tin (giả)
             (N'GYM',  21.014400, 105.524800))     -- Nhà thi đấu (giả)
     v(code, lat, lng) ON v.code = a.area_code
WHERE a.latitude IS NULL AND a.longitude IS NULL;
GO

-- B3. FAKE device IPs from the documentation range 192.0.2.0/24 (RFC 5737). Replace them with the real
--     addresses; only empty values are filled. An IP says nothing about where a box is.
UPDATE dbo.Device
SET ip_address = CONCAT(N'192.0.2.', 10 + device_id)
WHERE ip_address IS NULL AND device_id BETWEEN 1 AND 200;
GO

-- ===== Part C. Price functions =====

CREATE OR ALTER FUNCTION dbo.fn_Config (@key NVARCHAR(40))
RETURNS BIGINT
AS
BEGIN
    RETURN (SELECT int_value FROM dbo.AppConfig WHERE config_key = @key);
END;
GO

-- plan price times the size factor, rounded up to 100 VND (5,000 x 1.69 = 8,450 -> 8,500)
CREATE OR ALTER FUNCTION dbo.fn_SizePrice (@price BIGINT, @pct INT)
RETURNS BIGINT
AS
BEGIN
    RETURN CAST(CEILING(@price * ISNULL(@pct, 100) / 10000.0) AS BIGINT) * 100;
END;
GO

-- v5: every open method costs the same (the card is no longer 5% off), so the price of a slot is fn_SizePrice
DROP FUNCTION IF EXISTS dbo.fn_SlotPrice, dbo.fn_OpenPrice;
GO

-- One hour of a size, for every plan (spec v3 Q3): the shortest plan on sale gives the hour.
-- Hour = CEILING(sized price x 60 / minutes / 100) x 100: S 2,500, M 3,300, L 4,300 with the 2-hour plan.
CREATE OR ALTER FUNCTION dbo.fn_HourRate (@pct INT)
RETURNS BIGINT
AS
BEGIN
    DECLARE @price BIGINT, @minutes INT;
    SELECT TOP 1 @price = price, @minutes = duration_min FROM dbo.StoragePlan
    WHERE is_active = 1 AND price > 0 AND duration_min > 0 ORDER BY duration_min, plan_id;
    IF @minutes IS NULL RETURN 0;
    RETURN CAST(CEILING(dbo.fn_SizePrice(@price, @pct) * 60 / (@minutes * 100.0)) AS BIGINT) * 100;
END;
GO

-- Late fee of one hour: OVERDUE_FEE_PCT (150%) of the exact hour, rounded once: S 3,800, M 4,900, L 6,400.
CREATE OR ALTER FUNCTION dbo.fn_OverdueRate (@pct INT)
RETURNS BIGINT
AS
BEGIN
    DECLARE @price BIGINT, @minutes INT, @fee BIGINT = ISNULL(dbo.fn_Config(N'OVERDUE_FEE_PCT'), 150);
    SELECT TOP 1 @price = price, @minutes = duration_min FROM dbo.StoragePlan
    WHERE is_active = 1 AND price > 0 AND duration_min > 0 ORDER BY duration_min, plan_id;
    IF @minutes IS NULL RETURN 0;
    RETURN CAST(CEILING(dbo.fn_SizePrice(@price, @pct) * 60 * @fee / (@minutes * 10000.0)) AS BIGINT) * 100;
END;
GO

-- "Tự chọn" (custom duration): N whole hours (1..CUSTOM_MAX_HOURS) or N whole days (1..CUSTOM_MAX_DAYS).
-- Hours: min(hour of the size x N, sized day pass). Days: day pass x N x (100% for 1 day, CUSTOM_MULTI_DAY_PCT
-- for 2-6, CUSTOM_WEEK_PCT from 7), by size, rounded up once to 100 VND. The day pass is the active plan of
-- 1440 minutes. NULL when the minutes are not allowed or there is no day pass.
CREATE OR ALTER FUNCTION dbo.fn_CustomPrice (@pct INT, @minutes INT)
RETURNS BIGINT
AS
BEGIN
    DECLARE @day BIGINT = (SELECT TOP 1 price FROM dbo.StoragePlan
                           WHERE is_active = 1 AND price > 0 AND duration_min = 1440 ORDER BY plan_id);
    IF @day IS NULL OR @minutes IS NULL OR @minutes <= 0 RETURN NULL;
    DECLARE @max_h INT = ISNULL(dbo.fn_Config(N'CUSTOM_MAX_HOURS'), 23),
            @max_d INT = ISNULL(dbo.fn_Config(N'CUSTOM_MAX_DAYS'), 7);
    IF @minutes % 1440 = 0 AND @minutes / 1440 <= @max_d
    BEGIN
        DECLARE @days INT = @minutes / 1440;
        DECLARE @f INT = CASE WHEN @days = 1 THEN 100
                              WHEN @days >= 7 THEN ISNULL(dbo.fn_Config(N'CUSTOM_WEEK_PCT'), 80)
                              ELSE ISNULL(dbo.fn_Config(N'CUSTOM_MULTI_DAY_PCT'), 90) END;
        RETURN CAST(CEILING(@day * ISNULL(@pct, 100) * @days * @f / 1000000.0) AS BIGINT) * 100;
    END
    IF @minutes % 60 = 0 AND @minutes < 1440 AND @minutes / 60 <= @max_h
    BEGIN
        DECLARE @by_hour BIGINT = dbo.fn_HourRate(@pct) * (@minutes / 60), @cap BIGINT = dbo.fn_SizePrice(@day, @pct);
        RETURN CASE WHEN @by_hour < @cap THEN @by_hour ELSE @cap END;
    END
    RETURN NULL;
END;
GO

-- the colour of every door on the map; v3 adds the overdue lock and the escalation flags
CREATE OR ALTER VIEW dbo.v_LockerSlotMap AS
SELECT s.locker_slot_id AS slot_id, s.slot_code, s.size_code, s.size_cm,
       b.bank_id, b.bank_code, b.area_id,
       v.device_id, v.status AS device_status,
       CASE
           WHEN v.device_id IS NULL OR v.status = N'OFFLINE' THEN N'OFFLINE'   -- no box: nothing can open it
           WHEN s.status = N'MAINTENANCE' THEN N'MAINTENANCE'
           WHEN EXISTS (SELECT 1 FROM LockerSession ls JOIN Alert a ON a.session_id = ls.session_id
                        WHERE ls.slot_id = s.locker_slot_id AND a.status = N'OPEN') THEN N'ALERT'
           WHEN EXISTS (SELECT 1 FROM Deposit d
                        WHERE d.slot_id = s.locker_slot_id AND d.status = N'ACTIVE'
                          AND d.due_at < SYSUTCDATETIME()) THEN N'OVERDUE'
           ELSE s.status
       END AS display_status,
       CASE WHEN EXISTS (SELECT 1 FROM Deposit d WHERE d.slot_id = s.locker_slot_id AND d.status = N'ACTIVE'
                         AND d.locked_at IS NOT NULL) THEN 1 ELSE 0 END AS is_locked,
       CASE WHEN EXISTS (SELECT 1 FROM Deposit d WHERE d.slot_id = s.locker_slot_id AND d.status = N'ACTIVE'
                         AND d.escalated_at IS NOT NULL) THEN 1 ELSE 0 END AS is_escalated
FROM LockerSlot s
JOIN LockerBank b ON b.bank_id = s.bank_id
LEFT JOIN Device v ON v.device_id = b.device_id;
GO

-- ===== Part D. Booking =====

-- v3: price by size and open method; after paying, BOOKING_BUFFER (10,000 VND) must stay in the wallet
-- (with the card deposit of a first card on top). The late fee of the size is fixed now.
-- "Tự chọn": @custom_min (whole hours or whole days, priced by fn_CustomPrice) replaces @plan_id; the booking
-- keeps the longest active plan not longer than it (the day pass for days) for its grace time, and its minutes.
CREATE OR ALTER PROCEDURE Deposit_Reserve
    @user_id INT, @slot_id INT, @plan_id INT, @new_id BIGINT OUTPUT, @open_method NVARCHAR(12) = N'PIN',
    @custom_min INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @open_method IS NULL OR @open_method NOT IN (N'PIN', N'CARD', N'FINGERPRINT')
        THROW 50042, N'Choose how to open the locker: PIN, card or fingerprint', 1;
    IF @custom_min IS NOT NULL AND NOT (
           (@custom_min % 60 = 0 AND @custom_min < 1440
            AND @custom_min BETWEEN 60 AND 60 * ISNULL(dbo.fn_Config(N'CUSTOM_MAX_HOURS'), 23))
        OR (@custom_min % 1440 = 0 AND @custom_min BETWEEN 1440 AND 1440 * ISNULL(dbo.fn_Config(N'CUSTOM_MAX_DAYS'), 7)))
        THROW 50050, N'Choose whole hours or whole days within the limits', 1;
    IF (SELECT COUNT(*) FROM Deposit WHERE user_id = @user_id AND status = N'NO_SHOW'
        AND reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME())) >= 3
        THROW 50031, N'Booking is blocked: 3 no-shows in the last 7 days', 1;
    IF EXISTS (SELECT 1 FROM Deposit WHERE user_id = @user_id AND status IN (N'RESERVED', N'ACTIVE'))
        THROW 50032, N'You already have a booking in progress', 1;
    IF EXISTS (SELECT 1 FROM v_LockerSlotMap WHERE slot_id = @slot_id AND (device_id IS NULL OR device_status = N'OFFLINE'))
        THROW 50035, N'The locker is offline, booking is paused', 1;

    DECLARE @device_id INT, @pct INT;
    SELECT @device_id = b.device_id, @pct = ISNULL(z.price_pct, 100)
    FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id LEFT JOIN SlotSize z ON z.size_code = s.size_code
    WHERE s.locker_slot_id = @slot_id;
    -- a card counts once it was enrolled at a box (or staff marked it so)
    DECLARE @card_id INT = (SELECT TOP 1 card_id FROM UserCard WHERE user_id = @user_id AND status = N'ACTIVE'
                            AND (registered_device_id IS NOT NULL OR deposit_amount > 0) ORDER BY card_id DESC);
    DECLARE @has_finger BIT = CASE WHEN EXISTS (SELECT 1 FROM Fingerprint WHERE user_id = @user_id
                                   AND device_id = @device_id AND status = N'ACTIVE') THEN 1 ELSE 0 END;
    DECLARE @card_deposit BIGINT = CASE WHEN @open_method = N'CARD' AND @card_id IS NULL
                                        THEN dbo.fn_Config(N'CARD_DEPOSIT') ELSE 0 END;
    DECLARE @buffer BIGINT = ISNULL(dbo.fn_Config(N'BOOKING_BUFFER'), 0);
    DECLARE @hold INT = ISNULL(dbo.fn_Config(N'HOLD_MIN'), 15);
    DECLARE @pin CHAR(6) = NULL, @enroll CHAR(6) = NULL;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @price BIGINT;
        IF @custom_min IS NULL
        BEGIN
            SELECT @price = price FROM StoragePlan WITH (UPDLOCK, HOLDLOCK)
            WHERE plan_id = @plan_id AND is_active = 1;
            IF @price IS NULL THROW 50034, N'This storage plan is not available', 1;
            IF @price < 0 THROW 50040, N'The storage plan has an invalid price', 1;
            SET @price = dbo.fn_SizePrice(@price, @pct);
        END
        ELSE
        BEGIN
            -- the price reads the shortest plan and the day pass: lock those rows (and the kept plan) until COMMIT
            DECLARE @locked_plans INT;
            SELECT @locked_plans = COUNT(*) FROM StoragePlan WITH (UPDLOCK, HOLDLOCK)
            WHERE plan_id IN (SELECT TOP 1 plan_id FROM StoragePlan WHERE is_active = 1 AND price > 0 AND duration_min > 0
                              ORDER BY duration_min, plan_id)
               OR (is_active = 1 AND duration_min = 1440);
            SET @plan_id = NULL;
            SELECT TOP 1 @plan_id = plan_id FROM StoragePlan WITH (UPDLOCK, HOLDLOCK)
            WHERE is_active = 1 AND price > 0 AND duration_min > 0
            ORDER BY CASE WHEN duration_min <= @custom_min THEN 0 ELSE 1 END,
                     CASE WHEN duration_min <= @custom_min THEN -duration_min ELSE duration_min END, plan_id;
            SET @price = dbo.fn_CustomPrice(@pct, @custom_min);
            IF @plan_id IS NULL OR @price IS NULL OR @price <= 0
                THROW 50051, N'Custom duration is not available now', 1;
        END

        -- The conditional update prevents spending the same balance twice.
        UPDATE Users SET balance = balance - @price
        WHERE user_id = @user_id AND balance - @price - @card_deposit >= @buffer;
        IF @@ROWCOUNT = 0
        BEGIN
            DECLARE @balance BIGINT = (SELECT balance FROM Users WHERE user_id = @user_id);
            IF @balance >= @price + @card_deposit
                THROW 50046, N'After booking at least 10,000 VND must stay in the wallet', 1;
            IF @card_deposit > 0 THROW 50041, N'Insufficient balance for the price and the card deposit', 1;
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
                             open_method, pin_code, enroll_code, enroll_expires, size_pct, overdue_rate, custom_min)
        VALUES (@user_id, @slot_id, @plan_id, CASE WHEN @open_method = N'CARD' THEN @card_id END, @price, N'RESERVED',
                DATEADD(MINUTE, @hold, SYSUTCDATETIME()), @open_method, @pin, @enroll,
                CASE WHEN @enroll IS NOT NULL THEN DATEADD(MINUTE, 10, SYSUTCDATETIME()) END,
                @pct, dbo.fn_OverdueRate(@pct), @custom_min);
        SET @new_id = SCOPE_IDENTITY();
        DECLARE @diff NVARCHAR(200) = CONCAT(N'{"price":', @price, N',"method":"', @open_method, N'","size_pct":', @pct,
                                             CASE WHEN @custom_min IS NOT NULL THEN CONCAT(N',"custom_min":', @custom_min) END, N'}');
        EXEC Audit_Append @user_id, N'RESERVE', N'DEPOSIT', @new_id, @diff;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- the first open starts the clock: due = now + the booked minutes ("Tự chọn") or the plan's
CREATE OR ALTER PROCEDURE Deposit_CheckIn @device_id INT, @slot_code NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id BIGINT, @slot_id INT, @minutes INT;
    BEGIN TRAN;
    -- read and change the booking under one lock: a cancel or the no-show job at the same moment must not be undone
    SELECT TOP 1 @id = d.deposit_id, @slot_id = d.slot_id, @minutes = ISNULL(d.custom_min, p.duration_min)
    FROM Deposit d WITH (UPDLOCK, HOLDLOCK)
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    JOIN StoragePlan p ON p.plan_id = d.plan_id
    WHERE d.status = N'RESERVED' AND s.slot_code = @slot_code AND b.device_id = @device_id;
    IF @id IS NULL                                    -- nothing reserved here
    BEGIN
        COMMIT;
        RETURN;
    END
    UPDATE Deposit
    SET status = N'ACTIVE', started_at = SYSUTCDATETIME(), due_at = DATEADD(MINUTE, @minutes, SYSUTCDATETIME())
    WHERE deposit_id = @id AND status = N'RESERVED';
    IF @@ROWCOUNT = 1
    BEGIN
        UPDATE LockerSlot SET status = N'OCCUPIED' WHERE locker_slot_id = @slot_id;
        EXEC Audit_Append @sys, N'CHECK_IN', N'DEPOSIT', @id, NULL;
    END
    COMMIT;
END;
GO

-- v3: within CANCEL_FREE_MIN (5) minutes of booking everything paid comes back; after that, until the hold
-- ends, CANCEL_LATE_REFUND_PCT (50%) of it, rounded down to 100 VND, so a user who changes their mind still
-- frees the slot instead of letting it run into a no-show. @expected_refund is the amount the confirm popup
-- showed: a lower refund (the free minutes ended while the popup was open) is refused, nothing changes.
CREATE OR ALTER PROCEDURE Deposit_Cancel @deposit_id BIGINT, @actor INT, @expected_refund BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @window INT = ISNULL(dbo.fn_Config(N'CANCEL_FREE_MIN'), 5);
    DECLARE @late_pct BIGINT = ISNULL(dbo.fn_Config(N'CANCEL_LATE_REFUND_PCT'), 50);
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @slot INT, @refund BIGINT, @reserved DATETIME2, @hold DATETIME2;
        SELECT @slot = slot_id, @refund = paid_amount, @reserved = reserved_at, @hold = hold_until
        FROM Deposit WITH (UPDLOCK, HOLDLOCK)
        WHERE deposit_id = @deposit_id AND user_id = @actor AND status = N'RESERVED';
        IF @slot IS NULL
            THROW 50036, N'Nothing to cancel: not your reservation, or it already started', 1;
        IF @hold <= SYSUTCDATETIME()
            THROW 50047, N'The hold is over, the booking can no longer be cancelled', 1;
        IF @reserved <= DATEADD(MINUTE, -@window, SYSUTCDATETIME())
            SET @refund = @refund * @late_pct / 10000 * 100;
        IF @expected_refund IS NOT NULL AND @refund < @expected_refund
            THROW 50052, N'The free cancel time just ended, the refund is lower now', 1;

        UPDATE Deposit SET status = N'CANCELLED', ended_at = SYSUTCDATETIME()
        WHERE deposit_id = @deposit_id;
        UPDATE Users SET balance = balance + @refund WHERE user_id = @actor;
        UPDATE LockerSlot SET status = N'AVAILABLE' WHERE locker_slot_id = @slot;
        EXEC Audit_Append @actor, N'CANCEL', N'DEPOSIT', @deposit_id, @refund;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- v3: not coming before hold_until gives back NO_SHOW_REFUND_PCT (0%) of the price; the slot is free again
CREATE OR ALTER PROCEDURE Deposit_ExpireNoShow
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @pct BIGINT = ISNULL(dbo.fn_Config(N'NO_SHOW_REFUND_PCT'), 0);
    DECLARE @expired TABLE (deposit_id BIGINT, slot_id INT, user_id INT, refund BIGINT);
    DECLARE @id BIGINT, @refund BIGINT;
    BEGIN TRAN;
    UPDATE d SET d.status = N'NO_SHOW', d.ended_at = SYSUTCDATETIME()
    OUTPUT inserted.deposit_id, inserted.slot_id, inserted.user_id, inserted.paid_amount * @pct / 100 INTO @expired
    FROM Deposit d
    WHERE d.status = N'RESERVED' AND d.hold_until < SYSUTCDATETIME();

    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s JOIN @expired e ON e.slot_id = s.locker_slot_id
    WHERE s.status = N'RESERVED';

    UPDATE u SET u.balance = u.balance + r.refund
    FROM Users u
    JOIN (SELECT user_id, SUM(refund) AS refund FROM @expired GROUP BY user_id HAVING SUM(refund) > 0) r
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

-- v3 (Q5): an extension is paid, one hour of the size for every started hour, and is refused once the
-- booking is past its grace time (the overdue lock): that time is paid as a late fee instead.
-- The booking is read with UPDLOCK inside the transaction (Deposit before Users, the order of
-- Deposit_ChargeOverdue), so a pickup, the clock job or a double submit cannot slip in between check and change.
-- The grace minutes before an extension are not billed: the new due time counts from now (spec v3, 3.5).
CREATE OR ALTER PROCEDURE Deposit_Extend @deposit_id BIGINT, @minutes INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @minutes IS NULL OR @minutes NOT BETWEEN 15 AND 240 THROW 50037, N'You can add between 15 and 240 minutes', 1;
    DECLARE @count INT, @locked DATETIME2, @due DATETIME2, @grace INT, @pct INT, @charge BIGINT;
    BEGIN TRAN;
    SELECT @count = d.extend_count, @locked = d.locked_at, @due = d.due_at, @grace = p.grace_min,
           @pct = COALESCE(d.size_pct, z.price_pct, 100)
    FROM Deposit d WITH (UPDLOCK, HOLDLOCK) JOIN StoragePlan p ON p.plan_id = d.plan_id
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id LEFT JOIN SlotSize z ON z.size_code = s.size_code
    WHERE d.deposit_id = @deposit_id AND d.user_id = @actor AND d.status = N'ACTIVE';
    IF @count IS NULL THROW 50038, N'Nothing to extend: not your active booking', 1;   -- XACT_ABORT rolls back
    IF @locked IS NOT NULL OR DATEADD(MINUTE, @grace, @due) < SYSUTCDATETIME()
        THROW 50048, N'The booking is overdue and locked, it cannot be extended', 1;
    IF @count >= 3 THROW 50039, N'A booking can be extended 3 times at most', 1;
    SET @charge = CAST(CEILING(@minutes / 60.0) AS BIGINT) * dbo.fn_HourRate(@pct);
    UPDATE Users SET balance = balance - @charge WHERE user_id = @actor AND balance >= @charge;
    IF @@ROWCOUNT = 0 THROW 50049, N'Insufficient balance to extend', 1;
    UPDATE Deposit
    SET due_at = DATEADD(MINUTE, @minutes, CASE WHEN due_at > SYSUTCDATETIME() THEN due_at ELSE SYSUTCDATETIME() END),
        extend_count = extend_count + 1,
        paid_amount = paid_amount + @charge,
        due_reminder_at = NULL                                              -- a new due time gets a new reminder
    WHERE deposit_id = @deposit_id AND status = N'ACTIVE' AND locked_at IS NULL AND extend_count < 3;
    IF @@ROWCOUNT = 0 THROW 50038, N'Nothing to extend: not your active booking', 1;
    DECLARE @diff NVARCHAR(100) = CONCAT(N'{"minutes":', @minutes, N',"charge":', @charge, N'}');
    EXEC Audit_Append @actor, N'EXTEND', N'DEPOSIT', @deposit_id, @diff;
    COMMIT;
END;
GO

-- ===== Part E. Overdue =====

-- Locks the ACTIVE bookings past due_at + grace_min and takes the late fee of the hours not taken yet:
-- hours = CEILING(seconds since due_at / 3600), each at overdue_rate. The wallet may go below zero (a debt).
-- @deposit_id NULL: every booking (LockerMonitor); a value: that booking only (Device_Authorize at pickup).
-- Running it again takes nothing twice. No TRY/CATCH: it also runs inside the transaction of Device_Authorize.
CREATE OR ALTER PROCEDURE Deposit_ChargeOverdue @deposit_id BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @locked TABLE (deposit_id BIGINT);
    DECLARE @charged TABLE (deposit_id BIGINT, user_id INT, fee BIGINT, hours INT, total BIGINT);
    DECLARE @id BIGINT, @diff NVARCHAR(200);
    BEGIN TRAN;
    UPDATE d SET d.locked_at = @now,
                 d.overdue_rate = ISNULL(d.overdue_rate, dbo.fn_OverdueRate(COALESCE(d.size_pct, z.price_pct, 100)))
    OUTPUT inserted.deposit_id INTO @locked
    FROM Deposit d JOIN StoragePlan p ON p.plan_id = d.plan_id
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id LEFT JOIN SlotSize z ON z.size_code = s.size_code
    WHERE d.status = N'ACTIVE' AND d.locked_at IS NULL AND d.due_at IS NOT NULL
      AND DATEADD(MINUTE, p.grace_min, d.due_at) < @now
      AND (@deposit_id IS NULL OR d.deposit_id = @deposit_id)
    OPTION (RECOMPILE);   -- with a value: a key seek, so a pickup never scans into rows the clock job holds

    UPDATE d SET d.overdue_fee = d.overdue_fee + (h.hours - d.overdue_hours) * d.overdue_rate,
                 d.overdue_hours = h.hours
    OUTPUT inserted.deposit_id, inserted.user_id, inserted.overdue_fee - deleted.overdue_fee,
           inserted.overdue_hours, inserted.overdue_fee INTO @charged
    FROM Deposit d
    CROSS APPLY (SELECT CAST(CEILING(DATEDIFF_BIG(SECOND, d.due_at, @now) / 3600.0) AS INT) AS hours) h
    WHERE d.status = N'ACTIVE' AND d.locked_at IS NOT NULL AND h.hours > d.overdue_hours
      AND (@deposit_id IS NULL OR d.deposit_id = @deposit_id)
    OPTION (RECOMPILE);

    UPDATE u SET u.balance = u.balance - c.fee
    FROM Users u JOIN (SELECT user_id, SUM(fee) AS fee FROM @charged GROUP BY user_id) c ON c.user_id = u.user_id;

    WHILE EXISTS (SELECT 1 FROM @locked)
    BEGIN
        SELECT TOP 1 @id = deposit_id FROM @locked;
        EXEC Audit_Append @sys, N'OVERDUE_LOCK', N'DEPOSIT', @id, N'Past due time and grace, opening needs a non-negative balance';
        DELETE FROM @locked WHERE deposit_id = @id;
    END
    WHILE EXISTS (SELECT 1 FROM @charged)
    BEGIN
        SELECT TOP 1 @id = deposit_id, @diff = CONCAT(N'{"hours":', hours, N',"fee":', fee, N',"total":', total, N'}')
        FROM @charged;
        EXEC Audit_Append @sys, N'OVERDUE_FEE', N'DEPOSIT', @id, @diff;
        DELETE FROM @charged WHERE deposit_id = @id;
    END
    COMMIT;
END;
GO

-- v3: an overdue slot is never released by the clock any more (it still holds the user's things).
-- The 15-second job locks and charges; staff open it with a remote command when they must.
CREATE OR ALTER PROCEDURE Deposit_ExpireOverdue
AS
BEGIN
    SET NOCOUNT ON;
    SET DEADLOCK_PRIORITY LOW;            -- on a deadlock the box (Device_Authorize) wins, the job runs again in 15 s
    EXEC Deposit_ChargeOverdue NULL;
END;
GO

-- Past due_at + ESCALATE_HOURS (48): flag the booking, open an OVERDUE_ESCALATED alert for the staff of the
-- box and write the audit row, in one transaction so an escalation is never left without its alert.
-- Nothing is opened or released. Reporting to the authorities is done by the staff outside the system.
CREATE OR ALTER PROCEDURE Deposit_Escalate
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET DEADLOCK_PRIORITY LOW;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @hours INT = ISNULL(dbo.fn_Config(N'ESCALATE_HOURS'), 48);
    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @esc TABLE (deposit_id BIGINT);
    DECLARE @id BIGINT, @alert INT, @device INT, @diff NVARCHAR(200);
    BEGIN TRAN;
    UPDATE d SET d.escalated_at = @now
    OUTPUT inserted.deposit_id INTO @esc
    FROM Deposit d
    WHERE d.status = N'ACTIVE' AND d.escalated_at IS NULL AND d.due_at IS NOT NULL
      AND DATEADD(HOUR, @hours, d.due_at) < @now;
    WHILE EXISTS (SELECT 1 FROM @esc)
    BEGIN
        SELECT TOP 1 @id = deposit_id FROM @esc;
        SELECT @device = b.device_id FROM Deposit d JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
        JOIN LockerBank b ON b.bank_id = s.bank_id WHERE d.deposit_id = @id;
        INSERT INTO Alert (device_id, session_id, source, label, risk_score) VALUES (@device, NULL, N'RULE', N'OVERDUE_ESCALATED', NULL);
        SET @alert = SCOPE_IDENTITY();
        INSERT INTO AlertEvidence (alert_id, item, value_text)
        SELECT @alert, v.item, v.val
        FROM Deposit d JOIN Users u ON u.user_id = d.user_id
        JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
        CROSS APPLY (VALUES (N'deposit_id', CONVERT(NVARCHAR(200), d.deposit_id)),
                            (N'user', u.username),
                            (N'slot', CONCAT(b.bank_code, N' ', s.slot_code)),
                            (N'due_at_utc', CONVERT(NVARCHAR(200), d.due_at, 120)),
                            (N'hours_late', CONVERT(NVARCHAR(200), CEILING(DATEDIFF_BIG(SECOND, d.due_at, @now) / 3600.0))),   -- started hours, as charged
                            (N'overdue_fee', CONVERT(NVARCHAR(200), d.overdue_fee)),
                            (N'balance', CONVERT(NVARCHAR(200), u.balance))) v(item, val)
        WHERE d.deposit_id = @id;
        SET @diff = CONCAT(N'{"alert_id":', @alert, N',"hours":', @hours, N'}');
        EXEC Audit_Append @sys, N'OVERDUE_ESCALATE', N'DEPOSIT', @id, @diff;
        EXEC Audit_Append @sys, N'CREATE', N'ALERT', @alert, N'OVERDUE_ESCALATED';
        DELETE FROM @esc WHERE deposit_id = @id;
    END
    COMMIT;
END;
GO

-- the bookings whose due time comes within DUE_REMINDER_MIN (15) minutes and whose owner has an e-mail
CREATE OR ALTER PROCEDURE Deposit_DueSoon
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @min INT = ISNULL(dbo.fn_Config(N'DUE_REMINDER_MIN'), 15);
    SELECT d.deposit_id, u.email, u.full_name, s.slot_code, b.bank_code, a.name AS area_name,
           CONVERT(VARCHAR(19), d.due_at, 120) AS due_at,
           ISNULL(d.overdue_rate, dbo.fn_OverdueRate(COALESCE(d.size_pct, z.price_pct, 100))) AS overdue_rate
    FROM Deposit d JOIN Users u ON u.user_id = d.user_id
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id LEFT JOIN SlotSize z ON z.size_code = s.size_code
    JOIN LockerBank b ON b.bank_id = s.bank_id JOIN LockerArea a ON a.area_id = b.area_id
    WHERE d.status = N'ACTIVE' AND d.due_reminder_at IS NULL
      AND d.due_at > @now AND d.due_at <= DATEADD(MINUTE, @min, @now)
      AND u.email LIKE N'%_@_%';
END;
GO

-- the reminder is done: sent, or refused for good by the mail server (then it is not tried again)
CREATE OR ALTER PROCEDURE Deposit_MarkReminded @deposit_id BIGINT, @note NVARCHAR(100) = N'e-mail sent'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    BEGIN TRAN;
    UPDATE Deposit SET due_reminder_at = SYSUTCDATETIME()
    WHERE deposit_id = @deposit_id AND due_reminder_at IS NULL;
    IF @@ROWCOUNT = 1
        EXEC Audit_Append @sys, N'DUE_REMINDER', N'DEPOSIT', @deposit_id, @note;
    COMMIT;
END;
GO

-- ===== Part F. Procedures of 03_v2_v3.sql with the v3 changes =====

-- commands may have no slot (DELETE_FP); the reply carries the sensor slot and who asked.
-- A phone UNLOCK checks in, opens (ACCESS) or picks up only here, when the box takes it: an offline box changes nothing.
-- v6: the reply carries the phase, so the box knows a phone ACCESS opens like a CHECK_IN.
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

    -- v3: the wallet may have changed since the PIN was typed; a phone PICKUP of a locked booking whose
    -- owner is below zero after the late fee up to now is dropped, so the latch does not open.
    -- v6: a phone ACCESS of a booking that became overdue-locked meanwhile is dropped too (a locked slot only checks out)
    DECLARE @pickups TABLE (deposit_id BIGINT);
    INSERT INTO @pickups SELECT DISTINCT c.deposit_id
    FROM RemoteCommand c JOIN Deposit d ON d.deposit_id = c.deposit_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.phase IN (N'PICKUP', N'ACCESS') AND d.status = N'ACTIVE';
    WHILE EXISTS (SELECT 1 FROM @pickups)
    BEGIN
        SELECT TOP 1 @dep = deposit_id FROM @pickups;
        EXEC Deposit_ChargeOverdue @dep;
        DELETE FROM @pickups WHERE deposit_id = @dep;
    END
    DECLARE @dropped TABLE (command_id BIGINT, deposit_id BIGINT, phase NVARCHAR(10));
    UPDATE c SET c.status = N'EXPIRED'
    OUTPUT inserted.command_id, inserted.deposit_id, inserted.phase INTO @dropped
    FROM RemoteCommand c JOIN Deposit d ON d.deposit_id = c.deposit_id JOIN Users u ON u.user_id = d.user_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND d.locked_at IS NOT NULL
      AND ((c.phase = N'PICKUP' AND u.balance < 0) OR c.phase = N'ACCESS');
    DECLARE @sys_tp INT = (SELECT user_id FROM Users WHERE username = N'system'), @cmd BIGINT, @cmd_note NVARCHAR(100),
            @cmd_action NVARCHAR(30);
    WHILE EXISTS (SELECT 1 FROM @dropped)
    BEGIN
        SELECT TOP 1 @cmd = command_id, @dep = deposit_id, @phase = phase FROM @dropped;
        SET @cmd_note = CONCAT(N'{"command_id":', @cmd, N',"reason":"',
                               CASE @phase WHEN N'ACCESS' THEN N'OVERDUE_LOCKED' ELSE N'OVERDUE_UNPAID' END, N'"}');
        SET @cmd_action = CONCAT(N'PHONE_', @phase, N'_DROPPED');
        EXEC Audit_Append @sys_tp, @cmd_action, N'DEPOSIT', @dep, @cmd_note;
        DELETE FROM @dropped WHERE command_id = @cmd;
    END

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
        ELSE IF @phase = N'ACCESS' AND EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @dep AND status = N'ACTIVE')
            EXEC Audit_Append @sys_tp, N'ACCESS', N'DEPOSIT', @dep, N'{"method":"PHONE"}';   -- v6: one open during the rental
        DELETE FROM @work WHERE deposit_id = @dep;
    END
    COMMIT;
    SELECT command_id, slot_code, action, sensor_slot, source, phase FROM @taken;
END;
GO

-- ===== Device_Authorize (v3: the overdue lock): one decision for the keypad, the phone page, the card and the finger =====
-- First good try: RESERVED -> ACTIVE (CHECK_IN). Next good try: ACTIVE -> COMPLETED (PICKUP).
-- @source = PHONE queues an UNLOCK instead; the booking changes when the box takes it (RemoteCommand_TakePending).
-- v6, open many times: @intent says what a good try of an ACTIVE booking does.
--   NULL / CHECKOUT  PICKUP (old firmware and the Postman collection send no intent)
--   ASK              result CHOOSE: opens nothing, changes nothing, no guess; the box asks "A: Mo tu / B: Tra tu"
--                    and sends the same credential again with OPEN or CHECKOUT
--   OPEN             UNLOCK phase ACCESS: the booking stays ACTIVE, the slot OCCUPIED; an ACCESS audit row per open
-- An overdue-locked booking (wallet >= 0) only checks out: every intent is PICKUP. A RESERVED one always checks in.
CREATE OR ALTER PROCEDURE Device_Authorize
    @device_id INT, @method NVARCHAR(12), @pin NVARCHAR(10) = NULL, @card_uid NVARCHAR(32) = NULL,
    @sensor_slot INT = NULL, @source NVARCHAR(10) = N'DEVICE', @intent NVARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @reason NVARCHAR(20) = NULL, @phase NVARCHAR(10) = NULL, @left INT = 5, @retry INT = 0, @command BIGINT = NULL;
    DECLARE @deposit BIGINT, @status NVARCHAR(20), @slot_id INT, @slot_code NVARCHAR(20), @user INT,
            @booked NVARCHAR(12), @hold DATETIME2, @deposit_device INT;
    DECLARE @debt BIGINT = NULL, @fee BIGINT = NULL, @balance BIGINT;   -- v3: overdue lock
    DECLARE @locked BIT = 0, @choose BIT = 0;                         -- v6: open many times
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
        ELSE IF @status = N'ACTIVE'
        BEGIN
            -- v3: the late fee up to now; a locked slot opens only when the wallet is not below zero.
            -- OVERDUE_UNPAID is not a guess, so Auth_Log does not count it towards the lockout.
            EXEC Deposit_ChargeOverdue @deposit;
            SELECT @fee = overdue_fee FROM Deposit WHERE deposit_id = @deposit;
            SET @balance = (SELECT balance FROM Users WHERE user_id = @user);
            IF EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @deposit AND locked_at IS NOT NULL)
                SET @locked = 1;
            IF @locked = 1 AND @balance < 0
            BEGIN
                SET @reason = N'OVERDUE_UNPAID';
                SET @debt = -@balance;
            END
        END
    END

    IF @reason IS NULL
    BEGIN
        SET @phase = CASE WHEN @status = N'RESERVED' THEN N'CHECK_IN'
                          WHEN @locked = 1 THEN N'PICKUP'
                          WHEN @intent = N'ASK' THEN NULL
                          WHEN @intent = N'OPEN' THEN N'ACCESS'
                          ELSE N'PICKUP' END;
        IF @phase IS NULL
            SET @choose = 1;                              -- v6: nothing opens, nothing changes, the next call says what to do
        ELSE IF @source = N'PHONE'
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
        ELSE IF @phase = N'ACCESS'
        BEGIN
            -- v6: the booking stays ACTIVE and the slot OCCUPIED; one audit row per open ("Tu cua toi" counts them)
            DECLARE @sys_au INT = (SELECT user_id FROM Users WHERE username = N'system');
            DECLARE @access_note NVARCHAR(100) = CONCAT(N'{"method":"', @method, N'"}');
            EXEC Audit_Append @sys_au, N'ACCESS', N'DEPOSIT', @deposit, @access_note;
        END
        ELSE
            EXEC Deposit_Complete @device_id, @slot_code; -- writes the COMPLETE audit row, the slot is free again
        -- a CHOOSE is a good credential too: logged as ok, never counted towards the lockout
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

    SELECT CASE WHEN @reason IS NOT NULL THEN N'DENY' WHEN @choose = 1 THEN N'CHOOSE' ELSE N'UNLOCK' END AS result,
           @phase AS phase, @reason AS reason,
           CASE WHEN @reason IS NULL OR @reason IN (N'METHOD_MISMATCH', N'EXPIRED', N'ACCOUNT_LOCKED', N'OVERDUE_UNPAID') THEN @deposit END AS deposit_id,
           CASE WHEN @reason IS NULL THEN @slot_code END AS slot_code,
           @left AS attempts_left, @retry AS retry_after_sec, @command AS command_id, @booked AS open_method,
           @debt AS debt, CASE WHEN @phase = N'PICKUP' OR @reason = N'OVERDUE_UNPAID' THEN ISNULL(@fee, 0) END AS overdue_fee;
END;
GO

-- a finger: stores the template slot. A card: stores the UID and takes the one-time card deposit.
CREATE OR ALTER PROCEDURE Enroll_Finish
    @device_id INT, @type NVARCHAR(12), @code NVARCHAR(10), @sensor_slot INT = NULL, @card_uid NVARCHAR(32) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @deposit BIGINT, @user INT, @reason NVARCHAR(20), @left INT = 5, @retry INT = 0, @card_id INT = NULL;
    DECLARE @card_dep BIGINT = ISNULL(dbo.fn_Config(N'CARD_DEPOSIT'), 10000);   -- v3: from AppConfig
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
            UPDATE Users SET balance = balance - @card_dep WHERE user_id = @user AND balance >= @card_dep;
            IF @@ROWCOUNT = 0
                SET @reason = N'INSUFFICIENT_BALANCE';
            ELSE
            BEGIN
                IF @card_id IS NULL
                BEGIN
                    INSERT INTO UserCard (card_uid, user_id, deposit_amount, registered_device_id)
                    VALUES (@card_uid, @user, @card_dep, @device_id);
                    SET @card_id = SCOPE_IDENTITY();
                END
                ELSE
                    UPDATE UserCard SET deposit_amount = deposit_amount + @card_dep, registered_device_id = @device_id
                    WHERE card_id = @card_id;
                UPDATE Deposit SET card_id = @card_id WHERE deposit_id = @deposit;
                EXEC Audit_Append @user, N'ENROLL_CARD', N'USERCARD', @card_id, @card_dep;
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

-- ############################################################
-- Part 4 (was 03_v2_v3.sql)
-- ############################################################
-- ============================================================
-- 03_v2_v3.sql  v4: the areas sit on the VNU-HCM campus (Thu Duc / Di An) instead of the example campus.
-- Run after 03_v2_v3.sql (sqlcmd -I -f 65001). Safe to run again:
--   * a coordinate is only replaced while it is empty or still the example one (outside Ho Chi Minh City),
--     so a value typed by staff in the area form is never overwritten;
--   * a name or a location is only replaced while it still has the seed text;
--   * the new area DOMB and its cabinets are created once.
-- The coordinates of the library are APPROXIMATE (about 500 m); the other four are Google Maps pins. Put the real ones in the area form (LockerAreaController)
-- or edit the VALUES list and run this file again after setting latitude/longitude to NULL.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET NOCOUNT ON;

-- A. New area: dormitory zone B (demo cabinets, no hardware, drawn like DOMA)
IF NOT EXISTS (SELECT 1 FROM dbo.LockerArea WHERE area_code = N'DOMB')
    INSERT INTO dbo.LockerArea (area_code, name, location)
    VALUES (N'DOMB', N'Ký túc xá khu B', N'Sảnh ký túc xá khu B, ĐHQG-HCM');

INSERT INTO dbo.LockerBank (bank_code, name, area_id, device_id, door_rows)
SELECT v.code, v.name, a.area_id, NULL, 4
FROM (VALUES (N'DOMB-A', N'Bank A'), (N'DOMB-B', N'Bank B')) v(code, name)
JOIN dbo.LockerArea a ON a.area_code = N'DOMB'
WHERE NOT EXISTS (SELECT 1 FROM dbo.LockerBank b WHERE b.bank_code = v.code);

-- slots only for a bank that has none yet: A01..A16 and B01..B12; the bottom door is L, the one above it M
;WITH n AS (SELECT TOP (16) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO dbo.LockerSlot (slot_code, bank_id, size_cm, size_code, status)
SELECT RIGHT(b.bank_code, 1) + RIGHT('0' + CAST(n.i AS VARCHAR(2)), 2), b.bank_id, N'30x30x45',
       CASE WHEN (n.i - 1) % 4 = 3 THEN 'L' WHEN (n.i - 1) % 4 = 2 THEN 'M' ELSE 'S' END,
       N'AVAILABLE'
FROM dbo.LockerBank b
JOIN (VALUES (N'DOMB-A', 16), (N'DOMB-B', 12)) c(code, cnt) ON c.code = b.bank_code
JOIN n ON n.i <= c.cnt
WHERE NOT EXISTS (SELECT 1 FROM dbo.LockerSlot s WHERE s.bank_id = b.bank_id);

-- the measures always follow SlotSize (same rule as 03_v2_v3.sql)
UPDATE s SET s.size_cm = z.size_cm
FROM dbo.LockerSlot s JOIN dbo.SlotSize z ON z.size_code = s.size_code
WHERE ISNULL(s.size_cm, N'') <> z.size_cm;
GO

-- A2. DOMB gets demo boxes like DOMA: a bank with no device is OFFLINE in v_LockerSlotMap, so all 28 slots were unusable.
--     LockerMonitor fakes the heartbeat of "demo":true boxes only; the keys are the public sample pattern of 02_data_v1.sql.
DECLARE @now DATETIME2 = SYSUTCDATETIME();
DECLARE @admin INT = (SELECT user_id FROM dbo.Users WHERE username = N'admin');
DECLARE @weight INT = (SELECT sensor_type_id FROM dbo.SensorType WHERE name = N'WEIGHT');
DECLARE @domb TABLE (n INT, code NVARCHAR(30), bank NVARCHAR(30));
INSERT INTO @domb VALUES (9, N'LOCKER-09', N'DOMB-A'), (10, N'LOCKER-10', N'DOMB-B');

INSERT INTO dbo.Device (device_code, location, firmware, status, last_seen, api_key_hash)
SELECT v.code, a.location, N'1.2-enterprise', N'ACTIVE', @now,
       LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', 'device-' + CONVERT(VARCHAR(2), v.n) + '-api-key'), 2))
FROM @domb v
JOIN dbo.LockerBank b ON b.bank_code = v.bank AND b.device_id IS NULL
JOIN dbo.LockerArea a ON a.area_id = b.area_id
WHERE NOT EXISTS (SELECT 1 FROM dbo.Device d WHERE d.device_code = v.code);

UPDATE b SET b.device_id = d.device_id
FROM dbo.LockerBank b
JOIN @domb v ON v.bank = b.bank_code
JOIN dbo.Device d ON d.device_code = v.code
WHERE b.device_id IS NULL;

INSERT INTO dbo.OperatingProfile (device_id, params_json, updated_by, updated_at)
SELECT d.device_id, N'{"demo":true,"heartbeat_sec":10,"offline_timeout_sec":90,"item_left_g":50}', @admin, @now
FROM dbo.Device d JOIN @domb v ON v.code = d.device_code
WHERE NOT EXISTS (SELECT 1 FROM dbo.OperatingProfile p WHERE p.device_id = d.device_id);

INSERT INTO dbo.Calibration (device_id, sensor_type_id, offset_val, scale_val, version, valid_until, created_by)
SELECT d.device_id, @weight, 0, 1, 1, DATEADD(MONTH, 6, CAST(@now AS DATE)), @admin
FROM dbo.Device d JOIN @domb v ON v.code = d.device_code
WHERE @weight IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Calibration c WHERE c.device_id = d.device_id AND c.sensor_type_id = @weight);
GO

-- B. Names and places (only the seed texts are replaced)
UPDATE a SET a.name = v.new_name
FROM dbo.LockerArea a
JOIN (VALUES (N'DOMA', N'Ký túc xá A',    N'Ký túc xá khu A'),
             (N'GYM',  N'Nhà thi đấu',    N'Nhà văn hóa Sinh viên'),
             (N'LIB',  N'Thư viện',       N'Thư viện FPTU HCM'),
             (N'LIB',  N'Thư viện Trung tâm', N'Thư viện FPTU HCM'),
             (N'CANT', N'Căng tin',       N'Căng tin KTX khu A')) v(code, old_name, new_name)
  ON v.code = a.area_code AND a.name = v.old_name;

UPDATE a SET a.location = v.new_loc
FROM dbo.LockerArea a
JOIN (VALUES (N'DOMA', N'Sảnh ký túc xá A',              N'A14 KTX A ĐHQG TPHCM, Đông Hòa, Hồ Chí Minh'),
             (N'DOMA', N'Sảnh ký túc xá khu A, ĐHQG-HCM', N'A14 KTX A ĐHQG TPHCM, Đông Hòa, Hồ Chí Minh'),
             (N'GYM',  N'Phòng thay đồ nhà thi đấu',     N'Số 1 Lưu Hữu Phước, Đông Hòa, Hồ Chí Minh'),
             (N'GYM',  N'Nhà văn hóa Sinh viên TP.HCM, Làng Đại học', N'Số 1 Lưu Hữu Phước, Đông Hòa, Hồ Chí Minh'),
             (N'LIB',  N'Thư viện, tầng 1',              N'Thư viện, Đại học FPT TP.HCM, Khu Công nghệ cao, tầng 1'),
             (N'LIB',  N'Thư viện Trung tâm ĐHQG-HCM, tầng 1', N'Thư viện, Đại học FPT TP.HCM, Khu Công nghệ cao, tầng 1'),
             (N'CANT', N'Cạnh lối vào căng tin',         N'Căng tin cạnh ký túc xá khu A')) v(code, old_loc, new_loc)
  ON v.code = a.area_code AND a.location = v.old_loc;

-- the devices repeat the place of their area
UPDATE d SET d.location = a.location
FROM dbo.Device d
JOIN dbo.LockerBank b ON b.device_id = d.device_id
JOIN dbo.LockerArea a ON a.area_id = b.area_id
WHERE a.area_code IN (N'DOMA', N'GYM', N'LIB', N'CANT')
  AND d.location IN (N'Sảnh ký túc xá A', N'Phòng thay đồ nhà thi đấu', N'Thư viện, tầng 1', N'Cạnh lối vào căng tin',
                     N'Sảnh ký túc xá khu A, ĐHQG-HCM', N'Nhà văn hóa Sinh viên TP.HCM, Làng Đại học');
GO

-- C. Coordinates. DOMA, DOMB, GYM and CANT come from Google Maps pins; LIB (FPTU HCM) is approximate.
--    The values written by the first drafts of this file are cleared first so that they are replaced.
UPDATE dbo.LockerArea SET latitude = NULL, longitude = NULL
WHERE (area_code = N'DOMA' AND latitude IN (10.883000) AND longitude IN (106.781000))
   OR (area_code = N'DOMB' AND latitude IN (10.887000) AND longitude IN (106.777000))
   OR (area_code = N'GYM'  AND latitude IN (10.879000) AND longitude IN (106.800000))
   OR (area_code = N'CANT' AND latitude IN (10.882600) AND longitude IN (106.781500));
UPDATE a SET a.latitude = v.lat, a.longitude = v.lng
FROM dbo.LockerArea a
JOIN (VALUES (N'DOMA', 10.880078, 106.807655),    -- A14 KTX A ĐHQG TPHCM (Google Maps)
             (N'DOMB', 10.883592, 106.779613),    -- Ký túc xá khu B, ĐHQG (nhà C6) (Google Maps)
             (N'GYM',  10.875131, 106.800723),    -- Nhà Văn hóa Sinh viên TP.HCM (Google Maps)
             (N'LIB',  10.841100, 106.809900),    -- Thư viện, Đại học FPT TP.HCM (Khu Công nghệ cao, Thủ Đức)
             (N'CANT', 10.880278, 106.807855))    -- Căng tin KTX khu A: cùng chỗ với A14, lệch khoảng 30 m để hai ghim không đè nhau
     v(code, lat, lng) ON v.code = a.area_code
WHERE a.latitude IS NULL OR a.longitude IS NULL
   OR (a.area_code = N'LIB' AND a.latitude = 10.875000 AND a.longitude = 106.801000)   -- the first draft of this file
   OR a.latitude NOT BETWEEN 10.60 AND 11.20 OR a.longitude NOT BETWEEN 106.40 AND 107.10;
GO

-- D. FAKE device IPs for the library boxes (documentation range 192.0.2.0/24, RFC 5737); stored only, never used to find a place
UPDATE d SET d.ip_address = CONCAT(N'192.0.2.', 10 + d.device_id)
FROM dbo.Device d
JOIN dbo.LockerBank b ON b.device_id = d.device_id
JOIN dbo.LockerArea a ON a.area_id = b.area_id
WHERE a.area_code = N'LIB' AND d.ip_address IS NULL;
GO

SELECT area_code, name, location, latitude, longitude FROM dbo.LockerArea ORDER BY area_code;
SELECT d.device_code, d.ip_address, b.bank_code FROM dbo.Device d LEFT JOIN dbo.LockerBank b ON b.device_id = d.device_id ORDER BY d.device_id;
SELECT a.area_code, COUNT(s.locker_slot_id) AS slots
FROM dbo.LockerArea a LEFT JOIN dbo.LockerBank b ON b.area_id = a.area_id
LEFT JOIN dbo.LockerSlot s ON s.bank_id = b.bank_id GROUP BY a.area_code ORDER BY a.area_code;
GO
