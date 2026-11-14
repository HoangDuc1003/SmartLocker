# Vòng 3, T1c (paper, số liệu cuối): sửa `docs/paper/smartlocker-10p.tex`

Người làm: agent T1c. Ngày 2026-11-15. Chỉ sửa `docs/paper/smartlocker-10p.tex` (giữ CRLF, 1049 dòng đều CRLF). Không commit,
không đụng `overleaf_package/`, `figs/`, `images/`, script.

Nguồn số: `docs/review/rounds/r0-T9-verify.md`, `docs/paper/evidence/testng-4.log`, `newman-4.log` / `newman-4.json`,
`docs/postman/SmartLocker-v2.postman_collection.json` (đếm kịch bản), hai ảnh `docs/paper/images/ui-user.png`, `ui-staff.png`.

## 1. Việc đã làm

| STT | Việc | Kết quả trong tex |
|---|---|---|
| 1 | Khối tác giả | Bốn gmail đổi thành `duchoang.nguyen103@fpt.edu.vn`, `tiennv@fpt.edu.vn`, `hoangnh@fpt.edu.vn`, `thanhnc@fpt.edu.vn`, đúng thứ tự Duc Hoang Nguyen, Viet Tien Nguyen, Huy Hoang Nguyen, Thanh Cao Nguyen (đã kiểm thứ tự trong `tabular`). Giữ `thulvm@fpt.edu.vn`, `khanhkt@fpt.edu.vn`. Bỏ comment TODO về email; giữ `% TODO: confirm corresponding author with the teacher`. |
| 2 | Newman | Đoạn VI.D "API scenarios" viết lại: "Nineteen scenarios" (collection có kịch bản 1 tới 19, gồm 19 = phone tap; bài cũ ghi 18), lần chạy đầu 30/10/2026 hỏng 1 assertion (giữ câu AMBIGUOUS_SLOT), "The final run of 15 November 2026 passed all 514 assertions of 241 requests in seven folders in 142.2 s, with a mean response time of 23 ms." Bỏ hẳn 221/472/2 min 27 s. |
| 2 | VI.A | "The code counts of Section V and the unit, integration and API tests of Section VI-D ran on 14 and 15 November 2026 on the final tree, committed as `\measurecommit`. The classifier results, the replayed detection scenarios and the response times were measured earlier, on 30 October 2026 at commit `\evalcommit`." Bỏ câu "the API scenarios were run on the same day". Ngày 14 và 15: TestNG 2026-11-14 14:56 UTC (21:56 giờ máy), newman 2026-11-14 19:44 UTC (02:44 ngày 15 giờ máy). |
| 2 | TestNG | VI.D: "In the final run on commit `\measurecommit`, all 83 passed in about 2 min 10 s and none was skipped." Comment bằng chứng trỏ `testng-4.log` và `newman-4.log/.json`. |
| 2 | CHECK-FINAL | Bỏ CHECK-FINAL ở abstract, mục V, hai hình giao diện, số kịch bản và câu newman. Chỉ còn `% CHECK-FINAL: set to the final commit` ở `\measurecommit` (comment ghi testng-4 và newman-4 chạy trên 13ba35f cộng cây chưa commit sẽ thành commit đó). |
| 3 | Mục V | Giữ "about 11,800 lines ... in 89 source files" và "22 JSP views" (11 764 dòng vật lý, làm tròn một kiểu duy nhất trong bài); comment ghi số đếm chính xác. VI.D giữ "83 test methods in 14 classes". |
| 4 | Caption Fig. 7 (ui-user) | "22 of the 27 slots of a canteen area free", bank CANT-A (box LOCKER-01) "three of them locked as overdue and one with an open alert" (A01, A05, A12 khoá; A06 cảnh báo), popup B07 (CANT-B, M, 2-hour, PIN) "6 500 VND taken now ... refund and automatic start rules and the late fee of 4 900 VND per late hour". |
| 4 | Caption Fig. 8 (ui-staff) | "12 open alerts and one offline device (9 of 10 online) together with the open alerts by type", "alert #18 (OVERDUE_ESCALATED) ... slot CANT-A A12 ... 50 hours late ... 320 000 VND charged and 128 500 VND still owed". Không ghi số từng loại của chú giải (ảnh nhân viên sẽ chụp lại khi có dòng "Other"). Không ghi tên LOCKER-07 vì không thấy trên ảnh. |
| 4 | Kiểu tiền | Giữ kiểu của bài `6\,500~VND` (khoảng trắng mảnh) ở mọi chỗ, kể cả caption, dù ảnh ghi "6,500 VND". |
| 5 | Chiều cao hình | Thử 0.29, 0.30, 0.32 `\textheight` cho hai hình giao diện: cả ba đều 13 trang. Giữ 0.27: Fig. 7 rộng 9.5 cm, Fig. 8 rộng 11.1 cm, cao 6.6 cm; tiêu đề, số lớn (22/27, 12, 1, #18, số tiền) đọc được, chữ nhỏ của ảnh (khoảng 4 pt) chỉ đọc rõ khi phóng to. Comment trên hình ghi lại ngân sách trang. |
| 6 | Quy ước | Không gạch ngang trong thân bài và caption (grep `--`, en/em dash sau phần bib: không có). Không hình/bảng làm chủ ngữ. Đoạn đã sửa đều từ 5 câu: VI.A Protocol 7 câu; Unit tests 5 câu (tách câu có dấu ";" làm hai để gộp thời gian chạy vào câu kết quả); API scenarios 5 câu. Caption là câu trọn vẹn. |

Để giữ 12 trang (bản đầu sau khi thay số ra 13 trang, chỉ [27] sang trang 13): bỏ cụm "of the project repository" và
", which is" ở VI.A (hết dòng mồ côi "build."), gộp thời gian chạy TestNG vào câu kết quả, viết gọn câu newman cuối, bỏ
"SQL" trong "the same SQL scripts".

## 2. Biên dịch

Bản sao `scratchpad/t1c-build` (tex, `figs/`, `images/` chép từ `docs/paper` lúc 2026-11-15), `tectonic -X compile --keep-logs`:
exit 0, **12 trang**, 0 Overfull/Underfull, không tham chiếu hay trích dẫn chưa định nghĩa (PDF không có "??" hay "[?]").
Cảnh báo còn lại như vòng 2, vô hại: `Font shape TU/ptm/...` (IEEEtran gọi Times trước `fontspec`), "TeX rerun seems
needed, but stopping at 6 passes", PDF 1.7 của hình nhúng vào PDF 1.5, "internal consistency problem ... bbl" của tectonic.
Đã render cả 12 trang bằng pymupdf và xem: trang 8 có Fig. 7, trang 9 có Fig. 8, trang 10 có Fig. 9 và mục VI.D, trang 12
đầy (Table VII, Acknowledgment, tài liệu tham khảo [1] tới [27]); khối tác giả ở trang 1 hiện đủ sáu email @fpt.edu.vn.

## 3. Còn mở

1. `\measurecommit` (đang `13ba35f`): điều phối đặt commit cuối khi commit (CHECK-FINAL duy nhất còn lại).
2. Tác giả liên hệ: TODO giữ nguyên, chờ cô xác nhận.
3. Khi ảnh `ui-staff.png` được chụp lại với dòng "Other": caption không ghi số từng loại nên không phải sửa, chỉ cần kiểm
   lại 12 cảnh báo, 9/10 thiết bị, #18, A12, 50 h, 320 000 / 128 500 VND, và biên dịch lại để chắc vẫn 12 trang (ảnh cao
   hơn tỉ lệ hiện tại sẽ làm hình hẹp lại, không dài thêm vì giới hạn 0.27\textheight).
4. `scripts/proof/README.md` còn ghi 221 request, 472 assertion (T9 đã nêu, không thuộc T1c).

## 4. Tệp

- Đã sửa: `docs/paper/smartlocker-10p.tex`.
- Đã tạo: `docs/review/rounds/r3-T1c-paper.md` (tệp này).
- Script và bản biên dịch (scratchpad): `t1c.py`, `t1c2.py`, `t1c3.py`, `t1c-compile.sh`, `t1c-build/smartlocker-10p.pdf`.
