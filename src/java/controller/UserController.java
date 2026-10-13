package controller;

import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.regex.Pattern;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/**
 * User management. Read UserServlet.java of the UserManagement project first: the rules are the same.
 * GET: list (keyword, role, status, page), form (action=new|edit&id=), export.
 * POST: action = save | lock | unlock | reset | delete.
 */
@WebServlet(name = "UserController", urlPatterns = {"/UserController"})
public class UserController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/user.jsp";
    private static final int PAGE_SIZE = 10;
    private static final String DEFAULT_PASSWORD = "123456";

    private static final Pattern USERNAME = Pattern.compile("^[A-Za-z0-9_.]{3,50}$");
    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final Pattern PHONE = Pattern.compile("^0[0-9]{9}$");

    /** The administrator manages everybody; any other role manages only roles that rank strictly below it. */
    static boolean canManage(User me, User target) {
        return "ADMIN".equals(me.getRoleName()) || target.getRoleRank() > me.getRoleRank();
    }

    /** Server side validation of the add and edit form. Returns the first problem, or null. */
    String validate(User me, User u, int exceptId, int roleRank) throws SQLException {
        UserDao dao = new UserDao();
        if (!USERNAME.matcher(u.getUsername()).matches()) {
            return "Username must be 3 to 50 characters: letters without accents, digits, _ and .";
        }
        if (u.getFullName().length() < 2 || u.getFullName().length() > 80) {
            return "Full name must have 2 to 80 characters";
        }
        if (!EMAIL.matcher(u.getEmail()).matches()) {
            return "Email is required and must look like name@domain";
        }
        if (!u.getPhone().isEmpty() && !PHONE.matcher(u.getPhone()).matches()) {
            return "Phone must be 10 digits and start with 0";
        }
        if (!"ADMIN".equals(me.getRoleName()) && roleRank <= me.getRoleRank()) {
            return "You can only give a role below your own";
        }
        if (dao.usernameExists(u.getUsername(), exceptId)) {
            return "Username " + u.getUsername() + " is already taken";
        }
        if (dao.emailExists(u.getEmail(), exceptId)) {
            return "Email " + u.getEmail() + " is already used";
        }
        return null;
    }

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        String q = Web.trimmed(req, "q");
        String role = Web.trimmed(req, "role");
        String status = Web.trimmed(req, "status");
        UserDao dao = new UserDao();
        int total = dao.count(q, role, status);
        int pages = Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

        java.util.List<User> items = dao.search(q, role, status, page, PAGE_SIZE);
        req.setAttribute("mode", "list");
        req.setAttribute("items", items);
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("q", q);
        req.setAttribute("role", role);
        req.setAttribute("status", status);
        req.setAttribute("roles", new dao.PermissionDao().listRoles());
        req.setAttribute("areas", new dao.LockerAreaDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void showForm(HttpServletRequest req, HttpServletResponse res, User item, boolean isNew)
            throws SQLException, ServletException, IOException {
        User me = Web.currentUser(req);
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        java.util.List<java.util.Map<String, Object>> allRoles = new dao.PermissionDao().listRoles();
        java.util.List<java.util.Map<String, Object>> assignableRoles = new java.util.ArrayList<>();
        for (java.util.Map<String, Object> r : allRoles) {
            int rank = (Integer) r.get("rank_no");
            if ("ADMIN".equals(me.getRoleName()) || rank > me.getRoleRank()) {
                assignableRoles.add(r);
            }
        }
        req.setAttribute("roles", assignableRoles);
        req.setAttribute("areas", new dao.LockerAreaDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        String q = Web.trimmed(req, "q");
        String role = Web.trimmed(req, "role");
        String status = Web.trimmed(req, "status");
        UserDao dao = new UserDao();
        java.util.List<String[]> rows = new java.util.ArrayList<>();
        for (User u : dao.search(q, role, status, 1, Math.max(1, dao.count(q, role, status)))) {
            rows.add(new String[]{String.valueOf(u.getUserId()), u.getUsername(), u.getFullName(),
                u.getEmail(), u.getPhone() == null ? "" : u.getPhone(), u.getRoleName(),
                u.getAreaCode() == null ? "" : u.getAreaCode(), u.getStatus()});
        }
        util.Csv.send(res, "users.csv", new String[]{"user_id", "username", "full_name", "email", "phone", "role", "area", "status"}, rows);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        UserDao dao = new UserDao();
        try {
            if ("new".equals(action)) {
                User blank = new User();
                blank.setStatus("ACTIVE");
                blank.setRoleName("END_USER");
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                int id = Web.intParam(req, "id", 0);
                User item = dao.findById(id);
                if (item == null) {
                    Web.flash(req.getSession(), "User not found", true);
                    res.sendRedirect("UserController");
                    return;
                }
                if (!canManage(me, item) && me.getUserId() != item.getUserId()) {
                    Web.flash(req.getSession(), "You cannot edit users who outrank you", true);
                    res.sendRedirect("UserController");
                    return;
                }
                showForm(req, res, item, false);
            } else if ("export".equals(action)) {
                export(req, res);
            } else {
                showList(req, res);
            }
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        int id = Web.intParam(req, "id", 0);
        UserDao dao = new UserDao();
        dao.AuditDao auditDao = new dao.AuditDao();
        try {
            if ("grantBalance".equals(action)) {
                if (!"ADMIN".equals(me.getRoleName())) {
                    res.sendError(HttpServletResponse.SC_FORBIDDEN, "Only administrators can add funds directly.");
                    return;
                }
                User target = dao.findById(id);
                long amount = Web.longParam(req, "amount", 0);
                if (target == null) {
                    Web.flash(req.getSession(), "User not found", true);
                } else if (amount <= 0) {
                    Web.flash(req.getSession(), "Amount must be greater than 0", true);
                } else {
                    dao.addBalance(id, amount);
                    auditDao.append(me.getUserId(), "GRANT_MONEY", "USER", id, "Granted " + amount + " VND to " + target.getUsername());
                    Web.flash(req.getSession(), "Added " + String.format("%,d", amount) + " VND to "
                            + target.getUsername() + ". New balance: "
                            + String.format("%,d", target.getBalance() + amount) + " VND.", false);
                }
                res.sendRedirect("UserController");
                return;
            }

            if ("lock".equals(action) || "unlock".equals(action)) {
                User target = dao.findById(id);
                if (target == null) {
                    Web.flash(req.getSession(), "User not found", true);
                } else if (target.getUserId() == me.getUserId()) {
                    Web.flash(req.getSession(), "You cannot lock or unlock yourself", true);
                } else if (!canManage(me, target)) {
                    Web.flash(req.getSession(), "You cannot change status of users who outrank you", true);
                } else {
                    String newStatus = "lock".equals(action) ? "LOCKED" : "ACTIVE";
                    dao.setStatus(id, newStatus);
                    auditDao.append(me.getUserId(), "lock".equals(action) ? "LOCK" : "UNLOCK", "USER", id, target.getUsername());
                    Web.flash(req.getSession(), "User " + target.getUsername() + " is now " + newStatus, false);
                }
                res.sendRedirect("UserController");
                return;
            }

            if ("reset".equals(action)) {
                User target = dao.findById(id);
                if (target == null) {
                    Web.flash(req.getSession(), "User not found", true);
                } else if (!canManage(me, target) && target.getUserId() != me.getUserId()) {
                    Web.flash(req.getSession(), "You cannot reset password of users who outrank you", true);
                } else {
                    dao.resetPassword(id, DEFAULT_PASSWORD);
                    auditDao.append(me.getUserId(), "RESET_PW", "USER", id, target.getUsername());
                    Web.flash(req.getSession(), "Password for " + target.getUsername() + " reset to " + DEFAULT_PASSWORD, false);
                }
                res.sendRedirect("UserController");
                return;
            }

            if ("delete".equals(action)) {
                User target = dao.findById(id);
                if (target == null) {
                    Web.flash(req.getSession(), "User not found", true);
                } else if (target.getUserId() == me.getUserId()) {
                    Web.flash(req.getSession(), "You cannot delete yourself", true);
                } else if (!canManage(me, target)) {
                    Web.flash(req.getSession(), "You cannot delete users who outrank you", true);
                } else {
                    String reason = dao.delete(id);
                    if (reason == null) {
                        auditDao.append(me.getUserId(), "DELETE", "USER", id, target.getUsername());
                        Web.flash(req.getSession(), "User " + target.getUsername() + " deleted", false);
                    } else {
                        Web.flash(req.getSession(), reason, true);
                    }
                }
                res.sendRedirect("UserController");
                return;
            }

            // Save (Create or Update)
            User u = new User();
            u.setUserId(id);
            u.setUsername(Web.trimmed(req, "username"));
            u.setFullName(Web.trimmed(req, "fullName"));
            u.setEmail(Web.trimmed(req, "email"));
            u.setPhone(Web.trimmed(req, "phone"));
            u.setRoleName(Web.trimmed(req, "roleName"));
            u.setAreaId(Web.optionalInt(req, "areaId"));
            u.setStatus(Web.trimmed(req, "status"));
            if (u.getStatus().isEmpty()) {
                u.setStatus("ACTIVE");
            }

            int roleRank = new dao.PermissionDao().roleRank(u.getRoleName());
            String error = validate(me, u, id, roleRank);
            if (error != null) {
                req.setAttribute("error", error);
                showForm(req, res, u, id == 0);
                return;
            }

            if (id == 0) {
                int newId = dao.insert(u, DEFAULT_PASSWORD);
                auditDao.append(me.getUserId(), "CREATE", "USER", newId, u.getUsername());
                Web.flash(req.getSession(), "User " + u.getUsername() + " created with default password " + DEFAULT_PASSWORD, false);
            } else {
                User target = dao.findById(id);
                if (target == null || (!canManage(me, target) && target.getUserId() != me.getUserId())) {
                    Web.flash(req.getSession(), "You cannot edit users who outrank you", true);
                    res.sendRedirect("UserController");
                    return;
                }
                if (target.getUserId() == me.getUserId() && !target.getRoleName().equals(u.getRoleName())) {
                    u.setRoleName(target.getRoleName());
                }
                dao.update(u);
                auditDao.append(me.getUserId(), "UPDATE", "USER", id, u.getUsername());
                Web.flash(req.getSession(), "User " + u.getUsername() + " updated", false);
            }
            res.sendRedirect("UserController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
