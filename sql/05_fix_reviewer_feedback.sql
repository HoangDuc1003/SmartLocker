-- ============================================================
-- 05_fix_reviewer_feedback.sql
-- Fixes based on team reviewer feedback:
--   Issue #2: Remove USER:READ from TECHNICIAN role
--   Issue #7: Auto-release overdue bookings & reliable no-show expiry
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- 1. Remove USER permission from TECHNICIAN (Issue #2)
DELETE rp FROM dbo.RolePerm rp
JOIN dbo.Roles r ON r.role_id = rp.role_id
JOIN dbo.Permissions p ON p.perm_id = rp.perm_id
WHERE r.role_name = N'TECHNICIAN'
  AND p.resource = N'USER';
GO

-- 2. Reliable Deposit_ExpireNoShow (Issue #7)
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
    WHERE d.status = N'RESERVED' AND d.hold_until < SYSUTCDATETIME();

    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s JOIN @expired e ON e.slot_id = s.locker_slot_id
    WHERE s.status = N'RESERVED';

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

-- 3. Auto-release Overdue Bookings (Issue #7)
CREATE OR ALTER PROCEDURE Deposit_ExpireOverdue
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @overdue TABLE (deposit_id BIGINT, slot_id INT, user_id INT);
    DECLARE @id BIGINT;
    BEGIN TRAN;
    UPDATE d SET d.status = N'COMPLETED', d.ended_at = SYSUTCDATETIME()
    OUTPUT inserted.deposit_id, inserted.slot_id, inserted.user_id INTO @overdue
    FROM Deposit d
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    WHERE d.status = N'ACTIVE' AND d.due_at < SYSUTCDATETIME();

    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s JOIN @overdue o ON o.slot_id = s.locker_slot_id
    WHERE s.status <> N'MAINTENANCE';

    WHILE EXISTS (SELECT 1 FROM @overdue)
    BEGIN
        SELECT TOP 1 @id = deposit_id FROM @overdue;
        EXEC Audit_Append @sys, N'AUTO_RELEASE_OVERDUE', N'DEPOSIT', @id, N'Expired booking auto-released to AVAILABLE';
        DELETE FROM @overdue WHERE deposit_id = @id;
    END
    COMMIT;
END;
GO
