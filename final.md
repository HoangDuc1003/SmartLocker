# Smart Locker (Đề 01): làm theo bài mẫu Pouring-System và thêm 5 trường hợp thực tế

Tài liệu này dành cho nhóm làm Đề 01 PRJ301 FA26. Làm phần web trước. Tuần sau khi xong IoT thì cắm ESP32 vào, phía web không phải sửa gì.

---

## 0. Tóm tắt

- **Phần nền** làm đúng theo đề (Workshop 1 và 2). Bài mẫu Pouring-System dùng để học cách tổ chức: API nhận cả lô phiên, Weka chấm điểm rủi ro, nhật ký nối chuỗi băm, health API.
- **5 trường hợp thực tế thêm vào:**
  1. Tủ mất mạng, dữ liệu gửi lên trễ (`DEVICE_OFFLINE`)
  2. Nhân viên mở tủ từ xa: không báo nhầm thành `FORCED_OPEN`, và bắt được lệnh mở giả
  3. Mất thẻ, có người cầm thẻ đó đi mở tủ (`LOST_CARD_USED`)
  4. Đặt ngăn trước nhưng không đến (`NO_SHOW`)
  5. Cảm biến hỏng hoặc hết hạn hiệu chuẩn (`SENSOR_FAULT`)
- **Giữ thiết kế gọn:** không thêm API mới (chỉ mở rộng `/api/health`), không thêm thư viện, chỉ thêm 1 bảng (`RemoteCommand`) và 4 cột ở `LockerSession`. Mọi luật theo phiên nằm trong một lớp `RuleEngine`.
- **Khi chưa có IoT:** lớp `ScenarioSender` gửi đúng JSON mà ESP32 sẽ gửi. Tuần sau ESP32 gửi cùng JSON đó.

> Lưu ý: 6 nhãn của đề (NORMAL, OVERDUE, FORCED_OPEN, WRONG_USER, ITEM_LEFT, SUSPECTED_SPOOF) là **nhãn phiên dùng để train Weka**, giữ nguyên. 5 trường hợp mới sinh ra **nhãn cảnh báo vận hành** (`Alert.label`), không thêm lớp mới vào mô hình.

---

## 1. Học gì từ bài mẫu Pouring-System

| Bài mẫu | Bên mình | Lấy ý gì |
|---|---|---|
| `PourAPI` (`/api/pour-session/batch`) | `LockerSessionApi` (`/api/locker/batch`) | Nhận cả lô, lưu xong mới chấm điểm. Mẫu loại `MANUAL_BUTTON`, `NO_CUP` khỏi ML; mình loại `STAFF_OPEN`, `SENSOR_FAULT` |
| `WekaService` | `RiskScorer` | Nạp model một lần từ `WEB-INF/model`, thiếu model thì chạy chế độ dự phòng, risk = 1 − P(NORMAL), ngưỡng 0.80 |
| Luật trước, ML sau | `RuleEngine` → `RiskScorer` | Có luật khớp thì luật thắng, điểm ML chỉ làm bằng chứng phụ |
| `Audit_Append` + `ChainVerificationService` + `AuditChainDatabaseIntegrationTest` | `Audit_Append` (đề) + `AuditVerifier` + ca TestNG sửa dòng nhật ký | Giữ nguyên ý tưởng |
| `HealthAPI` | `HealthApi` | Mở rộng thành heartbeat hai chiều (trường hợp 1) |
| ACTIVE/MAINTENANCE do người đặt, OFFLINE do hệ thống suy ra | Giữ nguyên | Đây chính là trường hợp 1 |
| `Alert_Resolve_Maintenance` | Alert → MaintenanceTicket | Trường hợp 5 |

**3 chỗ nên làm tốt hơn bài mẫu (thầy hay hỏi):**

1. Mẫu gọi thẳng IP của ESP32 (`PourController` → `http://192.168.4.1/pour`), đổi mạng là hỏng. Bên mình để thiết bị tự hỏi server mỗi 10 giây (heartbeat) và server trả lệnh trong phản hồi. Server không cần biết IP thiết bị, và giả lập được khi chưa có phần cứng.
2. `SecurityFilter` của mẫu chỉ kiểm tra đã đăng nhập hay chưa. Bên mình kiểm tra quyền theo tài nguyên (`RESOURCE_BY_PATH` + `PermissionDao` như đề), còn quyền "chỉ của mình" thì kiểm tra trong stored procedure.
3. Mẫu viết cứng `device_id = 1` và actor = 2. Bên mình lấy `device_id` từ API key, và dùng một tài khoản `system` riêng cho các thao tác tự động.

---

## 2. Thứ tự làm

**Tuần này (chưa có IoT)**
1. Tạo project mới `SmartLocker` (NetBeans 13, Ant, JDK 8, Tomcat 9). **Không sửa project UserManagement**, chỉ lấy lại cách làm phân trang, xuất CSV và kiểm tra dữ liệu đầu vào.
2. Phần nền theo đề: 14 + 4 bảng, đăng nhập BCrypt, `SecurityFilter`, CRUD cho 6 thực thể.
3. Workshop 2: nạp TON_IoT, `ModelTrainer`, `LockerSessionApi` + `DataReplayer`, `Audit_Append` + `AuditVerifier`, dashboard.
4. Làm 5 trường hợp theo thứ tự 1 → 5. Trường hợp 1 dựng heartbeat, các trường hợp sau dùng lại.
5. Viết TestNG (mục 13).

**Tuần sau (có IoT)**

6. Viết firmware theo hợp đồng ở mục 12, rồi chạy lại đúng các kịch bản của `ScenarioSender` bằng tủ thật.
7. Thu khoảng 100 phiên có nhãn rồi chạy `TransferCheck`. Đây là điểm mới chính của đề và là phần cộng tối đa 2 điểm.

**Trước khi nộp:** README, video không quá 5 phút, báo cáo (mục 14).

---

## 3. Phần nền: những lỗi trong mã mẫu của đề cần sửa

Các lỗi dưới đây đều có thật trong mã mẫu. Lỗi 1 đã được kiểm tra trực tiếp với Gson.

**1. `rfid_ok` bị đọc thành false.** `DataReplayer` gửi `rs.getDouble("rfid_ok")` nên JSON có dạng `"rfid_ok":1.0`. Hàm `getAsBoolean()` của Gson đổi `1.0` thành **false**, nên mọi phiên phát lại có `rfid_ok = false`, cửa có mở là thành `FORCED_OPEN` hàng loạt. Cần sửa ở cả hai đầu:

```java
// DataReplayer
session.addProperty("rfid_ok", rs.getBoolean("rfid_ok"));

// LockerSessionApi: accept both true and 1.0
private static boolean readBool(JsonObject json, String key) {
    JsonPrimitive p = json.getAsJsonPrimitive(key);
    return p.isBoolean() ? p.getAsBoolean() : p.getAsDouble() != 0;
}
```

**2. Lệch 7 tiếng.** `DataReplayer` định dạng giờ theo máy (UTC+7), còn server ghi `SYSUTCDATETIME()` theo UTC. Thêm `stamp.setTimeZone(TimeZone.getTimeZone("UTC"));`. Trên ESP32 thì dùng `configTime(0, 0, "pool.ntp.org");`.

**3. Chuỗi băm báo bị sửa dù không ai sửa.** Nếu gọi `Audit_Append` với `@actor = NULL` thì `CONCAT` trong SQL biến NULL thành chuỗi rỗng, còn `rs.getInt()` trong `AuditVerifier` trả về 0, tức chuỗi "0". Hai bên băm ra khác nhau. Vì vậy **luôn truyền actor thật**, thao tác tự động thì dùng user `system`. Với `object_id` cũng vậy.

**4. API key không khớp.** Băm khoá trong SQL phải dùng chuỗi `'...'` (VARCHAR). Nếu viết `N'...'` thì SQL Server băm theo UTF-16LE, không khớp với Java băm UTF-8.

**5. Lỗi thật bị nuốt.** `LockerSessionApi` bắt mọi `SQLException` như thể bị trùng phiên. Chỉ bỏ qua khi mã lỗi là 2627 hoặc 2601 (vi phạm UNIQUE), xem mục 6.

**4 bảng thực thể đề yêu cầu nhưng chưa cho sẵn.** Cả 5 trường hợp đều dùng tới các bảng này:

```sql
CREATE TABLE LockerBank (
  bank_id   INT IDENTITY PRIMARY KEY,
  bank_code NVARCHAR(20) UNIQUE NOT NULL,
  location  NVARCHAR(80),
  device_id INT NULL REFERENCES Device,          -- one ESP32 drives one bank
  status    NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE');
ALTER TABLE LockerSlot ADD CONSTRAINT FK_LockerSlot_Bank FOREIGN KEY (bank_id) REFERENCES LockerBank(bank_id);

CREATE TABLE UserCard (
  card_id   INT IDENTITY PRIMARY KEY,
  card_uid  NVARCHAR(32) UNIQUE NOT NULL,        -- RC522 UID in hex
  user_id   INT NOT NULL REFERENCES Users,
  status    NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE',   -- ACTIVE, LOST, BLOCKED
  issued_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  lost_at   DATETIME2 NULL);

CREATE TABLE StoragePlan (
  plan_id      INT IDENTITY PRIMARY KEY,
  plan_name    NVARCHAR(40) NOT NULL,
  duration_min INT NOT NULL,
  grace_min    INT NOT NULL DEFAULT 10,
  price        INT NOT NULL DEFAULT 0,
  is_active    BIT NOT NULL DEFAULT 1);

CREATE TABLE Deposit (
  deposit_id   BIGINT IDENTITY PRIMARY KEY,
  user_id      INT NOT NULL REFERENCES Users,
  slot_id      INT NOT NULL REFERENCES LockerSlot(locker_slot_id),
  plan_id      INT NOT NULL REFERENCES StoragePlan,
  card_id      INT NULL REFERENCES UserCard,
  status       NVARCHAR(20) NOT NULL,             -- RESERVED, ACTIVE, COMPLETED, NO_SHOW, CANCELLED
  reserved_at  DATETIME2 DEFAULT SYSUTCDATETIME(),
  hold_until   DATETIME2 NULL,                    -- a reservation expires here
  started_at   DATETIME2 NULL,
  due_at       DATETIME2 NULL,                    -- online extension moves this forward
  ended_at     DATETIME2 NULL,
  extend_count INT NOT NULL DEFAULT 0);
```

---

## 4. Toàn cảnh 5 trường hợp

```
ESP32 (tuần sau)  hoặc  ScenarioSender (tuần này)
   │
   │  POST /api/health  mỗi 10 giây   {"slots":[{"slot_code":"A01","occupied":true}]}
   │  <── {"commands":[...], "blocked_cards":[...], "reserved":[...]}     trường hợp 1, 2, 3, 4
   │
   │  POST /api/locker/batch  sau mỗi phiên   {"sessions":[...]}
   v
LockerSessionApi ─> AlertService ─> RuleEngine (luật theo phiên)          trường hợp 2, 3, 5
                                 └> RiskScorer (Weka, chỉ khi ml_eligible)
LockerMonitor (30 giây một lần, luật theo thời gian)                      trường hợp 1, 4
   Device_MarkOffline -> Deposit_ExpireNoShow -> RemoteCommand_Expire
```

| # | Tình huống | Kết quả | Phát hiện ở | Vai trò liên quan | Bảng chính |
|---|---|---|---|---|---|
| 1 | Tủ mất mạng | Alert `DEVICE_OFFLINE`, sơ đồ chuyển xám | LockerMonitor | Operator, Technician | Device |
| 2 | Nhân viên mở tủ từ xa | Không cảnh báo. Nếu lệnh giả thì `SUSPECTED_SPOOF` | RuleEngine | Operator, Auditor | RemoteCommand |
| 3 | Mất thẻ | Thiết bị chặn thẻ. Lọt qua thì `LOST_CARD_USED` | heartbeat + RuleEngine | End user, Operator | UserCard |
| 4 | Đặt trước không đến | Deposit `NO_SHOW`, trả ngăn. 3 lần thì khoá đặt trước | LockerMonitor | End user | Deposit |
| 5 | Cảm biến hỏng | Alert `SENSOR_FAULT` + phiếu bảo trì, ngăn chuyển MAINTENANCE | RuleEngine | Technician | SensorType, Calibration, MaintenanceTicket |

---

## 5. Thay đổi CSDL dùng chung (tệp `sql/03_scenarios.sql`)

```sql
-- account for automatic actions, insert it FIRST so user_id = 1 (Java uses that constant)
INSERT INTO Users (username, password_hash, full_name, status)
VALUES (N'system', REPLICATE('x', 60), N'System account', N'DISABLED');   -- cannot log in

-- 4 optional columns: the replayed public data leaves them NULL
ALTER TABLE LockerSession ADD
  slot_id     INT NULL REFERENCES LockerSlot(locker_slot_id),
  card_uid    NVARCHAR(32) NULL,
  open_source NVARCHAR(10) NULL,        -- RFID | REMOTE
  command_id  BIGINT NULL;              -- no FK on purpose: a forged id must still be stored as evidence

CREATE TABLE RemoteCommand (
  command_id   BIGINT IDENTITY PRIMARY KEY,
  device_id    INT NOT NULL REFERENCES Device,
  slot_id      INT NOT NULL REFERENCES LockerSlot(locker_slot_id),
  action       NVARCHAR(20) NOT NULL DEFAULT 'UNLOCK',
  reason       NVARCHAR(200) NOT NULL,
  requested_by INT NOT NULL REFERENCES Users,
  status       NVARCHAR(20) NOT NULL DEFAULT 'PENDING',   -- PENDING, SENT, DONE, EXPIRED
  created_at   DATETIME2 DEFAULT SYSUTCDATETIME(),
  expires_at   DATETIME2 NOT NULL,
  done_at      DATETIME2 NULL,
  session_id   BIGINT NULL);                               -- the session that used it

-- new protected resources, run BEFORE the AUDITOR grant of the assignment
INSERT INTO Permissions (resource, action)
SELECT r.res, a.act
FROM (VALUES (N'LOCKERBANK'), (N'STORAGEPLAN'), (N'USERCARD'), (N'MYCARD'),
             (N'DEPOSIT'), (N'BOOKING'), (N'COMMAND')) r(res)
CROSS JOIN (VALUES (N'READ'), (N'WRITE')) a(act);

-- demo data
INSERT INTO Device (device_code, location, firmware, api_key_hash)
VALUES (N'LOCKER-01', N'Library hall', N'1.0',
        LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', 'device-1-api-key'), 2)));   -- VARCHAR, not N''
INSERT INTO LockerBank (bank_code, location, device_id) VALUES (N'BANK-A', N'Library hall', 1);
INSERT INTO LockerSlot (slot_code, bank_id, size_cm, status) VALUES
  (N'A01', 1, N'30x30x45', N'AVAILABLE'), (N'A02', 1, N'30x30x45', N'AVAILABLE'),
  (N'A03', 1, N'30x30x45', N'AVAILABLE'), (N'A04', 1, N'40x40x60', N'AVAILABLE');
INSERT INTO StoragePlan (plan_name, duration_min, grace_min, price) VALUES
  (N'2 hours', 120, 10, 5000),
  (N'Demo 2 minutes', 2, 1, 0);              -- makes OVERDUE appear quickly in the video
INSERT INTO SensorType (name, unit, min_valid, max_valid) VALUES
  (N'DOOR', N's', 0, 3600), (N'WEIGHT', N'g', -200, 20000), (N'STAY', N'min', 0, 10080);
INSERT INTO Calibration (device_id, sensor_type_id, offset_val, scale_val, version, valid_until, created_by)
SELECT 1, sensor_type_id, 0, 1, 1, DATEADD(MONTH, 3, CAST(SYSUTCDATETIME() AS DATE)), 1
FROM SensorType WHERE name = N'WEIGHT';    -- without this row every session becomes SENSOR_FAULT
-- after student1 and student2 are registered:
-- INSERT INTO UserCard (card_uid, user_id) VALUES (N'04A1B2C3', <student1 id>), (N'0499AABB', <student2 id>);
```

**View tô màu sơ đồ.** View này tính luôn các trạng thái mà 5 trường hợp sinh ra, và đếm vào yêu cầu "2 view":

```sql
CREATE OR ALTER VIEW v_LockerSlotMap AS
SELECT s.locker_slot_id, s.slot_code, b.bank_id, b.bank_code, v.device_id,
  CASE
    WHEN v.status = N'OFFLINE'     THEN N'OFFLINE'                         -- case 1
    WHEN s.status = N'MAINTENANCE' THEN N'MAINTENANCE'                     -- case 5
    WHEN EXISTS (SELECT 1 FROM Alert a JOIN LockerSession ls ON ls.session_id = a.session_id
                 WHERE ls.slot_id = s.locker_slot_id AND a.status = N'OPEN') THEN N'ALERT'
    WHEN EXISTS (SELECT 1 FROM Deposit d WHERE d.slot_id = s.locker_slot_id
                 AND d.status = N'ACTIVE' AND d.due_at < SYSUTCDATETIME()) THEN N'OVERDUE'
    ELSE s.status                                                          -- AVAILABLE, RESERVED, OCCUPIED
  END AS display_status
FROM LockerSlot s
JOIN LockerBank b ON b.bank_id = s.bank_id
LEFT JOIN Device v ON v.device_id = b.device_id;
```

**Dữ liệu rác không được vào mô hình.** Sửa view đặc trưng của đề như sau:

```sql
CREATE OR ALTER VIEW v_LockerSession_Features AS
SELECT s.session_id, s.device_id, s.door_open_sec, s.weight_delta_g, s.unlock_count, s.rfid_ok, s.stay_min, l.label
FROM LockerSession s JOIN LockerSessionLabel l ON l.session_id = s.session_id
WHERE ISNULL(s.open_source, N'RFID') <> N'REMOTE'                              -- case 2
  AND NOT EXISTS (SELECT 1 FROM Alert a
                  WHERE a.session_id = s.session_id AND a.label = N'SENSOR_FAULT');   -- case 5
```

**Phân quyền cho tài nguyên mới.** Tách `MYCARD`/`BOOKING` (người gửi đồ tự thao tác) khỏi `USERCARD`/`DEPOSIT` (nhân viên quản lý). Nếu dùng chung một tài nguyên thì END_USER có quyền ghi vào trang quản lý thẻ của tất cả mọi người.

| Tài nguyên | ADMIN | OPERATOR | TECHNICIAN | AUDITOR | END_USER |
|---|---|---|---|---|---|
| COMMAND | RW | RW | – | R | – |
| USERCARD, DEPOSIT | RW | RW | – | R | – |
| MYCARD, BOOKING | – | – | – | – | RW (chỉ của mình, kiểm tra trong SP) |
| MAINTENANCE, CALIBRATION | RW | R | RW | R | – |

```java
// SecurityFilter.RESOURCE_BY_PATH, add:
RESOURCE_BY_PATH.put("/RemoteCommandController", "COMMAND");
RESOURCE_BY_PATH.put("/UserCardController", "USERCARD");
RESOURCE_BY_PATH.put("/MyCardController", "MYCARD");
RESOURCE_BY_PATH.put("/DepositController", "DEPOSIT");
RESOURCE_BY_PATH.put("/BookingController", "BOOKING");
RESOURCE_BY_PATH.put("/MaintenanceController", "MAINTENANCE");
RESOURCE_BY_PATH.put("/CalibrationController", "CALIBRATION");
```

---

## 6. Trường hợp 1: Tủ mất mạng, dữ liệu gửi lên trễ

**Thực tế:** Wi-Fi thư viện chập chờn hoặc ESP32 bị rút điện. Nhân viên phải biết tủ đang "mù", không thể nghĩ là mọi thứ vẫn bình thường. Khi có mạng lại, các phiên trong bộ đệm được đẩy lên trễ.

**Hệ thống làm gì:**
- ESP32 gửi heartbeat 10 giây một lần, server cập nhật `last_seen`.
- Quá 60 giây không thấy heartbeat: thiết bị chuyển `OFFLINE`, sinh Alert `DEVICE_OFFLINE`, sơ đồ chuyển xám, nút mở từ xa và đặt trước bị khoá.
- Có heartbeat lại: thiết bị về `ACTIVE`, alert tự đóng. Trạng thái `MAINTENANCE` do người đặt thì giữ nguyên.
- Phiên gửi trễ vẫn đúng vì luật dùng giờ đo trên thiết bị (`measured_at`), không dùng giờ nhận. Trang lịch sử phiên hiện thêm cột `DATEDIFF(MINUTE, measured_at, ingested_at) AS upload_delay_min` và tô đậm khi lớn hơn 5.

**CSDL**

```sql
CREATE OR ALTER PROCEDURE Device_Heartbeat @device_id INT
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
  DECLARE @was NVARCHAR(20) = (SELECT status FROM Device WHERE device_id = @device_id);
  BEGIN TRAN;
  UPDATE Device SET last_seen = SYSUTCDATETIME(),
         status = CASE WHEN status = N'OFFLINE' THEN N'ACTIVE' ELSE status END   -- MAINTENANCE stays
  WHERE device_id = @device_id;
  IF @was = N'OFFLINE'
  BEGIN
    UPDATE Alert SET status = N'RESOLVED'
    WHERE device_id = @device_id AND label = N'DEVICE_OFFLINE' AND status = N'OPEN';
    EXEC Audit_Append @sys, N'BACK_ONLINE', N'DEVICE', @device_id, NULL;
  END
  COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE Device_MarkOffline @timeout_sec INT = 60
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
  DECLARE @gone TABLE (device_id INT);
  DECLARE @id INT, @alert INT;
  BEGIN TRAN;
  UPDATE Device SET status = N'OFFLINE'
  OUTPUT inserted.device_id INTO @gone
  WHERE status = N'ACTIVE'
    AND (last_seen IS NULL OR last_seen < DATEADD(SECOND, -@timeout_sec, SYSUTCDATETIME()));
  WHILE EXISTS (SELECT 1 FROM @gone)
  BEGIN
    SELECT TOP 1 @id = device_id FROM @gone;
    INSERT INTO Alert (device_id, session_id, source, label) VALUES (@id, NULL, N'RULE', N'DEVICE_OFFLINE');
    SET @alert = SCOPE_IDENTITY();
    INSERT INTO AlertEvidence (alert_id, item, value_text)
    SELECT @alert, N'last_seen_utc', ISNULL(CONVERT(NVARCHAR(30), last_seen, 120), N'never')
    FROM Device WHERE device_id = @id;
    EXEC Audit_Append @sys, N'MARK_OFFLINE', N'DEVICE', @id, NULL;
    DELETE FROM @gone WHERE device_id = @id;
  END
  COMMIT;
END;
```

**Java: lấy `device_id` từ API key, không tin số trong body** (sửa nhánh thiết bị của `SecurityFilter`):

```java
if (DEVICE_API_PATHS.contains(path)) {
    Integer deviceId;
    try {
        deviceId = new DeviceDao().findIdByApiKey(req.getHeader("X-API-Key"));
    } catch (SQLException e) {
        throw new ServletException(e);
    }
    if (deviceId == null) {
        res.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid API key");
        return;
    }
    req.setAttribute("DEVICE_ID", deviceId);   // APIs use this, never the device_id written in the body
    chain.doFilter(request, response);
    return;
}
```

```java
// DeviceDao
public Integer findIdByApiKey(String apiKey) throws SQLException {
    if (apiKey == null || apiKey.isEmpty()) {
        return null;
    }
    String sql = "SELECT device_id FROM Device WHERE api_key_hash = ?";
    try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
        ps.setString(1, SecurityUtils.sha256Hex(apiKey));
        try (ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : null;
        }
    }
}

public void heartbeat(int deviceId) throws SQLException {
    try (Connection conn = DbContext.getConnection();
         CallableStatement cs = conn.prepareCall("{call Device_Heartbeat(?)}")) {
        cs.setInt(1, deviceId);
        cs.execute();
    }
}

// SecurityUtils
public static String sha256Hex(String text) {
    try {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(text.getBytes("UTF-8"));
        StringBuilder sb = new StringBuilder();
        for (byte b : digest) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    } catch (Exception e) {
        throw new IllegalStateException(e);
    }
}
```

**`HealthApi`: một API phục vụ cả trường hợp 1 đến 4**

```java
@WebServlet("/api/health")
public class HealthApi extends HttpServlet {
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");   // set by SecurityFilter from X-API-Key
        JsonObject body = JsonParser.parseReader(req.getReader()).getAsJsonObject();
        Gson gson = new Gson();
        JsonObject reply = new JsonObject();
        try {
            new DeviceDao().heartbeat(deviceId);                                                   // case 1
            DepositDao depositDao = new DepositDao();
            if (body.has("slots")) {
                for (JsonElement element : body.getAsJsonArray("slots")) {
                    JsonObject slot = element.getAsJsonObject();
                    if (slot.get("occupied").getAsBoolean()) {
                        depositDao.checkIn(deviceId, slot.get("slot_code").getAsString());         // case 4
                    }
                }
            }
            reply.add("commands", gson.toJsonTree(new RemoteCommandDao().takePending(deviceId)));  // case 2
            reply.add("blocked_cards", gson.toJsonTree(new UserCardDao().blockedUids()));         // case 3
            reply.add("reserved", gson.toJsonTree(depositDao.reservedFor(deviceId)));              // case 4
        } catch (SQLException e) {
            log("Heartbeat failed for device " + deviceId, e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            return;
        }
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write(reply.toString());
    }
}
```

**`LockerMonitor`: luật theo thời gian, chạy nền trong Tomcat, không cần thêm thư viện**

```java
package service;

@WebListener
public class LockerMonitor implements ServletContextListener {

    private ScheduledExecutorService scheduler;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleWithFixedDelay(() -> {
            runProcedure("{call Device_MarkOffline(60)}");   // first: no-show skips offline devices
            runProcedure("{call Deposit_ExpireNoShow}");
            runProcedure("{call RemoteCommand_Expire}");
        }, 30, 30, TimeUnit.SECONDS);
    }

    private void runProcedure(String call) {
        try (Connection conn = DbContext.getConnection(); CallableStatement cs = conn.prepareCall(call)) {
            cs.execute();
        } catch (SQLException e) {
            // must catch: one uncaught exception silently cancels every later run
            System.err.println("LockerMonitor " + call + " failed: " + e.getMessage());
        }
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        scheduler.shutdownNow();   // NetBeans redeploys often, do not leak the thread
    }
}
```

**Giao diện:** Dashboard có huy hiệu thiết bị `ACTIVE` (xanh) hoặc `OFFLINE` (xám) kèm dòng "last seen 3 min ago", tính bằng `DATEDIFF(SECOND, last_seen, SYSUTCDATETIME())`. Alert `DEVICE_OFFLINE` không có `session_id`, nên trang cảnh báo đừng hiện link tới phiên.

**Thử ngay khi chưa có IoT:** chạy `ScenarioSender` với `heartbeat`. Chương trình gửi 6 nhịp rồi dừng. Khoảng 60 đến 90 giây sau thiết bị chuyển OFFLINE và có alert. Chạy lại thì thiết bị ACTIVE và alert được đóng.

---

## 7. Trường hợp 2: Nhân viên mở tủ từ xa, không báo nhầm FORCED_OPEN

**Thực tế:** Sinh viên quên thẻ, ra quầy trình thẻ sinh viên, nhân viên bấm mở ngăn từ xa. Phiên đó có `rfid_ok = false` và cửa có mở, nên **luật FORCED_OPEN của đề sẽ báo nhầm**. Ngược lại, kẻ gian có thể giả tín hiệu "mở từ xa" để mở tủ.

**Hệ thống làm gì:**
1. Operator bấm vào ngăn trên sơ đồ, chọn **Remote unlock**, bắt buộc nhập lý do, rồi xác nhận qua hộp thoại. Server tạo `RemoteCommand` trạng thái PENDING, hết hạn sau 2 phút, ghi audit.
2. Heartbeat kế tiếp nhận lệnh (trạng thái chuyển SENT), thiết bị mở khoá.
3. Phiên gửi lên có `open_source = "REMOTE"` và `command_id`.
4. `RuleEngine` kiểm tra lệnh: đúng thiết bị, đúng ngăn, đang SENT, phiên kết thúc trong vòng 30 phút sau khi tạo lệnh. Khớp thì kết quả là `STAFF_OPEN`: **không cảnh báo**, không đưa vào ML, lệnh chuyển DONE. Không khớp (lệnh không tồn tại hoặc đã dùng rồi) thì `SUSPECTED_SPOOF`.

**CSDL**

```sql
CREATE OR ALTER PROCEDURE RemoteCommand_Create
  @slot_id INT, @reason NVARCHAR(200), @actor INT, @new_id BIGINT OUTPUT
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @device_id INT, @device_status NVARCHAR(20), @owner INT;
  SELECT @device_id = v.device_id, @device_status = v.status, @owner = v.control_owner
  FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id JOIN Device v ON v.device_id = b.device_id
  WHERE s.locker_slot_id = @slot_id;
  IF @device_id IS NULL THROW 50010, N'This slot has no device', 1;
  IF @device_status <> N'ACTIVE' THROW 50011, N'Device is not online, the command cannot be delivered', 1;
  IF @owner IS NOT NULL AND @owner <> @actor THROW 50012, N'Another operator is controlling this device', 1;
  IF LEN(LTRIM(RTRIM(ISNULL(@reason, N'')))) < 5 THROW 50013, N'A reason of at least 5 characters is required', 1;
  BEGIN TRAN;
  INSERT INTO RemoteCommand (device_id, slot_id, action, reason, requested_by, expires_at)
  VALUES (@device_id, @slot_id, N'UNLOCK', @reason, @actor, DATEADD(MINUTE, 2, SYSUTCDATETIME()));
  SET @new_id = SCOPE_IDENTITY();
  EXEC Audit_Append @actor, N'REMOTE_UNLOCK', N'LOCKERSLOT', @slot_id, @reason;
  COMMIT;
END;
GO

-- heartbeat: hand over pending commands and mark them SENT in one atomic statement
CREATE OR ALTER PROCEDURE RemoteCommand_TakePending @device_id INT
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE c SET c.status = N'SENT'
  OUTPUT inserted.command_id, s.slot_code, inserted.action
  FROM RemoteCommand c JOIN LockerSlot s ON s.locker_slot_id = c.slot_id
  WHERE c.device_id = @device_id AND c.status = N'PENDING' AND c.expires_at > SYSUTCDATETIME();
END;
GO

-- only PENDING ones: a SENT command is already on the device and waits for its session
CREATE OR ALTER PROCEDURE RemoteCommand_Expire
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE RemoteCommand SET status = N'EXPIRED'
  WHERE status = N'PENDING' AND expires_at < SYSUTCDATETIME();
END;
```

**Java**

```java
@WebServlet("/RemoteCommandController")
public class RemoteCommandController extends HttpServlet {
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User user = (User) req.getSession().getAttribute("LOGIN_USER");
        int slotId = Integer.parseInt(req.getParameter("slotId"));
        try {
            long id = new RemoteCommandDao().create(slotId, req.getParameter("reason"), user.getUserId());
            req.getSession().setAttribute("flash", "Command #" + id + " queued, the slot opens within 10 seconds");
        } catch (SQLException e) {
            req.getSession().setAttribute("flash", e.getMessage());   // THROW text: offline, busy, no reason
        }
        res.sendRedirect("LockerMapController");
    }
}

// RemoteCommandDao
public long create(int slotId, String reason, int actorId) throws SQLException {
    try (Connection conn = DbContext.getConnection();
         CallableStatement cs = conn.prepareCall("{call RemoteCommand_Create(?, ?, ?, ?)}")) {
        cs.setInt(1, slotId);
        cs.setString(2, reason);
        cs.setInt(3, actorId);
        cs.registerOutParameter(4, Types.BIGINT);
        cs.execute();
        return cs.getLong(4);
    }
}

public List<Map<String, Object>> takePending(int deviceId) throws SQLException {
    List<Map<String, Object>> list = new ArrayList<>();
    try (Connection conn = DbContext.getConnection();
         CallableStatement cs = conn.prepareCall("{call RemoteCommand_TakePending(?)}")) {
        cs.setInt(1, deviceId);
        try (ResultSet rs = cs.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> cmd = new LinkedHashMap<>();
                cmd.put("command_id", rs.getLong("command_id"));
                cmd.put("slot_code", rs.getString("slot_code"));
                cmd.put("action", rs.getString("action"));
                list.add(cmd);
            }
        }
    }
    return list;
}

// called by AlertService when the verdict is STAFF_OPEN, a command can be used once
public void markDone(long commandId, long sessionId) throws SQLException {
    String sql = "UPDATE RemoteCommand SET status = 'DONE', done_at = SYSUTCDATETIME(), session_id = ? "
               + "WHERE command_id = ? AND status = 'SENT'";
    try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
        ps.setLong(1, sessionId);
        ps.setLong(2, commandId);
        ps.executeUpdate();
    }
}
```

**Giao diện** (khung chi tiết ngăn trên sơ đồ, hộp xác nhận đúng như đề yêu cầu):

```jsp
<form method="post" action="RemoteCommandController"
      onsubmit="return confirm('Unlock slot ${slot.slotCode} now? This action is logged.');">
  <input type="hidden" name="slotId" value="${slot.id}">
  <textarea name="reason" required minlength="5" placeholder="Reason, e.g. student forgot card, ID checked"></textarea>
  <button type="submit" ${device.status != 'ACTIVE' ? 'disabled' : ''}>Remote unlock</button>
</form>
```

Thêm trang lịch sử lệnh: ai mở, lý do, trạng thái, phiên nào đã dùng lệnh. Auditor xem được trang này.

**Thử ngay:** bấm Remote unlock ngăn A01 trên web, sau đó chạy `ScenarioSender` với `remote`. Phiên đầu ra STAFF_OPEN, không có alert. Phiên thứ hai dùng lại cùng lệnh nên ra `SUSPECTED_SPOOF`. Chạy `spoof` để gửi lệnh số 999999, cũng ra `SUSPECTED_SPOOF`.

---

## 8. Trường hợp 3: Mất thẻ

**Thực tế:** Sinh viên đánh rơi thẻ, người khác nhặt được và mở tủ lấy đồ.

**Hệ thống làm gì:**
1. END_USER vào **My cards**, bấm **Report lost** rồi xác nhận. Thẻ chuyển LOST và ghi audit. SP chỉ cho báo thẻ của chính mình, nên đổi `cardId` trên request cũng không báo mất thẻ người khác được.
2. Heartbeat trả về `blocked_cards`, thiết bị từ chối thẻ đó ngay tại tủ (đèn đỏ).
3. Nếu thiết bị đang mất mạng, vẫn dùng danh sách cũ và lỡ mở cho thẻ đó, thì khi phiên gửi lên `RuleEngine` sinh alert `LOST_CARD_USED`, kèm bằng chứng: UID thẻ, chủ thẻ, thời điểm báo mất.
4. Operator cấp thẻ mới. Lượt gửi đang chạy tự chuyển sang thẻ mới.

**CSDL**

```sql
CREATE OR ALTER PROCEDURE UserCard_ReportLost @card_id INT, @actor INT
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  BEGIN TRAN;
  UPDATE UserCard SET status = N'LOST', lost_at = SYSUTCDATETIME()
  WHERE card_id = @card_id AND user_id = @actor AND status = N'ACTIVE';   -- only the owner, only once
  IF @@ROWCOUNT = 0
  BEGIN
    ROLLBACK;
    THROW 50020, N'Card not found, not yours, or already reported', 1;
  END
  EXEC Audit_Append @actor, N'REPORT_LOST', N'USERCARD', @card_id, NULL;
  COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE UserCard_Replace
  @old_card_id INT, @new_uid NVARCHAR(32), @actor INT, @new_card_id INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @owner INT = (SELECT user_id FROM UserCard WHERE card_id = @old_card_id AND status <> N'ACTIVE');
  IF @owner IS NULL THROW 50021, N'Only a lost or blocked card can be replaced', 1;
  BEGIN TRAN;
  INSERT INTO UserCard (card_uid, user_id) VALUES (@new_uid, @owner);
  SET @new_card_id = SCOPE_IDENTITY();
  -- the running deposit follows its owner to the new card
  UPDATE Deposit SET card_id = @new_card_id
  WHERE card_id = @old_card_id AND status IN (N'RESERVED', N'ACTIVE');
  EXEC Audit_Append @actor, N'REPLACE_CARD', N'USERCARD', @new_card_id, NULL;
  COMMIT;
END;
```

```java
// UserCardDao, used by the heartbeat reply
public List<String> blockedUids() throws SQLException {
    List<String> list = new ArrayList<>();
    try (Connection conn = DbContext.getConnection();
         PreparedStatement ps = conn.prepareStatement("SELECT card_uid FROM UserCard WHERE status <> 'ACTIVE'");
         ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
            list.add(rs.getString(1));
        }
    }
    return list;
}
```

**Giao diện:** `MyCardController` có GET để liệt kê thẻ `WHERE user_id = <người đang đăng nhập>`, và POST `action=reportLost` để gọi SP với actor là người đang đăng nhập. Trang `UserCardController` của Operator có thêm nút **Issue replacement**.

**Thử ngay:** đăng nhập student1, báo mất thẻ `04A1B2C3`, rồi chạy `ScenarioSender` với `lostcard`. Phản hồi heartbeat có thẻ đó trong `blocked_cards`, và phiên dùng thẻ đó sinh alert `LOST_CARD_USED`.

---

## 9. Trường hợp 4: Đặt ngăn trước nhưng không đến

**Thực tế:** Đề yêu cầu tính năng "đặt ngăn trước". Ngoài đời người ta đặt rồi không đến, ngăn bị giữ mãi trong khi người khác cần.

**Hệ thống làm gì:**
1. END_USER bấm vào ngăn xanh trên sơ đồ, chọn **Reserve**. Ngăn chuyển vàng và được giữ 15 phút. Mệnh đề `WHERE status = 'AVAILABLE'` khoá luôn trường hợp hai người cùng bấm một ngăn, chỉ một người được.
2. Heartbeat trả về `reserved` (ngăn nào dành cho thẻ nào), thiết bị chỉ cho đúng thẻ đó mở ngăn này.
3. Người dùng tới và cất đồ, loadcell báo `occupied: true` trong heartbeat. Lượt gửi chuyển ACTIVE và bắt đầu tính giờ theo gói.
4. Hết 15 phút mà ngăn vẫn trống thì lượt gửi chuyển `NO_SHOW`, ngăn trả về AVAILABLE. **Nếu thiết bị đang OFFLINE thì không xét**, vì có thể người dùng đã tới nhưng tủ không báo lên được.
5. 3 lần NO_SHOW trong 7 ngày thì không được đặt trước nữa. Vẫn gửi trực tiếp bằng thẻ được. Lệnh khoá tự hết hạn, không cần bảng phạt riêng.

**CSDL**

```sql
CREATE OR ALTER PROCEDURE Deposit_Reserve @user_id INT, @slot_id INT, @plan_id INT, @new_id BIGINT OUTPUT
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @card_id INT = (SELECT TOP 1 card_id FROM UserCard WHERE user_id = @user_id AND status = N'ACTIVE');
  IF @card_id IS NULL THROW 50030, N'You need an active card to reserve', 1;
  IF (SELECT COUNT(*) FROM Deposit WHERE user_id = @user_id AND status = N'NO_SHOW'
      AND reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME())) >= 3
    THROW 50031, N'Booking is blocked: 3 no-shows in the last 7 days', 1;
  IF EXISTS (SELECT 1 FROM Deposit WHERE user_id = @user_id AND status IN (N'RESERVED', N'ACTIVE'))
    THROW 50032, N'You already have a booking in progress', 1;
  BEGIN TRAN;
  -- the WHERE clause is the lock: two users clicking the same slot, only one row is updated
  UPDATE LockerSlot SET status = N'RESERVED' WHERE locker_slot_id = @slot_id AND status = N'AVAILABLE';
  IF @@ROWCOUNT = 0
  BEGIN
    ROLLBACK;
    THROW 50033, N'This slot is no longer available', 1;
  END
  INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, hold_until)
  VALUES (@user_id, @slot_id, @plan_id, @card_id, N'RESERVED', DATEADD(MINUTE, 15, SYSUTCDATETIME()));
  SET @new_id = SCOPE_IDENTITY();
  EXEC Audit_Append @user_id, N'RESERVE', N'DEPOSIT', @new_id, NULL;
  COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE Deposit_CheckIn @device_id INT, @slot_code NVARCHAR(20)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
  DECLARE @id BIGINT, @slot_id INT, @minutes INT;
  SELECT TOP 1 @id = d.deposit_id, @slot_id = d.slot_id, @minutes = p.duration_min
  FROM Deposit d
  JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
  JOIN LockerBank b ON b.bank_id = s.bank_id
  JOIN StoragePlan p ON p.plan_id = d.plan_id
  WHERE d.status = N'RESERVED' AND s.slot_code = @slot_code AND b.device_id = @device_id;
  IF @id IS NULL RETURN;                       -- nothing reserved here, a normal walk-in deposit
  BEGIN TRAN;
  UPDATE Deposit SET status = N'ACTIVE', started_at = SYSUTCDATETIME(),
         due_at = DATEADD(MINUTE, @minutes, SYSUTCDATETIME())
  WHERE deposit_id = @id;
  UPDATE LockerSlot SET status = N'OCCUPIED' WHERE locker_slot_id = @slot_id;
  EXEC Audit_Append @sys, N'CHECK_IN', N'DEPOSIT', @id, NULL;
  COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE Deposit_ExpireNoShow
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
  DECLARE @expired TABLE (deposit_id BIGINT, slot_id INT);
  DECLARE @id BIGINT;
  BEGIN TRAN;
  UPDATE d SET d.status = N'NO_SHOW', d.ended_at = SYSUTCDATETIME()
  OUTPUT inserted.deposit_id, inserted.slot_id INTO @expired
  FROM Deposit d
  JOIN LockerSlot s ON s.locker_slot_id = d.slot_id
  JOIN LockerBank b ON b.bank_id = s.bank_id
  JOIN Device v ON v.device_id = b.device_id
  WHERE d.status = N'RESERVED' AND d.hold_until < SYSUTCDATETIME()
    AND v.status = N'ACTIVE';                  -- device offline: we cannot know, so we wait
  UPDATE s SET s.status = N'AVAILABLE'
  FROM LockerSlot s JOIN @expired e ON e.slot_id = s.locker_slot_id;
  WHILE EXISTS (SELECT 1 FROM @expired)
  BEGIN
    SELECT TOP 1 @id = deposit_id FROM @expired;
    EXEC Audit_Append @sys, N'NO_SHOW', N'DEPOSIT', @id, NULL;
    DELETE FROM @expired WHERE deposit_id = @id;
  END
  COMMIT;
END;
```

```java
// DepositDao, used by the heartbeat reply: which card may open which reserved slot
public List<Map<String, Object>> reservedFor(int deviceId) throws SQLException {
    String sql = "SELECT s.slot_code, c.card_uid FROM Deposit d "
               + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id "
               + "JOIN LockerBank b ON b.bank_id = s.bank_id "
               + "JOIN UserCard c ON c.card_id = d.card_id "
               + "WHERE b.device_id = ? AND d.status = 'RESERVED'";
    List<Map<String, Object>> list = new ArrayList<>();
    try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
        ps.setInt(1, deviceId);
        try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("slot_code", rs.getString(1));
                row.put("card_uid", rs.getString(2));
                list.add(row);
            }
        }
    }
    return list;
}

public void checkIn(int deviceId, String slotCode) throws SQLException {
    try (Connection conn = DbContext.getConnection();
         CallableStatement cs = conn.prepareCall("{call Deposit_CheckIn(?, ?)}")) {
        cs.setInt(1, deviceId);
        cs.setString(2, slotCode);
        cs.execute();
    }
}
```

**Giao diện:** Ngăn RESERVED màu vàng, hiện "Held until 14:35". `hold_until` lưu theo UTC, nên hiển thị thì cộng 7 giờ hoặc để JS đổi. Trang **My bookings** liệt kê lịch sử, kể cả NO_SHOW, và hiện thông báo khi đang bị khoá đặt trước.

**Thử ngay:**
- Đặt ngăn A02, rồi chạy `ScenarioSender` với `checkin`: lượt gửi chuyển ACTIVE.
- Muốn thấy NO_SHOW mà không phải chờ 15 phút (dùng được cho cả video), chạy trong SSMS:
  `UPDATE Deposit SET hold_until = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE status = 'RESERVED';`
  Trong vòng 30 giây lượt gửi chuyển NO_SHOW và ngăn chuyển xanh.

---

## 10. Trường hợp 5: Cảm biến hỏng hoặc hết hạn hiệu chuẩn

**Thực tế:** Loadcell bị lệch, dây công tắc từ lỏng, ESP32 mất NTP nên giờ sai. Dữ liệu sai sẽ làm luật **đổ lỗi cho người dùng** (FORCED_OPEN, ITEM_LEFT) và làm bẩn dữ liệu train.

**Hệ thống làm gì:** `RuleEngine` kiểm tra điều này **đầu tiên**:
- Giá trị nằm ngoài khoảng `min_valid`–`max_valid` của bảng `SensorType` (bảng dùng chung của đề, giờ mới thật sự được dùng).
- Số liệu vô lý: cửa mở lâu hơn cả phiên.
- Giờ thiết bị chạy trước server quá 5 phút, tức NTP hỏng.
- Hiệu chuẩn loadcell đã hết hạn (`Calibration.valid_until`).

Gặp một trong các điều trên thì sinh `SENSOR_FAULT`, không xét các luật đổ lỗi người dùng, không đưa vào ML. Hệ thống tự mở **phiếu bảo trì** giao cho Technician đang ít việc nhất, và chuyển ngăn sang MAINTENANCE (sơ đồ xám, không đặt được). Technician sửa xong, hiệu chuẩn lại (thêm dòng Calibration version mới), đóng phiếu, ngăn trở về AVAILABLE.

```sql
CREATE OR ALTER PROCEDURE Ticket_OpenForFault @device_id INT, @alert_id INT, @session_id BIGINT, @note NVARCHAR(400)
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @sys INT = (SELECT user_id FROM Users WHERE username = N'system');
  DECLARE @id INT;
  BEGIN TRAN;
  UPDATE LockerSlot SET status = N'MAINTENANCE'
  WHERE locker_slot_id = (SELECT slot_id FROM LockerSession WHERE session_id = @session_id);
  -- one open ticket per device is enough, later faults only add alerts
  IF NOT EXISTS (SELECT 1 FROM MaintenanceTicket WHERE device_id = @device_id AND status = N'OPEN')
  BEGIN
    INSERT INTO MaintenanceTicket (alert_id, device_id, assigned_to, note)
    SELECT @alert_id, @device_id,
      (SELECT TOP 1 u.user_id FROM Users u
       JOIN UserRole ur ON ur.user_id = u.user_id
       JOIN Roles r ON r.role_id = ur.role_id AND r.role_name = N'TECHNICIAN'
       WHERE u.status = N'ACTIVE'
       ORDER BY (SELECT COUNT(*) FROM MaintenanceTicket t
                 WHERE t.assigned_to = u.user_id AND t.status = N'OPEN')),   -- least busy technician
      @note;
    SET @id = SCOPE_IDENTITY();
    EXEC Audit_Append @sys, N'OPEN_TICKET', N'MAINTENANCE', @id, @note;
  END
  COMMIT;
END;
```

Phần Java nằm trong `RuleEngine.findSensorFault` và `AlertService` ở mục 11.

**Thử ngay:** chạy `ScenarioSender` với `sensor` (gửi khối lượng −5000 g): có alert `SENSOR_FAULT` (không phải FORCED_OPEN), có phiếu bảo trì, A01 chuyển xám. Muốn thử hiệu chuẩn hết hạn thì `UPDATE Calibration SET valid_until = '2026-01-01'`.

---

## 11. RuleEngine, AlertService, SessionContextDao

Lớp `RuleEngine` dưới đây **đã được compile bằng JDK 8 và chạy qua 12 ca** (mỗi nhãn một ca). Lớp này không đụng tới CSDL nên viết TestNG rất dễ.

```java
package service;

import java.util.HashMap;
import java.util.Map;

// Everything the rules need besides the session itself, loaded by AlertService from the database.
// Kept as a plain object so RuleEngine can be tested without a database.
public class SessionContext {
    private final Map<String, double[]> ranges = new HashMap<String, double[]>();
    private boolean calibrationValid = true;
    private long uploadDelaySec;          // ingested_at - measured_at, negative = device clock ahead
    private boolean commandValid;         // REMOTE open matches a SENT command for this slot
    private String cardStatus;            // ACTIVE, LOST, BLOCKED or null when the card is unknown
    private Integer cardOwnerId;
    private Integer depositOwnerId;
    private double allowedMin;            // plan duration + grace of the active deposit, 0 = unknown

    public void setRange(String sensor, double min, double max) {
        ranges.put(sensor, new double[]{min, max});
    }

    public boolean inRange(String sensor, double value) {
        double[] r = ranges.get(sensor);
        return r == null || (value >= r[0] && value <= r[1]);
    }
    // getters and setters for the other fields, generated by the IDE
}
```

```java
package service;

import java.util.ArrayList;
import java.util.List;

public class Verdict {
    private final String label;          // alert label, or NORMAL / STAFF_OPEN when no alert is raised
    private final boolean alert;
    private boolean mlEligible = true;
    private final List<String[]> evidence = new ArrayList<String[]>();

    private Verdict(String label, boolean alert) {
        this.label = label;
        this.alert = alert;
    }

    public static Verdict alert(String label, String item, String value) {
        return new Verdict(label, true).with(item, value);
    }

    public static Verdict normal() {
        return new Verdict("NORMAL", false);
    }

    // legitimate remote open by staff: no alert, and the session is not fed to the model
    public static Verdict staffOpen(long commandId) {
        return new Verdict("STAFF_OPEN", false).with("command_id", String.valueOf(commandId)).noMl();
    }

    public Verdict with(String item, String value) {
        evidence.add(new String[]{item, value});
        return this;
    }

    public Verdict noMl() {
        mlEligible = false;
        return this;
    }

    public String getLabel() { return label; }
    public boolean isAlert() { return alert; }
    public boolean isMlEligible() { return mlEligible; }
    public List<String[]> getEvidence() { return evidence; }
}
```

```java
package service;

import model.LockerSession;

// Rules run in priority order and the first match wins.
// Order matters: a broken sensor or a staff remote open must never be reported as FORCED_OPEN.
public class RuleEngine {

    public static final double ITEM_LEFT_G = 50;          // grams still in the slot after pickup
    public static final double SPOOF_WEIGHT_G = 50;       // weight changed although the door "never opened"
    public static final long CLOCK_AHEAD_SEC = 300;       // measured_at more than 5 minutes in the future

    public Verdict evaluate(LockerSession s, SessionContext ctx) {
        // 1. SENSOR_FAULT: data we cannot trust, blame the sensor and not the user
        String fault = findSensorFault(s, ctx);
        if (fault != null) {
            return Verdict.alert("SENSOR_FAULT", "reason", fault).noMl();
        }
        // 2. Remote open: a valid command means staff opened it, otherwise someone faked the signal
        if ("REMOTE".equals(s.getOpenSource())) {
            if (s.getCommandId() != null && ctx.isCommandValid()) {
                return Verdict.staffOpen(s.getCommandId());
            }
            return Verdict.alert("SUSPECTED_SPOOF", "reason", "remote open without a valid command")
                    .with("command_id", String.valueOf(s.getCommandId()));
        }
        // 3. A card reported lost or blocked was used
        if (ctx.getCardStatus() != null && !"ACTIVE".equals(ctx.getCardStatus())) {
            return Verdict.alert("LOST_CARD_USED", "card_uid", s.getCardUid())
                    .with("card_status", ctx.getCardStatus())
                    .with("card_owner_id", String.valueOf(ctx.getCardOwnerId()));
        }
        // 4. The 6 labels of the assignment
        if (!s.isRfidOk() && s.getDoorOpenSec() > 0) {
            return Verdict.alert("FORCED_OPEN", "door_open_sec", String.valueOf(s.getDoorOpenSec()))
                    .with("rfid_ok", "false");
        }
        if (s.isRfidOk() && ctx.getCardOwnerId() != null && ctx.getDepositOwnerId() != null
                && !ctx.getCardOwnerId().equals(ctx.getDepositOwnerId())) {
            return Verdict.alert("WRONG_USER", "card_owner_id", String.valueOf(ctx.getCardOwnerId()))
                    .with("deposit_owner_id", String.valueOf(ctx.getDepositOwnerId()));
        }
        if (s.getDoorOpenSec() == 0 && Math.abs(s.getWeightDeltaG()) > SPOOF_WEIGHT_G) {
            return Verdict.alert("SUSPECTED_SPOOF", "reason", "weight changed while the door sensor reported closed")
                    .with("weight_delta_g", String.valueOf(s.getWeightDeltaG()));
        }
        if (s.getWeightDeltaG() > ITEM_LEFT_G) {
            return Verdict.alert("ITEM_LEFT", "weight_delta_g", String.valueOf(s.getWeightDeltaG()));
        }
        if (ctx.getAllowedMin() > 0 && s.getStayMin() > ctx.getAllowedMin()) {
            return Verdict.alert("OVERDUE", "stay_min", String.valueOf(s.getStayMin()))
                    .with("allowed_min", String.valueOf(ctx.getAllowedMin()));
        }
        return Verdict.normal();   // AlertService may still raise ML_ANOMALY from the risk score
    }

    private String findSensorFault(LockerSession s, SessionContext ctx) {
        if (!ctx.inRange("DOOR", s.getDoorOpenSec())) {
            return "door_open_sec=" + s.getDoorOpenSec() + " is outside the valid range";
        }
        if (!ctx.inRange("WEIGHT", s.getWeightDeltaG())) {
            return "weight_delta_g=" + s.getWeightDeltaG() + " is outside the valid range";
        }
        if (!ctx.inRange("STAY", s.getStayMin())) {
            return "stay_min=" + s.getStayMin() + " is outside the valid range";
        }
        if (s.getDoorOpenSec() > s.getStayMin() * 60 + 5) {
            return "door was open longer than the whole session";
        }
        if (ctx.getUploadDelaySec() < -CLOCK_AHEAD_SEC) {
            return "device clock is " + (-ctx.getUploadDelaySec()) + " s ahead of the server, check NTP";
        }
        if (!ctx.isCalibrationValid()) {
            return "weight sensor calibration has expired";
        }
        return null;
    }
}
```

**`SessionContextDao.load(session)`:** mỗi trường của context là một câu truy vấn ngắn.

| Trường | SQL |
|---|---|
| ranges | `SELECT name, min_valid, max_valid FROM SensorType` |
| uploadDelaySec | `SELECT DATEDIFF(SECOND, measured_at, ingested_at) FROM LockerSession WHERE session_id = ?` (so sánh trong SQL nên múi giờ của JVM không ảnh hưởng) |
| calibrationValid | `SELECT COUNT(*) FROM Calibration c JOIN SensorType t ON t.sensor_type_id = c.sensor_type_id JOIN LockerSession s ON s.device_id = c.device_id WHERE s.session_id = ? AND t.name = 'WEIGHT' AND c.valid_until >= CAST(s.measured_at AS DATE)` > 0 |
| commandValid | `SELECT COUNT(*) FROM RemoteCommand c JOIN LockerSession s ON s.session_id = ? WHERE c.command_id = s.command_id AND c.device_id = s.device_id AND c.slot_id = s.slot_id AND c.status = 'SENT' AND s.measured_at BETWEEN c.created_at AND DATEADD(MINUTE, 30, c.created_at)` > 0 |
| cardStatus, cardOwnerId | `SELECT status, user_id FROM UserCard WHERE card_uid = ?` |
| depositOwnerId, allowedMin | `SELECT TOP 1 d.user_id, DATEDIFF(MINUTE, d.started_at, d.due_at) + p.grace_min FROM Deposit d JOIN StoragePlan p ON p.plan_id = d.plan_id JOIN LockerSession s ON s.slot_id = d.slot_id WHERE s.session_id = ? AND d.status = 'ACTIVE' ORDER BY d.started_at DESC` (dùng `due_at` nên gia hạn online tự được tính) |

```java
package service;

public class AlertService {

    private static final double ML_THRESHOLD = 0.80;
    private static final int SYSTEM_USER_ID = 1;   // 'system' is the first row inserted into Users

    private final RuleEngine ruleEngine = new RuleEngine();

    public void evaluate(LockerSession session) throws Exception {
        SessionContext ctx = new SessionContextDao().load(session);
        Verdict verdict = ruleEngine.evaluate(session, ctx);

        Double risk = null;
        if (verdict.isMlEligible()) {
            risk = RiskScorer.getInstance().score(session);           // 1 - P(NORMAL), model loaded once
            if (!verdict.isAlert() && risk >= ML_THRESHOLD) {
                verdict = Verdict.alert("ML_ANOMALY", "risk_score", String.format("%.2f", risk));
            }
        }
        if ("STAFF_OPEN".equals(verdict.getLabel())) {
            new RemoteCommandDao().markDone(session.getCommandId(), session.getSessionId());
            new AuditDao().append(SYSTEM_USER_ID, "COMMAND_DONE", "COMMAND", session.getCommandId(),
                    "session " + session.getSessionId());
        }
        if (verdict.isAlert()) {
            String source = "ML_ANOMALY".equals(verdict.getLabel()) ? "ML" : "RULE";
            int alertId = new AlertDao().create(session.getDeviceId(), session.getSessionId(),
                    source, verdict.getLabel(), risk, verdict.getEvidence());   // alert + evidence in one transaction
            new AuditDao().append(SYSTEM_USER_ID, "CREATE", "ALERT", alertId, verdict.getLabel());
            if ("SENSOR_FAULT".equals(verdict.getLabel())) {
                new MaintenanceDao().openForFault(session.getDeviceId(), alertId, session.getSessionId(),
                        verdict.getEvidence().get(0)[1]);                       // calls Ticket_OpenForFault
            }
        }
    }
}
```

**Thay đổi trong `LockerSessionApi`** (dựa trên mã của đề):

```java
int deviceId = (Integer) req.getAttribute("DEVICE_ID");      // instead of body.get("device_id")
...
session.setRfidOk(readBool(json, "rfid_ok"));                 // section 3, bug 1
session.setSlotCode(readString(json, "slot_code"));
session.setCardUid(readString(json, "card_uid"));
session.setOpenSource(readString(json, "open_source"));
session.setCommandId(json.has("command_id") && !json.get("command_id").isJsonNull()
        ? json.get("command_id").getAsLong() : null);

long newId;
try {
    newId = new LockerSessionDao().insert(session);
} catch (SQLException e) {
    if (e.getErrorCode() != 2627 && e.getErrorCode() != 2601) {
        log("Session insert failed", e);                      // a real error, not a duplicate upload
    }
    continue;
}
savedCount++;
session.setSessionId(newId);
try {
    new AlertService().evaluate(session);
} catch (Exception e) {
    log("Alert evaluation failed for session " + newId, e);
}

private static String readString(JsonObject json, String key) {
    return json.has(key) && !json.get(key).isJsonNull() ? json.get(key).getAsString() : null;
}
```

```java
// LockerSessionDao.insert: INSERT ... SELECT so slot_code can be turned into slot_id in the same statement
String sql = "INSERT INTO LockerSession (device_id, device_seq, measured_at, door_open_sec, weight_delta_g, "
           + "unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source, command_id) "
           + "SELECT ?, ?, ?, ?, ?, ?, ?, ?, "
           + "(SELECT s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id "
           + " WHERE b.device_id = ? AND s.slot_code = ?), ?, ?, ?";
// parameters 1-8 as in the assignment, then: 9 deviceId, 10 slotCode, 11 cardUid, 12 openSource,
// 13 commandId (ps.setNull(13, Types.BIGINT) when it is null)
```

---

## 12. Giả lập thiết bị khi chưa có IoT, và hợp đồng cho ESP32

### 12.1 `tool/ScenarioSender.java`

Lớp này đã compile bằng JDK 8 với Gson. Đổi `SCENARIO` rồi bấm Run File. Nhớ sửa `BASE_URL` cho đúng context path của project.

```java
package tool;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Scanner;
import java.util.TimeZone;

// Plays the ESP32 before the real device is ready: same URLs, same header, same JSON.
// Change SCENARIO and use Run File in NetBeans.
public class ScenarioSender {

    private static final String BASE_URL = "http://localhost:8080/SmartLocker/api";
    private static final String API_KEY = "device-1-api-key";
    private static final String SCENARIO = "remote";   // heartbeat | remote | spoof | lostcard | checkin | sensor

    // a new range of numbers on every run, so UNIQUE(device_id, device_seq) never drops our sessions
    private static int seq = (int) (System.currentTimeMillis() / 1000);

    public static void main(String[] args) throws Exception {
        String scenario = args.length > 0 ? args[0] : SCENARIO;
        switch (scenario) {
            case "heartbeat":   // case 1: 6 beats then stop, the device turns OFFLINE about 60 s later
                for (int i = 0; i < 6; i++) {
                    System.out.println(post("/health", heartbeat("A02", false)));
                    Thread.sleep(10000);
                }
                break;
            case "remote": {    // case 2: click Remote unlock on slot A01 in the web first
                JsonObject reply = JsonParser.parseString(post("/health", heartbeat("A01", true))).getAsJsonObject();
                JsonArray commands = reply.getAsJsonArray("commands");
                if (commands.size() == 0) {
                    System.out.println("No pending command, click Remote unlock first");
                    return;
                }
                JsonObject s = session("A01", null, false, 8, 0, 40);
                s.addProperty("open_source", "REMOTE");
                s.addProperty("command_id", commands.get(0).getAsJsonObject().get("command_id").getAsLong());
                System.out.println(postBatch(s));            // expected: STAFF_OPEN, no alert
                JsonObject replay = s.deepCopy();
                replay.addProperty("seq", ++seq);
                System.out.println(postBatch(replay));       // same command used twice: SUSPECTED_SPOOF
                break;
            }
            case "spoof": {     // case 2: REMOTE open with a command the server never issued
                JsonObject s = session("A01", null, false, 8, 0, 40);
                s.addProperty("open_source", "REMOTE");
                s.addProperty("command_id", 999999);
                System.out.println(postBatch(s));
                break;
            }
            case "lostcard":    // case 3: report card 04A1B2C3 lost in the web first
                System.out.println(post("/health", heartbeat("A01", false)));   // blocked_cards lists it now
                System.out.println(postBatch(session("A01", "04A1B2C3", true, 6, 2, 30)));
                break;
            case "checkin":     // case 4: reserve A02 in the web, then run this within the hold time
                System.out.println(post("/health", heartbeat("A02", true)));
                break;
            case "sensor":      // case 5: a weight no real slot can have
                System.out.println(postBatch(session("A01", "0499AABB", true, 6, -5000, 30)));
                break;
            default:
                System.out.println("Unknown scenario: " + scenario);
        }
    }

    private static JsonObject session(String slot, String card, boolean rfidOk,
                                      double doorSec, double weightG, double stayMin) {
        SimpleDateFormat utc = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        utc.setTimeZone(TimeZone.getTimeZone("UTC"));   // the server compares with SYSUTCDATETIME()
        JsonObject s = new JsonObject();
        s.addProperty("seq", ++seq);
        s.addProperty("measured_at", utc.format(new Date()));
        s.addProperty("door_open_sec", doorSec);
        s.addProperty("weight_delta_g", weightG);
        s.addProperty("unlock_count", 2);
        s.addProperty("rfid_ok", rfidOk);               // a real JSON boolean, never 1.0
        s.addProperty("stay_min", stayMin);
        s.addProperty("slot_code", slot);
        s.addProperty("card_uid", card);
        s.addProperty("open_source", "RFID");
        return s;
    }

    private static JsonObject heartbeat(String slot, boolean occupied) {
        JsonObject slotJson = new JsonObject();
        slotJson.addProperty("slot_code", slot);
        slotJson.addProperty("occupied", occupied);
        JsonArray slots = new JsonArray();
        slots.add(slotJson);
        JsonObject body = new JsonObject();
        body.addProperty("firmware", "sim-1.0");
        body.add("slots", slots);
        return body;
    }

    private static String postBatch(JsonObject session) throws Exception {
        JsonArray sessions = new JsonArray();
        sessions.add(session);
        JsonObject body = new JsonObject();
        body.addProperty("device_id", 1);
        body.add("sessions", sessions);
        return post("/locker/batch", body);
    }

    private static String post(String path, JsonObject body) throws Exception {
        HttpURLConnection conn = (HttpURLConnection) new URL(BASE_URL + path).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
        conn.setRequestProperty("X-API-Key", API_KEY);
        try (OutputStream out = conn.getOutputStream()) {
            out.write(body.toString().getBytes("UTF-8"));
        }
        int code = conn.getResponseCode();
        InputStream in = code < 400 ? conn.getInputStream() : conn.getErrorStream();
        String text = "";
        if (in != null) {
            try (Scanner sc = new Scanner(in, "UTF-8").useDelimiter("\\A")) {
                text = sc.hasNext() ? sc.next() : "";
            }
        }
        System.out.println("POST " + path + " -> HTTP " + code);
        return text;
    }
}
```

### 12.2 Hợp đồng API (đưa cho người làm firmware)

**Phiên:** `POST /api/locker/batch`, header `X-API-Key`, gửi sau mỗi phiên hoặc khi có mạng lại.

```json
{
  "device_id": 1,
  "sessions": [{
    "seq": 101,
    "measured_at": "2026-10-15 03:15:20",
    "door_open_sec": 6.5,
    "weight_delta_g": 2.0,
    "unlock_count": 2,
    "rfid_ok": true,
    "stay_min": 42.0,
    "slot_code": "A01",
    "card_uid": "04A1B2C3",
    "open_source": "RFID",
    "command_id": null
  }]
}
```

- `measured_at`: thời điểm kết thúc phiên (lấy đồ xong, cửa đóng), **giờ UTC** từ NTP.
- `weight_delta_g`: khối lượng còn trong ngăn lúc kết thúc so với lúc ngăn trống. Lấy hết đồ thì gần 0.
- `rfid_ok`: dạng `true`/`false`, không gửi `1`/`0`.

**Heartbeat:** `POST /api/health` mỗi 10 giây.

```json
{"firmware": "1.2", "slots": [{"slot_code": "A01", "occupied": true}, {"slot_code": "A02", "occupied": false}]}
```

Server trả về:

```json
{
  "commands": [{"command_id": 15, "slot_code": "A01", "action": "UNLOCK"}],
  "blocked_cards": ["04A1B2C3"],
  "reserved": [{"slot_code": "A02", "card_uid": "0499AABB"}]
}
```

### 12.3 Việc của firmware tuần sau

1. `configTime(0, 0, "pool.ntp.org")` để có giờ UTC.
2. Gửi heartbeat 10 giây một lần, đọc phản hồi bằng ArduinoJson, lưu `blocked_cards` và `reserved` trong RAM (mất mạng vẫn dùng danh sách cũ).
3. Khi quẹt thẻ: thẻ nằm trong `blocked_cards` thì đèn đỏ, không mở. Ngăn đang `reserved` cho thẻ khác thì cũng không mở.
4. Nhận lệnh `UNLOCK`: mở khoá, rồi đánh dấu phiên hiện tại `open_source = "REMOTE"` và `command_id = ...`.
5. Kết thúc phiên: điền thêm 4 trường mới rồi đưa vào hàng đợi (dùng đúng `enqueue`/`flushQueue` của đề).
6. `occupied` = loadcell lớn hơn khoảng 30 g.
7. Máy tính chạy Tomcat và ESP32 phải cùng Wi-Fi, và tường lửa Windows phải mở cổng 8080 chiều vào. Đây là lỗi hay gặp nhất khi mới cắm thiết bị thật.

### 12.4 Thu 100 phiên thật cho `TransferCheck` (phần +2 điểm)

| Nhãn | Cách tạo trên tủ thật | Số phiên |
|---|---|---|
| NORMAL | Quẹt thẻ, cất đồ, đóng cửa, quẹt lại, lấy đồ, đóng cửa | ~40 |
| OVERDUE | Dùng gói "Demo 2 minutes", để quá 3 phút | ~12 |
| FORCED_OPEN | Mở cửa không quẹt thẻ (nhả chốt bằng tay) | ~12 |
| WRONG_USER | Thẻ B mở ngăn của A (bật chế độ test trong firmware để không chặn) | ~12 |
| ITEM_LEFT | Lấy đồ nhưng để quên một món | ~12 |
| SUSPECTED_SPOOF | Áp nam châm vào công tắc từ trong lúc mở cửa | ~12 |

Gán nhãn ở trang LockerSessionLabel ngay sau mỗi phiên. Phiên STAFF_OPEN và SENSOR_FAULT tự bị loại khỏi `v_LockerSession_Features` (mục 5).

---

## 13. Kiểm thử TestNG

Đề yêu cầu tối thiểu 10 ca. 5 trường hợp mới góp 6 ca kiểm tra luật (không cần CSDL). Thêm ca sửa trái phép nhật ký kiểm toán của đề và vài ca của luật nền là đủ.

```java
package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;

import model.LockerSession;
import org.testng.annotations.Test;
import service.RuleEngine;
import service.SessionContext;
import service.Verdict;

public class RuleEngineTest {

    private final RuleEngine engine = new RuleEngine();

    private LockerSession session(double doorSec, double weightG, boolean rfidOk, double stayMin) {
        LockerSession s = new LockerSession();
        s.setDeviceId(1);
        s.setDoorOpenSec(doorSec);
        s.setWeightDeltaG(weightG);
        s.setRfidOk(rfidOk);
        s.setStayMin(stayMin);
        s.setSlotCode("A01");
        s.setCardUid("04A1B2C3");
        s.setOpenSource("RFID");
        return s;
    }

    private SessionContext healthyContext() {
        SessionContext c = new SessionContext();
        c.setRange("DOOR", 0, 3600);
        c.setRange("WEIGHT", -200, 20000);
        c.setRange("STAY", 0, 10080);
        c.setCardStatus("ACTIVE");
        c.setCardOwnerId(7);
        c.setDepositOwnerId(7);
        c.setAllowedMin(130);
        return c;
    }

    @Test
    public void remoteOpenWithValidCommandIsNotForcedOpen() {
        LockerSession s = session(8, 0, false, 40);
        s.setOpenSource("REMOTE");
        s.setCommandId(15L);
        SessionContext ctx = healthyContext();
        ctx.setCommandValid(true);
        Verdict v = engine.evaluate(s, ctx);
        assertEquals(v.getLabel(), "STAFF_OPEN");
        assertFalse(v.isAlert());
        assertFalse(v.isMlEligible());
    }

    @Test
    public void remoteOpenWithoutCommandIsSpoof() {
        LockerSession s = session(8, 0, false, 40);
        s.setOpenSource("REMOTE");
        s.setCommandId(999999L);
        assertEquals(engine.evaluate(s, healthyContext()).getLabel(), "SUSPECTED_SPOOF");
    }

    @Test
    public void lostCardIsFlagged() {
        SessionContext ctx = healthyContext();
        ctx.setCardStatus("LOST");
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "LOST_CARD_USED");
    }

    @Test
    public void impossibleWeightIsSensorFaultNotForcedOpen() {
        Verdict v = engine.evaluate(session(6, -5000, false, 30), healthyContext());
        assertEquals(v.getLabel(), "SENSOR_FAULT");
        assertFalse(v.isMlEligible());
    }

    @Test
    public void expiredCalibrationIsSensorFault() {
        SessionContext ctx = healthyContext();
        ctx.setCalibrationValid(false);
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "SENSOR_FAULT");
    }

    @Test
    public void deviceClockAheadIsSensorFault() {
        SessionContext ctx = healthyContext();
        ctx.setUploadDelaySec(-3600);
        assertEquals(engine.evaluate(session(6, 2, true, 30), ctx).getLabel(), "SENSOR_FAULT");
    }
}
```

Hai trường hợp theo thời gian (1 và 4) nên có thêm hai ca tích hợp có CSDL, viết theo cùng kiểu `AuditChainDatabaseIntegrationTest` của bài mẫu:
- Dùng UPDATE để đặt `hold_until` về quá khứ, gọi `Deposit_ExpireNoShow`, kiểm tra trạng thái là `NO_SHOW` và ngăn đã AVAILABLE.
- Dùng UPDATE để đặt `last_seen` về 2 phút trước, gọi `Device_MarkOffline`, kiểm tra thiết bị OFFLINE và có đúng 1 alert.

---

## 14. Viết vào báo cáo và quay video

**Báo cáo:** thêm mục "Context-aware rules for real operating conditions" và đánh giá bằng số liệu.
- Dựng sẵn một tập phiên: 20 lần mở từ xa hợp lệ, 20 phiên cảm biến lỗi, 20 phiên bình thường, 20 phiên mở cưỡng bức.
- Chạy `RuleEngine` hai lần: lần đầu tắt bước 1–3 (chỉ luật của đề), lần sau bật đủ. Thêm một cờ `boolean contextRules` vào constructor là đủ, chạy bằng một hàm `main` nhỏ, không cần server.
- Lập bảng so sánh: số lần **báo nhầm FORCED_OPEN** trước và sau. Chỉ luật của đề thì 20 lần mở từ xa đều bị báo nhầm. Cách đánh giá này giống bài mẫu, vốn loại MANUAL_BUTTON/NO_CUP khỏi ML để tăng độ chính xác.
- Nói rõ cảnh báo này khác với điểm mới chính của đề (độ suy giảm F1 khi chuyển từ TON_IoT sang tủ thật). Bảng 4 thuật toán và mốc so sánh vẫn là bảng chính.

**Video ≤ 5 phút:**

| Thời gian | Nội dung |
|---|---|
| 0:00–0:40 | Đăng nhập lần lượt 5 vai trò, sơ đồ tủ tô màu |
| 0:40–1:30 | DataReplayer phát dữ liệu, dashboard tự cập nhật, các cảnh báo nền |
| 1:30–3:30 | 5 trường hợp, mỗi trường hợp khoảng 25 giây (ScenarioSender hoặc tủ thật) |
| 3:30–4:15 | Sửa một dòng AuditLog trong SSMS, AuditVerifier chỉ ra đúng dòng bị sửa |
| 4:15–5:00 | Bảng Weka 4 thuật toán + mốc so sánh, kết quả TransferCheck nếu đã có |

---

## 15. Đối chiếu quy mô tối thiểu của đề

| Yêu cầu | Đã có |
|---|---|
| 15 bảng | 14 dùng chung + 4 của đề + LockerBank, UserCard, StoragePlan, Deposit, RemoteCommand = 23 |
| 10 stored procedure | Audit_Append + Device_Heartbeat, Device_MarkOffline, RemoteCommand_Create, RemoteCommand_TakePending, RemoteCommand_Expire, UserCard_ReportLost, UserCard_Replace, Deposit_Reserve, Deposit_CheckIn, Deposit_ExpireNoShow, Ticket_OpenForFault = 12 |
| 2 view | v_LockerSession_Features, v_LockerSlotMap |
| 2 API | /api/locker/batch, /api/health, /api/dashboard |
| 12 servlet, 12 JSP | Login, Logout, Register, Dashboard, LockerBank, LockerSlot, LockerMap, UserCard, MyCard, Deposit, Booking, StoragePlan, RemoteCommand, Alert, Maintenance, Calibration, Audit, User |

---

## 16. Lỗi hay gặp (ngoài mục 3)

- **Monitor tự dừng:** trong `LockerMonitor`, một exception không bắt sẽ âm thầm huỷ mọi lần chạy sau.
- **OUTPUT báo lỗi:** `UPDATE ... OUTPUT` không có `INTO` sẽ lỗi nếu bảng có trigger. Vì vậy đừng gắn trigger vào `RemoteCommand`.
- **Mất bằng chứng lệnh giả:** không đặt khoá ngoại cho `LockerSession.command_id`. Nếu đặt, lệnh giả bị từ chối khi INSERT và mất luôn bằng chứng.
- **Phiên nào cũng SENSOR_FAULT:** quên seed dòng Calibration cho WEIGHT.
- **404 khi chạy replayer:** `DataReplayer` của đề dùng `/PRJ301/`, phải đổi theo context path của project (ví dụ `/SmartLocker/`).
- **Thông báo lỗi khó đọc:** lỗi từ `THROW` trong SP tới Java dưới dạng `SQLException.getMessage()`, hiện thẳng ra flash message là người dùng đọc được.
