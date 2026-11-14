# Vòng 2 – Rà lại bản dịch giao diện tiếng Anh (web/ và chỗ nối với src/java)

Người rà: agent r1-UI-web (vòng 2). Chỉ đọc, không sửa tệp nào của repo (trừ báo cáo này). Không đụng Tomcat 8080.

## Kiểm lại các lỗi của `r1-UI-web.md`

| STT vòng 1 | Vị trí | Kết quả |
|---|---|---|
| 1 (cao) | `docs/postman/SmartLocker-v2.postman_collection.json` | **Đã sửa.** JSON hợp lệ. Không còn assertion nào có chữ tiếng Việt (chữ tiếng Việt còn lại chỉ ở tên/mô tả request). `vnd = n => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',') + ' VND'` cho `9,700 VND`, giống `AuthText.vnd` (`String.format(Locale.US, "%,d VND", n)`). Từng chuỗi được kiểm đều có nguyên văn trong chữ Java trả về: `Put your things in slot` / `Take your things from slot` / `tap link has expired` / `overdue and locked` / `You owe ` + vnd / `Top up your wallet` (`AuthText.phone`, qua `KioskApi:68`); `eql('Scan the card')`, `eql('Enrolled')` (`AuthText.enroll:150-152`); `eql('Overdue\nTop up to open')` (`AuthText.oled:78`); `Extended by 90 min.` và vnd + ` was taken from your wallet.` (`BookingController:67-69`); `Money added to account ` + user (`TopupController:122`); `Booking cancelled.` (`BookingController:59`); `overdue and the locker is locked, so it cannot be extended`, `The full-refund cancel time just ended`, `After booking, at least 10,000 VND must stay in your wallet` (`Web.SQL_MESSAGES`, khóa khớp đúng chữ `THROW 50048/50052/50046` trong `sql/03_v2_v3.sql`, `sqlMessage` so khớp nguyên chuỗi). Chưa chạy Newman (cần Tomcat và DB `SL_*` riêng). |
| 2 (trung bình) | `kiosk.jsp:89` | Đã sửa: "…each time you open the locker, choose Open (take or add items) or Check out (end the booking)." |
| 3 | `myLocker.jsp:311` | Đã sửa: "choose RFID card". |
| 4 | `myLocker.jsp:77, 90, 221` | Đã sửa: "slot". |
| 5 | `myLocker.jsp:126` | Đã sửa bằng `c:choose`: "1 time" / "N times". JspC biên dịch được. |
| 6 | `locker-map.js:379, 384` | Đã sửa: "Confirm opening". |
| 7 | `locker-map.js:846` | Đã sửa: "The Day pass plan costs the same and lasts 24 h." |
| 8 | `locker-map.js:622` | Đã sửa: "Connection lost, retrying". |
| 9 | `auth-modal.js:45-46` | Đã sửa: "E-mail", "reminder e-mail". |
| 10 | `remoteCommand.jsp:43`, `locker-map-staff.js:557` | Đã sửa: hai nơi cùng chữ "E.g. Customer forgot the card, ID checked at the front desk". |
| 11 | `locker-map.js:151` | Đã sửa comment ("2 h 05 min left", "5:00 late"). |
| 12 | `UserController.java:175`, `TopupDao.java:145` | Đã sửa: `String.format(Locale.US, "%,d", …) + " VND"`. |
| 13 | `CLAUDE.md:13, 52` | Đã sửa: "All visible text is English…" và locale `en_US`. |

## Kiểm lỗi vỡ mới

- `node --check` cả 13 tệp `web/js/*.js`: đạt.
- Biên dịch lại `src/java` (JDK 8) rồi biên dịch trước 22 JSP bằng JspC vào `…/scratchpad/r2-ui/jsp`: **0 lỗi, 22 `_jsp.class`**.
- Quét chữ có dấu tiếng Việt và `₫` trong `web/` (trừ `vendor`): 0 kết quả.
- So token cấu trúc giữa dòng xóa và dòng thêm: chỉ đổi chữ. Riêng `myLocker.jsp` thêm khối `c:choose`/`c:when`/`c:otherwise` của lỗi 5. Không đổi tham số form, id, `data-*`.

## Chữ OLED mới của `AuthText`

Đã chạy `AuthText.oled` và `AuthText.enroll` với mọi kết quả (CHOOSE, CONFIRM_EMAIL, UNLOCK ×3 phase) và mọi `reason` của switch (`attempts_left` 0/1/3, mã ngăn 3 ký tự, mã dãy `CANT-B`). Mọi dòng ≤ 16 ký tự và không chuỗi nào quá 2 dòng. `A: Open * cancel` dài đúng 16 ký tự, `B: Checkout B12` dài 15. Mã ngăn trong seed dài tối đa 4 ký tự, nên `B: Checkout A101` vừa đúng 16. `1 try left` / `3 tries left` đúng số ít/số nhiều.

"Checkout" (viết liền) lệch với thuật ngữ "Check out" của glossary. Viết đúng glossary là `B: Check out A101` thì ra 17 ký tự, quá giới hạn. Vì vậy cách viết rút gọn này chấp nhận được. Có một cách vừa giữ thuật ngữ vừa vừa 16 ký tự, xem lỗi 1 dưới đây.

## Lỗi còn lại (vòng 2)

| STT | Vị trí (file:line) | Lỗi | Mức độ | Đề nghị sửa |
|---|---|---|---|---|
| 1 | `src/java/service/AuthText.java:45` (và `test/test/AuthTextTest.java:37`, ví dụ ở `DeviceAuthApi.java:28`) | "Checkout" khác thuật ngữ "Check out" của glossary (do giới hạn 16 ký tự). | thấp | Hoặc giữ nguyên và thêm vào glossary một dòng `OLED only: "B: Checkout <slot>" (16-char limit)`. Hoặc dùng `"A:Open  *:Cancel\nB:Check out " + slot` (16 và ≤16 ký tự với mã ngăn ≤ 4 ký tự), đồng thời sửa test và ví dụ. |
| 2 | `firmware/SmartLocker_Online/SmartLocker_Online.ino:175` (ngoài `web/`, agent firmware) | Cùng một màn hình CHOOSE nhưng chữ khác nhau. Server gửi `A: Open * cancel` khi trả lời, còn firmware vẽ lại thành `A: Open  * quit`, nên chữ trên OLED đổi giữa chừng. | thấp | Dùng đúng chuỗi của server: `show("A: Open * cancel\nB: Checkout " + chooseSlot);`, hoặc chuỗi mới nếu chọn phương án 2 của lỗi 1. |

Không còn lỗi mức cao hay trung bình trong `web/` và các chỗ nối với `src/java`.

KẾT LUẬN: ĐẠT
