# Hộp LOCKER-01 nối web (ESP32)

Sketch `SmartLocker_Online.ino` biến hộp thật thành thiết bị `LOCKER-01` (khu CANT-A) của web.
Hộp không tự quyết định mở: mọi PIN, thẻ, vân tay đều gửi lên máy chủ, máy chủ trả `UNLOCK` thì hộp mới mở chốt.
Từ firmware 4.1 (v7) một đầu **PN532** làm cả hai việc, luân phiên trong mỗi vòng lặp: **đọc thẻ từ**, và **giả làm một thẻ
NFC** chứa liên kết của hộp để điện thoại chạm vào là mở trang của hộp và bấm "Mở tủ của tôi".

```
ESP32 ──Wi-Fi──► Tomcat /SmartLocker/api   (header X-API-Key = khóa của LOCKER-01)
  POST /api/health              3 giây/lần: giữ LOCKER-01 trực tuyến, nhận lệnh UNLOCK / DELETE_FP,
                                gửi "nfc":true và nhận "tap_path" để ghi vào thẻ NFC giả lập
  POST /api/device/auth         PIN 6 số, UID thẻ, số ô vân tay (+ intent) -> UNLOCK, CHOOSE, CONFIRM_EMAIL hoặc DENY + câu cho màn LCD
  POST /api/device/enroll/...   đăng ký thẻ (phím B) / vân tay (phím C) bằng mã 6 số ở "Tủ của tôi"
```

Máy chủ không bao giờ gọi vào hộp, nên không cần biết IP của ESP32. Lệnh mở từ điện thoại (chạm NFC, hoặc QR
`/k/LOCKER-01` rồi nhập PIN) hoặc từ nhân viên nằm chờ và hộp nhận ở heartbeat kế tiếp (chậm nhất khoảng 3 giây).

**Chạm NFC.** Liên kết trong thẻ có dạng `<SERVER_BASE>/k/LOCKER-01?n=<mã 12 ký tự>`. Mã do máy chủ cấp
(`Device_TapIssue`), đổi mỗi phút và sau mỗi lần mở, chỉ dùng được trong 5 phút, nên ai chép liên kết mang đi chỗ khác
cũng không mở được. Hộp không đọc gì từ điện thoại: máy chủ kiểm tra người đăng nhập và mã chạm. Android mở liên kết
ngay khi chạm; iPhone (XS trở lên) đọc thẻ NFC nền nhưng với thẻ giả lập bằng PN532 có máy không nhận, khi đó dùng QR.

**Thẻ và điện thoại luân phiên.** Mỗi vòng lặp PN532 làm một việc: đọc thẻ khoảng 30 ms hoặc giả lập thẻ NFC khoảng 40 ms, đổi vai
bằng `SAMConfig`. Đang gõ PIN hoặc đang đăng ký thẻ thì không giả lập. Điện thoại có ví HCE trả lời lệnh đọc thẻ bằng UID ngẫu
nhiên 4 byte bắt đầu bằng `08`: firmware bỏ qua, không gửi lên máy chủ, nên lần chạm không bị tính là thẻ lạ.

## 1. Chọn cách nối mạng

| Cách | Khi nào dùng | `secrets.h` |
|---|---|---|
| **LAN** (khuyên dùng khi demo) | ESP32 và laptop chạy Tomcat chung một Wi-Fi. Nên bật **Mobile hotspot** của laptop (băng tần 2.4 GHz) rồi cho ESP32 bắt vào: không phụ thuộc Wi-Fi phòng học, IP ổn định. | `SERVER_BASE "http://<IP laptop>:8080/SmartLocker"`, `CONFIG_URL ""` |
| **Internet** (Cloudflare tunnel) | Hộp ở mạng khác laptop, hoặc muốn giống triển khai thật. Chậm hơn (HTTPS qua tunnel). | `CONFIG_URL "https://hoangduc1003.github.io/SmartLocker/config.json"` (xem `docs/deploy.md`) |

IP laptop: `ipconfig` → mục đang dùng (Wi-Fi, hoặc "Local Area Connection*" khi bật hotspot, thường là `192.168.137.1`) → `IPv4 Address`.

## 2. Cài đặt

1. **Arduino IDE** → Boards Manager: `esp32` by Espressif (đã thử với 3.3.x). Board: **ESP32 Dev Module**.
2. **Library Manager**: `Keypad`, `Adafruit Fingerprint Sensor Library`, `ArduinoJson` (7.x),
   `LiquidCrystal I2C` (của Frank de Brabander). Servo chạy bằng LEDC của ESP32, không cần thư viện ESP32Servo.
   **PN532**: tải <https://github.com/Seeed-Studio/PN532> (Code → Download ZIP, đã thử bản 1.1.0), giải nén vào
   `Arduino/libraries` và đổi tên thư mục thành `PN532-Arduino` (một thư mục duy nhất, mọi file nằm trong `src/`). Không cần
   thư viện NDEF: sketch tự đóng gói bản ghi URL. Thư viện `Adafruit PN532` không giả lập thẻ được, đừng dùng thay.
3. Chép `secrets.example.h` thành `secrets.h` (cùng thư mục), điền Wi-Fi, `SERVER_BASE`, và `DEVICE_API_KEY` =
   phần sau `LOCKER-01=` trong `config/device-keys.local.properties` (chưa có thì chạy `scripts/set-device-key.ps1`).
   `secrets.h` đã nằm trong `.gitignore`, không commit.
4. **Sơ đồ chân** (giống bản `smart_locker_v4`, trừ đầu NFC):

   | Thiết bị | Chân ESP32 |
   |---|---|
   | PN532 | chế độ I2C (gạt công tắc I0 = 1, I1 = 0), SDA 21, SCL 22 chung với LCD, VCC 3V3 hoặc 5V theo module; địa chỉ 0x24. Các chân 4, 16, 17, 34 của RC522 cũ để trống |
   | AS608 | TX → 35, RX → 15 (tắt bằng `USE_FINGERPRINT = false` nếu cảm biến lỗi) |
   | LCD 1602 I2C | SDA 21, SCL 22, địa chỉ 0x27 (một số module là 0x3F) |
   | Servo chốt | 32 (khóa 0°, mở 85°) |
   | Servo cửa | 2 (đóng 0°, mở 180°) |
   | SRF05 | TRIG 5, ECHO 18 qua mạch chia áp |
   | Keypad | R1–R4: 13, 14, 25, 26; C1–C4: 33, 19, 23, 27 |

   Khác sketch Blynk: bản này không phát Wi-Fi `SmartDoorLock` và không dùng Blynk, mà bắt Wi-Fi/hotspot của laptop
   và hỏi web. Phím `B` là đăng ký **thẻ**, `C` là đăng ký **vân tay** (mã 6 số từ web), PIN do web cấp (không còn PIN chủ
   `1234`). Thẻ không lưu trong hộp mà trên web; mẫu vân tay nằm trong AS608 của hộp, web chỉ lưu số ô của nó.
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
| Chạm điện thoại vào đầu NFC | Điện thoại mở trang của hộp; đã đăng nhập thì bấm "Mở tủ của tôi". LCD hiện `Da gui lien ket` |
| Đặt ngón tay | Mở bằng vân tay (AS608 tìm số ô, gửi số ô lên web) |
| `B` + mã đăng ký + `#`, rồi quẹt thẻ | Đăng ký thẻ cho lượt đặt (miễn phí) |
| `C` + mã đăng ký + `#`, rồi đặt ngón tay 2 lần | Đăng ký vân tay (web chọn số ô, hộp lưu mẫu vào ô đó) |
| `D` | Cửa đang đóng: xem IP của hộp và tình trạng máy chủ. Cửa đang mở: khóa ngay |
| `A` / `B` sau `A: Mo tu` / `B: Tra tu` | Lượt đang thuê: `A` mở tủ (lượt vẫn chạy), `B` trả tủ (kết thúc lượt); `*` hoặc 15 giây không bấm thì hủy |

**Mở nhiều lần (từ firmware 3.3).** Mọi lần gửi PIN / thẻ / vân tay đều kèm `"intent":"ASK"`. Lượt `RESERVED` vẫn mở ngay
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
2. **Chạm điện thoại**: đặt với cách mở "Điện thoại" → đăng nhập web trên điện thoại → chạm điện thoại vào đầu PN532 →
   trang `/k/LOCKER-01?n=...` mở ra → bấm "Mở tủ của tôi" → hộp mở trong khoảng 3 giây, LCD `Mo tu (dien thoai)`.
   Lượt đang thuê: trang hiện hai nút "Mở tủ" / "Trả tủ". Bấm lại bằng liên kết cũ thì trang báo mã đã dùng, chạm lại.
3. **Thẻ**: đặt với cách mở bằng thẻ → "Tủ của tôi" hiện mã đăng ký 6 số → ở hộp bấm `B`, nhập mã, `#`, quẹt thẻ →
   `Dang ky xong` → quẹt thẻ để mở. Đăng ký không mất tiền.
3b. **Vân tay**: đặt với cách mở bằng vân tay → "Tủ của tôi" hiện mã đăng ký 6 số → ở hộp bấm `C`, nhập mã, `#`, đặt
   ngón tay 2 lần → `Dang ky xong` → đặt ngón tay để mở.
4. **Trang của hộp không cần NFC**: quét QR `/k/LOCKER-01`, nhập PIN trên điện thoại → hộp mở như trên.
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
| Serial `PN532 not found` | Công tắc chưa ở chế độ I2C, hoặc dây SDA/SCL lỏng. Hộp vẫn chạy PIN và vân tay (không đọc được thẻ, không có chạm NFC); `USE_NFC = false` để tắt hẳn. |
| Chạm điện thoại mà không mở gì | Bật NFC trên điện thoại; Serial phải có dòng `NFC tag: http...` (hộp đã nhận `tap_path`). Liên kết quá 126 byte thì hộp không ghi được: rút ngắn `SERVER_BASE`. |
| PN532 ngừng trả lời sau khi servo chạy | Sketch khởi động lại PN532 sau mỗi lần khóa; nên cấp nguồn servo riêng 5 V, chung GND với ESP32. |
| `Van tay chua dang ky` dù đã đăng ký trên web | Mẫu phải nằm trong AS608 của hộp này ở đúng số ô web lưu; đăng ký lại bằng phím `C`. |
