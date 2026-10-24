# Deploy Smart Locker miễn phí: Render + Azure SQL Database

Web chạy trên **Render** (gói Free, chạy bằng `Dockerfile` ở gốc repo). Cơ sở dữ liệu chạy trên **Azure SQL Database**, dùng ưu đãi miễn phí trọn đời của Azure. Sau khi cài xong, mỗi lần `git push` lên nhánh `main`, Render tự build lại và deploy.

| Thành phần | Dịch vụ | Giới hạn của gói miễn phí |
|---|---|---|
| Tomcat 9 + Java 8 | Render Web Service (Free) | RAM 512 MB. **Ngủ sau 15 phút không có request**, lần mở đầu tiên sau đó mất khoảng 1 phút |
| SQL Server | Azure SQL Database (free offer) | 100.000 vCore-giây và 32 GB mỗi tháng. Hết quota thì DB tạm dừng đến đầu tháng sau |

Cần chuẩn bị: tài khoản GitHub (repo đã push), tài khoản Render (đăng nhập bằng GitHub) và tài khoản Azure. Sinh viên nên dùng **Azure for Students** (đăng ký bằng email trường, không cần thẻ). Tài khoản Azure thường cần thẻ ngân hàng để xác minh, nhưng gói miễn phí không trừ tiền.

---

## Bước 1. Tạo Azure SQL Database miễn phí

1. Vào <https://portal.azure.com> → **Create a resource** → **SQL Database** → **Create**.
2. Đầu trang có khung **"Want to try Azure SQL Database for free?"**. Bấm **Apply offer**. Nếu không thấy khung này, subscription đã dùng hết lượt miễn phí (mỗi subscription được 10 DB).
3. Tab **Basics**:
   - **Resource group**: Create new, ví dụ `smartlocker-rg`.
   - **Database name**: `PRJ301_LOCKER`.
   - **Server**: Create new.
     - Server name: ví dụ `smartlocker-<tên-bạn>`, sẽ thành `smartlocker-<tên-bạn>.database.windows.net`.
     - Location: **(Asia Pacific) Southeast Asia**, gần Render Singapore.
     - Authentication method: **Use SQL authentication**. Đặt **Server admin login** (ví dụ `lockeradmin`) và một **mật khẩu mạnh**, rồi ghi lại cả hai.
   - **Behavior when free limit reached**: chọn **Auto-pause the database until next month**. Chọn như vậy thì không bao giờ bị tính tiền.
4. Tab **Networking**:
   - Connectivity method: **Public endpoint**.
   - **Add current client IP address**: **Yes**, để máy bạn nạp được dữ liệu ở Bước 2.
5. **Review + create** → **Create**, rồi chờ khoảng 3–5 phút.
6. Mở server vừa tạo → **Security → Networking** → **Firewall rules** → **+ Add a firewall rule** để Render vào được DB:
   - Cách an toàn hơn: trên Render, mở service (sau Bước 3) → **Connect** → tab **Outbound**, chép từng dải IP ra. Mỗi dải là một rule.
   - Cách nhanh: một rule `AllowAll` từ `0.0.0.0` đến `255.255.255.255`. Khi đó chỉ còn mật khẩu bảo vệ DB, nên mật khẩu phải thật mạnh.
   - Bấm **Save**.

## Bước 2. Nạp dữ liệu demo vào Azure

Azure SQL không cho dùng `USE` và `CREATE DATABASE`. Với cờ `-Azure`, `run_demo_db.ps1` bỏ những lệnh đó và chạy thẳng trong DB đã tạo. Mở PowerShell ở thư mục repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_demo_db.ps1 -Azure -Server smartlocker-<tên-bạn>.database.windows.net -User lockeradmin -Password "<mật khẩu>"
```

Script chạy lần lượt `01_schema.sql`, `02_data_v1.sql`, `03_v2_v3.sql`, rồi in số tài khoản theo từng vai trò (ADMIN, OPERATOR...). Chạy lại script bất cứ lúc nào để có dữ liệu sạch: script xóa mọi bảng cũ của DB đó trước khi tạo lại.

Nếu báo lỗi `Cannot open server ... Client with IP address ... is not allowed`: thêm IP đó vào Firewall rules (Bước 1, mục 6), chờ khoảng 1 phút rồi chạy lại.

## Bước 3. Tạo Web Service trên Render

1. Vào <https://dashboard.render.com> → **New** → **Web Service** → chọn repo `SmartLocker` (lần đầu cần cấp quyền cho Render đọc repo GitHub).
2. Điền:
   - **Name**: ví dụ `smartlocker`. Địa chỉ web sẽ là `https://smartlocker.onrender.com` (trùng tên thì Render thêm hậu tố).
   - **Language**: **Docker**. Render tự tìm `Dockerfile` ở gốc repo.
   - **Branch**: `main`.
   - **Region**: **Singapore**.
   - **Instance Type**: **Free**.
3. **Environment Variables**: thêm 3 biến dưới đây (`DbContext` đọc chúng; máy local không đặt biến nào nên vẫn dùng `localhost`):

   | Key | Value |
   |---|---|
   | `DB_URL` | `jdbc:sqlserver://smartlocker-<tên-bạn>.database.windows.net:1433;databaseName=PRJ301_LOCKER;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=60` |
   | `DB_USER` | `lockeradmin` |
   | `DB_PASSWORD` | mật khẩu ở Bước 1 |

   `loginTimeout=60` là bắt buộc. DB miễn phí tự tạm dừng khi không dùng, và lần kết nối đầu tiên cần khoảng 30–60 giây để DB thức dậy.
4. **Deploy Web Service**. Lần build đầu mất khoảng 5–10 phút. Theo dõi tab **Logs** đến khi thấy dòng `Server startup in [...] milliseconds`.
5. Mở `https://<tên-service>.onrender.com/`. Trang tự chuyển tới `/SmartLocker/`. Đăng nhập bằng một tài khoản demo (mật khẩu `123456`, xem README).

### Deploy lại từ terminal

Render tự build lại mỗi khi nhánh `main` có commit mới, nên deploy chỉ cần:

```bash
git push origin main
```

Muốn deploy lại mà không có commit mới: Render → service → **Settings** → **Deploy Hook**, chép URL đó ra (giữ bí mật, ai có URL cũng deploy được), rồi chạy:

```bash
curl -X POST "<Deploy Hook URL>"
```

## Bước 4 (tùy chọn). Gửi e-mail

Gửi mail đang tắt vì `config/mail.local.properties` không có trong repo. Muốn bật:

1. Render → service → **Environment** → **Secret Files** → **Add Secret File**:
   - Filename: `mail.local.properties`
   - Contents: nội dung file `config/mail.local.properties` trên máy, sửa dòng
     `app.base_url=https://<tên-service>.onrender.com/SmartLocker`
2. **Save Changes**. Render deploy lại. Container chép file đó vào chỗ có sẵn `mail-templates`, nên mẫu thư dùng như trên máy.

## Bước 5 (tùy chọn). Giữ web không ngủ

Render Free ngủ sau 15 phút không có request. Lúc ngủ, `LockerMonitor` cũng dừng, nên thiết bị không được theo dõi online/offline. Có thể giữ web thức bằng một dịch vụ ping miễn phí, ví dụ <https://uptimerobot.com>: tạo monitor **HTTP(s)** tới `https://<tên-service>.onrender.com/SmartLocker/`, chu kỳ 5–10 phút. 750 giờ miễn phí mỗi tháng của Render vừa đủ cho một service chạy suốt tháng.

Lưu ý: ping liên tục cũng làm DB Azure ít được nghỉ, nên tốn quota vCore-giây nhanh hơn. Xem mức đã dùng ở Azure Portal → database → **Overview** → **Free amount remaining**. Nếu quota sắp hết thì giảm chu kỳ ping hoặc tắt ping.

## Những điều cần biết

- **Session mất sau mỗi lần deploy** (container mới), nên phải đăng nhập lại. Render cũng không giữ file ghi xuống đĩa giữa các lần deploy.
- **ESP32 / mã QR**: địa chỉ `https://<tên-service>.onrender.com/SmartLocker` cố định, nên có thể đặt thẳng vào `base_url` thay cho tunnel trong [deploy.md](deploy.md). Chú ý: nếu web đang ngủ, request đầu tiên của hộp sẽ chờ khoảng 1 phút.
- **Lỗi thường gặp**:
  - Trang báo lỗi DB hoặc log có `Login failed` / `is not allowed to access the server`: kiểm tra `DB_USER`, `DB_PASSWORD` và Firewall rules của Azure.
  - Log có `The TCP/IP connection ... failed` ngay sau khi web thức dậy: DB đang thức. Tải lại trang sau khoảng 30 giây.
  - Log có `OutOfMemoryError`: gói Free chỉ có 512 MB RAM. Giảm `-Xmx` trong `Dockerfile` (đang là 320m) hoặc nâng gói.
- **Build image trên máy** (cần Docker Desktop đang chạy), để thử trước khi push:
  ```bash
  docker build -t smartlocker .
  ```
  ```bash
  docker run --rm -p 8080:8080 -e DB_URL="jdbc:sqlserver://host.docker.internal:1433;databaseName=PRJ301_LOCKER;encrypt=false" smartlocker
  ```
  Sau đó mở `http://localhost:8080/SmartLocker/`.
