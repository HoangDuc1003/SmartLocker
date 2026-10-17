-- ============================================================
-- 07_vietnamese_data.sql  Vietnamese names for the seed data that users see.
-- Run after 01..06. Safe to run again: each UPDATE only touches a row that still has
-- the English seed text, so a name changed later by staff is kept.
-- Technical codes (area_code, bank_code, slot_code, device_code) are not changed.
-- Plans are matched by name here; scripts that need a plan look it up by duration_min.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET NOCOUNT ON;

-- Storage plans
UPDATE p SET plan_name = v.vi
FROM dbo.StoragePlan p
JOIN (VALUES (N'2 hours', N'2 giờ'), (N'4 hours', N'4 giờ'), (N'Day pass', N'Trọn ngày'),
             (N'Demo 2 minutes', N'Demo 2 phút')) v(en, vi) ON p.plan_name = v.en;

-- Areas: name and location
UPDATE a SET name = v.vi
FROM dbo.LockerArea a
JOIN (VALUES (N'LIB', N'Library', N'Thư viện'), (N'DOMA', N'Dormitory A', N'Ký túc xá A'),
             (N'CANT', N'Canteen', N'Căng tin'), (N'GYM', N'Sports Hall', N'Nhà thi đấu'),
             (N'OPS', N'Operations', N'Vận hành')) v(code, en, vi)
  ON a.area_code = v.code AND a.name = v.en;

UPDATE a SET location = v.vi
FROM dbo.LockerArea a
JOIN (VALUES (N'Library, 1st floor', N'Thư viện, tầng 1'), (N'Dorm A lobby', N'Sảnh ký túc xá A'),
             (N'Next to the canteen entrance', N'Cạnh lối vào căng tin'),
             (N'Sports hall changing room', N'Phòng thay đồ nhà thi đấu'),
             (N'Staff office, no locker slots', N'Văn phòng nhân viên, không có ngăn tủ')) v(en, vi)
  ON a.location = v.en;

-- Devices: location (the same texts as the areas)
UPDATE d SET location = v.vi
FROM dbo.Device d
JOIN (VALUES (N'Library, 1st floor', N'Thư viện, tầng 1'), (N'Dorm A lobby', N'Sảnh ký túc xá A'),
             (N'Next to the canteen entrance', N'Cạnh lối vào căng tin'),
             (N'Sports hall changing room', N'Phòng thay đồ nhà thi đấu')) v(en, vi)
  ON d.location = v.en;

-- Locker banks: "Bank A" -> "Dãy A"
UPDATE dbo.LockerBank SET name = N'Dãy ' + SUBSTRING(name, 6, 10)
WHERE name LIKE N'Bank _%';

-- The system account is shown as the actor of automatic audit rows
UPDATE dbo.Users SET full_name = N'Tài khoản hệ thống'
WHERE username = N'system' AND full_name = N'System account';

-- One seeded ticket note still says "Bank CANT-A"
UPDATE dbo.MaintenanceTicket SET note = REPLACE(note, N'Bank CANT-A', N'dãy CANT-A')
WHERE note LIKE N'%Bank CANT-A%';
GO

SELECT plan_id, plan_name, is_active FROM dbo.StoragePlan ORDER BY plan_id;
SELECT area_code, name, location FROM dbo.LockerArea ORDER BY area_id;
SELECT bank_code, name FROM dbo.LockerBank ORDER BY bank_id;
GO
