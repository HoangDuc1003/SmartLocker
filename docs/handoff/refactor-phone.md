# Handoff: v7, thẻ từ và chạm điện thoại trên một PN532 (tag `rf-phone-card`)

## Mục tiêu
Chủ dự án đổi đầu đọc RC522 sang PN532. Quyết định cuối: hộp mở được bằng **cả điện thoại lẫn thẻ từ** ("cả 2 vừa đọc bằng điện
thoại vừa đọc thẻ được"), và **không còn cọc thẻ 10.000 đ**. "Bỏ giảm giá" chỉ là giảm giá của thẻ, đã bỏ từ v5; giảm giá nhiều
ngày của gói Tự chọn giữ nguyên.

Hai mốc trên nhánh `refactor/big`, sau `rf-p1`, trước P2:
- `rf-phone`: bản chỉ có điện thoại (đã bỏ thẻ). **Không dùng làm gốc nữa**, giữ để tham khảo.
- `rf-phone-card`: bản cuối, thẻ và điện thoại song song. P2 so proof với tag này.

## Cách hoạt động
- **Thẻ:** như `rf-p1` (đăng ký tại hộp bằng phím B và mã 6 số, báo mất, đổi thẻ, `blocked_cards`, xác nhận qua email `/c/{token}`
  hoặc trên bản đồ, `LOST_CARD_USED`, `WRONG_USER`), trừ cọc. Thẻ được coi là đã đăng ký khi có `registered_device_id`.
- **Điện thoại:** PN532 giả lập thẻ NFC Type 4 chứa `<base>/k/<mã hộp>?n=<mã chạm>`. Hộp gửi heartbeat `{"nfc":true}`, máy chủ
  (`Device_TapIssue`) trả `tap_path`. Mã 12 ký tự, đổi mỗi 60 giây và sau mỗi lần mở, dùng được 5 phút (`DeviceTap`). Trang `/k` có
  nút "Mở tủ của tôi" cho chủ lượt đặt đã đăng nhập → `POST /api/kiosk/unlock {"method":"PHONE","tap":...}`. Mở được mọi lượt đặt
  của người đó ở hộp đó (cả lượt đặt bằng thẻ, mật mã, vân tay). Thẻ thì không mở lượt đặt của cách khác (`METHOD_MISMATCH`).
- `TAP_EXPIRED` không tính là đoán sai; lần chạm bỏ qua khóa 5 lần của ô mật mã. `AuthAttempt.method = 'TAP'`.
- Hộp demo (`"demo":true`) không cần mã; cửa sổ "hộp còn sống" 30 giây; `LockerMonitor` lấy lệnh đang chờ của hộp demo.
- **Firmware 4.1:** một đối tượng PN532 hai vai, mỗi `loop()` một lát: đọc thẻ (`readPassiveTargetID`, 30 ms) hoặc giả lập (`emulate`,
  40 ms), đổi vai bằng `SAMConfig`. Không giả lập khi đang gõ PIN hoặc đăng ký thẻ. UID 4 byte bắt đầu `0x08` (ví HCE của điện thoại)
  bị bỏ qua trước mọi xử lý, nếu không lần chạm sẽ tính là `UNKNOWN_CARD`. Bản ghi NDEF tự đóng gói, không cần thư viện NDEF.

## Đã làm so với `rf-phone`
- `sql/04_phone.sql` sửa tại chỗ (chưa DB thật nào chạy): CHECK có đủ PIN, CARD, PHONE, FINGERPRINT; `Device_Authorize` gộp nhánh thẻ,
  email và điện thoại (tham số `@user_id`, `@tap` ở cuối); `Deposit_Reserve`, `Enroll_Finish` có thẻ, không cọc; chỉ còn xóa `CARD_DEPOSIT`.
- Khôi phục từ `rf-p1`: `CardConfirmController`, `MyCardController`, `UserCardController`, `UserCardDao`, `UserCard`, `CardMail`,
  `userCard.jsp`, `cardConfirm.jsp`, 2 mẫu email, luật `RuleEngine`, kịch bản `lostcard`, menu, popup xác nhận trên bản đồ, kịch bản Postman 3, 8, 9.
- Bỏ cọc ở: `Pricing`, JSON (`card_deposit*`), form đặt, "Tủ của tôi" (cột Tiền cọc), `Enroll_Finish`, `Deposit_Reserve`, `Web.SQL_MESSAGES` (50041).
- Thêm test `aCardEnrollsWithoutADepositAndOpens`, Postman kịch bản 19 (chạm điện thoại).

## Phụ thuộc vào `deposit_amount`
Cột `UserCard.deposit_amount` vẫn còn (do `03_v2_v3.sql` tạo), luôn là 0 với thẻ đăng ký mới và **không còn code nào đọc**. Thẻ đã
đăng ký trước đây vẫn tính vì `Enroll_Finish` cũ luôn ghi `registered_device_id`. `03_v2_v3.sql` vẫn chứa `CARD_DEPOSIT` và các
procedure cũ, được `04_phone.sql` thay; P2 gộp file sẽ bỏ hẳn.

## Kết quả kiểm tra
| Kiểm tra | Kết quả |
|---|---|
| TestNG, DB `SL_*` dựng sạch từ script + `test_setup` | 71/71, `Skips: 0` |
| Newman, Tomcat test 8081 | 241 request, 515 assertion, 0 lỗi |
| Biên dịch firmware 4.1 (`arduino-cli`, esp32 3.3.12, `PN532-Arduino` 1.1.0, build ngoài repo) | Đạt, 83% flash |
| E2E trình duyệt + giả lập hộp bằng curl | Bốn cách mở hiện đủ trên form đặt; đặt thẻ không cọc, đăng ký thẻ, quẹt thẻ CHECK_IN rồi CHOOSE, ví không bị trừ thêm; popup "Xác nhận mở tủ" trên bản đồ; chạm điện thoại mở lượt đặt bằng thẻ, CHOOSE → Trả tủ; mã đã dùng; mật mã trên trang `/k`; đăng ký và mở bằng vân tay; trang thẻ của nhân viên |
| `PRJ301_LOCKER` | `create_date` không đổi |

## Việc còn mở
- **Khi `rf-phone-card` lên `main`, DB Azure phải chạy `sql/04_phone.sql`** (một lần, `sqlcmd -I -b`; chạy lại được), nên dừng app trước. `main` hiện ở `5eea9e6` (trang "Dữ liệu cảm biến" + `sql/upgrade_main_2026-11.sql`), chưa có gì của `refactor/big`; phiên này không merge.
- **Firmware đã biên dịch nhưng chưa thử trên phần cứng.** Cần thử trên hộp thật: đổi vai giữa đọc thẻ và giả lập, quẹt thẻ, chạm Android, chạm iPhone (thẻ giả lập bằng PN532 có máy không đọc nền; khi đó dùng QR), và điện thoại có ví HCE.
- Xác nhận qua email cần cấu hình mail; E2E kiểm tra popup trên bản đồ bằng lệnh `AWAITING_EMAIL` tạo tay, chưa gửi thư thật.
- Nếu chạy lại `03_v2_v3.sql` thì phải chạy lại `04_phone.sql`.
- **`PRJ301_LOCKER` đã bị dựng lại ngày 2026-11-07 08:09:43** (không do các phiên này): `scripts/proof/lib.ps1` đổi mốc ngày.
- `firmware/SmartLocker_Local/SmartLocker_Local.ino` (bản thử phần cứng không mạng) vẫn dùng RC522.
- Lệnh của hộp demo nay ở trạng thái SENT mãi vì không có phiên nào xác nhận; chỉ là hiển thị.

## Cách kiểm tra lại (PowerShell, đường dẫn tuyệt đối)
```
C:\sl-wt\refactor\scripts\proof\build-db.ps1 -Repo C:\sl-wt\refactor -Database SL_X -TestSetup
C:\sl-wt\refactor\scripts\proof\test-stack.ps1 start -Database SL_X -Build
C:\sl-wt\refactor\scripts\proof\newman.ps1 -Database SL_X
C:\sl-wt\refactor\scripts\proof\test-stack.ps1 clean
```
Git Bash: `DB_URL='jdbc:sqlserver://localhost:1433;databaseName=SL_X;encrypt=false' sh scripts/test.sh`. Xong thì xóa `SL_X`.
`build-db.ps1 -Repo .` đọc file theo thư mục hiện tại của .NET: luôn truyền đường dẫn tuyệt đối.
