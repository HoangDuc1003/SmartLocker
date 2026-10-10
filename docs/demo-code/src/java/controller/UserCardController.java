package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Todo;

/** Cards for the operator: issue, block, replace a lost card (case 3). */
@WebServlet(name = "UserCardController", urlPatterns = {"/UserCardController"})
public class UserCardController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/userCard.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO list cards with search/count, filter by status; action=new shows the issue form
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("UserCardController.doPost: action=issue|block|unblock|replace: replace calls UserCardDao.replace and flashes the procedure message");
    }
}
