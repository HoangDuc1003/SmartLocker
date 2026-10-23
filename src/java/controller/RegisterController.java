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
        String email = Web.trimmed(req, "email");   // v3: optional, receives the due reminders as typed
        String password = req.getParameter("password") == null ? "" : req.getParameter("password");
        String confirm = req.getParameter("confirm") == null ? "" : req.getParameter("confirm");

        String error = null;
        if (!USERNAME.matcher(username).matches()) {
            error = "Tên đăng nhập dài 3 đến 50 ký tự: chữ không dấu, số, _ và .";
        } else if (fullName.length() < 2 || fullName.length() > 80) {
            error = "Họ tên dài từ 2 đến 80 ký tự";
        } else if (password.length() < 6) {
            error = "Mật khẩu có ít nhất 6 ký tự";
        } else if (!password.equals(confirm)) {
            error = "Mật khẩu nhập lại không khớp";
        } else if (!email.isEmpty() && !Web.isEmail(email)) {
            error = "Email không hợp lệ";
        }

        if (error != null) {
            if (Web.wantsJson(req)) {
                Web.writeJson(res, HttpServletResponse.SC_BAD_REQUEST, error);
                return;
            }
            req.setAttribute("error", error);
            req.setAttribute("username", username);
            req.setAttribute("fullName", fullName);
            req.setAttribute("email", email);
            req.getRequestDispatcher(VIEW).forward(req, res);
            return;
        }

        try {
            int id = new UserDao().register(username, password, fullName, email);
            new dao.AuditDao().append(id, "REGISTER", "USER", id, null);
            if (Web.wantsJson(req)) {   // the popup signs the new user in right after
                Web.writeJson(res, HttpServletResponse.SC_OK, null);
                return;
            }
            Web.flash(req.getSession(), "Đăng ký thành công. Bạn có thể đăng nhập.", false);
            res.sendRedirect(req.getContextPath() + "/LoginController");
        } catch (SQLException e) {
            if (e.getErrorCode() == 2627 || e.getErrorCode() == 2601) {
                boolean emailTaken = String.valueOf(e.getMessage()).contains("UX_Users_email");
                String taken = emailTaken ? "Email này đã được một tài khoản khác dùng"
                        : "Tên đăng nhập " + username + " đã được dùng";
                if (Web.wantsJson(req)) {
                    Web.writeJson(res, HttpServletResponse.SC_CONFLICT, taken);
                    return;
                }
                req.setAttribute("error", taken);
                req.setAttribute("username", username);
                req.setAttribute("fullName", fullName);
                req.setAttribute("email", email);
                req.getRequestDispatcher(VIEW).forward(req, res);
            } else {
                throw new ServletException(e);
            }
        }
    }
}
