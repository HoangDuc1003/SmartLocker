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
import util.Todo;
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
        throw Todo.of("read username, fullName, password, confirm; validate on the server (username pattern, password 6+ chars, "
                + "both passwords equal); UserDao.register; on SQLException 2627 say the username is taken; flash and redirect to LoginController");
    }
}
