# Vòng 0, T2: hình vẽ của bài (2026-11-14)

Phạm vi: góp ý của cô, Bảng 2 dòng 2, Bảng 3 dòng 15 tới 19, Bảng 4 dòng 2 và 3. Không commit gì.

## Bảng màu chung (`docs/paper/figs/colors.tex`)
- Nền pastel nhạt: xanh dương nhạt `slBlue` #DCEBFA, xanh bạc hà `slMint` #DDF3E3, vàng nhạt `slYellow` #FFF3C4,
  cam đào `slPeach` #FFE2C8, hồng san hô nhạt `slCoral` #FFD9D6 (và `slSky` #E9F6FB cho nền nhóm).
- Viền đậm cùng tông (#1F4E79, #1E6B3A, #7A5B00, #8A4513, #9B2226), mũi tên và đường xanh đen `slInk` #0F2338,
  chữ đen. Không có tím và không có xám trong mọi hình vẽ.
- Mọi style có tiền tố `sl` (`slbox`, `slmint`, `sldec`, `slterm`, `slok`, `slarr`, `sldbl`, `slret`, `slgroup`...),
  lệnh `\slsub{}` cho dòng phụ cỡ nhỏ. Đã biên dịch thử cùng preamble của bài: không xung đột, không overfull.
- Các hình TikZ vẽ đúng kích thước tự nhiên (rộng tối đa 17,5 cm, `\linewidth` = 516 pt = 18,1 cm), không
  `\resizebox`, nên chữ `\small` in ra đúng 9 pt. Mũi tên nối vào anchor của khối nên đầu mũi tên chạm sát mép.
- Bản gốc của năm hình TikZ (từ commit 13ba35f) giữ ở `docs/paper/figs/orig/` để đối chiếu.

## Từng hình
| Hình | Tệp | Hiện trạng |
|---|---|---|
| Fig. 1 `fig:arch` | `figs/fig-arch.tex` | Ba hàng: client (xanh dương), Tomcat 9 (nền xanh nhạt, viền đứt xanh lá) chứa Device APIs / KioskApi / SecurityFilter (bạc hà), AlertService và LockerMonitor (vàng), lớp DAO (cam đào), SQL Server (hồng). Một dòng chính mỗi khối, dòng phụ nhỏ. Nội dung như bản gốc. |
| Fig. 2 `fig:workflow` | `images/workflow.pdf/.png` từ `tools/make_workflow.py` | Ba panel xanh dương / bạc hà / hồng, viền đậm cùng tông (bỏ viền xám). Màu xám trong hình vẽ linh kiện được `hexc()` đổi sang xanh thép cùng độ sáng. Thẻ SRF05: "SRF05: presence, backlight, auto-lock"; thẻ servo: "SG90 servos: open, auto-lock". Mũi tên giữa panel chạm mép panel. |
| Fig. 3 `fig:block` | `figs/fig-block.tex` | Đầu vào bên trái (bàn phím, PN532, AS608, SRF05 "presence, backlight, auto-lock"), ESP32 ở giữa (firmware 4.3), đầu ra bên phải (LCD, bolt servo, door servo "locks 20 s after leaving"), nhãn bus trên dây. Hàng dưới: Browser/phone, Wi-Fi/Internet, nhóm Server (Tomcat, Rules + Weka, SQL Server). Vai trò SRF05 lấy từ `firmware/SmartLocker_Online/SmartLocker_Online.ino` 4.3: `DOOR_OPEN_MS` 20 s sau khi người rời đi, `DOOR_OPEN_MAX_MS` 120 s sau khi mở, `NEAR_CM` 50 cm bật đèn nền. |
| Fig. 4 `fig:seq` | `figs/fig-seq.tex` | Đầu lifeline tô màu, lifeline nét đứt xanh đen, khung `opt [remote or phone open]` nền vàng nhạt. Mũi tên liền là request, nét đứt là reply. Cùng mười thông điệp như bản gốc. |
| Fig. 5 `fig:state` | `figs/fig-state.tex` | Đã sửa theo v7.1 (`sql/05_auto_checkin.sql`): RESERVED → AVAILABLE chỉ còn "cancel (during the 15 min hold)"; RESERVED → OCCUPIED "first open (CHECK_IN) or hold ends (AUTO_CHECK_IN)"; OCCUPIED → AVAILABLE "return (PICKUP) after any debt is paid, or NO_SHOW if never opened"; vòng ACCESS / overdue lock + late fee; AVAILABLE ↔ MAINTENANCE. Đã hết overfull 24 pt (rộng 17,2 cm). |
| Fig. 6 `fig:flow` | `figs/fig-flow.tex` | Trải ngang cả trang, ba hàng: (1) Session → Load context → Sensor fault? → Remote or phone open? → Valid, unused command? → ℓ ← SUSPECTED_SPOOF; (2) ℓ ← first matching rule 3 to 8 và Risk r(s); (3) ℓ ≠ NORMAL? → Alert ℓ, evidence r / r ≥ 0.80? → ML_ANOMALY alert / No alert. Quyết định là hình thoi vàng; kết quả có viền dày: hồng khi có cảnh báo, bạc hà khi không cảnh báo. Bỏ gạch ngang "3–8" thành "3 to 8". |
| Fig. 7 `fig:ui-user` | `images/ui-user.png` từ `tools/make_ui_figs.py` | 893 × 618 px: panel khu vực của bản đồ (CANT-A, lưới ngăn dãy A) và popup xác nhận đặt ngăn B07, cắt sát, giữ nguyên độ phân giải. |
| Fig. 8 `fig:ui-staff` | `images/ui-staff.png` | 964 × 569 px: hai ô KPI (11 cảnh báo chưa xử lý, 0 thiết bị mất kết nối, 10/10 trực tuyến) + thẻ "cảnh báo theo loại"; bên phải tiêu đề cảnh báo #119 OVERDUE_ESCALATED và thẻ lượt gửi quá hạn (#10401, CANT-A A12, 50 giờ trễ, 320.000 đ đã thu, 128.500 đ còn nợ). |
| Fig. 9 (đánh giá) | `images/ml-eval.pdf` (vector) + `ml-eval.png` từ `tools/make_ml_eval.py` | 17 × 7 cm. (a) cột weighted F1 của IBk, Random Forest, J48, Naive Bayes, sáu lớp (xanh) và nhị phân (cam đào) cạnh nhau, số in đậm trên đầu cột; trục y từ 0 tới 1,0. (b) ma trận nhầm lẫn IBk sáu lớp: đường chéo bạc hà, ô sai hồng chữ đỏ đậm (7 WRONG_USER → NORMAL, 3 NORMAL → WRONG_USER, 1 ITEM_LEFT → SUSPECTED_SPOOF). |

## Nguồn số liệu của ml-eval
- Mọi số được script đọc trực tiếp từ `docs/paper/evidence/ml.log`, lần chạy 1 (CV giống hệt ở ba lần chạy), không gõ tay.
- Sáu lớp: mục "six classes (480 rows, 10-fold CV, new Random(42))": IBk 0.9771, RF 0.9478, J48 0.8558, NB 0.7775.
- Nhị phân: mục "label order {NORMAL, ABNORMAL}" (thứ tự dùng cho Table IV của bài): IBk 0.9754, RF 0.9387, J48 0.8476, NB 0.8519.
  Với thứ tự nhãn kia RF là 0.9406; các mô hình khác không đổi.
- Ma trận nhầm lẫn IBk có sẵn trong `ml.log` (khối "-- confusion matrix IBk --"), nên không cần chạy lại Weka và
  không tạo `evidence/ml-confusion.log`.

## Chụp lại ảnh giao diện (khi giao diện đã sang tiếng Anh)
- Chụp lại bốn ảnh nguồn trong `docs/paper/images/` cùng tên, khung nhìn 1440 × 900 CSS px, device scale 1, giao diện
  sáng: `map-area.png` (bản đồ của người dùng, chọn khu "canteen KTX A", panel khu mở), `booking-confirm.png` (popup
  xác nhận đặt ngăn B07), `dashboard.png` (tổng quan của admin; nên chụp cao 1000 px trở lên để thấy trọn chú giải
  cảnh báo, bản hiện tại bị cắt ở dòng OVERDUE_ESCALATED), `alert-escalated.png` (chi tiết cảnh báo #119).
- Sau đó mở `tools/make_ui_figs.py`, kiểm từng hộp cắt trong `FIGURES` (docstring mô tả vùng cần lấy) và chạy
  `python -I docs/paper/tools/make_ui_figs.py`. Script báo lỗi nếu hộp cắt nằm ngoài ảnh.
- Giữ mỗi hình ghép rộng khoảng 900 px: khi đặt ở 0,9\linewidth chữ 13 px in ra khoảng 6 tới 7 pt; ghép rộng hơn sẽ
  không đọc được trên giấy.

## Việc còn mở (gửi T1 / người điều phối)
1. Caption Fig. 8 (T1) ghi "the dashboard sums up slots, ... the audit-chain status and recent revenue", nhưng để chữ
   đọc được, phần cắt chỉ giữ ô cảnh báo chưa xử lý, ô thiết bị trực tuyến và thẻ cảnh báo theo loại. Đề nghị sửa
   caption, ví dụ: "...in which the dashboard shows the open alerts by type and the devices online, and an
   OVERDUE_ESCALATED alert shows a late booking with its late fee and the amount still owed." (hoặc báo T2 thêm vùng,
   đổi lại chữ nhỏ hơn).
2. Caption Fig. 6 cũ nói "shaded boxes are outcomes"; nay mọi khối đều có nền nhạt, kết quả được phân biệt bằng viền
   dày (hồng: có cảnh báo, bạc hà: không cảnh báo). Nên viết "...with outcomes drawn with a thick border".
3. (Đã xử lý) Trục giá trị của Fig. 9a nay bắt đầu từ 0, không cần ghi chú trong caption.
4. Trong ảnh chụp (Fig. 7, 8) màu là của chính ứng dụng: lát "OVERDUE_ESCALATED" của biểu đồ tròn là màu xám xanh
   của `app.css`; quy tắc không xám chỉ áp được cho hình vẽ, không sửa ảnh chụp.
5. Bản biên dịch toàn bài (bản sao `smartlocker-10p.tex` lúc 14/11 trong scratchpad, tectonic) không lỗi, không
   overfull; Fig. 1 tới 9 nằm ở trang 2 tới 9.

## Tệp đã tạo / sửa
- Mới: `docs/paper/figs/colors.tex`, `figs/fig-arch.tex`, `figs/fig-block.tex`, `figs/fig-seq.tex`,
  `figs/fig-state.tex`, `figs/fig-flow.tex`, `figs/orig/*.tex`, `tools/make_ml_eval.py`, `tools/make_ui_figs.py`,
  `images/ml-eval.pdf`, `images/ml-eval.png`, `images/ui-user.png`, `images/ui-staff.png`.
- Sửa: `tools/make_workflow.py`, `images/workflow.pdf`, `images/workflow.png`.

## Cách kiểm tra
- `python -I docs/paper/tools/make_workflow.py`, `make_ml_eval.py`, `make_ui_figs.py` (cần matplotlib, Pillow, PyMuPDF).
- Biên dịch bài (`tectonic -X compile smartlocker-10p.tex` trong `docs/paper`), xem trang 2 tới 9: không overfull,
  mũi tên chạm mép khối, không có tím/xám trong hình vẽ.

## Cập nhật sau góp ý của người điều phối
- `tools/make_ml_eval.py`: trục giá trị của panel (a) đổi từ 0,70..1,035 sang 0..1,08 (vạch 0 tới 1,0 bước 0,2), vì
  biểu đồ cột phải bắt đầu từ 0; số in đậm vẫn nằm trên đầu cột. Đã tạo lại `images/ml-eval.pdf/.png`, biên dịch lại
  bản sao toàn bài (không lỗi, không overfull) và xem trang 9: chênh lệch giữa các mô hình nhỏ hơn nhưng trung thực.
