-- Apply once to an existing PRJ301_LOCKER database without deleting its data.
-- Then run 03_scenarios.sql again to update the booking procedures.
USE PRJ301_LOCKER;
GO

IF COL_LENGTH('dbo.Users', 'balance') IS NULL
    ALTER TABLE dbo.Users ADD balance BIGINT NOT NULL
        CONSTRAINT DF_Users_balance DEFAULT 0;
GO

IF OBJECT_ID('dbo.TopupRequest', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TopupRequest (
        request_id    INT IDENTITY PRIMARY KEY,
        user_id       INT NOT NULL REFERENCES dbo.Users,
        amount        BIGINT NOT NULL CHECK (amount >= 1000),
        transfer_code NVARCHAR(80) NOT NULL UNIQUE,
        qr_url        NVARCHAR(1000) NOT NULL,
        status        NVARCHAR(20) NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
        created_at    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        approved_at   DATETIME2 NULL,
        approved_by   INT NULL REFERENCES dbo.Users,
        note          NVARCHAR(400) NULL);
END;
GO

IF COL_LENGTH('dbo.Deposit', 'paid_amount') IS NULL
    ALTER TABLE dbo.Deposit ADD paid_amount BIGINT NOT NULL DEFAULT 0;
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
