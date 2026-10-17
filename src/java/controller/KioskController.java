package controller;

import dao.DeviceAuthDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 * v2, spec 4.5 / 5.4: GET /k/{device_code}, the public phone page behind the QR printed on the box.
 * No login: the page only posts the PIN to /api/kiosk/unlock (js/kiosk.js). An unknown box answers 404 with a short text.
 */
@WebServlet(name = "KioskController", urlPatterns = {"/k/*"})
public class KioskController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/kiosk.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String path = req.getPathInfo();                       // "/LOCKER-01" (a trailing slash is allowed)
        String code = path == null ? "" : path.replaceAll("^/+|/+$", "");
        Map<String, Object> device = null;
        if (code.matches("[A-Za-z0-9_-]{1,40}")) {
            try {
                device = new DeviceAuthDao().findDeviceByCode(code);
            } catch (SQLException e) {
                throw new ServletException(e);
            }
        }
        req.setAttribute("deviceCode", code);
        req.setAttribute("device", device);
        if (device == null) {
            res.setStatus(HttpServletResponse.SC_NOT_FOUND);
        }
        res.setHeader("Cache-Control", "no-store");
        req.getRequestDispatcher(VIEW).forward(req, res);
    }
}
