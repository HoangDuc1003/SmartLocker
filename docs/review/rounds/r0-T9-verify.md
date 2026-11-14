# r0 T9: kiểm chứng cuối (DB mới, TestNG, Newman, E2E, ảnh tiếng Anh)

Ngày chạy: 2026-11-14/15 (giờ máy UTC+7). HEAD `13ba35f` + toàn bộ cây đang sửa, **chưa commit** (không commit gì).
Agent T9 không sửa mã nguồn. Tệp T9 đã ghi: `docs/images/*.png` (16 ảnh), `docs/paper/images/{map-area,booking-confirm,dashboard,alert-escalated,map-visitor,kiosk-phone,my-locker-pin,alerts}.png`,
`docs/paper/images/ui-user.png`, `ui-staff.png` (do script sinh), 2 hằng số crop trong `docs/paper/tools/make_ui_figs.py` (xem mục 5),
`docs/paper/evidence/testng-4.log`, `newman-4.json`, `newman-4.log`, và báo cáo này.

## 1. Môi trường

| Mục | Giá trị |
|---|---|
| CSDL | `SL_T9`, dựng bằng `scripts\proof\build-db.ps1 -Repo . -Database SL_T9 -Also @('06_english_messages.sql','test_setup.sql')` |
| Thứ tự script | `build-order.txt` (01, 02, 03, 04, 05), rồi 06, rồi `test_setup.sql`. **`build-order.txt` không có 06**: đúng ý đồ (03 mới tự seed tiếng Anh, 06 chỉ dành cho DB cũ) nên tôi chạy 06 bằng `-Also` |
| Tomcat test | Của riêng T9: `CATALINA_BASE=C:\sl-wt\tomcat-t9`, cổng 8091 (shutdown 8025), dùng chung chương trình `E:\apache-tomcat-9.0.113`, `DB_URL` trỏ `SL_T9`. Đã tắt khi xong |
| Vì sao không dùng `test-stack.ps1` | Script dừng vì repo có `config/mail.local.properties` (cấu hình mail thật của chủ dự án). T9 dựng ứng dụng vào `C:\sl-wt\t9\app\web` (ngoài repo, nên `MailService` không tìm thấy tệp đó) và đặt thêm `-Dsmartlocker.mailConfig` vào một tệp rỗng. Log: `Due reminder e-mails off, no mail settings found` |
| Tomcat 8080 của chủ | Không đụng (cổng 8080 đóng suốt buổi). `PRJ301_LOCKER` create_date vẫn `2026-11-07 08:09:43` sau mọi bước |
| Trình duyệt | Built-in browser (E2E tay) + Chrome headless qua CDP (`C:\sl-wt\t9\shot.mjs`, Node 24) cho ảnh PNG đúng 1440x900, DPR 1, theme sáng; ảnh điện thoại 390x844 DPR 2 |
| Kịch bản phụ | `C:\sl-wt\t9\stack.ps1` (bật/tắt Tomcat T9), `C:\sl-wt\t9\newman.ps1`, `C:\sl-wt\t9\s*.json` (các bước E2E/ảnh), `C:\sl-wt\t9\vi_scan.sql` (quét chữ Việt trong DB). `SL_T9` được giữ lại để chạy lại |

### Chạy lại 06 theo yêu cầu orchestrator (03 cũ đã biến tên dãy thành "Dãy A")

`sqlcmd -S localhost -U sa -P 12345 -d SL_T9 -I -b -f 65001 -i <đường dẫn Windows của sql\06_english_messages.sql>`

| Lần | PRINT |
|---|---|
| Lần 1 (sau khi orchestrator sửa 06) | StoragePlan 0, SlotSize 0, TopupRequest 0, AlertEvidence 0, MaintenanceTicket notes 0, sensor notes 0, closed rounds 0, RemoteCommand 0, **LockerBank names translated: 8**, **System account name translated: 1**; exit 0 |
| Lần 2 (kiểm tra chạy lại an toàn) | Tất cả 0; exit 0 |

Sau đó: 10 dãy đều tên `Bank A`/`Bank B` (trang Locker banks và bản đồ hiển thị đúng), `Users.full_name` của `system` = `System account`.
Trang Audit log hiện cột Actor bằng **username** `system` (không phải full name), nên chữ "System account" không xuất hiện ở đó; không sai.
Ảnh chụp đều chụp **sau** lần chạy 06 này, không ảnh nào còn "Dãy".

Quét toàn bộ cột nvarchar của `SL_T9` tìm chữ có dấu tiếng Việt: chỉ còn `LockerArea.name/location` (6), `Device.location` (10), `Users.full_name` (107) là tên riêng seed (được phép),
`RemoteCommand.reason` (4, "Chạm điện thoại": được dịch lúc hiển thị bởi `RemoteCommandDao.reasonText`, trang hiện tiếng Anh), và `AppConfig.note` (14, không trang nào hiển thị).

## 2. TestNG

Lệnh: `DB_URL='jdbc:sqlserver://localhost:1433;databaseName=SL_T9;encrypt=false' sh scripts/test.sh` (Git Bash). Log: `docs/paper/evidence/testng-4.log`.

| Lớp test | 14 |
|---|---|
| @Test (đếm `^\s*@Test`) | 83 |
| Tests run | 83 |
| Passes | 83 |
| Failures | 0 |
| Skips | 0 |
| Thời gian | 2 phút 10 giây |

Khớp con số 83 của bài. Không có lỗi nên không có gì do bản dịch gây ra.

## 3. Newman (Postman)

Trước khi chạy: `test_setup.sql` trên `SL_T9`. Lệnh tương đương `scripts/proof/newman.ps1` nhưng `base_url=http://localhost:8091/SmartLocker` (`C:\sl-wt\t9\newman.ps1`).
Log: `docs/paper/evidence/newman-4.log` (CLI, đã bỏ mã màu) và `newman-4.json`.

| Mục | Số |
|---|---|
| Thư mục (kịch bản cấp 1) | 7 |
| Request (gồm vòng lặp) | 241, lỗi 0 |
| Test script | 241, lỗi 0 |
| Pre-request script | 19 |
| Assertion | 514, lỗi 0 |
| Thời lượng | 2 phút 22,2 giây (newman), 149,5 giây tính cả khởi động |
| Thời gian phản hồi | trung bình 23 ms (min 2, max 682, s.d. 56) |

Lưu ý: `scripts/proof/README.md` còn ghi "221 request, 472 assertion" (số cũ).

## 4. E2E trên trình duyệt

Cách kiểm: mỗi trang được mở và quét bằng script (chữ có dấu tiếng Việt trong text, `placeholder`, `title`, `aria-label`, `data-confirm`, `option`; nút/tiêu đề bị tràn hoặc xuống dòng; cuộn ngang; lỗi JS),
cùng thao tác thật trên built-in browser và Chrome headless. Lỗi console: chỉ có `ERR_NAME_NOT_RESOLVED` của các máy chủ ô bản đồ dự phòng (đã biết, `area-map.js` tự đổi máy chủ); không lỗi JS nào.

| Vai | Đã làm | Kết quả |
|---|---|---|
| Khách | Bản đồ, danh sách khu, mở khu CANT, thẻ ngăn A03 (giá theo cỡ, "6,500 VND"), "Sign in to book", popup đăng ký (lỗi "The passwords do not match"), đăng ký `t9user` thành công và tự đăng nhập, link `/c/<token sai>` ("Invalid link ...") | Đạt |
| Người dùng | Nạp tiền (chọn 50,000 VND, tạo VietQR, lịch sử), Tủ của tôi (trống / có lượt), đặt B07: gói 2 giờ, Custom theo giờ (3 h, 9,900 VND), theo ngày (2 ngày, 58,500 VND, "saving 6,500 VND"), popup xác nhận, đặt thật (113,500 VND còn lại), hiện/ẩn PIN, popup hủy ("The full 6,500 VND goes back") và hủy thật (hoàn 6,500 VND), popup gia hạn của `v2noshow` ("Extend by 2 hours? 6,600 VND ..."), lượt quá hạn bị khóa của `student3` (5 h x 3,800 = 19,000 VND), trang `/k/LOCKER-08` (có lượt: "Open my locker"; không có lượt: PIN sai -> "Wrong PIN. 4 tries left.") | Đạt |
| Admin | Dashboard, Alerts (lọc, chi tiết #18, #20, đánh dấu đã xử lý #13), Audit (xác minh chuỗi: "The hash chain is intact"), Users (tạo `t9staff`: "created with the default password 123456"), Roles (lưu quyền END_USER), Areas/Banks/Slots/Plans: tạo, trùng mã ("Area code T9A already exists"), xóa ngăn, xóa gói, xóa khu còn dãy ("The area still has locker banks or users; set it to inactive ..."), RFID cards (cấp thẻ A9C4D201), Bookings (sửa #133: "Booking #133 updated"), Remote unlock ("Command #19 queued; the slot opens in about 10 seconds."), Calibration (thêm), Maintenance (danh sách), Sensor data, Top-up review (duyệt #57: "Money added to account t9user.", từ chối #9: "Top-up request #9 rejected."), 8 nút Export CSV (đều 200, `text/csv`, tiêu đề cột tiếng Anh), bản đồ nhân viên | Đạt |
| Operator (`operator1`) | Quét 12 trang nhân viên: đều 200, không chữ Việt ngoài tên riêng | Đạt |
| Auditor, Technician | Đăng nhập được; chưa kiểm từng trang (thiếu thời gian) | Chưa kiểm hết |

Chữ tiếng Việt còn thấy trên giao diện: chỉ tên khu, địa chỉ, tên thiết bị/người dùng seed (được phép), và khu `OPS` "Vận hành / Văn phòng nhân viên, không có ngăn tủ" (xem lỗi 6).
Tiền đúng dạng "12,000 VND"; ngày giờ dạng `15/11/2026 02:47` (dd/MM/yyyy, giờ địa phương); ô ngày của trình duyệt hiện `mm/dd/yyyy` theo locale của trình duyệt.

## 5. Ảnh chụp lại (tiếng Anh)

README (`docs/images/`, giữ tên và khung cũ): `map-visitor`, `map-area`, `booking-plan`, `booking-custom-hours`, `booking-custom-days`, `booking-confirm`, `locker-banks`, `alerts`,
`alert-escalated`, `sensor-data` (1440x900), `dashboard` (1440x960), `my-locker-pin`, `my-locker-extend`, `my-locker-overdue` (1440x1150), `map-phone`, `kiosk-phone` (780x1688).

Bài (`docs/paper/images/`): `map-area`, `booking-confirm`, `alert-escalated`, `map-visitor`, `alerts` (1440x900), `my-locker-pin` (1440x1150), `dashboard` (**1440x1040**, để thấy dòng
OVERDUE_ESCALATED của chú giải), `kiosk-phone` (390x735, thu nhỏ từ ảnh điện thoại; bài không dùng ảnh này).

`python -I docs/paper/tools/make_ui_figs.py`: `ui-user.png` 893x618, `ui-staff.png` 994x594. Đã kiểm từng khung:

| Ảnh | Khung | Kết quả |
|---|---|---|
| map-area | (20, 85, 401, 640) | Đúng: tiêu đề khu tới dòng tóm tắt dưới Bank A |
| booking-confirm | (500, 165, 940, 735) | Đúng: trọn popup |
| dashboard ô KPI | (728, 90, 1182, 246) | Đúng: "Open alerts" + "Offline devices" |
| dashboard donut | (651, 605, 1025, 960) -> **(651, 605, 1025, 985)** | Đã sửa hằng số: ảnh cao 1040, 960 cắt mất nửa dòng OVERDUE_ESCALATED và đáy thẻ |
| alert tiêu đề / thẻ / dòng | (262, 22/337/408, **700**, ...) -> phải **730** | Đã sửa 3 hằng số: câu tiếng Anh "(balance when escalated: -128,500 VND)" dài hơn và bị cắt ở 700 |

Docstring của script vẫn ghi dashboard 1440x960 và hình rộng khoảng 900 px: T2b nên cập nhật (ui-staff giờ rộng 994 px).

### Số trong hai hình (để sửa caption, hiện caption trong .tex còn số cũ: 23 of 27, 11 alerts, 10 of 10, #119)

- **ui-user**: khu "Căng tin KTX khu A": **22 free slots / 27 total**; chip Available 22, Occupied 1, Overdue 3, Alert 1; Bank A CANT-A · LOCKER-01 Online; dòng tóm tắt "10 free · 4 in use · 3 locked overdue · 1 to check" (A01, A05, A12 khóa quá hạn, A06 cảnh báo).
  Popup "Confirm booking of slot **B07**": B07 CANT-B, size M 40x40x40 cm, plan 2 hours, PIN, Taken now **6,500 VND**, Balance after **113,500 VND**, phí trễ 4,900 VND mỗi giờ (cỡ M), nút "Book and pay 6,500 VND".
- **ui-staff**: Open alerts **12**; Offline devices **1** ("9/10 devices online"); donut "12 open": SENSOR_FAULT 3, SUSPECTED_SPOOF 2, LOST_CARD_USED 2, ML_ANOMALY 1, OVERDUE_ESCALATED 1 (tổng chú giải 9, xem lỗi 1).
  "Alert **#18**: OVERDUE_ESCALATED": booking #122, user v3esc, slot CANT-A **A12**, due 13/11/2026 01:42, Hours late **50 h**, Late fee charged **320,000 VND**, Amount owed **128,500 VND** (balance when escalated: -128,500 VND).
  Thiết bị offline là LOCKER-07 (ví dụ seed, cảnh báo DEVICE_OFFLINE #13 mà T9 đã đánh dấu xử lý sau khi chụp; thiết bị vẫn OFFLINE).

## 6. Số đếm cho bài

| Mục | Số | Cách đếm |
|---|---|---|
| Tệp `.java` trong `src/java` | 89 | `find src/java -name '*.java' \| wc -l` |
| Dòng vật lý Java | 11 764 | `cat` tất cả rồi `wc -l` (cùng cách `code-stats-2.log`) |
| Theo gói | api 10/1 107, controller 25/3 024, dao 22/4 730, filter 1/226, ml 0/0, model 12/522, service 14/1 740, util 5/415 | tệp/dòng |
| JSP | 22 (thêm 4 `.jspf`) | `find web -name '*.jsp'` |
| @Test | 83 | 14 lớp: AuditChain 4, AuditFlood 6, AuthText 3, AutoCheckIn 5, CardMail 4, DeviceBank 3, LockerSessionList 7, MailTemplates 5, PhoneTap 5, PricingDatabase 6, Pricing 15, RiskScorer 1, RuleEngine 14, SecurityUtils 5 |
| HEAD | `13ba35f`, cây chưa commit | `git rev-parse --short HEAD` |

## 7. Lỗi tìm thấy

| # | Mức | Vị trí | Mô tả, cách tái hiện | Đề xuất sửa | Do bản dịch? |
|---|---|---|---|---|---|
| 1 | TB | `web/js/dash-charts.js:167` | Donut "Open alerts" chỉ vẽ 5 loại đầu (`rows.slice(0, 5)`) nhưng tâm ghi tổng 12. Trên SL_T9 thiếu DEVICE_OFFLINE, FORCED_OPEN, ITEM_LEFT (3 cảnh báo); 5 cung vẫn kín vòng nên tỉ lệ sai, tổng chú giải 9 khác 12. Hình ui-staff của bài cho thấy đúng chỗ này | Gộp phần còn lại thành dòng "Other" (tổng các loại sau vị trí 5) | Không (có sẵn ở HEAD) |
| 2 | Thấp | `src/java/dao/MaintenanceDao.java:65` | `rs.getInt("alert_id")` trả 0 khi NULL nên trang Maintenance hiện "#0" và link `AlertController?id=0` cho mọi phiếu không gắn cảnh báo | `int a = rs.getInt("alert_id"); map.put("alert_id", rs.wasNull() ? null : a);` | Không |
| 3 | Thấp | `web/js/locker-map.js` / `area-map.js` (vẽ pin) | CANT và DOMA cách nhau ~30 m: ở mức zoom toàn thành phố, vòng số của pin này đè lên nhãn của pin kia ("21" cạnh nhãn "Căng tin KTX khu A" trong khi danh sách ghi 22) | Gom pin trùng chỗ, hoặc ẩn nhãn pin bị che | Không |
| 4 | Thấp | CSS nút chọn gói trên thẻ ngăn (`web/css/locker-map.css`) | "4 hours 11,700 VND" và "Day pass 32,500 VND" xuống 3 dòng vì " VND" dài hơn "đ"; "2 hours 6,500 VND" chỉ 2 dòng nên các nút không đều (thấy trong `docs/images/booking-plan.png`) | Cho giá `white-space: nowrap` và cỡ chữ nhỏ hơn, hoặc bỏ " VND" trong nút (đơn vị đã có ở "Taken now") | Có (chuỗi dài hơn) |
| 5 | Thấp | `docs/postman/SmartLocker-v2.postman_collection.json` | Còn 223 dòng `"name"` có chữ tiếng Việt (tên request, mô tả, ví dụ "Nhật ký: OVERDUE_ESCALATE của lượt này", "Gọi đầu tiên để LOCKER-01 ..."). r1 đã giao T6, lúc T9 chạy vẫn chưa xong | Dịch tên và mô tả; assertion không đổi | Còn sót |
| 6 | Thấp | `sql/02_data_v1.sql` (seed khu OPS) | Khu `OPS` tên "Vận hành", địa chỉ "Văn phòng nhân viên, không có ngăn tủ" hiện ở trang Areas và mọi ô chọn khu (Banks, Users). Đây là từ thường, không phải địa danh | Seed "Operations" / "Staff office, no lockers" trong 02 và thêm UPDATE tương ứng vào 06 | Còn sót |
| 7 | Thông tin | `AppConfig.note` (14 dòng) | Ghi chú tiếng Việt trong DB, không trang nào hiển thị | Tùy chọn dịch trong 03/06 | - |

Không phải lỗi (đã kiểm lại):
- Từ chối nạp tiền: hai lần đầu bấm OK trong popup không gửi form; lần đầu OK được bấm bằng script. Với cú bấm thật trên trang mới tải, từ chối #9 và #10 đều chạy (`TopupRequest` 10 = REJECTED). Không tái hiện được.
- Cấp thẻ với UID `T9CARD01` không gửi: ô có `pattern` hex, trình duyệt chặn đúng.
- Toast "The map background could not load (needs Internet)" có trong DOM dù ô bản đồ đã tải: phần tử bị ẩn, không hiện trên ảnh.

## 8. Dữ liệu thử để lại trên SL_T9

Tài khoản `t9user` (mật khẩu demo), `t9staff`, khu `T9A`, dãy `T9A-A`, thẻ `A9C4D201`, hiệu chuẩn #12, lệnh mở #19; LOCKER-08 có 1 lần PIN sai của `t9user`.
Chạy `test_setup.sql` trước Newman như thường lệ.
