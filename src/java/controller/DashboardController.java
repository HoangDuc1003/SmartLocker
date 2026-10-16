package controller;

import dao.DashboardDao;
import dao.DeviceDao;
import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.Device;

/** Dashboard: numbers, the chart of recent sessions, the devices. */
@WebServlet(name = "DashboardController", urlPatterns = {"/DashboardController"})
public class DashboardController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/dashboard.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        try {
            DashboardDao dashboardDao = new DashboardDao();
            DashboardDao.KpiSnapshot kpis = dashboardDao.fetchKpis();
            req.setAttribute("kpis", kpis);
            Map<String, Integer> counts = dashboardDao.lockerCounts();
            req.setAttribute("counts", counts);

            List<Device> devices = new DeviceDao().listAll();
            req.setAttribute("devices", devices);

            Map<String, Integer> roles = new UserDao().countByRole();
            List<String> roleLabels = new ArrayList<>(roles.keySet());
            List<Integer> roleValues = new ArrayList<>(roles.values());
            req.setAttribute("roleLabels", roleLabels);
            req.setAttribute("roleValues", roleValues);

            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        res.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED);   // this page only reads
    }
}
