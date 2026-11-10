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

    /** insert() result: the device already sent this (device, seq). */
    public static final long DUPLICATE = -1;
    /** insert() result: the slot code matches slots in two banks of the device and nothing tells them apart. */
    public static final long AMBIGUOUS_SLOT = -2;
    /** insert() result: the bank_code sent with the session is not a bank of this device (nothing stored). */
    public static final long UNKNOWN_BANK = -3;

    /**
     * The slot of a session. A box may manage several banks (sql/demo_box.sql), so (device, slot_code) can match
     * more than one slot. Tie-breakers, in order: the bank_code sent with the session, then the slot of the
     * session's own command (PHONE/REMOTE). Returns null for no slot code or no match, AMBIGUOUS_SLOT when still
     * more than one slot fits: never guess, the alert rules would judge the wrong booking. A bank_code that is
     * not a bank of the device gives UNKNOWN_BANK (a firmware/config error, not "no slot").
     */
    static Long resolveSlot(Connection conn, LockerSession s) throws SQLException {
        if (s.getBankCode() != null) {
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM LockerBank WHERE device_id = ? AND bank_code = ?")) {
                ps.setInt(1, s.getDeviceId());
                ps.setString(2, s.getBankCode());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next() && rs.getInt(1) == 0) {
                        return UNKNOWN_BANK;
                    }
                }
            }
        }
        if (s.getSlotCode() == null) {
            return null;
        }
        String sql = "SELECT s.locker_slot_id, CASE WHEN c.command_id IS NULL THEN 0 ELSE 1 END AS of_command "
                + "FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "LEFT JOIN RemoteCommand c ON c.command_id = ? AND c.device_id = b.device_id AND c.slot_id = s.locker_slot_id "
                + "WHERE b.device_id = ? AND s.slot_code = ? AND (? IS NULL OR b.bank_code = ?)";
        List<long[]> rows = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            if (s.getCommandId() == null) {
                ps.setNull(1, Types.BIGINT);
            } else {
                ps.setLong(1, s.getCommandId());
            }
            ps.setInt(2, s.getDeviceId());
            ps.setString(3, s.getSlotCode());
            ps.setString(4, s.getBankCode());
            ps.setString(5, s.getBankCode());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows.add(new long[]{rs.getLong(1), rs.getInt(2)});
                }
            }
        }
        if (rows.size() == 1) {
            return rows.get(0)[0];
        }
        for (long[] r : rows) {
            if (r[1] == 1) {
                return r[0];                                  // the command names exactly one slot
            }
        }
        return rows.isEmpty() ? null : AMBIGUOUS_SLOT;
    }

    /**
     * Stores one session. Returns the new session_id, DUPLICATE when the same (device, seq) is already there
     * (the device re-sends its buffer), AMBIGUOUS_SLOT or UNKNOWN_BANK (nothing stored). Any other error is thrown.
     */
    public long insert(LockerSession s) throws SQLException {
        String sql = "INSERT INTO LockerSession (device_id, device_seq, measured_at, door_open_sec, weight_delta_g, "
                + "unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source, command_id) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DbContext.getConnection()) {
            Long slotId = resolveSlot(conn, s);
            if (slotId != null && (slotId == AMBIGUOUS_SLOT || slotId == UNKNOWN_BANK)) {
                return slotId;
            }
            try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
                ps.setInt(1, s.getDeviceId());
                ps.setInt(2, s.getDeviceSeq());
                ps.setTimestamp(3, s.getMeasuredAt());
                ps.setDouble(4, s.getDoorOpenSec());
                ps.setDouble(5, s.getWeightDeltaG());
                ps.setInt(6, s.getUnlockCount());
                ps.setBoolean(7, s.isRfidOk());
                ps.setDouble(8, s.getStayMin());
                if (slotId == null) {
                    ps.setNull(9, Types.INTEGER);
                } else {
                    ps.setInt(9, slotId.intValue());
                }
                ps.setString(10, s.getCardUid());
                ps.setString(11, s.getOpenSource());
                if (s.getCommandId() == null) {
                    ps.setNull(12, Types.BIGINT);
                } else {
                    ps.setLong(12, s.getCommandId());
                }
                ps.executeUpdate();
                try (ResultSet keys = ps.getGeneratedKeys()) {
                    return keys.next() ? keys.getLong(1) : DUPLICATE;
                }
            }
        } catch (SQLException e) {
            if (e.getErrorCode() == DUPLICATE_KEY || e.getErrorCode() == DUPLICATE_INDEX) {
                return DUPLICATE;
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

    /**
     * The filters of the "Dữ liệu cảm biến" page. q: a word in the box code, the slot code, the open source, the label or the alert,
     * or a session number. fromUtc / toUtc: the measured time, as UTC "yyyy-MM-dd HH:mm:ss" (the page turns the Vietnam
     * dates into these), toUtc excluded. sort: a key of SORTS, desc: newest / largest first.
     */
    public static final class Filter {
        public String q;
        public Integer deviceId;
        public String fromUtc;
        public String toUtc;
        public String sort = "measured";
        public boolean desc = true;
    }

    /** The sortable columns of the page: key -> SQL column. Only these reach ORDER BY. */
    public static final Map<String, String> SORTS = new LinkedHashMap<>();

    static {
        SORTS.put("measured", "ls.measured_at");
        SORTS.put("ingested", "ls.ingested_at");
        SORTS.put("id", "ls.session_id");
        SORTS.put("device", "v.device_code");
        SORTS.put("door", "ls.door_open_sec");
        SORTS.put("weight", "ls.weight_delta_g");
        SORTS.put("stay", "ls.stay_min");
    }

    private static final String LIST_FROM = "FROM LockerSession ls "
            + "JOIN Device v ON v.device_id = ls.device_id "
            + "LEFT JOIN LockerSlot s ON s.locker_slot_id = ls.slot_id "
            + "LEFT JOIN LockerSessionLabel l ON l.session_id = ls.session_id "
            + "OUTER APPLY (SELECT TOP 1 a.label, a.alert_id FROM Alert a WHERE a.session_id = ls.session_id ORDER BY a.alert_id DESC) al ";

    private static String where(Filter f, List<Object> params) {
        StringBuilder sb = new StringBuilder("WHERE 1 = 1 ");
        if (f.q != null && !f.q.isEmpty()) {
            String like = "%" + f.q.replace("[", "[[]").replace("%", "[%]").replace("_", "[_]") + "%";
            sb.append("AND (v.device_code LIKE ? OR s.slot_code LIKE ? OR ls.open_source LIKE ? OR l.label LIKE ? OR al.label LIKE ? "
                    + "OR CAST(ls.session_id AS NVARCHAR(20)) = ?) ");
            params.add(like);
            params.add(like);
            params.add(like);
            params.add(like);
            params.add(like);
            params.add(f.q.startsWith("#") ? f.q.substring(1) : f.q);
        }
        if (f.deviceId != null && f.deviceId > 0) {
            sb.append("AND ls.device_id = ? ");
            params.add(f.deviceId);
        }
        if (f.fromUtc != null) {
            sb.append("AND ls.measured_at >= CAST(? AS DATETIME2) ");
            params.add(f.fromUtc);
        }
        if (f.toUtc != null) {
            sb.append("AND ls.measured_at < CAST(? AS DATETIME2) ");
            params.add(f.toUtc);
        }
        return sb.toString();
    }

    private static void bind(PreparedStatement ps, List<Object> params) throws SQLException {
        for (int i = 0; i < params.size(); i++) {
            Object p = params.get(i);
            if (p instanceof Integer) {
                ps.setInt(i + 1, (Integer) p);
            } else {
                ps.setString(i + 1, (String) p);
            }
        }
    }

    /** One page of the "Dữ liệu cảm biến" list, with the box code and the label of each session. */
    public List<Map<String, Object>> list(Filter f, int page, int size) throws SQLException {
        List<Object> params = new ArrayList<>();
        String column = SORTS.containsKey(f.sort) ? SORTS.get(f.sort) : SORTS.get("measured");
        String dir = f.desc ? "DESC" : "ASC";
        String sql = "SELECT ls.session_id, ls.device_id, v.device_code, ls.device_seq, ls.measured_at, ls.ingested_at, "
                + "ls.door_open_sec, ls.weight_delta_g, ls.unlock_count, ls.rfid_ok, ls.stay_min, "
                + "s.slot_code, ls.open_source, l.label, al.label AS alert_label, al.alert_id "
                + LIST_FROM + where(f, params)
                + "ORDER BY " + column + " " + dir + ", ls.session_id " + dir + " OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            ps.setInt(params.size() + 1, (page - 1) * size);
            ps.setInt(params.size() + 2, size);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("session_id", rs.getLong("session_id"));
                    map.put("device_id", rs.getInt("device_id"));
                    map.put("device_code", rs.getString("device_code"));
                    map.put("device_seq", rs.getInt("device_seq"));
                    map.put("measured_at", rs.getTimestamp("measured_at"));
                    map.put("ingested_at", rs.getTimestamp("ingested_at"));
                    map.put("door_open_sec", rs.getDouble("door_open_sec"));
                    map.put("weight_delta_g", rs.getDouble("weight_delta_g"));
                    map.put("unlock_count", rs.getInt("unlock_count"));
                    map.put("rfid_ok", rs.getBoolean("rfid_ok"));
                    map.put("stay_min", rs.getDouble("stay_min"));
                    map.put("slot_code", rs.getString("slot_code"));
                    map.put("open_source", rs.getString("open_source"));
                    map.put("label", rs.getString("label"));             // the training label (seed data)
                    map.put("alert_label", rs.getString("alert_label")); // what the rules or the model raised, if anything
                    map.put("alert_id", rs.getObject("alert_id"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public int count(Filter f) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*) " + LIST_FROM + where(f, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
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
