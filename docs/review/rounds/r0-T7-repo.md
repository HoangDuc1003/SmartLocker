# Vòng 0 - T7 (repo): thư viện trong `web/WEB-INF/lib` và cấu hình kết nối DB

Ngày 14/11/2026. Ứng với nhận xét của giáo viên, Bảng 2 dòng 4 (thư viện) và dòng 6 (`sa` / `12345` trong `DbContext`).
Không commit gì; các lệnh `git mv` để sẵn thay đổi ở trạng thái staged (rename).

## 1. Đã chuyển

| Jar | Trước | Sau |
|---|---|---|
| `gson-2.10.1.jar` | `lib/` | `web/WEB-INF/lib/` |
| `jbcrypt-0.4.jar` | `lib/` | `web/WEB-INF/lib/` |
| `mssql-jdbc-12.8.1.jre8.jar` | `lib/` | `web/WEB-INF/lib/` |
| `weka.jar` | `lib/` | `web/WEB-INF/lib/` |
| `jstl-1.2.jar` | `web/WEB-INF/lib/` | giữ nguyên |
| `testng-7.5.jar`, `jcommander-1.78.jar`, `slf4j-api-1.7.36.jar` | `lib/` | giữ nguyên trong `lib/` (chỉ để test; TestNG cần SLF4J) |

Dùng `git mv` nên git ghi nhận là đổi tên (R), lịch sử jar giữ nguyên.

## 2. File đã sửa

| File | Thay đổi |
|---|---|
| `nbproject/project.properties` | `file.reference.*` của 4 jar chạy trỏ sang `web/WEB-INF/lib/...`, 3 jar test trỏ `lib/...` (dấu `/` thay `\\`, chạy được cả Linux). `javac.classpath` và `javac.test.classpath` giữ nguyên tên biến. Thêm chú thích giải thích bố cục. |
| `nbproject/project.xml` | `<web-module-libraries>` thành rỗng. Jar trong `web/WEB-INF/lib` đã vào WAR cùng thư mục web (target `-copy-webdir`), nếu vẫn khai báo `path-in-war` thì NetBeans chép jar thêm một lần vào cùng chỗ. Jar vẫn nằm trong `javac.classpath` nên NetBeans vẫn biên dịch và gợi ý code được. |
| `nbproject/build-impl.xml` | Bỏ 8 lệnh `<copyfiles>` của 4 jar trong `library-inclusion-in-manifest` và `library-inclusion-in-archive`. Nội dung đã đối chiếu với file sinh ra từ `build-impl.xsl` của NetBeans 13 (module web-project 1.89.0.1, đúng phiên bản ghi trong `genfiles.properties`): chạy XSL trên `project.xml` cũ và mới, khác nhau đúng 8 dòng này. |
| `nbproject/genfiles.properties` | Cập nhật CRC: `data.CRC32=8e13291e` (project.xml mới), `build-impl.xml.script.CRC32=8c11cbb1`. Thuật toán CRC của NetBeans đã kiểm lại trên file cũ (ra đúng `e5614892`, `5dd2ab4e`, `334708a0`, `42f0802d`). Nhờ vậy NetBeans coi `build-impl.xml` là bản sinh tự động còn mới, không hỏi tạo lại hay báo "modified externally". `build.xml` không đổi (XSL `build.xsl` sinh ra giống hệt). |
| `scripts/test.sh` | `CP` thêm `web/WEB-INF/lib/*` trước `lib/*`. |
| `scripts/build-dev.sh` | Biên dịch với `web/WEB-INF/lib/*`; bỏ bước `cp lib/*.jar build/web/WEB-INF/lib/` vì `cp -ru web/. build/web/` đã mang jar theo. |
| `Dockerfile` | Bỏ `COPY lib lib` và bước chép jar; `javac -cp "$CATALINA_HOME/lib/*:web/WEB-INF/lib/*"`; jar vào image cùng `web/`. |
| `README.md`, `README.en.md` | Mục "Build và chạy": NetBeans 13, jar nằm ở đâu, máy mới cần gì. Mục mới "3. Kết nối cơ sở dữ liệu" / "3. Database connection" (biến môi trường, `setenv.bat`, `setx`, `setenv.sh`, Docker, cảnh báo không dùng `sa`, T-SQL tạo login riêng). "Tài khoản demo" thành mục 4. Cây thư mục: `lib/` chỉ jar test, thêm `web/WEB-INF/lib/`. Dòng `DbContext` ở mục Bảo mật trỏ tới mục mới. Không đổi số liệu test hay ảnh. |
| `docs/review/rounds/r0-T7-repo.md` | Báo cáo này. |

`scripts/proof/*` không có đường dẫn jar (dựng app qua `build-dev.sh --no-reload`), `run_demo_db.bat/.ps1` không nhắc jar, `build.xml` không cần sửa.

## 3. Dòng 6: `DbContext`

`src/java/dao/DbContext.java` (T6 giữ file này, T7 không sửa) đọc **chỉ biến môi trường** qua `System.getenv`, không đọc system property:
`DB_URL` (mặc định `jdbc:sqlserver://localhost:1433;databaseName=PRJ301_LOCKER;encrypt=false`), `DB_USER` (mặc định `sa`), `DB_PASSWORD` (mặc định `12345`). Biến trống coi như chưa đặt. Giá trị đọc một lần khi lớp được nạp.
README giờ nói rõ mặc định chỉ cho demo local, cách đặt biến trên Windows/Linux/Docker, và cấp quyền tối thiểu:

```sql
CREATE LOGIN smartlocker_app WITH PASSWORD = N'...', CHECK_POLICY = ON;
USE PRJ301_LOCKER;
CREATE USER smartlocker_app FOR LOGIN smartlocker_app;
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dbo TO smartlocker_app;
```

Đã kiểm trong `src/java`: không có câu lệnh DDL lúc chạy, nên quyền trên là đủ về lý thuyết. **Chưa chạy thử app bằng login này** (tạo login là thay đổi bảo mật của SQL Server trên máy chủ nhân, không làm khi chưa được phép). Nếu T6 đổi tên biến hay thêm `-D` trong `DbContext`, phải sửa lại mục này trong hai README.

## 4. Kiểm tra

1. **Biên dịch bằng JDK 8** (`C:/Program Files/Java/jdk1.8.0_202/bin/javac -source 8 -target 8`), classpath chỉ gồm `servlet-api`, `jsp-api` của Tomcat và `web/WEB-INF/lib/*` (không có `lib/`), ra thư mục scratch `.../scratchpad/t7-build/classes`: 89 file nguồn, **exit 0**. Như vậy các jar đã chuyển đủ cho mã chạy. Test (`test/support`, `test/test`) biên dịch thêm `lib/*`: exit 0. Lúc chạy, các agent khác đang sửa `src/java` (DeviceAuthApi, Web, MailTemplates...) mà vẫn biên dịch được.
2. **Ant của NetBeans 13, mô phỏng máy mới** (`C:/Program Files/NetBeans-13/netbeans/extide/ant`, JAVA_HOME = JDK 1.8.0_202) trên bản chép của repo trong scratch (`build.xml`, `nbproject` không có `private/`, `src`, `web`, `lib`, `test`):
   - Chỉ có `-Dj2ee.server.home=E:/apache-tomcat-9.0.113`: dừng ở `-init-taskdefs` vì thiếu `libs.CopyLibs.classpath`.
   - Thêm `-Dlibs.CopyLibs.classpath=C:/Program Files/NetBeans-13/netbeans/java/ant/extra/org-netbeans-modules-java-j2seproject-copylibstask.jar`: `ant dist` **BUILD SUCCESSFUL**, `ant compile-test` **BUILD SUCCESSFUL** (20 file test).
   - `dist/SmartLocker.war` (19,6 MB) chứa `WEB-INF/lib/` đúng 5 jar, mỗi jar một lần: `gson-2.10.1.jar`, `jbcrypt-0.4.jar`, `jstl-1.2.jar`, `mssql-jdbc-12.8.1.jre8.jar`, `weka.jar`. Không có testng, jcommander, slf4j. 107 file `.class` và tài nguyên `ml/` trong `WEB-INF/classes`.
   - `libs.javaee-endorsed-api-7.0.classpath` không đặt cũng không làm build lỗi.
3. **`scripts/build-dev.sh --no-reload`** chạy trên bản chép trong scratch (không đụng Tomcat của chủ): `build/web/WEB-INF/lib` có đúng 5 jar trên, 107 class.
4. **TestNG không cần DB**: chạy `scripts/test.sh` đã sửa trên bản chép trong scratch, `DB_URL` trỏ tên giả `SL_T7_NODB` (không kết nối), lớp `test.RuleEngineTest,test.PricingTest,test.RiskScorerTest,test.SecurityUtilsTest`: **35/35 đạt, 0 lỗi, 0 bỏ qua**. Chạy tay javac/java với cùng classpath cũng 35/35.
5. **Dockerfile**: chưa build image (cần tải image tomcat); chỉ sửa theo cùng logic với `build-dev.sh`. `.dockerignore` không loại `web/WEB-INF/lib`.

Không biên dịch vào `build/` của repo, không dừng hay tải lại Tomcat cổng 8080.

## 5. Máy mới cần gì (NetBeans 13 + JDK 8 + Tomcat 9)

- JDK 8 (đã thử 1.8.0_202). NetBeans 13 trên máy này chạy bằng JDK 8 (`netbeans_jdkhome` trong `etc/netbeans.conf`); nếu NetBeans chạy bằng JDK mới hơn thì thêm JDK 8 ở Tools > Java Platforms.
- Tomcat 9 khai báo trong Tools > Servers. `nbproject/private/` không commit, nên lần đầu mở project NetBeans báo thiếu server: chuột phải project > Resolve Project Problems (hoặc Properties > Run) và chọn Tomcat 9. NetBeans tự ghi `j2ee.server.home`, `j2ee.server.instance` vào `nbproject/private/private.properties`.
- `libs.CopyLibs.classpath` do NetBeans tự cấp qua `build.properties` của người dùng; chỉ cần đặt tay khi chạy ant ngoài IDE (lệnh ở mục 4).
- Không cần thêm jar nào: jar chạy ở `web/WEB-INF/lib`, jar test ở `lib/`, đều trong git.
- SQL Server + `run_demo_db.ps1`; ngoài máy demo thì đặt `DB_URL`, `DB_USER`, `DB_PASSWORD` (README mục 3).
- Chưa mở thử bằng giao diện NetBeans (chỉ chạy ant headless với cùng `build-impl.xml`); CRC trong `genfiles.properties` khớp nên IDE không đòi sinh lại file.

## 6. Chỗ còn trỏ `lib/` ngoài phạm vi T7 (chưa sửa)

| File | Dòng | Ghi chú |
|---|---|---|
| `docs/paper/evidence/harness/scenario.sh` | 9-10 | `-cp "$H/classes;build/classes;lib/*"` để chạy `tool.ScenarioSender`; giờ thiếu Gson/JDBC. Cần thêm `web/WEB-INF/lib/*` (thuộc phần bài báo). |
| `docs/paper/evidence/harness/ExtendedEvidence.java` | 7, 10 | Chú thích lệnh `-cp "lib/weka.jar"`, nay là `web/WEB-INF/lib/weka.jar` (file chưa track). |
| `docs/paper/evidence/*.log` (`ml.log`, `retrain.log`, `scenarios.log`, `testng.log`, `extended.log`) | nhiều | Nhật ký lệnh đã chạy trước đây, ghi `lib/*`. Là bằng chứng lịch sử, nên để nguyên; nếu chạy lại thì dùng `web/WEB-INF/lib/*;lib/*`. |
| `CLAUDE.md` | 66 | "`testng`/`jcommander`/`slf4j` are test-only and stay out of `WEB-INF/lib`" vẫn đúng; có thể thêm một dòng bài học: jar chạy nằm ở `web/WEB-INF/lib`, không khai báo lại trong `project.xml`. |
| `docs/handoff/v3.md`, `docs/spec/smart-locker-v3.md` | | Nhắc `lib/` trong lịch sử, không cần sửa. |

## Vòng 2 - sửa theo rà chéo vòng 1 (`r1-T7-repo.md`, CHƯA ĐẠT)

Phạm vi sửa: `README.md`, `README.en.md`, và `docs/deploy-render.md` (orchestrator giao thêm cho T7 ở vòng này). Không đụng `nbproject`, script hay jar.

| STT r1 | Đã sửa |
|---|---|
| 1 (trung bình) | README mục 3 tách hai khối T-SQL: "SQL Server cài trên máy" (giữ `CREATE LOGIN` + `USE` + `CREATE USER ... FOR LOGIN`) và "Azure SQL Database" dùng contained user (`CREATE USER smartlocker_app WITH PASSWORD = N'...'` + cùng `GRANT`), chạy khi đã kết nối thẳng vào `PRJ301_LOCKER` bằng server admin (Query editor hoặc `sqlcmd -d PRJ301_LOCKER -N -I`). Ghi rõ `DB_URL` phải có `databaseName=...` và chạy lại `run_demo_db.ps1 -Azure` không xóa user (script chỉ DROP view, procedure, function, khóa ngoại, bảng, type; đã đọc `$dropAll`), quyền trên schema `dbo` vẫn còn. `docs/deploy-render.md`: thêm đoạn "Tạo tài khoản riêng cho web" cuối Bước 2; Bước 3 đặt `DB_USER = smartlocker_app`, `DB_PASSWORD` = mật khẩu của user đó; `lockeradmin` chỉ dùng chạy script dựng DB. Câu cảnh báo nói rõ cả "server admin của Azure". |
| 2 | Mục Build và chạy: project dùng `default_platform`; nếu NetBeans không chạy bằng JDK 8 thì thêm JDK 8 ở Tools > Java Platforms rồi chọn ở Properties > Libraries > Java Platform (NetBeans ghi `platform.active` vào `project.properties`) và Tools > Servers > Tomcat 9 > tab Platform. |
| 3 | Thêm đoạn: `encrypt=true` kiểm chứng chỉ; Azure có chứng chỉ hợp lệ; SQL Server tự cài với chứng chỉ tự ký báo `PKIX path building failed`, cần chứng chỉ CA tin cậy, hoặc chỉ trong mạng tin cậy thêm `;trustServerCertificate=true`. |
| 4 | Mật khẩu mẫu đổi thành `Doi-Mat-Khau#2026` (bản en: `Change-Me#2026`), đủ chữ hoa, thường, số, ký hiệu, dài hơn 8 ký tự, nên qua chính sách độ phức tạp của `CHECK_POLICY`; ghi rõ không dùng nguyên mẫu. Ghi chú `%` trong `setenv.bat` phải viết `%%`. |
| 5 | Thêm trường hợp Tomcat là Windows service: không đọc `setenv.bat`; Java Options của `Tomcat9w.exe` chỉ thêm `-D` mà `DbContext` không đọc; dùng `setx /M` trong PowerShell quản trị. Ghi chú: dịch vụ chỉ thấy biến hệ thống mới sau khi Windows khởi động lại (services.exe giữ môi trường từ lúc khởi động), chỉ restart service thường chưa đủ. |
| 6 (tùy chọn) | Đã kiểm: bảng là `dbo.AuditLog` và `dbo.HashChain` (`sql/01_schema.sql` dòng 120, 130). `src/java` không có `UPDATE`/`DELETE`/`INSERT` trực tiếp vào hai bảng; ghi qua `{call Audit_Append(...)}` (`AuditDao`, `TopupDao`), procedure này `INSERT` rồi `UPDATE AuditLog SET row_hash` (dbo sở hữu cả procedure và bảng, nên ownership chaining bỏ qua `DENY`). `DELETE FROM dbo.HashChain/AuditLog` chỉ có trong script seed `02_data_v1.sql` (chạy bằng quản trị). Đã thêm vào README như đoạn "Tăng cường (tùy chọn, chưa chạy thử với ứng dụng)" với `DENY UPDATE, DELETE` trên hai bảng và lưu ý phải chạy lại sau mỗi lần dựng lại DB (quyền gắn với bảng bị DROP). |
| 7 | Dành cho chủ repo (orchestrator báo): mở bằng giao diện NetBeans 13 trên bản clone sạch, và chạy thử app bằng `smartlocker_app` trên một DB `SL_*`. T7 không tạo login trên SQL Server của chủ. |

Kiểm tra vòng 2: neo `#3-kết-nối-cơ-sở-dữ-liệu` / `#3-database-connection` không đổi (tiêu đề giữ nguyên); `lockeradmin` trong `deploy-render.md` chỉ còn ở Bước 1, lệnh `run_demo_db.ps1` và lệnh tạo user. Không có thay đổi mã nên không chạy lại build/test. Các khối T-SQL chưa chạy trên SQL Server thật (cú pháp theo tài liệu SQL Server/Azure SQL).
