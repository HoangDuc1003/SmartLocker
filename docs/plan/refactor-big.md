# Plan refactor lớn SmartLocker

> Đây là bản plan đã được chủ dự án duyệt. Phần "Cập nhật từ P0" bên dưới thắng các câu nói khác đi ở phần sau.

## Cập nhật từ P0 (đọc trước khi làm bất kỳ phase nào)

- **Tomcat cổng 8080 là của chủ dự án.** Chạy từ NetBeans, có cả project khác (`PE_Prj301`). SmartLocker trong đó phục vụ từ `build/web` của thư mục OneDrive và dùng **mail thật**. Không stop, không reload, không chạy `scripts/build-dev.sh` ở thư mục đó, không ghi vào DB `PRJ301_LOCKER` trước P7.
- **Thư mục OneDrive** nằm trên nhánh `refactor/baseline`, đúng bằng tag `rf-baseline`, và không đổi nữa để app của chủ dự án vẫn chạy.
- **Mọi phase làm ở worktree `C:\sl-wt\refactor`, nhánh `refactor/big`**, ngoài OneDrive, có `build/` riêng. Worktree không có `config/*.local.properties` nên không có mail thật và không có khóa LOCKER-01: truyền `api_key` cho Newman bằng `--env-var`.
- **Test:** đặt `DB_URL` trỏ DB `SL_*`. Có thể tạo DB bằng cách khôi phục `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\PRJ301_LOCKER_pre_refactor.bak` (file logic `PRJ301_LOCKER`, `PRJ301_LOCKER_log`; thư mục dữ liệu `...\MSSQL\DATA\`). `scripts/test.sh` chưa bắt buộc `DB_URL` cho tới khi P1 sửa, nên luôn tự đặt.
- **Kiểm tra test đã chạy đúng DB** bằng `IDENT_CURRENT`: số dòng không đổi sau rollback nên không chứng minh được gì. Ở P0, `SL_P0` tăng audit 11239 lên 11244 còn `PRJ301_LOCKER` đứng yên.
- **Đính chính:** `ae87923` không xóa bước xác minh email; code Java của bước này chưa từng có trong git, E1 phải viết mới.
- **Hiện trạng test ở `rf-baseline`:** TestNG 60/60, `Skips: 0`, trên DB khôi phục từ backup. Newman **chưa chạy** từ khi có tính năng thẻ và email (P1 chạy lần đầu).

## Bối cảnh

Bạn muốn đợt refactor lớn nhất: rút gọn toàn bộ code, nhất là SQL, và sửa hết lỗi quét được. Ba agent đã đọc hết SQL, Java, frontend, firmware và tài liệu. Tôi đọc lại code cho các lỗi đánh dấu **[đã đọc]**; lỗi còn lại đến từ audit và sẽ được xác nhận bằng test fail trước khi sửa.

Hiện trạng: SQL 4.457 dòng, Java khoảng 11.000, JS/CSS/JSP 14.086. SQL là chỗ thừa nhiều nhất: 627 dòng là các bản chết của 10 object (`Deposit_ExpireNoShow` có 4 bản), cộng các lớp `ALTER` và `UPDATE` chồng lên schema gốc. Có 56 path chưa commit nên chưa có mốc để quay lại. Không có CI, và phần lớn Java chưa có test.

## Quyết định đã chốt

| Vấn đề | Quyết định |
|---|---|
| DB local | Backup `.bak`, dựng lại, bỏ dữ liệu cũ (mất `user1`, `hoangpro`). Giả định: không có DB hosted cần giữ |
| Mật khẩu | Khóa sau 5 lần sai, form đổi mật khẩu, reset sinh mật khẩu tạm. Tài khoản demo vẫn `123456` |
| Xác minh email | Bật lại bằng mã. Lịch sử git không có code cũ, phải viết mới, ước tính 100 đến 130 dòng thay vì 80 như tôi nói lúc hỏi |
| Dọn repo | Chỉ thêm `docs/paper/evidence/newman*.json` vào `.gitignore`. Giữ `.claude/skills`, giữ `README.en.md` đầy đủ, không commit `docs/paper` |

## Kết quả dự kiến

| Mảng | Hiện tại | Sau refactor | Giảm |
|---|---|---|---|
| SQL | 4.457 | khoảng 2.980 | **33%** |
| Java | khoảng 11.000 | khoảng 10.000 đến 10.300 | 6 đến 9% |
| JS/CSS/JSP | 14.086 | khoảng 13.300 | 6% |
| **Tổng** | khoảng 29.500 | khoảng 26.300 đến 26.600 | **khoảng 10%** |

Nói thẳng: tổng chỉ giảm khoảng 10%, không phải một nửa. Phần lớn còn lại là logic thật, và getter của model phải giữ vì JSP EL cần chúng. Sửa lỗi và tính năng mới sẽ cộng lại khoảng 400 dòng. Test và công cụ kiểm chứng thêm khoảng 700 dòng, không tính vào code sản phẩm.

## Nguyên tắc

- Refactor và sửa lỗi nằm ở **commit riêng**. Trong một đoạn refactor, DB cũ và mới phải giống hệt nhau, HTML và JSON ghi lại phải không đổi.
- Mỗi tầng làm theo thứ tự: refactor, kiểm chứng, rồi mới sửa lỗi của tầng đó. Sửa lỗi sau khi đã có bằng chứng tương đương thì công cụ so sánh cho thấy đúng object nào đổi.
- Không đổi hợp đồng API của hộp. Thiếu `physical` trong JSON là mọi servo đều chạy. Không đổi text `THROW` (khớp `Web.SQL_MESSAGES`), tên index, text hash của `Audit_Append`, chuỗi `"demo":true`.
- Không đụng `PRJ301_LOCKER` trước P7. Công cụ từ chối DB không có tiền tố `SL_`, `scripts/test.sh` bắt buộc có `DB_URL`, Tomcat test không được đọc cấu hình mail thật (sẽ gửi nhắc hạn thật).
- Mỗi phase bắt đầu từ `build/` sạch: `cp -u` và `javac` không xóa file cũ nên JSP và servlet đã bỏ vẫn chạy, che mất lỗi.
- Làm trên nhánh `refactor/big`, mỗi phase một tag `rf-*`. Rollback bằng `git revert`. **Không push và không merge vào `main` nếu bạn chưa đồng ý**: `docs/deploy-render.md` cho thấy web chạy từ repo nên push có thể làm Render deploy lại.
- Theo `CLAUDE.md`: mỗi phase một phiên mới dưới 300k token, kết thúc bằng commit và handoff `docs/handoff/refactor-<phase>.md`, rồi agent khác cross-review phần diff đó. Chạy tuần tự: song song không giảm token mà thêm rủi ro merge.

## Các phase

| Phase | Việc | Điều kiện qua phase | kTok |
|---|---|---|---|
| **P0** Mốc | Commit 56 path, tag `rf-baseline`, backup DB, chép plan | TestNG xanh trên build sạch | 40 |
| **B0** Lỗi khẩn | H1 | Test mới, không ảnh hưởng SQL | 40 |
| **P1** Công cụ | Tool so DB, stack test cổng 8081, chạy baseline | Hai lần build baseline khớp nhau, tool bắt được lỗi cấy | 150 |
| **P2a** SQL | Installer tạo DB, bỏ `USE`, bản chết, banner, guard no-op (khoảng -950 dòng) | Proof rỗng | 60 |
| **P2b** SQL | Gộp `ALTER` vào `CREATE`, sinh `02_procs.sql` bằng script | Proof rỗng, chạy lại `02_procs` hai lần vẫn đúng | 150 |
| **P2c** SQL | Gộp `UPDATE` vào seed, mỗi nhóm một commit | Proof, AuditChain, Postman | 200 |
| **P2d** SQL | Gộp `test_setup`, sửa tài liệu cài đặt, diễn tập nhánh Azure | Postman | 80 |
| **B-SQL** | M4, M17, M18, M19, lỗi SQL nhỏ, index | Test fail trước, proof chỉ liệt kê đúng object đã sửa | 120 |
| **P3** Lưới test | Ma trận quyền, golden JSON, kiểm `SQL_MESSAGES`, recorder | Xanh trên baseline, bắt được lỗi cấy | 150 |
| **P4a** Java | `Web`, `ApiJson`, config, hex, code chết | Recorder rỗng, Postman như cũ | 120 |
| **P4b** Java | DAO theo quy tắc lọc | Như trên | 180 |
| **B-Java** | H2, E1, M1, M2, M3, M5 đến M8, M10, M11, lỗi nhỏ (3 đợt) | Test fail trước, golden đổi đúng chỗ | 360 |
| **P5a** JS | File map dùng chung | E2E trên trình duyệt | 150 |
| **P5b** CSS | Rule giống hệt, code chết | Ảnh chụp cả hai theme | 100 |
| **P5c** JSP | Head jspf, pager tag | Recorder HTML rỗng, JspC | 120 |
| **B-UI** | M13, M14, M16, lỗi nhỏ UI | E2E trên trình duyệt | 120 |
| **B-FW** | M9, M12, M15, lỗi firmware nhỏ | Bạn nạp và thử trên hộp thật | 120 |
| **P7** Chốt | Dọn tên file, tài liệu, Docker, dựng lại DB thật | E2E đầy đủ, bạn nghiệm thu | 80 |

Có thể dừng an toàn sau bất kỳ tag nào. SQL, phần bạn ưu tiên nhất, xong sớm nhất.

### P0: mốc an toàn

- Tạo nhánh `refactor/big`. Thêm `docs/paper/evidence/newman*.json` vào `.gitignore`, `git add` theo từng path (không `git add docs`) để `docs/paper` vẫn untracked.
- Commit toàn bộ thay đổi hiện có, tag `rf-baseline`, thêm `.gitattributes` giữ CRLF cho `sql/`.
- `BACKUP DATABASE PRJ301_LOCKER` vào `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\`.
- Chép plan này vào `docs/plan/refactor-big.md`.
- Sửa `CLAUDE.md`: dòng 87 do tôi viết sai (`ae87923` không xóa gì, code Java xác minh chưa từng có trong git); thêm ngoại lệ cho phép các phase commit trên nhánh này, vì dòng 25 đang cấm commit.

### P1: công cụ kiểm chứng (`scripts/proof/`, PowerShell 5.1, khoảng 250 dòng)

- Bên cũ là worktree của `rf-baseline`. Script chép ra thư mục tạm, thay `PRJ301_LOCKER` bằng tên đích, giữ BOM, dừng nếu tên cũ còn sót. Sau khi chạy, xác nhận `create_date` của DB thật không đổi.
- Xuất ra text chuẩn để `git diff --no-index`, đọc được dòng nào khác: cột (cả view), identity, check, default, FK, index kèm filter, tham số, trigger, module đã bỏ comment và khoảng trắng, dữ liệu sắp theo PK. Thời gian so theo độ lệch từ mốc seed.
- Khác biệt được chấp nhận: cột khác nhau ngay giữa hai lần build baseline (PIN, hash audit), và `accepted.txt` chỉ cho metadata; dòng thừa trong file này làm tool báo lỗi. **Không bao giờ** chấp nhận khác biệt ở ô dữ liệu, identity, thứ tự cột, text `THROW`, tên index.
- Stack test: bản Tomcat `CATALINA_BASE` cổng 8081, `DB_URL` trỏ vào `SL_*`, không có mail thật. Newman chạy trên core cộng `test_setup`, **không** chạy `demo_box` (lý do ở M17).
- Lần chạy Postman đầu tiên cũng là lần đầu từ khi có tính năng thẻ và email. Lỗi tìm ra ở đây sửa trước khi đi tiếp.

### P2: SQL, mục tiêu chính

| File đích | Dòng | Nội dung |
|---|---|---|
| `sql/01_schema.sql` | 380 | Bảng ở dạng cuối, view gốc, `Audit_Append`, giữ các object của đề bài |
| `sql/02_procs.sql` | 1.350 | Hàm, view, procedure bản cuối; `CREATE OR ALTER`, **chạy lại an toàn trên DB đang dùng** |
| `sql/03_seed.sql` | 860 | Dữ liệu mẫu ở trạng thái cuối |
| `demo_box`, `test_setup`, `test_overdue`, `test_cleanup` | 393 | `test_setup` gộp còn 160 dòng |

Khoản giảm: bản chết 627, banner 140, gộp `ALTER` 128, guard no-op 105, seed trạng thái cuối 321, gộp `test_setup` 75, dòng thừa 80. Tổng 1.476. Khoảng 950 dòng gần như không rủi ro; 524 dòng còn lại mới cần cẩn thận.

Cần giữ đúng:
- Procedure phải chuyển **sau** khi gộp `ALTER`, vì `CREATE PROC` từ chối cột chưa có. Procedure đứng trước seed, vì seed gọi `Audit_Append` và `Code_NewSix`.
- Seed gộp dần từng nhóm, không viết lại một lần. Giữ nguyên dạng lệnh cho: hoán đổi thiết bị (id 5 là LOCKER-01), reseed identity (card 6, deposit 3; `02:553` phụ thuộc `card_id = n%20+1`). Thêm `ORDER BY` khi tạo ngăn. Hết budget thì dừng ở nhóm đang làm.
- Bỏ `USE` để chạy được với `-d`. Mỗi file có guard từ chối chạy trong `master`. Bỏ regex Azure trong `run_demo_db.ps1` (nó khớp text chính xác, sai thì hỏng im lặng) và diễn tập trên `SL_AZ`.
- Xóa: `V3_SIZE_LAYOUT`, `V3_OLD_SIZE_PCT`, key JSON không ai đọc. **Giữ** `email_code`, `email_pending` cho E1. Giữ `trg_LockerSession_AppendOnly`, `v_LockerSession_Features`, `control_owner`, các bảng của đề bài.
- `run_demo_db.ps1` và tài liệu cài đặt đổi trong P2d. Comment Java nhắc tên file cũ đổi ở P7.

### P3: lưới test trước khi đụng Java

Hiện không có test nào cho `SecurityFilter`, controller, CRUD của DAO, `Web`, `ApiJson`. Thêm:
1. Ma trận quyền role x path x method, dùng fake bằng `java.lang.reflect.Proxy` (`lib` không có Mockito).
2. Golden JSON: `DeviceAuthApi.reply`, heartbeat, khóa của `/api/locker-map` theo từng role.
3. Kiểm mọi text `THROW` có trong `Web.SQL_MESSAGES`.
4. Recorder `scripts/proof/`: cùng bộ GET theo từng role, so bản cũ và mới sau khi chuẩn hóa. Bắt được lỗi EL (chỉ nổ lúc chạy) và trường hợp `getObject` biến 0 thành `null`.

### P4: Java

- **P4a, khoảng -320 dòng:** `Web.page`, xử lý delete và `sqlMessage`; `ApiJson` public; gộp `MailService.candidates` với `MapboxConfig.candidates`; `CardMail.hash` dùng `SecurityUtils.sha256Hex`; xóa `IpGeoLocator`, 6 method chết và 22 getter chết (mỗi getter grep cả JSP trước khi xóa).
- **P4b, -350 đến -650 dòng:** thêm `DbContext.query/queryOne/queryInt/update/insertKey` cùng `RowMapper` được phép ném `SQLException`. Thử trước trên hai DAO. Chỉ đổi DAO nào **giảm từ 15% trở lên**, còn lại giữ nguyên. Không đụng đường đi của tiền (`TopupDao`, `DepositDao`, số dư trong `UserDao`, `LockerSlotDao.updateStatusAdmin`) và các DAO trả `Map` mà JSON phụ thuộc vào kiểu NULL. `inTx` chỉ thêm khi sửa M11.

### P5: frontend, khoảng -800 dòng

- **P5a, -207:** file `web/js/map-common.js` chứa 31 hàm giống từng byte và các hằng. Không gộp `load` (bản map có ETag và `no-store`, bản staff không; gộp sai là 304 không vẽ gì), `syncUrl`, `onPosition`, `ringHtml`.
- **P5b, -185 và -130 code chết:** token status và các rule giống từng byte giữa `locker-map.css` và `locker-map-staff.css`. Giữ `.slot`, `.legend`, `.notice`, `.panel-head` vì khác nhau có chủ đích. Xóa CSS và JS chết đã grep, kể cả class ghép chuỗi.
- **P5c, -266:** head jspf cho 7 trang và pager tag cho 11 file. Không dùng tag file cho phần cần `${ctx}`, `${me}` vì hai biến này đến từ nav jspf.

### Không làm mặc định, vì lợi ích nhỏ so với rủi ro

Khoảng 300 dòng: prelude taglib, page tail, row form tag, bảng menu chung, 5 hàm map gần giống. Có thể làm sau P5 nếu bạn muốn và còn budget.

## Danh sách lỗi

### Nghiêm trọng

| ID | Lỗi | Cách sửa | Đợt |
|---|---|---|---|
| H1 | **[đã đọc]** Username không giới hạn được ghi vào audit, và `LockerMonitor` nạp cả log mỗi 2 giây: khoảng 80 POST 2 MB gây OOM ở mọi lần chạy, còn nguyên sau khi restart. Mật khẩu gõ nhầm vào ô username cũng bị lưu | Chỉ ghi username có thật, tối đa 100 ký tự; `AuditVerifier` đọc theo luồng, lịch riêng 60 giây | B0 |
| H2 | **[đã đọc]** Không giới hạn đăng nhập sai, không có đổi mật khẩu, reset và tạo mới đều về `123456` | Lớp `Throttle` trong bộ nhớ (5 lần, 2 phút, theo cặp tài khoản + IP và theo IP); form đổi mật khẩu; reset và tạo mới sinh mật khẩu tạm hiện một lần | B-Java |
| E1 | **[đã đọc]** Email lưu như gõ, trong khi link mở tủ gửi tới đó | `setEmail` ghi `email_pending` và mã, gửi `verification_code`; nhập đúng (10 phút, 5 lần) mới chuyển sang `email`. Áp dụng cả khi đăng ký | B-Java |

### Trung bình

| ID | Lỗi | Cách sửa | Đợt |
|---|---|---|---|
| M1 | **[đã đọc]** Form sửa ngăn ghi `status`, OPERATOR đổi được OCCUPIED thành AVAILABLE khi đang có booking | Bỏ `status` khỏi `LockerSlotDao.update` | B-Java |
| M2 | **[đã đọc]** `AlertController` `device_status` cho ALERT:WRITE bật ACTIVE kèm `last_seen` mới, vượt qua guard ADMIN ngay bên dưới | Dùng cùng guard | B-Java |
| M3 | **[đã đọc]** `HealthApi` lấy lệnh (đã commit, booking đã đổi) rồi còn hai truy vấn có thể 500: mất lệnh, tủ đóng nhưng booking đã COMPLETED | Đọc hai danh sách trước `takePending` | B-Java |
| M4 | **[đã đọc]** `Ticket_OpenForFault` đè OCCUPIED; `Ticket_Close` đặt AVAILABLE trên booking đang chạy; lỗi thứ hai cùng thiết bị không có ticket và ngăn kẹt MAINTENANCE | Khôi phục trạng thái theo booking mở, đóng đủ các ngăn | B-SQL |
| M5 | **[đã đọc]** Scheduler một luồng, không timeout; RuntimeException hủy bảo trì âm thầm | Bắt `Throwable` cho mỗi việc, thêm `queryTimeout` và `socketTimeout` | B-Java |
| M6 | **[đã đọc]** Chỉ báo audit sai cả hai chiều: lỗi xác minh vẫn báo toàn vẹn, trang tải lần đầu báo "Bị sửa đổi" | Ba trạng thái: toàn vẹn, bị sửa, chưa rõ | B-Java |
| M7 | Đoán PIN ở `/k`: 5 lần mỗi 2 phút, không giới hạn IP | Dùng `Throttle` của H2 | B-Java |
| M8 | `LockerSessionApi:133`: lỗi đánh giá chỉ ghi log, gửi lại nhận DUPLICATE, mất cảnh báo | Đánh giá lại khi gửi lại nếu phiên chưa có kết quả | B-Java |
| M9 | **[đã đọc]** Firmware không gửi `/api/locker/batch`, nên hộp thật không chạy rule và ML, trong khi tài liệu nói có. Phần cứng không có cảm biến cửa và cân | **Sửa tài liệu cho đúng**, không thêm code. Muốn có thật thì cần phần cứng mới | B-FW |
| M10 | **[đã đọc]** Không có trang lỗi 500, người dùng thấy stack trace | Thêm `error-page` cho 500 và `Throwable` | B-Java |
| M11 | Audit tiền ghi sau commit trên connection khác; hoàn tiền ở `LockerSlotDao` chỉ ghi status | Ghi trong cùng transaction như `TopupDao:144`, thêm `inTx` | B-Java |
| M12 | **[đã đọc]** PIN gõ dở không hết hạn, người sau gõ nối vào và mất lượt thử | Xóa sau 20 giây không có phím | B-FW |
| M13 | Map staff vẽ lại mỗi 10 giây, mất focus và chữ đang gõ | Bỏ qua nếu dữ liệu không đổi, như `locker-map.js` | B-UI |
| M14 | **[đã đọc]** `glass-panel.js` bỏ qua `res.ok`, POST lỗi không báo gì | Kiểm tra status, báo toast | B-UI |
| M15 | **[đã đọc]** `secrets.example.h` chưa từng có, clone mới không build được firmware | Thêm file mẫu | B-FW |
| M16 | **[đã đọc]** Do tôi: `.place-alert` che tiêu đề thẻ ngăn khi rộng dưới 1496 px | Đẩy thẻ xuống dưới banner | B-UI |
| M17 | **[đã đọc]** `test_setup` âm thầm không làm gì khi LOCKER-01 không ở CANT-A; `demo_box` mặc định LIB-A còn README ghi CANT-A | `test_setup` báo lỗi rõ, sửa README, giữ LIB-A như DB của bạn | B-SQL |
| M18 | **[đã đọc]** Báo mất thẻ không cấp lại mã đăng ký, chủ tủ bị khóa ngoài | Làm như `Fingerprint_Delete` | B-SQL |
| M19 | Thẻ ACTIVE chưa đăng ký mở thẳng, bỏ qua cọc | Từ chối `CARD_NOT_ENROLLED`, seed đánh dấu thẻ mẫu đã đăng ký | B-SQL |

### Nhỏ

- **SQL (B-SQL):** không kiểm tra kết quả `sp_getapplock` **[đã đọc]**; `TakePending` xóa mọi việc của một deposit nên ACCESS rồi PICKUP trong một heartbeat mất PICKUP **[đã đọc]**; CHECK_IN từ điện thoại không kéo dài giờ giữ chỗ **[đã đọc]**; `Deposit_Cancel` trả ngăn đang MAINTENANCE về trống; `Deposit_CheckIn` đè ngăn đang MAINTENANCE; `03:1134` và `AuthText:147` viết cứng 10.000; tên dãy DOMB còn tiếng Anh. Thêm index: `LockerSession(slot_id)`, `Alert(session_id)` OPEN, `RemoteCommand(device_id, status)`, `RemoteCommand(confirm_hash)`, `AuditLog(object_type, object_id, action)`.
- **Java (B-Java):** đặt trùng trả 500 ở `BookingController:79`; `LockerMapDao:86-88` ghi DB trong GET của khách và nuốt lỗi; `CalibrationController` lưu 0 hoặc 1 khi gõ sai; `/api/locker/batch` trả 500 vĩnh viễn với chuỗi quá dài hoặc NaN; role lạ xóa role của user; `MailService:128` rò socket; doanh thu thiếu tiền no-show và KPI thiếu ALERT, OFFLINE; CSV giờ UTC không ghi nhãn; đăng xuất bằng GET; chưa rõ: Weka dùng chung không đồng bộ, cookie thiếu `Secure` sau TLS của Render.
- **UI (B-UI):** bảng dashboard mất nhãn trên điện thoại sau lần poll đầu; link sidebar đã đóng vẫn tab tới được; bấm lề popup đăng nhập đóng popup và mất chữ đã nhập; legend staff không thấy dưới 1800 px; lý do từ chối nạp tiền không được gửi (`topup.jsp:65-70`); text cũ ở `myLocker.jsp:139,180,184`, `locker-map-staff.js:470`, `lockerSlot.jsp:48`; chưa rõ, kiểm trên trình duyệt trước: popup đăng ký trên điện thoại thấp, thẻ ngăn khi xoay ngang.
- **Firmware (B-FW):** UNLOCK bị bỏ khi cửa đang mở; heartbeat chặn phím 6 giây khi offline; đăng ký vân tay 50 giây không có heartbeat; guard ở dòng 769 gần như không bao giờ chạy. Giữ `setInsecure()` vì đã ghi là bản demo.
- **Tài liệu (P7):** số liệu firmware và deploy lệch code; `docs/deploy.md:165` khuyên chạy lại SQL; spec nói hoàn 90% no-show; README thiếu test class, sai số kịch bản; `CLAUDE.md:67` nói firmware không có mạng. Sửa cả `README.md` lẫn `README.en.md`.

## Không làm trong đợt này

Không thêm thư viện hay build tool. Không đổi JSON của hộp. Không thêm phần cứng. Không xóa getter mà EL dùng. Không sửa `docs/paper` (bài báo không nhắc tên file SQL). `DbContext` vẫn có mặc định `sa/12345` cho máy local, tài liệu ghi rõ phải đặt `DB_*` khi deploy.

## Kiểm chứng

- **Mỗi phase:** build sạch, `sh scripts/test.sh` với `DB_URL` trỏ `SL_*` và `Skips: 0`, Newman 211 request so tập lỗi với baseline.
- **SQL:** proof rỗng giữa `rf-baseline` và HEAD, `AuditChainDatabaseIntegrationTest`, `02_procs.sql` chạy lại trên DB có dữ liệu không đổi gì.
- **P7, trên trình duyệt:** mọi trang ở cả hai theme và rộng 375 px; khách đăng nhập không tải lại trang; đặt ngăn, tự chọn, hủy qua mốc 5 phút, gia hạn, quá hạn; POST và flash trong panel; kéo sheet trên điện thoại; quét thẻ, mail, xác nhận, sóng, cảnh báo sai chỗ với SMTP giả; Mapbox token sai về Leaflet; tile offline; đăng nhập sai, đổi mật khẩu, xác minh email; drawer staff, mở từ xa, poll dashboard, `/k`, `/c/{token}`, 403, 404, 500.
- **P7, dựng lại DB thật:** chạy `run_demo_db.ps1`, `demo_box.sql`, `scripts/set-device-key.ps1`, rồi so với bản đã proof.
- **Bạn cần tự thử:** nạp firmware lên hộp thật, gửi Gmail thật, Mapbox có token thật. Máy này không có `arduino-cli` và chưa có token.

## Chi phí và rủi ro

- **Token:** ước tính khoảng 3 triệu, nhiều khả năng trải qua vài lần chạm giới hạn sử dụng. Hai lần review trước tốn 200k đến 280k so với 30k đã tính, nên con số thật có thể tới 4 triệu. Vì vậy phase nào cũng dừng được.
- **Rủi ro lớn nhất:** P2c (seed phụ thuộc thứ tự chạy, được proof chặn) và B-SQL với M19 (đổi hành vi thẻ, Postman có thể phải cập nhật).
- **Sai lệch kiến thức cũ:** nhiều dòng trong `CLAUDE.md` nhắc `03_v2_v3.sql`. P7 cập nhật hết. Dòng "không chạy lại toàn bộ `03_v2_v3.sql`" được thay bằng "chạy lại `02_procs.sql` an toàn".

## File chính

`run_demo_db.ps1`, `sql/*`, `scripts/test.sh`, `scripts/build-dev.sh`, `src/java/dao/DbContext.java`, `src/java/util/Web.java`, `src/java/api/ApiJson.java`, `src/java/api/HealthApi.java`, `src/java/service/LockerMonitor.java`, `src/java/service/AuditVerifier.java`, `src/java/controller/LoginController.java`, `src/java/controller/MyLockerController.java`, `src/java/controller/RegisterController.java`, `web/js/locker-map.js`, `web/js/locker-map-staff.js`, `web/js/glass-panel.js`, `web/css/locker-map.css`, `web/css/locker-map-staff.css`, `web/WEB-INF/web.xml`, `web/WEB-INF/views/common/*`, `firmware/SmartLocker_Online/SmartLocker_Online.ino`, `CLAUDE.md`, `README.md`, `README.en.md`, `docs/SYSTEM_FLOWS.md`.
