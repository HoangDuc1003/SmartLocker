# Vòng 2, T2b: sửa hình của bài báo theo `r1-paper.md`

Người làm: agent T2b (hình, vòng 2). Ngày 2026-11-15. Không commit gì. Chỉ sửa `docs/paper/figs/**`,
`docs/paper/tools/make_workflow.py`, `docs/paper/tools/make_ml_eval.py` và các ảnh sinh ra
`docs/paper/images/workflow.{pdf,png}`, `docs/paper/images/ml-eval.{pdf,png}`. Không đụng tới `.tex` (T1b) và
`make_ui_figs.py` (T9).

Ghi chú: phiên này bị ngắt giữa chừng vì giới hạn API rồi chạy tiếp. Phần lớn chỉnh sửa đã được làm trước lúc ngắt;
phiên chạy tiếp đã kiểm lại từng sửa đổi so với mã nguồn, sửa hai lỗi còn sót trong `make_ml_eval.py` (xem lỗi 5 và 9)
rồi biên dịch và xem lại các hình.

## 1. Từng lỗi và cách sửa

| Lỗi r1 | Hình | Sửa | Kiểm chứng |
|---|---|---|---|
| 5 | Fig. 9a (`make_ml_eval.py`) | Nhãn trên cột làm tròn half-up: `Decimal(<chuỗi trong ml.log>).quantize(Decimal("0.001"), ROUND_HALF_UP)`. Script giữ nguyên chuỗi số trong log (trước đây đổi qua float rồi `str()`), nên 0.7775 ra **0.778**. Phiên chạy tiếp còn gặp một dòng `run = first_run(fh.read())` bị lặp: lần đọc thứ hai trả chuỗi rỗng nên script dừng với `ValueError`; đã bỏ dòng lặp. | Chạy lại `python -I docs/paper/tools/make_ml_eval.py`. Cả 8 nhãn khớp cột F1 của Table VII trong tex: six classes IBk 0.977, RF 0.948, J48 0.856, NB 0.778; binary 0.975, 0.939, 0.848, 0.852. Ma trận IBk 80/73/80/79/80/77, lỗi 7, 1, 3 khớp `ml.log` và câu VI.C. |
| 9 | Fig. 9b (`make_ml_eval.py`) | Nhãn trục x xoay 45° với `ha="right", rotation_mode="anchor"`, cỡ 7.8 pt (in ra khoảng 8.3 pt). Hình cao 7.6 cm thay vì 7.0 cm, `bottom=0.34`, lưu với `bbox_inches="tight"`: bản trước cắt mất nhãn "Predicted class" ở đáy PNG và tiêu đề (b) chạm mép phải. | Xem `ml-eval.png` và một bản biên dịch thử có chèn hình ở `\linewidth`: các nhãn không chồng nhau, "Predicted class" và tiêu đề (b) nằm trọn trong hình. |
| 8 | Fig. 2 (`make_workflow.py`) | Thẻ RFID trắng trong ô PN532 dời và thu nhỏ: từ `cx+5..cx+30` thành `cx+3..cx+25`. Ô Credentials rộng 6..67 pt nên thẻ cách viền phải 5.5 pt, bo mạch đỏ cách viền trái 6.5 pt. | Phóng to 400 dpi vùng ô PN532 của `workflow.pdf`: thẻ nằm trọn trong ô, không chạm ô SRF05. Chạy lại script cho ra PNG giống hệt bản đang có (cùng md5). |
| 14 (thấp) | Fig. 3 (`figs/fig-block.tex`) | Ô "Door servo" đổi dòng phụ thành `closes 20 s after leaving`, còn ô "Bolt servo" giữ việc khoá. Đối chiếu `SmartLocker_Online.ino`: `SERVO_BOLT_PIN = 32`, `SERVO_DOOR_PIN = 2`; `closeDoor()` quay servo cửa về `DOOR_CLOSED_DEG` trước rồi mới đưa then về `BOLT_LOCKED_DEG`; `openDoor()` nhả then trước rồi mới mở cửa. Ý "auto-lock" vẫn nằm ở ô SRF05. | Trang 4 của bản biên dịch. |
| 15 (thấp) | Fig. 5 (`figs/fig-state.tex`) | Mũi tên AVAILABLE→MAINTENANCE ghi `staff or SENSOR_FAULT`. Đối chiếu: `Ticket_OpenForFault` (`sql/02_data_v1.sql`, "Case 5. A sensor breaks") đặt ngăn của phiên lỗi thành `MAINTENANCE` khi có cảnh báo SENSOR_FAULT; nhân viên đặt bằng `LockerSlotController`/`LockerSlotDao`; `Ticket_Close` trả ngăn về `AVAILABLE` (mũi tên "ticket closed"). | Trang 6. |
| 16 (thấp) | Fig. 6 (`figs/fig-flow.tex`) | Ô gán nhãn ghi `first matching rule 3 to 9`. Table III của tex: dòng 9 là NORMAL ("no rule matched"). | Trang 7. |
| 24 (thấp) | Fig. 6 (`figs/fig-flow.tex`) | Ô "Risk r(s) by (1)" dùng kiểu `proc` (xanh dương nhạt `slBlue`, viền mảnh) như mọi ô xử lý khác, không còn chung màu mint với ô kết quả "STAFF_OPEN, no alert" và "No alert" (viền dày). | Trang 7: chỉ hai ô kết quả không cảnh báo có màu mint. |
| Bảng 4 dòng 3 | Fig. 2 | Màu theo quy định: ba panel xanh dương nhạt, mint, hồng san hô nhạt, viền đậm cùng tông, chữ đen; `hexc()` đổi mọi tông xám trung tính của hình phần cứng thành xanh thép cùng độ sáng (không tím, không xám); mũi tên giữa các panel chạm viền panel sau. | Trang 3. |

Các hình TikZ (Fig. 1, 3, 4, 5, 6) hiện được T1b chép thẳng vào `smartlocker-10p.tex`. Đã so sánh: nội dung từng tệp
`figs/fig-*.tex` có mặt nguyên văn trong tex, nên hai nơi đang khớp. Lần sửa hình sau phải sửa cả hai nơi (hoặc tex quay
lại dùng `\input{figs/...}`).

## 2. Biên dịch và xem lại

- Chép `docs/paper` sang scratchpad `t2b-build`, chạy `tectonic -X compile smartlocker-10p.tex`: 12 trang, không lỗi,
  không tham chiếu chưa định nghĩa. Xuất các trang có hình ở 150 dpi và xem từng hình đã sửa: Fig. 2 (trang 3), Fig. 3
  (trang 4), Fig. 5 (trang 6), Fig. 6 (trang 7). Mũi tên chạm mép khối, không chữ nào chồng lên hình, không overfull
  nào nằm trong hình.
- Fig. 9 được xem bằng một bản biên dịch thử, trong đó hình được chèn ở `\linewidth` ngay sau Table VII (chỉ trong
  scratchpad).

## 3. Việc còn lại cho T1b (tệp `.tex`, tôi không sửa)

1. **Bản tex hiện tại không còn chèn `images/ml-eval.pdf`**: không có Fig. 8/9 và không có `\label{fig:ml}`; Fig. 7 lại
   là bốn ảnh cũ (`map-area`, `booking-confirm`, `dashboard`, `alert-escalated`), không phải `ui-user.png`/`ui-staff.png`.
   Bản `t1-before-r2.tex` trong scratchpad có dòng
   `\includegraphics[width=\linewidth,height=0.4\textheight,keepaspectratio]{images/ml-eval.pdf}`. Cần kiểm tra xem đây
   là có chủ ý hay bị ghi đè bởi một bản cũ, vì `r2-paper.md` lại báo Fig. 9 và caption của nó đã đạt.
2. Nhánh XeTeX của preamble: `\setmainfont{TeX Gyre Termes}[Extension=.otf, UprightFont=*-regular, ...]` làm tectonic
   dừng ("The font "TeX Gyre Termes-regular" cannot be found"). Khi có `Extension` thì phải là tên tệp:
   `\setmainfont{texgyretermes}[...]`. Bản biên dịch kiểm tra trong scratchpad đã sửa như vậy.
3. Overfull 11.9 pt ở dòng 958 (mục "Lost cards" trong danh sách các luật không cần telemetry), không liên quan tới hình.

## 4. Tệp đã sửa

- `docs/paper/tools/make_ml_eval.py`, `docs/paper/images/ml-eval.pdf`, `docs/paper/images/ml-eval.png`
- `docs/paper/tools/make_workflow.py`, `docs/paper/images/workflow.pdf`, `docs/paper/images/workflow.png`
- `docs/paper/figs/fig-block.tex`, `docs/paper/figs/fig-state.tex`, `docs/paper/figs/fig-flow.tex`

Cách kiểm lại: `python -I docs/paper/tools/make_ml_eval.py` (in ra các số F1 lấy từ log) và
`python -I docs/paper/tools/make_workflow.py`, rồi biên dịch như mục 2.

KẾT LUẬN: các lỗi hình 5, 8, 9, 14, 15, 16, 24 ĐẠT. Fig. 9 chỉ in ra khi T1b đưa hình trở lại tex.
