# Vòng 0, T1 (paper-text): sửa `docs/paper/smartlocker-10p.tex`

Chỉ sửa `smartlocker-10p.tex` (khối `filecontents` của bib giữ nguyên từng byte, CRLF giữ nguyên). Không commit.
`docs/paper/figs/orig/*.tex` đã có sẵn (T2 tạo trước), nên T1 không ghi đè.

Biên dịch thử bằng tectonic trong bản sao `scratchpad/t1-build` (dùng `figs/*.tex` thật của T2; ảnh `ui-user.png`,
`ui-staff.png`, `ml-eval.pdf` chưa có nên dùng ảnh giữ chỗ chỉ trong bản sao): không lỗi, không tham chiếu/trích dẫn
chưa định nghĩa, 12 trang (bản gốc 11 trang; thêm bảng đóng góp, tách Fig. 7 làm hai, thêm hình đánh giá và phụ lục).
Còn một cảnh báo Overfull 24 pt nằm trong `figs/fig-state.tex` (việc của T2).

## Bảng 3
| Dòng | Trạng thái | Cách sửa |
|---|---|---|
| 1 | Xong | III.D: SRF05 bật đèn nền LCD và khoá cửa 20 s sau khi người rời đi, chậm nhất 120 s sau khi mở; phím D khoá ngay. Đã kiểm `firmware/SmartLocker_Online/SmartLocker_Online.ino` (`DOOR_OPEN_MS = 20000`, `DOOR_OPEN_MAX_MS = 120000`, `doorTick`). Bảng phần cứng: SRF05 "Presence detection (backlight, automatic lock)". |
| 2 | Xong | Bỏ dòng ORCID; giữ dấu * cho Kieu Trong Khanh, thêm `% TODO: confirm corresponding author with the teacher`; giữ gmail, thêm `% TODO: replace with @fpt.edu.vn addresses` (chỉ comment). |
| 3 | Xong | Abstract chỉ còn "four" và "0.1 s"; bỏ 480, 0.977, 66, 472, 18, 6–31 ms; giảm vai trò học máy (tầng luật là chính, điểm rủi ro là tín hiệu phụ, chỉ tin khi có dữ liệu thật). |
| 4 | Xong | Mọi khoảng số viết "a to b" (6 to 31 ms, 1 to 23, 2 to 6 days, 36 to 38 ms, 90 to 105 s, 97 to 98 s, 0 to 3600 s, 1 to 7, 12 to 15.5 µs, 15 to 17 µs). Ô "--" bảng phần cứng thành "Built-in", dòng NORMAL bảng luật đánh số 9. Grep phần thân (sau bib): không còn `--`, `–`, `—`. |
| 5 | Xong | Danh sách đóng góp thành bảng `tab:contrib` (No., Contribution, Where it is shown; 3 dòng: III và V, IV, VI), không in đậm; câu dẫn theo gợi ý của cô. Bảng này thành Table I nên các bảng sau dời số (phần cứng II, luật III, giá IV, kịch bản V, thời gian đáp ứng VI, học máy VII ở phụ lục). |
| 6 | Xong | III.A: "In the end-to-end workflow (Fig. 2), ..." và gộp với đoạn kiến trúc thành một đoạn 7 câu. |
| 7 | Xong | III.E: câu theo gợi ý, hình trong ngoặc. |
| 8 | Xong | IV.C: "..., following the decision flow of Fig. 6." gộp vào câu trước. |
| 9 | Xong | V: gộp vào đoạn Monitoring thành "Monitoring and user interface" (6 câu), tham chiếu `fig:ui-user` và `fig:ui-staff`. |
| 10 | Xong | VI.B: đoạn dẫn theo gợi ý, kết quả có tham chiếu trong ngoặc (Fig. 9a); Table IV cũ chuyển xuống phụ lục (`\appendix[Full Cross-Validation Results]`, giữ nhãn `tab:ml`, nhắc là "Table VII in the appendix"). Thêm hình `images/ml-eval.pdf` (`fig:mleval`), caption là câu đầy đủ; VI.C trích Fig. 9b cho ma trận nhầm lẫn. |
| 11 | Xong | VI.E: câu theo gợi ý; đoạn số đo trên hộp thật đổi thành "In a separate session with the box online, ..." và gộp vào đoạn sau bảng (6 câu); đoạn lockout/offline viết lại thành 5 câu, bỏ nhãn in nghiêng. |
| 12 | Xong | IV.D: câu theo gợi ý. |
| 13 | Xong | VI.D: bỏ câu mở và bỏ danh sách; ba đoạn có đầu đề in nghiêng (Unit and integration tests, API scenarios, Detection scenarios), đoạn kịch bản gộp với đoạn giải thích hai lần chỉnh. |
| 14 | Xong | VI.F: không còn câu mở công thức và chuỗi First/Second/...; thêm nhãn `sec:limits`. |
| 15 | Xong | Caption Fig. 1 theo gợi ý. |
| 16 | Xong | Caption Fig. 2 theo gợi ý. |
| 17 | Xong | Caption Fig. 4 theo gợi ý. |
| 18 | Xong | Caption Fig. 5 theo gợi ý. |
| 19 | Xong | Caption Fig. 6 theo gợi ý. Caption Fig. 3, Fig. 7, Fig. 8, Fig. 9 cũng viết thành câu đầy đủ. |
| 20 | Xong | VI.A: 480 dòng, 5 cột đặc trưng + 1 cột nhãn, sinh bởi `sql/02_data_v1.sql` của nhóm (2026); lý do không dùng bộ công khai: không bộ nào ghi thời gian mở cửa, thay đổi khối lượng và thẻ của một phiên tủ khoá; TON_IoT [moustafa2021toniot] chỉ được trích trong câu lý do này (đã bỏ khỏi Related Work). Đã kiểm: bảng `PublicSession` (5 cột đặc trưng + `label`, thêm `public_id`, `sent` không dùng), CTE 480 dòng, nhãn theo `n % 6`; `ml.log` xác nhận rows=480, 80 mỗi lớp. |

## Bảng 4 và quyết định của nhóm
- Dòng 1 (phương án dự phòng): abstract, bảng đóng góp, VI.C (đoạn cuối mới), VI.F và kết luận đều nói tầng luật là đóng góp chính, điểm rủi ro học máy là tín hiệu phụ, chỉ nên tin sau khi huấn luyện và kiểm lại trên phiên thật. Thực nghiệm học máy giữ nguyên số.
- Dòng 2: hình đánh giá hai panel (a) F1, (b) ma trận nhầm lẫn IBk, bảng xuống phụ lục (T2 vẽ `images/ml-eval.pdf`).
- Dòng 5: các đoạn III.A (7 câu), V Monitoring and user interface (6 câu), VI.E (6 câu và 5 câu), kết luận (6 câu).
- Dòng 6: kết luận chỉ giữ hai số (0.1 s và F1 0.977), nhận định: luật xử lý các trường hợp danh tính (sai người, mất thẻ, mở từ xa giả), học máy là tín hiệu phụ khi có dữ liệu thật.
- (a) Mục V: "The interface is in English, while technical codes such as slot codes, card UIDs and status values are shown as they are."
- Hình: preamble có `\input{figs/colors.tex}` sau `\usepackage{tikz}`; Fig. 1, 3, 4, 5, 6 dùng `\input{figs/fig-*.tex}`; Fig. 7 tách thành `images/ui-user.png` (`fig:ui-user`) và `images/ui-staff.png` (`fig:ui-staff`), rộng 0.9\linewidth và tối đa 0.42\textheight. Lời cảm ơn nhắc "diagrams of Fig. 1 to Fig. 6 and the chart of Fig. 9".

## Sửa thêm (ngoài Bảng 3, để khớp mã nguồn)
- III.F Booking Lifecycle viết lại theo v7.1 (`sql/05_auto_checkin.sql`, có trong `sql/build-order.txt`): đặt chỗ không ai check-in thì tự bắt đầu khi hết giữ chỗ (`AUTO_CHECK_IN`), không hoàn tiền; phiên chưa từng mở kết thúc ở hạn + thời gian ân hạn là `NO_SHOW` không phạt trễ; luật 3 lần no-show trong 7 ngày vẫn còn (`03_v2_v3.sql`, THROW 50031). Bài cũ còn viết "no-show nothing" ở 15 phút. **Cho T2**: mũi tên "cancel / no-show (15 min)" trong `figs/fig-state.tex` nên khớp với điều này (hình hiện có "(AUTO_CHECK_IN)" nên có lẽ đã sửa; nhờ kiểm lại).
- Bảng kịch bản dùng gói `array` và cột `\raggedright` (hết Overfull của bảng này).
- VI.A: thêm câu nêu commit dùng để đo bằng macro `\measurecommit` (13ba35f), định nghĩa trong preamble.

## Số liệu đã dùng (đếm trên cây hiện tại, HEAD 13ba35f, 2026-11-14)
- Java: `find src/java -name '*.java' | wc -l` = 89; dòng vật lý (kể cả comment, dòng trống) `find src/java -name '*.java' | xargs cat | wc -l` = 11 736, viết "about 11 700 lines ... in 89 source files". Số 88 cũ lấy cùng cách trong `docs/paper/evidence/code-stats-2.log` ("all src/java *.java: files=88 lines=11384").
- JSP: `find web -name '*.jsp' | wc -l` = 22 (thêm `lockerSession.jsp` so với 21).
- `@Test`: `grep -rh '@Test' test | wc -l` = 83 phương thức trong 14 lớp (khớp số của cô).
- Học máy: lấy từ `docs/paper/evidence/ml.log` (không đổi số nào).

## Các mục CHECK-FINAL còn lại (agent kiểm chứng cập nhật)
1. `\newcommand{\measurecommit}{13ba35f}`: đặt commit cuối.
2. Abstract "All automated tests and replayed detection scenarios passed": chỉ đúng nếu lần chạy cuối qua hết.
3. Mục V: 89 tệp Java, ~11 700 dòng, 22 JSP; T6 đang dịch giao diện nên có thể đổi.
4. Caption `fig:ui-user`, `fig:ui-staff`: khớp với ảnh tiếng Anh cuối của T2 (caption hiện không ghi số cụ thể trên ảnh).
5. VI.A câu "...refer to commit \measurecommit": chỉ đúng nếu ml.log, đo thời gian đáp ứng và test được chạy lại trên commit đó; nếu không, ghi commit của từng log.
6. VI.D: 83 test, "all 83 passed and none was skipped" theo lần chạy TestNG cuối (cô chạy được 47/47 test không cần SQL Server).
7. VI.D newman: 18 kịch bản, 2 min 27 s, 221 requests, 472 assertions theo lần chạy cuối.

## Việc không làm được / ghi chú cho agent khác
- Không còn dấu gạch trong phần thân, nhưng danh mục tài liệu vẫn in en dash từ bib: số trang (`pages = {2347--2376}`) và tiêu đề [1] "... Solution -- The Results ...". T1 không được sửa bib; T3 nên xem (ví dụ đổi tiêu đề [1] thành dấu hai chấm).
- Caption bảng giữ kiểu tiêu đề IEEE (title case, đặt trên bảng), chưa đổi thành câu; quy ước "caption là câu" của cô chỉ nêu ví dụ cho hình.
- Overfull 24 pt trong `figs/fig-state.tex` (T2).

## Vòng 2: tích hợp tài liệu tham khảo của T3

- Khối `filecontents` của `smartlocker-10p.tex` thay bằng nội dung `docs/paper/refs-additions.bib`, tính từ mục
  `@article{alfuqaha2015iot` đến hết (bỏ các dòng chú thích `%` ở đầu tệp, giữ dòng chú thích ngăn cách "New works").
  Vẫn giữ vỏ `filecontents` và CRLF. 22 khoá cũ và 5 khoá mới, DOI in qua `note = {doi: ...}`.
- Trích dẫn mới (câu theo `refs-notes.md`, viết lại cho hợp văn phong; không gạch ngang, không để hình/bảng làm chủ ngữ):
  - II, đoạn "Smart and parcel lockers" (5 câu): `zhang2025parcel` (bài tổng quan: phần lớn nghiên cứu tối ưu vị trí tủ
    và định tuyến, chỉ một bài về an toàn và an ninh), `ciesla2023parcel` (khảo sát người dùng ở Ba Lan: ứng dụng riêng,
    cỡ ô khớp kiện, vị trí trạm); câu cuối nối với đặt ô trên bản đồ và giá theo cỡ ô.
  - II, đoạn "Anomaly detection" (6 câu): `demedeiros2023anomaly` (đa số là mô hình học, dữ liệu có nhãn hiếm),
    `shahin2025twostage` (hai tầng: mô hình sinh rồi gradient boosting, 99.14% trên N-BaIoT), `arp2024pitfalls` (30 bài,
    mỗi bài ít nhất ba trong mười lỗi, gồm sampling bias và lab-only evaluation) ghép vào câu Sommer và Paxson; câu kết:
    SmartLocker chưa có phiên thật có nhãn nên tầng một là luật tường minh ở máy chủ, mô hình học chỉ thêm điểm rủi ro.
  - VI.F: `arp2024pitfalls` (kết quả phân loại chịu sampling bias và lab-only evaluation vì mọi phiên là tổng hợp).
- Biên dịch lại trong `scratchpad/t1-build` (lần này với ảnh và hình thật của T2: `ui-user.png`, `ui-staff.png`,
  `ml-eval.pdf`, `figs/*.tex`): không lỗi, bibtex không cảnh báo, không trích dẫn/tham chiếu chưa định nghĩa, không còn
  Overfull (T2 đã sửa `fig-state.tex`). 13 trang; danh mục tràn 6 mục ([22] đến [27]) sang trang 13.
- Thứ tự IEEE: số trích dẫn tăng dần theo lần xuất hiện đầu tiên ([1] đến [27]); TON_IoT là [22] (chỉ trích ở VI.A).
  Rà văn bản PDF: dấu en dash trong danh mục chỉ còn ở khoảng trang (pp. a–b, kể cả 15:1–15:58); phần thân không có.
  Tiêu đề [1] đã thành dấu hai chấm.
- Không đổi: mục "Ứng viên chưa dùng" của T3 (bài IEEE chưa kiểm được trên trang nhà xuất bản) không đưa vào bài.
- Theo yêu cầu bổ sung của điều phối (sau khi T2 xong hình):
  - Caption `fig:ui-staff` chỉ tả phần có trên ảnh: ô 11 cảnh báo chưa xử lý, 0 thiết bị mất kết nối (10/10 trực tuyến),
    thẻ cảnh báo theo loại, và cảnh báo #119 `OVERDUE_ESCALATED` (ngăn CANT-A A12, trễ 50 giờ, phụ phí 320 000 VND đã thu,
    còn nợ 128 500 VND). Bỏ "slots, audit-chain status, revenue".
  - Caption `fig:ui-user` khớp ảnh: bảng khu vực của bản đồ (23/27 ngăn trống, dãy CANT-A của LOCKER-01, 2 ngăn khoá quá
    hạn, 1 ngăn có cảnh báo) và xác nhận đặt ngăn B07 (CANT-B, cỡ M, gói 2 giờ, mật mã, trừ ngay 6 500 VND, quy tắc hoàn
    tiền, tự bắt đầu và phụ phí trễ).
  - Caption Fig. 6: kết quả vẽ bằng khung viền dày, màu san hô khi có cảnh báo và màu bạc hà khi không (bỏ "shaded").
  - Caption Fig. 9 không nhắc trục y (ảnh hiện tại trục bắt đầu từ 0).
  - Lưu ý: hai ảnh `ui-*.png` hiện vẫn là giao diện tiếng Việt, trong khi mục V ghi giao diện tiếng Anh. Đã thêm
    CHECK-FINAL: chụp lại bằng giao diện tiếng Anh và kiểm lại mọi con số trong hai caption.
  - Biên dịch lại với ảnh thật: không lỗi, không Overfull, không trích dẫn/tham chiếu chưa định nghĩa, 13 trang; đã xem
    các trang 7 đến 10 (Fig. 6 đến Fig. 9), bố cục ổn.
- Ghi chú: bài giờ dài 13 trang (bản nộp trước 11 trang); nếu cần giữ 12 trang thì có thể thu ảnh `ui-*` (đang tối đa
  0.42\textheight mỗi ảnh) hoặc hình `ml-eval`.
