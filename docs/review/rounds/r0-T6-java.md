# Vòng 0 — T6 (ui-java): chữ tiếng Anh trong Java, SQL, test

Nguồn: `docs/review/teacher-feedback-2026-11-14.md`, Bảng 2 dòng 1. Thuật ngữ theo `docs/review/ui-glossary.md`
(tiền `12,000 VND`, ngày `dd/MM/yyyy HH:mm`, booking / slot / locker bank / box ...). Không commit.

## 1. Tệp đã sửa

**Java (`src/java`)** — mọi chuỗi người dùng thấy và mọi comment tiếng Việt đã chuyển sang tiếng Anh:

- `util/Web.java`: bảng `SQL_MESSAGES` (lỗi nghiệp vụ của procedure → câu hiển thị) nay là câu tiếng Anh; biến `vi` đổi thành `shown`.
- `service/AuthText.java`: chữ OLED (ASCII, ≤ 2 dòng × 16 ký tự, đã kiểm từng dòng) và chữ trang điện thoại `/k`;
  `vnd()` nay in `14,700 VND` (`String.format(Locale.US, "%,d VND", n)`).
- `service/MailTemplates.java`: tên mặc định `there` ("Hello there,"), giờ `dd/MM/yyyy HH:mm`, giá trị mẫu tiếng Anh
  (tên người/khu mẫu giữ nguyên vì là dữ liệu seed).
- `service/CardMail.java`: `action(phase)` trả đúng ba cụm từ glossary/T5 (xem mục 3).
- API: `DeviceAuthApi`, `DeviceEnrollApi`, `HealthApi`, `LockerSessionApi`, `KioskApi`, `MyLockerApi`, `filter/SecurityFilter`
  ("Bad request data", "Server error", "Wrong device key", lệnh mở từ xa `Open\n(phone)` / `Open\n(remote)`).
- Controller: Alert, Audit, Booking, Calibration, Deposit, Kiosk, LockerArea, LockerBank, LockerMap, LockerSession,
  LockerSlot, Login, Maintenance, MyCard, MyLocker, Register, RemoteCommand, Role, StoragePlan, Topup, UserCard, User
  (flash, lỗi kiểm tra form, `sendError`). Số tiền trong flash dùng `Locale.US` (`1,000 VND`).
- DAO: thông báo từ chối/xóa trong `DepositDao` (+ `customLabel` → `Custom · 3 h` / `Custom · 1 day` / `Custom · 2 days`),
  `CalibrationDao`, `LockerAreaDao`, `LockerBankDao`, `LockerSlotDao`, `StoragePlanDao`, `UserDao`; comment ở `LockerMapDao`,
  `LockerSessionDao`, `model/Deposit`, `model/LockerBank`, `service/LockerMonitor`, `util/Pricing`.
- `dao/RemoteCommandDao.java`: thêm `reasonText()` dịch 5 lý do do procedure tự ghi vào `RemoteCommand.reason`
  ("Mở bằng điện thoại" → "Opened with the phone", "Chạm điện thoại" → "Phone tap", "Quét thẻ, xác nhận qua email" →
  "Card scan, confirmed by e-mail", "Thay vân tay" → "Fingerprint replaced", "Xóa vân tay" → "Fingerprint deleted");
  lý do nhân viên tự gõ giữ nguyên. Dùng ở trang lịch sử lệnh (`search`).

**Mẫu email (`config/mail-templates/*.txt`, ngoài phạm vi ghi tên nhưng `MailTemplatesTest` đọc chúng)**: 11 mẫu + `_footer.txt`
dịch sang tiếng Anh, giữ CRLF và các `{{biến}}`/dòng `?`. Nút trong `card_confirm` khớp `cardConfirm.jsp` của T4
("Confirm opening", "It was not me"). `README.md` ở đó vẫn tiếng Việt (tài liệu), chỉ sửa hai câu về "there" và định dạng giờ/tiền.
Lưu ý: `booking_confirmed` và `reservation_expired` (không được gửi ở đâu) vẫn mô tả luật cũ trước v7.1 (hết giữ chỗ thì hủy);
tôi dịch đúng nghĩa, không sửa nội dung.

**Test (`test/test`)**: `AuthTextTest`, `CardMailTest`, `MailTemplatesTest` (đổi chuỗi mong đợi; `emptyNameBecomesBan` đổi tên
thành `emptyNameBecomesThere`), comment ở `LockerSessionListTest`, `PricingTest`, `PricingDatabaseIntegrationTest`. Không đổi logic.

## 2. SQL

- Mọi `THROW` của procedure (03/04/05) vốn đã là tiếng Anh; Java ánh xạ sang câu hiển thị ở `Web.sqlMessage`. Không sửa procedure nào.
- Lý do `RemoteCommand.reason` do procedure ghi: ánh xạ trong Java (mục 1), nên dòng cũ và mới đều hiện tiếng Anh, không phải viết lại
  các procedure lớn (Device_Authorize ...).
- Theo yêu cầu của orchestrator, dữ liệu đóng vai nhãn giao diện được đổi sang tiếng Anh:
  - `sql/03_v2_v3.sql`: khối "Storage plans" đảo chiều (đổi tên tiếng Việt cũ về `2 hours`, `4 hours`, `Day pass`, `Demo 2 minutes`);
    seed `SlotSize.items` dùng danh sách tiếng Anh. DB build mới (`build-order.txt`) có tiếng Anh ngay, không cần 06.
  - **Mới** `sql/06_english_messages.sql` (UTF-8 BOM, CRLF): cho DB đã có; trong một transaction, `UPDATE StoragePlan` (khớp tên tiếng Việt
    **và** `duration_min`) và `UPDATE SlotSize` (chỉ khi `items` đúng bằng chuỗi seed cũ). Không đụng procedure nên không phải chạy lại
    03/04/05; chạy lại an toàn. **Chưa chạy trên bất kỳ DB nào** (không chạy trên PRJ301_LOCKER). Không thêm vào `build-order.txt`
    (với DB mới nó không làm gì).
  - Tên khu/dãy/địa điểm và tên người dùng demo giữ nguyên.
- `sql/demo_box.sql`: 6 thông báo `THROW 509xx` dịch sang tiếng Anh (chỉ hiện trong sqlcmd). Comment tiếng Việt trong 03/04/
  `upgrade_main_2026-11.sql` dịch sang tiếng Anh. BOM giữ nguyên ở mọi tệp.
- Còn tiếng Việt trong sql/: dữ liệu seed (02, phần đổi tên khu/địa điểm/dãy trong 03, `AppConfig.note` không hiển thị ở đâu,
  tên người dùng kiểm thử trong `test_setup.sql`) và các lý do `RemoteCommand` trong procedure (đã dịch khi hiển thị).

## 3. Liên kết chữ với JS/JSP (chuỗi chính xác)

| Phía server | Phía web | Trạng thái |
|---|---|---|
| `CardMail.action`: CHECK_IN `store your things in the slot`, ACCESS `open the slot (the booking continues)`, PICKUP `pick up your things and check out (the booking ends)` | `web/js/locker-map.js` `CARD_ACTION` (dòng ~333); `cardConfirm.jsp` in sau "to" | Khớp |
| `DepositDao.customLabel`: `Custom · N h`, `Custom · 1 day`, `Custom · N days` | `locker-map.js` `'Custom · ' + durationText()` (`' h'`, `' day'`, `' days'`) | Khớp |
| `KioskApi`/`MyLockerApi` lỗi 500: `Server error, please try again.` | `web/js/kiosk.js:160` dự phòng cùng câu | Khớp |
| `Web.sqlMessage`: `The hold time is over, so the booking can no longer be cancelled.` | `locker-map.js:1016, 2145`, `user-pages.js:66` | Khớp (chỉ hiển thị, không so sánh) |
| `KioskApi` `message`, `LoginController`/`RegisterController` `error` (JSON) | hiển thị nguyên văn trong `kiosk.js`, `auth-modal.js` | Đã là tiếng Anh |
| `AuthText.phone` DEVICE_OFFLINE | `locker-map.js` có câu riêng cho DEVICE_OFFLINE | Không so sánh, chỉ nên cùng nghĩa |
| `SlotSize.items`, `StoragePlan.plan_name` | bảng giá/popup đặt ngăn trên bản đồ | Tiếng Anh sau 03 mới hoặc 06 |

Không có JS/JSP nào so sánh chuỗi flash hay `error` của server. `web/WEB-INF/web.xml` vẫn đặt `javax.servlet.jsp.jstl.fmt.locale = vi_VN`
— thuộc T4/T7; glossary yêu cầu `en_US`.

## 4. Kiểm thử

- Biên dịch 89 tệp `src/java` + test bằng JDK 8 (`C:/Program Files/Java/jdk1.8.0_202`, `-source 8 -target 8 -encoding UTF-8`),
  classpath Tomcat `servlet-api.jar`, `jsp-api.jar`, `web/WEB-INF/lib/*`, `lib/*`, ra thư mục scratchpad `t6-build` (không đụng `build/`).
- TestNG: RuleEngineTest, PricingTest, RiskScorerTest, SecurityUtilsTest, AuthTextTest, CardMailTest, MailTemplatesTest,
  LockerSessionListTest → **54/54 pass, 0 fail, 0 skip**.
- Không chạy test cần DB, không chạy SQL, không chạm Tomcat cổng 8080.

## 5. Còn lại / lưu ý

- **Firmware** (`firmware/SmartLocker_Online/*.ino`, không thuộc T6) vẫn có chữ OLED tiếng Việt không dấu của riêng nó: màn hình chờ
  `A: Mo tu  * huy / B: Tra tu`, `Mo tu ngan <slot>` (ghép với dòng 2 `(phone)`/`(remote)` từ server), `Ngan X OK`, `Da lay do`,
  `Quet the dang ky`, `Sai API key` ... Ý "firmware không có tiếng Việt" trong đề bài là chưa đúng. Câu do server gửi đã là tiếng Anh,
  nên OLED sẽ lẫn hai ngôn ngữ cho tới khi firmware được dịch (cần nạp lại ESP32).
- Tiếng Việt còn trong Java chỉ là dữ liệu: khóa của bảng ánh xạ trong `RemoteCommandDao` và tên người/khu mẫu trong
  `MailTemplates.sample` (seed).
- `docs/spec/*.md` còn nhắc `"Sai du lieu"`/chữ OLED cũ (tài liệu, không thuộc T6).
- `06_english_messages.sql` cần chạy trên DB thật (và Azure khi merge) bởi chủ dự án, sau khi thử trên một DB `SL_*`.

## Cách kiểm lại

```sh
B=<scratchpad>/t6-build; JDK="C:/Program Files/Java/jdk1.8.0_202/bin"; T=E:/apache-tomcat-9.0.113
CP="$T/lib/servlet-api.jar;$T/lib/jsp-api.jar;web/WEB-INF/lib/*;lib/*"
find src/java -name '*.java' > $B/s.txt && "$JDK/javac" -encoding UTF-8 -source 8 -target 8 -cp "$CP" -d $B/classes @$B/s.txt
"$JDK/javac" -encoding UTF-8 -source 8 -target 8 -cp "$B/classes;$CP" -d $B/test-classes test/support/*.java test/test/*.java
"$JDK/java" -cp "$B/test-classes;$B/classes;$CP" org.testng.TestNG -d $B/out -testclass test.AuthTextTest,test.CardMailTest,test.MailTemplatesTest,...
```

## Vòng 2 (theo `r1-UI-web.md` mục 1, 12 và `r1-UI-java.md` mục 1–12)

**Postman** (`docs/postman/SmartLocker-v2.postman_collection.json`, JSON hợp lệ, request không đổi): 19 assertion đổi sang đúng chữ
Java hiện trả về, mỗi chuỗi đã grep thấy trong `src/java`:
`'Put your things in slot'` (×3), `'Take your things from slot'`, `'tap link has expired'`, `eql('Scan the card')`, `eql('Enrolled')`,
`eql('Overdue\nTop up to open')`, `'overdue and locked'`, `'You owe ' + vnd(debt)`, `'Top up your wallet'`,
`'overdue and the locker is locked, so it cannot be extended'`, `'Extended by 90 min.'`, `vnd(charge) + ' was taken from your wallet.'`,
`'Money added to account ' + user`, `'Booking cancelled.'` (×2), `'The full-refund cancel time just ended'`,
`'After booking, at least 10,000 VND must stay in your wallet'`. Hàm `vnd` (×2) in `9,700 VND`. Tên test "Vietnamese message…" →
"English message…", "OK, Quet the" → "OK, Scan the card", "OK, Dang ky xong" → "OK, Enrolled". Không còn assertion tiếng Việt.
`scripts/proof/*` và các tệp `docs/postman` khác không kiểm chữ server. **Chưa chạy Newman** (cần Tomcat test riêng).

**Java**: `AuthText` — `1 try left` / `N tries left` (OLED và trang `/k`), CHOOSE `A: Open * cancel` (16 ký tự) / `B: Checkout <slot>`,
câu `/k` "Slot X is in your booking. …"; `AuthTextTest` và ví dụ trong `DeviceAuthApi` cập nhật theo. Nhật ký kiểm toán:
`UserController` "Granted 12,000 VND to …", `TopupDao` "Approved 50,000 VND for user …" (`Locale.US`, chỉ dòng mới).

**SQL**:
- `02_data_v1.sql`: câu seed hiện trên trang nhân viên đổi sang tiếng Anh (ghi chú nạp tiền, lý do 12 cảnh báo mẫu `AlertEvidence demo_case`,
  ghi chú phiếu bảo trì kể cả tiền tố phiếu cảm biến và 10 phiếu đã đóng, lý do lệnh mở từ xa "Emergency open from the admin desk, request N").
  Tên người/khu/dãy giữ nguyên.
- `03_v2_v3.sql`: khối đổi tên plan khớp cả `duration_min`; sửa comment B2 cũ; bỏ `REPLACE(note, 'Bank CANT-A', 'dãy CANT-A')`
  (lỗi tìm thấy khi thử: REPLACE không phân biệt hoa thường nên biến câu tiếng Anh thành "… of dãy CANT-A").
- `06_english_messages.sql`: thêm các `UPDATE` khớp đúng chuỗi cũ (TopupRequest.note, AlertEvidence, MaintenanceTicket.note — cả biến thể
  "dãy CANT-A" —, RemoteCommand.reason theo tiền tố + số, dùng `DATALENGTH` vì `LEN` bỏ dấu cách cuối). Vẫn một transaction, BOM, CRLF.
- **Đã thử trên DB riêng `SL_T6`** (build-db.ps1 + 06, rồi đưa dữ liệu về chuỗi cũ và chạy 06 hai lần): lần 1 đổi 4 plan, 1 SlotSize,
  55 ghi chú nạp tiền, 12 cảnh báo, 3+3+10 phiếu bảo trì, 8 lệnh từ xa; lần 2 đổi 0. Đã xóa `SL_T6`; PRJ301_LOCKER không bị đụng
  (build-db.ps1 xác nhận `create_date` không đổi).

**Mẫu email**: `due_soon` ("If your wallet balance is negative, top up first; then you can open the locker."), `topup_rejected`
("transfer note"), `overdue` (thêm "phone"); trả lại dòng trống cuối mọi mẫu; `README.md` ghi `booking_confirmed`/`reservation_expired`
không được gửi và còn luật trước v7.1 (nội dung giữ nguyên).

**Kiểm thử**: biên dịch lại 89 tệp ở JDK 8; 8 lớp test không cần DB: **54/54 pass**.
`web.xml` đã `en_US` (ghi chú vòng 0 đã cũ); firmware do agent khác xử lý.
