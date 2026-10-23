# SmartLocker: hệ thống tủ gửi đồ thông minh

Đồ án môn PRJ301 (FALL2026). Ứng dụng web Java Servlet/JSP theo mô hình MVC2, chạy trên Tomcat 9 với SQL Server,
điều khiển các hộp tủ ESP32 qua API thiết bị có khóa riêng cho từng hộp.

Tài liệu liên quan:
- [docs/spec/smart-locker-v2.md](docs/spec/smart-locker-v2.md): đặc tả v2 và hợp đồng API thiết bị (mục 4).
- [docs/spec/smart-locker-v3.md](docs/spec/smart-locker-v3.md): v3, chỉ phần thay đổi (cỡ ngăn, giá theo cỡ, hủy 5 phút, quá hạn và nợ, email nhắc hạn).
- [docs/SYSTEM_FLOWS.md](docs/SYSTEM_FLOWS.md): luồng nghiệp vụ, sơ đồ trạng thái, đường đi của dữ liệu dashboard.
- [docs/deploy.md](docs/deploy.md): chạy demo qua tunnel, trang điện thoại `/k/LOCKER-01`, khóa API của hộp thật.
- [docs/postman/](docs/postman/README.md): Postman collection (kịch bản v2 1–10 và thư mục v3 11–17), cách chạy bằng newman.

---

## Chức năng

**Người dùng (END_USER)**
- Đăng ký, đăng nhập (mật khẩu băm BCrypt có salt).
- Sơ đồ tủ theo khu (Thư viện, Ký túc xá A, Căng tin, Nhà thi đấu), làm mới 10 giây một lần. Mỗi dãy vẽ thành một khối tủ,
  cửa cao theo cỡ ngăn. Nút "Tìm tủ gần tôi" sắp các khu theo khoảng cách (định vị trên trình duyệt, không gửi vị trí lên
  máy chủ) và mở chỉ đường đi bộ trên Google Maps.
- Ba cỡ ngăn: S 20x20x20, M 40x40x40, L 60x60x60 cm, kèm gợi ý vật dụng vừa ngăn. Giá theo cỡ: giá gói × 1,00 / 1,30 / 1,69
  (tròn lên 100 đ), thẻ từ giảm thêm 5%. Ví dụ gói 2 giờ: S 5.000 đ, M 6.500 đ, L 8.500 đ.
- Đặt ngăn: chọn gói và cách mở (mật mã, thẻ từ, vân tay), popup xác nhận số tiền trừ ngay; giữ chỗ 15 phút.
  Sau khi đặt, ví phải còn ít nhất 10.000 đ để dự phòng phụ phí.
  - Hủy chỉ trong **5 phút đầu** kể từ lúc đặt, hoàn đủ; sau 5 phút không hủy được nữa.
  - Không đến trong 15 phút: lượt chuyển `NO_SHOW`, **không hoàn tiền (0%)**. 3 lần không đến trong 7 ngày thì tạm cấm đặt.
  - Gia hạn tối đa 3 lần, mỗi lần trả giá một giờ của cỡ cho mỗi giờ bắt đầu (S 2.500 đ, M 3.300 đ, L 4.300 đ).
- Quá hạn: ngăn không tự giải phóng. Qua `due_at` cộng thời gian ân hạn thì tủ bị khóa, mỗi giờ trễ (tính từ `due_at`, tròn
  lên) bị trừ phụ phí bằng 1,5 lần giá một giờ của cỡ (S 3.800 đ, M 4.900 đ, L 6.400 đ); ví có thể âm (nợ). Hộp và trang
  điện thoại từ chối mở (`OVERDUE_UNPAID`, kèm số nợ) tới khi nạp đủ tiền; lượt bị khóa không gia hạn được. Quá 48 giờ thì
  lượt được chuyển cho nhân viên xử lý (cảnh báo `OVERDUE_ESCALATED`).
- Email nhắc hạn 15 phút trước `due_at`, nếu người dùng đã xác nhận email bằng mã 6 số ở "Tủ của tôi".
- Ví: nạp tiền bằng mã VietQR, nhân viên duyệt rồi mới cộng tiền.
- "Tủ của tôi": mật mã (ẩn/hiện), mã đăng ký thẻ hoặc vân tay, đếm ngược thời gian còn hủy được và giữ chỗ,
  khung quá hạn (giờ trễ, phụ phí, số nợ, nút nạp tiền), email nhắc hạn, thẻ đã đăng ký (báo mất thẻ), vân tay, lịch sử.
- Trang điện thoại công khai `/k/{device_code}`: nhập mật mã để mở tủ; sai 5 lần thì trang tạm khóa 2 phút.

**Nhân viên**
- OPERATOR: sơ đồ tủ, lệnh mở từ xa, duyệt nạp tiền, quản lý khu, dãy, ngăn, gói gửi, thẻ, người dùng.
- TECHNICIAN: cảnh báo, phiếu bảo trì, hiệu chuẩn cảm biến, trạng thái ngăn.
- AUDITOR: chỉ đọc; xem và kiểm tra chuỗi băm của nhật ký audit.
- ADMIN: toàn quyền, gồm vai trò và phân quyền.

**Phía thiết bị và máy chủ**
- API thiết bị v2: heartbeat `/api/health`, xác thực tại hộp `/api/device/auth`, đăng ký thẻ/vân tay
  `/api/device/enroll/start|finish`, lịch sử mở/đóng `/api/locker/batch`. Header `X-API-Key`; máy chủ chỉ lưu SHA-256 của khóa.
- Khóa nhập sai: 5 lần sai trên hộp thì hộp tạm khóa 2 phút (bộ đếm của điện thoại tách riêng).
- Cảnh báo: luật cố định (`RuleEngine`) quyết định; mô hình Weka (`RiskScorer`) chỉ cho thêm điểm rủi ro.
- Nhật ký audit chuỗi băm SHA-256 do procedure `Audit_Append` ghi; `AuditVerifier` tính lại để kiểm tra.
- `LockerMonitor`: mỗi 2 giây dựng ảnh chụp số liệu cho dashboard (`/api/dashboard` đọc từ ảnh chụp, không truy vấn DB);
  mỗi 15 giây chạy các procedure hết hạn giữ chỗ, khóa và tính phụ phí lượt quá hạn (`Deposit_ExpireOverdue`), chuyển xử lý
  lượt quá 48 giờ (`Deposit_Escalate`), hết hạn lệnh và đánh dấu hộp mất kết nối (im lặng quá 90 giây).
- `DueReminder` (luồng riêng trong `LockerMonitor`) gửi email nhắc hạn qua `MailService` (SMTP viết bằng Java thuần).

Ghi chú khi demo: chỉ `LOCKER-01` (dãy CANT-A) là hộp thật. 7 hộp còn lại là hộp minh họa, có `"demo":true` trong
`OperatingProfile`, và `LockerMonitor` giả heartbeat cho riêng các hộp này. Hộp thật không gửi heartbeat sẽ chuyển OFFLINE.

---

## Kiến trúc

```mermaid
flowchart TD
    ESP["Hộp ESP32"] -->|X-API-Key| API["api/* (HealthApi, DeviceAuthApi, DeviceEnrollApi, LockerSessionApi)"]
    Phone["Điện thoại /k/LOCKER-01"] --> Kiosk["api/KioskApi"]
    Browser["Trình duyệt"] --> Filter["filter/SecurityFilter (RBAC theo bảng Permissions)"]
    Filter --> Ctrl["controller/* (MVC2)"]
    Ctrl --> Views["WEB-INF/views/*.jsp"]
    API --> DAO["dao/* (JDBC, DbContext)"]
    Kiosk --> DAO
    Ctrl --> DAO
    API --> Svc["service/AlertService, RuleEngine, RiskScorer"]
    Monitor["service/LockerMonitor"] -->|ảnh chụp 2 giây| DashApi["api/DashboardApi"]
    DAO --> DB[(SQL Server PRJ301_LOCKER)]
```

- `DbContext` mở một kết nối JDBC cho mỗi lần gọi DAO và đóng ngay bằng try-with-resources (không có connection pool).
- Mọi view nằm trong `WEB-INF/views`, chỉ vào được qua controller. Dữ liệu người dùng in bằng `<c:out>`; JavaScript dựng HTML qua `esc()` của `js/app.js`.
- Một stylesheet chung `web/css/app.css` (sáng/tối), `js/theme.js` đặt theme trước khi vẽ trang; không dùng CDN.

---

## Cài đặt

Yêu cầu: JDK 8, Apache Tomcat 9, SQL Server 2019/2022 (có `sqlcmd`), NetBeans (dự án web Ant).

### 1. Cơ sở dữ liệu

Chạy các script theo **đúng thứ tự 01 → 07, rồi 09** (file `01` xóa và tạo lại database; `08_accounts_v2.sql` không nằm
trong lượt chạy này):

| File | Nội dung |
|---|---|
| `sql/01_schema.sql` | Database, bảng, view, trigger, `Audit_Append`, quyền cơ bản |
| `sql/02_sample_data.sql` | Dữ liệu mẫu: tài khoản, khu, dãy, ngăn, lịch sử |
| `sql/03_scenarios.sql` | Procedure của các tình huống (hộp mất kết nối, mở từ xa, mất thẻ, đặt tủ...) |
| `sql/04_wallet_booking.sql` | Ví, nạp tiền, quyền TOPUP và SLOTSTATUS |
| `sql/05_fix_reviewer_feedback.sql` | Sửa quyền TECHNICIAN, tự giải phóng lượt quá hạn |
| `sql/06_demo_v2.sql` | v2: cách mở, mật mã, vân tay, khóa nhập sai, procedure `Device_Authorize`, `Enroll_*` |
| `sql/07_vietnamese_data.sql` | Đổi tên gói, khu, dãy, vị trí hộp trong dữ liệu mẫu sang tiếng Việt |
| `sql/09_v3.sql` | v3: bảng `AppConfig` (mọi con số), `SlotSize` (cỡ S/M/L, hệ số giá), cột quá hạn của `Deposit`, toạ độ khu (giả), IP hộp (giả), procedure giá theo cỡ, hủy 5 phút, quá hạn, chuyển xử lý, email nhắc hạn. Chạy lại được |
| `sql/10_campus_vnu.sql` | v4: các khu nằm trong khuôn viên ĐHQG-HCM và quanh FPTU HCM (toạ độ **gần đúng**, sửa trong trang Khu vực), thêm khu `DOMB` (KTX khu B), IP giả cho hộp ở thư viện |

Cách nhanh: `run_demo_db.bat` (gọi `run_demo_db.ps1`, chạy 01 → 07, 09 rồi 10). Hoặc từng file (luôn có `-I`):

```powershell
sqlcmd -S localhost -U sa -P 12345 -I -b -f 65001 -i sql\01_schema.sql
```

Sau `06_demo_v2.sql` (chạy lại 06 cũng vậy), khóa của `LOCKER-01` trở về khóa mẫu công khai. Chạy tiếp:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\set-device-key.ps1
```

Script tạo (hoặc dùng lại) khóa bí mật trong `config/device-keys.local.properties` (không commit) và ghi SHA-256 của nó vào DB.
Chạy lại `03` hoặc `05` sẽ đưa các procedure đặt tủ về bản v1, nên khi đó phải chạy lại `06`, `07` và `09`.
Chạy lại `06` thì cũng phải chạy lại `09` (06 ghi đè `Deposit_Reserve`, `Device_Authorize`... bằng bản v2).

### 2. Kết nối database

Sửa `URL`, `USER`, `PASSWORD` trong `src/java/dao/DbContext.java` (mặc định `localhost:1433`, `sa` / `12345`).

### 3. Build và chạy

- NetBeans: Clean and Build, rồi Run (Tomcat 9).
- Không có NetBeans: biên dịch `src/java` bằng `javac -encoding UTF-8 -source 8 -target 8`, classpath gồm
  `servlet-api.jar`, `jsp-api.jar`, `el-api.jar` của Tomcat và `lib/*.jar`; chép class vào `build/web/WEB-INF/classes`,
  chép `web/` vào `build/web/`, rồi trỏ context `SmartLocker` của Tomcat vào `build/web`.
- Git Bash: `sh scripts/build-dev.sh` làm đúng các bước trên (kể cả chép các jar cần khi chạy vào `WEB-INF/lib`) rồi báo
  Tomcat tải lại context (chờ khoảng 15 giây trước khi thử). Thêm `--no-reload` nếu chỉ muốn build.

Mở `http://localhost:8080/SmartLocker/`.

### 3b. Email nhắc hạn (không bắt buộc)

Chép `config/mail.local.properties.example` thành `config/mail.local.properties` (git bỏ qua `*.local.properties`) rồi điền
`mail.host`, `mail.port` (465 SSL hoặc 587 STARTTLS), `mail.user`, `mail.password` (mật khẩu ứng dụng Gmail 16 chữ, cần bật
xác minh 2 bước), `mail.from`, `mail.from_name`, `app.base_url` (link "Tủ của tôi" trong thư). Không có file thì việc gửi
email tắt, web vẫn chạy bình thường. Người dùng bật nhắc hạn ở "Tủ của tôi": nhập email, nhận mã 6 số, nhập mã để xác nhận.

Nội dung các email nằm ở `config/mail-templates/*.txt` (sắp đến hạn, quá hạn, chuyển nhân viên, đặt ngăn, hết giữ chỗ,
mã xác nhận, chào mừng, nạp tiền được duyệt/bị từ chối). Sửa chữ trực tiếp, `{{name}}` và các biến khác được thay lúc gửi;
xem danh sách biến trong `config/mail-templates/README.md`. Xem thử hoặc gửi bản mẫu: `sh scripts/mail-preview.sh due_soon [địa chỉ]`.
Hiện chỉ email sắp đến hạn được hệ thống gửi tự động.

### 4. Kiểm thử API

Chạy `sql/test_v2_setup.sql` (tài khoản `v2pin`, `v2card`, `v2fp`, `v2noshow`, `v3overdue`, `v3poor`; đặt lại bộ đếm sai
mã của LOCKER-01) rồi `sql/test_v3_setup.sql` (tài khoản `v3late`, `v3esc` và các lượt gửi đã ở sẵn trạng thái kịch bản v3
cần: quá hạn 130 phút, đặt từ 6 phút trước, quá hạn 49 giờ), sau đó:

```powershell
newman run docs/postman/SmartLocker-v2.postman_collection.json -e docs/postman/SmartLocker-local.postman_environment.json --env-var api_key=<khóa LOCKER-01>
```

Chạy Postman xong, trước buổi demo: `sql/test_v3_cleanup.sql` đóng các lượt gửi của tài khoản kiểm thử trên CANT-A
và xử lý cảnh báo chuyển xử lý của chúng, để sơ đồ tủ không còn ngăn khóa hay cảnh báo do test để lại.

Unit test (TestNG) nằm ở `test/test/` (`PricingTest`, `PricingDatabaseIntegrationTest`: giá theo cỡ, phụ phí, gia hạn).
Chạy tất cả bằng `sh scripts/test.sh` (Git Bash; các lớp `*DatabaseIntegrationTest` cần SQL Server đang chạy), hoặc một
lớp: `sh scripts/test.sh test.PricingTest`.
`sql/test_overdue.sql` dời `due_at` của một lượt `ACTIVE` về quá khứ để demo khóa quá hạn, phụ phí và chuyển xử lý
(sửa `@username`, `@minutes_late`, `@balance` ở đầu file).

---

## Tài khoản demo

Mật khẩu chung: `123456`. Tình trạng hiện tại của dữ liệu mẫu (sau `06_demo_v2.sql`):

| Vai trò | Tài khoản dùng được | Ghi chú |
|---|---|---|
| ADMIN | `admin`, `admin_lib`, `admin_doma`, `admin_cant`, `admin_gym`, `admin_ops`, `manager1`, `manager2`, `sysadmin1` | `sysadmin2` bị vô hiệu hóa |
| OPERATOR | `operator1` (LIB), `operator2` (DOMA), `operator3` (CANT), `operator4` (GYM) | Chỉ 4 operator hoạt động, mỗi khu một người; `operator5`…`operator22` bị vô hiệu hóa |
| TECHNICIAN | `tech1` … `tech22` | `tech20` bị khóa, `tech22` bị vô hiệu hóa |
| AUDITOR | `auditor1` … `auditor16` | `auditor15` bị khóa, `auditor16` bị vô hiệu hóa |
| END_USER | `student1` … `student28`, `user1` | `locked1`, `student28` bị khóa; `student27` bị vô hiệu hóa |
| END_USER (Postman) | `v2pin`, `v2card`, `v2fp`, `v2noshow` | Tạo bởi `sql/test_v2_setup.sql` |
| END_USER (Postman v3) | `v3overdue` (200.000 đ), `v3poor` (12.000 đ, dưới mức đệm) | Tạo bởi `sql/test_v2_setup.sql`; `sql/test_v3_setup.sql` cho `v3overdue` một lượt quá hạn, ví 5.000 đ |
| END_USER (Postman v3) | `v3late` (lượt đặt từ 6 phút trước), `v3esc` (lượt quá hạn 49 giờ) | Tạo bởi `sql/test_v3_setup.sql` |

Tài khoản bị khóa hoặc vô hiệu hóa dùng để thử thông báo lỗi khi đăng nhập.

---

## Cấu trúc thư mục

```
SmartLocker/
├── config/          khóa bí mật của hộp thật, cấu hình email (*.local.properties, không commit)
├── docs/            spec, SYSTEM_FLOWS, deploy, postman, plan, handoff (v3), review
├── lib/             thư viện jar: JDBC, Gson, jBCrypt, Weka (đóng gói vào WAR); TestNG, JCommander, SLF4J (chỉ để test)
├── firmware/        mã Arduino cho hộp ESP32 (SmartLocker_Local)
├── scripts/         build-dev.sh, test.sh, mail-preview.sh, set-device-key.ps1, update-tunnel-link.ps1
├── sql/             01..07, 09_v3.sql, 10_campus_vnu.sql, test_v2_setup.sql, test_v3_setup.sql, test_overdue.sql
├── src/java/
│   ├── api/         API JSON: thiết bị, điện thoại, dashboard, sơ đồ tủ, Tủ của tôi
│   ├── controller/  servlet MVC2 của các trang
│   ├── dao/         JDBC; DbContext là nơi duy nhất mở kết nối
│   ├── filter/      SecurityFilter: đăng nhập, phân quyền, khóa API thiết bị
│   ├── ml/          mô hình Weka đã train
│   ├── model/       lớp dữ liệu
│   ├── service/     LockerMonitor, DueReminder, MailService, AlertService, RuleEngine, RiskScorer, AuditVerifier
│   └── util/        Web (đọc tham số, dịch lỗi SQL), SecurityUtils, Pricing, Csv, SlotImages
├── test/
│   ├── test/        unit test và integration test (TestNG)
│   └── tool/        công cụ chạy tay, không đóng gói vào WAR (xem dưới)
└── web/             css, js, WEB-INF/views (JSP)
```

### Công cụ chạy tay (`test/tool`)

`ScenarioSender` (giả hộp ESP32 cho các kịch bản cũ), `DataReplayer` (phát lại dữ liệu `PublicSession`),
`ModelTrainer` (train mô hình Weka vào `src/java/ml`), `TransferCheck` (so sánh F1 trên dữ liệu công khai và dữ liệu hộp),
`DeviceKey` (đọc khóa LOCKER-01). Chạy bằng Run File trong NetBeans, hoặc:

```powershell
javac -encoding UTF-8 -cp "build/web/WEB-INF/classes;lib/*" -d build/tools test/tool/*.java
java -cp "build/tools;build/web/WEB-INF/classes;lib/*" tool.ScenarioSender remote
```

Chạy từ thư mục dự án (các công cụ đọc `config/` và ghi `src/java/ml` theo đường dẫn tương đối).

---

## Bảo mật

- `SecurityFilter`: đường dẫn chưa khai báo bị từ chối; GET cần quyền READ, các phương thức khác cần WRITE của tài nguyên.
- Khóa API thiết bị lưu dạng SHA-256; `device_id` lấy từ khóa, không tin body.
- Đặt tủ chống tranh chấp bằng khóa trong procedure (`UPDLOCK, HOLDLOCK`) và cập nhật có điều kiện trạng thái ngăn.
- Nhật ký audit chỉ thêm, nối chuỗi băm; AUDITOR chỉ có quyền đọc.

Hạn chế đã biết: chưa có CSRF token; tài khoản `sa` nằm trong `DbContext`; không có connection pool.

## Giấy phép

Đồ án học tập môn PRJ301. Xem `LICENSE`.
