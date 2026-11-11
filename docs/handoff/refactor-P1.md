# Handoff: refactor B0 và P1

## Mục tiêu
B0: sửa lỗi H1 (OOM do log audit). P1: dựng công cụ chứng minh DB mới giống DB cũ, stack test cổng 8081, chạy Newman lần đầu từ khi có tính năng thẻ và email. Cách dùng công cụ nằm ở `scripts/proof/README.md`.

## Đã làm

**B0 (tag `rf-b0`):**
- `LOGIN_FAIL` chỉ ghi tên của tài khoản có thật, theo đúng cách viết trong DB, tối đa 100 ký tự. Tên lạ không được ghi.
- `AuditVerifier` đọc theo luồng, `findFirstBroken(List)` và `loadRows` vẫn giữ cho test.
- Kiểm tra chuỗi chạy trên luồng riêng `LockerMonitor-audit` mỗi 60 giây. Snapshot chỉ đọc kết quả đã lưu; lần kiểm tra lỗi giữ kết quả trước (chỉ báo ba trạng thái là M6).
- Bằng chứng: 6 test mới đỏ đúng lý do trước khi sửa. Với heap 64 MB và 100 dòng log 2 MB, bản cũ OOM sau 1,9 giây, bản mới xong trong 7 giây.

**P1 (tag `rf-p1`):**
- `scripts/proof/`: `build-db`, `export-db`, `compare`, `proof`, `selftest`, `test-stack`, `newman`, `natural.txt`, `accepted.txt`, `newman-baseline.txt`, `README.md`.
- `scripts/test.sh` bắt buộc `DB_URL` trỏ `SL_*` và in lý do test fail (`test/support/FailurePrinter.java`).
- `run_demo_db.ps1 -Database SL_X` giờ dựng đúng DB đó. Trước đây nó vẫn xóa và dựng lại `PRJ301_LOCKER` dù truyền tên khác.
- `LockerMonitor` ghi log `Due reminder e-mails off` khi không có cấu hình mail.

**Lỗi code thật tìm thấy trong P1:** `sql/03_v2_v3.sql` mở đầu bằng hai BOM nên `sqlcmd` dừng ở batch đầu và `run_demo_db.ps1` không chạy được từ `rf-baseline`. Đã sửa ở commit riêng `d1ac356`. `build-db.ps1` bỏ BOM thừa để vẫn dựng được bên cũ.

**Tập lỗi Newman baseline: rỗng.** 221 request, 472 assertion, 0 lỗi, chạy lại vẫn vậy. Lưu ý là collection chưa có bước nào cho `CONFIRM_EMAIL` và `WRONG_PLACE`.

**Kết quả kiểm tra cuối:**

| Kiểm tra | Kết quả |
|---|---|
| Hai build baseline, cách nhau 70 giây | Khớp; khác biệt thô đúng bằng 4 cột trong `natural.txt` |
| Lỗi cấy: literal, check, ô seed, cùng index tắt, trigger database, user, option, hash chain, sửa dòng log | Bắt được cả 9, đúng file |
| `selftest.ps1` | Đạt toàn bộ 22 mục |
| `proof.ps1`: HEAD so với `rf-baseline` | Rỗng 5/5 lần; có `test_setup` và `test_cleanup` rỗng 5/5 lần |
| `run_demo_db.ps1` trên DB `SL_*` | Dựng được, giống hệt bản `build-db` |
| TestNG trên DB dựng từ script | 66/66, `Skips: 0`; `AuditChainDatabaseIntegrationTest` 4/4 |
| `PRJ301_LOCKER` | `create_date` vẫn 2026-10-28 07:20:35, `IDENT_CURRENT` của AuditLog vẫn 11239 |

**Cross-review:** một agent khác đọc diff. B0 không có lỗi. P1 có 11 phát hiện, tool từng báo "không khác" với 5 thứ thật sự khác. Đã sửa:
- Xuất thêm trạng thái index, trigger cấp database, user và quyền, tùy chọn DB, extended property, sequence, kiểu tự định nghĩa, table type.
- Thêm `10_audit_chain.txt` tính lại chuỗi hash, vì các cột hash đang bị che.
- `git diff --text`, thoát ký tự điều khiển, không bỏ sót dòng bắt đầu bằng `-- `.
- `accepted.txt` phân biệt hoa thường, mỗi dòng che một lần xuất hiện, từ chối `RAISERROR`, mỗi dòng module mang tên module.
- Newman không dùng lại báo cáo cũ; float in đủ độ chính xác; literal nhiều dòng không bị đổi; `test.sh` kiểm tra đúng tham số `databaseName`.

## Việc còn mở
- **`demo_box.sql` lỗi 50906 trên DB vừa dựng, ngay cả ở `rf-baseline`.** Bước P7 "chạy `run_demo_db.ps1`, `demo_box.sql`" sẽ vướng. Chưa sửa vì ngoài phạm vi; nên xem cùng M17 ở B-SQL.
- **`test_overdue.sql` không chứng minh được bằng so dữ liệu.** Nó đặt `due_at` đúng tròn giờ nên số giờ phạt lệch 1 tùy vài mili giây. Cùng một script cũng cho kết quả khác nhau (6/8 lần). Nếu P2 đụng file này thì so text.
- **Giới hạn đã chấp nhận của tool:** thời gian làm tròn đến phút, nên chênh dưới một phút không hiện ra; `create_date` chỉ phát hiện DB thật bị tạo lại, không thấy lệnh ghi (dùng `IDENT_CURRENT` khi cần).
- Rule của plan "Newman 211 request": số thật là 221 vì có vòng lặp trong kịch bản.
- L5 của `docs/handoff/fix-bugs-2.md` vẫn để B-Java kiểm tra cùng M8.

## File đã sửa
`scripts/proof/*` (mới), `scripts/test.sh`, `test/support/FailurePrinter.java` (mới), `test/test/AuditFloodDatabaseIntegrationTest.java` (mới), `src/java/controller/LoginController.java`, `src/java/dao/UserDao.java`, `src/java/service/AuditVerifier.java`, `src/java/service/LockerMonitor.java`, `sql/03_v2_v3.sql` (chỉ bỏ BOM thừa), `run_demo_db.ps1`, `CLAUDE.md`.

## Trạng thái máy
- **Còn giữ:** worktree `C:\sl-wt\baseline` (detached ở `rf-baseline`, P2 cần).
- **Đã dọn:** DB `SL_B0`, `SL_NEWMAN`, `SL_TEST`, `SL_PROOF_*`; Tomcat test và thư mục `C:\sl-wt\tomcat-8081`.
- Tomcat 8080 không bị đụng tới. Thư mục OneDrive không bị đụng tới và không cần đọc file khóa, vì DB test dùng khóa seed công khai `device-1-api-key`.
- Chưa push, chưa merge.

## Cách kiểm tra lại
PowerShell, từ gốc repo:
```
scripts\proof\selftest.ps1
scripts\proof\proof.ps1
scripts\proof\build-db.ps1 -Repo . -Database SL_NEWMAN
scripts\proof\test-stack.ps1 start -Database SL_NEWMAN -Build
scripts\proof\newman.ps1 -Database SL_NEWMAN
scripts\proof\test-stack.ps1 clean
```
Git Bash, sau khi dựng `SL_TEST` bằng `build-db.ps1 -TestSetup`:
```
DB_URL='jdbc:sqlserver://localhost:1433;databaseName=SL_TEST;encrypt=false' sh scripts/test.sh
```
Xong thì xóa các DB `SL_*` vừa tạo.
