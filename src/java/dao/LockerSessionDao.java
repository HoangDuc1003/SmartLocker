package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import model.LockerSession;

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
        String sql = "SELECT ls.session_id, ls.device_id, ls.device_seq, ls.measured_at, ls.ingested_at, "
                + "ls.door_open_sec, ls.weight_delta_g, ls.unlock_count, ls.rfid_ok, ls.stay_min, "
                + "ls.slot_id, s.slot_code, ls.card_uid, ls.open_source, ls.command_id, "
                + "DATEDIFF(MINUTE, ls.measured_at, ls.ingested_at) AS upload_delay_min "
                + "FROM LockerSession ls "
                + "LEFT JOIN LockerSlot s ON s.locker_slot_id = ls.slot_id ";
        if (deviceId != null && deviceId > 0) {
            sql += "WHERE ls.device_id = ? ";
        }
        sql += "ORDER BY ls.session_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            int idx = 1;
            if (deviceId != null && deviceId > 0) {
                ps.setInt(idx++, deviceId);
            }
            ps.setInt(idx++, (page - 1) * size);
            ps.setInt(idx, size);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("session_id", rs.getLong("session_id"));
                    map.put("device_id", rs.getInt("device_id"));
                    map.put("device_seq", rs.getInt("device_seq"));
                    map.put("measured_at", rs.getTimestamp("measured_at"));
                    map.put("ingested_at", rs.getTimestamp("ingested_at"));
                    map.put("door_open_sec", rs.getDouble("door_open_sec"));
                    map.put("weight_delta_g", rs.getDouble("weight_delta_g"));
                    map.put("unlock_count", rs.getInt("unlock_count"));
                    map.put("rfid_ok", rs.getBoolean("rfid_ok"));
                    map.put("stay_min", rs.getDouble("stay_min"));
                    map.put("slot_id", rs.getInt("slot_id"));
                    map.put("slot_code", rs.getString("slot_code"));
                    map.put("card_uid", rs.getString("card_uid"));
                    map.put("open_source", rs.getString("open_source"));
                    map.put("command_id", rs.getObject("command_id"));
                    map.put("upload_delay_min", rs.getInt("upload_delay_min"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public int count(Integer deviceId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM LockerSession ls ";
        if (deviceId != null && deviceId > 0) {
            sql += "WHERE ls.device_id = ?";
        }
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            if (deviceId != null && deviceId > 0) {
                ps.setInt(1, deviceId);
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public LockerSession findById(long sessionId) throws SQLException {
        String sql = "SELECT ls.session_id, ls.device_id, ls.device_seq, ls.measured_at, ls.ingested_at, "
                + "ls.door_open_sec, ls.weight_delta_g, ls.unlock_count, ls.rfid_ok, ls.stay_min, "
                + "ls.slot_id, s.slot_code, ls.card_uid, ls.open_source, ls.command_id "
                + "FROM LockerSession ls "
                + "LEFT JOIN LockerSlot s ON s.locker_slot_id = ls.slot_id "
                + "WHERE ls.session_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, sessionId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                LockerSession s = new LockerSession();
                s.setSessionId(rs.getLong("session_id"));
                s.setDeviceId(rs.getInt("device_id"));
                s.setDeviceSeq(rs.getInt("device_seq"));
                s.setMeasuredAt(rs.getTimestamp("measured_at"));
                s.setDoorOpenSec(rs.getDouble("door_open_sec"));
                s.setWeightDeltaG(rs.getDouble("weight_delta_g"));
                s.setUnlockCount(rs.getInt("unlock_count"));
                s.setRfidOk(rs.getBoolean("rfid_ok"));
                s.setStayMin(rs.getDouble("stay_min"));
                s.setSlotCode(rs.getString("slot_code"));
                s.setCardUid(rs.getString("card_uid"));
                s.setOpenSource(rs.getString("open_source"));
                long cmd = rs.getLong("command_id");
                s.setCommandId(rs.wasNull() ? null : cmd);
                return s;
            }
        }
    }
}
