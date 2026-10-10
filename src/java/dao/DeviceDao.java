package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import model.Device;
import util.SecurityUtils;
import util.Todo;

/** Devices (ESP32): login by API key, heartbeat, status. */
public class DeviceDao {

    /** device_id for an API key, or null. Only the SHA-256 of the key is stored, never the key. */
    public Integer findIdByApiKey(String apiKey) throws SQLException {
        throw Todo.of("DeviceDao.findIdByApiKey: hash the key with SecurityUtils.sha256Hex and compare with Device.api_key_hash");
    }

    /** Case 1: records last_seen, brings an OFFLINE device back and closes its alert. */
    public void heartbeat(int deviceId) throws SQLException {
        throw Todo.of("DeviceDao.heartbeat: {call Device_Heartbeat(?)}");
    }

    /** All devices with the seconds since their last heartbeat, for the dashboard and the device page. */
    public List<Device> listAll() throws SQLException {
        throw Todo.of("SELECT device columns, DATEDIFF(SECOND, last_seen, SYSUTCDATETIME()) AS last_seen_sec");
    }

    /** An operator sets ACTIVE or MAINTENANCE by hand. OFFLINE is only ever set by the system. */
    public boolean setStatus(int deviceId, String status) throws SQLException {
        throw Todo.of("UPDATE Device SET status = ? WHERE device_id = ?; refuse any status but ACTIVE or MAINTENANCE");
    }
}
