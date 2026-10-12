package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

/** Writes to the tamper-evident audit log and reads it back. */
public class AuditDao {

    /** user_id of the 'system' account, the first row of Users. Automatic work is done as this user. */
    public static final int SYSTEM_USER_ID = 1;

    /**
     * Appends one row through the Audit_Append stored procedure, which also chains its hash.
     * Always pass a real actor and a real object id: a NULL is hashed differently by SQL and Java.
     */
    public void append(int actorId, String action, String objectType, long objectId, String diff) throws SQLException {
        // CallableStatement {call Audit_Append(?,?,?,?,?)}
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Audit_Append(?, ?, ?, ?, ?)}")) {
            cs.setInt(1, actorId);
            cs.setString(2, action);
            cs.setString(3, objectType);
            cs.setLong(4, objectId);
            cs.setString(5, diff);
            cs.execute();
        }
    }

    /** One page of the log, newest first. action = "" for all. Keys: audit_id, ts, actor, action, object_type, object_id, diff_json. */
    public List<Map<String, Object>> search(String action, int page, int size) throws SQLException {
        String sql = "SELECT a.audit_id, a.ts, ISNULL(u.username, N'unknown') AS actor, a.action, "
                + "a.object_type, a.object_id, a.diff_json, a.row_hash "
                + "FROM AuditLog a LEFT JOIN Users u ON u.user_id = a.actor_user_id ";
        boolean hasAction = action != null && !action.trim().isEmpty();
        if (hasAction) {
            sql += "WHERE a.action = ? ";
        }
        sql += "ORDER BY a.audit_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        List<Map<String, Object>> list = new java.util.ArrayList<>();
        try (Connection conn = DbContext.getConnection(); java.sql.PreparedStatement ps = conn.prepareStatement(sql)) {
            int idx = 1;
            if (hasAction) {
                ps.setString(idx++, action.trim());
            }
            ps.setInt(idx++, (page - 1) * size);
            ps.setInt(idx++, size);
            try (java.sql.ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new java.util.HashMap<>();
                    map.put("audit_id", rs.getLong("audit_id"));
                    map.put("ts", rs.getTimestamp("ts"));
                    map.put("actor", rs.getString("actor"));
                    map.put("action", rs.getString("action"));
                    map.put("object_type", rs.getString("object_type"));
                    map.put("object_id", rs.getLong("object_id"));
                    map.put("diff_json", rs.getString("diff_json"));
                    map.put("row_hash", rs.getString("row_hash"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public int count(String action) throws SQLException {
        String sql = "SELECT COUNT(*) FROM AuditLog ";
        boolean hasAction = action != null && !action.trim().isEmpty();
        if (hasAction) {
            sql += "WHERE action = ?";
        }
        try (Connection conn = DbContext.getConnection(); java.sql.PreparedStatement ps = conn.prepareStatement(sql)) {
            if (hasAction) {
                ps.setString(1, action.trim());
            }
            try (java.sql.ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /** Distinct actions, for the filter drop-down. */
    public List<String> actions() throws SQLException {
        String sql = "SELECT DISTINCT action FROM AuditLog ORDER BY action";
        List<String> list = new java.util.ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             java.sql.PreparedStatement ps = conn.prepareStatement(sql);
             java.sql.ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(rs.getString(1));
            }
        }
        return list;
    }
}
