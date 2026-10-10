# Smart Locker: hướng dẫn từng file

Tài liệu này đi từ project trống đến bản nộp, **từng file một**. Project đã có sẵn **khung** cho mọi file: mở được, biên dịch được, chạy được. Việc của bạn là thay các `TODO` bằng code, theo thứ tự trong mục 3, vừa làm vừa hiểu hệ thống.

Cấu trúc của mỗi file trong tài liệu:

| Mục | Nội dung |
|---|---|
| **Đọc trước** | Nơi có ví dụ để học: đề, repo mẫu, project UserManagement cũ |
| **Việc của file** | File này làm gì, gọi ai, ai gọi nó |
| **Mẫu** | Code demo, đã biên dịch. Chỉ là một phần: các hàm còn lại là việc của bạn |
| **Khung bạn làm** | Các `TODO` có trong file khung, đúng như trong project |
| **Tự kiểm tra** | Cách biết file chạy đúng |
| **Dễ sai** | Lỗi thật đã gặp khi dựng thử |

Gợi ý nằm trong các file khung (`TODO ...`) viết bằng **tiếng Anh**, vì đề yêu cầu tên biến, nhãn và chú thích trong mã bằng tiếng Anh. Tài liệu này giải thích bằng tiếng Việt.

## Mục lục

- [0. Cách làm việc](#0-cách-làm-việc)
- [1. Hệ thống chạy như thế nào](#1-hệ-thống-chạy-như-thế-nào)
- [2. Chuẩn bị môi trường](#2-chuẩn-bị-môi-trường)
- [3. Thứ tự làm](#3-thứ-tự-làm)
- [Nguồn để đọc](#nguồn-để-đọc)
- [4. Giai đoạn 1: cơ sở dữ liệu](#4-giai-đoạn-1-cơ-sở-dữ-liệu)
- [5. Giai đoạn 2: đăng nhập và phân quyền](#5-giai-đoạn-2-đăng-nhập-và-phân-quyền)
- [6. Giai đoạn 3: thêm, xem, sửa, xoá](#6-giai-đoạn-3-thêm-xem-sửa-xoá)
- [7. Giai đoạn 4: sơ đồ tủ theo khu](#7-giai-đoạn-4-sơ-đồ-tủ-theo-khu)
- [8. Giai đoạn 5: nhật ký chống sửa](#8-giai-đoạn-5-nhật-ký-chống-sửa)
- [9. Giai đoạn 6: API cho thiết bị](#9-giai-đoạn-6-api-cho-thiết-bị)
- [10. Giai đoạn 7: luật và cảnh báo](#10-giai-đoạn-7-luật-và-cảnh-báo)
- [11. Giai đoạn 8: năm trường hợp thực tế](#11-giai-đoạn-8-năm-trường-hợp-thực-tế)
- [12. Giai đoạn 9: học máy](#12-giai-đoạn-9-học-máy)
- [13. Giai đoạn 10: dashboard](#13-giai-đoạn-10-dashboard)
- [14. Khi có thiết bị thật (tuần sau) và phần mở rộng +2 điểm](#14-khi-có-thiết-bị-thật-tuần-sau-và-phần-mở-rộng-2-điểm)
- [15. Nộp bài](#15-nộp-bài)
- [Phụ lục A. Lỗi thật đã gặp khi dựng thử](#phụ-lục-a-lỗi-thật-đã-gặp-khi-dựng-thử)
- [Phụ lục B. Thêm một trang mới](#phụ-lục-b-thêm-một-trang-mới)
- [Phụ lục C. Tìm file nằm ở mục nào](#phụ-lục-c-tìm-file-nằm-ở-mục-nào)

## 0. Cách làm việc

1. Mở file khung trong NetBeans, đọc phần `TODO` ở đầu và trong thân hàm.
2. Đọc mục **Đọc trước** và **Mẫu** của file đó trong tài liệu này.
3. **Tự gõ** (đừng copy từng dòng): bạn sẽ hiểu hơn và nhớ được khi thầy hỏi.
4. Bấm Run, thử trên trình duyệt, xem log của Tomcat.
5. Khi bí, so với `docs/demo-code/`: đó là cùng file ở dạng đã viết phần mẫu (các hàm không có trong mẫu vẫn còn `TODO`).

Khung đã được kiểm tra như sau, để bạn biết nó đáng tin tới đâu:

- Toàn bộ 70 file Java của khung biên dịch sạch bằng JDK 8, không một cảnh báo.
- Chạy trên Tomcat 9: cả 19 trang mở được (HTTP 200); chức năng ghi (POST) chưa viết trả lỗi `TODO ...` trong log; API chưa viết trả 501.
- Các bài test đi kèm khung **fail** với thông báo `TODO` và **pass** khi code đã viết. Đó là vòng học: làm cho test chuyển xanh.
- Các câu SQL trong tài liệu đã chạy thật trên SQL Server 2022: `01_schema.sql`, `03_scenarios.sql` (45 kiểm tra hành vi của 5 trường hợp), `02_workshop2.sql` (với dữ liệu thô giả lập), cùng 32 câu SQL trích từ các lớp DAO.
- Bộ kiểm tra nhật ký bằng Java đã đối chiếu với 22 dòng do `Audit_Append` của SQL Server ghi: dòng sạch báo đúng, dòng bị sửa báo đúng dòng bị sửa.
- Weka đã chạy thật: huấn luyện, lưu, nạp lại trong JVM mới và chấm điểm.

**Chưa kiểm tra được trên máy này** (cần bạn chạy):

- Các lớp DAO chạy qua JDBC với tài khoản `sa` của bạn (máy này không có thư viện xác thực Windows của driver, và mình không tạo tài khoản SQL). SQL bên trong đã chạy được, phần Java gọi JDBC mới chỉ biên dịch.
- Bài test TestNG chạy bằng chính TestNG (mình chạy logic test bằng bản thay thế nhỏ vì không có jar TestNG).
- Phần cứng ESP32.

## 1. Hệ thống chạy như thế nào

```
 Trình duyệt (5 vai trò)                 ESP32 (tuần sau) hoặc ScenarioSender (bây giờ)
        |  GET / POST + cookie phiên              |  POST /api/health          mỗi 10 giây
        |                                         |  POST /api/locker/batch    sau mỗi phiên
        v                                         v
 +-------------------------------------------------------------------------------+
 | Tomcat 9                                                                       |
 |                                                                                |
 |   SecurityFilter   công khai? khoá API của thiết bị? đã đăng nhập? có quyền?   |
 |        |                                      |                                |
 |   Controller --forward--> JSP            API servlet (JSON)                    |
 |        |                                      |                                |
 |        |                              AlertService                             |
 |        |                                |-- RuleEngine  (luật, chạy trước)     |
 |        |                                '-- RiskScorer  (Weka, chạy sau)       |
 |        v                                      v                                |
 |   DAO: mọi câu SQL nằm ở đây  <---------------'        LockerMonitor (30 giây) |
 +----------------------------|-----------------------------------------------+
                              v
              SQL Server: bảng, view, stored procedure (Audit_Append nối chuỗi băm)
```

### Một yêu cầu của người dùng đi qua những đâu

Ví dụ: nhân viên mở `LockerSlotController?q=A0&page=2`.

1. `SecurityFilter.doFilter`: đường dẫn không công khai, không phải API thiết bị. Lấy `LOGIN_USER` từ phiên, nạp tập quyền `{"MAP:READ", "LOCKERSLOT:WRITE", ...}` từ CSDL, tra bảng `RESOURCE_BY_PATH` ra `LOCKERSLOT`, phương thức GET nên cần `LOCKERSLOT:READ`. Có thì cho qua, không thì trả 403 và `denied.jsp`.
2. `LockerSlotController.doGet`: đọc `q`, `page` bằng `Web.trimmed` và `Web.intParam`, gọi `LockerSlotDao.count` và `search`, đặt kết quả vào `request`, rồi `forward` tới `lockerSlot.jsp`.
3. `lockerSlot.jsp`: chỉ in. Mỗi chuỗi đi qua `<c:out>` nên ký tự `<` trong dữ liệu không phá trang.
4. Khi bấm Delete (POST): bộ lọc đòi `LOCKERSLOT:WRITE`; controller kiểm tra, `dao.delete`, `AuditDao.append`, đặt thông báo vào phiên (`Web.flash`) rồi **redirect** (không forward). Nhờ vậy bấm F5 không xoá lần nữa. Mẫu này gọi là Post/Redirect/Get.

### Một phiên của thiết bị đi qua những đâu

1. ESP32 gửi `POST /api/locker/batch` kèm header `X-API-Key`.
2. `SecurityFilter` băm khoá bằng SHA-256, tra `Device.api_key_hash`. Tìm ra `device_id` thì đặt vào `request`; **mọi API dùng số này, không dùng `device_id` trong nội dung** thiết bị gửi.
3. `LockerSessionApi` lặp từng phiên: `LockerSessionDao.insert` (trùng `(device, seq)` thì bỏ qua), `AlertService.evaluate`, rồi `DepositDao.complete` trả ngăn.
4. `AlertService`: nạp `SessionContext` từ CSDL, `RuleEngine` quyết định theo thứ tự ưu tiên, `RiskScorer` cho điểm Weka, ghi `Alert` và bằng chứng.
5. Người dùng thấy ngăn đổi màu trên sơ đồ trong 10 giây (trang tự tải lại dữ liệu).

### Quy tắc của dự án (MVC2)

| Lớp | Được | Không được |
|---|---|---|
| JSP | In dữ liệu, form, vòng lặp JSTL | Không có câu SQL, không có `new Dao()`, không có logic nghiệp vụ |
| Controller | Đọc tham số, kiểm tra, gọi DAO, đặt thuộc tính, forward hoặc redirect | Không sinh HTML, không nối chuỗi SQL |
| DAO | Mọi câu SQL, luôn `PreparedStatement` với `?` | Không biết `HttpServletRequest` |
| Filter | Quyết định ai được vào đường dẫn nào | Không chứa nghiệp vụ |
| Stored procedure | Thao tác nhiều bước phải nguyên tử, và phải ghi nhật ký | |

Các quy ước dùng xuyên suốt:

- **Hai lần kiểm tra**: trình duyệt kiểm tra (`required`, `pattern`) chỉ để đỡ một vòng gửi lên; controller kiểm tra lại mọi luật. Người ta có thể gửi form mà không qua trình duyệt.
- **Lỗi có chữ cho người dùng**: stored procedure `THROW 50xxx, N'...'`. Trong Java, `SQLException.getErrorCode() >= 50000` nghĩa là lỗi này viết cho người dùng đọc, hiện nguyên văn bằng `Web.flash`. Mã khác là lỗi thật, ném tiếp. Bảng mã ở phụ lục B.
- **Giờ UTC**: CSDL ghi `SYSUTCDATETIME()`, thiết bị gửi giờ UTC. Chỉ đổi sang giờ địa phương khi hiển thị.
- **Nhật ký**: luôn truyền người thực hiện thật và mã đối tượng thật cho `Audit_Append`. NULL được SQL coi là chuỗi rỗng nhưng Java coi là `0`, hai bên băm ra khác nhau và bộ kiểm tra báo "bị sửa" dù không ai sửa. Việc tự động dùng người dùng `system` (user_id = 1).
- **Không đặt dữ liệu vào JavaScript viết thẳng trong HTML** (ví dụ `onsubmit="confirm('${x}')"`): một dấu nháy trong dữ liệu sẽ phá chuỗi.

### Bảng phân quyền

`R` là chỉ đọc, `RW` là đọc và ghi, `-` là không có. Đây là đề xuất của mình, thay bằng bảng trong tệp "Quy định chung" của đề nếu khác (đề tham chiếu tệp này, mình chưa có).

| Tài nguyên | ADMIN | OPERATOR | TECHNICIAN | AUDITOR | END_USER |
|---|---|---|---|---|---|
| USER | RW | RW | R | R | - |
| ROLE | RW | R | - | R | - |
| DEVICE | RW | R | RW | R | - |
| SENSOR_TYPE | RW | R | RW | R | - |
| CALIBRATION | RW | R | RW | R | - |
| PROFILE | RW | R | R | R | - |
| LOCKERSESSION | RW | R | R | R | - |
| LOCKERSLOT | RW | RW | R | R | - |
| ALERT | RW | RW | RW | R | - |
| MAINTENANCE | RW | R | RW | R | - |
| AUDIT | RW | R | - | R | - |
| MAP | RW | R | R | R | R |
| AREA | RW | RW | R | R | - |
| LOCKERBANK | RW | RW | R | R | - |
| STORAGEPLAN | RW | RW | - | R | - |
| USERCARD | RW | RW | - | R | - |
| MYCARD | RW | - | - | R | RW |
| DEPOSIT | RW | RW | R | R | - |
| BOOKING | RW | - | - | R | RW |
| COMMAND | RW | RW | - | R | - |

Quy tắc ngoài bảng, kiểm tra trong controller: trừ ADMIN, một vai trò chỉ thêm, sửa, khoá, đặt lại mật khẩu tài khoản có vai trò **thấp hơn** mình (`rank_no` lớn hơn).

Khác với bản demo giao diện: demo dùng mã quyền chi tiết như `USER_LOCK`; thật dùng cặp (tài nguyên, READ/WRITE) đúng như đề. Mở tủ từ xa là `COMMAND:WRITE`, đặt chỗ là `BOOKING:WRITE`, đổi quyền vai trò là `ROLE:WRITE`.

### Tên gọi

| Nhãn phiên của đề (dùng để huấn luyện) | NORMAL, OVERDUE, FORCED_OPEN, WRONG_USER, ITEM_LEFT, SUSPECTED_SPOOF |
|---|---|
| Nhãn cảnh báo thêm cho 5 trường hợp | DEVICE_OFFLINE, SENSOR_FAULT, LOST_CARD_USED, ML_ANOMALY |
| Kết quả không phải cảnh báo | NORMAL, STAFF_OPEN (nhân viên mở từ xa hợp lệ) |
| Năm trường hợp | 1 tủ mất mạng, 2 nhân viên mở từ xa, 3 mất thẻ, 4 đặt chỗ không đến, 5 cảm biến hỏng |

## 2. Chuẩn bị môi trường

### 2.1 Phần mềm

| Việc | Cách làm |
|---|---|
| JDK 8u202 trong NetBeans | Máy bạn đã cài ở `C:\Program Files\Java\jdk1.8.0_202`. Java Platform Manager đang chỉ liệt kê 8u171. Bấm **Add Platform**, chọn **Java SE**, trỏ tới thư mục trên. Không bắt buộc: 8u171 đủ dùng. Project đang dùng JDK mặc định |
| Tomcat 9 | Đã có ở `E:\apache-tomcat-9.0.113` (NetBeans lưu trong `nbproject/private/private.properties`) |
| SQL Server | Chạy dịch vụ `MSSQLSERVER`, cổng 1433 mở. Mật khẩu của `sa` bạn tự đặt, ghi vào `DbContext.java` |

### 2.2 Thư viện (jar)

| Jar | Trạng thái | Việc cần làm |
|---|---|---|
| `gson-2.10.1.jar` | Có ở `E:\` và đã nằm trong project | Không |
| `jbcrypt-0.4.jar` | Như trên | Không |
| `mssql-jdbc-12.8.1.jre8.jar` | Như trên | Không |
| `jstl-1.2.jar` | Mình đã chép vào `web/WEB-INF/lib/` | Không. Thiếu jar này mọi trang JSP lỗi "uri cannot be resolved" |
| `weka-stable-3.8.6.jar` | Có, **nhưng không đủ để chạy** | Xem 2.3 |
| `testng` | Chưa có | Xem 2.4 |

Project đang tham chiếu các jar ở `E:\` bằng đường dẫn tuyệt đối (`file.reference.*` trong `nbproject/project.properties`). Máy khác mở project sẽ lỗi. Đề yêu cầu chép jar vào dự án: chép vào thư mục `lib/` của project rồi thêm lại bằng **Libraries, Add JAR/Folder**. Kiểm tra trong **Project Properties, Packaging** là các jar được đóng vào `WEB-INF/lib` khi build.

### 2.3 Weka thiếu một thư viện phụ

Chạy `weka-stable-3.8.6.jar` đơn lẻ báo `NoClassDefFoundError: org/bounce/net/DefaultAuthenticator` ngay khi tạo bộ phân lớp đầu tiên. Có hai cách, cả hai đã chạy thử đến khi chấm điểm được:

- Dùng `weka.jar` (14 MB) trong thư mục `Library Pouring System` của repo mẫu `TrongBVD/Pouring-System`. Jar này đã gói sẵn các thư viện phụ. Thay thế `weka-stable-3.8.6.jar`.
- Hoặc giữ `weka-stable-3.8.6.jar` và thêm `bounce-0.18.jar` (thư viện phụ của Weka, có trên Maven Central).

### 2.4 TestNG

NetBeans có thể có sẵn thư viện TestNG: chuột phải **Test Libraries**, **Add Library**, tìm TestNG. Nếu không có, tải `testng-7.5.jar` cùng các jar mà nó cần (`jcommander`, `slf4j-api`; xem trang của TestNG 7.5 trên Maven Central để lấy đúng bản). Đề liệt kê `testng-7.5`.

### 2.5 Chạy thử khung

1. Chạy `sql/01_schema.sql` bản của bạn sau khi viết xong (mục 4). Chưa có CSDL thì các trang vẫn mở nhưng DAO chưa có để gọi.
2. Mở `nbproject/project.properties` chỉ để kiểm tra, không cần sửa.
3. Bấm **Run**. Trang chủ có hai nút: **Open the application** (khung của bạn) và **Open the static demo** (giao diện demo cũ với dữ liệu mẫu).
4. Mở `http://localhost:8080/SmartLocker/LockerSlotController`: trang trống, mới chỉ có thanh trên cùng (menu chưa có vì chưa có bộ lọc nạp quyền). Gửi một biểu mẫu ghi: lỗi 500, log Tomcat ghi `TODO ...`. Đúng như thiết kế.

Đường dẫn gốc `/SmartLocker` lấy từ `web/META-INF/context.xml`.

## 3. Thứ tự làm

| Giai đoạn | Mục tiêu (xong khi) | File |
|---|---|---|
| 1. CSDL | Chạy `01_schema.sql` không lỗi, thấy 90 ngăn tủ | `sql/01_schema.sql` |
| 2. Đăng nhập | Đăng nhập được 5 vai trò, menu đúng theo quyền, `student1` bị chặn khi gõ thẳng đường dẫn quản trị | `util/*`, `dao/DbContext`, `UserDao`, `PermissionDao`, `AuditDao`, `SecurityFilter`, `LoginController`, `LogoutController`, `RegisterController`, `login.jsp`, `register.jsp` |
| 3. CRUD | Thêm, sửa, xoá, tìm, phân trang, xuất CSV cho ngăn tủ, rồi làm tương tự cho các thực thể còn lại | `LockerSlot*` (mẫu), rồi `LockerBank`, `LockerArea`, `StoragePlan`, `Deposit`, `UserCard`, `Calibration`, `User`, `Role` |
| 4. Sơ đồ tủ | Sơ đồ tô màu theo khu hiện dữ liệu thật | `LockerMapDao`, `LockerMapApi`, `LockerMapController`, `lockerMap.jsp` |
| 5. Nhật ký chuỗi băm | Nút Verify báo chuỗi nguyên vẹn; sửa một dòng trong SSMS thì báo đúng dòng đó | `AuditVerifier`, `AuditController`, `audit.jsp`, test |
| 6. API thiết bị | `ScenarioSender` gửi nhịp tim và phiên, server nhận được | `DeviceDao`, `HealthApi`, `LockerSessionApi`, `LockerSessionDao`, `ScenarioSender` |
| 7. Luật và cảnh báo | Gửi phiên bất thường thì có cảnh báo kèm bằng chứng | `SessionContext`, `Verdict`, `RuleEngine`, `SessionContextDao`, `AlertDao`, `AlertService`, `AlertController`, `alert.jsp`, `MaintenanceDao`, `MaintenanceController` |
| 8. Năm trường hợp | Cả 5 kịch bản của `ScenarioSender` cho kết quả đúng | `sql/03_scenarios.sql`, `LockerMonitor`, `RemoteCommand*`, `UserCard*`, `MyCard*`, `Booking*` |
| 9. Học máy | Bảng so sánh 4 thuật toán, `RiskScorer` chấm điểm | `sql/02_workshop2.sql`, `ModelTrainer`, `RiskScorer`, `DataReplayer` |
| 10. Dashboard | Thẻ số liệu, biểu đồ tự cập nhật | `DashboardDao`, `DashboardApi`, `DashboardController`, `dashboard.jsp` |
| 11. Nộp bài | Đối chiếu yêu cầu của đề, xoá demo | mục 15 |

Tuần này chưa có IoT: giai đoạn 1 đến 10 đều làm được bằng `ScenarioSender`. Tuần sau thay bằng ESP32 theo mục 14.

## Nguồn để đọc

| Ký hiệu | Là gì |
|---|---|
| **DE01** | `De-01_locker.docx` trong thư mục Downloads: Workshop 1 (bước 1 đến 5), Workshop 2 (bước 1 đến 5), Assignment, Mở rộng |
| **POUR** | Repo mẫu 10 điểm: `https://github.com/TrongBVD/Pouring-System` (nhánh `master`), đọc đường dẫn `src/java/...` |
| **OLD** | Project UserManagement của bạn: `C:\Users\ADMIN\OneDrive\Desktop\PRJ301_UserManagement_FALL2026\UserManagement` |
| **FE** | Giao diện demo: thư mục `web/demo` trong project, và `SmartLocker-frontend\README.md` (hợp đồng JSON của sơ đồ tủ) |
| **G1** | Tài liệu trước `HUONG_DAN_SmartLocker.md` (cùng thư mục với OLD). Tài liệu này thay thế nó khi hai bên khác nhau: schema đã đổi (thêm tài nguyên `MAP`, bảng `LockerArea`) |

## 4. Giai đoạn 1: cơ sở dữ liệu

### 4.1 `sql/01_schema.sql`

**Đọc trước**

- DE01, Workshop 1, bước 2: 14 bảng dùng chung và 4 bảng riêng của đề (chép nguyên văn).
- DE01, Workshop 2, bước 4: thủ tục `Audit_Append`.
- POUR `SmartWaterAuditDB.sql`: cách bài 10 điểm tổ chức bảng. POUR `SmartWaterAuditdb_Procedures_Views_Bootstrap.sql`, dòng 156 là `Audit_Append`, dòng 524 là `User_Create`, dòng 708 là `Alert_Create`: xem cách mỗi thủ tục ghi nhật ký.
- OLD `sql/01_schema.sql`: cách viết file chạy lại được (xoá và tạo lại database).

**Việc của file**: tạo toàn bộ cơ sở dữ liệu `PRJ301_LOCKER` và dữ liệu mẫu. Mọi lớp Java chỉ là cách nói chuyện với các bảng này, nên đây là file nên làm trước và làm kỹ nhất: sai tên cột ở đây thì phải sửa ở nhiều nơi.

Các phần của file:

| Phần | Nội dung | Vì sao |
|---|---|---|
| A | Xoá và tạo lại database, bật `QUOTED_IDENTIFIER` | Chạy lại bao nhiêu lần cũng được. Chỉ mục có điều kiện (`WHERE ... IS NOT NULL`) đòi hai thiết lập này |
| B | 14 bảng của đề | Chép nguyên văn |
| C | 4 bảng riêng, trigger chỉ cho thêm | `LockerSession` không bao giờ sửa hay xoá được: bằng chứng không được đổi |
| D | Phần thêm của nhóm | Khu, dãy tủ, thẻ, gói, lượt gửi, lệnh từ xa, và các cột phụ (`email`, `rank_no`, `slot_id`...) |
| E | Hai view | `v_LockerSlotMap` tính màu của mỗi ngăn ở một chỗ; `v_LockerSession_Features` lọc dữ liệu huấn luyện |
| F | `Audit_Append` | Thủ tục duy nhất được ghi nhật ký, nối mã băm với dòng trước |
| G | Dữ liệu mẫu | Quyền, 16 tài khoản, 90 ngăn, thẻ, hai lượt gửi |

Điểm đáng hiểu:

- **`ALTER TABLE ... ADD` rồi dùng cột đó trong cùng batch thì lỗi `Invalid column name`.** Phải có `GO` ở giữa. Mình đã gặp đúng lỗi này khi chạy thử.
- **Hai chỉ mục duy nhất có điều kiện trên `Deposit`** (`WHERE status IN ('RESERVED','ACTIVE')`): chính cơ sở dữ liệu từ chối đặt hai lần một ngăn hoặc hai lượt mở cho một người, kể cả khi hai yêu cầu đến cùng lúc. Code Java không thể bảo đảm điều này một mình.
- **`command_id` của `LockerSession` cố ý không có khoá ngoại**: lệnh giả (số không tồn tại) vẫn phải lưu lại làm bằng chứng. Có khoá ngoại thì lệnh giả bị từ chối và mất bằng chứng.
- **Người dùng `system` phải là dòng đầu tiên của `Users`** để `user_id = 1`: Java dùng số này cho mọi việc tự động (`AuditDao.SYSTEM_USER_ID`). Hash của nó là 60 ký tự `x`, không phải BCrypt hợp lệ nên không thể đăng nhập.
- **Khoá API của thiết bị** lưu dạng SHA-256. Băm bằng `HASHBYTES('SHA2_256', 'device-1-api-key')` với chuỗi **không có `N`** (kiểu `VARCHAR`). Có `N` thì SQL Server băm theo UTF-16 và Java băm UTF-8 sẽ không khớp. Mình đã đối chiếu: SQL và Java cùng ra `73fb4e98...c849`.
- **Mọi tài khoản mẫu dùng chung một hash BCrypt** của `123456` (biến `@h`). Tài khoản tạo qua ứng dụng có muối riêng. Hash này sinh bằng `BCrypt.hashpw("123456", BCrypt.gensalt(10))`; bạn có thể sinh hash của bạn bằng vài dòng Java (`SecurityUtils.hashPassword`) rồi thay.
- **Bảng `RolePerm`** được điền bằng một câu `INSERT ... SELECT` từ danh sách `(vai trò, tài nguyên, 'R' hoặc 'RW')`. Muốn đổi quyền của một vai trò chỉ sửa một dòng.

**Mẫu**: toàn bộ file đã chạy được. Bạn tự viết từng phần theo bảng trên rồi so.

```sql
-- ============================================================
-- 01_schema.sql  Smart Locker, PRJ301 FALL2026, topic 01
-- Run the whole file in SSMS. It drops and recreates the database,
-- so run it again whenever you want a clean start.
--   Part A  database
--   Part B  the 14 shared tables of the assignment (copied from De-01, Workshop 1, step 2)
--   Part C  the 4 tables of the topic, trigger and view of the assignment
--   Part D  our additions: areas, banks, cards, plans, deposits, remote commands
--   Part E  seed data and the Audit_Append procedure
-- ============================================================

-- ===== Part A. Database =====
USE master;
GO
IF DB_ID('PRJ301_LOCKER') IS NOT NULL
BEGIN
    ALTER DATABASE PRJ301_LOCKER SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PRJ301_LOCKER;
END
GO
CREATE DATABASE PRJ301_LOCKER;
GO
USE PRJ301_LOCKER;
GO
-- filtered indexes (used below) need these two settings when rows are written
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ===== Part B. The 14 shared tables, as given in the assignment =====
CREATE TABLE Users (
    user_id       INT IDENTITY PRIMARY KEY,
    username      NVARCHAR(50) UNIQUE NOT NULL,
    password_hash CHAR(60) NOT NULL,                  -- BCrypt, always 60 characters
    full_name     NVARCHAR(80),
    status        NVARCHAR(20) DEFAULT 'ACTIVE',      -- ACTIVE, LOCKED, DISABLED
    created_at    DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE Roles (
    role_id   INT IDENTITY PRIMARY KEY,
    role_name NVARCHAR(30) UNIQUE NOT NULL);

CREATE TABLE UserRole (
    user_id INT REFERENCES Users,
    role_id INT REFERENCES Roles,
    PRIMARY KEY (user_id, role_id));

CREATE TABLE Permissions (
    perm_id  INT IDENTITY PRIMARY KEY,
    resource NVARCHAR(40),
    action   NVARCHAR(10),                            -- READ or WRITE
    UNIQUE (resource, action));

CREATE TABLE RolePerm (
    role_id INT REFERENCES Roles,
    perm_id INT REFERENCES Permissions,
    PRIMARY KEY (role_id, perm_id));

CREATE TABLE Device (
    device_id     INT IDENTITY PRIMARY KEY,
    device_code   NVARCHAR(30) UNIQUE,
    location      NVARCHAR(80),
    firmware      NVARCHAR(20),
    status        NVARCHAR(20) DEFAULT 'ACTIVE',      -- ACTIVE, MAINTENANCE, OFFLINE
    control_owner INT NULL REFERENCES Users,
    last_seen     DATETIME2 NULL,
    api_key_hash  CHAR(64) NOT NULL);                 -- SHA-256 of the key, never the key itself

CREATE TABLE SensorType (
    sensor_type_id INT IDENTITY PRIMARY KEY,
    name      NVARCHAR(40),
    unit      NVARCHAR(20),
    min_valid FLOAT,
    max_valid FLOAT);

CREATE TABLE Calibration (
    calib_id       INT IDENTITY PRIMARY KEY,
    device_id      INT REFERENCES Device,
    sensor_type_id INT REFERENCES SensorType,
    offset_val FLOAT,
    scale_val  FLOAT,
    version    INT,
    valid_until DATE,
    created_by INT REFERENCES Users);

CREATE TABLE OperatingProfile (
    profile_id  INT IDENTITY PRIMARY KEY,
    device_id   INT REFERENCES Device,
    params_json NVARCHAR(MAX),
    updated_by  INT REFERENCES Users,
    updated_at  DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE Alert (
    alert_id   INT IDENTITY PRIMARY KEY,
    device_id  INT REFERENCES Device,
    session_id BIGINT,
    source     NVARCHAR(10),                          -- RULE or ML
    label      NVARCHAR(40),
    risk_score FLOAT NULL,
    status     NVARCHAR(20) DEFAULT 'OPEN',           -- OPEN, RESOLVED
    created_at DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE AlertEvidence (
    evidence_id INT IDENTITY PRIMARY KEY,
    alert_id    INT REFERENCES Alert,
    item        NVARCHAR(60),
    value_text  NVARCHAR(200));

CREATE TABLE MaintenanceTicket (
    ticket_id   INT IDENTITY PRIMARY KEY,
    alert_id    INT NULL REFERENCES Alert,
    device_id   INT REFERENCES Device,
    assigned_to INT REFERENCES Users,
    note        NVARCHAR(400),
    status      NVARCHAR(20) DEFAULT 'OPEN',          -- OPEN, CLOSED
    opened_at   DATETIME2 DEFAULT SYSUTCDATETIME(),
    closed_at   DATETIME2 NULL);

CREATE TABLE AuditLog (
    audit_id      BIGINT IDENTITY PRIMARY KEY,
    actor_user_id INT,
    action        NVARCHAR(50),
    object_type   NVARCHAR(50),
    object_id     BIGINT,
    diff_json     NVARCHAR(MAX),
    ts            DATETIME2(7) DEFAULT SYSUTCDATETIME(),
    row_hash      CHAR(64) NULL);

CREATE TABLE HashChain (
    anchor_id  BIGINT IDENTITY PRIMARY KEY,
    audit_id   BIGINT REFERENCES AuditLog,
    prev_hash  CHAR(64),
    chain_hash CHAR(64));
GO

-- ===== Part C. The 4 tables of the topic, as given in the assignment =====
CREATE TABLE LockerSession (
    session_id     BIGINT IDENTITY PRIMARY KEY,
    device_id      INT NOT NULL REFERENCES Device,
    device_seq     INT NOT NULL,                      -- sequence number on the device, prevents duplicates
    measured_at    DATETIME2 NOT NULL,                -- time measured on the device
    ingested_at    DATETIME2 DEFAULT SYSUTCDATETIME(),-- time received by the server
    door_open_sec  FLOAT,
    weight_delta_g FLOAT,
    unlock_count   INT,
    rfid_ok        BIT,
    stay_min       FLOAT,
    UNIQUE (device_id, device_seq));

CREATE TABLE LockerSessionLabel (
    session_id BIGINT PRIMARY KEY REFERENCES LockerSession,
    label      NVARCHAR(40) NOT NULL,                 -- NORMAL, OVERDUE, FORCED_OPEN, WRONG_USER, ITEM_LEFT, SUSPECTED_SPOOF
    labeled_by INT REFERENCES Users,
    labeled_at DATETIME2 DEFAULT SYSUTCDATETIME());

CREATE TABLE LockerSessionReading (
    reading_id     BIGINT IDENTITY PRIMARY KEY,
    session_id     BIGINT REFERENCES LockerSession,
    sensor_type_id INT REFERENCES SensorType,
    measured_at    DATETIME2,
    value          FLOAT);

CREATE TABLE LockerSlot (
    locker_slot_id INT IDENTITY PRIMARY KEY,
    slot_code      NVARCHAR(20),
    bank_id        INT,
    size_cm        NVARCHAR(20),
    status         NVARCHAR(20),
    created_at     DATETIME2 DEFAULT SYSUTCDATETIME());
GO

-- sessions are append-only: block every update and delete
CREATE TRIGGER trg_LockerSession_AppendOnly ON LockerSession INSTEAD OF UPDATE, DELETE AS
BEGIN
    RAISERROR(N'Session records are append-only', 16, 1);
END;
GO

-- ===== Part D. Our additions =====

-- D1. Locker areas (Library, Dormitory ...) and banks (one cabinet of doors)
CREATE TABLE LockerArea (
    area_id   INT IDENTITY PRIMARY KEY,
    area_code NVARCHAR(16) UNIQUE NOT NULL,           -- LIB, DOMA, CANT, GYM, OPS
    name      NVARCHAR(80) NOT NULL,
    location  NVARCHAR(120) NULL,
    is_active BIT NOT NULL DEFAULT 1);

CREATE TABLE LockerBank (
    bank_id   INT IDENTITY PRIMARY KEY,
    bank_code NVARCHAR(20) UNIQUE NOT NULL,           -- LIB-A
    name      NVARCHAR(40) NOT NULL,                  -- Bank A
    area_id   INT NOT NULL REFERENCES LockerArea,
    device_id INT NULL REFERENCES Device,             -- NULL = drawn for illustration, no hardware
    door_rows INT NOT NULL DEFAULT 4,                 -- doors per column, used to draw the cabinet
    status    NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE');
CREATE UNIQUE INDEX UX_LockerBank_device ON LockerBank(device_id) WHERE device_id IS NOT NULL;

-- D2. Extra columns on the assignment's tables
ALTER TABLE Users ADD
    email   NVARCHAR(150) NULL,
    phone   NVARCHAR(20)  NULL,
    area_id INT NULL CONSTRAINT FK_Users_Area REFERENCES LockerArea(area_id);
GO
-- a column added by ALTER cannot be used in the same batch, hence the GO above
CREATE UNIQUE INDEX UX_Users_email ON Users(email) WHERE email IS NOT NULL;

ALTER TABLE Roles ADD rank_no INT NOT NULL CONSTRAINT DF_Roles_rank DEFAULT 99;   -- 1 = highest role
GO

ALTER TABLE LockerSlot ALTER COLUMN slot_code NVARCHAR(20) NOT NULL;
ALTER TABLE LockerSlot ALTER COLUMN bank_id INT NOT NULL;
ALTER TABLE LockerSlot ALTER COLUMN status NVARCHAR(20) NOT NULL;
ALTER TABLE LockerSlot ADD size_code CHAR(1) NOT NULL CONSTRAINT DF_LockerSlot_size DEFAULT 'S';   -- S, M, L
GO
ALTER TABLE LockerSlot ADD CONSTRAINT DF_LockerSlot_status DEFAULT 'AVAILABLE' FOR status;
ALTER TABLE LockerSlot ADD CONSTRAINT FK_LockerSlot_Bank FOREIGN KEY (bank_id) REFERENCES LockerBank(bank_id);
ALTER TABLE LockerSlot ADD CONSTRAINT UQ_LockerSlot_code UNIQUE (bank_id, slot_code);
ALTER TABLE LockerSlot ADD CONSTRAINT CK_LockerSlot_status
    CHECK (status IN ('AVAILABLE', 'RESERVED', 'OCCUPIED', 'MAINTENANCE'));

-- the device tells us which slot, which card and how the door was opened
ALTER TABLE LockerSession ADD
    slot_id     INT NULL CONSTRAINT FK_LockerSession_Slot REFERENCES LockerSlot(locker_slot_id),
    card_uid    NVARCHAR(32) NULL,
    open_source NVARCHAR(10) NULL,                    -- RFID or REMOTE
    command_id  BIGINT NULL;                          -- no foreign key on purpose: a forged id must still be stored as evidence
GO

-- D3. Cards, plans, deposits, remote commands
CREATE TABLE UserCard (
    card_id   INT IDENTITY PRIMARY KEY,
    card_uid  NVARCHAR(32) UNIQUE NOT NULL,           -- RC522 uid in hex
    user_id   INT NOT NULL REFERENCES Users,
    status    NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, LOST, BLOCKED
    issued_at DATETIME2 DEFAULT SYSUTCDATETIME(),
    lost_at   DATETIME2 NULL);

CREATE TABLE StoragePlan (
    plan_id      INT IDENTITY PRIMARY KEY,
    plan_name    NVARCHAR(40) NOT NULL,
    duration_min INT NOT NULL,
    grace_min    INT NOT NULL DEFAULT 10,
    price        INT NOT NULL DEFAULT 0,
    is_active    BIT NOT NULL DEFAULT 1);

CREATE TABLE Deposit (
    deposit_id   BIGINT IDENTITY PRIMARY KEY,
    user_id      INT NOT NULL REFERENCES Users,
    slot_id      INT NOT NULL REFERENCES LockerSlot(locker_slot_id),
    plan_id      INT NOT NULL REFERENCES StoragePlan,
    card_id      INT NULL REFERENCES UserCard,
    status       NVARCHAR(20) NOT NULL
                 CHECK (status IN ('RESERVED', 'ACTIVE', 'COMPLETED', 'NO_SHOW', 'CANCELLED')),
    reserved_at  DATETIME2 DEFAULT SYSUTCDATETIME(),
    hold_until   DATETIME2 NULL,                      -- a reservation expires here
    started_at   DATETIME2 NULL,
    due_at       DATETIME2 NULL,                      -- online extension moves this forward
    ended_at     DATETIME2 NULL,
    extend_count INT NOT NULL DEFAULT 0);
-- the database itself refuses a second open booking for one slot or one user
CREATE UNIQUE INDEX UX_Deposit_slot_open ON Deposit(slot_id) WHERE status IN ('RESERVED', 'ACTIVE');
CREATE UNIQUE INDEX UX_Deposit_user_open ON Deposit(user_id) WHERE status IN ('RESERVED', 'ACTIVE');

CREATE TABLE RemoteCommand (
    command_id   BIGINT IDENTITY PRIMARY KEY,
    device_id    INT NOT NULL REFERENCES Device,
    slot_id      INT NOT NULL REFERENCES LockerSlot(locker_slot_id),
    action       NVARCHAR(20) NOT NULL DEFAULT 'UNLOCK',
    reason       NVARCHAR(200) NOT NULL,
    requested_by INT NOT NULL REFERENCES Users,
    status       NVARCHAR(20) NOT NULL DEFAULT 'PENDING',   -- PENDING, SENT, DONE, EXPIRED
    created_at   DATETIME2 DEFAULT SYSUTCDATETIME(),
    expires_at   DATETIME2 NOT NULL,
    done_at      DATETIME2 NULL,
    session_id   BIGINT NULL);                              -- the session that used the command
GO

-- ===== Part E. Views =====

-- features for the machine learning step; sessions that are not user behaviour are left out
CREATE VIEW v_LockerSession_Features AS
SELECT s.session_id, s.device_id, s.door_open_sec, s.weight_delta_g, s.unlock_count, s.rfid_ok, s.stay_min, l.label
FROM LockerSession s
JOIN LockerSessionLabel l ON l.session_id = s.session_id
WHERE ISNULL(s.open_source, N'RFID') <> N'REMOTE'        -- a staff remote open is not a user
  AND NOT EXISTS (SELECT 1 FROM Alert a                  -- a broken sensor says nothing about the user
                  WHERE a.session_id = s.session_id AND a.label = N'SENSOR_FAULT');
GO

-- the colour of every door on the map, computed in one place
CREATE VIEW v_LockerSlotMap AS
SELECT s.locker_slot_id AS slot_id, s.slot_code, s.size_code, s.size_cm,
       b.bank_id, b.bank_code, b.area_id,
       v.device_id, v.status AS device_status,
       CASE
           WHEN v.status = N'OFFLINE'     THEN N'OFFLINE'
           WHEN s.status = N'MAINTENANCE' THEN N'MAINTENANCE'
           WHEN EXISTS (SELECT 1 FROM LockerSession ls JOIN Alert a ON a.session_id = ls.session_id
                        WHERE ls.slot_id = s.locker_slot_id AND a.status = N'OPEN') THEN N'ALERT'
           WHEN EXISTS (SELECT 1 FROM Deposit d
                        WHERE d.slot_id = s.locker_slot_id AND d.status = N'ACTIVE'
                          AND d.due_at < SYSUTCDATETIME()) THEN N'OVERDUE'
           ELSE s.status
       END AS display_status
FROM LockerSlot s
JOIN LockerBank b ON b.bank_id = s.bank_id
LEFT JOIN Device v ON v.device_id = b.device_id;
GO

-- ===== Part F. Audit_Append: one row of the log, chained to the row before it =====
CREATE OR ALTER PROCEDURE Audit_Append
    @actor INT, @action NVARCHAR(50), @objectType NVARCHAR(50), @objectId BIGINT, @diff NVARCHAR(MAX)
AS
BEGIN
    SET XACT_ABORT ON;
    BEGIN TRAN;
    DECLARE @id BIGINT, @ts DATETIME2(7), @prev CHAR(64), @row NVARCHAR(MAX), @hash CHAR(64);

    INSERT INTO AuditLog (actor_user_id, action, object_type, object_id, diff_json)
    VALUES (@actor, @action, @objectType, @objectId, @diff);
    SET @id = SCOPE_IDENTITY();
    SELECT @ts = ts FROM AuditLog WHERE audit_id = @id;

    -- lock the chain tail so two writers cannot fork the chain
    SELECT TOP 1 @prev = chain_hash FROM HashChain WITH (UPDLOCK, HOLDLOCK) ORDER BY anchor_id DESC;
    SET @prev = ISNULL(@prev, REPLICATE('0', 64));

    SET @row = CONCAT(@id, '|', CONVERT(NVARCHAR(33), @ts, 126), '|', @actor, '|', @action, '|',
                      @objectType, '|', @objectId, '|', ISNULL(@diff, ''), '|', @prev);
    SET @hash = LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', @row), 2));

    UPDATE AuditLog SET row_hash = @hash WHERE audit_id = @id;
    INSERT INTO HashChain (audit_id, prev_hash, chain_hash) VALUES (@id, @prev, @hash);
    COMMIT;
END;
GO

-- ===== Part G. Seed data =====

-- G1. Roles and permissions. Every resource gets a READ and a WRITE permission.
INSERT INTO Roles (role_name, rank_no) VALUES
    (N'ADMIN', 1), (N'OPERATOR', 2), (N'TECHNICIAN', 3), (N'AUDITOR', 4), (N'END_USER', 5);

INSERT INTO Permissions (resource, action)
SELECT r.res, a.act
FROM (VALUES (N'USER'), (N'ROLE'), (N'DEVICE'), (N'SENSOR_TYPE'), (N'CALIBRATION'), (N'PROFILE'),
             (N'LOCKERSESSION'), (N'LOCKERSLOT'), (N'ALERT'), (N'MAINTENANCE'), (N'AUDIT'),
             (N'MAP'), (N'AREA'), (N'LOCKERBANK'), (N'STORAGEPLAN'), (N'USERCARD'), (N'MYCARD'),
             (N'DEPOSIT'), (N'BOOKING'), (N'COMMAND')) r(res)
CROSS JOIN (VALUES (N'READ'), (N'WRITE')) a(act);

-- who may do what. R = READ only, RW = READ and WRITE, * = every resource.
-- Replace this table with the one in the assignment's "Quy dinh chung" file if it differs.
INSERT INTO RolePerm (role_id, perm_id)
SELECT r.role_id, p.perm_id
FROM (VALUES
    (N'ADMIN',      N'*',             N'RW'),
    (N'OPERATOR',   N'USER',          N'RW'), (N'OPERATOR', N'ROLE',        N'R'),
    (N'OPERATOR',   N'DEVICE',        N'R'),  (N'OPERATOR', N'SENSOR_TYPE', N'R'),
    (N'OPERATOR',   N'CALIBRATION',   N'R'),  (N'OPERATOR', N'PROFILE',     N'R'),
    (N'OPERATOR',   N'LOCKERSESSION', N'R'),  (N'OPERATOR', N'LOCKERSLOT',  N'RW'),
    (N'OPERATOR',   N'ALERT',         N'RW'), (N'OPERATOR', N'MAINTENANCE', N'R'),
    (N'OPERATOR',   N'AUDIT',         N'R'),  (N'OPERATOR', N'MAP',         N'R'),
    (N'OPERATOR',   N'AREA',          N'RW'), (N'OPERATOR', N'LOCKERBANK',  N'RW'),
    (N'OPERATOR',   N'STORAGEPLAN',   N'RW'), (N'OPERATOR', N'USERCARD',    N'RW'),
    (N'OPERATOR',   N'DEPOSIT',       N'RW'), (N'OPERATOR', N'COMMAND',     N'RW'),
    (N'TECHNICIAN', N'USER',          N'R'),  (N'TECHNICIAN', N'DEVICE',    N'RW'),
    (N'TECHNICIAN', N'SENSOR_TYPE',   N'RW'), (N'TECHNICIAN', N'CALIBRATION', N'RW'),
    (N'TECHNICIAN', N'PROFILE',       N'R'),  (N'TECHNICIAN', N'LOCKERSESSION', N'R'),
    (N'TECHNICIAN', N'LOCKERSLOT',    N'R'),  (N'TECHNICIAN', N'ALERT',     N'RW'),
    (N'TECHNICIAN', N'MAINTENANCE',   N'RW'), (N'TECHNICIAN', N'MAP',       N'R'),
    (N'TECHNICIAN', N'AREA',          N'R'),  (N'TECHNICIAN', N'LOCKERBANK', N'R'),
    (N'TECHNICIAN', N'DEPOSIT',       N'R'),
    (N'AUDITOR',    N'*',             N'R'),
    (N'END_USER',   N'MAP',           N'R'),  (N'END_USER', N'BOOKING',     N'RW'),
    (N'END_USER',   N'MYCARD',        N'RW')
) g(role_name, resource, mode)
JOIN Roles r ON r.role_name = g.role_name
JOIN Permissions p ON (g.resource = N'*' OR p.resource = g.resource)
                  AND (p.action = N'READ' OR g.mode = N'RW');
GO

-- G2. Areas, device, banks and slots
INSERT INTO LockerArea (area_code, name, location) VALUES
    (N'LIB',  N'Library',     N'Library, 1st floor'),
    (N'DOMA', N'Dormitory A', N'Dorm A lobby'),
    (N'CANT', N'Canteen',     N'Next to the canteen entrance'),
    (N'GYM',  N'Sports Hall', N'Sports hall changing room'),
    (N'OPS',  N'Operations',  N'Staff office, no locker slots');

-- the one real device. Its key is device-1-api-key, only the SHA-256 is stored.
-- the key is hashed as VARCHAR (no N prefix) so SQL Server and Java hash the same bytes
INSERT INTO Device (device_code, location, firmware, api_key_hash)
VALUES (N'LOCKER-01', N'Library, 1st floor', N'1.0',
        LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', 'device-1-api-key'), 2)));

INSERT INTO LockerBank (bank_code, name, area_id, device_id, door_rows)
SELECT v.code, v.name, a.area_id, v.device_id, v.door_rows
FROM (VALUES (N'LIB-A',  N'Bank A', N'LIB',  1,    2), (N'LIB-B',  N'Bank B', N'LIB',  NULL, 4),
             (N'DOMA-A', N'Bank A', N'DOMA', NULL, 4), (N'DOMA-B', N'Bank B', N'DOMA', NULL, 4),
             (N'CANT-A', N'Bank A', N'CANT', NULL, 4),
             (N'GYM-A',  N'Bank A', N'GYM',  NULL, 4), (N'GYM-B',  N'Bank B', N'GYM',  NULL, 4)
     ) v(code, name, area_code, device_id, door_rows)
JOIN LockerArea a ON a.area_code = v.area_code;

-- 90 doors: the slot code is the bank letter and a number, A01, A02 ...
WITH n AS (SELECT TOP (20) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO LockerSlot (slot_code, bank_id, size_cm, size_code, status)
SELECT RIGHT(b.bank_code, 1) + RIGHT('0' + CAST(n.i AS VARCHAR(2)), 2), b.bank_id, N'30x30x45', 'S', N'AVAILABLE'
FROM LockerBank b
JOIN (VALUES (N'LIB-A', 4), (N'LIB-B', 16), (N'DOMA-A', 20), (N'DOMA-B', 10),
             (N'CANT-A', 15), (N'GYM-A', 16), (N'GYM-B', 9)) c(code, cnt) ON c.code = b.bank_code
JOIN n ON n.i <= c.cnt;

-- a few tall doors
UPDATE s SET size_code = 'L', size_cm = N'40x40x90'
FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE (b.bank_code = N'DOMA-B' AND s.slot_code IN ('B03', 'B06', 'B07', 'B08', 'B09', 'B10'))
   OR (b.bank_code = N'CANT-A' AND s.slot_code IN ('A03', 'A06', 'A09', 'A12', 'A15'))
   OR (b.bank_code = N'GYM-B'  AND s.slot_code IN ('B03', 'B06', 'B09'));
GO

-- G3. Users. 'system' goes first so its user_id is 1: Java uses that id for automatic actions.
-- Every sample account shares one BCrypt hash of the password 123456. Accounts created
-- through the application get their own salt, as they should.
INSERT INTO Users (username, password_hash, full_name, status)
VALUES (N'system', REPLICATE('x', 60), N'System account', N'DISABLED');   -- cannot log in

DECLARE @h CHAR(60) = '$2a$10$iz5TJTP.i9YQlKBSU4GzKO.rbQIU.PocHFDv24b8Xsfm8hC2Rwp3m';
INSERT INTO Users (username, password_hash, full_name, email, phone, area_id, status)
SELECT v.username, @h, v.full_name, v.username + N'@smartlocker.edu.vn', v.phone, a.area_id, v.status
FROM (VALUES
    (N'admin',     N'Administrator',     NULL,         N'OPS',  N'ACTIVE'),
    (N'operator1', N'Tran Thi Hoa',      N'0901000002', N'OPS',  N'ACTIVE'),
    (N'operator2', N'Le Van Minh',       N'0901000003', N'OPS',  N'ACTIVE'),
    (N'tech1',     N'Pham Quoc Bao',     NULL,         N'OPS',  N'ACTIVE'),
    (N'tech2',     N'Vo Thi Lan',        N'0901000005', N'OPS',  N'ACTIVE'),
    (N'auditor1',  N'Nguyen Thanh Tung', NULL,         N'OPS',  N'ACTIVE'),
    (N'auditor2',  N'Do Thi Mai',        N'0901000007', N'OPS',  N'ACTIVE'),
    (N'student1',  N'Nguyen Van An',     N'0901000008', N'LIB',  N'ACTIVE'),
    (N'student2',  N'Tran Minh Chau',    NULL,         N'DOMA', N'ACTIVE'),
    (N'student3',  N'Le Hoang Nam',      N'0901000010', N'CANT', N'ACTIVE'),
    (N'student4',  N'Pham Thu Ha',       N'0901000011', N'GYM',  N'ACTIVE'),
    (N'student5',  N'Dang Quoc Huy',     NULL,         N'LIB',  N'ACTIVE'),
    (N'student6',  N'Ngo Bao Tram',      N'0901000013', N'DOMA', N'ACTIVE'),
    (N'student7',  N'Huynh Gia Bao',     N'0901000014', N'LIB',  N'ACTIVE'),
    (N'student8',  N'Vu Ngoc Anh',       NULL,         N'GYM',  N'ACTIVE'),
    (N'locked1',   N'Bui Van Khoa',      N'0901000016', N'DOMA', N'LOCKED')
) v(username, full_name, phone, area_code, status)
JOIN LockerArea a ON a.area_code = v.area_code;

INSERT INTO UserRole (user_id, role_id)
SELECT u.user_id, r.role_id
FROM Users u
JOIN Roles r ON r.role_name =
     CASE WHEN u.username = N'admin'                  THEN N'ADMIN'
          WHEN u.username LIKE N'operator%'           THEN N'OPERATOR'
          WHEN u.username LIKE N'tech%'               THEN N'TECHNICIAN'
          WHEN u.username LIKE N'auditor%'            THEN N'AUDITOR'
          WHEN u.username LIKE N'student%' OR u.username = N'locked1' THEN N'END_USER' END
WHERE u.username <> N'system';
GO

-- G4. Plans, sensors, calibration, cards, two deposits
INSERT INTO StoragePlan (plan_name, duration_min, grace_min, price) VALUES
    (N'2 hours', 120, 10, 5000),
    (N'4 hours', 240, 10, 9000),
    (N'Demo 2 minutes', 2, 1, 0);        -- makes OVERDUE appear quickly in the video

INSERT INTO SensorType (name, unit, min_valid, max_valid) VALUES
    (N'DOOR', N's', 0, 3600), (N'WEIGHT', N'g', -200, 20000), (N'STAY', N'min', 0, 10080);

-- without this row every session becomes SENSOR_FAULT
INSERT INTO Calibration (device_id, sensor_type_id, offset_val, scale_val, version, valid_until, created_by)
SELECT 1, sensor_type_id, 0, 1, 1, DATEADD(MONTH, 3, CAST(SYSUTCDATETIME() AS DATE)),
       (SELECT user_id FROM Users WHERE username = N'admin')
FROM SensorType WHERE name = N'WEIGHT';

INSERT INTO UserCard (card_uid, user_id)
SELECT v.uid, u.user_id
FROM (VALUES (N'04A1B2C3', N'student1'), (N'0499AABB', N'student2'), (N'04C3D4E5', N'student3'),
             (N'04F5A6B7', N'student4'), (N'04112233', N'student7')) v(uid, username)
JOIN Users u ON u.username = v.username;

-- student1 is using LIB-A A02, student7 has reserved LIB-A A03
INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, started_at, due_at)
SELECT u.user_id, s.locker_slot_id, 1, c.card_id, N'ACTIVE',
       DATEADD(MINUTE, -78, SYSUTCDATETIME()), DATEADD(MINUTE, 42, SYSUTCDATETIME())
FROM Users u JOIN UserCard c ON c.user_id = u.user_id
JOIN LockerBank b ON b.bank_code = N'LIB-A' JOIN LockerSlot s ON s.bank_id = b.bank_id AND s.slot_code = 'A02'
WHERE u.username = N'student1';

INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, hold_until)
SELECT u.user_id, s.locker_slot_id, 1, c.card_id, N'RESERVED', DATEADD(MINUTE, 9, SYSUTCDATETIME())
FROM Users u JOIN UserCard c ON c.user_id = u.user_id
JOIN LockerBank b ON b.bank_code = N'LIB-A' JOIN LockerSlot s ON s.bank_id = b.bank_id AND s.slot_code = 'A03'
WHERE u.username = N'student7';

UPDATE s SET status = N'OCCUPIED' FROM LockerSlot s JOIN Deposit d ON d.slot_id = s.locker_slot_id WHERE d.status = N'ACTIVE';
UPDATE s SET status = N'RESERVED' FROM LockerSlot s JOIN Deposit d ON d.slot_id = s.locker_slot_id WHERE d.status = N'RESERVED';
UPDATE s SET status = N'MAINTENANCE' FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id
WHERE b.bank_code = N'LIB-B' AND s.slot_code IN ('B09', 'B11', 'B15');
GO

-- first row of the audit chain
EXEC Audit_Append 1, N'SEED', N'DATABASE', 0, N'Initial data loaded';
GO
```

**Khung bạn làm**: file `sql/01_schema.sql` trong project có các mục `TODO A1` đến `TODO G6`. Làm từng phần, chạy lại từ đầu sau mỗi phần.

**Tự kiểm tra** (chạy trong SSMS, kết quả đã đối chiếu):

```sql
SELECT (SELECT COUNT(*) FROM Users)       AS users,        -- 17 (16 tài khoản + system)
       (SELECT COUNT(*) FROM Roles)       AS roles,        -- 5
       (SELECT COUNT(*) FROM Permissions) AS permissions,  -- 40 (20 tài nguyên x READ/WRITE)
       (SELECT COUNT(*) FROM RolePerm)    AS role_perm,    -- 110
       (SELECT COUNT(*) FROM LockerSlot)  AS slots,        -- 90
       (SELECT COUNT(*) FROM AuditLog)    AS audit_rows;   -- 1

-- những gì Java sẽ hỏi
SELECT p.resource + ':' + p.action FROM UserRole ur JOIN RolePerm rp ON rp.role_id = ur.role_id
JOIN Permissions p ON p.perm_id = rp.perm_id WHERE ur.user_id = (SELECT user_id FROM Users WHERE username = 'student1');
-- 5 dòng: BOOKING:READ, BOOKING:WRITE, MAP:READ, MYCARD:READ, MYCARD:WRITE

SELECT display_status, COUNT(*) FROM v_LockerSlotMap GROUP BY display_status;
-- AVAILABLE 85, MAINTENANCE 3, OCCUPIED 1, RESERVED 1
```

**Dễ sai**

- Mở file `.sql` trong SSMS rồi chạy bằng `sqlcmd` mà không có `-I`: chỉ mục có điều kiện báo lỗi khi chèn. Trong file đã có `SET QUOTED_IDENTIFIER ON`.
- Dán DDL từ Word: dấu nháy cong `'` thay cho `'` làm SQL báo lỗi cú pháp. Gõ lại dấu nháy.
- Quên seed dòng `Calibration` cho cảm biến `WEIGHT`: mọi phiên về sau bị đánh `SENSOR_FAULT` (mục 10).
- Chạy lại script khi đang mở kết nối từ Tomcat: phần A đã có `SINGLE_USER WITH ROLLBACK IMMEDIATE` để ngắt chúng.

### 4.2 `sql/03_scenarios.sql` (làm ở giai đoạn 8, đọc trước bây giờ)

**Đọc trước**: POUR `SmartWaterAuditdb_Procedures_Views_Bootstrap.sql` dòng 1614 (`Device_Create`) và 1696 (`Device_UpdateStatus_User`), để thấy mỗi thủ tục kiểm tra quyền, đổi dữ liệu rồi gọi `Audit_Append` thế nào.

**Việc của file**: 16 stored procedure của 5 trường hợp. Cộng `Audit_Append` thành 17 thủ tục, vượt yêu cầu tối thiểu 10 của đề.

| Trường hợp | Thủ tục | Mã lỗi (`THROW`) |
|---|---|---|
| 1 Tủ mất mạng | `Device_Heartbeat`, `Device_MarkOffline` | |
| 2 Mở từ xa | `RemoteCommand_Create`, `_TakePending`, `_Expire` | 50010 không có thiết bị, 50011 thiết bị không online, 50012 người khác đang điều khiển, 50013 lý do ngắn hơn 5 ký tự |
| 3 Mất thẻ | `UserCard_ReportLost`, `UserCard_Replace` | 50020 thẻ không phải của bạn hoặc đã báo, 50021 chỉ thẻ đã mất mới thay được |
| 4 Đặt chỗ | `Deposit_Reserve`, `_Cancel`, `_Extend`, `_CheckIn`, `_Complete`, `_ExpireNoShow` | 50030 chưa có thẻ, 50031 ba lần không đến, 50032 đã có lượt, 50033 ngăn đã bị lấy, 50034 gói không dùng được, 50035 tủ offline, 50036 không có gì để huỷ, 50037 số phút không hợp lệ, 50038 không phải lượt của bạn, 50039 đã gia hạn 3 lần |
| 5 Cảm biến hỏng | `Ticket_OpenForFault`, `Ticket_Close`, `Alert_Resolve` | 50040 phiếu không có hoặc đã đóng, 50041 cảnh báo không có hoặc đã xử lý |

Mấy ý đáng học:

- **Khoá bằng điều kiện `WHERE`**: `UPDATE LockerSlot SET status = 'RESERVED' WHERE locker_slot_id = @id AND status = 'AVAILABLE'` rồi kiểm tra `@@ROWCOUNT`. Hai người bấm cùng lúc, chỉ một cập nhật được dòng. Không cần khoá thủ công.
- **`UPDATE ... OUTPUT`** của `RemoteCommand_TakePending`: lấy lệnh và đánh dấu `SENT` trong một câu. Hai nhịp tim không thể nhận cùng một lệnh. Vì thế bảng này không được gắn trigger.
- **`Deposit_ExpireNoShow` bỏ qua thiết bị OFFLINE**: tủ không báo lên được thì chưa thể kết luận người dùng không đến.
- **Chọn kỹ thuật viên ít việc nhất** bằng `ORDER BY (SELECT COUNT(*) ...)` trong `Ticket_OpenForFault`.

**Mẫu**: file đầy đủ. Kèm theo là bộ kiểm tra `docs/demo-code/sql/test_scenarios.sql` gồm 45 khẳng định PASS/FAIL, đã chạy hết xanh.

```sql
-- ============================================================
-- 03_scenarios.sql  Stored procedures of the 5 real-life cases.
-- Run after 01_schema.sql. Safe to run again (CREATE OR ALTER).
--   Case 1  locker goes offline     Device_Heartbeat, Device_MarkOffline
--   Case 2  remote unlock          RemoteCommand_Create, _TakePending, _Expire
--   Case 3  lost card              UserCard_ReportLost, UserCard_Replace
--   Case 4  booking, no show       Deposit_Reserve, _Cancel, _Extend, _CheckIn, _Complete, _ExpireNoShow
--   Case 5  broken sensor          Ticket_OpenForFault, Ticket_Close, Alert_Resolve
-- Every procedure writes Audit_Append, automatic work is done by the 'system' user.
-- ============================================================
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ===== Case 1. A locker loses its network =====

-- the device calls this every 10 seconds; coming back from OFFLINE closes the alert
CREATE OR ALTER PROCEDURE Device_Heartbeat @device_id INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @was NVARCHAR(20) = (SELECT status FROM Device WHERE device_id = @device_id);
    BEGIN TRAN;
    UPDATE Device
    SET last_seen = SYSUTCDATETIME(),
        status = CASE WHEN status = N'OFFLINE' THEN N'ACTIVE' ELSE status END   -- MAINTENANCE stays
    WHERE device_id = @device_id;
    IF @was = N'OFFLINE'
    BEGIN
        UPDATE Alert SET status = N'RESOLVED'
        WHERE device_id = @device_id AND label = N'DEVICE_OFFLINE' AND status = N'OPEN';
        EXEC Audit_Append @sys, N'BACK_ONLINE', N'DEVICE', @device_id, NULL;
    END
    COMMIT;
END;
GO

-- LockerMonitor calls this every 30 seconds
CREATE OR ALTER PROCEDURE Device_MarkOffline @timeout_sec INT = 60
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @gone TABLE (device_id INT);
    DECLARE @id INT, @alert INT;
    BEGIN TRAN;
    UPDATE Device SET status = N'OFFLINE'
    OUTPUT inserted.device_id INTO @gone
    WHERE status = N'ACTIVE'
      AND (last_seen IS NULL OR last_seen < DATEADD(SECOND, -@timeout_sec, SYSUTCDATETIME()));
    WHILE EXISTS (SELECT 1 FROM @gone)
    BEGIN
        SELECT TOP 1 @id = device_id FROM @gone;
        INSERT INTO Alert (device_id, session_id, source, label) VALUES (@id, NULL, N'RULE', N'DEVICE_OFFLINE');
        SET @alert = SCOPE_IDENTITY();
        INSERT INTO AlertEvidence (alert_id, item, value_text)
        SELECT @alert, N'last_seen_utc', ISNULL(CONVERT(NVARCHAR(30), last_seen, 120), N'never')
        FROM Device WHERE device_id = @id;
        EXEC Audit_Append @sys, N'MARK_OFFLINE', N'DEVICE', @id, NULL;
        DELETE FROM @gone WHERE device_id = @id;
    END
    COMMIT;
END;
GO

-- ===== Case 2. Staff opens a slot from the web =====

CREATE OR ALTER PROCEDURE RemoteCommand_Create
    @slot_id INT, @reason NVARCHAR(200), @actor INT, @new_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @device_id INT, @device_status NVARCHAR(20), @owner INT;
    SELECT @device_id = v.device_id, @device_status = v.status, @owner = v.control_owner
    FROM LockerSlot s
    JOIN LockerBank b ON b.bank_id = s.bank_id
    JOIN Device v ON v.device_id = b.device_id
    WHERE s.locker_slot_id = @slot_id;

    IF @device_id IS NULL THROW 50010, N'This slot has no device', 1;
    IF @device_status <> N'ACTIVE' THROW 50011, N'Device is not online, the command cannot be delivered', 1;
    IF @owner IS NOT NULL AND @owner <> @actor THROW 50012, N'Another operator is controlling this device', 1;
    IF LEN(LTRIM(RTRIM(ISNULL(@reason, N'')))) < 5 THROW 50013, N'A reason of at least 5 characters is required', 1;

    BEGIN TRAN;
    INSERT INTO RemoteCommand (device_id, slot_id, action, reason, requested_by, expires_at)
    VALUES (@device_id, @slot_id, N'UNLOCK', LTRIM(RTRIM(@reason)), @actor, DATEADD(MINUTE, 2, SYSUTCDATETIME()));
    SET @new_id = SCOPE_IDENTITY();
    EXEC Audit_Append @actor, N'REMOTE_UNLOCK', N'LOCKERSLOT', @slot_id, @reason;
    COMMIT;
END;
GO

-- the heartbeat hands over pending commands and marks them SENT in one atomic statement
CREATE OR ALTER PROCEDURE RemoteCommand_TakePending @device_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE c SET c.status = N'SENT'
    OUTPUT inserted.command_id, s.slot_code, inserted.action
    FROM RemoteCommand c
    JOIN LockerSlot s ON s.locker_slot_id = c.slot_id
    WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.expires_at > SYSUTCDATETIME();
END;
GO

-- only PENDING ones: a SENT command is already on the device and waits for its session
CREATE OR ALTER PROCEDURE RemoteCommand_Expire
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE RemoteCommand SET status = N'EXPIRED'
    WHERE status = N'PENDING' AND expires_at < SYSUTCDATETIME();
END;
GO

-- ===== Case 3. A card is lost =====

CREATE OR ALTER PROCEDURE UserCard_ReportLost @card_id INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRAN;
    UPDATE UserCard SET status = N'LOST', lost_at = SYSUTCDATETIME()
    WHERE card_id = @card_id AND user_id = @actor AND status = N'ACTIVE';   -- only the owner, only once
    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK;
        THROW 50020, N'Card not found, not yours, or already reported', 1;
    END
    EXEC Audit_Append @actor, N'REPORT_LOST', N'USERCARD', @card_id, NULL;
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE UserCard_Replace
    @old_card_id INT, @new_uid NVARCHAR(32), @actor INT, @new_card_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @owner INT = (SELECT user_id FROM UserCard WHERE card_id = @old_card_id AND status <> N'ACTIVE');
    IF @owner IS NULL THROW 50021, N'Only a lost or blocked card can be replaced', 1;
    BEGIN TRAN;
    INSERT INTO UserCard (card_uid, user_id) VALUES (@new_uid, @owner);
    SET @new_card_id = SCOPE_IDENTITY();
    -- the running booking follows its owner to the new card
    UPDATE Deposit SET card_id = @new_card_id WHERE card_id = @old_card_id AND status IN (N'RESERVED', N'ACTIVE');
    EXEC Audit_Append @actor, N'REPLACE_CARD', N'USERCARD', @new_card_id, NULL;
    COMMIT;
END;
GO

-- ===== Case 4. Booking a slot, and not coming =====

CREATE OR ALTER PROCEDURE Deposit_Reserve
    @user_id INT, @slot_id INT, @plan_id INT, @new_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @card_id INT = (SELECT TOP 1 card_id FROM UserCard WHERE user_id = @user_id AND status = N'ACTIVE');
    IF @card_id IS NULL THROW 50030, N'You need an active card to reserve', 1;
    IF (SELECT COUNT(*) FROM Deposit WHERE user_id = @user_id AND status = N'NO_SHOW'
        AND reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME())) >= 3
        THROW 50031, N'Booking is blocked: 3 no-shows in the last 7 days', 1;
    IF EXISTS (SELECT 1 FROM Deposit WHERE user_id = @user_id AND status IN (N'RESERVED', N'ACTIVE'))
        THROW 50032, N'You already have a booking in progress', 1;
    IF NOT EXISTS (SELECT 1 FROM StoragePlan WHERE plan_id = @plan_id AND is_active = 1)
        THROW 50034, N'This storage plan is not available', 1;
    IF EXISTS (SELECT 1 FROM v_LockerSlotMap WHERE slot_id = @slot_id AND device_status = N'OFFLINE')
        THROW 50035, N'The locker is offline, booking is paused', 1;

    BEGIN TRAN;
    -- the WHERE clause is the lock: when two users click the same slot, only one row is updated
    UPDATE LockerSlot SET status = N'RESERVED' WHERE locker_slot_id = @slot_id AND status = N'AVAILABLE';
    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK;
        THROW 50033, N'This slot is no longer available', 1;
    END
    INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, hold_until)
    VALUES (@user_id, @slot_id, @plan_id, @card_id, N'RESERVED', DATEADD(MINUTE, 15, SYSUTCDATETIME()));
    SET @new_id = SCOPE_IDENTITY();
    EXEC Audit_Append @user_id, N'RESERVE', N'DEPOSIT', @new_id, NULL;
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE Deposit_Cancel @deposit_id BIGINT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @slot INT = (SELECT slot_id FROM Deposit WHERE deposit_id = @deposit_id AND user_id = @actor AND status = N'RESERVED');
    IF @slot IS NULL THROW 50036, N'Nothing to cancel: not your reservation, or it already started', 1;
    BEGIN TRAN;
    UPDATE Deposit SET status = N'CANCELLED', ended_at = SYSUTCDATETIME() WHERE deposit_id = @deposit_id;
    UPDATE LockerSlot SET status = N'AVAILABLE' WHERE locker_slot_id = @slot;
    EXEC Audit_Append @actor, N'CANCEL', N'DEPOSIT', @deposit_id, NULL;
    COMMIT;
END;
GO

-- online extension: add time to the due moment, at most 3 times
CREATE OR ALTER PROCEDURE Deposit_Extend @deposit_id BIGINT, @minutes INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @minutes NOT BETWEEN 15 AND 240 THROW 50037, N'You can add between 15 and 240 minutes', 1;
    DECLARE @count INT = (SELECT extend_count FROM Deposit WHERE deposit_id = @deposit_id AND user_id = @actor AND status = N'ACTIVE');
    IF @count IS NULL THROW 50038, N'Nothing to extend: not your active booking', 1;
    IF @count >= 3 THROW 50039, N'A booking can be extended 3 times at most', 1;
    BEGIN TRAN;
    UPDATE Deposit
    SET due_at = DATEADD(MINUTE, @minutes, CASE WHEN due_at > SYSUTCDATETIME() THEN due_at ELSE SYSUTCDATETIME() END),
        extend_count = extend_count + 1
    WHERE deposit_id = @deposit_id;
    EXEC Audit_Append @actor, N'EXTEND', N'DEPOSIT', @deposit_id, @minutes;
    COMMIT;
END;
GO

-- the heartbeat says a reserved slot now holds something: start the clock
CREATE OR ALTER PROCEDURE Deposit_CheckIn @device_id INT, @slot_code NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id BIGINT, @slot_id INT, @minutes INT;
    SELECT TOP 1 @id = d.deposit_id, @slot_id = d.slot_id, @minutes = p.duration_min
    FROM Deposit d
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    JOIN StoragePlan p ON p.plan_id = d.plan_id
    WHERE d.status = N'RESERVED' AND s.slot_code = @slot_code AND b.device_id = @device_id;
    IF @id IS NULL RETURN;                            -- nothing reserved here
    BEGIN TRAN;
    UPDATE Deposit
    SET status = N'ACTIVE', started_at = SYSUTCDATETIME(), due_at = DATEADD(MINUTE, @minutes, SYSUTCDATETIME())
    WHERE deposit_id = @id;
    UPDATE LockerSlot SET status = N'OCCUPIED' WHERE locker_slot_id = @slot_id;
    EXEC Audit_Append @sys, N'CHECK_IN', N'DEPOSIT', @id, NULL;
    COMMIT;
END;
GO

-- a session ended: the items are out, the slot is free again
CREATE OR ALTER PROCEDURE Deposit_Complete @device_id INT, @slot_code NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id BIGINT, @slot_id INT;
    SELECT TOP 1 @id = d.deposit_id, @slot_id = d.slot_id
    FROM Deposit d
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    WHERE d.status = N'ACTIVE' AND s.slot_code = @slot_code AND b.device_id = @device_id;
    IF @id IS NULL RETURN;
    BEGIN TRAN;
    UPDATE Deposit SET status = N'COMPLETED', ended_at = SYSUTCDATETIME() WHERE deposit_id = @id;
    UPDATE LockerSlot SET status = N'AVAILABLE' WHERE locker_slot_id = @slot_id AND status <> N'MAINTENANCE';
    EXEC Audit_Append @sys, N'COMPLETE', N'DEPOSIT', @id, NULL;
    COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE Deposit_ExpireNoShow
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @expired TABLE (deposit_id BIGINT, slot_id INT);
    DECLARE @id BIGINT;
    BEGIN TRAN;
    UPDATE d SET d.status = N'NO_SHOW', d.ended_at = SYSUTCDATETIME()
    OUTPUT inserted.deposit_id, inserted.slot_id INTO @expired
    FROM Deposit d
    JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
    JOIN LockerBank b ON b.bank_id = s.bank_id
    LEFT JOIN Device v ON v.device_id = b.device_id
    WHERE d.status = N'RESERVED' AND d.hold_until < SYSUTCDATETIME()
      AND (v.device_id IS NULL OR v.status = N'ACTIVE');   -- device offline: we cannot know, so we wait
    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s JOIN @expired e ON e.slot_id = s.locker_slot_id;
    WHILE EXISTS (SELECT 1 FROM @expired)
    BEGIN
        SELECT TOP 1 @id = deposit_id FROM @expired;
        EXEC Audit_Append @sys, N'NO_SHOW', N'DEPOSIT', @id, NULL;
        DELETE FROM @expired WHERE deposit_id = @id;
    END
    COMMIT;
END;
GO

-- ===== Case 5. A sensor breaks =====

-- a SENSOR_FAULT alert opens one ticket per device, gives it to the least busy technician
-- and takes the slot out of service
CREATE OR ALTER PROCEDURE Ticket_OpenForFault
    @device_id INT, @alert_id INT, @session_id BIGINT, @note NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
    DECLARE @id INT;
    BEGIN TRAN;
    UPDATE LockerSlot SET status = N'MAINTENANCE'
    WHERE locker_slot_id = (SELECT slot_id FROM LockerSession WHERE session_id = @session_id);
    IF NOT EXISTS (SELECT 1 FROM MaintenanceTicket WHERE device_id = @device_id AND status = N'OPEN')
    BEGIN
        INSERT INTO MaintenanceTicket (alert_id, device_id, assigned_to, note)
        SELECT @alert_id, @device_id,
               (SELECT TOP 1 u.user_id
                FROM Users u
                JOIN UserRole ur ON ur.user_id = u.user_id
                JOIN Roles r ON r.role_id = ur.role_id AND r.role_name = N'TECHNICIAN'
                WHERE u.status = N'ACTIVE'
                ORDER BY (SELECT COUNT(*) FROM MaintenanceTicket t
                          WHERE t.assigned_to = u.user_id AND t.status = N'OPEN')),   -- least busy technician
               @note;
        SET @id = SCOPE_IDENTITY();
        EXEC Audit_Append @sys, N'OPEN_TICKET', N'MAINTENANCE', @id, @note;
    END
    COMMIT;
END;
GO

-- the technician fixed the sensor: close the ticket, give the slot back
CREATE OR ALTER PROCEDURE Ticket_Close @ticket_id INT, @actor INT, @note NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @alert INT = (SELECT alert_id FROM MaintenanceTicket WHERE ticket_id = @ticket_id AND status = N'OPEN');
    IF NOT EXISTS (SELECT 1 FROM MaintenanceTicket WHERE ticket_id = @ticket_id AND status = N'OPEN')
        THROW 50040, N'Ticket not found or already closed', 1;
    BEGIN TRAN;
    UPDATE MaintenanceTicket
    SET status = N'CLOSED', closed_at = SYSUTCDATETIME(), note = ISNULL(@note, note)
    WHERE ticket_id = @ticket_id;
    UPDATE s SET s.status = N'AVAILABLE'
    FROM LockerSlot s
    JOIN LockerSession ls ON ls.slot_id = s.locker_slot_id
    JOIN Alert a ON a.session_id = ls.session_id
    WHERE a.alert_id = @alert AND s.status = N'MAINTENANCE';
    UPDATE Alert SET status = N'RESOLVED' WHERE alert_id = @alert;
    EXEC Audit_Append @actor, N'CLOSE_TICKET', N'MAINTENANCE', @ticket_id, @note;
    COMMIT;
END;
GO

-- staff marks an alert as handled
CREATE OR ALTER PROCEDURE Alert_Resolve @alert_id INT, @actor INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRAN;
    UPDATE Alert SET status = N'RESOLVED' WHERE alert_id = @alert_id AND status = N'OPEN';
    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK;
        THROW 50041, N'Alert not found or already resolved', 1;
    END
    EXEC Audit_Append @actor, N'RESOLVE_ALERT', N'ALERT', @alert_id, NULL;
    COMMIT;
END;
GO
```

**Khung bạn làm**: `sql/03_scenarios.sql` trong project liệt kê chữ ký từng thủ tục (đó là hợp đồng với các lớp DAO) và mã lỗi của chúng.

**Tự kiểm tra**: chạy `test_scenarios.sql` sau khi viết xong (nó dùng database `PRJ301_LOCKER`; chạy trên dữ liệu mới vừa tạo). Mỗi dòng in `PASS ...` hoặc `FAIL ...`.

**Dễ sai**

- `EXEC #chk 'x', @n = 1, ...` không hợp lệ trong T-SQL: biểu thức không truyền thẳng vào `EXEC`. Đặt vào biến trước (bộ kiểm tra đã làm vậy).
- `THROW` bên trong transaction với `SET XACT_ABORT ON` tự `ROLLBACK`. Nếu bạn gọi `ROLLBACK` trước `THROW` như trong `Deposit_Reserve` thì vẫn đúng, nhưng đừng `COMMIT` sau khi `THROW`.

### 4.3 `sql/02_workshop2.sql` (làm ở giai đoạn 9)

Xem mục 12.1.

## 5. Giai đoạn 2: đăng nhập và phân quyền

Mục tiêu: đăng nhập được bằng `admin`, `operator1`, `tech1`, `auditor1`, `student1` (mật khẩu `123456`); menu mỗi người khác nhau; `student1` gõ thẳng `UserController` thì bị chặn.

Thứ tự trong giai đoạn: `SecurityUtils` → `DbContext` (+ thử kết nối) → `User` → `UserDao.checkLogin` → `PermissionDao.loadKeys` → `AuditDao.append` → `LoginController` + `login.jsp` → `LogoutController` → `SecurityFilter` → `nav.jspf`.

### 5.1 `util/Todo.java`

Đã có sẵn, không phải viết. Mỗi hàm bạn chưa viết ném `UnsupportedOperationException("TODO ...")`. Dòng đó hiện trong log Tomcat và trong test, cho bạn biết còn thiếu gì. Khi viết xong một hàm, thay dòng `throw Todo.of(...)` bằng code thật.

### 5.2 `util/SecurityUtils.java`

**Đọc trước**: DE01 WS1 B3 (`BCrypt.checkpw`); POUR `utils/SecurityUtils.java` (băm SHA-256 UTF-16LE, và khoá thiết bị viết thẳng trong mã `"ESP32_SECRET_2026"`: bản của chúng ta tốt hơn, khoá nằm trong CSDL ở dạng băm).

**Việc của file**: ba hàm tĩnh: băm mật khẩu bằng BCrypt, so mật khẩu, băm SHA-256 cho khoá API. Được `UserDao`, `DeviceDao`, và test gọi.

**Mẫu**

```java
// src/java/util/SecurityUtils.java
package util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import org.mindrot.jbcrypt.BCrypt;

public class SecurityUtils {

    public static String hashPassword(String plain) {
        return BCrypt.hashpw(plain, BCrypt.gensalt(10));
    }

    public static boolean checkPassword(String plain, String hash) {
        if (plain == null || hash == null) {
            return false;
        }
        try {
            return BCrypt.checkpw(plain, hash);
        } catch (IllegalArgumentException e) {
            return false;   // the stored value is not a BCrypt hash, like the 'system' account
        }
    }

    public static String sha256Hex(String text) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `hashPassword(String plain)`: BCrypt.hashpw(plain, BCrypt.gensalt(10))
- `checkPassword(String plain, String hash)`: null check, BCrypt.checkpw, catch IllegalArgumentException
- `sha256Hex(String text)`: MessageDigest SHA-256 over UTF-8 bytes, then hex

**Tự kiểm tra**: `SecurityUtilsTest` (mục 5.14). Đối chiếu tay: `sha256Hex("device-1-api-key")` phải ra `73fb4e98f6db0f8a286c82e03e54764c4d8cd556fcfd858c0f6edf61cdaec849`, cùng giá trị cột `Device.api_key_hash` sau khi chạy `01_schema.sql`.

**Dễ sai**

- `BCrypt.checkpw` **ném `IllegalArgumentException`** khi giá trị lưu không phải BCrypt (tài khoản `system` có 60 ký tự `x`). Bắt lại và trả `false`, nếu không đăng nhập `system` làm sập trang.
- Băm `SHA-256` phải dùng `UTF-8` cho khoá API; băm nhật ký phải dùng `UTF-16LE` (mục 8). Hai chỗ khác nhau vì SQL Server băm `VARCHAR` và `NVARCHAR` khác nhau.

### 5.3 `util/Web.java` và `util/Csv.java`

Hai lớp tiện ích để controller ngắn gọn. `Csv` dùng ở mục 6.

**Mẫu `Web`**

```java
// src/java/util/Web.java
package util;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import model.User;

public class Web {

    public static String trimmed(HttpServletRequest req, String name) {
        String value = req.getParameter(name);
        return value == null ? "" : value.trim();
    }

    public static int intParam(HttpServletRequest req, String name, int defaultValue) {
        try {
            return Integer.parseInt(trimmed(req, name));
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public static Integer optionalInt(HttpServletRequest req, String name) {
        try {
            return Integer.valueOf(trimmed(req, name));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public static User currentUser(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        return session == null ? null : (User) session.getAttribute(LOGIN_USER);
    }

    public static void flash(HttpSession session, String message, boolean bad) {
        session.setAttribute("flash", message);
        session.setAttribute("flashBad", bad);
    }

    public static int pages(int total, int pageSize) {
        return Math.max(1, (total + pageSize - 1) / pageSize);
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `trimmed(HttpServletRequest req, String name)`
- `intParam(HttpServletRequest req, String name, int defaultValue)`
- `optionalInt(HttpServletRequest req, String name)`
- `currentUser(HttpServletRequest req)`
- `flash(HttpSession session, String message, boolean bad)`
- `pages(int total, int pageSize)`

**Mẫu `Csv`**

```java
// src/java/util/Csv.java
package util;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;
import javax.servlet.http.HttpServletResponse;

public class Csv {

    public static String cell(Object value) {
        if (value == null) {
            return "";
        }
        String s = String.valueOf(value);
        if (s.indexOf(',') < 0 && s.indexOf('"') < 0 && s.indexOf('\n') < 0 && s.indexOf('\r') < 0) {
            return s;
        }
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }

    public static void send(HttpServletResponse res, String filename, String[] header, List<String[]> rows) throws IOException {
        res.setContentType("text/csv;charset=UTF-8");
        res.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        PrintWriter out = res.getWriter();
        out.write('﻿');                                  // byte order mark
        out.print(join(header));
        out.print("\r\n");
        for (String[] row : rows) {
            out.print(join(row));
            out.print("\r\n");
        }
        out.flush();
    }

    private static String join(String[] values) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < values.length; i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(cell(values[i]));
        }
        return sb.toString();
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `cell(Object value)`
- `send(HttpServletResponse res, String filename, String[] header, List<String[]> rows)`

Dấu `﻿` (BOM) ở đầu tệp CSV để Excel nhận ra UTF-8; thiếu nó, tiếng Việt có dấu hiện lỗi font.

### 5.4 `dao/DbContext.java`

**Đọc trước**: DE01 WS1 B3 (mã mẫu `DbContext`); POUR `utils/DBContext.java`; OLD `dao/DBContext.java`.

**Việc của file**: nơi duy nhất mở kết nối. Khi đổi máy chỉ sửa ba hằng số ở đầu file.

File này đã hoàn chỉnh trong khung, **việc của bạn là sửa `PASSWORD`** cho đúng mật khẩu `sa` của máy bạn (đề dùng `12345`, project UserManagement dùng `123456`).

```java
package dao;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/** The only place that opens a database connection. Copied from the assignment, Workshop 1 step 3. */
public class DbContext {

    // change the host here when the machine or the network changes
    private static final String URL =
            "jdbc:sqlserver://localhost:1433;databaseName=PRJ301_LOCKER;encrypt=false";
    private static final String USER = "sa";
    private static final String PASSWORD = "12345";   // the password of your own sa account

    public static Connection getConnection() throws SQLException {
        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        } catch (ClassNotFoundException e) {
            throw new SQLException("SQL Server JDBC driver not found in WEB-INF/lib", e);
        }
        return DriverManager.getConnection(URL, USER, PASSWORD);
    }
}
```

**Tự kiểm tra**: tạo một lớp có `main` in số dòng của bảng `Users`:

```java
try (Connection c = DbContext.getConnection();
     ResultSet rs = c.createStatement().executeQuery("SELECT COUNT(*) FROM Users")) {
    rs.next();
    System.out.println("users = " + rs.getInt(1));   // 17
}
```

Chạy bằng chuột phải, **Run File**. Đây là phép thử nhỏ nhất xác nhận driver, JDK, SQL Server và mật khẩu cùng chạy.

**Dễ sai**

| Thông báo | Nguyên nhân |
|---|---|
| `SQL Server JDBC driver not found` | Chưa đưa `mssql-jdbc...jar` vào Libraries (mục 2.2) |
| `Login failed for user 'sa'` | Sai mật khẩu, hoặc SQL Server chưa bật chế độ Mixed Mode (SQL Server and Windows Authentication) |
| `The TCP/IP connection to the host localhost, port 1433 has failed` | Mở SQL Server Configuration Manager, bật TCP/IP cho `MSSQLSERVER`, khởi động lại dịch vụ |
| Lỗi TLS hoặc `PKIX path building failed` | Driver 12.x mặc định mã hoá; URL của đề có `encrypt=false`, đừng xoá |

### 5.5 `model/*.java`

11 lớp dữ liệu, chỉ có trường, getter và setter. Khung đã có sẵn đầy đủ; nếu muốn tự gõ lại thì dùng NetBeans: **Alt+Insert, Getter and Setter**.

| Lớp | Trường chính | Điền ở đâu |
|---|---|---|
| `User` | `userId`, `username`, `fullName`, `status`, `roleName`, `roleRank`, `email`, `phone`, `areaId`, `areaCode` | `UserDao.map`. **Không** chứa hash mật khẩu |
| `Device` | `deviceId`, `deviceCode`, `status`, `lastSeen`, `lastSeenSec` | `DeviceDao` |
| `LockerSession` | số đo (`doorOpenSec`, `weightDeltaG`...) + `slotCode`, `cardUid`, `openSource`, `commandId` | `LockerSessionApi.parse` |
| `LockerArea`, `LockerBank`, `LockerSlot` | mã, tên, khoá ngoại + trường nối (`bankCode`) | DAO tương ứng |
| `StoragePlan`, `UserCard`, `Deposit`, `Calibration` | cột của bảng + vài trường nối để hiện lên trang | DAO tương ứng |
| `Alert` | cột của bảng + `evidence` (danh sách cặp `{mục, giá trị}`) | `AlertDao` |

Kiểu `Integer`, `Long`, `Double` (không phải `int`...) dùng cho cột có thể NULL: `areaId`, `commandId`, `riskScore`, `deviceId` của bank.

### 5.6 `dao/UserDao.java` (phần đăng nhập)

**Đọc trước**: DE01 WS1 B3 (`checkLogin`, `BCrypt.checkpw`); OLD `dao/UserDAO.java`: `search`/`count` dùng `OFFSET ... FETCH`, `delete` dùng transaction; POUR `dao/UserDAO.java` dòng 12 (`authenticate`) và dòng 59 (`createAccount`: tạo người dùng và gán vai trò bằng thủ tục).

**Việc của file**: mọi câu SQL về người dùng. Giai đoạn này chỉ cần `checkLogin`, `register`, `usernameExists`, `search`, `count`; còn lại ở mục 6.5.

Khác với mã mẫu của đề: `checkLogin` **trả người dùng dù tài khoản bị khoá** (khi mật khẩu đúng), để trang hiện "tài khoản bị khoá" thay vì "sai mật khẩu". Controller kiểm tra `status`.

**Mẫu**

```java
// src/java/dao/UserDao.java
package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import model.User;
import util.SecurityUtils;

public class UserDao {

    private static final String COLUMNS = "u.user_id, u.username, u.full_name, u.status, u.email, u.phone, "
            + "u.area_id, a.area_code, r.role_name, r.rank_no";
    private static final String FROM = " FROM Users u "
            + "LEFT JOIN LockerArea a ON a.area_id = u.area_id "
            + "JOIN UserRole ur ON ur.user_id = u.user_id "
            + "JOIN Roles r ON r.role_id = ur.role_id ";

    private static User map(ResultSet rs) throws SQLException {
        User u = new User();
        u.setUserId(rs.getInt("user_id"));
        u.setUsername(rs.getString("username"));
        u.setFullName(rs.getString("full_name"));
        u.setStatus(rs.getString("status"));
        u.setEmail(rs.getString("email"));
        u.setPhone(rs.getString("phone"));
        int areaId = rs.getInt("area_id");
        u.setAreaId(rs.wasNull() ? null : areaId);
        u.setAreaCode(rs.getString("area_code"));
        u.setRoleName(rs.getString("role_name"));
        u.setRoleRank(rs.getInt("rank_no"));
        return u;
    }

    /** WHERE clause shared by search() and count(); the values go into params, never into the text. */
    private static String where(String keyword, String role, String status, List<Object> params) {
        StringBuilder sb = new StringBuilder(" WHERE u.username <> N'system'");
        if (keyword != null && !keyword.isEmpty()) {
            sb.append(" AND (u.username LIKE ? OR u.full_name LIKE ? OR u.email LIKE ?)");
            String like = "%" + keyword + "%";
            params.add(like);
            params.add(like);
            params.add(like);
        }
        if (role != null && !role.isEmpty()) {
            sb.append(" AND r.role_name = ?");
            params.add(role);
        }
        if (status != null && !status.isEmpty()) {
            sb.append(" AND u.status = ?");
            params.add(status);
        }
        return sb.toString();
    }

    public User checkLogin(String username, String password) throws SQLException {
        String sql = "SELECT " + COLUMNS + ", u.password_hash" + FROM + "WHERE u.username = ? ORDER BY r.rank_no";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, username);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next() && SecurityUtils.checkPassword(password, rs.getString("password_hash"))) {
                    return map(rs);   // the hash is not copied into the User
                }
            }
        }
        return null;
    }

    public int register(String username, String password, String fullName) throws SQLException {
        String insertUser = "INSERT INTO Users (username, password_hash, full_name) VALUES (?, ?, ?)";
        String insertRole = "INSERT INTO UserRole (user_id, role_id) SELECT ?, role_id FROM Roles WHERE role_name = N'END_USER'";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int id;
                try (PreparedStatement ps = conn.prepareStatement(insertUser, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setString(1, username);
                    ps.setString(2, SecurityUtils.hashPassword(password));
                    ps.setString(3, fullName);
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        keys.next();
                        id = keys.getInt(1);
                    }
                }
                try (PreparedStatement ps = conn.prepareStatement(insertRole)) {
                    ps.setInt(1, id);
                    ps.executeUpdate();
                }
                conn.commit();
                return id;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    public List<User> search(String keyword, String role, String status, int page, int size) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT " + COLUMNS + FROM + where(keyword, role, status, params)
                + " ORDER BY u.user_id OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        params.add((page - 1) * size);
        params.add(size);
        List<User> items = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    items.add(map(rs));
                }
            }
        }
        return items;
    }

    public int count(String keyword, String role, String status) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*)" + FROM + where(keyword, role, status, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public boolean usernameExists(String username, int exceptUserId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM Users WHERE username = ? AND user_id <> ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, username);
            ps.setInt(2, exceptUserId);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getInt(1) > 0;
            }
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `checkLogin(String username, String password)`: select by username (parameter), then SecurityUtils.checkPassword on the stored hash
- `register(String username, String password, String fullName)`: one transaction: INSERT Users, then INSERT UserRole for END_USER
- `findById(int userId)`: find one user by id: same query as checkLogin without the password, WHERE u.user_id = ?
- `findByUsername(String username)`: find one user by username (used by the register page to explain a clash)
- `search(String keyword, String role, String status, int page, int size)`: dynamic WHERE with ? parameters, ORDER BY ... OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
- `count(String keyword, String role, String status)`: the same WHERE, SELECT COUNT(*)
- `insert(User u, String plainPassword)`: INSERT Users (hash from SecurityUtils.hashPassword) and UserRole in one transaction, like register()
- `update(User u)`: UPDATE full_name, email, phone, area_id, status and replace the UserRole row, in one transaction
- `setStatus(int userId, String status)`: UPDATE Users SET status = ? (ACTIVE or LOCKED); return true when one row changed
- `resetPassword(int userId, String plainPassword)`: UPDATE password_hash with a new BCrypt hash
- `delete(int userId)`: DELETE UserRole then Users in one transaction; catch error 547 and return a readable reason
- `usernameExists(String username, int exceptUserId)`: SELECT COUNT(*) FROM Users WHERE username = ? AND user_id <> ?
- `emailExists(String email, int exceptUserId)`: same as usernameExists for the email column
- `countByRole()`: SELECT role_name, COUNT(*) ... GROUP BY role_name ORDER BY rank_no into a LinkedHashMap
- `countByStatus(String status)`: SELECT COUNT(*) FROM Users WHERE status = ?

**Tự kiểm tra**: `main` thử `new UserDao().checkLogin("student1", "123456")` trả đối tượng có `roleName = END_USER`; mật khẩu sai trả `null`; `locked1` trả đối tượng có `isLocked() = true`.

**Dễ sai**

- Quên `ORDER BY r.rank_no`: nếu sau này một người có hai vai trò, vai trò thấp có thể được chọn.
- `ps.setObject(i + 1, ...)` với `Integer` hoạt động, nhưng `null` cần `setNull` có kiểu.
- Số `?` và số phần tử `params` phải bằng nhau theo đúng thứ tự: `OFFSET ?` và `FETCH NEXT ?` luôn thêm **sau cùng** vào `params`.

### 5.7 `dao/PermissionDao.java`

**Đọc trước**: DE01 WS1 B4 (`hasPermission`, `RESOURCE_BY_PATH`); OLD `dao/UserDAO.java` `loadPermissions`; OLD `web/WEB-INF/views/rolePermission.jsp` (bảng tick quyền).

**Việc của file**: trả tập quyền của một người dạng `"RESOURCE:ACTION"`. Một truy vấn cho cả yêu cầu, thay vì mỗi bước một truy vấn như mã mẫu của đề. Bộ lọc đặt tập này vào `request` để menu dùng lại.

**Mẫu**

```java
// src/java/dao/PermissionDao.java
package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class PermissionDao {

    public Set<String> loadKeys(int userId) throws SQLException {
        String sql = "SELECT p.resource, p.action FROM UserRole ur "
                + "JOIN RolePerm rp ON rp.role_id = ur.role_id "
                + "JOIN Permissions p ON p.perm_id = rp.perm_id WHERE ur.user_id = ?";
        Set<String> keys = new HashSet<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    keys.add(rs.getString(1) + ":" + rs.getString(2));
                }
            }
        }
        return keys;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `loadKeys(int userId)`: one query over UserRole, RolePerm and Permissions
- `listRoles()`: Roles LEFT JOIN counts of UserRole and RolePerm, ORDER BY rank_no
- `permissionGrid(int roleId)`: Permissions LEFT JOIN RolePerm for this role, ORDER BY resource, action
- `saveRolePerms(int roleId, int[] permIds)`: DELETE FROM RolePerm WHERE role_id = ?, then batch INSERT, commit; rollback on error
- `roleName(int roleId)`: SELECT role_name FROM Roles WHERE role_id = ?

**Tự kiểm tra**: `loadKeys(9)` (id của `student1`) trả đúng 5 chuỗi: `MAP:READ`, `BOOKING:READ`, `BOOKING:WRITE`, `MYCARD:READ`, `MYCARD:WRITE`.

### 5.8 `dao/AuditDao.java`

**Đọc trước**: DE01 WS2 B4 (`Audit_Append`); POUR `service/ChainVerificationService.java` để hiểu vì sao việc truyền đủ giá trị quan trọng.

**Việc của file**: gọi `Audit_Append`. Mọi thao tác ghi dữ liệu trong ứng dụng gọi `append` một lần.

**Mẫu**

```java
// src/java/dao/AuditDao.java
package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

public class AuditDao {

    public void append(int actorId, String action, String objectType, long objectId, String diff) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Audit_Append(?, ?, ?, ?, ?)}")) {
            cs.setInt(1, actorId);
            cs.setString(2, action);
            cs.setString(3, objectType);
            cs.setLong(4, objectId);
            cs.setString(5, diff);
            cs.execute();
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `append(int actorId, String action, String objectType, long objectId, String diff)`: CallableStatement {call Audit_Append(?,?,?,?,?)}
- `search(String action, int page, int size)`: AuditLog JOIN Users (actor name), optional WHERE action = ?, ORDER BY audit_id DESC OFFSET/FETCH
- `count(String action)`: SELECT COUNT(*) FROM AuditLog with the same optional filter
- `actions()`: SELECT DISTINCT action FROM AuditLog ORDER BY action

**Tự kiểm tra**: sau khi gọi `append(1, "TEST", "USER", 5, null)`, câu `SELECT TOP 2 * FROM AuditLog ORDER BY audit_id DESC` có dòng mới và `HashChain` có thêm một dòng.

**Dễ sai**: `append(0, ...)` hoặc `objectId` bỏ trống. Xem "Nhật ký" ở mục 1.

### 5.9 `filter/SecurityFilter.java`

**Đọc trước**: DE01 WS1 B4 (mã mẫu của đề); POUR `filter/SecurityFilter.java` (chỉ kiểm tra đã đăng nhập, không kiểm tra quyền, và khoá thiết bị so sánh chuỗi cố định); OLD `filter/AuthFilter.java` (bảng đường dẫn tới quyền, "tiền tố dài nhất thắng").

**Việc của file**: cổng duy nhất vào ứng dụng. Bốn bước: đường dẫn công khai? khoá API của thiết bị? đã đăng nhập? có quyền không? Ẩn nút trong JSP chỉ để cho đẹp; **bộ lọc mới là thứ chặn thật**.

Quyết định thiết kế đáng nói với thầy:

- **Đường dẫn không có trong bảng thì bị từ chối (403)**, không phải cho qua. Quên một dòng thì an toàn, không phải hở.
- **Thiết bị vào bằng khoá API**, `device_id` lấy từ khoá chứ không tin số thiết bị gửi trong nội dung.
- Bộ lọc **đặt tập quyền vào `request`** (`perms`) để menu và API bản đồ dùng, không truy vấn lần hai.
- `Cache-Control: no-store`: sau khi đăng xuất, nút Back không hiện lại trang cũ.

**Mẫu**

```java
// src/java/filter/SecurityFilter.java
package filter;

import dao.DeviceDao;
import dao.PermissionDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

@WebFilter(urlPatterns = {"/*"})
public class SecurityFilter implements Filter {

    /** Reachable without signing in. */
    private static final Set<String> PUBLIC_PATHS = new HashSet<>(Arrays.asList(
            "/", "/index.html", "/favicon.ico", "/LoginController", "/RegisterController", "/LogoutController"));
    private static final String[] PUBLIC_PREFIXES = {"/css/", "/js/", "/img/", "/demo/"};

    /** The device signs with an X-API-Key header instead of a login. */
    private static final Set<String> DEVICE_API_PATHS = new HashSet<>(Arrays.asList(
            "/api/health", "/api/locker/batch"));

    /** servlet path -> resource name in the Permissions table. GET needs READ, anything else needs WRITE. */
    private static final Map<String, String> RESOURCE_BY_PATH = new HashMap<>();

    static {
        RESOURCE_BY_PATH.put("/LockerMapController", "MAP");
        RESOURCE_BY_PATH.put("/api/locker-map", "MAP");
        RESOURCE_BY_PATH.put("/DashboardController", "ALERT");
        RESOURCE_BY_PATH.put("/api/dashboard", "ALERT");
        RESOURCE_BY_PATH.put("/AlertController", "ALERT");
        RESOURCE_BY_PATH.put("/MaintenanceController", "MAINTENANCE");
        RESOURCE_BY_PATH.put("/CalibrationController", "CALIBRATION");
        RESOURCE_BY_PATH.put("/LockerAreaController", "AREA");
        RESOURCE_BY_PATH.put("/LockerBankController", "LOCKERBANK");
        RESOURCE_BY_PATH.put("/LockerSlotController", "LOCKERSLOT");
        RESOURCE_BY_PATH.put("/StoragePlanController", "STORAGEPLAN");
        RESOURCE_BY_PATH.put("/UserCardController", "USERCARD");
        RESOURCE_BY_PATH.put("/DepositController", "DEPOSIT");
        RESOURCE_BY_PATH.put("/RemoteCommandController", "COMMAND");
        RESOURCE_BY_PATH.put("/BookingController", "BOOKING");
        RESOURCE_BY_PATH.put("/MyCardController", "MYCARD");
        RESOURCE_BY_PATH.put("/UserController", "USER");
        RESOURCE_BY_PATH.put("/RoleController", "ROLE");
        RESOURCE_BY_PATH.put("/AuditController", "AUDIT");
    }

    private static boolean isPublic(String path) {
        if (PUBLIC_PATHS.contains(path)) {
            return true;
        }
        for (String prefix : PUBLIC_PREFIXES) {
            if (path.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }

    public void init(FilterConfig filterConfig) {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        req.setCharacterEncoding("UTF-8");
        String path = req.getServletPath();

        // 1. pages and files anyone may open
        if (isPublic(path)) {
            chain.doFilter(request, response);
            return;
        }

        try {
            // 2. a device signs with its key; the id comes from the key, never from the body it sends
            if (DEVICE_API_PATHS.contains(path)) {
                Integer deviceId = new DeviceDao().findIdByApiKey(req.getHeader("X-API-Key"));
                if (deviceId == null) {
                    res.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid API key");
                    return;
                }
                req.setAttribute("DEVICE_ID", deviceId);
                chain.doFilter(request, response);
                return;
            }

            // 3. everybody else must be signed in
            User user = Web.currentUser(req);
            if (user == null) {
                res.sendRedirect(req.getContextPath() + "/LoginController");
                return;
            }

            // 4. and must hold READ (GET) or WRITE (other methods) on the resource behind the path.
            //    A path that is not in the table is refused: forgetting a line is safe, not open.
            Set<String> keys = new PermissionDao().loadKeys(user.getUserId());
            req.setAttribute("perms", keys);   // common/nav.jspf reads it to draw the menu
            String resource = RESOURCE_BY_PATH.get(path);
            String action = "GET".equals(req.getMethod()) ? "READ" : "WRITE";
            if (resource == null || !keys.contains(resource + ":" + action)) {
                res.sendError(HttpServletResponse.SC_FORBIDDEN, "Permission denied");
                return;
            }
            res.setHeader("Cache-Control", "no-store");   // the Back button must not show a page after logout
            chain.doFilter(request, response);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**: khung cho mọi yêu cầu đi qua (`chain.doFilter`), để bạn thấy website chạy được trước khi có kiểm tra.

- `init(FilterConfig filterConfig)`: public -> device key -> signed in -> permission of the resource

**Tự kiểm tra** (sau khi viết xong, đăng nhập trong trình duyệt):

| Việc | Kết quả đúng |
|---|---|
| Chưa đăng nhập, mở `/SmartLocker/UserController` | Chuyển về trang đăng nhập |
| Đăng nhập `student1`, gõ `/SmartLocker/UserController` | Trang "Access denied" (403) |
| Đăng nhập `student1`, mở `/SmartLocker/LockerMapController` | Mở được |
| `curl.exe -i -X POST http://localhost:8080/SmartLocker/api/health` (không khoá) | 401 |
| Cùng lệnh có `-H "X-API-Key: device-1-api-key"` | Qua bộ lọc (kết quả do `HealthApi`) |

**Dễ sai**

- `getServletPath()` trả `/LockerSlotController`, không có tên project; còn `getRequestURI()` có. Bảng `RESOURCE_BY_PATH` dùng `getServletPath()`.
- Bộ lọc không áp dụng cho `forward` và trang lỗi (mặc định chỉ chặn `REQUEST`): `denied.jsp` không bị lọc lại.
- Quên thêm đường dẫn của controller mới vào `RESOURCE_BY_PATH`: trang mới trả 403 với mọi người, kể cả ADMIN.

### 5.10 `controller/LoginController.java`

**Đọc trước**: DE01 WS1 B3; POUR `controller/LoginController.java` (chuyển hướng lỗi lên URL; ta dùng `forward` kèm thuộc tính, không để tên đăng nhập lộ lên URL); OLD `controller/LoginServlet.java`.

**Việc của file**: GET hiện form; POST kiểm tra mật khẩu, từ chối tài khoản bị khoá, tạo phiên, ghi nhật ký, chuyển hướng theo quyền.

- `req.changeSessionId()` sau khi đăng nhập: chống tấn công cố định phiên (session fixation).
- Đăng nhập sai ghi `LOGIN_FAIL` với người thực hiện là `system` và mã đối tượng `0`.
- Người có quyền `ALERT:READ` (nhân viên) vào Dashboard; người dùng thường vào sơ đồ tủ.

**Mẫu**

```java
// src/java/controller/LoginController.java
package controller;

import dao.AuditDao;
import dao.PermissionDao;
import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Set;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

@WebServlet(name = "LoginController", urlPatterns = {"/LoginController"})
public class LoginController extends HttpServlet {

    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        if (Web.currentUser(req) != null) {
            res.sendRedirect(req.getContextPath() + "/LockerMapController");
            return;
        }
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String username = Web.trimmed(req, "username");
        String password = req.getParameter("password") == null ? "" : req.getParameter("password");
        try {
            User user = new UserDao().checkLogin(username, password);
            String error = null;
            if (user == null) {
                error = "Invalid username or password";
                new AuditDao().append(AuditDao.SYSTEM_USER_ID, "LOGIN_FAIL", "USER", 0, "username=" + username);
            } else if (user.isLocked()) {
                error = "This account is locked, ask a Locker Operator to unlock it";
            } else if (!"ACTIVE".equals(user.getStatus())) {
                error = "This account cannot sign in";
            }
            if (error != null) {
                req.setAttribute("error", error);
                req.setAttribute("username", username);
                req.getRequestDispatcher(VIEW).forward(req, res);
                return;
            }
            req.getSession(true);
            req.changeSessionId();                       // a new session id after login stops session fixation
            req.getSession().setAttribute(Web.LOGIN_USER, user);
            new AuditDao().append(user.getUserId(), "LOGIN", "USER", user.getUserId(), null);

            Set<String> keys = new PermissionDao().loadKeys(user.getUserId());
            String home = keys.contains("ALERT:READ") ? "/DashboardController" : "/LockerMapController";
            res.sendRedirect(req.getContextPath() + home);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `doGet(HttpServletRequest req, HttpServletResponse res)`: a signed-in user goes home, everybody else sees the form
- `doPost(HttpServletRequest req, HttpServletResponse res)`: check the password, refuse a locked account, start the session, audit, redirect by permission

**Tự kiểm tra**

| Việc | Kết quả đúng |
|---|---|
| `admin` / `123456` | Vào Dashboard |
| `student1` / `123456` | Vào sơ đồ tủ, menu chỉ có Locker map, My bookings, My cards |
| `student1` / `sai` | Báo "Invalid username or password", ô tên vẫn còn chữ `student1`, ô mật khẩu trống |
| `locked1` / `123456` | Báo tài khoản bị khoá |
| `system` / bất kỳ | Báo sai (hash không phải BCrypt, không ném lỗi) |
| Trong SSMS `SELECT TOP 5 * FROM AuditLog ORDER BY audit_id DESC` | Có dòng `LOGIN` và `LOGIN_FAIL` |

### 5.11 `controller/LogoutController.java`, `controller/RegisterController.java`

`LogoutController` ngắn, xem mẫu. `RegisterController` giống `LoginController`: mẫu cho `doGet`, `doPost` bạn tự viết.

```java
// src/java/controller/LogoutController.java
package controller;

import java.io.IOException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

@WebServlet(name = "LogoutController", urlPatterns = {"/LogoutController"})
public class LogoutController extends HttpServlet {

    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        HttpSession session = req.getSession(false);
        if (session != null) {
            session.invalidate();   // drops the login state
        }
        res.sendRedirect(req.getContextPath() + "/LoginController");
    }

    // ... the other methods are in your skeleton file
}
```

- `doGet(HttpServletRequest req, HttpServletResponse res)`

**Tự kiểm tra**: đăng ký `newuser` / `abc123`; đăng nhập được với vai trò Locker User; đăng ký lại cùng tên báo "đã có". Kiểm tra trong SSMS: `SELECT password_hash FROM Users WHERE username = 'newuser'` có 60 ký tự bắt đầu bằng `$2a$`.

### 5.12 `web/WEB-INF/views/common/nav.jspf`, `login.jsp`, `register.jsp`, `denied.jsp`, `web.xml`

Phần giao diện, đã hoàn chỉnh trong khung (mình viết, bạn đọc để hiểu). Điểm cần hiểu:

- `nav.jspf` được chèn vào các trang bằng `<%@ include file="common/nav.jspf" %>`. Nó đọc `perms` (tập quyền do bộ lọc đặt) để vẽ menu: `${perms.contains('USER:READ')}`. Gọi phương thức có tham số trong EL cần EL 3.0, Tomcat 9 có sẵn.
- Mọi chuỗi từ dữ liệu đi qua `<c:out>` (tự thoát `<`, `&`, `"`). Không bao giờ viết `${user.fullName}` thẳng vào HTML.
- Thông báo một lần (`flash`) nằm trong phiên: `Web.flash(session, ...)` đặt, `nav.jspf` hiện và xoá.
- `web.xml` chỉ khai báo những gì chú thích (annotation) không làm được: thời gian phiên, trang lỗi 403 và 404, trang chào.

```jsp
<%-- Top bar and menu, shared by every page after sign in.
     A page includes it with   <%@ include file="common/nav.jspf" %>   and may set activeNav first, for example
     <c:set var="activeNav" value="slots"/>.
     "perms" is the set of "RESOURCE:ACTION" strings that SecurityFilter puts in the request, so the menu always
     shows what the signed-in user may open. Hiding a link is a convenience: the filter is what really blocks. --%>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<c:set var="me" value="${sessionScope.LOGIN_USER}"/>
<div class="topbar">
    <div class="brand">Smart Locker <span class="sem">FALL2026</span></div>
    <div class="who">
        <c:out value="${me.fullName}"/>
        <span class="tag"><c:out value="${me.roleName}"/></span>
        <a class="out" href="${ctx}/LogoutController">Logout</a>
    </div>
</div>
<div class="menu">
    <c:if test="${perms.contains('MAP:READ')}"><a href="${ctx}/LockerMapController" class="${activeNav == 'map' ? 'on' : ''}">Locker map</a></c:if>
    <c:if test="${perms.contains('ALERT:READ')}">
        <a href="${ctx}/DashboardController" class="${activeNav == 'dashboard' ? 'on' : ''}">Dashboard</a>
        <a href="${ctx}/AlertController" class="${activeNav == 'alerts' ? 'on' : ''}">Alerts</a>
    </c:if>
    <c:if test="${perms.contains('BOOKING:READ')}"><a href="${ctx}/BookingController" class="${activeNav == 'bookings' ? 'on' : ''}">My bookings</a></c:if>
    <c:if test="${perms.contains('MYCARD:READ')}"><a href="${ctx}/MyCardController" class="${activeNav == 'mycards' ? 'on' : ''}">My cards</a></c:if>
    <c:if test="${perms.contains('USER:READ')}"><a href="${ctx}/UserController" class="${activeNav == 'users' ? 'on' : ''}">Users</a></c:if>
    <c:if test="${perms.contains('ROLE:READ')}"><a href="${ctx}/RoleController" class="${activeNav == 'roles' ? 'on' : ''}">Roles</a></c:if>
    <c:if test="${perms.contains('AREA:READ') or perms.contains('LOCKERBANK:READ') or perms.contains('LOCKERSLOT:READ')
                  or perms.contains('STORAGEPLAN:READ') or perms.contains('USERCARD:READ') or perms.contains('DEPOSIT:READ')
                  or perms.contains('COMMAND:READ') or perms.contains('CALIBRATION:READ') or perms.contains('MAINTENANCE:READ')}">
        <details class="menu-more">
            <summary>Manage</summary>
            <div class="menu-more__list">
                <c:if test="${perms.contains('AREA:READ')}"><a href="${ctx}/LockerAreaController">Areas</a></c:if>
                <c:if test="${perms.contains('LOCKERBANK:READ')}"><a href="${ctx}/LockerBankController">Banks</a></c:if>
                <c:if test="${perms.contains('LOCKERSLOT:READ')}"><a href="${ctx}/LockerSlotController">Slots</a></c:if>
                <c:if test="${perms.contains('STORAGEPLAN:READ')}"><a href="${ctx}/StoragePlanController">Storage plans</a></c:if>
                <c:if test="${perms.contains('USERCARD:READ')}"><a href="${ctx}/UserCardController">Cards</a></c:if>
                <c:if test="${perms.contains('DEPOSIT:READ')}"><a href="${ctx}/DepositController">Deposits</a></c:if>
                <c:if test="${perms.contains('COMMAND:READ')}"><a href="${ctx}/RemoteCommandController">Remote commands</a></c:if>
                <c:if test="${perms.contains('CALIBRATION:READ')}"><a href="${ctx}/CalibrationController">Calibration</a></c:if>
                <c:if test="${perms.contains('MAINTENANCE:READ')}"><a href="${ctx}/MaintenanceController">Maintenance</a></c:if>
            </div>
        </details>
    </c:if>
    <c:if test="${perms.contains('AUDIT:READ')}"><a href="${ctx}/AuditController" class="${activeNav == 'audit' ? 'on' : ''}">Audit log</a></c:if>
</div>
<%-- one message after a POST: Web.flash(session, text, bad) --%>
<c:if test="${not empty sessionScope.flash}">
    <div class="flash ${sessionScope.flashBad ? 'bad' : ''}"><c:out value="${sessionScope.flash}"/></div>
    <c:remove var="flash" scope="session"/>
    <c:remove var="flashBad" scope="session"/>
</c:if>
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">

    <!-- Servlets, the filter and the listener are declared with annotations in the source. -->

    <session-config>
        <session-timeout>45</session-timeout>
    </session-config>

    <welcome-file-list>
        <welcome-file>index.html</welcome-file>
    </welcome-file-list>

    <!-- SecurityFilter answers 403 for a role without the permission; an unknown address is 404 -->
    <error-page>
        <error-code>403</error-code>
        <location>/WEB-INF/views/denied.jsp</location>
    </error-page>
    <error-page>
        <error-code>404</error-code>
        <location>/WEB-INF/views/denied.jsp</location>
    </error-page>
</web-app>
```

Hai trang đăng nhập và đăng ký xem trong `docs/demo-code/web/WEB-INF/views/`.

**Tự kiểm tra**: đăng nhập từng vai trò, so menu với bảng phân quyền ở mục 1: `student1` thấy Locker map, My bookings, My cards; `tech1` thấy Locker map, Dashboard, Alerts, Users và nhóm Manage (không có Roles, vì bảng quyền không cho kỹ thuật viên đọc `ROLE`); không ai thấy mục không có quyền đọc.

### 5.13 `index.html`

Trang chào có hai nút. Khi nộp bài, đổi thành chuyển hướng thẳng tới `LoginController` và xoá nút demo.

### 5.14 `test/test/SecurityUtilsTest.java`

**Đọc trước**: POUR `test/test/SecurityUtilsTest.java`.

**Mẫu**: năm test, không cần cơ sở dữ liệu.

```java
package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertNotEquals;
import static org.testng.Assert.assertTrue;

import org.testng.annotations.Test;
import util.SecurityUtils;

/** Pure Java, no database. */
public class SecurityUtilsTest {

    @Test
    public void hashIsSixtyCharactersAndMatchesItsPassword() {
        String hash = SecurityUtils.hashPassword("123456");
        assertEquals(hash.length(), 60);
        assertTrue(SecurityUtils.checkPassword("123456", hash));
    }

    @Test
    public void wrongPasswordIsRejected() {
        assertFalse(SecurityUtils.checkPassword("654321", SecurityUtils.hashPassword("123456")));
    }

    @Test
    public void twoHashesOfOnePasswordDiffer() {
        assertNotEquals(SecurityUtils.hashPassword("123456"), SecurityUtils.hashPassword("123456"));
    }

    @Test
    public void aStoredValueThatIsNotBcryptNeverLogsIn() {
        // the 'system' account has 60 x characters as its hash
        assertFalse(SecurityUtils.checkPassword("123456", "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"));
        assertFalse(SecurityUtils.checkPassword(null, SecurityUtils.hashPassword("123456")));
    }

    @Test
    public void sha256MatchesTheHashSqlServerStoresForTheDemoKey() {
        assertEquals(SecurityUtils.sha256Hex("device-1-api-key"),
                "73fb4e98f6db0f8a286c82e03e54764c4d8cd556fcfd858c0f6edf61cdaec849");
    }
}
```

**Khung bạn làm**: khung có sẵn test đầu tiên và danh sách `TODO` bốn test còn lại. Chuột phải file, **Test File**.

**Cột mốc cuối giai đoạn 2**: đăng nhập đủ 5 vai trò đúng bảng trên; `SecurityUtilsTest` xanh.

## 6. Giai đoạn 3: thêm, xem, sửa, xoá

Đề yêu cầu đủ bốn thao tác cho 6 thực thể riêng (dãy tủ, ngăn tủ, thẻ người dùng, lượt gửi, gói thời gian gửi, người dùng) và cho các thực thể dùng chung. Làm **một** thực thể thật kỹ (ngăn tủ), rồi các thực thể còn lại gần như chép lại.

### 6.1 Mẫu của mọi trang CRUD: ngăn tủ

Bốn file làm việc cùng nhau: `model/LockerSlot`, `dao/LockerSlotDao`, `controller/LockerSlotController`, `views/lockerSlot.jsp`.

**Đọc trước**

- DE01 WS1 B5: "Làm mẫu đầy đủ cho LockerSlot": `LockerSlotDao.search`/`insert`, `LockerSlotController`, `locker_list.jsp`.
- OLD `controller/UserServlet.java` (cách kiểm tra, thông báo, chuyển hướng), `dao/UserDAO.java` (`search`, `count`, `delete` có transaction), `web/WEB-INF/views/userList.jsp` và `userForm.jsp`, `controller/ExportServlet.java` (xuất CSV).

**Việc của từng file**

| File | Việc | Không làm |
|---|---|---|
| `LockerSlot` | Giữ dữ liệu một ngăn | Không có SQL |
| `LockerSlotDao` | `search`, `count`, `findById`, `insert`, `update`, `delete`, `codeExists` | Không biết `request` |
| `LockerSlotController` | Đọc tham số, kiểm tra, gọi DAO, đặt thuộc tính, forward hoặc redirect | Không có SQL, không in HTML |
| `lockerSlot.jsp` | Một trang, hai chế độ: `mode = list` hoặc `form` | Không có SQL, không có logic nghiệp vụ |

Những ý quan trọng:

- **Phân trang ở máy chủ**: `ORDER BY ... OFFSET ? ROWS FETCH NEXT ? ROWS ONLY`. Chỉ các dòng của trang rời CSDL. `ORDER BY` bắt buộc khi dùng `OFFSET`.
- **Câu `WHERE` dựng động nhưng chỉ chứa `?`**: giá trị người dùng gõ nằm trong `List<Object> params`, không bao giờ nằm trong chuỗi SQL. Gõ `'; DROP TABLE...` vào ô tìm kiếm không có tác dụng. `search` và `count` dùng chung hàm `where(...)` để số trang khớp số dòng.
- **Xoá bị CSDL từ chối** (khoá ngoại, lỗi 547) không làm sập trang: DAO trả về **chuỗi lý do** và controller hiện nguyên văn. Ngăn có lượt gửi không xoá được.
- **Post/Redirect/Get**: sau mỗi POST thành công, `sendRedirect`. Tải lại trang không gửi lại form.
- **Form lỗi giữ nguyên chữ đã gõ**: `showForm(req, res, s, isNew)` nhận đối tượng người dùng vừa nhập.

**Mẫu `model/LockerSlot.java`**: lớp dữ liệu, khung đã có đủ.

**Mẫu `dao/LockerSlotDao.java`**

```java
// src/java/dao/LockerSlotDao.java
package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import model.LockerSlot;

public class LockerSlotDao {

    private static final String SELECT = "SELECT s.locker_slot_id, s.slot_code, s.bank_id, b.bank_code, "
            + "s.size_cm, s.size_code, s.status FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id";

    private static LockerSlot map(ResultSet rs) throws SQLException {
        LockerSlot s = new LockerSlot();
        s.setSlotId(rs.getInt("locker_slot_id"));
        s.setSlotCode(rs.getString("slot_code"));
        s.setBankId(rs.getInt("bank_id"));
        s.setBankCode(rs.getString("bank_code"));
        s.setSizeCm(rs.getString("size_cm"));
        s.setSizeCode(rs.getString("size_code"));
        s.setStatus(rs.getString("status"));
        return s;
    }

    /** Builds the WHERE text with ? marks only; the values go into params in the same order. */
    private static String where(String keyword, Integer bankId, String status, List<Object> params) {
        StringBuilder sb = new StringBuilder(" WHERE 1 = 1");
        if (keyword != null && !keyword.isEmpty()) {
            sb.append(" AND s.slot_code LIKE ?");
            params.add("%" + keyword + "%");
        }
        if (bankId != null) {
            sb.append(" AND s.bank_id = ?");
            params.add(bankId);
        }
        if (status != null && !status.isEmpty()) {
            sb.append(" AND s.status = ?");
            params.add(status);
        }
        return sb.toString();
    }

    private static void bind(PreparedStatement ps, List<Object> params) throws SQLException {
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
    }

    public List<LockerSlot> search(String keyword, Integer bankId, String status, int page, int size) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = SELECT + where(keyword, bankId, status, params)
                + " ORDER BY b.bank_code, s.slot_code OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        params.add((page - 1) * size);
        params.add(size);
        List<LockerSlot> items = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    items.add(map(rs));
                }
            }
        }
        return items;
    }

    public int count(String keyword, Integer bankId, String status) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM LockerSlot s" + where(keyword, bankId, status, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public LockerSlot findById(int slotId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(SELECT + " WHERE s.locker_slot_id = ?")) {
            ps.setInt(1, slotId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    public int insert(LockerSlot s) throws SQLException {
        String sql = "INSERT INTO LockerSlot (slot_code, bank_id, size_cm, size_code, status) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, s.getSlotCode());
            ps.setInt(2, s.getBankId());
            ps.setString(3, s.getSizeCm());
            ps.setString(4, s.getSizeCode());
            ps.setString(5, s.getStatus());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        }
    }

    public boolean update(LockerSlot s) throws SQLException {
        String sql = "UPDATE LockerSlot SET slot_code = ?, bank_id = ?, size_cm = ?, size_code = ?, status = ? "
                + "WHERE locker_slot_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, s.getSlotCode());
            ps.setInt(2, s.getBankId());
            ps.setString(3, s.getSizeCm());
            ps.setString(4, s.getSizeCode());
            ps.setString(5, s.getStatus());
            ps.setInt(6, s.getSlotId());
            return ps.executeUpdate() == 1;
        }
    }

    public String delete(int slotId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM LockerSlot WHERE locker_slot_id = ?")) {
            ps.setInt(1, slotId);
            return ps.executeUpdate() == 1 ? null : "This slot no longer exists";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "This slot has bookings or sessions, set it to MAINTENANCE instead";
            }
            throw e;
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `search(String keyword, Integer bankId, String status, int page, int size)`: server side paging: only the rows of the page leave the database
- `count(String keyword, Integer bankId, String status)`: the same WHERE, so the page count matches the rows
- `findById(int slotId)`
- `insert(LockerSlot s)`: INSERT ... with RETURN_GENERATED_KEYS
- `update(LockerSlot s)`: UPDATE ... WHERE locker_slot_id = ?, true when one row changed
- `delete(int slotId)`: catch SQL error 547 (foreign key) and return a readable reason instead of failing
- `codeExists(int bankId, String slotCode, int exceptSlotId)`: SELECT COUNT(*) FROM LockerSlot WHERE bank_id = ? AND slot_code = ? AND locker_slot_id <> ?

**Mẫu `controller/LockerSlotController.java`**

```java
// src/java/controller/LockerSlotController.java
package controller;

import dao.AuditDao;
import dao.LockerBankDao;
import dao.LockerSlotDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.LockerSlot;
import model.User;
import util.Csv;
import util.Web;

@WebServlet(name = "LockerSlotController", urlPatterns = {"/LockerSlotController"})
public class LockerSlotController extends HttpServlet {

    private static final int PAGE_SIZE = 10;
    private static final Pattern SLOT_CODE = Pattern.compile("^[A-Za-z0-9_-]{1,20}$");
    private static final Set<String> STATUSES = new HashSet<>(Arrays.asList("AVAILABLE", "RESERVED", "OCCUPIED", "MAINTENANCE"));
    private static final Set<String> SIZES = new HashSet<>(Arrays.asList("S", "M", "L"));

    private final LockerSlotDao dao = new LockerSlotDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        String q = Web.trimmed(req, "q");
        Integer bankId = Web.optionalInt(req, "bankId");
        String status = Web.trimmed(req, "status");
        int total = dao.count(q, bankId, status);
        int pages = Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

        req.setAttribute("mode", "list");
        req.setAttribute("items", dao.search(q, bankId, status, page, PAGE_SIZE));
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("q", q);
        req.setAttribute("bankId", bankId);
        req.setAttribute("status", status);
        req.setAttribute("banks", new LockerBankDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    /** item holds what the form shows: blank values for a new slot, the typed values after a failed save. */
    private void showForm(HttpServletRequest req, HttpServletResponse res, LockerSlot item, boolean isNew)
            throws SQLException, ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.setAttribute("banks", new LockerBankDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    /** Sends the rows the user is looking at, not the whole table. */
    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        String q = Web.trimmed(req, "q");
        Integer bankId = Web.optionalInt(req, "bankId");
        String status = Web.trimmed(req, "status");
        List<String[]> rows = new ArrayList<>();
        for (LockerSlot s : dao.search(q, bankId, status, 1, Math.max(1, dao.count(q, bankId, status)))) {
            rows.add(new String[]{String.valueOf(s.getSlotId()), s.getBankCode(), s.getSlotCode(),
                s.getSizeCode(), s.getSizeCm(), s.getStatus()});
        }
        Csv.send(res, "slots.csv", new String[]{"slot_id", "bank", "slot_code", "size", "size_cm", "status"}, rows);
    }

    private LockerSlot readForm(HttpServletRequest req) {
        LockerSlot s = new LockerSlot();
        s.setSlotId(Web.intParam(req, "id", 0));
        s.setSlotCode(Web.trimmed(req, "slotCode"));
        s.setBankId(Web.intParam(req, "bankId", 0));
        s.setSizeCode(Web.trimmed(req, "sizeCode"));
        s.setSizeCm(Web.trimmed(req, "sizeCm"));
        s.setStatus(Web.trimmed(req, "status"));
        return s;
    }

    /** The browser checks only save a round trip; this is the check that counts. Returns null when valid. */
    private String validate(LockerSlot s) throws SQLException {
        if (!SLOT_CODE.matcher(s.getSlotCode()).matches()) {
            return "Slot code must be 1 to 20 letters, digits, - or _";
        }
        if (s.getBankId() <= 0) {
            return "Choose a bank";
        }
        if (!SIZES.contains(s.getSizeCode())) {
            return "Size must be S, M or L";
        }
        if (s.getSizeCm().length() > 20) {
            return "Size in cm is at most 20 characters";
        }
        if (!STATUSES.contains(s.getStatus())) {
            return "Status is not valid";
        }
        if (dao.codeExists(s.getBankId(), s.getSlotCode(), s.getSlotId())) {
            return "This bank already has a slot with the code " + s.getSlotCode();
        }
        return null;
    }

    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String action = Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                LockerSlot blank = new LockerSlot();
                blank.setSizeCode("S");
                blank.setStatus("AVAILABLE");
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                LockerSlot item = dao.findById(Web.intParam(req, "id", 0));
                if (item == null) {
                    Web.flash(req.getSession(), "That slot does not exist", true);
                    res.sendRedirect("LockerSlotController");
                    return;
                }
                showForm(req, res, item, false);
            } else if ("export".equals(action)) {
                export(req, res);
            } else {
                showList(req, res);
            }
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        try {
            if ("delete".equals(action)) {
                int id = Web.intParam(req, "id", 0);
                LockerSlot old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    new AuditDao().append(me.getUserId(), "DELETE", "LOCKERSLOT", id, old.getBankCode() + " " + old.getSlotCode());
                    Web.flash(req.getSession(), "Slot " + old.getSlotCode() + " deleted", false);
                } else {
                    Web.flash(req.getSession(), reason == null ? "Nothing was deleted" : reason, true);
                }
                res.sendRedirect("LockerSlotController");
                return;
            }

            LockerSlot s = readForm(req);
            String error = validate(s);
            if (error != null) {                        // show the form again with what the user typed
                req.setAttribute("error", error);
                showForm(req, res, s, s.getSlotId() == 0);
                return;
            }
            if ("create".equals(action)) {
                int id = dao.insert(s);
                new AuditDao().append(me.getUserId(), "CREATE", "LOCKERSLOT", id, s.getSlotCode());
                Web.flash(req.getSession(), "Slot " + s.getSlotCode() + " created", false);
            } else {
                dao.update(s);
                new AuditDao().append(me.getUserId(), "UPDATE", "LOCKERSLOT", s.getSlotId(), s.getSlotCode());
                Web.flash(req.getSession(), "Slot " + s.getSlotCode() + " saved", false);
            }
            res.sendRedirect("LockerSlotController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**: khung `doGet` chỉ forward tới trang trống để trang mở được; `doPost` ném `TODO`.

**Mẫu `views/lockerSlot.jsp`** (trang hoàn chỉnh, bạn đọc kỹ rồi dựa vào đó viết các trang khác)

```jsp
<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="slots"/>
<%-- The model of every CRUD page. One JSP, two modes: LockerSlotController sets mode = list or form.
     Attributes of the list: items, total, page, pages, q, bankId, status, banks.
     Attributes of the form: item, isNew, banks, and error after a failed save. --%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Slots</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add a slot' : 'Edit slot'}</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <%-- the browser checks save a round trip, the controller repeats every rule --%>
    <form class="form" method="post" action="${ctx}/LockerSlotController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.slotId}">

        <label for="bankId">Bank *</label>
        <select id="bankId" name="bankId" required>
            <option value="">-- Choose a bank --</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${item.bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>

        <label for="slotCode">Slot code *</label>
        <input type="text" id="slotCode" name="slotCode" value="<c:out value='${item.slotCode}'/>"
               required maxlength="20" pattern="[A-Za-z0-9_-]{1,20}" title="1 to 20 letters, digits, - or _">

        <label for="sizeCode">Size *</label>
        <select id="sizeCode" name="sizeCode" required>
            <option value="S" ${item.sizeCode == 'S' ? 'selected' : ''}>S, small</option>
            <option value="M" ${item.sizeCode == 'M' ? 'selected' : ''}>M, medium</option>
            <option value="L" ${item.sizeCode == 'L' ? 'selected' : ''}>L, large (two rows high on the map)</option>
        </select>

        <label for="sizeCm">Size in cm</label>
        <input type="text" id="sizeCm" name="sizeCm" value="<c:out value='${item.sizeCm}'/>" maxlength="20" placeholder="30x30x45">

        <label for="status">Status *</label>
        <select id="status" name="status" required>
            <c:forEach var="st" items="AVAILABLE,RESERVED,OCCUPIED,MAINTENANCE">
                <option value="${st}" ${item.status == st ? 'selected' : ''}>${st}</option>
            </c:forEach>
        </select>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/LockerSlotController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Slots (${total})</h2>

    <form class="filter" method="get" action="${ctx}/LockerSlotController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Slot code">
        <select name="bankId">
            <option value="">-- All banks --</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>
        <select name="status">
            <option value="">-- All statuses --</option>
            <c:forEach var="st" items="AVAILABLE,RESERVED,OCCUPIED,MAINTENANCE">
                <option value="${st}" ${status == st ? 'selected' : ''}>${st}</option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerSlotController">Clear</a>
        <%-- the controls of a role without WRITE are not drawn; the filter would refuse the request anyway --%>
        <c:if test="${perms.contains('LOCKERSLOT:WRITE')}"><a class="btn" href="${ctx}/LockerSlotController?action=new">Add slot</a></c:if>
        <c:url var="exportUrl" value="/LockerSlotController">
            <c:param name="action" value="export"/><c:param name="q" value="${q}"/>
            <c:param name="bankId" value="${bankId}"/><c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Bank</th><th>Slot</th><th>Size</th><th>Size (cm)</th><th class="c">Status</th><th>Actions</th></tr>
        <c:forEach var="s" items="${items}">
        <tr class="${s.status == 'MAINTENANCE' ? 'locked' : ''}">
            <td>${s.slotId}</td>
            <td><c:out value="${s.bankCode}"/></td>
            <td><c:out value="${s.slotCode}"/></td>
            <td>${s.sizeCode}</td>
            <td><c:out value="${s.sizeCm}"/></td>
            <td class="c">${s.status}</td>
            <td class="ops">
                <c:if test="${perms.contains('LOCKERSLOT:WRITE')}">
                    <a href="${ctx}/LockerSlotController?action=edit&amp;id=${s.slotId}">Edit</a>
                    <%-- never print data inside inline JavaScript: a quote in the data would break out of the string --%>
                    <form method="post" action="${ctx}/LockerSlotController" onsubmit="return confirm('Delete this slot?');">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${s.slotId}">
                        <button type="submit" class="link danger">Delete</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="c">No slot matches the filter</td></tr></c:if>
    </table>
    </div>

    <%-- c:url encodes every value, so a keyword with & or a space cannot break the link --%>
    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/LockerSlotController">
                        <c:param name="q" value="${q}"/><c:param name="bankId" value="${bankId}"/>
                        <c:param name="status" value="${status}"/><c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>
    </div>
</c:otherwise>

</c:choose>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
```

Đọc trang này theo thứ tự: khối `c:choose` chia hai chế độ; ô lọc giữ giá trị bằng `<c:out>`; nút "Add slot" chỉ hiện khi `perms.contains('LOCKERSLOT:WRITE')`; bảng `c:forEach`; xoá bằng `<form method="post">` chứ không bằng liên kết (liên kết GET không được đổi dữ liệu); phân trang bằng `c:url` + `c:param` để mã hoá giá trị (từ khoá có `&` hoặc khoảng trắng không phá liên kết).

**Tự kiểm tra** (sau khi `LockerBankDao.listAll` đã có, mục 6.2, vì form cần danh sách dãy):

| Việc | Kết quả đúng |
|---|---|
| Mở `LockerSlotController` bằng `admin` | Bảng 10 ngăn, `Slots (90)`, nút Add, Export CSV |
| Gõ `A0` vào ô tìm, lọc bank `LIB-A` | Chỉ ngăn của LIB-A có mã chứa `A0` |
| Trang 2 | Dòng khác, ô lọc vẫn giữ giá trị |
| Bấm Add, để trống mã, bấm Save | Trình duyệt chặn (`required`); nếu bỏ thuộc tính này thì controller báo lỗi và **giữ nguyên** các ô |
| Thêm `Z99` vào `LIB-A`, rồi thêm lại `Z99` | Lần hai báo "This bank already has a slot with the code Z99" |
| Xoá ngăn `A02` của `LIB-A` (đang có lượt gửi) | Báo lý do, ngăn vẫn còn |
| Đăng nhập `auditor1` | Thấy danh sách, **không** có nút Add, Edit, Delete |
| Bấm Export CSV | Tải `slots.csv`, mở bằng Excel đúng tiếng Việt |
| SSMS: `SELECT TOP 3 * FROM AuditLog ORDER BY audit_id DESC` | Có dòng `CREATE`, `DELETE` của `LOCKERSLOT` |

**Dễ sai**

- **Dữ liệu lấy từ người dùng không bao giờ in thẳng bằng `${...}` vào HTML hoặc vào JavaScript.** Mình đã gặp lỗi này ngay trong mã mẫu: `onsubmit="confirm('Delete slot ${s.slotCode}?')"` in mã ngăn vào chuỗi JavaScript; mã chứa dấu nháy sẽ phá chuỗi. Bản sửa không đưa dữ liệu vào đó.
- Quên `ORDER BY` khi dùng `OFFSET`: lỗi cú pháp.
- `FETCH NEXT ? ROWS`: tham số hoá được ở SQL Server 2012 trở lên.
- `s.bankId == b.bankId` trong EL so số với số; nếu `bankId` của bộ lọc là `null` thì kết quả `false`, không lỗi.
- Quên `<form method="post">` bao nút xoá: nút nằm ngoài form không gửi gì.

### 6.2 Bốn thực thể chép lại từ mẫu

Với mỗi thực thể, làm đúng thứ tự: **DAO** (cho `search` và `count` chạy trước, kiểm tra bằng `main`), rồi **controller**, rồi **JSP**. Sao chép `LockerSlot*` rồi đổi: tên bảng, cột, luật kiểm tra.

| Thực thể | Luật kiểm tra (controller) | Xoá bị từ chối khi |
|---|---|---|
| **Dãy tủ** `LockerBank` | Mã 2 đến 20 ký tự `A-Z 0-9 -`, duy nhất; tên 1 đến 40; khu bắt buộc; thiết bị không bắt buộc và **mỗi thiết bị chỉ thuộc một dãy**; số hàng cửa 1 đến 8 | Dãy còn ngăn tủ |
| **Khu** `LockerArea` | Mã 2 đến 16 ký tự `A-Z 0-9`, duy nhất; tên 2 đến 80; vị trí tối đa 120 | Khu còn dãy tủ hoặc còn người dùng |
| **Gói gửi** `StoragePlan` | Tên 1 đến 40; phút 1 đến 1440; ân hạn 0 đến 120; giá không âm | Gói đã có lượt gửi (nên bỏ chọn "đang dùng" thay vì xoá) |
| **Lượt gửi** `Deposit` (cho nhân viên) | Người dùng, ngăn **đang AVAILABLE**, gói bắt buộc; thẻ nếu chọn phải thuộc người đó | Lượt gửi còn mở (`RESERVED` hoặc `ACTIVE`) |

`LockerBankDao.listAll()` đã viết sẵn trong khung ở dạng mẫu vì `LockerSlotController` cần nó. Mẫu:

```java
// src/java/dao/LockerBankDao.java
package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import model.LockerBank;

public class LockerBankDao {

    public List<LockerBank> listAll() throws SQLException {
        String sql = "SELECT b.bank_id, b.bank_code, b.name, b.area_id, a.area_code, b.device_id, b.door_rows, b.status, "
                + "(SELECT COUNT(*) FROM LockerSlot s WHERE s.bank_id = b.bank_id) AS slot_count "
                + "FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id ORDER BY b.bank_code";
        List<LockerBank> items = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                LockerBank b = new LockerBank();
                b.setBankId(rs.getInt("bank_id"));
                b.setBankCode(rs.getString("bank_code"));
                b.setName(rs.getString("name"));
                b.setAreaId(rs.getInt("area_id"));
                b.setAreaCode(rs.getString("area_code"));
                int deviceId = rs.getInt("device_id");
                b.setDeviceId(rs.wasNull() ? null : deviceId);
                b.setDoorRows(rs.getInt("door_rows"));
                b.setStatus(rs.getString("status"));
                b.setSlotCount(rs.getInt("slot_count"));
                items.add(b);
            }
        }
        return items;
    }

    // ... the other methods are in your skeleton file
}
```

Danh sách việc của từng thực thể (đúng như trong khung):

**`dao/LockerBankDao`**

- `listAll()`: SELECT with the area code, ORDER BY bank_code
- `search(String keyword, Integer areaId, int page, int size)`: like LockerSlotDao.search: filter by code/name and area, OFFSET/FETCH
- `count(String keyword, Integer areaId)`: like LockerSlotDao.count
- `findById(int bankId)`: one bank by id
- `insert(LockerBank b)`: INSERT bank_code, name, area_id, device_id (nullable: use setNull), door_rows, status
- `update(LockerBank b)`: UPDATE the same columns
- `delete(int bankId)`: DELETE, catch 547 and return a readable reason
- `codeExists(String bankCode, int exceptBankId)`: SELECT COUNT(*) FROM LockerBank WHERE bank_code = ? AND bank_id <> ?

**`dao/LockerAreaDao`**

- `listAll()`: SELECT area columns, a subquery COUNT of slots (LockerBank join LockerSlot) and of users (Users.area_id)
- `findById(int areaId)`: one area by id
- `insert(LockerArea a)`: INSERT area_code, name, location, is_active with RETURN_GENERATED_KEYS
- `update(LockerArea a)`: UPDATE name, location, is_active; the code may change too
- `delete(int areaId)`: DELETE, catch 547 and return a readable reason
- `codeExists(String areaCode, int exceptAreaId)`: SELECT COUNT(*) FROM LockerArea WHERE area_code = ? AND area_id <> ?

**`dao/StoragePlanDao`**

- `listAll(boolean activeOnly)`: SELECT all plans ORDER BY duration_min, optionally WHERE is_active = 1
- `findById(int planId)`: one plan by id
- `insert(StoragePlan p)`: INSERT plan_name, duration_min, grace_min, price, is_active
- `update(StoragePlan p)`: UPDATE the same columns
- `delete(int planId)`: DELETE, catch 547 and return a readable reason

**`dao/DepositDao`** (tất cả các hàm; những hàm gọi thủ tục có mẫu ở mục 11.5)

- `reserve(int userId, int slotId, int planId)`: {call Deposit_Reserve(?, ?, ?, ?)} with a BIGINT OUTPUT parameter
- `cancel(long depositId, int userId)`: {call Deposit_Cancel(?, ?)}
- `extend(long depositId, int minutes, int userId)`: {call Deposit_Extend(?, ?, ?)} like cancel()
- `checkIn(int deviceId, String slotCode)`: {call Deposit_CheckIn(?, ?)}
- `complete(int deviceId, String slotCode)`: {call Deposit_Complete(?, ?)} like checkIn()
- `reservedFor(int deviceId)`: RESERVED deposits of the device with the uid of the card
- `listByUser(int userId)`: Deposit JOIN LockerSlot JOIN LockerBank JOIN StoragePlan WHERE user_id = ? ORDER BY reserved_at DESC
- `search(String keyword, String status, int page, int size)`: same joins as listByUser plus Users, optional filters, OFFSET/FETCH
- `count(String keyword, String status)`: SELECT COUNT(*) with the same filters
- `findById(long depositId)`: one deposit by id
- `insert(Deposit d)`: INSERT user_id, slot_id, plan_id, card_id, status, started_at, due_at; the slot becomes OCCUPIED in the same transaction
- `update(Deposit d)`: UPDATE plan_id, due_at, status
- `delete(long depositId)`: DELETE only when status is COMPLETED, NO_SHOW or CANCELLED

**Controller và trang** của bốn thực thể, theo mẫu của mục 6.1:

| Controller | Trang | Việc |
|---|---|---|
| `LockerBankController` | `lockerBank.jsp` | CRUD đầy đủ như `LockerSlotController` (danh sách, tìm, phân trang, form, xuất CSV, xoá có lý do, nhật ký, flash, redirect); riêng: ô lọc theo khu; ô chọn thiết bị chỉ liệt kê thiết bị chưa gắn dãy nào |
| `LockerAreaController` | `lockerArea.jsp` | CRUD đầy đủ như `LockerSlotController` (danh sách, tìm, phân trang, form, xuất CSV, xoá có lý do, nhật ký, flash, redirect); riêng: cột số ngăn và số người dùng của khu |
| `StoragePlanController` | `storagePlan.jsp` | CRUD đầy đủ như `LockerSlotController` (danh sách, tìm, phân trang, form, xuất CSV, xoá có lý do, nhật ký, flash, redirect); riêng: không cần phân trang |
| `DepositController` | `deposit.jsp` | CRUD đầy đủ như `LockerSlotController` (danh sách, tìm, phân trang, form, xuất CSV, xoá có lý do, nhật ký, flash, redirect); riêng: chọn ngăn từ danh sách ngăn đang AVAILABLE; tô dòng của lượt gửi quá hạn |

Mỗi trang JSP trong khung ghi rõ ở đầu file: thuộc tính controller đặt, bộ lọc, cột của bảng. Đọc phần chú thích đó trước khi viết.

**Tự kiểm tra**: mỗi thực thể qua đủ chín bước của bảng ở mục 6.1. Riêng xoá: thử xoá khu `LIB` (có dãy) thấy lý do, thử xoá khu vừa tạo (không dùng) thì xoá được.

### 6.3 Thẻ và gói: `UserCardDao`, `UserCardController`, `userCard.jsp`

Thẻ có thêm hai thao tác đặc biệt (báo mất, thay thẻ) thuộc trường hợp 3, làm ở mục 11.4. Phần CRUD của nhân viên:

**Luật kiểm tra**: `card_uid` 4 đến 32 ký tự hex (`0-9 A-F`), duy nhất (lỗi SQL 2627 thì báo "thẻ đã có"); người dùng bắt buộc; trạng thái `ACTIVE` hoặc `BLOCKED` (nhân viên khoá/mở thẻ); `LOST` chỉ đặt bằng thủ tục.

**`dao/UserCardDao`** (phần CRUD)

- `blockedUids()`: SELECT card_uid FROM UserCard WHERE status <> 'ACTIVE'
- `reportLost(int cardId, int actorId)`: {call UserCard_ReportLost(?, ?)}; the THROW text of the procedure is the SQLException message
- `replace(int oldCardId, String newUid, int actorId)`: {call UserCard_Replace(?, ?, ?, ?)} with an OUTPUT parameter
- `search(String keyword, String status, int page, int size)`: UserCard JOIN Users, optional keyword and status filters, OFFSET/FETCH
- `count(String keyword, String status)`: SELECT COUNT(*) with the same filters
- `listByUser(int userId)`: SELECT ... WHERE user_id = ? ORDER BY issued_at DESC
- `findById(int cardId)`: one card by id
- `insert(UserCard c)`: INSERT card_uid, user_id with RETURN_GENERATED_KEYS
- `setStatus(int cardId, String status)`: UPDATE UserCard SET status = ?

**`controller/UserCardController`**: GET: list cards with search/count, filter by status; action=new shows the issue form; POST: action=issue/block/unblock/replace: replace calls UserCardDao.replace and flashes the procedure message

### 6.4 Hiệu chuẩn: `CalibrationDao`, `CalibrationController`, `calibration.jsp`

**Đọc trước**: DE01 bảng `Calibration` và `SensorType` (WS1 B2).

**Việc**: kỹ thuật viên ghi nhận hiệu chuẩn cảm biến. **Mỗi lần hiệu chuẩn lại là một dòng mới** với `version` tăng dần; dòng cũ giữ làm lịch sử. Hiệu chuẩn `WEIGHT` hết hạn (`valid_until` đã qua) khiến mọi phiên mới bị coi là `SENSOR_FAULT` (trường hợp 5), nên trang cần tô đỏ dòng hết hạn.

**Luật kiểm tra**: thiết bị và loại cảm biến bắt buộc; `scale_val` lớn hơn 0; `valid_until` là ngày trong tương lai.

- `search(Integer deviceId, int page, int size)`: Calibration JOIN Device JOIN SensorType, ORDER BY device, sensor, version DESC, OFFSET/FETCH
- `count(Integer deviceId)`: SELECT COUNT(*) with the same filter
- `findById(int calibId)`: one row by id
- `insert(Calibration c)`: INSERT with version = ISNULL(MAX(version),0)+1 for the same device and sensor_type_id
- `update(Calibration c)`: UPDATE offset_val, scale_val, valid_until
- `delete(int calibId)`: DELETE; return a reason if it fails
- `sensorTypes()`: SELECT sensor_type_id, name FROM SensorType

**`controller/CalibrationController`**: CRUD như mục 6.1, lọc theo thiết bị, tô đỏ dòng hết hạn.

**Tự kiểm tra**: thêm hiệu chuẩn mới cho `LOCKER-01`, `WEIGHT`: `version` thành 2. Sửa `valid_until` của dòng mới nhất về ngày đã qua rồi gửi một phiên bằng `ScenarioSender` (mục 9): phiên thành `SENSOR_FAULT`.

### 6.5 Người dùng: `UserDao` (phần còn lại), `UserController`, `user.jsp`

**Đọc trước (quan trọng, đây là phần UserManagement làm tốt nhất)**

- OLD `controller/UserServlet.java`: `validate` (dòng 208), `canManage` (259), `delete`, `lock`, `reset`; OLD `dao/UserDAO.java`: `search`, `delete` có transaction (dòng 273); OLD `web/WEB-INF/views/userForm.jsp` và `userList.jsp`; OLD `controller/ExportServlet.java`.
- POUR `controller/UserManageController.java`: bản của bài mẫu chỉ kiểm tra "là ADMIN". Bản của bạn phải làm hơn: kiểm tra theo cấp vai trò.
- FE: `web/demo/users.html` và `user-form.html` là giao diện mà trang JSP cần giống.

**Luật** (kiểm tra ở controller; bản demo giao diện đã chạy đúng các luật này):

| Trường | Luật |
|---|---|
| Tên đăng nhập | 3 đến 50 ký tự `A-Z a-z 0-9 _ .`, duy nhất |
| Họ tên | 2 đến 80 ký tự (cột `full_name` là `NVARCHAR(80)`) |
| Email | Bắt buộc, đúng dạng `a@b.c`, duy nhất |
| Điện thoại | Không bắt buộc; nếu nhập thì 10 chữ số, bắt đầu bằng 0 |
| Vai trò | Phải tồn tại; trừ ADMIN, chỉ được cấp vai trò **thấp hơn** vai trò của mình |
| Khu | Không bắt buộc; nếu chọn thì phải đang hoạt động |
| Tự sửa mình | Không tự đổi vai trò, không tự khoá, không tự xoá |
| Sửa, khoá, đặt lại mật khẩu, xoá người khác | Chỉ khi vai trò người đó **thấp hơn** mình (`canManage`); **kiểm tra lại ở máy chủ** dù giao diện đã ẩn nút |

**Mẫu `UserController`**: các mẫu (`USERNAME`, `EMAIL`, `PHONE`, `canManage`, `validate`) đã viết; `doGet`/`doPost` là việc của bạn.

```java
// src/java/controller/UserController.java
package controller;

import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.regex.Pattern;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;

@WebServlet(name = "UserController", urlPatterns = {"/UserController"})
public class UserController extends HttpServlet {

    private static final Pattern USERNAME = Pattern.compile("^[A-Za-z0-9_.]{3,50}$");
    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final Pattern PHONE = Pattern.compile("^0[0-9]{9}$");

    /** The administrator manages everybody; any other role manages only roles that rank strictly below it. */
    static boolean canManage(User me, User target) {
        return "ADMIN".equals(me.getRoleName()) || target.getRoleRank() > me.getRoleRank();
    }

    /** Server side validation of the add and edit form. Returns the first problem, or null. */
    String validate(User me, User u, int exceptId, int roleRank) throws SQLException {
        UserDao dao = new UserDao();
        if (!USERNAME.matcher(u.getUsername()).matches()) {
            return "Username must be 3 to 50 characters: letters without accents, digits, _ and .";
        }
        if (u.getFullName().length() < 2 || u.getFullName().length() > 80) {
            return "Full name must have 2 to 80 characters";
        }
        if (!EMAIL.matcher(u.getEmail()).matches()) {
            return "Email is required and must look like name@domain";
        }
        if (!u.getPhone().isEmpty() && !PHONE.matcher(u.getPhone()).matches()) {
            return "Phone must be 10 digits and start with 0";
        }
        if (!"ADMIN".equals(me.getRoleName()) && roleRank <= me.getRoleRank()) {
            return "You can only give a role below your own";
        }
        if (dao.usernameExists(u.getUsername(), exceptId)) {
            return "Username " + u.getUsername() + " is already taken";
        }
        if (dao.emailExists(u.getEmail(), exceptId)) {
            return "Email " + u.getEmail() + " is already used";
        }
        return null;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm: `controller/UserController`**

- (the work is described in the comments of the file)

**Khung bạn làm: các hàm còn lại của `UserDao`** (cùng danh sách ở mục 5.6)

**Tự kiểm tra**: bảng sau; mỗi dòng đều phải đúng.

| Đăng nhập | Việc | Kết quả đúng |
|---|---|---|
| `operator1` | Mở danh sách | Thấy cả 16 tài khoản; chỉ các dòng vai trò thấp hơn (TECHNICIAN trở xuống) có nút Lock, Reset, Delete |
| `operator1` | Sửa `admin` bằng cách gõ `UserController?action=edit&id=2` | Bị từ chối |
| `operator1` | Thêm người với vai trò ADMIN | Báo "You can only give a role below your own" |
| `operator1` | Tự khoá mình | Không có nút; gửi tay bằng công cụ vẫn bị từ chối |
| `admin` | Xoá `student8` (chưa có lịch sử) | Xoá được |
| `admin` | Xoá `student1` (có thẻ và lượt gửi) | Báo lý do (khoá ngoại), tài khoản còn nguyên |
| `auditor1` | Mở danh sách | Xem được và xuất CSV; không có nút nào khác |

### 6.6 Vai trò và quyền: `RoleController`, `role.jsp`, `PermissionDao` (phần còn lại)

**Đọc trước**: OLD `web/WEB-INF/views/rolePermission.jsp` (bảng tick), OLD `controller/RoleServlet.java`; POUR `SmartWaterAuditdb_Procedures_Views_Bootstrap.sql` dòng 610 (`RolePerm_Grant_Batch`).

**Việc**: danh sách vai trò (cấp, số người, số quyền) và bảng tick quyền: mỗi hàng là một cặp (tài nguyên, READ/WRITE). Lưu = xoá hết quyền cũ của vai trò rồi thêm lại các ô được tick, **trong một transaction**. Quyền nằm trong bảng `RolePerm` nên đổi quyền có hiệu lực ngay ở yêu cầu kế tiếp, không cần đăng nhập lại (bộ lọc đọc quyền mỗi yêu cầu).

**Luật**: ADMIN không được bỏ `ROLE:READ` và `ROLE:WRITE` của chính mình (nếu không không ai trả lại quyền được).

- `loadKeys(int userId)`: one query over UserRole, RolePerm and Permissions
- `listRoles()`: Roles LEFT JOIN counts of UserRole and RolePerm, ORDER BY rank_no
- `permissionGrid(int roleId)`: Permissions LEFT JOIN RolePerm for this role, ORDER BY resource, action
- `saveRolePerms(int roleId, int[] permIds)`: DELETE FROM RolePerm WHERE role_id = ?, then batch INSERT, commit; rollback on error
- `roleName(int roleId)`: SELECT role_name FROM Roles WHERE role_id = ?

- `doPost(HttpServletRequest req, HttpServletResponse res)`: RoleController.doPost: action=savePerms&roleId=&permIds=...: PermissionDao.saveRolePerms; the administrator keeps ROLE:READ and ROLE:WRITE

**Tự kiểm tra**: `admin` bỏ tick `LOCKERSLOT:WRITE` của OPERATOR, lưu. `operator1` tải lại trang ngăn tủ: nút Add, Edit, Delete biến mất; gửi tay một POST thì 403. Tick lại: mọi thứ trở về.

**Cột mốc cuối giai đoạn 3**: sáu thực thể riêng và người dùng, vai trò đủ bốn thao tác; đều có tìm kiếm, phân trang, xuất CSV (ít nhất ở ngăn tủ và người dùng); mọi thao tác ghi để lại dòng trong `AuditLog`.

## 7. Giai đoạn 4: sơ đồ tủ theo khu

Đề yêu cầu "sơ đồ dãy tủ tô màu theo trạng thái, đặt ngăn trước, gia hạn trực tuyến, xác nhận mở tủ từ xa". Trang này gom cả bốn. Phần **giao diện (JavaScript, CSS)** đã làm xong: `web/js/locker-map.js`, `web/css/locker-map.css`. Việc của bạn là phía máy chủ: đưa đúng dữ liệu cho trang.

Trang là một cái vỏ rỗng; `locker-map.js` gọi `GET /api/locker-map?area=LIB` rồi vẽ, và tự gọi lại sau mỗi 10 giây. Vì vậy `LockerMapController` chỉ có việc forward.

### 7.1 Dữ liệu mà trang cần (hợp đồng JSON)

```json
{
  "areas": [{"area_code": "LIB", "name": "Library", "location": "Library, 1st floor",
             "slot_count": 20, "available": 15, "alert": 0, "live": true}],
  "area":  {"area_code": "LIB", "name": "Library", "location": "Library, 1st floor"},
  "plans": [{"plan_id": 1, "plan_name": "2 hours", "duration_min": 120, "price": 5000}],
  "banks": [{"bank_id": 1, "bank_code": "LIB-A", "name": "Bank A", "live": true,
             "device_status": "ACTIVE", "last_seen_sec": 4, "rows": 2,
             "slots": [{"slot_id": 2, "slot_code": "A02", "size": "S", "size_cm": "30x30x45",
                        "status": "OCCUPIED", "mine": true, "occupant": null, "deposit_id": 535,
                        "hold_until": null, "due_at": "2026-10-09T11:38:32Z",
                        "alert": null, "ticket_id": null}]}]
}
```

| Trường | Lấy từ đâu |
|---|---|
| `areas[]` | `LockerArea` với số ngăn, số ngăn trống, số cảnh báo, `live` = có dãy gắn thiết bị. Khu không có ngăn (OPS) bị bỏ |
| `banks[].live` | `LockerBank.device_id IS NOT NULL` (dãy vẽ minh hoạ thì `false`, giao diện hiện nhãn "Illustration" và không có nút thao tác) |
| `banks[].rows` | `LockerBank.door_rows`: số cửa trên một cột, để vẽ tủ |
| `slots[].status` | cột `display_status` của view `v_LockerSlotMap`: OFFLINE, MAINTENANCE, ALERT, OVERDUE, hoặc trạng thái của ngăn |
| `slots[].mine` | lượt gửi của ngăn thuộc người đang đăng nhập |
| `hold_until`, `due_at` | giờ UTC dạng `2026-10-09T11:38:32Z` (có chữ `Z`) |

**Phần máy chủ phải giấu theo vai trò** (làm ở máy chủ, không giấu trên giao diện):

| Trường | Locker User | Nhân viên (có `ALERT:READ`) |
|---|---|---|
| `occupant` (tên người dùng ngăn) | `null` | tên đăng nhập |
| `deposit_id` | chỉ của chính mình | có |
| `alert`, `ticket_id` | `null` | có |
| `areas[].alert` | 0 | số thật |

### 7.2 `dao/LockerMapDao.java`

**Đọc trước**: FE `SmartLocker-frontend\README.md` mục 4.2; `web/js/locker-map.js` phần đầu (hàm `normalize` cho biết trường nào có thể thiếu); bốn câu truy vấn đã chạy được trong `docs/demo-code/src/java/dao/LockerMapDao.java`.

**Việc của file**: bốn truy vấn, mỗi truy vấn ra một phần JSON: danh sách khu, gói, dãy của khu đang xem, ngăn của khu đang xem. Dùng `OUTER APPLY (SELECT TOP 1 ...)` để lấy cảnh báo và phiếu bảo trì đang mở của mỗi ngăn.

**Mẫu**

```java
// src/java/dao/LockerMapDao.java
package dao;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

public class LockerMapDao {

    /** "2026-10-09 10:56:40.1234567" from a DATETIME2 column becomes "2026-10-09T10:56:40Z". */
    private static String iso(String sqlText) {
        return sqlText == null ? null : sqlText.substring(0, 19).replace(' ', 'T') + "Z";
    }

    private static void put(JsonObject o, String key, String value) {
        if (value == null) {
            o.add(key, com.google.gson.JsonNull.INSTANCE);
        } else {
            o.addProperty(key, value);
        }
    }

    public JsonObject load(String areaCode, int userId, boolean staff) throws SQLException {
        JsonObject root = new JsonObject();
        try (Connection conn = DbContext.getConnection()) {

            // the menu: one row per area that has slots
            JsonArray areas = new JsonArray();
            String chosen = null;
            String areaSql = "SELECT a.area_code, a.name, a.location, COUNT(m.slot_id) AS slot_count, "
                    + "SUM(CASE WHEN m.display_status = N'AVAILABLE' THEN 1 ELSE 0 END) AS available, "
                    + "SUM(CASE WHEN m.display_status = N'ALERT' THEN 1 ELSE 0 END) AS alerts, "
                    + "MAX(CASE WHEN m.device_id IS NOT NULL THEN 1 ELSE 0 END) AS live "
                    + "FROM LockerArea a LEFT JOIN v_LockerSlotMap m ON m.area_id = a.area_id "
                    + "WHERE a.is_active = 1 GROUP BY a.area_code, a.name, a.location "
                    + "HAVING COUNT(m.slot_id) > 0 ORDER BY a.area_code";
            try (PreparedStatement ps = conn.prepareStatement(areaSql); ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    JsonObject a = new JsonObject();
                    a.addProperty("area_code", rs.getString("area_code"));
                    a.addProperty("name", rs.getString("name"));
                    put(a, "location", rs.getString("location"));
                    a.addProperty("slot_count", rs.getInt("slot_count"));
                    a.addProperty("available", rs.getInt("available"));
                    a.addProperty("alert", staff ? rs.getInt("alerts") : 0);
                    a.addProperty("live", rs.getInt("live") == 1);
                    areas.add(a);
                    String code = rs.getString("area_code");
                    if (chosen == null || code.equalsIgnoreCase(areaCode)) {
                        chosen = code;   // the first area, unless the page asked for another one
                    }
                }
            }
            root.add("areas", areas);
            if (chosen == null) {
                root.add("banks", new JsonArray());
                return root;
            }
            for (int i = 0; i < areas.size(); i++) {
                JsonObject a = areas.get(i).getAsJsonObject();
                if (a.get("area_code").getAsString().equals(chosen)) {
                    JsonObject current = new JsonObject();
                    current.addProperty("area_code", chosen);
                    current.add("name", a.get("name"));
                    current.add("location", a.get("location"));
                    root.add("area", current);
                }
            }

            // the booking form needs the plans
            JsonArray plans = new JsonArray();
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT plan_id, plan_name, duration_min, price FROM StoragePlan WHERE is_active = 1 ORDER BY duration_min");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    JsonObject p = new JsonObject();
                    p.addProperty("plan_id", rs.getInt(1));
                    p.addProperty("plan_name", rs.getString(2));
                    p.addProperty("duration_min", rs.getInt(3));
                    p.addProperty("price", rs.getInt(4));
                    plans.add(p);
                }
            }
            root.add("plans", plans);

            // the banks of the chosen area
            JsonArray banks = new JsonArray();
            Map<Integer, JsonArray> slotsOfBank = new HashMap<>();
            String bankSql = "SELECT b.bank_id, b.bank_code, b.name, b.device_id, b.door_rows, v.status AS device_status, "
                    + "DATEDIFF(SECOND, v.last_seen, SYSUTCDATETIME()) AS last_seen_sec "
                    + "FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id LEFT JOIN Device v ON v.device_id = b.device_id "
                    + "WHERE a.area_code = ? AND b.status = N'ACTIVE' ORDER BY b.bank_code";
            try (PreparedStatement ps = conn.prepareStatement(bankSql)) {
                ps.setString(1, chosen);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        JsonObject b = new JsonObject();
                        b.addProperty("bank_id", rs.getInt("bank_id"));
                        b.addProperty("bank_code", rs.getString("bank_code"));
                        b.addProperty("name", rs.getString("name"));
                        rs.getInt("device_id");
                        boolean live = !rs.wasNull();
                        b.addProperty("live", live);
                        put(b, "device_status", rs.getString("device_status"));
                        int seen = rs.getInt("last_seen_sec");
                        if (rs.wasNull()) {
                            b.add("last_seen_sec", com.google.gson.JsonNull.INSTANCE);
                        } else {
                            b.addProperty("last_seen_sec", seen);
                        }
                        b.addProperty("rows", rs.getInt("door_rows"));
                        JsonArray slots = new JsonArray();
                        b.add("slots", slots);
                        slotsOfBank.put(rs.getInt("bank_id"), slots);
                        banks.add(b);
                    }
                }
            }
            root.add("banks", banks);

            // the slots: status from the view, the booking on it, the open alert and ticket
            String slotSql = "SELECT m.slot_id, m.slot_code, m.size_code, m.size_cm, m.bank_id, m.display_status, "
                    + "d.deposit_id, d.user_id, u.username, CONVERT(VARCHAR(27), d.hold_until, 121) AS hold_until, "
                    + "CONVERT(VARCHAR(27), d.due_at, 121) AS due_at, al.alert_id, al.label AS alert_label, tk.ticket_id "
                    + "FROM v_LockerSlotMap m "
                    + "JOIN LockerArea a ON a.area_id = m.area_id "
                    + "LEFT JOIN Deposit d ON d.slot_id = m.slot_id AND d.status IN (N'RESERVED', N'ACTIVE') "
                    + "LEFT JOIN Users u ON u.user_id = d.user_id "
                    + "OUTER APPLY (SELECT TOP 1 x.alert_id, x.label FROM Alert x JOIN LockerSession ls ON ls.session_id = x.session_id "
                    + "             WHERE ls.slot_id = m.slot_id AND x.status = N'OPEN' ORDER BY x.alert_id DESC) al "
                    + "OUTER APPLY (SELECT TOP 1 t.ticket_id FROM MaintenanceTicket t JOIN Alert x ON x.alert_id = t.alert_id "
                    + "             JOIN LockerSession ls ON ls.session_id = x.session_id "
                    + "             WHERE ls.slot_id = m.slot_id AND t.status = N'OPEN' ORDER BY t.ticket_id DESC) tk "
                    + "WHERE a.area_code = ? ORDER BY m.bank_code, m.slot_code";
            try (PreparedStatement ps = conn.prepareStatement(slotSql)) {
                ps.setString(1, chosen);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        JsonArray target = slotsOfBank.get(rs.getInt("bank_id"));
                        if (target == null) {
                            continue;   // a bank that is not ACTIVE
                        }
                        JsonObject s = new JsonObject();
                        s.addProperty("slot_id", rs.getInt("slot_id"));
                        s.addProperty("slot_code", rs.getString("slot_code"));
                        s.addProperty("size", rs.getString("size_code"));
                        put(s, "size_cm", rs.getString("size_cm"));
                        s.addProperty("status", rs.getString("display_status"));
                        int owner = rs.getInt("user_id");
                        boolean hasOwner = !rs.wasNull();
                        boolean mine = hasOwner && owner == userId;
                        s.addProperty("mine", mine);
                        put(s, "occupant", staff && hasOwner ? rs.getString("username") : null);
                        long depositId = rs.getLong("deposit_id");
                        boolean hasDeposit = !rs.wasNull();
                        if (hasDeposit && (mine || staff)) {
                            s.addProperty("deposit_id", depositId);
                        } else {
                            s.add("deposit_id", com.google.gson.JsonNull.INSTANCE);
                        }
                        put(s, "hold_until", iso(rs.getString("hold_until")));
                        put(s, "due_at", iso(rs.getString("due_at")));
                        int alertId = rs.getInt("alert_id");
                        if (staff && !rs.wasNull()) {
                            JsonObject alert = new JsonObject();
                            alert.addProperty("alert_id", alertId);
                            alert.addProperty("label", rs.getString("alert_label"));
                            s.add("alert", alert);
                        } else {
                            s.add("alert", com.google.gson.JsonNull.INSTANCE);
                        }
                        int ticketId = rs.getInt("ticket_id");
                        if (staff && !rs.wasNull()) {
                            s.addProperty("ticket_id", ticketId);
                        } else {
                            s.add("ticket_id", com.google.gson.JsonNull.INSTANCE);
                        }
                        target.add(s);
                    }
                }
            }
        }
        return root;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `load(String areaCode, int userId, boolean staff)`: four queries: areas, plans, banks of the area, slots of the area; the JSON matches the frontend

**Dễ sai**

- `rs.getInt("device_id")` rồi `rs.wasNull()`: chỉ gọi `wasNull()` **ngay sau** cột vừa đọc.
- Đổi `DATETIME2` sang giờ UTC có `Z`: dùng `CONVERT(VARCHAR(27), cột, 121)` ở SQL rồi cắt 19 ký tự. Đọc `getTimestamp` rồi định dạng bằng Java dễ lệch múi giờ của máy chủ.
- Quên `HAVING COUNT(m.slot_id) > 0`: khu OPS không có ngăn hiện ra trên menu.
- Gửi `occupant` cho Locker User: lộ tên người khác. Kiểm tra bằng cách đăng nhập `student1` và xem JSON.

### 7.3 `api/LockerMapApi.java` và `controller/LockerMapController.java`

**Mẫu**

```java
// src/java/api/LockerMapApi.java
package api;

import dao.LockerMapDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Set;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

@WebServlet(name = "LockerMapApi", urlPatterns = {"/api/locker-map"})
public class LockerMapApi extends HttpServlet {

    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        User me = Web.currentUser(req);
        @SuppressWarnings("unchecked")
        Set<String> keys = (Set<String>) req.getAttribute("perms");   // put there by SecurityFilter
        boolean staff = keys != null && keys.contains("ALERT:READ");  // staff may see names, alerts and tickets
        try {
            String json = new LockerMapDao().load(Web.trimmed(req, "area"), me.getUserId(), staff).toString();
            res.setContentType("application/json;charset=UTF-8");
            res.setHeader("Cache-Control", "no-store");
            res.getWriter().write(json);
        } catch (SQLException e) {
            log("Locker map failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }

    // ... the other methods are in your skeleton file
}
```

```java
// src/java/controller/LockerMapController.java
package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

@WebServlet(name = "LockerMapController", urlPatterns = {"/LockerMapController"})
public class LockerMapController extends HttpServlet {

    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        req.getRequestDispatcher("/WEB-INF/views/lockerMap.jsp").forward(req, res);
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `doGet(HttpServletRequest req, HttpServletResponse res)`: the role decides how much the JSON tells; the filter has already checked MAP:READ

`LockerMapApi` đọc `perms` do bộ lọc đặt để biết người này có phải nhân viên (có `ALERT:READ`). **Không** đặt `/api/locker-map` vào `DEVICE_API_PATHS`: đây là API của người dùng đã đăng nhập, dùng phiên chứ không dùng khoá API.

### 7.4 `views/lockerMap.jsp`, `js/locker-map.js`, `css/locker-map.css`

Đã hoàn chỉnh. `lockerMap.jsp` chỉ có một thẻ `<main id="lockerApp" data-api="..." data-role="...">` và hai thẻ `<script>`. Cho biết các đường dẫn biểu mẫu qua `data-booking-url`, `data-command-url`, `data-alert-url`, `data-ticket-url`.

Các biểu mẫu trong khung chi tiết ngăn gửi lên:

| Người dùng | Tới | Trường |
|---|---|---|
| Locker User, ngăn trống | `BookingController` | `action=reserve`, `slotId`, `planId`, `area`, `slot` |
| Locker User, ngăn của mình đang giữ chỗ | `BookingController` | `action=cancel`, `depositId`, ... |
| Locker User, ngăn của mình đang dùng | `BookingController` | `action=extend`, `depositId`, `minutes` |
| ADMIN, OPERATOR | `RemoteCommandController` | `slotId`, `reason`, `area`, `slot` |

Sau mỗi POST các controller redirect về `LockerMapController?area=...&slot=...`, nên trang mở lại đúng ngăn đó và hiện thông báo (flash).

**Tự kiểm tra** (cột mốc của giai đoạn 4)

1. Đăng nhập `student1`, mở trang bản đồ: menu bên trái có Library, Dormitory A, Canteen, Sports Hall. Library có nhãn **Live**.
2. Bấm Library, thấy dãy `LIB-A` (4 ngăn: A02 viền "You") và `LIB-B` (nhãn Illustration).
3. Bấm một ngăn trống của `LIB-A`: thấy form **Reserve**. Chưa viết `BookingController.doPost` thì bấm sẽ báo lỗi 500 `TODO`: đúng.
4. Mở `/SmartLocker/api/locker-map?area=LIB` trong cùng trình duyệt: JSON đúng hợp đồng; `occupant` là `null` với `student1`.
5. Đăng nhập `operator1`: cùng địa chỉ cho `occupant` = `student1` ở A02.
6. Trên điện thoại hoặc thu hẹp cửa sổ: khung chi tiết trượt từ dưới lên.

Giá trị mong đợi với dữ liệu mẫu mới tạo: Library `slot_count 20`, `available 15`; Canteen 15 trên 15; Dormitory A 30 trên 30; Sports Hall 25 trên 25.

## 8. Giai đoạn 5: nhật ký chống sửa

Mục tiêu: mọi thao tác ghi dữ liệu để lại một dòng trong `AuditLog`, các dòng nối nhau bằng mã băm. Sửa tay một dòng trong SSMS thì chuỗi "đứt" và chương trình chỉ đúng dòng bị sửa.

### 8.1 Cách chuỗi băm hoạt động

`Audit_Append` làm, trong một transaction:

1. Chèn dòng vào `AuditLog` và lấy `audit_id`, `ts`.
2. Khoá đuôi chuỗi (`WITH (UPDLOCK, HOLDLOCK)`) lấy `chain_hash` của dòng trước (dòng đầu dùng 64 ký tự `0`). Khoá này ngăn hai thao tác ghi cùng lúc làm chuỗi rẽ nhánh.
3. Dựng chuỗi: `id|ts|actor|action|objectType|objectId|diff|prevHash`, với `ts` là `CONVERT(NVARCHAR(33), ts, 126)` tức dạng `2026-10-09T15:25:40.3907024`.
4. Băm SHA-256 chuỗi đó, lưu vào `AuditLog.row_hash` và `HashChain.chain_hash`.

Muốn sửa một dòng mà không bị phát hiện, kẻ sửa phải tính lại mã băm của **mọi dòng sau nó**. Bộ kiểm tra tính lại cả chuỗi từ đầu và so từng dòng.

Hai chi tiết quyết định đúng sai:

- **`NVARCHAR` được SQL Server băm theo UTF-16 little endian**, nên Java phải băm `text.getBytes("UTF-16LE")`. Dùng UTF-8 thì mọi dòng đều "bị sửa".
- **Thời gian**: để SQL tự chuyển `ts` ra chữ (`CONVERT ... 126`) rồi Java lấy nguyên chuỗi đó. Đọc `Timestamp` rồi định dạng lại bằng Java mất độ chính xác 100 nano giây và sai (bài mẫu POUR mất công làm việc này trong `ChainVerificationService`, dòng `TS_FMT`; bản của chúng ta tránh được).

### 8.2 `service/AuditVerifier.java`

**Đọc trước**: DE01 WS2 B4 (mã `AuditVerifier`); POUR `service/ChainVerificationService.java` (khác ở chỗ: bài mẫu có hai mã băm cho mỗi dòng và đánh dấu mọi dòng sau chỗ đứt là hỏng, hiệu ứng domino).

**Việc của file**: tính lại chuỗi. Tách làm hai: `findFirstBroken(List<Row>)` thuần Java (dễ kiểm thử, không cần database) và `loadRows()` đọc từ database.

**Mẫu**

```java
// src/java/service/AuditVerifier.java
package service;

import dao.DbContext;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

public class AuditVerifier {

    /** SQL Server hashes an NVARCHAR as UTF-16 little endian, so Java must hash the same bytes. */
    private static final Charset UTF16LE = Charset.forName("UTF-16LE");

    private static String toHex(byte[] bytes) {   // Java 8 has no HexFormat
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    public static long findFirstBroken(List<Row> rows) {
        String prevHash = ZERO_HASH;
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (Row r : rows) {
                String text = r.auditId + "|" + r.tsText + "|" + r.actor + "|" + r.action + "|" + r.objectType + "|"
                        + r.objectId + "|" + r.diff + "|" + prevHash;
                String expected = toHex(digest.digest(text.getBytes(UTF16LE)));
                if (!prevHash.equals(r.prevHash) || !expected.equals(r.chainHash)) {
                    return r.auditId;
                }
                prevHash = expected;
            }
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
        return -1;
    }

    public static List<Row> loadRows() throws SQLException {
        String sql = "SELECT a.audit_id, CONVERT(NVARCHAR(33), a.ts, 126), a.actor_user_id, a.action, a.object_type, "
                + "a.object_id, ISNULL(a.diff_json, N''), h.prev_hash, h.chain_hash "
                + "FROM AuditLog a JOIN HashChain h ON h.audit_id = a.audit_id ORDER BY h.anchor_id";
        List<Row> rows = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                rows.add(new Row(rs.getLong(1), rs.getString(2), rs.getInt(3), rs.getString(4), rs.getString(5),
                        rs.getLong(6), rs.getString(7), rs.getString(8), rs.getString(9)));
            }
        }
        return rows;
    }

    public static long findFirstBroken() throws SQLException {
        return findFirstBroken(loadRows());
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**: lớp `Row` và hằng `ZERO_HASH` có sẵn trong khung vì bài kiểm thử dùng.

- `findFirstBroken(List<Row> rows)`: walk the chain in order: the link to the previous row, then the recomputed hash
- `loadRows()`: the query converts ts to text in SQL and turns NULL into an empty diff
- `findFirstBroken()`

**Đã kiểm chứng**: mình chạy `Audit_Append` 22 lần trên SQL Server thật (có dòng `diff` rỗng), đưa các dòng vào bộ kiểm tra Java: báo chuỗi nguyên vẹn. Sửa dòng 7 bằng `UPDATE AuditLog SET action = ...` rồi chạy lại: báo `audit_id = 7`.

### 8.3 `dao/AuditDao.java` (phần danh sách), `controller/AuditController.java`, `views/audit.jsp`

**Việc**: trang danh sách nhật ký (mới nhất trước, lọc theo hành động, phân trang) và nút **Verify chain** (`?action=verify`). Nút gọi `AuditVerifier.findFirstBroken()` rồi hiện kết quả: "chuỗi nguyên vẹn" hoặc "dòng #7 bị sửa".

- `append(int actorId, String action, String objectType, long objectId, String diff)`: CallableStatement {call Audit_Append(?,?,?,?,?)}
- `search(String action, int page, int size)`: AuditLog JOIN Users (actor name), optional WHERE action = ?, ORDER BY audit_id DESC OFFSET/FETCH
- `count(String action)`: SELECT COUNT(*) FROM AuditLog with the same optional filter
- `actions()`: SELECT DISTINCT action FROM AuditLog ORDER BY action

- (the work is described in the comments of the file)

Trang `audit.jsp` trong khung ghi sẵn thuộc tính controller đặt và các cột.

**Tự kiểm tra**

| Việc | Kết quả đúng |
|---|---|
| `auditor1` mở trang, bấm Verify chain | Báo nguyên vẹn |
| Trong SSMS: `UPDATE AuditLog SET action = N'TAMPERED' WHERE audit_id = 3;` rồi Verify | Báo dòng 3 |
| Khôi phục giá trị cũ của dòng đó, Verify | Lại nguyên vẹn |
| `student1` mở `AuditController` | 403 |

Ghi lại giá trị `action` ban đầu trước khi sửa. Nếu quên, chạy lại `01_schema.sql` để tạo lại dữ liệu.

### 8.4 `test/test/AuditChainDatabaseIntegrationTest.java`

**Đọc trước**: POUR `test/test/AuditChainDatabaseIntegrationTest.java`: bài mẫu cũng sửa thẳng một dòng thành `TAMPERED-BY-TESTNG` rồi kiểm tra bị phát hiện. Đề đòi "ca phát hiện sửa trái phép nhật ký kiểm toán".

**Mẫu**: hai test **không cần database** (chuỗi dựng trong bộ nhớ) và hai test chạm database thật, bị bỏ qua (`SkipException`) trên máy không có `PRJ301_LOCKER`. Test thứ hai chạm database luôn khôi phục dòng đã sửa trong `finally`.

```java
package test;

import static org.testng.Assert.assertEquals;

import dao.DbContext;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import org.testng.SkipException;
import org.testng.annotations.Test;
import service.AuditVerifier;
import service.AuditVerifier.Row;

/**
 * The tamper-evident log: a chain that is intact verifies, a row that was edited is found.
 * The first two tests need no database. The last two run against PRJ301_LOCKER and are skipped when it is not there.
 */
public class AuditChainDatabaseIntegrationTest {

    private static final Charset UTF16LE = Charset.forName("UTF-16LE");

    private static String sha256(String text) throws Exception {
        StringBuilder sb = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(text.getBytes(UTF16LE))) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /** Builds a valid chain of n rows the way Audit_Append does. */
    private static List<Row> chainOf(int n) throws Exception {
        List<Row> rows = new ArrayList<Row>();
        String prev = AuditVerifier.ZERO_HASH;
        for (int i = 1; i <= n; i++) {
            String ts = "2026-10-09T10:00:0" + i + ".1234567";
            String text = i + "|" + ts + "|1|ACTION" + i + "|USER|" + i + "||" + prev;
            String hash = sha256(text);
            rows.add(new Row(i, ts, 1, "ACTION" + i, "USER", i, "", prev, hash));
            prev = hash;
        }
        return rows;
    }

    @Test
    public void anIntactChainVerifies() throws Exception {
        assertEquals(AuditVerifier.findFirstBroken(chainOf(5)), -1L);
    }

    @Test
    public void anEditedRowIsFoundAtTheRowThatWasEdited() throws Exception {
        List<Row> rows = chainOf(5);
        rows.get(2).action = "TAMPERED-BY-TESTNG";          // somebody edits row 3 in SSMS
        assertEquals(AuditVerifier.findFirstBroken(rows), 3L);
    }

    // ---- against the real database ----

    /** A SkipException marks the test as skipped, not failed, on a machine where the database is not installed. */
    private static void skipWithoutDatabase() {
        try (Connection conn = DbContext.getConnection()) {
            if (conn == null || conn.isClosed()) {
                throw new SkipException("No database connection");
            }
        } catch (SQLException e) {
            throw new SkipException("PRJ301_LOCKER is not available: " + e.getMessage());
        }
    }

    @Test
    public void theRealLogIsIntactBeforeAnyTampering() throws Exception {
        skipWithoutDatabase();
        assertEquals(AuditVerifier.findFirstBroken(), -1L);
    }

    @Test(dependsOnMethods = "theRealLogIsIntactBeforeAnyTampering")
    public void tamperingWithARealRowIsDetectedAndUndone() throws Exception {
        skipWithoutDatabase();
        List<Row> rows = AuditVerifier.loadRows();
        if (rows.isEmpty()) {
            throw new SkipException("The log is empty, sign in once first");
        }
        long target = rows.get(rows.size() - 1).auditId;
        String original = rows.get(rows.size() - 1).action;
        try {
            update(target, "TAMPERED-BY-TESTNG");
            assertEquals(AuditVerifier.findFirstBroken(), target);
        } finally {
            update(target, original);                       // always put it back
        }
        assertEquals(AuditVerifier.findFirstBroken(), -1L);
    }

    private static void update(long auditId, String action) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("UPDATE AuditLog SET action = ? WHERE audit_id = ?")) {
            ps.setString(1, action);
            ps.setLong(2, auditId);
            ps.executeUpdate();
        }
    }
}
```

**Khung bạn làm**: khung có `chainOf` và test đầu; danh sách còn lại là `TODO`.

**Cột mốc cuối giai đoạn 5**: hai test không cần database xanh; nút Verify đúng với dòng bị sửa.

## 9. Giai đoạn 6: API cho thiết bị

Mục tiêu: `ScenarioSender` (giả lập ESP32) gửi nhịp tim và phiên lên, server nhận và phản hồi. Khi ESP32 thật sẵn sàng, nó gửi **cùng JSON đó** nên phía web không phải sửa.

### 9.1 Hai API và nguyên tắc

| API | Ai gọi, khi nào | Làm gì |
|---|---|---|
| `POST /api/health` | Thiết bị, mỗi 10 giây | Cập nhật `last_seen`, báo ngăn nào đang có đồ, **nhận lại** lệnh mở, thẻ bị chặn, ngăn đã đặt |
| `POST /api/locker/batch` | Thiết bị, sau mỗi phiên hoặc khi có mạng lại | Gửi một **mảng** phiên (bộ đệm lúc mất mạng) |

Nguyên tắc thiết kế (đáng nói với thầy):

- **Máy chủ không bao giờ gọi thiết bị**: mọi thứ máy chủ muốn nói với thiết bị nằm trong phản hồi của nhịp tim. Bài mẫu POUR gọi thẳng `http://192.168.4.1/pour` từ `PourController`, đổi mạng là hỏng; cách của ta không cần biết địa chỉ IP của thiết bị và giả lập được khi chưa có phần cứng.
- **`device_id` lấy từ khoá API**, đặt vào `request` bởi `SecurityFilter`. Số thiết bị nằm trong nội dung bị bỏ qua: thiết bị A không thể giả làm thiết bị B.
- **Gửi lại an toàn** (idempotent): `UNIQUE (device_id, device_seq)` làm phiên trùng bị bỏ qua. Thiết bị không chắc đã gửi được hay chưa thì cứ gửi lại.
- **HTTP 500 khi cơ sở dữ liệu lỗi** để thiết bị giữ bộ đệm và gửi lại; **HTTP 200 kèm `rejected`** cho phiên sai dạng (lỗi vĩnh viễn, gửi lại cũng vô ích).

### 9.2 Hợp đồng JSON (đưa cho người làm firmware)

Nhịp tim:

```json
POST /api/health        header  X-API-Key: device-1-api-key
{"firmware": "1.2", "slots": [{"slot_code": "A01", "occupied": true}, {"slot_code": "A02", "occupied": false}]}

200 {"commands": [{"command_id": 15, "slot_code": "A01", "action": "UNLOCK"}],
     "blocked_cards": ["04A1B2C3"],
     "reserved": [{"slot_code": "A04", "card_uid": "0499AABB"}]}
```

Phiên:

```json
POST /api/locker/batch  header  X-API-Key: device-1-api-key
{"sessions": [{"seq": 101, "measured_at": "2026-10-15 03:15:20", "door_open_sec": 6.5,
               "weight_delta_g": 2.0, "unlock_count": 2, "rfid_ok": true, "stay_min": 42.0,
               "slot_code": "A01", "card_uid": "04A1B2C3", "open_source": "RFID", "command_id": null}]}

200 {"saved": 1, "duplicates": 0, "rejected": 0}
```

- `measured_at`: giờ **UTC**, định dạng `yyyy-MM-dd HH:mm:ss`, thời điểm kết thúc phiên.
- `rfid_ok`: `true` hoặc `false`. Nhưng máy chủ vẫn chấp nhận `1.0` (xem "Dễ sai").
- `weight_delta_g`: khối lượng còn trong ngăn so với lúc trống; lấy hết đồ thì gần 0.
- `open_source`: `RFID` (mặc định) hoặc `REMOTE`; với `REMOTE` thì `command_id` là số của lệnh vừa nhận.

### 9.3 `dao/DeviceDao.java`

**Đọc trước**: POUR `dao/DeviceDAO.java` (cách bài mẫu cập nhật trạng thái thiết bị, qua thủ tục `Device_UpdateStatus_User`).

**Mẫu**

```java
// src/java/dao/DeviceDao.java
package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import model.Device;
import util.SecurityUtils;

public class DeviceDao {

    public Integer findIdByApiKey(String apiKey) throws SQLException {
        if (apiKey == null || apiKey.isEmpty()) {
            return null;
        }
        String sql = "SELECT device_id FROM Device WHERE api_key_hash = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, SecurityUtils.sha256Hex(apiKey));
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : null;
            }
        }
    }

    public void heartbeat(int deviceId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Device_Heartbeat(?)}")) {
            cs.setInt(1, deviceId);
            cs.execute();
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `findIdByApiKey(String apiKey)`: hash the key with SecurityUtils.sha256Hex and compare with Device.api_key_hash
- `heartbeat(int deviceId)`: {call Device_Heartbeat(?)}
- `listAll()`: SELECT device columns, DATEDIFF(SECOND, last_seen, SYSUTCDATETIME()) AS last_seen_sec
- `setStatus(int deviceId, String status)`: UPDATE Device SET status = ? WHERE device_id = ?; refuse any status but ACTIVE or MAINTENANCE

### 9.4 `api/HealthApi.java`

**Đọc trước**: POUR `controller/HealthAPI.java` (bài mẫu chỉ ghi sức khoẻ cảm biến; bản của ta mở rộng thành nhịp tim hai chiều).

**Mẫu**

```java
// src/java/api/HealthApi.java
package api;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import dao.DepositDao;
import dao.DeviceDao;
import dao.RemoteCommandDao;
import dao.UserCardDao;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

@WebServlet(name = "HealthApi", urlPatterns = {"/api/health"})
public class HealthApi extends HttpServlet {

    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");   // set by SecurityFilter from the API key
        JsonElement parsed = JsonParser.parseReader(req.getReader());
        JsonObject body = parsed.isJsonObject() ? parsed.getAsJsonObject() : new JsonObject();
        JsonObject reply = new JsonObject();
        Gson gson = new Gson();
        try {
            new DeviceDao().heartbeat(deviceId);                                                    // case 1
            DepositDao deposits = new DepositDao();
            if (body.has("slots")) {
                for (JsonElement element : body.getAsJsonArray("slots")) {
                    JsonObject slot = element.getAsJsonObject();
                    if (slot.get("occupied").getAsBoolean()) {
                        deposits.checkIn(deviceId, slot.get("slot_code").getAsString());            // case 4
                    }
                }
            }
            reply.add("commands", gson.toJsonTree(new RemoteCommandDao().takePending(deviceId)));   // case 2
            reply.add("blocked_cards", gson.toJsonTree(new UserCardDao().blockedUids()));          // case 3
            reply.add("reserved", gson.toJsonTree(deposits.reservedFor(deviceId)));                 // case 4
        } catch (SQLException e) {
            log("Heartbeat failed for device " + deviceId, e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            return;
        } catch (RuntimeException bad) {                     // wrong JSON shape: the device's mistake, not ours
            res.sendError(HttpServletResponse.SC_BAD_REQUEST, "Bad heartbeat body");
            return;
        }
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write(reply.toString());
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**: khung trả 501 Not Implemented.

- `doPost(HttpServletRequest req, HttpServletResponse res)`: heartbeat, check-in of occupied slots, then the reply for cases 2, 3 and 4

### 9.5 `dao/LockerSessionDao.java` và `api/LockerSessionApi.java`

**Đọc trước**: DE01 WS2 B3 (`LockerSessionApi`, `LockerSessionDao.insert`); POUR `controller/PourAPI.java` (nhận cả lô, lưu trước, chấm điểm sau).

**Việc**: `LockerSessionApi.doPost` lặp qua từng phiên: đọc, lưu, đánh giá, trả ngăn.

Điểm khác với mã mẫu của đề, mỗi điểm là một lỗi thật:

| Lỗi trong mã mẫu của đề | Hậu quả | Cách của ta |
|---|---|---|
| `DataReplayer` gửi `"rfid_ok":1.0`, rồi `getAsBoolean()` đọc `1.0` thành `false` | Mọi phiên phát lại bị coi là không có thẻ, sinh hàng loạt `FORCED_OPEN`. Đã kiểm chứng bằng Gson | `readBool` chấp nhận cả `true` và số; `DataReplayer` gửi `rs.getBoolean` |
| Giờ định dạng theo máy (UTC+7), server ghi UTC | Lệch 7 tiếng | Thiết bị và `DataReplayer` gửi UTC |
| `catch (SQLException duplicate)` coi mọi lỗi SQL là trùng | Lỗi thật bị nuốt, phiên mất | Chỉ lỗi 2627 và 2601 là trùng; lỗi khác ném tiếp |
| Tin `device_id` trong nội dung | Giả mạo thiết bị | Dùng `DEVICE_ID` từ khoá |

**Mẫu `LockerSessionDao`**

```java
// src/java/dao/LockerSessionDao.java
package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.List;
import java.util.Map;
import model.LockerSession;

public class LockerSessionDao {

    public long insert(LockerSession s) throws SQLException {
        String sql = "INSERT INTO LockerSession (device_id, device_seq, measured_at, door_open_sec, weight_delta_g, "
                + "unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source, command_id) "
                + "SELECT ?, ?, ?, ?, ?, ?, ?, ?, "
                + "(SELECT s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id "
                + " WHERE b.device_id = ? AND s.slot_code = ?), ?, ?, ?";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, s.getDeviceId());
            ps.setInt(2, s.getDeviceSeq());
            ps.setTimestamp(3, s.getMeasuredAt());
            ps.setDouble(4, s.getDoorOpenSec());
            ps.setDouble(5, s.getWeightDeltaG());
            ps.setInt(6, s.getUnlockCount());
            ps.setBoolean(7, s.isRfidOk());
            ps.setDouble(8, s.getStayMin());
            ps.setInt(9, s.getDeviceId());
            ps.setString(10, s.getSlotCode());
            ps.setString(11, s.getCardUid());
            ps.setString(12, s.getOpenSource());
            if (s.getCommandId() == null) {
                ps.setNull(13, Types.BIGINT);
            } else {
                ps.setLong(13, s.getCommandId());
            }
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getLong(1) : -1;
            }
        } catch (SQLException e) {
            if (e.getErrorCode() == DUPLICATE_KEY || e.getErrorCode() == DUPLICATE_INDEX) {
                return -1;
            }
            throw e;
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `insert(LockerSession s)`: INSERT ... SELECT so slot_code becomes slot_id in the same statement; catch the duplicate
- `search(Integer deviceId, int page, int size)`: LockerSession LEFT JOIN LockerSlot, plus DATEDIFF(MINUTE, measured_at, ingested_at) AS upload_delay_min, newest first
- `count(Integer deviceId)`: SELECT COUNT(*) with the same filter
- `findById(long sessionId)`: one session by id

**Mẫu `LockerSessionApi`**

```java
// src/java/api/LockerSessionApi.java
package api;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonPrimitive;
import dao.DepositDao;
import dao.DeviceDao;
import dao.LockerSessionDao;
import java.io.IOException;
import java.sql.SQLException;
import java.sql.Timestamp;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.LockerSession;
import service.AlertService;

@WebServlet(name = "LockerSessionApi", urlPatterns = {"/api/locker/batch"})
public class LockerSessionApi extends HttpServlet {

    /** getAsBoolean() turns the number 1.0 into FALSE, so accept both forms. */
    private static boolean readBool(JsonObject json, String key) {
        JsonPrimitive p = json.getAsJsonPrimitive(key);
        return p.isBoolean() ? p.getAsBoolean() : p.getAsDouble() != 0;
    }

    private static String readString(JsonObject json, String key) {
        return json.has(key) && !json.get(key).isJsonNull() ? json.get(key).getAsString() : null;
    }

    private static LockerSession parse(JsonObject json, int deviceId) {
        LockerSession s = new LockerSession();
        s.setDeviceId(deviceId);                                  // from the API key, never from the body
        s.setDeviceSeq(json.get("seq").getAsInt());
        s.setMeasuredAt(Timestamp.valueOf(json.get("measured_at").getAsString()));   // "yyyy-MM-dd HH:mm:ss", UTC
        s.setDoorOpenSec(json.get("door_open_sec").getAsDouble());
        s.setWeightDeltaG(json.get("weight_delta_g").getAsDouble());
        s.setUnlockCount(json.get("unlock_count").getAsInt());
        s.setRfidOk(readBool(json, "rfid_ok"));
        s.setStayMin(json.get("stay_min").getAsDouble());
        s.setSlotCode(readString(json, "slot_code"));
        s.setCardUid(readString(json, "card_uid"));
        String source = readString(json, "open_source");
        s.setOpenSource(source == null ? "RFID" : source);
        s.setCommandId(json.has("command_id") && !json.get("command_id").isJsonNull() ? json.get("command_id").getAsLong() : null);
        return s;
    }

    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");
        JsonArray sessions;
        try {
            JsonElement parsed = JsonParser.parseReader(req.getReader());
            sessions = parsed.getAsJsonObject().getAsJsonArray("sessions");
        } catch (RuntimeException bad) {
            res.sendError(HttpServletResponse.SC_BAD_REQUEST, "Body must be {\"sessions\":[...]}");
            return;
        }
        LockerSessionDao dao = new LockerSessionDao();
        int saved = 0, duplicates = 0, rejected = 0;
        try {
            for (JsonElement element : sessions) {
                LockerSession s;
                try {
                    s = parse(element.getAsJsonObject(), deviceId);
                } catch (RuntimeException bad) {
                    rejected++;                                   // a malformed session is skipped, the others go on
                    continue;
                }
                long id = dao.insert(s);
                if (id < 0) {
                    duplicates++;
                    continue;
                }
                s.setSessionId(id);
                saved++;
                try {
                    new AlertService().evaluate(s);              // before complete(): the rules read the active booking
                } catch (SQLException e) {
                    log("Alert evaluation failed for session " + id, e);   // the session is stored; do not make the device resend it
                }
                if (s.getSlotCode() != null) {
                    new DepositDao().complete(deviceId, s.getSlotCode());
                }
            }
            new DeviceDao().heartbeat(deviceId);                  // a batch also proves the device is alive
        } catch (SQLException e) {
            log("Batch insert failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            return;
        }
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"saved\":" + saved + ",\"duplicates\":" + duplicates + ",\"rejected\":" + rejected + "}");
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `doPost(HttpServletRequest req, HttpServletResponse res)`: insert each session, evaluate it, then free the slot; count saved, duplicate and rejected

Thứ tự trong vòng lặp quan trọng: **`evaluate` trước, `complete` sau**. Luật `WRONG_USER` và `OVERDUE` đọc lượt gửi đang `ACTIVE`; trả ngăn trước thì lượt gửi đã `COMPLETED` và hai luật này không bao giờ chạy.

### 9.6 `tool/ScenarioSender.java`

**Việc**: giả lập ESP32. Mỗi kịch bản là một giá trị của `SCENARIO`:

| Kịch bản | Trường hợp | Chuẩn bị trước | Kết quả đúng |
|---|---|---|---|
| `heartbeat` | 1 | không | 6 nhịp rồi im; khoảng 60 đến 90 giây sau thiết bị `OFFLINE`, có cảnh báo `DEVICE_OFFLINE` |
| `remote` | 2 | bấm Remote unlock ngăn A01 trên web | Phiên đầu: `STAFF_OPEN`, **không** cảnh báo. Phiên hai dùng lại lệnh: `SUSPECTED_SPOOF` |
| `spoof` | 2 | không | Lệnh số 999999 không tồn tại: `SUSPECTED_SPOOF` |
| `lostcard` | 3 | `student1` báo mất thẻ `04A1B2C3` | Nhịp tim có thẻ trong `blocked_cards`; phiên dùng thẻ đó: `LOST_CARD_USED` |
| `checkin` | 4 | đặt ngăn A04 trên web | Lượt gửi chuyển `ACTIVE`, ngăn `OCCUPIED` |
| `sensor` | 5 | không | Khối lượng -5000 g: `SENSOR_FAULT` (không phải `FORCED_OPEN`), có phiếu bảo trì |

**Mẫu**

```java
// src/java/tool/ScenarioSender.java
package tool;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Scanner;
import java.util.TimeZone;

public class ScenarioSender {

    public static void main(String[] args) throws Exception {
        String scenario = args.length > 0 ? args[0] : SCENARIO;
        switch (scenario) {
            case "heartbeat":   // case 1: 6 beats then stop, the device turns OFFLINE about 60 s later
                for (int i = 0; i < 6; i++) {
                    System.out.println(post("/health", heartbeat("A02", false)));
                    Thread.sleep(10000);
                }
                break;
            case "remote": {    // case 2: click Remote unlock on slot A01 in the web first
                JsonObject reply = JsonParser.parseString(post("/health", heartbeat("A01", true))).getAsJsonObject();
                JsonArray commands = reply.getAsJsonArray("commands");
                if (commands.size() == 0) {
                    System.out.println("No pending command, click Remote unlock first");
                    return;
                }
                JsonObject s = session("A01", null, false, 8, 0, 40);
                s.addProperty("open_source", "REMOTE");
                s.addProperty("command_id", commands.get(0).getAsJsonObject().get("command_id").getAsLong());
                System.out.println(postBatch(s));            // expected: STAFF_OPEN, no alert
                JsonObject replay = s.deepCopy();
                replay.addProperty("seq", ++seq);
                System.out.println(postBatch(replay));       // same command used twice: SUSPECTED_SPOOF
                break;
            }
            case "spoof": {     // case 2: REMOTE open with a command the server never issued
                JsonObject s = session("A01", null, false, 8, 0, 40);
                s.addProperty("open_source", "REMOTE");
                s.addProperty("command_id", 999999);
                System.out.println(postBatch(s));
                break;
            }
            case "lostcard":    // case 3: report card 04A1B2C3 lost in the web first
                System.out.println(post("/health", heartbeat("A01", false)));   // blocked_cards lists it now
                System.out.println(postBatch(session("A01", "04A1B2C3", true, 6, 2, 30)));
                break;
            case "checkin":     // case 4: reserve A04 in the web, then run this within the hold time
                System.out.println(post("/health", heartbeat("A04", true)));
                break;
            case "sensor":      // case 5: a weight no real slot can have
                System.out.println(postBatch(session("A01", "0499AABB", true, 6, -5000, 30)));
                break;
            default:
                System.out.println("Unknown scenario: " + scenario);
        }
    }

    private static JsonObject session(String slot, String card, boolean rfidOk,
                                      double doorSec, double weightG, double stayMin) {
        SimpleDateFormat utc = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        utc.setTimeZone(TimeZone.getTimeZone("UTC"));   // the server compares with SYSUTCDATETIME()
        JsonObject s = new JsonObject();
        s.addProperty("seq", ++seq);
        s.addProperty("measured_at", utc.format(new Date()));
        s.addProperty("door_open_sec", doorSec);
        s.addProperty("weight_delta_g", weightG);
        s.addProperty("unlock_count", 2);
        s.addProperty("rfid_ok", rfidOk);               // a real JSON boolean, never 1.0
        s.addProperty("stay_min", stayMin);
        s.addProperty("slot_code", slot);
        s.addProperty("card_uid", card);
        s.addProperty("open_source", "RFID");
        return s;
    }

    private static JsonObject heartbeat(String slot, boolean occupied) {
        JsonObject slotJson = new JsonObject();
        slotJson.addProperty("slot_code", slot);
        slotJson.addProperty("occupied", occupied);
        JsonArray slots = new JsonArray();
        slots.add(slotJson);
        JsonObject body = new JsonObject();
        body.addProperty("firmware", "sim-1.0");
        body.add("slots", slots);
        return body;
    }

    private static String postBatch(JsonObject session) throws Exception {
        JsonArray sessions = new JsonArray();
        sessions.add(session);
        JsonObject body = new JsonObject();
        body.addProperty("device_id", 1);
        body.add("sessions", sessions);
        return post("/locker/batch", body);
    }

    private static String post(String path, JsonObject body) throws Exception {
        HttpURLConnection conn = (HttpURLConnection) new URL(BASE_URL + path).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
        conn.setRequestProperty("X-API-Key", API_KEY);
        try (OutputStream out = conn.getOutputStream()) {
            out.write(body.toString().getBytes("UTF-8"));
        }
        int code = conn.getResponseCode();
        InputStream in = code < 400 ? conn.getInputStream() : conn.getErrorStream();
        String text = "";
        if (in != null) {
            try (Scanner sc = new Scanner(in, "UTF-8").useDelimiter("\\A")) {
                text = sc.hasNext() ? sc.next() : "";
            }
        }
        System.out.println("POST " + path + " -> HTTP " + code);
        return text;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `main(String[] args)`: one switch, one case per scenario

Chạy bằng chuột phải, **Run File**, sau khi Tomcat đang chạy. Đổi `SCENARIO` hoặc truyền tham số ở **Project Properties, Run, Arguments**.

**Tự kiểm tra bằng `curl.exe`** (Windows 10 trở lên có sẵn):

```bash
curl.exe -i -X POST http://localhost:8080/SmartLocker/api/health -H "X-API-Key: device-1-api-key" -H "Content-Type: application/json" -d "{\"slots\":[]}"
```

Mong đợi trên dữ liệu mẫu mới tạo: HTTP 200 và `{"commands":[],"blocked_cards":[],"reserved":[{"slot_code":"A03","card_uid":"04112233"}]}` (`student7` đang giữ chỗ ngăn A03). Không có `-H "X-API-Key..."`: 401. Khoá sai: 401.

**Dễ sai**

- Quên `Content-Type`: không sao, `getReader()` vẫn đọc được.
- Gửi `measured_at` giờ địa phương: phiên bị coi là "trong tương lai" 7 tiếng, thành `SENSOR_FAULT` (đồng hồ thiết bị chạy trước server hơn 5 phút).
- Trùng `seq`: `ScenarioSender` khởi tạo `seq` theo giây hiện tại để mỗi lần chạy khác nhau. Nếu tự đặt `seq = 1` thì lần chạy thứ hai báo `duplicates`.

## 10. Giai đoạn 7: luật và cảnh báo

Mục tiêu: gửi một phiên bất thường thì có `Alert` kèm bằng chứng; xem được trên trang cảnh báo.

### 10.1 Hai tầng và thứ tự ưu tiên

`AlertService.evaluate` làm theo thứ tự:

1. Nạp `SessionContext` từ CSDL (`SessionContextDao`).
2. `RuleEngine.evaluate`: các luật, **luật đầu tiên khớp thắng**.
3. Nếu phiên đáng đưa cho mô hình (`mlEligible`): `RiskScorer.score` cho điểm 0 đến 1. Không có luật nào khớp mà điểm đạt 0,80 thì cảnh báo `ML_ANOMALY`. Có luật khớp thì điểm vẫn lưu làm bằng chứng phụ.
4. Ghi `Alert` và bằng chứng; với `SENSOR_FAULT` mở phiếu bảo trì; với `STAFF_OPEN` đánh dấu lệnh đã dùng.

Thứ tự luật (cố ý, vì loại trước có độ tin cậy cao hơn):

| # | Luật | Nhãn | Vì sao đứng ở đây |
|---|---|---|---|
| 1 | Số đo ngoài khoảng hợp lệ, số vô lý, đồng hồ thiết bị chạy trước server hơn 5 phút, hiệu chuẩn hết hạn | `SENSOR_FAULT` | Dữ liệu không đáng tin thì **không đổ lỗi cho người dùng** |
| 2 | `open_source = REMOTE`: lệnh hợp lệ thì bình thường, không thì giả mạo | `STAFF_OPEN` (không cảnh báo) hoặc `SUSPECTED_SPOOF` | Nhân viên mở hợp lệ không được báo thành `FORCED_OPEN` |
| 3 | Thẻ đã báo mất hoặc bị chặn | `LOST_CARD_USED` | |
| 4 | Cửa mở mà thẻ không hợp lệ | `FORCED_OPEN` | Sáu nhãn của đề |
| 5 | Thẻ của người khác với chủ lượt gửi | `WRONG_USER` | |
| 6 | Khối lượng đổi mà cảm biến cửa báo chưa mở | `SUSPECTED_SPOOF` | |
| 7 | Còn đồ trong ngăn sau khi lấy | `ITEM_LEFT` | |
| 8 | Gửi lâu hơn gói + gia hạn + ân hạn | `OVERDUE` | |

Phiên bị loại khỏi mô hình (`noMl`): `STAFF_OPEN` và `SENSOR_FAULT`. View `v_LockerSession_Features` cũng loại chúng khỏi dữ liệu huấn luyện, nếu không mô hình học nhầm.

### 10.2 `service/SessionContext.java`, `service/Verdict.java`

`SessionContext`: lớp dữ liệu thuần (khung đã có đủ). `Verdict`: kết quả của luật; khung có trường, bạn viết các hàm. Hai lớp này cố ý **không đụng cơ sở dữ liệu** để `RuleEngine` kiểm thử được bằng vài dòng.

**Mẫu `Verdict`**

```java
// src/java/service/Verdict.java
package service;

import java.util.ArrayList;
import java.util.List;

public class Verdict {

    public static Verdict alert(String label, String item, String value) {
        return new Verdict(label, true).with(item, value);
    }

    public static Verdict normal() {
        return new Verdict("NORMAL", false);
    }

    public static Verdict staffOpen(long commandId) {
        return new Verdict("STAFF_OPEN", false).with("command_id", String.valueOf(commandId)).noMl();
    }

    public Verdict with(String item, String value) {
        evidence.add(new String[]{item, value});
        return this;
    }

    public Verdict noMl() {
        mlEligible = false;
        return this;
    }

    // ... the other methods are in your skeleton file
}
```

- `alert(String label, String item, String value)`: new Verdict(label, true).with(item, value)
- `normal()`
- `staffOpen(long commandId)`
- `with(String item, String value)`: add one {item, value} pair and return this, so calls can be chained
- `noMl()`

### 10.3 `service/RuleEngine.java`

**Đọc trước**: DE01 bảng "Nhãn kết quả phiên" (6 nhãn) và mục "Đủ luật cảnh báo" (mỗi cảnh báo kèm bằng chứng); POUR `controller/PourAPI.java` hàm `applyCupMissingOverride` và `executeWekaWithDatabaseView` (bài mẫu: luật vật lý đứng trước, bỏ phiên thủ công khỏi mô hình).

**Mẫu**

```java
// src/java/service/RuleEngine.java
package service;

import model.LockerSession;

public class RuleEngine {

    public Verdict evaluate(LockerSession s, SessionContext ctx) {
        // 1. SENSOR_FAULT: data we cannot trust, blame the sensor and not the user
        String fault = findSensorFault(s, ctx);
        if (fault != null) {
            return Verdict.alert("SENSOR_FAULT", "reason", fault).noMl();
        }
        // 2. Remote open: a valid command means staff opened it, otherwise someone faked the signal
        if ("REMOTE".equals(s.getOpenSource())) {
            if (s.getCommandId() != null && ctx.isCommandValid()) {
                return Verdict.staffOpen(s.getCommandId());
            }
            return Verdict.alert("SUSPECTED_SPOOF", "reason", "remote open without a valid command")
                    .with("command_id", String.valueOf(s.getCommandId()));
        }
        // 3. A card reported lost or blocked was used
        if (ctx.getCardStatus() != null && !"ACTIVE".equals(ctx.getCardStatus())) {
            return Verdict.alert("LOST_CARD_USED", "card_uid", s.getCardUid())
                    .with("card_status", ctx.getCardStatus())
                    .with("card_owner_id", String.valueOf(ctx.getCardOwnerId()));
        }
        // 4. The six labels of the assignment
        if (!s.isRfidOk() && s.getDoorOpenSec() > 0) {
            return Verdict.alert("FORCED_OPEN", "door_open_sec", String.valueOf(s.getDoorOpenSec()))
                    .with("rfid_ok", "false");
        }
        if (s.isRfidOk() && ctx.getCardOwnerId() != null && ctx.getDepositOwnerId() != null
                && !ctx.getCardOwnerId().equals(ctx.getDepositOwnerId())) {
            return Verdict.alert("WRONG_USER", "card_owner_id", String.valueOf(ctx.getCardOwnerId()))
                    .with("deposit_owner_id", String.valueOf(ctx.getDepositOwnerId()));
        }
        if (s.getDoorOpenSec() == 0 && Math.abs(s.getWeightDeltaG()) > SPOOF_WEIGHT_G) {
            return Verdict.alert("SUSPECTED_SPOOF", "reason", "weight changed while the door sensor reported closed")
                    .with("weight_delta_g", String.valueOf(s.getWeightDeltaG()));
        }
        if (s.getWeightDeltaG() > ITEM_LEFT_G) {
            return Verdict.alert("ITEM_LEFT", "weight_delta_g", String.valueOf(s.getWeightDeltaG()));
        }
        if (ctx.getAllowedMin() > 0 && s.getStayMin() > ctx.getAllowedMin()) {
            return Verdict.alert("OVERDUE", "stay_min", String.valueOf(s.getStayMin()))
                    .with("allowed_min", String.valueOf(ctx.getAllowedMin()));
        }
        return Verdict.normal();   // AlertService may still raise ML_ANOMALY from the risk score
    }

    private String findSensorFault(LockerSession s, SessionContext ctx) {
        if (!ctx.inRange("DOOR", s.getDoorOpenSec())) {
            return "door_open_sec=" + s.getDoorOpenSec() + " is outside the valid range";
        }
        if (!ctx.inRange("WEIGHT", s.getWeightDeltaG())) {
            return "weight_delta_g=" + s.getWeightDeltaG() + " is outside the valid range";
        }
        if (!ctx.inRange("STAY", s.getStayMin())) {
            return "stay_min=" + s.getStayMin() + " is outside the valid range";
        }
        if (s.getDoorOpenSec() > s.getStayMin() * 60 + 5) {
            return "door was open longer than the whole session";
        }
        if (ctx.getUploadDelaySec() < -CLOCK_AHEAD_SEC) {
            return "device clock is " + (-ctx.getUploadDelaySec()) + " s ahead of the server, check NTP";
        }
        if (!ctx.isCalibrationValid()) {
            return "weight sensor calibration has expired";
        }
        return null;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `evaluate(LockerSession s, SessionContext ctx)`: 1 sensor fault, 2 remote open, 3 lost card, 4 the six labels of the assignment
- `findSensorFault(LockerSession s, SessionContext ctx)`: valid ranges, impossible numbers, device clock, expired calibration

**Tự kiểm tra**: `RuleEngineTest` ở mục 10.8.

### 10.4 `dao/SessionContextDao.java`

**Việc**: sáu truy vấn ngắn, mỗi truy vấn điền một trường của `SessionContext`.

| Trường | Câu hỏi |
|---|---|
| khoảng hợp lệ | `SELECT name, min_valid, max_valid FROM SensorType` |
| độ trễ tải lên | `DATEDIFF(SECOND, measured_at, ingested_at)` tính **trong SQL**, nên múi giờ của máy Java không ảnh hưởng |
| hiệu chuẩn còn hạn | có dòng `Calibration` `WEIGHT` với `valid_until >= ngày của phiên` |
| lệnh hợp lệ | lệnh `SENT` đúng thiết bị, đúng ngăn, tạo trong vòng 30 phút trước phiên |
| thẻ | trạng thái và chủ thẻ theo `card_uid` |
| lượt gửi | chủ và thời gian cho phép (`due_at - started_at + ân hạn`) của lượt `ACTIVE` ở ngăn đó |

**Mẫu**

```java
// src/java/dao/SessionContextDao.java
package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import model.LockerSession;
import service.SessionContext;

public class SessionContextDao {

    public SessionContext load(LockerSession s) throws SQLException {
        SessionContext ctx = new SessionContext();
        try (Connection conn = DbContext.getConnection()) {

            // 1. valid ranges of the sensors (DOOR, WEIGHT, STAY)
            try (PreparedStatement ps = conn.prepareStatement("SELECT name, min_valid, max_valid FROM SensorType");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ctx.setRange(rs.getString(1), rs.getDouble(2), rs.getDouble(3));
                }
            }

            // 2. how late the upload was; negative means the device clock is ahead of the server (done in SQL, no time zones)
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT DATEDIFF(SECOND, measured_at, ingested_at) FROM LockerSession WHERE session_id = ?")) {
                ps.setLong(1, s.getSessionId());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        ctx.setUploadDelaySec(rs.getLong(1));
                    }
                }
            }

            // 3. a WEIGHT calibration that was still valid on the day of the session
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM Calibration c JOIN SensorType t ON t.sensor_type_id = c.sensor_type_id "
                    + "JOIN LockerSession s ON s.device_id = c.device_id "
                    + "WHERE s.session_id = ? AND t.name = N'WEIGHT' AND c.valid_until >= CAST(s.measured_at AS DATE)")) {
                ps.setLong(1, s.getSessionId());
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    ctx.setCalibrationValid(rs.getInt(1) > 0);
                }
            }

            // 4. a remote open is genuine only for a SENT command of this device and slot, issued less than 30 minutes before
            if ("REMOTE".equals(s.getOpenSource()) && s.getCommandId() != null) {
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT COUNT(*) FROM RemoteCommand c JOIN LockerSession s ON s.session_id = ? "
                        + "WHERE c.command_id = s.command_id AND c.device_id = s.device_id AND c.slot_id = s.slot_id "
                        + "AND c.status = N'SENT' AND s.measured_at BETWEEN c.created_at AND DATEADD(MINUTE, 30, c.created_at)")) {
                    ps.setLong(1, s.getSessionId());
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        ctx.setCommandValid(rs.getInt(1) > 0);
                    }
                }
            }

            // 5. the card: unknown card = null status and owner
            if (s.getCardUid() != null) {
                try (PreparedStatement ps = conn.prepareStatement("SELECT status, user_id FROM UserCard WHERE card_uid = ?")) {
                    ps.setString(1, s.getCardUid());
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            ctx.setCardStatus(rs.getString(1));
                            ctx.setCardOwnerId(rs.getInt(2));
                        }
                    }
                }
            }

            // 6. the booking of the slot: its owner, and how long it may last (plan + extensions + grace)
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT TOP 1 d.user_id, DATEDIFF(MINUTE, d.started_at, d.due_at) + p.grace_min "
                    + "FROM Deposit d JOIN StoragePlan p ON p.plan_id = d.plan_id "
                    + "JOIN LockerSession s ON s.slot_id = d.slot_id "
                    + "WHERE s.session_id = ? AND d.status = N'ACTIVE' ORDER BY d.started_at DESC")) {
                ps.setLong(1, s.getSessionId());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        ctx.setDepositOwnerId(rs.getInt(1));
                        ctx.setAllowedMin(rs.getDouble(2));
                    }
                }
            }
        }
        return ctx;
    }

    // ... the other methods are in your skeleton file
}
```

- `load(LockerSession s)`: six short queries, one per field of the context

### 10.5 `dao/AlertDao.java`, `service/AlertService.java`

**Đọc trước**: POUR `dao/AlertDAO.java` (trang cảnh báo đang mở, xử lý qua thủ tục `Alert_Resolve_Maintenance`).

**Mẫu `AlertDao.create`**: một transaction, hoặc có cả cảnh báo lẫn bằng chứng, hoặc không có gì.

```java
// src/java/dao/AlertDao.java
package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.List;
import model.Alert;

public class AlertDao {


        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int alertId;
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO Alert (device_id, session_id, source, label, risk_score) VALUES (?, ?, ?, ?, ?)",
                        Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, deviceId);
                    ps.setLong(2, sessionId);
                    ps.setString(3, source);
                    ps.setString(4, label);
                    if (risk == null) {
                        ps.setNull(5, Types.FLOAT);
                    } else {
                        ps.setDouble(5, risk);
                    }
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        keys.next();
                        alertId = keys.getInt(1);
                    }
                }
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO AlertEvidence (alert_id, item, value_text) VALUES (?, ?, ?)")) {
                    for (String[] pair : evidence) {
                        ps.setInt(1, alertId);
                        ps.setString(2, pair[0]);
                        ps.setString(3, pair[1]);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                }
                conn.commit();
                return alertId;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
}

    public void resolve(int alertId, int actorId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Alert_Resolve(?, ?)}")) {
            cs.setInt(1, alertId);
            cs.setInt(2, actorId);
            cs.execute();
        }
    }

    // ... the other methods are in your skeleton file
}
```

- ``: one transaction: INSERT Alert, then one INSERT AlertEvidence per item
- `resolve(int alertId, int actorId)`: {call Alert_Resolve(?, ?)}
- `search(String status, String label, int page, int size)`: Alert with optional status and label filters, ORDER BY alert_id DESC, OFFSET/FETCH
- `count(String status, String label)`: SELECT COUNT(*) with the same filters
- `findById(int alertId)`: SELECT the alert, then SELECT item, value_text FROM AlertEvidence WHERE alert_id = ?
- `countOpen()`: SELECT COUNT(*) FROM Alert WHERE status = 'OPEN'

**Mẫu `AlertService`**

```java
// src/java/service/AlertService.java
package service;

import dao.AlertDao;
import dao.AuditDao;
import dao.MaintenanceDao;
import dao.RemoteCommandDao;
import dao.SessionContextDao;
import java.sql.SQLException;
import java.util.Locale;
import model.LockerSession;

public class AlertService {

    public void evaluate(LockerSession session) throws SQLException {
        SessionContext ctx = new SessionContextDao().load(session);
        Verdict verdict = ruleEngine.evaluate(session, ctx);

        Double risk = null;
        if (verdict.isMlEligible()) {                        // a staff open or a broken sensor is not user behaviour
            risk = RiskScorer.getInstance().score(session);  // 1 - P(NORMAL)
            if (!verdict.isAlert() && risk >= ML_THRESHOLD) {
                verdict = Verdict.alert("ML_ANOMALY", "risk_score", String.format(Locale.ROOT, "%.2f", risk));
            }
        }

        if ("STAFF_OPEN".equals(verdict.getLabel())) {       // case 2: the command is used up
            new RemoteCommandDao().markDone(session.getCommandId(), session.getSessionId());
            new AuditDao().append(AuditDao.SYSTEM_USER_ID, "COMMAND_DONE", "COMMAND", session.getCommandId(),
                    "session " + session.getSessionId());
        }

        if (verdict.isAlert()) {
            String source = "ML_ANOMALY".equals(verdict.getLabel()) ? "ML" : "RULE";
            int alertId = new AlertDao().create(session.getDeviceId(), session.getSessionId(), source,
                    verdict.getLabel(), risk, verdict.getEvidence());
            new AuditDao().append(AuditDao.SYSTEM_USER_ID, "CREATE", "ALERT", alertId, verdict.getLabel());
            if ("SENSOR_FAULT".equals(verdict.getLabel())) {  // case 5: a ticket and the slot out of service
                new MaintenanceDao().openForFault(session.getDeviceId(), alertId, session.getSessionId(),
                        verdict.getEvidence().get(0)[1]);
            }
        }
    }

    // ... the other methods are in your skeleton file
}
```

- `evaluate(LockerSession session)`: context -> rules -> model -> alert -> follow-up (command done, ticket opened)

### 10.6 `dao/MaintenanceDao.java`

```java
// src/java/dao/MaintenanceDao.java
package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

public class MaintenanceDao {

    public void openForFault(int deviceId, int alertId, long sessionId, String note) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Ticket_OpenForFault(?, ?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setInt(2, alertId);
            cs.setLong(3, sessionId);
            cs.setString(4, note);
            cs.execute();
        }
    }

    // ... the other methods are in your skeleton file
}
```

- `openForFault(int deviceId, int alertId, long sessionId, String note)`: {call Ticket_OpenForFault(?, ?, ?, ?)}
- `close(int ticketId, int actorId, String note)`: {call Ticket_Close(?, ?, ?)} like openForFault()
- `search(String status, int page, int size)`: MaintenanceTicket JOIN Device JOIN Users (assigned_to), optional status, ORDER BY ticket_id DESC, OFFSET/FETCH
- `count(String status)`: SELECT COUNT(*) with the same filter

### 10.7 `controller/AlertController.java`, `views/alert.jsp`, `controller/MaintenanceController.java`, `views/maintenance.jsp`

**Việc**: danh sách cảnh báo (lọc theo trạng thái và nhãn); bấm vào một cảnh báo thấy chi tiết: **bảng bằng chứng** và phiên sinh ra nó; nút Resolve. Danh sách phiếu bảo trì; kỹ thuật viên đóng phiếu kèm ghi chú.

- `doPost(HttpServletRequest req, HttpServletResponse res)`: AlertController.doPost: action=resolve&id=: AlertDao.resolve(id, me.getUserId()), flash, redirect to the list

- `doPost(HttpServletRequest req, HttpServletResponse res)`: MaintenanceController.doPost: action=close&ticketId=&note=: MaintenanceDao.close(ticketId, me.getUserId(), note); the slot becomes AVAILABLE again

Đề yêu cầu "từ cảnh báo bấm tới được chi tiết phiên và phiếu bảo trì": bảng bằng chứng có liên kết tới phiên và, nếu có, tới phiếu của cảnh báo đó. Trên sơ đồ tủ, khung chi tiết ngăn đã có nút "Open alert #..." và "Open maintenance ticket #..." trỏ tới `AlertController?id=` và `MaintenanceController?id=`.

### 10.8 `test/test/RuleEngineTest.java`

**Mẫu**: 12 test, mỗi luật một cái, không cần database hay server. Đề yêu cầu tối thiểu 10 ca TestNG; cộng 5 của `SecurityUtilsTest` và 2 của bộ kiểm tra nhật ký là đủ.

```java
package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertTrue;

import model.LockerSession;
import org.testng.annotations.Test;
import service.RuleEngine;
import service.SessionContext;
import service.Verdict;

/**
 * One test per rule. No database and no server: RuleEngine only needs a session and a context.
 * Add one test for every new rule you write.
 */
public class RuleEngineTest {

    private final RuleEngine engine = new RuleEngine();

    private LockerSession session(double doorSec, double weightG, boolean rfidOk, double stayMin) {
        LockerSession s = new LockerSession();
        s.setDeviceId(1);
        s.setDoorOpenSec(doorSec);
        s.setWeightDeltaG(weightG);
        s.setRfidOk(rfidOk);
        s.setStayMin(stayMin);
        s.setUnlockCount(2);
        s.setSlotCode("A01");
        s.setCardUid("04A1B2C3");
        s.setOpenSource("RFID");
        return s;
    }

    /** A context in which nothing is wrong: valid ranges, the card of the booking owner, 130 minutes allowed. */
    private SessionContext healthy() {
        SessionContext c = new SessionContext();
        c.setRange("DOOR", 0, 3600);
        c.setRange("WEIGHT", -200, 20000);
        c.setRange("STAY", 0, 10080);
        c.setCardStatus("ACTIVE");
        c.setCardOwnerId(7);
        c.setDepositOwnerId(7);
        c.setAllowedMin(130);
        return c;
    }

    @Test
    public void normalSessionRaisesNothing() {
        Verdict v = engine.evaluate(session(6, 2, true, 40), healthy());
        assertEquals(v.getLabel(), "NORMAL");
        assertFalse(v.isAlert());
        assertTrue(v.isMlEligible());
    }

    @Test
    public void remoteOpenWithValidCommandIsNotForcedOpen() {
        LockerSession s = session(8, 0, false, 40);
        s.setOpenSource("REMOTE");
        s.setCommandId(15L);
        SessionContext ctx = healthy();
        ctx.setCommandValid(true);
        Verdict v = engine.evaluate(s, ctx);
        assertEquals(v.getLabel(), "STAFF_OPEN");
        assertFalse(v.isAlert());
        assertFalse(v.isMlEligible());
    }

    @Test
    public void remoteOpenWithoutCommandIsSpoof() {
        LockerSession s = session(8, 0, false, 40);
        s.setOpenSource("REMOTE");
        s.setCommandId(999999L);
        assertEquals(engine.evaluate(s, healthy()).getLabel(), "SUSPECTED_SPOOF");
    }

    @Test
    public void lostCardIsFlagged() {
        SessionContext ctx = healthy();
        ctx.setCardStatus("LOST");
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "LOST_CARD_USED");
    }

    @Test
    public void impossibleWeightIsSensorFaultNotForcedOpen() {
        Verdict v = engine.evaluate(session(6, -5000, false, 30), healthy());
        assertEquals(v.getLabel(), "SENSOR_FAULT");
        assertFalse(v.isMlEligible());
    }

    @Test
    public void expiredCalibrationIsSensorFault() {
        SessionContext ctx = healthy();
        ctx.setCalibrationValid(false);
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "SENSOR_FAULT");
    }

    @Test
    public void deviceClockAheadIsSensorFault() {
        SessionContext ctx = healthy();
        ctx.setUploadDelaySec(-3600);
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "SENSOR_FAULT");
    }

    @Test
    public void doorOpenedWithoutValidCardIsForcedOpen() {
        assertEquals(engine.evaluate(session(6, 2, false, 40), healthy()).getLabel(), "FORCED_OPEN");
    }

    @Test
    public void cardOfAnotherUserIsWrongUser() {
        SessionContext ctx = healthy();
        ctx.setCardOwnerId(9);
        assertEquals(engine.evaluate(session(6, 2, true, 40), ctx).getLabel(), "WRONG_USER");
    }

    @Test
    public void weightChangedWithClosedDoorIsSpoof() {
        assertEquals(engine.evaluate(session(0, -150, true, 40), healthy()).getLabel(), "SUSPECTED_SPOOF");
    }

    @Test
    public void itemStillInsideIsItemLeft() {
        assertEquals(engine.evaluate(session(6, 400, true, 40), healthy()).getLabel(), "ITEM_LEFT");
    }

    @Test
    public void stayLongerThanPlanIsOverdue() {
        assertEquals(engine.evaluate(session(6, 2, true, 200), healthy()).getLabel(), "OVERDUE");
    }
}
```

**Khung bạn làm**: khung có sẵn hai hàm trợ giúp `session(...)`, `healthy()` và test đầu tiên; 11 test còn lại để dạng `TODO`. Cách viết: tạo phiên bất thường, cho `healthy()` thay đổi đúng một thứ, kiểm tra nhãn.

**Tự kiểm tra**

1. Chạy `ScenarioSender` kịch bản `sensor`. Trang Alerts có `SENSOR_FAULT`, bằng chứng ghi `weight_delta_g=-5000.0 is outside the valid range`, và có phiếu bảo trì.
2. Trong SSMS: `SELECT TOP 5 label, source, risk_score FROM Alert ORDER BY alert_id DESC;`.
3. Sai thứ tự luật (ví dụ đặt `FORCED_OPEN` lên đầu): `RuleEngineTest.impossibleWeightIsSensorFaultNotForcedOpen` fail. Đó là lý do có bài test.

**Dễ sai**

- Không seed `Calibration`: mọi phiên thành `SENSOR_FAULT`.
- `AlertService` ném lỗi làm API trả 500 và thiết bị gửi lại phiên đã lưu: `LockerSessionApi` bắt `SQLException` của `evaluate` riêng, phiên đã lưu thì không bắt thiết bị gửi lại.
- Luật dùng `==` để so chuỗi: dùng `"X".equals(...)`.

**Cột mốc cuối giai đoạn 7**: 12 test của `RuleEngineTest` xanh; kịch bản `sensor` cho cảnh báo kèm bằng chứng.

## 11. Giai đoạn 8: năm trường hợp thực tế

Cả năm trường hợp đã được thiết kế sao cho phần lớn việc nằm sẵn trong các file ở những giai đoạn trước (thủ tục SQL, `RuleEngine`, `HealthApi`, bản đồ). Giai đoạn này nối chúng lại bằng các file còn thiếu và kiểm tra từng trường hợp từ đầu đến cuối.

Làm theo thứ tự: chạy `sql/03_scenarios.sql` (mục 4.2), rồi các file dưới đây.

### 11.1 `service/LockerMonitor.java` (trường hợp 1 và một phần trường hợp 2, 4)

**Đọc trước**: không có trong đề lẫn bài mẫu (bài mẫu không tự phát hiện thiết bị mất mạng). Đọc tài liệu `ScheduledExecutorService` của Java.

**Việc của file**: chạy theo đồng hồ, không phải do ai bấm: mỗi 30 giây gọi ba thủ tục `Device_MarkOffline(60)`, `Deposit_ExpireNoShow`, `RemoteCommand_Expire`. Chạy trong Tomcat nhờ `@WebListener`, không cần thư viện hẹn giờ.

**Mẫu**

```java
// src/java/service/LockerMonitor.java
package service;

import dao.DbContext;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

@WebListener
public class LockerMonitor implements ServletContextListener {

    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleWithFixedDelay(new Runnable() {
            @Override
            public void run() {
                runProcedure("{call Device_MarkOffline(60)}");   // first: a no-show is not judged while the device is offline
                runProcedure("{call Deposit_ExpireNoShow}");
                runProcedure("{call RemoteCommand_Expire}");
            }
        }, 30, 30, TimeUnit.SECONDS);
    }

    private void runProcedure(String call) {
        try (Connection conn = DbContext.getConnection(); CallableStatement cs = conn.prepareCall(call)) {
            cs.execute();
        } catch (SQLException e) {
            // an exception that escapes run() silently cancels every later run, so catch it here
            LOG.log(Level.WARNING, "LockerMonitor " + call + " failed: " + e.getMessage());
        }
    }

    public void contextDestroyed(ServletContextEvent sce) {
        if (scheduler != null) {
            scheduler.shutdownNow();
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**: khung **không làm gì** (ghi chú trong thân hàm). Cố ý như vậy: một listener ném lỗi khi khởi động làm cả ứng dụng không chạy.

- `contextInitialized(ServletContextEvent sce)`: one thread, every 30 seconds: Device_MarkOffline, Deposit_ExpireNoShow, RemoteCommand_Expire
- `contextDestroyed(ServletContextEvent sce)`: NetBeans redeploys often: stop the thread or every redeploy leaks one

**Dễ sai**

- Một ngoại lệ thoát khỏi `run()` **huỷ im lặng mọi lần chạy sau** của `scheduleWithFixedDelay`. Vì vậy `runProcedure` tự bắt `SQLException`.
- Không `shutdownNow()` trong `contextDestroyed`: mỗi lần NetBeans triển khai lại để rò thêm một luồng.
- Gọi `Device_MarkOffline` trước `Deposit_ExpireNoShow` (đúng thứ tự trong mẫu): tủ đã mất mạng thì chưa kết luận người dùng "không đến".

### 11.2 Trường hợp 1: tủ mất mạng

| Bước | Điều xảy ra | Nơi xem |
|---|---|---|
| 1 | Thiết bị gửi nhịp tim mỗi 10 giây, `last_seen` cập nhật | `SELECT status, last_seen FROM Device` |
| 2 | Im hơn 60 giây. Trong vòng 30 giây sau, `LockerMonitor` chạy `Device_MarkOffline` | Thiết bị `OFFLINE`, một cảnh báo `DEVICE_OFFLINE` có bằng chứng `last_seen_utc` |
| 3 | Sơ đồ: toàn bộ ngăn `LIB-A` thành xám có vạch; nút mở từ xa và đặt chỗ bị khoá | Trang bản đồ |
| 4 | Nhịp tim quay lại: thiết bị `ACTIVE`, cảnh báo tự đóng | |
| 5 | Phiên gửi bù sau khi có mạng vẫn đúng: luật dùng `measured_at` do thiết bị đo, không dùng giờ nhận | Cột `upload_delay_min` của lịch sử phiên |

**Thử**: chạy `ScenarioSender` kịch bản `heartbeat`, đợi 90 giây rồi tải lại bản đồ và trang Alerts. Chạy lại để thấy thiết bị trở về. (Giá trị đã kiểm chứng ở bộ kiểm tra SQL: `Device_MarkOffline` hai lần liên tiếp chỉ tạo **một** cảnh báo.)

### 11.3 Trường hợp 2: nhân viên mở từ xa

**Đọc trước**: DE01 "xác nhận mở tủ từ xa" (Tương tác nổi bật); POUR `controller/PourController.java` (cách bài mẫu điều khiển: gọi thẳng thiết bị; ta không làm vậy, xem mục 9.1).

**Files**: `dao/RemoteCommandDao.java`, `controller/RemoteCommandController.java`, `views/remoteCommand.jsp`.

**Mẫu `RemoteCommandDao`**

```java
// src/java/dao/RemoteCommandDao.java
package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class RemoteCommandDao {

    public long create(int slotId, String reason, int actorId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call RemoteCommand_Create(?, ?, ?, ?)}")) {
            cs.setInt(1, slotId);
            cs.setString(2, reason);
            cs.setInt(3, actorId);
            cs.registerOutParameter(4, Types.BIGINT);
            cs.execute();
            return cs.getLong(4);
        }
    }

    public List<Map<String, Object>> takePending(int deviceId) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call RemoteCommand_TakePending(?)}")) {
            cs.setInt(1, deviceId);
            try (ResultSet rs = cs.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> cmd = new LinkedHashMap<>();
                    cmd.put("command_id", rs.getLong("command_id"));
                    cmd.put("slot_code", rs.getString("slot_code"));
                    cmd.put("action", rs.getString("action"));
                    list.add(cmd);
                }
            }
        }
        return list;
    }

    public void markDone(long commandId, long sessionId) throws SQLException {
        String sql = "UPDATE RemoteCommand SET status = 'DONE', done_at = SYSUTCDATETIME(), session_id = ? "
                + "WHERE command_id = ? AND status = 'SENT'";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, sessionId);
            ps.setLong(2, commandId);
            ps.executeUpdate();
        }
    }

    // ... the other methods are in your skeleton file
}
```

- `create(int slotId, String reason, int actorId)`: {call RemoteCommand_Create(?, ?, ?, ?)} with a BIGINT OUTPUT parameter
- `takePending(int deviceId)`: the procedure is an UPDATE ... OUTPUT, so it returns a result set
- `markDone(long commandId, long sessionId)`: UPDATE ... WHERE status = 'SENT' makes the command single use
- `search(String status, int page, int size)`: RemoteCommand JOIN LockerSlot JOIN Users (requested_by), optional status, ORDER BY command_id DESC, OFFSET/FETCH
- `count(String status)`: SELECT COUNT(*) with the same filter

**Mẫu `RemoteCommandController`**

```java
// src/java/controller/RemoteCommandController.java
package controller;

import dao.RemoteCommandDao;
import java.io.IOException;
import java.net.URLEncoder;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

@WebServlet(name = "RemoteCommandController", urlPatterns = {"/RemoteCommandController"})
public class RemoteCommandController extends HttpServlet {

    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        try {
            long id = new RemoteCommandDao().create(Web.intParam(req, "slotId", 0), Web.trimmed(req, "reason"), me.getUserId());
            Web.flash(req.getSession(), "Command #" + id + " queued, the slot opens within 10 seconds.", false);
        } catch (SQLException e) {
            if (e.getErrorCode() >= 50000) {
                Web.flash(req.getSession(), e.getMessage(), true);
            } else {
                throw new ServletException(e);
            }
        }
        res.sendRedirect("LockerMapController?area=" + URLEncoder.encode(Web.trimmed(req, "area"), "UTF-8")
                + "&slot=" + Web.intParam(req, "slot", 0));
    }

    // ... the other methods are in your skeleton file
}
```

| Bước | Điều xảy ra |
|---|---|
| 1 | `operator1` bấm ngăn trên bản đồ, nhập **lý do** (tối thiểu 5 ký tự), xác nhận bằng hộp thoại. Chỉ có với dãy có thiết bị |
| 2 | `RemoteCommand_Create`: từ chối nếu thiết bị offline (50011), người khác đang điều khiển (50012), lý do ngắn (50013). Lệnh `PENDING`, hết hạn sau 2 phút |
| 3 | Nhịp tim kế tiếp nhận lệnh: `commands: [{command_id, slot_code, action}]` và lệnh thành `SENT` |
| 4 | Thiết bị mở khoá; phiên gửi lên có `open_source = REMOTE` và `command_id` |
| 5 | `RuleEngine`: lệnh hợp lệ (đúng thiết bị, đúng ngăn, `SENT`, tạo trong 30 phút trước) thì `STAFF_OPEN`: **không** cảnh báo, không đưa vào mô hình, lệnh chuyển `DONE`. Lệnh không có hoặc đã dùng thì `SUSPECTED_SPOOF` |

**Thử**: đăng nhập `operator1`, mở khoá ngăn A01 với lý do "Student forgot card". Chạy `ScenarioSender` kịch bản `remote`: phản hồi đầu `saved: 1`, **không có** cảnh báo mới; lần phát lại cùng lệnh sinh `SUSPECTED_SPOOF`. Kịch bản `spoof` (lệnh 999999) cũng cho `SUSPECTED_SPOOF`. Xem `SELECT command_id, status, session_id FROM RemoteCommand`.

### 11.4 Trường hợp 3: mất thẻ

**Đọc trước**: DE01 bảng "Thực thể riêng" (thẻ người dùng). Không có trong bài mẫu (bài mẫu nhắc RFID ở phần "future work").

**Files**: `dao/UserCardDao.java`, `controller/MyCardController.java`, `views/myCard.jsp`, `controller/UserCardController.java` (nút thay thẻ).

**Mẫu `UserCardDao`**

```java
// src/java/dao/UserCardDao.java
package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import model.UserCard;

public class UserCardDao {

    public List<String> blockedUids() throws SQLException {
        List<String> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT card_uid FROM UserCard WHERE status <> 'ACTIVE'");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(rs.getString(1));
            }
        }
        return list;
    }

    public void reportLost(int cardId, int actorId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call UserCard_ReportLost(?, ?)}")) {
            cs.setInt(1, cardId);
            cs.setInt(2, actorId);
            cs.execute();
        }
    }

    public int replace(int oldCardId, String newUid, int actorId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call UserCard_Replace(?, ?, ?, ?)}")) {
            cs.setInt(1, oldCardId);
            cs.setString(2, newUid);
            cs.setInt(3, actorId);
            cs.registerOutParameter(4, Types.INTEGER);
            cs.execute();
            return cs.getInt(4);
        }
    }

    // ... the other methods are in your skeleton file
}
```

Danh sách việc đầy đủ của `UserCardDao` ở mục 6.3.

**Khung bạn làm: `MyCardController`**

- `doPost(HttpServletRequest req, HttpServletResponse res)`: MyCardController.doPost: action=reportLost&cardId=: UserCardDao.reportLost(cardId, me.getUserId()); the procedure refuses a card that is not yours; flash and redirect

| Bước | Điều xảy ra |
|---|---|
| 1 | `student1` vào **My cards**, bấm **Report lost** (có hộp xác nhận) |
| 2 | `UserCard_ReportLost`: chỉ chủ thẻ, chỉ thẻ `ACTIVE`; thẻ thành `LOST`, ghi nhật ký |
| 3 | Nhịp tim kế tiếp trả `blocked_cards: ["04A1B2C3"]`; thiết bị từ chối thẻ này tại tủ |
| 4 | Nếu thiết bị đang mất mạng nên vẫn mở cho thẻ đó, phiên gửi lên sinh cảnh báo `LOST_CARD_USED` kèm uid, trạng thái thẻ, chủ thẻ |
| 5 | Nhân viên cấp thẻ mới (`UserCardDao.replace`): lượt gửi đang chạy chuyển sang thẻ mới |

**Thử**: đăng nhập `student1`, báo mất `04A1B2C3`. Chạy `ScenarioSender` kịch bản `lostcard`: phản hồi nhịp tim có thẻ trong `blocked_cards` và phiên cho `LOST_CARD_USED`. Đăng nhập `operator1`, thay thẻ: `SELECT card_id FROM Deposit WHERE status = 'ACTIVE'` đổi sang thẻ mới.

### 11.5 Trường hợp 4: đặt ngăn trước, không đến

**Đọc trước**: DE01 "đặt ngăn trước", "gia hạn trực tuyến" (Tương tác nổi bật).

**Files**: `dao/DepositDao.java` (các hàm gọi thủ tục), `controller/BookingController.java`, `views/booking.jsp`; biểu mẫu nằm sẵn trong khung chi tiết ngăn của bản đồ.

**Mẫu `DepositDao`**

```java
// src/java/dao/DepositDao.java
package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import model.Deposit;

public class DepositDao {

    public long reserve(int userId, int slotId, int planId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Reserve(?, ?, ?, ?)}")) {
            cs.setInt(1, userId);
            cs.setInt(2, slotId);
            cs.setInt(3, planId);
            cs.registerOutParameter(4, Types.BIGINT);
            cs.execute();
            return cs.getLong(4);
        }
    }

    public void cancel(long depositId, int userId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Cancel(?, ?)}")) {
            cs.setLong(1, depositId);
            cs.setInt(2, userId);
            cs.execute();
        }
    }

    public void checkIn(int deviceId, String slotCode) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_CheckIn(?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, slotCode);
            cs.execute();
        }
    }

    public List<Map<String, String>> reservedFor(int deviceId) throws SQLException {
        String sql = "SELECT s.slot_code, c.card_uid FROM Deposit d "
                + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id "
                + "JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "JOIN UserCard c ON c.card_id = d.card_id "
                + "WHERE b.device_id = ? AND d.status = 'RESERVED'";
        List<Map<String, String>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, String> row = new LinkedHashMap<>();
                    row.put("slot_code", rs.getString(1));
                    row.put("card_uid", rs.getString(2));
                    list.add(row);
                }
            }
        }
        return list;
    }

    // ... the other methods are in your skeleton file
}
```

Danh sách việc đầy đủ của `DepositDao` ở mục 6.2.

**Mẫu `BookingController`**

```java
// src/java/controller/BookingController.java
package controller;

import dao.DepositDao;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

@WebServlet(name = "BookingController", urlPatterns = {"/BookingController"})
public class BookingController extends HttpServlet {

    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        try {
            User me = Web.currentUser(req);
            req.setAttribute("items", new DepositDao().listByUser(me.getUserId()));
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        DepositDao dao = new DepositDao();
        try {
            if ("reserve".equals(action)) {
                dao.reserve(me.getUserId(), Web.intParam(req, "slotId", 0), Web.intParam(req, "planId", 0));
                Web.flash(req.getSession(), "Slot reserved. Swipe your card at the locker within 15 minutes.", false);
            } else if ("cancel".equals(action)) {
                dao.cancel(Web.intParam(req, "depositId", 0), me.getUserId());
                Web.flash(req.getSession(), "Reservation cancelled.", false);
            } else if ("extend".equals(action)) {
                dao.extend(Web.intParam(req, "depositId", 0), Web.intParam(req, "minutes", 60), me.getUserId());
                Web.flash(req.getSession(), "Your time was extended.", false);
            } else {
                Web.flash(req.getSession(), "Unknown action", true);
            }
        } catch (SQLException e) {
            if (e.getErrorCode() >= 50000) {                 // our own THROW: the text is written for the user
                Web.flash(req.getSession(), e.getMessage(), true);
            } else {
                throw new ServletException(e);
            }
        }
        res.sendRedirect(backUrl(req));
    }

    private static String backUrl(HttpServletRequest req) throws UnsupportedEncodingException {
        if ("list".equals(Web.trimmed(req, "back"))) {
            return "BookingController";
        }
        return "LockerMapController?area=" + URLEncoder.encode(Web.trimmed(req, "area"), "UTF-8")
                + "&slot=" + Web.intParam(req, "slot", 0);
    }

    // ... the other methods are in your skeleton file
}
```

- `doGet(HttpServletRequest req, HttpServletResponse res)`
- `doPost(HttpServletRequest req, HttpServletResponse res)`: action = reserve | cancel | extend; the procedure checks the rules and writes the audit row

| Bước | Điều xảy ra |
|---|---|
| 1 | `student2` chọn ngăn trống của dãy có thiết bị, chọn gói, bấm Reserve. Ngăn thành `RESERVED`, giữ 15 phút, hiện đếm ngược |
| 2 | Người thứ hai bấm cùng ngăn: báo "This slot is no longer available" (50033). Mỗi người chỉ một lượt mở (50032) |
| 3 | Nhịp tim trả `reserved: [{slot_code, card_uid}]`: thiết bị chỉ cho đúng thẻ đó mở ngăn này |
| 4 | Người dùng tới, cất đồ: nhịp tim báo `occupied: true` thì `Deposit_CheckIn` đổi lượt thành `ACTIVE`, đặt `due_at` theo gói |
| 5 | Hết 15 phút mà ngăn vẫn trống: `LockerMonitor` chạy `Deposit_ExpireNoShow`: `NO_SHOW`, ngăn `AVAILABLE`. **Thiết bị đang offline thì không xét** |
| 6 | Ba lần `NO_SHOW` trong 7 ngày: không đặt trước được nữa (50031), vẫn gửi trực tiếp bằng thẻ. Không cần bảng phạt riêng |
| 7 | Gia hạn trực tuyến: tối đa 3 lần, mỗi lần 15 đến 240 phút. Huỷ giữ chỗ khi còn `RESERVED` |

**Thử**

1. Đăng nhập `student2`, đặt ngăn `A04` của Library. Bản đồ: ngăn vàng.
2. Chạy `ScenarioSender` kịch bản `checkin`: lượt gửi `ACTIVE`, ngăn xanh dương.
3. Muốn thấy `NO_SHOW` mà không chờ 15 phút (dùng cả khi quay video), chạy trong SSMS rồi đợi tối đa 30 giây:
   ```sql
   UPDATE Deposit SET hold_until = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE status = 'RESERVED';
   ```
4. Gói **Demo 2 minutes** (gói `OVERDUE` nhanh): gửi bằng gói này, quá 3 phút thì ngăn chuyển cam `OVERDUE`.

### 11.6 Trường hợp 5: cảm biến hỏng

**Đọc trước**: DE01 bảng `SensorType` (`min_valid`, `max_valid`) và `Calibration`; bảng này chính là chỗ luật `SENSOR_FAULT` lấy khoảng hợp lệ.

Các file đã làm ở giai đoạn 7 (`RuleEngine`, `AlertService`, `MaintenanceDao`) và mục 6.4 (hiệu chuẩn).

| Bước | Điều xảy ra |
|---|---|
| 1 | Phiên có khối lượng -5000 g (ngoài `[-200, 20000]`), hoặc đồng hồ thiết bị chạy trước máy chủ hơn 5 phút, hoặc hiệu chuẩn `WEIGHT` hết hạn |
| 2 | `RuleEngine` luật số 1: `SENSOR_FAULT`. **Không** kết luận `FORCED_OPEN`, không đưa vào mô hình |
| 3 | `Ticket_OpenForFault`: ngăn thành `MAINTENANCE` (xám trên bản đồ, không đặt được); một phiếu cho mỗi thiết bị, giao cho kỹ thuật viên **ít việc nhất** |
| 4 | Kỹ thuật viên sửa, thêm hiệu chuẩn mới, đóng phiếu: `Ticket_Close` trả ngăn về `AVAILABLE`, cảnh báo `RESOLVED` |

**Thử**: chạy `ScenarioSender` kịch bản `sensor`. Trang Alerts có `SENSOR_FAULT`; ngăn A01 xám; đăng nhập `tech1` hoặc `tech2` thấy phiếu mới; đóng phiếu thì ngăn trở lại.

**Cột mốc cuối giai đoạn 8**: sáu kịch bản của `ScenarioSender` cho đúng kết quả ở các bảng trên; `test_scenarios.sql` xanh 45 dòng.

## 12. Giai đoạn 9: học máy

Mục tiêu: một bảng so sánh 4 thuật toán (accuracy, precision, recall, F1) đặt cạnh kết quả của bài báo gốc, và `RiskScorer` chấm điểm phiên bằng mô hình thắng.

### 12.1 `sql/02_workshop2.sql`

**Đọc trước**: DE01 WS2 B1 (nạp dữ liệu công khai). Dữ liệu: `research.unsw.edu.au/projects/toniot-datasets`, thư mục `Train_Test_datasets`, tệp `Train_Test_IoT_Garage_Door.csv`.

**Việc**: bảng `PublicSession` và câu lệnh gom mỗi 20 hàng liên tiếp thành một phiên.

**Mẫu**

```sql
-- ============================================================
-- 02_workshop2.sql  The public data set (TON_IoT garage door) turned into sessions.
-- Run it in two rounds: part 1 now, then import the csv, then part 2.
-- Source of the file: research.unsw.edu.au/projects/toniot-datasets, folder Train_Test_datasets,
-- file Train_Test_IoT_Garage_Door.csv
-- ============================================================
USE PRJ301_LOCKER;
GO

-- ===== Part 1. The table the sessions go into =====
-- Same feature names as the device sends, so the model trained here can score device sessions.
CREATE TABLE PublicSession (
    public_id      INT IDENTITY PRIMARY KEY,
    door_open_sec  FLOAT,
    weight_delta_g FLOAT,
    unlock_count   INT,
    rfid_ok        BIT,
    stay_min       FLOAT,
    label          NVARCHAR(40),
    sent           BIT DEFAULT 0);
GO

-- ===== Import the csv =====
-- In SSMS: right click the database PRJ301_LOCKER, Tasks, Import Flat File, choose the csv and
-- type RawGarageDoor as the table name. Do NOT create RawGarageDoor yourself, the wizard creates it.
-- Then look at what it made, the query of part 2 needs the columns door_state and label:
--     SELECT TOP 10 * FROM RawGarageDoor;
--     SELECT label, COUNT(*) FROM RawGarageDoor GROUP BY label;
-- If the names differ in your file, change them in part 2.

-- ===== Part 2. Group the rows into sessions =====
-- Every 20 consecutive rows become one simulated session; a row is about 3 seconds.
-- A session is NORMAL when none of its rows is an attack, FORCED_OPEN otherwise.
-- ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) keeps no real order. If the file has date and time columns,
-- put them in the ORDER BY: ORDER BY [date], [time].
WITH numbered AS (
    SELECT *, (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) / 20 AS session_no
    FROM RawGarageDoor
)
INSERT INTO PublicSession (door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, label)
SELECT SUM(CASE WHEN door_state = 'open' THEN 3 ELSE 0 END),          -- seconds with the door open
       0,                                                              -- the public data has no weight
       COUNT(*),                                                       -- 20, a placeholder for unlock_count
       MIN(CASE WHEN label = 0 THEN 1 ELSE 0 END),                     -- 1 only if every row is normal
       20.0,
       CASE WHEN MAX(label) = 0 THEN 'NORMAL' ELSE 'FORCED_OPEN' END
FROM numbered
GROUP BY session_no;
GO

-- ===== Check. A few hundred sessions and a few dozen of each label are needed for the training to mean anything =====
SELECT COUNT(*) AS total_sessions FROM PublicSession;
SELECT label, COUNT(*) AS n FROM PublicSession GROUP BY label ORDER BY n DESC;
GO
```

**Khung bạn làm**: `sql/02_workshop2.sql` trong project có bốn `TODO`.

Các bước: chạy phần 1; import tệp csv bằng SSMS (**Tasks, Import Flat File**, đặt tên bảng `RawGarageDoor`, **đừng tạo bảng trước**); xem bảng wizard vừa tạo (`SELECT TOP 10 * FROM RawGarageDoor`) rồi chạy phần 2.

**Lưu ý trung thực**

- **Mình chưa tải tệp này**, nên chưa xác nhận tên cột của nó. Câu lệnh cần cột `door_state` (giá trị `open`/`closed`) và `label` (0 bình thường, 1 tấn công). Nếu tên khác thì sửa trong phần 2. Mình đã thử câu lệnh với một bảng giả lập có các cột đó: ra 50 phiên (30 `NORMAL`, 20 `FORCED_OPEN`).
- `ROW_NUMBER() OVER (ORDER BY (SELECT NULL))` không bảo đảm thứ tự. Nếu tệp có cột ngày và giờ, đưa chúng vào `ORDER BY`.
- Cách gom của đề chỉ cho **hai nhãn** (`NORMAL`, `FORCED_OPEN`), nên mô hình học máy chỉ phân biệt hai loại này. Bốn nhãn còn lại do luật xử lý. Ghi điều đó vào báo cáo, đừng để thầy phát hiện.

### 12.2 `tool/ModelTrainer.java`

**Đọc trước**: DE01 WS2 B2 (mã `ModelTrainer`); POUR `service/WekaService.java` (cách bài mẫu nạp mô hình một lần và chấm điểm).

**Việc**: đọc `PublicSession`, chạy kiểm định chéo 10 phần cho 4 thuật toán (RandomForest, J48, NaiveBayes, IBk), in bảng, huấn luyện thuật toán thắng (F1 trọng số cao nhất) trên toàn bộ dữ liệu, lưu hai tệp vào `src/java/ml/`: `locker_model.bin` (mô hình) và `locker_header.arff` (tên thuộc tính và nhãn, không có hàng).

Tách thành các hàm nhỏ (`build`, `compare`, `save`, `readTable`) để thử bằng dữ liệu bộ nhớ không cần database.

**Mẫu**

```java
// src/java/tool/ModelTrainer.java
package tool;

import dao.DbContext;
import java.io.File;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.bayes.NaiveBayes;
import weka.classifiers.lazy.IBk;
import weka.classifiers.trees.J48;
import weka.classifiers.trees.RandomForest;
import weka.core.Attribute;
import weka.core.DenseInstance;
import weka.core.Instances;
import weka.core.SerializationHelper;

public class ModelTrainer {

    public static void main(String[] args) throws Exception {
        Instances data = loadFromDatabase("SELECT " + String.join(", ", FEATURES)
                + ", label FROM PublicSession WHERE label IS NOT NULL");
        Classifier best = compare(data);
        save(best, data, new File("src/java/ml"));
    }

    public static Classifier compare(Instances data) throws Exception {
        Map<String, Classifier> models = new LinkedHashMap<String, Classifier>();
        models.put("RandomForest", new RandomForest());
        models.put("J48", new J48());
        models.put("NaiveBayes", new NaiveBayes());
        models.put("IBk", new IBk(5));

        System.out.printf("%-14s %9s %10s %8s %8s%n", "model", "accuracy", "precision", "recall", "f1");
        Classifier best = null;
        double bestF1 = -1;
        for (Map.Entry<String, Classifier> entry : models.entrySet()) {
            Evaluation eval = new Evaluation(data);
            eval.crossValidateModel(entry.getValue(), data, 10, new Random(42));
            System.out.printf("%-14s %9.4f %10.4f %8.4f %8.4f%n", entry.getKey(), eval.pctCorrect() / 100,
                    eval.weightedPrecision(), eval.weightedRecall(), eval.weightedFMeasure());
            if (eval.weightedFMeasure() > bestF1) {
                bestF1 = eval.weightedFMeasure();
                best = entry.getValue();
            }
        }
        best.buildClassifier(data);          // cross validation trained copies; train the winner on every row
        return best;
    }

    public static void save(Classifier model, Instances data, File folder) throws Exception {
        folder.mkdirs();
        SerializationHelper.write(new File(folder, "locker_model.bin").getPath(), model);
        try (PrintWriter out = new PrintWriter(new File(folder, "locker_header.arff"), "UTF-8")) {
            out.print(new Instances(data, 0).toString());
        }
        System.out.println("saved the model to " + folder.getAbsolutePath());
    }

    public static Instances build(List<double[]> rows, List<String> rowLabels) {
        List<String> labels = new ArrayList<String>();
        for (String label : rowLabels) {
            if (!labels.contains(label)) {
                labels.add(label);
            }
        }
        return build(rows, rowLabels, labels);
    }

    public static Instances build(List<double[]> rows, List<String> rowLabels, List<String> labels) {
        ArrayList<Attribute> attributes = new ArrayList<Attribute>();
        for (String name : FEATURES) {
            attributes.add(new Attribute(name));
        }
        attributes.add(new Attribute("label", labels));
        Instances data = new Instances("locker", attributes, rows.size());
        data.setClassIndex(attributes.size() - 1);
        for (int i = 0; i < rows.size(); i++) {
            double[] values = new double[FEATURES.length + 1];
            System.arraycopy(rows.get(i), 0, values, 0, FEATURES.length);
            values[FEATURES.length] = labels.indexOf(rowLabels.get(i));
            data.add(new DenseInstance(1.0, values));
        }
        return data;
    }

    public static Instances loadFromDatabase(String sql) throws Exception {
        Table t = readTable(sql);
        return build(t.rows, t.labels);
    }

    public static Table readTable(String sql) throws Exception {
        Table table = new Table();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                double[] values = new double[FEATURES.length];
                for (int i = 0; i < FEATURES.length; i++) {
                    values[i] = rs.getDouble(FEATURES[i]);
                }
                table.rows.add(values);
                table.labels.add(rs.getString("label"));
            }
        }
        return table;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `main(String[] args)`: load the table, compare, save the winner
- `compare(Instances data)`: crossValidateModel(model, data, 10, new Random(42)), weighted precision, recall and F1
- `save(Classifier model, Instances data, File folder)`: SerializationHelper.write and an empty copy of the data as the header
- `build(List<double[]> rows, List<String> rowLabels)`: the class labels are the distinct texts, in the order they appear
- `build(List<double[]> rows, List<String> rowLabels, List<String> labels)`: numeric attributes, one nominal class, the class is the last column
- `loadFromDatabase(String sql)`
- `readTable(String sql)`: one double per feature, the label as text

**Đã kiểm chứng** với 600 dòng dữ liệu giả lập (400 bình thường, 200 mở cưỡng bức): bảng in đủ 4 dòng, hai tệp được tạo, và `RiskScorer` đọc lại được trong một JVM mới: phiên bình thường cho điểm 0,000, phiên mở cưỡng bức cho 1,000. Dữ liệu giả lập tách bạch hoàn toàn nên điểm F1 là 1,000: đừng đưa số này vào báo cáo.

**Dễ sai**

- `weka-stable-3.8.6.jar` thiếu thư viện phụ, lỗi `NoClassDefFoundError: org/bounce/...` (mục 2.3).
- `new Attribute("label", labels)` cần `List<String>`. Danh sách nhãn phải **cùng thứ tự** giữa lúc huấn luyện và lúc chấm điểm: vì vậy `RiskScorer` tìm vị trí của `NORMAL` bằng `indexOfValue("NORMAL")` thay vì đoán số 0.
- Quên huấn luyện lại thuật toán thắng trên toàn bộ dữ liệu (`best.buildClassifier(data)`): kiểm định chéo huấn luyện các bản sao, bản gốc chưa được huấn luyện.
- Chạy bằng Run File từ NetBeans thì thư mục làm việc là thư mục project, nên `src/java/ml` nằm đúng chỗ. Chạy từ dòng lệnh ở thư mục khác thì tệp rơi nhầm chỗ.

**Dùng trong báo cáo**: bảng đề yêu cầu "đặt 4 thuật toán và mốc so sánh trong cùng một bảng". Mốc là kết quả của Alsaedi và cộng sự (IEEE Access, 2020) trên TON_IoT: tìm bảng của tập dữ liệu **Garage Door** trong bài báo và chép các số đó, kèm lưu ý rằng cách chia dữ liệu và nhãn của bạn khác nên so sánh chỉ mang tính tham khảo.

| Mô hình | Accuracy | Precision | Recall | F1 |
|---|---|---|---|---|
| RandomForest | (số của bạn) | | | |
| J48 | | | | |
| NaiveBayes | | | | |
| IBk (k=5) | | | | |
| Alsaedi và cộng sự, 2020 (Garage Door) | (số trong bài báo) | | | |

Giải thích lý do chọn thuật toán thắng trong báo cáo: F1 trọng số cao nhất, thời gian dự đoán đủ nhanh cho từng phiên.

### 12.3 `service/RiskScorer.java`

**Đọc trước**: POUR `service/WekaService.java` (nạp mô hình một lần, `distributionForInstance`, điểm rủi ro = tổng xác suất các lớp bất thường).

**Việc**: nạp hai tệp từ classpath (`/ml/...`) **một lần**, rồi `score(session)` trả `1 - P(NORMAL)` từ 0 đến 1. Không tìm thấy mô hình thì trả 0, nên hệ thống chạy được chỉ với luật cho đến khi bạn huấn luyện xong. Điều này tránh mọi lỗi khi chưa có tệp.

**Mẫu**

```java
// src/java/service/RiskScorer.java
package service;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.logging.Logger;
import model.LockerSession;
import weka.classifiers.Classifier;
import weka.core.DenseInstance;
import weka.core.Instance;
import weka.core.Instances;
import weka.core.SerializationHelper;

public class RiskScorer {

    public static synchronized RiskScorer getInstance() {
        if (instance == null) {
            instance = load();
        }
        return instance;
    }

    public static RiskScorer fromStreams(InputStream modelStream, InputStream headerStream) throws Exception {
        Classifier model = (Classifier) SerializationHelper.read(modelStream);
        Instances header = new Instances(new BufferedReader(new InputStreamReader(headerStream, StandardCharsets.UTF_8)));
        header.setClassIndex(header.numAttributes() - 1);
        return new RiskScorer(model, header);
    }

    public double score(LockerSession s) {
        if (model == null || normalIndex < 0) {
            return 0.0;
        }
        try {
            double[] values = new double[header.numAttributes()];
            for (int i = 0; i < header.numAttributes(); i++) {
                if (i != header.classIndex()) {
                    values[i] = featureValue(header.attribute(i).name(), s);
                }
            }
            Instance row = new DenseInstance(1.0, values);
            row.setDataset(header);
            double[] distribution = model.distributionForInstance(row);
            return Math.min(1.0, Math.max(0.0, 1.0 - distribution[normalIndex]));
        } catch (Exception e) {
            LOG.warning("Scoring failed, answering 0: " + e.getMessage());
            return 0.0;
        }
    }

    private static RiskScorer load() {
        try (InputStream modelStream = RiskScorer.class.getResourceAsStream("/ml/locker_model.bin");
             InputStream headerStream = RiskScorer.class.getResourceAsStream("/ml/locker_header.arff")) {
            if (modelStream == null || headerStream == null) {
                LOG.warning("No model in /ml (locker_model.bin, locker_header.arff): scores will be 0. Run tool.ModelTrainer.");
                return new RiskScorer(null, null);
            }
            return fromStreams(modelStream, headerStream);
        } catch (Exception e) {
            LOG.warning("Could not load the model: " + e.getMessage());
            return new RiskScorer(null, null);
        }
    }

    private static double featureValue(String name, LockerSession s) {
        switch (name) {
            case "door_open_sec":  return s.getDoorOpenSec();
            case "weight_delta_g": return s.getWeightDeltaG();
            case "unlock_count":   return s.getUnlockCount();
            case "rfid_ok":        return s.isRfidOk() ? 1 : 0;
            case "stay_min":       return s.getStayMin();
            default: throw new IllegalArgumentException("Unknown feature " + name);
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `getInstance()`: load once, keep it; a missing or broken file gives a scorer that always answers 0
- `fromStreams(InputStream modelStream, InputStream headerStream)`: SerializationHelper.read for the model, new Instances(reader) for the ARFF header
- `score(LockerSession s)`: fill one instance by attribute name, distributionForInstance, 1 - P(NORMAL)

**Tự kiểm tra**: sau khi `ModelTrainer` chạy xong, **Clean and Build** (để NetBeans chép `src/java/ml/*` vào `WEB-INF/classes/ml`), khởi động lại Tomcat, rồi chạy `DataReplayer`. Trong `Alert` có dòng `source = 'ML'`, `risk_score` từ 0,80 trở lên, và dòng `RULE` có `risk_score` đi kèm làm bằng chứng phụ.

### 12.4 `tool/DataReplayer.java`

**Đọc trước**: DE01 WS2 B3 (`DataReplayer`).

**Việc**: phát lại `PublicSession` qua đúng API của thiết bị, có mô phỏng mất mạng 15% để thử bộ đệm. Khác mã mẫu: gửi `rs.getBoolean` chứ không `getDouble`, giờ UTC, chỉ xoá bộ đệm khi máy chủ trả 200.

**Mẫu**

```java
// src/java/tool/DataReplayer.java
package tool;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import dao.DbContext;
import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Random;
import java.util.TimeZone;

public class DataReplayer {

    public static void main(String[] args) throws Exception {
        SimpleDateFormat stamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        stamp.setTimeZone(TimeZone.getTimeZone("UTC"));      // the server works in UTC, not in your time zone
        Random random = new Random();
        JsonArray buffer = new JsonArray();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min "
                     + "FROM PublicSession ORDER BY public_id")) {
            while (rs.next()) {
                JsonObject session = new JsonObject();
                session.addProperty("seq", ++seq);
                session.addProperty("measured_at", stamp.format(new Date()));
                session.addProperty("door_open_sec", rs.getDouble("door_open_sec"));
                session.addProperty("weight_delta_g", rs.getDouble("weight_delta_g"));
                session.addProperty("unlock_count", rs.getInt("unlock_count"));
                session.addProperty("rfid_ok", rs.getBoolean("rfid_ok"));   // a real boolean, not 1.0
                session.addProperty("stay_min", rs.getDouble("stay_min"));
                buffer.add(session);

                if (random.nextDouble() < DROP_RATE) {
                    System.out.println("network down, buffered sessions: " + buffer.size());
                    continue;                                 // keep the sessions in the buffer
                }
                if (buffer.size() >= BATCH_LIMIT || random.nextDouble() < 0.5) {
                    if (send(buffer)) {
                        buffer = new JsonArray();
                    }
                }
                Thread.sleep(200);
            }
            send(buffer);                                     // flush whatever is left
        }
    }

    private static boolean send(JsonArray sessions) throws IOException {
        if (sessions.size() == 0) {
            return true;
        }
        JsonObject body = new JsonObject();
        body.add("sessions", sessions);                       // the device id comes from the API key
        HttpURLConnection conn = (HttpURLConnection) new URL(API_URL).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
        conn.setRequestProperty("X-API-Key", API_KEY);
        try (OutputStream out = conn.getOutputStream()) {
            out.write(body.toString().getBytes("UTF-8"));
        }
        int code = conn.getResponseCode();
        System.out.println("sent " + sessions.size() + " sessions, server replied " + code);
        conn.disconnect();
        return code == 200;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `main(String[] args)`: read PublicSession, buffer rows, send a batch when the "network" is up
- `send(JsonArray sessions)`: POST with the X-API-Key header; keep the buffer when the answer is not 200

**Chú ý**: `API_URL` chứa tên project (`/SmartLocker/`). Nếu bạn đổi context path ở `context.xml` thì sửa theo, nếu không nhận 404.

## 13. Giai đoạn 10: dashboard

Trang tổng quan có số liệu và biểu đồ vẽ bằng thẻ `canvas` (không tải thư viện từ Internet, vì máy phòng thi có thể không có mạng).

**Files**: `dao/DashboardDao.java`, `api/DashboardApi.java`, `controller/DashboardController.java`, `views/dashboard.jsp` (đã hoàn chỉnh).

**Mẫu `DashboardDao.recentSessions` và `DashboardApi`**

```java
// src/java/dao/DashboardDao.java
package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class DashboardDao {

    public List<Map<String, Object>> recentSessions(int deviceId, int limit) throws SQLException {
        String sql = "SELECT TOP (?) CONVERT(VARCHAR(19), measured_at, 120) AS t, door_open_sec, weight_delta_g "
                + "FROM LockerSession WHERE device_id = ? ORDER BY measured_at DESC";
        List<Map<String, Object>> points = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            ps.setInt(2, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> p = new LinkedHashMap<>();
                    p.put("time", rs.getString("t"));
                    p.put("a", rs.getDouble("door_open_sec"));
                    p.put("b", rs.getDouble("weight_delta_g"));
                    points.add(0, p);
                }
            }
        }
        return points;
    }

    // ... the other methods are in your skeleton file
}
```

```java
// src/java/api/DashboardApi.java
package api;

import com.google.gson.Gson;
import dao.DashboardDao;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Web;

@WebServlet(name = "DashboardApi", urlPatterns = {"/api/dashboard"})
public class DashboardApi extends HttpServlet {

    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        int deviceId = Web.intParam(req, "device", 1);
        try {
            String json = new Gson().toJson(new DashboardDao().recentSessions(deviceId, 50));
            res.setContentType("application/json;charset=UTF-8");
            res.setHeader("Cache-Control", "no-store");
            res.getWriter().write(json);
        } catch (SQLException e) {
            log("Dashboard data failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `recentSessions(int deviceId, int limit)`: TOP (?) newest first in SQL, then reversed in Java
- `lockerCounts()`: one query on v_LockerSlotMap grouped by display_status, plus COUNT of OPEN alerts and OFFLINE devices

- (the work is described in the comments of the file)

`dashboard.jsp` đọc các thuộc tính sau (đều tuỳ chọn, thiếu thì hiện 0): `counts` (Map với `free`, `inUse`, `overdue`, `openAlerts`, `offlineDevices`), `devices`, `roleLabels`, `roleValues`. Biểu đồ gọi `/api/dashboard?device=1` mỗi 5 giây.

**Tự kiểm tra**: chạy `DataReplayer`; biểu đồ "Live sessions" tự dài ra không cần tải lại trang. Tắt `ScenarioSender`; thẻ "Devices offline" tăng sau khoảng 90 giây.

## 14. Khi có thiết bị thật (tuần sau) và phần mở rộng +2 điểm

Phía web **không phải sửa gì**: ESP32 gửi đúng hai loại JSON ở mục 9.2 tới đúng hai địa chỉ. Việc của firmware:

| Việc | Ghi chú |
|---|---|
| Kết nối Wi-Fi và lấy giờ UTC bằng NTP (`configTime(0, 0, "pool.ntp.org")`) | Giờ sai thì phiên bị đánh `SENSOR_FAULT` (đồng hồ chạy trước máy chủ quá 5 phút) |
| Gửi nhịp tim mỗi 10 giây tới `http://<IP máy chủ>:8080/SmartLocker/api/health` với header `X-API-Key: device-1-api-key` | Gửi kèm `slots`: ngăn nào đang có đồ (loadcell vượt khoảng 30 g) |
| Đọc phản hồi bằng ArduinoJson, **giữ trong RAM** `blocked_cards` và `reserved` | Mất mạng vẫn dùng danh sách cũ |
| Khi quẹt thẻ: thẻ nằm trong `blocked_cards` thì đèn đỏ, không mở; ngăn đã `reserved` cho thẻ khác thì không mở | Đây là phần của trường hợp 3 và 4 chạy ngay tại tủ |
| Nhận lệnh `UNLOCK` thì mở khoá và đánh dấu phiên hiện tại `open_source = "REMOTE"`, `command_id = ...` | Trường hợp 2 |
| Khi một phiên kết thúc, đóng gói 5 số đo + 4 trường phụ, đưa vào hàng đợi, gửi cả lô tới `/api/locker/batch` | Dùng `enqueue` và `flushQueue` của mã mẫu DE01 phần "Mở rộng" |

**Đọc trước**: DE01 phần "Mở rộng khuyến khích" (khung mã ESP32 với `enqueue`, `flushQueue`); POUR `pouring_system/pouring_system.ino` dòng 1258 (gửi lô phiên bằng `HTTPClient`) và 1698 (gửi nhịp tim). Các `server.on("/pour", ...)` ở dòng 1490 trở đi **không cần** cho bản của ta: bài mẫu mở một máy chủ nhỏ trên ESP32 để web gọi vào, còn ta để ESP32 hỏi.

Mình **không** viết sẵn mã Arduino vì không có cách biên dịch và thử ở đây; viết mã chưa kiểm chứng rồi đưa cho bạn thì rủi ro hơn là để trống.

**Mạng**: máy chạy Tomcat và ESP32 phải cùng Wi-Fi. Lấy IP của máy bằng `ipconfig` (dòng IPv4 của bộ điều hợp Wi-Fi). Tường lửa Windows chặn kết nối vào cổng 8080 theo mặc định: đây là lỗi hay gặp nhất khi cắm thiết bị thật. Cho phép bằng **Windows Defender Firewall, Advanced settings, Inbound Rules, New Rule, Port 8080** (hoặc mở một cửa sổ PowerShell chạy bằng quyền Administrator). IP của máy đổi khi đổi mạng, cần sửa lại trong firmware.

### 14.1 Thu 100 phiên thật có nhãn

Phiên của thiết bị chỉ dùng được cho `TransferCheck` khi có nhãn trong `LockerSessionLabel`. Cách tạo từng loại (đề gợi ý khoảng 100 phiên):

| Nhãn | Tạo trên tủ thật | Số phiên |
|---|---|---|
| NORMAL | Quẹt thẻ, cất đồ, đóng cửa, quẹt lại, lấy đồ | khoảng 40 |
| OVERDUE | Dùng gói "Demo 2 minutes", để quá 3 phút | khoảng 12 |
| FORCED_OPEN | Mở cửa không quẹt thẻ | khoảng 12 |
| WRONG_USER | Thẻ của người này mở ngăn của người khác | khoảng 12 |
| ITEM_LEFT | Lấy đồ nhưng để quên một món | khoảng 12 |
| SUSPECTED_SPOOF | Áp nam châm vào công tắc từ khi mở cửa | khoảng 12 |

Gán nhãn trong SSMS ngay sau mỗi phiên (đề đặt nhãn ở bảng riêng vì phiên không sửa được):

```sql
INSERT INTO LockerSessionLabel (session_id, label, labeled_by)
VALUES (123, N'NORMAL', (SELECT user_id FROM Users WHERE username = N'operator1'));
```

Phiên `STAFF_OPEN` và `SENSOR_FAULT` tự bị loại khỏi `v_LockerSession_Features`.

### 14.2 `tool/TransferCheck.java`: điểm mới của đề

**Đọc trước**: DE01 phần "Mở rộng khuyến khích" (`TransferCheck`) và dòng "Điểm mới cần đạt": huấn luyện trên dữ liệu công khai rồi kiểm tra lại trên tủ thật, đo mức suy giảm.

**Mã mẫu của đề có lỗi**: nó huấn luyện trên `PublicSession` (nhãn `NORMAL`, `FORCED_OPEN`) rồi đánh giá trên dữ liệu thiết bị có thêm các nhãn khác. Mỗi tập tự lập danh sách nhãn, nên số thứ tự của nhãn (0, 1, 2...) không còn cùng nghĩa giữa hai tập: kết quả sai, hoặc Weka báo lỗi. Bản dưới đây đưa **cả hai** về hai nhãn `NORMAL` và `ABNORMAL` (mọi nhãn khác `NORMAL` là bất thường) và dựng cả hai bằng cùng danh sách nhãn.

**Mẫu**

```java
// src/java/tool/TransferCheck.java
package tool;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
import tool.ModelTrainer.Table;
import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.trees.RandomForest;
import weka.core.Instances;

public class TransferCheck {

    public static void main(String[] args) throws Exception {
        Table publicSessions = ModelTrainer.readTable("SELECT " + COLUMNS + " FROM PublicSession WHERE label IS NOT NULL");
        Table deviceSessions = ModelTrainer.readTable("SELECT " + COLUMNS + " FROM v_LockerSession_Features");
        double[] f1 = run(publicSessions, deviceSessions);
        System.out.printf("F1 on public data (10-fold cross validation): %.3f%n", f1[0]);
        System.out.printf("F1 on real device data                      : %.3f%n", f1[1]);
        System.out.printf("drop when moving from the lab to the device : %.3f%n", f1[0] - f1[1]);
    }

    public static double[] run(Table publicSessions, Table deviceSessions) throws Exception {
        Instances publicData = ModelTrainer.build(publicSessions.rows, binary(publicSessions.labels), LABELS);
        Instances deviceData = ModelTrainer.build(deviceSessions.rows, binary(deviceSessions.labels), LABELS);

        Classifier model = new RandomForest();
        Evaluation crossValidation = new Evaluation(publicData);
        crossValidation.crossValidateModel(model, publicData, 10, new Random(42));

        model.buildClassifier(publicData);
        Evaluation onDevice = new Evaluation(publicData);
        onDevice.evaluateModel(model, deviceData);
        return new double[]{crossValidation.weightedFMeasure(), onDevice.weightedFMeasure()};
    }

    private static List<String> binary(List<String> labels) {
        List<String> out = new ArrayList<String>();
        for (String label : labels) {
            out.add("NORMAL".equals(label) ? "NORMAL" : "ABNORMAL");
        }
        return out;
    }

    // ... the other methods are in your skeleton file
}
```

**Khung bạn làm**

- `main(String[] args)`: read the two tables, call run(), print the drop
- `run(Table publicSessions, Table deviceSessions)`: build both with the same two labels; cross validate; train on everything; evaluateModel on the device data

**Đã kiểm chứng bằng dữ liệu giả lập** (không phải kết quả thật): khi dữ liệu thiết bị cùng phân phối với dữ liệu công khai thì F1 là 1,000 cả hai; khi dịch chuyển phân phối (cửa mở lâu hơn, ngắn hơn) thì F1 trên thiết bị giảm còn 0,175, chênh 0,825. Con số thật của bạn sẽ nằm giữa hai cực này. Giá trị cần báo cáo là **hiệu hai dòng F1** do chương trình in ra.

## 15. Nộp bài

### 15.1 Đối chiếu yêu cầu của đề

| Yêu cầu (DE01, Assignment) | Bạn có |
|---|---|
| 15 bảng | 24 bảng sau `01_schema.sql`, thêm `PublicSession` và `RawGarageDoor` khi nạp dữ liệu |
| 12 servlet làm Controller | 20 controller và 4 servlet API |
| 12 trang JSP | 20 trang JSP và `common/nav.jspf` |
| 10 stored procedure | 17 (`Audit_Append` và 16 thủ tục ở `03_scenarios.sql`) |
| 2 view | `v_LockerSession_Features`, `v_LockerSlotMap` |
| 2 API | `/api/health`, `/api/locker/batch`, cộng `/api/locker-map`, `/api/dashboard` |
| Phân quyền đủ 5 vai trò | Mục 1, bảng quyền, kiểm tra bởi `SecurityFilter` |
| Tương tác nổi bật: sơ đồ dãy tủ tô màu, đặt ngăn trước, gia hạn trực tuyến, xác nhận mở tủ từ xa | Mục 7 và mục 11 |
| Tương tác chung: tìm kiếm, lọc, phân trang, xuất CSV, từ cảnh báo tới chi tiết phiên và phiếu, hộp xác nhận cho lệnh điều khiển | Mục 6, 10.7, 11.3 |
| Luật cảnh báo cho đủ 6 nhãn, mỗi cảnh báo kèm bằng chứng | `RuleEngine`, mục 10 |
| Mô hình Weka tích hợp vào `RiskScorer`, giải thích lý do chọn | Mục 12 |
| Bảng 4 thuật toán và mốc so sánh | Mục 12.2 |
| Tối thiểu 10 ca TestNG, có ca phát hiện sửa trái phép nhật ký | 21 ca: 12 + 5 + 4 |
| Kho GitHub công khai có README, video không quá 5 phút, báo cáo kỹ thuật | Mục 15.3 đến 15.5 |
| Mở rộng (+2 điểm): thiết bị thật và `TransferCheck` | Mục 14 |

"Thực thể dùng chung" cũng cần đủ bốn thao tác. Hỏi thầy chính xác những thực thể nào được tính; an toàn nhất là: người dùng, vai trò (quyền), thiết bị (đặt `ACTIVE`/`MAINTENANCE`), hiệu chuẩn, cảnh báo (xử lý), phiếu bảo trì (đóng). Đề trong khung chưa có trang riêng cho `Device`, `SensorType`, `OperatingProfile`; thêm theo mục phụ lục B nếu thầy yêu cầu.

### 15.2 Dọn trước khi nộp

- [ ] Xoá thư mục `web/demo`. Trong `web/index.html` bỏ nút demo và đổi thành chuyển hướng tới `LoginController`. Trong `SecurityFilter` bỏ `/demo/` khỏi `PUBLIC_PREFIXES`.
- [ ] `DbContext.java`: đừng để mật khẩu `sa` thật trong kho công khai. Dùng đúng giá trị mà đề nói, hoặc ghi vào README rằng cần sửa.
- [ ] Chép các jar vào project (mục 2.2) để máy khác mở không bị lỗi đường dẫn `E:\`.
- [ ] Xoá `docs/demo-code` và `docs/HUONG_DAN_TUNG_FILE.md` khỏi kho nộp (đây là tài liệu học của bạn, không phải sản phẩm).
- [ ] Chạy lại `01_schema.sql`, `02_workshop2.sql`, `03_scenarios.sql` trên máy sạch để chắc chắn chạy một mạch.
- [ ] Chạy toàn bộ test; kịch bản `ScenarioSender` đủ sáu cái.

### 15.3 Kho GitHub

```
.gitignore:
build/
dist/
nbproject/private/
*.class
```

`README.md` cần có: mô tả hệ thống, sơ đồ kiến trúc (mục 1), cách chạy (thư viện, chạy ba file SQL theo thứ tự, sửa `DbContext`, Run), bảng tài khoản mẫu và vai trò, cách chạy `ScenarioSender` và `DataReplayer`, cách huấn luyện mô hình, cách chạy test, kết quả bảng 4 thuật toán.

### 15.4 Video không quá 5 phút

| Thời gian | Nội dung |
|---|---|
| 0:00 đến 0:40 | Đăng nhập lần lượt các vai trò; menu khác nhau; sơ đồ tủ tô màu |
| 0:40 đến 1:30 | `DataReplayer` phát dữ liệu; dashboard tự cập nhật; cảnh báo nền |
| 1:30 đến 3:30 | Năm trường hợp, mỗi trường hợp khoảng 25 giây (`ScenarioSender` hoặc tủ thật) |
| 3:30 đến 4:15 | Sửa một dòng `AuditLog` trong SSMS; nút Verify chỉ đúng dòng đó |
| 4:15 đến 5:00 | Bảng 4 thuật toán và mốc so sánh; kết quả `TransferCheck` nếu đã có |

### 15.5 Báo cáo kỹ thuật

Khung báo cáo nằm trong tệp "Quy định chung" của đề (mình chưa có). Bài báo POUR (file `BaoCao_FinalProject_PRJ301.pdf` bạn gửi) là mẫu cách trình bày: tóm tắt, giới thiệu, công trình liên quan, phương pháp (sơ đồ khối, sơ đồ lưu đồ, thiết kế cơ sở dữ liệu), kết quả (bảng so sánh thuật toán, kiểm thử tự động), thảo luận (**hạn chế**), kết luận. Đoạn "Empirical Validation via Automated Testing" của bài báo tương ứng với ca kiểm thử sửa nhật ký của ta.

Ba điểm nên viết trung thực vì thầy hay hỏi:

- Mô hình học máy chỉ có hai nhãn do cách gom dữ liệu công khai (mục 12.1). Bốn nhãn còn lại do luật.
- Số liệu `TransferCheck` đến từ số phiên có nhãn ít; nói rõ cỡ mẫu.
- Năm trường hợp thực tế được kiểm tra bằng bộ giả lập `ScenarioSender` và bộ kiểm tra SQL; nêu cái nào đã thử trên tủ thật.

## Phụ lục A. Lỗi thật đã gặp khi dựng thử

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Invalid column name 'email'` ngay sau `ALTER TABLE ... ADD email` | Cột mới chưa dùng được trong cùng batch | Thêm `GO` |
| Chèn dữ liệu báo lỗi liên quan chỉ mục có điều kiện | `QUOTED_IDENTIFIER` đang tắt (mặc định của `sqlcmd`) | `SET QUOTED_IDENTIFIER ON` đầu file, hoặc chạy `sqlcmd -I` |
| `EXEC p 'x', @n = 1` báo cú pháp sai | T-SQL không cho biểu thức làm đối số của `EXEC` | Tính vào biến rồi truyền biến |
| Đăng nhập tài khoản `system` làm sập | `BCrypt.checkpw` ném `IllegalArgumentException` khi hash không phải BCrypt | Bắt lỗi, trả `false` |
| Phát lại dữ liệu công khai ra toàn `FORCED_OPEN` | `1.0` bị `getAsBoolean()` đọc thành `false` | Gửi và đọc kiểu boolean thật |
| Phiên bị `SENSOR_FAULT` hàng loạt | Thiếu dòng `Calibration` `WEIGHT`, hoặc giờ gửi lên là giờ địa phương | Seed hiệu chuẩn; gửi UTC |
| Bộ kiểm tra nhật ký báo "bị sửa" dù không ai sửa | `NULL` ở actor hoặc `object_id`; băm UTF-8 thay vì UTF-16LE | Luôn truyền giá trị thật; `getBytes("UTF-16LE")` |
| Khoá API không khớp | Băm `N'...'` ở SQL (UTF-16) nhưng Java băm UTF-8 | Băm chuỗi `VARCHAR` không có `N` |
| `NoClassDefFoundError: org/bounce/...` khi tạo bộ phân lớp Weka | `weka-stable-3.8.6.jar` thiếu thư viện phụ | Mục 2.3 |
| Trang JSP báo `uri ... jstl/core cannot be resolved` | Thiếu `jstl-1.2.jar` trong `WEB-INF/lib` | Đã chép sẵn vào project |
| Tên có `<` làm vỡ trang, hoặc dấu nháy phá JavaScript | In dữ liệu thô bằng `${}` | `<c:out>`; không đưa dữ liệu vào JavaScript viết thẳng trong HTML |
| Thêm controller mới nhưng mọi người đều 403 | Chưa có dòng trong `RESOURCE_BY_PATH` | Thêm dòng và dòng quyền trong `Permissions` |
| `LockerMonitor` ngừng chạy âm thầm | Ngoại lệ thoát khỏi `run()` | Bắt `SQLException` trong từng lần gọi |
| Trong JavaScript `form.action` trả về một ô nhập thay vì địa chỉ | Một trường tên `action` che thuộc tính của form | Đổi tên trường |
| Luật `WRONG_USER` và `OVERDUE` không bao giờ chạy | `complete` được gọi trước `evaluate` nên lượt gửi đã `COMPLETED` | Đúng thứ tự: `evaluate` rồi `complete` |

## Phụ lục B. Thêm một trang mới

1. Tạo bảng và dòng quyền: `INSERT INTO Permissions (resource, action) VALUES (N'TÊN', N'READ'), (N'TÊN', N'WRITE')`, rồi `INSERT INTO RolePerm` cho vai trò nào được dùng.
2. Tạo `Model`, `Dao` (mọi SQL ở đây), `Controller` với `@WebServlet`.
3. Thêm một dòng vào `RESOURCE_BY_PATH` của `SecurityFilter`: `put("/XController", "TÊN")`.
4. Tạo JSP trong `WEB-INF/views`, `<c:set var="activeNav" ...>` và `<%@ include file="common/nav.jspf" %>`.
5. Thêm liên kết vào `nav.jspf` bọc trong `<c:if test="${perms.contains('TÊN:READ')}">`.
6. Mỗi thao tác ghi gọi `AuditDao.append`; mỗi POST thành công kết thúc bằng `Web.flash` và `sendRedirect`.
7. Viết ít nhất một test.

## Phụ lục C. Tìm file nằm ở mục nào

| File trong project | Mục |
|---|---|
| `sql/01_schema.sql` | 4.1 |
| `sql/02_workshop2.sql` | 12.1 |
| `sql/03_scenarios.sql` | 4.2 |
| `src/java/api/DashboardApi.java` | 13 |
| `src/java/api/HealthApi.java` | 9.4 |
| `src/java/api/LockerMapApi.java` | 7.2, 7.3 |
| `src/java/api/LockerSessionApi.java` | 9.5 |
| `src/java/controller/AlertController.java` | 10.7 |
| `src/java/controller/AuditController.java` | 8.3 |
| `src/java/controller/BookingController.java` | 11.5 |
| `src/java/controller/CalibrationController.java` | 6.4 |
| `src/java/controller/DashboardController.java` | 13 |
| `src/java/controller/DepositController.java` | 6.2 |
| `src/java/controller/LockerAreaController.java` | 6.2 |
| `src/java/controller/LockerBankController.java` | 6.2 |
| `src/java/controller/LockerMapController.java` | 7.2, 7.3 |
| `src/java/controller/LockerSlotController.java` | 6.1 |
| `src/java/controller/LoginController.java` | 5.10 |
| `src/java/controller/LogoutController.java` | 5.11 |
| `src/java/controller/MaintenanceController.java` | 10.7 |
| `src/java/controller/MyCardController.java` | 11.4 |
| `src/java/controller/RegisterController.java` | 5.11 |
| `src/java/controller/RemoteCommandController.java` | 11.3 |
| `src/java/controller/RoleController.java` | 6.6 |
| `src/java/controller/StoragePlanController.java` | 6.2 |
| `src/java/controller/UserCardController.java` | 6.3, 11.4 |
| `src/java/controller/UserController.java` | 6.5 |
| `src/java/dao/AlertDao.java` | 10.5 |
| `src/java/dao/AuditDao.java` | 5.8, 8.3 |
| `src/java/dao/CalibrationDao.java` | 6.4 |
| `src/java/dao/DashboardDao.java` | 13 |
| `src/java/dao/DbContext.java` | 5.4 |
| `src/java/dao/DepositDao.java` | 6.2, 11.5 |
| `src/java/dao/DeviceDao.java` | 9.3 |
| `src/java/dao/LockerAreaDao.java` | 6.2 |
| `src/java/dao/LockerBankDao.java` | 6.2 |
| `src/java/dao/LockerMapDao.java` | 7.2, 7.3 |
| `src/java/dao/LockerSessionDao.java` | 9.5 |
| `src/java/dao/LockerSlotDao.java` | 6.1 |
| `src/java/dao/MaintenanceDao.java` | 10.6 |
| `src/java/dao/PermissionDao.java` | 5.7, 6.6 |
| `src/java/dao/RemoteCommandDao.java` | 11.3 |
| `src/java/dao/SessionContextDao.java` | 10.4 |
| `src/java/dao/StoragePlanDao.java` | 6.2 |
| `src/java/dao/UserCardDao.java` | 6.3, 11.4 |
| `src/java/dao/UserDao.java` | 5.6, 6.5 |
| `src/java/filter/SecurityFilter.java` | 5.9 |
| `src/java/model/Alert.java` | 5.5 |
| `src/java/model/Calibration.java` | 5.5 |
| `src/java/model/Deposit.java` | 5.5 |
| `src/java/model/Device.java` | 5.5 |
| `src/java/model/LockerArea.java` | 5.5 |
| `src/java/model/LockerBank.java` | 5.5 |
| `src/java/model/LockerSession.java` | 5.5 |
| `src/java/model/LockerSlot.java` | 5.5 |
| `src/java/model/StoragePlan.java` | 5.5 |
| `src/java/model/User.java` | 5.5 |
| `src/java/model/UserCard.java` | 5.5 |
| `src/java/service/AlertService.java` | 10.5 |
| `src/java/service/AuditVerifier.java` | 8.2 |
| `src/java/service/LockerMonitor.java` | 11.1 |
| `src/java/service/RiskScorer.java` | 12.3 |
| `src/java/service/RuleEngine.java` | 10.3 |
| `src/java/service/SessionContext.java` | 10.2 |
| `src/java/service/Verdict.java` | 10.2 |
| `src/java/tool/DataReplayer.java` | 12.4 |
| `src/java/tool/ModelTrainer.java` | 12.2 |
| `src/java/tool/ScenarioSender.java` | 9.6 |
| `src/java/tool/TransferCheck.java` | 14.2 |
| `src/java/util/Csv.java` | 5.3 |
| `src/java/util/SecurityUtils.java` | 5.2 |
| `src/java/util/Todo.java` | 5.1 |
| `src/java/util/Web.java` | 5.3 |
| `test/test/AuditChainDatabaseIntegrationTest.java` | 8.4 |
| `test/test/RuleEngineTest.java` | 10.8 |
| `test/test/SecurityUtilsTest.java` | 5.14 |
| `web/WEB-INF/views/alert.jsp` | 10.7 |
| `web/WEB-INF/views/audit.jsp` | 8.3 |
| `web/WEB-INF/views/booking.jsp` | 11.5 |
| `web/WEB-INF/views/calibration.jsp` | 6.4 |
| `web/WEB-INF/views/common/nav.jspf` | 5.12 |
| `web/WEB-INF/views/dashboard.jsp` | 13 |
| `web/WEB-INF/views/denied.jsp` | 5.12 |
| `web/WEB-INF/views/deposit.jsp` | 6.2 |
| `web/WEB-INF/views/lockerArea.jsp` | 6.2 |
| `web/WEB-INF/views/lockerBank.jsp` | 6.2 |
| `web/WEB-INF/views/lockerMap.jsp` | 7.4 |
| `web/WEB-INF/views/lockerSlot.jsp` | 6.1 |
| `web/WEB-INF/views/login.jsp` | 5.12 |
| `web/WEB-INF/views/maintenance.jsp` | 10.7 |
| `web/WEB-INF/views/myCard.jsp` | 11.4 |
| `web/WEB-INF/views/register.jsp` | 5.12 |
| `web/WEB-INF/views/remoteCommand.jsp` | 11.3 |
| `web/WEB-INF/views/role.jsp` | 6.6 |
| `web/WEB-INF/views/storagePlan.jsp` | 6.2 |
| `web/WEB-INF/views/user.jsp` | 6.5 |
| `web/WEB-INF/views/userCard.jsp` | 6.3 |
| `web/WEB-INF/web.xml` | 5.12 |
| `web/index.html` | 5.13 |
