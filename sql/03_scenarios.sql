-- ============================================================
-- 03_scenarios.sql  Stored procedures of the 5 real-life cases.
-- Run after 01_schema.sql. Safe to run again (CREATE OR ALTER).
--   Case 1  locker goes offline     Device_Heartbeat, Device_MarkOffline
--   Case 2  remote unlock          RemoteCommand_Create, _TakePending, _Expire
--   Case 3  lost card              UserCard_ReportLost, UserCard_Replace
--   Case 4  booking, no show       Deposit_Reserve, _Cancel, _Extend, _CheckIn, _Complete, _ExpireNoShow
--   Case 5  broken sensor          Ticket_OpenForFault, Ticket_Close, Alert_Resolve
-- Every procedure writes Audit_Append, automatic work is done by the 'system' user.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ===== Case 1. A locker loses its network =====

-- the device calls this every 10 seconds; coming back from OFFLINE closes the alert
CREATE OR ALTER PROCEDURE Device_Heartbeat @device_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @was NVARCHAR(20) = (SELECT status FROM Device WHERE device_id = @device_id);
    BEGIN TRAN;
    UPDATE Device
    SET last_seen = SYSUTCDATETIME(),
        status = CASE WHEN status = N'OFFLINE' THEN N'ACTIVE' ELSE status END   -- MAINTENANCE stays
    WHERE device_id = @device_id;
    IF @was = N'OFFLINE'
    BEGIN
        UPDATE Alert SET status = N'RESOLVED'
        WHERE device_id = @device_id AND label = N'DEVICE_OFFLINE' AND status = N'OPEN';
        EXEC Audit_Append @sys, N'BACK_ONLINE', N'DEVICE', @device_id, NULL;
    END
    COMMIT;
END;
GO

-- LockerMonitor calls this every 30 seconds
CREATE OR ALTER PROCEDURE Device_MarkOffline @timeout_sec INT = 60
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @gone TABLE (device_id INT);
    DECLARE @id INT, @alert INT;
    BEGIN TRAN;
    UPDATE Device SET status = N'OFFLINE'
    OUTPUT inserted.device_id INTO @gone
    WHERE status = N'ACTIVE'
      AND (last_seen IS NULL OR last_seen < DATEADD(SECOND, -@timeout_sec, SYSUTCDATETIME()));
    WHILE EXISTS (SELECT 1 FROM @gone)
    BEGIN
        SELECT TOP 1 @id = device_id FROM @gone;
        INSERT INTO Alert (device_id, session_id, source, label) VALUES (@id, NULL, N'RULE', N'DEVICE_OFFLINE');
        SET @alert = SCOPE_IDENTITY();
        INSERT INTO AlertEvidence (alert_id, item, value_text)
        SELECT @alert, N'last_seen_utc', ISNULL(CONVERT(NVARCHAR(30), last_seen, 120), N'never')
        FROM Device WHERE device_id = @id;
        EXEC Audit_Append @sys, N'MARK_OFFLINE', N'DEVICE', @id, NULL;
        DELETE FROM @gone WHERE device_id = @id;
    END
    COMMIT;
END;
GO

-- ===== Case 2. Staff opens a slot from the web =====

CREATE OR ALTER PROCEDURE RemoteCommand_Create
    @slot_id INT, @reason NVARCHAR(200), @actor INT, @new_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @device_id INT, @device_status NVARCHAR(20), @owner INT;
    SELECT @device_id = v.device_id, @device_status = v.status, @owner = v.control_owner
    FROM LockerSlot s
    JOIN LockerBank b ON b.bank_id = s.bank_id
    JOIN Device v ON v.device_id = b.device_id
    WHERE s.locker_slot_id = @slot_id;

    IF @device_id IS NULL THROW 50010, N'This slot has no device', 1;
    IF @device_status <> N'ACTIVE' THROW 50011, N'Device is not online, the command cannot be delivered', 1;
    IF @owner IS NOT NULL AND @owner <> @actor THROW 50012, N'Another operator is controlling this device', 1;
    IF LEN(LTRIM(RTRIM(ISNULL(@reason, N'')))) < 5 THROW 50013, N'A reason of at least 5 characters is required', 1;

    BEGIN TRAN;
    INSERT INTO RemoteCommand (device_id, slot_id, action, reason, requested_by, expires_at)
    VALUES (@device_id, @slot_id, N'UNLOCK', LTRIM(RTRIM(@reason)), @actor, DATEADD(MINUTE, 2, SYSUTCDATETIME()));
    SET @new_id = SCOPE_IDENTITY();
    EXEC Audit_Append @actor, N'REMOTE_UNLOCK', N'LOCKERSLOT', @slot_id, @reason;
    COMMIT;
END;
GO

-- the heartbeat hands over pending commands and marks them SENT in one atomic statement
CREATE OR ALTER PROCEDURE RemoteCommand_TakePending @device_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE c SET c.status = N'SENT'
    OUTPUT inserted.command_id, s.slot_code, inserted.action
    FROM RemoteCommand c
    JOIN LockerSlot s ON s.locker_slot_id = c.slot_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.expires_at > SYSUTCDATETIME();
END;
GO

-- only PENDING ones: a SENT command is already on the device and waits for its session
CREATE OR ALTER PROCEDURE RemoteCommand_Expire
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE RemoteCommand SET status = N'EXPIRED'
    WHERE status = N'PENDING' AND expires_at < SYSUTCDATETIME();
END;
GO

-- ===== Case 3. A card is lost =====

CREATE OR ALTER PROCEDURE UserCard_ReportLost @card_id INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRAN;
    UPDATE UserCard SET status = N'LOST', lost_at = SYSUTCDATETIME()
    WHERE card_id = @card_id AND user_id = @actor AND status = N'ACTIVE';   -- only the owner, only once
    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK;
        THROW 50020, N'Card not found, not yours, or already reported', 1;
    END
    EXEC Audit_Append @actor, N'REPORT_LOST', N'USERCARD', @card_id, NULL;
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE UserCard_Replace
    @old_card_id INT, @new_uid NVARCHAR(32), @actor INT, @new_card_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @owner INT = (SELECT user_id FROM UserCard WHERE card_id = @old_card_id AND status <> N'ACTIVE');
    IF @owner IS NULL THROW 50021, N'Only a lost or blocked card can be replaced', 1;
    BEGIN TRAN;
    INSERT INTO UserCard (card_uid, user_id) VALUES (@new_uid, @owner);
    SET @new_card_id = SCOPE_IDENTITY();
    -- the running booking follows its owner to the new card
    UPDATE Deposit SET card_id = @new_card_id WHERE card_id = @old_card_id AND status IN (N'RESERVED', N'ACTIVE');
    EXEC Audit_Append @actor, N'REPLACE_CARD', N'USERCARD', @new_card_id, NULL;
    COMMIT;
END;
GO

-- ===== Case 4. Booking a slot, and not coming =====

CREATE OR ALTER PROCEDURE Deposit_Reserve
    @user_id INT, @slot_id INT, @plan_id INT, @new_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF (SELECT COUNT(*) FROM Deposit WHERE user_id = @user_id AND status = N'NO_SHOW'
        AND reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME())) >= 3
        THROW 50031, N'Booking is blocked: 3 no-shows in the last 7 days', 1;
    IF EXISTS (SELECT 1 FROM Deposit WHERE user_id = @user_id AND status IN (N'RESERVED', N'ACTIVE'))
        THROW 50032, N'You already have a booking in progress', 1;
    IF EXISTS (SELECT 1 FROM v_LockerSlotMap WHERE slot_id = @slot_id AND device_status = N'OFFLINE')
        THROW 50035, N'The locker is offline, booking is paused', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @price BIGINT;
        SELECT @price = price FROM StoragePlan WITH (UPDLOCK, HOLDLOCK)
        WHERE plan_id = @plan_id AND is_active = 1;
        IF @price IS NULL THROW 50034, N'This storage plan is not available', 1;
        IF @price < 0 THROW 50040, N'The storage plan has an invalid price', 1;

        -- The conditional update prevents spending the same balance twice.
        UPDATE Users SET balance = balance - @price
        WHERE user_id = @user_id AND balance >= @price;
        IF @@ROWCOUNT = 0 THROW 50030, N'Insufficient balance. Add funds before booking.', 1;

        -- The WHERE clause is the lock: only one user can reserve a free slot.
        UPDATE LockerSlot SET status = N'RESERVED'
        WHERE locker_slot_id = @slot_id AND status = N'AVAILABLE';
        IF @@ROWCOUNT = 0 THROW 50033, N'This slot is no longer available', 1;

        INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, hold_until)
        VALUES (@user_id, @slot_id, @plan_id, NULL, @price, N'RESERVED',
                DATEADD(MINUTE, 15, SYSUTCDATETIME()));
        SET @new_id = SCOPE_IDENTITY();
        EXEC Audit_Append @user_id, N'RESERVE', N'DEPOSIT', @new_id, @price;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE Deposit_Cancel @deposit_id BIGINT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @slot INT, @refund BIGINT;
        SELECT @slot = slot_id, @refund = paid_amount
        FROM Deposit WITH (UPDLOCK, HOLDLOCK)
        WHERE deposit_id = @deposit_id AND user_id = @actor AND status = N'RESERVED';
        IF @slot IS NULL
            THROW 50036, N'Nothing to cancel: not your reservation, or it already started', 1;

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

-- online extension: add time to the due moment, at most 3 times
CREATE OR ALTER PROCEDURE Deposit_Extend @deposit_id BIGINT, @minutes INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @minutes NOT BETWEEN 15 AND 240 THROW 50037, N'You can add between 15 and 240 minutes', 1;
    DECLARE @count INT = (SELECT extend_count FROM Deposit WHERE deposit_id = @deposit_id AND user_id = @actor AND status = N'ACTIVE');
    IF @count IS NULL THROW 50038, N'Nothing to extend: not your active booking', 1;
    IF @count >= 3 THROW 50039, N'A booking can be extended 3 times at most', 1;
    BEGIN TRAN;
    UPDATE Deposit
    SET due_at = DATEADD(MINUTE, @minutes, CASE WHEN due_at > SYSUTCDATETIME() THEN due_at ELSE SYSUTCDATETIME() END),
        extend_count = extend_count + 1
    WHERE deposit_id = @deposit_id;
    EXEC Audit_Append @actor, N'EXTEND', N'DEPOSIT', @deposit_id, @minutes;
    COMMIT;
END;
GO

-- the heartbeat says a reserved slot now holds something: start the clock
CREATE OR ALTER PROCEDURE Deposit_CheckIn @device_id INT, @slot_code NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id BIGINT, @slot_id INT, @minutes INT;
    SELECT TOP 1 @id = d.deposit_id, @slot_id = d.slot_id, @minutes = p.duration_min
    FROM Deposit d
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    JOIN StoragePlan p ON p.plan_id = d.plan_id
    WHERE d.status = N'RESERVED' AND s.slot_code = @slot_code AND b.device_id = @device_id;
    IF @id IS NULL RETURN;                            -- nothing reserved here
    BEGIN TRAN;
    UPDATE Deposit
    SET status = N'ACTIVE', started_at = SYSUTCDATETIME(), due_at = DATEADD(MINUTE, @minutes, SYSUTCDATETIME())
    WHERE deposit_id = @id;
    UPDATE LockerSlot SET status = N'OCCUPIED' WHERE locker_slot_id = @slot_id;
    EXEC Audit_Append @sys, N'CHECK_IN', N'DEPOSIT', @id, NULL;
    COMMIT;
END;
GO

-- a session ended: the items are out, the slot is free again
CREATE OR ALTER PROCEDURE Deposit_Complete @device_id INT, @slot_code NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id BIGINT, @slot_id INT;
    SELECT TOP 1 @id = d.deposit_id, @slot_id = d.slot_id
    FROM Deposit d
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    WHERE d.status = N'ACTIVE' AND s.slot_code = @slot_code AND b.device_id = @device_id;
    IF @id IS NULL RETURN;
    BEGIN TRAN;
    UPDATE Deposit SET status = N'COMPLETED', ended_at = SYSUTCDATETIME() WHERE deposit_id = @id;
    UPDATE LockerSlot SET status = N'AVAILABLE' WHERE locker_slot_id = @slot_id AND status <> N'MAINTENANCE';
    EXEC Audit_Append @sys, N'COMPLETE', N'DEPOSIT', @id, NULL;
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE Deposit_ExpireNoShow
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @expired TABLE (deposit_id BIGINT, slot_id INT, user_id INT, paid_amount BIGINT);
    DECLARE @id BIGINT, @refund BIGINT;
    BEGIN TRAN;
    UPDATE d SET d.status = N'NO_SHOW', d.ended_at = SYSUTCDATETIME()
    OUTPUT inserted.deposit_id, inserted.slot_id, inserted.user_id, inserted.paid_amount INTO @expired
    FROM Deposit d
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    LEFT JOIN Device v ON v.device_id = b.device_id
    WHERE d.status = N'RESERVED' AND d.hold_until < SYSUTCDATETIME()
      AND (v.device_id IS NULL OR v.status = N'ACTIVE');   -- device offline: we cannot know, so we wait
    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s JOIN @expired e ON e.slot_id = s.locker_slot_id;
    UPDATE u SET u.balance = u.balance + r.refund
    FROM Users u
    JOIN (SELECT user_id, SUM(paid_amount) AS refund FROM @expired GROUP BY user_id) r
      ON r.user_id = u.user_id;
    WHILE EXISTS (SELECT 1 FROM @expired)
    BEGIN
        SELECT TOP 1 @id = deposit_id, @refund = paid_amount FROM @expired;
        EXEC Audit_Append @sys, N'NO_SHOW', N'DEPOSIT', @id, @refund;
        DELETE FROM @expired WHERE deposit_id = @id;
    END
    COMMIT;
END;
GO

-- ===== Case 5. A sensor breaks =====

-- a SENSOR_FAULT alert opens one ticket per device, gives it to the least busy technician
-- and takes the slot out of service
CREATE OR ALTER PROCEDURE Ticket_OpenForFault
    @device_id INT, @alert_id INT, @session_id BIGINT, @note NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id INT;
    BEGIN TRAN;
    UPDATE LockerSlot SET status = N'MAINTENANCE'
    WHERE locker_slot_id = (SELECT slot_id FROM LockerSession WHERE session_id = @session_id);
    IF NOT EXISTS (SELECT 1 FROM MaintenanceTicket WHERE device_id = @device_id AND status = N'OPEN')
    BEGIN
        INSERT INTO MaintenanceTicket (alert_id, device_id, assigned_to, note)
        SELECT @alert_id, @device_id,
               (SELECT TOP 1 u.user_id
                FROM Users u
                JOIN UserRole ur ON ur.user_id = u.user_id
                JOIN Roles r ON r.role_id = ur.role_id AND r.role_name = N'TECHNICIAN'
                WHERE u.status = N'ACTIVE'
                ORDER BY (SELECT COUNT(*) FROM MaintenanceTicket t
                          WHERE t.assigned_to = u.user_id AND t.status = N'OPEN')),   -- least busy technician
               @note;
        SET @id = SCOPE_IDENTITY();
        EXEC Audit_Append @sys, N'OPEN_TICKET', N'MAINTENANCE', @id, @note;
    END
    COMMIT;
END;
GO

-- the technician fixed the sensor: close the ticket, give the slot back
CREATE OR ALTER PROCEDURE Ticket_Close @ticket_id INT, @actor INT, @note NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @alert INT = (SELECT alert_id FROM MaintenanceTicket WHERE ticket_id = @ticket_id AND status = N'OPEN');
    IF NOT EXISTS (SELECT 1 FROM MaintenanceTicket WHERE ticket_id = @ticket_id AND status = N'OPEN')
        THROW 50040, N'Ticket not found or already closed', 1;
    BEGIN TRAN;
    UPDATE MaintenanceTicket
    SET status = N'CLOSED', closed_at = SYSUTCDATETIME(), note = ISNULL(@note, note)
    WHERE ticket_id = @ticket_id;
    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s
    JOIN LockerSession ls ON ls.slot_id = s.locker_slot_id
    JOIN Alert a ON a.session_id = ls.session_id
    WHERE a.alert_id = @alert AND s.status = N'MAINTENANCE';
    UPDATE Alert SET status = N'RESOLVED' WHERE alert_id = @alert;
    EXEC Audit_Append @actor, N'CLOSE_TICKET', N'MAINTENANCE', @ticket_id, @note;
    COMMIT;
END;
GO

-- staff marks an alert as handled
CREATE OR ALTER PROCEDURE Alert_Resolve @alert_id INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRAN;
    UPDATE Alert SET status = N'RESOLVED' WHERE alert_id = @alert_id AND status = N'OPEN';
    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK;
        THROW 50041, N'Alert not found or already resolved', 1;
    END
    EXEC Audit_Append @actor, N'RESOLVE_ALERT', N'ALERT', @alert_id, NULL;
    COMMIT;
END;
GO
