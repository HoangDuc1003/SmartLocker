# Vòng 1 – Rà chéo bản dịch giao diện tiếng Anh (web/ và chỗ nối với src/java)

Người rà: agent r1-UI-web. Phạm vi: `web/` (JSP, tag, `web.xml`, JS, CSS) và các chỗ JS/JSP/Java phụ thuộc chữ của nhau.
Chỉ đọc, không sửa tệp nào của repo (trừ báo cáo này).

## Đã kiểm

1. **Vỡ cú pháp**
   - `node --check` cả 13 tệp `web/js/*.js`: đạt.
   - Biên dịch `src/java` (89 tệp) bằng JDK 8, rồi biên dịch trước **toàn bộ 22 JSP** bằng `org.apache.jasper.JspC` của Tomcat 9.0.113
     (classpath: `lib/*`, `bin/tomcat-juli.jar`, `ant.jar` của NetBeans 8.2, `web/WEB-INF/lib/*`, lớp vừa biên dịch), ra scratchpad
     `.../scratchpad/r1-ui/jsp`: **0 lỗi, 22 lớp `_jsp.class`**. Không đụng Tomcat 8080.
   - So từng tệp các token cấu trúc giữa dòng bị xóa và dòng thêm (`name=`, `id=`, `class=`, `data-*`, `${...}`, thẻ `<c:`/`<fmt:`,
     hằng chữ hoa): chỉ khác ở phần chữ (giá trị `value="..."`, `data-confirm`, chuỗi trong EL). Không đổi tham số form, id, class, mã.
   - Không có dấu nháy đơn (`don't`...) trong chữ mới của JSP; JS đã qua `node --check`. Hai `<script>` nội tuyến (`nav.jspf`,
     `nav-floating.jspf`) không có chữ hiển thị mới.
   - `fmt`: `web.xml` cố định `en_US`; không có `type="currency"` (sẽ in `$`); `type="percent"` cho ra `80%`; `lateRefund`
     (`myLocker.jsp:61`) vẫn `groupingUsed="false"`, `maxFractionDigits="0"` nên `expectedRefund` gửi lên vẫn là số trơn.
2. **Còn tiếng Việt**: quét `web/` (trừ `vendor`) bằng regex mọi chữ có dấu tiếng Việt và `₫`, cùng các từ không dấu thường gặp
   (`khong`, `cua`, `ngan`, `thanh toan`, `dang nhap`...), `vi-VN`, `vi_VN`, `lang="vi"`: **0 kết quả**. Mọi trang `lang="en"`.
   Trong `src/java` chỉ còn khóa ánh xạ của `RemoteCommandDao` và tên mẫu trong `MailTemplates.sample` (dữ liệu, hợp lệ).
3. **Nhất quán**: nhãn trạng thái của JS (`locker-map*.js`, `dashboard.js`, `dash-charts.js`) khớp `status.tag`; tiền `12,000 VND`
   ở JSP (`fmt` + ` VND`), JS (`toLocaleString('en-US') + ' VND'`) và Java (`%,d VND`); giờ `HH:mm` 24 giờ (`en-GB`) trong JS,
   `dd/MM/yyyy HH:mm` trong `<ui:dt>`; đếm ngược `2 h 05 min left` giống nhau giữa `user-pages.js` và `locker-map*.js`.
4. **Chỗ nối (khớp từng byte)**
   - `myLocker.jsp:232-235` option `+30 min · … VND` / `+1 hour` / `+2 hours` / `+4 hours` → `user-pages.js:95-96` cắt ở `·`, bỏ `+`,
     dựng `Extend by 1 hour? 12,000 VND is taken from your wallet now.` = câu ban đầu ở `myLocker.jsp:227`. Khớp.
   - Hủy đặt: `data-confirm-late`, `data-late-label`, `[data-cancel-label]` (`myLocker.jsp:203-214`) chỉ được JS chép sang. Khớp.
   - `kiosk.jsp:54,77,81,83` (`Open my locker`, `Open`, `Open`, `Check out`) = chữ `kiosk.js:115,140,207,234,250` đặt lại. Khớp.
   - `CardMail.action()` (`src/java/service/CardMail.java:111-116`) = `CARD_ACTION` (`locker-map.js:333`). Khớp.
   - `DepositDao.customLabel` `Custom · N h` / `1 day` / `N days` = `locker-map.js:816` + `durationText()`. Khớp.
   - `dashboard.jsp:73,207,211` `Intact`/`Tampered`, `Device #`, `Valid`/`Denied` = `dashboard.js:60,128,132`; `lockerSession.jsp:93` cũng vậy.
   - `KioskApi` 500 `Server error, please try again.` = `kiosk.js:160`; `Web.sqlMessage` "The hold time is over, so the booking can no
     longer be cancelled." = `locker-map.js:1016,2145`, `user-pages.js:66`. Không có JS nào so sánh chuỗi flash/`error` của server.
5. **Luật UI của CLAUDE.md**: không thêm `confirm()`, không thêm CDN; các `style=` trong dòng sửa là lề/cỡ chữ có từ trước, không có
   màu; HTML trong JS vẫn qua `esc()` (token cấu trúc không đổi).

## Lỗi tìm thấy

| STT | Vị trí (file:line) | Lỗi | Mức độ | Đề nghị sửa |
|---|---|---|---|---|
| 1 | `docs/postman/SmartLocker-v2.postman_collection.json` (16 assertion + hàm `vnd`) — ngoài `web/` nhưng là chỗ nối với chữ của `src/java` | Collection Newman (bộ kiểm `scripts/proof/newman.ps1`) vẫn kiểm câu tiếng Việt do server trả về: `include('Mời cất đồ')` (3 lần), `'Mời lấy đồ'`, `'chạm'`, `'quá hạn'`, `'Bạn còn nợ ' + vnd(debt)`, `'nạp tiền'`, `'quá hạn và tủ đang bị khóa nên không gia hạn được'`, `'Đã gia hạn thêm 90 phút.'`, `'Đã trừ ' + vnd(charge)`, `'Đã cộng tiền vào tài khoản ' + user`, `'Đã hủy lượt đặt. Đã hoàn'` (2 lần), `'Thời gian hủy được hoàn đủ vừa hết'`, `'Sau khi đặt, ví phải còn ít nhất 10.000 đ'`; `vnd` còn in `9.700 đ`. Sau bản dịch Java, 16 assertion này sẽ trượt. Không báo cáo vòng 0 nào nhận phần này. | cao | Đổi `vnd` thành `n => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',') + ' VND'` và thay các chuỗi: `'Mời cất đồ'` → `'Put your things in slot'`; `'Mời lấy đồ'` → `'Take your things from slot'`; `'chạm'` → `'tap link has expired'`; `'quá hạn'` → `'overdue and locked'`; `'Bạn còn nợ ' + vnd(debt)` → `'You owe ' + vnd(debt)`; `'nạp tiền'` → `'Top up your wallet'`; `'quá hạn và tủ đang bị khóa nên không gia hạn được'` → `'overdue and the locker is locked, so it cannot be extended'`; `'Đã gia hạn thêm 90 phút.'` → `'Extended by 90 min.'`; `'Đã trừ ' + vnd(charge)` → `vnd(charge) + ' was taken from your wallet'`; `'Đã cộng tiền vào tài khoản ' + user` → `'Money added to account ' + user`; `'Đã hủy lượt đặt. Đã hoàn'` → `'Booking cancelled. '`; `'Thời gian hủy được hoàn đủ vừa hết'` → `'The full-refund cancel time just ended'`; `'Sau khi đặt, ví phải còn ít nhất 10.000 đ'` → `'After booking, at least 10,000 VND must stay in your wallet'`. Rồi chạy lại Newman trên DB `SL_*` (không chạy trên `PRJ301_LOCKER`). |
| 2 | `web/WEB-INF/views/kiosk.jsp:89-90` | Câu sai ngữ pháp, thiếu động từ chính: "During the booking, each time you choose Open (take or add items) or Check out (end the booking)." | trung bình | `The first opening is for storing your things. During the booking, each time you open the locker, choose Open (take or add items) or Check out (end the booking). The latch closes by itself after a few seconds.` |
| 3 | `web/WEB-INF/views/myLocker.jsp:311` | Hướng dẫn bảo chọn "Card" nhưng nút trong form đặt ngăn ghi "RFID card" (`locker-map.js:691`). | thấp | `You have no card yet. When you book, choose RFID card and enroll it at the box with the enrollment code.` |
| 4 | `web/WEB-INF/views/myLocker.jsp:77, 90, 221` | Dùng "locker" cho ngăn (glossary: ngăn = slot); bản đồ (`locker-map.js`) nói cùng ý bằng "slot". | thấp | `:77` `Overdue: the slot is locked`; `:90` `A locked slot cannot be extended.`; `:221` `An overdue, locked slot cannot be extended.` |
| 5 | `web/WEB-INF/views/myLocker.jsp:126` | `${d.accessCount} times` in ra "1 times". | thấp | `${d.accessCount} ${d.accessCount == 1 ? 'time' : 'times'}` |
| 6 | `web/js/locker-map.js:379, 384` | Cùng một hành động mà nhãn khác: bản đồ "Confirm the opening", còn `cardConfirm.jsp` và mail `card_confirm` ghi "Confirm opening". | thấp | Đổi cả hai chỗ thành `Confirm opening`. |
| 7 | `web/js/locker-map.js:846` | Gọi gói trọn ngày là "the full-day plan", trong khi tên gói nay là `Day pass` (`sql/03_v2_v3.sql`, `06_english_messages.sql`) và `Web.sqlMessage` viết "day pass plan". | thấp | `'/h. The Day pass plan costs the same and lasts 24 h.'` |
| 8 | `web/js/locker-map.js:622` | Thông báo mất kết nối khác chữ với `locker-map-staff.js` và `dashboard.js` ("Connection lost, retrying"). | thấp | `text = 'Connection lost, retrying';` |
| 9 | `web/js/auth-modal.js:45-46` | Viết "Email"/"email", mọi chỗ khác (JSP, Java, status `Awaiting e-mail`) viết "e-mail". | thấp | `'E-mail <span class="muted">(optional)</span>'` và `hint: 'Get a reminder e-mail 15 minutes before your booking ends.'` |
| 10 | `web/WEB-INF/views/remoteCommand.jsp:43` | Placeholder lý do mở từ xa khác với `locker-map-staff.js` ("E.g. Student forgot the card, ID checked at the front desk"); "Customer" không khớp người dùng là sinh viên. | thấp | `placeholder="E.g. Student forgot the card, ID checked at the front desk"` |
| 11 | `web/js/locker-map.js:151` | Comment cũ mô tả định dạng không còn đúng ("2h 05m left", "late 5m"). | thấp | `// "12:34 left" under an hour, "2 h 05 min left" above, "... late" when the time has passed` |
| 12 | `src/java/controller/UserController.java:175`, `src/java/dao/TopupDao.java:145` (chỗ nối Java → `audit.jsp`) | Chi tiết nhật ký kiểm toán in tiền không phân nhóm ("Granted 12000 VND", "Approved 50000 VND"), lệch quy ước `12,000 VND`. Đây là dữ liệu đi vào chuỗi băm, chỉ áp dụng cho dòng mới. | thấp | `"Granted " + String.format(java.util.Locale.US, "%,d", amount) + " VND to " + ...` và tương tự cho `TopupDao`. |
| 13 | `CLAUDE.md` (dòng "All visible text is Vietnamese" và bài học "JSTL `fmt` ... fixed to `vi_VN` in web.xml, do not remove it") | Hai dòng này nay trái với code (`web.xml` = `en_US`, UI tiếng Anh); agent sau đọc CLAUDE.md có thể đổi ngược. Ngoài phạm vi `web/`, để orchestrator sửa. | thấp | UI rules: `All visible text is English; technical codes (slot code, RFID UID, status enum) stay as is.` Bài học: `JSTL fmt follows the browser's Accept-Language; the locale is fixed to en_US in web.xml (money 12,000 VND), do not remove it.` |

Ghi chú không tính là lỗi: nội dung REJECTED của `cardConfirm.jsp` và `locker-map.js` viết khác nhau nhưng cùng nghĩa và không bị so
sánh; `topup.jsp:110` "e.g. 78888" để trơn là hợp lý vì ô nhập chỉ nhận chữ số; dữ liệu seed (tên khu, người dùng) vẫn tiếng Việt là đúng
quy ước. Ảnh chụp trong `docs/images/` (README dùng) giờ là giao diện cũ, thuộc task README.

KẾT LUẬN: CHƯA ĐẠT
