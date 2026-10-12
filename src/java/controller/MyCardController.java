package controller;

import dao.UserCardDao;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/** The cards of the signed-in Locker User, and the Report lost button (case 3). */
@WebServlet(name = "MyCardController", urlPatterns = {"/MyCardController"})
public class MyCardController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/myCard.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        try {
            User me = Web.currentUser(req);
            req.setAttribute("items", new UserCardDao().listByUser(me.getUserId()));
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        if ("reportLost".equals(action)) {
            int cardId = Web.intParam(req, "cardId", 0);
            try {
                new UserCardDao().reportLost(cardId, me.getUserId());
                Web.flash(req.getSession(), "Card reported as lost and deactivated.", false);
            } catch (SQLException e) {
                if (e.getErrorCode() >= 50000) {
                    Web.flash(req.getSession(), e.getMessage(), true);
                } else {
                    throw new ServletException(e);
                }
            }
        }
        res.sendRedirect("MyCardController");
    }
}
