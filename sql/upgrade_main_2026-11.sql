-- ============================================================
-- upgrade_main_2026-11.sql  Brings a database built from main at da95f43 up to the code of d4a5d94.
-- For a live database (Azure SQL behind Render): it changes only these objects and keeps every row.
--   column  RemoteCommand.confirm_hash (the card e-mail step)
--   new     CardConfirm_Find, CardConfirm_Decide
--   changed Deposit_CheckIn, Deposit_Complete (@locker_slot_id), Device_Heartbeat, RemoteCommand_Expire,
--           RemoteCommand_TakePending, Device_Authorize (@confirm_hash)
-- Never run all of 03_v2_v3.sql on a live database instead: it resets the key of LOCKER-01.
-- Run it in the database of the app:
--   sqlcmd -I -S <server> -d <database> -U <user> -P <password> -i sql\upgrade_main_2026-11.sql
-- Safe to run twice. The procedure texts are the last definitions of 03_v2_v3.sql, copied as they are.
-- ============================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF DB_NAME() = N'master'
    THROW 50999, N'Run this script in the database of the app (sqlcmd -d), not in master.', 1;
GO
IF COL_LENGTH('dbo.RemoteCommand', 'confirm_hash') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD confirm_hash CHAR(64) NULL;
GO

-- ===== Case 1. A locker loses its network =====

-- the device calls this every 10 seconds; coming back from OFFLINE closes the alert
CREATE OR ALTER PROCEDURE Device_Heartbeat @device_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @was NVARCHAR(20);
    DECLARE @old TABLE (status NVARCHAR(20));
    BEGIN TRAN;
    -- the old status comes from the UPDATE itself (row already locked), so a Device_MarkOffline running in
    -- between cannot leave the device ACTIVE with its DEVICE_OFFLINE alert still open
    UPDATE Device
    SET last_seen = SYSUTCDATETIME(),
        status = CASE WHEN status = N'OFFLINE' THEN N'ACTIVE' ELSE status END   -- MAINTENANCE stays
    OUTPUT deleted.status INTO @old
    WHERE device_id = @device_id;
    SELECT @was = status FROM @old;
    IF @was = N'OFFLINE'
    BEGIN
        UPDATE Alert SET status = N'RESOLVED'
        WHERE device_id = @device_id AND label = N'DEVICE_OFFLINE' AND status = N'OPEN';
        EXEC Audit_Append @sys, N'BACK_ONLINE', N'DEVICE', @device_id, NULL;
    END
    COMMIT;
END;
GO

-- only those not yet on the device (PENDING, or a card scan AWAITING_EMAIL): a SENT command waits for its session
CREATE OR ALTER PROCEDURE RemoteCommand_Expire
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE RemoteCommand SET status = N'EXPIRED'
    WHERE status IN (N'PENDING', N'AWAITING_EMAIL') AND expires_at < SYSUTCDATETIME();
END;
GO

-- a session ended: the items are out, the slot is free again
-- @locker_slot_id (optional): a box that manages several banks may see the same slot code twice; callers that
-- know the slot pass it so the right booking is closed
CREATE OR ALTER PROCEDURE Deposit_Complete @device_id INT, @slot_code NVARCHAR(20), @locker_slot_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id BIGINT, @slot_id INT;
    BEGIN TRAN;
    -- read under UPDLOCK, HOLDLOCK: a keypad PICKUP and a remote command racing on the same booking must not
    -- both close it (the second one waits, then finds no ACTIVE row)
    SELECT TOP 1 @id = d.deposit_id, @slot_id = d.slot_id
    FROM Deposit d WITH (UPDLOCK, HOLDLOCK)
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    WHERE d.status = N'ACTIVE' AND s.slot_code = @slot_code AND b.device_id = @device_id
      AND (@locker_slot_id IS NULL OR d.slot_id = @locker_slot_id);
    IF @id IS NULL
    BEGIN
        COMMIT;   -- keeps @@TRANCOUNT balanced for callers that run inside their own transaction
        RETURN;
    END
    UPDATE Deposit SET status = N'COMPLETED', ended_at = SYSUTCDATETIME() WHERE deposit_id = @id;
    UPDATE LockerSlot SET status = N'AVAILABLE' WHERE locker_slot_id = @slot_id AND status <> N'MAINTENANCE';
    EXEC Audit_Append @sys, N'COMPLETE', N'DEPOSIT', @id, NULL;
    COMMIT;
END;
GO

-- the first open starts the clock: due = now + the booked minutes ("Tự chọn") or the plan's
-- @locker_slot_id (optional): see Deposit_Complete; Device_Authorize and RemoteCommand_TakePending pass it
CREATE OR ALTER PROCEDURE Deposit_CheckIn @device_id INT, @slot_code NVARCHAR(20), @locker_slot_id INT = NULL
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
    WHERE d.status = N'RESERVED' AND s.slot_code = @slot_code AND b.device_id = @device_id
      AND (@locker_slot_id IS NULL OR d.slot_id = @locker_slot_id);
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

    -- the booking's own slot goes along: a box with several banks may hold the same slot code twice
    DECLARE @work TABLE (deposit_id BIGINT, phase NVARCHAR(10), slot_code NVARCHAR(20), slot_id INT);
    INSERT INTO @work SELECT t.deposit_id, t.phase, t.slot_code, d.slot_id
    FROM @taken t JOIN Deposit d ON d.deposit_id = t.deposit_id WHERE t.phase IS NOT NULL;
    DECLARE @work_slot INT;
    WHILE EXISTS (SELECT 1 FROM @work)
    BEGIN
        SELECT TOP 1 @dep = deposit_id, @phase = phase, @slot = slot_code, @work_slot = slot_id FROM @work;
        IF @phase = N'CHECK_IN' AND EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @dep AND status = N'RESERVED')
            EXEC Deposit_CheckIn @device_id, @slot, @work_slot;
        ELSE IF @phase = N'PICKUP' AND EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @dep AND status = N'ACTIVE')
            EXEC Deposit_Complete @device_id, @slot, @work_slot;
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
    @sensor_slot INT = NULL, @source NVARCHAR(10) = N'DEVICE', @intent NVARCHAR(10) = NULL, @confirm_hash CHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @reason NVARCHAR(20) = NULL, @phase NVARCHAR(10) = NULL, @left INT = 5, @retry INT = 0, @command BIGINT = NULL;
    DECLARE @deposit BIGINT, @status NVARCHAR(20), @slot_id INT, @slot_code NVARCHAR(20), @user INT,
            @booked NVARCHAR(12), @hold DATETIME2, @deposit_device INT;
    DECLARE @debt BIGINT = NULL, @fee BIGINT = NULL, @balance BIGINT;   -- v3: overdue lock
    DECLARE @locked BIT = 0, @choose BIT = 0;                         -- v6: open many times
    DECLARE @confirm BIT = 0, @mail_to NVARCHAR(150) = NULL, @mail_name NVARCHAR(150) = NULL, @log_deposit BIGINT,
            @sent_hash CHAR(64) = NULL, @waiting BIT = 0;                                       -- e-mail step
    DECLARE @right_deposit BIGINT = NULL, @right_slot NVARCHAR(20) = NULL, @right_bank NVARCHAR(20) = NULL,
            @right_area NVARCHAR(150) = NULL, @right_area_code NVARCHAR(20) = NULL;             -- the box where the booking is
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
            -- the owner's booking is at another box: a wrong place, not a wrong card, so it is no guess and no lockout
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

    -- the seed accounts have made-up addresses (@smartlocker.edu.vn): no mail can reach them, so their cards open as before
    IF @user IS NOT NULL AND @method = N'CARD'
        SELECT @mail_to = email, @mail_name = full_name FROM Users
        WHERE user_id = @user AND email IS NOT NULL AND email NOT LIKE N'%@smartlocker.edu.vn';

    IF @reason IS NULL
    BEGIN
        SET @phase = CASE WHEN @status = N'RESERVED' THEN N'CHECK_IN'
                          WHEN @locked = 1 THEN N'PICKUP'
                          WHEN @intent = N'ASK' THEN NULL
                          WHEN @intent = N'OPEN' THEN N'ACCESS'
                          ELSE N'PICKUP' END;
        IF @phase IS NULL
            SET @choose = 1;                              -- v6: nothing opens, nothing changes, the next call says what to do
        ELSE IF @confirm_hash IS NOT NULL AND @method = N'CARD' AND @source = N'DEVICE' AND @mail_to IS NOT NULL
        BEGIN
            -- nothing opens yet: the command waits for the link in the e-mail, then goes the way of a phone command.
            -- A second scan during the wait sends no second e-mail, unless the first could not be sent (DeviceAuthDao.mailFailed
            -- cleared its hash); another choice (OPEN after CHECKOUT) replaces the wait. A scan just after the answer, before
            -- the box took the command (one heartbeat), gets that command too.
            SET @confirm = 1;
            UPDATE RemoteCommand SET status = N'EXPIRED'
            WHERE deposit_id = @deposit AND status = N'AWAITING_EMAIL' AND (phase <> @phase OR expires_at <= @now);
            SELECT TOP 1 @command = command_id, @sent_hash = confirm_hash,
                   @waiting = CASE WHEN status = N'AWAITING_EMAIL' THEN 1 ELSE 0 END
            FROM RemoteCommand
            WHERE deposit_id = @deposit AND phase = @phase AND expires_at > @now AND status IN (N'AWAITING_EMAIL', N'PENDING')
            ORDER BY command_id DESC;
            IF @command IS NULL
            BEGIN
                INSERT INTO RemoteCommand (device_id, slot_id, action, reason, requested_by, status, expires_at, source, deposit_id,
                                           phase, confirm_hash)
                VALUES (@device_id, @slot_id, N'UNLOCK', N'Quét thẻ, xác nhận qua email', @user, N'AWAITING_EMAIL',
                        DATEADD(MINUTE, 5, @now), N'PHONE', @deposit, @phase, @confirm_hash);
                SET @command = SCOPE_IDENTITY();
            END
            ELSE IF @waiting = 1 AND @sent_hash IS NULL
                UPDATE RemoteCommand SET confirm_hash = @confirm_hash, expires_at = DATEADD(MINUTE, 5, @now) WHERE command_id = @command;
            ELSE
                SET @mail_to = NULL;                      -- already sent
            IF @mail_to IS NOT NULL
            BEGIN
                SELECT @right_bank = b.bank_code, @right_area = a.name, @right_area_code = a.area_code
                FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id JOIN LockerArea a ON a.area_id = b.area_id
                WHERE s.locker_slot_id = @slot_id;
                -- the time to answer does not come out of the hold: a scan in time must not end as a no-show without a refund
                UPDATE Deposit SET hold_until = DATEADD(MINUTE, 5, @now)
                WHERE deposit_id = @deposit AND status = N'RESERVED' AND hold_until < DATEADD(MINUTE, 5, @now);
            END
        END
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
        -- a scan at the wrong box is logged on the booking it was for: the map of its owner warns about it
        SET @log_deposit = ISNULL(@deposit, @right_deposit);
        EXEC Auth_Log @device_id, @channel, @log_method, 0, @reason, @log_deposit, @left OUTPUT, @retry OUTPUT;
    END
    COMMIT;

    SELECT CASE WHEN @reason IS NOT NULL THEN N'DENY' WHEN @choose = 1 THEN N'CHOOSE' WHEN @confirm = 1 THEN N'CONFIRM_EMAIL'
                ELSE N'UNLOCK' END AS result,
           @phase AS phase, @reason AS reason,
           CASE WHEN @reason IS NULL OR @reason IN (N'METHOD_MISMATCH', N'EXPIRED', N'ACCOUNT_LOCKED', N'OVERDUE_UNPAID') THEN @deposit END AS deposit_id,
           CASE WHEN @reason IS NULL THEN @slot_code END AS slot_code,
           @left AS attempts_left, @retry AS retry_after_sec, @command AS command_id, @booked AS open_method,
           @debt AS debt, CASE WHEN @phase = N'PICKUP' OR @reason = N'OVERDUE_UNPAID' THEN ISNULL(@fee, 0) END AS overdue_fee,
           -- for the server only (DeviceAuthApi sends the e-mail): never copied to the box
           CASE WHEN @confirm = 1 OR @reason = N'WRONG_PLACE' THEN @mail_to END AS mail_to, @mail_name AS mail_name,
           @right_deposit AS right_deposit, @right_slot AS right_slot, @right_bank AS right_bank,
           @right_area AS right_area, @right_area_code AS right_area_code;
END;
GO

-- ===== Card + e-mail: the page behind the link (CardConfirmController) =====
-- What a link stands for; changes nothing, so a mail scanner that opens the link cannot open a locker.
CREATE OR ALTER PROCEDURE CardConfirm_Find @hash CHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 c.command_id, c.status, c.phase, DATEDIFF(SECOND, SYSUTCDATETIME(), c.expires_at) AS left_sec,
           s.slot_code, b.bank_code, a.name AS area_name, a.location, v.device_code
    FROM RemoteCommand c
    JOIN LockerSlot s ON s.locker_slot_id = c.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id
    JOIN LockerArea a ON a.area_id = b.area_id JOIN Device v ON v.device_id = c.device_id
    WHERE c.confirm_hash = @hash
    ORDER BY c.command_id DESC;
END;
GO

-- The owner answers: @hash from the page behind the link, or @user_id signed in on the map (the e-mail may never come: a
-- mistyped address, the mail server down). Approve: the command becomes a PENDING one and the box takes it with its heartbeat
-- (RemoteCommand_TakePending checks the booking again and moves it on). result: OK, REJECTED, EXPIRED, DONE_BEFORE, NOT_FOUND,
-- DEVICE_OFFLINE (nothing changes: the answer works again when the box is back).
CREATE OR ALTER PROCEDURE CardConfirm_Decide @hash CHAR(64) = NULL, @approve BIT, @user_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @now DATETIME2 = SYSUTCDATETIME(), @result NVARCHAR(20), @command BIGINT, @device INT, @status NVARCHAR(20),
            @expires DATETIME2, @phase NVARCHAR(10), @deposit BIGINT, @owner INT, @lock_name NVARCHAR(40), @booking NVARCHAR(20);
    DECLARE @via NVARCHAR(30) = CASE WHEN @hash IS NULL THEN N'{"via":"map"}' ELSE N'{"via":"email"}' END;
    IF @hash IS NOT NULL
        SELECT TOP 1 @command = command_id, @device = device_id FROM RemoteCommand WHERE confirm_hash = @hash ORDER BY command_id DESC;
    ELSE
        SELECT TOP 1 @command = command_id, @device = device_id FROM RemoteCommand
        WHERE requested_by = @user_id AND status = N'AWAITING_EMAIL' AND expires_at > @now ORDER BY command_id DESC;
    IF @command IS NULL
    BEGIN
        SELECT N'NOT_FOUND' AS result;
        RETURN;
    END
    SET @lock_name = CONCAT(N'auth-device-', @device);
    BEGIN TRAN;
    EXEC sp_getapplock @Resource = @lock_name, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    SELECT @status = status, @expires = expires_at, @phase = phase, @deposit = deposit_id, @owner = requested_by
    FROM RemoteCommand WITH (UPDLOCK, HOLDLOCK) WHERE command_id = @command;
    SELECT @booking = status FROM Deposit WITH (UPDLOCK, HOLDLOCK) WHERE deposit_id = @deposit;
    IF @status <> N'AWAITING_EMAIL'
        SET @result = CASE WHEN @status = N'EXPIRED' THEN N'EXPIRED' ELSE N'DONE_BEFORE' END;
    ELSE IF @approve = 0
    BEGIN
        UPDATE RemoteCommand SET status = N'EXPIRED' WHERE command_id = @command;
        EXEC Audit_Append @owner, N'CARD_CONFIRM_REJECTED', N'DEPOSIT', @deposit, @via;
        SET @result = N'REJECTED';
    END
    ELSE IF @expires <= @now OR @booking IS NULL OR @booking <> CASE @phase WHEN N'CHECK_IN' THEN N'RESERVED' ELSE N'ACTIVE' END
    BEGIN
        UPDATE RemoteCommand SET status = N'EXPIRED' WHERE command_id = @command;
        SET @result = N'EXPIRED';
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM Device WHERE device_id = @device AND status = N'ACTIVE' AND last_seen > DATEADD(SECOND, -10, @now))
        SET @result = N'DEVICE_OFFLINE';
    ELSE
    BEGIN
        UPDATE RemoteCommand SET status = N'PENDING', expires_at = DATEADD(MINUTE, 2, @now) WHERE command_id = @command;
        UPDATE Deposit SET hold_until = DATEADD(MINUTE, 2, @now)   -- the box takes it within a heartbeat or two: no no-show meanwhile
        WHERE deposit_id = @deposit AND status = N'RESERVED' AND hold_until < DATEADD(MINUTE, 2, @now);
        EXEC Audit_Append @owner, N'CARD_CONFIRMED', N'DEPOSIT', @deposit, @via;
        SET @result = N'OK';
    END
    COMMIT;
    SELECT @result AS result;
END;
GO
