# UI glossary (English interface)

Shared by T4 (JSP), T5 (JS/CSS) and T6 (Java/SQL messages) so every page says the same thing.
Technical codes stay as they are: slot codes (A01), bank/device codes (LOCKER-01), RFID UIDs,
status enums (ACTIVE, OCCUPIED...), reason codes (WRONG_CODE...), permission keys (ALERT:READ).
Place names that are seed data in the database stay as they are.

## Formats

| What | Convention | Example |
|---|---|---|
| Money | grouping with commas, no decimals, a space, then `VND` (never `đ`, `₫`, `VNĐ`, `$`) | `12,000 VND`, `-5,000 VND` |
| Money in JS | `Number(n).toLocaleString('en-US') + ' VND'` | |
| Money in Java | `String.format(Locale.US, "%,d VND", n)` (or `NumberFormat.getInstance(Locale.US)`) | |
| JSTL fmt locale | fixed to `en_US` in `web.xml` (never the browser's language) | `<fmt:formatNumber ... groupingUsed="true"/> VND` |
| Date + time | `dd/MM/yyyy HH:mm`, 24-hour clock, Vietnam time (Asia/Ho_Chi_Minh); unchanged pattern, `<ui:dt>` | `16/10/2026 21:55` |
| Date only | `dd/MM/yyyy` | `16/10/2026` |
| Time only | `HH:mm` (`HH:mm:ss` where seconds matter) | `21:55` |
| Durations | `min`, `h`, `s`, `days` with a space; `1 h 30 min` | `30 min`, `2 h`, `12 s` |
| Relative time | `just now`, `5 min ago`, `in 3 min`, `2 h ago` | |
| Percent | `80%` | |
| Decimal separator | `.` | `1.5 s` |
| Weight | `g`, `kg` | `250 g` |

## Navigation (menu entries and page titles)

| Vietnamese | English |
|---|---|
| Tổng quan | Dashboard |
| Sơ đồ tủ | Locker map |
| Cảnh báo | Alerts (one: alert) |
| Dữ liệu cảm biến | Sensor data |
| Tủ của tôi | My locker |
| Nạp tiền | Top up (noun: top-up) |
| Duyệt nạp tiền | Top-up review |
| Khu vực | Areas |
| Dãy tủ | Locker banks |
| Ngăn tủ | Slots |
| Gói gửi đồ / gói thuê | Storage plans |
| Thẻ RFID | RFID cards |
| Lượt gửi đồ (staff list) | Bookings |
| Mở khóa từ xa | Remote unlock |
| Hiệu chuẩn | Calibration |
| Bảo trì / phiếu bảo trì | Maintenance / maintenance ticket |
| Người dùng | Users |
| Vai trò & quyền | Roles & permissions |
| Nhật ký kiểm toán | Audit log |
| Vận hành / Cá nhân / Quản lý / Hệ thống (menu groups) | Operations / Personal / Management / System |
| Thêm (overflow tab) | More |
| Bỏ qua menu | Skip to content |
| Đổi nền sáng / tối | Toggle light/dark theme |

## Roles

| Vietnamese | English |
|---|---|
| Quản trị viên | Administrator |
| Nhân viên vận hành | Operator |
| Kỹ thuật viên | Technician |
| Kiểm toán viên | Auditor |
| Người dùng / sinh viên | User / student |
| Khách | Visitor |

## Domain terms

| Vietnamese | English | Note |
|---|---|---|
| tủ (the product) | locker | |
| hộp tủ, bộ điều khiển | locker box, box; controller | the ESP32 device (device code) |
| dãy tủ | locker bank, bank | |
| ngăn, ô | slot | |
| khu vực | area | |
| cỡ ngăn S/M/L | slot size S/M/L | |
| đặt ngăn | Book slot (button) / book a slot | |
| lượt đặt, lượt gửi, lượt thuê | booking | one entity everywhere |
| giữ chỗ | hold (reservation) | `hold_until` = held until |
| cất đồ (lần mở đầu) | check in / store your things | |
| lấy đồ | pick up | |
| mở tủ (giữa lượt thuê) | Open | kiosk intent OPEN |
| trả tủ | Check out | kiosk intent CHECKOUT; ends the booking |
| gia hạn | Extend / extension | |
| hủy | Cancel | |
| hoàn tiền | refund | |
| quá hạn | overdue | |
| hạn trả | due time | |
| thời gian ân hạn | grace period | |
| phụ phí trễ hạn | late fee | |
| số tiền đang nợ | amount owed | |
| ví | wallet | |
| số dư | balance | |
| nạp tiền | top up / top-up | |
| mật mã 6 số | 6-digit PIN | |
| thẻ | card | |
| vân tay | fingerprint | |
| chạm điện thoại (NFC) | phone tap | |
| đăng ký thẻ / vân tay | enroll (enrollment) | |
| báo mất | report lost | |
| mất kết nối | offline | |
| trực tuyến | online | |
| chập chờn | unstable | DEGRADED |
| hết chỗ | Full | |
| còn trống | available / free | |
| lệnh mở khóa | unlock command | |
| heartbeat | heartbeat | |
| cảnh báo | alert | |
| điểm rủi ro | risk score | |
| chuyển cấp, leo thang | escalate / escalation | |
| xử lý, đóng cảnh báo | resolve | |
| nhật ký | log | audit log for the hash chain |
| chuỗi băm | hash chain | |
| hiệu chuẩn | calibration | |
| khối lượng | weight | |
| thời gian mở cửa | door-open time | |
| phiên (cảm biến) | session | |
| nhân viên | staff | |
| quầy | front desk | |
| ghi chú | note | |
| lý do | reason | |

## Status labels (`<ui:status>`, JS status maps should match)

| Code | English | Code | English |
|---|---|---|---|
| ACTIVE | Active | ACTIVE (booking) | In use |
| AVAILABLE | Available | RESERVED | Reserved |
| OCCUPIED | Occupied | MAINTENANCE | Maintenance |
| OFFLINE | Offline | DISABLED | Disabled |
| INACTIVE | Inactive | LOCKED | Locked |
| BLOCKED | Blocked | LOST | Reported lost |
| OPEN | Open | RESOLVED | Resolved |
| CLOSED | Closed | COMPLETED | Completed |
| NO_SHOW | No-show | CANCELLED | Cancelled |
| OVERDUE | Overdue | AWAITING_EMAIL | Awaiting e-mail |
| PENDING | Pending | SENT | Sent |
| DONE | Done | EXPIRED | Expired |
| APPROVED | Approved | REJECTED | Rejected |
| ONLINE | Online | DEGRADED | Unstable |

## Common buttons and labels

| Vietnamese | English |
|---|---|
| Đăng nhập / Đăng ký / Đăng xuất | Sign in / Sign up / Sign out |
| Lưu | Save |
| Hủy | Cancel |
| Thêm | Add |
| Sửa | Edit |
| Xóa | Delete |
| Quay lại | Back |
| Đóng | Close |
| Lọc / Xóa lọc | Filter / Clear filters |
| Tìm kiếm | Search |
| Xuất CSV | Export CSV |
| Thao tác | Actions |
| Trạng thái / Tất cả trạng thái | Status / All statuses |
| Tạo lúc / Cập nhật lúc | Created / Updated |
| Chưa có ... nào | No ... yet |
| Không có ... khớp bộ lọc | No ... match the filters |
| Xác nhận | Confirm |
| Đồng ý | OK |
| Đang tải… | Loading… |

## Wording rules

- Short, plain sentences; sentence case for buttons and headings ("Book slot", "Top-up review").
- In confirm texts (`data-confirm`) ask a question and state the amount taken now: "Extend by 1 hour? 12,000 VND is taken from your wallet now." (`user-pages.js` rebuilds it as "Extend by " + the option label before "·"; options read "+30 min · 12,000 VND", "+1 hour · ...", "+2 hours · ...")
- Avoid apostrophes inside JS strings and EL single-quoted literals (write "do not", "cannot"); if one is needed, escape it.
- `CardMail.action(phase)` (Java) is printed after "to" on `cardConfirm.jsp` ("Your card was just scanned at box X to ..."): keep it a verb phrase, e.g. "pick up your things and check out (the booking ends)", "open the slot (the booking continues)", "store your things in the slot".


## JS (T5: terms used only in web/js)

| Vietnamese | English | Where |
|---|---|---|
| Mở tủ (kiosk button) / Mở tủ của tôi (phone tap) / Trả tủ | Open / Open my locker / Check out | `kiosk.js` rewrites the kiosk.jsp buttons with these texts |
| Đang gửi… / Đang kiểm tra… | Sending… / Checking… | busy buttons |
| còn 12:34 / trễ 5:00 / còn 2 giờ 05 phút | 12:34 left / 5:00 late / 2 h 05 min left | countdowns (`locker-map*.js`, `user-pages.js`) |
| Đã hết giờ | Time is up | `user-pages.js` fallback of `data-late-text` |
| Vừa cập nhật / Cập nhật 12 giây trước | Updated just now / Updated 12 s ago | map sync line |
| Trống / Sắp hết / Còn nhiều / Hết chỗ (area tone) | Free / Almost full / Plenty free / Full | map pins and area list |
| Cỡ S · Nhỏ / Vừa / Lớn; Vừa với | Size S · Small / Medium / Large; Fits | size card |
| Mật mã / Thẻ RFID / Điện thoại / Vân tay (open methods) | PIN / RFID card / Phone / Fingerprint | booking form |
| Gói gửi / Cách mở tủ / Trừ ngay / Số dư còn lại | Storage plan / Open method / Taken now / Balance after | booking and extension popups |
| Tự chọn (theo giờ / theo ngày) | Custom (by hour / by day) | custom plan block |
| Miễn phí | Free | price 0 |
| Đặt ngăn / Đặt và trả X | Book slot / Book and pay X | |
| Gia hạn · trả X / Gia hạn và trả X | Extend · pay X / Extend and pay X | |
| Hủy đặt · hoàn đủ | Cancel booking · full refund | |
| Chỉ đường | Directions | |
| Tủ của bạn | Your locker | map pin and tags |
| Thứ Hai … Chủ nhật / T2 … CN | Monday … Sunday / Mon … Sun | heat map |
| 1,5 tr (chart value) | 1.5M | `dash-charts.js` bar labels (`12k` unchanged) |
| Ngày trên trục doanh thu | `dd/MM` | |
| Giờ trong JS | `toLocaleTimeString('en-GB', {hour:'2-digit', minute:'2-digit'})` (24 h); numbers `toLocaleString('en-US')` | |

## JSP (T4: texts fixed in web/WEB-INF/views)

| Vietnamese | English | Where |
|---|---|---|
| Hợp lệ / Từ chối (rfid_ok) | Valid / Denied | dashboard.jsp, lockerSession.jsp (same as `dashboard.js`) |
| Bị sửa đổi / Toàn vẹn (audit chain card) | Tampered / Intact | dashboard.jsp `#k-audit` (same as `dashboard.js`) |
| Thiết bị #12 | Device #12 | dashboard.jsp, alert.jsp |
| Thẻ từ / Điện thoại / Vân tay / Mật mã (open method) | RFID card / Phone / Fingerprint / PIN | myLocker.jsp |
| Mã đăng ký thẻ từ / vân tay | Card / Fingerprint enrollment code | myLocker.jsp |
| Hoàn đủ nếu hủy trong | Full refund if cancelled within | myLocker.jsp `[data-cancel-label]` |
| Hoàn 50% (X đ) nếu hủy trong | 50% refund (X VND) if cancelled within | myLocker.jsp `data-late-label` |
| Email nhắc hạn | Due reminder e-mail | myLocker.jsp |
| Báo mất thẻ | Report lost | myLocker.jsp, userCard.jsp |
| Cấp thẻ | Issue card | userCard.jsp |
| Duyệt / Từ chối (top-up) | Approve / Reject | topup.jsp |
| Nội dung chuyển khoản | Transfer note | topup.jsp |
| Tạo lượt gửi tại quầy | New front-desk booking | deposit.jsp |
| Khóa quá hạn / Chuyển xử lý | Overdue lock / Escalated | deposit.jsp |
| Mô phỏng / Hộp thật / Chỉ minh họa | Simulated / Real box / Illustration only | lockerBank.jsp |

- Device LCD only (16x2, 16 chars per line): "Checkout" in one word, because "B: Check out A101" is 17 chars. The choose screen is "A: Open * cancel" / "B: Checkout <slot>" in both AuthText (server) and the firmware.
