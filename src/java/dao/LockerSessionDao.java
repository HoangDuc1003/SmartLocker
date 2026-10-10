package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.List;
import java.util.Map;
import model.LockerSession;
import util.Todo;

/** Sessions are append-only: this class inserts and reads, it never updates or deletes. */
public class LockerSessionDao {

    /** SQL Server error numbers for a UNIQUE violation. */
    public static final int DUPLICATE_KEY = 2627;
    public static final int DUPLICATE_INDEX = 2601;

    /**
     * Stores one session. Returns the new session_id, or -1 when the same (device, seq) is already there,
     * which happens when the device re-sends its buffer. Any other error is thrown.
     */
    public long insert(LockerSession s) throws SQLException {
        throw Todo.of("LockerSessionDao.insert: INSERT ... SELECT so slot_code becomes slot_id in the same statement; catch the duplicate");
    }

    /** One page of sessions for the history page and the alert detail. Keys follow the table columns. */
    public List<Map<String, Object>> search(Integer deviceId, int page, int size) throws SQLException {
        throw Todo.of("LockerSession LEFT JOIN LockerSlot, plus DATEDIFF(MINUTE, measured_at, ingested_at) AS upload_delay_min, newest first");
    }

    public int count(Integer deviceId) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filter");
    }

    public LockerSession findById(long sessionId) throws SQLException {
        throw Todo.of("one session by id");
    }
}
