# Mẫu email của Smart Locker

Mỗi file `*.txt` là một mẫu. Sửa trực tiếp, không cần biên dịch lại; khởi động lại Tomcat để chắc chắn mẫu mới được dùng.

## Cách viết

- Dòng đầu: `Subject: tiêu đề` (có thể chứa `{{...}}`), sau đó một dòng trống, rồi nội dung.
- `{{ten_bien}}` được thay bằng giá trị lúc gửi. Biến không có giá trị thì thành chuỗi rỗng.
- Dòng bắt đầu bằng `?` là **dòng tuỳ chọn**: bỏ dấu `?` khi gửi, và cả dòng bị bỏ nếu một biến trong dòng rỗng
  (ví dụ link khi chưa cấu hình `app.base_url`).
- `_footer.txt` được nối vào cuối mọi email.
- Chỉ có chữ thuần (không HTML). Mọi giá trị chèn vào đều bị bỏ xuống dòng và cắt tối đa 300 ký tự.
- `{{name}}` là họ tên người nhận; nếu trống thì dùng "bạn".

## Các mẫu và biến

| Mẫu | Khi nào gửi | Biến |
|---|---|---|
| `due_soon` | Sắp đến hạn (15 phút trước) — **đang chạy tự động** | name, slot_code, bank_code, area_name, due_at, overdue_rate, my_locker_url |
| `overdue` | Quá hạn, tủ bị khóa | name, slot_code, bank_code, area_name, due_at, overdue_rate, overdue_hours, overdue_fee, balance, escalate_hours, topup_url, my_locker_url |
| `overdue_escalated` | Quá hạn lâu, chuyển nhân viên | name, slot_code, bank_code, area_name, due_at, overdue_hours, overdue_fee, balance, my_locker_url |
| `booking_confirmed` | Đặt ngăn thành công | name, slot_code, bank_code, area_name, plan_name, open_method, amount, hold_until, my_locker_url |
| `reservation_expired` | Hết giữ chỗ mà không tới | name, slot_code, area_name, hold_min, refund_amount, refund_pct, map_url |
| `verification_code` | Mã xác nhận email | name, code, expires_min |
| `welcome` | Đăng ký tài khoản | name, username, map_url, my_locker_url |
| `topup_approved` | Duyệt nạp tiền | name, amount, balance, topup_url |
| `topup_rejected` | Từ chối nạp tiền | name, amount, reason, topup_url |

Thời gian ghi theo giờ Việt Nam (`16:00 23/10/2026`), tiền ghi `14.700 đ`.

## Xem thử

```bash
sh scripts/mail-preview.sh list
sh scripts/mail-preview.sh due_soon
sh scripts/mail-preview.sh due_soon ten@gmail.com
```

Lệnh thứ hai in nội dung với dữ liệu mẫu; lệnh thứ ba gửi thật bản mẫu đó tới địa chỉ đã cho.
Hiện chỉ `due_soon` được hệ thống gửi tự động; các mẫu còn lại đã sẵn sàng và chưa nối vào sự kiện nào.
