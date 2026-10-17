-- 04_wallet_booking.sql  Wallet and booking additions. Run after 01..03 (order: 01 -> 07, see README).
-- Safe to run again: every change is guarded. TopupRequest itself is created in 01_schema.sql.
USE PRJ301_LOCKER;
GO

IF COL_LENGTH('dbo.Users', 'balance') IS NULL
    ALTER TABLE dbo.Users ADD balance BIGINT NOT NULL
        CONSTRAINT DF_Users_balance DEFAULT 0;
GO

IF COL_LENGTH('dbo.Deposit', 'paid_amount') IS NULL
    ALTER TABLE dbo.Deposit ADD paid_amount BIGINT NOT NULL DEFAULT 0;
GO

IF COL_LENGTH('dbo.RemoteCommand', 'sent_at') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD sent_at DATETIME2 NULL;
GO
UPDATE dbo.RemoteCommand SET sent_at = DATEADD(SECOND, 1, created_at)
WHERE status IN (N'SENT', N'DONE') AND sent_at IS NULL;
GO

INSERT INTO dbo.Permissions (resource, action)
SELECT N'TOPUP', v.action
FROM (VALUES (N'READ'), (N'WRITE')) v(action)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Permissions p
    WHERE p.resource = N'TOPUP' AND p.action = v.action);
GO

INSERT INTO dbo.RolePerm (role_id, perm_id)
SELECT r.role_id, p.perm_id
FROM dbo.Roles r
CROSS JOIN dbo.Permissions p
WHERE r.role_name IN (N'ADMIN', N'OPERATOR', N'END_USER')
  AND p.resource = N'TOPUP'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RolePerm rp
      WHERE rp.role_id = r.role_id AND rp.perm_id = p.perm_id);
GO

-- Slot status permissions for existing installations.
USE PRJ301_LOCKER;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF NOT EXISTS (SELECT 1 FROM Permissions WHERE resource = N'SLOTSTATUS' AND action = N'WRITE')
    INSERT INTO Permissions (resource, action) VALUES (N'SLOTSTATUS', N'WRITE');
INSERT INTO RolePerm (role_id, perm_id)
SELECT r.role_id, p.perm_id FROM Roles r CROSS JOIN Permissions p
WHERE r.role_name IN (N'ADMIN', N'TECHNICIAN')
  AND p.resource = N'SLOTSTATUS' AND p.action = N'WRITE'
  AND NOT EXISTS (SELECT 1 FROM RolePerm rp WHERE rp.role_id = r.role_id AND rp.perm_id = p.perm_id);
COMMIT;
GO
