# Vòng 1 — rà chéo T6 (ui-java): chữ tiếng Anh phía server

Người rà: agent rà chéo vòng 1 (chỉ đọc, không sửa tệp nào của repo ngoài tệp này).
Phạm vi: `git diff -- src/java test sql config`, tệp mới `sql/06_english_messages.sql`, báo cáo `r0-T6-java.md`, glossary `ui-glossary.md`.

## Đã kiểm gì, kết quả

| Hạng mục | Cách kiểm | Kết quả |
|---|---|---|
| Còn tiếng Việt trong `src/java`, `test`, mẫu mail | grep mọi ký tự ngoài ASCII và các từ tiếng Việt không dấu thường gặp | Chỉ còn: khóa ánh xạ `RemoteCommandDao` (cố ý), tên người/khu mẫu trong `MailTemplates.sample` (seed), ký tự BOM trong `MailTemplates.read`/`Csv`. Không còn comment tiếng Việt. Đạt |
| Không đổi logic | So token của 49 tệp Java trước/sau, bỏ comment và chuỗi | Khác biệt chỉ là: chuỗi ghép thêm dấu `.`, `Locale.US` thay `.replace(',', '.')` (Topup/User/AuthText), `customLabel` có số ít/số nhiều, `RemoteCommandDao.reasonText`, biến `vi`→`shown`, tên test `emptyNameBecomesThere`. Đạt |
| Khóa `Web.SQL_MESSAGES` | So 30 khóa với HEAD và với mọi `THROW 5xxxx, N'...'` trong `sql/` (từng byte) | 30/30 khóa không đổi và đều có trong procedure. `THROW` chưa ánh xạ (`...PIN, card or fingerprint`, `...card deposit` bản cũ, thông báo của `demo_box`/script test) vốn đã là tiếng Anh. Đạt |
| `RemoteCommand.reason` do procedure ghi | grep mọi `INSERT INTO RemoteCommand` trong 02/03/04/upgrade | Đúng 5 chuỗi (`Mở bằng điện thoại`, `Chạm điện thoại`, `Quét thẻ, xác nhận qua email`, `Thay vân tay`, `Xóa vân tay`), cả 5 có trong ánh xạ; `reasonText` có `trim()`, null an toàn; chỉ `search()` đọc cột này. Đạt (xem lỗi 2 về dòng seed) |
| Tiền / ngày | Đọc `AuthText.vnd`, `MailTemplates.time`, flash Topup/User | `14,700 VND`, `-5,000 VND`; mail `dd/MM/yyyy HH:mm` theo `Asia/Ho_Chi_Minh`. Đạt |
| Chữ OLED | Firmware: LCD 1602, `show()` tách ở `\n`, `lcdLine()` cắt 16 ký tự | Mọi dòng ≤ 16 (dài nhất `Wrong box! Go to`, `Store your items` = 16; `B: Checkout A01` = 15). CHOOSE do firmware tự vẽ. Đạt |
| SQL | BOM (`efbbbf`) mọi `sql/*.sql`; diff 04/upgrade chỉ là comment; `demo_box.sql` chỉ đổi 6 thông báo `THROW 509xx` | Đạt |
| Dựng DB thử | `build-db.ps1 -Database SL_R1_JAVA` (01→05 bản mới): chạy sạch, plan/`SlotSize.items` tiếng Anh ngay. Giả lập DB cũ (tên plan + items tiếng Việt, một plan “admin sửa”), chạy 06 hai lần bằng `sqlcmd -I -b -f 65001` | Lần 1: 3 plan + 3 cỡ được dịch, plan đã sửa giữ nguyên; lần 2: 0 + 0, `@@TRANCOUNT` = 0. Chuỗi tiếng Việt trong 06 khớp từng byte với seed cũ của 03. Đã xóa `SL_R1_JAVA`; `PRJ301_LOCKER` không bị đụng (create_date 2026-11-07 08:09:43) |
| Test | JDK 8 biên dịch `src/java` + `test` vào scratchpad `r1-java`, chạy 8 lớp TestNG không cần DB | **54/54 pass**. Diff test chỉ đổi chuỗi mong đợi, comment và tên một test |
| Nối chữ với web | `CardMail.action` ↔ `CARD_ACTION` trong `locker-map.js`; `customLabel` ↔ `'Custom · '`; nút `cardConfirm.jsp` ↔ `card_confirm.txt` | Khớp |

## Lỗi

| STT | Vị trí (file:line) | Lỗi | Mức độ | Đề nghị sửa (thay chính xác) |
|---|---|---|---|---|
| 1 | `docs/postman/SmartLocker-v2.postman_collection.json`: 2457, 2537, 2799, 3347, 3397, 4613, 4663, 7378, 7618, 7628–7630, 7681, 8133, 8138, 8139, 8588, 9198, 9454, 9530, 9842 | Bộ Postman/Newman (dùng bởi `scripts/proof/newman.ps1`, số liệu bài báo VI.D) vẫn so chuỗi tiếng Việt cũ của server; sau thay đổi của T6 khoảng 19 assertion sẽ fail. Chưa task nào nhận sửa (T6 không nhắc; `docs/postman` không đổi). | trung bình | 2457/2537/4663: `include('Mời cất đồ')` → `include('Put your things in slot')`; 2799: `'Mời lấy đồ'` → `'Take your things from slot'`; 3347: `eql('Quet the')` → `eql('Scan the card')` (đổi luôn tên test); 3397: `eql('Dang ky xong')` → `eql('Enrolled')`; 4613: `include('chạm')` → `include('Tap your phone')`; 7378: `eql('Qua han tra tu\\nNap tien de mo')` → `eql('Overdue\\nTop up to open')`; 7618 và 8133: `const vnd = n => String(n).replace(/\\B(?=(\\d{3})+(?!\\d))/g, ',') + ' VND';   // AuthText.vnd: 14,700 VND`; 7628: `'quá hạn'` → `'overdue'`; 7629: `'Bạn còn nợ ' + vnd(...)` → `'You owe ' + vnd(...)`; 7630: `'nạp tiền'` → `'Top up your wallet'`; 7681: → `'The booking is overdue and the locker is locked, so it cannot be extended'`; 8138: `'Đã gia hạn thêm 90 phút.'` → `'Extended by 90 min.'`; 8139: `'Đã trừ ' + vnd(charge) + ' vào ví.'` → `vnd(charge) + ' was taken from your wallet.'`; 8588: `'Đã cộng tiền vào tài khoản '` → `'Money added to account '`; 9198/9530: `'Đã hủy lượt đặt. Đã hoàn'` → `'Booking cancelled. '`; 9454: → `'The full-refund cancel time just ended'`; 9842: → `'After booking, at least 10,000 VND must stay in your wallet'`. Đổi tên test `'Vietnamese message'` → `'English message'`. Sau đó chạy lại Newman trên một DB `SL_*` |
| 2 | `sql/02_data_v1.sql:391-393, 564-575, 663, 677-679, 689, 702` | Dữ liệu seed dạng câu (không phải tên người/địa điểm) vẫn tiếng Việt và hiện trên trang nhân viên: ghi chú nạp tiền (Top-up review), `message` của 12 cảnh báo mẫu (Alerts; cảnh báo mới do `RuleEngine` ghi tiếng Anh nên trang bị lẫn hai thứ tiếng), ghi chú phiếu bảo trì (Maintenance), lý do lệnh mở từ xa `Hỗ trợ mở tủ khẩn cấp từ quầy quản trị viên lần N` (Remote unlock; `reasonText` không dịch vì là chuỗi ghép). Theo yêu cầu, chỉ tên khu/địa điểm/người được giữ. | trung bình | Dịch các chuỗi này ngay trong 02 (ví dụ 391 `N'Waiting for the bank transfer to be matched'`, 392 `N'Transfer matched and added to the wallet'`, 393 `N'Rejected: the transfer note does not match the reference code'`, 702 `N'Emergency open from the admin desk, request '`, 689 `N'Maintenance and sensor check done, round '`, 663 `N'Check and recalibrate the weight sensor: '`, 677 `N'Routine maintenance of LIB-A: check the solenoid bolts of slots A01-A04'`, 678 `N'Check the RFID reader antenna in the DOMA-A dormitory lobby'`, 679 `N'Clean the infrared sensor and the reed switch of bank CANT-A'`, các `message` cảnh báo 564–575 dịch nghĩa tương ứng) và thêm vào `06_english_messages.sql` các `UPDATE ... WHERE <cột> = N'<chuỗi cũ>'` (và `LIKE N'Hỗ trợ mở tủ khẩn cấp%'` cho RemoteCommand/ghi chú có số) để DB đang chạy cũng đổi; giữ nguyên tính idempotent |
| 3 | `src/java/service/AuthText.java:53`, `:112` | Khi còn 1 lần thử: `1 tries left` (sai số nhiều), cả OLED lẫn trang `/k`. | thấp | 53: `"Wrong PIN\n" + n + (n == 1 ? " try left" : " tries left")` với `long n = num(row, "attempts_left")`; 112: `"Wrong PIN. " + n + (n == 1 ? " try left." : " tries left.")` |
| 4 | `src/java/service/AuthText.java:40` | Glossary: `*` là Cancel, nút là “Check out”; câu CHOOSE ghi `* quit`, `Checkout`. (Firmware tự vẽ màn CHOOSE nên chỉ ảnh hưởng JSON/Postman/test.) | thấp | `"A: Open * cancel\nB: Check out " + slot` chỉ vừa 16 ký tự khi mã ngăn 3 ký tự; nếu giữ an toàn độ dài thì để nguyên `Checkout`, chỉ đổi `* quit` → `* cancel` (`"A: Open * cancel"` = 16) và cập nhật `AuthTextTest` |
| 5 | `src/java/service/AuthText.java:96` | `is rented by you` hơi gượng. | thấp | `"Slot " + slot + " is in your booking. Choose Open to take or store things, or Check out to take everything and end the booking."` |
| 6 | `config/mail-templates/due_soon.txt:8` | `top up before you can open the locker` sai ý (nghĩa là “nạp trước khi có thể mở”, đọc ngược). | thấp | `If your wallet balance is negative, top up first; then you can open the locker.` |
| 7 | `config/mail-templates/topup_rejected.txt:8` | Glossary dùng “Transfer note” (topup.jsp). | thấp | `Check the transfer note, then create a new request.` |
| 8 | `config/mail-templates/overdue.txt:13` | Liệt kê cách mở thiếu điện thoại (v7 có phone). Nội dung cũ, nhưng nên sửa khi đã đụng tới. | thấp | `2. Open the locker as usual (PIN, card, phone or fingerprint) and pick up your things.` |
| 9 | `config/mail-templates/booking_confirmed.txt:12`, `reservation_expired.txt:5` | Mô tả luật trước v7.1 (hết giữ chỗ thì hủy); v7.1 tự check-in ở `hold_until`. Hai mẫu chưa được gửi ở đâu (T6 đã ghi chú). | thấp | `booking_confirmed.txt:12`: `Come to the locker and store your things before {{hold_until}}. If you do not, the booking starts by itself at {{hold_until}} and the time you paid for runs from then.`; `reservation_expired`: ghi chú trong `config/mail-templates/README.md` là mẫu lỗi thời, không dùng từ v7.1 |
| 10 | `sql/03_v2_v3.sql:743-746` | Khối đổi tên plan chỉ khớp theo tên, còn 06 khớp tên **và** `duration_min`; hai nơi được nói là “cùng một UPDATE”. Không gây lỗi (tên tiếng Việt là duy nhất). | thấp | Đổi VALUES thành `(N'2 hours', N'2 giờ', 120), (N'4 hours', N'4 giờ', 240), (N'Day pass', N'Trọn ngày', 1440), (N'Demo 2 minutes', N'Demo 2 phút', 2)) v(en, vi, minutes) ON p.plan_name = v.vi AND p.duration_min = v.minutes;` |
| 11 | `sql/03_v2_v3.sql:144` | Comment cũ `found by duration: 07 renames the plans` nay sai (không có 07, plan không còn bị đổi sang tiếng Việt). | thấp | `-- B2. Demo 2 minutes is off: deposits refer to it, so it is not deleted (found by duration, never by name)` |
| 12 | `config/mail-templates/*.txt` | Mọi mẫu mất dòng trống cuối tệp (`\ No newline at end of file`). `render()` có `trim()` nên không ảnh hưởng nội dung mail. | thấp | Thêm CRLF cuối mỗi tệp (tùy chọn) |

Ghi chú ngoài phạm vi T6 (không tính vào kết luận): `web/WEB-INF/web.xml` còn `fmt.locale = vi_VN` (T4/T7); firmware còn chữ LCD tiếng Việt không dấu (`Mo tu ngan ...` ghép với `(phone)`/`(remote)` của server, `Ngan X OK`, `Da lay do`...) — thuộc T8; `03_v2_v3.sql:773` (`Dãy ...`) và `:777` (`Tài khoản hệ thống`) là tên seed, chấp nhận giữ.

## Cách kiểm lại

```sh
# token diff (bỏ comment/chuỗi) và khóa SQL_MESSAGES
python -I <scratchpad>/r1-java/tokdiff.py
python -I <scratchpad>/r1-java/keys.py
# test không cần DB: 54/54
"$JDK/java" -cp "<r1-java>\test-classes;<r1-java>\classes;$CP" org.testng.TestNG -useDefaultListeners false \
  -testclass test.RuleEngineTest,test.PricingTest,test.RiskScorerTest,test.SecurityUtilsTest,test.AuthTextTest,test.CardMailTest,test.MailTemplatesTest,test.LockerSessionListTest
# 06 idempotent: build-db.ps1 -Database SL_R1_JAVA, giả lập tên cũ, chạy 06 hai lần (3+3 rồi 0+0), xóa DB
```

KẾT LUẬN: CHƯA ĐẠT
