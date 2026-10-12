package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Numbers for the dashboard cards and the live chart. */
public class DashboardDao {

    /** The last sessions of a device, oldest first so a chart can draw them left to right. Keys: time, a, b. */
    public List<Map<String, Object>> recentSessions(int deviceId, int limit) throws SQLException {
        // TOP (?) newest first in SQL, then reversed in Java
        String sql = "SELECT TOP (?) CONVERT(VARCHAR(19), measured_at, 120) AS t, door_open_sec, weight_delta_g "
                + "FROM LockerSession WHERE device_id = ? ORDER BY measured_at DESC";
        List<Map<String, Object>> points = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            ps.setInt(2, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> p = new LinkedHashMap<>();
                    p.put("time", rs.getString("t"));
                    p.put("a", rs.getDouble("door_open_sec"));
                    p.put("b", rs.getDouble("weight_delta_g"));
                    points.add(0, p);
                }
            }
        }
        return points;
    }

    /** Counts for the cards: free, inUse, overdue, openAlerts, offlineDevices. */
    public Map<String, Integer> lockerCounts() throws SQLException {
        Map<String, Integer> counts = new LinkedHashMap<>();
        int free = 0;
        int inUse = 0;
        int overdue = 0;
        int openAlerts = 0;
        int offlineDevices = 0;

        try (Connection conn = DbContext.getConnection()) {
            String sqlMap = "SELECT display_status, COUNT(*) AS cnt FROM v_LockerSlotMap GROUP BY display_status";
            try (PreparedStatement ps = conn.prepareStatement(sqlMap);
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String status = rs.getString("display_status");
                    int cnt = rs.getInt("cnt");
                    if ("AVAILABLE".equalsIgnoreCase(status)) {
                        free += cnt;
                    } else if ("OCCUPIED".equalsIgnoreCase(status) || "RESERVED".equalsIgnoreCase(status)) {
                        inUse += cnt;
                    } else if ("OVERDUE".equalsIgnoreCase(status)) {
                        inUse += cnt;
                        overdue += cnt;
                    }
                }
            }

            String sqlAlerts = "SELECT COUNT(*) FROM Alert WHERE status = 'OPEN'";
            try (PreparedStatement ps = conn.prepareStatement(sqlAlerts);
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    openAlerts = rs.getInt(1);
                }
            }

            String sqlDevices = "SELECT COUNT(*) FROM Device WHERE status = 'OFFLINE'";
            try (PreparedStatement ps = conn.prepareStatement(sqlDevices);
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    offlineDevices = rs.getInt(1);
                }
            }
        }

        counts.put("free", free);
        counts.put("inUse", inUse);
        counts.put("overdue", overdue);
        counts.put("openAlerts", openAlerts);
        counts.put("offlineDevices", offlineDevices);
        return counts;
    }
}
