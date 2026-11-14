# Ghi chú tài liệu tham khảo (task T3, 2026-11-14)

Đáp ứng Bảng 4 dòng 4 trong `docs/review/teacher-feedback-2026-11-14.md`: thêm DOI cho mọi mục và thêm 5 công trình 2022 tới 2025.
Tệp `refs-additions.bib` là toàn bộ danh mục đã sửa (22 khoá cũ giữ nguyên tên, 5 khoá mới ở cuối). T1 chỉ cần chép nội dung
tệp này vào khối `filecontents` của `smartlocker-10p.tex`.

## 1. Cách kiểm

- Mỗi DOI được tra qua Crossref (`https://api.crossref.org/works/<doi>`): so tên bài, tác giả, tạp chí hoặc hội nghị, tập, số, trang, năm.
- Mỗi DOI được thử trên `https://doi.org/<doi>`: cả 25 DOI đều trả 302 về đúng trang nhà xuất bản (ghi ở cột cuối bảng).
- 5 bài mới được mở trên trang nhà xuất bản (MDPI, Frontiers, CACM) và đọc thẻ `citation_*` cùng phần tóm tắt.
- IEEE Xplore trả HTTP 420 (chặn bot) cả trong trình duyệt tích hợp lẫn Chrome, ACM DL hiện trang kiểm tra Cloudflare; với các
  bài cũ của IEEE và ACM, phần kiểm dựa trên Crossref và đường dẫn doi.org. Bài mới của ACM được kiểm trên trang CACM.

## 2. In DOI với IEEEtran

`IEEEtran.bst` bản 1.14 (bản hiện hành trên CTAN, 2015/08/26) không đọc trường `doi`, nên DOI sẽ không hiện trong bài nếu chỉ có
trường này. Vì vậy mỗi mục có thêm `note = {doi: ...}`; IEEEtran in note ở cuối mục, đúng dạng "..., 2015, doi: 10.1109/...".
Hai mục không có DOI (Kohavi, Provos) dùng `url`, IEEEtran in "[Online]. Available: ...".
Lưu ý: khối `filecontents` ghi đè `smartlocker-refs.bib`, tệp này cũng được `smartlocker-iciit.tex` (ACM) đọc. ACM-Reference-Format
tự in `doi`, nên với bản ACM cần bỏ các dòng `note` để DOI không bị in hai lần.

## 3. Bảng thay đổi theo từng mục cũ

| Khoá | DOI hoặc mã định danh | Sửa metadata | Trang đích của DOI |
|---|---|---|---|
| alfuqaha2015iot | 10.1109/COMST.2015.2444095 | Không | ieeexplore.ieee.org/document/7123563 |
| sicari2015security | 10.1016/j.comnet.2014.11.008 | Không | linkinghub.elsevier.com/retrieve/pii/S1389128614003971 |
| iwan2016parcel | 10.1016/j.trpro.2016.02.018 | Tên bài: dấu gạch giữa hai vế đổi thành dấu hai chấm (quy định không dùng gạch ngang), chữ giữ nguyên | linkinghub.elsevier.com/retrieve/pii/S2352146516000193 |
| mitrokotsa2010rfid | 10.1007/s10796-009-9210-z | Không | link.springer.com/10.1007/s10796-009-9210-z |
| chandola2009anomaly | 10.1145/1541880.1541882 | Không (Crossref ghi trang 1-58, bài số 15, khớp 15:1 tới 15:58) | dl.acm.org/doi/10.1145/1541880.1541882 |
| sommer2010outside | 10.1109/SP.2010.25 | Không | ieeexplore.ieee.org/document/5504793 |
| moustafa2021toniot | 10.1016/j.scs.2021.102994 | Không; giữ khoá (T1 chỉ còn trích ở VI.A) | linkinghub.elsevier.com/retrieve/pii/S2210670721002808 |
| hall2009weka | 10.1145/1656274.1656278 | Không (Crossref cắt phụ đề "An Update", trang ACM có đủ) | dl.acm.org/doi/10.1145/1656274.1656278 |
| breiman2001rf | 10.1023/A:1010933404324 | Không | link.springer.com/10.1023/A:1010933404324 |
| quinlan1993c45 | 10.1016/C2009-0-27846-9; ISBN 1-55860-238-0 | Thêm `isbn`, `doi`. DOI là bản điện tử của Elsevier (Morgan Kaufmann), Crossref ghi năm 1993, ISBN điện tử 978-0-08-050058-4; các chương có DOI con 10.1016/B978-0-08-050058-4.5xxxx | linkinghub.elsevier.com/retrieve/pii/C20090278469 |
| john1995nb | 10.48550/arXiv.1302.4964 | Thêm `publisher`. Kỷ yếu UAI 1995 không có DOI; DOI này là bản arXiv (đăng 2013), trang arXiv ghi "Appears in Proceedings of the Eleventh Conference on Uncertainty in Artificial Intelligence (UAI1995)" và mã UAI-P-1995-PG-338-345, khớp trang 338 tới 345 | arxiv.org/abs/1302.4964 |
| aha1991ibl | 10.1007/BF00153759 | Không | link.springer.com/10.1007/BF00153759 |
| kohavi1995cv | Không có DOI; url https://www.ijcai.org/proceedings/1995/147 | Trang 1137 tới 1145 sửa thành 1137 tới 1144 (theo trang IJCAI); thêm tập 2 | ijcai.org/proceedings/1995/147 |
| haber1991timestamp | 10.1007/BF00196791 | Không | link.springer.com/10.1007/BF00196791 |
| provos1999bcrypt | Không có DOI (USENIX 1999 không cấp DOI); url https://www.usenix.org/legacy/events/usenix99/provos.html | Trang 81 tới 91 sửa thành 81 tới 92 (bản HTML của USENIX ghi "Pp. 81-92 of the Proceedings"); thêm địa điểm Monterey, CA | static.usenix.org/events/usenix99/provos/provos_html/index.html |
| rfidiot2023locker | 10.1063/5.0101139 | Không. Trang AIP ghi tập 2427, bài 020098, ngày 27/02/2023, khớp bài và nhận xét của cô. Bản ghi Crossref của DOI này lại ghi tập 2605 và hội nghị IEET-2021 (Izhevsk); đây là lỗi khai báo phía Crossref, giữ 2427 theo trang nhà xuất bản | pubs.aip.org/aip/acp/article/2866432 (URL đầy đủ chứa /2427/1/020098/) |
| roman2013features | 10.1016/j.comnet.2012.12.018 | Không | linkinghub.elsevier.com/retrieve/pii/S1389128613000054 |
| abomhara2015cyber | 10.13052/jcsm2245-1439.414 | Không. Crossref không ghi tập và số; giữ tập 4 số 1 (mã DOI .414 nghĩa là tập 4, số 1, bài 4). Trang River Publishers không mở được từ máy này | journals.riverpublishers.com/index.php/JCSANDM/article/view/6087 |
| want2006rfid | 10.1109/MPRV.2006.2 | Không | ieeexplore.ieee.org/document/1593568 |
| coskun2013nfc | 10.1007/s11277-012-0935-5 | Không | link.springer.com/10.1007/s11277-012-0935-5 |
| jain2004biometric | 10.1109/TCSVT.2003.818349 | Không | ieeexplore.ieee.org/document/1262027 |
| ahmed2016survey | 10.1016/j.jnca.2015.11.016 | Không | linkinghub.elsevier.com/retrieve/pii/S1084804515002891 |

Độ phủ: 20/22 mục cũ có DOI, 2/22 (Kohavi IJCAI 1995, Provos USENIX 1999) không có DOI và dùng URL ổn định của nhà xuất bản.
5/5 mục mới có DOI. Tổng 25/27 mục có DOI.

### Các mục còn in dấu gạch
Trong tên bài, tên tạp chí và tên hội nghị không còn dấu gạch ngang (chỉ còn gạch nối trong từ ghép của tên chính thức như
"Al-Fuqaha", "AI-Based", "Time-Stamp", "Instance-Based", "Cross-Validation", "Future-Adaptable", "Two-Stage", "Privacy-Preserving",
đó là gạch nối, không phải gạch ngang). Dấu gạch duy nhất được in là khoảng trang `a--b` (IEEEtran in "pp. a-b"), theo quy ước
thư mục: alfuqaha2015iot, sicari2015security, iwan2016parcel, mitrokotsa2010rfid, chandola2009anomaly, sommer2010outside,
hall2009weka, breiman2001rf, john1995nb, aha1991ibl, kohavi1995cv, haber1991timestamp, provos1999bcrypt, roman2013features,
abomhara2015cyber, want2006rfid, coskun2013nfc, jain2004biometric, ahmed2016survey, ciesla2023parcel, arp2024pitfalls.
Các mục chỉ có số bài, không in gạch: moustafa2021toniot, quinlan1993c45, rfidiot2023locker, zhang2025parcel,
demedeiros2023anomaly, shahin2025twostage.

## 4. Năm công trình mới

### 4.1 zhang2025parcel
- Trích dẫn: Q. Zhang and E. Demir, "Parcel locker solutions for last mile delivery: A systematic literature review and future research directions," *Frontiers in Future Transportation*, vol. 6, Art. no. 1654621, Aug. 2025.
- DOI: 10.3389/ffutr.2025.1654621
- Trang nhà xuất bản: https://www.frontiersin.org/journals/future-transportation/articles/10.3389/ffutr.2025.1654621/full
- Tóm tắt: bài tổng quan có hệ thống về tủ nhận hàng (parcel locker) cho giao hàng chặng cuối, xét chi phí, hiệu quả vận hành
  và tính bền vững. Tác giả kết luận phần lớn nghiên cứu về mạng tủ tập trung vào chọn vị trí tối ưu và định tuyến, một số bài
  xét yếu tố động và tủ di động. Trong bảng tổng hợp các bài về tính bền vững, nhóm "Safety and security" chỉ có 1 bài. Bài này
  củng cố trực tiếp nhận định của mục II rằng nghiên cứu về tủ tập trung vào logistics hơn là an ninh truy cập.
- Vị trí: mục II, đoạn "Smart and parcel lockers", câu đầu.
- Câu đề xuất:
  > Research on parcel lockers has concentrated on last-mile logistics \cite{iwan2016parcel}, and a recent systematic review finds that most studies of locker networks optimise locker locations and delivery routes, while only one of the sustainability studies it classifies deals with safety and security \cite{zhang2025parcel}.

### 4.2 ciesla2023parcel
- Trích dẫn: M. Cieśla, "Perceived importance and quality attributes of automated parcel locker services in urban areas," *Smart Cities*, vol. 6, no. 5, pp. 2661-2679, Oct. 2023.
- DOI: 10.3390/smartcities6050120
- Trang nhà xuất bản: https://www.mdpi.com/2624-6511/6/5/120
- Tóm tắt: khảo sát người dùng tủ nhận hàng ở Ba Lan, mã hoá theo mô hình Kano để xếp hạng các thuộc tính chất lượng dịch vụ.
  Theo chỉ số hài lòng tổng, các thuộc tính quan trọng nhất là ứng dụng riêng (-0,96), đặt kiện đúng ô (-0,82), cỡ ô khớp cỡ kiện
  (-0,79), vị trí trạm (-0,74) và hỗ trợ người khuyết tật (-0,62). Bài cho thấy phía người dùng cần ứng dụng, chọn cỡ ô và vị trí,
  là những điểm SmartLocker giải quyết bằng đặt ô trên bản đồ và giá theo cỡ ô S, M, L.
- Vị trí: mục II, đoạn "Smart and parcel lockers", sau câu về \cite{rfidiot2023locker} (hoặc ở đoạn đầu mục I, sau câu có \cite{iwan2016parcel}).
- Câu đề xuất:
  > A survey of parcel locker users in Poland ranks a dedicated application, a box size matched to the item and the location of the stations among the most important quality attributes of the service \cite{ciesla2023parcel}. SmartLocker answers these needs with booking on a map and with slot sizes that are priced separately.

### 4.3 demedeiros2023anomaly
- Trích dẫn: K. DeMedeiros, A. Hendawi, and M. Alvarez, "A survey of AI-based anomaly detection in IoT and sensor networks," *Sensors*, vol. 23, no. 3, Art. no. 1352, Jan. 2023.
- DOI: 10.3390/s23031352
- Trang nhà xuất bản: https://www.mdpi.com/1424-8220/23/3/1352
- Tóm tắt: tổng quan các phương pháp phát hiện bất thường trong IoT và mạng cảm biến, chủ yếu công trình 2017 tới 2022. Phần kết
  luận đếm 10 phương pháp không học sâu, 10 dùng MLP, 6 dựa trên đồ thị, 4 dùng LSTM/GRU, 7 dùng autoencoder hoặc VAE, 4 dùng CNN;
  theo ứng dụng, 13 bài nhằm phát hiện tác nhân độc hại, là nhóm lớn nhất. Bài cũng dẫn nhận định rằng dữ liệu có nhãn hiếm và
  mẫu bất thường ít nên học có giám sát hoàn toàn kém hiệu quả hơn học không giám sát. Điều này khớp lý do SmartLocker để luật quyết
  định và chỉ dùng mô hình học máy làm tín hiệu phụ khi chưa có phiên thật có nhãn.
- Vị trí: mục II, đoạn "Anomaly detection", ngay sau câu có \cite{chandola2009anomaly, ahmed2016survey}.
- Câu đề xuất:
  > For IoT and sensor networks, a survey of recent detectors finds that most are learned models such as multilayer perceptrons, recurrent networks and autoencoders, that the detection of malicious actors is their most common application, and that the scarcity of labelled data makes fully supervised detectors less successful than unsupervised ones \cite{demedeiros2023anomaly}. SmartLocker has no labelled sessions from real use yet, so it decides identity cases with explicit rules.

### 4.4 shahin2025twostage
- Trích dẫn: M. Shahin, A. Hosseinzadeh, and F. F. Chen, "A two-stage hybrid federated learning framework for privacy-preserving IoT anomaly detection and classification," *IoT*, vol. 6, no. 3, Art. no. 48, 2025.
- DOI: 10.3390/iot6030048
- Trang nhà xuất bản: https://www.mdpi.com/2624-831X/6/3/48
- Tóm tắt: khung phát hiện bất thường hai tầng cho thiết bị IoT. Tầng một, mỗi thiết bị huấn luyện một mô hình sinh (tốt nhất là VAE)
  chỉ trên lưu lượng bình thường để gắn cờ bất thường; tầng hai, bộ phân loại Histogram-based Gradient Boosting gán loại tấn công cho
  lưu lượng bị gắn cờ. Huấn luyện theo học liên kết (federated) trên 9 thiết bị thương mại của bộ N-BaIoT, đạt độ chính xác trung bình
  99,14%. Đây là đối chiếu trực tiếp cho thiết kế hai tầng của SmartLocker: cùng hai tầng nhưng tầng một của SmartLocker là luật
  tường minh trên telemetry và ngữ cảnh đặt chỗ, chạy ở máy chủ, còn mô hình học máy chỉ cho điểm rủi ro.
- Vị trí: mục II, đoạn "Anomaly detection", sau câu về Sommer và Paxson (hoặc đầu mục IV khi giới thiệu hai tầng).
- Câu đề xuất:
  > Shahin et al. \cite{shahin2025twostage} flag anomalous IoT traffic with a generative model trained on the benign traffic of each device and then label the flagged traffic with a gradient-boosting classifier, reaching an average accuracy of 99.14\% on the N-BaIoT dataset. SmartLocker also detects in two tiers, but its first tier is a set of explicit rules over device telemetry and booking context on the server, and its learned model only adds a risk score.

### 4.5 arp2024pitfalls
- Trích dẫn: D. Arp, E. Quiring, F. Pendlebury, A. Warnecke, F. Pierazzi, C. Wressnegger, L. Cavallaro, and K. Rieck, "Pitfalls in machine learning for computer security," *Communications of the ACM*, vol. 67, no. 11, pp. 104-112, Nov. 2024.
- DOI: 10.1145/3643456
- Trang nhà xuất bản: https://cacm.acm.org/research/pitfalls-in-machine-learning-for-computer-security/ (trang ACM DL https://dl.acm.org/doi/10.1145/3643456 bị Cloudflare chặn khi kiểm; trang CACM ghi Vol. 67 No. 11 và DOI này)
- Tóm tắt: bài nêu mười lỗi thường gặp khi dùng học máy cho bài toán an ninh (P1 sampling bias, P2 label inaccuracy, P3 data snooping,
  P4 spurious correlations, P5 biased parameter selection, P6 inappropriate baseline, P7 inappropriate performance measures, P8 base rate
  fallacy, P9 lab-only evaluation, P10 inappropriate threat model) và phân tích 30 bài ở bốn hội nghị an ninh hàng đầu: mỗi bài mắc ít
  nhất ba lỗi. Bài dùng để nói rõ giới hạn của kết quả phân loại trên dữ liệu tổng hợp trong SmartLocker (sampling bias, lab-only
  evaluation) và bổ sung cho Sommer và Paxson bằng một nguồn mới.
- Vị trí: mục VI, tiểu mục "Limitations", sau câu "The training data are synthetic as well ..."; có thể thêm một câu ở mục II cạnh \cite{sommer2010outside}.
- Câu đề xuất (Limitations):
  > Arp et al. \cite{arp2024pitfalls} list sampling bias and lab-only evaluation among ten common pitfalls of learning-based security systems, and the classifier results reported here are exposed to both, since every session is synthetic and none comes from a deployed box.
- Câu đề xuất (mục II, tuỳ chọn):
  > A later analysis of 30 machine-learning papers from top security venues finds that each one suffers from at least three of ten common pitfalls, among them sampling bias, the base rate fallacy and lab-only evaluation \cite{arp2024pitfalls}.

## 5. Ứng viên chưa dùng (chưa kiểm được trên trang nhà xuất bản)

Các bài IEEE dưới đây có trên Crossref và rất sát đề tài, nhưng IEEE Xplore trả HTTP 420 nên chưa đọc được trang nhà xuất bản;
theo yêu cầu "kiểm từng bài trên trang nhà xuất bản", chưa đưa vào bài. Nếu nhóm mở được Xplore và đọc tóm tắt, có thể thay hoặc
thêm (nhất là bài đầu, về tủ khoá trong khuôn viên trường):

| DOI | Bài (Crossref) |
|---|---|
| 10.1109/CYBER59472.2023.10256600 | Y. Wu et al., "A Design of Smart Locker System Based on IoT for Campus," IEEE CYBER 2023, Qinhuangdao, pp. 1287-1292 |
| 10.1109/AIDE64228.2025.10987522 | Chandrappa S et al., "Smart Locker 2.0: Leveraging IoT and Machine Learning for Secure, User-Friendly Public Storage," AIDE 2025, pp. 696-700 |
| 10.1109/LT60077.2024.10469610 | M. Balfaqih, "Enhancing Security and Flexibility in Smart Locker Systems: A Multi-Authentication Approach with IoT Integration," L&T 2024, pp. 325-329 |
| 10.1109/ICOIN59985.2024.10572085 | W. Park et al., "Locker-Scale Positioning and Dynamic Access Key Management for IoT-based Smart Delivery Services," ICOIN 2024 (Ho Chi Minh City), pp. 521-525 |
| 10.1109/IDCIoT56793.2023.10053507 | K. R. Umadi et al., "Smart E-Locker System using IoT," IDCIoT 2023, pp. 41-45 |
| 10.1109/ICCMC56507.2023.10084110 | B. Khokher et al., "Advance Computing in IoT based High-Security Smart Bank Locker," ICCMC 2023, pp. 1331-1335 |
