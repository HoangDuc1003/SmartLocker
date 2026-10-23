# Kế hoạch làm lại giao diện (v4): bản đồ + danh sách tủ gần → xa + dashboard biểu đồ

Trạng thái: **GĐ 0–3 đã làm xong** (hệ thiết kế bổ sung, dữ liệu khu + toạ độ, trang tủ có bản đồ, dashboard biểu đồ).
**GĐ 4–6 (trang người dùng, trang quản trị, rà soát toàn bộ) chưa làm**, chờ bạn duyệt giao diện GĐ 1–3.
Khác với bản nháp: Thư viện đặt gần **FPTU HCM** (theo yêu cầu), bản đồ không có sơ đồ SVG riêng mà dùng Leaflet không có ảnh nền
(lưới + ghi chú) khi mất mạng. Toạ độ KTX A (A14), KTX B, Nhà văn hóa Sinh viên lấy từ ghim Google Maps của bạn
(căng tin KTX A cùng chỗ, lệch ~30 m); chỉ thư viện FPTU HCM còn gần đúng. Bảng toạ độ ở mục 5 bên dưới là số cũ của bản nháp.
Khách vào thẳng trang tủ (không đăng nhập), hỏi vị trí ngay, popup đăng nhập/đăng ký khi đặt ngăn.

## 1. Bạn yêu cầu gì

1. Làm lại giao diện toàn bộ theo dạng web app trực quan (tham khảo ảnh FlowPilot: danh sách bên trái, bản đồ lớn bên phải).
2. Trang **tủ**: một bên là danh sách khu, **sắp từ gần nhất đến xa nhất**; bên cạnh có **bản đồ** sẵn.
3. **Dashboard**: dùng **biểu đồ** thay cho chữ và bảng khô khan.
4. Đặt tọa độ thật cho các khu:
   - Khu A: Ký túc xá khu A, ĐHQG-HCM
   - Khu B: Ký túc xá khu B, ĐHQG-HCM
   - Gym: Nhà văn hóa Sinh viên TP.HCM
   - Thư viện: (câu bạn viết bị cụt, xem mục 8)

## 2. Hiện trạng (đã đọc code)

| Thứ | Hiện có | Hệ quả cho kế hoạch |
|---|---|---|
| Sơ đồ tủ | `web/js/locker-map.js` (1415 dòng) + `locker-map.css`. Đã có định vị trình duyệt, `distanceTo`, `sortedAreas`, nhãn khoảng cách. **Chưa có bản đồ.** | Không viết lại logic gần/xa, chỉ đổi cách hiển thị và thêm bản đồ. |
| Tọa độ | `LockerArea.latitude/longitude` (sql/09_v3.sql) đang là **tọa độ giả quanh Hòa Lạc**, Hà Nội. | Phải thay bằng tọa độ TP.HCM. |
| Khu | `LIB, DOMA, CANT, GYM, OPS`. **Chưa có khu B.** | Thêm khu `DOMB` + vài dãy tủ mẫu. |
| Dashboard | `dashboard.jsp` + `dashboard.js`: thẻ KPI, 1 biểu đồ đường vẽ canvas (cảm biến), còn lại là **bảng** (khu, thiết bị, cảnh báo, lượt gửi). | Thêm biểu đồ thật, bảng chỉ còn là chi tiết phụ. |
| Ràng buộc dự án | Chạy offline, **không CDN**, không style màu inline, màu qua token `app.css`, chữ tiếng Việt, icon SVG, không "LIVE" giả. `/api/dashboard` không được query DB (lấy từ cache `LockerMonitor`). | Quyết định thư viện bản đồ và nơi đặt số liệu thống kê (mục 4, 6). |

## 3. Hướng thiết kế (rút từ ảnh mẫu)

- **Bố cục chia đôi** trên màn hình rộng: cột trái 380–420px (danh sách + bộ lọc), cột phải là bản đồ chiếm phần còn lại, cao hết màn hình. Chọn một khu ở bên nào thì bên kia cũng sáng lên theo (hai chiều).
- **Thẻ khu** (mỗi khu một thẻ): tên, địa điểm, **khoảng cách** ("320 m"), thanh/vòng **tỉ lệ ngăn trống**, nhãn trạng thái (Còn nhiều / Sắp hết / Hết / Có lỗi). Màu **không phải dấu hiệu duy nhất**: luôn kèm chữ hoặc biểu tượng.
- **Ghim trên bản đồ** cùng màu theo trạng thái, ghim ghi số ngăn trống; ghim vị trí của bạn có vòng sai số.
- Bấm một khu → bản đồ bay tới khu đó, mở **sơ đồ tủ** (các cabinet hiện có) ở dưới hoặc trong khung trượt. Các popup đặt chỗ/gia hạn giữ nguyên logic.
- **Điện thoại (375px)**: bản đồ ở trên (cao ~40vh), danh sách khu là bottom sheet kéo lên; có nút thay thế cho mọi thao tác kéo.
- Sáng/tối thiết kế cùng lúc qua token; tôn trọng `prefers-reduced-motion`; vùng bấm ≥ 44px; focus nhìn thấy rõ.
- Phong cách: sạch, nền sáng, thẻ bo góc, một màu nhấn xanh, ít đổ bóng. Không emoji, không hiệu ứng thừa.

## 4. Bản đồ: chọn cách làm

Cần bản đồ thật nhưng dự án cấm CDN và phải chạy offline.

| Phương án | Ưu | Nhược |
|---|---|---|
| **A (đề xuất)**: Leaflet **tải về đặt trong `web/js/vendor/leaflet/`** (không CDN) + nền ảnh từ OpenStreetMap | Bản đồ thật, kéo/zoom/ghim đẹp, nhẹ (~40 KB) | Ảnh nền cần Internet. Khi mất mạng tự **chuyển sang sơ đồ SVG** (mục dưới) |
| B: chỉ vẽ **sơ đồ SVG** từ tọa độ (không nền đường phố) | Hoàn toàn offline, không phụ thuộc ai | Trông không phải "bản đồ", khó định hướng |

Phương án A kèm **bản dự phòng SVG**: chiếu lat/lng lên khung, ghim và vị trí người dùng vẫn đúng, chỉ không có đường/tòa nhà. Ghi nguồn "© OpenStreetMap" trên bản đồ theo điều khoản. Ảnh nền chỉ là ảnh, không phải script, nên không vi phạm quy tắc "không CDN script"; nhưng đây vẫn là lệnh gọi ra ngoài nên cần bạn đồng ý (mục 8).

**Gần → xa**: giữ logic hiện có (Haversine trên trình duyệt, định vị bằng `navigator.geolocation`). Khi người dùng không cho phép vị trí: giữ thứ tự theo mã khu và hiện dòng "Bật vị trí để xếp theo khoảng cách" kèm nút; **không** gọi dịch vụ IP bên ngoài (`IpGeoLocator` vẫn để trống như hiện tại).

## 5. Tọa độ và dữ liệu khu

Tôi **không tra được tọa độ chính xác** (OpenStreetMap không trả kết quả cho các tên này), nên cột tọa độ bên dưới chỉ là điểm xuất phát **±500 m**, cần bạn thay bằng số thật. Cách lấy: Google Maps, bấm chuột phải đúng chỗ đặt tủ, bấm vào dòng số đầu tiên để chép "lat, lng".

| Mã khu | Tên hiển thị | Vị trí | lat, lng (tạm, cần xác nhận) |
|---|---|---|---|
| `DOMA` | Ký túc xá khu A | KTX khu A, ĐHQG-HCM (Đông Hòa, Dĩ An / Linh Trung, Thủ Đức) | 10.8830, 106.7810 |
| `DOMB` (**mới**) | Ký túc xá khu B | KTX khu B, ĐHQG-HCM | 10.8870, 106.7770 |
| `GYM` | Nhà văn hóa Sinh viên | Nhà văn hóa Sinh viên TP.HCM, Làng Đại học | 10.8790, 106.8000 |
| `LIB` | Thư viện | (giả định) Thư viện FPTU HCM | 10.8750, 106.8010 |
| `CANT` | Căng tin | (giả định) gần KTX khu A | gần `DOMA` |
| `OPS` | Vận hành | không có tủ, không hiện trên bản đồ | để trống |

Việc cần làm về dữ liệu (một file mới `sql/10_campus_vnu.sql`, chạy được nhiều lần, giữ BOM UTF-8, chạy bằng `sqlcmd -I`):
1. `UPDATE` tọa độ và tên/địa điểm tiếng Việt cho các khu trên (ghi đè tọa độ giả của 09_v3; chỉ ghi đè khi giá trị vẫn là giá trị giả Hòa Lạc).
2. Thêm khu `DOMB` + 1–2 dãy tủ + ngăn mẫu, kèm thiết bị mẫu. Mã dãy/ngăn/thiết bị là mã kỹ thuật, giữ như cũ.
3. Cập nhật `07_vietnamese_data.sql`/README nếu có chỗ nhắc "Hòa Lạc" hay tên khu cũ; chạy lại `sql/test_v3_setup.sql` để kiểm tra không vỡ dữ liệu test.
4. Form **Khu vực** (`lockerArea.jsp` / `LockerAreaController`): thêm hai ô nhập lat/lng (kiểm tra −90..90 và −180..180) để nhân viên tự sửa sau này, không cần SQL.

## 6. Dashboard bằng biểu đồ

Nguyên tắc: **mỗi biểu đồ trả lời một câu hỏi**, có tooltip, chú giải, và bảng dữ liệu thay thế cho người dùng đọc màn hình. Vẽ bằng SVG/canvas thuần (không thư viện, không CDN), màu lấy từ token.

| # | Biểu đồ | Trả lời câu hỏi | Dữ liệu |
|---|---|---|---|
| 1 | **Vòng (donut)** trống / đang dùng / lỗi + số lớn ở giữa | Còn bao nhiêu ngăn? | có sẵn trong snapshot |
| 2 | **Thanh ngang theo khu**, mỗi thanh chia 3 màu | Khu nào đầy nhất? | snapshot (có `areas`) |
| 3 | **Đường 24 giờ** số lượt gửi, hôm nay so với hôm qua | Giờ nào đông? | **mới**, cần truy vấn |
| 4 | **Bản đồ nhiệt thứ × giờ** (như "Average storage load" ở ảnh mẫu) | Khi nào tủ kín nhất? | **mới**, cần truy vấn |
| 5 | **Cột doanh thu 7 ngày** | Tiền thu vào mỗi ngày | **mới**, cần truy vấn |
| 6 | **Donut cảnh báo theo loại** + chấm cảnh báo trên thẻ KPI | Vấn đề đang là gì? | snapshot (`alerts`) |
| 7 | **Đồng hồ thiết bị online** (n/N) | Thiết bị còn sống không? | snapshot (`devices`) |
| 8 | Đường cảm biến hiện có, đổi sang style mới | Giữ nguyên chức năng | `/api/dashboard?device=` |
| 9 | **Sparkline nhỏ** trong thẻ KPI | Xu hướng nhanh | cùng nguồn #3 |

Các bảng (thiết bị, cảnh báo, lượt gửi gần đây) giữ lại nhưng **thu gọn** ở dưới, mở ra khi cần.

Quy tắc dự án: **không query DB trong `/api/dashboard`.** Các số liệu mới (#3, #4, #5, #9) sẽ nằm ở **endpoint riêng `/api/dashboard/stats`**, gộp một truy vấn tổng hợp và **cache 60 giây** trong bộ nhớ, trang gọi chậm hơn (mỗi 60 s), không đụng đường nóng của snapshot. Nếu chưa muốn thêm endpoint thì bỏ #3, #4, #5 và dashboard vẫn có 5 biểu đồ.

Hiển thị theo vai trò: người dùng thường không thấy tiền/cảnh báo của người khác (giữ đúng cách `LockerMapDao` lọc ở server); doanh thu chỉ cho ADMIN/OPERATOR.

## 7. Phạm vi "làm lại hết" và thứ tự làm

Làm theo từng giai đoạn, **mỗi giai đoạn chạy được và kiểm thử được trước khi sang giai đoạn sau**:

| GĐ | Nội dung | File chính |
|---|---|---|
| 0 | Hệ thiết kế: token màu/chữ/khoảng cách, thẻ, nhãn, chip lọc, donut/thanh, vỏ trang (sidebar + header), skeleton khi tải | `css/app.css`, `common/nav.jspf` |
| 1 | **Dữ liệu khu** + tọa độ + khu B + form sửa tọa độ | `sql/10_campus_vnu.sql`, `lockerArea.jsp`, `LockerAreaController`, `LockerAreaDao` |
| 2 | **Trang tủ**: chia đôi danh sách/bản đồ, Leaflet nội bộ + dự phòng SVG, đồng bộ hai chiều, bottom sheet trên điện thoại | `lockerMap.jsp`, `js/locker-map.js`, `css/locker-map.css`, `js/vendor/leaflet/*` |
| 3 | **Dashboard** biểu đồ + endpoint stats | `dashboard.jsp`, `js/dashboard.js`, `DashboardDao`, `api/DashboardApi` (hoặc `api/DashboardStatsApi` mới) |
| 4 | **Trang người dùng**: Tủ của tôi, Nạp tiền, Đăng nhập/Đăng ký, Cảnh báo | `myLocker.jsp`, `topup.jsp`, `login.jsp`, `register.jsp`, `alert.jsp` + `js/my-locker.js` |
| 5 | **Trang quản trị** (CRUD: khu, dãy, ngăn, gói, thẻ, người dùng, vai trò, nhật ký...): đổi sang bảng/thẻ/biểu mẫu chung, không đổi chức năng | các `*.jsp` còn lại |
| 6 | Rà soát: sáng/tối, 375px, bàn phím, giảm chuyển động, tương phản, ngoại tuyến | toàn bộ |

Không đụng: bảng giá `util.Pricing`/`AppConfig`, luồng mở tủ, API thiết bị, quy tắc quá hạn. Chỉ thay lớp hiển thị và thêm phần dữ liệu/thống kê nêu trên. Tên tham số form và `data-confirm` giữ nguyên để không vỡ controller.

## 8. Cách kiểm thử (theo quy trình của dự án)

- Chạy thật trong Chrome (claude-in-chrome): mọi nút, mọi API mà trang gọi; sửa → test lại đến khi qua. Hard reload (Ctrl+Shift+R) sau mỗi lần triển khai; chờ ~15 s sau khi đụng `SmartLocker.xml`.
- Bản đồ: cho phép vị trí → thứ tự đổi theo khoảng cách; từ chối → còn thứ tự mặc định + nút bật vị trí; ngắt mạng → chuyển sang sơ đồ SVG; bấm ghim ↔ bấm thẻ khu đồng bộ.
- Dashboard: dữ liệu rỗng (khu chưa có lượt gửi) hiện trạng thái rỗng có hướng dẫn, không phải khung trống; tooltip bằng bàn phím; bảng thay thế đúng số.
- Không có popup nào bị làm mới giữa chừng (quy tắc "popup đóng băng làm mới" trong bài học); không rò kết nối JDBC.
- Chạy lại `PricingTest`, `PricingDatabaseIntegrationTest`, `sql/test_v3_setup.sql`.
- Sau mỗi giai đoạn: agent khác review chéo, trả kết quả, lặp đến khi qua.

## 9. Cần bạn xác nhận (không có thì tôi dùng giả định ghi bên cạnh)

1. **Thư viện ở đâu?** Câu của bạn bị cụt ("còn thư viện và…"). Giả định: Thư viện FPTU HCM.
2. **Căng tin** không được nhắc. Giả định: đặt gần KTX khu A.
3. **Tọa độ chính xác** của 4 điểm (tôi chỉ có số gần đúng ±500 m ở mục 5). Bạn gửi "lat, lng" từ Google Maps thì tôi thay luôn.
4. **Bản đồ nền từ OpenStreetMap cần Internet** (có dự phòng offline). Đồng ý với phương án A? Nếu demo luôn không có mạng thì chọn B.
5. **Endpoint `/api/dashboard/stats` mới** cho biểu đồ theo giờ/doanh thu: đồng ý? Nếu không, dashboard chỉ có 5 biểu đồ từ dữ liệu hiện có.
6. **Phạm vi:** làm đủ GĐ 0–6 (tất cả trang), hay ưu tiên GĐ 0–3 (tủ + dashboard) trước rồi mới tới các trang còn lại? Tôi đề xuất **GĐ 0–3 trước**, vì đó là phần bạn nhắc rõ; GĐ 4–5 làm tiếp sau khi bạn duyệt giao diện.
7. **Khu B**: dữ liệu mẫu (vài dãy tủ + ngăn) là dữ liệu demo, đúng không?
