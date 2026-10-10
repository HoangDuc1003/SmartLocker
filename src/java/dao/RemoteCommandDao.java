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
        throw Todo.of("RemoteCommandDao.create: {call RemoteCommand_Create(?, ?, ?, ?)} with a BIGINT OUTPUT parameter");
    }

    /** Hands the pending commands to the device in the heartbeat reply. Keys: command_id, slot_code, action. */
    public List<Map<String, Object>> takePending(int deviceId) throws SQLException {
        throw Todo.of("RemoteCommandDao.takePending: the procedure is an UPDATE ... OUTPUT, so it returns a result set");
    }

    /** A valid command is used once: SENT becomes DONE and remembers the session that used it. */
    public void markDone(long commandId, long sessionId) throws SQLException {
        throw Todo.of("RemoteCommandDao.markDone: UPDATE ... WHERE status = 'SENT' makes the command single use");
    }

    /** History page: who opened which slot, why, and what became of the command. */
    public List<Map<String, Object>> search(String status, int page, int size) throws SQLException {
        throw Todo.of("RemoteCommand JOIN LockerSlot JOIN Users (requested_by), optional status, ORDER BY command_id DESC, OFFSET/FETCH");
    }

    public int count(String status) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filter");
    }
}
