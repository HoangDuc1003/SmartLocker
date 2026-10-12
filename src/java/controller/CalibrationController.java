package controller;

import dao.AuditDao;
import dao.CalibrationDao;
import dao.DeviceDao;
import java.io.IOException;
import java.sql.Date;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.Calibration;
import model.User;
import util.Csv;
import util.Web;

/** Calibration of sensors; a new version is a new row (case 5). */
@WebServlet(name = "CalibrationController", urlPatterns = {"/CalibrationController"})
public class CalibrationController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/calibration.jsp";
    private static final int PAGE_SIZE = 10;

    private final CalibrationDao dao = new CalibrationDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        Integer deviceId = Web.optionalInt(req, "deviceId");
        int total = dao.count(deviceId);
        int pages = Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

        req.setAttribute("mode", "list");
        req.setAttribute("items", dao.search(deviceId, page, PAGE_SIZE));
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("deviceId", deviceId);
        req.setAttribute("devices", new DeviceDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void showForm(HttpServletRequest req, HttpServletResponse res, Calibration item, boolean isNew)
            throws SQLException, ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.setAttribute("devices", new DeviceDao().listAll());
        req.setAttribute("sensorTypes", dao.sensorTypes());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        Integer deviceId = Web.optionalInt(req, "deviceId");
        List<String[]> rows = new ArrayList<>();
        for (Calibration c : dao.search(deviceId, 1, Math.max(1, dao.count(deviceId)))) {
            rows.add(new String[]{
                String.valueOf(c.getCalibId()),
                c.getDeviceCode(),
                c.getSensorName(),
                String.valueOf(c.getVersion()),
                String.valueOf(c.getOffsetVal()),
                String.valueOf(c.getScaleVal()),
                c.getValidUntil() != null ? c.getValidUntil().toString() : ""
            });
        }
        Csv.send(res, "calibration.csv",
                new String[]{"calib_id", "device", "sensor", "version", "offset", "scale", "valid_until"},
                rows);
    }

    private Calibration readForm(HttpServletRequest req) {
        Calibration c = new Calibration();
        c.setCalibId(Web.intParam(req, "id", 0));
        c.setDeviceId(Web.intParam(req, "deviceId", 0));
        c.setSensorTypeId(Web.intParam(req, "sensorTypeId", 0));
        try {
            c.setOffsetVal(Double.parseDouble(req.getParameter("offsetVal")));
        } catch (Exception ex) {
            c.setOffsetVal(0.0);
        }
        try {
            c.setScaleVal(Double.parseDouble(req.getParameter("scaleVal")));
        } catch (Exception ex) {
            c.setScaleVal(1.0);
        }
        String validStr = Web.trimmed(req, "validUntil");
        if (!validStr.isEmpty()) {
            try {
                c.setValidUntil(Date.valueOf(validStr));
            } catch (Exception ignored) {
            }
        }
        return c;
    }

    private String validate(Calibration c, boolean isNew) {
        if (isNew && c.getDeviceId() <= 0) {
            return "Please select a device";
        }
        if (isNew && c.getSensorTypeId() <= 0) {
            return "Please select a sensor type";
        }
        if (c.getScaleVal() <= 0) {
            return "Scale value must be greater than 0";
        }
        if (c.getValidUntil() == null) {
            return "Valid until date is required (YYYY-MM-DD)";
        }
        return null;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String action = Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                Calibration blank = new Calibration();
                blank.setOffsetVal(0.0);
                blank.setScaleVal(1.0);
                blank.setValidUntil(new Date(System.currentTimeMillis() + 365L * 86400000L));
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                int id = Web.intParam(req, "id", 0);
                Calibration item = dao.findById(id);
                if (item == null) {
                    Web.flash(req.getSession(), "Calibration record not found", true);
                    res.sendRedirect("CalibrationController");
                    return;
                }
                showForm(req, res, item, false);
            } else if ("export".equals(action)) {
                export(req, res);
            } else {
                showList(req, res);
            }
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        try {
            if ("delete".equals(action)) {
                int id = Web.intParam(req, "id", 0);
                Calibration old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    new AuditDao().append(me.getUserId(), "DELETE", "CALIBRATION", id, old.getDeviceCode() + " " + old.getSensorName());
                    Web.flash(req.getSession(), "Calibration record deleted", false);
                } else {
                    Web.flash(req.getSession(), reason == null ? "Nothing was deleted" : reason, true);
                }
                res.sendRedirect("CalibrationController");
                return;
            }

            Calibration c = readForm(req);
            c.setCreatedBy(me.getUserId());
            boolean isNew = "create".equals(action);
            String error = validate(c, isNew);
            if (error != null) {
                req.setAttribute("error", error);
                showForm(req, res, c, isNew);
                return;
            }

            if (isNew) {
                int id = dao.insert(c);
                new AuditDao().append(me.getUserId(), "CREATE", "CALIBRATION", id, "Device #" + c.getDeviceId() + " Sensor #" + c.getSensorTypeId());
                Web.flash(req.getSession(), "Calibration record added successfully", false);
            } else {
                dao.update(c);
                new AuditDao().append(me.getUserId(), "UPDATE", "CALIBRATION", c.getCalibId(), "Calibration #" + c.getCalibId());
                Web.flash(req.getSession(), "Calibration record updated", false);
            }
            res.sendRedirect("CalibrationController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
