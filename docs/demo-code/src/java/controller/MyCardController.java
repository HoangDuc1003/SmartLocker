package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Todo;

/** The cards of the signed-in Locker User, and the Report lost button (case 3). */
@WebServlet(name = "MyCardController", urlPatterns = {"/MyCardController"})
public class MyCardController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/myCard.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO UserCardDao.listByUser(me.getUserId()) into items, then forward
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("MyCardController.doPost: action=reportLost&cardId=: UserCardDao.reportLost(cardId, me.getUserId()); the procedure refuses a card that is not yours; flash and redirect");
    }
}
