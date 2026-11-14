# Vòng 2 — rà chéo T6 (ui-java): kiểm lại các sửa đổi sau vòng 1

Người rà: agent rà chéo (chỉ đọc; không sửa tệp nào của repo ngoài tệp này). Đối chiếu: mục "Vòng 2" trong `r0-T6-java.md`,
`r1-UI-java.md` (12 mục), `git diff -- src/java test sql config docs/postman`.

## Các mục vòng 1: trạng thái

| Mục r1 | Nội dung | Kết quả kiểm |
|---|---|---|
| 1 | Postman so chữ tiếng Việt cũ | Đã sửa. JSON hợp lệ, 22 dòng đổi, request không đổi; không còn `pm.expect` nào chứa chữ ngoài ASCII. 16 chuỗi mong đợi mới đều có trong `src/java` (grep từng chuỗi); `vnd` in `14,700 VND`. Chưa chạy Newman (T6 ghi rõ) |
| 2 | Câu seed tiếng Việt trong 02 | Đã sửa trong 02 (ghi chú nạp tiền, 12 `demo_case`, phiếu bảo trì, lý do lệnh từ xa) và 06 có `UPDATE` tương ứng. Không script, test hay Postman nào khớp theo các chuỗi cũ (grep `sql/`, `scripts/`, `docs/postman`, `src/java`) |
| 3 | `1 tries left` | Đã sửa (`tries(n)`), cả LCD và trang `/k` (`Wrong PIN. 1 try left.`) |
| 4 | `* quit` | `A: Open * cancel` (16 ký tự); giữ `Checkout` để vừa LCD — chấp nhận |
| 5 | `is rented by you` | `is in your booking` |
| 6–8 | `due_soon`, `topup_rejected`, `overdue` | Đã sửa đúng câu đề nghị |
| 9 | Mẫu theo luật trước v7.1 | Ghi vào `config/mail-templates/README.md:31` — chấp nhận (mẫu không được gửi) |
| 10 | 03 đổi tên plan chỉ theo tên | Nay khớp tên **và** `duration_min`, giống 06 |
| 11 | Comment B2 cũ | Đã sửa |
| 12 | Mất dòng trống cuối mẫu mail | Mọi mẫu kết thúc bằng CRLF; BOM/không BOM như HEAD |

## Kiểm độc lập vòng 2

| Hạng mục | Cách kiểm | Kết quả |
|---|---|---|
| Không đổi logic | So token Java (bỏ comment/chuỗi) với HEAD | Ngoài các khác biệt đã duyệt ở vòng 1, chỉ thêm: `AuthText.tries(int)`, `Locale.US` trong dòng nhật ký kiểm toán `UserController` (GRANT_MONEY) và `TopupDao` (TOPUP_APPROVE). Không chỗ nào đọc lại chuỗi kiểm toán (grep); hash chain tính trên chuỗi đã lưu nên không ảnh hưởng |
| Bỏ `REPLACE` trong 03 | Đọc HEAD: `REPLACE(note, N'Bank CANT-A', N'dãy CANT-A') WHERE note LIKE N'%Bank CANT-A%'` chỉ nhắm đúng một ghi chú seed | Không đổi gì khác: không ghi chú seed nào khác chứa `Bank CANT-A`; với seed tiếng Anh mới, giữ REPLACE sẽ sinh ra `... of dãy CANT-A` (collation không phân biệt hoa thường), nên bỏ là đúng. DB cũ đã bị REPLACE được 06 xử lý (cả hai biến thể) |
| T-SQL 06, idempotent | Dựng `SL_R2_JAVA` 01→05 rồi 06 (bản sao đã đổi tên DB của `build-db.ps1`, `sqlcmd -I -f 65001 -b -l 120`) | Build sạch; 06 trên DB mới: 0 dòng mọi `UPDATE` |
| | Giả lập DB cũ: tên plan/items tiếng Việt, 55 ghi chú nạp tiền, 12 `demo_case`, 3 phiếu cảm biến với tiền tố cũ, 3 phiếu cố định (biến thể `dãy CANT-A`), 10 phiếu đã đóng "lần N", 8 lệnh "lần N"; cộng 1 plan và 1 cỡ "admin đã sửa" | Lần 1: 3 plan, 1 cỡ, 55, 12, 3, 3, 10, 8; plan và cỡ đã sửa được giữ nguyên. Lần 2: 0 ở mọi `UPDATE`, `@@TRANCOUNT` = 0. Sau đó không còn dòng nào chứa ký tự ngoài ASCII ở 4 cột đó; số N được giữ đúng (`round 9`, `request 8`) |
| | Dọn dẹp | Đã xóa `SL_R2_JAVA` và thư mục tạm; `PRJ301_LOCKER` không bị đụng (`create_date` 2026-11-07 08:09:43) |
| BOM | Ba byte đầu của mọi `sql/*.sql` | Đều `EF BB BF` |
| Giới hạn LCD | Chạy `AuthText.oled`/`enroll` cho mọi result, reason, `attempts_left` 0/1/4, mọi open method | Mọi dòng là ASCII, ≤ 16 ký tự, ≤ 2 dòng (dài nhất: `A: Open * cancel`, `Store your items`, `Wrong box! Go to`) |
| Test | JDK 8, biên dịch 89 tệp `src/java` + `test` vào scratchpad `r2-java`; 8 lớp không cần DB | **54/54 pass**; diff test chỉ đổi chuỗi mong đợi |

## Lỗi

| STT | Vị trí (file:line) | Lỗi | Mức độ | Đề nghị sửa (thay chính xác) |
|---|---|---|---|---|
| 1 | `sql/03_v2_v3.sql:773-775`, `:777-779` | Tôi đã bỏ sót ở vòng 1: 03 vẫn **dịch ngược sang tiếng Việt** hai nhãn mà seed ghi tiếng Anh. Trên DB build mới: 8 dãy tên `Dãy A`/`Dãy B` (hiện ở tiêu đề dãy trên bản đồ `locker-map.js:606` và trang Locker banks), trong khi `DOMB-A`/`DOMB-B` (thêm ở `03:1949`, sau khối đổi tên) vẫn là `Bank A`/`Bank B`, nên cùng một danh sách lẫn hai thứ tiếng. Ngoài ra `system` có `full_name` là `Tài khoản hệ thống` (người thực hiện các dòng tự động trong nhật ký kiểm toán). Đây là nhãn giao diện như tên plan, không phải tên người hay địa điểm. | trung bình | 03: thay khối `-- Locker banks: "Bank A" -> "Dãy A"` bằng `-- Locker banks: the names are UI labels and stay English; an older build renamed them to "Dãy X"` + `UPDATE dbo.LockerBank SET name = N'Bank ' + SUBSTRING(name, 5, 10) WHERE name LIKE N'Dãy _%';`, và khối tài khoản hệ thống bằng `UPDATE dbo.Users SET full_name = N'System account' WHERE username = N'system' AND full_name = N'Tài khoản hệ thống';`. Thêm hai `UPDATE` giống hệt vào 06 (in `@@ROWCOUNT` như các khối khác). Lưu ý `N'Dãy '` dài 4 ký tự nên dùng `SUBSTRING(name, 5, 10)` |
| 2 | `sql/02_data_v1.sql:753-754` | Dòng kiểm toán seed ghi `amount 50000 VND`, còn dòng mới ghi `50,000 VND`. | thấp | `N'Approved TopupRequest 1 (amount 50,000 VND) for student1'`, `N'Approved TopupRequest 2 (amount 100,000 VND) for student2'` (chỉ trong 02; không sửa dòng cũ trên DB đang chạy, vì hash chain tính trên chuỗi đã lưu) |
| 3 | `docs/postman/...collection.json` | Chưa chạy Newman sau khi đổi assertion (T6 đã ghi rõ). | thấp | Chạy `scripts\proof\newman.ps1 -Database SL_*` trên Tomcat test khi có thể |

KẾT LUẬN: CHƯA ĐẠT
