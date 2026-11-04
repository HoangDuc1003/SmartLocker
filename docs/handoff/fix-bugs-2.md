# Handoff: fix-bugs-2

## Mục tiêu
Sửa toàn bộ phát hiện trong `docs/review/fix-bugs-review.md` (M1, L1–L5), test, triển khai, kiểm tra trên trình duyệt/DB.
Không commit; không sửa `docs/paper/*`, README, `src/java/ml/*`.

## Đã làm
- **M1** `LockerMonitor.heartbeatDemoDevices`: thiết bị demo OFFLINE chỉ được heartbeat giả lập khi bản ghi trạng thái
  mới nhất trong AuditLog (`MARK_OFFLINE` / `BACK_ONLINE` / `DEVICE_STATUS`) là `MARK_OFFLINE` (do `Device_MarkOffline`).
  OFFLINE do nhân viên ("Đánh dấu mất kết nối") hoặc seed LOCKER-07 giữ nguyên. Lesson trong CLAUDE.md đã cập nhật.
- **L1** `LockerBankDao.slotCodeClash` + kiểm tra trong `LockerBankController.validate` (lỗi tiếng Việt trên form, không lưu);
  thêm `LockerSlotDao.codeExistsOnDevice` + `LockerSlotController.validate`. Comment lý do trả 200 cho AMBIGUOUS_SLOT trong `LockerSessionApi`.
- **L2** `bank_code` rỗng -> null (`LockerSessionApi.parse`); mã dãy không thuộc thiết bị -> `UNKNOWN_BANK` trong `errors`
  (`LockerSessionDao.UNKNOWN_BANK = -3`).
- **L3** `Deposit_Complete` (sql/02_data_v1.sql): đọc booking sau `BEGIN TRAN` với `WITH (UPDLOCK, HOLDLOCK)`; nhánh không có
  booking `COMMIT; RETURN;` để giữ @@TRANCOUNT.
- **L4** `Device_Heartbeat`: lấy trạng thái cũ bằng `OUTPUT deleted.status` trong transaction.
- **L5** `RemoteCommandDao.markDone` trả boolean (UPDATE ... WHERE status='SENT'); `AlertService` đổi sang `SUSPECTED_SPOOF`
  nếu lệnh đã bị dùng; comment `RuleEngine` sửa cho đúng.
- L3/L4 đã áp lên DB live (chỉ 2 khối CREATE OR ALTER). Đã build/deploy (`scripts/build-dev.sh`).
- Test mới `test/test/DeviceBankDatabaseIntegrationTest.java` (3 test). `sh scripts/test.sh`: 56/56 đạt.

## Đã kiểm tra
- M1: `Device_MarkOffline` thật trên LOCKER-10 -> ~3 s sau ACTIVE, cảnh báo RESOLVED. Nhân viên đánh dấu mất kết nối
  -> vẫn OFFLINE sau 45 s. Đã khôi phục (ACTIVE, xoá cảnh báo test #58).
- L1: form sửa DOMA-A gán LOCKER-01 -> hiện lỗi trùng mã A01, DB không đổi.
- L2: curl `/api/locker/batch` (device-3-api-key) -> `UNKNOWN_BANK` cho `ZZZ`, `""` không bị coi là mã lạ; không lưu dòng nào.

## Việc còn mở
- Cần một agent khác cross-review diff này (theo quy trình CLAUDE.md).
- L5 chưa test live (cần tạo lệnh từ xa thật, sinh audit); chỉ kiểm tra bằng đọc code.
- I2 của review (README/SYSTEM_FLOWS chưa mô tả `bank_code`, `errors`, nay thêm `UNKNOWN_BANK`) để cho task README.

## File đã sửa
`CLAUDE.md`, `sql/02_data_v1.sql`, `src/java/service/{LockerMonitor,AlertService,RuleEngine}.java`,
`src/java/dao/{RemoteCommandDao,LockerSessionDao,LockerBankDao,LockerSlotDao}.java`, `src/java/api/LockerSessionApi.java`,
`src/java/controller/{LockerBankController,LockerSlotController}.java`, `test/test/DeviceBankDatabaseIntegrationTest.java` (mới).

## Cách kiểm tra lại
1. `sh scripts/test.sh` -> 56 đạt.
2. `SELECT CHARINDEX('UPDLOCK', OBJECT_DEFINITION(OBJECT_ID('Deposit_Complete')))` > 0 và
   `OBJECT_DEFINITION(OBJECT_ID('Device_Heartbeat'))` chứa `OUTPUT deleted.status` (`sqlcmd -I`).
3. M1: set `last_seen` của một thiết bị demo lùi 10 phút, `EXEC Device_MarkOffline 90` -> trong ~15 s quay lại ACTIVE;
   bấm "Đánh dấu mất kết nối" trên trang chi tiết cảnh báo -> giữ OFFLINE; nhớ bấm "Hoạt động lại" để khôi phục.
4. L2: POST `/api/locker/batch` với `bank_code` lạ -> `errors[].code = UNKNOWN_BANK`.
