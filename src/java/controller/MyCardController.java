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

/** Report lost (case 3). The cards are listed on "Tủ của tôi"; GET of the old page redirects there (spec v2 Q17). */
@WebServlet(name = "MyCardController", urlPatterns = {"/MyCardController"})
public class MyCardController extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        res.sendRedirect(req.getContextPath() + "/MyLockerController");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        if ("reportLost".equals(action)) {
            int cardId = Web.intParam(req, "cardId", 0);
            try {
                new UserCardDao().reportLost(cardId, me.getUserId());
                Web.flash(req.getSession(), "Đã báo mất thẻ và khóa thẻ.", false);
            } catch (SQLException e) {
                if (e.getErrorCode() >= 50000) {
                    Web.flash(req.getSession(), Web.sqlMessage(e), true);
                } else {
                    throw new ServletException(e);
                }
            }
        }
        res.sendRedirect("MyLockerController#cards");
    }
}
