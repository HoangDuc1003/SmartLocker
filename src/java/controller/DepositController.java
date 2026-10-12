package controller;

import dao.AuditDao;
import dao.DepositDao;
import dao.LockerSlotDao;
import dao.StoragePlanDao;
import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.Deposit;
import model.StoragePlan;
import model.User;
import util.Csv;
import util.Web;

/** Deposits for staff: view all bookings, register a walk-in, change, delete a closed one. */
@WebServlet(name = "DepositController", urlPatterns = {"/DepositController"})
public class DepositController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/deposit.jsp";
    private static final int PAGE_SIZE = 10;

    private final DepositDao dao = new DepositDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        String q = Web.trimmed(req, "q");
        String status = Web.trimmed(req, "status");
        int total = dao.count(q, status);
        int pages = Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

        req.setAttribute("mode", "list");
        req.setAttribute("items", dao.search(q, status, page, PAGE_SIZE));
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("q", q);
        req.setAttribute("status", status);
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void showForm(HttpServletRequest req, HttpServletResponse res, Deposit item, boolean isNew)
            throws SQLException, ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.setAttribute("slots", new LockerSlotDao().search(null, null, "AVAILABLE", 1, 1000));
        req.setAttribute("plans", new StoragePlanDao().listAll(true));
        req.setAttribute("users", new UserDao().search(null, null, "ACTIVE", 1, 1000));
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        String q = Web.trimmed(req, "q");
        String status = Web.trimmed(req, "status");
        List<String[]> rows = new ArrayList<>();
        for (Deposit d : dao.search(q, status, 1, Math.max(1, dao.count(q, status)))) {
            rows.add(new String[]{
                String.valueOf(d.getDepositId()),
                d.getUsername(),
                d.getBankCode(),
                d.getSlotCode(),
                d.getPlanName(),
                d.getStatus(),
                d.getReservedAt() != null ? d.getReservedAt().toString() : "",
                d.getStartedAt() != null ? d.getStartedAt().toString() : "",
                d.getDueAt() != null ? d.getDueAt().toString() : "",
                d.getEndedAt() != null ? d.getEndedAt().toString() : ""
            });
        }
        Csv.send(res, "deposits.csv",
                new String[]{"deposit_id", "user", "bank", "slot", "plan", "status", "reserved_at", "started_at", "due_at", "ended_at"},
                rows);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String action = Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                Deposit blank = new Deposit();
                blank.setStatus("ACTIVE");
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                long id = Web.intParam(req, "id", 0);
                Deposit item = dao.findById(id);
                if (item == null) {
                    Web.flash(req.getSession(), "Deposit not found", true);
                    res.sendRedirect("DepositController");
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
                long id = Web.intParam(req, "id", 0);
                Deposit old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    new AuditDao().append(me.getUserId(), "DELETE", "DEPOSIT", id, "Deposit #" + id);
                    Web.flash(req.getSession(), "Deposit #" + id + " deleted", false);
                } else {
                    Web.flash(req.getSession(), reason == null ? "Nothing was deleted" : reason, true);
                }
                res.sendRedirect("DepositController");
                return;
            }

            if ("create".equals(action)) {
                int userId = Web.intParam(req, "userId", 0);
                int slotId = Web.intParam(req, "slotId", 0);
                int planId = Web.intParam(req, "planId", 0);
                if (userId <= 0 || slotId <= 0 || planId <= 0) {
                    req.setAttribute("error", "User, slot, and storage plan are required.");
                    Deposit d = new Deposit();
                    d.setUserId(userId);
                    d.setSlotId(slotId);
                    d.setPlanId(planId);
                    showForm(req, res, d, true);
                    return;
                }
                StoragePlan plan = new StoragePlanDao().findById(planId);
                Deposit d = new Deposit();
                d.setUserId(userId);
                d.setSlotId(slotId);
                d.setPlanId(planId);
                d.setStatus("ACTIVE");
                long now = System.currentTimeMillis();
                int duration = (plan != null) ? plan.getDurationMin() : 60;
                d.setDueAt(new Timestamp(now + duration * 60000L));
                try {
                    long newId = dao.insert(d);
                    new AuditDao().append(me.getUserId(), "CREATE", "DEPOSIT", newId, "Walk-in deposit");
                    Web.flash(req.getSession(), "Deposit #" + newId + " created successfully", false);
                } catch (SQLException e) {
                    req.setAttribute("error", e.getMessage());
                    showForm(req, res, d, true);
                    return;
                }
            } else if ("update".equals(action)) {
                long id = Web.intParam(req, "id", 0);
                int planId = Web.intParam(req, "planId", 0);
                String status = Web.trimmed(req, "status");
                Deposit d = dao.findById(id);
                if (d == null) {
                    Web.flash(req.getSession(), "Deposit not found", true);
                    res.sendRedirect("DepositController");
                    return;
                }
                d.setPlanId(planId);
                d.setStatus(status);
                String dueStr = Web.trimmed(req, "dueAt");
                if (!dueStr.isEmpty()) {
                    try {
                        if (dueStr.length() == 16) {
                            dueStr += ":00";
                        }
                        d.setDueAt(Timestamp.valueOf(dueStr.replace("T", " ")));
                    } catch (Exception ignored) {
                    }
                }
                dao.update(d);
                new AuditDao().append(me.getUserId(), "UPDATE", "DEPOSIT", id, "Status: " + status);
                Web.flash(req.getSession(), "Deposit #" + id + " updated", false);
            } else {
                Web.flash(req.getSession(), "Unknown action", true);
            }
            res.sendRedirect("DepositController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
