package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import model.LockerArea;

/** Areas (Thư viện, Ký túc xá A...): list, find, insert, update, delete. */
public class LockerAreaDao {

    /** Every area with its slot count and user count, ordered by code. The list page and the drop-downs use it. */
    public List<LockerArea> listAll() throws SQLException {
        String sql = "SELECT a.area_id, a.area_code, a.name, a.location, a.is_active, a.latitude, a.longitude, "
                + "(SELECT COUNT(*) FROM LockerBank b JOIN LockerSlot s ON s.bank_id = b.bank_id WHERE b.area_id = a.area_id) AS slot_count, "
                + "(SELECT COUNT(*) FROM Users u WHERE u.area_id = a.area_id) AS user_count "
                + "FROM LockerArea a ORDER BY a.area_code";
        List<LockerArea> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                LockerArea a = new LockerArea();
                a.setAreaId(rs.getInt("area_id"));
                a.setAreaCode(rs.getString("area_code"));
                a.setName(rs.getString("name"));
                a.setLocation(rs.getString("location"));
                a.setActive(rs.getBoolean("is_active"));
                a.setLatitude(coord(rs, "latitude"));
                a.setLongitude(coord(rs, "longitude"));
                a.setSlotCount(rs.getInt("slot_count"));
                a.setUserCount(rs.getInt("user_count"));
                list.add(a);
            }
        }
        return list;
    }

    private static Double coord(ResultSet rs, String column) throws SQLException {
        java.math.BigDecimal v = rs.getBigDecimal(column);
        return v == null ? null : v.doubleValue();
    }

    private static void bindCoord(PreparedStatement ps, int idx, Double value) throws SQLException {
        if (value == null) {
            ps.setNull(idx, java.sql.Types.DECIMAL);
        } else {
            ps.setBigDecimal(idx, java.math.BigDecimal.valueOf(value).setScale(6, java.math.RoundingMode.HALF_UP));
        }
    }

    public List<LockerArea> search(String keyword, int page, int size) throws SQLException {
        String sql = "SELECT a.area_id, a.area_code, a.name, a.location, a.is_active, a.latitude, a.longitude, "
                + "(SELECT COUNT(*) FROM LockerBank b JOIN LockerSlot s ON s.bank_id = b.bank_id WHERE b.area_id = a.area_id) AS slot_count, "
                + "(SELECT COUNT(*) FROM Users u WHERE u.area_id = a.area_id) AS user_count "
                + "FROM LockerArea a ";
        boolean hasKeyword = keyword != null && !keyword.trim().isEmpty();
        if (hasKeyword) {
            sql += "WHERE a.area_code LIKE ? OR a.name LIKE ? OR a.location LIKE ? ";
        }
        sql += "ORDER BY a.area_code OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        List<LockerArea> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            int idx = 1;
            if (hasKeyword) {
                String k = "%" + keyword.trim() + "%";
                ps.setString(idx++, k);
                ps.setString(idx++, k);
                ps.setString(idx++, k);
            }
            ps.setInt(idx++, (page - 1) * size);
            ps.setInt(idx++, size);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    LockerArea a = new LockerArea();
                    a.setAreaId(rs.getInt("area_id"));
                    a.setAreaCode(rs.getString("area_code"));
                    a.setName(rs.getString("name"));
                    a.setLocation(rs.getString("location"));
                    a.setActive(rs.getBoolean("is_active"));
                a.setLatitude(coord(rs, "latitude"));
                a.setLongitude(coord(rs, "longitude"));
                    a.setSlotCount(rs.getInt("slot_count"));
                    a.setUserCount(rs.getInt("user_count"));
                    list.add(a);
                }
            }
        }
        return list;
    }

    public int count(String keyword) throws SQLException {
        String sql = "SELECT COUNT(*) FROM LockerArea a ";
        boolean hasKeyword = keyword != null && !keyword.trim().isEmpty();
        if (hasKeyword) {
            sql += "WHERE a.area_code LIKE ? OR a.name LIKE ? OR a.location LIKE ? ";
        }
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            if (hasKeyword) {
                String k = "%" + keyword.trim() + "%";
                ps.setString(1, k);
                ps.setString(2, k);
                ps.setString(3, k);
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public LockerArea findById(int areaId) throws SQLException {
        String sql = "SELECT a.area_id, a.area_code, a.name, a.location, a.is_active, a.latitude, a.longitude, "
                + "(SELECT COUNT(*) FROM LockerBank b JOIN LockerSlot s ON s.bank_id = b.bank_id WHERE b.area_id = a.area_id) AS slot_count, "
                + "(SELECT COUNT(*) FROM Users u WHERE u.area_id = a.area_id) AS user_count "
                + "FROM LockerArea a WHERE a.area_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, areaId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    LockerArea a = new LockerArea();
                    a.setAreaId(rs.getInt("area_id"));
                    a.setAreaCode(rs.getString("area_code"));
                    a.setName(rs.getString("name"));
                    a.setLocation(rs.getString("location"));
                    a.setActive(rs.getBoolean("is_active"));
                a.setLatitude(coord(rs, "latitude"));
                a.setLongitude(coord(rs, "longitude"));
                    a.setSlotCount(rs.getInt("slot_count"));
                    a.setUserCount(rs.getInt("user_count"));
                    return a;
                }
            }
        }
        return null;
    }

    public int insert(LockerArea a) throws SQLException {
        String sql = "INSERT INTO LockerArea (area_code, name, location, is_active, latitude, longitude) VALUES (?, ?, ?, ?, ?, ?)";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, a.getAreaCode());
            ps.setString(2, a.getName());
            ps.setString(3, a.getLocation());
            ps.setBoolean(4, a.isActive());
            bindCoord(ps, 5, a.getLatitude());
            bindCoord(ps, 6, a.getLongitude());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        }
    }

    public boolean update(LockerArea a) throws SQLException {
        String sql = "UPDATE LockerArea SET area_code = ?, name = ?, location = ?, is_active = ?, latitude = ?, longitude = ? WHERE area_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, a.getAreaCode());
            ps.setString(2, a.getName());
            ps.setString(3, a.getLocation());
            ps.setBoolean(4, a.isActive());
            bindCoord(ps, 5, a.getLatitude());
            bindCoord(ps, 6, a.getLongitude());
            ps.setInt(7, a.getAreaId());
            return ps.executeUpdate() == 1;
        }
    }

    /** null when deleted, otherwise the reason: banks or users still point to the area (SQL error 547). */
    public String delete(int areaId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM LockerArea WHERE area_id = ?")) {
            ps.setInt(1, areaId);
            return ps.executeUpdate() == 1 ? null : "Không tìm thấy khu vực";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "Khu vực còn dãy tủ hoặc người dùng, hãy chuyển sang ngừng hoạt động thay vì xóa";
            }
            throw e;
        }
    }

    public boolean codeExists(String areaCode, int exceptAreaId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM LockerArea WHERE area_code = ? AND area_id <> ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, areaCode);
            ps.setInt(2, exceptAreaId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) > 0;
            }
        }
    }
}
