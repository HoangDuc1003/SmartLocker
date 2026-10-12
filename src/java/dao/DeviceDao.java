package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import model.Device;
import util.SecurityUtils;

/** Devices (ESP32): login by API key, heartbeat, status. */
public class DeviceDao {

    /** device_id for an API key, or null. Only the SHA-256 of the key is stored, never the key. */
    public Integer findIdByApiKey(String apiKey) throws SQLException {
        // hash the key with SecurityUtils.sha256Hex and compare with Device.api_key_hash
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

    /** Case 1: records last_seen, brings an OFFLINE device back and closes its alert. */
    public void heartbeat(int deviceId) throws SQLException {
        // {call Device_Heartbeat(?)}
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Device_Heartbeat(?)}")) {
            cs.setInt(1, deviceId);
            cs.execute();
        }
    }

    /** All devices with the seconds since their last heartbeat, for the dashboard and the device page. */
    public List<Device> listAll() throws SQLException {
        String sql = "SELECT device_id, device_code, location, firmware, status, last_seen, "
                + "DATEDIFF(SECOND, last_seen, SYSUTCDATETIME()) AS last_seen_sec "
                + "FROM Device ORDER BY device_code";
        List<Device> list = new java.util.ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Device d = new Device();
                d.setDeviceId(rs.getInt("device_id"));
                d.setDeviceCode(rs.getString("device_code"));
                d.setLocation(rs.getString("location"));
                d.setFirmware(rs.getString("firmware"));
                d.setStatus(rs.getString("status"));
                d.setLastSeen(rs.getTimestamp("last_seen"));
                int sec = rs.getInt("last_seen_sec");
                d.setLastSeenSec(rs.wasNull() ? null : sec);
                list.add(d);
            }
        }
        return list;
    }

    /** An operator sets ACTIVE or MAINTENANCE by hand. OFFLINE is only ever set by the system. */
    public boolean setStatus(int deviceId, String status) throws SQLException {
        if (!"ACTIVE".equals(status) && !"MAINTENANCE".equals(status)) {
            return false;
        }
        String sql = "UPDATE Device SET status = ? WHERE device_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setInt(2, deviceId);
            return ps.executeUpdate() == 1;
        }
    }

    public List<Device> listAvailableForBank(Integer currentDeviceId) throws SQLException {
        String sql = "SELECT device_id, device_code, location, firmware, status, last_seen, "
                + "DATEDIFF(SECOND, last_seen, SYSUTCDATETIME()) AS last_seen_sec FROM Device "
                + "WHERE device_id NOT IN (SELECT device_id FROM LockerBank WHERE device_id IS NOT NULL "
                + (currentDeviceId != null && currentDeviceId > 0 ? "AND device_id <> " + currentDeviceId : "")
                + ") ORDER BY device_code";
        List<Device> list = new java.util.ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Device d = new Device();
                d.setDeviceId(rs.getInt("device_id"));
                d.setDeviceCode(rs.getString("device_code"));
                d.setLocation(rs.getString("location"));
                d.setFirmware(rs.getString("firmware"));
                d.setStatus(rs.getString("status"));
                d.setLastSeen(rs.getTimestamp("last_seen"));
                int sec = rs.getInt("last_seen_sec");
                d.setLastSeenSec(rs.wasNull() ? null : sec);
                list.add(d);
            }
        }
        return list;
    }
}
