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
import util.Todo;

/** Every SQL statement about users and their role. One role per user is assumed. */
public class UserDao {

    private static final String COLUMNS = "u.user_id, u.username, u.full_name, u.status, u.email, u.phone, "
            + "u.area_id, a.area_code, r.role_name, r.rank_no";
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

    /** Self registration: a new END_USER. Returns the new user_id; username taken = SQLException 2627. */
    public int register(String username, String password, String fullName) throws SQLException {
        // one transaction: INSERT Users, then INSERT UserRole for END_USER
        String insertUser = "INSERT INTO Users (username, password_hash, full_name) VALUES (?, ?, ?)";
        String insertRole = "INSERT INTO UserRole (user_id, role_id) SELECT ?, role_id FROM Roles WHERE role_name = N'END_USER'";
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int id;
                try (PreparedStatement ps = conn.prepareStatement(insertUser, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setString(1, username);
                    ps.setString(2, SecurityUtils.hashPassword(password));
                    ps.setString(3, fullName);
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

    public User findById(int userId) throws SQLException {
        throw Todo.of("find one user by id: same query as checkLogin without the password, WHERE u.user_id = ?");
    }

    public User findByUsername(String username) throws SQLException {
        throw Todo.of("find one user by username (used by the register page to explain a clash)");
    }

    /** One page of users. page starts at 1. */
    public List<User> search(String keyword, String role, String status, int page, int size) throws SQLException {
        // dynamic WHERE with ? parameters, ORDER BY ... OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
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
        // the same WHERE, SELECT COUNT(*)
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
        throw Todo.of("INSERT Users (hash from SecurityUtils.hashPassword) and UserRole in one transaction, like register()");
    }

    public boolean update(User u) throws SQLException {
        throw Todo.of("UPDATE full_name, email, phone, area_id, status and replace the UserRole row, in one transaction");
    }

    public boolean setStatus(int userId, String status) throws SQLException {
        throw Todo.of("UPDATE Users SET status = ? (ACTIVE or LOCKED); return true when one row changed");
    }

    public boolean resetPassword(int userId, String plainPassword) throws SQLException {
        throw Todo.of("UPDATE password_hash with a new BCrypt hash");
    }

    /** null when deleted, otherwise the reason it cannot be deleted (a foreign key, SQL error 547). */
    public String delete(int userId) throws SQLException {
        throw Todo.of("DELETE UserRole then Users in one transaction; catch error 547 and return a readable reason");
    }

    /** exceptUserId = 0 when creating. */
    public boolean usernameExists(String username, int exceptUserId) throws SQLException {
        // SELECT COUNT(*) FROM Users WHERE username = ? AND user_id <> ?
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
        throw Todo.of("same as usernameExists for the email column");
    }

    /** role name to number of users, for the dashboard chart. */
    public Map<String, Integer> countByRole() throws SQLException {
        throw Todo.of("SELECT role_name, COUNT(*) ... GROUP BY role_name ORDER BY rank_no into a LinkedHashMap");
    }

    public int countByStatus(String status) throws SQLException {
        throw Todo.of("SELECT COUNT(*) FROM Users WHERE status = ?");
    }
}
