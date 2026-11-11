# Duyệt bài báo `docs/paper/smartlocker.tex` (agent "reviewer", 30/10/2026)

Phạm vi: bản `smartlocker.tex` sau khi agent "editor" sửa (`CHANGES.md`), đối chiếu với các log trong `docs/paper/evidence/`,
mã nguồn, SQL, firmware và 9 ảnh trong `docs/paper/images/`. `docs/paper/` chưa được git theo dõi nên `git diff` không có gì;
tôi đọc toàn bộ file (655 dòng). Không sửa file nào ngoài file này. Bỏ qua TODO newman theo yêu cầu (chỉ xét số "17 kịch bản").

Số dòng dưới đây là số dòng trong `smartlocker.tex`.

---

## A. Mức CAO (phải sửa trước khi nộp)

### A1. "17 Postman scenarios" sai: collection có 18 kịch bản
- **Vị trí:** VI.D Functional Testing, dòng 546–547.
- **Vấn đề:** `docs/postman/SmartLocker-v2.postman_collection.json` có thư mục `Scenarios` gồm kịch bản 1–10 **và 18**
  ("Mở nhiều lần: CHOOSE, OPEN (ACCESS) hai lần, CHECKOUT", 21 request), thư mục `v3` gồm 11–17. Tổng 18 kịch bản,
  cộng 9 request lẻ (Heartbeat 1, Auth 3, Enroll 2, Kiosk 2, Batch 1); tổng 211 request. Danh sách nội dung trong bài
  cũng thiếu: thẻ đã báo mất (8), đặt bằng PIN nhưng quẹt thẻ (9), sai API key/body (10), mật mã của lượt đã kết thúc
  hoặc của hộp khác (7), mở nhiều lần (18).
- **Bằng chứng:** đếm bằng script đọc JSON của collection; `docs/postman/README.md` mục "Kịch bản 18".
- **Sửa:** "18 scenarios (…, lost card, wrong credential type, a PIN of a finished booking or another box, a wrong API key,
  repeated opens during one rental, …)". Khi điền kết quả newman, dùng số request của lần chạy mới (211 nếu không đổi).

### A2. Chú thích ảnh `kiosk-phone.png` mô tả điều không có trong ảnh
- **Vị trí:** chú thích Hình `fig:ui2`, dòng 431–432: "rejecting a code that is not six digits".
- **Vấn đề:** ảnh chỉ có form trống (ô "Mật mã 6 số", nút "Mở tủ" và đoạn hướng dẫn); **không có** thông báo lỗi nào.
  `screens.log` (20:30) ghi có bấm "Mở tủ" với mã trống và thấy "Mật mã gồm đúng 6 chữ số.", nhưng ảnh lưu không chứa nó.
- **Sửa:** hoặc chụp lại khi thông báo lỗi đang hiện, hoặc đổi chú thích: "the phone unlock page of box LOCKER-06 at phone
  width: a six-digit PIN field; the note below it explains the 5-try, 2-minute lock of the page".

### A3. Firmware hiện tại không gửi phiên truy cập (`/api/locker/batch`) — bài viết như thể hộp có gửi
- **Vị trí:** III.D Device Protocol dòng 211–221 ("The box uses three endpoints"), IV.A dòng 266 ("Every opening of a slot
  produces an access session reported by the box"), VI.D dòng 578 ("with a 2 s pause before the session, **as on a real box**"),
  VI.F dòng 619–621.
- **Vấn đề:** `grep -rn "locker/batch" firmware/` = 0 kết quả; `SmartLocker_Online.ino` chỉ gọi `/api/health` và
  `/api/device/auth`. Như vậy mọi phiên telemetry trong bài đều do `ScenarioSender`/seed tạo ra; câu "as on a real box"
  không có căn cứ đo.
- **Sửa:** III.D: "The device protocol has three endpoints; the current firmware uses the first two, and the batch upload is
  exercised by the device simulator." IV.A: "…an access session, uploaded through `/api/locker/batch`". VI.D: bỏ "as on a
  real box". VI.F hạn chế thứ nhất: thêm "the firmware does not upload sessions yet".

### A4. "Binary … which is what the risk score uses" không đúng với mã
- **Vị trí:** VI.A dòng 450–451.
- **Vấn đề:** `test/tool/ModelTrainer.main` lưu mô hình **6 lớp** có weighted F1 cao nhất (IBk, k=5) vào
  `src/java/ml/locker_model.bin`; `RiskScorer` tính `risk = 1 − P(NORMAL)` từ mô hình 6 lớp đó (`RiskScorer.java` dòng 17,
  33). Mô hình nhị phân trong bảng là mô hình huấn luyện riêng trong harness, không được triển khai. Bài cũng không nói
  mô hình nào đang chạy.
- **Sửa:** "…and a binary problem (NORMAL vs. ABNORMAL), which measures the NORMAL-versus-rest decision that the risk score
  makes. The deployed model is the six-class winner (IBk), and the risk is one minus its probability of NORMAL."

### A5. Độ trung thực của kết quả kịch bản phát hiện (Abstract, VI.D, Conclusion)
- **Vị trí:** Abstract dòng 52–53; Bảng `tab:scen` dòng 570; đoạn dòng 575–579; Conclusion dòng 644.
- **Vấn đề:**
  1. "All six scenarios ended as expected" trong khi hàng `sensor` có cột Expected "ticket" và Observed "no new ticket" —
     tự mâu thuẫn trong cùng một bảng.
  2. `checkin`: kịch bản của bộ giả lập **không** cho kết quả mong đợi (lượt 159 vẫn `RESERVED`, `scenarios.log` dòng 277–278);
     kết quả trong bảng đến từ một request PIN thêm bằng tay. Bài có nói, nhưng Abstract "six detection scenarios replayed
     with a device simulator" ngụ ý cả sáu chạy nguyên trạng.
  3. `remote` lần 1: hai phiên đều thành `SUSPECTED_SPOOF`. Bài quy cho "the test set-up rather than the detector", nhưng
     luật yêu cầu `s.measured_at BETWEEN c.created_at AND created_at + 30 min` không có dung sai
     (`src/java/dao/SessionContextDao.java` dòng 58): một hộp có đồng hồ chậm hơn máy chủ dưới 1 s cũng sẽ bị báo giả mạo.
     Đây là một tính chất của bộ phát hiện, nên nói ra (và đưa vào Limitations hoặc future work: dung sai vài giây/NTP).
- **Sửa (gợi ý câu chữ):**
  - Bảng, hàng sensor, cột Expected: "SENSOR\_FAULT, slot out of service, a ticket unless the box already has an open one".
  - Đoạn dưới bảng: "All six scenarios produced the expected label. Two needed a change: …(remote)… The comparison has no
    tolerance, so a device clock that lags the server would cause the same false alarm; a small tolerance is future work.
    …(checkin)…"
  - Abstract: "…six detection scenarios replayed through the device API produced the expected labels (two after adjusting the
    simulator)…". Conclusion dòng 644: giữ "produced the expected labels", thêm "(two after adjusting the simulator)".

---

## B. Mức TRUNG BÌNH

### B1. Hàng "Late fee per hour (150%)" không bằng 150% của hàng "Hourly rate" ngay trên
- **Vị trí:** Bảng `tab:price` dòng 390–391.
- **Vấn đề:** số đúng với SQL (`fn_HourRate`, `fn_LateFee` trong `sql/03_v2_v3.sql` dòng 973–995: phụ phí tính từ giá giờ
  **chưa làm tròn** rồi làm tròn một lần), nhưng người đọc thấy M: 3 300 × 1,5 = 4 950 ≠ 4 900; L: 4 300 × 1,5 = 6 450 ≠ 6 400.
- **Sửa:** thêm một câu/chú thích: "Hourly rate and late fee are derived from the 2-hour plan price and rounded up to 100 VND
  once (late fee = 150% of the unrounded hourly rate)". Các số còn lại trong bảng đã khớp (xem mục E).

### B2. "one-time PIN" (Abstract dòng 44) sai
- **Vấn đề:** PIN gắn với lượt đặt và được dùng nhiều lần trong một lượt thuê (ACCESS, "A: open / B: return", kịch bản 18;
  chính bài mô tả ở dòng 230–231).
- **Sửa:** "a per-booking PIN".

### B3. Ma trận nhầm lẫn của Random Forest, nhưng lời bình gắn với IBk
- **Vị trí:** Abstract dòng 50–52; Bảng `tab:cm`; Discussion dòng 523–529.
- **Vấn đề:** Abstract nói mô hình tốt nhất là IBk rồi "the errors show that wrong-user access cannot be told from normal
  access" — nhưng ma trận trong bài là của RF. IBk (mô hình được triển khai) có WU 73/7, NO 3/77 **và 1 ITEM\_LEFT → SPOOF**
  (`ml.log` dòng 35–51), nên "All errors are between WRONG\_USER and NORMAL" chỉ đúng với RF. IBk nhận đúng 73/80 phiên
  WRONG\_USER nên "cannot be told" là nói quá.
- **Sửa:** hoặc thay bảng bằng ma trận của IBk (mô hình chạy thật), hoặc giữ RF nhưng ghi rõ "for Random Forest", và đổi
  Abstract thành "…most errors are between wrong-user and normal access, which telemetry alone cannot reliably separate…".

### B4. Câu Naive Bayes vẫn gợi một khẳng định chưa kiểm
- **Vị trí:** dòng 526–528: "labels 80 of the 400 abnormal sessions as NORMAL, as many as there are wrong-user sessions
  (we did not check which classes these 80 sessions come from)".
- **Vấn đề:** "as many as there are wrong-user sessions" dẫn người đọc tới kết luận chưa được đo; trong bài báo khoa học câu
  ngoặc "we did not check" đọc như thiếu sót.
- **Sửa:** chạy lại harness in ma trận 6 lớp × dự đoán nhị phân (rẻ), hoặc bỏ cả vế "as many as… (we did not check…)".

### B5. Bỏ sót một lần đo OFFLINE
- **Vị trí:** dòng 611–612.
- **Vấn đề:** `scenarios.log` dòng 364–369 có 6 cảnh báo cũ: 98, 98, 97, **906**, 110, 98 s. Bài nêu "four … 97–98 s" và
  110 s, bỏ 906 s (Tomcat không chạy). Lý do loại là hợp lý nhưng phải nói. Ngoài ra `last_seen_utc` trong evidence chỉ có
  giây nguyên (sai số +1 s).
- **Sửa:** "…took 97–98 s (one took 110 s because the application was reloaded during the wait, and one was excluded because
  the server was stopped)". Conclusion "within 90–105 s" → "within 90–105 s while the server runs".

### B6. Hạn chế thứ ba mô tả sai các ngăn khác; các hộp demo không được công bố
- **Vị trí:** VI.F dòng 624–625; chú thích Hình `fig:ui1`, `fig:ui2`.
- **Vấn đề:** "the other slots are managed logically by the same box" chỉ đúng với 4 ngăn LIB-A do LOCKER-01 quản lý.
  9 thiết bị còn lại (LOCKER-02..10, gồm LOCKER-06 của GYM-A trong các hình) là thiết bị demo, heartbeat do máy chủ giả lập
  (`src/java/service/LockerMonitor.java` dòng 124–128, `"demo":true`). Bảng điều khiển trong `dashboard.png` hiện "10/10 thiết bị
  trực tuyến" là nhờ giả lập đó.
- **Sửa:** "Only one slot has a physical lock; the box manages a few more slots logically, and the other banks shown in the
  figures belong to demo devices whose heartbeat is simulated by the server."

### B7. "the public set" gây hiểu nhầm
- **Vị trí:** dòng 623 ("train on the public set").
- **Vấn đề:** tập 480 phiên là dữ liệu tổng hợp trong bảng `PublicSession` (`sql/02_data_v1.sql` dòng 713–718), không phải
  tập dữ liệu công khai; bài lại vừa nhắc TON\_IoT ở Related Work.
- **Sửa:** "train on the synthetic set, test on about 100 labelled device sessions (`TransferCheck`)".

### B8. Bước 6 "appends an audit entry" không đúng với mọi phiên
- **Vị trí:** IV.C dòng 339.
- **Vấn đề:** `AlertService.evaluate` chỉ ghi audit khi có cảnh báo (`CREATE ALERT`) hoặc STAFF\_OPEN (`COMMAND_DONE`);
  phiên NORMAL không có dòng audit.
- **Sửa:** gộp vào bước 4–5: "…marks the command as done and logs it in the audit chain" / "…stores the alert and logs it".

---

## C. Mức THẤP

- **C1. "6–31 ms on average"** (Abstract dòng 53, Conclusion dòng 645): số đúng (mean 5,9 / 17,0 / 31,1 ms, `latency.log`
  dòng 107–110) nhưng dễ hiểu thành "trung bình chung". Đề xuất: "a mean server-side processing time of 6–31 ms per endpoint
  on localhost (95th percentile at most 96 ms)". Abstract hiện chỉ nói "on the server side", nên thêm "localhost".
- **C2. JDK:** dòng 453–455 ngụ ý mọi phép đo dùng JDK 1.8.0\_202; Tomcat chạy trên JDK 1.8.0\_171 (`latency.log` dòng 4,
  README evidence). Thêm "(Tomcat on JDK 1.8.0\_171)".
- **C3.** Dòng 448–449 "IBk with k = 5 … all with default parameters" → "otherwise default parameters".
- **C4. Lockout** (dòng 346–348): đúng 5 lần sai → khóa 120 s, hai bộ đếm BOX/PHONE (`sql/03_v2_v3.sql` dòng 360–411), nhưng
  điều kiện là 5 lần sai **trong 5 phút**; thêm "within 5 minutes".
- **C5. Luật 2** (bảng rules): lệnh hợp lệ còn phải được tạo trước phiên và trong 30 phút trước đó (`SessionContextDao` dòng 58);
  có thể ghi "a valid, unused command issued shortly before".
- **C6. Hình `fig:ui1` (trên phải):** ảnh hiển thị tên "Nhà văn hóa Sinh viên", không có chữ "GYM" ở tiêu đề; ghi
  "area GYM (Nhà văn hóa Sinh viên)". `alerts.png` hiện số rủi ro thô `0.09999999999999998` và cột thiết bị "Thiết bị #5"
  (lỗi giao diện đã ghi trong `screens.log`); nên sửa giao diện rồi chụp lại, hoặc cắt ảnh.
- **C7. Tiếng Anh/văn phong:** dòng 70 "What it does:" quá khẩu ngữ → "Its main functions are:". Abstract dòng 52–53
  "passed 51 of 52 automated tests …, six detection scenarios …, and answered …" ghép ba vế không cùng động từ; tách câu.
  Câu đầu Abstract (dòng 41–43) dài, nên tách làm hai.
- **C8.** `rfidiot2023locker` (doi 10.1063/5.0101139): không kiểm trực tuyến được trong lượt này; nhóm tác giả nên tự mở DOI
  để xác nhận tên bài, tác giả, năm.
- **C9. IBk 15–17 µs** (dòng 499): khớp 3 lần chạy 6 lớp (17,16 / 16,34 / 14,94 µs, làm tròn). README evidence ghi 14,9–18,7 µs
  vì gộp lần chạy nhị phân; bài đã ghi đúng là "six-class setting". Không cần sửa.

---

## D. Mục tiêu rút gọn (bỏ công thức/ký hiệu, tập trung vấn đề và chức năng)

Đạt phần lớn: không còn phương trình, `\rho`, `x(s)`, `C(s)`, `Eq.~`, `algorithmic`. Toán còn lại chỉ là kích thước
($20\times20\times20$), $k=5$, $20\times480$, $\mu$s — hợp lý. Đề xuất thêm:
- **D1.** Hình `fig:f1` (biểu đồ cột) lặp lại đúng cột F1 của Bảng `tab:ml` → bỏ hình, bỏ luôn `pgfplots` (tiết kiệm ~18 dòng).
- **D2.** Danh sách 6 bước ở IV.C (dòng 330–340) lặp lại đoạn văn ngay trên (bước 2–3 = câu "If no rule matched…"). Gộp thành
  2–3 câu: rules → risk (trừ SENSOR\_FAULT/STAFF\_OPEN) → ML\_ANOMALY nếu ≥ 0,80 → lưu cảnh báo/phiếu → audit.
- **D3.** Cột "ESP32 pins" của Bảng `tab:hw` là chi tiết lắp ráp, không phục vụ thông điệp chính; có thể bỏ (sơ đồ nối dây
  `wiring.png` sẽ chứa thông tin này). Các chân trong bảng đều khớp firmware (`SmartLocker_Online.ino` dòng 53–76).
- **D4.** Không thấy nội dung cốt lõi bị cắt nhầm: vấn đề, chức năng, kiến trúc, luật, kết quả ML, kiểm thử, hạn chế đều còn.
  Lockout/offline/escalation được nhắc ở IV.D, VI.E và Conclusion — chấp nhận được.

---

## E. Truy vết số liệu (đã kiểm, khớp)

| Số trong bài | Nguồn |
|---|---|
| 480 phiên, 6 lớp × 80 | `ml.log` dòng 11 |
| Bảng ML 6 lớp và nhị phân (RF, J48, NB, IBk) | `ml.log` dòng 16, 32–34, 65–73 (thứ tự {NORMAL, ABNORMAL}) |
| Hình F1: 0.9478 / 0.8558 / 0.7775 / 0.9771; 0.9387 / 0.8476 / 0.8519 / 0.9754 | `ml.log` |
| Ma trận RF (80, 63/17, 8/72), F1 0.834 / 0.852 | `ml.log` dòng 17–30 |
| NB nhị phân 80 ABNORMAL → NORMAL, 0 NORMAL sai | `ml.log` dòng 68–71 |
| RF train 36–38 ms (35,8 / 37,7 / 37,2), suy luận 12–15,5 µs; IBk < 1 ms, 15–17 µs | `ml.log` dòng 16, 95, 174, 34, 113, 192 |
| Seed 42, 10-fold, IBk(5), trung vị 11 lần, 20×N dự đoán, 3 lần chạy | `ml.log` dòng 4–6; `ModelTrainer.java` dòng 48–58 |
| i5-11400H 2,7 GHz 6 nhân, 16 GB, Windows 11 64-bit, JDK 1.8.0\_202, Weka 3.8.6, Tomcat 9.0.113, SQL Server 2022 | `machine.log`, `ml.log` dòng 12 |
| 52 test / 51 / 0 / 1 skip; RuleEngine 13 | `testng.log` dòng 10, 34 |
| ~10 600 dòng, 85 file, 20 JSP | `code-stats.log` dòng 14, 18 |
| Heartbeat 3 s | `HealthApi.INTERVAL_SEC = 3`; firmware dòng 111 |
| Snapshot 2 s, job 15 s, offline 90 s | `LockerMonitor.java` dòng 42, 45, 129 |
| Ngưỡng ML 0.80 | `AlertService.java` dòng 19 |
| 50 g (ITEM\_LEFT, SPOOF), 300 s đồng hồ | `RuleEngine.java` dòng 12–14 |
| Khoảng cảm biến: cửa 0–3600 s, khối lượng −200…20 000 g, gửi 0–10 080 phút | `sql/01_schema.sql` dòng 501 |
| Giữ chỗ 15 phút, hủy 5 phút 100% / 50%, không đến 0%, phí trễ 150%, 48 giờ | `AppConfig` trong `sql/03_v2_v3.sql` dòng 818–826 |
| 3 lần không đến trong 7 ngày | `sql/03_v2_v3.sql` dòng 1072–1074 |
| Gia hạn tối đa 3 lần | `sql/03_v2_v3.sql` dòng 1289 |
| Khóa 5 lần sai / 120 s, bộ đếm riêng cho trang điện thoại | `sql/03_v2_v3.sql` dòng 360–411; `latency.log` dòng 115–123 |
| Hệ số cỡ 100 / 130 / 169%, làm tròn lên 100 đ | `SlotSize` dòng 846–851, `fn_SizePrice` dòng 960–964 |
| Bảng giá: 2 giờ 5 000/6 500/8 500; 4 giờ 9 000/11 700/15 300; trọn ngày 25 000/32 500/42 300; giờ 2 500/3 300/4 300; phí trễ 3 800/4 900/6 400 | gói `sql/01_schema.sql` dòng 494–497; công thức `sql/03_v2_v3.sql` dòng 960–995; tính lại tay khớp; `PricingTest`; ảnh `booking-confirm.png` (M 6 500 đ, phí trễ 4 900 đ) |
| Kích thước S/M/L 20/40/60 cm | `SlotSize` |
| SHA-256 khóa thiết bị và chuỗi audit, khóa UPDLOCK đuôi chuỗi, các trường được băm | `sql/01_schema.sql` dòng 335–356, 423 |
| Chân ESP32 (Bảng I) | `firmware/SmartLocker_Online/SmartLocker_Online.ino` dòng 53–76 |
| Kịch bản: 6 heartbeat cách 10 s; 104,6 s; lệnh 20 DONE, phát lại → SPOOF; spoof; lostcard + blocked list; checkin; −5000 g, MAINTENANCE, không phiếu mới | `scenarios.log` dòng 82–84, 141–199, 277–278, 316–358 |
| OFFLINE cũ 97–98 s, 110 s (reload) | `scenarios.log` dòng 364–373 (thiếu 906 s, xem B5) |
| Bảng thời gian phản hồi (mean/median/p95/min/max) | `latency.log` dòng 107–110 |
| Lần sai 1–4 còn 4→1, lần 5 khóa 120 s, `LOCKED_OUT`, nhận lại sau 125,5 s | `latency.log` dòng 115–140 |
| Không CSRF, SameSite=Lax, chỉ Wi-Fi, HTTP 8080, Cloudflare tunnel, `setInsecure` | `code-stats.log`, README evidence |
| Hình UI: 5 khu vực; GYM-A 3 ngăn khóa quá hạn + 1 cảnh báo; A03 GYM-A gói 2 giờ PIN; PIN + 2 đếm ngược; cảnh báo #36, A05, 52 giờ | ảnh tương ứng + `screens.log` (riêng `kiosk-phone.png` lệch, xem A2) |

Số không có nguồn: không tìm thấy số nào bịa. Các lệch nằm ở cách diễn đạt (A1, A4, B1, B3, B5, C1).

---

## F. LaTeX (không có trình biên dịch; kiểm bằng script)

- Ngoặc `{}` cân bằng 466/466; mọi `\begin`/`\end` khớp; mọi `\ref` có `\label` và ngược lại; 16 khóa `\cite` đều có trong
  `references.bib`, không khóa thừa.
- Không còn `\STATE`, `algorithmic`, `Eq.~`, `\eqref`; `_ # %` ngoài toán/`\texttt` đều đã thoát (chỉ `#1/#2` trong định nghĩa
  macro `\img`, hợp lệ).
- `tikz` vẫn cần (Hình 1 kiến trúc, Hình trạng thái); `pgfplots` chỉ dùng cho `fig:f1` (bỏ nếu theo D1); `float` cần cho `[H]`;
  `amsmath` gần như không dùng nhưng vô hại.
- `\TODO` còn đúng 3 chỗ, đều có chủ đích: newman (dòng 548), đo đầu-cuối trên hộp thật (dòng 614), và ô giữ chỗ
  `wiring.png` do macro `\img` vẽ (dòng 204).
- Lưu ý nhỏ: `flushend` không có tác dụng ở chế độ `onecolumn`; có thể bỏ.

---

## Kết luận: **NEEDS FIXES**

Các con số đều truy được về log, mã hoặc SQL, và LaTeX sạch. Cần sửa trước khi nộp: A1 (18 chứ không phải 17 kịch bản),
A2 (chú thích ảnh kiosk), A3 (firmware không gửi phiên), A4 (mô hình nhị phân không phải mô hình chấm điểm rủi ro),
A5 (diễn đạt kết quả kịch bản + điểm yếu dung sai thời gian của luật lệnh từ xa). Nhóm B nên sửa cùng lượt;
C và D là tùy chọn.

---

# Vòng 2 (agent "reviewer-2", 30/10/2026)

Phạm vi: `smartlocker.tex` sau lượt sửa "Vòng 2" của `CHANGES.md` (655 dòng, đọc toàn bộ), đối chiếu lại với log, mã,
SQL, firmware, collection Postman và ảnh. Không sửa file nào ngoài file này. Số dòng là số dòng trong `smartlocker.tex`.

## 1. Kiểm tra các mục vòng 1

| Mục | Kết quả | Bằng chứng |
|---|---|---|
| A1 | Đạt | Collection: thư mục Scenarios (1–10, 18) + v3 (11–17) = 18 kịch bản; 211 mục request trong collection, newman chạy 221 request. Danh sách ở dòng 533–536 khớp nội dung kịch bản. |
| Newman | Đạt | `newman.log` dòng 1305–1315, 1367: requests 221 (0 lỗi), assertions 472 (1 lỗi), 2m 25.3s; lỗi là `POST /api/locker/batch` 500 ở kịch bản 2 (trang điện thoại), dòng 389, 1329–1333. Câu giải thích (hai dãy cùng có A01) khớp README evidence. |
| A2 | Đạt | Đã xem `kiosk-phone.png`: tiêu đề "Mở tủ LOCKER-06", ô "Mật mã 6 số", ghi chú "Nhập sai 5 lần, trang này tạm khóa nhập 2 phút". Chú thích dòng 430–432 đúng. |
| A3 | Đạt | `SmartLocker_Online.ino` chỉ gọi `/health`, `/device/auth`, `/device/enroll/start`, `/device/enroll/finish` (dòng 302, 509, 531, 544); `grep locker/batch firmware` = 0. Dòng 211–223, 269, 541–542, 612–614 đúng. |
| A4 | **Sai ở chỗ mới** — xem R2-A1 | `locker_model.bin` đúng là RandomForest, nhưng là mô hình **hai lớp** {NORMAL, FORCED_OPEN}, không phải sáu lớp. |
| A5 | Đạt | Bảng hàng sensor (dòng 559) hết mâu thuẫn; đoạn dòng 564–570 đúng với `scenarios.log`; luật `s.measured_at BETWEEN c.created_at AND DATEADD(MINUTE, 30, c.created_at)` ở `SessionContextDao.java` dòng 58, không dung sai — câu "a device clock that lags the server would cause the same false alarm" đúng. |
| B1 | Đạt | `fn_HourRate` (dòng 974) và `fn_OverdueRate` (dòng 987) trong `sql/03_v2_v3.sql`: phí trễ = CEILING(giá cỡ × 60 × 150 / (phút × 10000)) × 100, tức 150% giá giờ chưa làm tròn, làm tròn một lần; M: 6 500 → 4 875 → 4 900. Ghi chú: hàm lấy gói **ngắn nhất đang bán** (hiện là 2 giờ), bài ghi "2-hour plan" — chấp nhận được. |
| B2 | Đạt | "per-booking PIN" (dòng 41). |
| B3 | Đạt về số, sai ở tiêu đề | `ml.log` dòng 35–51: IBk WU 73/7, NO 3/77, IL→SS 1 = 11 lỗi, 10 giữa WU/NO — đúng với dòng 510–512. Tiêu đề Bảng V "Currently Deployed Model" sai (R2-A1). |
| B4 | Đạt | Dòng 513–514 chỉ còn số đo (`ml.log` dòng 68–71). |
| B5 | Đạt | `scenarios.log` dòng 364–371: 98, 98, 97, 906, 110, 98, 105 (= 104,6 s); bài nêu bốn lần 97–98 s, 110 s (reload), 906 s bị loại, sai số 1 s. |
| B6 | Đạt | `LockerMonitor.java` dòng 124–128: heartbeat giả lập chỉ cho thiết bị `"demo":true`. |
| B7, B8 | Đạt | "synthetic set" (dòng 616); audit chỉ cho `COMMAND_DONE` và `CREATE ALERT` (`AlertService.java` dòng 39, 47) — dòng 333–336 đúng. |
| C1–C5, C7 | Đạt | `latency.log`; JDK 1.8.0_171 (dòng 459); "otherwise with default parameters"; "within 5 minutes"; luật 2 "issued at most 30 min before". |
| C6 | Đạt | Chú thích dùng lệnh dấu `\`a`, `\u{a}`, `\'o`, `\^e` (an toàn với mã hóa OT1 mặc định). |
| C8 | Còn mở | DOI `10.1063/5.0101139` vẫn cần nhóm tác giả tự xác nhận. |
| D1 | Đạt | Không còn `pgfplots`, `axis`, `addplot`, `fig:f1`. |
| D2 | Đạt | Danh sách 6 bước đã gộp thành đoạn văn (dòng 329–336). |
| D3 | Giữ cột chân (quyết định của orchestrator) | — |
| F | Đạt | Không còn `flushend`. |

## 2. Phát hiện mới

### R2-A1 (CAO). Mô hình đang triển khai là Random Forest **hai lớp (NORMAL, FORCED_OPEN)**, không phải sáu lớp
- **Vị trí:** dòng 452–455 ("The deployed risk model is a six-class classifier … the model file currently shipped … is a
  Random Forest from an earlier training run"); tiêu đề Bảng `tab:cm` dòng 490 ("Currently Deployed Model").
- **Bằng chứng:** `src/java/ml/locker_header.arff` (và bản trong `build/web/WEB-INF/classes/ml/`, cùng md5
  `5377c254…` cho `locker_model.bin`): `@attribute label {NORMAL,FORCED_OPEN}`. Chuỗi trong `locker_model.bin`: chỉ có nhãn
  `NORMAL` và `FORCED_OPEN`, lớp `weka.classifiers.trees.RandomForest`. `RiskScorer` lấy chỉ số NORMAL từ header nên vẫn chạy:
  risk = P(FORCED_OPEN). Ma trận trong Bảng V là của RF sáu lớp trong 10-fold CV trên dữ liệu hiện tại (`ml.log`), **không**
  phải của file đang chạy.
- **Sửa:** dòng 452–455: "The training tool deploys the six-class model with the best weighted F1 (IBk on the current
  data), and the risk is one minus its probability of NORMAL. The model file currently shipped with the prototype is
  older: a two-class Random Forest (NORMAL vs.\ FORCED\_OPEN) from an earlier data set; retraining replaces it." Tiêu đề
  Bảng V: bỏ ", Currently Deployed Model" (ví dụ "Confusion Matrix and Per-Class F1 of Random Forest (Six Classes)").
  Thêm một vế vào Limitations thứ hai: "the shipped model file predates the six-class data set". (Hoặc chạy lại
  `tool.ModelTrainer` để file đúng với bài — nhưng đó là sửa mã, ngoài phạm vi bài.)

### R2-B1 (TRUNG BÌNH). Lớp WRONG_USER và NORMAL được sinh bằng **cùng một công thức** — bài nên nói thẳng
- **Vị trí:** dòng 443–445 (mô tả dữ liệu), 512–516 (Discussion), Abstract dòng 48–49, Intro dòng 80–81 ("a comparison of
  four classifiers that also shows what telemetry alone cannot detect"), Conclusion dòng 640–642 ("this confirms …").
- **Bằng chứng:** `sql/02_data_v1.sql` dòng 718–733: với `n % 6 = 0` (NORMAL) và `n % 6 = 2` (WRONG_USER), cả năm đặc trưng
  dùng chung biểu thức (cửa `3 + n%7`, khối lượng `-10 - n%80`, mở 1 lần, thẻ hợp lệ, gửi `10 + n%90`). Hai lớp chỉ khác
  nhau ở số dư của chỉ số dòng, nên việc RF/IBk tách được 63–73/80 phiên là hiện vật của phép chia dư, còn việc "telemetry
  không tách được" là đúng **theo cách sinh dữ liệu**, không phải một phát hiện thực nghiệm.
- **Sửa:** Dữ liệu: thêm "wrong-user sessions are generated with exactly the same formulas as normal ones, since the
  telemetry of a wrong user is that of a normal visit". Discussion dòng 514–516: thay "comes from regularities of the
  synthetic generator" bằng "is an artefact of the generator, which draws both classes from the same formulas". Intro
  và Conclusion: hạ giọng từ "shows/confirms" thành "illustrates" (ví dụ "the classifiers illustrate, on data built so,
  that telemetry alone does not separate wrong-user from normal access"). Không thêm số mới.

### R2-B2 (TRUNG BÌNH). Lặp các câu "trung thực" ở nhiều chỗ — nên gộp
- Thiết bị demo / heartbeat giả lập: chú thích Hình ui1 (dòng 415–416), Hình ui2 (dòng 428–429), Limitations thứ ba (dòng
  618–619). → Giữ ở Limitations và **một** chú thích (ui2, nơi có dashboard "10/10 trực tuyến"); bỏ câu ở ui1.
- Firmware chưa gửi phiên: III.D (dòng 222–223), VI.D (dòng 541), Limitations thứ nhất (dòng 613–614). → Giữ III.D và
  Limitations; ở VI.D đủ "a device simulator".
- Dung sai đồng hồ và lỗi tra ngăn theo mã: VI.D (dòng 537–540, 566–567), Limitations thứ tư, Future work. → Limitations thứ tư
  có thể chỉ trỏ lại ("the two weaknesses found in Section~VI-D") thay vì giải thích lại cơ chế.
- "Response times measured on the server only" bị nhét vào Limitations thứ ba (về khóa vật lý), trong khi VI.E đã nói rõ ở
  dòng 575–577 và có TODO. → Bỏ vế này khỏi hạn chế thứ ba (hoặc đưa thành câu riêng).
- "(two after adjusting the simulator)" ở Abstract và Conclusion: chấp nhận được (một lần mỗi nơi).

### R2-C (THẤP)
- **C1.** Dòng 615 "the cross-validation scores are an upper bound": không chứng minh được là cận trên; dùng "optimistic".
- **C2.** Abstract dòng 46–47 "On 480 labelled (synthetic) telemetry sessions" → "On 480 synthetic, labelled telemetry
  sessions". Abstract dài ~260 từ (IEEE khuyên 150–250); có thể bỏ vế "Lockouts, heartbeat monitoring, … complete the design".
- **C3.** Conclusion không nhắc kết quả kiểm thử tự động (51/52, 471/472) trong khi Abstract có; thêm nửa câu để hai phần khớp.
- **C4.** Dòng 455–456: đoạn "Protocol" ôm cả chuyện triển khai mô hình; sau khi sửa R2-A1, nên chuyển câu về file mô hình
  sang IV.C (Tier 2) hoặc V, để VI.A chỉ mô tả thí nghiệm.
- **C5.** Dòng 603: câu quá dài với ngoặc "(computed from a last-seen time stored to the whole second, …)"; tách thành câu
  riêng.
- **C6.** Danh sách 52 test (dòng 529–531) không nhắc `AuthTextTest` (3 test); không sai vì không liệt kê đủ, bỏ qua được.
- **C7.** `amsmath`, `amssymb`, `amsfonts` gần như không dùng (chỉ `$\backslash$`, `$\times$`, `$\rightarrow$` — đều có
  trong LaTeX gốc); vô hại, có thể bỏ.

## 3. Truy vết số mới của vòng 2 (đã kiểm, khớp)

| Số | Nguồn |
|---|---|
| 18 kịch bản | collection Postman (Scenarios 1–10, 18; v3 11–17) |
| 221 request / 0 lỗi; 472 assertion / 1 lỗi; 2 phút 25 s | `newman.log` dòng 1307, 1313, 1315, 1367 |
| Lỗi batch 500, kịch bản điện thoại, hai dãy cùng A01 | `newman.log` dòng 389, 1329–1333; README evidence |
| IBk 11 lỗi: 7 WU→NO, 3 NO→WU, 1 IL→SS | `ml.log` dòng 35–41 |
| 30 phút (luật 2) | `SessionContextDao.java` dòng 53–58 |
| 4 900 (phí trễ M), 150% giá giờ chưa làm tròn | `sql/03_v2_v3.sql` dòng 973–996 |
| 97–98 s, 110 s, 906 s bị loại, ±1 s | `scenarios.log` dòng 360–371 |
| JDK 1.8.0_171 cho Tomcat | `machine.log`, README evidence |
| p95 ≤ 96 ms, trung bình 6–31 ms | `latency.log` |

Không thấy số nào bịa. Sai sự thật duy nhất là mô tả mô hình đang triển khai (R2-A1).

## 4. LaTeX (không có trình biên dịch; kiểm bằng script)
- Ngoặc `{}` 444/444; mọi `\begin`/`\end` khớp; mọi `\ref` ↔ `\label` (không thừa/thiếu); 16 khóa `\cite` đều có trong
  `references.bib`, không khóa thừa.
- Không còn `pgfplots`, `flushend`, `algorithm`, `\STATE`, `Eq.`, `\eqref`, ký hiệu `\rho`; không có `_`/`#`/`%` chưa thoát
  ngoài toán và `\texttt`; không có ký tự ngoài ASCII (dấu tiếng Việt dùng lệnh dấu).
- TODO: đúng 2 chỗ như yêu cầu — `\TODO` đo đầu-cuối trên hộp thật (dòng 607) và ô giữ chỗ `wiring.png` do macro `\img`
  vẽ (dòng 203; file không có trong `images/`). 8 ảnh còn lại đều có.
- Bảng `tab:rules` (cột p 8.2 cm + 3 cột l) và `tab:scen` (5 + 3 + 6 cm) vừa với khổ onecolumn của IEEEtran (~18 cm) theo
  ước lượng; nên xem lại khi biên dịch.

## Kết luận vòng 2: **NEEDS FIXES**

Hầu hết các mục vòng 1 đã sửa đúng và truy được nguồn. Phải sửa: **R2-A1** (file mô hình đang chạy là RF hai lớp
NORMAL/FORCED_OPEN; câu "six-class" và tiêu đề "Currently Deployed Model" sai). Nên sửa: R2-B1 (nói rõ WRONG_USER và
NORMAL cùng công thức sinh, hạ giọng "shows/confirms") và R2-B2 (gộp các câu lưu ý lặp lại). R2-C tùy chọn.

# Vòng 3 (agent "reviewer-3", 30/10/2026)

Phạm vi: `smartlocker.tex` sau lượt sửa "Vòng 3" của `CHANGES.md` (659 dòng, đọc toàn bộ), đối chiếu với `ml.log`,
`testng.log`, `newman.log`, `latency.log`, `sql/02_data_v1.sql`, `src/java/ml/locker_header.arff`,
`test/tool/ModelTrainer.java`, `src/java/service/RiskScorer.java`. Chỉ sửa file này. Số dòng là số dòng trong `smartlocker.tex`.

## 1. Kiểm tra các mục vòng 2

| Mục | Kết quả | Bằng chứng |
|---|---|---|
| R2-A1 (mô tả) | Đạt | Dòng 329–335: công cụ huấn luyện so bốn mô hình, chọn F1 trọng số cao nhất và huấn luyện lại trên mọi dòng (`ModelTrainer.java` dòng 44–67, `save` ghi `locker_model.bin`); hiện là IBk (0.9771 > RF 0.9478). File đi kèm: `locker_header.arff` có `@attribute label {NORMAL,FORCED_OPEN}` → RF hai lớp; `RiskScorer` lấy chỉ số NORMAL từ header, risk = 1 − P(NORMAL) (dòng 33, 68); ngưỡng 0.80 (`AlertService.ML_THRESHOLD`). Câu "the binary models … are not deployed" (dòng 456–457) đúng. Limitations thứ hai (dòng 623–624) trỏ `sec:tier2`. |
| R2-A1 (Bảng V) | Đạt, từng ô | `ml.log` run 1 dòng 35–50: FO 80; WU 73/·/7; OD 80; IL 79 + 1→SS; SS 80; NO 3/·/77 — khớp dòng 498–503. F1: 1.0000→1.000, 0.9359→0.936, 1.0000→1.000, 0.9937→0.994, 0.9938→0.994, 0.9390→0.939 — đúng. Tiêu đề không còn "Currently Deployed". |
| RF trong Discussion | Đạt | `ml.log` dòng 17–24: WU→NO 17, NO→WU 8, các ô khác nằm trên đường chéo → "all of its errors are between these two classes" đúng. IBk: 11 lỗi = 7 + 3 + 1 (IL→SS) — dòng 511–514 đúng. |
| R2-B1 | Đạt | `sql/02_data_v1.sql` dòng 718–733: với `n % 6 = 0` (NORMAL) và `n % 6 = 2` (WRONG_USER) cả năm đặc trưng đi vào nhánh `ELSE` (cửa `3 + n%7`, khối lượng `-10 - n%80`, mở 1 lần, thẻ hợp lệ, lưu `10 + n%90`) — đúng là cùng công thức. Câu "slightly different values through the row index" cũng đúng: ví dụ `n%90` của NORMAL là bội của 6, của WRONG_USER là 6k+2, nên thời gian lưu hai lớp không bao giờ trùng. Intro/Abstract/Conclusion đã hạ giọng ("illustrates"). |
| R2-B2 | Đạt | Chú thích ui1 không còn câu thiết bị demo (chỉ ui2, dòng 430–431, và Limitations thứ ba); VI.D chỉ "a device simulator"; Limitations thứ tư trỏ `sec:tests`; Limitations thứ ba không còn vế "response times". |
| C1–C5 | Đạt | "optimistic" (dòng 621); Abstract 247 từ (script); Conclusion có 51/52 và 471/472 (dòng 645–646); câu file mô hình đã sang IV.C; câu "These four delays …" tách riêng (dòng 608). |
| C6–C8 | Theo quyết định cũ | Không xét lại. |

## 2. Nhất quán toàn bài và nguồn số

| Số | Abstract | Kết quả | Kết luận | Nguồn |
|---|---|---|---|---|
| 480 phiên, F1 IBk 0.977, RF 0.948 | có | Bảng IV | có | `ml.log` dòng 13, 16, 34 |
| Bảng IV (6 lớp và nhị phân thứ tự {NORMAL, ABNORMAL}) | — | dòng 475–478 | — | `ml.log` dòng 16–34, 65–73; làm tròn đúng mọi ô |
| Thời gian RF 36–38 ms, 12–15.5 µs; IBk 15–17 µs | — | dòng 485–487 | — | `ml.log` ba lần chạy: 35.8/37.7/37.2; 12.34/13.84/15.48; 17.16/16.34/14.94 |
| NB nhị phân 80/400 | — | dòng 519–520 | — | `ml.log` dòng 69–71 |
| 51/52 (1 bỏ qua) | có | dòng 536 | có | `testng.log` dòng 116, 74 |
| 221 request, 472 assertion / 1 lỗi, 18 kịch bản, 2 phút 25 s | có | dòng 538–542 | có | `newman.log` dòng 1307, 1313, 1315, 1367 |
| 120 s khóa, 125.5 s | — | dòng 604–606 | 120 s | `latency.log` dòng 119–123, 140 |
| 90–105 s, 104.6 s | — | dòng 606–607, Bảng VI | có | `scenarios.log` (đã kiểm vòng 2) |
| 6–31 ms trung bình | có | Bảng VII (5.9, 17.0, 31.1) | có | `latency.log` |

Không thấy số nào thiếu nguồn hoặc lệch giữa Abstract, kết quả và Kết luận.

## 3. LaTeX (kiểm bằng script, không có trình biên dịch)
- Ngoặc `{}` 449/449 (sau khi bỏ `\{`, `\}`, chú thích); 30 `\begin` khớp `\end`; 17 `\label`, mọi `\ref` có `\label`, không
  thừa/thiếu, không trùng (gồm `sec:tier2`, `sec:tests`, `sec:ml`, `sec:latency`).
- 16 khóa `\cite` đều có trong `references.bib`, không khóa thừa. Chỉ ký tự ASCII. Không có `_`/`#` chưa thoát ngoài
  toán, `\texttt` và định nghĩa macro.
- TODO: đúng hai — `\TODO` đo đầu-cuối trên hộp thật (dòng 612) và ô giữ chỗ `wiring.png` (dòng 202, file không có trong
  `images/`; 8 ảnh còn lại có đủ).

## 4. Phát hiện mới
- **R3-C1 (THẤP, tùy chọn).** Intro dòng 79–80 "on synthetic data built that way": cụm "that way" chưa có tiền ngữ ở
  Intro (người đọc chưa biết dữ liệu được sinh thế nào). Gợi ý: "on synthetic data in which wrong-user and normal
  sessions share the same telemetry, that telemetry alone does not separate …". Không ảnh hưởng tính đúng.

## Kết luận vòng 3: **PASS**

Mọi mục vòng 2 đã sửa đúng và truy được nguồn; Bảng V khớp `ml.log` từng ô; mô tả mô hình đang chạy (RF hai lớp
NORMAL/FORCED_OPEN) và mô hình công cụ sẽ triển khai (IBk sáu lớp) đúng với mã. Chỉ còn một gợi ý câu chữ (R3-C1) và
hai TODO dành cho nhóm tác giả.

# Vòng 4 (agent "reviewer-4", 30/10/2026)

Phạm vi: `smartlocker.tex` sau lượt sửa "Vòng 4" của `CHANGES.md` (660 dòng, đọc toàn bộ), đối chiếu `retrain.log`,
`newman.log` ("Lần chạy 2"), `newman-2.json`, `testng-2.log`, mã sau các sửa lỗi của agent fix-bugs-2
(`RuleEngine`, `AlertService`, `RemoteCommandDao`, `SessionContextDao`, `LockerSessionDao`, `LockerSessionApi`,
`LockerBankDao`, `LockerMonitor`, `sql/03_v2_v3.sql`). Chỉ thêm mục này và `testng-3.log`. Số dòng là số dòng trong `smartlocker.tex`.

## 1. Đo lại TestNG (`testng-3.log`)
- `sqlcmd -S . -E -I -i <test_setup.sql, đường dẫn Windows>` (exit 0), rồi `sh scripts/test.sh` lúc 2026-10-30T16:30:29Z,
  sau khi fix-bugs-2 sửa mã (16:23–16:25Z): **56 test, 56 pass, 0 fail, 0 skip**.
- Số `@Test` theo lớp: AuditChainDatabaseIntegration 4, AuthText 3, DeviceBankDatabaseIntegration 3 (mới: heartbeat đưa
  thiết bị OFFLINE về và đóng cảnh báo; `Deposit_Complete` không có booking giữ transaction của bên gọi; gán dãy tủ trùng mã
  ngăn bị báo), MailTemplates 5, PricingDatabaseIntegration 6, Pricing 15, RiskScorer 1, RuleEngine 14, SecurityUtils 5 = 56.

## 2. Đối chiếu các mục vòng 4
| Mục | Kết quả | Bằng chứng |
|---|---|---|
| IBk (k=5) sáu lớp là mô hình triển khai, rủi ro 0.20 cho phiên bình thường | Đạt | `retrain.log`: `model class: weka.classifiers.lazy.IBk`, `-K 5`, header 6 nhãn, `normal-like ... risk=0.2016`; 16 số CV trùng `ml.log` |
| Newman 221 / 472 / 0 lỗi, 2 min 24 s, 18 kịch bản | Đạt | `newman.log` dòng ~2600–2664; `newman-2.json`: requests 221/0, assertions 472/0, 144.1 s, thư mục 1+3+2+2+1+11+7 |
| Dung sai đồng hồ 60 s, có test | Đạt | `RuleEngine.COMMAND_CLOCK_LAG_SEC = 60`, `isCommandInWindow`; `RuleEngineTest.commandWindowToleratesASlowBoxClock` |
| `AMBIGUOUS_SLOT` | Đạt | `LockerSessionDao.resolveSlot`: `bank_code`, rồi ngăn của lệnh, nếu còn >1 thì `AMBIGUOUS_SLOT` |
| Bốn hạn chế | Đạt | dòng 621–632 |
| TestNG 53 | **Lỗi thời** | nay 56 (mục 1) |

## 3. Sửa lỗi của fix-bugs-2 so với bài
- Lệnh từ xa dùng một lần nguyên tử (`markDone` trả boolean; phiên thứ hai cùng lệnh → `SUSPECTED_SPOOF` "remote command
  already used"): câu "replay: SUSPECTED\_SPOOF" ở Bảng VI và hàng 2' "(never issued, or already used)" vẫn đúng (phát lại
  tuần tự bị bắt ở bước đọc ngữ cảnh vì lệnh đã `DONE`; phát lại đồng thời bị bắt ở `markDone`). Không câu nào sai.
- Thiết bị demo chỉ tự hồi phục khi audit gần nhất là `MARK_OFFLINE`: bài chỉ nói "demo devices whose heartbeat is simulated
  by the server" (chú thích Hình ui2, hạn chế thứ ba) — vẫn đúng. Kịch bản heartbeat (104.6 s) chạy trên LOCKER-01 (không
  demo), không bị ảnh hưởng.
- `LockerBankDao.slotCodeClash` (trang quản trị không cho một hộp có hai dãy trùng mã ngăn), `UNKNOWN_BANK`,
  `Deposit_Complete` đọc với `UPDLOCK, HOLDLOCK`: không mâu thuẫn câu nào (dòng 373–375 vẫn đúng, nay đúng hơn). Cấu hình
  thử nghiệm "two banks that both have a slot A01" được tạo bằng SQL (`newman.log` Step 2), nên vẫn mô tả đúng lần chạy.

## 4. LaTeX (script, không có trình biên dịch)
Ngoặc `{}` 448/448 (bỏ `\{`, `\}`, chú thích); 60 thẻ `\begin`/`\end` (30 cặp) lồng đúng; mọi `\ref` có `\label`
(`sec:tier2`, `sec:tests` không được tham chiếu, vô hại); 16 khóa `\cite` đều có trong `references.bib`, không khóa thừa;
chỉ ASCII; Abstract 243 từ. TODO hiển thị đúng hai: `\TODO` đo đầu-cuối (dòng 616) và ô giữ chỗ `wiring.png` (file không
có; 9 ảnh còn lại có đủ).

## 5. Phát hiện
- **R4-A1 (PHẢI SỬA).** 53 → 56 ở bốn chỗ: dòng 48 (Abstract), 535 và 537 (VI.D), 647 (Kết luận). Câu VI.D nên kể thêm
  nhóm test mới (thủ tục heartbeat, trả ngăn và quy tắc gán dãy tủ trên CSDL). Abstract không đổi số từ.
- **R4-B1 (TRUNG BÌNH, bằng chứng, không đổi chữ).** Newman lần 2 chạy 16:16–16:19Z; bản fix-bugs-2 được triển khai lúc
  16:25Z (`build/web/.../RemoteCommandDao.class`). Kết quả 221/472/0 là của bản trước đó (đã có sửa tra ngăn). Các sửa sau
  không đổi luồng Postman (không gửi `bank_code`, phát lại tuần tự), nên rủi ro thấp; nên chạy lại newman (lần 3) trên bản
  hiện tại trước khi nộp và chỉ đổi tên log nếu vẫn 221/472/0.
- **R4-C1 (THẤP, tùy chọn).** Bảng III hàng 2 "issued at most 30~min before the session" chưa nhắc dung sai 60 s (chỉ có ở
  đoạn sau Bảng VI): thêm "(a box clock up to 60~s behind is tolerated)".
- **R4-C2 (THẤP, tùy chọn).** IV.C "A STAFF\_OPEN session marks its remote command as done;" có thể nói rõ tính dùng một
  lần nguyên tử: "... as done with a conditional update, so of two sessions carrying the same command only one is a staff
  open and the other becomes SUSPECTED\_SPOOF;".

## Kết luận vòng 4: **NEEDS FIXES** (chỉ R4-A1: số test 53 → 56). Sau khi sửa R4-A1 là PASS; R4-B1 là việc bằng chứng.
