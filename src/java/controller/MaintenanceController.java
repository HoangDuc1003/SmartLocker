package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Todo;

/** Maintenance tickets (case 5): list, and close a ticket after the repair. */
@WebServlet(name = "MaintenanceController", urlPatterns = {"/MaintenanceController"})
public class MaintenanceController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/maintenance.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO list tickets with MaintenanceDao.search/count, filter by status
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("MaintenanceController.doPost: action=close&ticketId=&note=: MaintenanceDao.close(ticketId, me.getUserId(), note); the slot becomes AVAILABLE again");
    }
}
