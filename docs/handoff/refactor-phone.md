# Handoff: v7, điện thoại thay thẻ từ (phase `rf-phone`)

## Mục tiêu
Chủ dự án đổi đầu đọc RC522 sang PN532 và bỏ hẳn thẻ từ: mở tủ bằng điện thoại (chạm NFC), bỏ cọc thẻ 10.000 đ.
"Bỏ giảm giá" chỉ là giảm giá của thẻ, đã bỏ từ v5; giảm giá nhiều ngày của gói Tự chọn **giữ nguyên**.
Làm trên nhánh `refactor/big` sau `rf-p1`, trước P2. Thư mục OneDrive, Tomcat 8080 và DB `PRJ301_LOCKER` không bị đụng.

## Cách hoạt động
- PN532 (I2C, chung bus với LCD) giả lập một thẻ NFC Type 4 chứa link `<base>/k/<mã hộp>?n=<mã chạm>`.
- Hộp gửi heartbeat `{"nfc":true}`; máy chủ (`Device_TapIssue`) trả `"tap_path"`. Mã 12 ký tự, đổi mỗi 60 giây và sau mỗi
  lần mở, dùng được 5 phút (bảng `DeviceTap`, tự xóa dòng quá 1 ngày).
- Điện thoại chạm hộp → trang `/k/...?n=` (GET không đổi gì, `Referrer-Policy: no-referrer`). Đã đăng nhập và có lượt đặt ở
  hộp đó thì có nút "Mở tủ của tôi" → `POST /api/kiosk/unlock {"method":"PHONE","tap":...,"intent":"ASK"}` (cần phiên,
  401 `NOT_SIGNED_IN` nếu không). `Device_Authorize` (tham số mới `@user_id`, `@tap`) kiểm tra mã, mở **mọi** lượt đặt của
  người đó ở hộp đó, xếp lệnh UNLOCK như trang điện thoại cũ, đánh dấu mã đã dùng (chỉ khi UNLOCK, CHOOSE thì không).
- `TAP_EXPIRED` không tính là đoán sai; lần chạm bỏ qua khóa 5 lần của ô mật mã. Nhật ký `AuthAttempt.method = 'TAP'`.
- Hộp demo (`"demo":true`) không có đầu đọc: không cần mã; cửa sổ "hộp còn sống" của nó là 30 giây (nhịp tim giả 15 giây/lần)
  và `LockerMonitor` nay **lấy lệnh đang chờ** của hộp demo (trước đây lệnh mở từ `/k` ở hộp demo nằm PENDING tới khi hết hạn).

## Đã làm
- **SQL** `sql/04_phone.sql` (BOM, CRLF, chạy lại được, đã chạy 3 lần trên `SL_PHONE`): hết hạn lệnh `AWAITING_EMAIL`, bỏ cột
  `RemoteCommand.confirm_hash`, bỏ `CardConfirm_*`, `UserCard_*`, đổi lượt `CARD` thành `PHONE`, CHECK mới (PIN, PHONE,
  FINGERPRINT), bỏ `Deposit.card_id` và bảng `UserCard`, bỏ `CARD_DEPOSIT` và quyền `USERCARD`/`MYCARD`; thêm `DeviceTap`,
  `Device_TapIssue`; viết lại `Auth_Log`, `Device_Authorize`, `Deposit_Reserve`, `Enroll_Finish`, `RemoteCommand_Expire`.
  `sql/build-order.txt` cho công cụ proof; `run_demo_db.ps1` chạy thêm 04.
- **Java**: xóa `CardConfirmController`, `MyCardController`, `UserCardController`, `UserCardDao`, `UserCard`, `CardMail`;
  `DeviceAuthDao` (`authorizeTap`, `tapToken`, `openBookingAt`, cờ `demo`), `KioskController`/`KioskApi` (chạm), `HealthApi`
  (`tap_path`, bỏ `blocked_cards`/`reserved`), `DeviceAuthApi`, `DeviceEnrollApi` (chỉ vân tay), `AuthText`, `RuleEngine`
  (bỏ `LOST_CARD_USED` và `WRONG_USER` theo chủ thẻ), `DepositDao`, `Pricing.canBook`, `Web.SQL_MESSAGES`, `SecurityFilter`,
  `LockerMapDao`/`Api`, `MyLockerApi`/`Controller`, `BookingController`, `LockerMonitor`.
- **UI**: `kiosk.jsp`/`kiosk.js` (khung "Mở tủ của tôi", CHOOSE dùng chung với mật mã, mã hết hạn thì bỏ nút), bản đồ
  (cách mở "Điện thoại", nút "Mở tủ bằng điện thoại", bỏ cọc thẻ và popup xác nhận thẻ), "Tủ của tôi" (bỏ mục thẻ), menu.
- **Firmware** `SmartLocker_Online.ino` 4.0-esp32: PN532 + `EmulateTag` của Seeed-Studio, `"nfc":true`, ghi lại thẻ khi
  `tap_path` hoặc base URL đổi, bỏ quét và đăng ký thẻ (phím B), giữ PIN, vân tay, A/B, servo. README firmware cập nhật.
- **Tài liệu**: README.md, README.en.md, SYSTEM_FLOWS.md, deploy.md, CLAUDE.md (bài học về thẻ viết lại, thêm bài học về mã
  chạm), Postman (kịch bản 3 thành chạm điện thoại, bỏ 8 và 9, thêm bước 400/401).
- **Test**: `PhoneTapDatabaseIntegrationTest` (4 test: mã dùng một lần và mã mới, không bị khóa mật mã chặn, người không có lượt
  đặt, hộp demo không cần mã). Xóa `CardMailTest` và 2 test thẻ của `RuleEngineTest`.

## Kết quả kiểm tra
| Kiểm tra | Kết quả |
|---|---|
| TestNG trên `SL_PHONE` (dựng từ script + `test_setup`) | 64/64, `Skips: 0` (cả trước và sau các sửa của review, DB dựng lại sạch) |
| Newman trên Tomcat test 8081 | 213 request, 454 assertion, 0 lỗi; sau các sửa của review: 214 request, 455 assertion, 0 lỗi (khớp `newman-baseline.txt`) |
| E2E trình duyệt, hộp demo LOCKER-05 | đặt "Điện thoại" → popup không còn cọc → "Mở tủ bằng điện thoại" → CHECK_IN; đăng nhập từ trang hộp quay lại đúng trang; CHOOSE → Mở tủ (ACCESS, hộp demo nhận lệnh sau 6 giây) → Trả tủ (PICKUP, COMPLETED) |
| E2E trình duyệt, LOCKER-01 (heartbeat bằng curl) | mã sai → `TAP_EXPIRED`, nút biến mất; mã thật → CHECK_IN; heartbeat nhận UNLOCK và mã mới; "Tủ của tôi" hiện cách mở Điện thoại |
| `PRJ301_LOCKER` | `create_date` không đổi trong suốt phiên |

## Review chéo
- **Vòng 1** (agent khác đọc toàn bộ diff) tìm 2 lỗi nặng, 3 lỗi vừa, vài lỗi nhỏ. Đã sửa hết:
  - bảng chữ của mã chạm có 55 ký tự trong `CHAR(56)` nên khoảng 1/6 mã chứa dấu cách → `VARCHAR` + `LEN(@abc)` (300 mã thử: 0 lỗi);
  - `UPDATE` CARD→PHONE chạy khi CHECK cũ còn (lỗi 547 trên DB có lượt CARD) → bỏ CHECK trước; các lệnh xóa (cột
    `confirm_hash`, `CardConfirm_*`, `UserCard`, `card_id`, `CARD_DEPOSIT`, quyền) dời xuống cuối file, sau các procedure mới;
  - `HealthApi`: lỗi khi cấp mã chạm sau `takePending` không còn trả 500 làm mất lệnh đã SENT;
  - firmware: UID của thẻ giả lập là `static` (EmulateTag giữ con trỏ), nghe NFC 40 ms thay 120 ms và không nghe khi đang gõ PIN;
  - so mã chạm phân biệt hoa thường (`COLLATE Latin1_General_BIN2`);
  - còn sót: `AWAITING_EMAIL` ở `status.tag` và bộ lọc lệnh, comment `kiosk.jsp`, README của proof; Postman thêm bước
    đăng xuất trước bước 401.
  - Không sửa (chấp nhận): một mã chạm dùng chung cho mọi người chạm trong 60 giây; mã nằm trong log truy cập.
- **Migration trên DB giống DB đang chạy**: dựng `SL_PHONE_MIG` từ `rf-baseline`, đặt 2 lượt đang mở thành CARD và 1 lệnh
  `AWAITING_EMAIL`, chạy `04_phone.sql` với `sqlcmd -b` hai lần: cả hai lần exit 0, 2 lượt thành PHONE, lệnh chờ email hết
  hạn, bảng và cột thẻ đã xóa.

- **Vòng 2** (agent khác kiểm lại từng chỗ sửa): **đạt**, 8/8 chỗ sửa đúng. Đã sửa thêm 3 điểm nhỏ nó nêu: bỏ chữ `o` khỏi
  bảng chữ của mã (đúng như comment), `LockerMonitor` coi hộp là demo theo dòng `OperatingProfile` mới nhất (cùng quy tắc với
  `Device_Authorize`, để hộp đã thành hộp thật không bị lấy lệnh), `HealthApi` bắt cả `RuntimeException` khi cấp mã.
  Sau đó: TestNG 64/64, 300 mã thử đều đúng bảng chữ, hộp demo vẫn báo sống, heartbeat vẫn trả `tap_path`.

## Việc còn mở
- **Khi `rf-phone` lên `main`, DB Azure đang chạy phải chạy `sql/04_phone.sql`** (một lần, `sqlcmd -I -b`; chạy lại được).
  Không chạy lại `03_v2_v3.sql` sau đó. `main` hiện ở `5eea9e6` (trang "Dữ liệu cảm biến" + `sql/upgrade_main_2026-11.sql`)
  và chưa có gì của `refactor/big`; phiên này không merge.
- Chạy `04_phone.sql` trên DB đang có người dùng: nên dừng app trước. Giữa lúc bỏ CHECK cũ và thêm CHECK mới, một
  `Deposit_Reserve` bản cũ còn chạy có thể chèn lượt CARD và lệnh thêm CHECK sẽ lỗi 547 (chạy lại script là qua).
- Lệnh của hộp demo (kể cả mở từ xa của nhân viên, `DELETE_FP`) nay ở trạng thái SENT mãi vì không có phiên nào xác nhận;
  trước đây chúng thành EXPIRED. Chỉ là hiển thị ở danh sách lệnh.
- **Firmware chưa biên dịch**: máy không có `arduino-cli`. Chủ dự án cần cài thư viện Seeed PN532 (README firmware), nạp và thử
  trên hộp thật, cả iPhone (thẻ giả lập bằng PN532 có máy iPhone không đọc nền) lẫn Android.
- **`PRJ301_LOCKER` đã bị dựng lại ngày 2026-11-07 08:09:43** (không phải trong phiên này): `scripts/proof/lib.ps1` đổi mốc
  ngày sang giá trị đó. Chủ dự án nên xác nhận đó là do mình làm.
- `firmware/SmartLocker_Local/SmartLocker_Local.ino` (bản thử phần cứng không mạng) vẫn dùng RC522: chưa đổi.
- Cột `LockerSession.card_uid` và các cột "Mã thẻ" của dashboard/cảnh báo là dữ liệu telemetry v1 của đề bài: giữ nguyên.
- Sau `04_phone.sql`, `03_v2_v3.sql` không chạy lại được (cần `UserCard`): P2 gộp file sẽ xử lý; README đã ghi.
- P2: proof so với tag `rf-phone`, không so với `rf-baseline` nữa.
- Kịch bản 9 cũ (METHOD_MISMATCH) đã bỏ cùng thẻ; chưa có bước Postman nào kiểm tra METHOD_MISMATCH.

## Trạng thái máy
- Đã dọn: Tomcat test 8081 (`test-stack.ps1 clean`), DB `SL_PHONE`, `SL_PHONE_MIG`. Còn worktree `C:\sl-wtaseline` (P2 cần).
- `PRJ301_LOCKER` vẫn `create_date` 2026-11-07 08:09:43; Tomcat 8080 và thư mục OneDrive không bị đụng.
- Commit trên `refactor/big`, tag `rf-phone`. Chưa push, chưa merge.

## File chính
`sql/04_phone.sql`, `sql/build-order.txt`, `src/java/dao/DeviceAuthDao.java`, `src/java/api/KioskApi.java`,
`src/java/controller/KioskController.java`, `src/java/api/HealthApi.java`, `src/java/service/LockerMonitor.java`,
`web/WEB-INF/views/kiosk.jsp`, `web/js/kiosk.js`, `web/js/locker-map.js`, `web/WEB-INF/views/myLocker.jsp`,
`firmware/SmartLocker_Online/SmartLocker_Online.ino`, `docs/postman/SmartLocker-v2.postman_collection.json`.

## Cách kiểm tra lại (PowerShell, đường dẫn tuyệt đối)
```
C:\sl-wt\refactor\scripts\proof\build-db.ps1 -Repo C:\sl-wt\refactor -Database SL_X -TestSetup
C:\sl-wt\refactor\scripts\proof\test-stack.ps1 start -Database SL_X -Build
C:\sl-wt\refactor\scripts\proof\newman.ps1 -Database SL_X
C:\sl-wt\refactor\scripts\proof\test-stack.ps1 clean
```
Git Bash: `DB_URL='jdbc:sqlserver://localhost:1433;databaseName=SL_X;encrypt=false' sh scripts/test.sh`. Xong thì xóa `SL_X`.
Lưu ý: `build-db.ps1 -Repo .` trong PowerShell đọc file theo thư mục hiện tại của .NET, không phải `Set-Location`: luôn
truyền đường dẫn tuyệt đối.
