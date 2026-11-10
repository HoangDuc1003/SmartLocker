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

    /** method = PIN or FINGERPRINT; source = DEVICE (the box itself) or PHONE (the /k page). */
    public Map<String, Object> authorize(int deviceId, String method, String pin, Integer sensorSlot, String source)
            throws SQLException {
        return authorize(deviceId, method, pin, sensorSlot, source, null);
    }

    /**
     * v6: intent = ASK (an ACTIVE booking answers CHOOSE), OPEN (UNLOCK phase ACCESS), CHECKOUT or null (PICKUP).
     * A RESERVED booking always checks in, an overdue-locked one always picks up.
     */
    public Map<String, Object> authorize(int deviceId, String method, String pin, Integer sensorSlot, String source,
                                         String intent) throws SQLException {
        return call(deviceId, method, pin, sensorSlot, source, intent, null, null);
    }

    /**
     * v7: the signed-in owner tapped the box with a phone (method PHONE). tap is the token of the box's NFC tag
     * (Device_TapIssue); a demo box needs none. Opens any open booking of the user on this box, as a phone command.
     */
    public Map<String, Object> authorizeTap(int deviceId, int userId, String tap, String intent) throws SQLException {
        return call(deviceId, "PHONE", null, null, "PHONE", intent, userId, tap);
    }

    private Map<String, Object> call(int deviceId, String method, String pin, Integer sensorSlot, String source,
                                     String intent, Integer userId, String tap) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Device_Authorize(?, ?, ?, ?, ?, ?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, method);
            cs.setString(3, pin);
            if (sensorSlot == null) {
                cs.setNull(4, Types.INTEGER);
            } else {
                cs.setInt(4, sensorSlot);
            }
            cs.setString(5, source);
            cs.setString(6, intent);
            if (userId == null) {
                cs.setNull(7, Types.INTEGER);
            } else {
                cs.setInt(7, userId);
            }
            cs.setString(8, tap);
            return firstRow(cs);
        }
    }

    /** The token the box writes into its NFC tag; a new one each minute and after each use (Device_TapIssue). */
    public String tapToken(int deviceId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Device_TapIssue(?)}")) {
            cs.setInt(1, deviceId);
            Object token = firstRow(cs).get("token");
            return token == null ? null : token.toString().trim();
        }
    }

    /** type = FINGERPRINT (the only thing left to enroll). A finger gets a free AS608 slot in "sensor_slot". */
    public Map<String, Object> enrollStart(int deviceId, String type, String code) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Enroll_Start(?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, type);
            cs.setString(3, code);
            return firstRow(cs);
        }
    }

    /** Stores the finger slot. */
    public Map<String, Object> enrollFinish(int deviceId, String type, String code, Integer sensorSlot) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Enroll_Finish(?, ?, ?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, type);
            cs.setString(3, code);
            if (sensorSlot == null) {
                cs.setNull(4, Types.INTEGER);
            } else {
                cs.setInt(4, sensorSlot);
            }
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

    /** device_id, device_code, location, status, bank_code, area_name, demo of a box by its code (the /k page), or null. */
    public Map<String, Object> findDeviceByCode(String deviceCode) throws SQLException {
        // one box may manage several banks (sql/demo_box.sql): list them all, the area of the first
        String sql = "SELECT v.device_id, v.device_code, v.location, v.status, bk.bank_code, bk.area_name, "
                + "CASE WHEN EXISTS (SELECT 1 FROM (SELECT TOP 1 p.params_json FROM OperatingProfile p WHERE p.device_id = v.device_id "
                + "ORDER BY p.profile_id DESC) p WHERE p.params_json LIKE N'%\"demo\":true%') THEN 1 ELSE 0 END AS demo "
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
                row.put("demo", rs.getInt("demo") == 1);   // a demo box has no NFC reader: its page opens without a tap
                return row;
            }
        }
    }

    /** The open booking (RESERVED or ACTIVE) of a user on a box: slot_code, bank_code, status, open_method; or null. */
    public Map<String, Object> openBookingAt(int userId, int deviceId) throws SQLException {
        String sql = "SELECT TOP 1 s.slot_code, b.bank_code, d.status, d.open_method FROM Deposit d "
                + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "WHERE d.user_id = ? AND b.device_id = ? AND d.status IN (N'RESERVED', N'ACTIVE')";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setInt(2, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("slot_code", rs.getString("slot_code"));
                row.put("bank_code", rs.getString("bank_code"));
                row.put("status", rs.getString("status"));
                row.put("open_method", rs.getString("open_method"));
                return row;
            }
        }
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
}
