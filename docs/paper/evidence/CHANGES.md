# Thay đổi của `docs/paper/smartlocker.tex` (agent "editor", 30/10/2026)

Chỉ sửa `smartlocker.tex`; `references.bib` giữ nguyên (cả 16 khóa vẫn được trích dẫn). Không có trình biên dịch LaTeX:
đã kiểm tra bằng script rằng ngoặc `{}` cân bằng (466/466), mọi `\begin`/`\end` khớp, mọi `\ref` có `\label`, mọi `\cite`
có trong `references.bib`, không còn `_` hoặc `$` lẻ ngoài chế độ toán / không thoát.

## Sửa theo mục

| Mục | Thay đổi |
|---|---|
| Preamble | Bỏ gói `algorithmic` (không còn dùng sau khi bỏ Algorithm 1). `amsmath` giữ lại. |
| Abstract | Viết lại theo mạch: vấn đề (tủ dùng chìa/mã giấy, không đặt trước, nhân viên không thấy cạy cửa/mất thẻ/quá hạn, tủ nối mạng bị giả lệnh) → SmartLocker làm gì → đã kiểm chứng gì (F1 0.977, 51/52 test, 6 kịch bản phát hiện, thời gian phản hồi máy chủ 6–31 ms trung bình). Ghi rõ dữ liệu 480 phiên là tổng hợp. |
| I. Introduction | Rút gọn: gộp 2 đoạn vấn đề thành 1; 5 gạch đầu dòng "contributions" thành 3 gạch "what it does" (thuê tủ, hộp mỏng có xác thực, phát hiện truy cập bất thường); thêm 1 câu "đã kiểm chứng gì"; đoạn bố cục gộp vào cùng đoạn. |
| II. Related Work | Chỉ thêm dòng trống trước "IoT security" (trước đó dính vào đoạn trên). |
| IV.A Telemetry | Bỏ phương trình `x(s)=(d,w,u,r,t)` và các ký hiệu; thay bằng Bảng "Telemetry Features of an Access Session" (`tab:features`, 5 đặc trưng: thời gian mở cửa, thay đổi khối lượng, số lần mở khóa, thẻ hợp lệ, thời gian gửi). Bỏ ký hiệu `C(s)`. |
| IV.B Bảng "Detection Rules" | Viết điều kiện bằng lời thay cho d/w/t/r (ví dụ `d > 60t+5` → "door open longer than the whole stay"). Đối chiếu `src/java/service/RuleEngine.java`: ngưỡng 50 g, 300 s, thứ tự luật giữ nguyên. Rule 2' thêm "(never issued, or already used)" — đúng với kịch bản phát lại lệnh. Hành động rule 1: "Alert, ticket, no ML". |
| IV.C Tier 2 | Bỏ phương trình `ρ = 1 − P(NORMAL|x)`; nói bằng một câu (risk = 1 − xác suất NORMAL; cảnh báo ML_ANOMALY khi không luật nào khớp và risk ≥ 0.80, `AlertService.ML_THRESHOLD = 0.80`). Thay Algorithm 1 (hình `alg:detect`) bằng danh sách 6 bước; bước SENSOR_FAULT ghi "one open ticket per device" (đối chiếu `Ticket_OpenForFault` trong `sql/02_data_v1.sql`: chỉ mở phiếu khi thiết bị chưa có phiếu OPEN). |
| IV.E Audit log | Bỏ công thức hash dài; mô tả bằng lời (mỗi bản ghi lưu SHA-256 của các trường của nó cùng hash của bản ghi trước), trích dẫn Haber–Stornetta. |
| V. Implementation | Câu số dòng mã: "about 10 600 lines in 85 source files, counting all packages … and the security filter". Chú thích Hình UI sửa theo `screens.log` (xem dưới). |
| VI.A Setup | Thay `Eq.~(1)` bằng `Table~\ref{tab:features}`; "r = 0" → "no valid card"; ghi thứ tự nhãn nhị phân {NORMAL, ABNORMAL}; mô tả cách đo thời gian (trung vị 11 lần build, 20×480 dự đoán sau 1 lượt khởi động, 3 lần chạy); điền phần cứng (TODO cũ). Thêm `\label{sec:latency}` cho mục thời gian phản hồi. |
| VI.B Kết quả | Câu thời gian sửa theo đo thực tế (6 lớp). |
| VI.C Discussion | Câu Naive Bayes làm mềm: chỉ nói 80/400 phiên ABNORMAL bị gán NORMAL, 0 phiên NORMAL sai, "as many as there are wrong-user sessions (we did not check which classes …)". |
| VI.D Functional Testing | TODO newman viết lại: nêu chính xác lý do chưa chạy được và cách chạy lại. Mô tả kịch bản phát hiện: bộ giả lập dùng khóa của LOCKER-01, truy vấn DB sau mỗi kịch bản. Bảng kịch bản: điền cột Observed, sửa Input/Expected theo các bước thật; thêm đoạn giải thích trung thực 2 kịch bản cần chạy lại (remote: lỗi làm tròn giây của bộ giả lập; checkin: `ScenarioSender checkin` chỉ gửi heartbeat nên phải gửi PIN qua `/api/device/auth`). |
| VI.E Response time | Đổi tên thành "Server-Side Response Time". Bỏ bảng đầu-cuối toàn TODO; thay bằng bảng thời gian xử lý phía máy chủ (curl, localhost, 30 lần/endpoint), ghi rõ không gồm Wi-Fi, đầu đọc, servo. Thêm số đo khóa 5 lần sai (120 s) và phát hiện OFFLINE (104,6 s; 97–98 s; 1 lần 110 s do reload). Giữ MỘT `\TODO` đỏ cho đo đầu-cuối trên hộp thật. |
| VI.F Limitations | "three" → "four"; câu thứ ba thêm "response times measured on the server only"; hạn chế thứ tư (bảo mật truyền tải) thay cho TODO. |
| VII. Conclusion | "offline detection within about 90 s" → "within 90–105 s", thêm "120 s lockout"; thêm 1 câu về 6 kịch bản và thời gian phản hồi; future work thêm đo đầu-cuối trên hộp, CSRF token và kiểm tra chứng chỉ. |

### Chú thích hình (theo `screens.log`)
- Hình UI 1: `map-visitor.png` = bản đồ 5 khu vực, khách chưa đăng nhập; `map-area.png` = khu GYM, dãy GYM-A có 3 ngăn bị khóa quá hạn (A01, A05, A04) và 1 ngăn có cảnh báo (A06); `booking-confirm.png` = popup xác nhận đặt A03 GYM-A, gói 2 giờ, PIN; `my-locker-pin.png` = "Tủ của tôi" với PIN, đếm ngược giữ chỗ và hủy miễn phí. Ghi thêm "(in Vietnamese)".
- Hình UI 2: `dashboard.png`, `alerts.png`; `alert-escalated.png` = cảnh báo #36 `OVERDUE_ESCALATED`, GYM-A A05, trễ 52 giờ, bảng bằng chứng; `kiosk-phone.png` = `/k/LOCKER-06` ở bề rộng điện thoại, báo lỗi mã không đủ 6 chữ số.

## Số đã điền → log

| Số trong bài | Log |
|---|---|
| i5-11400H 2,7 GHz 6 nhân, 16 GB RAM, Windows 11 64-bit, JDK 1.8.0_202 | `machine.log` |
| Weka 3.8.6 | `ml.log` (dòng `java=1.8.0_202 weka=3.8.6`) |
| Tomcat 9.0.113, SQL Server 2022 trên cùng máy | `machine.log`, `latency.log` (đầu file) |
| Thứ tự nhãn nhị phân {NORMAL, ABNORMAL} cho RF 0.938/0.939 | `ml.log` |
| RF train 36–38 ms (trung vị 35,8 / 37,7 / 37,2), suy luận 12–15,5 µs (12,34 / 13,84 / 15,48); IBk train < 1 ms, suy luận 15–17 µs (17,16 / 16,34 / 14,94) — bài chỉ nêu bảng 6 lớp | `ml.log` (3 lần chạy) |
| NB nhị phân: 80 phiên ABNORMAL → NORMAL, 0 NORMAL sai | `ml.log` (ma trận nhầm lẫn nhị phân NaiveBayes) |
| ~10 600 dòng, 85 file, gồm cả `filter` | `code-stats.log` (10 624 dòng) |
| heartbeat: 6 heartbeat cách 10 s; OFFLINE sau 104,6 s | `scenarios.log` (alert 45, delta_ms 104579) |
| 4 cảnh báo cũ 97–98 s; 1 lần 110 s do reload context | `scenarios.log` (alerts 14, 15, 17, 38; 37) |
| remote: phiên 160 không cảnh báo, lệnh 20 `DONE`, audit `COMMAND_DONE`; phiên phát lại 161 → `SUSPECTED_SPOOF` | `scenarios.log` |
| spoof: `SUSPECTED_SPOOF` "remote open without a valid command" | `scenarios.log` (alert 39) |
| lostcard: `LOST_CARD_USED`, thẻ có trong `blocked_cards` | `scenarios.log` (alert 44) |
| checkin: PIN → `UNLOCK` `CHECK_IN`, lượt 159 `ACTIVE`, A04 `OCCUPIED`, không cảnh báo | `scenarios.log` |
| sensor: khối lượng −5000 g ngoài khoảng −200…20 000 g → `SENSOR_FAULT`, A01 `MAINTENANCE`, không phiếu mới (đã có phiếu OPEN số 6) | `scenarios.log` (alert 40) |
| Bảng thời gian phản hồi: health 5,9/6,0/6,8/4,6/7,3; device/auth 17,0/15,7/19,0/14,1/48,0; kiosk/unlock 31,1/16,2/96,0/13,4/102,7 ms (mean/p50/p95/min/max) | `latency.log` (mục statistics) |
| Không tính 1 lượt khởi động mỗi endpoint | `harness/latency.sh` dòng 19 |
| Khóa: lần sai 1–4 còn 4→1 lần, lần 5 `retry_after_sec` 120, PIN đúng trong lúc khóa → `LOCKED_OUT`, PIN đúng được nhận lại ở lần thử đầu sau khóa, 125,5 s sau `LOCK_START` | `latency.log` |
| Heartbeat mỗi 3 s (`interval_sec: 3`) | `latency.log`, `scenarios.log` |
| Không CSRF token, chỉ `SameSite=Lax`; chỉ Wi-Fi; Tomcat HTTP 8080; HTTPS chỉ qua Cloudflare tunnel, firmware `setInsecure()` | `code-stats.log` |
| Ngưỡng 0.80, 48 giờ, 90 s / 15 s | `src/java/service/AlertService.java:19`, `sql/03_v2_v3.sql` (`ESCALATE_HOURS` 48), `LockerMonitor.java` (theo `README.md` của evidence) |

## TODO còn mở cho nhóm tác giả
1. **Newman (17 kịch bản Postman)** — mục VI.D: gán lại LOCKER-01 cho CANT-A, chạy `sql/test_setup.sql`, rồi lệnh newman trong `newman.log`; điền số request/assertion đạt/tổng. Không dùng lại kết quả 23/10/2026 như kết quả hiện tại.
2. **Thời gian đầu-cuối trên hộp thật** — cuối mục VI.E: PIN / thẻ / vân tay / trang điện thoại → servo chuyển động, ≥ 20 lần mỗi cách (có thể quay video và đếm khung hình). Nếu đo thêm "rút điện → OFFLINE" trên hộp thật thì bổ sung vào cùng đoạn.
3. **Sơ đồ nối dây `images/wiring.png`** — Hình phần cứng (mục III.C) vẫn là ô giữ chỗ đỏ do macro `\img` vẽ.

## Điểm cần người duyệt kiểm tra
- Tóm tắt và kết luận nói "six detection scenarios … produced the expected labels": đúng với lần chạy được ghi, nhưng remote cần chạy lại (lỗi làm tròn giây của bộ giả lập) và checkin cần thêm bước PIN; cả hai đã được nêu trong bài ngay dưới bảng.
- Bảng kịch bản `sensor`: cột Expected ghi "ticket" nhưng thực tế không mở phiếu mới vì thiết bị đã có phiếu OPEN (đúng thiết kế một phiếu/thiết bị); cột Observed ghi rõ điều này.
- Con số "6–31 ms" trong Abstract/Conclusion là trung bình của 3 endpoint (5,9 và 31,1 làm tròn); p95 của `/api/kiosk/unlock` là 96 ms.
- Thời gian ML trong bài là của bài toán 6 lớp; README của evidence nêu IBk 14,9–18,7 µs vì gộp cả các lần chạy nhị phân.

## Vòng 2 (agent "editor-2", 30/10/2026) — sửa theo `REVIEW.md`

Chỉ sửa `smartlocker.tex`; `references.bib` giữ nguyên. Kiểm bằng script (`chk.py` trong scratchpad): ngoặc `{}` 444/444,
mọi begin/end khớp, mọi ref có label và ngược lại, 16 khóa cite đều có trong `references.bib`, không còn `_`/`#` chưa thoát.
Còn đúng 2 TODO: đo đầu-cuối trên hộp thật (VI.E) và ô giữ chỗ `wiring.png` (macro `img`).

| Mục | Đã sửa |
|---|---|
| A1 | "17" → "18 scenarios" (đếm trong `docs/postman/SmartLocker-v2.postman_collection.json`: thư mục Scenarios 1–10 và 18, thư mục v3 11–17); danh sách bổ sung thẻ đã báo mất, đặt PIN nhưng quẹt thẻ, PIN của lượt đã kết thúc/hộp khác, sai API key/body, mở nhiều lần trong một lượt, cộng các request lẻ tới endpoint thiết bị. |
| Newman (TODO) | Đã điền từ `newman.log` (dòng SUMMARY) và README evidence: 221 request (0 lỗi), 472 assertion (1 lỗi), 2 phút 25 s. Lỗi duy nhất: `POST /api/locker/batch` HTTP 500 ở kịch bản 2 vì lần chạy tạm cho LOCKER-01 quản lý LIB-A và CANT-A, cả hai có ngăn A01, truy vấn slot theo (device, slot_code) trong `LockerSessionDao.insert` trả 2 dòng. Nêu trung thực 1 câu ở VI.D, thêm vào Limitations (hạn chế thứ tư) và future work. TODO newman đã xóa. Abstract thêm "471 of 472 assertions of an 18-scenario API test suite". |
| A2 | Chú thích `kiosk-phone.png` đổi theo ảnh: trang mở tủ LOCKER-06 ở bề rộng điện thoại, ô PIN 6 số, ghi chú khóa 5 lần sai/2 phút (đã xem ảnh). Không chụp lại. |
| A3 | `grep` firmware: `SmartLocker_Online.ino` chỉ gọi `/api/health`, `/api/device/auth`, `/api/device/enroll/start|finish`; không có `locker/batch`. III.D: "The device API has three main endpoints (two more enroll a card or a fingerprint)" + câu "firmware dùng hai endpoint đầu và enroll; chưa gửi phiên; batch chỉ do bộ giả lập". IV.A: phiên "uploaded through /api/locker/batch". VI.D: bỏ "as on a real box"; mô tả bộ giả lập "sends device API requests (heartbeats, credentials and session uploads)". Limitations thứ nhất: firmware chưa gửi phiên, mọi phiên trong thí nghiệm đến từ bộ giả lập hoặc seed. |
| A4 | Bỏ "which is what the risk score uses"; nhị phân = "measures the NORMAL-versus-rest decision", là phân tích thêm, không triển khai; risk = 1 − P(NORMAL) của mô hình 6 lớp (`RiskScorer.java` dòng 17, 68). **Khác với quyết định "mô hình triển khai là IBk":** file đang dùng `src/java/ml/locker_model.bin` (và bản trong `build/web`, ngày 12/10) là **RandomForest** (chuỗi lớp Java serialize: `weka.classifiers.trees.RandomForest`, không có `IBk`). `ModelTrainer` lưu mô hình 6 lớp có F1 cao nhất, trên dữ liệu hiện tại là IBk. Bài viết đúng sự thật: file hiện có là Random Forest của một lần huấn luyện trước; huấn luyện lại sẽ thay bằng IBk. |
| A5 | Bảng kịch bản hàng sensor, Expected: "a ticket unless the box already has an open one". Đoạn dưới bảng: "All six scenarios produced the expected label. Two needed a change"; nói rõ luật lệnh từ xa so thời gian không có dung sai (`SessionContextDao` dòng 58: `measured_at BETWEEN created_at AND +30 min`) nên đồng hồ hộp chậm sẽ gây báo động giả; checkin của bộ giả lập để lượt ở `RESERVED`, kết quả có được nhờ gửi PIN. Abstract và Conclusion thêm "(two after adjusting the simulator)". Dung sai đồng hồ đưa vào Limitations và future work. Tiêu đề bảng: "Replayed through the Device API". |
| B1 | Thêm câu ở V: giá giờ suy ra từ giá gói 2 giờ theo cỡ; phí trễ = 150% giá giờ chưa làm tròn, làm tròn một lần (vì thế M là 4 900 chứ không phải 1,5 × 3 300). Đối chiếu `fn_HourRate`, `fn_OverdueRate` trong `sql/03_v2_v3.sql`. |
| B2 | "one-time PIN" → "per-booking PIN". |
| B3 | Giữ ma trận Random Forest (đúng là mô hình đang triển khai, xem A4), tiêu đề thêm "Currently Deployed Model". Discussion: các lớp nhận đúng hoàn toàn "by Random Forest"; thêm lỗi của IBk theo `ml.log` dòng 35–41: 10/11 lỗi giữa WRONG_USER và NORMAL (7 và 3), 1 ITEM_LEFT → SUSPECTED_SPOOF. Abstract/Conclusion: "most of its errors are between wrong-user and normal access, which telemetry alone cannot reliably separate". |
| B4 | Bỏ vế "as many as there are wrong-user sessions (we did not check …)"; chỉ giữ số đo: 80/400 phiên bất thường bị gán NORMAL, mọi phiên NORMAL đúng. |
| B5 | Thêm: số 97–98 s tính từ last_seen lưu tới giây nguyên nên lệch tối đa 1 s; trong 2 cảnh báo cũ còn lại, 1 lần 110 s do reload, 1 lần (906 s) bị loại vì máy chủ dừng (`scenarios.log` dòng 364–371). Conclusion: "within 90–105 s while the server runs". |
| B6 | Limitations thứ ba: hộp quản lý thêm vài ngăn logic; các dãy khác trong hình thuộc thiết bị demo có heartbeat do máy chủ giả lập (`LockerMonitor.java` dòng 124–128; `"demo":true` cho mọi thiết bị trừ LOCKER-01, `sql/03_v2_v3.sql` dòng 130–138). Chú thích Hình ui1 (GYM-A là thiết bị demo) và ui2 (mọi thiết bị trừ LOCKER-01 là demo). |
| B7 | "public set" → "synthetic set" (`TransferCheck` đọc bảng `PublicSession`, dữ liệu tổng hợp). |
| B8 | Danh sách 6 bước (IV.C) gộp thành 3 câu (cùng D2); audit chỉ ghi khi lệnh hoàn tất (`COMMAND_DONE`) và khi tạo cảnh báo (`CREATE ALERT`) — đối chiếu `AlertService.evaluate`. |
| C1 | Abstract/Conclusion: "on localhost … a mean time of 6–31 ms per endpoint (95th percentile at most 96 ms)" (p95 lớn nhất 96,0 ms, `latency.log`). |
| C2 | Thêm "Tomcat 9.0.113 (on JDK 1.8.0_171)". |
| C3 | "all with default parameters" → "otherwise with default parameters". |
| C4 | "after 5 wrong guesses within 5 minutes" (`sql/03_v2_v3.sql` dòng 360). |
| C5 | Luật 2: "a valid, unused command for this slot, issued at most 30 min before the session" (`SessionContextDao` dòng 53–58). |
| C6 | Chú thích ui1: "area GYM (“Nhà văn hóa Sinh viên”)" viết bằng lệnh dấu LaTeX (an toàn khi biên dịch). `alerts.png` (số rủi ro thô, "Thiết bị #5"): không nhắc trong bài; chú thích chỉ ghi "the alert list", không khẳng định gì thêm. Lỗi giao diện báo riêng. |
| C7 | "What it does:" → "Its main functions are:"; câu đầu Abstract tách đôi; câu kết quả trong Abstract tách thành ba câu. |
| C8 | Không sửa: cần nhóm tác giả tự mở DOI 10.1063/5.0101139 để xác nhận. |
| C9 | Không cần sửa (reviewer xác nhận). |
| D1 | Bỏ Hình `fig:f1` và gói `pgfplots`; câu "Table … and Fig. …" chỉ còn bảng; không còn chỗ nào tham chiếu `fig:f1`. |
| D2 | Xem B8. |
| D3 | Giữ cột chân ESP32 của Bảng I (theo quyết định của orchestrator). |
| F | Bỏ gói `flushend` (vô tác dụng ở onecolumn). |

## Vòng 3 (agent "editor-3", 30/10/2026) — sửa theo "Vòng 2" của `REVIEW.md`

| Mục | Sửa |
|---|---|
| R2-A1 | IV.C (Tier 2, thêm `\label{sec:tier2}`): công cụ huấn luyện so bốn bộ phân lớp và triển khai mô hình sáu lớp có F1 trọng số cao nhất (IBk trên dữ liệu hiện tại); file mô hình đi kèm bản mẫu cũ hơn: Random Forest **hai lớp** (NORMAL vs FORCED_OPEN) từ bộ dữ liệu trước, nên hệ thống đang chạy dùng 1 − P(NORMAL) của nó; huấn luyện lại sẽ thay file (`src/java/ml/locker_header.arff`, `locker_model.bin`, `test/tool/ModelTrainer.java`). Bỏ các câu triển khai mô hình khỏi VI.A Protocol (chỉ còn mô tả thí nghiệm; giữ "the binary models … are not deployed"). Limitations thứ hai: thêm "the model file shipped with the prototype predates the six-class data set". |
| R2-A1 (Bảng V) | **Đổi sang ma trận nhầm lẫn của IBk** (tiêu đề "Confusion Matrix and Per-Class F1 of IBk (k=5), Six Classes, 10-Fold Cross-Validation"). Lý do: IBk là mô hình thắng và là mô hình công cụ huấn luyện sẽ triển khai, lời bình Discussion vốn nói về IBk, và ma trận RF không còn gắn với file nào đang chạy. Số lấy nguyên từ `ml.log` run 1 dòng 35–51: WU 73/7, IL 79 + 1→SS, NO 3/77; F1 1.000, 0.936 (0.9359), 1.000, 0.994 (0.9937), 0.994 (0.9938), 0.939 (0.9390). Số của RF (17 WU→NO, 8 NO→WU, `ml.log` dòng 19–25) chuyển vào lời văn Discussion. |
| R2-B1 | Dataset (VI.A): thêm "Wrong-user sessions are generated with exactly the same formulas as normal ones … the two classes differ only in the row index that the formulas take as input" (`sql/02_data_v1.sql` dòng 718–733). Discussion viết lại: lỗi WU/NO "follows from how the data is built, not from an empirical observation"; việc IBk/RF vẫn tách phần lớn là "an artefact of the generator, whose formulas give the two classes slightly different values through the row index". Đoạn sau mở bằng "The design argument does not depend on these scores" và giữ lập luận luật 5 (danh tính). Intro: "shows" → "illustrates, on synthetic data built that way, that telemetry alone does not separate wrong-user from normal access"; Abstract: "this illustrates why identity is checked by a rule, not by telemetry"; Conclusion: "confirms" → "illustrates, rather than proves". Không thêm số mới. |
| R2-B2 | Bỏ câu thiết bị demo ở chú thích Hình ui1 (giữ ở ui2 và Limitations thứ ba). VI.D chỉ nói "a device simulator" (đã như vậy, không nhắc firmware). Limitations thứ tư chỉ trỏ lại "the two weaknesses … found in Section~\ref{sec:tests}" (thêm `\label{sec:tests}` cho Functional Testing) thay vì giải thích lại cơ chế. Bỏ vế "response times … measured on the server only" khỏi Limitations thứ ba (VI.E và TODO đã nói). |
| C1 | "upper bound" → "optimistic" (và thêm lý do: hai lớp cùng công thức). |
| C2 | Abstract: "On 480 synthetic, labelled telemetry sessions"; bỏ vế "Lockouts, heartbeat monitoring, … complete the design" và vế p95 (vẫn có trong Bảng latency và Conclusion không cần); rút gọn câu đầu và câu kết quả. Khoảng 247 từ (`wc -w`, ≤ 250). |
| C3 | Conclusion thêm "passed 51 of 52 unit and integration tests (one skipped) and 471 of 472 assertions of the 18 API scenarios". |
| C4 | Xem R2-A1 (câu file mô hình chuyển sang IV.C). |
| C5 | Câu "(computed from a last-seen time …)" tách thành câu riêng "These four delays are computed from …". |
| C6 | Bỏ qua (theo reviewer). |
| C7 | Giữ `amsmath,amssymb,amsfonts` (theo orchestrator). |
| C8 | Không sửa: DOI 10.1063/5.0101139 để nhóm tác giả xác nhận. |

Kiểm tra cú pháp (script, không có trình biên dịch): ngoặc `{}` 456/456; 30 cặp `\begin`/`\end` khớp; mọi `\ref` ↔ `\label` (thêm `sec:tier2`, `sec:ml`, `sec:tests`, không thừa/thiếu); chỉ ký tự ASCII; không thêm khóa `\cite`. TODO còn đúng hai: `\TODO` đo đầu-cuối trên hộp thật (VI.E) và ô giữ chỗ `wiring.png` do macro `\img` vẽ.

## Vòng 4 (agent "editor-4", 30/10/2026) — cập nhật theo hệ thống sau khi huấn luyện lại và sửa lỗi

| Mục | Sửa |
|---|---|
| Mô hình | IV.C (`sec:tier2`): bỏ câu "file mô hình đi kèm là Random Forest hai lớp cũ"; nay ghi IBk (k=5) sáu lớp là mô hình triển khai, và một phiên tự tạo có telemetry bình thường cho rủi ro 0.20, dưới ngưỡng (`retrain.log`: `normal-like ... risk=0.2016`). Discussion: "the model that the training tool selects" → "the deployed model". Limitations thứ hai: bỏ câu "the model file ... predates the six-class data set". |
| TestNG | Chạy `sql/test_setup.sql` rồi `sh scripts/test.sh` (`testng-2.log`): 53 test, 53 pass, 0 skip. VI.D: 53 test, rule engine 14 test (`RuleEngineTest` có thêm `commandWindowToleratesASlowBoxClock`), "all 53 passed". Abstract và Conclusion: "passed all 53 unit and integration tests". |
| Newman | VI.D: nêu lần chạy 1 lỗi 1 assertion (HTTP 500 ở `/api/locker/batch` vì hai dãy cùng có A01), máy chủ nay tra ngăn theo `bank_code` hoặc ngăn của lệnh, nếu không thì từ chối `AMBIGUOUS_SLOT`; kết quả báo cáo là lần chạy 2: 221 request, 472 assertion, 0 lỗi, 2 min 24 s (`newman.log` mục "Lần chạy 2", `newman-2.json`; vẫn 18 kịch bản: 11 + 7). Abstract và Conclusion: "all 472 ... assertions". |
| Đồng hồ lệnh từ xa | Đoạn sau Bảng kịch bản: lỗi "không có dung sai đồng hồ" được mô tả là do kịch bản *remote* phát hiện và đã sửa: luật chấp nhận phiên ghi giờ sớm hơn lệnh tối đa 60 s (`RuleEngine.COMMAND_CLOCK_LAG_SEC = 60`), có test rule engine. Không nhắc "dùng một lần" là nguyên tử, không nhắc phục hồi thiết bị demo. |
| Limitations / Future work | "five" → "four" hạn chế: bỏ hạn chế thứ tư cũ (hai điểm yếu đã sửa); Future work bỏ "a clock tolerance for remote opens" và "slot lookup that stays unique ...". |
| `README.md` (evidence) | Bảng file: thêm `newman-2.json`, `retrain.log`, `testng-2.log`. Bảng đối chiếu: dòng TestNG (53/53, rule engine 14) và dòng Postman (lần chạy 2). |

Kiểm tra cú pháp (script): ngoặc `{}` 455/455; 30 cặp `\begin`/`\end` khớp; mọi `\ref` có `\label` (`sec:tier2`, `sec:tests` nay không còn được tham chiếu, vô hại); chỉ ASCII; Abstract 243 từ; không thêm khóa `\cite`. TODO còn đúng hai: đo đầu-cuối trên hộp thật (VI.E) và ô giữ chỗ `wiring.png`.

## Vòng 5 (07/11/2026) — đối chiếu với mã sau refactor (worktree `C:\sl-wt\refactor`, nhánh `refactor/big`, `rf-p1`)

Mã đối chiếu: HEAD `9bd04b9` (sau B0/H1 và P1). Các phase P2 trở đi (SQL, Java, UI) **chưa chạy**, nên số dòng, số file và số test
sẽ còn đổi; khi các phase đó xong cần đối chiếu lại. Số mới lấy từ `code-stats-2.log` (lệnh và đầu ra đầy đủ) và
`docs/handoff/refactor-P1.md` của worktree (TestNG 66/66, Skips 0, DB dựng từ script; Newman 221 request, 472 assertion, 0 lỗi).
Không chạy lại TestNG/Newman trong vòng này.

| Mục | Sửa | Căn cứ |
|---|---|---|
| Abstract, VI.D, Conclusion | 56 → **66** test, mô tả thêm: kiểm tra chuỗi audit trên log lớn, link xác nhận thẻ, thông điệp hộp; "none skipped, on a database built from the SQL scripts" | `code-stats-2.log` (66 `@Test`: thêm `AuditFloodDatabaseIntegrationTest` 6, `CardMailTest` 4), handoff P1 |
| VI.D Newman | Thêm lần chạy sau khi có xác nhận thẻ qua email: 221/472, 0 lỗi; collection chưa có bước `CONFIRM_EMAIL`/`WRONG_PLACE` | handoff P1 |
| III.B | Bản đồ: Leaflet, hoặc Mapbox GL khi có token | `MapboxConfig.java`, `lockerMap.jsp` |
| III.D | `/api/device/auth` trả thêm `CONFIRM_EMAIL`; đoạn mới về xác nhận quét thẻ qua email (lệnh chờ 5 phút, chỉ lưu SHA-256 của link, POST trên `/c/{token}`, GET không đổi gì, chủ thẻ cũng xác nhận được trên bản đồ, tài khoản demo bỏ qua) và `WRONG_PLACE` | `DeviceAuthApi.java` (Javadoc), `CardMail.java`, `sql/03_v2_v3.sql` dòng 1682–1712, `CardConfirmController.java` |
| IV.D | Gạch đầu dòng mới "Card at the wrong box": ghi trên lượt đặt, bản đồ cảnh báo, email tối đa 1 lần/10 phút, không tính là đoán sai | `CardMail.WRONG_PLACE_GAP_MS`, `CLAUDE.md` |
| IV.E | Luồng nền kiểm tra chuỗi audit mỗi 60 s, đọc theo luồng; dashboard chỉ đọc kết quả | `LockerMonitor.AUDIT_INTERVAL_SEC`, `AuditVerifier.java` (H1) |
| V | 10 600 dòng/85 file/20 JSP → **11 400 dòng (11 384)/88 file/21 JSP** (thêm `cardConfirm.jsp`); "works offline" → không tải script từ CDN (Leaflet và Mapbox GL đều đóng gói), tile cần Internet, lỗi tile thì vẽ ghim trên lưới | `code-stats-2.log` |
| V giá | Thêm "Tự chọn": 1–23 giờ theo giá giờ, trần bằng gói ngày; 1–7 ngày theo gói ngày (90% cho 2–6 ngày, 80% cho 7 ngày); mọi cách mở cùng giá, thẻ đầu tiên cọc 10 000 đ thu ở hộp | `fn_CustomPrice`, `AppConfig` (`sql/03_v2_v3.sql` dòng 821–833), `util/Pricing.java` |
| V Monitoring | Thêm luồng kiểm audit 60 s và email nhắc hạn 15 phút trước (khi có cấu hình mail) | `LockerMonitor.java` |
| V Security | Đăng nhập sai chỉ ghi tên tài khoản có thật (H1) | `LoginController.java`, handoff P1 |

Đã kiểm và **không** cần sửa: thứ tự và ngưỡng luật (50 g, 300 s, 30 phút, 60 s), ngưỡng ML 0.80, khóa 5 lần/5 phút/120 s và bộ đếm
riêng của trang điện thoại, OFFLINE 90 s/job 15 s, snapshot 2 s, heartbeat 3 s, giữ chỗ 15 phút, hủy 5 phút 100%/50%, 3 lần không đến
trong 7 ngày, gia hạn tối đa 3 lần, phụ phí 150%, chuyển nhân viên sau 48 giờ, bảng giá và hệ số cỡ, kích thước S/M/L, chân ESP32,
firmware vẫn không gọi `/api/locker/batch` và vẫn `setInsecure()`.

Chưa làm: ảnh chụp màn hình (`images/*.png`, 30/10) chưa chụp lại; nếu bản đồ đang chạy Mapbox thì `map-visitor.png`/`map-area.png`
có thể khác giao diện hiện tại. Kiểm cú pháp: ngoặc `{}` 456/456, 30 cặp begin/end, mọi `\ref` có `\label`, chỉ ASCII.

## Vòng 6 (07/11/2026) — số đo đầu-cuối trên hộp thật

| Mục | Sửa | Căn cứ |
|---|---|---|
| VI.E | Xóa `\TODO` đo đầu-cuối; thay bằng: 20 lần mở bằng trang điện thoại, trung bình 1,67 s từ lúc gửi PIN tới khi cửa mở, phần lớn là chờ heartbeat kế tiếp (3 s, trung bình 1,5 s) | Tác giả đo và báo trong chat; **chưa có file log** trong `evidence/` |
| VII Future work | "measuring the end-to-end response time on the box" → chỉ còn bàn phím, thẻ, vân tay | |

Còn một ô giữ chỗ đỏ: `wiring.png` (macro `\img`) ở Hình phần cứng.

## Vòng 7 (07/11/2026) — bản hoàn thiện

- Bỏ macro `\TODO` và `\img` (ô giữ chỗ đỏ), gói `xcolor` (chỉ macro TODO dùng) và `\BibTeX` thừa của template IEEE.
- Mọi hình dùng `\includegraphics{images/...}`; biên dịch từ thư mục `docs/paper`. Cả 9 ảnh đều có trong `images/`.
- Hình phần cứng chỉ còn ảnh hộp thật (`hardware-box.png`): bỏ ô `wiring.png` chưa có ảnh, chú thích "The assembled locker box prototype."
- Xóa mọi comment `%` (dòng phân cách mục, ghi chú trong TikZ). Nội dung bài không đổi.
- Kiểm cú pháp: ngoặc `{}` 406/406, 30 cặp begin/end, mọi `\ref` có `\label`, chỉ ASCII, không còn `TODO`.
