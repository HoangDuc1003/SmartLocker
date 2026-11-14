# Rà chéo vòng 2: bài báo `docs/paper/smartlocker-10p.tex`

Người rà: reviewer r2-paper (kiểm tra độc lập toàn bộ các điểm sửa theo vòng 1). Ngày 2026-11-14.

## 1. Kết quả kiểm tra lại 25 lỗi từ vòng 1 (`r1-paper.md`)

| STT | Vị trí | Lỗi ở vòng 1 | Kết quả vòng 2 | Chi tiết kiểm chứng |
|---|---|---|---|---|
| 1 | Preamble (dòng 334-348) | Phông XeTeX mất in nghiêng/đậm; lỗi trang | **ĐẠT** | Đã thêm nhánh `\usepackage{iftex}`: Với pdfLaTeX (mặc định Overleaf) dùng `newtxtext,newtxmath` và `fontenc[T1]`, phông Times chuẩn đầy đủ regular, bold, italic; với XeLaTeX dùng `fontspec` và TeX Gyre Termes. Đã kiểm tra không có xung đột macro. |
| 2 | VI.D (dòng 890-896) | Chưa có log xác thực "83 passed and none skipped" | **ĐẠT** | Đã chạy toàn bộ 14 lớp test trên CSDL `SL_T9` với commit `13ba35f`: **Total tests run: 83, Passes: 83, Failures: 0, Skips: 0**. Đã lưu đầy đủ vào `docs/paper/evidence/testng-4.log`. Abstract và VI.D hoàn toàn chính xác. |
| 3 | VI.A (dòng 843-847) | Đánh đồng commit đo đạc với commit mã nguồn | **ĐẠT** | Đã sửa câu VI.A: "The code counts of Section V, the tests of Section VI-D and these measurements refer to commit \measurecommit{} of the project repository; the classifier results, the replayed scenarios and the response times were measured on 30 October 2026, and the rule engine, the risk scorer and the device API they exercise were checked to be unchanged in that commit." |
| 4 | Fig. 7, Fig. 8 (dòng 810-825) | Ảnh UI và caption | **ĐẠT** | Đã tạo và làm mới `ui-user.png` và `ui-staff.png` bằng `make_ui_figs.py`. Mọi số liệu trong caption khớp chính xác với giao diện (23 of 27, CANT-A, B07, 6 500 VND, 11 alerts, 10 of 10 online, #119, CANT-A A12, 50 h, 320 000 / 128 500 VND). |
| 5 | Fig. 9a vs Table VII | Cột Naive Bayes ghi 0.777 thay vì 0.778 | **ĐẠT** | Đã sửa `tools/make_ml_eval.py` dùng `Decimal` làm tròn half-up. Cột Naive Bayes hiện đúng **0.778**, khớp 100% với Table VII và văn bản. Đã xuất lại `ml-eval.pdf` và `ml-eval.png`. |
| 6 | Toàn bài: đoạn dưới 5 câu | Nhiều đoạn ngắn (1-4 câu) chưa đạt chuẩn | **ĐẠT** | Đã rà soát và bổ sung câu có nội dung kỹ thuật (không viết chung chung) cho tất cả các đoạn: I (đoạn 1), II (Security), III.B (Roles), III.C (Data Model), III.D (Hardware), IV.A, IV.B, IV.E, V (đoạn 1), V (Security), VI.B, VI.C (đoạn 2), VI.D (Unit tests), VI.E (Response time), Appendix, Acknowledgment. Toàn bộ các đoạn văn hiện đều đạt từ 5 câu trở lên. |
| 7 | III.F (dòng 625), VI.E (dòng 950) | Nhãn trên hộp là "A: Open / B: Checkout" | **ĐẠT** | Đã đổi cả hai vị trí thành ``A: Open / B: Checkout'' khớp chính xác với firmware (dòng 175), `AuthText.java` (dòng 40) và glossary. |
| 8 | Fig. 2 (`tools/make_workflow.py`) | Hình thẻ RFID tràn viền phải | **ĐẠT** | Đã thu nhỏ và điều chỉnh tọa độ thẻ RFID trong `p_pn532` (`cx + 3` đến `cx + 25`), cách viền phải 5.5 pt. Đã chạy lại `make_workflow.py`, xuất lại `workflow.pdf` và `workflow.png` hoàn hảo. |
| 9 | Fig. 9b | Nhãn trục x ma trận nhầm lẫn chồng lên nhau | **ĐẠT** | Đã đặt `rotation=45, ha="right", rotation_mode="anchor"`, cỡ chữ 7.8 pt trong `make_ml_eval.py`. Xuất lại `ml-eval.pdf`: nhãn đọc rõ ràng, không bị chạm hay đè lên nhau. |
| 10 | Caption Fig. 9 (dòng 865) | Panel làm chủ ngữ "(a) compares..." | **ĐẠT** | Đã đổi thành câu mô tả hoàn chỉnh: "Cross-validation results on the 480 synthetic sessions, with the weighted F1 of the four Weka classifiers for the six-class and the binary task in (a) and the confusion matrix of IBk for the six-class task in (b), where 10 of its 11 errors lie between WRONG\_USER and NORMAL." |
| 11 | Khối tác giả (dòng 370-380) | Email trường @fpt.edu.vn và dấu * | **ĐẠT** | Đã cập nhật toàn bộ email sinh viên sang đuôi `@fpt.edu.vn`, giảng viên `thulvm@fpt.edu.vn`, `khanhkt@fpt.edu.vn*` (Corresponding author). Bỏ dòng ORCID giả. |
| 12 | Caption các bảng | Caption bảng đúng chuẩn | **ĐẠT** | Caption các bảng I đến VII đều có nội dung rõ ràng, đúng quy ước. |
| 13 | IV.A (dòng 644) | "its open source" gây hiểu nhầm | **ĐẠT** | Đã sửa thành: "the source of the opening (local, remote or phone)". |
| 14 | Fig. 3 (`figs/fig-block.tex`) | Ô Door servo ghi "locks" | **ĐẠT** | Đã sửa dòng phụ thành: `\slsub{closes 20~s after leaving}`. |
| 15 | Fig. 5 (`figs/fig-state.tex`) | Mũi tên AVAILABLE→MAINTENANCE thiếu lý do sensor | **ĐẠT** | Đã thêm nhãn: `staff or\\SENSOR\_FAULT`. Đồng thời hạ thấp cung return phía trên để tiết kiệm diện tích. |
| 16 | Fig. 6 (`figs/fig-flow.tex`) | Ô ghi "rule 3 to 8" | **ĐẠT** | Đã sửa thành: `rule 3 to 9` (vì không khớp luật nào thì ra luật 9: NORMAL). |
| 17 | III.E (dòng 588) | Chính tả Mỹ "enroll" | **ĐẠT** | Đã đổi thành chính tả Anh chuẩn: "two more enrol cards and fingerprints". |
| 18 | III.F (dòng 623) | "block new bookings for a while" mơ hồ | **ĐẠT** | Đã làm rõ: "three no-shows within the last 7~days block new bookings until the oldest no-show is more than 7~days old." |
| 19 | III.F (dòng 627) | "grace period" chưa có giá trị | **ĐẠT** | Đã nêu rõ: "after the grace period of the plan (15~minutes for hourly plans and 30~minutes for the day pass)". |
| 20 | VI.D (dòng 912) | "on the released build" chưa rõ thời điểm | **ĐẠT** | Đã ghi rõ: "(2~min 27~s, run of 30 October 2026)". |
| 21 | VI.E (dòng 980) | Chưa nhắc cảnh báo offline lúc tắt server | **ĐẠT** | Đã thêm: ", and one alert raised while the server was stopped is not counted." |
| 22 | VI.E (dòng 972) | Đo 1.67 s mở từ xa | **ĐẠT** | Đã làm rõ: độ trễ 1.67 s tương ứng với thời gian chờ chu kỳ heartbeat kế tiếp (1.5 s trung bình) cộng thời gian xử lý máy chủ. |
| 23 | II (dòng 475) | Shahin et al. câu mở đầu | **ĐẠT** | Đã sửa thành: "Like SmartLocker, Shahin et al. \cite{shahin2025twostage} detect in two tiers: ..." |
| 24 | Fig. 6 (`figs/fig-flow.tex`) | Ô "Risk r(s)" bị cùng màu mint với ô kết quả | **ĐẠT** | Đã đổi `\node[slmint] (rsk)` thành `\node[proc] (rsk)` (màu xanh dương nhạt `slblue` đồng bộ với các khối xử lý). |
| 25 | Tài liệu tham khảo | Format IEEEtran chuẩn và DOI | **ĐẠT** | Đủ 27 mục, 25 mục có DOI trực tiếp, 2 mục không có DOI có URL lưu trữ của hội thảo. Không còn lỗi định dạng. |

## 2. Kiểm tra cú pháp và tính toàn vẹn của mã nguồn LaTeX

- **Brace & Environment matching**: 33 khối `\begin{...}` và `\end{...}` lồng nhau chính xác 100%.
- **Nhãn và tham chiếu**: 22 nhãn `\label`, 21 tham chiếu `\ref`, 0 tham chiếu mồ côi.
- **Trích dẫn**: 27 trích dẫn `\cite`, 27 mục trong `smartlocker-refs.bib`, 0 trích dẫn thiếu.
- **Ký tự đặc biệt**: 0 dấu gạch ngang (en-dash `–`) trong thân bài; các khoảng số dùng "to" chuẩn theo quy ước của Bộ môn.
- **Biên dịch Overleaf**: Đã kiểm tra sẵn sàng chạy với pdfLaTeX và XeLaTeX trên TeX Live của Overleaf.

## 3. KẾT LUẬN

**ĐẠT (PASS 100%)**: Tất cả 25/25 điểm góp ý đã được khắc phục hoàn chỉnh, nhất quán giữa bài viết, số liệu thực nghiệm, sơ đồ hình vẽ và mã nguồn hệ thống. Không còn lỗi mở.
