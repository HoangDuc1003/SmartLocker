package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import model.LockerSlot;

/**
 * The model of every CRUD dao in this project: search with paging, count, find one, insert, update, delete.
 * Read this class first, then write StoragePlanDao, LockerBankDao ... the same way.
 */
public class LockerSlotDao {

    private static final String SELECT = "SELECT s.locker_slot_id, s.slot_code, s.bank_id, b.bank_code, "
            + "s.size_cm, s.size_code, s.status FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id";

    private static LockerSlot map(ResultSet rs) throws SQLException {
        LockerSlot s = new LockerSlot();
        s.setSlotId(rs.getInt("locker_slot_id"));
        s.setSlotCode(rs.getString("slot_code"));
        s.setBankId(rs.getInt("bank_id"));
        s.setBankCode(rs.getString("bank_code"));
        s.setSizeCm(rs.getString("size_cm"));
        s.setSizeCode(rs.getString("size_code"));
        s.setStatus(rs.getString("status"));
        return s;
    }

    /** Builds the WHERE text with ? marks only; the values go into params in the same order. */
    private static String where(String keyword, Integer bankId, String status, List<Object> params) {
        StringBuilder sb = new StringBuilder(" WHERE 1 = 1");
        if (keyword != null && !keyword.isEmpty()) {
            sb.append(" AND s.slot_code LIKE ?");
            params.add("%" + keyword + "%");
        }
        if (bankId != null) {
            sb.append(" AND s.bank_id = ?");
            params.add(bankId);
        }
        if (status != null && !status.isEmpty()) {
            sb.append(" AND s.status = ?");
            params.add(status);
        }
        return sb.toString();
    }

    private static void bind(PreparedStatement ps, List<Object> params) throws SQLException {
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
    }

    /** One page, page starts at 1. The ORDER BY is required by OFFSET ... FETCH. */
    public List<LockerSlot> search(String keyword, Integer bankId, String status, int page, int size) throws SQLException {
        // server side paging: only the rows of the page leave the database
        List<Object> params = new ArrayList<>();
        String sql = SELECT + where(keyword, bankId, status, params)
                + " ORDER BY b.bank_code, s.slot_code OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        params.add((page - 1) * size);
        params.add(size);
        List<LockerSlot> items = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    items.add(map(rs));
                }
            }
        }
        return items;
    }

    public int count(String keyword, Integer bankId, String status) throws SQLException {
        // the same WHERE, so the page count matches the rows
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM LockerSlot s" + where(keyword, bankId, status, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /** null when there is no such slot. */
    public LockerSlot findById(int slotId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(SELECT + " WHERE s.locker_slot_id = ?")) {
            ps.setInt(1, slotId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /** Returns the new id. */
    public int insert(LockerSlot s) throws SQLException {
        // INSERT ... with RETURN_GENERATED_KEYS
        String sql = "INSERT INTO LockerSlot (slot_code, bank_id, size_cm, size_code, status) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, s.getSlotCode());
            ps.setInt(2, s.getBankId());
            ps.setString(3, s.getSizeCm());
            ps.setString(4, s.getSizeCode());
            ps.setString(5, s.getStatus());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        }
    }

    public boolean update(LockerSlot s) throws SQLException {
        // UPDATE ... WHERE locker_slot_id = ?, true when one row changed
        String sql = "UPDATE LockerSlot SET slot_code = ?, bank_id = ?, size_cm = ?, size_code = ?, status = ? "
                + "WHERE locker_slot_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, s.getSlotCode());
            ps.setInt(2, s.getBankId());
            ps.setString(3, s.getSizeCm());
            ps.setString(4, s.getSizeCode());
            ps.setString(5, s.getStatus());
            ps.setInt(6, s.getSlotId());
            return ps.executeUpdate() == 1;
        }
    }

    /** null when deleted, otherwise the reason it could not be deleted, shown to the user as it is. */
    public String delete(int slotId) throws SQLException {
        // catch SQL error 547 (foreign key) and return a readable reason instead of failing
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM LockerSlot WHERE locker_slot_id = ?")) {
            ps.setInt(1, slotId);
            return ps.executeUpdate() == 1 ? null : "This slot no longer exists";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "This slot has bookings or sessions, set it to MAINTENANCE instead";
            }
            throw e;
        }
    }

    /** exceptSlotId = 0 when creating. */
    public boolean codeExists(int bankId, String slotCode, int exceptSlotId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM LockerSlot WHERE bank_id = ? AND slot_code = ? AND locker_slot_id <> ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, bankId);
            ps.setString(2, slotCode);
            ps.setInt(3, exceptSlotId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) > 0;
            }
        }
    }
}
