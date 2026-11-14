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
                    Web.flash(req.getSession(), "Alert not found.", true);
                    res.sendRedirect("AlertController");
                    return;
                }
                req.setAttribute("mode", "detail");
                req.setAttribute("alert", a);
                if (a.getSessionId() != null) {
                    LockerSession s = new LockerSessionDao().findById(a.getSessionId());
                    req.setAttribute("session", s);
                }
                if (a.getDeviceId() > 0) {
                    model.Device dev = new dao.DeviceDao().findById(a.getDeviceId());
                    req.setAttribute("device", dev);
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
                    Web.flash(req.getSession(), Web.sqlMessage(e), true);
                } else {
                    throw new ServletException(e);
                }
            }
            res.sendRedirect("AlertController?id=" + id);
            return;
        }

        if ("device_status".equals(action)) {
            int alertId = Web.intParam(req, "alertId", 0);
            int deviceId = Web.intParam(req, "deviceId", 0);
            String status = Web.trimmed(req, "status").toUpperCase();
            try {
                model.Device oldDev = new dao.DeviceDao().findById(deviceId);
                if (oldDev != null && ("ACTIVE".equals(status) || "MAINTENANCE".equals(status) || "OFFLINE".equals(status))) {
                    boolean ok = new dao.DeviceDao().setStatus(deviceId, status);
                    if (ok) {
                        new dao.AuditDao().append(me.getUserId(), "DEVICE_STATUS", "DEVICE", deviceId,
                                oldDev.getDeviceCode() + ": " + oldDev.getStatus() + " -> " + status);
                        String statusLabel = "ACTIVE".equals(status) ? "active" : "MAINTENANCE".equals(status) ? "maintenance" : "offline";
                        Web.flash(req.getSession(), "Box " + oldDev.getDeviceCode() + " set to " + statusLabel + ".", false);
                    } else {
                        Web.flash(req.getSession(), "Could not update the box status.", true);
                    }
                }
            } catch (SQLException e) {
                throw new ServletException(e);
            }
            if (alertId > 0) {
                res.sendRedirect("AlertController?id=" + alertId);
                return;
            }
            res.sendRedirect("AlertController");
            return;
        }

        // This is the short path from the locker map.  It is deliberately
        // limited to ADMIN: only an administrator may manually acknowledge
        // that an offline controller is back online.
        if ("activate_device_from_map".equals(action)) {
            if (!"ADMIN".equals(me.getRoleName())) {
                res.sendError(HttpServletResponse.SC_FORBIDDEN, "Administrator permission required");
                return;
            }
            int deviceId = Web.intParam(req, "deviceId", 0);
            String area = Web.trimmed(req, "area");
            int slot = Web.intParam(req, "slot", 0);
            try {
                model.Device oldDev = new dao.DeviceDao().findById(deviceId);
                if (oldDev == null) {
                    Web.flash(req.getSession(), "The box to update was not found.", true);
                } else if ("ACTIVE".equals(oldDev.getStatus())) {
                    Web.flash(req.getSession(), "Box " + oldDev.getDeviceCode() + " is already online.", false);
                } else if (new dao.DeviceDao().setStatus(deviceId, "ACTIVE")) {
                    new dao.AuditDao().append(me.getUserId(), "DEVICE_STATUS", "DEVICE", deviceId,
                            oldDev.getDeviceCode() + ": " + oldDev.getStatus() + " -> ACTIVE (locker map)");
                    Web.flash(req.getSession(), "Box " + oldDev.getDeviceCode() + " set to online.", false);
                } else {
                    Web.flash(req.getSession(), "Could not update the box status.", true);
                }
            } catch (SQLException e) {
                throw new ServletException(e);
            }
            String target = "LockerMapController";
            if (!area.isEmpty()) {
                target += "?area=" + java.net.URLEncoder.encode(area, "UTF-8");
                if (slot > 0) {
                    target += "&slot=" + slot;
                }
            }
            res.sendRedirect(target);
            return;
        }

        res.sendRedirect("AlertController");
    }
}
