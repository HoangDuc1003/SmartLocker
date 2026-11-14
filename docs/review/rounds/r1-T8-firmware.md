# Vòng 1 - Đánh giá chéo T8 (firmware sang tiếng Anh)

Ngày 15/11/2026. Phạm vi: `git diff -- firmware/` (`SmartLocker_Online.ino`, `SmartLocker_Local.ino`, `SmartLocker_Online/README.md`). Chỉ đọc, không sửa file repo.

## Cách kiểm

1. So dòng token (bỏ chú thích, thay mọi chuỗi bằng `"S"`) giữa `HEAD` và bản làm việc bằng script Python: Online 5441 = 5441 token, Local 1196 = 1196 token, **giống hệt** → không đổi logic, khóa JSON, đường dẫn, chân, thời gian, `F()`, luồng điều khiển (chuỗi trong code gồm cả khóa JSON/đường dẫn cũng đã so là cùng vị trí; chỉ nội dung chuỗi khác).
2. Liệt kê mọi chuỗi và đo từng dòng (tách `\n`): các chuỗi > 16 ký tự đều là Serial/`#error` (không lên LCD). Chuỗi ghép: `"Slot " + mã + " OK"` (tối đa 16 khi mã 5 ký tự), `"Open slot " + mã` (13 với mã 3 ký tự), `"Locks in 120s"` 13, `"B: Checkout " + mã` = 12 + mã (16 khi mã 4 ký tự), IP `192.168.100.100` 15, `"HTTP " + mã` ngắn. Mọi dòng <= 16 với mã ngăn 3-4 ký tự (A01, B07).
3. Đối chiếu `AuthText.java`, `HealthApi.java`, `docs/review/ui-glossary.md`.
4. Tìm ký tự không ASCII và từ tiếng Việt không dấu trong `*.ino`, `*.h`: không còn (cả chuỗi và chú thích).
5. Đối chiếu các câu trích trong README với code.
6. Biên dịch: `arduino-cli` có (Arduino IDE), core `esp32:esp32 3.3.12`. Cả hai sketch **không biên dịch được trong môi trường này** vì thiếu thư viện (`ArduinoJson.h`, `MFRC522.h` "No such file", dù `lib list` có ghi; thư mục thư viện nằm trong `OneDrive\Tài liệu\Arduino\libraries`, đường dẫn có dấu / OneDrive). Đây là lỗi môi trường, không liên quan phần đổi (token đã bằng nhau). Chưa xác nhận bằng build thật; nên nạp thử trên máy có thư viện đầy đủ.

## Bảng lỗi

| STT | Vị trí | Lỗi | Mức độ | Đề nghị sửa (exact text) |
|---|---|---|---|---|
| 1 | `SmartLocker_Online.ino` `showSlotOk` dòng 2 và nhánh `UNLOCK` (`"Picked up"` / `"Opened"` / `"Stored"`) | Khác câu của máy chủ cho cùng phase: server (`AuthText`) dòng 1 là `Take your items` / `Open the door` / `Store your items`, dòng 2 `Slot <mã>`; ngăn không servo của firmware hiện `Slot A01 OK` / `Picked up`. Chỉ là màn hình riêng của ngăn demo không servo, ý nghĩa khớp | Thấp | Giữ nguyên (chấp nhận được); nếu muốn thống nhất: `"Slot " + mã + " OK\n"` + `"Take items"` / `"Door opened"` / `"Store items"` |
| 2 | `.ino` dòng 174 `MODE_ENROLL_CARD`: `Scan your card` | Server dùng `Scan the card` cho cùng bước đăng ký thẻ (`AuthText.enroll`) | Thấp | `F("Scan the card\n(* to cancel)")` (14 / 13 ký tự) |
| 3 | `.ino` dòng 175: `B: Checkout ` + mã ngăn | Mã ngăn 5 ký tự trở lên bị `lcdLine` cắt (12 + 5 = 17). Mã seed là 3 ký tự nên chưa xảy ra; server cũng cùng giới hạn | Thấp | Không cần sửa; ghi chú trong README nếu đổi định dạng mã |
| 4 | `README.md` dòng 82, 111 và chú thích `.ino` dòng 18, 542: `A: Open / B: Checkout` | Rút gọn, màn thật là `A: Open * cancel` / `B: Checkout <slot>` (README dòng 86 đã đúng) | Thấp | Thay bằng `A: Open * cancel` / `B: Checkout A01` ở README dòng 82 và 111 |
| 5 | Nhất quán thuật ngữ | LCD dùng `Checkout` một từ, glossary/web dùng `Check out` (hai từ): đã được glossary dòng 216 ghi nhận là ngoại lệ LCD (16 ký tự). Không phải lỗi | Thông tin | Không sửa |

Ghi chú: ban đầu `.ino` dòng 175 là `A: Open  * quit` (17 ký tự khi có hai khoảng trắng, "quit" lệch "cancel" của server); orchestrator đã sửa thành `A: Open * cancel\nB: Checkout ` (16 / 12 + mã), khớp `AuthText` và glossary. Tôi đã kiểm bản mới: khớp. `Wrong PIN`, `Locked 2 min`, `Enrolled`, `Enroll failed`, `Open\n(phone)`/`Open\n(remote)` khớp server. README: `Cannot reach / the server`, `Wrong API key`, `Link sent / Check your phone`, `Fingerprint not / enrolled`, `Locks in ..s`, `Someone near...`, `Open slot A01 / (phone)`/`(remote)`, `No Wi-Fi`, `Enrolled` khớp code. README còn tiếng Việt là chủ đích (tài liệu nộp bằng tiếng Việt).

KẾT LUẬN: ĐẠT
