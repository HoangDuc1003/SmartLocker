# Review thay đổi của agent "fix-bugs"

Người review: code-reviewer · Ngày: 30/10/2026 · Phạm vi: `git diff` chưa commit (bỏ qua `src/java/ml/*`, `docs/paper/*`).

## Kết luận: NEEDS FIXES (nhỏ)

Không có lỗi chặn (blocker). Bốn sửa lỗi đúng ý đồ, test xanh, SQL trên DB khớp repo. Còn 1 lỗi mức Trung bình
(heartbeat giả lập làm mất trạng thái OFFLINE cố ý của thiết bị demo) và vài điểm Thấp nên sửa kèm.

## Kiểm tra đã chạy

| Hạng mục | Kết quả |
|---|---|
| `sh scripts/test.sh` | 53 chạy, 53 đạt, 0 lỗi, 0 bỏ qua |
| 4 thủ tục trên DB live (`OBJECT_DEFINITION`) so với file | Khớp từng dòng (chỉ khác `CREATE` / `CREATE OR ALTER`): `Deposit_Complete` (02), `Deposit_CheckIn`, `RemoteCommand_TakePending`, `Device_Authorize` (bản cuối trong 03) |
| Trình duyệt (claude-in-chrome, admin) | Danh sách cảnh báo hiện mã thiết bị (`LOCKER-01`, `LOCKER-10`) và rủi ro dạng `100%`, `0%`, `–`; chi tiết #50 hiện `100%`, hai thẻ cùng `top=76px`, `margin-top: 0`; không lỗi console. Ảnh: `docs/review/alert-detail.jpg` |
| Trang khác dùng `.grid-2/.grid-3` | Dashboard (2 panel cùng top), Nạp tiền (2 panel cùng top/cao), không lỗi console. `remoteCommand.jsp` dùng `.grid-3` cho form (con là `.field`, không phải `.panel`) nên không bị ảnh hưởng. Ở màn hẹp (1 cột) `gap: 16px` vẫn tạo khoảng cách dọc, nên bỏ `margin-top` không làm dính panel |
| Bản đồ | 5 khu vực demo hiện số ngăn trống; dashboard "9/10 thiết bị trực tuyến"; DB: 9 thiết bị demo `ACTIVE`, `last_seen` 11 s |

## Đối chiếu quy tắc CLAUDE.md

- try-with-resources JDBC: đạt (`LockerSessionDao.insert/resolveSlot`, `LockerMonitor.heartbeatDemoDevices`, `SessionContextDao`, `AlertDao.search`).
- `EXEC` chỉ nhận biến/hằng: đạt (`@work_slot`, `@slot_id`).
- Tương thích firmware cũ/Postman: đạt. Không có `bank_code` → `(? IS NULL OR ...)` cho cùng kết quả cũ trên hộp 1 dãy; tham số `@locker_slot_id INT = NULL` giữ các lời gọi 2 đối số (`sql/test_setup.sql:183,220`, bản cũ trong 03 dòng 350/522). Trả lời batch chỉ thêm trường `errors`.
- `<c:out>` / không style màu inline: đạt (`alert.jsp` dùng `<c:out>` cho `deviceCode`, `fmt:formatNumber` cho rủi ro; taglib `fmt` đã khai báo dòng 3).
- Heartbeat demo không chạm thiết bị không-demo, không ghi đè MAINTENANCE: đạt (lọc `"demo":true`; `Device_Heartbeat` giữ MAINTENANCE). `LOCKER-01` (demo=0) không bị đụng.
- Bảo mật dung sai 60 s: chấp nhận được. Lệnh vẫn gắn device + slot + `status='SENT'`; `measured_at` do chính thiết bị đã xác thực bằng API key gửi lên, nên dung sai không mở thêm đường cho bên ngoài. `DATEDIFF` được chặn tràn bằng `CASE` ±1 ngày.

## Phát hiện

### Trung bình

**M1. Heartbeat giả lập hồi sinh mọi thiết bị demo OFFLINE, kể cả OFFLINE cố ý** — `src/java/service/LockerMonitor.java:207-226`
- Bằng chứng: bản cũ chỉ cập nhật `WHERE d.status = 'ACTIVE'`, nên thiết bị bị đặt OFFLINE giữ nguyên. Bản mới gọi `Device_Heartbeat` cho mọi thiết bị demo, mà thủ tục này đổi `OFFLINE -> ACTIVE`, đóng cảnh báo `DEVICE_OFFLINE` và ghi `BACK_ONLINE`.
  1. Seed `sql/02_data_v1.sql:309` cố ý đặt `LOCKER-07` OFFLINE kèm cảnh báo "Device Offline Alert" (dòng 650) làm ví dụ Case 1. Với DB mới, sau ~15 s chạy Tomcat ví dụ này biến mất: cảnh báo tự RESOLVED, dashboard "10/10".
  2. Nút "Đánh dấu mất kết nối" trên trang chi tiết cảnh báo (`web/WEB-INF/views/alert.jsp:71`) với thiết bị demo bị đảo ngược sau ≤15 s, nên người dùng/nhân viên thấy nút không có tác dụng.
- Đề xuất (chọn một): (a) chỉ hồi sinh thiết bị do `Device_MarkOffline` đánh dấu (ví dụ chỉ heartbeat khi `status = 'ACTIVE'`, hoặc `status = 'OFFLINE'` và hành động audit gần nhất là `MARK_OFFLINE`, không phải `DEVICE_STATUS` do nhân viên); hoặc (b) thêm cờ trong `OperatingProfile` (`"simulate_offline":true`) cho `LOCKER-07` và bỏ qua thiết bị đó, kèm việc `AlertController` set OFFLINE thủ công ghi cờ tương tự. Cập nhật dòng lesson mới trong CLAUDE.md cho khớp.

### Thấp

**L1. Phiên `AMBIGUOUS_SLOT` bị bỏ hẳn, thiết bị xoá buffer** — `src/java/api/LockerSessionApi.java:105-111`, `src/java/dao/LockerSessionDao.java:78-80`
- Trả 200 kèm `rejected`, nên firmware coi như đã gửi xong; dữ liệu cảm biến (có thể là bằng chứng FORCED_OPEN) chỉ còn trong log Tomcat. Hiện firmware, Postman và tài liệu đều chưa gửi `bank_code`, nên trên hộp có mã ngăn trùng thì mọi phiên RFID đều bị loại.
- Hiện DB live không có mã trùng (truy vấn `GROUP BY device_id, slot_code HAVING COUNT(*)>1` rỗng), `sql/demo_box.sql:30-33` đã chặn trùng; nhưng `LockerBankDao.insert/update` (dòng 135, 156) cho admin gán `device_id` vào dãy tủ mà không kiểm tra. Đề xuất: chặn trùng ở `LockerBankDao`/controller khi gán thiết bị (gốc rễ). Tuỳ chọn thêm: lưu phiên với `slot_id NULL` thay vì bỏ, để giữ lịch sử.

**L2. `bank_code` rỗng hoặc sai bị coi là "không tìm thấy ngăn"** — `src/java/dao/LockerSessionDao.java:40`
- `""` không là NULL nên `b.bank_code = ''` không khớp, phiên lưu với `slot_id NULL` và không báo lỗi. Đề xuất: chuẩn hoá chuỗi rỗng thành null trong `LockerSessionApi.parse`; `bank_code` không thuộc thiết bị thì đưa vào `errors` (ví dụ `UNKNOWN_BANK`).

**L3. (có từ trước, diff có sửa vào) `Deposit_Complete` đọc rồi sửa ngoài transaction, không `UPDLOCK, HOLDLOCK`** — `sql/02_data_v1.sql:1081-1086`
- Vi phạm lesson "check then change". Hai lời gọi đồng thời (PICKUP qua bàn phím + `RemoteCommand_TakePending`) có thể cùng đọc một booking ACTIVE; lời thứ hai ghi COMPLETE/audit lần nữa. Đề xuất: đưa `SELECT` vào sau `BEGIN TRAN` với `FROM Deposit d WITH (UPDLOCK, HOLDLOCK)` như `Deposit_CheckIn`. Khi áp lên DB chỉ chạy khối `CREATE OR ALTER` này (không chạy lại cả file).

**L4. (có từ trước) `Device_Heartbeat` đọc `@was` ngoài transaction** — `sql/02_data_v1.sql:824`
- Với thiết bị thật, nếu `Device_MarkOffline` chen giữa lúc đọc `@was` và `UPDATE`, thiết bị lên ACTIVE nhưng cảnh báo `DEVICE_OFFLINE` không được đóng. Heartbeat demo không bị (cùng luồng `LockerMonitor`). Đề xuất: đọc `@was` trong transaction bằng `WITH (UPDLOCK, HOLDLOCK)`, hoặc dùng `OUTPUT deleted.status`.

**L5. (có từ trước) Lệnh "dùng một lần" chưa nguyên tử** — `src/java/service/AlertService.java:38`, `src/java/dao/SessionContextDao.java:57-66`
- Kiểm tra `status='SENT'` và `markDone` là hai câu lệnh rời. Hai batch đồng thời mang cùng `command_id` có thể cùng được STAFF_OPEN. Javadoc mới ở `RuleEngine.java:16-20` nói "used once (markDone)", nên ghi rõ giới hạn này hoặc dùng `UPDATE ... WHERE status='SENT'` và lấy `@@ROWCOUNT` làm điều kiện hợp lệ.

### Thông tin

- I1. `SessionContextDao`: `DATEDIFF(SECOND, ...)` đếm ranh giới giây nên sai số ±1 s ở hai đầu cửa sổ; không đáng kể.
- I2. Tài liệu API/Postman (README, SYSTEM_FLOWS) chưa mô tả `bank_code` và mảng `errors`; để cho task README.
- I3. Trang chi tiết cảnh báo #50: cột "Mã thẻ" hiện ô `code` rỗng khi `card_uid` trống (có từ trước, không thuộc diff).
- I4. `ScenarioSender` gửi `measured_at` có mili-giây; `Timestamp.valueOf` đọc được, nên tương thích.

## Không thay đổi gì

Review chỉ đọc: không sửa code, không commit, chỉ chạy truy vấn SELECT trên DB, không đăng nhập bằng tài khoản newman, không đụng CANT-A/LIB-A.

## Vòng 2

Người review: code-reviewer-2 · Ngày: 30/10/2026 · Phạm vi: các sửa M1, L1–L5 của agent "fix-bugs-2" (`git diff`) và test mới `test/test/DeviceBankDatabaseIntegrationTest.java`.

### Kết luận: PASS

M1 và L1–L5 đều đã sửa đúng ý đồ, không thấy lỗi mới mức Trung bình trở lên. Còn 2 điểm Thấp và vài điểm thông tin, có thể sửa sau.

### Kiểm tra đã chạy

| Hạng mục | Kết quả |
|---|---|
| `sh scripts/test.sh` | 56 chạy, 56 đạt, 0 lỗi, 0 bỏ qua (3 test mới đều chạy, không bị skip) |
| `OBJECT_DEFINITION` trên DB live so với repo | Khớp (bỏ khoảng trắng, `CREATE`/`CREATE OR ALTER`): `Deposit_Complete`, `Device_Heartbeat` (02), `Deposit_CheckIn`, `RemoteCommand_TakePending`, `Device_Authorize` (bản cuối trong 03). Một dòng tiếng Việt trong `Device_Authorize` khác do sqlcmd in ra theo codepage console, không phải khác nội dung |
| Lớp đã deploy | `build/web/WEB-INF/classes` (23:25) mới hơn mã nguồn (23:24); có `slotCodeClash`, `MARK_OFFLINE` trong .class |
| DB (chỉ SELECT) | 9 thiết bị demo `ACTIVE`, `last_seen` ~15 s; `LOCKER-01` (thật) OFFLINE như mong đợi. AuditLog 768 dòng, chỉ có PK clustered |
| Trình duyệt (claude-in-chrome, admin) | Sửa dãy `DOMA-B` bấm Lưu không đổi gì: flash "Đã lưu dãy tủ DOMA-B". Sửa ngăn `B01` (id 41) bấm Lưu không đổi gì: về danh sách, không lỗi. Không cần hoàn tác (không đổi dữ liệu; chỉ thêm 2 dòng audit UPDATE). Danh sách + chi tiết cảnh báo #60 hiển thị đúng. `/api/locker-map`: CANT/DOMA/DOMB/GYM `offline=0`, LIB `offline=4` (LIB-A gắn LOCKER-01 thật). Không lỗi console |

### Đối chiếu từng sửa

- **M1 (đạt).** `LockerMonitor.heartbeatDemoDevices` (`src/java/service/LockerMonitor.java:211-234`) chỉ heartbeat thiết bị demo không OFFLINE, hoặc OFFLINE mà dòng audit trạng thái mới nhất là `MARK_OFFLINE`. Đã đối chiếu: `Device_MarkOffline` ghi `MARK_OFFLINE` (02:866), `Device_Heartbeat` ghi `BACK_ONLINE` (02:839), nhân viên ghi `DEVICE_STATUS` ở cả hai đường (`AlertController.java:102,139`); không có đường Java nào khác đổi `Device.status`. Thứ tự theo `audit_id DESC` (IDENTITY) là đúng, không phụ thuộc `ts`. Kịch bản: (a) seed LOCKER-07 OFFLINE không có audit → subquery NULL → giữ OFFLINE; (b) tự OFFLINE rồi nhân viên "Đánh dấu mất kết nối" → mới nhất là `DEVICE_STATUS` → giữ OFFLINE; (c) nhân viên OFFLINE rồi bật lại ACTIVE, sau đó máy ngủ → `MARK_OFFLINE` mới nhất → hồi sinh. `Device_MarkOffline` chỉ chạm hàng `ACTIVE` nên không ghi đè lựa chọn của nhân viên. Dùng chung một connection, try-with-resources đúng.
- **L1 (đạt).** `LockerBankDao.slotCodeClash` + `LockerBankController.validate:78`, `LockerSlotDao.codeExistsOnDevice` + `LockerSlotController.validate:115`. Thông báo tiếng Việt. Form gửi đúng tên tham số controller đọc (`id`, `bankCode`, `deviceId`, `bankId`, `slotCode`). Dãy không có thiết bị: JOIN với `device_id NULL` không khớp → không báo trùng (đúng). Dãy mới (id 0) chưa có ngăn → bỏ qua (đúng).
- **L2 (đạt).** `LockerSessionApi.parse` chuẩn hoá `""`/khoảng trắng thành null; `resolveSlot` trả `UNKNOWN_BANK` khi mã dãy không thuộc thiết bị, API đưa vào `errors`.
- **L3 (đạt).** `Deposit_Complete` (02:1080-1104) đọc trong `BEGIN TRAN` với `UPDLOCK, HOLDLOCK`; nhánh không có booking `COMMIT; RETURN`. Với caller có transaction riêng (`RemoteCommand_TakePending` 03:1469, `Device_Authorize` 03:1561, cả hai giữ `sp_getapplock`), `BEGIN TRAN` lồng chỉ tăng `@@TRANCOUNT` và `COMMIT` lồng chỉ giảm, khóa giữ đến COMMIT ngoài: không lỗi 266, không commit sớm. Test `completeWithoutABookingKeepsTheCallersTransaction` xác nhận `@@TRANCOUNT` = 1 sau lời gọi.
- **L4 (đạt).** `Device_Heartbeat` lấy trạng thái cũ bằng `OUTPUT deleted.status INTO @old` trong cùng câu `UPDATE` (hàng đã khóa), nên `Device_MarkOffline` chen giữa không còn để cảnh báo mở.
- **L5 (đạt).** `RemoteCommandDao.markDone` trả `executeUpdate() == 1` với `WHERE status = 'SENT'`. Thứ tự trong `AlertService.evaluate`: đọc context (lệnh SENT) → `RuleEngine` ra `STAFF_OPEN` → `markDone`; phiên thua cuộc đua đổi thành `SUSPECTED_SPOOF` rồi đi chung nhánh tạo cảnh báo + audit `CREATE ALERT` như cảnh báo luật khác; phiên đến sau khi lệnh đã DONE bị `SessionContextDao` (`status = 'SENT'`) loại ngay ở luật → cũng `SUSPECTED_SPOOF`. `COMMAND_DONE` chỉ ghi khi thắng.
- EXEC chỉ nhận biến/hằng: đạt (`@work_slot`, `@slot_id`). Tham số mới `@locker_slot_id INT = NULL` giữ lời gọi 2 đối số cũ.

### Phát hiện

#### Thấp

**R2-L1. Truy vấn M1 quét toàn bộ AuditLog mỗi 15 s cho mỗi thiết bị demo OFFLINE không có dòng audit trạng thái** — `src/java/service/LockerMonitor.java:212-217`
- Bằng chứng: `AuditLog` chỉ có PK clustered (`sys.indexes`). Subquery `TOP 1 ... WHERE object_type='DEVICE' AND object_id=? AND action IN (...) ORDER BY audit_id DESC` duyệt ngược PK đến khi gặp dòng khớp; với thiết bị không có dòng nào (như seed LOCKER-07 khi giữ OFFLINE) là quét hết bảng mỗi chu kỳ. Hiện 768 dòng nên không đáng kể, nhưng AuditLog tăng theo mỗi booking/lần mở.
- Đề xuất: thêm index `IX_AuditLog_object (object_type, object_id, audit_id DESC) INCLUDE (action)` (chỉ chạy khối CREATE INDEX trên DB live), hoặc chấp nhận và ghi chú.

**R2-L2. Javadoc cũ của `markDone` còn sót** — `src/java/dao/RemoteCommandDao.java:61`
- Dòng `/** A valid command is used once ... */` nằm ngay trên Javadoc mới (dòng 62-65), thành hai khối liền nhau; công cụ Javadoc chỉ lấy khối gần nhất. Đề xuất: xoá dòng 61.

#### Thông tin

- R2-I1. Cuộc đua hẹp ở M1: `DeviceDao.setStatus` commit rồi `AuditDao.append(DEVICE_STATUS)` chạy ở câu riêng. Nếu thiết bị demo đang ACTIVE nhưng dòng audit cuối là `MARK_OFFLINE` (được bật lại bằng đường không ghi audit như `sql/test_setup.sql:76`), heartbeat chạy đúng giữa hai câu có thể hồi sinh nó. Cửa sổ vài ms, chỉ với dữ liệu test; không cần sửa.
- R2-I2. Phiên thua cuộc đua ở L5 có `risk = null` (vì `STAFF_OPEN` là `noMl`), trong khi `SUSPECTED_SPOOF` từ luật có điểm ML. Trang cảnh báo hiện `–`; chấp nhận được.
- R2-I3. `slotCodeClash` chạy ở mọi lần lưu dãy có thiết bị; nếu DB đã có dữ liệu trùng từ trước thì không sửa được tên dãy cho đến khi gỡ thiết bị. Hiện không có mã trùng; thông báo đã giải thích lý do.
- R2-I4. Form dãy tủ chỉ liệt kê thiết bị chưa gắn dãy nào (`DeviceDao.listAvailableForBank`), nên qua UI không tạo được trùng; kiểm tra phía server vẫn cần cho request tự soạn và `demo_box.sql`.

### Không thay đổi gì

Chỉ đọc: không sửa code, không commit, chỉ SELECT trên DB. Hai lần bấm Lưu không đổi dữ liệu (chỉ thêm audit `UPDATE` cho LOCKERBANK 4 và slot 41).
