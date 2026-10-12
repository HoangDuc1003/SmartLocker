package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Roles and permissions: who may READ or WRITE which resource. */
public class PermissionDao {

    /** Every permission of a user as "RESOURCE:ACTION" strings, for example "USER:READ". */
    public Set<String> loadKeys(int userId) throws SQLException {
        // one query over UserRole, RolePerm and Permissions
        String sql = "SELECT p.resource, p.action FROM UserRole ur "
                + "JOIN RolePerm rp ON rp.role_id = ur.role_id "
                + "JOIN Permissions p ON p.perm_id = rp.perm_id WHERE ur.user_id = ?";
        Set<String> keys = new HashSet<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    keys.add(rs.getString(1) + ":" + rs.getString(2));
                }
            }
        }
        return keys;
    }

    /** One row per role: role_id, role_name, rank_no, user_count, perm_count. */
    public List<Map<String, Object>> listRoles() throws SQLException {
        String sql = "SELECT r.role_id, r.role_name, r.rank_no, "
                + "(SELECT COUNT(*) FROM UserRole ur WHERE ur.role_id = r.role_id) AS user_count, "
                + "(SELECT COUNT(*) FROM RolePerm rp WHERE rp.role_id = r.role_id) AS perm_count "
                + "FROM Roles r ORDER BY r.rank_no";
        java.util.List<Map<String, Object>> list = new java.util.ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> map = new java.util.HashMap<>();
                map.put("role_id", rs.getInt("role_id"));
                map.put("role_name", rs.getString("role_name"));
                map.put("rank_no", rs.getInt("rank_no"));
                map.put("user_count", rs.getInt("user_count"));
                map.put("perm_count", rs.getInt("perm_count"));
                list.add(map);
            }
        }
        return list;
    }

    /** Every permission with a flag telling if the role has it: {perm_id, resource, action, granted}. */
    public List<String[]> permissionGrid(int roleId) throws SQLException {
        String sql = "SELECT p.perm_id, p.resource, p.action, "
                + "CASE WHEN rp.role_id IS NOT NULL THEN 1 ELSE 0 END AS granted "
                + "FROM Permissions p "
                + "LEFT JOIN RolePerm rp ON rp.perm_id = p.perm_id AND rp.role_id = ? "
                + "ORDER BY p.resource, p.action";
        java.util.List<String[]> list = new java.util.ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, roleId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(new String[]{
                        String.valueOf(rs.getInt("perm_id")),
                        rs.getString("resource"),
                        rs.getString("action"),
                        String.valueOf(rs.getInt("granted"))
                    });
                }
            }
        }
        return list;
    }

    /** Replaces the permissions of a role. One transaction: DELETE the old rows, INSERT the ticked ones. */
    public void saveRolePerms(int roleId, int[] permIds) throws SQLException {
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                try (PreparedStatement ps = conn.prepareStatement("DELETE FROM RolePerm WHERE role_id = ?")) {
                    ps.setInt(1, roleId);
                    ps.executeUpdate();
                }
                if (permIds != null && permIds.length > 0) {
                    try (PreparedStatement ps = conn.prepareStatement("INSERT INTO RolePerm (role_id, perm_id) VALUES (?, ?)")) {
                        for (int pid : permIds) {
                            ps.setInt(1, roleId);
                            ps.setInt(2, pid);
                            ps.addBatch();
                        }
                        ps.executeBatch();
                    }
                }
                conn.commit();
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    public String roleName(int roleId) throws SQLException {
        String sql = "SELECT role_name FROM Roles WHERE role_id = ?";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, roleId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) : null;
            }
        }
    }

    public int roleRank(String roleName) throws SQLException {
        String sql = "SELECT rank_no FROM Roles WHERE role_name = ?";
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, roleName);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 999;
            }
        }
    }
}
