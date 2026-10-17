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
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Device_Heartbeat(?)}")) {
            cs.setInt(1, deviceId);
            cs.execute();
        }
    }

    /** v2 heartbeat: the box reports its firmware version (at most 20 characters are kept). */
    public void setFirmware(int deviceId, String firmware) throws SQLException {
        String sql = "UPDATE Device SET firmware = ? WHERE device_id = ? AND ISNULL(firmware, '') <> ?";
        String value = firmware.length() > 20 ? firmware.substring(0, 20) : firmware;
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, value);
            ps.setInt(2, deviceId);
            ps.setString(3, value);
            ps.executeUpdate();
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

    public Device findById(int deviceId) throws SQLException {
        String sql = "SELECT device_id, device_code, location, firmware, status, last_seen, "
                + "DATEDIFF(SECOND, last_seen, SYSUTCDATETIME()) AS last_seen_sec "
                + "FROM Device WHERE device_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Device d = new Device();
                    d.setDeviceId(rs.getInt("device_id"));
                    d.setDeviceCode(rs.getString("device_code"));
                    d.setLocation(rs.getString("location"));
                    d.setFirmware(rs.getString("firmware"));
                    d.setStatus(rs.getString("status"));
                    d.setLastSeen(rs.getTimestamp("last_seen"));
                    int sec = rs.getInt("last_seen_sec");
                    d.setLastSeenSec(rs.wasNull() ? null : sec);
                    return d;
                }
            }
        }
        return null;
    }

    /** An operator or technician sets ACTIVE, MAINTENANCE or OFFLINE. Bringing ACTIVE updates last_seen and resolves DEVICE_OFFLINE alerts. */
    public boolean setStatus(int deviceId, String status) throws SQLException {
        if (!"ACTIVE".equals(status) && !"MAINTENANCE".equals(status) && !"OFFLINE".equals(status)) {
            return false;
        }
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int changed;
                if ("ACTIVE".equals(status)) {
                    String updateSql = "UPDATE Device SET status = 'ACTIVE', last_seen = SYSUTCDATETIME() WHERE device_id = ?";
                    try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
                        ps.setInt(1, deviceId);
                        changed = ps.executeUpdate();
                    }
                    // Close any open DEVICE_OFFLINE alerts for this device
                    String resolveAlert = "UPDATE Alert SET status = 'RESOLVED' WHERE device_id = ? AND label = 'DEVICE_OFFLINE' AND status = 'OPEN'";
                    try (PreparedStatement ps = conn.prepareStatement(resolveAlert)) {
                        ps.setInt(1, deviceId);
                        ps.executeUpdate();
                    }
                } else {
                    String updateSql = "UPDATE Device SET status = ? WHERE device_id = ?";
                    try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
                        ps.setString(1, status);
                        ps.setInt(2, deviceId);
                        changed = ps.executeUpdate();
                    }
                }
                conn.commit();
                return changed == 1;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
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
