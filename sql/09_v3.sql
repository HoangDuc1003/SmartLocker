-- ============================================================
-- 09_v3.sql  Smart Locker v3 (docs/spec/smart-locker-v3.md). Run after 01..08 (or 01..07). Safe to run again.
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
    (N'NO_SHOW_REFUND_PCT', 0,     N'Phần trăm hoàn lại khi không đến'),
    (N'BOOKING_BUFFER',     10000, N'Số dư tối thiểu còn lại sau khi đặt (đ), dự phòng phụ phí'),
    (N'OVERDUE_FEE_PCT',    150,   N'Phụ phí một giờ trễ, phần trăm của giá một giờ'),
    (N'ESCALATE_HOURS',     48,    N'Quá hạn chừng này giờ thì chuyển nhân viên xử lý'),
    (N'DUE_REMINDER_MIN',   15,    N'Gửi email nhắc trước hạn trả chừng này phút'),
    (N'CARD_DEPOSIT',       30000, N'Tiền cọc thẻ từ, thu một lần khi đăng ký thẻ tại hộp')) v(k, v, n)
WHERE NOT EXISTS (SELECT 1 FROM dbo.AppConfig c WHERE c.config_key = v.k);
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
    VALUES (N'V3_SIZE_LAYOUT', 1, N'Đã xếp lại cỡ ngăn theo v3 (09_v3.sql chỉ làm một lần)');
END
GO
-- open bookings made before v3 were priced as size S: they keep factor 100 after the resize (once)
IF NOT EXISTS (SELECT 1 FROM dbo.AppConfig WHERE config_key = N'V3_OLD_SIZE_PCT')
BEGIN
    UPDATE dbo.Deposit SET size_pct = 100 WHERE size_pct IS NULL AND status IN (N'RESERVED', N'ACTIVE');
    INSERT INTO dbo.AppConfig (config_key, int_value, note)
    VALUES (N'V3_OLD_SIZE_PCT', 1, N'Lượt mở từ trước v3 giữ hệ số cỡ 100 (09_v3.sql chỉ làm một lần)');
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

-- size first, then the card 5% off, each rounded up to 100 VND (L 2 hours: 8,500 -> 8,075 -> 8,100)
CREATE OR ALTER FUNCTION dbo.fn_SlotPrice (@price BIGINT, @pct INT, @method NVARCHAR(12))
RETURNS BIGINT
AS
BEGIN
    DECLARE @sized BIGINT = dbo.fn_SizePrice(@price, @pct);
    RETURN CASE WHEN @method = N'CARD' THEN CAST(CEILING(@sized * 95 / 10000.0) AS BIGINT) * 100 ELSE @sized END;
END;
GO

-- v2 callers: size factor 100
CREATE OR ALTER FUNCTION dbo.fn_OpenPrice (@price BIGINT, @method NVARCHAR(12))
RETURNS BIGINT
AS
BEGIN
    RETURN dbo.fn_SlotPrice(@price, 100, @method);
END;
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
        SELECT @price = price FROM StoragePlan WITH (UPDLOCK, HOLDLOCK)
        WHERE plan_id = @plan_id AND is_active = 1;
        IF @price IS NULL THROW 50034, N'This storage plan is not available', 1;
        IF @price < 0 THROW 50040, N'The storage plan has an invalid price', 1;
        SET @price = dbo.fn_SlotPrice(@price, @pct, @open_method);

        -- The conditional update prevents spending the same balance twice.
        UPDATE Users SET balance = balance - @price
        WHERE user_id = @user_id AND balance - @price - @card_deposit >= @buffer;
        IF @@ROWCOUNT = 0
        BEGIN
            DECLARE @balance BIGINT = (SELECT balance FROM Users WHERE user_id = @user_id);
            IF @balance >= @price + @card_deposit
                THROW 50046, N'After booking at least 10,000 VND must stay in the wallet', 1;
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
                             open_method, pin_code, enroll_code, enroll_expires, size_pct, overdue_rate)
        VALUES (@user_id, @slot_id, @plan_id, CASE WHEN @open_method = N'CARD' THEN @card_id END, @price, N'RESERVED',
                DATEADD(MINUTE, @hold, SYSUTCDATETIME()), @open_method, @pin, @enroll,
                CASE WHEN @enroll IS NOT NULL THEN DATEADD(MINUTE, 10, SYSUTCDATETIME()) END,
                @pct, dbo.fn_OverdueRate(@pct));
        SET @new_id = SCOPE_IDENTITY();
        DECLARE @diff NVARCHAR(200) = CONCAT(N'{"price":', @price, N',"method":"', @open_method, N'","size_pct":', @pct, N'}');
        EXEC Audit_Append @user_id, N'RESERVE', N'DEPOSIT', @new_id, @diff;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- v3: only within CANCEL_FREE_MIN (5) minutes of booking, everything paid comes back
CREATE OR ALTER PROCEDURE Deposit_Cancel @deposit_id BIGINT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @window INT = ISNULL(dbo.fn_Config(N'CANCEL_FREE_MIN'), 5);
    BEGIN TRY
        BEGIN TRAN;
        DECLARE @slot INT, @refund BIGINT, @reserved DATETIME2;
        SELECT @slot = slot_id, @refund = paid_amount, @reserved = reserved_at
        FROM Deposit WITH (UPDLOCK, HOLDLOCK)
        WHERE deposit_id = @deposit_id AND user_id = @actor AND status = N'RESERVED';
        IF @slot IS NULL
            THROW 50036, N'Nothing to cancel: not your reservation, or it already started', 1;
        IF @reserved <= DATEADD(MINUTE, -@window, SYSUTCDATETIME())
            THROW 50047, N'The 5 minutes to cancel are over', 1;

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

-- ===== Part F. Procedures of 06_demo_v2.sql with the v3 changes =====

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

    -- v3: the wallet may have changed since the PIN was typed; a phone PICKUP of a locked booking whose
    -- owner is below zero after the late fee up to now is dropped, so the latch does not open
    DECLARE @pickups TABLE (deposit_id BIGINT);
    INSERT INTO @pickups SELECT DISTINCT c.deposit_id
    FROM RemoteCommand c JOIN Deposit d ON d.deposit_id = c.deposit_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.phase = N'PICKUP' AND d.status = N'ACTIVE';
    WHILE EXISTS (SELECT 1 FROM @pickups)
    BEGIN
        SELECT TOP 1 @dep = deposit_id FROM @pickups;
        EXEC Deposit_ChargeOverdue @dep;
        DELETE FROM @pickups WHERE deposit_id = @dep;
    END
    DECLARE @dropped TABLE (command_id BIGINT, deposit_id BIGINT);
    UPDATE c SET c.status = N'EXPIRED'
    OUTPUT inserted.command_id, inserted.deposit_id INTO @dropped
    FROM RemoteCommand c JOIN Deposit d ON d.deposit_id = c.deposit_id JOIN Users u ON u.user_id = d.user_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.phase = N'PICKUP'
      AND d.locked_at IS NOT NULL AND u.balance < 0;
    DECLARE @sys_tp INT = (SELECT user_id FROM Users WHERE username = N'system'), @cmd BIGINT, @cmd_note NVARCHAR(100);
    WHILE EXISTS (SELECT 1 FROM @dropped)
    BEGIN
        SELECT TOP 1 @cmd = command_id, @dep = deposit_id FROM @dropped;
        SET @cmd_note = CONCAT(N'{"command_id":', @cmd, N',"reason":"OVERDUE_UNPAID"}');
        EXEC Audit_Append @sys_tp, N'PHONE_PICKUP_DROPPED', N'DEPOSIT', @dep, @cmd_note;
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
        DELETE FROM @work WHERE deposit_id = @dep;
    END
    COMMIT;
    SELECT command_id, slot_code, action, sensor_slot, source FROM @taken;
END;
GO

-- ===== Device_Authorize (v3: the overdue lock): one decision for the keypad, the phone page, the card and the finger =====
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
    DECLARE @debt BIGINT = NULL, @fee BIGINT = NULL, @balance BIGINT;   -- v3: overdue lock
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
            IF EXISTS (SELECT 1 FROM Deposit WHERE deposit_id = @deposit AND locked_at IS NOT NULL) AND @balance < 0
            BEGIN
                SET @reason = N'OVERDUE_UNPAID';
                SET @debt = -@balance;
            END
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
           CASE WHEN @reason IS NULL OR @reason IN (N'METHOD_MISMATCH', N'EXPIRED', N'ACCOUNT_LOCKED', N'OVERDUE_UNPAID') THEN @deposit END AS deposit_id,
           CASE WHEN @reason IS NULL THEN @slot_code END AS slot_code,
           @left AS attempts_left, @retry AS retry_after_sec, @command AS command_id, @booked AS open_method,
           @debt AS debt, CASE WHEN @phase = N'PICKUP' OR @reason = N'OVERDUE_UNPAID' THEN ISNULL(@fee, 0) END AS overdue_fee;
END;
GO

-- a finger: stores the template slot. A card: stores the UID and takes the one-time 30,000 VND deposit.
CREATE OR ALTER PROCEDURE Enroll_Finish
    @device_id INT, @type NVARCHAR(12), @code NVARCHAR(10), @sensor_slot INT = NULL, @card_uid NVARCHAR(32) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @deposit BIGINT, @user INT, @reason NVARCHAR(20), @left INT = 5, @retry INT = 0, @card_id INT = NULL;
    DECLARE @card_dep BIGINT = ISNULL(dbo.fn_Config(N'CARD_DEPOSIT'), 30000);   -- v3: from AppConfig
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
