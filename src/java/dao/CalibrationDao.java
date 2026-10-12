package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import model.Calibration;

/** Calibration of a sensor on a device. A new version is a new row, old rows stay as history. */
public class CalibrationDao {

    private static final String SELECT = "SELECT c.calib_id, c.device_id, d.device_code, c.sensor_type_id, st.name AS sensor_name, "
            + "c.offset_val, c.scale_val, c.version, c.valid_until, c.created_by "
            + "FROM Calibration c "
            + "JOIN Device d ON d.device_id = c.device_id "
            + "JOIN SensorType st ON st.sensor_type_id = c.sensor_type_id";

    private static Calibration map(ResultSet rs) throws SQLException {
        Calibration c = new Calibration();
        c.setCalibId(rs.getInt("calib_id"));
        c.setDeviceId(rs.getInt("device_id"));
        c.setDeviceCode(rs.getString("device_code"));
        c.setSensorTypeId(rs.getInt("sensor_type_id"));
        c.setSensorName(rs.getString("sensor_name"));
        c.setOffsetVal(rs.getDouble("offset_val"));
        c.setScaleVal(rs.getDouble("scale_val"));
        c.setVersion(rs.getInt("version"));
        c.setValidUntil(rs.getDate("valid_until"));
        c.setCreatedBy(rs.getInt("created_by"));
        return c;
    }

    public List<Calibration> search(Integer deviceId, int page, int size) throws SQLException {
        String sql = SELECT;
        if (deviceId != null && deviceId > 0) {
            sql += " WHERE c.device_id = ?";
        }
        sql += " ORDER BY d.device_code, st.name, c.version DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        List<Calibration> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            int idx = 1;
            if (deviceId != null && deviceId > 0) {
                ps.setInt(idx++, deviceId);
            }
            ps.setInt(idx++, (page - 1) * size);
            ps.setInt(idx, size);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    public int count(Integer deviceId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM Calibration c";
        if (deviceId != null && deviceId > 0) {
            sql += " WHERE c.device_id = ?";
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

    public Calibration findById(int calibId) throws SQLException {
        String sql = SELECT + " WHERE c.calib_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, calibId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /** Adds the next version for the device and sensor: MAX(version) + 1. */
    public int insert(Calibration c) throws SQLException {
        String sql = "INSERT INTO Calibration (device_id, sensor_type_id, offset_val, scale_val, version, valid_until, created_by) "
                + "VALUES (?, ?, ?, ?, (SELECT ISNULL(MAX(version), 0) + 1 FROM Calibration WHERE device_id = ? AND sensor_type_id = ?), ?, ?)";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, c.getDeviceId());
            ps.setInt(2, c.getSensorTypeId());
            ps.setDouble(3, c.getOffsetVal());
            ps.setDouble(4, c.getScaleVal());
            ps.setInt(5, c.getDeviceId());
            ps.setInt(6, c.getSensorTypeId());
            ps.setDate(7, c.getValidUntil());
            ps.setInt(8, c.getCreatedBy());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        }
    }

    public boolean update(Calibration c) throws SQLException {
        String sql = "UPDATE Calibration SET offset_val = ?, scale_val = ?, valid_until = ? WHERE calib_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDouble(1, c.getOffsetVal());
            ps.setDouble(2, c.getScaleVal());
            ps.setDate(3, c.getValidUntil());
            ps.setInt(4, c.getCalibId());
            return ps.executeUpdate() == 1;
        }
    }

    public String delete(int calibId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM Calibration WHERE calib_id = ?")) {
            ps.setInt(1, calibId);
            return ps.executeUpdate() == 1 ? null : "Calibration row not found";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "This calibration record is in use and cannot be deleted";
            }
            throw e;
        }
    }

    /** Dropdown data: sensor types as {id, name}. */
    public List<String[]> sensorTypes() throws SQLException {
        String sql = "SELECT sensor_type_id, name FROM SensorType ORDER BY sensor_type_id";
        List<String[]> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(new String[]{String.valueOf(rs.getInt(1)), rs.getString(2)});
            }
        }
        return list;
    }
}
