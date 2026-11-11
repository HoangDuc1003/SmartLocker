# Bằng chứng đo đạc cho bài báo `docs/paper/smartlocker.tex`

Ngày đo: 30/10/2026 (giờ UTC ghi trong từng log). Mỗi file log ghi lệnh đã chạy và thời điểm ở đầu, kèm nguyên văn đầu ra.
Không có con số nào trong bảng dưới đây được suy ra mà không có log. Các script phụ trợ nằm trong `harness/`
(không sửa mã nguồn của repo; `src/java/ml` giữ nguyên byte, xem `ml.log`).

| File | Nội dung |
|---|---|
| `machine.log` | CPU, RAM, hệ điều hành, JDK, Tomcat, SQL Server |
| `testng.log` | `sh scripts/test.sh` + chạy lại theo từng lớp và theo từng phương thức |
| `ml.log` | So sánh 4 bộ phân loại Weka (10-fold CV, seed 42), 6 lớp và nhị phân, ma trận nhầm lẫn, thời gian |
| `newman.log`, `newman.json`, `newman-2.json`, `newman-3.json` | Postman/newman, CANT-A tạm gán cho LOCKER-01: lần chạy 1 (30/10/2026 13:42–13:44 UTC, `newman.json`, 1 assertion lỗi) và lần chạy 2 sau khi sửa tra cứu ngăn (16:16–16:19 UTC, `newman-2.json`, 0 lỗi, số dùng trong bài), lần chạy 3 trên bản build cuối (16:39–16:42 UTC, `newman-3.json`, 0 lỗi); báo cáo JSON đã che `api_key` |
| `retrain.log` | Huấn luyện lại bằng `test/tool/ModelTrainer`: mô hình triển khai mới là IBk (k=5) sáu lớp, thay Random Forest hai lớp cũ; kiểm tra rủi ro của vài phiên mẫu; TestNG 52/52 lúc đó |
| `testng-2.log` | `sh scripts/test.sh` sau `sql/test_setup.sql` (30/10/2026 16:22 UTC, agent paper-editor-4): 53 test, 53 pass, 0 fail, 0 skip |
| `code-stats-2.log` | Đếm lại trên worktree refactor `rf-p1` (07/11/2026): 88 file Java, 11 384 dòng, 21 JSP, 66 `@Test`, các hằng số đã đối chiếu |
| `testng-3.log` | `sh scripts/test.sh` sau `sql/test_setup.sql` (30/10/2026 16:30 UTC, agent reviewer-4, sau khi triển khai fix-bugs-2): 56 test, 56 pass, 0 fail, 0 skip |
| `scenarios.log` | 6 kịch bản của `test/tool/ScenarioSender.java` + truy vấn DB sau mỗi kịch bản |
| `latency.log` | Thời gian phản hồi phía máy chủ của API thiết bị (curl, 30 lần/endpoint) + kiểm tra khóa 5 lần sai |
| `code-stats.log` | Số dòng Java theo package, số JSP, CSRF, Wi-Fi/HTTPS trong firmware |

## Máy đo (`machine.log`)
Intel Core i5-11400H @ 2.70 GHz (6 nhân / 12 luồng), RAM 16 GB (2 × 8 GB DDR4-3200, 15,77 GiB khả dụng), Windows 11 Home
Single Language 10.0.26200 64-bit (Acer Nitro AN515-57). JDK chạy TestNG và Weka: Oracle 1.8.0_202. Tomcat 9.0.113
đang chạy trên JDK 1.8.0_171. SQL Server 2022 Developer (RTM) 16.0.1000.6.

## Bảng đối chiếu: số trong bài báo → giá trị đo

| Số trong bài báo (vị trí) | Giá trị đo | Khớp? | Log | Lệnh |
|---|---|---|---|---|
| (Vòng 5: bài nay ghi 66 test, xem `CHANGES.md` vòng 5) 56 test, 56 pass (Functional Testing, Abstract, Conclusion) | 56 / 56 / 0 fail / 0 skip (trước đó `testng-2.log`: 53/53; `testng.log`: 52 / 51 / 0 / 1) | Khớp | `testng-3.log` | `sql/test_setup.sql` rồi `sh scripts/test.sh` |
| Rule engine: 14 test | `RuleEngineTest` 14 `@Test` (thêm `commandWindowToleratesASlowBoxClock`) | Khớp | `testng-2.log` | `grep -c @Test test/test/RuleEngineTest.java` |
| Test bị skip "do điều kiện DB chưa chuẩn bị" | `PricingDatabaseIntegrationTest.customReserveChargesTheCustomPriceAndKeepsTheMinutes`: "Run sql/test_setup.sql first (needs v2pin without an open booking, a free L slot)"; sau khi chạy `test_setup.sql` lớp này 6/6 pass | Khớp (lý do đúng) | `testng.log` | listener `harness/PrintListener.java` |
| 480 phiên, 6 lớp × 80 | 480; mỗi lớp 80 | Khớp | `ml.log` | `harness/MlEvidence.java` |
| RF 6 lớp: Acc 0.948, P 0.949, R 0.948, F1 0.948 (Bảng IV, Hình F1 0.9478) | 0.9479 / 0.9494 / 0.9479 / 0.9478 | Khớp | `ml.log` | như trên |
| J48 6 lớp: 0.856 / 0.857 / 0.856 / 0.856 (F1 0.8558) | 0.8563 / 0.8565 / 0.8563 / 0.8558 | Khớp | `ml.log` | |
| NB 6 lớp: 0.779 / 0.778 / 0.779 / 0.778 (F1 0.7775) | 0.7792 / 0.7775 / 0.7792 / 0.7775 | Khớp | `ml.log` | |
| IBk 6 lớp: 0.977 / 0.978 / 0.977 / 0.977 (F1 0.9771) | 0.9771 / 0.9775 / 0.9771 / 0.9771 | Khớp | `ml.log` | |
| RF nhị phân: Acc 0.938, F1 0.939 (0.9387) | 0.9375 / 0.9387 **khi thứ tự nhãn là {NORMAL, ABNORMAL}**; 0.9396 / 0.9406 khi thứ tự {ABNORMAL, NORMAL} hoặc theo thứ tự xuất hiện | Khớp có điều kiện | `ml.log` | |
| J48 nhị phân: 0.831 / 0.848 (0.8476) | 0.8313 / 0.8476 | Khớp | `ml.log` | |
| NB nhị phân: 0.833 / 0.852 (0.8519) | 0.8333 / 0.8519 | Khớp | `ml.log` | |
| IBk nhị phân: 0.975 / 0.975 (0.9754) | 0.9750 / 0.9754 | Khớp | `ml.log` | |
| Ma trận nhầm lẫn RF (Bảng V): WU 63/17, NO 8/72, còn lại 80; F1 WU 0.834, NO 0.852 | giống hệt; F1 WU 0.8344, NO 0.8521, các lớp khác 1.0000 | Khớp | `ml.log` | |
| NB nhị phân "gán cả 80 phiên WRONG_USER là NORMAL" | 80 phiên ABNORMAL bị đoán NORMAL, 0 NORMAL bị đoán sai; **chưa kiểm tra** 80 phiên đó có đúng là WRONG_USER không | Một phần | `ml.log` | |
| RF train ≈ 46 ms, suy luận ≈ 9 µs/phiên; IBk ≈ 20 µs/phiên | RF train (trung vị 11 lần) 35,8–37,7 ms (lần đầu 37,5–43,2 ms); RF suy luận 12,3–15,5 µs; IBk 14,9–18,7 µs (3 lần chạy, 6 lớp) | Lệch (cùng bậc độ lớn; thời gian dao động theo lần chạy) | `ml.log` | |
| Hardware: TODO | xem mục "Máy đo" | — | `machine.log` | |
| ≈ 10 600 dòng Java trong api/controller/dao/service/model/util | Toàn bộ `src/java`: 10 624 dòng (85 file). Riêng 6 package nêu tên: 10 400 dòng (thiếu `filter`, 224 dòng) | Lệch nhẹ về cách diễn đạt | `code-stats.log` | `find … | xargs cat | wc -l` |
| 20 JSP views | 20 file `.jsp` (tất cả trong `web/WEB-INF/views`) + 4 `.jspf` | Khớp | `code-stats.log` | `find web -name '*.jsp'` |
| Khóa sau 5 lần sai, 120 s | Lần sai 1–4: `attempts_left` 4→1; lần 5: `retry_after_sec` 120; lần 6–7 và PIN đúng trong lúc khóa: `LOCKED_OUT`; PIN đúng được nhận lại ở lần thử đầu tiên sau khóa, 125,5 s sau `LOCK_START` (không thử trong khoảng 120–125 s) | Khớp | `latency.log` | curl `/api/device/auth` |
| OFFLINE trong 90–105 s (90 s + job 15 s) | Kịch bản heartbeat: heartbeat cuối 13:32:20.433 → cảnh báo `DEVICE_OFFLINE` 13:34:05.011 = **104,6 s**. Các cảnh báo cũ trong DB: 97, 98, 98, 98 s; 110 s (trùng lúc context Tomcat reload); 906 s (Tomcat không chạy) | Khớp khi Tomcat chạy liên tục | `scenarios.log` | `harness/offline.sh` |
| Snapshot 2 s, job 15 s, timeout 90 s | `SNAPSHOT_INTERVAL_SEC = 2`, `PROCEDURE_INTERVAL_SEC = 15`, `Device_MarkOffline(90)` | Khớp (đọc mã) | `code-stats.log` không chứa; xem `src/java/service/LockerMonitor.java` dòng 42, 45, 129 | grep |
| 18 kịch bản Postman: 221 request, 472 assertion, không lỗi, 2 min 24 s (Functional Testing, Abstract, Conclusion) | Lần chạy 2 (sau khi sửa `LockerSessionDao.resolveSlot`): 221 request (0 lỗi), 472 assertion (0 lỗi), 2 phút 24,1 s, phản hồi trung bình 16 ms. Lần chạy 1: 472 assertion, **1 lỗi** (bước "Batch: bản ghi PHONE dùng command_id", HTTP 500 vì hai dãy cùng có A01), 2 phút 25,3 s | Khớp | `newman.log` (mục "Lần chạy 2"), `newman-2.json`; lần 1: `newman.json` | `newman run … --reporters cli,json` |

### Bảng "Detection Scenarios" (cột Observed)

| Kịch bản | Mong đợi (bài báo) | Quan sát thực tế (`scenarios.log`) |
|---|---|---|
| heartbeat | DEVICE_OFFLINE | 6 heartbeat HTTP 200, rồi im lặng: thiết bị `OFFLINE`, cảnh báo `DEVICE_OFFLINE` (alert 45) sau 104,6 s |
| remote | STAFF_OPEN (không cảnh báo) | Lần 1: cả 2 phiên đều `SUSPECTED_SPOOF` vì `ScenarioSender` gửi `measured_at` làm tròn xuống giây, lệnh được tạo cùng giây nên `measured_at < created_at` (lỗi của bộ giả lập, có truy vấn chứng minh). Lần 2 (chờ 2 s sau khi xếp lệnh): phiên 160 không cảnh báo, lệnh 20 chuyển `DONE` (audit `COMMAND_DONE`); phiên phát lại 161 dùng lại lệnh → `SUSPECTED_SPOOF` (alert 43), đúng như chú thích trong mã |
| spoof | SUSPECTED_SPOOF | `SUSPECTED_SPOOF` (alert 39, `command_id` 999999, "remote open without a valid command") |
| lostcard | LOST_CARD_USED | `LOST_CARD_USED` (alert 44, `card_status` LOST, chủ thẻ 72); thẻ có trong `blocked_cards` của heartbeat |
| checkin | NORMAL (CHECK_IN) | Bản thân `ScenarioSender checkin` chỉ gửi heartbeat (A04 occupied): không có phiên, không cảnh báo, lượt 159 vẫn `RESERVED`. Thêm bước gửi PIN của lượt qua `/api/device/auth`: `UNLOCK`, `phase CHECK_IN`, lượt chuyển `ACTIVE`, audit `CHECK_IN`, không cảnh báo |
| sensor | SENSOR_FAULT + ticket | Cảnh báo `SENSOR_FAULT` (alert 40) và ngăn A01 chuyển `MAINTENANCE`, nhưng **không mở phiếu bảo trì mới** vì LOCKER-01 đã có phiếu OPEN số 6 (dữ liệu mẫu); `Ticket_OpenForFault` chỉ mở một phiếu cho mỗi thiết bị |

### Thời gian phản hồi phía máy chủ (`latency.log`, localhost, 30 lần/endpoint, không tính lần khởi động)

| Endpoint | Mean | Min | p50 | p95 | Max (ms) |
|---|---|---|---|---|---|
| `POST /api/health` (heartbeat) | 5,9 | 4,6 | 6,0 | 6,8 | 7,3 |
| `POST /api/device/auth` PIN đúng, `intent: ASK` | 17,0 | 14,1 | 15,7 | 19,0 | 48,0 |
| `POST /api/kiosk/unlock` PIN đúng, `intent: ASK` | 31,1 | 13,4 | 16,2 | 96,0 | 102,7 |
| `POST /api/device/auth` PIN sai (7 lần, chỉ minh họa khóa) | 2,4–30,8 | | | | |

Đây chỉ là thời gian xử lý của máy chủ đo từ cùng máy, không gồm Wi-Fi, đọc thẻ/vân tay hay servo. Bảng
"End-to-End Response Time of the Locker Box" (Table latency) vẫn chưa có số liệu đo trên hộp thật.
LOCKER-01 không trực tuyến: `last_seen` chỉ thay đổi khi các script trong phiên này gọi API, firmware gốc
`3.3-esp32` (heartbeat của `ScenarioSender` ghi đè thành `sim-1.0`; hộp thật sẽ ghi lại khi kết nối).

### Dữ kiện cho mục Limitations (`code-stats.log`)
- Không có CSRF token: `grep -rniE 'csrf|xsrf|_token|anti.?forgery'` trong `src/java` và `web` = 0 kết quả; không kiểm tra
  `Origin`/`Referer`. Biện pháp hiện có: cookie phiên `SameSite=Lax` (`web/META-INF/context.xml`).
- Firmware online chỉ dùng Wi-Fi (`WiFi.h`, `HTTPClient`); không có BLE/Ethernet/GSM. Firmware `SmartLocker_Local` không có mạng.
- HTTPS: Tomcat chỉ nghe cổng 8080 (HTTP); cổng 8443 không mở; `web.xml` không có `transport-guarantee`. HTTPS chỉ có
  khi đi qua Cloudflare tunnel, và firmware gọi `secure.setInsecure()` (không kiểm tra/ghim chứng chỉ). Chế độ LAN là HTTP thuần.

## Sai khác giữa bài báo và đo đạc
1. RF nhị phân chỉ ra đúng 0.938 / 0.939 khi danh sách nhãn là {NORMAL, ABNORMAL}; với thứ tự khác là 0.940 / 0.941.
   Nên ghi rõ thứ tự nhãn (hoặc báo cả hai). `test/tool/ModelTrainer` không có phần nhị phân và đo thời gian; các số đó do harness này tạo.
2. Thời gian: RF train ~36–38 ms (bài báo 46 ms), RF suy luận ~12–15 µs (bài báo 9 µs), IBk ~15–19 µs (bài báo 20 µs).
   Nên ghi khoảng giá trị hoặc "dưới 50 ms / dưới 20 µs" thay vì một con số.
3. "≈ 10 600 dòng trong api, controller, DAO, service, model, util": đúng cho toàn bộ `src/java` (10 624, có cả `filter`);
   riêng 6 package là 10 400.
4. Kịch bản remote: lần chạy đầu cho `SUSPECTED_SPOOF` do `measured_at` của bộ giả lập bị làm tròn giây; chỉ đúng
   STAFF_OPEN khi phiên đến sau lệnh ít nhất 1 s.
5. Kịch bản checkin: `ScenarioSender checkin` (chỉ heartbeat) không còn tạo check-in; check-in cần PIN qua `/api/device/auth`.
6. Kịch bản sensor: có `SENSOR_FAULT` nhưng không có phiếu mới khi thiết bị đã có phiếu OPEN.
7. OFFLINE có thể vượt 105 s nếu Tomcat reload trong lúc chờ (đo được 110 s một lần); khi chạy ổn định: 97–105 s.
8. Chú thích trong `ScenarioSender` ghi "OFFLINE khoảng 60 s sau", thực tế ngưỡng là 90 s + chu kỳ 15 s.

## Newman / Postman (`newman.log`, `newman.json`)
DB đang gán hộp thật LOCKER-01 cho dãy LIB-A (`sql/demo_box.sql`, 28/10), còn `sql/test_setup.sql` và collection (11 chỗ
`CANT-A`) giả định LOCKER-01 quản lý CANT-A. Theo lựa chọn của người dùng, CANT-A được gán tạm cho LOCKER-01 rồi trả lại sau khi
chạy. Vì chỉ mục duy nhất có lọc `UX_LockerBank_device` (một thiết bị một dãy) chặn lệnh UPDATE khi LOCKER-01 còn giữ LIB-A, chỉ mục
này được xóa tạm (đúng cách `demo_box.sql` làm cho hộp quản lý nhiều dãy) và tạo lại khi khôi phục; hàng LIB-A và lượt 73 không bị đụng.

Trình tự (giờ UTC trong log): ghi trạng thái ban đầu → gán CANT-A cho LOCKER-01 → `test_setup.sql` (thành công) → newman
(1 lần) → `test_cleanup.sql` (đóng 1 lượt, xử lý 1 cảnh báo) → trả CANT-A về LOCKER-05, tạo lại chỉ mục, đặt `firmware` của
LOCKER-01 về `3.3-esp32` → kiểm tra trạng thái cuối khớp ban đầu.

| Chỉ số | Thực hiện | Lỗi |
|---|---|---|
| request | 221 | 0 |
| test-script | 221 | 0 |
| prerequest-script | 19 | 0 |
| assertion | 472 | 1 |

Tổng thời gian 2 phút 25,3 s; phản hồi trung bình 30 ms (min 2, max 267, độ lệch chuẩn 34 ms). Số request/assertion lớn hơn
lần chạy ngày 23/10 trong `docs/postman/README.md` (201/422) vì collection đã thêm bước (ví dụ kịch bản 18).

Lỗi duy nhất: kịch bản 2, bước "Batch: bản ghi PHONE dùng command_id", `POST /api/locker/batch` trả 500. Log Tomcat:
`Subquery returned more than 1 value` trong `LockerSessionDao.insert` (tìm `slot_id` theo `device_id` + `slot_code`). Trong lúc đo
LOCKER-01 quản lý cả LIB-A và CANT-A, cả hai dãy đều có ngăn `A01`, nên truy vấn trả 2 hàng. Đây là hệ quả của cách gán tạm
(khi LOCKER-01 chỉ quản lý CANT-A, truy vấn trả 1 hàng), nhưng cũng là lỗi tiềm ẩn của ứng dụng với hộp nhiều dãy mà
`demo_box.sql` cho phép (mã ngăn không duy nhất trong một thiết bị). Không sửa mã; không chạy lại vì lỗi lặp lại chắc chắn khi
chưa được đổi LIB-A.

Sau khi khôi phục, LOCKER-01 ở trạng thái `ACTIVE` (heartbeat của `test_setup.sql` và collection); `LockerMonitor` tự đưa về
`OFFLINE` sau khoảng 90–105 s.

### Lần chạy 2 (sau khi sửa lỗi) (`newman.log` mục "Lần chạy 2", `newman-2.json`)
Sau lần chạy 1, `LockerSessionDao.resolveSlot` được sửa: tìm ngăn theo `bank_code` hoặc theo ngăn của lệnh gắn với phiên, nếu
không xác định được thì trả `AMBIGUOUS_SLOT`; `Deposit_CheckIn`/`Deposit_Complete` nhận thêm ngăn. Bản sửa đã được triển khai
trước khi đo lại. Lần chạy 2 (30/10/2026, newman 16:16:47–16:19:21 UTC) lặp lại đúng cách gán tạm của lần 1 (cùng một giao dịch:
xóa tạm `UX_LockerBank_device`, CANT-A → LOCKER-01, LIB-A vẫn ở LOCKER-01) → `test_setup.sql` → newman (1 lần) →
`test_cleanup.sql` (đóng 1 lượt, xử lý 1 cảnh báo) → khôi phục.

| Chỉ số | Thực hiện | Lỗi |
|---|---|---|
| request | 221 | 0 |
| test-script | 221 | 0 |
| prerequest-script | 19 | 0 |
| assertion | 472 | **0** |

Tổng thời gian 2 phút 24,1 s; phản hồi trung bình 16 ms (min 1, max 178, độ lệch chuẩn 22 ms). Bước lỗi ở lần 1 (kịch bản 2,
"Batch: bản ghi PHONE dùng command_id", ngăn `A01` có ở cả LIB-A và CANT-A) nay trả 200 và `saved` = 1. Không cần chạy lại.
`api_key` trong `newman-2.json` đã được thay bằng `***` (70 chỗ, kiểm tra lại còn 0).

Khôi phục: CANT-A về LOCKER-05 (device 1), tạo lại `UX_LockerBank_device` (duy nhất, cột `device_id`, lọc
`[device_id] IS NOT NULL`, NONCLUSTERED) như ban đầu, `firmware` của LOCKER-01 = `3.3-esp32`, lượt 73 vẫn `ACTIVE`, CANT-A không
còn lượt mở. Trạng thái cuối khớp trạng thái đầu; LOCKER-01 tạm `ACTIVE` sau heartbeat của lần chạy rồi được `LockerMonitor` tự
đưa về `OFFLINE`.

### Lần chạy 3 (bản build cuối) (`newman.log` mục "Lần chạy 3", `newman-3.json`)
Chạy trên bản build sau fix-bugs-2 (lớp trong `build/web` lúc 16:25 UTC: `markDone` dùng một lần nguyên tử, `UNKNOWN_BANK`,
chặn trùng mã ngăn trong một thiết bị ở `LockerBankController`, khóa trong `Device_Heartbeat`/`Deposit_Complete`). Trước khi chạy
đã kiểm tra: chỉ `RemoteCommandDao.java` được lưu sau bản build, nhưng biên dịch lại cho cùng chữ ký phương thức và cùng chuỗi
SQL với lớp đang chạy, nên không có thay đổi chưa triển khai. Trình tự giống hệt lần 2 (cách gán tạm làm thẳng bằng SQL, không
qua giao diện nên không bị kiểm tra trùng mã ngăn chặn); newman 16:39:32–16:42:01 UTC, 1 lần.

| Chỉ số | Thực hiện | Lỗi |
|---|---|---|
| request | 221 | 0 |
| test-script | 221 | 0 |
| prerequest-script | 19 | 0 |
| assertion | 472 | **0** |

Tổng thời gian 2 phút 26,9 s; phản hồi trung bình 27 ms (min 1, max 176, độ lệch chuẩn 27 ms). Không cần chạy lại.
`api_key` trong `newman-3.json` đã được thay bằng `***` (70 chỗ, kiểm tra lại còn 0).

Khôi phục như lần 2 (CANT-A về LOCKER-05, tạo lại `UX_LockerBank_device` giống hệt, `firmware` = `3.3-esp32`, lượt 73 vẫn
`ACTIVE`). Khác trạng thái đầu một điểm có chủ ý: lúc bắt đầu CANT-A có 3 lượt `RESERVED` của tài khoản kiểm thử (208–210, do
lần chạy TestNG 16:30 UTC để lại sau `test_setup.sql`); `test_setup.sql` và `test_cleanup.sql` đã đóng chúng, nên cuối cùng CANT-A
không còn lượt mở. LOCKER-01 tạm `ACTIVE` sau heartbeat của lần chạy rồi được `LockerMonitor` tự đưa về `OFFLINE`.

## Không đo được (và lý do)
- **Thời gian đầu-cuối trên hộp thật** (PIN/RFID/vân tay/điện thoại → servo): hộp không trực tuyến; không đo thời gian servo.
- **Power off → OFFLINE trên hộp thật**: chỉ đo bằng bộ giả lập (104,6 s), không phải rút điện hộp thật.

## Thay đổi trạng thái DB do phiên đo này
- `sql/test_setup.sql` phần 1 đã commit (đặt lại các tài khoản kiểm thử, bộ đếm sai của LOCKER-01) trước khi lỗi 50035.
- Cảnh báo mới: 39–45 (SUSPECTED_SPOOF, SENSOR_FAULT, LOST_CARD_USED, DEVICE_OFFLINE), phiên 156–162, lệnh từ xa 19 (còn `SENT`,
  sẽ hết hạn) và 20 (`DONE`).
- Ngăn LIB-A A01: bị `SENSOR_FAULT` đưa về `MAINTENANCE`, đã trả về `AVAILABLE` qua giao diện admin.
- Thẻ 04A1B2C3 của student1: báo mất rồi admin mở khóa lại (`ACTIVE`; `lost_at` vẫn còn giá trị).
- Đã chạy `sql/test_cleanup.sql` (đóng 1 lượt: lượt 159 của v2pin → `COMPLETED`, A04 trống). Lượt 73 của student1 và cách gán
  LIB-A→LOCKER-01, CANT-A→LOCKER-05 giữ nguyên như trước phiên đo. Bộ đếm sai của LOCKER-01 có 5 lần sai + 1 lần khóa đã hết hạn
  (13:34:56 UTC): chạy `sql/test_setup.sql` trước lần chạy Postman tiếp theo.
- `Device.firmware` của LOCKER-01 = `sim-1.0` (trước đó `3.3-esp32`); phiên newman đã đặt lại `3.3-esp32`.

## Huấn luyện lại mô hình (2026-10-30, `retrain.log`)

- Mô hình cũ trong `src/java/ml` (12/10) là RandomForest **hai lớp** `{NORMAL, FORCED_OPEN}`, không khớp bài báo. Bản sao và
  sha256 lưu ở `harness/old-model/` (bin `aa480e04…be06d`, arff `3aa77fb2…41ad7`).
- Đã chạy lại `test/tool/ModelTrainer` (JDK 1.8.0_202, thư mục làm việc = gốc dự án) trên `PublicSession` (480 dòng, 6 lớp).
  Kết quả 10-fold CV (`new Random(42)`) trùng đúng 16 số của bảng sáu lớp trong `ml.log`:
  RandomForest 0,9479 / 0,9494 / 0,9479 / 0,9478; J48 0,8563 / 0,8565 / 0,8563 / 0,8558; NaiveBayes 0,7792 / 0,7775 / 0,7792 / 0,7775;
  **IBk (k=5) 0,9771 / 0,9775 / 0,9771 / 0,9771** (accuracy / precision / recall / F1 có trọng số).
- Mô hình mới được lưu: `weka.classifiers.lazy.IBk -K 5`, nhãn `{FORCED_OPEN, WRONG_USER, OVERDUE, ITEM_LEFT, SUSPECTED_SPOOF, NORMAL}`
  (bin `eec4b327…a433`, arff `c1cbcc84…596c`).
- `RiskScorer` lấy vị trí của `NORMAL` từ header (`indexOfValue("NORMAL")`, ở đây là 5) nên rủi ro = 1 − P(NORMAL) đúng với sáu lớp,
  không cần sửa mã. `test.RiskScorerTest` đạt 1/1, toàn bộ bộ TestNG đạt 52/52.
- Triển khai: chép hai tệp vào `build/web/WEB-INF/classes/ml` rồi nạp lại context (không chạy `build-dev.sh` để khỏi triển khai mã
  đang sửa dở của phiên khác). Kiểm tra đầu-cuối: một phiên gửi qua `/api/locker/batch` bằng LOCKER-01 (cửa 8 s, 3 lần mở, `rfid_ok`
  = false) tạo cảnh báo 50 `FORCED_OPEN` với `risk_score` = 0,9996, đúng mô hình mới (mô hình cũ cho 0,10). Dữ liệu thử còn lại:
  phiên 165 và cảnh báo 50.
