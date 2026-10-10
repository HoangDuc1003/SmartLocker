package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/** The audit log and the integrity check of its hash chain. */
@WebServlet(name = "AuditController", urlPatterns = {"/AuditController"})
public class AuditController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/audit.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO list with AuditDao.search/count (filter by action); action=verify calls AuditVerifier.findFirstBroken() and shows the result
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        res.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED);   // this page only reads
    }
}
