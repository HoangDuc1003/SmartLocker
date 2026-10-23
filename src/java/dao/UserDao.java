package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import model.User;
import util.SecurityUtils;

/** Every SQL statement about users and their role. One role per user is assumed. */
public class UserDao {

    private static final String COLUMNS = "u.user_id, u.username, u.full_name, u.status, u.email, u.phone, "
            + "u.area_id, a.area_code, r.role_name, r.rank_no, u.balance";
    private static final String FROM = " FROM Users u "
            + "LEFT JOIN LockerArea a ON a.area_id = u.area_id "
            + "JOIN UserRole ur ON ur.user_id = u.user_id "
            + "JOIN Roles r ON r.role_id = ur.role_id ";

    private static User map(ResultSet rs) throws SQLException {
        User u = new User();
        u.setUserId(rs.getInt("user_id"));
        u.setUsername(rs.getString("username"));
        u.setFullName(rs.getString("full_name"));
        u.setStatus(rs.getString("status"));
        u.setEmail(rs.getString("email"));
        u.setPhone(rs.getString("phone"));
        int areaId = rs.getInt("area_id");
        u.setAreaId(rs.wasNull() ? null : areaId);
        u.setAreaCode(rs.getString("area_code"));
        u.setRoleName(rs.getString("role_name"));
        u.setRoleRank(rs.getInt("rank_no"));
        u.setBalance(rs.getLong("balance"));
        return u;
    }

    /** WHERE clause shared by search() and count(); the values go into params, never into the text. */
    private static String where(String keyword, String role, String status, List<Object> params) {
        StringBuilder sb = new StringBuilder(" WHERE u.username <> N'system'");
        if (keyword != null && !keyword.isEmpty()) {
            sb.append(" AND (u.username LIKE ? OR u.full_name LIKE ? OR u.email LIKE ?)");
            String like = "%" + keyword + "%";
            params.add(like);
            params.add(like);
            params.add(like);
        }
        if (role != null && !role.isEmpty()) {
            sb.append(" AND r.role_name = ?");
            params.add(role);
        }
        if (status != null && !status.isEmpty()) {
            sb.append(" AND u.status = ?");
            params.add(status);
        }
        return sb.toString();
    }

    /** The user when the password matches, whatever the status; null otherwise. The controller checks the status. */
    public User checkLogin(String username, String password) throws SQLException {
        // select by username (parameter), then SecurityUtils.checkPassword on the stored hash
        String sql = "SELECT " + COLUMNS + ", u.password_hash" + FROM + "WHERE u.username = ? ORDER BY r.rank_no";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, username);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next() && SecurityUtils.checkPassword(password, rs.getString("password_hash"))) {
                    return map(rs);   // the hash is not copied into the User
                }
            }
        }
        return null;
    }

    /** v3: with the optional e-mail that receives the due reminders; an e-mail in use = 2601 on UX_Users_email. */
    public int register(String username, String password, String fullName, String email) throws SQLException {
        // one transaction: INSERT Users, then INSERT UserRole for END_USER
        String insertUser = "INSERT INTO Users (username, password_hash, full_name, email) VALUES (?, ?, ?, ?)";
        String insertRole = "INSERT INTO UserRole (user_id, role_id) SELECT ?, role_id FROM Roles WHERE role_name = N'END_USER'";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int id;
                try (PreparedStatement ps = conn.prepareStatement(insertUser, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setString(1, username);
                    ps.setString(2, SecurityUtils.hashPassword(password));
                    ps.setString(3, fullName);
                    ps.setString(4, email == null || email.isEmpty() ? null : email);
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        keys.next();
                        id = keys.getInt(1);
                    }
                }
                try (PreparedStatement ps = conn.prepareStatement(insertRole)) {
                    ps.setInt(1, id);
                    ps.executeUpdate();
                }
                conn.commit();
                return id;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    /** v3: the user's own e-mail for the due reminders, saved as typed; empty removes it. 2601 when another account has it. */
    public void setEmail(int userId, String email) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("UPDATE Users SET email = ? WHERE user_id = ?")) {
            ps.setString(1, email == null || email.isEmpty() ? null : email);
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

    /** v3: the e-mail of a user, or null. */
    public String getEmail(int userId) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT email FROM Users WHERE user_id = ?")) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) : null;
            }
        }
    }

    public User findById(int userId) throws SQLException {
        String sql = "SELECT " + COLUMNS + FROM + "WHERE u.user_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /** One page of users. page starts at 1. */
    public List<User> search(String keyword, String role, String status, int page, int size) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT " + COLUMNS + FROM + where(keyword, role, status, params)
                + " ORDER BY u.user_id OFFSET ? ROWS FETCH NEXT ? ROWS ONLY";
        params.add((page - 1) * size);
        params.add(size);
        List<User> items = new ArrayList<>();
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

    public int count(String keyword, String role, String status) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*)" + FROM + where(keyword, role, status, params);
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /** Creates an account with the default password, role from u.getRoleName(). Returns the new id. */
    public int insert(User u, String plainPassword) throws SQLException {
        String insertUser = "INSERT INTO Users (username, password_hash, full_name, email, phone, area_id, status) VALUES (?, ?, ?, ?, ?, ?, ?)";
        String insertRole = "INSERT INTO UserRole (user_id, role_id) SELECT ?, role_id FROM Roles WHERE role_name = ?";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int id;
                try (PreparedStatement ps = conn.prepareStatement(insertUser, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setString(1, u.getUsername());
                    ps.setString(2, SecurityUtils.hashPassword(plainPassword));
                    ps.setString(3, u.getFullName());
                    ps.setString(4, u.getEmail());
                    ps.setString(5, u.getPhone() == null || u.getPhone().isEmpty() ? null : u.getPhone());
                    if (u.getAreaId() != null && u.getAreaId() > 0) {
                        ps.setInt(6, u.getAreaId());
                    } else {
                        ps.setNull(6, java.sql.Types.INTEGER);
                    }
                    ps.setString(7, u.getStatus() == null ? "ACTIVE" : u.getStatus());
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        keys.next();
                        id = keys.getInt(1);
                    }
                }
                try (PreparedStatement ps = conn.prepareStatement(insertRole)) {
                    ps.setInt(1, id);
                    ps.setString(2, u.getRoleName());
                    ps.executeUpdate();
                }
                conn.commit();
                return id;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    public boolean update(User u) throws SQLException {
        String updateUser = "UPDATE Users SET full_name = ?, email = ?, phone = ?, area_id = ?, status = ? WHERE user_id = ?";
        String deleteRole = "DELETE FROM UserRole WHERE user_id = ?";
        String insertRole = "INSERT INTO UserRole (user_id, role_id) SELECT ?, role_id FROM Roles WHERE role_name = ?";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                try (PreparedStatement ps = conn.prepareStatement(updateUser)) {
                    ps.setString(1, u.getFullName());
                    ps.setString(2, u.getEmail());
                    ps.setString(3, u.getPhone() == null || u.getPhone().isEmpty() ? null : u.getPhone());
                    if (u.getAreaId() != null && u.getAreaId() > 0) {
                        ps.setInt(4, u.getAreaId());
                    } else {
                        ps.setNull(4, java.sql.Types.INTEGER);
                    }
                    ps.setString(5, u.getStatus());
                    ps.setInt(6, u.getUserId());
                    ps.executeUpdate();
                }
                if (u.getRoleName() != null && !u.getRoleName().isEmpty()) {
                    try (PreparedStatement ps = conn.prepareStatement(deleteRole)) {
                        ps.setInt(1, u.getUserId());
                        ps.executeUpdate();
                    }
                    try (PreparedStatement ps = conn.prepareStatement(insertRole)) {
                        ps.setInt(1, u.getUserId());
                        ps.setString(2, u.getRoleName());
                        ps.executeUpdate();
                    }
                }
                conn.commit();
                return true;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    public boolean setStatus(int userId, String status) throws SQLException {
        String sql = "UPDATE Users SET status = ? WHERE user_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setInt(2, userId);
            return ps.executeUpdate() == 1;
        }
    }

    public boolean resetPassword(int userId, String plainPassword) throws SQLException {
        String sql = "UPDATE Users SET password_hash = ? WHERE user_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, SecurityUtils.hashPassword(plainPassword));
            ps.setInt(2, userId);
            return ps.executeUpdate() == 1;
        }
    }

    /** null when deleted, otherwise the reason it cannot be deleted (a foreign key, SQL error 547). */
    public String delete(int userId) throws SQLException {
        String delRole = "DELETE FROM UserRole WHERE user_id = ?";
        String delUser = "DELETE FROM Users WHERE user_id = ?";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                try (PreparedStatement ps = conn.prepareStatement(delRole)) {
                    ps.setInt(1, userId);
                    ps.executeUpdate();
                }
                try (PreparedStatement ps = conn.prepareStatement(delUser)) {
                    ps.setInt(1, userId);
                    int n = ps.executeUpdate();
                    conn.commit();
                    return n == 1 ? null : "Không tìm thấy người dùng";
                }
            } catch (SQLException e) {
                conn.rollback();
                if (e.getErrorCode() == 547) {
                    return "Người dùng đã có dữ liệu liên quan (thẻ, lượt gửi, nhật ký), hãy chuyển sang DISABLED hoặc LOCKED thay vì xóa";
                }
                throw e;
            }
        }
    }

    /** exceptUserId = 0 when creating. */
    public boolean usernameExists(String username, int exceptUserId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM Users WHERE username = ? AND user_id <> ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, username);
            ps.setInt(2, exceptUserId);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getInt(1) > 0;
            }
        }
    }

    public boolean emailExists(String email, int exceptUserId) throws SQLException {
        if (email == null || email.trim().isEmpty()) {
            return false;
        }
        String sql = "SELECT COUNT(*) FROM Users WHERE email = ? AND user_id <> ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email.trim());
            ps.setInt(2, exceptUserId);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getInt(1) > 0;
            }
        }
    }

    /** role name to number of users, for the dashboard chart. */
    public Map<String, Integer> countByRole() throws SQLException {
        String sql = "SELECT r.role_name, COUNT(ur.user_id) AS cnt "
                + "FROM Roles r LEFT JOIN UserRole ur ON ur.role_id = r.role_id "
                + "GROUP BY r.role_name, r.rank_no ORDER BY r.rank_no";
        Map<String, Integer> map = new LinkedHashMap<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                map.put(rs.getString("role_name"), rs.getInt("cnt"));
            }
        }
        return map;
    }

    public long getBalance(int userId) throws SQLException {
        String sql = "SELECT balance FROM Users WHERE user_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0L;
            }
        }
    }

    public void addBalance(int userId, long amount) throws SQLException {
        String sql = "UPDATE Users SET balance = balance + ? WHERE user_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, amount);
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

    public void setBalance(int userId, long balance) throws SQLException {
        String sql = "UPDATE Users SET balance = ? WHERE user_id = ?";
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, balance);
            ps.setInt(2, userId);
            ps.executeUpdate();
        }
    }

}
