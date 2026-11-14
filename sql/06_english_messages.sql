-- ============================================================
-- 06_english_messages.sql  Smart Locker: English interface (PRJ301 asks for an English UI, see
-- docs/review/teacher-feedback-2026-11-14.md, table 2 row 1).
-- For a database built before this change. A fresh build needs nothing: 03_v2_v3.sql now seeds the English text.
-- Safe to run again, also on a live database: it only rewrites rows that still hold the old Vietnamese seed text,
-- so a plan or an item list an admin edited is left alone. It changes no procedure, so 03/04/05 need no re-run.
--
-- It also translates the seed sentences of 02_data_v1.sql that staff pages show (top-up notes, sample alert
-- reasons, maintenance notes, remote unlock reasons); 02 itself now seeds them in English.
-- What stays as it is: area, bank and location names and the demo user names (seed data, place names),
-- except the OPS area ("Operations", the staff office), which is ordinary words and is turned back to English.
-- The reasons the procedures write into RemoteCommand.reason ("Mở bằng điện thoại", ...) are translated when they
-- are shown (dao.RemoteCommandDao.reasonText), so old rows read the same as new ones.
-- The business errors the procedures THROW are English already; util.Web.sqlMessage rewords them for the pages.
--
-- Run (on an SL_* test database first):
--   sqlcmd -S localhost -U sa -P 12345 -d <database> -I -b -f 65001 -i sql\06_english_messages.sql
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRAN;

-- storage plan names are UI labels (the code finds plans by duration_min, never by name)
UPDATE p SET plan_name = v.en
FROM dbo.StoragePlan p
JOIN (VALUES (N'2 hours', N'2 giờ', 120), (N'4 hours', N'4 giờ', 240), (N'Day pass', N'Trọn ngày', 1440),
             (N'Demo 2 minutes', N'Demo 2 phút', 2)) v(en, vi, minutes)
  ON p.plan_name = v.vi AND p.duration_min = v.minutes;
PRINT CONCAT('StoragePlan renamed: ', @@ROWCOUNT);

-- the example items of each slot size, shown in the booking popup of the map
UPDATE s SET items = v.en
FROM dbo.SlotSize s
JOIN (VALUES
    ('S', N'Ví;Điện thoại;Chìa khóa;Tai nghe;Sạc dự phòng;Sổ tay nhỏ',
          N'Wallet;Phone;Keys;Headphones;Power bank;Small notebook'),
    ('M', N'Laptop tới 15,6 inch;Túi xách;Balo nhỏ (dưới 40 cm);Một đôi giày;Áo khoác gấp gọn',
          N'Laptop up to 15.6 inch;Handbag;Small backpack (under 40 cm);A pair of shoes;Folded jacket'),
    ('L', N'Balo lớn;Vali cabin (55x40x20 cm);Mũ bảo hiểm fullface;Túi thể thao;Thùng đồ nhỏ',
          N'Large backpack;Cabin suitcase (55x40x20 cm);Full-face helmet;Sports bag;Small box')) v(code, vi, en)
  ON s.size_code = v.code AND s.items = v.vi;
PRINT CONCAT('SlotSize items translated: ', @@ROWCOUNT);

-- the seed sentences of 02_data_v1.sql that staff pages show (names stay as they are)
UPDATE t SET note = v.en
FROM dbo.TopupRequest t
JOIN (VALUES
    (N'Chờ đối soát giao dịch chuyển khoản ngân hàng',
     N'Waiting for the bank transfer to be matched'),
    (N'Đã đối soát khớp lệnh và cộng tiền vào ví',
     N'Transfer matched and added to the wallet'),
    (N'Từ chối: nội dung chuyển khoản không khớp mã tham chiếu',
     N'Rejected: the transfer note does not match the reference code')) v(vi, en) ON t.note = v.vi;
PRINT CONCAT('TopupRequest notes translated: ', @@ROWCOUNT);

-- the reason of each sample alert (Alerts page, evidence "demo_case")
UPDATE e SET value_text = v.en
FROM dbo.AlertEvidence e
JOIN (VALUES
    (N'Cửa mở khi RFID không hợp lệ (Cạy tủ)',
     N'Door opened without a valid RFID card (forced open)'),
    (N'Khối lượng thay đổi trong khi cửa báo đóng',
     N'Weight changed while the door reported closed'),
    (N'Còn vật nặng 220g sau khi lấy đồ và đóng cửa',
     N'A 220 g item was left after pick-up and the door closed'),
    (N'Gửi đồ 170 phút, vượt gói 120 phút và ân hạn',
     N'Stored for 170 min, over the 120-min plan and the grace period'),
    (N'Thẻ student25 cố tình quét mở slot của student14',
     N'The card of student25 was scanned to open the slot of student14'),
    (N'Thẻ đã báo mất được sử dụng lại',
     N'A card reported lost was used again'),
    (N'Thẻ bị khóa được sử dụng lại',
     N'A blocked card was used again'),
    (N'Hiệu chuẩn cảm biến khối lượng đã hết hạn',
     N'The weight sensor calibration has expired'),
    (N'Mở từ xa không có lệnh hợp lệ',
     N'Remote open without a valid command'),
    (N'Đồng hồ thiết bị trôi quá 15 phút so với máy chủ',
     N'The box clock drifted more than 15 min from the server'),
    (N'Khối lượng 25000g vượt giới hạn cảm biến',
     N'Weight 25000 g exceeds the sensor limit'),
    (N'Mô hình Machine Learning phát hiện hành vi bất thường (Điểm 0.94)',
     N'The machine learning model detected unusual behaviour (score 0.94)')) v(vi, en) ON e.item = N'demo_case' AND e.value_text = v.vi;
PRINT CONCAT('AlertEvidence demo_case translated: ', @@ROWCOUNT);

-- maintenance ticket notes: three fixed sentences, the sensor tickets (prefix + alert reason), the closed rounds
UPDATE m SET note = v.en
FROM dbo.MaintenanceTicket m
JOIN (VALUES
    (N'Bảo trì định kỳ tủ LIB-A: kiểm tra chốt solenoid các ô A01-A04',
     N'Routine maintenance of LIB-A: check the solenoid bolts of slots A01-A04'),
    (N'Kiểm tra ăng ten đọc thẻ RFID tại sảnh Ký túc xá DOMA-A',
     N'Check the RFID reader antenna in the DOMA-A dormitory lobby'),
    (N'Vệ sinh cảm biến hồng ngoại và công tắc từ Bank CANT-A',
     N'Clean the infrared sensor and the reed switch of bank CANT-A'),
    -- the older 03_v2_v3.sql turned "Bank CANT-A" into "dãy CANT-A" (also in the English note of a build in between)
    (N'Vệ sinh cảm biến hồng ngoại và công tắc từ dãy CANT-A',
     N'Clean the infrared sensor and the reed switch of bank CANT-A'),
    (N'Clean the infrared sensor and the reed switch of dãy CANT-A',
     N'Clean the infrared sensor and the reed switch of bank CANT-A')) v(vi, en) ON m.note = v.vi;
PRINT CONCAT('MaintenanceTicket notes translated: ', @@ROWCOUNT);

UPDATE m SET note = N'Check and recalibrate the weight sensor: ' + v.en
FROM dbo.MaintenanceTicket m
JOIN (VALUES
    (N'Cửa mở khi RFID không hợp lệ (Cạy tủ)',
     N'Door opened without a valid RFID card (forced open)'),
    (N'Khối lượng thay đổi trong khi cửa báo đóng',
     N'Weight changed while the door reported closed'),
    (N'Còn vật nặng 220g sau khi lấy đồ và đóng cửa',
     N'A 220 g item was left after pick-up and the door closed'),
    (N'Gửi đồ 170 phút, vượt gói 120 phút và ân hạn',
     N'Stored for 170 min, over the 120-min plan and the grace period'),
    (N'Thẻ student25 cố tình quét mở slot của student14',
     N'The card of student25 was scanned to open the slot of student14'),
    (N'Thẻ đã báo mất được sử dụng lại',
     N'A card reported lost was used again'),
    (N'Thẻ bị khóa được sử dụng lại',
     N'A blocked card was used again'),
    (N'Hiệu chuẩn cảm biến khối lượng đã hết hạn',
     N'The weight sensor calibration has expired'),
    (N'Mở từ xa không có lệnh hợp lệ',
     N'Remote open without a valid command'),
    (N'Đồng hồ thiết bị trôi quá 15 phút so với máy chủ',
     N'The box clock drifted more than 15 min from the server'),
    (N'Khối lượng 25000g vượt giới hạn cảm biến',
     N'Weight 25000 g exceeds the sensor limit'),
    (N'Mô hình Machine Learning phát hiện hành vi bất thường (Điểm 0.94)',
     N'The machine learning model detected unusual behaviour (score 0.94)')) v(vi, en) ON m.note = N'Kiểm tra và hiệu chuẩn lại cảm biến trọng lượng: ' + v.vi;
PRINT CONCAT('MaintenanceTicket sensor notes translated: ', @@ROWCOUNT);

-- DATALENGTH, not LEN: LEN ignores the trailing space of the prefix
UPDATE dbo.MaintenanceTicket
SET note = N'Maintenance and sensor check done, round ' + SUBSTRING(note, DATALENGTH(N'Đã hoàn thành bảo dưỡng và kiểm tra cảm biến lần ') / 2 + 1, 20)
WHERE note LIKE N'Đã hoàn thành bảo dưỡng và kiểm tra cảm biến lần ' + N'[0-9]%';
PRINT CONCAT('MaintenanceTicket closed rounds translated: ', @@ROWCOUNT);

-- remote unlock reasons of the seed ("... lần N")
UPDATE dbo.RemoteCommand
SET reason = N'Emergency open from the admin desk, request ' + SUBSTRING(reason, DATALENGTH(N'Hỗ trợ mở tủ khẩn cấp từ quầy quản trị viên lần ') / 2 + 1, 20)
WHERE reason LIKE N'Hỗ trợ mở tủ khẩn cấp từ quầy quản trị viên lần ' + N'[0-9]%';
PRINT CONCAT('RemoteCommand seed reasons translated: ', @@ROWCOUNT);

-- Older builds of 03_v2_v3.sql renamed "Bank A" to "Dãy A" and the system account to Vietnamese
UPDATE dbo.LockerBank SET name = N'Bank ' + SUBSTRING(name, 5, 10)
WHERE name LIKE N'Dãy _%';
PRINT CONCAT('LockerBank names translated: ', @@ROWCOUNT);

UPDATE dbo.Users SET full_name = N'System account'
WHERE username = N'system' AND full_name = N'Tài khoản hệ thống';
PRINT CONCAT('System account name translated: ', @@ROWCOUNT);

-- The OPS area is not a place but the staff office: older builds of 03 gave it Vietnamese words
-- (Areas page and every area dropdown); real place names stay Vietnamese
UPDATE dbo.LockerArea SET name = N'Operations'
WHERE area_code = N'OPS' AND name = N'Vận hành';
PRINT CONCAT('OPS area name translated: ', @@ROWCOUNT);

UPDATE dbo.LockerArea SET location = N'Staff office, no locker slots'
WHERE area_code = N'OPS' AND location = N'Văn phòng nhân viên, không có ngăn tủ';
PRINT CONCAT('OPS area location translated: ', @@ROWCOUNT);

COMMIT;
GO
