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

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: columns that every user query returns, and the row mapper

    /** The user when the password matches, whatever the status; null otherwise. The controller checks the status. */
    public User checkLogin(String username, String password) throws SQLException {
        throw Todo.of("UserDao.checkLogin: select by username (parameter), then SecurityUtils.checkPassword on the stored hash");
    }

    /** Self registration: a new END_USER. Returns the new user_id; username taken = SQLException 2627. */
    public int register(String username, String password, String fullName) throws SQLException {
        throw Todo.of("UserDao.register: one transaction: INSERT Users, then INSERT UserRole for END_USER");
    }

    public User findById(int userId) throws SQLException {
        throw Todo.of("find one user by id: same query as checkLogin without the password, WHERE u.user_id = ?");
    }

    public User findByUsername(String username) throws SQLException {
        throw Todo.of("find one user by username (used by the register page to explain a clash)");
    }

    /** One page of users. page starts at 1. */
    public List<User> search(String keyword, String role, String status, int page, int size) throws SQLException {
        throw Todo.of("UserDao.search: dynamic WHERE with ? parameters, ORDER BY ... OFFSET ? ROWS FETCH NEXT ? ROWS ONLY");
    }

    public int count(String keyword, String role, String status) throws SQLException {
        throw Todo.of("UserDao.count: the same WHERE, SELECT COUNT(*)");
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
        throw Todo.of("UserDao.usernameExists: SELECT COUNT(*) FROM Users WHERE username = ? AND user_id <> ?");
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
