package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * v2: the box decides nothing, it asks. Device_Authorize, Enroll_Start and Enroll_Finish make the decision
 * and the lockout count in one transaction; this class only calls them and returns their one row.
 */
public class DeviceAuthDao {

    /** The single row of a procedure as column -> value (Integer, Long, String or null). */
    private static Map<String, Object> firstRow(CallableStatement cs) throws SQLException {
        // the procedures run EXEC inside, so skip update counts until the result set comes
        boolean isResult = cs.execute();
        while (!isResult && cs.getUpdateCount() != -1) {
            isResult = cs.getMoreResults();
        }
        Map<String, Object> row = new LinkedHashMap<>();
        if (!isResult) {
            return row;
        }
        try (ResultSet rs = cs.getResultSet()) {
            if (rs.next()) {
                ResultSetMetaData md = rs.getMetaData();
                for (int i = 1; i <= md.getColumnCount(); i++) {
                    row.put(md.getColumnLabel(i), rs.getObject(i));
                }
            }
        }
        return row;
    }

    /** method = PIN, CARD or FINGERPRINT; source = DEVICE (the box itself) or PHONE (the /k page). */
    public Map<String, Object> authorize(int deviceId, String method, String pin, String cardUid,
                                         Integer sensorSlot, String source) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Device_Authorize(?, ?, ?, ?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, method);
            cs.setString(3, pin);
            cs.setString(4, cardUid);
            if (sensorSlot == null) {
                cs.setNull(5, Types.INTEGER);
            } else {
                cs.setInt(5, sensorSlot);
            }
            cs.setString(6, source);
            return firstRow(cs);
        }
    }

    /** type = CARD or FINGERPRINT. A finger gets a free AS608 slot in "sensor_slot". */
    public Map<String, Object> enrollStart(int deviceId, String type, String code) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Enroll_Start(?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, type);
            cs.setString(3, code);
            return firstRow(cs);
        }
    }

    /** Stores the finger slot, or the card UID and its one-time card deposit. */
    public Map<String, Object> enrollFinish(int deviceId, String type, String code, Integer sensorSlot, String cardUid)
            throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Enroll_Finish(?, ?, ?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, type);
            cs.setString(3, code);
            if (sensorSlot == null) {
                cs.setNull(4, Types.INTEGER);
            } else {
                cs.setInt(4, sensorSlot);
            }
            cs.setString(5, cardUid);
            return firstRow(cs);
        }
    }

    /** The owner removes a finger; the box gets DELETE_FP with its next heartbeat. Throws 50045 when not found. */
    public void deleteFingerprint(int fpId, int userId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Fingerprint_Delete(?, ?)}")) {
            cs.setInt(1, fpId);
            cs.setInt(2, userId);
            cs.execute();
        }
    }

    /** device_id, device_code, location, status of a box by its code (the /k/{device_code} page), or null. */
    public Map<String, Object> findDeviceByCode(String deviceCode) throws SQLException {
        // one box may manage several banks (sql/demo_box.sql): list them all, the area of the first
        String sql = "SELECT v.device_id, v.device_code, v.location, v.status, bk.bank_code, bk.area_name "
                + "FROM Device v OUTER APPLY (SELECT STRING_AGG(b.bank_code, ', ') WITHIN GROUP (ORDER BY b.bank_code) AS bank_code, "
                + "MIN(a.name) AS area_name FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id "
                + "WHERE b.device_id = v.device_id) bk WHERE v.device_code = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, deviceCode);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("device_id", rs.getInt("device_id"));
                row.put("device_code", rs.getString("device_code"));
                row.put("location", rs.getString("location"));
                row.put("status", rs.getString("status"));
                row.put("bank_code", rs.getString("bank_code"));
                row.put("area_name", rs.getString("area_name"));
                return row;
            }
        }
    }

    /** The registered cards of a user (newest first). Keys: card_id, card_uid, status, deposit_amount, registered_device. */
    public List<Map<String, Object>> cardsOf(int userId) throws SQLException {
        String sql = "SELECT c.card_id, c.card_uid, c.status, c.deposit_amount, v.device_code, c.issued_at "
                + "FROM UserCard c LEFT JOIN Device v ON v.device_id = c.registered_device_id "
                + "WHERE c.user_id = ? ORDER BY c.card_id DESC";
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("card_id", rs.getInt("card_id"));
                    row.put("card_uid", rs.getString("card_uid"));
                    row.put("status", rs.getString("status"));
                    row.put("deposit_amount", rs.getLong("deposit_amount"));
                    row.put("registered_device", rs.getString("device_code"));
                    row.put("registered", rs.getString("device_code") != null || rs.getLong("deposit_amount") > 0);
                    list.add(row);
                }
            }
        }
        return list;
    }

    /** The ACTIVE fingerprints of a user, one per box. Keys: fp_id, device_code, sensor_slot, created_at. */
    public List<Map<String, Object>> fingerprintsOf(int userId) throws SQLException {
        String sql = "SELECT f.fp_id, v.device_code, f.sensor_slot, f.created_at FROM Fingerprint f "
                + "JOIN Device v ON v.device_id = f.device_id WHERE f.user_id = ? AND f.status = N'ACTIVE' "
                + "ORDER BY v.device_code";
        List<Map<String, Object>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("fp_id", rs.getInt("fp_id"));
                    row.put("device_code", rs.getString("device_code"));
                    row.put("sensor_slot", rs.getInt("sensor_slot"));
                    row.put("created_at", rs.getTimestamp("created_at"));
                    list.add(row);
                }
            }
        }
        return list;
    }

    /** True when the user has a card enrolled at a box (or marked so by staff): no card deposit is due. */
    public boolean hasRegisteredCard(int userId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM UserCard WHERE user_id = ? AND status = N'ACTIVE' "
                + "AND (registered_device_id IS NOT NULL OR deposit_amount > 0)";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) > 0;
            }
        }
    }
}
