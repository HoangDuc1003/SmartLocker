# Công cụ kiểm chứng refactor

Chứng minh DB dựng từ script mới giống hệt DB dựng từ `rf-baseline`, và có sẵn một stack test không đụng gì của chủ dự án.
Mọi lệnh chạy bằng PowerShell 5.1 từ gốc repo, trừ `scripts/test.sh` chạy bằng Git Bash.

## Chuẩn bị (một lần)

```
git worktree add --detach C:\sl-wt\baseline rf-baseline
```

## Các lệnh

| Việc | Lệnh |
|---|---|
| So DB cũ và mới | `scripts\proof\proof.ps1` (thêm `-TestSetup` để gồm cả `test_setup.sql`, `-Keep` để giữ hai DB) |
| Tự kiểm tra công cụ (hai build khớp, 3 lỗi cấy, `accepted.txt`) | `scripts\proof\selftest.ps1` |
| Dựng một DB | `scripts\proof\build-db.ps1 -Repo . -Database SL_X [-TestSetup]` |
| Bật hoặc tắt Tomcat test | `scripts\proof\test-stack.ps1 start -Database SL_X [-Build]`, `... stop`, `... clean` |
| Chạy Postman | `scripts\proof\newman.ps1 -Database SL_X` (Tomcat test phải đang chạy trên đúng DB đó) |
| TestNG | `DB_URL='jdbc:sqlserver://localhost:1433;databaseName=SL_X;encrypt=false' sh scripts/test.sh`. DB phải dựng với `-TestSetup`, nếu không sẽ có test bị bỏ qua |

## Rào chắn

- Mọi công cụ từ chối tên DB không có tiền tố `SL_`. Sau mỗi lần chạy, công cụ kiểm tra `create_date` của `PRJ301_LOCKER` vẫn là 2026-10-28 07:20:35 và báo động nếu khác.
- Tomcat test dùng `CATALINA_BASE` riêng (`C:\sl-wt\tomcat-8081`), cổng 8081, shutdown 8015. Nó chỉ dùng chung file chương trình của `E:\apache-tomcat-9.0.113`, không đọc `conf` của Tomcat 8080 khi chạy và không đụng `SmartLocker.xml` ở đó.
- Không có mail thật: công cụ dừng nếu thấy `config/mail.local.properties` hoặc `conf/smartlocker-mail.properties`, và dừng nếu log không có dòng `Due reminder e-mails off`.
- Script gốc không bị sửa: `build-db.ps1` chép ra thư mục tạm, thay tên DB, giữ BOM và dừng nếu còn câu `USE`, `CREATE`, `ALTER`, `DROP DATABASE` trỏ sang DB khác.

## Công cụ so những gì

`export-db.ps1` ghi ra các file text chuẩn rồi `compare.ps1` so bằng `git diff --no-index`:

| File | Nội dung |
|---|---|
| `01_columns.txt` | Cột của bảng, view và hàm trả về bảng, gồm thứ tự, kiểu, null, collation, computed |
| `02_identity.txt` | Seed, increment, giá trị cuối của identity |
| `03_constraints.txt` | Check, default, FK |
| `04_indexes.txt` | Index kèm cột, include, filter |
| `05_parameters.txt` | Tham số của procedure và function |
| `06_objects.txt` | Danh sách object, trigger, kiểu tự định nghĩa, sequence |
| `07_modules.txt` | Text của procedure, view, function, trigger đã bỏ comment và khoảng trắng, kèm `ANSI_NULLS` và `QUOTED_IDENTIFIER` |
| `data/<bảng>.txt` | Mọi dòng, sắp theo khóa chính |

Khác biệt tự nhiên được che như sau:

- Tên do SQL Server tự sinh (`PK__Users__3B75D760`) in là `<auto>`.
- Thời gian, kể cả chuỗi ISO trong cột text, in là số phút lệch so với lúc tạo DB.
- Cột trong `natural.txt` in là `<natural:độ dài>`, riêng `NULL` vẫn là `NULL`. `selftest.ps1` báo lỗi nếu danh sách này khác đúng những gì thật sự khác giữa hai lần build.

`accepted.txt` chỉ dùng cho metadata (`03`, `05`, `06`, `07`), mỗi dòng dạng `<file>|<+ hoặc ->|<dòng trong diff>`. Công cụ từ chối dòng nói về dữ liệu, identity, cột, index hay `THROW`, và báo lỗi nếu có dòng không còn cần nữa.

Kết quả diff nằm ở `%TEMP%\sl-proof\diff.txt`.

## Newman

`newman-baseline.txt` là tập assertion đang fail, mỗi dòng một assertion. Hiện file này rỗng: 221 request (211 mục cộng các vòng lặp của kịch bản), 472 assertion, không lỗi. `newman.ps1` chạy lại `test_setup.sql` trước mỗi lần và báo `NEW FAILURE` hoặc `NOW PASSES` khi khác baseline. Khóa `device-1-api-key` là khóa seed công khai của `03_v2_v3.sql`.

Collection chưa có bước nào cho `CONFIRM_EMAIL` và `WRONG_PLACE`, nên Newman xanh chưa nói gì về hai nhánh đó.
