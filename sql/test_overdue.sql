-- ============================================================
-- test_overdue.sql  Demo / test helper for v3 overdue (docs/spec/smart-locker-v3.md, D5). Not demo data.
-- Moves the due time of ONE open ACTIVE booking into the past, so the overdue lock, the late fee and the
-- escalation can be shown without waiting hours. It fakes no heartbeat and no displayed number: the normal
-- jobs (LockerMonitor, every 15 s) lock, charge and escalate from the moved due time.
--
-- Edit the three values below, then run:
--   sqlcmd -S localhost -U sa -P 12345 -I -b -f 65001 -i sql\test_overdue.sql
--   @username      owner of the ACTIVE booking (check in first: open the box once)
--   @minutes_late  how long ago due_at was: 130 = 2 h 10 min (3 hours charged), 2890 = more than 48 h
--   @balance       set the wallet to this before charging (NULL keeps it), e.g. 5000 to end in a debt
-- Safe to run again: each run moves due_at from "now" again; hours already charged are not charged twice.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
DECLARE @username NVARCHAR(50) = N'v3overdue';
DECLARE @minutes_late INT = 130;
DECLARE @balance BIGINT = 5000;

DECLARE @id BIGINT = (SELECT d.deposit_id FROM Deposit d JOIN Users u ON u.user_id = d.user_id
                      WHERE u.username = @username AND d.status = N'ACTIVE');
IF @id IS NULL
BEGIN
    RAISERROR(N'No ACTIVE booking for this user: book a slot and open the box once (CHECK_IN) first.', 16, 1);
    RETURN;
END
BEGIN TRAN;
UPDATE Deposit SET due_at = DATEADD(MINUTE, -@minutes_late, SYSUTCDATETIME()),
                   started_at = CASE WHEN started_at > DATEADD(MINUTE, -@minutes_late - 1, SYSUTCDATETIME())
                                     THEN DATEADD(MINUTE, -@minutes_late - 120, SYSUTCDATETIME()) ELSE started_at END
WHERE deposit_id = @id;
UPDATE Deposit SET reserved_at = DATEADD(MINUTE, -5, started_at)   -- booked before it started
WHERE deposit_id = @id AND reserved_at > started_at;
IF @balance IS NOT NULL
    UPDATE u SET u.balance = @balance FROM Users u WHERE u.username = @username;
DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
DECLARE @note NVARCHAR(100) = CONCAT(N'test_overdue.sql: due_at moved ', @minutes_late, N' minutes back');
EXEC Audit_Append @sys, N'TEST_OVERDUE', N'DEPOSIT', @id, @note;
COMMIT;

-- do now what LockerMonitor does in the next 15 seconds
EXEC Deposit_ExpireOverdue;
EXEC Deposit_Escalate;

SELECT d.deposit_id, u.username, u.balance, d.due_at, d.locked_at, d.overdue_hours, d.overdue_fee, d.escalated_at
FROM Deposit d JOIN Users u ON u.user_id = d.user_id WHERE d.deposit_id = @id;
GO
