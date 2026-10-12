package controller;

import dao.RemoteCommandDao;
import java.io.IOException;
import java.net.URLEncoder;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/**
 * Case 2. An operator unlocks a slot from the web. POST comes from the slot panel of the map,
 * GET shows the history of commands: who opened which slot, why, and what became of it.
 */
@WebServlet(name = "RemoteCommandController", urlPatterns = {"/RemoteCommandController"})
public class RemoteCommandController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/remoteCommand.jsp";
    private static final int PAGE_SIZE = 10;

    private final RemoteCommandDao dao = new RemoteCommandDao();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String status = Web.trimmed(req, "status");
        try {
            int total = dao.count(status);
            int pages = Web.pages(total, PAGE_SIZE);
            int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

            List<Map<String, Object>> items = dao.search(status, page, PAGE_SIZE);
            req.setAttribute("items", items);
            req.setAttribute("total", total);
            req.setAttribute("page", page);
            req.setAttribute("pages", pages);
            req.setAttribute("status", status);
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        try {
            long id = dao.create(Web.intParam(req, "slotId", 0), Web.trimmed(req, "reason"), me.getUserId());
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
