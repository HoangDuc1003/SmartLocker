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

    private static final Pattern USERNAME = Pattern.compile("^[A-Za-z0-9_.]{3,50}$");

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // no sign-up page: the map opens the popup on its "Sign up" tab
        res.sendRedirect(Web.signInUrl(req, "register", null));
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String username = Web.trimmed(req, "username");
        String fullName = Web.trimmed(req, "fullName");
        String email = Web.trimmed(req, "email");   // v3: optional, receives the due reminders as typed
        String password = req.getParameter("password") == null ? "" : req.getParameter("password");
        String confirm = req.getParameter("confirm") == null ? "" : req.getParameter("confirm");

        String error = null;
        if (!USERNAME.matcher(username).matches()) {
            error = "The username has 3 to 50 characters: letters without accents, digits, _ and .";
        } else if (fullName.length() < 2 || fullName.length() > 80) {
            error = "The full name must be 2 to 80 characters long";
        } else if (password.length() < 6) {
            error = "The password must have at least 6 characters";
        } else if (!password.equals(confirm)) {
            error = "The passwords do not match";
        } else if (!email.isEmpty() && !Web.isEmail(email)) {
            error = "Invalid e-mail address";
        }

        if (error != null) {
            if (Web.wantsJson(req)) {
                Web.writeJson(res, HttpServletResponse.SC_BAD_REQUEST, error);
                return;
            }
            Web.flash(req.getSession(), error, true);
            res.sendRedirect(Web.signInUrl(req, "register", null));
            return;
        }

        try {
            int id = new UserDao().register(username, password, fullName, email);
            new dao.AuditDao().append(id, "REGISTER", "USER", id, null);
            if (Web.wantsJson(req)) {   // the popup signs the new user in right after
                Web.writeJson(res, HttpServletResponse.SC_OK, null);
                return;
            }
            Web.flash(req.getSession(), "Signed up. You can sign in now.", false);
            res.sendRedirect(Web.signInUrl(req, "login", null));
        } catch (SQLException e) {
            if (e.getErrorCode() == 2627 || e.getErrorCode() == 2601) {
                boolean emailTaken = String.valueOf(e.getMessage()).contains("UX_Users_email");
                String taken = emailTaken ? "This e-mail address is already used by another account"
                        : "Username " + username + " is already taken";
                if (Web.wantsJson(req)) {
                    Web.writeJson(res, HttpServletResponse.SC_CONFLICT, taken);
                    return;
                }
                Web.flash(req.getSession(), taken, true);
                res.sendRedirect(Web.signInUrl(req, "register", null));
            } else {
                throw new ServletException(e);
            }
        }
    }
}
