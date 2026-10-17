package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Case 2: unlock commands from staff to a device. */
public class RemoteCommandDao {

    /** Queues an UNLOCK for the slot. Returns the command id. The procedure refuses an offline device (50011). */
    public long create(int slotId, String reason, int actorId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call RemoteCommand_Create(?, ?, ?, ?)}")) {
            cs.setInt(1, slotId);
            cs.setString(2, reason);
            cs.setInt(3, actorId);
            cs.registerOutParameter(4, Types.BIGINT);
            cs.execute();
            return cs.getLong(4);
        }
    }

    /** Hands the pending commands to the device in the heartbeat reply. Keys: command_id, slot_code, action, sensor_slot, source. */
    public List<Map<String, Object>> takePending(int deviceId) throws SQLException {
        // the procedure ends with one SELECT; it also checks in or picks up phone bookings, so skip any update count first
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call RemoteCommand_TakePending(?)}")) {
            cs.setInt(1, deviceId);
            boolean isResult = cs.execute();
            while (!isResult && cs.getUpdateCount() != -1) {
                isResult = cs.getMoreResults();
            }
            if (!isResult) {
                return list;
            }
            try (ResultSet rs = cs.getResultSet()) {
                while (rs.next()) {
                    Map<String, Object> cmd = new LinkedHashMap<>();
                    cmd.put("command_id", rs.getLong("command_id"));
                    cmd.put("slot_code", rs.getString("slot_code"));
                    cmd.put("action", rs.getString("action"));
                    int sensorSlot = rs.getInt("sensor_slot");
                    cmd.put("sensor_slot", rs.wasNull() ? null : sensorSlot);
                    cmd.put("source", rs.getString("source"));
                    list.add(cmd);
                }
            }
        }
        return list;
    }

    /** A valid command is used once: SENT becomes DONE and remembers the session that used it. */
    public void markDone(long commandId, long sessionId) throws SQLException {
        // UPDATE ... WHERE status = 'SENT' makes the command single use
        String sql = "UPDATE RemoteCommand SET status = 'DONE', done_at = SYSUTCDATETIME(), session_id = ? "
                + "WHERE command_id = ? AND status = 'SENT'";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, sessionId);
            ps.setLong(2, commandId);
            ps.executeUpdate();
        }
    }

    /** History page: who opened which slot, why, and what became of the command. */
    public List<Map<String, Object>> search(String status, int page, int size) throws SQLException {
        String sql = "SELECT rc.command_id, rc.device_id, rc.slot_id, s.slot_code, rc.action, rc.status, "
                + "rc.reason, u.username AS requested_by_name, rc.created_at, rc.sent_at, rc.done_at, rc.session_id "
                + "FROM RemoteCommand rc "
                + "LEFT JOIN LockerSlot s ON s.locker_slot_id = rc.slot_id "   // DELETE_FP has no slot
                + "JOIN Users u ON u.user_id = rc.requested_by ";
        if (status != null && !status.trim().isEmpty()) {
            sql += "WHERE rc.status = ? ";
        }
        sql += "ORDER BY rc.command_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
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
                    map.put("command_id", rs.getLong("command_id"));
                    map.put("device_id", rs.getInt("device_id"));
                    map.put("slot_id", rs.getObject("slot_id"));
                    map.put("slot_code", rs.getString("slot_code"));
                    map.put("action", rs.getString("action"));
                    map.put("status", rs.getString("status"));
                    map.put("reason", rs.getString("reason"));
                    map.put("requested_by_name", rs.getString("requested_by_name"));
                    map.put("created_at", rs.getTimestamp("created_at"));
                    map.put("sent_at", rs.getTimestamp("sent_at"));
                    map.put("done_at", rs.getTimestamp("done_at"));
                    map.put("session_id", rs.getObject("session_id"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public int count(String status) throws SQLException {
        String sql = "SELECT COUNT(*) FROM RemoteCommand rc ";
        if (status != null && !status.trim().isEmpty()) {
            sql += "WHERE rc.status = ?";
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
