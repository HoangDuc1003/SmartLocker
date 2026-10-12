package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import model.StoragePlan;

/** Storage plans: 2 hours, 4 hours, the 2 minute demo plan. Write it like LockerSlotDao. */
public class StoragePlanDao {

    private static StoragePlan map(ResultSet rs) throws SQLException {
        StoragePlan p = new StoragePlan();
        p.setPlanId(rs.getInt("plan_id"));
        p.setPlanName(rs.getString("plan_name"));
        p.setDurationMin(rs.getInt("duration_min"));
        p.setGraceMin(rs.getInt("grace_min"));
        p.setPrice(rs.getInt("price"));
        p.setActive(rs.getBoolean("is_active"));
        return p;
    }

    /** activeOnly = true for the booking form, false for the management page. */
    public List<StoragePlan> listAll(boolean activeOnly) throws SQLException {
        String sql = "SELECT plan_id, plan_name, duration_min, grace_min, price, is_active FROM StoragePlan "
                + (activeOnly ? "WHERE is_active = 1 " : "")
                + "ORDER BY duration_min";
        List<StoragePlan> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(map(rs));
            }
        }
        return list;
    }

    public StoragePlan findById(int planId) throws SQLException {
        String sql = "SELECT plan_id, plan_name, duration_min, grace_min, price, is_active FROM StoragePlan WHERE plan_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, planId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    public int insert(StoragePlan p) throws SQLException {
        String sql = "INSERT INTO StoragePlan (plan_name, duration_min, grace_min, price, is_active) VALUES (?, ?, ?, ?, ?)";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, p.getPlanName());
            ps.setInt(2, p.getDurationMin());
            ps.setInt(3, p.getGraceMin());
            ps.setInt(4, p.getPrice());
            ps.setBoolean(5, p.isActive());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                return keys.next() ? keys.getInt(1) : -1;
            }
        }
    }

    public boolean update(StoragePlan p) throws SQLException {
        String sql = "UPDATE StoragePlan SET plan_name = ?, duration_min = ?, grace_min = ?, price = ?, is_active = ? WHERE plan_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, p.getPlanName());
            ps.setInt(2, p.getDurationMin());
            ps.setInt(3, p.getGraceMin());
            ps.setInt(4, p.getPrice());
            ps.setBoolean(5, p.isActive());
            ps.setInt(6, p.getPlanId());
            return ps.executeUpdate() == 1;
        }
    }

    /** null when deleted, otherwise the reason: a plan used by a booking cannot be deleted (547); deactivate it instead. */
    public String delete(int planId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("DELETE FROM StoragePlan WHERE plan_id = ?")) {
            ps.setInt(1, planId);
            return ps.executeUpdate() == 1 ? null : "Plan not found";
        } catch (SQLException e) {
            if (e.getErrorCode() == 547) {
                return "This plan has deposits/bookings associated with it; set it to inactive instead of deleting";
            }
            throw e;
        }
    }
}
