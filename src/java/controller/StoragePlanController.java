package controller;

import dao.AuditDao;
import dao.StoragePlanDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.StoragePlan;
import model.User;
import util.Csv;
import util.Web;

/** Storage plans. Add, view, edit, delete; a plan that was used is deactivated instead. */
@WebServlet(name = "StoragePlanController", urlPatterns = {"/StoragePlanController"})
public class StoragePlanController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/storagePlan.jsp";

    private final StoragePlanDao dao = new StoragePlanDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        List<StoragePlan> items = dao.listAll(false);
        req.setAttribute("mode", "list");
        req.setAttribute("items", items);
        req.setAttribute("total", items.size());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void showForm(HttpServletRequest req, HttpServletResponse res, StoragePlan item, boolean isNew)
            throws ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        List<String[]> rows = new ArrayList<>();
        for (StoragePlan p : dao.listAll(false)) {
            rows.add(new String[]{
                String.valueOf(p.getPlanId()),
                p.getPlanName(),
                String.valueOf(p.getDurationMin()),
                String.valueOf(p.getGraceMin()),
                String.valueOf(p.getPrice()),
                p.isActive() ? "ACTIVE" : "INACTIVE"
            });
        }
        Csv.send(res, "plans.csv", new String[]{"plan_id", "plan_name", "duration_min", "grace_min", "price", "status"}, rows);
    }

    private StoragePlan readForm(HttpServletRequest req) {
        StoragePlan p = new StoragePlan();
        p.setPlanId(Web.intParam(req, "id", 0));
        p.setPlanName(Web.trimmed(req, "planName"));
        p.setDurationMin(Web.intParam(req, "durationMin", 0));
        p.setGraceMin(Web.intParam(req, "graceMin", 0));
        p.setPrice(Web.intParam(req, "price", 0));
        String activeParam = req.getParameter("isActive");
        p.setActive("true".equalsIgnoreCase(activeParam) || "1".equals(activeParam) || "on".equalsIgnoreCase(activeParam));
        return p;
    }

    private String validate(StoragePlan p) {
        if (p.getPlanName() == null || p.getPlanName().length() < 1 || p.getPlanName().length() > 40) {
            return "Plan name must be 1 to 40 characters";
        }
        if (p.getDurationMin() < 1 || p.getDurationMin() > 1440) {
            return "Duration must be between 1 and 1440 minutes";
        }
        if (p.getGraceMin() < 0 || p.getGraceMin() > 120) {
            return "Grace period must be between 0 and 120 minutes";
        }
        if (p.getPrice() < 0) {
            return "Price must be non-negative";
        }
        return null;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String action = Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                StoragePlan blank = new StoragePlan();
                blank.setDurationMin(60);
                blank.setGraceMin(15);
                blank.setPrice(0);
                blank.setActive(true);
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                int id = Web.intParam(req, "id", 0);
                StoragePlan item = dao.findById(id);
                if (item == null) {
                    Web.flash(req.getSession(), "Storage plan not found", true);
                    res.sendRedirect("StoragePlanController");
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
                StoragePlan old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    new AuditDao().append(me.getUserId(), "DELETE", "STORAGEPLAN", id, old.getPlanName());
                    Web.flash(req.getSession(), "Plan " + old.getPlanName() + " deleted", false);
                } else {
                    Web.flash(req.getSession(), reason == null ? "Nothing was deleted" : reason, true);
                }
                res.sendRedirect("StoragePlanController");
                return;
            }

            StoragePlan p = readForm(req);
            String error = validate(p);
            if (error != null) {
                req.setAttribute("error", error);
                showForm(req, res, p, p.getPlanId() == 0);
                return;
            }

            if ("create".equals(action)) {
                int id = dao.insert(p);
                new AuditDao().append(me.getUserId(), "CREATE", "STORAGEPLAN", id, p.getPlanName());
                Web.flash(req.getSession(), "Plan " + p.getPlanName() + " created", false);
            } else {
                dao.update(p);
                new AuditDao().append(me.getUserId(), "UPDATE", "STORAGEPLAN", p.getPlanId(), p.getPlanName());
                Web.flash(req.getSession(), "Plan " + p.getPlanName() + " saved", false);
            }
            res.sendRedirect("StoragePlanController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
