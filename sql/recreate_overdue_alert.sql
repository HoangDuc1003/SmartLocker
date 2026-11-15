
USE PRJ301_LOCKER;
SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;

-- 1. Ensure LOCKER-01 manages CANT-A
DECLARE @dev INT = (SELECT device_id FROM Device WHERE device_code = N'LOCKER-01');
UPDATE LockerBank SET device_id = @dev WHERE bank_code = N'CANT-A';
UPDATE Device SET status = N'ACTIVE', last_seen = SYSUTCDATETIME() WHERE device_id = @dev;

-- 2. Clean up any existing booking on CANT-A A12 and for user v3esc
DECLARE @slot_a12 INT = (SELECT s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id WHERE b.bank_code = N'CANT-A' AND s.slot_code = N'A12');
DECLARE @user_id INT = (SELECT user_id FROM Users WHERE username = N'v3esc');

UPDATE Deposit SET status = N'COMPLETED', ended_at = SYSUTCDATETIME() WHERE (slot_id = @slot_a12 OR user_id = @user_id) AND status IN (N'RESERVED', N'ACTIVE');
UPDATE LockerSlot SET status = N'AVAILABLE' WHERE locker_slot_id = @slot_a12;
UPDATE Users SET balance = 200000, status = N'ACTIVE' WHERE user_id = @user_id;

-- Close old alerts for v3esc
UPDATE a SET a.status = N'RESOLVED' FROM Alert a
WHERE a.label = N'OVERDUE_ESCALATED' AND a.status = N'OPEN'
  AND EXISTS (SELECT 1 FROM AlertEvidence e WHERE e.alert_id = a.alert_id AND e.item = N'user' AND e.value_text = N'v3esc');

-- 3. Reserve and CheckIn
DECLARE @plan INT = (SELECT TOP 1 plan_id FROM StoragePlan WHERE duration_min = 120 AND is_active = 1 ORDER BY plan_id);
DECLARE @dep_id BIGINT;
EXEC Deposit_Reserve @user_id, @slot_a12, @plan, @dep_id OUTPUT, N'PIN';
EXEC Deposit_CheckIn @dev, N'A12', @slot_a12;

-- 4. Move due_at to 49.5 hours ago so started hours = 50 hours
UPDATE Deposit SET due_at = DATEADD(MINUTE, -2970, SYSUTCDATETIME()),
                   started_at = DATEADD(MINUTE, -3090, SYSUTCDATETIME()),
                   reserved_at = DATEADD(MINUTE, -3095, SYSUTCDATETIME())
WHERE deposit_id = @dep_id;

-- 5. Lock, charge overdue, and escalate
EXEC Deposit_ExpireOverdue;
EXEC Deposit_Escalate;

-- 6. Show results
SELECT d.deposit_id, d.status AS dep_status, d.overdue_hours, d.overdue_fee, u.balance AS user_balance, d.due_at, d.escalated_at
FROM Deposit d JOIN Users u ON u.user_id = d.user_id WHERE d.deposit_id = @dep_id;

SELECT TOP 1 a.alert_id, a.label, a.status AS alert_status, a.source, a.created_at, dev.device_code, dev.location
FROM Alert a JOIN Device dev ON dev.device_id = a.device_id
WHERE a.label = N'OVERDUE_ESCALATED' AND a.status = N'OPEN'
ORDER BY a.alert_id DESC;

SELECT e.item, e.value_text
FROM AlertEvidence e
WHERE e.alert_id = (SELECT TOP 1 alert_id FROM Alert WHERE label = N'OVERDUE_ESCALATED' AND status = N'OPEN' ORDER BY alert_id DESC);
