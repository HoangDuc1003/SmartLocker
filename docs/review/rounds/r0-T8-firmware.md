# Vòng 0 - T8 (firmware): chữ trên màn hình hộp sang tiếng Anh

Ngày 14/11/2026. Phạm vi: `firmware/**` (sketch `SmartLocker_Online`, `SmartLocker_Local`, header, README của hộp).
Không commit gì. Không đổi logic, giao thức, trường JSON, đường dẫn API, chân, hằng thời gian hay hành vi.
Phiên bản firmware giữ `4.3-esp32`: không có chú thích nào yêu cầu tăng số khi chỉ đổi chữ.

## 1. Giới hạn màn hình

- `SmartLocker_Online`: **LCD 1602 I2C** (`LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2)`), font cố định của HD44780, **2 dòng x 16 ký tự**.
  Mọi chữ đi qua `show()` → `lcdLine()`: cắt còn 16 ký tự, đệm khoảng trắng, luôn ghi từ cột 0 (dòng 0 / dòng 1, `'\n'` tách dòng).
  Không có toạ độ x/y nào khác, nên không thể chồng chữ; chữ dài hơn 16 sẽ bị **cắt** (không tràn). Mục tiêu: mọi dòng <= 16.
- Không dùng OLED SSD1306 (128x64) trong firmware hiện tại; câu của máy chủ (`AuthText.oled*`) cũng theo giới hạn 2 x 16.
- `SmartLocker_Local`: không có màn hình, chỉ Serial (không giới hạn độ dài).
- Không có bộ đệm `char[]` nào chứa chữ hiển thị: các câu là `F("...")` hoặc `String`; bộ đệm `char b[3]` (hex UID) và `ndefBuf[128]` (URL thẻ NFC) không đổi.

## 2. `SmartLocker_Online.ino`: chữ trên LCD (trước → sau, độ dài từng dòng)

| Chỗ | Trước | Sau | Độ dài |
|---|---|---|---|
| `drawIdle` nhập mã đăng ký thẻ / vân tay | `Ma DK the:` / `Ma DK van tay:` | `Enroll card:` / `Enroll finger:` | 12 / 14 |
| `drawIdle` chờ quẹt thẻ đăng ký | `Quet the dang ky` / `(* de huy)` | `Scan your card` / `(* to cancel)` | 14 / 13 |
| `drawIdle` CHOOSE | `A: Mo tu  * huy` / `B: Tra tu A01` | `A: Open  * quit` / `B: Checkout A01` (giống `AuthText` của máy chủ) | 15 / 15 (mã ngăn 3 ký tự; 4 ký tự vẫn = 16) |
| `drawIdle` đang gõ PIN, dòng 2 | `# gui  * xoa` | `# send  * clear` | 15 |
| `drawIdle` mất máy chủ | `Mat ket noi` / `Dang thu lai...` | `Offline` / `Retrying...` | 7 / 11 |
| `drawIdle` mất Wi-Fi | `Mat Wi-Fi` / `Dang noi lai...` | `No Wi-Fi` / `Reconnecting...` | 8 / 15 |
| `drawIdle` màn chờ | `PIN + # / van tay` (17, bị cắt thành `...van ta`) / `the / cham NFC` | `PIN + # / finger` / `card / phone tap` | 16 / 16 (sửa luôn lỗi bị cắt) |
| `nfcSlice` điện thoại đã đọc thẻ NFC | `Da gui lien ket` / `Xem dien thoai` | `Link sent` / `Check your phone` | 9 / 16 |
| `showSlotOk` ngăn không có servo | `Ngan A01 OK` | `Slot A01 OK` | 11 |
| `showSlotOk` dòng 2 theo phase (PICKUP / ACCESS / CHECK_IN) | `Da lay do` / `Da mo tu` / `Da gui do` | `Picked up` / `Opened` / `Stored` | 9 / 6 / 6 |
| `closeDoor` | `Da khoa cua` | `Door locked` | 11 |
| `doorTick` có người ở cửa | `Bam D de khoa` / `Co nguoi, cho...` | `Press D to lock` / `Someone near...` | 15 / 15 |
| `doorTick` đếm ngược | `Bam D de khoa` / `Tu khoa sau 20s` | `Press D to lock` / `Locks in 20s` | 15 / tối đa 13 (`Locks in 120s`) |
| `connectWifi` | `Noi Wi-Fi...` | `Joining Wi-Fi...` | 16 |
| `runCommands` UNLOCK mặc định khi thiếu `message` | `Mo tu` | `Open` (máy chủ gửi `Open\n(phone)` / `Open\n(remote)`, `HealthApi`) | 4 |
| `runCommands` UNLOCK dòng 1 | `Mo tu ngan A01` | `Open slot A01` | 13 |
| `runCommands` CANCEL_ENROLL | `Da huy dang ky` | `Enroll cancelled` | 16 |
| `showServerError` 401 | `Sai API key` / `(xem secrets.h)` | `Wrong API key` / `(see secrets.h)` | 13 / 15 |
| `showServerError` không kết nối | `Khong goi duoc` / `may chu` | `Cannot reach` / `the server` | 12 / 10 |
| `showServerError` HTTP khác | `Loi may chu` / `HTTP 500` | `Server error` / `HTTP 500` | 12 / 8 |
| `authorize` | `Dang kiem tra...` | `Checking...` | 11 |
| `enrollCall` mặc định khi thiếu `message` | `Loi dang ky` | `Enroll failed` (giống máy chủ) | 13 |
| `captureFinger` lần 1 | `Dat ngon tay` / `len cam bien` | `Place finger` / `on the sensor` | 12 / 13 |
| `captureFinger` lần 2 | `Dat lai` / `cung ngon tay` | `Place the same` / `finger again` | 14 / 12 |
| `captureFinger` nhấc tay | `Nhac ngon tay ra` | `Lift your finger` | 16 |
| `startEnroll` | `Kiem tra ma...` | `Checking code...` | 16 |
| `startEnroll` không có AS608 | `Khong thay AS608` | `AS608 not found` | 15 |
| `startEnroll` lấy mẫu lỗi | `Lay van tay loi` / `Bam C lam lai` | `Finger failed` / `Press C to retry` | 13 / 16 |
| `startEnroll`, `finishCardEnroll` mặc định | `Dang ky xong` | `Enrolled` (giống máy chủ) | 8 |
| phím `*` (2 chỗ) | `Da huy` | `Cancelled` | 9 |
| phím `D`, dòng 2 | `May chu OK` | `Server OK` (dòng 1 là IP, tối đa 15) | 9 |
| phím `#` thiếu số | `Can du 6 so` | `Need 6 digits` | 13 |
| vân tay đọc lỗi | `Khong doc duoc` / `van tay, thu lai` | `Finger not read` / `Try again` | 15 / 9 |
| vân tay không có trong cảm biến | `Van tay chua` / `dang ky` | `Fingerprint not` / `enrolled` | 15 / 8 |
| `setup` | `SmartLocker` / `Khoi dong...` | `SmartLocker` / `Starting...` | 11 / 11 |
| hết giờ quẹt thẻ đăng ký | `Het thoi gian` / `quet the` | `Card scan` / `timed out` | 9 / 9 |
| hết giờ chọn A/B | `Het thoi gian` / `chon, da huy` | `Choice timed out` / `Cancelled` | 16 / 9 |

Mọi dòng mới <= 16 ký tự (đã đo bằng script). Kiểu biểu thức giữ nguyên: câu cố định vẫn `F("...")` (cả hai nhánh của
`?:` đều là `F()`), câu ghép với biến vẫn là `String` như cũ, giá trị mặc định của ArduinoJson (`| "..."`) vẫn là chuỗi C.

Chú thích tiếng Việt không dấu trong code đã đổi: `"Mo tu cua toi"` → `"Open my locker"`, `"Tu cua toi"` → `"My locker"`,
`("A: Mo tu / B: Tra tu")` → `("A: Open / B: Checkout")` (2 chỗ), `"Ngan B08 OK"` → `"Slot B08 OK"`,
`"mat ket noi"` → `"Offline"`, `"Mo tu\n(dien thoai)"` → `"Open\n(phone)"`. Các chú thích khác vốn đã bằng tiếng Anh.
Thông báo Serial của sketch này vốn đã bằng tiếng Anh; dòng `[LCD] ...` in lại chữ trên LCD nên tự đổi theo.

## 3. `SmartLocker_Local.ino`: Serial Monitor (không giới hạn độ dài)

| Trước | Sau |
|---|---|
| `===== TU CHOI =====` | `====== DENIED =====` (giữ 19 ký tự cho khớp dòng `=` bên dưới) |
| `Phuong thuc: ` (2 chỗ) | `Method: ` |
| `Ma/ID: ` (2 chỗ) | `Code/ID: ` |
| `PIN da xoa.` | `PIN cleared.` |
| `Nhap PIN truoc, sau do bam #.` | `Enter the PIN first, then press #.` |
| `Van tay: khong doc duoc anh, thu lai.` | `Fingerprint: could not read the image, try again.` |
| `Do khop: ` | `Confidence: ` |
| `khong co mau da dang ky` | `no enrolled template matches` |
| `Loi khi tim mau van tay.` | `Fingerprint search error.` |
| `PIN demo: 1234, nhap tren keypad va bam #; bam * de xoa.` | `Demo PIN: 1234, type it on the keypad and press #; press * to clear.` |
| `Quet the de xem UID; sua ALLOWED_CARD_UIDS de cho phep the.` | `Scan a card to see its UID; edit ALLOWED_CARD_UIDS to allow it.` |
| `RC522 da khoi tao.` | `RC522 ready.` |
| `Cam bien van tay da ket noi.` | `Fingerprint sensor connected.` |
| `So mau van tay da luu trong cam bien: ` | `Fingerprint templates stored in the sensor: ` |
| `Khong thay cam bien van tay. Kiem tra nguon, TX/RX va baud.` | `Fingerprint sensor not found. Check power, TX/RX and baud.` |
| `San sang. Mo Serial Monitor 9600 baud.` | `Ready. Open the Serial Monitor at 9600 baud.` |

Giá trị phương thức (`KEYPAD/PIN`, `RFID`, `FINGERPRINT`) và `CHECK-IN LOCAL: OK` giữ nguyên (mã kỹ thuật).

## 4. Header và README

- `secrets.example.h`, `secrets.h`: chú thích vốn đã bằng tiếng Anh, không sửa (`secrets.h` nằm trong `.gitignore`).
- `firmware/SmartLocker_Online/README.md`: giữ văn bản tiếng Việt (tài liệu nộp), chỉ đổi các câu LCD và nhãn giao diện
  được trích sang chữ tiếng Anh mới: `Link sent`, `A: Open` / `B: Checkout`, `A: Open  * quit` / `B: Checkout A01`,
  `Someone near...`, `Locks in ..s`, `Store your items / Slot A01`, `Open the door`, `Take your items`,
  `Open slot A01 / (phone)`, `Open slot A01 / (remote)`, `Enrolled`, `No Wi-Fi`, `Wrong PIN / Locked 2 min`,
  `Locked / Wait .. s`, `Cannot reach / the server`, `Wrong API key`, `Fingerprint not / enrolled`; nút web
  "Open my locker", "Open" / "Check out", trang "My locker". Câu "do máy chủ viết (không dấu)" sửa thành
  "(tiếng Anh, ASCII, tối đa 2 dòng 16 ký tự)" và thêm một dòng liệt kê các câu firmware tự hiện.

## 5. Biên dịch

Dùng `arduino-cli` đi kèm Arduino IDE (`...\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe`, cấu hình
`~/.arduinoIDE/arduino-cli.yaml`, thư viện ở `C:\ArduinoSketchbook\libraries`), core `esp32:esp32` 3.3.12, board
`esp32:esp32:esp32` (ESP32 Dev Module), thư mục build nằm trong scratchpad (không tạo file trong repo):

| Sketch | Kết quả |
|---|---|
| `SmartLocker_Online` | OK (exit 0). Flash 1,091,563 byte (83%), RAM toàn cục 52,036 byte (15%). Chỉ có cảnh báo cũ của thư viện `LiquidCrystal_I2C` (khai "mọi kiến trúc"). |
| `SmartLocker_Local` | OK (exit 0). Flash 285,192 byte (21%), RAM toàn cục 22,676 byte (6%). |

Lưu ý: `SmartLocker_Online` biên dịch với `secrets.h` có sẵn trên máy (bị gitignore); máy khác cần chép `secrets.example.h` trước.

## 6. Còn lại

- Chưa nạp lên hộp thật để nhìn LCD (không có phần cứng trong phiên này); độ dài đã kiểm bằng script và đối chiếu `lcdLine()`.
- `SmartLocker_Local.ino` lưu xuống dòng LF (như trước); git báo sẽ đổi sang CRLF khi chạm vào file, không ảnh hưởng biên dịch.
- Ngoài `firmware/` còn trích câu LCD cũ (không dấu) ở `docs/spec/smart-locker-v2.md` (tài liệu đặc tả cũ); không thuộc
  phạm vi T8, để task tài liệu quyết định. README gốc, `SYSTEM_FLOWS` và bài báo không còn chứa các câu LCD cũ đã tìm.
