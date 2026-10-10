package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import util.Todo;

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
        throw Todo.of("one query on v_LockerSlotMap grouped by display_status, plus COUNT of OPEN alerts and OFFLINE devices");
    }
}
