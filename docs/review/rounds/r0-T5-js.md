# Vòng 0, T5 (ui-js): chuyển chữ giao diện trong JS sang tiếng Anh

Theo Bảng 2 dòng 1 của `docs/review/teacher-feedback-2026-11-14.md`. Không commit. Chỉ sửa `web/js/*.js` (không đụng `web/js/vendor/**`) và chú thích trong `web/css/*.css`; thêm một mục "JS" ở cuối `docs/review/ui-glossary.md` (chỉ nối thêm).

## Tệp đã sửa

| Tệp | Nội dung |
|---|---|
| `web/js/app.js` | Popup xác nhận mặc định: Confirm / OK / Back |
| `web/js/auth-modal.js` | Popup đăng nhập, đăng ký: tiêu đề, nhãn, gợi ý, lỗi mạng, "Sending…" |
| `web/js/area-map.js`, `area-map-mapbox.js` | Nhãn ghim "Your locker", tiêu đề ghim, thông báo lỗi bản đồ, "Your location" |
| `web/js/glass-panel.js` | "Loading…", lỗi tải nội dung |
| `web/js/theme.js` | aria-label nút đổi nền |
| `web/js/user-pages.js` | Đếm ngược ("2 h 05 min left", "Time is up"), popup gia hạn ("Extend by 1 hour? 12,000 VND is taken from your wallet now."), Show/Hide PIN, tiền `en-US` + ` VND` |
| `web/js/kiosk.js` | Trang hộp tủ `/k/...`: nút Open / Open my locker, Check out, thông báo khóa PIN, lỗi máy chủ |
| `web/js/dashboard.js` | Bảng thiết bị, cảnh báo, phiên mở tủ, biểu đồ canvas, trạng thái kết nối, thời gian tương đối ("5 min ago") |
| `web/js/dash-charts.js` | Mọi nhãn biểu đồ, chú giải, tooltip, aria-label; thứ trong tuần (Mon…Sun); giá trị cột "1.5M"; ngày trục doanh thu `dd/MM` |
| `web/js/locker-map.js` | Bản đồ người dùng: thẻ ngăn, form đặt ngăn, gói tự chọn (Custom), popup đặt/gia hạn/hủy, hộp quá hạn, thông báo vị trí, xác nhận thẻ, định vị |
| `web/js/locker-map-staff.js` | Sơ đồ tủ của nhân viên: thẻ ngăn, mở khóa từ xa, đổi trạng thái, kết nối lại dãy, định vị |
| `web/css/app.css`, `web/css/locker-map.css` | Chỉ 3 dòng chú thích có chữ giao diện tiếng Việt trong ngoặc kép; CSS không có `content: "..."` chứa chữ |

Định dạng (khớp glossary): số `toLocaleString('en-US')`; tiền `12,000 VND` (bỏ hết `đ`); giờ `toLocaleTimeString('en-GB', {hour, minute})` (24 giờ, `HH:mm`); ngày `dd/MM` như `<ui:dt>`; dấu thập phân `.` (khoảng cách `1.5 km`, trước là `1,5`). Chuỗi thời gian không có múi giờ vẫn đọc là UTC (`parseUtc`, `fmtTime` không đổi). Nhãn trạng thái trong JS khớp bảng `<ui:status>` của glossary (Available, Reserved, Occupied, Overdue, Maintenance, Offline, Online, Unstable, Active).

Không đổi id, class, `data-*`, trường API, tham số, mã giao thức. HTML vẫn dựng qua `window.SmartLocker.esc`; không dùng `confirm()` mới (chỗ `window.confirm` cũ trong `app.js` chỉ là dự phòng khi trình duyệt không có `<dialog>`, giữ nguyên). Không có dấu nháy đơn trong chuỗi tiếng Anh mới.

## Liên kết chữ giữa JS và JSP/Java (T4, T6 cần giữ khớp)

Không đoạn JS nào so sánh chữ tiếng Việt từ máy chủ: mọi nhánh rẽ dựa trên mã (`result`, `reason`, `status`, `confirm_phase`, `ok`, lỗi nội bộ `'SESSION'`). Các điểm phụ thuộc chữ:

1. **`user-pages.js` `syncExtend`** đọc chữ của `<option>` trong `myLocker.jsp` (`select[name=minutes]`), cắt ở dấu `·` và bỏ dấu `+`, ghép thành `'Extend by ' + label + '? ' + money(data-price) + ' is taken from your wallet now.'`. T4 phải giữ dạng `+1 hour · <số> VND` (có `+`, có `·`, phần trước `·` là thời lượng). Hiện JSP còn `+30 phút · … đ`, `+1 giờ · … đ`, `+2 giờ`, `+4 giờ` (dòng 232-235).
2. **`kiosk.js`** tự đặt lại chữ nút sau khi chờ: `#kioskSubmit` = `'Open'`, `#tapOpen` = `'Open my locker'`; câu dự phòng `'Choose Open or Check out.'`. `kiosk.jsp` (T4) nên in đúng các chữ này cho `#kioskSubmit`, `#tapOpen`, nút `data-intent="OPEN"` (`Open`) và `data-intent="CHECKOUT"` (`Check out`), nếu không chữ nút sẽ đổi sau lần bấm đầu.
3. **`locker-map.js` `CARD_ACTION`** = `CardMail.action(phase)` (Java, T6), hiện đúng như glossary: `CHECK_IN: 'store your things in the slot'`, `ACCESS: 'open the slot (the booking continues)'`, `PICKUP: 'pick up your things and check out (the booking ends)'`; câu bao: `'Your card was just scanned at the box to ' + action + '. Your locker: …'`. T6 nên dùng cùng ba cụm này trong `src/java/service/CardMail.java`.
4. **Chữ máy chủ được in nguyên văn** (T6 dịch phía Java/SQL, JS không cần đổi):
   - `data.message` của `/api/kiosk/unlock` (`src/java/api/KioskApi.java`) trên trang hộp tủ.
   - `json.error` của POST `LoginController` / `RegisterController` khi gửi `Accept: application/json` (popup đăng nhập).
   - Trong `/api/locker-map`: `plans[].plan_name` (bảng StoragePlan, `sql/03_v2_v3.sql` dòng 744 đổi tên gói sang `2 giờ`, `4 giờ`, `Trọn ngày`), `sizes[].items` (cột `SlotSize.items`, in sau "Fits:"), `slot.occupant`, tên/địa điểm khu (dữ liệu mẫu, giữ nguyên).
   - `slot.alert.label` và nhãn cảnh báo ở dashboard là mã (`TAMPER_ALERT`…), giữ nguyên.
5. **`locker-map.js` `customNote`** nhắc gói trọn ngày bằng chữ chung "the full-day plan" (trước là "Gói Trọn ngày", tên gói trong DB). Nếu T6 đặt lại tên gói là `Day pass`, có thể sửa câu thành "The Day pass plan costs the same and lasts 24 h." cho khớp.
6. Thuộc tính `data-confirm`, `data-late-text`, `data-confirm-title`, `data-confirm-ok` do JSP (T4) cung cấp; JS chỉ in lại.

## Còn tiếng Việt và lý do

Quét `web/js/*.js` (trừ vendor) và `web/css/*.css` bằng biểu thức các chữ có dấu tiếng Việt (`À-ÿ`, `ăđĩũơư`, `Ạ-ỹ`) và `vi-VN`: chỉ còn 2 dòng trong `locker-map.js` (734, 738) có ký tự `×` (dấu nhân trong "20×20×20 cm"), không phải tiếng Việt. Không còn `vi-VN` hay hậu tố `đ`.

## Kiểm tra

- `node --check` cả 13 tệp `web/js/*.js`: đạt.
- Giữ nguyên kiểu xuống dòng (CRLF/LF) của từng tệp; không đổi BOM.
- Chưa chạy E2E trên trình duyệt (để bước kiểm thử chung sau). Khi chạy cần xem: popup đặt ngăn/gia hạn/hủy trên bản đồ, đếm ngược trong "My locker", trang `/k/{device}`, dashboard (biểu đồ, bảng), sơ đồ tủ nhân viên.


## Vòng 2 (theo `docs/review/rounds/r1-UI-web.md`, mục 4)

- `web/js/locker-map.js:379,384`: "Confirm the opening" → "Confirm opening" (giống `cardConfirm.jsp` và e-mail).
- `web/js/locker-map.js:846`: "The full-day plan" → "The Day pass plan" (gói mẫu nay tên "Day pass").
- `web/js/locker-map.js:622`: "Lost the server connection, retrying" → "Connection lost, retrying" (giống hệt `locker-map-staff.js:441` và `dashboard.js:254`, không dấu chấm cuối).
- `web/js/locker-map.js:151`: sửa chú thích cũ thành `"2 h 05 min left"`, `"5:00 late"`.
- `web/js/auth-modal.js:45-46`: "Email" → "E-mail" (nhãn và gợi ý "reminder e-mail").
- `web/js/locker-map-staff.js:557`: placeholder → "E.g. Customer forgot the card, ID card checked" (giống `remoteCommand.jsp:43`).
- `node --check` ba tệp đã sửa: đạt.
