# Vòng 2 - Rà chéo T7 (repo): README kết nối DB và `docs/deploy-render.md`

Ngày 14/11/2026. Người rà: reviewer r1/r2 (chỉ đọc). Phạm vi: `git diff` của `README.md`, `README.en.md`, `docs/deploy-render.md`
(phần sửa theo `r1-T7-repo.md` mục 1-6; ghi chú của T7 ở "Vòng 2" trong `r0-T7-repo.md`).

## Đã kiểm

| Mục r1 | Kết quả |
|---|---|
| 1. Azure contained user | `CREATE USER smartlocker_app WITH PASSWORD = N'...'` chạy trong chính database `PRJ301_LOCKER` là đúng cú pháp Azure SQL Database (DB trên Azure luôn cho contained user, không cần `ALTER DATABASE ... CONTAINMENT`). README và deploy-render ghi đúng chỗ phải chạy: kết nối thẳng vào `PRJ301_LOCKER` (không phải `master`) bằng server admin, qua Query editor hoặc `sqlcmd -d PRJ301_LOCKER -N -I`. Câu "`DB_URL` phải có `databaseName=...`" đúng (contained user không vào được `master`). Câu "chạy lại `run_demo_db.ps1 -Azure` không xóa user": đúng, `$dropAll` chỉ xóa view, procedure, function, khóa ngoại, bảng, type; quyền cấp trên `SCHEMA::dbo` còn vì schema không bị xóa. |
| 1. deploy-render Bước 3 | `DB_USER = smartlocker_app`, `DB_PASSWORD` = mật khẩu của user đó; `lockeradmin` chỉ còn ở Bước 1, lệnh `run_demo_db.ps1` và lệnh tạo user. `DB_URL` đã có `databaseName=PRJ301_LOCKER` (tên DB đặt ở Bước 1). Đạt. |
| 2. NetBeans platform | Properties > Libraries > Java Platform (ghi `platform.active`) và Tools > Servers > Tomcat 9 > tab Platform > Java Platform: đúng tên mục trong NetBeans 13. |
| 3. encrypt / trustServerCertificate | Mô tả đúng: mssql-jdbc 12 kiểm chứng chỉ khi `encrypt=true`, Azure có chứng chỉ hợp lệ, chứng chỉ tự ký báo `PKIX path building failed`; `trustServerCertificate=true` chỉ trong mạng tin cậy. |
| 4. Mật khẩu / `%%` | `Doi-Mat-Khau#2026` / `Change-Me#2026`: đủ 4 loại ký tự, dài hơn 8, không chứa tên tài khoản, nên qua chính sách độ phức tạp của Windows và của Azure. `#` an toàn trong `set "..."`, `setx`, chuỗi nháy đơn của sh và `docker -e`. Ghi chú `%` thành `%%` trong `.bat` đúng. |
| 5. Windows service | Đúng: dịch vụ nhận môi trường từ Service Control Manager (`services.exe`), tiến trình này chỉ đọc biến hệ thống lúc Windows khởi động và không cập nhật khi `setx /M` phát `WM_SETTINGCHANGE`; vì vậy sau `setx /M` phải khởi động lại Windows, chỉ restart service thì chưa thấy biến mới. Ô Java Options của `Tomcat9w.exe` chỉ thêm `-D` là đúng, và `DbContext` chỉ đọc `System.getenv`. |
| 6. DENY trên `dbo.AuditLog` / `dbo.HashChain` | `Audit_Append` (`sql/01_schema.sql:333`) là SQL tĩnh, do `dbo` sở hữu, ghi vào bảng của `dbo` (`INSERT AuditLog`, `UPDATE AuditLog SET row_hash`, `SELECT ... WITH (UPDLOCK, HOLDLOCK)` trên `HashChain`, `INSERT HashChain`). Ownership chaining bỏ qua kiểm quyền, kể cả `DENY`; procedure khác gọi `Audit_Append` cũng nằm trong cùng chuỗi. Không có trigger nào trên hai bảng (trigger duy nhất là `trg_LockerSession_AppendOnly`), không có `ON DELETE/UPDATE CASCADE`, không có dynamic SQL trong procedure lúc chạy. Java không UPDATE/DELETE/INSERT trực tiếp hai bảng (`AuditVerifier` chỉ đọc). DENY chỉ chặn UPDATE/DELETE, không chặn INSERT. Vậy không thể làm hỏng `Audit_Append`. Câu "chạy lại sau mỗi lần dựng lại database" đúng. |
| Ngôn ngữ | Phần tiếng Việt mới tự nhiên, đúng thuật ngữ. Bản tiếng Anh khớp nghĩa với bản Việt. |

## Lỗi

| STT | Vị trí (file:line) | Lỗi | Mức độ | Đề nghị sửa |
|---|---|---|---|---|
| 1 | `README.md` / `README.en.md` khối "SQL Server cài trên máy" (khoảng dòng 254-262) | `run_demo_db.ps1` trên máy **xóa và tạo lại** database (`sql/01_schema.sql:18-21`, `DROP DATABASE PRJ301_LOCKER`). Login `smartlocker_app` ở mức server còn, nhưng database user và lệnh `GRANT` mất theo database. Sau mỗi lần dựng lại, app báo `Cannot open database "PRJ301_LOCKER" requested by the login`. README chỉ nhắc chạy lại cho `DENY`, chưa nhắc cho `CREATE USER` + `GRANT`. Khác với Azure, nơi user được giữ. | thấp | Thêm một câu sau khối local: mỗi lần chạy lại `run_demo_db.ps1` trên máy, chạy lại phần từ `USE PRJ301_LOCKER;` (`CREATE USER ... FOR LOGIN` + `GRANT`); login vẫn còn nên không chạy lại `CREATE LOGIN`. |
| 2 | `README.md` / `README.en.md` đoạn "Tomcat cài dạng dịch vụ" | Nội dung đúng, nhưng còn cách gọn hơn: biến hệ thống bằng `setx /M` thì mọi tài khoản và tiến trình trên máy đều đọc được mật khẩu, lại phải khởi động lại Windows. Procrun của Tomcat cho đặt biến riêng cho dịch vụ, không cần khởi động lại Windows: `tomcat9.exe //US//Tomcat9 ++Environment "DB_USER=smartlocker_app"` (giá trị chứa `;` hoặc `#`, như `DB_URL` hay mật khẩu mẫu, phải đặt trong nháy đơn). | thấp | Tùy chọn: thêm cách `++Environment` (đặt xong chỉ cần restart service) và một lưu ý ngắn rằng biến hệ thống thì mọi tài khoản trên máy đọc được. |
| 3 | `README.md` / `README.en.md` khối Azure (2 dòng `CREATE USER` / `GRANT`); `docs/deploy-render.md:56-60` | README không có `GO`, deploy-render có `GO`. Trong `sqlcmd` tương tác, lệnh chỉ chạy khi gõ `GO`. Hai tài liệu đưa cùng một khối nhưng viết khác nhau. | thấp | Thống nhất: thêm `GO` vào khối Azure của README (giống deploy-render), hoặc ghi "trong `sqlcmd`, gõ `GO` để chạy". |
| 4 | `README.en.md:173` | "so NetBeans should best run on JDK 8" là câu tiếng Anh không tự nhiên. | thấp | "so it is best to run NetBeans on JDK 8". |

Còn để ngỏ từ r1 (mục 7, việc của chủ repo, không tính cho T7): mở bằng giao diện NetBeans 13 trên một bản clone sạch, và chạy thử app với `smartlocker_app` trên một DB `SL_*`. Các khối T-SQL mới chỉ được kiểm qua đọc mã và tài liệu, chưa chạy trên SQL Server hay Azure thật.

KẾT LUẬN: ĐẠT
