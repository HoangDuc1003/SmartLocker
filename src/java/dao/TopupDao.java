package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import model.TopupRequest;

/** Account top-up requests and staff decisions. */
public class TopupDao {

    private static final String BASE_SELECT = "SELECT r.request_id, r.user_id, u.username, u.full_name, "
            + "r.amount, r.transfer_code, r.qr_url, r.status, "
            + "r.created_at, r.approved_at, r.approved_by, adm.username AS approved_by_name, r.note "
            + "FROM TopupRequest r "
            + "JOIN Users u ON u.user_id = r.user_id "
            + "LEFT JOIN Users adm ON adm.user_id = r.approved_by ";

    private static TopupRequest map(ResultSet rs) throws SQLException {
        TopupRequest t = new TopupRequest();
        t.setRequestId(rs.getInt("request_id"));
        t.setUserId(rs.getInt("user_id"));
        t.setUsername(rs.getString("username"));
        t.setFullName(rs.getString("full_name"));
        t.setAmount(rs.getLong("amount"));
        t.setTransferCode(rs.getString("transfer_code"));
        t.setQrUrl(rs.getString("qr_url"));
        t.setStatus(rs.getString("status"));
        t.setCreatedAt(rs.getTimestamp("created_at"));
        t.setApprovedAt(rs.getTimestamp("approved_at"));
        int admId = rs.getInt("approved_by");
        t.setApprovedBy(rs.wasNull() ? null : admId);
        t.setApprovedByName(rs.getString("approved_by_name"));
        t.setNote(rs.getString("note"));
        return t;
    }

    /** Creates a new pending topup request and returns its generated ID. */
    public int create(int userId, long amount, String transferCode, String qrUrl) throws SQLException {
        String sql = "INSERT INTO TopupRequest (user_id, amount, transfer_code, qr_url, status) "
                + "VALUES (?, ?, ?, ?, N'PENDING')";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, userId);
            ps.setLong(2, amount);
            ps.setString(3, transferCode);
            ps.setString(4, qrUrl);
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                return rs.next() ? rs.getInt(1) : -1;
            }
        }
    }

    public TopupRequest findById(int requestId) throws SQLException {
        String sql = BASE_SELECT + "WHERE r.request_id = ?";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, requestId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /** List requests of a specific user, newest first. */
    public List<TopupRequest> listByUser(int userId) throws SQLException {
        String sql = BASE_SELECT + "WHERE r.user_id = ? ORDER BY r.request_id DESC";
        List<TopupRequest> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    /** List all requests (optionally filtered by status: PENDING, APPROVED, REJECTED), newest first. */
    public List<TopupRequest> listAll(String status) throws SQLException {
        String sql = BASE_SELECT;
        boolean filter = status != null && !status.trim().isEmpty();
        if (filter) {
            sql += "WHERE r.status = ? ";
        }
        sql += "ORDER BY CASE WHEN r.status = N'PENDING' THEN 0 ELSE 1 END, r.request_id DESC";
        List<TopupRequest> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (filter) {
                ps.setString(1, status.trim());
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    /**
     * Admin approves a topup request in a single atomic transaction:
     * 1. Updates TopupRequest to APPROVED.
     * 2. Credits the amount to the user's balance in Users table.
     * 3. Appends an audit trail record in the same transaction.
     */
    public boolean approve(int requestId, int adminId) throws SQLException {
        TopupRequest req = findById(requestId);
        if (req == null || !"PENDING".equals(req.getStatus())) {
            return false;
        }

        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                // 1. Mark approved
                String sqlUpdate = "UPDATE TopupRequest SET status = N'APPROVED', approved_at = SYSUTCDATETIME(), approved_by = ? "
                        + "WHERE request_id = ? AND status = N'PENDING'";
                try (PreparedStatement ps = conn.prepareStatement(sqlUpdate)) {
                    ps.setInt(1, adminId);
                    ps.setInt(2, requestId);
                    if (ps.executeUpdate() == 0) {
                        conn.rollback();
                        return false;
                    }
                }

                // 2. Add money to user balance
                String sqlAdd = "UPDATE Users SET balance = balance + ? WHERE user_id = ?";
                try (PreparedStatement ps = conn.prepareStatement(sqlAdd)) {
                    ps.setLong(1, req.getAmount());
                    ps.setInt(2, req.getUserId());
                    ps.executeUpdate();
                }

                appendAudit(conn, adminId, "TOPUP_APPROVE", requestId,
                        "Approved " + req.getAmount() + " VND for user " + req.getUsername());
                conn.commit();
                return true;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    /** Admin rejects a topup request. */
    public boolean reject(int requestId, int adminId, String note) throws SQLException {
        String sql = "UPDATE TopupRequest SET status = N'REJECTED', approved_at = SYSUTCDATETIME(), approved_by = ?, note = ? "
                + "WHERE request_id = ? AND status = N'PENDING'";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                try (PreparedStatement ps = conn.prepareStatement(sql)) {
                    ps.setInt(1, adminId);
                    ps.setString(2, note);
                    ps.setInt(3, requestId);
                    if (ps.executeUpdate() == 0) {
                        conn.rollback();
                        return false;
                    }
                }
                appendAudit(conn, adminId, "TOPUP_REJECT", requestId, "Rejected: " + note);
                conn.commit();
                return true;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    private static void appendAudit(Connection conn, int actorId, String action,
                                    int requestId, String detail) throws SQLException {
        try (CallableStatement cs = conn.prepareCall("{call Audit_Append(?, ?, ?, ?, ?)}")) {
            cs.setInt(1, actorId);
            cs.setString(2, action);
            cs.setString(3, "TOPUP");
            cs.setLong(4, requestId);
            cs.setString(5, detail);
            cs.execute();
        }
    }
}
