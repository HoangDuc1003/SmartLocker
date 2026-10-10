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
        // INSERT ... SELECT so slot_code becomes slot_id in the same statement; catch the duplicate
        String sql = "INSERT INTO LockerSession (device_id, device_seq, measured_at, door_open_sec, weight_delta_g, "
                + "unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source, command_id) "
                + "SELECT ?, ?, ?, ?, ?, ?, ?, ?, "
                + "(SELECT s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id "
                + " WHERE b.device_id = ? AND s.slot_code = ?), ?, ?, ?";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, s.getDeviceId());
            ps.setInt(2, s.getDeviceSeq());
            ps.setTimestamp(3, s.getMeasuredAt());
            ps.setDouble(4, s.getDoorOpenSec());
            ps.setDouble(5, s.getWeightDeltaG());
            ps.setInt(6, s.getUnlockCount());
            ps.setBoolean(7, s.isRfidOk());
            ps.setDouble(8, s.getStayMin());
            ps.setInt(9, s.getDeviceId());
            ps.setString(10, s.getSlotCode());
            ps.setString(11, s.getCardUid());
            ps.setString(12, s.getOpenSource());
            if (s.getCommandId() == null) {
                ps.setNull(13, Types.BIGINT);
            } else {
                ps.setLong(13, s.getCommandId());
            }
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getLong(1) : -1;
            }
        } catch (SQLException e) {
            if (e.getErrorCode() == DUPLICATE_KEY || e.getErrorCode() == DUPLICATE_INDEX) {
                return -1;
            }
            throw e;
        }
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
