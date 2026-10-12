package controller;

import dao.AuditDao;
import dao.PermissionDao;
import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Set;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/** Shows the login form and signs the user in. */
@WebServlet(name = "LoginController", urlPatterns = {"/LoginController"})
public class LoginController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/login.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // a signed-in user goes home, everybody else sees the form
        if (Web.currentUser(req) != null) {
            res.sendRedirect(req.getContextPath() + "/LockerMapController");
            return;
        }
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // check the password, refuse a locked account, start the session, audit, redirect by permission
        String username = Web.trimmed(req, "username");
        String password = req.getParameter("password") == null ? "" : req.getParameter("password");
        try {
            User user = new UserDao().checkLogin(username, password);
            String error = null;
            if (user == null) {
                error = "Invalid username or password";
                new AuditDao().append(AuditDao.SYSTEM_USER_ID, "LOGIN_FAIL", "USER", 0, "username=" + username);
            } else if (user.isLocked()) {
                error = "This account is locked, ask a Locker Operator to unlock it";
            } else if (!"ACTIVE".equals(user.getStatus())) {
                error = "This account cannot sign in";
            }
            if (error != null) {
                req.setAttribute("error", error);
                req.setAttribute("username", username);
                req.getRequestDispatcher(VIEW).forward(req, res);
                return;
            }
            req.getSession(true);
            req.changeSessionId();                       // a new session id after login stops session fixation
            req.getSession().setAttribute(Web.LOGIN_USER, user);
            new AuditDao().append(user.getUserId(), "LOGIN", "USER", user.getUserId(), null);

            Set<String> keys = new PermissionDao().loadKeys(user.getUserId());
            String home = keys.contains("ALERT:READ") ? "/DashboardController" : "/LockerMapController";
            res.sendRedirect(req.getContextPath() + home);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
