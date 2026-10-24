-- ============================================================
-- test_cleanup.sql  Clears what the Postman test setups leave on the real box, before a live demo.
-- test_setup.sql / test_setup.sql prepare bookings on CANT-A (LOCKER-01) for Postman: after a run, the
-- slots of v2noshow, v3overdue, v3late and v3esc can stay reserved, locked or escalated, with an open
-- OVERDUE_ESCALATED alert. This closes the open bookings of the test accounts only, frees their slots and
-- resolves their escalation alerts. Demo accounts and real bookings are not touched. Safe to run again.
--   sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -b -f 65001 -i sql\test_cleanup.sql
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
DECLARE @tests TABLE (user_id INT);
INSERT INTO @tests SELECT user_id FROM Users
WHERE username IN (N'v2pin', N'v2card', N'v2fp', N'v2noshow', N'v3overdue', N'v3poor', N'v3late', N'v3esc');

BEGIN TRAN;
DECLARE @open TABLE (deposit_id BIGINT, slot_id INT);
UPDATE d SET d.status = CASE WHEN d.status = N'RESERVED' THEN N'CANCELLED' ELSE N'COMPLETED' END,
             d.ended_at = SYSUTCDATETIME()
OUTPUT inserted.deposit_id, inserted.slot_id INTO @open
FROM Deposit d JOIN @tests t ON t.user_id = d.user_id
WHERE d.status IN (N'RESERVED', N'ACTIVE');
UPDATE s SET s.status = N'AVAILABLE' FROM LockerSlot s JOIN @open o ON o.slot_id = s.locker_slot_id
WHERE s.status IN (N'RESERVED', N'OCCUPIED');

DECLARE @alerts TABLE (alert_id INT);
UPDATE a SET a.status = N'RESOLVED'
OUTPUT inserted.alert_id INTO @alerts
FROM Alert a
WHERE a.label = N'OVERDUE_ESCALATED' AND a.status = N'OPEN'
  AND EXISTS (SELECT 1 FROM AlertEvidence e JOIN Users u ON u.username = e.value_text JOIN @tests t ON t.user_id = u.user_id
              WHERE e.alert_id = a.alert_id AND e.item = N'user');

DECLARE @n INT = (SELECT COUNT(*) FROM @open), @m INT = (SELECT COUNT(*) FROM @alerts);
DECLARE @note NVARCHAR(100) = CONCAT(N'test_cleanup.sql: ', @n, N' test bookings closed, ', @m, N' alerts resolved');
IF @n > 0 OR @m > 0
    EXEC Audit_Append @sys, N'TEST_CLEANUP', N'DEPOSIT', 0, @note;
COMMIT;
SELECT @n AS bookings_closed, @m AS alerts_resolved;
GO
