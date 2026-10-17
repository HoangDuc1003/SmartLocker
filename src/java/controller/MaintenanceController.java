package controller;

import dao.MaintenanceDao;
import java.io.IOException;
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

/** Maintenance tickets (case 5): list, and close a ticket after the repair. */
@WebServlet(name = "MaintenanceController", urlPatterns = {"/MaintenanceController"})
public class MaintenanceController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/maintenance.jsp";
    private static final int PAGE_SIZE = 10;

    private final MaintenanceDao dao = new MaintenanceDao();

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
            req.setAttribute("hlId", Web.intParam(req, "id", 0));   // the row linked from the locker map
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        if ("close".equals(action)) {
            int ticketId = Web.intParam(req, "ticketId", 0);
            String note = Web.trimmed(req, "note");
            try {
                dao.close(ticketId, me.getUserId(), note);
                Web.flash(req.getSession(), "Đã đóng phiếu #" + ticketId + ". Ngăn tủ liên quan trở lại trạng thái AVAILABLE.", false);
            } catch (SQLException e) {
                if (e.getErrorCode() >= 50000) {
                    Web.flash(req.getSession(), Web.sqlMessage(e), true);
                } else {
                    throw new ServletException(e);
                }
            }
        }
        res.sendRedirect("MaintenanceController");
    }
}
