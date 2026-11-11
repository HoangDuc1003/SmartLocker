-- ============================================================
-- 05_auto_checkin.sql  Smart Locker v7.1: a reservation nobody checked in starts by itself.
-- Run after 03_v2_v3.sql (and 04_phone.sql if you use it). Safe to run again, also on a live database: it replaces
-- two procedures and patches one, and keeps every row. Run it again after 03 or 04 were run again.
--
-- Before: not checking in within the hold (15 minutes) ended the booking as NO_SHOW: the slot was freed, the money lost.
-- Now: at hold_until the booking checks in by itself (AUTO_CHECK_IN): it becomes ACTIVE, the slot OCCUPIED and
-- the slot stays locked for its owner. The paid time starts then: the owner may come early, late or never, and opens
-- the slot whenever they like until it is due. Nothing is refunded. A cancel is only possible during the hold.
-- If nobody opened the slot at all (no ACCESS row) by due_at + grace, there is nothing inside to protect: the booking
-- ends as NO_SHOW, the slot is free and no late fee is charged.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- the clock job (every 15 s) and Device_Authorize call it: the bookings whose hold ended start now,
-- counted from hold_until, so the paid time does not depend on when the job ran
CREATE OR ALTER PROCEDURE Deposit_ExpireNoShow
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @started TABLE (deposit_id BIGINT, slot_id INT);
    DECLARE @id BIGINT;
    BEGIN TRAN;
    UPDATE d SET d.status = N'ACTIVE', d.started_at = d.hold_until,
                 d.due_at = DATEADD(MINUTE, ISNULL(d.custom_min, p.duration_min), d.hold_until)
    OUTPUT inserted.deposit_id, inserted.slot_id INTO @started
    FROM Deposit d WITH (UPDLOCK, HOLDLOCK) JOIN StoragePlan p ON p.plan_id = d.plan_id
    WHERE d.status = N'RESERVED' AND d.hold_until < SYSUTCDATETIME();

    UPDATE s SET s.status = N'OCCUPIED'
    FROM LockerSlot s JOIN @started e ON e.slot_id = s.locker_slot_id
    WHERE s.status = N'RESERVED';

    WHILE EXISTS (SELECT 1 FROM @started)
    BEGIN
        SELECT TOP 1 @id = deposit_id FROM @started;
        EXEC Audit_Append @sys, N'AUTO_CHECK_IN', N'DEPOSIT', @id, NULL;
        DELETE FROM @started WHERE deposit_id = @id;
    END
    COMMIT;
END;
GO

-- v3: an overdue slot is never released by the clock (it still holds the user's things), the job locks and charges.
-- v7.1: except a booking that started by itself and was never opened: nothing is inside, so it simply ends.
CREATE OR ALTER PROCEDURE Deposit_ExpireOverdue
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET DEADLOCK_PRIORITY LOW;            -- on a deadlock the box (Device_Authorize) wins, the job runs again in 15 s
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @unused TABLE (deposit_id BIGINT, slot_id INT);
    DECLARE @id BIGINT;
    BEGIN TRAN;
    UPDATE d SET d.status = N'NO_SHOW', d.ended_at = SYSUTCDATETIME()
    OUTPUT inserted.deposit_id, inserted.slot_id INTO @unused
    FROM Deposit d JOIN StoragePlan p ON p.plan_id = d.plan_id
    WHERE d.status = N'ACTIVE' AND d.locked_at IS NULL AND d.due_at IS NOT NULL
      AND DATEADD(MINUTE, p.grace_min, d.due_at) < SYSUTCDATETIME()
      AND EXISTS (SELECT 1 FROM AuditLog a WHERE a.object_type = N'DEPOSIT' AND a.object_id = d.deposit_id
                  AND a.action = N'AUTO_CHECK_IN')
      AND NOT EXISTS (SELECT 1 FROM AuditLog a WHERE a.object_type = N'DEPOSIT' AND a.object_id = d.deposit_id
                      AND a.action = N'ACCESS');
    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s JOIN @unused e ON e.slot_id = s.locker_slot_id
    WHERE s.status = N'OCCUPIED';
    WHILE EXISTS (SELECT 1 FROM @unused)
    BEGIN
        SELECT TOP 1 @id = deposit_id FROM @unused;
        EXEC Audit_Append @sys, N'NO_SHOW', N'DEPOSIT', @id, 0;       -- never opened: nothing refunded, nothing more to charge
        DELETE FROM @unused WHERE deposit_id = @id;
    END
    COMMIT;
    EXEC Deposit_ChargeOverdue NULL;
END;
GO

-- Device_Authorize: a RESERVED booking whose hold ended no longer answers EXPIRED (and no longer ends the booking):
-- it opens as a check-in, exactly as if the hold had not ended; the clock job would start it within 15 s anyway.
-- The branch is switched off in place (AND 1 = 0) so the same patch works on the 03 text and on the 04 text.
DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.Device_Authorize'));
DECLARE @old NVARCHAR(100) = N'ELSE IF @status = N''RESERVED'' AND @hold < @now';
DECLARE @at INT = CHARINDEX(N'PROCEDURE Device_Authorize', @def);
IF @def IS NULL OR @at = 0
    THROW 50907, N'Device_Authorize was not found: run 03_v2_v3.sql first', 1;
IF CHARINDEX(@old + N' AND 1 = 0', @def) = 0
BEGIN
    IF CHARINDEX(@old, @def) = 0
        THROW 50908, N'Device_Authorize has an unexpected text: the hold branch was not found', 1;
    SET @def = REPLACE(@def, @old, @old + N' AND 1 = 0   -- v7.1: a reservation never expires, the clock job checks it in');
    SET @def = N'CREATE OR ALTER ' + SUBSTRING(@def, @at, LEN(@def));
    EXEC sys.sp_executesql @def;
END
GO

SELECT status, COUNT(*) AS bookings FROM dbo.Deposit GROUP BY status ORDER BY status;
GO
