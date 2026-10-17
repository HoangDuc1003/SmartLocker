# Đánh giá SmartLocker so với dự án tham chiếu Pouring-System

Người viết: agent "evaluator", ngày 17/10/2026. Đây là báo cáo chỉ đọc: không sửa file nào khác trong SmartLocker.
Tham chiếu: https://github.com/TrongBVD/Pouring-System (theo lời bạn, dự án cùng môn PRJ301, được 10/10),
clone `--depth 1` vào scratchpad. Chỉ đọc, không build hay chạy gì từ repo này.

Quy ước: **[Đoán]** là suy luận chưa kiểm chứng. Điểm /10 là ước lượng theo từng tiêu chí, không phải
thang điểm chính thức của môn (mình không có rubric).

---

## 1. Tóm tắt dự án tham chiếu (Pouring-System / SmartWaterAuditDB)

**Nó là gì:** máy rót nước IoT dùng ESP32 + loadcell. Thiết bị gửi phiên rót qua `POST /api/pour-session/batch`
và heartbeat qua `/api/health`. Web Java Servlet/JSP (Ant, NetBeans) cho phép xem lịch sử rót, cảnh báo, bảo trì,
nhật ký cảm biến, thống kê, quản lý người dùng và nhật ký audit có chuỗi băm. Weka chấm điểm bất thường cho từng phiên rót.

**Cấu trúc (186 file):**
- `src/java/{controller,dao,model,service,utils,filter}`: 17 controller, 10 DAO, 9 model, 3 service
  (`WekaService`, `ChainVerificationService`, `MlScoringResult`), `utils/DBContext.java` (HikariCP, có DB dự phòng), `utils/SecurityUtils.java`.
- `web/*.jsp`: 14 JSP **đặt ở web root** (không nằm trong `WEB-INF`), `web/css/style.css` (947 dòng).
- `SmartWaterAuditDB.sql` (568 dòng, 22 bảng) và `SmartWaterAuditdb_Procedures_Views_Bootstrap.sql` (3.182 dòng:
  2 view, khoảng 22 stored procedure, `Bootstrap_Init`, 3 index).
- `pouring_system/pouring_system.ino`: firmware ESP32 2.315 dòng.
- `test/test/*.java` + `testng.xml`: TestNG (unit `SecurityUtilsTest`, test song song `ParallelSecurityUtilsTest`,
  integration `AuditChainDatabaseIntegrationTest` chạy trên SQL Server thật, tự `SkipException` khi không có DB).
- `demo_videos and pictures/`: 4 video demo phần cứng thật, 13 ảnh chụp màn hình, và
  `RCA_ErrorAbort_vs_Success_Pouring90ml.txt` (phân tích nguyên nhân gốc một lỗi firmware/backend).
- `web/WEB-INF/model/*.model`: 4 mô hình Weka đã train (Hoeffding, Logistic, NaiveBayes, RandomTree).

**Điểm mạnh có lẽ mang lại 10/10 [Đoán, theo bằng chứng]:**
1. **CSDL rất sâu**: logic nghiệp vụ nằm trong stored procedure có transaction, `SET XACT_ABORT ON`, TRY/CATCH, `THROW`;
   ràng buộc `CHECK` dày đặc phản ánh luật vật lý và nghiệp vụ (ví dụ `PourSession`: `ck_ps_time_order`,
   `ck_ps_result_code`, `ck_ps_tank_empty_consistency`, `UNIQUE(device_id, upload_id)` để chống trùng lô).
   Bằng chứng: `SmartWaterAuditDB.sql:120-203`.
2. **Audit chuỗi băm làm đúng trong DB**: `dbo.Audit_Append` khóa đỉnh chuỗi bằng `UPDLOCK, HOLDLOCK` để không bị rẽ nhánh,
   băm SHA-256 theo dạng chuẩn hóa (`Procedures...sql:156-270`); Java kiểm chứng lại bằng `ChainVerificationService`,
   và có integration test sửa một dòng rồi phát hiện (`test/test/AuditChainDatabaseIntegrationTest.java`).
3. **Demo phần cứng thật có bằng chứng**: video, ảnh, firmware đầy đủ, và một bản RCA. Đây là thứ giám khảo thấy ngay.
4. **ML có thật trong luồng ingest**: `PourAPI` gọi `WekaService` lúc nhận lô (`src/java/controller/PourAPI.java:112`).
5. **Có kiểm thử tự động** (TestNG, có cả nhóm unit/parallel/integration).

**Điểm yếu của tham chiếu (để không bắt chước nhầm):**
- Mật khẩu băm SHA-256 **không salt** (`utils/SecurityUtils.java`), API key thiết bị cứng `"ESP32_SECRET_2026"`, mật khẩu `sa` cứng.
- Bảng `Permissions/RolePerm` được nạp vào `User` nhưng `hasPermission` **không được gọi ở đâu**
  (`grep hasPermission` chỉ ra định nghĩa ở `model/User.java:28`); controller tự so chuỗi vai trò, ví dụ
  `AdminController.java:22`. Filter chỉ kiểm tra đã đăng nhập hay chưa.
- JSP ở web root, nhiều `<style>` nội tuyến, gần như không dùng `<c:out>` (0 lần ở 12/14 JSP).
- `build/`, `dist/*.war`, `.idea/` bị commit; README ngắn, chủ yếu hướng dẫn cài thư viện và đổi IP.

---

## 2. Bảng so sánh theo tiêu chí

| Tiêu chí | Pouring-System | SmartLocker | Bằng chứng / nhận xét |
|---|---|---|---|
| Chức năng / nghiệp vụ | **9** | **9** | Ref: rót theo profile, cảnh báo, bảo trì, hiệu chuẩn, thống kê, audit, ML. SL rộng hơn: khu/dãy/ngăn tủ, đặt tủ giữ chỗ 15 phút, ví + nạp tiền VietQR, 4 cách mở (PIN bàn phím, PIN điện thoại, RFID, vân tay), thẻ, lệnh mở từ xa, bảo trì, hiệu chuẩn, cảnh báo luật + Weka, audit chuỗi băm (`src/java/controller` 22 servlet, `src/java/api` 9 API). Rủi ro của SL: phạm vi rộng nên dễ có góc chưa test. |
| Kiến trúc MVC2 và phân lớp | 7 | **8** | Ref: JSP ngoài `WEB-INF` (mở trực tiếp được), `PourAPI` 257 dòng nằm trong `controller` và chứa cả logic nghiệp vụ. SL: mọi view trong `web/WEB-INF/views`, tách `api/`, `controller/`, `dao/`, `service/`, `util/`; SQL gần như chỉ ở DAO. Trừ điểm: `service/LockerMonitor.java:178`, `service/AuditVerifier.java:94`, `api/HealthApi.java:47` tự mở `DbContext`; `util/Web.java` chứa bảng dịch thông báo lỗi SQL. |
| CSDL và stored procedure | **10** | 8 | SL: 25 bảng ở `sql/01_schema.sql`, khoảng 30 procedure (`03_scenarios.sql` 17, `06_demo_v2.sql` 12...), 2 view, trigger `trg_LockerSession_AppendOnly`, hàm `fn_OpenPrice`, `Audit_Append`. Trừ điểm: ít `CHECK` hơn hẳn (01_schema chỉ 4); procedure bị định nghĩa lại ở nhiều file (`Deposit_ExpireNoShow` 3 lần, `Deposit_Reserve`, `Deposit_ExpireOverdue`, `RemoteCommand_TakePending` 2 lần); `TopupRequest` tạo ở cả `01_schema.sql:245` và `04_wallet_booking.sql:13`. |
| Bảo mật / phân quyền | 6 | **8.5** | SL: BCrypt có salt (`util/SecurityUtils.java`), một filter RBAC trung tâm, mặc định từ chối đường dẫn chưa khai báo (`filter/SecurityFilter.java:153-157`), GET cần READ, còn lại cần WRITE; khóa API thiết bị lưu dạng SHA-256 và tra ra `device_id` (không tin body); khóa nhập sai 5 lần trên hộp; `<c:out>` và `esc()` trong JS. Trừ điểm: không có CSRF token; mật khẩu `sa` cứng trong `dao/DbContext.java`; tiền tố công khai `/demo/` vẫn mở. |
| Kiểm tra dữ liệu | **8** | 7 | Ref đẩy kiểm tra xuống DB (CHECK + procedure). SL: `Web.intParam/trimmed` an toàn, procedure `THROW` lỗi nghiệp vụ và được dịch sang tiếng Việt (`Web.sqlMessage`), form có `required/pattern/maxlength` ở hầu hết JSP. Thiếu CHECK cho số tiền, thời gian, cân nặng ở nhiều bảng. |
| Giao diện / UX | 7 | **8** | SL: một bộ token sáng/tối `web/css/app.css`, `theme.js`, `nav.jspf` dùng chung, tiếng Việt, SVG, phân trang, xuất CSV, popup xác nhận. Trừ điểm: vẫn còn `style="..."` (10 chỗ ở `dashboard.jsp`, phần lớn là độ rộng thanh động, chấp nhận được), `locker-map.css` 902 dòng tách khỏi token chung [Đoán: chưa kiểm hết]. Ref: CSS đơn giản, `<style>` nội tuyến, chữ tiếng Anh. |
| Tài liệu | 7 | 7.5 | SL nhiều tài liệu hơn: `README.md`, `docs/SYSTEM_FLOWS.md` (mermaid), `docs/spec/smart-locker-v2.md`, `docs/deploy.md`, `docs/postman/`. Nhưng README tiếng Anh, có emoji, và **nói sai so với code**: "DAOs with connection pooling" (`README.md:185`, trong khi `DbContext` không có pool), chỉ báo `LIVE/RECONNECTING` (đã không còn trong `dashboard.js`), thứ tự SQL chỉ 01–05 (thiếu `06_demo_v2.sql`), con số "giảm tải DB hơn 80%" không có số đo. Ref: README ngắn nhưng có video, ảnh, RCA. |
| Kiểm thử | 7 | 6.5 | SL: `test/test/RuleEngineTest.java` (12 case đặt tên rõ theo kịch bản), `SecurityUtilsTest` (5), `RiskScorerTest` (1), `AuditChainDatabaseIntegrationTest` (4, có sửa dòng thật rồi hoàn tác), Postman collection v2 5.261 dòng + `sql/test_v2_setup.sql`. Không thấy `testng.xml` hay script chạy test, `test-output/` cũ [Đoán: test có thể chưa chạy lại sau v2]. Không có test cho DAO/procedure đặt tủ, là phần rủi ro nhất. |
| Khả năng demo / deploy | **10** | 7 | Ref có video phần cứng chạy thật. SL: có `docs/deploy.md`, `run_demo_db.ps1`, script tunnel; nhưng `run_demo_db.ps1:24-28` **không chạy `06_demo_v2.sql`** nên DB dựng bằng script sẽ thiếu bảng v2 (`Fingerprint`, `AuthAttempt`, ...); không có ảnh hay video; `vercel.json` và `index.html` ở gốc trỏ tới trang mock `web/demo/`; phụ thuộc Cloudflare quick tunnel (URL đổi mỗi lần). |
| Chất lượng code | 6 | 7 | SL: tên lớp nhất quán (`XxxController`, `XxxDao`), comment giải thích "vì sao", try-with-resources. Trừ điểm: mã chết và trùng lặp (mục 4), comment còn sót từ khung bài (`util/SecurityUtils.java`: `// BCrypt.hashpw(plain, BCrypt.gensalt(10))` ngay trên đúng dòng đó; `DbContext.java:7` "Copied from the assignment"; `util/Todo.java` không ai gọi), lớp lớn (`UserDao` 383 dòng, `DepositDao` 316, `DashboardDao` 314). Ref: helper JSON lặp trong controller, `System.err`, chuỗi vai trò cứng. |
| **Trung bình (không trọng số)** | **7.7** | **7.7** | Ngang nhau trên giấy. Ref được 10/10 có lẽ nhờ hai thứ có trọng số lớn mà bảng này không phản ánh: **demo phần cứng thật có bằng chứng** và **độ sâu CSDL**. [Đoán] |

---

## 3. SmartLocker làm tốt hơn tham chiếu

- **Phân quyền thực sự được thực thi**: bảng `Permissions` được filter dùng cho mọi request, mặc định từ chối;
  ref chỉ nạp quyền mà không kiểm tra.
- **Mật khẩu BCrypt có salt**, khóa API riêng cho từng thiết bị (băm SHA-256), lấy `device_id` từ khóa;
  ref dùng SHA-256 không salt và một khóa chung cứng trong code.
- **View nằm trong `WEB-INF`**, chỉ vào được qua controller.
- **Chống XSS có quy tắc** (`<c:out>`, `esc()`), có bài học ghi trong `CLAUDE.md`.
- **Nghiệp vụ phong phú và gần thực tế hơn**: ví, giữ chỗ, phạt không đến (hoàn 90%), gia hạn tối đa 3 lần,
  4 cách mở tủ, khóa sau 5 lần sai, trang điện thoại công khai.
- **Dashboard đọc từ snapshot cache** (`LockerMonitor`) thay vì truy vấn DB mỗi lần poll.
- **Có spec, hợp đồng API và Postman collection** cho API thiết bị v2: ref không có tài liệu API.
- **Giao diện thống nhất** (một stylesheet, theme sáng/tối, tiếng Việt).

## 4. SmartLocker còn thiếu so với tham chiếu

- **Bằng chứng demo**: không có ảnh, video, nhật ký chạy thật hay firmware trong repo (spec ghi firmware ngoài phạm vi,
  nhưng giám khảo vẫn muốn thấy hộp thật chạy).
- **Ràng buộc CHECK trong DB** ít hơn nhiều; ref dùng DB làm lớp bảo vệ cuối.
- **Một bộ SQL gọn**: ref có 2 file rõ vai trò (schema + procedure/view/bootstrap). SL có 7 file kiểu "migration vá"
  (`05_fix_reviewer_feedback.sql`) và procedure bị viết lại, nên khó biết bản nào là bản chạy.
- **Connection pool** (ref dùng HikariCP). SL mở kết nối mới mỗi lần, mà filter đã truy vấn 2 lần mỗi request
  (`SecurityFilter.java:141` lấy số dư, `:145` lấy quyền).
- **Bản phân tích sự cố (RCA)**: ref có một bản ngắn mà thuyết phục; SL có "Lessons" trong `CLAUDE.md`
  nhưng đó là ghi chú cho agent, không phải tài liệu nộp bài.
- **Bộ chạy test** (`testng.xml`) và kết quả test mới.

---

## 5. Danh sách refactor theo thứ tự ưu tiên

Nguyên tắc: không đổi đường dẫn, header `X-API-Key`, tên field JSON hay mã `reason` của API thiết bị v2
(`/api/health`, `/api/locker/batch`, `/api/device/auth`, `/api/device/enroll/*`, `/api/kiosk/unlock`).
Sau mỗi mục, chạy lại Postman collection v2 và các kịch bản E2E.

| # | File / package | Thay đổi | Lý do | Công sức |
|---|---|---|---|---|
| 1 | `run_demo_db.ps1`, `README.md` (mục Database Setup) | Thêm `06_demo_v2.sql` vào danh sách chạy và tài liệu. | Dựng DB bằng script hiện tại sẽ thiếu toàn bộ phần v2, demo hỏng ngay. | S |
| 2 | `docs/demo-code/` (88 file đã commit) | Xóa: đây là bản sao cũ của `src`, `sql`, `web`, `test`. | Hai bản code khiến người chấm hoặc agent đọc nhầm; `grep` ra kết quả trùng. | S |
| 3 | `web/demo/`, `index.html` ở gốc, `vercel.json`, tiền tố `"/demo/"` trong `SecurityFilter.PUBLIC_PREFIXES` | Xóa trang mock (chính `web/demo/README.txt` ghi "Trước khi nộp bài, xóa cả thư mục web/demo"). Nếu `index.html` gốc đang được trang GitHub Pages chuyển tiếp dùng thì giữ, chỉ bỏ phần trỏ tới mock. | Dữ liệu giả công khai mâu thuẫn quy tắc "không hiển thị trạng thái giả"; giám khảo có thể tưởng đó là app thật. | S |
| 4 | `util/Todo.java`, comment khung bài trong `util/SecurityUtils.java` (3 dòng `// BCrypt...`, `// null check...`, `// MessageDigest...`), `dao/DbContext.java:7`, `RuleEngine.java:17,37`, `TransferCheck.java:14` | Xóa lớp không dùng và các comment "skeleton/assignment". | Mã chết, comment lặp lại đúng dòng code bên dưới. | S |
| 5 | `README.md`, `docs/SYSTEM_FLOWS.md` | Viết lại bằng tiếng Việt, bỏ emoji, bỏ các câu sai so với code (connection pooling, `LIVE/RECONNECTING`, "giảm 80%", `ant compile` khi máy không có ant trên PATH), cập nhật cấu trúc thư mục (`api/`, `tool/`, `config/`, `scripts/`), thêm phần API v2 trỏ tới spec và Postman. | Tài liệu nói sai là điểm trừ dễ bị hỏi vặn nhất khi bảo vệ. | M |
| 6 | `sql/` | Gộp thành bộ rõ vai trò, ví dụ `01_schema.sql` (mọi bảng, gồm `TopupRequest` một lần và các bảng v2), `02_procedures_views.sql` (mỗi procedure chỉ một bản cuối cùng), `03_sample_data.sql`, `04_demo_v2.sql` (chỉ dữ liệu demo). Bỏ tên "fix_reviewer_feedback". Giữ UTF-8 BOM. Kiểm tra bằng cách dựng DB mới từ đầu rồi chạy Postman. | Hiện `Deposit_ExpireNoShow` có 3 bản; ai đọc `03_scenarios.sql` sẽ thấy logic cũ. | L |
| 7 | `sql/01_schema.sql` | Thêm `CHECK` kiểu tham chiếu: số tiền `Deposit`/`StoragePlan` > 0, `due_at > started_at`, `door_open_sec >= 0`, `balance >= 0`, các enum trạng thái còn thiếu. | Lớp phòng thủ cuối ở DB, đúng thứ ref được khen. | M |
| 8 | `src/java/tool/` (`ModelTrainer`, `TransferCheck`, `DataReplayer`, `ScenarioSender`) | Chuyển sang source root riêng (ví dụ `tools/src`) hoặc thư mục test, không đóng gói vào WAR. **Không xóa Weka**: `service/RiskScorer` được `service/AlertService.java:31` gọi lúc chạy. | Các lớp `main` chạy tay nằm lẫn với code web; `ScenarioSender` chứa URL localhost cứng. | M |
| 9 | `util/Web.java` | Chuyển `SQL_MESSAGES` và `sqlMessage` sang lớp riêng (ví dụ `util/ErrorText.java`, đặt cạnh `service/AuthText.java`), để `Web` chỉ còn helper request/session. | Một lớp đang gánh hai việc, bảng dịch sẽ còn dài thêm. | S |
| 10 | `api/HealthApi.java:64-71`, `api/LockerSessionApi.java:67`, `api/DashboardApi.java:49` | Dùng `ApiJson.body()` và `ApiJson.GSON` thay cho `JsonParser`/`new Gson()` riêng. Lưu ý: `ApiJson.GSON` có `serializeNulls` và định dạng ngày riêng, nên phải so JSON trả về trước và sau để không đổi hợp đồng API. | Helper trùng lặp, hai cách viết lỗi 400. | S–M |
| 11 | `web/js/app.js`, `web/js/dashboard.js`, `web/js/locker-map.js` | Giữ một `esc()` trong `app.js` (gắn vào `window`), hai file kia dùng lại. | Ba bản của một hàm bảo mật; sửa một bản dễ quên hai bản kia. | S |
| 12 | `service/LockerMonitor.java:178`, `service/AuditVerifier.java:94`, `api/HealthApi.java:47` | Chuyển truy vấn vào DAO (`DeviceDao`, `AuditDao`, một `ping()` trong `DbContext`). | Đúng phân lớp MVC2: chỉ DAO chạm JDBC. | S–M |
| 13 | `filter/SecurityFilter.java`, `dao/DbContext.java` | Thêm pool (Tomcat JDBC qua `META-INF/context.xml` + JNDI) **hoặc** cache quyền trong session và chỉ làm mới khi đổi vai trò; đọc tài khoản DB từ file cấu hình giống `config/device-keys.local.properties`. | Hai truy vấn DB trên mỗi request (cả request ajax poll), không có pool; mật khẩu `sa` trong code. | M |
| 14 | `dao/UserDao.java` (383 dòng), `dao/DepositDao.java`, `dao/DashboardDao.java` | Tách `UserDao` thành phần đăng nhập/hồ sơ/số dư và phần quản trị CRUD; kiểm tra `DashboardDao` còn được dùng khi dashboard đã chạy từ snapshot. | Lớp lớn khó đọc khi bảo vệ. | M |
| 15 | Các JSP có form POST + `filter/` | Thêm CSRF token đơn giản (token trong session, `<input type="hidden">` trong `nav.jspf`/form, filter kiểm tra). Bỏ qua cho đường dẫn API thiết bị. | Lỗ hổng phổ biến mà giám khảo hay hỏi; ref cũng không có nên đây là điểm cộng. | M |
| 16 | Comment trong code | Chốt một quy ước: comment code tiếng Anh (hiện gần như toàn bộ là tiếng Anh), văn bản giao diện và tài liệu nộp bài tiếng Việt. Ghi quy ước vào `CLAUDE.md`. | Hiện README/SYSTEM_FLOWS tiếng Anh nhưng spec/deploy tiếng Việt. | S |
| 17 | `web/WEB-INF/views/*.jsp` | Chuyển `style="font-size:20px"`, `style="margin-top:16px"` (ví dụ `dashboard.jsp:93,132`) thành class trong `app.css`; giữ `style="width:..%"` động. | Nhất quán với quy tắc một stylesheet. | S |

---

## 6. Rủi ro cho buổi demo và chấm điểm

1. **DB dựng thiếu v2** nếu dùng `run_demo_db.ps1` (mục 5.1). Rủi ro cao, sửa mất 1 phút.
2. **Cây làm việc đang có rất nhiều thay đổi chưa commit** (`git status`: hơn 50 file sửa, `booking.jsp` đã xóa) trong khi
   nhiều agent cùng sửa. Cần một commit ổn định đã test, và demo từ commit đó.
3. **Tunnel**: Cloudflare quick tunnel đổi URL mỗi lần chạy; nếu mạng phòng thi chặn thì trang điện thoại `/k/LOCKER-01`
   và ESP32 qua tunnel đều hỏng. Chuẩn bị phương án LAN cùng Wi-Fi như ref (`docs/deploy.md` mục xử lý sự cố).
4. **Heartbeat giả cho 7 thiết bị demo** (`LockerMonitor.java:120-125`, chỉ thiết bị có `"demo":true`): đúng spec Q14,
   nhưng phải nói rõ khi demo, nếu không sẽ bị coi là "trạng thái giả".
5. **Tài liệu nói quá** (pool, chỉ báo LIVE, 80%): giám khảo đối chiếu code là thấy ngay (mục 5.5).
6. **ML**: mô hình train trên dữ liệu công khai (`PublicSession`, TON_IoT theo comment `ModelTrainer`), trong khi spec ghi
   hộp thật không có cảm biến cửa và cân (`weight_delta_g` gửi 0). Điểm rủi ro của Weka trên dữ liệu thật gần như vô nghĩa;
   cần trả lời trung thực "luật quyết định, ML chỉ bổ trợ" và chuẩn bị số liệu từ `TransferCheck`. [Đoán: chưa chạy để xem F1]
7. **Không có bằng chứng ghi sẵn**: nên quay video hộp LOCKER-01 mở bằng PIN, thẻ, vân tay và chụp ảnh từng màn hình,
   để dự phòng khi phần cứng hỏng lúc demo. Đây là thứ ref có mà SL không có.
8. **Dữ liệu demo bị v2 thay đổi**: `06_demo_v2.sql` chuyển 18 operator sang `DISABLED`, trong khi README vẫn liệt kê
   `operator1`…`operator22`. Đăng nhập nhầm tài khoản bị khóa giữa buổi demo sẽ gây lúng túng.
9. **Test chưa chạy lại** [Đoán]: `test-output/` có vẻ là kết quả cũ; integration test cần DB thật. Chạy lại và lưu kết quả trước buổi chấm.
10. **Phạm vi rộng**: 22 controller và 9 API, mỗi nút đều có thể bị bấm thử. Ưu tiên test E2E 10 kịch bản trong spec §6.2 trước khi refactor sâu
    (mục 6, 13, 14 nên làm sau buổi demo nếu thời gian gấp).

---

## 7. Cách kiểm chứng báo cáo này

- Tham chiếu: clone repo trên, xem các file và số dòng đã dẫn.
- SmartLocker: các đường dẫn và số dòng ở trên lấy từ cây làm việc ngày 17/10/2026; vì các agent khác đang sửa song song,
  số dòng có thể lệch vài dòng.
