package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import model.LockerBank;

/** Banks: one cabinet of doors in an area, linked to the device that drives it. */
public class LockerBankDao {

    /** Every bank, for the drop-downs of other pages. No paging. */
    public List<LockerBank> listAll() throws SQLException {
        String sql = "SELECT b.bank_id, b.bank_code, b.name, b.area_id, a.area_code, b.device_id, b.door_rows, b.status, "
                + "(SELECT COUNT(*) FROM LockerSlot s WHERE s.bank_id = b.bank_id) AS slot_count "
                + "FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id ORDER BY b.bank_code";
        List<LockerBank> items = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                LockerBank b = new LockerBank();
                b.setBankId(rs.getInt("bank_id"));
                b.setBankCode(rs.getString("bank_code"));
                b.setName(rs.getString("name"));
                b.setAreaId(rs.getInt("area_id"));
                b.setAreaCode(rs.getString("area_code"));
                int deviceId = rs.getInt("device_id");
                b.setDeviceId(rs.wasNull() ? null : deviceId);
                b.setDoorRows(rs.getInt("door_rows"));
                b.setStatus(rs.getString("status"));
                b.setSlotCount(rs.getInt("slot_count"));
                items.add(b);
            }
        }
        return items;
    }

    /** The box of a bank: demo or real, and its physical slot ("physical_slot_id" in OperatingProfile, sql/demo_box.sql). */
    private static final String BOX_COLUMNS = ", v.device_code, bx.demo, ps.slot_code AS physical_slot, pb.bank_code AS physical_bank ";
    private static final String BOX_JOIN = " LEFT JOIN Device v ON v.device_id = b.device_id "
            + "OUTER APPLY (SELECT TOP 1 CASE WHEN p.params_json LIKE '%\"demo\":true%' THEN 1 ELSE 0 END AS demo, "
            + "TRY_CAST(JSON_VALUE(p.params_json, '$.physical_slot_id') AS INT) AS slot_id "
            + "FROM OperatingProfile p WHERE p.device_id = b.device_id ORDER BY p.profile_id DESC) bx "
            + "LEFT JOIN LockerSlot ps ON ps.locker_slot_id = bx.slot_id LEFT JOIN LockerBank pb ON pb.bank_id = ps.bank_id";

    private static LockerBank map(ResultSet rs) throws SQLException {
        LockerBank b = new LockerBank();
        b.setBankId(rs.getInt("bank_id"));
        b.setBankCode(rs.getString("bank_code"));
        b.setName(rs.getString("name"));
        b.setAreaId(rs.getInt("area_id"));
        b.setAreaCode(rs.getString("area_code"));
        int deviceId = rs.getInt("device_id");
        b.setDeviceId(rs.wasNull() ? null : deviceId);
        b.setDoorRows(rs.getInt("door_rows"));
        b.setStatus(rs.getString("status"));
        b.setSlotCount(rs.getInt("slot_count"));
        b.setDeviceCode(rs.getString("device_code"));
        b.setDemoDevice(rs.getInt("demo") == 1);
        b.setPhysicalSlot(rs.getString("physical_slot"));
        b.setPhysicalBank(rs.getString("physical_bank"));
        return b;
    }

    private static String where(String keyword, Integer areaId, List<Object> params) {
        StringBuilder sb = new StringBuilder();
        boolean where = false;
        if (keyword != null && !keyword.trim().isEmpty()) {
            sb.append(" WHERE (b.bank_code LIKE ? OR b.name LIKE ?)");
            String k = "%" + keyword.trim() + "%";
            params.add(k);
            params.add(k);
            where = true;
        }
        if (areaId != null && areaId > 0) {
            sb.append(where ? " AND " : " WHERE ");
            sb.append("b.area_id = ?");
            params.add(areaId);
        }
        return sb.toString();
    }

    public List<LockerBank> search(String keyword, Integer areaId, int page, int size) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT b.bank_id, b.bank_code, b.name, b.area_id, a.area_code, b.device_id, b.door_rows, b.status, "
                + "(SELECT COUNT(*) FROM LockerSlot s WHERE s.bank_id = b.bank_id) AS slot_count " + BOX_COLUMNS
                + "FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id" + BOX_JOIN
                + where(keyword, areaId, params)
                + " ORDER BY b.bank_code OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        params.add((page - 1) * size);
        params.add(size);
        List<LockerBank> items = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    items.add(map(rs));
                }
            }
        }
        return items;
    }

    public int count(String keyword, Integer areaId) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id" + where(keyword, areaId, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public LockerBank findById(int bankId) throws SQLException {
        String sql = "SELECT b.bank_id, b.bank_code, b.name, b.area_id, a.area_code, b.device_id, b.door_rows, b.status, "
                + "(SELECT COUNT(*) FROM LockerSlot s WHERE s.bank_id = b.bank_id) AS slot_count " + BOX_COLUMNS
                + "FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id" + BOX_JOIN + " WHERE b.bank_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bankId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    public int insert(LockerBank b) throws SQLException {
        String sql = "INSERT INTO LockerBank (bank_code, name, area_id, device_id, door_rows, status) VALUES (?, ?, ?, ?, ?, ?)";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, java.sql.Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, b.getBankCode());
            ps.setString(2, b.getName());
            ps.setInt(3, b.getAreaId());
            if (b.getDeviceId() != null && b.getDeviceId() > 0) {
                ps.setInt(4, b.getDeviceId());
            } else {
                ps.setNull(4, java.sql.Types.INTEGER);
            }
            ps.setInt(5, b.getDoorRows());
            ps.setString(6, b.getStatus() == null ? "ACTIVE" : b.getStatus());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        }
    }

    public boolean update(LockerBank b) throws SQLException {
        String sql = "UPDATE LockerBank SET bank_code = ?, name = ?, area_id = ?, device_id = ?, door_rows = ?, status = ? WHERE bank_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, b.getBankCode());
            ps.setString(2, b.getName());
            ps.setInt(3, b.getAreaId());
            if (b.getDeviceId() != null && b.getDeviceId() > 0) {
                ps.setInt(4, b.getDeviceId());
            } else {
                ps.setNull(4, java.sql.Types.INTEGER);
            }
            ps.setInt(5, b.getDoorRows());
            ps.setString(6, b.getStatus());
            ps.setInt(7, b.getBankId());
            return ps.executeUpdate() == 1;
        }
    }

    /** null when deleted, otherwise the reason (a bank with slots cannot be deleted: SQL error 547). */
    public String delete(int bankId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM LockerBank WHERE bank_id = ?")) {
            ps.setInt(1, bankId);
            return ps.executeUpdate() == 1 ? null : "Không tìm thấy dãy tủ";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "Dãy tủ còn ngăn, hãy xóa hoặc chuyển các ngăn trước";
            }
            throw e;
        }
    }

    public boolean codeExists(String bankCode, int exceptBankId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM LockerBank WHERE bank_code = ? AND bank_id <> ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, bankCode);
            ps.setInt(2, exceptBankId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) > 0;
            }
        }
    }
}
