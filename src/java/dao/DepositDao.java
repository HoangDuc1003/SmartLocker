package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import model.Deposit;

/** Bookings and deposits. The state changes are stored procedures, the lists are plain queries. */
public class DepositDao {

    private static final String SELECT = "SELECT d.deposit_id, d.user_id, u.username, d.slot_id, s.slot_code, b.bank_code, "
            + "d.plan_id, p.plan_name, d.card_id, d.paid_amount, d.status, d.reserved_at, d.hold_until, "
            + "d.started_at, d.due_at, d.ended_at, d.extend_count, "
            + "d.open_method, d.pin_code, d.enroll_code, d.enroll_expires, v.device_code, "
            + "s.size_code, s.size_cm, p.grace_min, d.overdue_rate, d.overdue_hours, d.overdue_fee, d.locked_at, d.escalated_at, d.custom_min "
            + "FROM Deposit d "
            + "JOIN Users u ON u.user_id = d.user_id "
            + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id "
            + "JOIN LockerBank b ON b.bank_id = s.bank_id "
            + "JOIN StoragePlan p ON p.plan_id = d.plan_id "
            + "LEFT JOIN Device v ON v.device_id = b.device_id";

    /** "Tự chọn · 3 giờ" / "Tự chọn · 2 ngày" for a custom booking of that many minutes. */
    public static String customLabel(int minutes) {
        return minutes % 1440 == 0 ? "Tự chọn · " + (minutes / 1440) + " ngày" : "Tự chọn · " + (minutes / 60) + " giờ";
    }

    private static Deposit map(ResultSet rs) throws SQLException {
        Deposit d = new Deposit();
        d.setDepositId(rs.getLong("deposit_id"));
        d.setUserId(rs.getInt("user_id"));
        d.setUsername(rs.getString("username"));
        d.setSlotId(rs.getInt("slot_id"));
        d.setSlotCode(rs.getString("slot_code"));
        d.setBankCode(rs.getString("bank_code"));
        d.setPlanId(rs.getInt("plan_id"));
        int customMin = rs.getInt("custom_min");
        d.setCustomMin(rs.wasNull() ? null : customMin);
        // a custom booking shows what was booked ("Tự chọn · 3 giờ"), not the plan it keeps for the grace time
        d.setPlanName(rs.wasNull() ? rs.getString("plan_name") : customLabel(customMin));
        int cardId = rs.getInt("card_id");
        d.setCardId(rs.wasNull() ? null : cardId);
        d.setPaidAmount(rs.getLong("paid_amount"));
        d.setStatus(rs.getString("status"));
        d.setReservedAt(rs.getTimestamp("reserved_at"));
        d.setHoldUntil(rs.getTimestamp("hold_until"));
        d.setStartedAt(rs.getTimestamp("started_at"));
        d.setDueAt(rs.getTimestamp("due_at"));
        d.setEndedAt(rs.getTimestamp("ended_at"));
        d.setExtendCount(rs.getInt("extend_count"));
        d.setOpenMethod(rs.getString("open_method"));
        d.setPinCode(rs.getString("pin_code"));
        d.setEnrollCode(rs.getString("enroll_code"));
        d.setEnrollExpires(rs.getTimestamp("enroll_expires"));
        d.setDeviceCode(rs.getString("device_code"));
        d.setSizeCode(rs.getString("size_code"));
        d.setSizeCm(rs.getString("size_cm"));
        d.setGraceMin(rs.getInt("grace_min"));
        long rate = rs.getLong("overdue_rate");
        d.setOverdueRate(rs.wasNull() ? null : rate);
        d.setOverdueHours(rs.getInt("overdue_hours"));
        d.setOverdueFee(rs.getLong("overdue_fee"));
        d.setLockedAt(rs.getTimestamp("locked_at"));
        d.setEscalatedAt(rs.getTimestamp("escalated_at"));
        return d;
    }

    private static String where(String keyword, String status, List<Object> params) {
        StringBuilder sb = new StringBuilder(" WHERE 1 = 1");
        if (keyword != null && !keyword.trim().isEmpty()) {
            sb.append(" AND (u.username LIKE ? OR s.slot_code LIKE ?)");
            String k = "%" + keyword.trim() + "%";
            params.add(k);
            params.add(k);
        }
        if (status != null && !status.trim().isEmpty()) {
            sb.append(" AND d.status = ?");
            params.add(status.trim());
        }
        return sb.toString();
    }

    private static void bind(PreparedStatement ps, List<Object> params) throws SQLException {
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
    }

    /** The open methods a booking may choose (spec v2, Q9). */
    public static final java.util.List<String> OPEN_METHODS = java.util.Arrays.asList("PIN", "CARD", "FINGERPRINT");

    /** v2: the open method decides the code (a PIN or an enroll code); the price depends on the plan and the size only. */
    public long reserve(int userId, int slotId, int planId, String openMethod) throws SQLException {
        return reserve(userId, slotId, planId, openMethod, null);
    }

    /** customMin != null: "Tự chọn" (whole hours or days); the procedure checks it, prices it and picks the plan. */
    public long reserve(int userId, int slotId, int planId, String openMethod, Integer customMin) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Reserve(?, ?, ?, ?, ?, ?)}")) {
            cs.setInt(1, userId);
            cs.setInt(2, slotId);
            cs.setInt(3, planId);
            cs.registerOutParameter(4, Types.BIGINT);
            cs.setString(5, openMethod);
            if (customMin == null) {
                cs.setNull(6, Types.INTEGER);
            } else {
                cs.setInt(6, customMin);
            }
            cs.execute();
            return cs.getLong(4);
        }
    }

    /** The open booking (RESERVED or ACTIVE) of a user, or null. */
    public Deposit findOpenByUser(int userId) throws SQLException {
        String sql = SELECT + " WHERE d.user_id = ? AND d.status IN ('RESERVED', 'ACTIVE')";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /** A new 10-minute enroll code for the owner's open booking; throws 50044 when nothing is left to enroll. */
    public String newEnrollCode(long depositId, int userId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Enroll_NewCode(?, ?, ?)}")) {
            cs.setLong(1, depositId);
            cs.setInt(2, userId);
            cs.registerOutParameter(3, Types.CHAR);
            cs.execute();
            return cs.getString(3);
        }
    }

    /**
     * What each NO_SHOW of a user got back, read from its audit row (v2 gave 90%, v3 gives 0%),
     * so old bookings keep the refund they really had.
     */
    public Map<Long, Long> noShowRefunds(int userId) throws SQLException {
        Map<Long, Long> refunds = new java.util.HashMap<>();
        String sql = "SELECT a.object_id, a.diff_json FROM AuditLog a JOIN Deposit d ON d.deposit_id = a.object_id "
                + "WHERE a.action = N'NO_SHOW' AND a.object_type = N'DEPOSIT' AND d.user_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    try {
                        refunds.put(rs.getLong(1), Long.parseLong(rs.getString(2).trim()));
                    } catch (RuntimeException notANumber) {
                        // an old row without the amount: leave it out, the page shows no refund line
                    }
                }
            }
        }
        return refunds;
    }

    /** v3: the ACTIVE bookings due within DUE_REMINDER_MIN minutes whose owner has an e-mail and got no reminder. */
    public List<Map<String, String>> dueSoon() throws SQLException {
        List<Map<String, String>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_DueSoon}");
             ResultSet rs = cs.executeQuery()) {
            java.sql.ResultSetMetaData md = rs.getMetaData();
            while (rs.next()) {
                Map<String, String> row = new java.util.LinkedHashMap<>();
                for (int i = 1; i <= md.getColumnCount(); i++) {
                    row.put(md.getColumnLabel(i), rs.getString(i));
                }
                list.add(row);
            }
        }
        return list;
    }

    /** v3: the reminder of a booking is done (written once, with an audit row): "e-mail sent" or why it stopped. */
    public void markReminded(long depositId, String note) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_MarkReminded(?, ?)}")) {
            cs.setLong(1, depositId);
            cs.setString(2, note);
            cs.execute();
        }
    }

    public void cancel(long depositId, int userId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Cancel(?, ?)}")) {
            cs.setLong(1, depositId);
            cs.setInt(2, userId);
            cs.execute();
        }
    }

    /** Online extension: moves due_at forward, at most 3 times. */
    public void extend(long depositId, int minutes, int userId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Extend(?, ?, ?)}")) {
            cs.setLong(1, depositId);
            cs.setInt(2, minutes);
            cs.setInt(3, userId);
            cs.execute();
        }
    }

    /** For the heartbeat reply: which card may open which reserved slot of this device. Keys: slot_code, card_uid. */
    public List<Map<String, String>> reservedFor(int deviceId) throws SQLException {
        String sql = "SELECT s.slot_code, c.card_uid FROM Deposit d "
                + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id "
                + "JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "JOIN UserCard c ON c.card_id = d.card_id "
                + "WHERE b.device_id = ? AND d.status = 'RESERVED'";
        List<Map<String, String>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, String> row = new LinkedHashMap<>();
                    row.put("slot_code", rs.getString(1));
                    row.put("card_uid", rs.getString(2));
                    list.add(row);
                }
            }
        }
        return list;
    }

    /** The bookings of one user, newest first: the My bookings page. */
    public List<Deposit> listByUser(int userId) throws SQLException {
        String sql = SELECT + " WHERE d.user_id = ? ORDER BY d.reserved_at DESC";
        List<Deposit> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    /** One page for staff. keyword matches username or slot code; status = "" for all. */
    public List<Deposit> search(String keyword, String status, int page, int size) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = SELECT + where(keyword, status, params)
                + " ORDER BY d.deposit_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        params.add((page - 1) * size);
        params.add(size);
        List<Deposit> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    public int count(String keyword, String status) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM Deposit d "
                + "JOIN Users u ON u.user_id = d.user_id "
                + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id "
                + "JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "JOIN StoragePlan p ON p.plan_id = d.plan_id"
                + where(keyword, status, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public Deposit findById(long depositId) throws SQLException {
        String sql = SELECT + " WHERE d.deposit_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, depositId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /** A business refusal from Java, shown to the user like a THROW 50000+ of a procedure. */
    private static SQLException refused(String message) {
        return new SQLException(message, "45000", 50000);
    }

    /**
     * Staff registers a deposit for a walk-in user, only on an AVAILABLE slot. A user who already has an open
     * booking hits UX_Deposit_user_open (2601), which the controller turns into a message.
     */
    public long insert(Deposit d) throws SQLException {
        String sqlDeposit = "INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, started_at, due_at) "
                + "VALUES (?, ?, ?, ?, ?, SYSUTCDATETIME(), ?)";
        String sqlSlot = "UPDATE LockerSlot SET status = 'OCCUPIED' WHERE locker_slot_id = ? AND status = 'AVAILABLE' "
                + "AND NOT EXISTS (SELECT 1 FROM v_LockerSlotMap m WHERE m.slot_id = locker_slot_id AND m.display_status = 'OFFLINE')";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                try (PreparedStatement psSlot = conn.prepareStatement(sqlSlot)) {
                    psSlot.setInt(1, d.getSlotId());
                    if (psSlot.executeUpdate() != 1) {
                        throw refused("Ngăn này không còn trống hoặc hộp tủ đang mất kết nối, hãy chọn ngăn khác.");
                    }
                }
                long depositId;
                try (PreparedStatement ps = conn.prepareStatement(sqlDeposit, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, d.getUserId());
                    ps.setInt(2, d.getSlotId());
                    ps.setInt(3, d.getPlanId());
                    if (d.getCardId() != null && d.getCardId() > 0) {
                        ps.setInt(4, d.getCardId());
                    } else {
                        ps.setNull(4, Types.INTEGER);
                    }
                    ps.setString(5, d.getStatus() != null ? d.getStatus() : "ACTIVE");
                    ps.setTimestamp(6, d.getDueAt());
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        depositId = keys.next() ? keys.getLong(1) : -1;
                    }
                }
                conn.commit();
                return depositId;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    private static boolean isOpen(String status) {
        return "RESERVED".equals(status) || "ACTIVE".equals(status);
    }

    /** Booking statuses staff may pick in the edit form. */
    public static final java.util.List<String> STATUSES =
            java.util.Arrays.asList("RESERVED", "ACTIVE", "COMPLETED", "NO_SHOW", "CANCELLED");

    /**
     * Staff changes the plan, the due time or closes a booking; returns the amount refunded (0 when none).
     * An open booking may only be closed (its slot is freed unless it is under maintenance); a closed one is never
     * reopened and RESERVED/ACTIVE never swap here (that is the box's check-in). A hold CANCELLED by staff gives the
     * money back like Deposit_Cancel. A due time moved (compared to the second, as the form shows it) re-arms the
     * reminder; moved into the future it also lifts the overdue lock and the escalation, and the late hours restart
     * from the new due time (the fee already charged stays).
     */
    public long update(Deposit d) throws SQLException {
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                String oldStatus;
                int slotId;
                int userId;
                long paid;
                try (PreparedStatement ps = conn.prepareStatement("SELECT status, slot_id, user_id, "
                        + "ISNULL(paid_amount, 0) FROM Deposit WITH (UPDLOCK, HOLDLOCK) WHERE deposit_id = ?")) {
                    ps.setLong(1, d.getDepositId());
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) {
                            throw refused("Không tìm thấy lượt gửi");
                        }
                        oldStatus = rs.getString(1);
                        slotId = rs.getInt(2);
                        userId = rs.getInt(3);
                        paid = rs.getLong(4);
                    }
                }
                String newStatus = d.getStatus();
                boolean closing = isOpen(oldStatus) && !isOpen(newStatus);
                if (!oldStatus.equals(newStatus) && isOpen(newStatus)) {
                    throw refused(isOpen(oldStatus)
                            ? "Trạng thái Đã đặt / Đang gửi do hộp tủ chuyển, không đổi tay được."
                            : "Không mở lại được lượt gửi đã kết thúc, hãy tạo lượt mới.");
                }
                try (PreparedStatement ps = conn.prepareStatement("UPDATE Deposit SET "
                        + "plan_id = CASE WHEN ? > 0 THEN ? ELSE plan_id END, due_at = ?, status = ?, "
                        + "ended_at = CASE WHEN ? = 1 THEN SYSUTCDATETIME() ELSE ended_at END, "
                        + "locked_at = CASE WHEN ? > SYSUTCDATETIME() THEN NULL ELSE locked_at END, "
                        + "escalated_at = CASE WHEN ? > SYSUTCDATETIME() THEN NULL ELSE escalated_at END, "
                        + "overdue_hours = CASE WHEN ? > SYSUTCDATETIME() THEN 0 ELSE overdue_hours END, "
                        + "due_reminder_at = CASE WHEN DATEDIFF_BIG(SECOND, due_at, ?) = 0 THEN due_reminder_at ELSE NULL END "
                        + "WHERE deposit_id = ?")) {
                    ps.setInt(1, d.getPlanId());
                    ps.setInt(2, d.getPlanId());
                    ps.setTimestamp(3, d.getDueAt());
                    ps.setString(4, newStatus);
                    ps.setInt(5, closing ? 1 : 0);
                    for (int i = 6; i <= 9; i++) {
                        ps.setTimestamp(i, d.getDueAt());
                    }
                    ps.setLong(10, d.getDepositId());
                    ps.executeUpdate();
                }
                long refund = "RESERVED".equals(oldStatus) && "CANCELLED".equals(newStatus) ? paid : 0;
                if (refund > 0) {
                    try (PreparedStatement ps = conn.prepareStatement(
                            "UPDATE Users SET balance = balance + ? WHERE user_id = ?")) {
                        ps.setLong(1, refund);
                        ps.setInt(2, userId);
                        ps.executeUpdate();
                    }
                }
                if (closing) {
                    try (PreparedStatement ps = conn.prepareStatement("UPDATE LockerSlot SET status = 'AVAILABLE' "
                            + "WHERE locker_slot_id = ? AND status IN ('RESERVED', 'OCCUPIED')")) {
                        ps.setInt(1, slotId);
                        ps.executeUpdate();
                    }
                }
                conn.commit();
                return refund;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /** null when deleted, otherwise the reason. Only a booking that is not open may be deleted. */
    public String delete(long depositId) throws SQLException {
        Deposit d = findById(depositId);
        if (d == null) return "Không tìm thấy lượt gửi";
        if ("RESERVED".equals(d.getStatus()) || "ACTIVE".equals(d.getStatus())) {
            return "Không xóa được lượt gửi đang dùng hoặc đang giữ chỗ. Hãy hủy hoặc kết thúc trước.";
        }
        String sql = "DELETE FROM Deposit WHERE deposit_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, depositId);
            return ps.executeUpdate() == 1 ? null : "Không có gì bị xóa";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "Lượt gửi này đang được dữ liệu khác tham chiếu, không xóa được.";
            }
            throw e;
        }
    }
}
