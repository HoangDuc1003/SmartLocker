# Smart Locker v3: spec (chỉ phần thay đổi so với v2)

Trạng thái: **đã duyệt 23/10/2026**, đang triển khai. Đã chốt Q3, Q5, Q6, Q7 (23/10/2026).
Ngày: 23/10/2026. Nền: [smart-locker-v2.md](smart-locker-v2.md) và code hiện tại (đã đọc lại, xem mục 0).

Các mục đánh dấu **[Giả định]** là chỗ mình tự chọn; bạn sửa khi duyệt.

---

## 0. Hiện trạng đã kiểm tra trong code và DB

| Điểm | Thực tế |
|---|---|
| Cỡ ngăn | `LockerSlot.size_code` (S/M/L) và `size_cm`. DB hiện có 84 ngăn `S 30x30x45` và 18 ngăn `L 40x40x90`, **chưa có ngăn M**. |
| Gói | `2 giờ` 120 phút 5.000 đ, `4 giờ` 240 phút 9.000 đ, `Trọn ngày` 1440 phút 25.000 đ; `grace_min` lần lượt 10, 10, 30. |
| Giá | `util/Pricing.java` và `dbo.fn_OpenPrice` (thẻ giảm 5%, tròn lên 100 đ). Giữ chỗ 15 phút nằm cứng trong `Deposit_Reserve` và `Pricing.HOLD_MIN`. |
| Hủy | `Deposit_Cancel` cho hủy bất cứ lúc nào khi còn `RESERVED`, hoàn 100%. |
| Không đến | `Deposit_ExpireNoShow` (bản 06) hoàn 90%. |
| Quá hạn | `Deposit_ExpireOverdue` chuyển `COMPLETED` và trả ngăn về `AVAILABLE`. Được gọi ở `LockerMonitor` (15 giây) **và** trong `LockerMapDao` (mỗi lần tải sơ đồ). |
| Gia hạn | `Deposit_Extend` **không thu tiền**, cho gia hạn cả khi đã quá hạn. Đây là lỗ hổng khi có phụ phí (xem Q5). |
| Lượt tại quầy | `DepositDao.insert` (nhân viên) ghi thẳng `ACTIVE`, `paid_amount = 0`, không qua procedure. |
| Email | Cột `Users.email` có sẵn nhưng chỉ 7 tài khoản có email; trang đăng ký chưa có ô email. Chưa có thư viện gửi mail trong `lib/`. |
| Khu vực | `LockerArea` chưa có toạ độ; `Device` chưa có cột IP. |
| CSS | Ngoài `app.css` còn có `css/locker-map.css` (đã có từ trước, chỉ trang sơ đồ dùng). v3 giữ nguyên cách tách này. |
| Thay đổi chưa commit | `AlertController`, `LockerMapDao`, `locker-map.js/.css` có nút "Kết nối lại cả dãy" của ADMIN. v3 giữ lại tính năng này khi vẽ lại tủ. |

---

## 1. Bảng quyết định

| # | Quyết định |
|---|---|
| D1 | Trang đăng nhập chia đôi: trái là hình lưới tủ SVG tĩnh và 3 điểm nổi bật, phải là form. Giữ `action`, `username`/`password`, vùng lỗi và flash, link đăng ký, nút sáng/tối; thêm nút hiện/ẩn mật khẩu. ≤ 768px: cột trái thành dải đầu trang. `register.jsp` dùng cùng bố cục. |
| D2 | S = 20x20x20, M = 40x40x40, L = 60x60x60 cm. Không có tải trọng. Gợi ý vật dụng và ảnh theo cỡ. |
| D3 | Hệ số giá theo cỡ, mỗi bậc +30%: **S ×1,00, M ×1,30, L ×1,69** [Giả định, Q1]. Tròn lên 100 đ. Thứ tự: giá gói → hệ số cỡ (tròn 100) → giảm 5% thẻ (tròn 100). |
| D4 | Trừ tiền khi đặt. Hủy chỉ trong **5 phút đầu**, hoàn 100%. Giữ chỗ 15 phút từ lúc đặt. Không đến: `NO_SHOW`, **hoàn 0 đ**. Giữ luật 3 lần không đến trong 7 ngày. |
| D5 | Ngăn không bao giờ tự giải phóng. Quá `due_at + grace_min`: khóa, tính phụ phí 1,5 lần giá một giờ cho mỗi giờ bắt đầu, trừ vào ví (cho phép âm). Mở chỉ khi số dư ≥ 0. Quá 48 giờ: chuyển xử lý, cảnh báo cho OPERATOR/ADMIN. |
| D6 | Toạ độ (giả) cho 4 khu, IP giả RFC 5737 cho từng hộp. Trình duyệt định vị bằng `watchPosition`, tính haversine tại chỗ, không gửi vị trí lên server. Nút "Chỉ đường" mở Google Maps (không API key). |
| D7 | Deploy giữ phương án A. Chỉ thêm `09_v3.sql` vào `run_demo_db` và ghi chú HTTPS cho định vị. |
| D8 (mới) | **Email nhắc hạn**: 15 phút trước `due_at`, gửi một email cho chủ lượt gửi (nếu có email). SMTP viết bằng Java thuần, Gmail mật khẩu ứng dụng (đã chốt Q6). |
| D9 (mới) | **Vẽ lại hình tủ** trên sơ đồ, không dùng lại thiết kế cũ: mỗi dãy là một khối tủ, cửa ngăn cao theo cỡ (S 1 phần, M 2 phần, L 3 phần), có tay nắm, nhãn mã ngăn, màu trạng thái lấy từ token. Bảng đặt ngăn và popup cũng làm mới. Không đổi bố cục cả trang, không đụng phần cứng (đã chốt Q7). |
| D10 (mới) | **Gia hạn thu tiền**: giá một giờ của cỡ (không ×1,5) cho mỗi giờ bắt đầu thêm; không cho gia hạn khi tủ đã khóa vì quá hạn (đã chốt Q5). |

---

## 2. Thay đổi dữ liệu (`sql/09_v3.sql`, UTF-8 BOM, chạy lại được)

### 2.1 Bảng cấu hình (một chỗ duy nhất cho các con số)

`AppConfig(config_key NVARCHAR(40) PK, int_value BIGINT NOT NULL, note NVARCHAR(200))`

| Khóa | Giá trị | Dùng ở |
|---|---|---|
| `HOLD_MIN` | 15 | `Deposit_Reserve`, popup, đếm ngược |
| `CANCEL_FREE_MIN` | 5 | `Deposit_Cancel`, nút hủy, đếm ngược |
| `CANCEL_LATE_REFUND_PCT` | 50 | `Deposit_Cancel`: hủy sau `CANCEL_FREE_MIN` phút, trước khi hết giữ chỗ |
| `NO_SHOW_REFUND_PCT` | 0 | `Deposit_ExpireNoShow` |
| `BOOKING_BUFFER` | 10000 | `Deposit_Reserve` (Q2) |
| `OVERDUE_FEE_PCT` | 150 | phụ phí mỗi giờ = 150% giá một giờ |
| `ESCALATE_HOURS` | 48 | chuyển xử lý |
| `DUE_REMINDER_MIN` | 15 | email nhắc hạn |
| `CARD_DEPOSIT` | 30000 | cọc thẻ (thay số cứng trong `Deposit_Reserve`, `Enroll_Finish`) |

SQL đọc qua `dbo.fn_Config(@key)`. Java đọc bảng này qua `AppConfigDao` (cache 60 giây) để hiển thị; `Pricing.java` chỉ còn công thức, nhận tham số.

### 2.2 Cỡ ngăn

Bảng mới `SlotSize(size_code CHAR(1) PK, size_cm NVARCHAR(20), price_pct INT CHECK 100..500, items NVARCHAR(400), sort_no INT)`.
Đây là **chỗ duy nhất** chứa số đo, hệ số giá và gợi ý vật dụng; web lấy qua API, JSP lấy qua DAO.

| Cỡ | Số đo | Hệ số | Gợi ý vật dụng (vừa số đo) |
|---|---|---|---|
| S | 20x20x20 | 100 | ví, điện thoại, chìa khóa, tai nghe, sạc dự phòng, sổ tay nhỏ |
| M | 40x40x40 | 130 | laptop tới 15,6 inch, túi xách, balo nhỏ (dưới 40 cm), một đôi giày, áo khoác gấp |
| L | 60x60x60 | 169 | balo lớn, vali cabin (55x40x20), mũ bảo hiểm fullface, túi thể thao, thùng đồ nhỏ |

- `LockerSlot.size_cm` cập nhật theo `SlotSize` cho mọi ngăn.
- Phân bổ cỡ (đã chốt Q7): theo vị trí trong cột của dãy (`door_rows`): dãy 4 hàng là S, S, M, L từ trên xuống; dãy 2 hàng là M, L. Ngăn đang có lượt mở vẫn đổi cỡ được (chỉ là mô phỏng, chỉ có một hộp thật).
- Ảnh: `web/img/lockers/size-s.webp|png`, `size-m`, `size-l`. Chưa có ảnh thì hiện SVG nội tuyến của cỡ đó. Đường dẫn ảnh do server trả (`img` trong API) chỉ khi file tồn tại, nên không bao giờ có ô ảnh vỡ.

### 2.3 Deposit: cột mới (giữ trạng thái `ACTIVE`, không thêm enum)

| Cột | Ý nghĩa |
|---|---|
| `size_pct INT NULL` | hệ số cỡ lúc đặt (chụp lại để đổi bảng giá sau không ảnh hưởng lượt cũ) |
| `overdue_rate BIGINT NULL` | phụ phí một giờ trễ của cỡ, chụp lúc đặt (mục 3.3). NULL (lượt tại quầy, lượt cũ) thì tính lại theo cỡ khi cần |
| `overdue_hours INT NOT NULL DEFAULT 0` | số giờ trễ đã thu |
| `overdue_fee BIGINT NOT NULL DEFAULT 0` | tổng phụ phí đã thu |
| `locked_at DATETIME2 NULL` | lúc bị khóa vì quá hạn |
| `escalated_at DATETIME2 NULL` | lúc chuyển xử lý (48 giờ) |
| `due_reminder_at DATETIME2 NULL` | lúc đã gửi email nhắc hạn |

**Lý do không thêm trạng thái `OVERDUE`/`LOCKED`:** CHECK của `Deposit.status`, hai unique index lọc theo `RESERVED`/`ACTIVE`, `UX_Deposit_pin_open`, `Device_Authorize`, `Enroll_*`, DAO và JSP đều dựa vào `ACTIVE`. Giữ `ACTIVE` thì ngăn tự nhiên vẫn bị chiếm (`OCCUPIED`), người khác không đặt được, mật mã vẫn duy nhất; trạng thái "khóa" chỉ là `locked_at IS NOT NULL`.

### 2.4 Khu vực và thiết bị

- `LockerArea.latitude DECIMAL(9,6) NULL`, `longitude DECIMAL(9,6) NULL`. **Toạ độ giả** quanh một khuôn viên ví dụ (Hòa Lạc, Hà Nội, khoảng 21.0130, 105.5270), các khu cách nhau 100–400 m. Comment trong SQL ghi rõ là giả, chỗ để thay.
- `Device.ip_address NVARCHAR(45) NULL`: `192.0.2.11`…`192.0.2.18` (RFC 5737, dải dành cho tài liệu). Chỉ để lưu, không dùng để suy ra vị trí.

### 2.5 Procedure

| Procedure | Thay đổi |
|---|---|
| `fn_SlotPrice(@price, @pct, @method)` (mới) | giá gói × hệ số cỡ (tròn 100) rồi giảm thẻ (tròn 100). `fn_OpenPrice` giữ lại, gọi `fn_SlotPrice` với 100 cho code cũ. |
| `fn_HourRate(@pct)`, `fn_OverdueRate(@pct)` (mới) | giá một giờ và phụ phí một giờ của một cỡ, lấy từ gói đang bán có `duration_min` nhỏ nhất (mục 3.3). |
| `Deposit_Reserve` | giá theo cỡ; kiểm tra `số dư − giá ≥ BOOKING_BUFFER` (và cọc thẻ nếu lần đầu); lỗi mới `50046`; lưu `size_pct`, `overdue_rate`; `hold_until` = `HOLD_MIN`. |
| `Deposit_Cancel` | trong `CANCEL_FREE_MIN` phút hoàn 100%; sau đó tới `hold_until` hoàn `CANCEL_LATE_REFUND_PCT`% (làm tròn xuống 100 đ); hết giữ chỗ: `50047`. Tham số `@expected_refund` (số popup đã hiện): hoàn thấp hơn thì `50052`, không đổi gì. |
| `Deposit_ExpireNoShow` | hoàn `NO_SHOW_REFUND_PCT` (0%); audit ghi số hoàn 0. |
| `Deposit_ExpireOverdue` | **không giải phóng ngăn nữa**: gọi `Deposit_ChargeOverdue` (khóa lượt quá `due_at + grace_min`, audit `OVERDUE_LOCK`, thu phụ phí). Bỏ `AUTO_RELEASE_OVERDUE`. `LockerMonitor` gọi `Deposit_Escalate` ngay sau đó. |
| `Deposit_ChargeOverdue @deposit_id = NULL` (mới) | thu phần giờ trễ chưa thu cho một lượt (hoặc mọi lượt bị khóa): `giờ = CEILING(giây trễ kể từ due_at / 3600)`, trừ `(giờ − overdue_hours) × overdue_rate` vào ví (cho phép âm), audit `OVERDUE_FEE`. Chạy lại không thu trùng. |
| `Deposit_Escalate` (mới) | lượt `ACTIVE` quá `due_at + ESCALATE_HOURS`, chưa `escalated_at`: đặt `escalated_at`, tạo cảnh báo `OVERDUE_ESCALATED` (kèm bằng chứng: lượt, người dùng, ngăn, giờ trễ, phụ phí, số dư) và audit `OVERDUE_ESCALATE` + `CREATE ALERT` **trong cùng một transaction**. Khác bản nháp (tạo cảnh báo qua `AlertService` trong Java): làm trong SQL để không bao giờ có lượt đã chuyển xử lý mà thiếu cảnh báo khi Java lỗi giữa chừng. |
| `Deposit_Extend` | từ chối khi lượt đã bị khóa (`locked_at` có giá trị): lỗi mới `50048`. Thu `CEILING(phút/60) × giá_1_giờ` của cỡ (mục 3.5); thiếu tiền: lỗi mới `50049`. |
| `Device_Authorize` | với phase `PICKUP` của lượt đã khóa: gọi `Deposit_ChargeOverdue` cho lượt đó, nếu số dư < 0 thì `DENY OVERDUE_UNPAID` (không tính vào bộ đếm 5 lần sai, vì không phải đoán mã), trả thêm `debt`. Số dư ≥ 0 thì `PICKUP` như cũ. |
| `RemoteCommand_TakePending` | lệnh mở của điện thoại cho lượt đã khóa: kiểm tra lại số dư trước khi `PICKUP` (tiền có thể đổi giữa lúc nhập mã và lúc hộp nhận lệnh). |
| `Deposit_DueSoon` (mới) | danh sách lượt `ACTIVE` có `due_at` trong 15 phút tới, chưa nhắc, chủ có email. |
| `Deposit_MarkReminded @deposit_id` (mới) | ghi `due_reminder_at`. |
| `v_LockerSlotMap` | thêm `is_locked`, `is_escalated`; `display_status` giữ `OVERDUE` cho ngăn quá hạn. |

Mã lỗi mới, dịch sang tiếng Việt trong `Web.sqlMessage`:
- `50046`: sau khi đặt, số dư phải còn ít nhất 10.000 đ để dự phòng phụ phí.
- `50047`: đã hết thời gian giữ chỗ, không hủy được nữa.
- `50052`: thời gian hủy hoàn đủ vừa hết trong lúc popup đang mở; lượt chưa bị hủy.
- `50048`: lượt gửi đã quá hạn và bị khóa, không gia hạn được; hãy nạp tiền và lấy đồ.
- `50049`: số dư không đủ để gia hạn.

`LockerMapDao` bỏ lời gọi `Deposit_ExpireOverdue` (việc của `LockerMonitor`); giữ `Deposit_ExpireNoShow` nếu đang có.

---

## 3. Quy tắc tiền (Java `Pricing` và SQL phải khớp, có test so sánh)

### 3.1 Giá đặt

`giá_cỡ = CEILING(giá_gói × hệ_số / 100 / 100) × 100`; `giá_thẻ = CEILING(giá_cỡ × 95 / 100 / 100) × 100`.

| Gói | S mật mã/vân tay | S thẻ | M | M thẻ | L | L thẻ |
|---|---|---|---|---|---|---|
| 2 giờ (5.000) | 5.000 | 4.800 | 6.500 | 6.200 | 8.500 | 8.100 |
| 4 giờ (9.000) | 9.000 | 8.600 | 11.700 | 11.200 | 15.300 | 14.600 |
| Trọn ngày (25.000) | 25.000 | 23.800 | 32.500 | 30.900 | 42.300 | 40.200 |

### 3.2 Điều kiện đặt
`số dư − giá ≥ 10.000` (lần đầu dùng thẻ: `số dư − giá − 30.000 ≥ 10.000`) [Giả định, Q2]. Popup và nút đặt hiện **số tiền trừ ngay** (`giá`), cọc thẻ ghi riêng là "trừ khi đăng ký thẻ tại hộp".

### 3.3 Phụ phí quá hạn (đã chốt Q3: một giá chung theo cỡ)
Gói gốc là gói đang bán có `duration_min` nhỏ nhất (hiện là 2 giờ, 5.000 đ). Mọi gói dùng chung:
- `giá_1_giờ(cỡ) = CEILING(giá_cỡ_của_gói_gốc × 60 / thời_lượng / 100) × 100`
- `phụ_phí_1_giờ(cỡ) = CEILING(giá_cỡ_của_gói_gốc × 60 × 150 / (thời_lượng × 100) / 100) × 100`

| Cỡ | Giá một giờ (gia hạn) | Phụ phí một giờ trễ |
|---|---|---|
| S | 2.500 | 3.800 |
| M | 3.300 | 4.900 |
| L | 4.300 | 6.400 |

- Không áp giảm 5% thẻ cho phụ phí và gia hạn [Giả định].
- `overdue_rate` được chụp vào `Deposit` lúc đặt, nên đổi giá gói sau đó không làm đổi phụ phí của lượt đang mở.
- Giờ trễ đếm từ `due_at`, **tròn lên theo giờ bắt đầu**; ân hạn chỉ hoãn lúc khóa. Lấy đồ trong ân hạn thì không mất phụ phí. Qua ân hạn thì giờ đầu bị tính ngay [Giả định].
- Ví dụ: cỡ M, lấy đồ trễ 2 giờ 10 phút: 3 giờ × 4.900 = 14.700 đ.
- **Không có trần.** Rủi ro: quên 1 tuần ở cỡ L là 168 × 6.400 ≈ 1,07 triệu đ nợ. Mình không tự đặt trần, chỉ nêu ở báo cáo cuối.

### 3.4 Hủy và không đến
- Hủy trong 5 phút đầu: hoàn 100% số đã trả. Sau 5 phút, tới hết 15 phút giữ chỗ: hoàn 50% (làm tròn xuống 100 đ), để người đổi ý vẫn có lý do trả ngăn sớm thay vì để thành không đến. Hết giữ chỗ: không có nút, DB từ chối.
- Không đến trước `hold_until`: hoàn 0 đ, ngăn trống lại. `Pricing.noShowRefund(x) = 0`.

### 3.4b Tự chọn thời gian (bổ sung sau v5)
- Ngoài 3 gói cố định, người dùng chọn **N giờ** (1–`CUSTOM_MAX_HOURS` = 23) hoặc **N ngày** (1–`CUSTOM_MAX_DAYS` = 7).
- Theo giờ: `min(giá_1_giờ(cỡ) × N, giá_cỡ(trọn ngày))`. Theo ngày: `CEILING(giá_trọn_ngày × hệ_số_cỡ × N × k / 1.000.000) × 100`,
  `k` = 100 (1 ngày), `CUSTOM_MULTI_DAY_PCT` = 90 (2–6 ngày), `CUSTOM_WEEK_PCT` = 80 (từ 7 ngày).
- SQL `dbo.fn_CustomPrice(@pct, @minutes)`, Java `Pricing.customPrice`; `PricingDatabaseIntegrationTest` so S/M/L với 1–23 giờ và 1–7 ngày.
- `Deposit_Reserve(..., @custom_min)`: giá luôn tính ở server; lượt giữ `plan_id` của gói dài nhất không vượt `custom_min` (ân hạn), `Deposit.custom_min` cho hạn trả.
- Không thêm gói 1 giờ vào `StoragePlan`: `fn_HourRate` lấy giờ từ gói ngắn nhất, thêm gói sẽ đổi giá gia hạn và phụ phí.

### 3.5 Gia hạn (đã chốt Q5)
- Chỉ khi lượt `ACTIVE` và chưa bị khóa. Vẫn tối đa 3 lần, mỗi lần 15–240 phút.
- Thu `CEILING(phút / 60) × giá_1_giờ(cỡ)` ngay khi gia hạn, không cho số dư âm. Ví dụ cỡ M thêm 90 phút: 2 × 3.300 = 6.600 đ.
- Popup gia hạn hiện số tiền trừ ngay.

---

## 4. Thay đổi hợp đồng API

### 4.1 `POST /api/device/auth` và `POST /api/kiosk/unlock`

Lý do mới `OVERDUE_UNPAID`:
```json
{"result":"DENY","reason":"OVERDUE_UNPAID","deposit_id":120,"debt":14700,
 "attempts_left":5,"retry_after_sec":0,"message":"Qua han tra tu\nNap tien de mo"}
```
- `debt`: số tiền đang nợ (dương, bằng `−số_dư`).
- OLED: `Qua han tra tu` / `Nap tien de mo` (14 và 14 ký tự, ASCII).
- Điện thoại: "Tủ đã quá hạn và đang bị khóa. Bạn còn nợ 14.700 đ. Hãy nạp tiền vào ví rồi mở lại."
- Không tính vào 5 lần sai. Mở thành công sau khi nạp: `UNLOCK` `PICKUP` như cũ, thêm trường `overdue_fee` (tổng phụ phí của lượt, 0 nếu không trễ).

### 4.2 `GET /api/locker-map` (thêm trường, không bỏ trường cũ)
- `sizes`: `[{"code":"M","size_cm":"40x40x40","price_pct":130,"items":["laptop tới 15,6 inch",...],"img":"img/lockers/size-m.webp"|null}]`.
- `plans[i].prices`: `{"S":{"PIN":5000,"CARD":4800},"M":{...},"L":{...}}`; `sizes[i].hour_rate` và `sizes[i].overdue_rate`.
- `areas[i].latitude`, `longitude` (có thể `null`).
- `rules`: `hold_min`, `cancel_min`, `booking_buffer`, `card_deposit`.
- `custom` (khi có gói trọn ngày): `max_hours`, `max_days`, `hours.{S,M,L}[1..23 giờ]`, `days.{S,M,L}[1..7 ngày]`, `hour_rate`, `day_price` (chỉ để hiển thị).
- Ngăn của mình: `cancel_until`, `hold_until`, `due_at`, `locked`, `debt`, `overdue_fee`.

Không thêm API mới cho khu vực: toạ độ đi kèm danh sách khu sẵn có.

### 4.3 Dự phòng định vị theo IP
Chỉ thêm interface `service.IpGeoLocator { Optional<double[]> locate(String ip); }` và `NoIpGeoLocator` (luôn rỗng). Không gọi dịch vụ ngoài.

---

## 5. Thay đổi giao diện

Thiết kế dùng skill ui-ux-pro-max để chọn bố cục, nhưng chỉ dùng token và class trong `app.css` (và `locker-map.css` cho sơ đồ), không CDN, không màu inline, không emoji.

1. **Đăng nhập / Đăng ký** (D1). Trái: SVG lưới tủ 3 cỡ, 3 điểm nổi bật (giá theo giờ và cỡ tủ; mở bằng mật mã, thẻ từ, vân tay; chỉ đường tới tủ gần nhất). Phải: form, nút hiện/ẩn mật khẩu (`aria-pressed`), `:focus-visible`, `role="alert"`. Email nhận nhắc hạn đặt ở "Tủ của tôi" và chỉ được lưu sau khi người dùng nhập **mã 6 số gửi tới địa chỉ đó** (rà soát bảo mật M1: không cho đổi địa chỉ qua CSRF hay dùng email của người khác). Trang đăng ký không có ô email.
2. **Sơ đồ tủ** (D9, D6):
   - Vẽ lại khối tủ: cửa cao theo cỡ, nhãn mã ngăn và cỡ, biểu tượng SVG cho trạng thái, ngăn bị khóa quá hạn có biểu tượng ổ khóa.
   - Dải "Tủ gần bạn": khu gần nhất và khoảng cách, nút "Chỉ đường"; danh sách khu sắp theo khoảng cách. `watchPosition` tối đa 1 lần cập nhật / 10 giây, dừng khi tab ẩn. Bị từ chối, hết giờ, không hỗ trợ hoặc không phải HTTPS: thông báo tiếng Việt, danh sách khu như cũ.
3. **Bảng đặt ngăn**: thẻ cỡ ngăn (ảnh hoặc SVG, số đo, gợi ý vật dụng), giá theo cỡ cho từng cách mở.
   **Popup xác nhận**: số tiền trừ ngay; "Hủy trong 5 phút đầu: hoàn đủ. Sau đó tới hết giờ giữ chỗ: hoàn 50%"; "Giữ chỗ 15 phút"; "Không đến sẽ mất toàn bộ số tiền"; phụ phí quá hạn mỗi giờ; số dư còn lại sau khi đặt. Panel tự làm mới vẫn dừng khi popup mở.
4. **Tủ của tôi**: đếm ngược "hoàn đủ nếu hủy trong" (5 phút), rồi "hoàn 50% (X đ) nếu hủy trong" (tới hết giữ chỗ), và "giữ chỗ" (15 phút); nút đổi số tiền và câu xác nhận khi qua mốc 5 phút, biến mất khi hết giữ chỗ, không cần tải lại; đứng yên khi popup đang mở. Lượt quá hạn: khung cảnh báo "Đã quá hạn, tủ đang khóa", số giờ trễ, phụ phí đã thu, số tiền đang nợ, nút "Nạp tiền" tới `TopupController`. Lượt chuyển xử lý: ghi rõ đã chuyển cho nhân viên.
5. **Cảnh báo / vận hành** (OPERATOR, ADMIN): cảnh báo `OVERDUE_ESCALATED` kèm người dùng, ngăn, số giờ trễ, số nợ. Lượt gửi (`deposit.jsp`) có cột "Khóa quá hạn" và "Chuyển xử lý".
6. Mọi chỗ còn ghi "hoàn 90%", "mất 10%" được sửa.

---

## 6. Email nhắc hạn (D8)

- Job trong `LockerMonitor` (chu kỳ 15 giây sẵn có, không đụng `/api/dashboard`): `Deposit_DueSoon` → gửi → `Deposit_MarkReminded`. Gửi lỗi thì thử lại ở chu kỳ sau, tới khi quá `due_at`.
- Nội dung tiếng Việt: ngăn, khu, hạn trả (giờ Việt Nam), phụ phí mỗi giờ nếu trễ, link "Tủ của tôi" (lấy `base_url` cấu hình).
- Cấu hình ở `config/mail.local.properties` (đã nằm trong `.gitignore` theo mẫu `*.local.properties`): host, port, user, mật khẩu ứng dụng, người gửi, `base_url`. Không có file thì job tắt, ghi log một lần; web vẫn chạy offline bình thường.
- Cách gửi (đã chốt Q6): client SMTP viết bằng Java thuần (`SSLSocket` cổng 465 hoặc STARTTLS 587, `AUTH LOGIN`), không thêm thư viện. Bạn tạo mật khẩu ứng dụng Gmail và ghi vào file cấu hình.

---

## 7. Kế hoạch test

### 7.1 Unit test (TestNG, `test/test/PricingTest.java`)
Giá theo cỡ và làm tròn (bảng 3.1), thứ tự cỡ rồi thẻ, giá một giờ và phụ phí theo cỡ (bảng 3.3), tiền gia hạn, hoàn tiền khi không đến = 0, cửa sổ hủy (4:59 được, 5:00 không), giờ trễ tròn lên (0 giây, 1 giây, đúng 1 giờ, 1 giờ 1 giây), khóa sau ân hạn, mốc 15 phút / 48 giờ, phụ phí không thu trùng.

### 7.2 Integration test (DB, theo mẫu `AuditChainDatabaseIntegrationTest`)
So `Pricing` với `fn_SlotPrice`, `fn_HourRate` và `fn_OverdueRate` cho mọi gói × cỡ × cách mở; `Deposit_ChargeOverdue` chạy 2 lần chỉ thu một lần.

### 7.3 Postman (thêm thư mục "v3" vào collection v2, scenario 11–16)

| # | Kịch bản | Mong đợi |
|---|---|---|
| 6 (sửa) | Không đến | `NO_SHOW`, hoàn 0 đ (trước đây 90%) |
| 11 | Quá hạn bị khóa (`sql/test_overdue.sql` dời `due_at` về quá khứ, số dư nhỏ) | `DENY OVERDUE_UNPAID`, có `debt` |
| 12 | Nạp tiền (script duyệt nạp) rồi mở lại | `UNLOCK PICKUP`, `overdue_fee` đúng |
| 13 | Hủy trong 5 phút / sau 5 phút | hoàn 100% / số cũ: lỗi 50052, số đúng: hoàn 50% |
| 14 | Đặt khi số dư dưới mức đệm | lỗi 50046 |
| 15 | Chuyển xử lý sau 48 giờ | `escalated_at` có giá trị, có cảnh báo `OVERDUE_ESCALATED`, audit `OVERDUE_ESCALATE` |
| 16 | Kiosk với lượt bị khóa | `OVERDUE_UNPAID`, message tiếng Việt có số nợ |
| 17 | Gia hạn lượt chưa quá hạn / lượt đã khóa | trừ đúng tiền gia hạn / lỗi 50048 |

Không có bước đoán sai mã nào trước scenario 5 (Lessons). `OVERDUE_UNPAID` không làm giảm `attempts_left`.
`sql/test_v2_setup.sql` tạo thêm `v3overdue`, `v3poor`; `ScenarioSender` chạy lại các kịch bản cũ (remote, spoof, sensor).

### 7.4 End-to-end trên trình duyệt (claude-in-chrome)
Đăng nhập (sáng/tối, 375px, hiện/ẩn mật khẩu, sai mật khẩu); sơ đồ (vẽ tủ mới, định vị cho phép / từ chối, chỉ đường); đặt từng cỡ, popup; hủy trong 5 phút; nút hủy đổi sang hoàn 50% sau 5 phút và biến mất khi hết giữ chỗ; quá hạn trên "Tủ của tôi", nạp tiền, duyệt, mở bằng `/k/LOCKER-01`; cảnh báo chuyển xử lý trên trang cảnh báo; email nhắc hạn tới hộp thư thử. Hard reload sau mỗi lần deploy CSS/JS.

---

## 8. Cách làm việc

1. Giai đoạn 2–5 như prompt. Mỗi agent có khoảng 200–300k token; gần hết thì viết `docs/handoff/<agent>.md` (mục tiêu, đã làm, còn lại, file đã sửa, cách kiểm tra) và mình mở phiên mới từ handoff đó.
2. Lỗi gặp trong lúc làm ghi vào `docs/handoff/v3-errors.md` (triệu chứng, nguyên nhân, cách sửa); bài học chung thêm vào cuối Lessons của `CLAUDE.md`.
3. Sau mỗi giai đoạn: tự kiểm, chạy test, rồi 3 agent rà soát chéo (SQL và tiền; UI/UX và quy tắc CLAUDE.md; bảo mật). Lặp tới khi không còn lỗi mức trung bình trở lên.
4. Không commit, không push nếu bạn chưa yêu cầu.

---

## 9. Giả định và câu hỏi cần xác nhận

| # | Câu hỏi | Mặc định nếu không trả lời |
|---|---|---|
| Q1 | Hệ số M/L | S ×1,00, M ×1,30, L ×1,69 |
| Q2 | Khoản đệm sau khi đặt | 10.000 đ |
| Q3 | Cách tính giá một giờ cho phụ phí | **Đã chốt**: một giá chung theo cỡ từ gói ngắn nhất. Còn giả định: đếm giờ từ `due_at`, ân hạn chỉ hoãn khóa |
| Q4 | Ân hạn | giữ `grace_min` hiện có (10, 10, 30 phút) |
| Q5 | Gia hạn | **Đã chốt**: thu giá một giờ × số giờ thêm; cấm khi đã khóa |
| Q6 | Gửi email | **Đã chốt**: SMTP Java thuần (SSL 465 / STARTTLS 587), Gmail mật khẩu ứng dụng; email xác nhận bằng mã ở "Tủ của tôi" |
| Q7 | Thiết kế lại tủ | **Đã chốt**: vẽ lại hình tủ trên sơ đồ; dãy 4 hàng S, S, M, L; dãy 2 hàng M, L |
| — | Phụ phí không trần | giữ không trần, nêu rủi ro ở báo cáo cuối |
| — | Toạ độ giả | quanh Hòa Lạc (21.0130, 105.5270); bạn thay sau |
