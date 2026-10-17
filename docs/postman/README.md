# Postman: Smart Locker v2

Các file:
- `SmartLocker-v2.postman_collection.json`: thư mục Heartbeat, Auth, Enroll, Kiosk (điện thoại), Batch, Scenarios (10 kịch bản của spec mục 6.2).
- `SmartLocker-local.postman_environment.json`: `base_url` = `http://localhost:8080/SmartLocker`.
- `SmartLocker-tunnel.postman_environment.json`: thay `REPLACE-ME` bằng địa chỉ Cloudflare tunnel hiện tại.

## Trước mỗi lần chạy
1. Tomcat và SQL Server đang chạy, đã chạy `sql/06_demo_v2.sql`.
2. Chạy `sql/test_v2_setup.sql` (tạo hoặc đặt lại tài khoản `v2pin`, `v2card`, `v2fp`, `v2noshow`, mật khẩu `123456`,
   và đặt lại bộ đếm sai mật mã của LOCKER-01). Ví dụ:
   `sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -f 65001 -i sql/test_v2_setup.sql`

## Postman Runner
Import collection và environment, chọn environment, Run collection, giữ nguyên thứ tự. Kịch bản 5 có một bước chờ
122 giây (hộp bị khóa nhập 2 phút), nên cả lượt chạy mất khoảng 2 phút 20 giây.

## Newman (nếu có Node)
```
npm install -g newman
newman run docs/postman/SmartLocker-v2.postman_collection.json -e docs/postman/SmartLocker-local.postman_environment.json
```

## Lưu ý
- Mọi lần đoán sai (sai mật mã, thẻ hoặc vân tay chưa đăng ký, mã đăng ký sai) đều tính vào giới hạn 5 lần trong 5 phút
  của hộp. Kịch bản 5 cần bộ đếm bằng 0, nên phải chạy `test_v2_setup.sql` ngay trước.
- Kịch bản 3 tạo một UID thẻ ngẫu nhiên mỗi lần chạy; kịch bản 8 báo mất chính thẻ đó.
