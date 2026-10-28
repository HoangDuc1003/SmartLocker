# Smart Locker v2: spec

Trạng thái: **đã duyệt 17/10/2026**, đang triển khai. Chưa có code nào được sửa theo spec này.
Ngày: 17/10/2026. Dự án: PRJ301, Java 8 Servlet/JSP, Tomcat 9, SQL Server.

Các mục đánh dấu **[Giả định]** là chi tiết bạn chưa trả lời. Mình chọn mặc định; bạn sửa khi duyệt.

---

## 1. Phạm vi

### Trong phạm vi
1. Dữ liệu demo: giữ dữ liệu hiện có, thêm script `sql/06_demo_v2.sql` (mục 3).
2. Bốn cách mở tủ, do server quyết định:
   - mật mã trên bàn phím 4x4;
   - mật mã trên điện thoại (quét QR rồi nhập);
   - thẻ từ RC522;
   - vân tay AS608.
3. API thiết bị v2, cùng Postman collection và environment.
4. Trang web "Tủ của tôi", gộp "Thẻ của tôi" với "Lượt đặt của tôi".
5. Thay đổi về giá:
   - chọn thẻ từ được giảm 5%;
   - lần đầu đăng ký thẻ thì cọc 30.000 đ;
   - không đến lấy tủ thì phạt 10%, có popup xác nhận lúc đặt;
   - bỏ gói "Demo 2 minutes".
6. Kiểm thử end-to-end bằng Postman và giao diện web.
7. Deploy theo phương án A: laptop, Cloudflare quick tunnel và trang chuyển tiếp trên GitHub Pages.

### Ngoài phạm vi
- Firmware ESP32: spec chỉ chốt hợp đồng API.
- Deploy 24/7 trên cloud (Render cộng Azure SQL): để làm sau.
- Mở cửa khi mất mạng: thiết bị từ chối và báo "Mat ket noi".
- Cảm biến cửa và cân: không có. `door_open_sec` gửi thời gian mở chốt cố định, `weight_delta_g` gửi 0.

---

## 2. Các quyết định đã chốt

| # | Quyết định |
|---|---|
| Q1, Q8 | Không seed lại. Script `06` chọn 4 operator, mỗi người 1 khu vực. 18 operator còn lại chuyển sang `DISABLED` (không xóa, để giữ lịch sử và chuỗi audit). |
| Q3, Q6 | Mỗi khu vực có 1 hộp IoT: ESP32, OLED 0.96", bàn phím 4x4, RC522, AS608, mô tơ đẩy thanh chốt. **Chỉ có 1 cơ cấu khóa**, nên server chỉ trả "mở" hoặc "không mở", không chọn ngăn. |
| Q4 | Server quyết định trực tuyến. Mất mạng thì từ chối. |
| Q9, Q15 | Khi đặt tủ, người dùng chọn 1 trong 3: **Mật mã** (dùng cho cả bàn phím và điện thoại), **Thẻ từ**, **Vân tay**. |
| Q10 | Mỗi lượt đặt có một mật mã 6 số riêng, hết hiệu lực khi lượt kết thúc. |
| Q11 | Trang điện thoại không cần đăng nhập. Sai 5 lần trong 5 phút thì khóa nhập 2 phút trên hộp đó (tính chung cho mọi cách mở). |
| Q12 | Xác thực đúng lần đầu: check-in, RESERVED → ACTIVE. Lần đúng tiếp theo: lấy đồ và kết thúc, ACTIVE → COMPLETED. Chốt tự đóng sau 8 giây. Heartbeat của hộp thật 3 giây một lần. |
| Q13 | QR được **in và dán** lên hộp. OLED chỉ hiện trạng thái. |
| Q14 | Hộp thật là `LOCKER-01` (Canteen, dãy CANT-A). Mọi ngăn của CANT-A dùng chung 1 chốt. 7 thiết bị còn lại vẫn là demo, server giả heartbeat cho chúng. |
| Q15 | Chọn Thẻ từ: giá gói giảm 5%, **làm tròn lên tới 100 đ** (ví dụ 5.000 đ → 4.750 đ → **4.800 đ**). Lần đầu dùng thẻ phải cọc 30.000 đ, trừ vào ví. Người dùng tự tới hộp quét thẻ để đăng ký, sau đó web hiện UID thẻ. |
| Q15 | Bỏ gói "Demo 2 minutes": đặt `is_active = 0` (đã có lượt gửi tham chiếu nên không xóa được). |
| Q16 | Vân tay đăng ký **một lần cho mỗi người trên mỗi hộp**, dùng lại cho các lượt sau. |
| Q17 | Trang mới "Tủ của tôi". `MyCardController` và `BookingController` (GET) chuyển hướng sang trang này. Menu chỉ còn một mục. |
| Q19 | Không đến trước `hold_until`: hoàn 90%, giữ lại 10% (`CEILING`, tính bằng đồng). Popup xác nhận lúc đặt nêu rõ quy định này. |
| Q20 | Cloudflare quick tunnel cùng trang chuyển tiếp cố định trên GitHub Pages (mục 7). |

**Đã chốt thêm (vòng 4):**
- **Tiền cọc thẻ** 30.000 đ chỉ thu một lần cho mỗi thẻ, để bù khi thẻ bị lấy mất. Báo mất thì không hoàn cọc; nhân viên thu hồi thẻ thì hoàn lại.
- **Thông báo OLED** dạng ASCII không dấu, và **trang điện thoại** công khai không cần đăng nhập: đã đồng ý.

**[Giả định]**
- **Giảm 5%**: áp dụng cho mọi lượt chọn cách mở Thẻ từ.
- **Lưu mật mã**: mật mã được **lưu dạng rõ** (cột `pin_code`), chỉ chủ lượt đặt và ADMIN xem được. Vòng 1 mình đề xuất chỉ lưu hash, nhưng trang "Tủ của tôi" cần hiện lại mật mã khi người dùng bấm, nên phải đổi. Mật mã sống ngắn và chỉ mở được một lượt; đây là đồ án nên chấp nhận.
- **Giới hạn không đến**: giữ quy định cũ, không đến 3 lần trong 7 ngày thì bị khóa đặt tủ.

---

## 3. Thay đổi dữ liệu (`sql/06_demo_v2.sql`, có UTF-8 BOM)

| Thay đổi | Chi tiết |
|---|---|
| `Deposit` thêm cột | `open_method NVARCHAR(12)` (`PIN`, `CARD`, `FINGERPRINT`), `pin_code CHAR(6) NULL`, `enroll_code CHAR(6) NULL`, `enroll_expires DATETIME2 NULL`. Unique index có lọc: `pin_code` không trùng giữa các lượt `RESERVED`/`ACTIVE`. |
| Bảng mới `Fingerprint` | `fp_id INT IDENTITY`, `user_id`, `device_id`, `sensor_slot INT` (1–160), `status` (`ACTIVE`, `DELETED`), `created_at`. Unique `(device_id, sensor_slot)` cho các dòng ACTIVE. |
| Bảng mới `AuthAttempt` | `device_id`, `at`, `method`, `ok BIT`, `reason`. Dùng để khóa nhập khi sai 5 lần và để audit. |
| `UserCard` thêm cột | `deposit_amount BIGINT DEFAULT 0`, `registered_device_id INT NULL`. |
| `StoragePlan` | "Demo 2 minutes" chuyển sang `is_active = 0`. |
| Users | 4 operator `ACTIVE`, mỗi người 1 trong 4 khu vực. Các operator còn lại chuyển sang `DISABLED`. |
| Procedure | Sửa `Deposit_Reserve` (giá theo cách mở, sinh mật mã), sửa `Deposit_ExpireNoShow` (phạt 10%). Thêm `Device_Authorize`, `Enroll_Start`, `Enroll_Finish`. |
| Dữ liệu demo | Các lượt đang mở của CANT-A được gán `open_method` và mật mã. 1 người dùng có vân tay đăng ký sẵn, 1 người có thẻ sẵn, để demo ngay không cần chuẩn bị. |

Script **chạy lại được nhiều lần** (`IF COL_LENGTH ... IS NULL`, `CREATE OR ALTER`).

---

## 4. Hợp đồng API thiết bị v2

Quy ước chung:
- Mọi endpoint `/api/device/*` dùng header `X-API-Key: <key của hộp>`. Server tìm ra `device_id` từ key; body không bao giờ gửi `device_id`.
- JSON dạng UTF-8. Thời gian gửi lên theo UTC, dạng `yyyy-MM-dd HH:mm:ss`.
- `message` trong phản hồi là **ASCII không dấu, tối đa 16 ký tự mỗi dòng, tối đa 2 dòng**, để in thẳng lên OLED. Font của OLED không có tiếng Việt có dấu [Giả định].
- Mã HTTP:
  - `200`: có kết quả nghiệp vụ, kể cả từ chối (`result: DENY`).
  - `400`: sai định dạng body.
  - `401`: sai key.
  - `500`: lỗi server; thiết bị hiện "Loi may chu".

### 4.1 Heartbeat: `POST /api/health` (giữ đường dẫn cũ, mở rộng phản hồi)

Request:
```json
{"firmware":"2.0","uptime_sec":1234}
```
Response:
```json
{"interval_sec":3,
 "commands":[{"command_id":15,"action":"UNLOCK","slot_code":"A04","open_sec":8,"message":"Mo tu\n(dien thoai)",
               "phase":"ACCESS","physical":true},
             {"command_id":16,"action":"DELETE_FP","sensor_slot":7}],
 "server_time":"2026-10-17 07:03:00"}
```
- v6: lệnh `UNLOCK` của trang điện thoại có `phase` (`CHECK_IN`, `ACCESS` hoặc `PICKUP`); lệnh mở từ xa của nhân viên
  không có `phase`. Hộp mở chốt như nhau cho mọi phase và theo cờ `physical`.
- `action` có 3 giá trị:
  - `UNLOCK`: mở chốt (từ điện thoại hoặc lệnh từ xa);
  - `DELETE_FP`: xóa mẫu vân tay trên AS608;
  - `CANCEL_ENROLL`: hủy chế độ đăng ký.
- Bỏ phần check-in qua trường `slots.occupied` của thiết kế cũ: v2 check-in qua `auth`. Các trường cũ (`blocked_cards`, `reserved`) vẫn trả về để `ScenarioSender` cũ chạy được, firmware mới bỏ qua chúng.

### 4.2 Xác thực tại hộp: `POST /api/device/auth`

Request, một trong 3 dạng:
```json
{"method":"PIN","pin":"482913"}
{"method":"CARD","card_uid":"04A1B2C3"}
{"method":"FINGERPRINT","sensor_slot":7}
```
Response khi được mở:
```json
{"result":"UNLOCK","phase":"CHECK_IN","deposit_id":120,"slot_code":"A04",
 "open_sec":8,"message":"Moi cat do\nNgan A04"}
```
- `phase` là `CHECK_IN` (RESERVED → ACTIVE), `ACCESS` (v6: mở trong lúc thuê, lượt vẫn ACTIVE) hoặc `PICKUP`
  (ACTIVE → COMPLETED, ngăn trở lại trống).

**v6: mở nhiều lần trong một lượt thuê.** Request có thêm trường tùy chọn `intent`:

| `intent` | Lượt `ACTIVE` chưa khóa quá hạn |
|---|---|
| không gửi | `UNLOCK PICKUP` như trước (firmware cũ, Postman cũ) |
| `ASK` | `CHOOSE`: không mở, không đổi gì, không tính là đoán sai |
| `OPEN` | `UNLOCK ACCESS`: lượt vẫn `ACTIVE`, ngăn vẫn `OCCUPIED`, ghi audit `ACCESS` |
| `CHECKOUT` | `UNLOCK PICKUP` |

Lượt `RESERVED` luôn `CHECK_IN`. Lượt bị khóa quá hạn: ví âm thì `DENY OVERDUE_UNPAID`; ví ≥ 0 thì mọi `intent` đều là
`PICKUP` (không `CHOOSE`, không `ACCESS`). `intent` khác ba giá trị trên trả `400`.

```json
{"method":"PIN","pin":"482913","intent":"ASK"}
{"result":"CHOOSE","deposit_id":120,"slot_code":"A04","choose_sec":15,"options":["OPEN","CHECKOUT"],
 "message":"A: Mo tu  * huy\nB: Tra tu A04"}
{"method":"PIN","pin":"482913","intent":"OPEN"}
{"result":"UNLOCK","phase":"ACCESS","deposit_id":120,"slot_code":"A04","open_sec":8,"message":"Moi mo tu\nNgan A04","physical":true}
```
Hộp nhận `CHOOSE` thì giữ PIN / UID thẻ / ô vân tay vừa đọc, hiện hai dòng của `message`, chờ phím `A` (gửi lại với
`OPEN`) hoặc `B` (gửi lại với `CHECKOUT`); `*` hoặc hết `choose_sec` giây thì hủy. Lần gửi lại là một lần xác thực đầy đủ:
server không giữ trạng thái giữa hai lần gọi.

Response khi từ chối:
```json
{"result":"DENY","reason":"WRONG_CODE","attempts_left":3,"retry_after_sec":0,"message":"Sai ma\nCon 3 lan"}
```

| `reason` | Khi nào |
|---|---|
| `WRONG_CODE` | Mật mã không khớp lượt nào đang mở trên hộp này |
| `LOCKED_OUT` | Sai 5 lần trong 5 phút; `retry_after_sec` cho biết còn chờ bao lâu |
| `NO_BOOKING` | Thẻ hoặc vân tay hợp lệ nhưng người đó không có lượt đang mở trên hộp này |
| `METHOD_MISMATCH` | Lượt đặt chọn cách mở khác (ví dụ đặt bằng mật mã nhưng quẹt thẻ) |
| `CARD_BLOCKED` | Thẻ đã báo mất hoặc bị khóa |
| `UNKNOWN_CARD` / `UNKNOWN_FINGER` | Chưa đăng ký |
| `EXPIRED` | Lượt đặt đã quá `hold_until` (đã chuyển sang NO_SHOW) |
| `ACCOUNT_LOCKED` | Tài khoản người dùng bị khóa |

Server ghi mọi lần thử vào `AuthAttempt` và ghi `Audit_Append` cho các lần mở (`CHECK_IN`, `ACCESS`, `COMPLETE`).

### 4.3 Đăng ký thẻ hoặc vân tay tại hộp

Trên web, "Tủ của tôi" hiện **mã đăng ký 6 số**, có hạn 10 phút. Mã này sinh ra khi lượt đặt chọn Thẻ từ hoặc Vân tay mà người dùng chưa đăng ký trên hộp đó.

Tại hộp: bấm `B` (thẻ) hoặc `C` (vân tay), rồi nhập mã đăng ký.

`POST /api/device/enroll/start`
```json
{"type":"FINGERPRINT","enroll_code":"551204"}
```
Phản hồi khi thành công:
```json
{"result":"OK","sensor_slot":7,"message":"Dat ngon tay\n2 lan"}
```
- Server cấp số `sensor_slot` còn trống trên hộp. Với `type: "CARD"` thì không có `sensor_slot`, và `message` là `Quet the`.

`POST /api/device/enroll/finish`
```json
{"type":"FINGERPRINT","enroll_code":"551204","sensor_slot":7}
{"type":"CARD","enroll_code":"551204","card_uid":"04A1B2C3"}
```
Phản hồi khi thành công:
```json
{"result":"OK","message":"Dang ky xong"}
```
Thẻ mới đăng ký thì server trừ 30.000 đ cọc. Từ lúc đó, web hiện UID thẻ của người dùng.

Các lý do lỗi (`result: "ERROR"`, kèm `reason`):
- `BAD_CODE`: mã đăng ký sai.
- `CODE_EXPIRED`: mã đã quá 10 phút.
- `CARD_IN_USE`: UID thẻ đã thuộc người khác.
- `SENSOR_FULL`: cảm biến hết chỗ lưu mẫu.
- `INSUFFICIENT_BALANCE`: không đủ tiền cọc.

### 4.4 Báo sự kiện mở/đóng: `POST /api/locker/batch` (giữ nguyên)

Thiết bị gửi một bản ghi sau mỗi lần chốt đóng lại:
- `open_source`: `PIN`, `PHONE`, `CARD`, `FINGERPRINT` hoặc `REMOTE`.
- `door_open_sec`: thời gian chốt mở.
- `weight_delta_g`: 0.
- `rfid_ok`: true nếu lần mở đó được xác thực.
- `command_id`: lấy từ lệnh nếu mở bằng điện thoại hoặc lệnh từ xa.

Endpoint này **không** kết thúc lượt gửi nữa, vì việc đó đã làm ở `auth` (phase `PICKUP`). Chỉ còn lưu lịch sử và chạy luật cảnh báo.

### 4.5 Điện thoại (công khai, không cần API key)

| Endpoint | Mô tả |
|---|---|
| `GET /k/{device_code}` | Trang nhập mật mã của hộp, giao diện tiếng Việt, tối ưu cho điện thoại. Đây là đích của QR. |
| `POST /api/kiosk/unlock` | Body `{"device_code":"LOCKER-01","pin":"482913","intent":"ASK"}`. Server dùng chung logic xác thực và giới hạn sai với mục 4.2 (kể cả `intent`). Nếu đúng thì tạo lệnh `UNLOCK` có `phase` (thiết bị nhận trong vòng 3 giây qua heartbeat). Response giống `auth` nhưng `message` có dấu, kèm `command_id`. v6: `CHOOSE` thì trang hiện hai nút "Mở tủ" / "Trả tủ" và gửi lại cùng mật mã với `OPEN` / `CHECKOUT`. |

`SecurityFilter` mở công khai `/k/*` và `/api/kiosk/unlock`.

### 4.6 Tóm tắt luồng

```
Web: đặt tủ (chọn cách mở) → Deposit RESERVED, trừ tiền, sinh mật mã hoặc mã đăng ký
Hộp: [nếu Thẻ/Vân tay mà chưa đăng ký] enroll/start → enroll/finish
Hộp: auth (lần 1) → UNLOCK, CHECK_IN → mở chốt 8 giây → batch
Hộp: auth ASK (các lần sau) → CHOOSE → phím A: auth OPEN → UNLOCK, ACCESS → mở chốt, lượt vẫn ACTIVE → batch
                                    → phím B: auth CHECKOUT → UNLOCK, PICKUP → COMPLETED, ngăn trống → batch
Điện thoại: /k/LOCKER-01 → kiosk/unlock → lệnh UNLOCK → heartbeat → mở chốt
Không đến trước hold_until → NO_SHOW, hoàn 90%
```

---

## 5. Thay đổi web

1. **Đặt tủ** (bảng chi tiết ngăn trên sơ đồ tủ):
   - Chọn cách mở bằng 3 nút radio. Thẻ từ hiện giá đã giảm 5%, và ghi "cọc 30.000 đ lần đầu" nếu người dùng chưa có thẻ.
   - Bấm đặt thì hiện **popup xác nhận** gồm: tổng tiền, cách mở, "giữ chỗ 15 phút; không đến sẽ mất 10%".
2. **Tủ của tôi** (`MyLockerController`, trang mới):
   - Lượt đang mở: ngăn, hạn trả, cách mở, mật mã (che sẵn, bấm mới hiện), mã đăng ký nếu cần, đếm ngược thời gian giữ chỗ.
   - Thẻ từ: UID, tiền cọc, nút báo mất.
   - Vân tay: danh sách hộp đã đăng ký.
   - Lịch sử lượt gửi.
3. **Menu**: "Lượt đặt của tôi" và "Thẻ của tôi" được thay bằng "Tủ của tôi". URL cũ chuyển hướng sang trang mới.
4. **Trang `/k/{device_code}`**: một ô nhập 6 số, bàn phím số của điện thoại, thông báo kết quả, đếm ngược khi bị khóa nhập.

---

## 6. Kế hoạch test

### 6.1 Postman (`docs/postman/`)
- `SmartLocker-v2.postman_collection.json` (v2.1), chia thư mục: Heartbeat, Auth, Enroll, Kiosk (điện thoại), Batch, Scenarios.
- `SmartLocker-local.postman_environment.json` và `SmartLocker-tunnel.postman_environment.json`, chứa `base_url`, `api_key`, `device_code`, `pin`...
- Mỗi request có `pm.test` kiểm tra mã HTTP, `result` và `reason`. Các bước nối nhau bằng `pm.environment.set` (ví dụ lưu `deposit_id`).
- Hướng dẫn chạy bằng Postman Runner, kèm Newman nếu có Node.

### 6.2 Kịch bản end-to-end

Mỗi kịch bản kiểm tra cả phản hồi API lẫn giao diện web:

| # | Kịch bản | Kết quả mong đợi |
|---|---|---|
| 1 | Đặt tủ bằng mật mã → `auth` PIN → `auth` PIN lần 2 | CHECK_IN rồi PICKUP. Sơ đồ: ngăn đã đặt → đang dùng → trống. Audit có `CHECK_IN` và `COMPLETE`. |
| 2 | Như 1, nhưng lần 1 mở từ trang `/k/LOCKER-01` | Có lệnh UNLOCK, heartbeat kế tiếp nhận được lệnh, lượt chuyển ACTIVE |
| 3 | Đặt bằng thẻ, lần đầu: enroll CARD → `auth` CARD ×2 | Trừ cọc 30.000 đ và giá đã giảm 5%. "Tủ của tôi" hiện UID thẻ. |
| 4 | Đặt bằng vân tay: enroll FINGERPRINT → `auth` FINGERPRINT ×2. Đặt lượt thứ 2 thì không phải đăng ký lại. | `sensor_slot` được cấp; lượt sau dùng lại |
| 5 | Sai mật mã 5 lần | Lần 6 trả `LOCKED_OUT` kèm `retry_after_sec`; sau 2 phút nhập lại được |
| 6 | Đặt tủ nhưng không đến (chỉnh `hold_until` về quá khứ bằng script test) | NO_SHOW, hoàn 90%. Popup lúc đặt có nêu quy định. |
| 7 | Mật mã của lượt đã kết thúc, hoặc của hộp khác | `WRONG_CODE` |
| 8 | Thẻ đã báo mất | `CARD_BLOCKED` |
| 9 | Đặt bằng mật mã nhưng quẹt thẻ | `METHOD_MISMATCH` |
| 10 | Sai API key hoặc body sai định dạng | `401` / `400` |

Ngoài ra:
- Smoke test toàn bộ trang (curl) không có lỗi 500.
- Kiểm tra giao diện trên trình duyệt ở cả nền sáng và nền tối, và ở chiều rộng 375px.
- Chạy lại kịch bản cũ của `ScenarioSender` (remote, spoof, sensor) để chắc không vỡ.

Phần cứng thật (ESP32) do bạn tự chạy, theo cùng các kịch bản.

---

## 7. Kế hoạch deploy (phương án A)

1. **Máy chủ**: laptop chạy Tomcat 9 (`E:/apache-tomcat-9.0.113`) và SQL Server đang có. Không cần sửa `DbContext`.
2. **Mở ra Internet**: chạy `cloudflared tunnel --url http://localhost:8080` để nhận một địa chỉ `https://<ngẫu-nhiên>.trycloudflare.com`. Quick tunnel không cần tài khoản, và **địa chỉ đổi mỗi lần chạy lại**.
3. **Địa chỉ cố định**: dùng nhánh `gh-pages` của chính repo `HoangDuc1003/SmartLocker` (public). Bạn bật Pages một lần ở Settings → Pages → Branch `gh-pages`. Link cố định là `https://hoangduc1003.github.io/SmartLocker/`. Nhánh gồm 3 file:
   - `index.html`: chuyển tiếp tới `<tunnel>/SmartLocker/`, dành cho giảng viên.
   - `k/LOCKER-01/index.html`: chuyển tiếp tới `<tunnel>/SmartLocker/k/LOCKER-01`. Đây là đích của QR dán trên hộp, nên QR **không phải in lại**.
   - `config.json`: `{"base_url":"https://<tunnel>/SmartLocker"}` cho ESP32.

   Mỗi lần chạy lại tunnel thì chạy script `scripts/update-tunnel-link.ps1`. Script này đọc địa chỉ tunnel mới, sửa 3 file trên rồi đẩy lên GitHub.
4. **ESP32**: lúc khởi động gọi `GET https://hoangduc1003.github.io/SmartLocker/config.json` để lấy `base_url`. Gặp lỗi kết nối thì đọc lại. Gọi HTTPS bằng `WiFiClientSecure` với `setInsecure()`, chấp nhận được với đồ án.
5. **Hướng dẫn chạy demo**: viết vào `docs/deploy.md`, gồm checklist trước buổi demo (bật SQL Server và Tomcat, chạy tunnel, chạy script cập nhật link, thử bằng 4G).

**Đã tra (17/10/2026):**
- **Quick tunnel** ([Cloudflare docs](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)):
  - tối đa 200 request đang xử lý cùng lúc, vượt thì trả 429;
  - không hỗ trợ SSE (app không dùng SSE);
  - không cam kết uptime, chỉ dành cho test và demo.

  Với 1 hộp gửi heartbeat 3 giây một lần, cộng vài người xem web, thì dư sức.
- **GitHub Pages**: sau khi push có thể mất **tới khoảng 10 phút** mới cập nhật, và trình duyệt có thể giữ bản cũ thêm khoảng 10 phút nữa. Nguồn là trang hỗ trợ cũ của GitHub và diễn đàn, chưa thấy tài liệu chính thức mới. Cách xử lý: chạy tunnel và script cập nhật link **ít nhất 20 phút trước buổi demo**, và thử bằng tab ẩn danh. Riêng ESP32 đọc `config.json` không qua cache trình duyệt, nên chỉ phải chờ phần build.
- **Wi-Fi và HTTPS của ESP32**: bạn đã nối Wi-Fi và nhập mật khẩu được. Phần gọi HTTPS (`WiFiClientSecure`) bạn tự kiểm tra trên phần cứng.

---

## 8. Tiêu chí hoàn thành

- [ ] `06_demo_v2.sql` chạy được trên DB hiện tại và chạy lại lần 2 không lỗi. Có 4 operator, mỗi người 1 khu vực. Gói Demo 2 phút đã tắt.
- [ ] Cả 10 kịch bản ở mục 6.2 pass trong Postman Runner. Collection và environment nằm trong `docs/postman/`.
- [ ] Giao diện web khớp mỗi kịch bản (sơ đồ, "Tủ của tôi", audit, số dư).
- [ ] Smoke test toàn bộ trang không có lỗi 500. Không có chữ tiếng Anh mới hiện cho người dùng (trừ mã kỹ thuật).
- [ ] Giảng viên mở được web qua link GitHub Pages từ mạng khác.
- [ ] Một request giả lập ESP32 gửi từ mạng 4G qua tunnel chạy thành công (heartbeat và auth).
- [ ] Có `docs/deploy.md` và `scripts/update-tunnel-link.ps1`.
- [ ] Có ít nhất một vòng rà soát chéo bằng agent và không còn lỗi mức trung bình trở lên. `CLAUDE.md` được thêm bài học mới.

## 9. Thứ tự thực hiện đề xuất

1. SQL `06`: cột, bảng và procedure mới, kèm dữ liệu demo.
2. API `auth`, `enroll`, `kiosk`, heartbeat v2 và `SecurityFilter`.
3. Postman collection, chạy 10 kịch bản ở mức API.
4. Web: đặt tủ, popup, "Tủ của tôi", trang `/k/...`.
5. Test end-to-end trên giao diện, rồi rà soát chéo.
6. Deploy: tunnel, GitHub Pages, tài liệu, rồi thử bằng 4G.
