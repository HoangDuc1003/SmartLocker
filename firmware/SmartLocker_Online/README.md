# Hộp LOCKER-01 nối web (ESP32)

Sketch `SmartLocker_Online.ino` biến hộp thật thành thiết bị `LOCKER-01` (khu CANT-A) của web.
Hộp không tự quyết định mở: mọi PIN, thẻ, vân tay đều gửi lên máy chủ, máy chủ trả `UNLOCK` thì hộp mới mở chốt.

```
ESP32 ──Wi-Fi──► Tomcat /SmartLocker/api   (header X-API-Key = khóa của LOCKER-01)
  POST /api/health              3 giây/lần: giữ LOCKER-01 trực tuyến, nhận lệnh UNLOCK / DELETE_FP
  POST /api/device/auth         PIN 6 số, UID thẻ, số ô vân tay (+ intent) -> UNLOCK, CHOOSE hoặc DENY + câu cho màn LCD
  POST /api/device/enroll/...   đăng ký thẻ (phím B) / vân tay (phím C) bằng mã 6 số ở "Tủ của tôi"
```

Máy chủ không bao giờ gọi vào hộp, nên không cần biết IP của ESP32. Lệnh mở từ điện thoại (QR `/k/LOCKER-01`)
hoặc từ nhân viên nằm chờ và hộp nhận ở heartbeat kế tiếp (chậm nhất khoảng 3 giây).

## 1. Chọn cách nối mạng

| Cách | Khi nào dùng | `secrets.h` |
|---|---|---|
| **LAN** (khuyên dùng khi demo) | ESP32 và laptop chạy Tomcat chung một Wi-Fi. Nên bật **Mobile hotspot** của laptop (băng tần 2.4 GHz) rồi cho ESP32 bắt vào: không phụ thuộc Wi-Fi phòng học, IP ổn định. | `SERVER_BASE "http://<IP laptop>:8080/SmartLocker"`, `CONFIG_URL ""` |
| **Internet** (Cloudflare tunnel) | Hộp ở mạng khác laptop, hoặc muốn giống triển khai thật. Chậm hơn (HTTPS qua tunnel). | `CONFIG_URL "https://hoangduc1003.github.io/SmartLocker/config.json"` (xem `docs/deploy.md`) |

IP laptop: `ipconfig` → mục đang dùng (Wi-Fi, hoặc "Local Area Connection*" khi bật hotspot, thường là `192.168.137.1`) → `IPv4 Address`.

## 2. Cài đặt

1. **Arduino IDE** → Boards Manager: `esp32` by Espressif (đã thử với 3.3.x). Board: **ESP32 Dev Module**.
2. **Library Manager**: `MFRC522`, `Keypad`, `Adafruit Fingerprint Sensor Library`, `ArduinoJson` (7.x),
   `LiquidCrystal I2C` (của Frank de Brabander). Servo chạy bằng LEDC của ESP32, không cần thư viện ESP32Servo.
3. Chép `secrets.example.h` thành `secrets.h` (cùng thư mục), điền Wi-Fi, `SERVER_BASE`, và `DEVICE_API_KEY` =
   phần sau `LOCKER-01=` trong `config/device-keys.local.properties` (chưa có thì chạy `scripts/set-device-key.ps1`).
   `secrets.h` đã nằm trong `.gitignore`, không commit.
4. **Sơ đồ chân** (giống bản `smart_locker_v4`, không phải đấu lại):

   | Thiết bị | Chân ESP32 |
   |---|---|
   | RC522 | SS 4, SCK 16, MOSI 17, MISO 34, RST nối 3V3 |
   | AS608 | TX → 35, RX → 15 (tắt bằng `USE_FINGERPRINT = false` nếu cảm biến lỗi) |
   | LCD 1602 I2C | SDA 21, SCL 22, địa chỉ 0x27 (một số module là 0x3F) |
   | Servo chốt | 32 (khóa 0°, mở 85°) |
   | Servo cửa | 2 (đóng 0°, mở 180°) |
   | SRF05 | TRIG 5, ECHO 18 qua mạch chia áp |
   | Keypad | R1–R4: 13, 14, 25, 26; C1–C4: 33, 19, 23, 27 |

   Khác sketch Blynk: bản này không phát Wi-Fi `SmartDoorLock` và không dùng Blynk, mà bắt Wi-Fi/hotspot của laptop
   và hỏi web. Phím `B` là đăng ký **thẻ**, `C` là đăng ký **vân tay** (mã 6 số từ web), PIN do web cấp (không còn PIN chủ
   `1234`). Thẻ và vân tay không lưu trong hộp mà trên web.
5. **Tường lửa Windows**: lần đầu Tomcat chạy, Windows hỏi cho Java truy cập mạng → tích cả **Private**. Nếu ESP32 vẫn báo
   "Khong goi duoc may chu", mở cổng 8080 (PowerShell **Run as administrator**):
   `New-NetFirewallRule -DisplayName "Tomcat 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow`
6. Nạp sketch, mở Serial Monitor 115200. Thấy `Wi-Fi OK, IP ...` và trên web (Thiết bị / bản đồ) `LOCKER-01` trực tuyến là xong.

Thử nhanh từ điện thoại cùng Wi-Fi: mở `http://<IP laptop>:8080/SmartLocker/` — mở được thì ESP32 cũng gọi được.

## 3. Dùng tại hộp

| Phím / thao tác | Việc |
|---|---|
| `0-9` rồi `#` | Gửi PIN 6 số của lượt đặt |
| `*` | Xóa PIN / hủy đăng ký |
| Quẹt thẻ | Mở bằng thẻ đã đăng ký |
| Đặt ngón tay | Mở bằng vân tay (AS608 tìm số ô, gửi số ô lên web) |
| `B` + mã đăng ký + `#`, rồi quẹt thẻ | Đăng ký thẻ cho lượt đặt |
| `C` + mã đăng ký + `#`, rồi đặt ngón tay 2 lần | Đăng ký vân tay (web chọn số ô, hộp lưu mẫu vào ô đó) |
| `D` | Cửa đang đóng: xem IP của hộp và tình trạng máy chủ. Cửa đang mở: khóa ngay |
| `A` / `B` sau `A: Mo tu` / `B: Tra tu` | Lượt đang thuê: `A` mở tủ (lượt vẫn chạy), `B` trả tủ (kết thúc lượt); `*` hoặc 15 giây không bấm thì hủy |

**Mở nhiều lần (firmware 3.3).** Mọi lần gửi PIN / thẻ / vân tay đều kèm `"intent":"ASK"`. Lượt `RESERVED` vẫn mở ngay
(CHECK_IN). Lượt đang thuê thì máy chủ trả `CHOOSE`: hộp giữ PIN / UID thẻ / số ô vân tay vừa đọc, hiện
`A: Mo tu  * huy` / `B: Tra tu A01`, bấm `A` gửi lại với `"intent":"OPEN"` (UNLOCK phase `ACCESS`: nhả chốt, bấm D để khóa,
tự khóa như lần cất đồ), bấm `B` gửi lại với `"intent":"CHECKOUT"` (PICKUP). Lượt bị khóa quá hạn không hỏi, chỉ trả tủ
(ví âm thì từ chối `OVERDUE_UNPAID`). Máy chủ cũ bỏ qua `intent` và trả PICKUP như trước. Lệnh `UNLOCK` trong heartbeat có
thêm `phase` (in ra Serial); hộp mở như nhau cho mọi phase và vẫn theo cờ `physical`.

Khi mở: servo chốt nhả (và servo cửa mở, nếu `USE_DOOR_SERVO = true`). Người dùng bấm `D` để khóa lại; quên khóa thì
sau 30 giây (`DOOR_OPEN_MS`) hộp tự khóa. LCD hiện `Bam D de khoa / Tu khoa sau ..s`.
SRF05 chỉ dùng cho màn hình: có người trong 50 cm thì bật đèn LCD, không có ai và không bấm gì 1 phút (`SCREEN_OFF_MS`)
thì tắt. Hộp không còn LED xanh/đỏ. Câu trên LCD do máy chủ viết (không dấu), ví dụ `Sai ma / Con 3 lan`, `Tam khoa / Cho 120 giay`.

Hộp thật chỉ có **một cửa** nhưng CANT-A có các ngăn A01–A15: lượt đặt ở ngăn nào của CANT-A cũng mở cùng cửa này.
Khi demo nên đặt một ngăn (ví dụ A01) và nói rõ cửa đại diện cho ngăn đó.

## 4. Kịch bản demo

1. **PIN**: đăng nhập tài khoản sinh viên → bản đồ → khu CANT-A → đặt ngăn, chọn mở bằng PIN → nhập PIN ở hộp →
   cửa mở, LCD `Moi cat do / Ngan A01` (CHECK_IN). Nhập lại PIN → LCD `A: Mo tu / B: Tra tu`: bấm `A` → `Moi mo tu`
   (ACCESS, lượt vẫn chạy, "Tủ của tôi" tăng số lần mở; làm lại bao nhiêu lần cũng được); bấm `B` → `Moi lay do` (PICKUP),
   lượt kết thúc.
2. **Thẻ**: đặt với cách mở bằng thẻ → "Tủ của tôi" hiện mã đăng ký 6 số → ở hộp bấm `B`, nhập mã, `#`, quẹt thẻ →
   `Dang ky xong` → quẹt thẻ để mở.
3. **Vân tay**: tương tự với phím `C`.
4. **Điện thoại**: quét QR `/k/LOCKER-01`, nhập PIN trên điện thoại → hộp mở trong khoảng 3 giây, LCD `Mo tu (dien thoai)`.
   Lượt đang thuê: trang hiện hai nút "Mở tủ" / "Trả tủ".
5. **Nhân viên mở từ xa** (operator3 phụ trách CANT): trang quản lý thiết bị → mở từ xa có lý do → hộp mở `Mo tu (tu xa)`.
6. **Mất kết nối**: rút Wi-Fi/tắt hotspot → LCD `Mat Wi-Fi`; khoảng 90 giây sau web đánh dấu LOCKER-01 OFFLINE và không cho đặt ở CANT-A.
7. **Sai 5 lần**: nhập PIN sai 5 lần → `Tam khoa / Cho 120 giay` (bộ đếm nằm ở máy chủ).

## 5. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| LCD `Khong goi duoc may chu`, Serial `connection refused` / `read Timeout` | Sai IP trong `SERVER_BASE`, Tomcat chưa chạy, hoặc tường lửa chặn 8080 (bước 2.5). |
| LCD `Sai API key`, Serial `HTTP 401` | `DEVICE_API_KEY` không khớp `config/device-keys.local.properties` (key đổi sau khi chạy `set-device-key.ps1 -New` hoặc `03_v2_v3.sql`). |
| Không bắt được Wi-Fi | ESP32 chỉ chạy 2.4 GHz; đặt hotspot của laptop ở 2.4 GHz. |
| Biên dịch báo `ArduinoJson.h: No such file` dù đã cài | Thư mục sketchbook có dấu (`OneDrive\Tài liệu\Arduino`) làm trình biên dịch ESP32 không đọc được. File → Preferences → Sketchbook location đổi sang `C:\Arduino`, rồi cài lại các thư viện. |
| RC522 không đọc thẻ sau khi servo chạy | Sketch đã gọi `PCD_Init()` sau mỗi lần đóng; nên cấp nguồn servo riêng 5 V, chung GND với ESP32. |
| `Van tay chua dang ky` dù đã đăng ký trên web | Mẫu phải nằm trong AS608 của hộp này ở đúng số ô web lưu; đăng ký lại bằng phím `C`. |
