# Rà chéo vòng 1: bài báo `docs/paper/smartlocker-10p.tex`

Người rà: agent rà chéo r1 (chỉ đọc mã nguồn, chỉ ghi tệp này). Ngày 2026-11-14.

Cách làm: chép `docs/paper` (tex, figs, images) sang scratchpad `r1-paper`, biên dịch bằng
`tectonic -X compile smartlocker-10p.tex` (không lỗi, không tham chiếu/trích dẫn chưa định nghĩa), xuất 13 trang PNG
110 dpi và xem từng trang, trích văn bản PDF để tìm kiếm. Đối chiếu với firmware `SmartLocker_Online.ino` (4.3),
`src/java/service/{RuleEngine,AlertService,LockerMonitor}.java`, `sql/02_data_v1.sql`, `sql/03_v2_v3.sql`,
`sql/04_phone.sql`, `sql/05_auto_checkin.sql`, `docs/paper/evidence/*.log`, `tools/make_ml_eval.py`,
`tools/make_workflow.py`, `figs/*.tex`. Thử thêm một bản biên dịch với phông Times (TeX Gyre Termes) trong
scratchpad `r1-times` để kiểm số trang.

## 1. Bảng kiểm từng dòng góp ý của cô

### Bảng 2 (mã nguồn, liên quan tới bài)

| Dòng | Nội dung | Kết quả | Ghi chú |
|---|---|---|---|
| 2.1 | Giao diện tiếng Anh, sửa câu mục V | CHƯA ĐẠT (đã biết) | Câu mục V đã sửa ("The interface is in English"). Fig. 7 và Fig. 8 trong PDF vẫn là ảnh giao diện tiếng Việt, nên PDF hiện tự mâu thuẫn. Có chú thích `CHECK-FINAL` ở dòng 766-767 của tex. |
| 2.2 | SRF05 tự khoá, cập nhật III.D, Fig. 2, Fig. 3 | ĐẠT | Câu III.D khớp firmware: `DOOR_OPEN_MS = 20000`, `DOOR_OPEN_MAX_MS = 120000`, phím D khoá ngay. Fig. 2 ("SRF05: presence, backlight, auto-lock") và Fig. 3 ("SRF05 ultrasonic / presence, backlight, auto-lock") đã vẽ lại. Có một lỗi nhỏ ở Fig. 3, xem lỗi 14. |
| 2.3 | Số test, số tệp, chạy lại test, ghi commit | CHƯA ĐẠT | Đếm đúng trên cây hiện tại: 89 Java, 11 759 dòng, 22 JSP, 83 `@Test` trong 14 lớp, 14 test RuleEngine. Hai điểm chưa đúng. (a) Câu "all 83 passed and none was skipped" không có log: log TestNG mới nhất `testng-3.log` (2026-10-30) chỉ chạy 56 test. (b) Câu VI.A gắn mọi phép đo vào commit 13ba35f, nhưng các log đo đều có ngày 2026-10-30, trước commit này (2026-11-14). Xem lỗi 2 và 3. |

### Bảng 3 (các câu trong bài)

| Dòng | Vị trí | Kết quả | Ghi chú |
|---|---|---|---|
| 1 | III.D SRF05 | ĐẠT | Đúng câu đề nghị, thêm ý phím D. |
| 2 | Khối tác giả | CHƯA ĐẠT (một phần) | Đã bỏ ORCID. Bốn gmail vẫn còn, tác giả liên hệ chưa chốt (hai dòng TODO 356-357), đúng như nhóm quyết định chờ. |
| 3 | Abstract nhiều số | ĐẠT | Chỉ còn "about 0.1 s" và "four"; không gạch ngang. |
| 4 | Khoảng số dùng en dash | ĐẠT | 6 to 31 ms, 1 to 23, 2 to 6 days, 36 to 38 ms, 90 to 105 s, 97 to 98 s, 0 to 3600 s; Table II ô "Built-in"; Table III dòng NORMAL số 9. Không còn en/em dash trong thân bài và caption (chỉ còn số trang trong tài liệu tham khảo). |
| 5 | Đóng góp thành bảng | ĐẠT | Table I ba cột No., Contribution, Where it is shown; không dòng nào in đậm. |
| 6 | III.A Fig. 2 làm chủ ngữ | ĐẠT | |
| 7 | III.E Fig. 4 làm chủ ngữ | ĐẠT | |
| 8 | IV.C câu Fig. 6 | ĐẠT | Đã gộp vào câu trước. |
| 9 | V User interface | ĐẠT | Gộp vào đoạn "Monitoring and user interface" (5 câu). |
| 10 | VI.B đoạn dẫn, bảng làm chủ ngữ | ĐẠT | Có đoạn dẫn; Table IV cũ thành Fig. 9 và Table VII ở phụ lục. |
| 11 | VI.E hộp thật offline và số đo hộp thật | ĐẠT | Đúng câu đề nghị. Số 1.67 s chưa có log trong `evidence/`, xem lỗi 22. |
| 12 | IV.D câu chủ đề | ĐẠT | |
| 13 | VI.D "tested at three levels" | ĐẠT | Đã bỏ. |
| 14 | VI.F First, Second... | ĐẠT | |
| 15 | Caption Fig. 1 | ĐẠT | |
| 16 | Caption Fig. 2 | ĐẠT | |
| 17 | Caption Fig. 4 | ĐẠT | |
| 18 | Caption Fig. 5 | ĐẠT | |
| 19 | Caption Fig. 6 | ĐẠT | Đổi "shaded boxes" thành "thick border, coral/mint", khớp hình. |
| 20 | VI.A Dataset | ĐẠT | 480 dòng, 5 cột đặc trưng và 1 cột nhãn, `sql/02_data_v1.sql`, lý do không dùng bộ công khai; TON_IoT [22] được dùng làm lý do. Khớp `sql/02_data_v1.sql` dòng 713-735 (6 lớp × 80, WRONG_USER cùng công thức với NORMAL). |

### Bảng 4 (nội dung làm thêm)

| Dòng | Hạng mục | Kết quả | Ghi chú |
|---|---|---|---|
| 1 | Thực nghiệm học máy | ĐẠT (theo phương án dự phòng) | Abstract, Introduction, Table I, VI.C và kết luận đều nói tầng luật là đóng góp chính, học máy là tín hiệu phụ. |
| 2 | Hình cho phần đánh giá | ĐẠT | Fig. 9 hai panel, số in đậm trên cột, ma trận nhầm lẫn IBk; bảng chuyển xuống phụ lục. Có lệch số 0.777/0.778 (lỗi 5) và nhãn trục chồng nhau (lỗi 9). |
| 3 | Màu, cỡ chữ, Fig. 6 rộng, Fig. 7 tách | ĐẠT (còn lỗi nhỏ) | Fig. 1, 3, 4, 5, 6 pastel, không tím/xám (`figs/colors.tex`), mũi tên chạm mép khối, chữ 9 pt; Fig. 6 rộng gần hết trang. Fig. 7 tách thành Fig. 7 và Fig. 8. Còn: hình thẻ RFID ở Fig. 2 tràn qua viền ô (lỗi 8), Fig. 8 cắt mất nửa dòng chú giải cuối (lỗi 4). |
| 4 | Tài liệu tham khảo mới, DOI | ĐẠT | Năm bài 2023-2025 dùng có nội dung: [5], [6], [15], [16], [18]; [7] có DOI 10.1063/5.0101139. Mọi mục có DOI, trừ [21] Provos (USENIX 1999) và [27] Kohavi (IJCAI 1995), hai bài này không có DOI nên in URL. Đánh số liên tục 1-27 theo thứ tự trích. |
| 5 | Đoạn văn ngắn | ĐẠT cho các đoạn cô nêu; CHƯA ĐẠT toàn bài | Các đoạn III.A, V User interface, VI.E cuối và kết luận đã có từ 5 câu. Còn 15 đoạn khác dưới 5 câu, xem lỗi 6. |
| 6 | Kết luận | ĐẠT | Chỉ còn hai số (0.977, about 0.1 s); có nhận định luật cho danh tính, học máy là tín hiệu phụ khi có dữ liệu thật. |

## 2. Danh sách lỗi

Trang tính theo bản biên dịch tectonic 13 trang; dòng là dòng trong `smartlocker-10p.tex`.

| STT | Vị trí | Lỗi | Mức độ | Đề nghị sửa |
|---|---|---|---|---|
| 1 | Preamble, dòng 326-327; mọi trang | Biên dịch bằng tectonic (XeTeX) thì IEEEtran không có Times (`Font shape TU/ptm/m/n undefined`). Phông rơi về Latin Modern, nên **mất hết chữ nghiêng, đậm và small caps**: các tiêu đề chạy "Smart and parcel lockers.", "Dataset.", "Protocol.", `\emph{area}`, tên tạp chí trong tài liệu tham khảo, tiêu đề mục small caps. Đây cũng là lý do bài dài 13 trang. Tôi đã thử với phông Termes: bài còn **12 trang** và trang 12 đầy. | cao | Biên dịch bằng pdfLaTeX (Overleaf). Nếu vẫn dùng tectonic thì thêm ngay sau `\documentclass[...]{IEEEtran}`: `\usepackage{iftex}` `\ifXeTeX\usepackage{fontspec}\setmainfont{texgyretermes}[Extension=.otf,UprightFont=*-regular,BoldFont=*-bold,ItalicFont=*-italic,BoldItalicFont=*-bolditalic]\fi`. Đã thử trong scratchpad: Termes có Regular, Bold và Italic, bài 12 trang. |
| 2 | VI.D dòng 855-860, abstract dòng 382 | "In the final run all 83 passed and none was skipped" chưa có bằng chứng. Log mới nhất `evidence/testng-3.log` (2026-10-30) là 56/56, `testng.log` là 52 test với 1 skip. Năm lớp AutoCheckIn, PhoneTap, CardMail, LockerSessionList, AuditFlood (27 test) chưa có log nào. Câu abstract "All automated tests ... passed" dựa vào câu này. | cao | Chạy `sh scripts/test.sh` trên commit cuối, với DB test dựng bằng `-TestSetup`, và lưu `docs/paper/evidence/testng-4.log`. Sau đó viết số thật: "In the final run on commit \measurecommit{}, all 83 passed and none was skipped." Nếu có test bị skip thì ghi "N of the 83 passed and M were skipped because ...", đồng thời sửa abstract thành "All automated tests that ran and all replayed detection scenarios passed". |
| 3 | VI.A dòng 811-812 | "The code counts of Section V, the tests of Section VI-D and these measurements refer to commit 13ba35f" là sai. `ml.log`, `latency.log`, `scenarios.log` và `newman.log` đều ghi ngày 2026-10-30, còn 13ba35f là ngày 2026-11-14. | cao | Cách 1: chạy lại ML, latency, newman và TestNG trên commit cuối. Cách 2: ghi đúng thời điểm đo: "The code counts of Section V refer to commit \measurecommit{} of the project repository; the classifier results, the replayed scenarios and the response times were measured on 30 October 2026, and the rule engine, the risk scorer and the device API they exercise were checked to be unchanged in that commit." Vế cuối chỉ được giữ sau khi đã kiểm bằng `git diff <commit 30/10> 13ba35f -- src/java/service src/java/api sql`. |
| 4 | Fig. 7, Fig. 8 (trang 8-9), dòng 766-785 | Ảnh vẫn là giao diện tiếng Việt, trong khi mục V viết "The interface is in English" (Bảng 2 dòng 1). Fig. 8 cắt ngang dòng chú giải cuối "OVERDUE_ESCALATED 1" của biểu đồ donut. | cao (đã biết, chờ bước kiểm chứng) | Chụp lại bằng giao diện tiếng Anh. Khi cắt panel cảnh báo, lấy đủ cả dòng chú giải cuối, rồi kiểm lại mọi số trong hai caption (đã có danh sách trong `CHECK-FINAL` dòng 766-767). |
| 5 | Fig. 9a so với dòng 819 và Table VII | Cột Naive Bayes sáu lớp ghi **0.777**, còn văn bản và Table VII ghi **0.778**. `ml.log` cho 0.7775; `make_ml_eval.py` dùng `"%.3f" % v` nên float 0.7775 thành 0.777. | trung bình | Trong `tools/make_ml_eval.py` làm tròn half-up: `from decimal import Decimal, ROUND_HALF_UP`; nhãn = `str(Decimal(str(v)).quantize(Decimal("0.001"), ROUND_HALF_UP))`, rồi xuất lại `ml-eval.pdf`. Như vậy hình ghi 0.778, khớp bảng. |
| 6 | Toàn bài: đoạn dưới 5 câu | Ngoài các đoạn cô đã nêu, còn các đoạn ngắn sau. I đoạn 1 (dòng 392, 4 câu). II "Security of IoT devices" (446, 4). III.B Roles (503, 2). III.C Data Model (512, 3). III.D Hardware (521, 4). IV.A (613, 3). IV.B (625, 3). IV.E (710, 3). V đoạn 1 (719, 3). V "Security." (762, **1 câu**). VI.B (816, 4). VI.C đoạn 2 (845, 4). VI.D "Unit and integration tests" (856, 3). VI.E đoạn 1 (901, **2 câu**). Phụ lục (967, 1). Acknowledgment (990, 3). Câu dẫn danh sách ở III.E (559) và IV.D (694) có thể giữ. | trung bình | Sửa trước các đoạn 1-2 câu. **VI.E:** chuyển Table VI xuống sau đoạn "Every request was answered..." rồi gộp đoạn 901 với đoạn 924, được 7 câu. **V Security:** thay bằng 5 câu: "\textit{Security.} Passwords are hashed with BCrypt, and device keys are stored only as SHA-256 hashes. The session user is reloaded from the database on every request, so a locked account is signed out at once. A failed sign-in is logged with the account name only if that account exists. All user data is escaped, with \texttt{<c:out>} in JSP and with a single escaping function in JavaScript. Visitors may open only the map and its read-only data, and every write request requires a session." **III.B:** gộp vào cuối III.A và bỏ tiêu đề "Roles" (bớt luôn một tiêu đề). **IV.B:** thêm "Rule 2' is the negative branch of rule 2 and therefore shares its place in the order. Rules 4 to 8 then describe what happened at the slot, from the most to the least serious case." **IV.A:** thêm "The five features are the input of the risk model of Section IV-C, while the context is used only by the rules. A session sent again after an outage is stored once, because the batch endpoint keeps the per-device sequence number." Các đoạn 4 câu chỉ cần thêm một câu có thông tin. |
| 7 | III.F dòng 595, VI.E dòng 904 | Nhãn trên hộp không khớp. Bài viết “A: open / B: return”, còn hộp và server hiện "A: Open / B: Checkout" (firmware dòng 175, `AuthText.java:40`, intent `CHECKOUT`). | trung bình | Dòng 595: "Later authentications offer ``A: Open / B: Checkout'', where A keeps the rental (\texttt{ACCESS}) and B ends it (\texttt{PICKUP})". Dòng 904: "...answers with the ``A: Open / B: Checkout'' choice without modifying any data." |
| 8 | Fig. 2 (trang 3), ô "PN532 NFC, RFID card" | Hình chữ nhật thẻ RFID vẽ tràn qua viền phải của ô, chạm sang ô SRF05 (chồng hình). | trung bình | Trong `tools/make_workflow.py`, thu nhỏ hoặc dời hình thẻ vào trong ô PN532 (cách viền ít nhất 4 px), rồi xuất lại `workflow.pdf`. |
| 9 | Fig. 9b (trang 10) | Nhãn trục x xoay chồng lên nhau: "FORCED_OPEN" chồng "WRONG_USER", "ITEM_LEFT" chồng "SUSP._SPOOF". | trung bình | Dùng `rotation=45, ha="right", rotation_mode="anchor"` và cỡ 8, hoặc đổi nhãn thành "FORCED", "WRONG", "OVERDUE", "ITEM", "SPOOF", "NORMAL" và giải thích viết tắt trong caption. |
| 10 | Caption Fig. 9, dòng 827-829 | Panel làm chủ ngữ: "(a) compares ... and (b) shows ...". | trung bình | "Cross-validation results on the 480 synthetic sessions, with the weighted F1 of the four Weka classifiers for the six-class and the binary task in (a) and the confusion matrix of IBk for the six-class task in (b), where 10 of its 11 errors lie between WRONG\_USER and NORMAL." |
| 11 | Khối tác giả, dòng 355-366 | Bốn địa chỉ gmail và tác giả liên hệ vẫn chờ (Bảng 3 dòng 2). | trung bình (đã biết) | Điền địa chỉ @fpt.edu.vn và chốt dấu * theo trao đổi với cô trước khi nộp; nhớ xoá hai dòng TODO. |
| 12 | Caption các bảng I-VII | Caption bảng vẫn kiểu tiêu đề IEEE (Title Case), không phải câu hoàn chỉnh. Cô chỉ nêu ví dụ cho hình, nhưng quy ước ghi chung "caption là câu hoàn chỉnh có nội dung". | thấp | Nếu cô áp dụng cho bảng thì đổi, ví dụ Table VI: "Server-side response time of the device API in milliseconds, measured over 30 requests per endpoint on localhost". Nếu không thì giữ kiểu IEEE. Nên hỏi cô. |
| 13 | IV.A dòng 616 | "its open source (local, remote or phone)" dễ đọc thành "open-source". | thấp | "the source of the opening (local, remote or phone)". |
| 14 | Fig. 3 (`figs/fig-block.tex`), ô "Door servo" | Ô "Door servo / locks 20 s after leaving" chưa chính xác. Servo cửa chỉ đóng cửa, then khoá do servo then làm (`closeDoor()`: cửa trước, then sau), và mốc 120 s không được ghi. | thấp | Đổi dòng phụ thành `\slsub{closes 20 s after leaving}`, hoặc chuyển ý tự khoá về ô SRF05, nơi đã ghi "auto-lock". |
| 15 | Fig. 5 (`figs/fig-state.tex`) | Mũi tên AVAILABLE→MAINTENANCE chỉ ghi "staff", trong khi IV.C viết SENSOR_FAULT cũng đưa ngăn ra khỏi phục vụ (kịch bản sensor ở Table V: slot MAINTENANCE). | thấp | Ghi nhãn "staff or SENSOR\_FAULT". |
| 16 | Fig. 6 (`figs/fig-flow.tex`), ô "ℓ ← first matching rule 3 to 8" | Khi không luật 3-8 nào khớp thì ℓ = NORMAL, tức luật 9. | thấp | Đổi thành "rule 3 to 9". |
| 17 | III.E dòng 560 | Bài dùng chính tả Anh (organised, recognises, artefact) nhưng ở đây lại viết "enroll" kiểu Mỹ. | thấp | "two more enrol cards and fingerprints". |
| 18 | III.F dòng 594 | "block new bookings for a while" mơ hồ. Mã nguồn chặn khi còn từ 3 no-show trong 7 ngày gần nhất (`03_v2_v3.sql` dòng 1077). | thấp | "three no-shows within the last 7 days block new bookings until the oldest of them is more than 7 days old". |
| 19 | III.F dòng 594-597 | "the grace period" chưa có giá trị. | thấp | Thêm giá trị `grace_min` của gói, ví dụ "the grace period of the plan (30 min for the day pass)". Lấy đúng giá trị từng gói trong `StoragePlan`. |
| 20 | VI.D dòng 866 | "on the released build" không rõ là bản nào. | thấp | "(2 min 27 s, run of 30 October 2026)", hoặc ghi commit sau khi chạy lại. |
| 21 | VI.E dòng 934-935 | Báo bốn cảnh báo offline 97 tới 98 s và một cảnh báo 110 s, nhưng bỏ không nói cảnh báo 18 (906 s, lúc Tomcat dừng) có trong `scenarios.log`. | thấp | Thêm vào cuối câu: "..., and one alert raised while the server was stopped is not counted." |
| 22 | VI.E dòng 926-928 | Phép đo 1.67 s và 1.5 s là tác giả báo, chưa có log (`evidence/CHANGES.md` dòng 168 ghi "chưa có file log"). | thấp | Lưu `evidence/e2e-phone.log` (20 lần: giờ gửi, giờ cửa mở) để có bằng chứng như các số khác. |
| 23 | II dòng 459 | "Shahin et al. [16] also detect in two tiers": chữ "also" đứng trước khi đoạn này nói SmartLocker có hai tầng. | thấp | "Like SmartLocker, Shahin et al. \cite{shahin2025twostage} detect in two tiers: ..." |
| 24 | Fig. 6 | Ô xử lý "Risk r(s) by (1)" cùng màu mint với ô kết quả "STAFF_OPEN, no alert" và "No alert". Caption phân biệt bằng viền dày nên vẫn đúng, nhưng dễ nhầm. | thấp | Tô ô "Risk r(s)" màu xanh dương nhạt (`slblue`) như các ô xử lý khác. |
| 25 | Tài liệu [7] | Kiểu IEEEtran in "vol. 2427, no. 1.   AIP, Feb. 2023, p. 020098" với khoảng trắng thừa trước "AIP". | thấp | Trong bib, bỏ `publisher` hoặc chuyển sang `@inproceedings` với `organization`. Có thể giữ nguyên. |

## 3. Các mục đã kiểm và khớp (không cần sửa)

- Ngưỡng: 50 g (`ITEM_LEFT_G`, `SPOOF_WEIGHT_G`), 300 s (`CLOCK_AHEAD_SEC`), 30 phút (`COMMAND_TTL_SEC`), 60 s
  (`COMMAND_CLOCK_LAG_SEC`), τ = 0.80 (`AlertService.ML_THRESHOLD`), heartbeat 3 s (firmware `heartbeatEveryMs`),
  timeout 90 s và job 15 s (`Device_MarkOffline(90)`, `PROCEDURE_INTERVAL_SEC`), snapshot 2 s, audit 60 s.
- Thứ tự luật trong Table III khớp `RuleEngine.evaluate` (gồm 2' và SUSPECTED_SPOOF dòng 6 dùng |Δw|).
- Vòng đời đặt chỗ v7.1 (giữ 15 phút, hoàn 100% trong 5 phút rồi 50%, AUTO_CHECK_IN khi hết giữ chỗ, NO_SHOW ở hạn
  cộng ân hạn khi chưa mở, không phí trễ, 3 lần gia hạn, phí trễ 150%, leo thang 48 h) khớp `AppConfig` và
  `05_auto_checkin.sql`.
- Bảng giá (Table IV) tính lại đúng: M phí trễ 2500 × 1.3 × 1.5 = 4875 làm tròn lên 4900; L ngày 42 250 làm tròn 42 300.
- Chân nối Table II khớp firmware (keypad 13/14/25/26 và 33/19/23/27, AS608 RX 35/TX 15, servo 32/2, SRF05 5/18,
  I2C 21/22, PN532 0x24).
- Số học máy khớp `ml.log`: IBk 0.977/0.975, RF 0.948/0.939 (binary theo thứ tự nhãn {NORMAL, ABNORMAL}), J48, ma trận
  IBk 73/7/3/77/79/1, RF 17 và 8, NB binary 80 trên 400, thời gian RF 35.8 tới 37.7 ms, 12.3 tới 15.5 µs, IBk 14.9 tới
  17.2 µs, r = 0.2016 (`retrain.log`). Chỉ lệch 0.777 trong hình (lỗi 5).
- Table VI khớp `latency.log`; 104.6 s, 97 tới 98 s, 110 s, 125.5 s khớp `scenarios.log` và `latency.log`;
  newman 221 requests, 472 assertions, 2 m 26.9 s khớp `newman.log`.
- Trigger append-only và hai filtered unique index khớp `01_schema.sql`.
- Abstract và kết luận đặt học máy ở vai trò phụ; không còn gạch ngang trong thân bài và caption; không hình/bảng nào
  làm chủ ngữ trong thân bài (chỉ còn caption Fig. 9, lỗi 10); Table I không có dòng in đậm.
- Mọi `\cite` đều có mục, không cảnh báo chưa định nghĩa; số thứ tự 1-27 theo thứ tự trích dẫn.

## 4. Đề nghị đưa bài về 12 trang (chưa áp dụng)

Trang 13 hiện chỉ có 7 mục tài liệu tham khảo, khoảng 1/6 trang.

1. **Sửa phông (lỗi 1).** Với Times/Termes, bài còn 12 trang mà không cắt nội dung nào (đã thử).
2. Nếu vẫn thiếu chỗ sau khi thêm câu cho các đoạn ngắn (lỗi 6), giảm Fig. 7 và Fig. 8 từ `height=0.42\textheight`
   xuống `0.34\textheight` và cắt sát vùng cần xem khi chụp lại ảnh tiếng Anh. Mỗi hình bớt được khoảng 0.08 trang.
3. Gộp III.B Roles vào cuối III.A và bỏ tiêu đề. Cách này bớt khoảng 3 dòng và sửa luôn đoạn 2 câu.
4. Fig. 5: hạ cung "return (PICKUP) ..." sát hơn hàng trạng thái và giảm khoảng cách tới MAINTENANCE. Bớt khoảng 4 dòng
   mà không mất nhãn nào.
5. Đặt Table VII (phụ lục) ở `[!t]` thay cho `[H]` để LaTeX xếp cùng trang với Acknowledgment.

KẾT LUẬN: CHƯA ĐẠT
