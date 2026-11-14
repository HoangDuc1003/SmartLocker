# Rà chéo vòng 3 (cuối): bài báo `docs/paper/smartlocker-10p.tex`

Người rà: agent rà chéo r3 (chỉ đọc repo, chỉ ghi tệp này). Ngày 2026-11-15.
Không dùng `r2-paper.md` (không tin cậy). Đối chiếu với `teacher-feedback-2026-11-14.md`, `r1-paper.md` (25 lỗi),
`r2-T1b-paper.md`, `r3-T1c-paper.md`, `r2-T2b-figures.md`, `r0-T9-verify.md`, `r1-T9b-verify.md` và `docs/paper/evidence/*`.

Cách làm: chép `smartlocker-10p.tex`, `figs/`, `images/` sang `scratchpad/r3-paper`, `tectonic -X compile --keep-logs`
(exit 0), xuất 12 trang PNG 110 dpi bằng pymupdf và xem từng trang, phóng to Fig. 2, Fig. 7 (ảnh gốc), Fig. 8; trích
văn bản PDF để grep (gạch ngang, hình/bảng làm chủ ngữ, số câu mỗi đoạn bằng script). Đối chiếu số với `ml.log`,
`latency.log`, `scenarios.log`, `testng-4.log`, `newman-4.log`, `newman-5.log`, collection Postman, firmware 4.3,
`RuleEngine`, `AlertService`, `KioskApi`, `04_phone.sql`, `SecurityFilter`, đếm lại tệp trong cây làm việc.

## 1. Bảng kiểm

### 1.1 Góp ý của cô

| Dòng | Nội dung | Kết quả | Bằng chứng |
|---|---|---|---|
| 2.1 | Giao diện tiếng Anh, câu mục V | ĐẠT | V: "The interface is in English, while technical codes ... are shown as they are". Fig. 7, Fig. 8 là ảnh giao diện tiếng Anh (Confirm booking, Book and pay, Open alerts, Offline devices). Chỉ còn tên và mô tả khu (dữ liệu) tiếng Việt, xem lỗi 9. |
| 2.2 | SRF05 tự khoá, III.D, Fig. 2, Fig. 3 | ĐẠT | III.D đúng câu đề nghị + phím D; khớp `DOOR_OPEN_MS = 20000`, `DOOR_OPEN_MAX_MS = 120000`. Fig. 2 "SRF05: presence, backlight, auto-lock"; Fig. 3 "SRF05 ultrasonic / presence, backlight, auto-lock", "Door servo / closes 20 s after leaving". |
| 2.3 | 83 test, 89 Java, 22 JSP, commit đo | ĐẠT (còn lỗi 1, 4) | Đếm lại: 89 tệp Java, 11 765 dòng ("about 11 800"), 22 JSP, 83 `@Test` trong 14 lớp, 14 test RuleEngine. VI.A ghi `\measurecommit` và `\evalcommit` (da95f43, 2026-10-28, commit kế tiếp 2026-11-04, nên đúng là bản của 30/10). |
| 3.1 | III.D SRF05 | ĐẠT | Đúng câu đề nghị. |
| 3.2 | Khối tác giả | ĐẠT (phần dấu * chờ cô) | Không ORCID; sáu email @fpt.edu.vn, thứ tự tên đúng; giữ `% TODO: confirm corresponding author with the teacher` theo quyết định. |
| 3.3 | Abstract ít số | ĐẠT | Chỉ còn "four" và "about 0.1 s"; không gạch ngang. |
| 3.4 | Khoảng số không dùng en dash | ĐẠT | Grep PDF: en/em dash chỉ còn ở số trang tài liệu tham khảo. "Built-in" ở Table II, NORMAL số 9 ở Table III. |
| 3.5 | Đóng góp thành bảng | ĐẠT | Table I (No., Contribution, Where it is shown), câu dẫn đúng đề nghị, không dòng in đậm. |
| 3.6 | III.A Fig. 2 | ĐẠT | "In the end-to-end workflow (Fig. 2), ...". |
| 3.7 | III.E Fig. 4 | ĐẠT | Đúng câu đề nghị. |
| 3.8 | IV.C Fig. 6 | ĐẠT | Gộp: "..., following the decision flow of Fig. 6." |
| 3.9 | V User interface | ĐẠT | Gộp vào đoạn "Monitoring and user interface" (6 câu). |
| 3.10 | VI.B đoạn dẫn | ĐẠT | Đoạn dẫn đúng đề nghị; "IBk achieves ... (Fig. 9a)". |
| 3.11 | VI.E | ĐẠT | Đúng hai câu đề nghị. |
| 3.12 | IV.D câu chủ đề | ĐẠT | Đúng câu đề nghị. |
| 3.13 | VI.D "three levels" | ĐẠT | Đã bỏ. |
| 3.14 | VI.F First... Fourth | ĐẠT | Đúng cấu trúc đề nghị. |
| 3.15-3.19 | Caption Fig. 1, 2, 4, 5, 6 | ĐẠT | Đúng câu đề nghị (Fig. 6: "boxes with a thick border, coral ... mint", khớp hình). |
| 3.20 | VI.A Dataset | ĐẠT | 480 dòng, 5 cột đặc trưng + 1 cột nhãn, `sql/02_data_v1.sql` (2026), lý do; TON_IoT [22] được dùng làm lý do. Bộ sinh 480 dòng không đổi sau 13ba35f (diff 02 chỉ dịch chữ). |
| 4.1 | Học máy là tín hiệu phụ | ĐẠT | Abstract, I, Table I, VI.C, VII. |
| 4.2 | Hình cho đánh giá | ĐẠT | Fig. 9 (a) cột F1 có số in đậm, (b) ma trận IBk; Table VII ở phụ lục. |
| 4.3 | Màu, cỡ chữ, Fig. 6, Fig. 7 | ĐẠT | `figs/colors.tex` pastel, không tím/xám; mũi tên chạm mép; Fig. 6 rộng; UI tách Fig. 7 / Fig. 8. Lỗi nhỏ 10. |
| 4.4 | Tài liệu mới, DOI | ĐẠT | Sáu bài 2023-2025 ([5], [6], [7], [15], [16], [18]); mọi mục in DOI trừ [21], [27] (không có DOI, in URL). |
| 4.5 | Đoạn ngắn | ĐẠT cho các đoạn cô nêu | Còn hai đoạn 4 câu (lỗi 7). |
| 4.6 | Kết luận | ĐẠT | Hai số (0.977, about 0.1 s) và nhận định luật/học máy. |

### 1.2 Lỗi vòng 1 (`r1-paper.md`)

| Lỗi | Kết quả | Ghi chú |
|---|---|---|
| 1 Phông | ĐẠT | PDF nhúng TeXGyreTermes Regular/Bold/Italic, TeXGyreCursor; nghiêng, đậm, small caps hiện đủ. |
| 2 TestNG | ĐẠT (lỗi 4) | `testng-4.log`: 83/83, 0 skip, 2 m 10.5 s. |
| 3 Ngày đo | ĐẠT | VI.A tách `\measurecommit` / `\evalcommit` và nói rõ phần đã đổi. |
| 4 Ảnh tiếng Anh | ĐẠT | Chú giải donut đủ 5 dòng ("Other (3 types) 3"). |
| 5 0.777/0.778 | ĐẠT | Fig. 9a ghi 0.778. |
| 6 Đoạn ngắn | ĐẠT phần lớn | Còn 2 đoạn 4 câu (lỗi 7). |
| 7 Checkout | ĐẠT | Khớp `AuthText.java:45`, firmware dòng 175. |
| 8 Thẻ RFID tràn ô | ĐẠT | Phóng to 300 dpi: thẻ nằm trong ô. |
| 9 Nhãn trục Fig. 9b | ĐẠT | Xoay 45°, không chồng. |
| 10 Caption Fig. 9 | ĐẠT | |
| 11 Email | ĐẠT | Dấu * chờ cô (TODO). |
| 12 Caption bảng | Giữ kiểu IEEE (quyết định) | |
| 13-19, 21, 23-25 | ĐẠT | Kiểm từng câu/hình. |
| 20 Ngày newman | ĐẠT một phần | Có ngày, nhưng số thời gian là của lần chạy không phải cuối (lỗi 1). |
| 22 1.67 s | ĐẠT (ghi rõ không có log) | Lỗi 12. |

### 1.3 Quy ước, số liệu, hình, tài liệu, trang

| Mục | Kết quả |
|---|---|
| Không gạch ngang trong thân bài/caption | ĐẠT |
| Không hình/bảng làm chủ ngữ | ĐẠT (grep "Fig./Table ... shows/gives/lists/compares": không có) |
| Không câu mở chủ đề chung chung | ĐẠT |
| Đoạn từ 5 câu | 2 đoạn 4 câu (lỗi 7); câu dẫn danh sách IV.D giữ được |
| Caption câu đầy đủ | ĐẠT (hình); bảng giữ kiểu IEEE |
| Abstract ít số; Table I không in đậm | ĐẠT |
| Ngưỡng 50 g, 300 s, 30 min, 60 s, τ = 0.80, 3 s, 90 s/15 s, 120 s, 5 lần/5 phút (kênh PHONE riêng, `Auth_Log`) | Khớp mã |
| Vòng đời v7.1, giá Table IV (4 900, 6 400, 42 300) | Khớp |
| Số học máy (0.977/0.975, 0.948/0.939, 0.856/0.848, 0.778/0.852, ma trận 73/7/3/77/79/1, RF 17/8, NB 80/400, thời gian) | Khớp `ml.log` |
| Table V, Table VI, 104.6 s, 97-98 s, 110 s, 906 s, 125.5 s | Khớp `scenarios.log`, `latency.log` |
| 19 kịch bản Postman, 241 request, 514 assertion | Khớp collection, `newman-4/5.log`; thời gian và trung bình sai lần chạy (lỗi 1) |
| Caption Fig. 7 (22/27, CANT-A LOCKER-01, A01/A05/A12 khoá, A06 cảnh báo, B07 CANT-B M 2 hours PIN 6 500, 4 900/giờ) | Khớp ảnh |
| Caption Fig. 8 (11 open, 1 offline, 9/10, #18, CANT-A A12, 50 h, 320 000 / 128 500) | Khớp ảnh |
| Hình: pastel, không tím/xám, mũi tên chạm mép, không chồng | ĐẠT (icon Fig. 2 màu navy, không xám) |
| Tài liệu: 27 mục, không `[?]`, DOI in đủ | ĐẠT |
| 12 trang, 0 Overfull/Underfull, không tham chiếu chưa định nghĩa | ĐẠT |
| Nhánh pdfLaTeX của bộ chọn phông | ĐẠT: `\usepackage{iftex}` + `\ifPDFTeX\else ... \fi` cân ngoặc, nhánh pdfLaTeX không nạp gì; tex chỉ có ký tự ASCII; `filecontents*[overwrite]` cần LaTeX 2019-10+ (Overleaf có). Chưa chạy thử pdflatex (máy không có). |

## 2. Danh sách lỗi

| STT | Vị trí | Lỗi | Mức độ | Đề nghị sửa |
|---|---|---|---|---|
| 1 | VI.D "API scenarios", dòng 910-911; comment dòng 360-362 và 896-897 | Bài gọi lần chạy newman-4 (02:44 ngày 15/11, 142.2 s, trung bình 23 ms) là "the final run". Lần chạy cuối thật là `newman-5.log` (05:49 ngày 15/11, sau các sửa của T10): 241 request, 514 assertion, 0 lỗi, **2 m 21.2 s = 141.2 s, trung bình 35 ms**. Cô yêu cầu số khớp lần chạy cuối. | trung bình | Dòng 910-911: "The final run of 15 November 2026 passed all 514 assertions of 241 requests in seven folders in 141.2~s, with a mean response time of 35~ms." Comment dòng 897 và 361: thay `newman-4.log` bằng `newman-5.log` (2 min 21.2 s, avg 35 ms). |
| 2 | Table I dòng 438; VI.D "Detection scenarios" dòng 913 | "credentials signed with a per-device key" và "session uploads signed with the key of the real box" sai kỹ thuật: hộp chỉ gửi khoá trong header `X-API-Key` (firmware dòng 380, `SecurityFilter` dòng 148), không có chữ ký hay HMAC. Chữ "signed" ngụ ý bảo vệ toàn vẹn thông điệp mà hệ thống không có (VI.F còn nói HTTP thường, `setInsecure`). | trung bình | Dòng 438: "and an ESP32 box that only forwards credentials, authenticated with a per-device API key;". Dòng 913: "A device simulator sends heartbeats, credentials and session uploads authenticated with the key of the real box LOCKER-01, ...". |
| 3 | `docs/paper/SmartLocker_Paper_Overleaf.zip`, `overleaf_package/` (chưa theo dõi) | Hai gói Overleaf là bản 2026-11-14 22:41 (`main.tex` 72 595 byte), chính là bản T1b xác định có nội dung bịa (email, câu không căn cứ), kèm `ui-user.png`, `ui-staff.png`, `ml-eval.pdf`, `workflow.pdf` cũ; zip không có `figs/`. `README_OVERLEAF.txt` hướng dẫn tải zip này lên Overleaf, nên rất dễ nộp nhầm bản cũ. | trung bình | Xoá cả hai (hoặc dựng lại từ `docs/paper` sau khi chốt: `smartlocker-10p.tex`, `figs/*.tex`, `images/{workflow.pdf,ml-eval.pdf,ui-user.png,ui-staff.png}`), và không đưa vào commit nộp. |
| 4 | VI.A dòng 846-848, VI.D dòng 903-904 | `testng-4.log` chạy lúc 21:56 ngày 14/11, trước các sửa của T10 (`MaintenanceDao.java`, `sql/02,03,04,06`). Các sửa đó chỉ là chữ và một null-check, nhưng câu "all 83 passed ... on commit `\measurecommit`" sẽ nói về một cây khác cây đã chạy. | thấp | Trước khi đặt `\measurecommit`, chạy lại `sh scripts/test.sh` trên commit cuối (khoảng 2 phút, DB `SL_*` dựng với `-TestSetup`), lưu `evidence/testng-5.log`, sửa comment dòng 896. Nếu không chạy lại: "In the final run, on the tree of commit \texttt{\measurecommit} before its last text-only fixes, all 83 passed ...". |
| 5 | VI.A dòng 851, VI.D dòng 900 và 906 | "phone tap" được nhắc ba lần nhưng mục III không giới thiệu (PN532 giả lập thẻ NFC chứa liên kết trang điện thoại với mã dùng một lần). | thấp | Thêm vào cuối III.D (Device Protocol), trước câu "A card presented at the wrong box": "The PN532 also emulates an NFC tag, so a phone that taps the box opens the phone page with a one-time token that the box received in its heartbeat." |
| 6 | VI.D dòng 907 | "no-show" trong danh sách kịch bản: kịch bản 6 của collection là "No-show: checked in automatically after 15 minutes, no refund (v7.1)", tức tự check-in, không phải NO_SHOW. | thấp | "... the five-try lockout, automatic check-in, overdue lock, ...". |
| 7 | VI.B dòng 856-862; Acknowledgment dòng 1039-1044 | Hai đoạn chỉ 4 câu (quy ước 5 câu). | thấp | VI.B: thêm sau "...in the appendix.": "IBk and Random Forest rank first and second on both tasks, whereas Naive Bayes overtakes J48 in the binary task." (đúng theo Table VII: sáu lớp IBk > RF > J48 > NB; nhị phân 0.975 > 0.939 > 0.852 > 0.848). Acknowledgment: tách câu thứ hai thành hai câu: "... to edit and shorten the English text and to check the \LaTeX{} source. The assistant also drew the diagrams of Fig. 1 to Fig. 6 and the chart of Fig. 9." |
| 8 | Fig. 9b | Nhãn viết tắt "SUSP._SPOOF" không giải thích trong caption. | thấp | Thêm cuối caption Fig. 9: "..., where 10 of its 11 errors lie between WRONG\_USER and NORMAL and SUSP.\_SPOOF stands for SUSPECTED\_SPOOF." |
| 9 | Fig. 7 (ảnh `ui-user.png`) | Tên khu "Căng tin KTX khu A" và mô tả "Căng tin cạnh ký túc xá khu A" là dữ liệu tiếng Việt; tên riêng giữ được, nhưng dòng mô tả là chữ thường, người chấm có thể coi là giao diện chưa dịch. | thấp | Hoặc đổi mô tả khu CANT trong seed sang tiếng Anh ("Canteen next to dormitory A") rồi chụp lại, hoặc thêm vào caption: "(area names are data and keep their Vietnamese place names)". |
| 10 | Fig. 8 | Hai panel lệch đỉnh, panel cảnh báo nhỏ và nhiều khoảng trắng; chữ nhỏ trong ảnh khoảng 4 pt. | thấp | Trong `tools/make_ui_figs.py` căn đỉnh hai panel và cắt sát panel #18 (bỏ khoảng trắng dưới dòng "Amount owed") để hình rộng hơn trong cùng 0.27\textheight. |
| 11 | Fig. 2 (`workflow.pdf`) | Ô "SG90 servos": mã SG90 không có trong firmware, README hay Table II ("Servo"). `workflow.pdf` dùng Helvetica không nhúng (PDF có `Helvetica`, `Helvetica-Bold` loại n/a), không hợp chuẩn IEEE PDF eXpress. | thấp | Nếu không chắc mẫu servo thì đổi nhãn thành "Servos: open, auto-lock". Xuất `workflow.pdf` với phông nhúng (trong pymupdf dùng `fontfile` Arial/Helvetica TTF thay `helv`). |
| 12 | VI.E dòng 952-954 | Số 1.67 s (20 lần mở) vẫn không có log, chỉ được nói rõ trong bài. | thấp (đã biết) | Lưu `evidence/e2e-phone.log` nếu còn số liệu; nếu không thì giữ câu hiện tại. |
| 13 | Khối tác giả dòng 374 | Dấu * và TODO chờ cô xác nhận. | thấp (đã biết, quyết định nhóm) | Xoá TODO sau khi cô chốt. |
| 14 | Commit nộp | `docs/paper/figs/`, `images/ui-user.png`, `ui-staff.png`, `ml-eval.pdf`, `ml-eval.png`, `tools/make_ml_eval.py`, `tools/make_ui_figs.py` chưa được theo dõi; thiếu chúng thì tex không biên dịch được từ commit. | thấp (nhắc) | Thêm các tệp này vào commit cuối cùng với tex; `\measurecommit` đặt đúng commit đó (CHECK-FINAL). |

## 3. Các mục đã kiểm và khớp

- Biên dịch: 12 trang, trang 12 đầy (Table VII, Acknowledgment, [1] tới [27]); 0 Overfull/Underfull; cảnh báo còn lại vô
  hại (`TU/ptm` trước `fontspec`, PDF 1.7 nhúng, "rerun ... 6 passes").
- Chỉ còn đúng một `CHECK-FINAL` (`\measurecommit`) và một TODO (tác giả liên hệ), như quyết định.
- `\evalcommit` da95f43 (2026-10-28) là commit cuối trước ngày đo 30/10; câu "Since then ..." khớp các thay đổi đã biết.
- Fig. 1, 3, 4, 5, 6: pastel, không tím/xám (`figs/colors.tex`), mũi tên chạm mép, chữ đọc được ở 110 dpi, không chồng.
  Fig. 2: icon navy/xanh, thẻ RFID trong ô. Fig. 9: hai panel đọc được, 0.778 đúng.
- Thuật ngữ khớp nhãn giao diện tiếng Anh: "A: Open / B: Checkout", "Confirm booking", "Book and pay", "taken now",
  "Day pass", "Open alerts", "Offline devices".

KẾT LUẬN: CHƯA ĐẠT
