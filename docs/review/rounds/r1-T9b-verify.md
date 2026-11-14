# r1 T9b: kiểm chứng vòng 2 (các bản sửa của T10)

Ngày chạy: 15/11/2026 (giờ máy UTC+7). HEAD `13ba35f` + toàn bộ cây đang sửa, **chưa commit** (không commit gì, không sửa mã nguồn).
Nguồn việc: `docs/review/rounds/r0-T10-fixes.md` mục 3 (danh sách kiểm trên trình duyệt) và yêu cầu của orchestrator.

Tệp T9b đã ghi: `docs/paper/evidence/newman-5.json`, `newman-5.log`, `docs/images/dashboard.png`, `docs/paper/images/dashboard.png`,
`docs/paper/images/ui-user.png` và `ui-staff.png` (do script sinh lại), và báo cáo này. Không đổi hằng số crop nào.

## 1. Môi trường

| Mục | Giá trị |
|---|---|
| Ứng dụng | Dựng lại từ cây hiện tại vào `C:\sl-wt\t9\app\web` (xóa thư mục cũ, chép `web/`, `javac` JDK 8 cho 89 tệp `src/java` -> 107 lớp, chép tài nguyên). `WEB-INF/lib` chỉ có gson, jbcrypt, jstl, mssql-jdbc, weka (không testng/jcommander/slf4j) |
| Tomcat | Của riêng T9: `C:\sl-wt\t9\stack.ps1 start` (`CATALINA_BASE=C:\sl-wt\tomcat-t9`, cổng 8091, shutdown 8025, cửa sổ riêng, `DB_URL` -> `SL_T9`, `-Dsmartlocker.mailConfig` tệp rỗng). Log: `Due reminder e-mails off, no mail settings found`. Đã tắt khi xong (`port 8091 open: False`) |
| CSDL | `SL_T9` (giữ từ T9/T10, đã có 06 mới với khu OPS tiếng Anh) |
| Tomcat 8080 / `PRJ301_LOCKER` | Không đụng: cổng 8080 không mở suốt buổi; `PRJ301_LOCKER` create_date vẫn `2026-11-07 08:09:43` |
| Trình duyệt | Built-in browser (thao tác thật: đăng nhập qua popup, bấm nút, hover/focus tooltip, đổi theme, đổi khổ 1440x900 / 375 / 700) + Chrome headless (`C:\sl-wt\t9\shot.mjs`) cho ảnh PNG đúng 1440x1040 DPR 1, theme sáng |

## 2. Danh sách kiểm của T10

| # | Kiểm | Kết quả | Bằng chứng |
|---|---|---|---|
| 1 | Dashboard, thẻ "Open alerts": > 5 loại thì 4 loại nhiều nhất + "Other (N types)" màu xám, cộng chú giải = số ở tâm | **ĐẠT** | Trước Newman: 8 loại mở, API `/api/dashboard/stats` `alertsOpen` = SENSOR_FAULT 3, SUSPECTED_SPOOF 2, LOST_CARD_USED 2, ML_ANOMALY 1, OVERDUE_ESCALATED 1, DEVICE_OFFLINE 1, FORCED_OPEN 1, ITEM_LEFT 1. Chú giải: 3, 2, 2, 1, **Other (4 types) 4**; 3+2+2+1+4 = **12** = tâm "12 open". Cung: lớp `seg-bad/seg-warn/seg-use/seg-ok/seg-mute`, `stroke-dasharray` 24.40 / 16.07 / 16.07 / 7.73 / 32.73 (đúng tỉ lệ 3/2/2/1/4 trên 12, trừ khe). Tooltip cung xám (focus bằng bàn phím) hiện "Other (4 types): 4 (33%)". Sau Newman: 7 loại, chú giải 3, 2, 2, 1, **Other (3 types) 3** = 11 = tâm "11 open"; tooltip "Other (3 types): 3 (27%)". Không cần tạo cảnh báo thêm (SL_T9 luôn có > 5 loại mở) |
| 1b | Theme sáng và tối | **ĐẠT** | `colorScheme` light/dark trên built-in browser: cung xám phân biệt rõ với nền vòng ở cả hai theme, chữ chú giải đọc được; không màu inline (`style` null trên mọi cung) |
| 2 | Thẻ ngăn B07 (cỡ M, khu CANT), 1440x900: 4 nút gói đúng 2 dòng, cao bằng nhau, không tràn | **ĐẠT** | Mỗi nút 71x44 px; dòng 1 cao 17 px, dòng 2 cao 13 px; `scrollWidth == clientWidth` cho mọi chữ ("11,700 VND" 62/62, "32,500 VND" 62/62, "Hours / days" 66/66) |
| 2b | Chọn từng gói đổi "Taken now" | **ĐẠT** | 2 hours 6,500 VND; 4 hours 11,700 VND; Day pass 32,500 VND; Custom (3 h mặc định) 9,900 VND |
| 2c | 375 px (preset mobile, bottom sheet) | **ĐẠT** | Mỗi nút 76x44 px, 2 dòng, không tràn; không cuộn ngang (`scrollWidth` trang = 375) |
| 2d | ~700 px (tablet) | **ĐẠT** | Nút 61 px rộng < 65.5 px nên giá xuống dòng có chủ đích ("11,700 / VND", "Hours / / days"); mọi nút cao 51 px bằng nhau; chữ nằm trong nút (ví dụ "11,700 VND" 469-526 trong nút 467-528). Xem lỗi 1 về hàng "Open method" (không thuộc phần T10 sửa) |
| 3 | Maintenance: phiếu không gắn cảnh báo không hiện "#0" | **ĐẠT** | 16 phiếu (13 phiếu `alert_id NULL`): ô Alert trống, không có `#0` hay `id=0` trong HTML cả 2 trang. Phiếu 1, 2, 3 có link `#8`, `#10`, `#11`; bấm `#8` mở đúng "Alert #8: SENSOR_FAULT" |
| 4 | Khu OPS "Operations" / "Staff office, no locker slots" | **ĐẠT** | Trang Areas: `5 OPS Operations Staff office, no locker slots 0 31 Active`; ô chọn khu ở Locker banks "OPS – Operations", ở Users > Add user "OPS – Operations"; không còn chữ "Vận hành". Các khu khác giữ tên riêng tiếng Việt |
| 5 | Lỗi console | **ĐẠT** | `read_console_messages` (chỉ lỗi) rỗng trên Dashboard, bản đồ, Tủ của tôi, kiosk |

### Hồi quy nhanh

| Trang | Đã làm | Kết quả |
|---|---|---|
| Đăng nhập | Popup "Sign in to continue" trên bản đồ: chọn ô (triple-click), gõ `admin` / mật khẩu demo, Enter -> vào được | ĐẠT |
| Popup đặt ngăn | `t9user` (số dư 50,000 VND), B07 gói 2 hours, PIN -> "Confirm booking of slot B07": B07 CANT-B, M 40x40x40 cm, Taken now 6,500 VND, Balance after 43,500 VND, 4 dòng quy tắc (hoàn tiền 5 phút, tự bắt đầu sau 15 phút, phí trễ 4,900 VND/giờ cỡ M), nút "Book and pay 6,500 VND"; bấm "Back" đóng popup, không đặt | ĐẠT |
| Tủ của tôi | `t9user`: không có lượt, phần e-mail nhắc hạn, thẻ. `student3`: lượt A01 CANT-A quá hạn bị khóa (Late hours 7 h, Late fee 26,600 VND, 3,800 VND/giờ, Amount owed 0 VND), Show PIN -> 6 chữ số, nút đổi thành "Hide PIN" | ĐẠT |
| Kiosk `/k/LOCKER-08` | `t9user`: "Open locker LOCKER-08", "Account t9user has no open booking at this box...", ô PIN, hướng dẫn tiếng Anh. Không gõ PIN (tránh khóa trước Newman) | ĐẠT |
| Dashboard | Ô KPI, 3 donut, cột doanh thu, tooltip; tự làm mới 5 s không lỗi | ĐẠT |

## 3. Newman

Trước khi chạy: `test_setup.sql` trên `SL_T9` (qua `C:\sl-wt\t9\newman.ps1`, cùng bước với `scripts/proof/newman.ps1`, `base_url=http://localhost:8091/SmartLocker`).
Collection `docs/postman/SmartLocker-v2.postman_collection.json` với tên request tiếng Anh (bản dịch của T10).

| Mục | Số |
|---|---|
| Thư mục cấp 1 | 7 |
| Request | **241**, lỗi 0 |
| Test script | 241, lỗi 0 |
| Pre-request script | 19 |
| Assertion | **514**, lỗi **0** |
| Thời lượng | 2 phút 21,2 giây (newman), 145,0 giây tính cả khởi động |
| Thời gian phản hồi | trung bình 35 ms (min 3, max 330, s.d. 41) |

Lưu: `docs/paper/evidence/newman-5.json`, `newman-5.log` (CLI, bỏ mã màu, thêm 4 dòng đầu như `newman-4.log`). Log không còn chữ tiếng Việt nào (tên thư mục và request đều tiếng Anh, ví dụ "Heartbeat v2 (keeps the box online)", "Audit log: OVERDUE_ESCALATE of this booking").

## 4. Ảnh chụp lại

| Ảnh | Kích thước | Ghi chú |
|---|---|---|
| `docs/images/dashboard.png` | **1440x1040** (trước là 1440x960) | Cùng khung với bản bài; ở 960 dòng cuối chú giải ("Other (3 types)", y khoảng 955) sẽ bị cắt nên dùng 1040 cho cả README |
| `docs/paper/images/dashboard.png` | 1440x1040 | Cùng ảnh trên; chú giải 5 dòng hiện trọn, thấy đáy thẻ |
| `docs/paper/images/ui-user.png` | 893x618 | Script sinh lại, nguồn không đổi |
| `docs/paper/images/ui-staff.png` | 994x594 | Kiểm khung: ô KPI (728, 90, 1182, 246) trọn 2 ô "Open alerts" + "Offline devices"; donut (651, 605, 1025, 985) trọn thẻ, đủ 5 dòng chú giải và đáy thẻ; ba khung alert (262, ..., 730, ...) trọn tiêu đề, thẻ và dòng "Amount owed". **Không cần đổi hằng số crop** |

Cách chụp: Chrome headless qua `shot.mjs`, đăng nhập admin, viewport 1440x1040 DPR 1, theme sáng, chờ 6 s. Ngay trước khi chụp, T9b gửi **một heartbeat của LOCKER-01** (`POST /api/health`, khóa `device-1-api-key`, đúng body `{"firmware":"2.0","uptime_sec":60}` của request đầu Newman) vì heartbeat cuối của Newman đã quá 60 s và ô hiện "8/10" (LOCKER-01 "Unstable"). Đây là cùng tình trạng lúc T9 chụp (ngay sau Newman). Ảnh `alert-escalated.png` không chụp lại (vẫn ảnh của T9, #18).

### Số trong `ui-staff.png` so với caption (`smartlocker-10p.tex` dòng 816-818)

| Mục | Trong hình | Caption | Khớp? |
|---|---|---|---|
| Open alerts (ô KPI và tâm donut) | **11** | 12 | **Khác** |
| Offline devices | 1, "9/10 devices online" | one offline, 9 of 10 online | Khớp |
| Chú giải donut | SENSOR_FAULT 3, SUSPECTED_SPOOF 2, LOST_CARD_USED 2, ML_ANOMALY 1, Other (3 types) 3 (= OVERDUE_ESCALATED, FORCED_OPEN, ITEM_LEFT) | "open alerts by type" | Khớp (caption không nêu số) |
| Alert | #18 OVERDUE_ESCALATED, booking #122, user v3esc | #18 OVERDUE_ESCALATED | Khớp |
| Ngăn | CANT-A A12, due 13/11/2026 01:42 | CANT-A A12 | Khớp |
| Hours late | 50 h | 50 hours | Khớp |
| Late fee charged | 320,000 VND | 320 000 VND | Khớp |
| Amount owed | 128,500 VND (balance when escalated: -128,500 VND) | 128 500 VND | Khớp |

Vì sao 11: lúc T9 chụp, cảnh báo DEVICE_OFFLINE #13 (LOCKER-07) còn mở (12); T9 đã đánh dấu xử lý #13 sau khi chụp. Lần này Newman tự đóng DEVICE_OFFLINE của LOCKER-01 (#21, #23) khi máy gửi heartbeat lại, nên còn 11.
**Đề xuất cho agent bài**: sửa caption thành "11 open alerts" (không tạo cảnh báo giả để khớp số cũ). Có thể nói thêm rằng chú giải gộp các loại hiếm thành "Other".

Ghi chú dữ liệu: trên `SL_T9` hiện tại #18 đã RESOLVED và Newman tạo cảnh báo OVERDUE_ESCALATED mới #22 (kịch bản leo thang chạy lại sau `test_setup.sql`). Hình chỉ cắt tiêu đề, thẻ chứng cứ và các dòng số tiền của #18 (không cắt dòng Status), nên hình không mâu thuẫn; nếu sau này chụp lại `alert-escalated.png` trên DB này thì số cảnh báo sẽ là #22 chứ không phải #18.

## 5. Lỗi tìm thấy

| # | Mức | Vị trí | Mô tả, cách tái hiện | Đề xuất sửa |
|---|---|---|---|---|
| 1 | Thấp | `web/css/locker-map.css:1330` (`.seg-opt`), hàng "Open method" do `web/js/locker-map.js` (`reserveForm`) vẽ | Ở khổ khoảng 700 px (thẻ ngăn nổi bên phải, nút rộng 61 px), chữ "Fingerprint" (70 px, một từ, không xuống dòng được) tràn khỏi nút 5 px mỗi bên (chữ 592-662 trong nút 597-657) và chạm sang nút "Phone" bên cạnh (nút đó kết thúc ở 593). 1440x900 và 375 px không bị (70/70, vừa khít). Có từ trước, không do T10 (T10 chỉ đổi hàng gói) | Cho hàng phương thức mở cùng container như hàng gói và giảm cỡ chữ (ví dụ 11-12 px) khi nút < 72 px, hoặc dùng nhãn ngắn hơn ("Finger"), hoặc chuyển hàng này sang lưới 2 cột ở khổ hẹp |
| 2 | Thông tin | `docs/paper/smartlocker-10p.tex:816` | Caption ghi 12 open alerts, hình mới hiện 11 (xem mục 4) | Agent bài sửa thành 11 |

Không phải lỗi (đã kiểm lại):
- Ô "Devices" lúc đầu hiện "Unstable 1": LOCKER-01 có `health: DEGRADED`, `lastSeenSec: 87` (heartbeat cuối của Newman quá 60 s). Đúng thiết kế; một heartbeat mới đưa về Online.
- Ở 700 px, giá "6,500 VND" của gói 2 hours vẫn một dòng trong khi ba nút kia xuống dòng: chữ ngắn hơn 65.5 px nên không gãy; mọi nút vẫn cao bằng nhau (51 px), đúng mô tả của T10.

Các bản sửa T10 khác (MaintenanceDao, khu OPS, collection Postman, donut) không có lỗi mới.

## 6. Dữ liệu để lại trên SL_T9

Như sau T9 và thêm: một lần chạy `test_setup.sql` + Newman (lượt, cảnh báo #22, #23...), một heartbeat LOCKER-01 lúc 22:53:34 UTC. Không đặt ngăn, không gõ PIN.
`SL_T9` được giữ lại để chạy lại.

KẾT LUẬN: ĐẠT
