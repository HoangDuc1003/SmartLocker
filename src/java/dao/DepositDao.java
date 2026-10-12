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
            + "d.plan_id, p.plan_name, d.card_id, d.status, d.reserved_at, d.hold_until, "
            + "d.started_at, d.due_at, d.ended_at, d.extend_count "
            + "FROM Deposit d "
            + "JOIN Users u ON u.user_id = d.user_id "
            + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id "
            + "JOIN LockerBank b ON b.bank_id = s.bank_id "
            + "JOIN StoragePlan p ON p.plan_id = d.plan_id";

    private static Deposit map(ResultSet rs) throws SQLException {
        Deposit d = new Deposit();
        d.setDepositId(rs.getLong("deposit_id"));
        d.setUserId(rs.getInt("user_id"));
        d.setUsername(rs.getString("username"));
        d.setSlotId(rs.getInt("slot_id"));
        d.setSlotCode(rs.getString("slot_code"));
        d.setBankCode(rs.getString("bank_code"));
        d.setPlanId(rs.getInt("plan_id"));
        d.setPlanName(rs.getString("plan_name"));
        int cardId = rs.getInt("card_id");
        d.setCardId(rs.wasNull() ? null : cardId);
        d.setStatus(rs.getString("status"));
        d.setReservedAt(rs.getTimestamp("reserved_at"));
        d.setHoldUntil(rs.getTimestamp("hold_until"));
        d.setStartedAt(rs.getTimestamp("started_at"));
        d.setDueAt(rs.getTimestamp("due_at"));
        d.setEndedAt(rs.getTimestamp("ended_at"));
        d.setExtendCount(rs.getInt("extend_count"));
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

    /** Case 4: books a slot for the user. The procedure throws a readable error when it cannot (50030 to 50035). */
    public long reserve(int userId, int slotId, int planId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Reserve(?, ?, ?, ?)}")) {
            cs.setInt(1, userId);
            cs.setInt(2, slotId);
            cs.setInt(3, planId);
            cs.registerOutParameter(4, Types.BIGINT);
            cs.execute();
            return cs.getLong(4);
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

    /** The heartbeat says this slot now holds something: the clock of a reserved booking starts. */
    public void checkIn(int deviceId, String slotCode) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_CheckIn(?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, slotCode);
            cs.execute();
        }
    }

    /** A session ended: the booking is completed and the slot is free again. */
    public void complete(int deviceId, String slotCode) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Complete(?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, slotCode);
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

    /** Staff registers a deposit for a walk-in user. Keep the unique indexes of the table in mind. */
    public long insert(Deposit d) throws SQLException {
        String sqlDeposit = "INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, status, started_at, due_at) "
                + "VALUES (?, ?, ?, ?, ?, SYSUTCDATETIME(), ?)";
        String sqlSlot = "UPDATE LockerSlot SET status = 'OCCUPIED' WHERE locker_slot_id = ?";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
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
                try (PreparedStatement psSlot = conn.prepareStatement(sqlSlot)) {
                    psSlot.setInt(1, d.getSlotId());
                    psSlot.executeUpdate();
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

    /** Staff changes the plan or the due time. */
    public boolean update(Deposit d) throws SQLException {
        String sql = "UPDATE Deposit SET plan_id = ?, due_at = ?, status = ? WHERE deposit_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, d.getPlanId());
            ps.setTimestamp(2, d.getDueAt());
            ps.setString(3, d.getStatus());
            ps.setLong(4, d.getDepositId());
            return ps.executeUpdate() == 1;
        }
    }

    /** null when deleted, otherwise the reason. Only a booking that is not open may be deleted. */
    public String delete(long depositId) throws SQLException {
        Deposit d = findById(depositId);
        if (d == null) return "Deposit not found";
        if ("RESERVED".equals(d.getStatus()) || "ACTIVE".equals(d.getStatus())) {
            return "Cannot delete an active or reserved booking. Cancel or complete it first.";
        }
        String sql = "DELETE FROM Deposit WHERE deposit_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, depositId);
            return ps.executeUpdate() == 1 ? null : "Nothing was deleted";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "This booking is referenced by other records and cannot be deleted.";
            }
            throw e;
        }
    }
}
