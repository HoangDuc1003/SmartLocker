package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import util.Todo;

/** Writes to the tamper-evident audit log and reads it back. */
public class AuditDao {

    /** user_id of the 'system' account, the first row of Users. Automatic work is done as this user. */
    public static final int SYSTEM_USER_ID = 1;

    /**
     * Appends one row through the Audit_Append stored procedure, which also chains its hash.
     * Always pass a real actor and a real object id: a NULL is hashed differently by SQL and Java.
     */
    public void append(int actorId, String action, String objectType, long objectId, String diff) throws SQLException {
        throw Todo.of("AuditDao.append: CallableStatement {call Audit_Append(?,?,?,?,?)}");
    }

    /** One page of the log, newest first. action = "" for all. Keys: audit_id, ts, actor, action, object_type, object_id, diff_json. */
    public List<Map<String, Object>> search(String action, int page, int size) throws SQLException {
        throw Todo.of("AuditLog JOIN Users (actor name), optional WHERE action = ?, ORDER BY audit_id DESC OFFSET/FETCH");
    }

    public int count(String action) throws SQLException {
        throw Todo.of("SELECT COUNT(*) FROM AuditLog with the same optional filter");
    }

    /** Distinct actions, for the filter drop-down. */
    public List<String> actions() throws SQLException {
        throw Todo.of("SELECT DISTINCT action FROM AuditLog ORDER BY action");
    }
}
