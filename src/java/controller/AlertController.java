package controller;

import dao.AlertDao;
import dao.LockerSessionDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.List;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.Alert;
import model.LockerSession;
import model.User;
import util.Web;

/** Alerts: the list, and the detail of one alert with its evidence and the session behind it. */
@WebServlet(name = "AlertController", urlPatterns = {"/AlertController"})
public class AlertController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/alert.jsp";
    private static final int PAGE_SIZE = 10;

    private final AlertDao dao = new AlertDao();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String idParam = req.getParameter("id");
        try {
            if (idParam != null && !idParam.isEmpty()) {
                int id = Web.intParam(req, "id", 0);
                Alert a = dao.findById(id);
                if (a == null) {
                    Web.flash(req.getSession(), "Alert not found", true);
                    res.sendRedirect("AlertController");
                    return;
                }
                req.setAttribute("mode", "detail");
                req.setAttribute("alert", a);
                if (a.getSessionId() != null) {
                    LockerSession s = new LockerSessionDao().findById(a.getSessionId());
                    req.setAttribute("session", s);
                }
                req.getRequestDispatcher(VIEW).forward(req, res);
                return;
            }

            String status = Web.trimmed(req, "status");
            String label = Web.trimmed(req, "label");
            int total = dao.count(status, label);
            int pages = Web.pages(total, PAGE_SIZE);
            int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

            List<Alert> items = dao.search(status, label, page, PAGE_SIZE);
            req.setAttribute("mode", "list");
            req.setAttribute("items", items);
            req.setAttribute("total", total);
            req.setAttribute("page", page);
            req.setAttribute("pages", pages);
            req.setAttribute("status", status);
            req.setAttribute("label", label);
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        if ("resolve".equals(action)) {
            int id = Web.intParam(req, "id", 0);
            try {
                dao.resolve(id, me.getUserId());
                Web.flash(req.getSession(), "Alert #" + id + " marked as resolved.", false);
            } catch (SQLException e) {
                if (e.getErrorCode() >= 50000) {
                    Web.flash(req.getSession(), e.getMessage(), true);
                } else {
                    throw new ServletException(e);
                }
            }
        }
        res.sendRedirect("AlertController");
    }
}
