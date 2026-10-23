-- ============================================================
-- 10_campus_vnu.sql  v4: the areas sit on the VNU-HCM campus (Thu Duc / Di An) instead of the example campus.
-- Run after 09_v3.sql (sqlcmd -I -f 65001). Safe to run again:
--   * a coordinate is only replaced while it is empty or still the example one (outside Ho Chi Minh City),
--     so a value typed by staff in the area form is never overwritten;
--   * a name or a location is only replaced while it still has the seed text;
--   * the new area DOMB and its cabinets are created once.
-- The coordinates of the library are APPROXIMATE (about 500 m); the other four are Google Maps pins. Put the real ones in the area form (LockerAreaController)
-- or edit the VALUES list and run this file again after setting latitude/longitude to NULL.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET NOCOUNT ON;

-- A. New area: dormitory zone B (demo cabinets, no hardware, drawn like DOMA)
IF NOT EXISTS (SELECT 1 FROM dbo.LockerArea WHERE area_code = N'DOMB')
    INSERT INTO dbo.LockerArea (area_code, name, location)
    VALUES (N'DOMB', N'Ký túc xá khu B', N'Sảnh ký túc xá khu B, ĐHQG-HCM');

INSERT INTO dbo.LockerBank (bank_code, name, area_id, device_id, door_rows)
SELECT v.code, v.name, a.area_id, NULL, 4
FROM (VALUES (N'DOMB-A', N'Bank A'), (N'DOMB-B', N'Bank B')) v(code, name)
JOIN dbo.LockerArea a ON a.area_code = N'DOMB'
WHERE NOT EXISTS (SELECT 1 FROM dbo.LockerBank b WHERE b.bank_code = v.code);

-- slots only for a bank that has none yet: A01..A16 and B01..B12; the bottom door is L, the one above it M
;WITH n AS (SELECT TOP (16) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO dbo.LockerSlot (slot_code, bank_id, size_cm, size_code, status)
SELECT RIGHT(b.bank_code, 1) + RIGHT('0' + CAST(n.i AS VARCHAR(2)), 2), b.bank_id, N'30x30x45',
       CASE WHEN (n.i - 1) % 4 = 3 THEN 'L' WHEN (n.i - 1) % 4 = 2 THEN 'M' ELSE 'S' END,
       N'AVAILABLE'
FROM dbo.LockerBank b
JOIN (VALUES (N'DOMB-A', 16), (N'DOMB-B', 12)) c(code, cnt) ON c.code = b.bank_code
JOIN n ON n.i <= c.cnt
WHERE NOT EXISTS (SELECT 1 FROM dbo.LockerSlot s WHERE s.bank_id = b.bank_id);

-- the measures always follow SlotSize (same rule as 09_v3.sql)
UPDATE s SET s.size_cm = z.size_cm
FROM dbo.LockerSlot s JOIN dbo.SlotSize z ON z.size_code = s.size_code
WHERE ISNULL(s.size_cm, N'') <> z.size_cm;
GO

-- B. Names and places (only the seed texts are replaced)
UPDATE a SET a.name = v.new_name
FROM dbo.LockerArea a
JOIN (VALUES (N'DOMA', N'Ký túc xá A',    N'Ký túc xá khu A'),
             (N'GYM',  N'Nhà thi đấu',    N'Nhà văn hóa Sinh viên'),
             (N'LIB',  N'Thư viện',       N'Thư viện FPTU HCM'),
             (N'LIB',  N'Thư viện Trung tâm', N'Thư viện FPTU HCM'),
             (N'CANT', N'Căng tin',       N'Căng tin KTX khu A')) v(code, old_name, new_name)
  ON v.code = a.area_code AND a.name = v.old_name;

UPDATE a SET a.location = v.new_loc
FROM dbo.LockerArea a
JOIN (VALUES (N'DOMA', N'Sảnh ký túc xá A',              N'A14 KTX A ĐHQG TPHCM, Đông Hòa, Hồ Chí Minh'),
             (N'DOMA', N'Sảnh ký túc xá khu A, ĐHQG-HCM', N'A14 KTX A ĐHQG TPHCM, Đông Hòa, Hồ Chí Minh'),
             (N'GYM',  N'Phòng thay đồ nhà thi đấu',     N'Số 1 Lưu Hữu Phước, Đông Hòa, Hồ Chí Minh'),
             (N'GYM',  N'Nhà văn hóa Sinh viên TP.HCM, Làng Đại học', N'Số 1 Lưu Hữu Phước, Đông Hòa, Hồ Chí Minh'),
             (N'LIB',  N'Thư viện, tầng 1',              N'Thư viện, Đại học FPT TP.HCM, Khu Công nghệ cao, tầng 1'),
             (N'LIB',  N'Thư viện Trung tâm ĐHQG-HCM, tầng 1', N'Thư viện, Đại học FPT TP.HCM, Khu Công nghệ cao, tầng 1'),
             (N'CANT', N'Cạnh lối vào căng tin',         N'Căng tin cạnh ký túc xá khu A')) v(code, old_loc, new_loc)
  ON v.code = a.area_code AND a.location = v.old_loc;

-- the devices repeat the place of their area
UPDATE d SET d.location = a.location
FROM dbo.Device d
JOIN dbo.LockerBank b ON b.device_id = d.device_id
JOIN dbo.LockerArea a ON a.area_id = b.area_id
WHERE a.area_code IN (N'DOMA', N'GYM', N'LIB', N'CANT')
  AND d.location IN (N'Sảnh ký túc xá A', N'Phòng thay đồ nhà thi đấu', N'Thư viện, tầng 1', N'Cạnh lối vào căng tin',
                     N'Sảnh ký túc xá khu A, ĐHQG-HCM', N'Nhà văn hóa Sinh viên TP.HCM, Làng Đại học');
GO

-- C. Coordinates. DOMA, DOMB, GYM and CANT come from Google Maps pins; LIB (FPTU HCM) is approximate.
--    The values written by the first drafts of this file are cleared first so that they are replaced.
UPDATE dbo.LockerArea SET latitude = NULL, longitude = NULL
WHERE (area_code = N'DOMA' AND latitude IN (10.883000) AND longitude IN (106.781000))
   OR (area_code = N'DOMB' AND latitude IN (10.887000) AND longitude IN (106.777000))
   OR (area_code = N'GYM'  AND latitude IN (10.879000) AND longitude IN (106.800000))
   OR (area_code = N'CANT' AND latitude IN (10.882600) AND longitude IN (106.781500));
UPDATE a SET a.latitude = v.lat, a.longitude = v.lng
FROM dbo.LockerArea a
JOIN (VALUES (N'DOMA', 10.880078, 106.807655),    -- A14 KTX A ĐHQG TPHCM (Google Maps)
             (N'DOMB', 10.883592, 106.779613),    -- Ký túc xá khu B, ĐHQG (nhà C6) (Google Maps)
             (N'GYM',  10.875131, 106.800723),    -- Nhà Văn hóa Sinh viên TP.HCM (Google Maps)
             (N'LIB',  10.841100, 106.809900),    -- Thư viện, Đại học FPT TP.HCM (Khu Công nghệ cao, Thủ Đức)
             (N'CANT', 10.880278, 106.807855))    -- Căng tin KTX khu A: cùng chỗ với A14, lệch khoảng 30 m để hai ghim không đè nhau
     v(code, lat, lng) ON v.code = a.area_code
WHERE a.latitude IS NULL OR a.longitude IS NULL
   OR (a.area_code = N'LIB' AND a.latitude = 10.875000 AND a.longitude = 106.801000)   -- the first draft of this file
   OR a.latitude NOT BETWEEN 10.60 AND 11.20 OR a.longitude NOT BETWEEN 106.40 AND 107.10;
GO

-- D. FAKE device IPs for the library boxes (documentation range 192.0.2.0/24, RFC 5737); stored only, never used to find a place
UPDATE d SET d.ip_address = CONCAT(N'192.0.2.', 10 + d.device_id)
FROM dbo.Device d
JOIN dbo.LockerBank b ON b.device_id = d.device_id
JOIN dbo.LockerArea a ON a.area_id = b.area_id
WHERE a.area_code = N'LIB' AND d.ip_address IS NULL;
GO

SELECT area_code, name, location, latitude, longitude FROM dbo.LockerArea ORDER BY area_code;
SELECT d.device_code, d.ip_address, b.bank_code FROM dbo.Device d LEFT JOIN dbo.LockerBank b ON b.device_id = d.device_id ORDER BY d.device_id;
SELECT a.area_code, COUNT(s.locker_slot_id) AS slots
FROM dbo.LockerArea a LEFT JOIN dbo.LockerBank b ON b.area_id = a.area_id
LEFT JOIN dbo.LockerSlot s ON s.bank_id = b.bank_id GROUP BY a.area_code ORDER BY a.area_code;
GO
