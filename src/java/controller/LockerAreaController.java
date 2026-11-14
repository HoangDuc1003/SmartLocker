package controller;

import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/** Areas: Library, Dormitory ... Add, view, edit, delete. */
@WebServlet(name = "LockerAreaController", urlPatterns = {"/LockerAreaController"})
public class LockerAreaController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/lockerArea.jsp";

    private static final int PAGE_SIZE = 10;
    private static final java.util.regex.Pattern AREA_CODE = java.util.regex.Pattern.compile("^[A-Za-z0-9]{2,16}$");

    private final dao.LockerAreaDao dao = new dao.LockerAreaDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        String q = util.Web.trimmed(req, "q");
        int total = dao.count(q);
        int pages = util.Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, util.Web.intParam(req, "page", 1)), pages);

        req.setAttribute("mode", "list");
        req.setAttribute("items", dao.search(q, page, PAGE_SIZE));
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("q", q);
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void showForm(HttpServletRequest req, HttpServletResponse res, model.LockerArea item, boolean isNew)
            throws ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        String q = util.Web.trimmed(req, "q");
        java.util.List<String[]> rows = new java.util.ArrayList<>();
        for (model.LockerArea a : dao.search(q, 1, Math.max(1, dao.count(q)))) {
            rows.add(new String[]{String.valueOf(a.getAreaId()), a.getAreaCode(), a.getName(),
                a.getLocation(), String.valueOf(a.getSlotCount()), String.valueOf(a.getUserCount()),
                a.isActive() ? "ACTIVE" : "INACTIVE"});
        }
        util.Csv.send(res, "areas.csv", new String[]{"area_id", "area_code", "name", "location", "slots", "users", "status"}, rows);
    }

    /** Empty means "not placed on the map"; a comma is accepted as the decimal mark. */
    private static Double parseCoord(String text) {
        if (text.isEmpty()) {
            return null;
        }
        double v = Double.parseDouble(text.replace(',', '.'));
        if (Double.isNaN(v) || Double.isInfinite(v)) {
            throw new NumberFormatException(text);
        }
        return v;
    }

    private String validate(model.LockerArea a) throws SQLException {
        if ((a.getLatitude() == null) != (a.getLongitude() == null)) {
            return "Enter both latitude and longitude, or leave both empty";
        }
        if (a.getLatitude() != null && (a.getLatitude() < -90 || a.getLatitude() > 90)) {
            return "The latitude must be between -90 and 90";
        }
        if (a.getLongitude() != null && (a.getLongitude() < -180 || a.getLongitude() > 180)) {
            return "The longitude must be between -180 and 180";
        }
        if (!AREA_CODE.matcher(a.getAreaCode()).matches()) {
            return "The area code has 2 to 16 letters or digits";
        }
        if (a.getName().length() < 2 || a.getName().length() > 80) {
            return "The name must be 2 to 80 characters long";
        }
        if (a.getLocation() != null && a.getLocation().length() > 120) {
            return "The location can be at most 120 characters long";
        }
        if (dao.codeExists(a.getAreaCode(), a.getAreaId())) {
            return "Area code " + a.getAreaCode() + " already exists";
        }
        return null;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String action = util.Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                model.LockerArea blank = new model.LockerArea();
                blank.setActive(true);
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                int id = util.Web.intParam(req, "id", 0);
                model.LockerArea item = dao.findById(id);
                if (item == null) {
                    util.Web.flash(req.getSession(), "Area not found", true);
                    res.sendRedirect("LockerAreaController");
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
        model.User me = util.Web.currentUser(req);
        String action = util.Web.trimmed(req, "action");
        dao.AuditDao auditDao = new dao.AuditDao();
        try {
            if ("delete".equals(action)) {
                int id = util.Web.intParam(req, "id", 0);
                model.LockerArea old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    auditDao.append(me.getUserId(), "DELETE", "AREA", id, old.getAreaCode());
                    util.Web.flash(req.getSession(), "Area " + old.getAreaCode() + " deleted", false);
                } else {
                    util.Web.flash(req.getSession(), reason == null ? "Nothing was deleted" : reason, true);
                }
                res.sendRedirect("LockerAreaController");
                return;
            }

            model.LockerArea a = new model.LockerArea();
            a.setAreaId(util.Web.intParam(req, "id", 0));
            a.setAreaCode(util.Web.trimmed(req, "areaCode").toUpperCase());
            a.setName(util.Web.trimmed(req, "name"));
            a.setLocation(util.Web.trimmed(req, "location"));
            try {
                a.setLatitude(parseCoord(util.Web.trimmed(req, "latitude")));
                a.setLongitude(parseCoord(util.Web.trimmed(req, "longitude")));
            } catch (NumberFormatException e) {
                req.setAttribute("error", "Latitude and longitude must be numbers, e.g. 10.8411 and 106.8099");
                showForm(req, res, a, a.getAreaId() == 0);
                return;
            }
            a.setActive("on".equals(req.getParameter("active")) || "true".equalsIgnoreCase(req.getParameter("active")) || "1".equals(req.getParameter("active")));

            String error = validate(a);
            if (error != null) {
                req.setAttribute("error", error);
                showForm(req, res, a, a.getAreaId() == 0);
                return;
            }

            if ("create".equals(action) || a.getAreaId() == 0) {
                int id = dao.insert(a);
                auditDao.append(me.getUserId(), "CREATE", "AREA", id, a.getAreaCode());
                util.Web.flash(req.getSession(), "Area " + a.getAreaCode() + " created", false);
            } else {
                dao.update(a);
                auditDao.append(me.getUserId(), "UPDATE", "AREA", a.getAreaId(), a.getAreaCode());
                util.Web.flash(req.getSession(), "Area " + a.getAreaCode() + " saved", false);
            }
            res.sendRedirect("LockerAreaController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
