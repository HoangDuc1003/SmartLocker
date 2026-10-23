-- ============================================================
-- test_v3_setup.sql  Prepared bookings for the "v3" folder of the Postman collection (docs/postman). Not demo data.
-- Postman cannot run SQL, so the steps that need time travel start from bookings already in the needed state,
-- the same way test_v2_setup.sql prepares v2noshow for scenario 6. Nothing here fakes a fee, a lock or an alert:
-- only times are moved back; the lock, the late fee and the escalation come from the normal code
-- (Device_Authorize charges on demand, LockerMonitor every 15 s).
-- Run AFTER sql/test_v2_setup.sql (it resets v3overdue and v3poor), before each Postman run. Safe to run again.
--   v3overdue  ACTIVE PIN booking on CANT-A, due 130 minutes ago (3 started hours late), wallet 5,000 VND
--              -> scenario 11 (box: OVERDUE_UNPAID + debt), 16 (phone), 17 (extension refused 50048), 12 (top-up, PICKUP)
--   v3late     RESERVED PIN booking on CANT-A booked 6 minutes ago -> scenario 13 (cancel refused, 50047)
--   v3esc      ACTIVE PIN booking on CANT-A, due 49 hours ago -> scenario 15 (LockerMonitor locks, charges, escalates)
--   v3poor     untouched here (test_v2_setup.sql: 12,000 VND) -> scenario 14
-- Password of every account: 123456.
--   sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -b -f 65001 -i sql\test_v3_setup.sql
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
DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');

INSERT INTO Users (username, password_hash, full_name, status, balance, area_id)
SELECT v.u, @hash, v.n, N'ACTIVE', 200000, @area
FROM (VALUES (N'v3late', N'Kiểm thử hủy muộn'), (N'v3esc', N'Kiểm thử chuyển xử lý')) v(u, n)
WHERE NOT EXISTS (SELECT 1 FROM Users x WHERE x.username = v.u);
INSERT INTO UserRole (user_id, role_id)
SELECT u.user_id, @role FROM Users u
WHERE u.username IN (N'v3late', N'v3esc')
  AND NOT EXISTS (SELECT 1 FROM UserRole r WHERE r.user_id = u.user_id);

DECLARE @tests TABLE (user_id INT);
INSERT INTO @tests SELECT user_id FROM Users WHERE username IN (N'v3overdue', N'v3late', N'v3esc');

BEGIN TRAN;
-- close what a previous run left open (an overdue or escalated booking too), and free its slots
DECLARE @open TABLE (deposit_id BIGINT, slot_id INT);
UPDATE d SET d.status = CASE WHEN d.status = N'RESERVED' THEN N'CANCELLED' ELSE N'COMPLETED' END,
             d.ended_at = SYSUTCDATETIME()
OUTPUT inserted.deposit_id, inserted.slot_id INTO @open
FROM Deposit d JOIN @tests t ON t.user_id = d.user_id
WHERE d.status IN (N'RESERVED', N'ACTIVE');
UPDATE s SET s.status = N'AVAILABLE' FROM LockerSlot s JOIN @open o ON o.slot_id = s.locker_slot_id
WHERE s.status IN (N'RESERVED', N'OCCUPIED');
UPDATE u SET u.balance = 200000, u.status = N'ACTIVE' FROM Users u JOIN @tests t ON t.user_id = u.user_id;
-- earlier runs may have left NO_SHOWs (3 in 7 days would block booking, 50031): moved out of the window
UPDATE d SET d.reserved_at = DATEADD(DAY, -8, d.reserved_at)
FROM Deposit d JOIN @tests t ON t.user_id = d.user_id
WHERE d.status = N'NO_SHOW' AND d.reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME());
-- the escalation alert of an earlier run is closed, so scenario 15 finds its own
UPDATE a SET a.status = N'RESOLVED' FROM Alert a
WHERE a.label = N'OVERDUE_ESCALATED' AND a.status = N'OPEN'
  AND EXISTS (SELECT 1 FROM AlertEvidence e JOIN Users u ON u.username = e.value_text JOIN @tests t ON t.user_id = u.user_id
              WHERE e.alert_id = a.alert_id AND e.item = N'user');
-- the box must not be OFFLINE for Deposit_Reserve (as in test_v2_setup.sql; Postman heartbeats keep it alive after)
UPDATE Device SET last_seen = SYSUTCDATETIME(), status = CASE WHEN status = N'OFFLINE' THEN N'ACTIVE' ELSE status END
WHERE device_id = @dev;
COMMIT;

-- plans are looked up by duration, not by name (07_vietnamese_data.sql renames them)
DECLARE @plan INT = (SELECT TOP 1 plan_id FROM StoragePlan WHERE duration_min = 120 AND is_active = 1 ORDER BY plan_id);
DECLARE @user INT, @slot INT, @slot_code NVARCHAR(20), @id BIGINT, @note NVARCHAR(100);

-- The prepared bookings take L, then M slots of CANT-A, so the S slots stay free for scenarios 1-4, 7, 9, 13, 14, 17.
-- v2noshow (test_v2_setup.sql) already holds its slot (RESERVED), so it is not picked here.

-- 1. v3overdue: booked, opened once (CHECK_IN), due time moved 130 minutes back, wallet 5,000 VND
SET @user = (SELECT user_id FROM Users WHERE username = N'v3overdue');
SET @slot = NULL; SET @slot_code = NULL;
SELECT TOP 1 @slot = s.locker_slot_id, @slot_code = s.slot_code
FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE b.bank_code = N'CANT-A' AND s.status = N'AVAILABLE'
ORDER BY CASE s.size_code WHEN N'L' THEN 0 WHEN N'M' THEN 1 ELSE 2 END, s.slot_code;
IF @slot IS NULL THROW 50099, N'No free slot on CANT-A for a test booking: run sql/test_v3_cleanup.sql', 1;
SET @id = NULL;
EXEC Deposit_Reserve @user, @slot, @plan, @id OUTPUT, N'PIN';
EXEC Deposit_CheckIn @dev, @slot_code;
UPDATE Deposit SET due_at = DATEADD(MINUTE, -130, SYSUTCDATETIME()),
                   started_at = DATEADD(MINUTE, -250, SYSUTCDATETIME()),
                   reserved_at = DATEADD(MINUTE, -255, SYSUTCDATETIME())   -- booked before it started
WHERE deposit_id = @id;
UPDATE Users SET balance = 5000 WHERE user_id = @user;
SET @note = N'test_v3_setup.sql: due_at moved 130 minutes back';
EXEC Audit_Append @sys, N'TEST_OVERDUE', N'DEPOSIT', @id, @note;

-- 2. v3late: booked 6 minutes ago, so the free cancel window (5 minutes) is over. The hold is stretched to
--    30 minutes from now so the booking does not become NO_SHOW before Postman reaches scenario 13.
SET @user = (SELECT user_id FROM Users WHERE username = N'v3late');
SET @slot = NULL; SET @slot_code = NULL;
SELECT TOP 1 @slot = s.locker_slot_id, @slot_code = s.slot_code
FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE b.bank_code = N'CANT-A' AND s.status = N'AVAILABLE'
ORDER BY CASE s.size_code WHEN N'L' THEN 0 WHEN N'M' THEN 1 ELSE 2 END, s.slot_code;
IF @slot IS NULL THROW 50099, N'No free slot on CANT-A for a test booking: run sql/test_v3_cleanup.sql', 1;
SET @id = NULL;
EXEC Deposit_Reserve @user, @slot, @plan, @id OUTPUT, N'PIN';
UPDATE Deposit SET reserved_at = DATEADD(MINUTE, -6, SYSUTCDATETIME()),
                   hold_until = DATEADD(MINUTE, 30, SYSUTCDATETIME())
WHERE deposit_id = @id;
SET @note = N'test_v3_setup.sql: reserved_at moved 6 minutes back';
EXEC Audit_Append @sys, N'TEST_SETUP', N'DEPOSIT', @id, @note;

-- 3. v3esc: booked, opened once, due time moved 49 hours back. LockerMonitor locks it, takes the late fee and
--    escalates it (Deposit_Escalate) within 15 seconds once Tomcat runs.
SET @user = (SELECT user_id FROM Users WHERE username = N'v3esc');
SET @slot = NULL; SET @slot_code = NULL;
SELECT TOP 1 @slot = s.locker_slot_id, @slot_code = s.slot_code
FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE b.bank_code = N'CANT-A' AND s.status = N'AVAILABLE'
ORDER BY CASE s.size_code WHEN N'L' THEN 0 WHEN N'M' THEN 1 ELSE 2 END, s.slot_code;
IF @slot IS NULL THROW 50099, N'No free slot on CANT-A for a test booking: run sql/test_v3_cleanup.sql', 1;
SET @id = NULL;
EXEC Deposit_Reserve @user, @slot, @plan, @id OUTPUT, N'PIN';
EXEC Deposit_CheckIn @dev, @slot_code;
UPDATE Deposit SET due_at = DATEADD(HOUR, -49, SYSUTCDATETIME()),
                   started_at = DATEADD(HOUR, -51, SYSUTCDATETIME()),
                   reserved_at = DATEADD(MINUTE, -51 * 60 - 5, SYSUTCDATETIME())
WHERE deposit_id = @id;
SET @note = N'test_v3_setup.sql: due_at moved 49 hours back';
EXEC Audit_Append @sys, N'TEST_OVERDUE', N'DEPOSIT', @id, @note;

SELECT u.username, u.balance, d.deposit_id, s.slot_code, s.size_code, d.paid_amount, d.status,
       d.reserved_at, d.due_at, d.locked_at, d.escalated_at
FROM Users u
LEFT JOIN Deposit d ON d.user_id = u.user_id AND d.status IN (N'RESERVED', N'ACTIVE')
LEFT JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
WHERE u.user_id IN (SELECT user_id FROM @tests)
ORDER BY u.username;
GO
