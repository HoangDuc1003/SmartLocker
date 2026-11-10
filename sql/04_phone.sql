-- ============================================================
-- 04_phone.sql  Smart Locker v7: the phone replaces the RFID card.
-- Run after 03_v2_v3.sql. Safe to run again, also on a live database (it keeps every booking and audit row).
--   Part A  card bookings become PHONE, the card e-mail waits expire
--   Part B  the NFC tap token (DeviceTap)
--   Part C  procedures: Device_TapIssue, Device_Authorize, Deposit_Reserve, Enroll_Finish, Auth_Log, RemoteCommand_Expire
--   Part D  the card goes: UserCard, Deposit.card_id, the card deposit, confirm_hash, CardConfirm_*
-- The box has a PN532 that emulates an NFC tag. The tag holds the link /k/{device_code}?n={token}; the token comes
-- with the heartbeat and changes every minute. A phone that taps the box opens that link, the signed-in owner presses
-- "Mở tủ", and Device_Authorize (method PHONE) checks the token is fresh: the owner stands at the box.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ===== Part A. Card bookings become PHONE =====

-- a card scan waiting for its e-mail can no longer be answered
UPDATE dbo.RemoteCommand SET status = N'EXPIRED' WHERE status = N'AWAITING_EMAIL';
GO

-- the old check (PIN, CARD, FINGERPRINT) goes first, or the update below breaks it (error 547)
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Deposit_open_method')
    ALTER TABLE dbo.Deposit DROP CONSTRAINT CK_Deposit_open_method;
GO
-- open card bookings open with the phone of their owner; nothing is left to enroll for them
UPDATE dbo.Deposit SET open_method = N'PHONE', enroll_code = NULL, enroll_expires = NULL
WHERE open_method = N'CARD';
ALTER TABLE dbo.Deposit ADD CONSTRAINT CK_Deposit_open_method CHECK (open_method IN (N'PIN', N'PHONE', N'FINGERPRINT'));
GO

-- ===== Part B. The NFC tap token =====

IF OBJECT_ID(N'dbo.DeviceTap') IS NULL
CREATE TABLE dbo.DeviceTap (
    tap_id    BIGINT IDENTITY PRIMARY KEY,
    device_id INT NOT NULL REFERENCES dbo.Device(device_id),
    token     CHAR(12) NOT NULL,
    issued_at DATETIME2 NOT NULL CONSTRAINT DF_DeviceTap_issued DEFAULT SYSUTCDATETIME(),
    used_at   DATETIME2 NULL,
    used_by   INT NULL REFERENCES dbo.Users(user_id));
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_DeviceTap_device_token')
    CREATE INDEX IX_DeviceTap_device_token ON dbo.DeviceTap (device_id, token) INCLUDE (issued_at, used_at);
GO

-- ===== Part C. Procedures =====

-- The token the box writes into its NFC tag, from the heartbeat (HealthApi, "nfc":true). A new one every minute and
-- after each use; a token works for 5 minutes (time to sign in on the phone). Rows older than a day are removed.
CREATE OR ALTER PROCEDURE Device_TapIssue @device_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME(), @token CHAR(12) = NULL;
    -- no 0/O, 1/l/I: someone may read it off the screen of a phone
    DECLARE @abc VARCHAR(64) = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    DECLARE @n INT = LEN(@abc);   -- 56: every pick is a letter or a digit, never padding
    DECLARE @lock_name NVARCHAR(40) = CONCAT(N'tap-device-', @device_id);
    BEGIN TRAN;
    EXEC sp_getapplock @Resource = @lock_name, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    SELECT TOP 1 @token = token FROM DeviceTap
    WHERE device_id = @device_id AND used_at IS NULL AND issued_at > DATEADD(SECOND, -60, @now)
    ORDER BY tap_id DESC;
    IF @token IS NULL
    BEGIN
        DECLARE @raw VARBINARY(12) = CRYPT_GEN_RANDOM(12), @i INT = 1, @t VARCHAR(12) = '';
        WHILE @i <= 12
        BEGIN
            SET @t = @t + SUBSTRING(@abc, CAST(SUBSTRING(@raw, @i, 1) AS INT) % @n + 1, 1);
            SET @i = @i + 1;
        END
        SET @token = @t;
        INSERT INTO DeviceTap (device_id, token, issued_at) VALUES (@device_id, @token, @now);
        DELETE FROM DeviceTap WHERE device_id = @device_id AND issued_at < DATEADD(DAY, -1, @now);
    END
    COMMIT;
    SELECT @token AS token;
END;
GO

-- logs one try. Only guesses (a code or a finger nobody has) count towards the lockout of its channel.
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
      AND reason IN (N'WRONG_CODE', N'UNKNOWN_FINGER', N'BAD_CODE')
      AND ((@channel = N'PHONE' AND method = N'PHONE') OR (@channel <> N'PHONE' AND method NOT IN (N'PHONE', N'TAP')))
      AND at > DATEADD(MINUTE, -5, @now) AND at > ISNULL(@mark, '19000101');
    SET @left = CASE WHEN 5 - @fails < 0 THEN 0 ELSE 5 - @fails END;
    SET @retry = 0;
    IF @ok = 0 AND @left = 0 AND @reason IN (N'WRONG_CODE', N'UNKNOWN_FINGER', N'BAD_CODE')
    BEGIN
        INSERT INTO AuthAttempt (device_id, at, method, ok, reason) VALUES (@device_id, @now, @lock_method, 0, N'LOCK_START');
        SET @retry = 120;
    END
END;
GO

-- ===== Device_Authorize (v7: the phone tap): one decision for the keypad, the phone page and the finger =====
-- First good try: RESERVED -> ACTIVE (CHECK_IN). Next good try: ACTIVE -> COMPLETED (PICKUP).
-- @source = PHONE queues an UNLOCK instead; the booking changes when the box takes it (RemoteCommand_TakePending).
-- @method = PHONE is the signed-in @user_id with the @tap token of the box's NFC tag (logged as TAP, never a guess,
-- never blocked by the PIN lockout of the phone page). It opens any open booking of that user on this box, whatever
-- its open method; a demo box has no NFC reader and needs no token. The token is used up by the UNLOCK it gives.
-- v6, open many times: @intent says what a good try of an ACTIVE booking does.
--   NULL / CHECKOUT  PICKUP (old firmware and the Postman collection send no intent)
--   ASK              result CHOOSE: opens nothing, changes nothing, no guess; the box asks "A: Mo tu / B: Tra tu"
--                    and sends the same credential again with OPEN or CHECKOUT
--   OPEN             UNLOCK phase ACCESS: the booking stays ACTIVE, the slot OCCUPIED; an ACCESS audit row per open
-- An overdue-locked booking (wallet >= 0) only checks out: every intent is PICKUP. A RESERVED one always checks in.
CREATE OR ALTER PROCEDURE Device_Authorize
    @device_id INT, @method NVARCHAR(12), @pin NVARCHAR(10) = NULL, @sensor_slot INT = NULL,
    @source NVARCHAR(10) = N'DEVICE', @intent NVARCHAR(10) = NULL, @user_id INT = NULL, @tap NVARCHAR(16) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @reason NVARCHAR(20) = NULL, @phase NVARCHAR(10) = NULL, @left INT = 5, @retry INT = 0, @command BIGINT = NULL;
    DECLARE @deposit BIGINT, @status NVARCHAR(20), @slot_id INT, @slot_code NVARCHAR(20), @user INT,
            @booked NVARCHAR(12), @hold DATETIME2;
    DECLARE @debt BIGINT = NULL, @fee BIGINT = NULL, @balance BIGINT;   -- v3: overdue lock
    DECLARE @locked BIT = 0, @choose BIT = 0;                         -- v6: open many times
    DECLARE @tap_id BIGINT = NULL, @log_deposit BIGINT;               -- v7: the phone tap
    DECLARE @right_deposit BIGINT = NULL, @right_slot NVARCHAR(20) = NULL, @right_bank NVARCHAR(20) = NULL,
            @right_area NVARCHAR(150) = NULL, @right_area_code NVARCHAR(20) = NULL;             -- the box where the booking is
    IF @method = N'PHONE' SET @source = N'PHONE';
    DECLARE @log_method NVARCHAR(12) = CASE WHEN @method = N'PHONE' THEN N'TAP' WHEN @source = N'PHONE' THEN N'PHONE'
                                            ELSE @method END;
    DECLARE @channel NVARCHAR(5) = CASE WHEN @source = N'PHONE' THEN N'PHONE' ELSE N'BOX' END;
    DECLARE @lock_name NVARCHAR(40) = CONCAT(N'auth-device-', @device_id);
    -- a demo box has no ESP32: LockerMonitor beats for it (and takes its commands) every 15 s, and it has no NFC reader
    DECLARE @demo BIT = CASE WHEN EXISTS (SELECT 1 FROM (SELECT TOP 1 params_json FROM OperatingProfile WHERE device_id = @device_id
                                                        ORDER BY profile_id DESC) p WHERE p.params_json LIKE N'%"demo":true%')
                             THEN 1 ELSE 0 END;

    BEGIN TRAN;
    -- one box, one decision at a time: the counter and the booking cannot be raced
    EXEC sp_getapplock @Resource = @lock_name, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;

    IF @method <> N'PHONE'
        EXEC Auth_LockCheck @device_id, @channel, @retry OUTPUT;
    IF @retry > 0
        SET @reason = N'LOCKED_OUT';
    ELSE IF @source = N'PHONE' AND NOT EXISTS (SELECT 1 FROM Device WHERE device_id = @device_id AND status = N'ACTIVE'
                                               AND last_seen > DATEADD(SECOND, CASE WHEN @demo = 1 THEN -30 ELSE -10 END, @now))
        SET @reason = N'DEVICE_OFFLINE';            -- no heartbeat for 10 s (30 s for a demo box): the command would not reach it
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
    ELSE IF @method = N'PHONE'
    BEGIN
        SET @user = @user_id;
        IF @user IS NULL
            SET @reason = N'NOT_SIGNED_IN';
        ELSE IF @demo = 0
        BEGIN
            SELECT TOP 1 @tap_id = tap_id FROM DeviceTap WITH (UPDLOCK, HOLDLOCK)
            WHERE device_id = @device_id AND token = @tap COLLATE Latin1_General_BIN2 AND used_at IS NULL AND issued_at > DATEADD(MINUTE, -5, @now)
            ORDER BY tap_id DESC;
            IF @tap_id IS NULL SET @reason = N'TAP_EXPIRED';   -- no tap, an old tap or one already used
        END
    END
    ELSE IF @method = N'FINGERPRINT'
    BEGIN
        SELECT @user = user_id FROM Fingerprint
        WHERE device_id = @device_id AND sensor_slot = @sensor_slot AND status = N'ACTIVE';
        IF @user IS NULL SET @reason = N'UNKNOWN_FINGER';
    END
    ELSE
        SET @reason = N'BAD_METHOD';

    -- a phone or a finger: the open booking of its owner on this box
    IF @reason IS NULL AND @method IN (N'PHONE', N'FINGERPRINT')
    BEGIN
        SELECT TOP 1 @deposit = d.deposit_id
        FROM Deposit d WITH (UPDLOCK, HOLDLOCK) JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
        WHERE d.user_id = @user AND d.status IN (N'RESERVED', N'ACTIVE') AND b.device_id = @device_id;
        IF @deposit IS NULL
        BEGIN
            -- the owner's booking is at another box: a wrong place, not a wrong credential, so it is no guess and no lockout
            SELECT TOP 1 @right_deposit = d.deposit_id, @right_slot = s.slot_code, @right_bank = b.bank_code,
                   @right_area = a.name, @right_area_code = a.area_code
            FROM Deposit d JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
            JOIN LockerArea a ON a.area_id = b.area_id
            WHERE d.user_id = @user AND d.status IN (N'RESERVED', N'ACTIVE');
            IF @right_deposit IS NOT NULL
                SET @reason = N'WRONG_PLACE';
            ELSE
            BEGIN
                SELECT TOP 1 @deposit = d.deposit_id
                FROM Deposit d JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
                WHERE d.user_id = @user AND d.status = N'NO_SHOW' AND b.device_id = @device_id
                  AND d.ended_at > DATEADD(HOUR, -1, @now)
                ORDER BY d.deposit_id DESC;
                SET @reason = CASE WHEN @deposit IS NULL THEN N'NO_BOOKING' ELSE N'EXPIRED' END;
            END
        END
    END

    IF @reason IS NULL AND @deposit IS NOT NULL
    BEGIN
        SELECT @status = d.status, @slot_id = d.slot_id, @slot_code = s.slot_code, @booked = d.open_method,
               @hold = d.hold_until, @user = d.user_id
        FROM Deposit d WITH (UPDLOCK, HOLDLOCK) JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
        WHERE d.deposit_id = @deposit;
        IF @booked <> @method AND @method <> N'PHONE'       -- the owner's phone opens every method of the owner
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
                VALUES (@device_id, @slot_id, N'UNLOCK',
                        CASE WHEN @method = N'PHONE' THEN N'Chạm điện thoại' ELSE N'Mở bằng điện thoại' END,
                        @user, DATEADD(MINUTE, 2, @now), N'PHONE', @deposit, @phase);
                SET @command = SCOPE_IDENTITY();
            END
            IF @tap_id IS NOT NULL
                UPDATE DeviceTap SET used_at = @now, used_by = @user WHERE tap_id = @tap_id;   -- one tap, one open
        END
        ELSE IF @phase = N'CHECK_IN'
            EXEC Deposit_CheckIn @device_id, @slot_code, @slot_id;  -- writes the CHECK_IN audit row
        ELSE IF @phase = N'ACCESS'
        BEGIN
            -- v6: the booking stays ACTIVE and the slot OCCUPIED; one audit row per open ("Tu cua toi" counts them)
            DECLARE @sys_au INT = (SELECT user_id FROM Users WHERE username = N'system');
            DECLARE @access_note NVARCHAR(100) = CONCAT(N'{"method":"', @method, N'"}');
            EXEC Audit_Append @sys_au, N'ACCESS', N'DEPOSIT', @deposit, @access_note;
        END
        ELSE
            EXEC Deposit_Complete @device_id, @slot_code, @slot_id; -- writes the COMPLETE audit row, the slot is free again
        -- a CHOOSE is a good credential too: logged as ok, never counted towards the lockout
        EXEC Auth_Log @device_id, @channel, @log_method, 1, NULL, @deposit, @left OUTPUT, @retry OUTPUT;
    END
    ELSE IF @reason = N'LOCKED_OUT'
    BEGIN
        INSERT INTO AuthAttempt (device_id, at, method, ok, reason) VALUES (@device_id, @now, @log_method, 0, @reason);
        SET @left = 0;
    END
    ELSE
    BEGIN
        -- a try at the wrong box is logged on the booking it was for: the map of its owner warns about it
        SET @log_deposit = ISNULL(@deposit, @right_deposit);
        EXEC Auth_Log @device_id, @channel, @log_method, 0, @reason, @log_deposit, @left OUTPUT, @retry OUTPUT;
    END
    COMMIT;

    SELECT CASE WHEN @reason IS NOT NULL THEN N'DENY' WHEN @choose = 1 THEN N'CHOOSE' ELSE N'UNLOCK' END AS result,
           @phase AS phase, @reason AS reason,
           CASE WHEN @reason IS NULL OR @reason IN (N'METHOD_MISMATCH', N'EXPIRED', N'ACCOUNT_LOCKED', N'OVERDUE_UNPAID') THEN @deposit END AS deposit_id,
           CASE WHEN @reason IS NULL THEN @slot_code END AS slot_code,
           @left AS attempts_left, @retry AS retry_after_sec, @command AS command_id, @booked AS open_method,
           @debt AS debt, CASE WHEN @phase = N'PICKUP' OR @reason = N'OVERDUE_UNPAID' THEN ISNULL(@fee, 0) END AS overdue_fee,
           @right_deposit AS right_deposit, @right_slot AS right_slot, @right_bank AS right_bank,
           @right_area AS right_area, @right_area_code AS right_area_code;
END;
GO

-- ===== Part C (cont.). Booking =====

-- v3: price by size; after paying, BOOKING_BUFFER (10,000 VND) must stay in the wallet. The late fee of the size is fixed now.
-- v7: PHONE needs nothing at the box (no PIN, no enrollment): the owner taps the box with a signed-in phone.
-- "Tự chọn": @custom_min (whole hours or whole days, priced by fn_CustomPrice) replaces @plan_id; the booking
-- keeps the longest active plan not longer than it (the day pass for days) for its grace time, and its minutes.
CREATE OR ALTER PROCEDURE Deposit_Reserve
    @user_id INT, @slot_id INT, @plan_id INT, @new_id BIGINT OUTPUT, @open_method NVARCHAR(12) = N'PIN',
    @custom_min INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @open_method IS NULL OR @open_method NOT IN (N'PIN', N'PHONE', N'FINGERPRINT')
        THROW 50042, N'Choose how to open the locker: PIN, phone or fingerprint', 1;
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
    DECLARE @has_finger BIT = CASE WHEN EXISTS (SELECT 1 FROM Fingerprint WHERE user_id = @user_id
                                   AND device_id = @device_id AND status = N'ACTIVE') THEN 1 ELSE 0 END;
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
        WHERE user_id = @user_id AND balance - @price >= @buffer;
        IF @@ROWCOUNT = 0
        BEGIN
            DECLARE @balance BIGINT = (SELECT balance FROM Users WHERE user_id = @user_id);
            IF @balance >= @price
                THROW 50046, N'After booking at least 10,000 VND must stay in the wallet', 1;
            THROW 50030, N'Insufficient balance. Add funds before booking.', 1;
        END

        -- The WHERE clause is the lock: only one user can reserve a free slot.
        UPDATE LockerSlot SET status = N'RESERVED'
        WHERE locker_slot_id = @slot_id AND status = N'AVAILABLE';
        IF @@ROWCOUNT = 0 THROW 50033, N'This slot is no longer available', 1;

        IF @open_method = N'PIN'
            EXEC Code_NewSix @pin OUTPUT;
        IF @open_method = N'FINGERPRINT' AND @has_finger = 0
            EXEC Code_NewSix @enroll OUTPUT;

        INSERT INTO Deposit (user_id, slot_id, plan_id, paid_amount, status, hold_until,
                             open_method, pin_code, enroll_code, enroll_expires, size_pct, overdue_rate, custom_min)
        VALUES (@user_id, @slot_id, @plan_id, @price, N'RESERVED',
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

-- a finger: stores the template slot (v7: the card is gone, FINGERPRINT is the only thing to enroll)
CREATE OR ALTER PROCEDURE Enroll_Finish
    @device_id INT, @type NVARCHAR(12), @code NVARCHAR(10), @sensor_slot INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @deposit BIGINT, @user INT, @reason NVARCHAR(20), @left INT = 5, @retry INT = 0;
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
    ELSE IF @reason IS NULL
        SET @reason = N'BAD_CODE';
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
           @left AS attempts_left, @retry AS retry_after_sec;
END;
GO

-- only those not yet on the device: a SENT command waits for its session
CREATE OR ALTER PROCEDURE RemoteCommand_Expire
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE RemoteCommand SET status = N'EXPIRED'
    WHERE status = N'PENDING' AND expires_at < SYSUTCDATETIME();
END;
GO

-- ===== Part D. The card objects go, after the procedures that used them were replaced =====
-- (a run stopped before this point leaves the old objects in place and the new procedures working)

IF COL_LENGTH('dbo.RemoteCommand', 'confirm_hash') IS NOT NULL
    ALTER TABLE dbo.RemoteCommand DROP COLUMN confirm_hash;
GO

DROP PROCEDURE IF EXISTS dbo.CardConfirm_Find, dbo.CardConfirm_Decide, dbo.UserCard_Replace, dbo.UserCard_ReportLost;
GO

-- Deposit.card_id and its foreign key (an auto-generated name), then the table itself
DECLARE @fk SYSNAME, @sql NVARCHAR(400);
SELECT @fk = fk.name FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns c ON c.constraint_object_id = fk.object_id
WHERE fk.parent_object_id = OBJECT_ID(N'dbo.Deposit') AND COL_NAME(c.parent_object_id, c.parent_column_id) = N'card_id';
IF @fk IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE dbo.Deposit DROP CONSTRAINT ' + QUOTENAME(@fk);
    EXEC sp_executesql @sql;
END
IF COL_LENGTH('dbo.Deposit', 'card_id') IS NOT NULL
    ALTER TABLE dbo.Deposit DROP COLUMN card_id;
GO
DROP TABLE IF EXISTS dbo.UserCard;
GO

DELETE FROM dbo.AppConfig WHERE config_key = N'CARD_DEPOSIT';
DELETE rp FROM dbo.RolePerm rp JOIN dbo.Permissions p ON p.perm_id = rp.perm_id WHERE p.resource IN (N'USERCARD', N'MYCARD');
DELETE FROM dbo.Permissions WHERE resource IN (N'USERCARD', N'MYCARD');
GO

SELECT open_method, COUNT(*) AS bookings FROM dbo.Deposit GROUP BY open_method ORDER BY open_method;
GO
