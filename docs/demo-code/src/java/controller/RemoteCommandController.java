package controller;

import dao.RemoteCommandDao;
import java.io.IOException;
import java.net.URLEncoder;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Todo;
import util.Web;

/**
 * Case 2. An operator unlocks a slot from the web. POST comes from the slot panel of the map,
 * GET shows the history of commands: who opened which slot, why, and what became of it.
 */
@WebServlet(name = "RemoteCommandController", urlPatterns = {"/RemoteCommandController"})
public class RemoteCommandController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/remoteCommand.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO page the history with RemoteCommandDao.search/count, filter by status, then forward
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // create the command; the procedure refuses an offline device, a missing reason, a busy device
        User me = Web.currentUser(req);
        try {
            long id = new RemoteCommandDao().create(Web.intParam(req, "slotId", 0), Web.trimmed(req, "reason"), me.getUserId());
            Web.flash(req.getSession(), "Command #" + id + " queued, the slot opens within 10 seconds.", false);
        } catch (SQLException e) {
            if (e.getErrorCode() >= 50000) {
                Web.flash(req.getSession(), e.getMessage(), true);
            } else {
                throw new ServletException(e);
            }
        }
        res.sendRedirect("LockerMapController?area=" + URLEncoder.encode(Web.trimmed(req, "area"), "UTF-8")
                + "&slot=" + Web.intParam(req, "slot", 0));
    }
}
