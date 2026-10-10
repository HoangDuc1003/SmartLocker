package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import model.LockerBank;
import util.Todo;

/** Banks: one cabinet of doors in an area. Write it like LockerSlotDao. */
public class LockerBankDao {

    /** Every bank, for the drop-downs of other pages. No paging. */
    public List<LockerBank> listAll() throws SQLException {
        // SELECT with the area code, ORDER BY bank_code
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

    public List<LockerBank> search(String keyword, Integer areaId, int page, int size) throws SQLException {
        throw Todo.of("like LockerSlotDao.search: filter by code/name and area, OFFSET/FETCH");
    }

    public int count(String keyword, Integer areaId) throws SQLException {
        throw Todo.of("like LockerSlotDao.count");
    }

    public LockerBank findById(int bankId) throws SQLException {
        throw Todo.of("one bank by id");
    }

    public int insert(LockerBank b) throws SQLException {
        throw Todo.of("INSERT bank_code, name, area_id, device_id (nullable: use setNull), door_rows, status");
    }

    public boolean update(LockerBank b) throws SQLException {
        throw Todo.of("UPDATE the same columns");
    }

    /** null when deleted, otherwise the reason (a bank with slots cannot be deleted: SQL error 547). */
    public String delete(int bankId) throws SQLException {
        throw Todo.of("DELETE, catch 547 and return a readable reason");
    }

    public boolean codeExists(String bankCode, int exceptBankId) throws SQLException {
        throw Todo.of("SELECT COUNT(*) FROM LockerBank WHERE bank_code = ? AND bank_id <> ?");
    }
}
