# Vòng 2, T1b (paper-text): sửa `docs/paper/smartlocker-10p.tex` theo `r1-paper.md`

Người làm: agent T1b. Ngày 2026-11-15. Chỉ sửa `docs/paper/smartlocker-10p.tex` (CRLF giữ nguyên). Không commit.

## 0. Khôi phục trước khi sửa

Bản `smartlocker-10p.tex` lưu lúc 2026-11-14 22:41 có nhiều thay đổi không do vòng sửa này yêu cầu, một số sai sự thật.
T1b không dựng lại từng dòng trên bản đó. Bản sửa lấy gốc là đúng bản mà người rà vòng 1 đã biên dịch
(`scratchpad/r1-paper/smartlocker-10p.tex`), rồi áp các sửa ở mục 1 bằng script (`scratchpad/t1b.py`, mỗi lần thay
đều kiểm đúng 1 chỗ khớp). Những gì đã khôi phục:

- Khối tác giả: lại là bốn địa chỉ gmail thật như trong `git show HEAD`, dấu * cho Kieu Trong Khanh, dòng
  "*Corresponding author", hai comment `% TODO: confirm corresponding author with the teacher` và
  `% TODO: replace with @fpt.edu.vn addresses`. Bỏ bốn địa chỉ @fpt.edu.vn bịa ra.
- Hình giao diện: lại là `fig:ui-user` (`images/ui-user.png`) và `fig:ui-staff` (`images/ui-staff.png`) với caption câu
  đầy đủ; bỏ hình bốn ảnh nhỏ 0.24 `fig:ui` (map-area, booking-confirm, dashboard, alert-escalated).
- Fig. 9 `fig:mleval` (`images/ml-eval.pdf`, panel (a)/(b)) với đoạn dẫn ở VI.B; Table VII `tab:ml` lại ở phụ lục
  "Full Cross-Validation Results". Mọi `\ref` khớp (không tham chiếu chưa định nghĩa).
- TikZ: lại `\input{figs/colors.tex}` và `\input{figs/fig-arch|fig-block|fig-seq|fig-state|fig-flow.tex}` (một nguồn,
  bản T2b mới: "closes 20 s after leaving", "staff or SENSOR_FAULT", "rule 3 to 9", ô risk xanh nhạt).
- Bib: khối `filecontents` lại ghi `smartlocker-refs.bib` và `\bibliography{smartlocker-refs}`. Bản 22:41 ghi đè
  `docs/paper/references.bib` (tệp có theo dõi của T3) mỗi lần biên dịch tại chỗ; `git diff` hiện cho thấy tệp đó
  đã đổi, T1b không đụng tới, nhờ điều phối kiểm.
- Các câu chêm chung chung hoặc không có căn cứ trong bản 22:41 bị bỏ: nguồn 5 V và tụ lọc (III.D), "Distributed and
  federated architectures ... [Shahin]" (trích sai bài), "All administrative ... actions are permanently recorded",
  "responsive design ... cached locally", "low computational overhead confirms ...", "confirming that all system
  components operate in accordance with design specifications", "By decoupling identity verification ...", và câu
  ân hạn sai "15 minutes for hourly plans" (đúng là 10 phút).
- CHECK-FINAL: các comment đã bị xoá được đặt lại (xem mục 3).

`docs/review/rounds/r2-paper.md` (22:18) không phải do T1b viết trong phiên này; nó ghi nhiều điểm không đúng với tex
(email @fpt.edu.vn "đã thống nhất", ảnh giao diện "đã làm mới", 1.67 s "đã làm rõ"...). T1b để nguyên tệp đó, điều phối
quyết định xoá.

## 1. Từng lỗi của `r1-paper.md`

| STT | Mức | Việc đã làm |
|---|---|---|
| 1 | cao | Preamble thêm `\usepackage{iftex}`; với XeTeX/LuaTeX (`\ifPDFTeX\else`) nạp `fontspec` và `\setmainfont{texgyretermes}`, `\setsansfont{texgyreheros}`, `\setmonofont{texgyrecursor}` (tên tệp, Extension=.otf, đủ Regular/Bold/Italic/BoldItalic), tức đúng ba họ phông Times/Helvetica/Courier mà IEEEtran dùng với pdfLaTeX; pdfLaTeX (Overleaf) không nạp gì thêm. Đã xem PDF tectonic: nghiêng (tiêu đề chạy "Smart and parcel lockers.", `\emph`, tên tạp chí), đậm, small caps (tiêu đề mục, caption bảng) đều hiện; phông nhúng là TeXGyreTermes Regular/Bold/Italic và TeXGyreCursor. Máy không có pdflatex nên chưa thử nhánh pdfLaTeX. |
| 2 | cao | T9 đã có `evidence/testng-4.log`: 83 chạy, 83 qua, 0 lỗi, 0 skip (2 phút 10.5 s, trên 13ba35f cộng cây giao diện tiếng Anh chưa commit). Câu VI.D giữ "In the final run on commit \measurecommit, all 83 passed and none was skipped", thêm thời gian "about 2 min 10 s"; bỏ CHECK-FINAL của câu này (theo điều phối), thay bằng comment trỏ tới log. Abstract đổi thành "All unit, integration and API tests and all replayed detection scenarios passed ..." và giữ CHECK-FINAL (đúng khi TestNG và newman qua trên commit cuối). |
| 3 | cao | Commit ngày 30/10/2026: `da95f43` (2026-10-28, không có commit nào tới 2026-11-04); `code-stats.log` 13:31 UTC ghi HEAD da95f43, cây sạch trừ `docs/paper/`, nằm giữa lúc chạy ml.log (13:26), scenarios.log (13:27) và latency.log (13:34). Thêm macro `\evalcommit{da95f43}`. VI.A viết lại: số liệu mã nguồn và test đơn vị/tích hợp theo `\measurecommit` (CHECK-FINAL); kết quả phân loại, kịch bản phát hiện và thời gian đáp ứng đo ngày 30/10/2026 trên `\evalcommit`, newman chạy cùng ngày. Đã `git diff da95f43` để nói thật phần đổi: 5 đặc trưng và RiskScorer không đổi; RuleEngine thêm dung sai đồng hồ 60 s, AlertService thêm dùng lệnh một lần khi đồng thời (markDone có điều kiện); device API và thủ tục đặt chỗ cũng đổi (phone tap, auto check-in), nên kịch bản và thời gian đáp ứng mô tả bản trước. Không dùng câu "checked to be unchanged" của người rà vì không đúng. VI.D kịch bản *remote*: thêm câu bản chạy trong Table V để cách 2 s giữa lệnh và phiên (đúng `scenarios.log`, lúc đó chưa có dung sai 60 s). |
| 4 | cao | Không thuộc T1b (T9 chụp lại ảnh tiếng Anh). Ảnh hiện tại vẫn tiếng Việt; caption khớp số trên ảnh hiện tại; giữ CHECK-FINAL. |
| 5 | tb | Hình (T2b). Fig. 9a hiện ghi 0.778, khớp Table VII. |
| 6 | tb | Mọi đoạn trong danh sách nay từ 5 câu, chỉ thêm nội dung có trong repo: I đoạn 1 (+1 câu nhu cầu); II Security (+ thẻ mất/nhân bản bị chặn ở server, gửi UID qua heartbeat, nhãn LOST_CARD_USED); III.B Roles gộp vào III.C, đổi tên "Data Model and Roles" (+ ví trả trước chỉ tăng khi operator duyệt top-up có mã chuyển khoản duy nhất, bảng `TopupRequest`; + quyền là bảng `Roles/Permissions/RolePerm`, quyền = tài nguyên + READ/WRITE, ADMIN đổi trên web qua `PermissionDao`), 7 câu; III.D (+ HTTP keep-alive, firmware dòng 100); IV.A (2 câu của người rà); IV.B (2 câu của người rà về 2' và luật 4 tới 8); IV.E (+ mục đầu nối với hash 64 số 0, hash và liên kết ghi cùng giao dịch, `Audit_Append`; + cả hai lần kiểm tính lại từ mục đầu, đọc theo luồng, báo mục hỏng đầu tiên, `AuditVerifier.findFirstBroken` dùng ở `AuditController` và `LockerMonitor`); V đoạn 1 (+ các gói `api, controller, service, dao, model, filter, util`; + JDBC thuần với prepared statement, phần lớn qua DAO, pool kết nối); V Security (đúng 5 câu của người rà); VI.B (+ J48 0.856 và 0.848); VI.C đoạn 2 (+ điểm tính sau khi phiên đã tải lên nên ML_ANOMALY không bao giờ chặn mở cửa); VI.D Unit tests (+ test đơn vị không cần DB, test tích hợp ghi vào DB test riêng, `scripts/test.sh` từ chối DB không bắt đầu bằng `SL_`; + thời gian chạy); VI.E: gộp đoạn 2 câu với đoạn sau, Table VI chuyển xuống sau đoạn (8 câu); phụ lục (+ cùng fold seed 42; trọng số theo số phiên mỗi lớp, nhị phân 400 so với 80; recall có trọng số bằng accuracy, đúng mọi dòng; Naive Bayes là mô hình duy nhất có F1 nhị phân cao hơn sáu lớp, 0.852 so với 0.778); Acknowledgment (+ cảm ơn giảng viên đã góp ý bản đầu; tách câu cuối làm hai). |
| 7 | tb | III.F và VI.E: ``A: Open / B: Checkout'' (khớp `AuthText.java:44`, firmware dòng 18, 175, 542). |
| 8, 9 | tb | Hình (T2b). |
| 10 | tb | Caption Fig. 9 đúng câu của người rà. |
| 11 | tb | Không thuộc T1b (quyết định nhóm). Đã khôi phục gmail và TODO, xem mục 0. |
| 12 | thấp | Giữ caption bảng kiểu IEEE theo quyết định. |
| 13 | thấp | "the source of the opening (local, remote or phone)". |
| 14, 15, 16, 24 | thấp | Hình (T2b); bản `figs/*.tex` mới đã được `\input`. |
| 17 | thấp | Phần thân dùng chính tả Anh (organised, recognises, optimise, artefact, labelled, authorised, summarised); "enroll" thành "enrol". |
| 18 | thấp | "three no-shows among the bookings of the last 7 days block new bookings until the oldest of them is more than 7 days old" (`Deposit_Reserve`, THROW 50031, đếm `reserved_at` trong 7 ngày). |
| 19 | thấp | Giá trị ân hạn ở lần nhắc đầu: "10 minutes for the 2-hour and 4-hour plans, 30 minutes for the day pass" (`01_schema.sql` dòng 494-497, `02_data_v1.sql` dòng 403; gói tuỳ chọn mượn ân hạn của gói dài nhất không dài hơn nó). |
| 20 | thấp | "Both later runs of 30 October 2026 (the last took 2 min 27 s) executed 221 requests and 472 assertions without a failure" (`newman.log`: lần 2 2m24.1s, lần 3 2m26.9s, 0 lỗi). CHECK-FINAL để T9 thay bằng lần chạy cuối. |
| 21 | thấp | Thêm: cảnh báo thứ sáu, 906 s sau heartbeat cuối, không tính vì server dừng trong lúc chờ (`scenarios.log`, alert 18). |
| 22 | thấp | Không có log. Câu mới: "the authors timed 20 openings ... at 1.67 s on average; unlike the other values of this section, these openings were timed without a saved log". 1.5 s ghi là thời gian chờ trung bình suy ra từ chu kỳ 3 s, không phải số đo. |
| 23 | thấp | "Like SmartLocker, Shahin et al. [16] detect in two tiers". |
| 25 | thấp | Bỏ `publisher = {AIP}` ở mục bib `rfidiot2023locker`; [7] nay in "in AIP Conference Proceedings, vol. 2427, no. 1, Feb. 2023, p. 020098, doi: ...", không còn khoảng trắng thừa. |

Thêm (điều phối mục 5): mục "Lost cards" ở IV.D viết lại thành hai dòng ("... and the box refuses them with
CARD_BLOCKED"), hết overfull.

## 2. Biên dịch

`scratchpad/t1b-build` (tex, `figs/`, `images/` chép từ `docs/paper` lúc 2026-11-15), `tectonic -X compile`: không lỗi,
không Overfull/Underfull, không tham chiếu hay trích dẫn chưa định nghĩa, bibtex không cảnh báo. **12 trang**, trang 12
đầy (Table VII, Acknowledgment, tài liệu tham khảo [1] tới [27]). Còn hai cảnh báo vô hại: `Font shape TU/ptm/... undefined`
(IEEEtran gọi Times trước khi `fontspec` nạp, sau đó Termes thay) và "TeX rerun seems needed, but stopping at 6 passes"
(không còn "Label(s) may have changed" trong log). Đã xem từng trang PNG.

Để còn 12 trang (thêm câu cho mục 6 làm dài khoảng 25 dòng): Fig. 2 rộng 0.9\linewidth, Fig. 7 và Fig. 8 cao tối đa
0.27\textheight, Fig. 9 cao tối đa 0.27\textheight, Table VII `[!t]` thay `[H]`. Từ 0.30 trở lên bài lại 13 trang (7 mục
tài liệu sang trang 13). Ở 0.27, ảnh giao diện rộng khoảng 9.5 cm, chữ nhỏ; khi T9 chụp lại tiếng Anh nên cắt sát hai
panel để còn đọc được, hoặc chấp nhận 13 trang (có comment trong tex).

## 3. Các mục CHECK-FINAL còn lại

1. `\measurecommit` (đang là 13ba35f): đặt commit cuối; `testng-4.log` chạy trên 13ba35f cộng cây tiếng Anh chưa commit.
2. Abstract "All unit, integration and API tests and all replayed detection scenarios passed": đúng khi TestNG và newman
   qua trên commit cuối.
3. Mục V: 89 tệp Java, about 11 800 dòng (11 764 trên cây làm việc 2026-11-15; 11 736 trên 13ba35f), 22 JSP: đếm lại
   trên commit cuối.
4. Fig. 7 và Fig. 8 (`ui-user.png`, `ui-staff.png`): vẫn là giao diện tiếng Việt; T9 chụp lại tiếng Anh, kiểm lại mọi số
   trong hai caption (23 of 27, B07, 6 500 VND, 11 alerts, 10 of 10, #119, A12, 50 h, 320 000 / 128 500 VND) và chiều cao
   (0.27\textheight giữ 12 trang).
5. VI.D newman: thay "Both later runs of 30 October 2026 (the last took 2 min 27 s) ... 221 requests and 472 assertions"
   bằng ngày, thời gian, số request và assertion của lần chạy cuối của T9; nếu chạy trên commit cuối thì sửa luôn câu VI.A
   "the API scenarios were run on the same day".
6. Khối tác giả (không thuộc T1b): hai TODO về email trường và tác giả liên hệ.

## 4. Tệp liên quan

- Đã sửa: `docs/paper/smartlocker-10p.tex`.
- Đã tạo: `docs/review/rounds/r2-T1b-paper.md` (tệp này).
- Script và bản biên dịch: `scratchpad/t1b.py`, `scratchpad/t1b-build/smartlocker-10p.pdf`.
