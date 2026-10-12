package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Case 5: maintenance tickets. */
public class MaintenanceDao {

    /**
     * Opens one ticket for the device (not a second one while one is open), gives it to the least busy
     * technician and puts the slot of the session out of service.
     */
    public void openForFault(int deviceId, int alertId, long sessionId, String note) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Ticket_OpenForFault(?, ?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setInt(2, alertId);
            cs.setLong(3, sessionId);
            cs.setString(4, note);
            cs.execute();
        }
    }

    /** The technician fixed it: closes the ticket, gives the slot back, resolves the alert. */
    public void close(int ticketId, int actorId, String note) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Ticket_Close(?, ?, ?)}")) {
            cs.setInt(1, ticketId);
            cs.setInt(2, actorId);
            cs.setString(3, note);
            cs.execute();
        }
    }

    /** Keys: ticket_id, alert_id, device_code, assigned_to_name, note, status, opened_at, closed_at. */
    public List<Map<String, Object>> search(String status, int page, int size) throws SQLException {
        String sql = "SELECT t.ticket_id, t.alert_id, d.device_code, u.full_name AS assigned_to_name, "
                + "t.note, t.status, t.opened_at, t.closed_at "
                + "FROM MaintenanceTicket t "
                + "JOIN Device d ON d.device_id = t.device_id "
                + "LEFT JOIN Users u ON u.user_id = t.assigned_to ";
        if (status != null && !status.trim().isEmpty()) {
            sql += "WHERE t.status = ? ";
        }
        sql += "ORDER BY t.ticket_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            int idx = 1;
            if (status != null && !status.trim().isEmpty()) {
                ps.setString(idx++, status.trim());
            }
            ps.setInt(idx++, (page - 1) * size);
            ps.setInt(idx, size);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("ticket_id", rs.getInt("ticket_id"));
                    map.put("alert_id", rs.getInt("alert_id"));
                    map.put("device_code", rs.getString("device_code"));
                    map.put("assigned_to_name", rs.getString("assigned_to_name"));
                    map.put("note", rs.getString("note"));
                    map.put("status", rs.getString("status"));
                    map.put("opened_at", rs.getTimestamp("opened_at"));
                    map.put("closed_at", rs.getTimestamp("closed_at"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public int count(String status) throws SQLException {
        String sql = "SELECT COUNT(*) FROM MaintenanceTicket t ";
        if (status != null && !status.trim().isEmpty()) {
            sql += "WHERE t.status = ?";
        }
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            if (status != null && !status.trim().isEmpty()) {
                ps.setString(1, status.trim());
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }
}
