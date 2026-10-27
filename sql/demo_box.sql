-- SmartLocker: the real box, the banks it manages and its one physical compartment.
-- Edit only the three settings below, then run (safe to run again):
--   sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -b -f 65001 -i sql\demo_box.sql
--
-- The box authorizes every booking of the banks it manages (CHECK_IN / PICKUP move on as usual), but the
-- servo moves only for the physical slot; any other slot shows "OK" on the LCD (UNLOCK reply "physical":false).
-- Banks the box gives up get a "demo":true device, so they stay ONLINE on the map.
-- The API key of the device is never touched (scripts/set-device-key.ps1 owns it).

-- ===== Settings =====
DECLARE @device_code   NVARCHAR(30)  = N'LOCKER-01';  -- the real ESP32 box
DECLARE @banks         NVARCHAR(400) = N'CANT-A';     -- banks it manages, comma separated, e.g. N'CANT-A,CANT-B'
DECLARE @physical_bank NVARCHAR(20)  = N'CANT-A';     -- bank + slot of the compartment with the servo;
DECLARE @physical_slot NVARCHAR(20)  = N'A01';        --   both NULL: every slot of the box moves the servo
-- ====================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @list TABLE (bank_code NVARCHAR(20) PRIMARY KEY);
INSERT INTO @list SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@banks, N',') WHERE LTRIM(RTRIM(value)) <> N'';

DECLARE @dev INT = (SELECT device_id FROM dbo.Device WHERE device_code = @device_code);
IF @dev IS NULL
    THROW 50901, N'Không tìm thấy thiết bị @device_code.', 1;
IF NOT EXISTS (SELECT 1 FROM @list)
    THROW 50902, N'@banks rỗng: hộp phải quản lý ít nhất một dãy tủ.', 1;
IF EXISTS (SELECT 1 FROM @list l WHERE NOT EXISTS (SELECT 1 FROM dbo.LockerBank b WHERE b.bank_code = l.bank_code))
    THROW 50903, N'Có mã dãy tủ trong @banks không tồn tại.', 1;
-- Deposit_CheckIn / Deposit_Complete find the booking by device + slot code, so the codes must not repeat
IF EXISTS (SELECT s.slot_code FROM dbo.LockerSlot s JOIN dbo.LockerBank b ON b.bank_id = s.bank_id
           JOIN @list l ON l.bank_code = b.bank_code GROUP BY s.slot_code HAVING COUNT(*) > 1)
    THROW 50904, N'Các dãy tủ trong @banks có mã ngăn trùng nhau (ví dụ A01 ở hai dãy); chọn các dãy có mã ngăn khác nhau.', 1;

-- a bank the box gives up keeps its open bookings, but its fingers and phone commands belong to this device
IF EXISTS (SELECT 1 FROM dbo.Deposit d JOIN dbo.LockerSlot s ON s.locker_slot_id = d.slot_id
           JOIN dbo.LockerBank b ON b.bank_id = s.bank_id
           WHERE b.device_id = @dev AND b.bank_code NOT IN (SELECT bank_code FROM @list)
             AND d.status IN (N'RESERVED', N'ACTIVE'))
    THROW 50906, N'Dãy tủ mà hộp sắp bỏ ra còn lượt gửi RESERVED/ACTIVE; chờ các lượt đó kết thúc rồi chạy lại.', 1;

DECLARE @physical_id INT = NULL;
IF @physical_bank IS NOT NULL OR @physical_slot IS NOT NULL
BEGIN
    SELECT @physical_id = s.locker_slot_id
    FROM dbo.LockerSlot s JOIN dbo.LockerBank b ON b.bank_id = s.bank_id
    JOIN @list l ON l.bank_code = b.bank_code
    WHERE b.bank_code = @physical_bank AND s.slot_code = @physical_slot;
    IF @physical_id IS NULL
        THROW 50905, N'Ngăn vật lý không thuộc các dãy trong @banks.', 1;
END;

DECLARE @sys INT = (SELECT user_id FROM dbo.Users WHERE username = N'system');
DECLARE @now DATETIME2 = SYSUTCDATETIME();

BEGIN TRAN;

-- one device per bank was a unique index; a box that manages several banks needs it gone
IF (SELECT COUNT(*) FROM @list) > 1
   AND EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_LockerBank_device' AND object_id = OBJECT_ID(N'dbo.LockerBank'))
    DROP INDEX UX_LockerBank_device ON dbo.LockerBank;

-- 1. banks the box gives up lose it for now (they get a demo device in step 3)
DECLARE @released TABLE (bank_id INT PRIMARY KEY, bank_code NVARCHAR(20), name NVARCHAR(40));
UPDATE b SET b.device_id = NULL
OUTPUT inserted.bank_id, inserted.bank_code, inserted.name INTO @released
FROM dbo.LockerBank b
WHERE b.device_id = @dev AND b.bank_code NOT IN (SELECT bank_code FROM @list);

-- 2. the box takes its banks; their old demo devices become spare
UPDATE b SET b.device_id = @dev
FROM dbo.LockerBank b JOIN @list l ON l.bank_code = b.bank_code
WHERE b.device_id IS NULL OR b.device_id <> @dev;

-- 3. every released bank gets a spare demo device, or a new one
DECLARE @bank INT, @bank_code NVARCHAR(20), @bank_name NVARCHAR(40), @spare INT, @spare_code NVARCHAR(30);
WHILE EXISTS (SELECT 1 FROM @released)
BEGIN
    SELECT TOP 1 @bank = bank_id, @bank_code = bank_code, @bank_name = name FROM @released ORDER BY bank_code;
    SET @spare = (SELECT TOP 1 d.device_id FROM dbo.Device d
                  WHERE d.device_id <> @dev
                    AND NOT EXISTS (SELECT 1 FROM dbo.LockerBank x WHERE x.device_id = d.device_id)
                    AND EXISTS (SELECT 1 FROM dbo.OperatingProfile p
                                WHERE p.device_id = d.device_id AND p.params_json LIKE N'%"demo":true%')
                  ORDER BY d.device_code);
    IF @spare IS NULL
    BEGIN
        SET @spare_code = CONCAT(N'DEMO-', @bank_code);
        INSERT INTO dbo.Device (device_code, location, firmware, status, last_seen, api_key_hash)
        VALUES (@spare_code, @bank_name, N'demo', N'ACTIVE', @now,
                LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONVERT(NVARCHAR(36), NEWID())), 2)));  -- nobody knows the key
        SET @spare = SCOPE_IDENTITY();
        INSERT INTO dbo.OperatingProfile (device_id, params_json, updated_by, updated_at)
        VALUES (@spare, N'{"demo":true,"heartbeat_sec":10,"offline_timeout_sec":90,"item_left_g":50}', @sys, @now);
    END;
    -- LockerMonitor gives a heartbeat only to an ACTIVE demo device
    UPDATE dbo.Device SET status = N'ACTIVE', last_seen = @now WHERE device_id = @spare;
    UPDATE dbo.LockerBank SET device_id = @spare WHERE bank_id = @bank;
    DELETE FROM @released WHERE bank_id = @bank;
END;

-- 4. profiles: the box is real ("demo":false) and knows its physical slot; there is one real box
IF NOT EXISTS (SELECT 1 FROM dbo.OperatingProfile WHERE device_id = @dev)
    INSERT INTO dbo.OperatingProfile (device_id, params_json, updated_by, updated_at)
    VALUES (@dev, N'{"demo":false,"heartbeat_sec":3,"offline_timeout_sec":90,"item_left_g":50}', @sys, @now);
UPDATE dbo.OperatingProfile
SET params_json = JSON_MODIFY(JSON_MODIFY(COALESCE(params_json, N'{}'), N'$.demo', CAST(0 AS BIT)), N'$.physical_slot_id', @physical_id),
    updated_by = @sys, updated_at = @now
WHERE device_id = @dev;
UPDATE dbo.OperatingProfile
SET params_json = JSON_MODIFY(JSON_MODIFY(COALESCE(params_json, N'{}'), N'$.demo', CAST(1 AS BIT)), N'$.physical_slot_id', NULL),
    updated_by = @sys, updated_at = @now
WHERE device_id <> @dev
  AND (params_json LIKE N'%"demo":false%' OR params_json LIKE N'%"physical_slot_id"%');

-- back to one bank per device: the unique index returns
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_LockerBank_device' AND object_id = OBJECT_ID(N'dbo.LockerBank'))
   AND NOT EXISTS (SELECT device_id FROM dbo.LockerBank WHERE device_id IS NOT NULL GROUP BY device_id HAVING COUNT(*) > 1)
    CREATE UNIQUE INDEX UX_LockerBank_device ON dbo.LockerBank(device_id) WHERE device_id IS NOT NULL;

DECLARE @note NVARCHAR(MAX) = CONCAT(N'{"banks":"', STRING_ESCAPE(@banks, 'json'), N'","physical_slot_id":',
                                     COALESCE(CONVERT(NVARCHAR(12), @physical_id), N'null'), N'}');
EXEC dbo.Audit_Append @sys, N'DEMO_BOX', N'DEVICE', @dev, @note;

COMMIT;

-- the resulting mapping
SELECT b.bank_code, d.device_code,
       CASE WHEN p.params_json LIKE N'%"demo":true%' THEN N'demo' ELSE N'real' END AS kind,
       ps.slot_code AS physical_slot
FROM dbo.LockerBank b
LEFT JOIN dbo.Device d ON d.device_id = b.device_id
LEFT JOIN dbo.OperatingProfile p ON p.device_id = d.device_id
LEFT JOIN dbo.LockerSlot ps ON ps.locker_slot_id = TRY_CAST(JSON_VALUE(p.params_json, N'$.physical_slot_id') AS INT)
                           AND ps.bank_id = b.bank_id
ORDER BY CASE WHEN b.device_id = @dev THEN 0 ELSE 1 END, b.bank_code;
