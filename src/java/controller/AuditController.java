package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Web;

/** The audit log and the integrity check of its hash chain. */
@WebServlet(name = "AuditController", urlPatterns = {"/AuditController"})
public class AuditController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/audit.jsp";

    private static final int PAGE_SIZE = 15;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String actionParam = Web.trimmed(req, "action");
        String actFilter = Web.trimmed(req, "act");
        dao.AuditDao dao = new dao.AuditDao();
        try {
            if ("verify".equals(actionParam)) {
                long broken = service.AuditVerifier.findFirstBroken();
                if (broken == -1L) {
                    req.setAttribute("integrity", "The hash chain is intact. No records have been tampered with.");
                    req.setAttribute("integrityStatus", "ok");
                } else {
                    req.setAttribute("integrity", "Hash chain broken at row #" + broken + "! Tampering detected.");
                    req.setAttribute("integrityStatus", "bad");
                }
            }

            int total = dao.count(actFilter);
            int pages = Web.pages(total, PAGE_SIZE);
            int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

            java.util.List<java.util.Map<String, Object>> items = dao.search(actFilter, page, PAGE_SIZE);
            req.setAttribute("items", items);
            req.setAttribute("total", total);
            req.setAttribute("page", page);
            req.setAttribute("pages", pages);
            req.setAttribute("action", actFilter);
            req.setAttribute("actions", dao.actions());

            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (Exception e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        res.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED);   // this page only reads
    }
}
