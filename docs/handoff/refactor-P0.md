# Handoff: refactor P0 (mốc an toàn)

## Mục tiêu
Tạo mốc để quay lại trước đợt refactor lớn. Plan đã duyệt: `docs/plan/refactor-big.md`, đọc phần "Cập nhật từ P0" trước.

## Đã làm
- Commit toàn bộ phần chưa commit (`ecd3dd6`): thẻ + email, sóng và cảnh báo sai chỗ, Mapbox, fix-bugs-2. `docs/paper` vẫn untracked, `docs/paper/evidence/newman*.json` đã vào `.gitignore`.
- Commit plan, sửa `CLAUDE.md`, thêm `.gitattributes` (`7c25e8c`), tag `rf-baseline`.
- Backup: `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\PRJ301_LOCKER_pre_refactor.bak` (COPY_ONLY, CHECKSUM, `RESTORE VERIFYONLY` đạt, đã khôi phục thử thành công).
- TestNG 60/60, `Skips: 0`, trên bản khôi phục `SL_P0` (đã xóa sau đó). Chứng minh đúng DB bằng `IDENT_CURRENT`.

## Trạng thái máy
- Thư mục OneDrive: nhánh `refactor/baseline`, đúng bằng `rf-baseline`. Không làm việc ở đó.
- Worktree làm việc: `C:\sl-wt\refactor`, nhánh `refactor/big`.
- `main` không đổi (`da95f43`). Chưa push gì.
- Tomcat 8080 là của chủ dự án (NetBeans). Nó tắt lúc 16:04:37 ngày 2026-11-04 do nhận lệnh shutdown ngay sau các request của NetBeans; không phải do P0. Đừng bật lại.

## Việc còn mở
- `docs/handoff/fix-bugs-2.md` ghi L5 chưa test live: để B-Java kiểm tra cùng M8.
- Tên phần `email_code` trong `CLAUDE.md` đã đính chính; dòng về "code" ở trên vẫn sai cho tới khi làm E1.
- Newman chưa chạy từ khi có tính năng thẻ và email: P1 chạy lần đầu.

## File đã sửa
`.gitignore`, `.gitattributes`, `CLAUDE.md`, `docs/plan/refactor-big.md`.

## Cách kiểm tra lại
`git log --oneline -3 rf-baseline`; `git status` ở thư mục OneDrive chỉ còn `docs/paper/`; `RESTORE VERIFYONLY` trên file `.bak`.
