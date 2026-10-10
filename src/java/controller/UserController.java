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

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: the patterns, the rank rule and the shared validation

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
