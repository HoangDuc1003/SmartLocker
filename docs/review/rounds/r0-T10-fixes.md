# r0 T10: sửa lỗi sau kiểm chứng T9

Ngày: 15/11/2026. Nguồn lỗi: `docs/review/rounds/r0-T9-verify.md` mục 7. Không commit gì. Không đụng Tomcat 8080, `PRJ301_LOCKER`
(create_date vẫn `2026-11-07 08:09:43`), `docs/paper/*.tex`, `overleaf_package/`, `scripts/generate_clean_main.py`.

## 1. Đã sửa

| # | Lỗi T9 | Tệp | Cách sửa |
|---|---|---|---|
| 1 | Lỗi 1 (TB): donut "Open alerts" chỉ vẽ 5 loại đầu, chú giải cộng không ra số ở tâm | `web/js/dash-charts.js` (`drawAlerts`) | Bảng màu chỉ có 5 lớp (`CAT`: `seg-bad`, `seg-warn`, `seg-use`, `seg-ok`, `seg-mute`). Nếu có hơn 5 loại: giữ 4 loại đầu (dữ liệu đã sắp theo số lượng giảm dần trong `DashboardDao`), phần còn lại gộp thành dòng **"Other (N types)"** màu `seg-mute`. Không quá 5 loại thì vẽ như cũ. Tổng các cung và chú giải luôn bằng số ở tâm. Không thêm màu inline; donut giữ `r = 15`, nét 5 (hover 6): 15 + 3 = 18 <= 36/2 |
| 2 | Lỗi 4 (thấp): nút gói trên thẻ ngăn xuống 3 dòng ("4 hours 11,700 VND") trong khi "2 hours" 2 dòng | `web/js/locker-map.js` (`reserveForm`), `web/css/locker-map.css` | Giá của gói và chữ "Hours / days" của nút Custom có thêm lớp `seg-opt__sub--line`: cỡ 11px, `white-space: nowrap`, nên mọi nút gói đều đúng 2 dòng. Mỗi `.seg-opt` có nút như vậy là một container (`container: seg-opt / inline-size`); khi nút hẹp hơn chữ (`@container seg-opt (max-width: 65.5px)`, ví dụ màn tablet 640-760 px hoặc nhiều gói hơn) chữ được xuống dòng lại thay vì tràn sang nút bên cạnh. Đo bằng Chrome headless (font Segoe UI của máy này): khung gói rộng 302 px (thẻ ngăn desktop) và 343 px (điện thoại) đều 44 px cao, mọi chữ một dòng ("11,700 VND" 62 px, "Hours / days" 66 px trong 66,5 px); 270 px thì xuống dòng có chủ đích |
| 3 | Lỗi 2 (thấp): phiếu bảo trì không gắn cảnh báo hiện "#0" và link `AlertController?id=0` | `src/java/dao/MaintenanceDao.java` (`list`) | `int alertId = rs.getInt("alert_id"); map.put("alert_id", rs.wasNull() ? null : alertId);`. `web/WEB-INF/views/maintenance.jsp` dòng 39 đã có `<c:if test="${not empty t.alert_id}">` nên ô Alert để trống, không có link. Không lớp nào khác đọc map này (không có CSV bảo trì) |
| 4 | Lỗi 5 (thấp): collection Postman còn tên/mô tả tiếng Việt | `docs/postman/SmartLocker-v2.postman_collection.json` | Dịch 243 chuỗi: 223 `name` + 16 `description` có dấu, và 4 tên không dấu ("Sai API key -> 401", "auth sai key -> 401", "heartbeat sai key -> 401", "heartbeat body sai -> 400"). Tiền viết "5,000 VND". Thay bằng so khớp chuỗi JSON nên định dạng tệp giữ nguyên; script kiểm tra cây JSON trước/sau giống hệt nhau ngoài `name`/`description` (request, body, script test, assertion không đổi). Bản dịch là song ánh (không hai tên Việt khác nhau thành cùng một tên Anh). 4 request tự lặp bằng `postman.setNextRequest(pm.info.requestName)` vẫn có tên duy nhất. Sau khi sửa: JSON hợp lệ, 0 ký tự có dấu tiếng Việt trong tệp, 7 thư mục cấp 1, 26 thư mục, 231 request |
| 5 | Lỗi 6 (thấp): khu `OPS` "Vận hành / Văn phòng nhân viên, không có ngăn tủ" | `sql/03_v2_v3.sql`, `sql/06_english_messages.sql` | Chữ tiếng Việt **không nằm trong `02_data_v1.sql`**: `01_schema.sql` seed `OPS` bằng tiếng Anh ("Operations", "Staff office, no locker slots"), chính khối "Areas: name and location" của `03` đổi sang tiếng Việt. Đã bỏ dòng `OPS` khỏi cả hai `VALUES` trong 03 (các địa danh LIB, DOMA, CANT, GYM vẫn tiếng Việt). Thêm vào 06, trong transaction trước `COMMIT`, hai UPDATE khớp đúng chữ cũ (`area_code = 'OPS' AND name = N'Vận hành'`, `... AND location = N'Văn phòng nhân viên, không có ngăn tủ'`) với PRINT riêng; sửa luôn ghi chú đầu tệp 06. Cả hai tệp còn BOM UTF-8 |
| 6 | Docstring hình bài | `docs/paper/tools/make_ui_figs.py` | Chỉ docstring: hình dưới khoảng 1000 px (ui-user 893 x 618, ui-staff 994 x 594), dashboard 1440 x 1040, tên tiếng Anh ("Dashboard", "Open alerts", "Offline devices"), cảnh báo OVERDUE_ESCALATED là #18 trên DB test 15/11. Không đổi hằng số crop |
| 7 | Số đếm cũ | `scripts/proof/README.md`, `README.md`, `README.en.md` | proof README: "241 request (231 mục cộng các vòng lặp), 514 assertion, không lỗi, khoảng 142 giây (lần chạy 15/11/2026, `newman-4.log`)"; ngày tạo `PRJ301_LOCKER` ghi 2026-10-28 đã sửa thành 2026-11-07 08:09:43 cho khớp `lib.ps1`. README.md/README.en.md: bảng kiểm thử (dòng 460-461) đã đúng 83/83, 14 lớp, 241/514; sửa dòng "Đánh giá"/"Evaluation" của mục bài báo (dòng 616) từ "66 test TestNG, 472 assertion" thành "83 ... 514". Chỉ đổi số |

Không sửa (ngoài phạm vi T10): lỗi 3 của T9 (pin CANT/DOMA đè nhãn) và lỗi 7 (`AppConfig.note`).

## 2. Kiểm tra đã chạy

| Kiểm tra | Kết quả |
|---|---|
| JDK 8 (`jdk1.8.0_202`) biên dịch toàn bộ `src/java` vào `scratchpad/t10/classes`, classpath `servlet-api.jar;jsp-api.jar;web/WEB-INF/lib/*;lib/*` | exit 0 |
| `node --check web/js/dash-charts.js`, `web/js/locker-map.js` | OK |
| Khối 03 đã sửa: biên dịch trên `SL_T9` với `SET NOEXEC ON` | OK |
| `sqlcmd -S localhost -U sa -P 12345 -d SL_T9 -I -b -f 65001 -i <đường dẫn Windows của sql\06_english_messages.sql>`, lần 1 | 10 dòng PRINT cũ đều 0; **OPS area name translated: 1**, **OPS area location translated: 1**; exit 0 |
| Cùng lệnh, lần 2 | 12 dòng PRINT đều 0; exit 0 |
| `LockerArea` OPS trên `SL_T9` sau đó | `Operations` / `Staff office, no locker slots` |
| Collection Postman | Xem dòng 4 ở trên. Chưa chạy lại Newman (chỉ đổi tên, assertion giữ nguyên) |

## 3. Việc cho agent kiểm chứng trên trình duyệt (Tomcat riêng, DB `SL_T9`)

Cần build lại (`MaintenanceDao` là lớp Java: context reload, đăng nhập lại) và tải cứng (Ctrl+Shift+R) vì đổi CSS/JS.

1. **Dashboard** (admin), thẻ "Open alerts": nếu số loại cảnh báo đang mở > 5, chú giải có đúng 5 dòng: 4 loại nhiều nhất + "Other (N types)" màu xám (`seg-mute`), cung xám tương ứng trên donut, tooltip của cung xám "Other (N types): x (y%)". **Cộng 5 số trong chú giải phải bằng số ở tâm.** Nếu chỉ còn <= 5 loại (T9 đã xử lý #13), tạo thêm cảnh báo mở hoặc kiểm bằng dữ liệu `/api/dashboard/stats` (`alertsOpen`) để thấy nhánh "Other". Kiểm cả theme tối. Hình `docs/images/dashboard.png`, `docs/paper/images/dashboard.png` và `ui-staff.png` cần chụp lại sau sửa (chú giải đổi; vẫn 5 dòng nên khung crop donut có lẽ giữ được, nhưng nên kiểm lại; caption trong .tex do agent bài lo).
2. **Bản đồ người dùng**, khu CANT, thẻ ngăn B07 (cỡ M) ở 1440 x 900: 4 nút gói "2 hours / 6,500 VND", "4 hours / 11,700 VND", "Day pass / 32,500 VND", "Custom / Hours / days" đều đúng 2 dòng, cao bằng nhau, chữ không tràn ra ngoài nút. Lặp lại ở 375 px (bottom sheet, preset mobile) và ở khoảng 700 px (tablet: chữ được phép xuống dòng, nhưng không được đè sang nút bên). Chọn từng gói vẫn đổi "Taken now" như trước.
3. **Maintenance** (admin/technician): phiếu không gắn cảnh báo có ô Alert trống (không "#0", không link `AlertController?id=0`); phiếu có cảnh báo vẫn có link "#n" mở đúng chi tiết.
4. **Areas** và các ô chọn khu (Banks, Users): khu `OPS` hiện "Operations", địa chỉ "Staff office, no locker slots"; các khu khác vẫn tên riêng tiếng Việt.
5. (Tùy chọn) Newman: `test_setup.sql` rồi chạy lại collection; kỳ vọng vẫn 241 request, 514 assertion, 0 lỗi, tên request trong báo cáo là tiếng Anh.

## 4. Tệp đã sửa

- `web/js/dash-charts.js`, `web/js/locker-map.js`, `web/css/locker-map.css`
- `src/java/dao/MaintenanceDao.java`
- `docs/postman/SmartLocker-v2.postman_collection.json`
- `sql/03_v2_v3.sql`, `sql/06_english_messages.sql`
- `docs/paper/tools/make_ui_figs.py` (docstring)
- `scripts/proof/README.md`, `README.md`, `README.en.md` (số đếm)
- Báo cáo này
