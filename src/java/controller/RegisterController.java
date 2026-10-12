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
import util.Web;

/** Self registration. Every new account is a Locker User (END_USER). */
@WebServlet(name = "RegisterController", urlPatterns = {"/RegisterController"})
public class RegisterController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/register.jsp";
    private static final Pattern USERNAME = Pattern.compile("^[A-Za-z0-9_.]{3,50}$");

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String username = Web.trimmed(req, "username");
        String fullName = Web.trimmed(req, "fullName");
        String password = req.getParameter("password") == null ? "" : req.getParameter("password");
        String confirm = req.getParameter("confirm") == null ? "" : req.getParameter("confirm");

        String error = null;
        if (!USERNAME.matcher(username).matches()) {
            error = "Username must be 3 to 50 characters: letters without accents, digits, _ and .";
        } else if (fullName.length() < 2 || fullName.length() > 80) {
            error = "Full name must be 2 to 80 characters";
        } else if (password.length() < 6) {
            error = "Password must have at least 6 characters";
        } else if (!password.equals(confirm)) {
            error = "Passwords do not match";
        }

        if (error != null) {
            req.setAttribute("error", error);
            req.setAttribute("username", username);
            req.setAttribute("fullName", fullName);
            req.getRequestDispatcher(VIEW).forward(req, res);
            return;
        }

        try {
            int id = new UserDao().register(username, password, fullName);
            new dao.AuditDao().append(id, "REGISTER", "USER", id, null);
            Web.flash(req.getSession(), "Registration successful! You can now sign in.", false);
            res.sendRedirect(req.getContextPath() + "/LoginController");
        } catch (SQLException e) {
            if (e.getErrorCode() == 2627 || e.getErrorCode() == 2601) {
                req.setAttribute("error", "Username " + username + " is already taken");
                req.setAttribute("username", username);
                req.setAttribute("fullName", fullName);
                req.getRequestDispatcher(VIEW).forward(req, res);
            } else {
                throw new ServletException(e);
            }
        }
    }
}
