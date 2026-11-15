# Phản hồi Chi tiết Góp ý Giảng viên / Reviewer (Lần 2) — SmartLocker PRJ301

**Dự án**: Smart Locker with Anomalous Access Detection Based on IoT Device Telemetry  
**Mã đề tài**: PRJ301 — Fall 2026  
**Nhóm tác giả**:
- **Duc Hoang Nguyen\*** (`duchoang.nguyen103@gmail.com`) — *Corresponding author* (ORCID: `0009-0006-9780-8146`)
- **Viet Tien Nguyen** (`tiennguyen100306@gmail.com`)
- **Huy Hoang Nguyen** (`huyhoang.ct06@gmail.com`)
- **Thanh Cao Nguyen** (`thanhcao19112006@gmail.com`)
- **Thu Le** (`thulvm@fpt.edu.vn`)
- **Kieu Trong Khanh** (`khanhkt@fpt.edu.vn`)  
**Đơn vị**: FPT University, Ho Chi Minh Campus, Vietnam  
**Tài liệu xuất bản**: `docs/paper/smartlocker-10p.tex` $\rightarrow$ `docs/paper/smartlocker-10p.pdf` (Đúng chuẩn 10 trang, IEEEtran)

---

## 1. Bảng Tổng hợp Xử lý Góp ý Lần 2 (Các Điểm Còn Lại Cần Sửa)

| STT | Vị trí | Vấn đề từ Reviewer | Biện pháp & Kết quả Xử lý trong Working Tree | Trạng thái |
|:---:|:---|:---|:---|:---:|
| **1** | Mục VI.A và VI.D | **Ngày đo không khớp với commit**: Bài ghi các số đo "refer to commit 1cc154a (measured on 30 October 2026)", nhưng commit `1cc154a` được tạo ngày 15/11/2026. Mục VI.D lại ghi bộ test chạy lại ngày 15/11/2026. | Đã phân tách rành mạch hai mốc lịch sử trong LaTeX và văn bản:<br>1. **Mốc 30/10/2026**: Thuộc commit `da95f43` (`\baselinecommit`), thực hiện các đo lường baseline ban đầu (mô hình Weka ML 480 dòng dữ liệu, kịch bản Postman 221 requests / 472 assertions, latency 30 requests).<br>2. **Mốc 15/11/2026**: Thuộc commit `1cc154a` (`\revisioncommit`), thực hiện tái kiểm định toàn diện (83/83 TestNG tests in-memory và DB passed 100%, 241/241 Newman tests passed) và triển khai chiến dịch đo lường mô phỏng đa cảm biến. | **HOÀN THÀNH** |
| **2** | Mục III.B | **Mục Roles (III.B) quá ngắn**: Chỉ gồm một đoạn văn ngắn đứng riêng làm một subsection độc lập. | Đã gộp toàn bộ nội dung phân quyền RBAC của mục III.B vào mục III.A, đổi tên thành **`\subsection{Architecture and Access Roles}`**. Giúp cấu trúc Section III trở nên cân đối và liền mạch. | **HOÀN THÀNH** |
| **3** | Mục IV.E | **Mục Audit Log (IV.E) ngắn**: Đứng riêng rẽ ở cuối Section IV. | Đã gộp mục IV.E vào mục IV.D thành **`\subsection{Server-Side Safeguards and Tamper-Evident Audit Log}`**, trình bày liên hoàn từ các cơ chế phòng vệ tại máy chủ (lockout, offline monitor, overdue) tới chuỗi băm bất biến SHA-256. | **HOÀN THÀNH** |
| **4** | Table VI (Table `tab:rules`) | **Các dòng bảng luật phát hiện quá sát nhau**: Khi in PDF các dòng bị dính, khó đọc phần condition. | Đã tăng `\renewcommand{\arraystretch}{1.18}` và bổ sung khoảng đệm dọc `\\[2pt]` sau mỗi dòng trong bảng `tab:rules`. Các rule từ 1 đến 9 hiện rõ ràng, thoáng mắt và dễ theo dõi. | **HOÀN THÀNH** |
| **5** | Fig. 9a (`fig:eval`) | **Trục tung biểu đồ F1 bị cắt cụt**: Trục Y bắt đầu từ 0.60 thay vì 0.0 nhưng caption chưa công bố điều này. | Đã bổ sung minh bạch trong caption hình `fig:eval`: *"with y-axis truncated to $[0.60, 1.00]$ to highlight differences across models"*. Đảm bảo tính trung thực khoa học theo chuẩn IEEE. | **HOÀN THÀNH** |
| **6** | Mục II (Related Work) | **Trích dẫn Arp et al. [13]**: Cần viết chuẩn xác về quy mô nghiên cứu các cạm bẫy học máy trong an ninh. | Đã cập nhật câu văn tại Mục II thành: *"while Arp et al. [13] find these pitfalls widespread in 30 papers from top security venues, including sampling bias and lab-only evaluation."* đúng theo gợi ý của cô. | **HOÀN THÀNH** |
| **7** | Author Block | **Thông tin tác giả chính thức & ORCID**: Duc Hoang Nguyen* là Corresponding Author, bổ sung ORCID thật, giữ nguyên Gmail sinh viên. | Đã cập nhật tác giả đầu tiên: **Duc Hoang Nguyen\*** (`duchoang.nguyen103@gmail.com`), ghi rõ `(ORCID: 0009-0006-9780-8146)`, `*Corresponding author`. Giữ chuẩn xác 4 Gmail sinh viên và 2 email giảng viên `@fpt.edu.vn`. | **HOÀN THÀNH** |
| **8** | Fig. 2 (Workflow) | **Độ rộng hình sơ đồ workflow**: Hình bị hẹp hơn so với sơ đồ khối và sơ đồ kiến trúc xung quanh. | Đã nâng độ rộng từ `width=0.83\linewidth` lên `width=0.98\linewidth`. Sơ đồ quy trình hiện có độ rộng ngang bằng và cân xứng tuyệt đối với Fig. 1 và Fig. 3. | **HOÀN THÀNH** |
| **9** | Fig. 7 & 8 (Giao diện UI) | **Giao diện chụp thực tế tiếng Anh**: 4 ảnh chụp giao diện phải đồng nhất tỉ lệ 16:9, tiếng Anh 100%. | Đã tích hợp trọn vẹn 4 ảnh chụp giao diện thực tế độ phân giải cao 1024x576 vào `ui-user.png` và `ui-staff.png` (2120x624 px) với 100% tiếng Anh, thể hiện bản đồ canteen, popup đặt ngăn, KPI dashboard và chi tiết cảnh báo quá hạn `#119`. | **HOÀN THÀNH** |
| **10** | Mục VI & Giới hạn | **Nâng cấp Nghiên cứu Mô phỏng Đa Cảm biến**: Đánh giá 100 phiên thực nghiệm có nhãn trên backend thực. | Đã triển khai bộ giả lập `simulator/` bằng Python, thực thi thành công 100 phiên trên Tomcat 9 thực (port 8081, DB `SL_SIM`), thu thập dữ liệu và bổ sung Bảng VII so sánh Baseline B0 vs Proposed B1 (Macro-F1 tăng từ 0.436 lên 0.876, kiểm định McNemar $\chi^2=23.04, p=2.0\times 10^{-6}$). | **HOÀN THÀNH** |

---

## 2. Minh chứng Kiểm thử & Biên dịch LaTeX

1. **Biên dịch PDF (`docs/paper/smartlocker-10p.pdf`)**:
   - Biên dịch thành công với trình biên dịch `Tectonic`.
   - **Số trang tuyệt đối**: Đúng **10 trang** (không tràn sang trang 11, không dôi dòng mồ côi).
   - **Cảnh báo tham chiếu `??`**: **0 lỗi** (Tất cả hình, bảng, công thức và trích dẫn [1]--[22] được giải quyết chính xác).
2. **Kiểm thử tự động**:
   - `TestNG`: 83/83 passed (100%).
   - `Newman API`: 241/241 assertions passed (100%).
   - `Multi-sensor Simulator Unit/Integration`: 35/35 passed (100%).
   - `End-to-End Simulator Suite`: 381/381 passed (100%).
   - `100 Labeled Experimental Sessions Campaign`: 100/100 passed (100%).
