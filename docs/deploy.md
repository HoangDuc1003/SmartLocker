# Deploy Smart Locker cho buổi demo (phương án A)

Laptop chạy Tomcat và SQL Server. Cloudflare quick tunnel đưa web ra Internet. Mỗi lần chạy, quick tunnel cấp một địa chỉ ngẫu nhiên mới, nên nhánh `gh-pages` của repo giữ một **link cố định** chuyển tiếp tới địa chỉ đó:

| Link cố định (GitHub Pages) | Chuyển tới |
|---|---|
| `https://hoangduc1003.github.io/SmartLocker/` | `<tunnel>/SmartLocker/` (dành cho giảng viên) |
| `https://hoangduc1003.github.io/SmartLocker/k/LOCKER-01/` | `<tunnel>/SmartLocker/k/LOCKER-01` (đích của QR dán trên hộp) |
| `https://hoangduc1003.github.io/SmartLocker/config.json` | `{"base_url":"<tunnel>/SmartLocker","updated_at":"..."}` (cho ESP32) |

Script `scripts/update-tunnel-link.ps1` tạo lại các file trên, commit **chỉ trên nhánh `gh-pages`** (qua một worktree tạm, không đụng tới nhánh `main` hay git config) rồi hỏi bạn trước khi `git push origin gh-pages`.

Trang chuyển tiếp là HTML tĩnh, không dùng CDN. Trang chuyển bằng JavaScript và `meta refresh`, có thêm liên kết bấm tay. JavaScript đọc `config.json` mới nhất (không qua cache) trước, nên trình duyệt còn giữ trang cũ vẫn tới đúng tunnel mới.

---

## 1. Cài đặt một lần

1. **Tạo nhánh `gh-pages` lần đầu**: chạy script như ở mục 2, bước 4. Nhánh chưa có thì script tự tạo nhánh orphan, chỉ chứa 4 file: `index.html`, `k/LOCKER-01/index.html`, `config.json`, `.nojekyll`.
2. **Bật GitHub Pages**: vào repo `HoangDuc1003/SmartLocker` → **Settings** → **Pages** → **Build and deployment**:
   - Source: **Deploy from a branch**
   - Branch: **`gh-pages`**, thư mục **`/ (root)`** → **Save**.

   Sau vài phút, trang Settings → Pages hiện dòng "Your site is live at `https://hoangduc1003.github.io/SmartLocker/`".
3. **In QR** cho `https://hoangduc1003.github.io/SmartLocker/k/LOCKER-01/` rồi dán lên hộp. Link này không đổi, nên **chỉ phải in một lần**. Cách tạo QR không cần gửi link cho dịch vụ lạ:
   - **Chrome hoặc Edge** (có sẵn, chạy trên máy): mở link trên → bấm biểu tượng chia sẻ ở thanh địa chỉ (hoặc chuột phải vào trang) → **Tạo mã QR cho trang này** / **Create QR code for this page** → **Tải xuống**.
   - **Python, chạy offline**: `pip install segno` (gói mã nguồn mở trên PyPI), rồi
     `python -c "import segno; segno.make('https://hoangduc1003.github.io/SmartLocker/k/LOCKER-01/', error='m').save('qr-locker-01.png', scale=12, border=4)"`.
   - In khổ tối thiểu khoảng 3 x 3 cm. Quét thử bằng camera điện thoại trước khi dán.
   - Không dùng trang tạo QR "rút gọn link" hoặc "QR động": những trang đó chèn link trung gian, có thể hết hạn.
4. **(Tùy chọn) Cho cloudflared ghi log ra file** để script tự đọc địa chỉ:
   `cloudflared tunnel --url http://localhost:8080 --logfile C:\temp\cloudflared.log`

---

## 2. Checklist ngày demo (bắt đầu **ít nhất 20 phút** trước giờ demo)

1. **SQL Server**: kiểm tra service `MSSQLSERVER` (hoặc instance bạn dùng) đang chạy, DB `PRJ301_LOCKER` mở được.
2. **Tomcat**: chạy `E:\apache-tomcat-9.0.113\bin\startup.bat`. Mở `http://localhost:8080/SmartLocker/` và đăng nhập thử một tài khoản demo.
3. **Tunnel**: mở một cửa sổ PowerShell riêng và **để nguyên cửa sổ đó** suốt buổi demo:
   `cloudflared tunnel --url http://localhost:8080 --logfile C:\temp\cloudflared.log`
   Chép địa chỉ `https://<tên-ngẫu-nhiên>.trycloudflare.com` trong khung thông báo. Mở `<địa chỉ>/SmartLocker/` để chắc tunnel chạy.
4. **Cập nhật link cố định**: mở PowerShell ở thư mục repo, chạy một trong hai lệnh:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\update-tunnel-link.ps1 -TunnelUrl https://<tên-ngẫu-nhiên>.trycloudflare.com
   powershell -ExecutionPolicy Bypass -File .\scripts\update-tunnel-link.ps1 -LogFile C:\temp\cloudflared.log
   ```
   Script thử gọi tunnel. Không gọi được thì chỉ cảnh báo, script vẫn chạy tiếp. Sau đó script commit trên `gh-pages` và hỏi
   `Đẩy nhánh gh-pages lên GitHub ...? Gõ 'co' để đồng ý`. Gõ `co` rồi Enter để push.
   - Muốn xem trước nội dung, không commit: thêm `-DryRun`.
   - Muốn commit nhưng chưa push: thêm `-NoPush`, lúc nào sẵn sàng thì chạy `git push origin gh-pages`.
5. **Chờ GitHub Pages cập nhật** (tới khoảng 10 phút). Xem tiến độ ở tab **Actions** của repo (workflow "pages build and deployment"). Mở `https://hoangduc1003.github.io/SmartLocker/config.json` và kiểm tra `base_url` là địa chỉ mới.
6. **Thử từ mạng khác**: trên điện thoại, **tắt Wi-Fi, dùng 4G**, mở bằng **tab ẩn danh**:
   - `https://hoangduc1003.github.io/SmartLocker/`: phải tới trang đăng nhập.
   - Quét QR trên hộp: phải tới trang nhập mật mã của `LOCKER-01`.
7. **ESP32**: khởi động lại hộp (hoặc chờ hộp tự đọc lại `config.json`). Trên web, thiết bị `LOCKER-01` phải hiện trực tuyến.
8. **Trong lúc demo**: không tắt cửa sổ cloudflared, không cho laptop ngủ (Settings → Power → Never sleep khi cắm sạc).

Chạy lại cloudflared thì tunnel ra địa chỉ mới, lúc đó **làm lại từ bước 3**.

---

## 3. Ghi chú cho ESP32

- **Lúc khởi động**: đọc `https://hoangduc1003.github.io/SmartLocker/config.json`, lấy `base_url` (ví dụ `https://abc-def.trycloudflare.com/SmartLocker`). Mọi API thiết bị ghép vào sau `base_url`.
- **HTTPS**: dùng `WiFiClientSecure` với `setInsecure()`, nghĩa là không kiểm tra chứng chỉ. Cách này chấp nhận được với đồ án, áp dụng cho cả GitHub Pages và tunnel.
- **Thử lại**: đọc `config.json` lỗi thì chờ 2, 4, 8 giây rồi thử lại, tối đa khoảng 30 giây. Màn OLED hiện `Dang ket noi...` trong lúc chờ. Nếu đã có `base_url` cũ (lưu trong `Preferences`/NVS) thì vẫn dùng tạm bản cũ.
- **Tunnel đổi địa chỉ khi hộp đang chạy**: nếu heartbeat lỗi kết nối (tên miền tunnel cũ có thể không còn phân giải được) hoặc nhận mã HTTP 5xx **3 lần liên tiếp** thì đọc lại `config.json`. ESP32 không có cache trình duyệt, nên chỉ phải chờ GitHub Pages build xong.
- **API thiết bị** (chi tiết ở `docs/spec/smart-locker-v2.md` §4): header `X-API-Key: <key của hộp>`, JSON UTF-8, thời gian theo UTC.
  - `POST {base_url}/api/health`: heartbeat 3 giây một lần, nhận lệnh `UNLOCK` / `DELETE_FP` / `CANCEL_ENROLL`.
  - `POST {base_url}/api/device/auth`: xác thực bằng `PIN`, `CARD` hoặc `FINGERPRINT`.
  - `POST {base_url}/api/device/enroll/start` và `/api/device/enroll/finish`: đăng ký thẻ hoặc vân tay.
  - `POST {base_url}/api/locker/batch`: báo sự kiện sau mỗi lần chốt đóng.

Ví dụ đọc `config.json` (Arduino core ESP32, thư viện ArduinoJson 6 hoặc 7):

```cpp
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* CONFIG_URL = "https://hoangduc1003.github.io/SmartLocker/config.json";
String baseUrl;

bool loadBaseUrl() {
  for (int i = 0, wait = 2000; i < 4; i++, wait *= 2) {
    WiFiClientSecure client;
    client.setInsecure();                 // đồ án: bỏ kiểm tra chứng chỉ
    HTTPClient http;
    http.setTimeout(8000);
    if (http.begin(client, CONFIG_URL)) {
      int code = http.GET();
      if (code == 200) {
        JsonDocument doc;                 // ArduinoJson 7; bản 6 dùng StaticJsonDocument<256>
        if (!deserializeJson(doc, http.getString())) {
          const char* u = doc["base_url"];
          if (u && strncmp(u, "https://", 8) == 0) { baseUrl = u; http.end(); return true; }
        }
      }
      http.end();
    }
    delay(wait);
  }
  return false;                           // giữ baseUrl cũ (nếu có), báo "Loi mang" trên OLED
}
```

---

## 4. Xử lý sự cố

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Trình duyệt hoặc ESP32 nhận **HTTP 429** | Quick tunnel chỉ cho tối đa 200 request đang xử lý cùng lúc, vượt thì trả 429 | Giảm số tab đang mở trang tự làm mới. Kiểm tra không có vòng lặp gọi API liên tục. Chờ vài giây rồi thử lại. Một hộp gửi heartbeat 3 giây một lần cộng vài người xem web thì còn dư nhiều. |
| Link GitHub Pages vẫn chuyển tới **tunnel cũ** | Pages chưa build xong (tới khoảng 10 phút), hoặc trình duyệt còn giữ bản cũ | Xem tab Actions. Mở `config.json` kèm `?t=123` để xem bản mới nhất. Thử bằng tab ẩn danh. Trang chuyển tiếp tự đọc `config.json` mới, nên thường chỉ phải chờ phần build. |
| Đã chạy lại cloudflared, link cũ **không vào được** | Quick tunnel đổi địa chỉ mỗi lần chạy | Chạy lại script với địa chỉ mới (mục 2, bước 4), rồi chờ Pages cập nhật. |
| Script báo `Địa chỉ không hợp lệ` | Dán nhầm địa chỉ, hoặc không phải `https://...trycloudflare.com` | Chép lại địa chỉ trong khung thông báo của cloudflared. Dán cả `/SmartLocker/` phía sau cũng được, script tự bỏ phần đường dẫn. |
| Script báo không tìm thấy địa chỉ trong log | cloudflared chưa tạo xong tunnel, hoặc sai file log | Chờ tới khi cửa sổ cloudflared hiện khung có địa chỉ, rồi chạy lại. Hoặc dùng `-TunnelUrl`. |
| `git push` bị từ chối (non-fast-forward) | Nhánh `gh-pages` trên GitHub đã bị sửa ở nơi khác | Script tự tua nhánh cục bộ tới bản trên GitHub nếu được. Nếu vẫn lỗi: `git branch -D gh-pages` rồi chạy lại script, script sẽ dựng lại nhánh từ bản trên GitHub. |
| `git push` hỏi đăng nhập hoặc báo 403 | Git chưa đăng nhập GitHub trên máy này | Đăng nhập qua Git Credential Manager (cửa sổ hiện ra khi push), rồi gõ lại `git push origin gh-pages`. |
| PowerShell báo "running scripts is disabled" | Execution policy chặn script | Chạy qua `powershell -ExecutionPolicy Bypass -File ...` như ở trên. Cách này chỉ áp dụng cho lần chạy đó, không sửa cấu hình máy. |
| Pages trả **404** | Pages chưa bật, hoặc chọn sai nhánh hoặc thư mục | Settings → Pages: Branch `gh-pages`, `/ (root)`. |
| Tới tunnel nhưng `/SmartLocker/k/LOCKER-01` báo 404 | Bản build trên Tomcat chưa có trang điện thoại | Build lại và deploy `build/web` (`sh scripts/build-dev.sh`, xem README). |
| Tunnel trả **502** | Tomcat tắt, hoặc cloudflared mất kết nối | Kiểm tra `http://localhost:8080/SmartLocker/` trên laptop. Xem cửa sổ cloudflared. Nếu phải chạy lại tunnel thì làm lại từ mục 2, bước 3. |

---

## 5. Thông tin đã tra (17/10/2026)

- **Cloudflare quick tunnel** ([Cloudflare docs: Quick Tunnels](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)):
  - tối đa **200 request đang xử lý cùng lúc** (in-flight), vượt thì trả `429`;
  - **không hỗ trợ Server-Sent Events (SSE)**. App không dùng SSE: dashboard tự gọi lại API theo chu kỳ;
  - **không cam kết uptime** (không có SLA), chỉ dành cho thử nghiệm và demo;
  - **địa chỉ đổi mỗi lần** tạo quick tunnel mới.
- **GitHub Pages**: sau khi push, trang có thể mất **tới khoảng 10 phút** mới cập nhật, và trình duyệt có thể giữ bản cũ thêm một lúc (Pages trả header `Cache-Control: max-age=600`, đã kiểm tra bằng `curl -I`). Nguồn là trang trợ giúp cũ của GitHub và diễn đàn cộng đồng; chưa thấy tài liệu chính thức mới nêu con số này. Vì vậy cần chạy script **ít nhất 20 phút trước buổi demo** và thử bằng tab ẩn danh.

---

## 6. Tham số của script

| Tham số | Ý nghĩa |
|---|---|
| `-TunnelUrl <url>` | Địa chỉ tunnel (`https://<tên>.trycloudflare.com`) |
| `-LogFile <file>` | Đọc địa chỉ `*.trycloudflare.com` xuất hiện cuối cùng trong log cloudflared |
| `-DryRun` | Chỉ in nội dung file, không đụng git |
| `-NoPush` | Commit trên `gh-pages` nhưng không push |
| `-SkipCheck` | Bỏ bước thử gọi tunnel |
| `-DeviceCode LOCKER-01,LOCKER-02` | Tạo thêm trang `k/<mã>/` cho hộp khác (mặc định chỉ `LOCKER-01`) |

Không truyền `-TunnelUrl` hay `-LogFile` thì script hỏi địa chỉ.

---

## v3: database, định vị và email

Phương án deploy không đổi. Chỉ thêm ba điểm:

- **Database**: `run_demo_db.ps1` (qua `run_demo_db.bat`) chạy `01_schema.sql`, `02_data_v1.sql` rồi `03_v2_v3.sql`. Đã có
  database thì chỉ cần chạy lại `sqlcmd -S localhost -U sa -P 12345 -I -b -f 65001 -i sql\03_v2_v3.sql` (chạy lại được; luôn có `-I`).
- **Định vị "Tìm tủ gần tôi" cần HTTPS**: trình duyệt chỉ cho `navigator.geolocation` trên trang HTTPS (hoặc `localhost`).
  Khi demo trên điện thoại, mở **link tunnel** (`https://hoangduc1003.github.io/SmartLocker/` chuyển tới
  `https://<tên>.trycloudflare.com/SmartLocker/`), không mở `http://<IP laptop>:8080`, nếu không trang chỉ báo "cần HTTPS" và
  giữ danh sách khu như cũ. Toạ độ các khu trong `03_v2_v3.sql` là **gần đúng** (ĐHQG-HCM, FPTU HCM), sửa cột `LockerArea.latitude/longitude`
  nếu cần khoảng cách thật. Vị trí không được gửi lên máy chủ.
- **Email nhắc hạn**: chép `config/mail.local.properties.example` thành `config/mail.local.properties` trên laptop chạy Tomcat
  (không commit), điền tài khoản Gmail và **mật khẩu ứng dụng** (bật xác minh 2 bước rồi tạo ở
  `https://myaccount.google.com/apppasswords`), `mail.port` 465 (SSL) hoặc 587 (STARTTLS). Thư ghép link
  `app.base_url + "/MyLockerController"`, nên `app.base_url` phải là địa chỉ tunnel hiện tại kèm `/SmartLocker`
  (`https://<tên>.trycloudflare.com/SmartLocker`), **không** phải link GitHub Pages (Pages không có trang `MyLockerController`,
  link sẽ báo 404). Tunnel đổi địa chỉ thì sửa lại dòng này; để trống thì thư không có link. Sửa file thì build lại hoặc tải
  lại context Tomcat. Không có file thì việc gửi email tắt, mọi trang khác vẫn chạy. Mạng chặn cổng 465/587 thì thư không đi; thử lại
  bằng 4G hoặc đổi cổng.

---

## Khóa API của LOCKER-01

Hộp thật mở ra Internet qua tunnel, nên không dùng khóa công khai `device-1-api-key`.
- Chạy `powershell -ExecutionPolicy Bypass -File scripts/set-device-key.ps1` (thêm `-New` để đổi khóa). Script tạo khóa ngẫu nhiên trong `config/device-keys.local.properties` (git bỏ qua file này) và chỉ lưu SHA-256 vào `Device.api_key_hash`.
- Nạp khóa đó vào firmware ESP32, vào biến `api_key` của environment Postman, và cho `ScenarioSender` (tự đọc file trên hoặc `-Dsmartlocker.apiKey=...`).
- 7 hộp demo vẫn dùng `device-N-api-key`.
