# Vòng 0 – T4 (ui-jsp): dịch chữ giao diện JSP sang tiếng Anh

Mục tiêu: theo Bảng 2 dòng 1 của `docs/review/teacher-feedback-2026-11-14.md`, mọi chữ hiển thị trong JSP/JSPF/tag chuyển sang tiếng Anh (không có công tắc đổi ngôn ngữ). Mã kỹ thuật (mã ngăn, UID, enum trạng thái, mã lý do, khóa quyền) giữ nguyên.

## Thuật ngữ

Bảng thuật ngữ chung: `docs/review/ui-glossary.md` (T4 viết trước, T5 bổ sung mục JS, T4 bổ sung mục JSP ở cuối).
Quy ước định dạng ghi trong đó:
- Tiền: `12,000 VND` (phân nhóm kiểu en-US, khoảng trắng, `VND`; bỏ hết `đ`, `₫`, `VNĐ`).
- Locale JSTL `fmt` cố định `en_US` trong `web.xml` (vẫn cố định, không theo trình duyệt).
- Ngày giờ: `<ui:dt>` giữ mẫu `dd/MM/yyyy HH:mm`, 24 giờ, giờ Việt Nam (tag không có chữ tiếng Việt nên không phải sửa). JS (T5) dùng `HH:mm` 24 giờ và `dd/MM` cho trục biểu đồ, khớp với nhau.
- Thời lượng: `min`, `h`, `hour(s)`, `s`.

## Tệp đã sửa (chỉ chữ; không đổi tên tham số, id, class, tên thuộc tính data-*)

- `web/WEB-INF/web.xml`: `vi_VN` -> `en_US` và chú thích của nó (không đụng `fileEncoding` hay cấu hình khác).
- `web/WEB-INF/tags/status.tag`: nhãn trạng thái tiếng Anh (Active, In use, Available, Reserved, Occupied, Maintenance, Offline, Disabled, Inactive, Locked, Blocked, Reported lost, Open, Resolved, Closed, Completed, No-show, Cancelled, Overdue, Awaiting e-mail, Pending, Sent, Done, Expired, Approved, Rejected, Online, Unstable).
- `web/WEB-INF/views/common/nav.jspf`, `nav-floating.jspf`: menu, nhóm menu, vai trò, nút đăng nhập/đăng ký/đăng xuất, số dư `VND`, aria-label.
- Mọi trang trong `web/WEB-INF/views/`: alert, audit, calibration, cardConfirm, dashboard, denied, deposit, kiosk, lockerArea, lockerBank, lockerMap, lockerMapStaff, lockerSession, lockerSlot, maintenance, myLocker, remoteCommand, role, storagePlan, topup, user, userCard. `lang="vi"` -> `lang="en"` ở mọi trang.
- `common/icons.jspf`, `common/panel-flash.jspf`, `tags/dt.tag`: không có chữ tiếng Việt, không sửa.

## Chỗ JS/Java phụ thuộc vào chữ trong JSP (đã khớp với T5)

- `myLocker.jsp` `select[name=minutes]`: `user-pages.js` lấy phần trước dấu `·` của option và bỏ dấu `+` để dựng câu xác nhận. Option có dạng `+30 min · 12,000 VND`, `+1 hour · ...`, `+2 hours · ...`, `+4 hours · ...`; câu ban đầu `Extend by 1 hour? 12,000 VND is taken from your wallet now.` giống câu JS dựng lại.
- `myLocker.jsp` form hủy: `data-confirm-late`, `data-late-label` và `[data-cancel-label]` do JSP viết, `user-pages.js` chỉ chép sang (`Full refund if cancelled within` / `50% refund (X VND) if cancelled within`).
- `kiosk.jsp`: `#kioskSubmit` = `Open`, `#tapOpen` = `Open my locker`, các nút `data-intent` = `Open` / `Check out` (đúng chuỗi `kiosk.js` đặt lại).
- `[data-balance-text]` (lockerMap.jsp) in `12,000 VND`; `locker-map.js` ghi lại bằng `money()` cùng định dạng.
- `dashboard.jsp`: `#k-audit` `Intact`/`Tampered`, thẻ `Valid`/`Denied` và `Device #12` giống `dashboard.js`; `#ch-hourly-meta`, `#ch-revenue-meta` chỉ là chữ ban đầu, JS ghi đè.
- `app.js` đọc chữ `<th>` làm nhãn thẻ trên điện thoại: chỉ hiển thị, không so khớp.
- Java (T6): `cardConfirm.jsp` in `Your card was just scanned at box X to ${action}.`, nên `CardMail.action(phase)` phải là cụm động từ tiếng Anh (đã ghi trong glossary). Các chữ khác do controller đưa vào (flash, `error`, `integrity`, `roleLabels`) thuộc T6.

## Còn tiếng Việt và lý do

- Không còn ký tự tiếng Việt trong `views/`, `tags/` và `web.xml` (kiểm bằng script tìm mọi chữ có dấu tiếng Việt, `đ` và `₫`: 0 kết quả).
- Dữ liệu từ CSDL (tên khu, vị trí, tên gói, tên người) vẫn có thể là tiếng Việt vì là dữ liệu seed, không phải việc của T4.

## Kiểm tra đã làm

- So số lượng `<c:`, `</c:`, `<fmt:`, `<ui:`, `${`, dấu `"` và dấu `'` của từng tệp với HEAD: giống hệt, nên không làm vỡ thẻ, EL hay chuỗi JS (không dùng dấu nháy đơn kiểu "don't" trong chữ mới).
- Kiểu xuống dòng (CRLF/LF) của từng tệp giữ nguyên; `git diff --stat`: 26 tệp, số dòng thêm bằng số dòng bớt.
- Chưa chạy JSP trên Tomcat và chưa kiểm thử E2E trên trình duyệt (để agent kiểm chứng làm sau; không đụng Tomcat 8080 của chủ dự án).

## Đề nghị cho bước kiểm chứng

Mở từng trang sau khi triển khai, xem chữ, số tiền (`12,000 VND`), popup xác nhận gia hạn (đổi option rồi xem câu), hủy đặt (qua mốc 5 phút), trang kiosk `/k/{device}` (chọn Open/Check out) và trang `/c/{token}`.

## Vòng 2 (theo `docs/review/rounds/r1-UI-web.md`)

- Lỗi 2, `kiosk.jsp:89-90`: thêm động từ chính theo câu người rà đề nghị: "During the booking, each time you open the locker, choose Open (take or add items) or Check out (end the booking)."
- Lỗi 3, `myLocker.jsp`: dòng thẻ trống ghi "choose RFID card" (đúng nhãn nút ở `locker-map.js`).
- Lỗi 4, `myLocker.jsp`: chỗ có nghĩa là ngăn dùng "slot": "Overdue: the slot is locked", "A locked slot cannot be extended.", "An overdue, locked slot cannot be extended.".
- Lỗi 5, `myLocker.jsp`: số lần mở dùng `c:choose`, in "1 time" / "N times".
- Lỗi 10, `remoteCommand.jsp:43`: placeholder là "E.g. Customer forgot the card, ID checked at the front desk". Theo orchestrator, T5 dùng "Customer forgot the card…" trên bản đồ nhân viên; T5 nên dùng đúng chuỗi này để hai nơi giống nhau.
- Kiểm tra lại: quét chữ tiếng Việt trong `views/`, `tags/` và `web.xml` cho 0 kết quả. Số token của `kiosk.jsp` và `remoteCommand.jsp` vẫn giống HEAD. `myLocker.jsp` thêm đúng phần của khối `c:choose` mới (3 `<c:`, 3 `</c:`, 1 `${`, 2 dấu `"`) và không thay đổi gì khác.
