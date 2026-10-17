-- ============================================================
-- 08_accounts_v2.sql  Accounts v2: the extra demo accounts are DELETED (not disabled) and replaced.
-- Run after 07. Re-runnable: a second run finds nothing to delete or add and changes nothing.
-- Back up first, the deletes cannot be undone:
--   BACKUP DATABASE PRJ301_LOCKER TO DISK = N'<backup dir>\PRJ301_LOCKER_before_accounts_v2.bak' WITH INIT;
--
-- Accounts kept: system, admin, operator1..4 (one per area, set by 06), student1 (card registered on
-- LOCKER-01) and student3 (fingerprint in sensor slot 1 of LOCKER-01), the Postman accounts v2*.
-- New accounts (password 123456):
--   ADMIN       admin2
--   AUDITOR     kiemtoan1..3
--   TECHNICIAN  kythuat1 (LIB), kythuat2 (DOMA), kythuat3 (CANT), kythuat4 (GYM), kythuat5 (OPS)
--   END_USER    sv001..sv124; bikhoa1 (LOCKED) and vohieu1 (DISABLED) for the login error messages
-- Active totals afterwards: ADMIN 2, OPERATOR 4, AUDITOR 3, TECHNICIAN 5, END_USER 130.
--
-- Rows of a deleted user: roles, cards, fingerprints, top-ups, deposits, remote commands they requested and
-- their audit rows are deleted; tickets go to the new technician of the area; calibrations, profiles and
-- top-up approvals they made go to admin; session labels lose the labeller; device control is released.
-- The audit hash chain is then rebuilt from the first row exactly as Audit_Append computes it.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
DECLARE @accounts TABLE (username NVARCHAR(50) PRIMARY KEY, full_name NVARCHAR(80), role_name NVARCHAR(30),
                         area_code NVARCHAR(16), status NVARCHAR(20), balance BIGINT);
INSERT INTO @accounts VALUES
    (N'admin2', N'Mai Phương Yến', N'ADMIN', N'OPS', N'ACTIVE', 300000),
    (N'kiemtoan1', N'Phạm Đức Việt', N'AUDITOR', N'OPS', N'ACTIVE', 50000),
    (N'kiemtoan2', N'Ngô Công Tùng', N'AUDITOR', N'OPS', N'ACTIVE', 50000),
    (N'kiemtoan3', N'Lý Công Thắng', N'AUDITOR', N'OPS', N'ACTIVE', 50000),
    (N'kythuat1', N'Lâm Ngọc Giang', N'TECHNICIAN', N'LIB', N'ACTIVE', 30000),
    (N'kythuat2', N'Phạm Hồng Anh', N'TECHNICIAN', N'DOMA', N'ACTIVE', 30000),
    (N'kythuat3', N'Lý Gia Huy', N'TECHNICIAN', N'CANT', N'ACTIVE', 30000),
    (N'kythuat4', N'Đỗ Bảo Nhi', N'TECHNICIAN', N'GYM', N'ACTIVE', 30000),
    (N'kythuat5', N'Mai Minh Nhân', N'TECHNICIAN', N'OPS', N'ACTIVE', 30000),
    (N'sv001', N'Trịnh Phương Mai', N'END_USER', N'DOMA', N'ACTIVE', 120000),
    (N'sv002', N'Hoàng Diệu Mai', N'END_USER', N'CANT', N'ACTIVE', 50000),
    (N'sv003', N'Đỗ Bảo Phương', N'END_USER', N'GYM', N'ACTIVE', 15000),
    (N'sv004', N'Hồ Diệu Trang', N'END_USER', N'LIB', N'ACTIVE', 150000),
    (N'sv005', N'Phạm Khánh Thảo', N'END_USER', N'DOMA', N'ACTIVE', 75000),
    (N'sv006', N'Lâm Hữu Quân', N'END_USER', N'CANT', N'ACTIVE', 25000),
    (N'sv007', N'Võ Thành Vinh', N'END_USER', N'GYM', N'ACTIVE', 200000),
    (N'sv008', N'Lý Tuấn Trung', N'END_USER', N'LIB', N'ACTIVE', 100000),
    (N'sv009', N'Đinh Đức Tài', N'END_USER', N'DOMA', N'ACTIVE', 40000),
    (N'sv010', N'Trần Phương Hạnh', N'END_USER', N'CANT', N'ACTIVE', 0),
    (N'sv011', N'Lâm Khánh Quyên', N'END_USER', N'GYM', N'ACTIVE', 120000),
    (N'sv012', N'Vũ Ngọc Yến', N'END_USER', N'LIB', N'ACTIVE', 50000),
    (N'sv013', N'Lý Tuấn Khoa', N'END_USER', N'DOMA', N'ACTIVE', 15000),
    (N'sv014', N'Đặng Tuấn Hải', N'END_USER', N'CANT', N'ACTIVE', 150000),
    (N'sv015', N'Lý Thành Sơn', N'END_USER', N'GYM', N'ACTIVE', 75000),
    (N'sv016', N'Võ Thị Châu', N'END_USER', N'LIB', N'ACTIVE', 25000),
    (N'sv017', N'Lâm Hồng Thảo', N'END_USER', N'DOMA', N'ACTIVE', 200000),
    (N'sv018', N'Đỗ Đức Khoa', N'END_USER', N'CANT', N'ACTIVE', 100000),
    (N'sv019', N'Dương Tuấn Tài', N'END_USER', N'GYM', N'ACTIVE', 40000),
    (N'sv020', N'Ngô Tuấn Kiên', N'END_USER', N'LIB', N'ACTIVE', 0),
    (N'sv021', N'Đặng Gia Thắng', N'END_USER', N'DOMA', N'ACTIVE', 120000),
    (N'sv022', N'Phạm Hữu Lộc', N'END_USER', N'CANT', N'ACTIVE', 50000),
    (N'sv023', N'Mai Hoàng Thắng', N'END_USER', N'GYM', N'ACTIVE', 15000),
    (N'sv024', N'Huỳnh Thành Nhân', N'END_USER', N'LIB', N'ACTIVE', 150000),
    (N'sv025', N'Lê Mỹ Quyên', N'END_USER', N'DOMA', N'ACTIVE', 75000),
    (N'sv026', N'Phan Khánh Hà', N'END_USER', N'CANT', N'ACTIVE', 25000),
    (N'sv027', N'Nguyễn Ngọc Anh', N'END_USER', N'GYM', N'ACTIVE', 200000),
    (N'sv028', N'Trịnh Ngọc Vy', N'END_USER', N'LIB', N'ACTIVE', 100000),
    (N'sv029', N'Vũ Minh Việt', N'END_USER', N'DOMA', N'ACTIVE', 40000),
    (N'sv030', N'Trịnh Mỹ Hạnh', N'END_USER', N'CANT', N'ACTIVE', 0),
    (N'sv031', N'Đỗ Quốc An', N'END_USER', N'GYM', N'ACTIVE', 120000),
    (N'sv032', N'Đinh Diệu Xuân', N'END_USER', N'LIB', N'ACTIVE', 50000),
    (N'sv033', N'Lý Quốc Tùng', N'END_USER', N'DOMA', N'ACTIVE', 15000),
    (N'sv034', N'Đinh Thu Vy', N'END_USER', N'CANT', N'ACTIVE', 150000),
    (N'sv035', N'Mai Hoàng Cường', N'END_USER', N'GYM', N'ACTIVE', 75000),
    (N'sv036', N'Huỳnh Thu Uyên', N'END_USER', N'LIB', N'ACTIVE', 25000),
    (N'sv037', N'Ngô Khánh Hà', N'END_USER', N'DOMA', N'ACTIVE', 200000),
    (N'sv038', N'Phan Thành An', N'END_USER', N'CANT', N'ACTIVE', 100000),
    (N'sv039', N'Hồ Minh Bảo', N'END_USER', N'GYM', N'ACTIVE', 40000),
    (N'sv040', N'Đỗ Văn An', N'END_USER', N'LIB', N'ACTIVE', 0),
    (N'sv041', N'Bùi Hoàng Thắng', N'END_USER', N'DOMA', N'ACTIVE', 120000),
    (N'sv042', N'Phạm Hồng Phương', N'END_USER', N'CANT', N'ACTIVE', 50000),
    (N'sv043', N'Huỳnh Quốc Vinh', N'END_USER', N'GYM', N'ACTIVE', 15000),
    (N'sv044', N'Ngô Công Nam', N'END_USER', N'LIB', N'ACTIVE', 150000),
    (N'sv045', N'Vũ Ngọc Trang', N'END_USER', N'DOMA', N'ACTIVE', 75000),
    (N'sv046', N'Phan Thu Châu', N'END_USER', N'CANT', N'ACTIVE', 25000),
    (N'sv047', N'Trần Hữu Tài', N'END_USER', N'GYM', N'ACTIVE', 200000),
    (N'sv048', N'Lý Văn Đạt', N'END_USER', N'LIB', N'ACTIVE', 100000),
    (N'sv049', N'Phan Tuấn Đạt', N'END_USER', N'DOMA', N'ACTIVE', 40000),
    (N'sv050', N'Huỳnh Khánh Linh', N'END_USER', N'CANT', N'ACTIVE', 0),
    (N'sv051', N'Ngô Ngọc Nhi', N'END_USER', N'GYM', N'ACTIVE', 120000),
    (N'sv052', N'Đỗ Thu Linh', N'END_USER', N'LIB', N'ACTIVE', 50000),
    (N'sv053', N'Ngô Mỹ Phương', N'END_USER', N'DOMA', N'ACTIVE', 15000),
    (N'sv054', N'Mai Hồng Phương', N'END_USER', N'CANT', N'ACTIVE', 150000),
    (N'sv055', N'Mai Mỹ Giang', N'END_USER', N'GYM', N'ACTIVE', 75000),
    (N'sv056', N'Vũ Văn Cường', N'END_USER', N'LIB', N'ACTIVE', 25000),
    (N'sv057', N'Bùi Thành Tùng', N'END_USER', N'DOMA', N'ACTIVE', 200000),
    (N'sv058', N'Huỳnh Văn Phúc', N'END_USER', N'CANT', N'ACTIVE', 100000),
    (N'sv059', N'Đỗ Tuấn Kiên', N'END_USER', N'GYM', N'ACTIVE', 40000),
    (N'sv060', N'Trịnh Đức Dũng', N'END_USER', N'LIB', N'ACTIVE', 0),
    (N'sv061', N'Võ Tuấn Tài', N'END_USER', N'DOMA', N'ACTIVE', 120000),
    (N'sv062', N'Phan Công Long', N'END_USER', N'CANT', N'ACTIVE', 50000),
    (N'sv063', N'Trịnh Quốc Dũng', N'END_USER', N'GYM', N'ACTIVE', 15000),
    (N'sv064', N'Phạm Thành Hiếu', N'END_USER', N'LIB', N'ACTIVE', 150000),
    (N'sv065', N'Trần Bảo Trâm', N'END_USER', N'DOMA', N'ACTIVE', 75000),
    (N'sv066', N'Phạm Tuấn Nam', N'END_USER', N'CANT', N'ACTIVE', 25000),
    (N'sv067', N'Lê Mỹ My', N'END_USER', N'GYM', N'ACTIVE', 200000),
    (N'sv068', N'Võ Ngọc Anh', N'END_USER', N'LIB', N'ACTIVE', 100000),
    (N'sv069', N'Võ Khánh Anh', N'END_USER', N'DOMA', N'ACTIVE', 40000),
    (N'sv070', N'Vũ Thị Mai', N'END_USER', N'CANT', N'ACTIVE', 0),
    (N'sv071', N'Trịnh Diệu Ngân', N'END_USER', N'GYM', N'ACTIVE', 120000),
    (N'sv072', N'Dương Diệu Yến', N'END_USER', N'LIB', N'ACTIVE', 50000),
    (N'sv073', N'Lâm Văn Quân', N'END_USER', N'DOMA', N'ACTIVE', 15000),
    (N'sv074', N'Phan Diệu Phương', N'END_USER', N'CANT', N'ACTIVE', 150000),
    (N'sv075', N'Phạm Bảo Thảo', N'END_USER', N'GYM', N'ACTIVE', 75000),
    (N'sv076', N'Võ Thành Long', N'END_USER', N'LIB', N'ACTIVE', 25000),
    (N'sv077', N'Đỗ Văn Nhân', N'END_USER', N'DOMA', N'ACTIVE', 200000),
    (N'sv078', N'Nguyễn Hoàng Lộc', N'END_USER', N'CANT', N'ACTIVE', 100000),
    (N'sv079', N'Phạm Mỹ Xuân', N'END_USER', N'GYM', N'ACTIVE', 40000),
    (N'sv080', N'Đinh Thị Trang', N'END_USER', N'LIB', N'ACTIVE', 0),
    (N'sv081', N'Phan Tuấn Bảo', N'END_USER', N'DOMA', N'ACTIVE', 120000),
    (N'sv082', N'Phạm Quốc Việt', N'END_USER', N'CANT', N'ACTIVE', 50000),
    (N'sv083', N'Trần Thu Thảo', N'END_USER', N'GYM', N'ACTIVE', 15000),
    (N'sv084', N'Đặng Thị Oanh', N'END_USER', N'LIB', N'ACTIVE', 150000),
    (N'sv085', N'Đỗ Thành Quân', N'END_USER', N'DOMA', N'ACTIVE', 75000),
    (N'sv086', N'Ngô Thanh Xuân', N'END_USER', N'CANT', N'ACTIVE', 25000),
    (N'sv087', N'Trịnh Thị Hạnh', N'END_USER', N'GYM', N'ACTIVE', 200000),
    (N'sv088', N'Trịnh Tuấn Quân', N'END_USER', N'LIB', N'ACTIVE', 100000),
    (N'sv089', N'Hoàng Đức An', N'END_USER', N'DOMA', N'ACTIVE', 40000),
    (N'sv090', N'Trịnh Hồng Oanh', N'END_USER', N'CANT', N'ACTIVE', 0),
    (N'sv091', N'Bùi Thu Yến', N'END_USER', N'GYM', N'ACTIVE', 120000),
    (N'sv092', N'Huỳnh Tuấn Bảo', N'END_USER', N'LIB', N'ACTIVE', 50000),
    (N'sv093', N'Mai Hoàng Nam', N'END_USER', N'DOMA', N'ACTIVE', 15000),
    (N'sv094', N'Bùi Văn Kiên', N'END_USER', N'CANT', N'ACTIVE', 150000),
    (N'sv095', N'Vũ Hữu Bảo', N'END_USER', N'GYM', N'ACTIVE', 75000),
    (N'sv096', N'Mai Quốc Nhân', N'END_USER', N'LIB', N'ACTIVE', 25000),
    (N'sv097', N'Hồ Gia Khang', N'END_USER', N'DOMA', N'ACTIVE', 200000),
    (N'sv098', N'Võ Gia Huy', N'END_USER', N'CANT', N'ACTIVE', 100000),
    (N'sv099', N'Dương Hồng Trang', N'END_USER', N'GYM', N'ACTIVE', 40000),
    (N'sv100', N'Đinh Hoàng Huy', N'END_USER', N'LIB', N'ACTIVE', 0),
    (N'sv101', N'Ngô Thu Quyên', N'END_USER', N'DOMA', N'ACTIVE', 120000),
    (N'sv102', N'Đỗ Tuấn Lộc', N'END_USER', N'CANT', N'ACTIVE', 50000),
    (N'sv103', N'Trần Thu Dung', N'END_USER', N'GYM', N'ACTIVE', 15000),
    (N'sv104', N'Trịnh Mỹ Hà', N'END_USER', N'LIB', N'ACTIVE', 150000),
    (N'sv105', N'Phạm Văn Tùng', N'END_USER', N'DOMA', N'ACTIVE', 75000),
    (N'sv106', N'Đinh Mỹ Uyên', N'END_USER', N'CANT', N'ACTIVE', 25000),
    (N'sv107', N'Hồ Khánh Trang', N'END_USER', N'GYM', N'ACTIVE', 200000),
    (N'sv108', N'Mai Quốc Trung', N'END_USER', N'LIB', N'ACTIVE', 100000),
    (N'sv109', N'Hoàng Khánh My', N'END_USER', N'DOMA', N'ACTIVE', 40000),
    (N'sv110', N'Đặng Văn Nhân', N'END_USER', N'CANT', N'ACTIVE', 0),
    (N'sv111', N'Phan Quốc Long', N'END_USER', N'GYM', N'ACTIVE', 120000),
    (N'sv112', N'Đặng Bảo Hà', N'END_USER', N'LIB', N'ACTIVE', 50000),
    (N'sv113', N'Phan Văn Việt', N'END_USER', N'DOMA', N'ACTIVE', 15000),
    (N'sv114', N'Ngô Gia Tài', N'END_USER', N'CANT', N'ACTIVE', 150000),
    (N'sv115', N'Trịnh Quốc Nhân', N'END_USER', N'GYM', N'ACTIVE', 75000),
    (N'sv116', N'Huỳnh Gia Tùng', N'END_USER', N'LIB', N'ACTIVE', 25000),
    (N'sv117', N'Nguyễn Ngọc Thảo', N'END_USER', N'DOMA', N'ACTIVE', 200000),
    (N'sv118', N'Nguyễn Gia Cường', N'END_USER', N'CANT', N'ACTIVE', 100000),
    (N'sv119', N'Phan Phương Hà', N'END_USER', N'GYM', N'ACTIVE', 40000),
    (N'sv120', N'Vũ Quốc Dũng', N'END_USER', N'LIB', N'ACTIVE', 0),
    (N'sv121', N'Lý Minh Nhân', N'END_USER', N'DOMA', N'ACTIVE', 120000),
    (N'sv122', N'Võ Diệu Mai', N'END_USER', N'CANT', N'ACTIVE', 50000),
    (N'sv123', N'Đỗ Hữu Thịnh', N'END_USER', N'GYM', N'ACTIVE', 15000),
    (N'sv124', N'Mai Thanh Ngân', N'END_USER', N'LIB', N'ACTIVE', 150000),
    (N'bikhoa1', N'Dương Công Phúc', N'END_USER', N'DOMA', N'LOCKED', 0),
    (N'vohieu1', N'Lê Hồng Xuân', N'END_USER', N'GYM', N'DISABLED', 0)
;

DECLARE @keep TABLE (username NVARCHAR(50) PRIMARY KEY);
INSERT INTO @keep VALUES (N'system'), (N'admin'), (N'operator1'), (N'operator2'), (N'operator3'), (N'operator4'),
                         (N'student1'), (N'student3'), (N'v2pin'), (N'v2card'), (N'v2fp'), (N'v2noshow');
INSERT INTO @keep SELECT username FROM @accounts;

DECLARE @del TABLE (user_id INT PRIMARY KEY);
INSERT INTO @del SELECT u.user_id FROM Users u WHERE u.username NOT IN (SELECT username FROM @keep);

IF NOT EXISTS (SELECT 1 FROM @del)
   AND NOT EXISTS (SELECT 1 FROM @accounts a WHERE NOT EXISTS (SELECT 1 FROM Users u WHERE u.username = a.username))
BEGIN
    PRINT N'08_accounts_v2: accounts already in place, nothing to do';
    RETURN;
END

DECLARE @admin INT = (SELECT user_id FROM Users WHERE username = N'admin');
DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
DECLARE @hash CHAR(60) = (SELECT password_hash FROM Users WHERE username = N'admin');   -- BCrypt of 123456
DECLARE @now DATETIME2(7) = SYSUTCDATETIME();
DECLARE @deleted INT = (SELECT COUNT(*) FROM @del);

BEGIN TRAN;

-- ===== Part A. Delete the accounts that are not kept, and every row that belongs to them =====
DECLARE @delDep TABLE (id BIGINT PRIMARY KEY);
DECLARE @delCard TABLE (id BIGINT PRIMARY KEY);
DECLARE @delTop TABLE (id BIGINT PRIMARY KEY);
DECLARE @delFp TABLE (id BIGINT PRIMARY KEY);
DECLARE @delCmd TABLE (id BIGINT PRIMARY KEY);
INSERT INTO @delDep SELECT deposit_id FROM Deposit WHERE user_id IN (SELECT user_id FROM @del);
INSERT INTO @delCard SELECT card_id FROM UserCard WHERE user_id IN (SELECT user_id FROM @del);
INSERT INTO @delTop SELECT request_id FROM TopupRequest WHERE user_id IN (SELECT user_id FROM @del);
INSERT INTO @delFp SELECT fp_id FROM Fingerprint WHERE user_id IN (SELECT user_id FROM @del);
INSERT INTO @delCmd SELECT command_id FROM RemoteCommand WHERE requested_by IN (SELECT user_id FROM @del);

-- A1. what the deleted users did to shared things stays, with another actor or none
UPDATE Device SET control_owner = NULL WHERE control_owner IN (SELECT user_id FROM @del);
UPDATE Calibration SET created_by = @admin WHERE created_by IN (SELECT user_id FROM @del);
UPDATE OperatingProfile SET updated_by = @admin WHERE updated_by IN (SELECT user_id FROM @del);
UPDATE LockerSessionLabel SET labeled_by = NULL WHERE labeled_by IN (SELECT user_id FROM @del);
UPDATE TopupRequest SET approved_by = @admin
WHERE approved_by IN (SELECT user_id FROM @del) AND request_id NOT IN (SELECT id FROM @delTop);
UPDATE MaintenanceTicket SET assigned_to = NULL WHERE assigned_to IN (SELECT user_id FROM @del);   -- B4 assigns them again

-- A2. bookings: free the door of an open booking, unlink attempts and commands, then delete
UPDATE s SET s.status = N'AVAILABLE'
FROM LockerSlot s JOIN Deposit d ON d.slot_id = s.locker_slot_id
WHERE d.deposit_id IN (SELECT id FROM @delDep) AND d.status IN (N'RESERVED', N'ACTIVE')
  AND s.status IN (N'RESERVED', N'OCCUPIED');
UPDATE AuthAttempt SET deposit_id = NULL WHERE deposit_id IN (SELECT id FROM @delDep);
UPDATE RemoteCommand SET deposit_id = NULL WHERE deposit_id IN (SELECT id FROM @delDep);
UPDATE Deposit SET card_id = NULL WHERE card_id IN (SELECT id FROM @delCard);   -- a kept booking paid with a deleted card
DELETE FROM Deposit WHERE deposit_id IN (SELECT id FROM @delDep);

DELETE FROM RemoteCommand WHERE command_id IN (SELECT id FROM @delCmd);
DELETE FROM Fingerprint WHERE fp_id IN (SELECT id FROM @delFp);
DELETE FROM UserCard WHERE card_id IN (SELECT id FROM @delCard);
DELETE FROM TopupRequest WHERE request_id IN (SELECT id FROM @delTop);
DELETE FROM UserRole WHERE user_id IN (SELECT user_id FROM @del);

-- A3. audit rows of the deleted users and of their objects; the chain is rebuilt in Part C
DELETE FROM HashChain;
DELETE FROM AuditLog
WHERE actor_user_id IN (SELECT user_id FROM @del)
   OR (object_type = N'USER'        AND object_id IN (SELECT user_id FROM @del))
   OR (object_type = N'DEPOSIT'     AND object_id IN (SELECT id FROM @delDep))
   OR (object_type = N'USERCARD'    AND object_id IN (SELECT id FROM @delCard))
   OR (object_type = N'TOPUP'       AND object_id IN (SELECT id FROM @delTop))
   OR (object_type = N'FINGERPRINT' AND object_id IN (SELECT id FROM @delFp))
   OR (object_type = N'COMMAND'     AND object_id IN (SELECT id FROM @delCmd));

DELETE FROM Users WHERE user_id IN (SELECT user_id FROM @del);

-- A4. no door stays RESERVED or OCCUPIED without an open booking
UPDATE s SET s.status = N'AVAILABLE'
FROM LockerSlot s
WHERE s.status IN (N'RESERVED', N'OCCUPIED')
  AND NOT EXISTS (SELECT 1 FROM Deposit d WHERE d.slot_id = s.locker_slot_id AND d.status IN (N'RESERVED', N'ACTIVE'));

-- ===== Part B. New accounts and their history (only for the accounts this run creates) =====
DECLARE @new TABLE (user_id INT PRIMARY KEY, username NVARCHAR(50), n INT, area_id INT, created_at DATETIME2(7));
INSERT INTO Users (username, password_hash, full_name, status, balance, area_id, created_at)
OUTPUT inserted.user_id, inserted.username,
       CASE WHEN inserted.username LIKE N'sv[0-9][0-9][0-9]' THEN CAST(SUBSTRING(inserted.username, 3, 3) AS INT) ELSE 0 END,
       inserted.area_id, inserted.created_at
INTO @new
SELECT a.username, @hash, a.full_name, a.status, a.balance, ar.area_id,
       DATEADD(DAY, -(35 + CASE WHEN a.username LIKE N'sv[0-9][0-9][0-9]'
                                THEN CAST(SUBSTRING(a.username, 3, 3) AS INT) % 25 ELSE 25 END), @now)
FROM @accounts a JOIN LockerArea ar ON ar.area_code = a.area_code
WHERE NOT EXISTS (SELECT 1 FROM Users u WHERE u.username = a.username);

INSERT INTO UserRole (user_id, role_id)
SELECT n.user_id, r.role_id FROM @new n
JOIN @accounts a ON a.username = n.username
JOIN Roles r ON r.role_name = a.role_name;

-- B1. cards for sv001..sv024
INSERT INTO UserCard (card_uid, user_id, status, issued_at)
SELECT CONCAT('A8', LEFT(CONVERT(VARCHAR(64), HASHBYTES('MD5', n.username), 2), 6)), n.user_id, N'ACTIVE',
       DATEADD(DAY, 1, n.created_at)
FROM @new n
WHERE n.n BETWEEN 1 AND 24
  AND NOT EXISTS (SELECT 1 FROM UserCard c
                  WHERE c.card_uid = CONCAT('A8', LEFT(CONVERT(VARCHAR(64), HASHBYTES('MD5', n.username), 2), 6)));

-- B2. top-ups over the last 30 days: approved (sv001..sv070, a second one for sv001..sv025), pending, rejected
DECLARE @admin2 INT = (SELECT user_id FROM Users WHERE username = N'admin2');
INSERT INTO TopupRequest (user_id, amount, transfer_code, qr_url, status, created_at, approved_at, approved_by, note)
SELECT t.user_id, t.amount, t.code,
       CONCAT(N'https://img.vietqr.io/image/MB-0981025559-compact2.png?amount=', t.amount, N'&addInfo=', t.code,
              N'&accountName=SMART+LOCKER'),
       t.status, t.created_at,
       CASE WHEN t.status = N'PENDING' THEN NULL ELSE DATEADD(MINUTE, 3 + t.n % 25, t.created_at) END,
       CASE WHEN t.status = N'PENDING' THEN NULL WHEN t.n % 2 = 0 THEN @admin ELSE @admin2 END,
       CASE WHEN t.status = N'REJECTED' THEN N'Không nhận được chuyển khoản' END
FROM (
    SELECT n.user_id, n.n, k.k,
           CASE (n.n + k.k) % 5 WHEN 0 THEN 50000 WHEN 1 THEN 100000 WHEN 2 THEN 200000 WHEN 3 THEN 20000 ELSE 30000 END AS amount,
           CONCAT(N'TOPUP_', n.user_id, N'_', LEFT(CONVERT(VARCHAR(64), HASHBYTES('MD5', CONCAT(n.username, N'#', k.k)), 2), 12)) AS code,
           CASE WHEN n.n <= 70 THEN N'APPROVED' WHEN n.n <= 76 THEN N'PENDING' ELSE N'REJECTED' END AS status,
           CASE WHEN n.n BETWEEN 71 AND 76
                THEN DATEADD(MINUTE, -(60 + n.n * 37 % 2800), @now)                       -- pending: last 2 days
                ELSE DATEADD(MINUTE, -((n.n * 5 + k.k * 13) % 29 * 1440 + (n.n % 10 + 1) * 60), @now) END AS created_at
    FROM @new n
    JOIN (VALUES (1), (2)) k(k) ON k.k = 1 OR n.n <= 25
    WHERE n.n BETWEEN 1 AND 79
) t;

-- B3. completed bookings over the last 30 days: one for sv001..sv096, two for every third of them
DECLARE @slots TABLE (area_id INT, idx INT, slot_id INT, PRIMARY KEY (area_id, idx));
INSERT INTO @slots
SELECT b.area_id, ROW_NUMBER() OVER (PARTITION BY b.area_id ORDER BY s.locker_slot_id) - 1, s.locker_slot_id
FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE s.status <> N'MAINTENANCE';

INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, reserved_at, hold_until,
                     started_at, due_at, ended_at, extend_count, open_method, pin_code)
SELECT x.user_id, x.slot_id, p.plan_id, x.card_id, dbo.fn_OpenPrice(p.price, x.method), N'COMPLETED',
       x.reserved_at, DATEADD(MINUTE, 15, x.reserved_at),
       DATEADD(MINUTE, x.n % 9 + 1, x.reserved_at),
       DATEADD(MINUTE, x.n % 9 + 1 + p.duration_min, x.reserved_at),
       DATEADD(MINUTE, x.n % 9 + 1 + p.duration_min * (30 + (x.n * 13 + x.k) % 60) / 100, x.reserved_at),
       0, x.method,
       CASE WHEN x.method = N'PIN' THEN RIGHT(CONCAT('00000', (x.n * 7919 + x.k * 104729) % 1000000), 6) END
FROM (
    SELECT n.user_id, n.n, k.k,
           (SELECT s.slot_id FROM @slots s
            WHERE s.area_id = n.area_id
              AND s.idx = (n.n * 3 + k.k) % (SELECT COUNT(*) FROM @slots c WHERE c.area_id = n.area_id)) AS slot_id,
           CASE WHEN k.k = 1 AND c.card_id IS NOT NULL THEN N'CARD' ELSE N'PIN' END AS method,
           CASE WHEN k.k = 1 THEN c.card_id END AS card_id,
           CASE WHEN d.d >= 2 THEN (n.n + k.k) % 3 WHEN d.d = 1 THEN (n.n + k.k) % 2 ELSE 0 END AS plan_no,
           DATEADD(MINUTE, -(d.d * 1440 + ((n.n * 5 + k.k * 3) % 12 + 3) * 60 + n.n % 50), @now) AS reserved_at
    FROM @new n
    JOIN (VALUES (1), (2)) k(k) ON k.k = 1 OR n.n % 3 = 0
    CROSS APPLY (SELECT (n.n * 7 + k.k * 11) % 30 AS d) d
    OUTER APPLY (SELECT TOP 1 uc.card_id FROM UserCard uc WHERE uc.user_id = n.user_id AND uc.status = N'ACTIVE') c
    WHERE n.n BETWEEN 1 AND 96
) x
JOIN StoragePlan p ON p.duration_min = CASE x.plan_no WHEN 0 THEN 120 WHEN 1 THEN 240 ELSE 1440 END AND p.is_active = 1;

-- B4. every ticket without a technician goes to the new technician of its area (kythuat5 when none)
UPDATE t SET t.assigned_to = ISNULL(tech.user_id, (SELECT user_id FROM Users WHERE username = N'kythuat5'))
FROM MaintenanceTicket t
LEFT JOIN LockerBank b ON b.device_id = t.device_id
LEFT JOIN LockerArea a ON a.area_id = b.area_id
OUTER APPLY (SELECT u.user_id FROM Users u
             WHERE u.username = CASE a.area_code WHEN N'LIB' THEN N'kythuat1' WHEN N'DOMA' THEN N'kythuat2'
                                                 WHEN N'CANT' THEN N'kythuat3' WHEN N'GYM' THEN N'kythuat4' END) tech
WHERE t.assigned_to IS NULL;

-- ===== Part C. Rebuild the hash chain over the remaining rows, in audit_id order =====
-- Same text as Audit_Append: CONCAT turns a NULL actor or object id into '', the diff is ISNULL(diff, '').
DECLARE @order TABLE (pos INT IDENTITY PRIMARY KEY, audit_id BIGINT);
INSERT INTO @order (audit_id) SELECT audit_id FROM AuditLog ORDER BY audit_id;

DECLARE @pos INT = 1, @last INT = (SELECT COUNT(*) FROM @order);
DECLARE @id BIGINT, @ts DATETIME2(7), @actor INT, @action NVARCHAR(50), @objectType NVARCHAR(50),
        @objectId BIGINT, @diff NVARCHAR(MAX), @prev CHAR(64) = REPLICATE('0', 64), @row NVARCHAR(MAX), @h CHAR(64);
WHILE @pos <= @last
BEGIN
    SELECT @id = a.audit_id, @ts = a.ts, @actor = a.actor_user_id, @action = a.action, @objectType = a.object_type,
           @objectId = a.object_id, @diff = a.diff_json
    FROM @order o JOIN AuditLog a ON a.audit_id = o.audit_id WHERE o.pos = @pos;
    SET @row = CONCAT(@id, '|', CONVERT(NVARCHAR(33), @ts, 126), '|', @actor, '|', @action, '|',
                      @objectType, '|', @objectId, '|', ISNULL(@diff, ''), '|', @prev);
    SET @h = LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', @row), 2));
    UPDATE AuditLog SET row_hash = @h WHERE audit_id = @id;
    INSERT INTO HashChain (audit_id, prev_hash, chain_hash) VALUES (@id, @prev, @h);
    SET @prev = @h;
    SET @pos += 1;
END

DECLARE @added INT = (SELECT COUNT(*) FROM @new);
DECLARE @note NVARCHAR(200) = CONCAT(@deleted, N' accounts deleted, ', @added, N' accounts added, audit chain rebuilt');
EXEC Audit_Append @sys, N'ACCOUNTS_V2', N'USER', 0, @note;    -- object id 0: many users
COMMIT;
PRINT CONCAT(N'08_accounts_v2: ', @note);
GO

SELECT r.role_name, u.status, COUNT(*) AS accounts
FROM Users u JOIN UserRole ur ON ur.user_id = u.user_id JOIN Roles r ON r.role_id = ur.role_id
GROUP BY r.role_name, u.status ORDER BY r.role_name, u.status;
GO
