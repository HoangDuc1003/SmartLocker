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
import util.Todo;

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

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO list with UserDao.search/count, the form for new and edit, the CSV export; then forward to VIEW
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("UserController.doPost: save (validate, insert or update), lock, unlock, reset, delete; every action "
                + "checks canManage(me, target) again on the server, audits, flashes and redirects");
    }
}
