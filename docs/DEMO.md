# Kịch bản demo SmartLocker

Khoảng 20 phút, đi theo vòng đời một lượt gửi rồi sang phía nhân viên. Mỗi cảnh ghi **làm gì**, **nói gì** và **cần thấy gì**.
Mật khẩu mọi tài khoản demo: `123456`.

## 0. Chuẩn bị (trước giờ demo)

| Việc | Lệnh / thao tác |
|---|---|
| Dựng lại DB sạch | `powershell -ExecutionPolicy Bypass -File .\run_demo_db.ps1` |
| Gắn hộp thật vào dãy | Sửa 4 biến đầu `sql/demo_box.sql` (mặc định dãy `LIB-A`, ngăn servo `A01`) rồi chạy |
| Build và chạy web | `sh scripts/build-dev.sh`, chờ 15 giây, mở `http://localhost:8080/SmartLocker/` |
| Hộp ESP32 | Cắm điện, bấm `D` trên keypad: LCD phải báo máy chủ OK. Trên trang Dãy tủ, `LOCKER-01` là ACTIVE |
| Trình duyệt | Mở 2 cửa sổ: thường (người dùng) và ẩn danh (nhân viên). Hard reload `Ctrl+Shift+R` một lần |
| Điện thoại | Cùng mạng hoặc qua tunnel (`docs/deploy.md`), đã đăng nhập `student10` |
| Ví `student10` | Còn ít nhất 20.000 đ (nếu thiếu: làm cảnh 5 trước) |

Trong lúc demo không chạy lại `build-dev.sh` và không sửa `SmartLocker.xml`: Tomcat tải lại sẽ đăng xuất mọi người.

## Cảnh 1. Khách xem bản đồ (1 phút)

- **Làm:** mở trang chủ khi chưa đăng nhập, bấm "Tìm tủ gần tôi", phóng vào một khu, chọn một dãy.
- **Nói:** bản đồ là trang chính, khách xem được không cần tài khoản. 5 khu trong ĐHQG-HCM, tự làm mới 10 giây một lần. Leaflet nằm sẵn trong repo, mất Internet vẫn thấy ghim trên nền lưới.
- **Thấy:** ngăn trống, đang dùng, khóa quá hạn có màu khác nhau; dãy của hộp mất kết nối không đặt được.

## Cảnh 2. Đăng nhập trong popup (30 giây)

- **Làm:** bấm Đặt ngăn khi chưa đăng nhập, popup đăng nhập hiện ra; đăng nhập `student10`.
- **Nói:** không có trang đăng nhập riêng, menu đổi ngay không tải lại trang.

## Cảnh 3. Đặt ngăn (2 phút)

- **Làm:** chọn một ngăn trống cỡ S ở dãy của hộp thật. Lướt qua gói 2 giờ / 4 giờ / Trọn ngày / Tự chọn, đổi cỡ M, L để thấy giá đổi. Chọn gói 2 giờ, cách mở **mật mã**, bấm Đặt.
- **Nói:** popup ghi số tiền trừ ngay, số dư còn lại, luật hủy. Sau khi đặt ví phải còn 10.000 đ dự phòng phụ phí. Giá do procedure SQL tính, trang chỉ hiển thị. Hai người bấm cùng một ngăn thì chỉ một người được (`UPDLOCK, HOLDLOCK`).
- **Thấy:** "Tủ của tôi" hiện mật mã 6 số, đếm ngược 15 phút giữ chỗ, nút Hủy kèm số tiền hoàn (100% trong 5 phút đầu).

## Cảnh 4. Mở tủ tại hộp thật (3 phút)

1. Nhập mật mã + `#` trên keypad → servo mở, LCD báo CHECK_IN. Trên web lượt chuyển ACTIVE, đồng hồ bắt đầu tính giờ.
2. Nhập lại mật mã → LCD hỏi `A: Mo tu / B: Tra tu`. Bấm `A` → mở tủ, lượt vẫn chạy, số lần mở tăng.
3. Để dành phím `B` cho cuối cảnh 6.

- **Nói:** hộp không tự quyết, nó gửi lên `/api/device/auth` kèm khóa API riêng; máy chủ chỉ lưu SHA-256 của khóa.
- **Thêm nếu còn thời gian:**
  - Thẻ: `student1` có thẻ đăng ký sẵn trên `LOCKER-01`.
  - Vân tay: `student3` có vân tay ở ô cảm biến 1.
  - Gõ sai mật mã 5 lần → kênh đó khóa 2 phút. Làm cuối cùng vì sẽ chặn các bước sau.

**Chạm điện thoại / QR:** trên điện thoại đã đăng nhập, quét QR trên hộp (hoặc chạm vào đầu đọc) → trang `/k/LOCKER-01` → "Mở tủ của tôi". Mã chạm đổi mỗi phút và chỉ dùng được một lần.

## Cảnh 5. Nạp tiền và duyệt (2 phút)

- **Làm (người dùng):** Nạp tiền → nhập số tiền → hiện mã VietQR, yêu cầu ở trạng thái chờ.
- **Làm (cửa sổ ẩn danh, `operator1`):** Duyệt nạp tiền → Duyệt.
- **Thấy:** số dư trên menu của `student10` tăng ở request tiếp theo.

## Cảnh 6. Gia hạn, quá hạn, nợ (3 phút)

1. Trong Tủ của tôi bấm **Gia hạn** 1 giờ (tối đa 3 lần, giá một giờ của cỡ ngăn).
2. Giả quá hạn không cần chờ: sửa đầu `sql/test_overdue.sql` thành `@username = N'student10'`, `@minutes_late = 130`, `@balance = 5000` rồi chạy:

   ```bash
   sqlcmd -S localhost -U sa -P 12345 -I -b -f 65001 -i sql\test_overdue.sql
   ```

3. Trong 15 giây: ngăn khóa, trừ phụ phí 3 giờ trễ, ví âm. Tủ của tôi hiện số nợ.
4. Nhập mật mã ở hộp → từ chối `OVERDUE_UNPAID`, LCD hiện số nợ.
5. Nạp tiền và duyệt như cảnh 5 cho ví hết âm, nhập mật mã, bấm `B` → PICKUP, lượt COMPLETED, ngăn trống lại.

- **Nói:** ngăn không tự giải phóng khi quá hạn vì đồ còn trong đó. Script chỉ dời giờ hết hạn; việc khóa và tính tiền do job nền thật làm.
- **Biến thể:** `@minutes_late = 2890` (hơn 48 giờ) → cảnh báo `OVERDUE_ESCALATED` cho nhân viên.

## Cảnh 7. Tổng quan và cảnh báo (3 phút, `admin`)

- **Làm:** Tổng quan: trạng thái ngăn, mức dùng theo khu, thiết bị, lượt đặt theo giờ, doanh thu 7 ngày.
- Bơm sự kiện cảm biến giả có lỗi và có dấu hiệu gian lận:

  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts\send-demo.ps1 -Count 5 -Fault -Bad
  ```

- **Thấy:**
  - Dữ liệu cảm biến: có phiên mới, lọc và sắp xếp được.
  - Cảnh báo: `SENSOR_FAULT`, `SUSPECTED_SPOOF`... kèm bằng chứng.
- **Nói:** `RuleEngine` quyết định có cảnh báo hay không, mô hình Weka chỉ cộng thêm điểm rủi ro. `/api/dashboard` đọc ảnh chụp trong RAM, không truy vấn DB mỗi lần làm mới.

## Cảnh 8. Thiết bị mất kết nối (1 phút)

- **Làm:** rút điện hộp ESP32, chờ khoảng 90 giây.
- **Thấy:** `LOCKER-01` thành OFFLINE, cảnh báo `DEVICE_OFFLINE`, dãy của nó trên bản đồ không đặt được. Cắm lại → ACTIVE.
- Làm cảnh này lúc đang trả lời câu hỏi để không phải đứng chờ.

## Cảnh 9. Vận hành và kỹ thuật (2 phút)

- **`operator1`:** Mở khóa từ xa ngăn có servo (`A01` nếu giữ mặc định của `demo_box.sql`; hộp nhận lệnh ở heartbeat kế tiếp, servo mở. Ngăn khác chỉ báo trên LCD); Lượt gửi đồ; Thẻ RFID (báo mất thẻ).
- **`tech1`:** mở một cảnh báo → tạo phiếu Bảo trì; trang Hiệu chuẩn.
- **Nói:** mỗi vai trò chỉ thấy menu và thao tác của mình; `SecurityFilter` chặn ở máy chủ, không chỉ ẩn nút.

## Cảnh 10. Kiểm toán và phân quyền (1 phút)

- **`auditor1`:** Nhật ký kiểm toán → kiểm tra chuỗi băm SHA-256: hợp lệ. Mọi thao tác ở các cảnh trước đều có dòng ở đây.
- **`admin`:** Vai trò & quyền: bật/tắt quyền của một vai trò.
- **`locked1`:** đăng nhập bị từ chối (tài khoản bị khóa).

## Kết (1 phút)

- **Kiểm thử:**
  - TestNG 83/83.
  - Postman/newman 19 kịch bản, 514 assertion, 0 lỗi.
  - Trình duyệt 36/36 mục.
- **Đã biết còn thiếu:** giới hạn đăng nhập sai, CSRF token, xác minh email (README mục Bảo mật).

## Khi có sự cố

| Sự cố | Cách xử lý |
|---|---|
| Hộp thật không lên mạng | Đặt ở dãy minh họa (ví dụ `CANT-B`) và mở bằng trang điện thoại `/k/...` với mật mã |
| Bản đồ không có nền | Không có Internet: ghim vẫn hiện trên nền lưới, cứ tiếp tục |
| Trang báo 404 ngay sau khi build | Tomcat đang tải lại, chờ 15 giây rồi đăng nhập lại |
| Popup đăng nhập tự điền `admin` | Bấm ba lần vào ô để chọn hết rồi gõ tên khác |
| `test_overdue.sql` báo không có lượt ACTIVE | Chưa mở tủ lần đầu (cảnh 4 bước 1) |
| Dọn dữ liệu sau buổi demo | Chạy `sql/test_cleanup.sql` hoặc dựng lại bằng `run_demo_db.ps1` |
