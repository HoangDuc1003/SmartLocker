# Postman: Smart Locker v2 và v3

Các file:
- `SmartLocker-v2.postman_collection.json`: thư mục Heartbeat, Auth, Enroll, Kiosk (điện thoại), Batch, Scenarios (10 kịch bản
  của spec v2 mục 6.2) và thư mục **v3** (kịch bản 11–17 của `docs/spec/smart-locker-v3.md` mục 7.3). Một collection duy nhất.
- `SmartLocker-local.postman_environment.json`: `base_url` = `http://localhost:8080/SmartLocker`.
- `SmartLocker-tunnel.postman_environment.json`: thay `REPLACE-ME` bằng địa chỉ Cloudflare tunnel hiện tại.

## Trước mỗi lần chạy
1. Tomcat và SQL Server đang chạy, đã chạy `sql/06_demo_v2.sql`, `sql/07_vietnamese_data.sql` và `sql/09_v3.sql`.
2. Chạy **theo thứ tự** hai script, ngay trước khi chạy collection:
   ```
   sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -b -f 65001 -i sql\test_v2_setup.sql
   sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -b -f 65001 -i sql\test_v3_setup.sql
   ```
   - `test_v2_setup.sql`: tạo hoặc đặt lại `v2pin`, `v2card`, `v2fp`, `v2noshow`, `v3overdue`, `v3poor` (mật khẩu `123456`),
     đặt lại bộ đếm sai mã của LOCKER-01, và tạo lượt đặt đã hết giờ giữ chỗ của `v2noshow` (kịch bản 6).
   - `test_v3_setup.sql` (chạy sau, vì script v2 đặt lại `v3overdue`): Postman không chạy được SQL, nên các bước cần "tua thời
     gian" bắt đầu từ lượt gửi đã ở sẵn trạng thái cần. Script chỉ dời mốc thời gian; khóa, phụ phí và chuyển xử lý do chính
     hệ thống làm (`Device_Authorize` tính ngay khi nhập mã, `LockerMonitor` 15 giây một lần).

     | Tài khoản | Lượt chuẩn bị | Dùng ở |
     |---|---|---|
     | `v3overdue` | `ACTIVE` (đã mở lần 1), `due_at` cách đây 130 phút, ví 5.000 đ | 11, 16, 17, 12 |
     | `v3late` | `RESERVED`, đặt từ 6 phút trước (giữ chỗ kéo dài tới 30 phút để không thành `NO_SHOW` giữa chừng) | 13 |
     | `v3esc` | `ACTIVE`, `due_at` cách đây 49 giờ | 15 |
     | `v3poor` | không có lượt, ví 12.000 đ (từ `test_v2_setup.sql`) | 14 |

     Các lượt chuẩn bị lấy ngăn cỡ L rồi M của CANT-A, để các ngăn cỡ S còn trống cho những kịch bản đặt mới.
3. Biến `api_key` là khóa LOCKER-01 trong `config/device-keys.local.properties`.

## Postman Runner
Import collection và environment, chọn environment, Run collection, giữ nguyên thứ tự. Kịch bản 5 có một bước chờ
122 giây (hộp bị khóa nhập 2 phút), kịch bản 6 và 15 có thể hỏi lại vài lần cách nhau 5 giây (chờ `LockerMonitor`),
nên cả lượt chạy mất khoảng 2 phút 40 giây.

## Newman (nếu có Node)
```
npm install -g newman
newman run docs/postman/SmartLocker-v2.postman_collection.json -e docs/postman/SmartLocker-local.postman_environment.json --env-var api_key=<khóa LOCKER-01>
```
Kết quả lần chạy ngày 23/10/2026: 201 request, 422 assertion, 0 lỗi.

## Thư mục v3
Chạy theo thứ tự 11, 16, 17, 12, 13, 14, 15: kịch bản 16 và phần đầu của 17 dùng lượt bị khóa của 11, trước khi 12 nạp tiền
và lấy đồ.

| # | Kịch bản | Kiểm tra |
|---|---|---|
| 11 | `v3overdue` nhập mật mã tại hộp | `DENY OVERDUE_UNPAID`, `debt` = phụ phí − 5.000 đ, phụ phí = số giờ trễ × phụ phí một giờ của cỡ; nhập lại không thu trùng và không giảm `attempts_left`; "Tủ của tôi" có `locked`, ví âm đúng số nợ; sơ đồ hiện ngăn bị khóa |
| 16 | Cùng lượt, mở bằng `/api/kiosk/unlock` | `OVERDUE_UNPAID`, không có lệnh, câu tiếng Việt "Bạn còn nợ X đ" |
| 17 | Gia hạn lượt bị khóa; `v2pin` đặt cỡ S, mở, gia hạn 90 phút | lỗi 50048 (flash), không trừ tiền; gia hạn trừ 2 × giá một giờ của S, flash "Đã trừ ... vào ví", `due_at` lùi 90 phút, lấy đồ `overdue_fee` = 0 |
| 12 | `v3overdue` tạo yêu cầu nạp (nợ + 20.000 đ), `admin` duyệt, mở lại | ví 20.000 đ, `UNLOCK PICKUP` có `overdue_fee` bằng phụ phí của 11, lượt `COMPLETED`, ngăn trống |
| 13 | `v2pin` đặt rồi hủy ngay; `v3late` hủy lượt đặt 6 phút trước | hoàn 100%; lỗi 50047 (flash), lượt vẫn `RESERVED`; cuối cùng mở và lấy đồ để trả ngăn |
| 14 | `v3poor` đặt cỡ S 2 giờ | lỗi 50046 (flash), không có lượt, ví vẫn 12.000 đ |
| 15 | `v3esc` | chờ `LockerMonitor`: lượt `escalated`, `locked`, phụ phí ≥ 49 giờ; `admin` thấy cảnh báo `OVERDUE_ESCALATED` (lượt, người dùng) và dòng audit `OVERDUE_ESCALATE` có `alert_id` |

- Lỗi nghiệp vụ của các form (50046, 50047, 50048) hiện ở thanh flash của trang mà form chuyển tới; Postman theo redirect
  và tìm đúng câu tiếng Việt trong HTML.
- Nạp tiền: không có API duyệt riêng, Postman dùng chính form `TopupController` (người dùng `action=create`, nhân viên
  `action=approve`, tài khoản nhân viên trong biến `staff_user`, mặc định `admin`). Bước tạo yêu cầu tắt theo redirect để
  đọc mã yêu cầu trong header `Location`.
- Các kịch bản tự tìm gói 2 giờ theo `duration_min` (không theo tên gói) và chỉ chọn ngăn cỡ S, vì chúng kiểm tra giá của cỡ S.

## Lưu ý

- **Sau khi chạy Postman, trước buổi demo**: chạy `sql/test_v3_cleanup.sql`. Các script setup để lại lượt đặt của tài khoản kiểm thử trên CANT-A (hộp thật LOCKER-01): ngăn đang giữ chỗ, ngăn khóa quá hạn, ngăn đã chuyển xử lý và một cảnh báo `OVERDUE_ESCALATED` đang mở. Script cleanup đóng các lượt đó, trả ngăn về trống và xử lý cảnh báo; không đụng tài khoản demo.
- Mọi lần đoán sai (sai mật mã, thẻ hoặc vân tay chưa đăng ký, mã đăng ký sai) đều tính vào giới hạn 5 lần trong 5 phút
  của hộp. Kịch bản 5 cần bộ đếm bằng 0, nên phải chạy `test_v2_setup.sql` ngay trước. Thư mục v3 không có bước đoán sai;
  `OVERDUE_UNPAID` không tính là lần sai.
- Kịch bản 3 tạo một UID thẻ ngẫu nhiên mỗi lần chạy; kịch bản 8 báo mất chính thẻ đó.
- Kịch bản 6 (v3): không đến thì không hoàn tiền; ví còn 200.000 đ trừ giá lượt đặt.
- Phụ phí của `v3overdue` tính theo giờ bắt đầu kể từ `due_at`: chạy collection quá 50 phút sau `test_v3_setup.sql` thì
  số giờ trễ thành 4 (các kiểm tra vẫn đúng vì tính theo số giờ API trả), nhưng nên chạy lại script ngay trước mỗi lần chạy.
