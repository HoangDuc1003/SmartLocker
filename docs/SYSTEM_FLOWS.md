# SmartLocker: luồng hệ thống và nghiệp vụ

Tài liệu mô tả đường đi của dữ liệu và vòng đời một lượt gửi đồ, đúng với code hiện tại (v2).
Hợp đồng API chi tiết của thiết bị nằm ở [spec/smart-locker-v2.md](spec/smart-locker-v2.md) mục 4.

---

## Phần 1: Dashboard và tiến trình nền

### 1.1 Đường đi dữ liệu

```mermaid
flowchart TD
    DB[(SQL Server)] -->|truy vấn tổng hợp, 2 giây một lần| LM["LockerMonitor (luồng nền)"]
    LM -->|thay nguyên ảnh chụp| CACHE["AtomicReference&lt;Snapshot&gt;"]
    API["DashboardApi /api/dashboard"] -->|chỉ đọc bộ nhớ, không truy vấn DB| CACHE
    Page["dashboard.jsp + js/dashboard.js"] -->|setTimeout 5 giây, hủy sau 8 giây bằng AbortController| API
    LM -->|15 giây một lần| PROC["Procedure: Device_MarkOffline(90), Deposit_ExpireNoShow,
    Deposit_ExpireOverdue, RemoteCommand_Expire"]
```

### 1.2 Các thành phần
1. **`LockerMonitor`** (`ServletContextListener`, một luồng nền):
   - Mỗi 2 giây dựng `Snapshot` (KPI, số ngăn theo trạng thái, cảnh báo mới, tình trạng hộp, lượt mở gần đây) và kết quả kiểm tra chuỗi băm audit (`AuditVerifier`).
   - Mỗi 15 giây chạy các procedure hết hạn. Hộp im lặng quá 90 giây chuyển `OFFLINE`.
   - Hộp minh họa (`"demo":true` trong `OperatingProfile`) được giả heartbeat; hộp thật `LOCKER-01` thì không.
2. **`DashboardApi`**: trả JSON từ ảnh chụp; trả 503 nếu ảnh chụp chưa có (vài giây đầu sau khi deploy).
   `?device=ID` là truy vấn riêng cho biểu đồ của một hộp.
3. **`dashboard.jsp`**: lần vẽ đầu do server render; sau đó `dashboard.js` hỏi lại theo chu kỳ người dùng chọn,
   không gửi yêu cầu mới khi yêu cầu cũ chưa xong, và chỉ cập nhật ô có giá trị thay đổi.

---

## Phần 2: Vòng đời một lượt gửi

### 2.1 Đặt và dùng tủ

```mermaid
flowchart TD
    Start(["Đăng ký / đăng nhập"]) --> Map["Sơ đồ tủ: chọn ngăn trống"]
    Map --> Form["Chọn gói và cách mở: mật mã, thẻ từ, vân tay"]
    Form --> Confirm["Popup xác nhận: giá, cọc thẻ, tổng tiền"]
    Confirm --> Reserve{"Deposit_Reserve"}
    Reserve -- "50030 / 50041 thiếu tiền" --> Err["Thông báo lỗi tiếng Việt (Web.sqlMessage)"]
    Reserve -- "50031 3 lần không đến trong 7 ngày" --> Err
    Reserve -- "50032 đang có lượt gửi" --> Err
    Reserve -- "50033 ngăn vừa bị đặt" --> Err
    Reserve -- "50035 hộp mất kết nối" --> Err
    Reserve -- "Thành công" --> Held["RESERVED, giữ chỗ 15 phút, đã trừ tiền"]
    Held --> Mine["Tủ của tôi: mật mã hoặc mã đăng ký thẻ/vân tay"]
    Mine --> Open1{"Mở lần 1 tại hộp (auth) hoặc điện thoại (/k/LOCKER-01)"}
    Open1 -- "CHECK_IN" --> Active["ACTIVE, ngăn OCCUPIED, đếm tới due_at"]
    Held -- "Hủy trước khi đến" --> Cancel["CANCELLED, hoàn 100%"]
    Held -- "Hết 15 phút" --> NoShow["NO_SHOW, hoàn 90%, giữ 10%"]
    Active -- "Gia hạn (tối đa 3 lần)" --> Active
    Active --> Open2{"Mở lần 2"}
    Open2 -- "PICKUP" --> Done["COMPLETED, ngăn AVAILABLE"]
    Active -- "Quá due_at" --> Auto["Deposit_ExpireOverdue: COMPLETED, ngăn AVAILABLE"]
```

### 2.2 Mở tủ tại hộp (`POST /api/device/auth`)

```mermaid
sequenceDiagram
    participant Box as Hộp ESP32
    participant Api as DeviceAuthApi
    participant Db as Device_Authorize
    Box->>Api: X-API-Key + {"method":"PIN","pin":"..."}
    Api->>Api: kiểm tra định dạng (400 nếu sai)
    Api->>Db: device_id lấy từ khóa, không lấy từ body
    Db-->>Api: UNLOCK (CHECK_IN / PICKUP) hoặc DENY + reason
    Api-->>Box: message ASCII cho màn OLED, open_sec, attempts_left, retry_after_sec
```

- Lý do từ chối thường gặp: `WRONG_CODE`, `UNKNOWN_CARD`, `UNKNOWN_FINGER`, `CARD_BLOCKED`, `METHOD_MISMATCH`, `LOCKED_OUT`.
- Chỉ các lần đoán sai mới tính vào bộ đếm. Sai 5 lần thì hộp tạm khóa 120 giây. Điện thoại có bộ đếm riêng.
- Điện thoại (`/api/kiosk/unlock`) không mở trực tiếp: máy chủ xếp lệnh `UNLOCK`, hộp nhận lệnh ở heartbeat kế tiếp,
  và lúc đó lượt gửi mới chuyển CHECK_IN hoặc PICKUP. Hộp không thấy heartbeat trong 10 giây thì trả `DEVICE_OFFLINE`.

### 2.3 Thẻ từ và vân tay
- Đặt bằng thẻ lần đầu: cần đủ tiền cho giá gói và cọc 30.000 đ; cọc chỉ bị trừ khi đăng ký thẻ xong (`enroll/finish`).
- Đăng ký tại hộp: bấm B/C, nhập mã đăng ký 6 số (hết hạn sau 10 phút, lấy mã mới ở "Tủ của tôi").
- Báo mất thẻ: thẻ chuyển `LOST`, UID nằm trong `blocked_cards` của heartbeat; dùng lại sẽ bị `CARD_BLOCKED`.
- Xóa vân tay: máy chủ xếp lệnh `DELETE_FP` cho hộp; nếu đang có lượt gửi bằng vân tay trên hộp đó, lượt đó nhận mã đăng ký mới.

### 2.4 Bảng tình huống

| Tình huống | Điều kiện | Hệ thống làm gì | Kết quả |
|---|---|---|---|
| Đặt thành công | Đủ tiền, ngăn trống, hộp hoạt động | Trừ tiền, giữ chỗ 15 phút, ghi audit `RESERVE` | Lượt `RESERVED`, ngăn `RESERVED` |
| Thiếu tiền | Số dư nhỏ hơn giá (và cọc thẻ nếu có) | `THROW 50030` / `50041`, không đổi gì | Báo lỗi |
| Đang có lượt gửi | Đã có lượt `RESERVED` hoặc `ACTIVE` | `THROW 50032` | Báo lỗi |
| Hay không đến | 3 lần `NO_SHOW` trong 7 ngày | `THROW 50031` | Tạm cấm đặt |
| Hộp mất kết nối | Hộp `OFFLINE` | `THROW 50035` | Báo lỗi |
| Không đến | Hết 15 phút giữ chỗ | `Deposit_ExpireNoShow`: hoàn 90% | Lượt `NO_SHOW`, ngăn trống |
| Hủy | Người dùng hủy trước khi mở lần đầu | Hoàn đủ số đã trả | Lượt `CANCELLED`, ngăn trống |
| Quá hạn | `due_at` đã qua | `Deposit_ExpireOverdue`, audit `AUTO_RELEASE_OVERDUE` | Lượt `COMPLETED`, ngăn trống |
| Mở từ xa | Nhân viên gửi lệnh có lý do | `RemoteCommand` chờ hộp nhận ở heartbeat; hết hạn nếu không ai nhận | Hộp mở, luật ghi nhận `STAFF_OPEN` |
| Mở giả | Lượt mở `REMOTE`/`PHONE` không có lệnh hợp lệ | `RuleEngine` | Cảnh báo `SUSPECTED_SPOOF` |
| Cảm biến hỏng | Số đo ngoài khoảng, đồng hồ lệch, hết hạn hiệu chuẩn | `RuleEngine` | Cảnh báo `SENSOR_FAULT`, phiếu bảo trì |

### 2.5 Trạng thái ngăn tủ

```mermaid
stateDiagram-v2
    [*] --> AVAILABLE
    AVAILABLE --> RESERVED : Deposit_Reserve
    RESERVED --> AVAILABLE : hủy / không đến
    RESERVED --> OCCUPIED : mở lần 1 (CHECK_IN)
    OCCUPIED --> AVAILABLE : mở lần 2 (PICKUP) / quá hạn tự giải phóng
    AVAILABLE --> MAINTENANCE : kỹ thuật viên / nhân viên
    MAINTENANCE --> AVAILABLE : đóng phiếu bảo trì
```

Trên sơ đồ tủ còn có các trạng thái hiển thị `OVERDUE`, `ALERT`, `OFFLINE`: chúng được tính từ lượt gửi, cảnh báo đang mở
và trạng thái hộp, không lưu trong cột `LockerSlot.status`.
