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
import util.Todo;

/** Case 2: unlock commands from staff to a device. */
public class RemoteCommandDao {

    /** Queues an UNLOCK for the slot. Returns the command id. The procedure refuses an offline device (50011). */
    public long create(int slotId, String reason, int actorId) throws SQLException {
        // {call RemoteCommand_Create(?, ?, ?, ?)} with a BIGINT OUTPUT parameter
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

    /** Hands the pending commands to the device in the heartbeat reply. Keys: command_id, slot_code, action. */
    public List<Map<String, Object>> takePending(int deviceId) throws SQLException {
        // the procedure is an UPDATE ... OUTPUT, so it returns a result set
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call RemoteCommand_TakePending(?)}")) {
            cs.setInt(1, deviceId);
            try (ResultSet rs = cs.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> cmd = new LinkedHashMap<>();
                    cmd.put("command_id", rs.getLong("command_id"));
                    cmd.put("slot_code", rs.getString("slot_code"));
                    cmd.put("action", rs.getString("action"));
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
        throw Todo.of("RemoteCommand JOIN LockerSlot JOIN Users (requested_by), optional status, ORDER BY command_id DESC, OFFSET/FETCH");
    }

    public int count(String status) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filter");
    }
}
