-- ============================================================
-- test_v2_setup.sql  Test accounts for the v2 Postman collection (docs/postman). Not demo data.
-- Run before each Postman run. Safe to run again: it only touches the v2test* accounts.
--   v2pin, v2card, v2fp  END_USER in Canteen, balance 200,000, no open booking, no card, no finger
--   v2noshow             a PIN booking on CANT-A whose hold time is already over (scenario 6)
--   v3overdue            v3: balance 200,000, no open booking (overdue scenarios 11, 12, 15, 16 with test_overdue.sql)
--   v3poor               v3: balance 12,000, below price + 10,000 buffer for every size (scenario 14)
--   LOCKER-01            heartbeat now, both lockout counters (box and phone) reset
-- Password of every account: 123456.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
DECLARE @hash CHAR(60) = (SELECT password_hash FROM Users WHERE username = N'student1');   -- BCrypt of 123456
DECLARE @role INT = (SELECT role_id FROM Roles WHERE role_name = N'END_USER');
DECLARE @area INT = (SELECT area_id FROM LockerArea WHERE area_code = N'CANT');
DECLARE @dev INT = (SELECT device_id FROM Device WHERE device_code = N'LOCKER-01');

INSERT INTO Users (username, password_hash, full_name, status, balance, area_id)
SELECT v.u, @hash, v.n, N'ACTIVE', 200000, @area
FROM (VALUES (N'v2pin', N'Kiểm thử mật mã'), (N'v2card', N'Kiểm thử thẻ từ'),
             (N'v2fp', N'Kiểm thử vân tay'), (N'v2noshow', N'Kiểm thử không đến'),
             (N'v3overdue', N'Kiểm thử quá hạn'), (N'v3poor', N'Kiểm thử ít tiền')) v(u, n)
WHERE NOT EXISTS (SELECT 1 FROM Users x WHERE x.username = v.u);
INSERT INTO UserRole (user_id, role_id)
SELECT u.user_id, @role FROM Users u
WHERE u.username IN (N'v2pin', N'v2card', N'v2fp', N'v2noshow', N'v3overdue', N'v3poor')
  AND NOT EXISTS (SELECT 1 FROM UserRole r WHERE r.user_id = u.user_id);

DECLARE @tests TABLE (user_id INT);
INSERT INTO @tests SELECT user_id FROM Users WHERE username IN (N'v2pin', N'v2card', N'v2fp', N'v2noshow', N'v3overdue', N'v3poor');

BEGIN TRAN;
-- close what a previous run left open, and free its slots
DECLARE @open TABLE (deposit_id BIGINT, slot_id INT);
UPDATE d SET d.status = CASE WHEN d.status = N'RESERVED' THEN N'CANCELLED' ELSE N'COMPLETED' END,
             d.ended_at = SYSUTCDATETIME()
OUTPUT inserted.deposit_id, inserted.slot_id INTO @open
FROM Deposit d JOIN @tests t ON t.user_id = d.user_id
WHERE d.status IN (N'RESERVED', N'ACTIVE');
UPDATE s SET s.status = N'AVAILABLE' FROM LockerSlot s JOIN @open o ON o.slot_id = s.locker_slot_id
WHERE s.status IN (N'RESERVED', N'OCCUPIED');

-- no card, no finger: scenarios 3 and 4 enroll again (Postman makes a new card UID each run)
UPDATE c SET c.status = N'BLOCKED', c.lost_at = ISNULL(c.lost_at, SYSUTCDATETIME())
FROM UserCard c JOIN @tests t ON t.user_id = c.user_id WHERE c.status = N'ACTIVE';
UPDATE f SET f.status = N'DELETED' FROM Fingerprint f JOIN @tests t ON t.user_id = f.user_id WHERE f.status = N'ACTIVE';
UPDATE u SET u.balance = 200000, u.status = N'ACTIVE' FROM Users u JOIN @tests t ON t.user_id = u.user_id;
UPDATE Users SET balance = 12000 WHERE username = N'v3poor';
-- v3: an escalation alert of an earlier run is closed, so scenario 15 sees its own
UPDATE a SET a.status = N'RESOLVED' FROM Alert a
WHERE a.label = N'OVERDUE_ESCALATED' AND a.status = N'OPEN'
  AND EXISTS (SELECT 1 FROM AlertEvidence e JOIN Users u ON u.username = e.value_text JOIN @tests t ON t.user_id = u.user_id
              WHERE e.alert_id = a.alert_id AND e.item = N'user');

-- the box is alive and its lockout counter starts from zero
UPDATE Device SET last_seen = SYSUTCDATETIME(), status = CASE WHEN status = N'OFFLINE' THEN N'ACTIVE' ELSE status END
WHERE device_id = @dev;
INSERT INTO AuthAttempt (device_id, method, ok, reason) VALUES (@dev, N'ADMIN', 1, N'COUNTER_RESET');
COMMIT;

-- scenario 6: a PIN booking whose 15 minutes are already over; LockerMonitor makes it NO_SHOW (v3: no refund).
-- The slot is the last free one of CANT-A (A15, size M since 09_v3.sql: 6,500 VND).
DECLARE @user INT = (SELECT user_id FROM Users WHERE username = N'v2noshow');
DECLARE @slot INT = (SELECT TOP 1 s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
                     WHERE b.bank_code = N'CANT-A' AND s.status = N'AVAILABLE' ORDER BY s.slot_code DESC);
DECLARE @id BIGINT;
-- earlier runs left NO_SHOWs; 3 in 7 days would block booking (50031), so they are moved out of the window
UPDATE Deposit SET reserved_at = DATEADD(DAY, -8, reserved_at)
WHERE user_id = @user AND status = N'NO_SHOW' AND reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME());
DECLARE @plan INT = (SELECT TOP 1 plan_id FROM StoragePlan WHERE duration_min = 120 AND is_active = 1 ORDER BY plan_id);
EXEC Deposit_Reserve @user, @slot, @plan, @id OUTPUT, N'PIN';
UPDATE Deposit SET hold_until = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE deposit_id = @id;
SELECT u.username, u.balance, d.deposit_id, d.paid_amount, d.status, d.pin_code
FROM Users u LEFT JOIN Deposit d ON d.user_id = u.user_id AND d.deposit_id = @id
WHERE u.user_id IN (SELECT user_id FROM @tests);
GO
