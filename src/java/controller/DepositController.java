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
import service.AuthText;
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
                long id = Web.longParam(req, "id", 0);
                Deposit item = dao.findById(id);
                if (item == null) {
                    Web.flash(req.getSession(), "Không tìm thấy lượt gửi", true);
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
                long id = Web.longParam(req, "id", 0);
                Deposit old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    new AuditDao().append(me.getUserId(), "DELETE", "DEPOSIT", id, "Deposit #" + id);
                    Web.flash(req.getSession(), "Đã xóa lượt gửi #" + id, false);
                } else {
                    Web.flash(req.getSession(), reason == null ? "Không có gì bị xóa" : reason, true);
                }
                res.sendRedirect("DepositController");
                return;
            }

            if ("create".equals(action)) {
                int userId = Web.intParam(req, "userId", 0);
                int slotId = Web.intParam(req, "slotId", 0);
                int planId = Web.intParam(req, "planId", 0);
                if (userId <= 0 || slotId <= 0 || planId <= 0) {
                    req.setAttribute("error", "Cần chọn người dùng, ngăn tủ và gói gửi đồ.");
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
                int duration = (plan != null) ? plan.getDurationMin() : 60;
                // started_at is SYSUTCDATETIME(), so the due time is UTC as well
                d.setDueAt(Timestamp.valueOf(java.time.LocalDateTime.now(java.time.ZoneOffset.UTC).plusMinutes(duration)));
                try {
                    long newId = dao.insert(d);
                    new AuditDao().append(me.getUserId(), "CREATE", "DEPOSIT", newId, "Walk-in deposit");
                    Web.flash(req.getSession(), "Đã tạo lượt gửi #" + newId, false);
                } catch (SQLException e) {
                    boolean openBooking = (e.getErrorCode() == 2601 || e.getErrorCode() == 2627)
                            && String.valueOf(e.getMessage()).contains("UX_Deposit_user_open");
                    if (e.getErrorCode() < 50000 && !openBooking) {
                        throw e;   // not a business rule: the outer handler turns it into a server error
                    }
                    req.setAttribute("error", openBooking
                            ? "Người dùng này đang có một lượt gửi chưa kết thúc." : Web.sqlMessage(e));
                    showForm(req, res, d, true);
                    return;
                }
            } else if ("update".equals(action)) {
                long id = Web.longParam(req, "id", 0);
                int planId = Web.intParam(req, "planId", 0);
                String status = Web.trimmed(req, "status");
                Deposit d = dao.findById(id);
                if (d == null) {
                    Web.flash(req.getSession(), "Không tìm thấy lượt gửi", true);
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
                        // the operator types Vietnam time, the DB stores UTC (read back as the UTC wall clock)
                        java.time.Instant due = java.time.LocalDateTime.parse(dueStr.replace(" ", "T"))
                                .atZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh")).toInstant();
                        d.setDueAt(Timestamp.valueOf(java.time.LocalDateTime.ofInstant(due, java.time.ZoneOffset.UTC)));
                    } catch (java.time.DateTimeException e) {
                        Web.flash(req.getSession(), "Hạn trả không đúng định dạng, ví dụ 2026-10-20 18:00:00.", true);
                        res.sendRedirect("DepositController?action=edit&id=" + id);
                        return;
                    }
                }
                if (!DepositDao.STATUSES.contains(status)) {
                    Web.flash(req.getSession(), "Trạng thái không hợp lệ", true);
                    res.sendRedirect("DepositController?action=edit&id=" + id);
                    return;
                }
                long refund;
                try {
                    refund = dao.update(d);
                } catch (SQLException e) {
                    if (e.getErrorCode() < 50000) {
                        throw e;
                    }
                    Web.flash(req.getSession(), Web.sqlMessage(e), true);
                    res.sendRedirect("DepositController?action=edit&id=" + id);
                    return;
                }
                new AuditDao().append(me.getUserId(), "UPDATE", "DEPOSIT", id,
                        "Status: " + status + (refund > 0 ? ", refund " + refund : ""));
                Web.flash(req.getSession(), "Đã cập nhật lượt gửi #" + id
                        + (refund > 0 ? ", hoàn " + AuthText.vnd(refund) + " vào ví người dùng" : ""), false);
            } else {
                Web.flash(req.getSession(), "Thao tác không hợp lệ", true);
            }
            res.sendRedirect("DepositController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
