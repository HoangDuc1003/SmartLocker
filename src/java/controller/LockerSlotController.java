package controller;

import dao.AuditDao;
import dao.LockerBankDao;
import dao.LockerSlotDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.LockerSlot;
import model.User;
import util.Csv;
import util.Web;

/**
 * Add, view, edit and delete door slots. The pattern of every CRUD controller:
 * GET shows a list or a form, POST changes data then redirects (Post/Redirect/Get),
 * the message for the next page travels in the session as a flash.
 */
@WebServlet(name = "LockerSlotController", urlPatterns = {"/LockerSlotController"})
public class LockerSlotController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/lockerSlot.jsp";

    private static final int PAGE_SIZE = 10;
    private static final Pattern SLOT_CODE = Pattern.compile("^[A-Za-z0-9_-]{1,20}$");
    private static final Set<String> STATUSES = new HashSet<>(Arrays.asList("AVAILABLE", "RESERVED", "OCCUPIED", "MAINTENANCE"));
    private static final Set<String> SIZES = new HashSet<>(Arrays.asList("S", "M", "L"));

    private final LockerSlotDao dao = new LockerSlotDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        String q = Web.trimmed(req, "q");
        Integer bankId = Web.optionalInt(req, "bankId");
        String status = Web.trimmed(req, "status");
        int total = dao.count(q, bankId, status);
        int pages = Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

        req.setAttribute("mode", "list");
        req.setAttribute("items", dao.search(q, bankId, status, page, PAGE_SIZE));
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("q", q);
        req.setAttribute("bankId", bankId);
        req.setAttribute("status", status);
        req.setAttribute("banks", new LockerBankDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    /** item holds what the form shows: blank values for a new slot, the typed values after a failed save. */
    private void showForm(HttpServletRequest req, HttpServletResponse res, LockerSlot item, boolean isNew)
            throws SQLException, ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.setAttribute("banks", new LockerBankDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    /** Sends the rows the user is looking at, not the whole table. */
    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        String q = Web.trimmed(req, "q");
        Integer bankId = Web.optionalInt(req, "bankId");
        String status = Web.trimmed(req, "status");
        List<String[]> rows = new ArrayList<>();
        for (LockerSlot s : dao.search(q, bankId, status, 1, Math.max(1, dao.count(q, bankId, status)))) {
            rows.add(new String[]{String.valueOf(s.getSlotId()), s.getBankCode(), s.getSlotCode(),
                s.getSizeCode(), s.getSizeCm(), s.getStatus()});
        }
        Csv.send(res, "slots.csv", new String[]{"slot_id", "bank", "slot_code", "size", "size_cm", "status"}, rows);
    }

    private LockerSlot readForm(HttpServletRequest req) {
        LockerSlot s = new LockerSlot();
        s.setSlotId(Web.intParam(req, "id", 0));
        s.setSlotCode(Web.trimmed(req, "slotCode"));
        s.setBankId(Web.intParam(req, "bankId", 0));
        s.setSizeCode(Web.trimmed(req, "sizeCode"));
        s.setSizeCm(Web.trimmed(req, "sizeCm"));
        s.setStatus(Web.trimmed(req, "status"));
        return s;
    }

    /** The browser checks only save a round trip; this is the check that counts. Returns null when valid. */
    private String validate(LockerSlot s) throws SQLException {
        if (!SLOT_CODE.matcher(s.getSlotCode()).matches()) {
            return "Slot code must be 1 to 20 letters, digits, - or _";
        }
        if (s.getBankId() <= 0) {
            return "Choose a bank";
        }
        if (!SIZES.contains(s.getSizeCode())) {
            return "Size must be S, M or L";
        }
        if (s.getSizeCm().length() > 20) {
            return "Size in cm is at most 20 characters";
        }
        if (!STATUSES.contains(s.getStatus())) {
            return "Status is not valid";
        }
        if (dao.codeExists(s.getBankId(), s.getSlotCode(), s.getSlotId())) {
            return "This bank already has a slot with the code " + s.getSlotCode();
        }
        return null;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // action = new | edit | export, anything else is the list
        String action = Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                LockerSlot blank = new LockerSlot();
                blank.setSizeCode("S");
                blank.setStatus("AVAILABLE");
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                LockerSlot item = dao.findById(Web.intParam(req, "id", 0));
                if (item == null) {
                    Web.flash(req.getSession(), "That slot does not exist", true);
                    res.sendRedirect("LockerSlotController");
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
        // action = create | update | delete; validate, write, audit, flash, redirect
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        try {
            if ("delete".equals(action)) {
                int id = Web.intParam(req, "id", 0);
                LockerSlot old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    new AuditDao().append(me.getUserId(), "DELETE", "LOCKERSLOT", id, old.getBankCode() + " " + old.getSlotCode());
                    Web.flash(req.getSession(), "Slot " + old.getSlotCode() + " deleted", false);
                } else {
                    Web.flash(req.getSession(), reason == null ? "Nothing was deleted" : reason, true);
                }
                res.sendRedirect("LockerSlotController");
                return;
            }

            LockerSlot s = readForm(req);
            String error = validate(s);
            if (error != null) {                        // show the form again with what the user typed
                req.setAttribute("error", error);
                showForm(req, res, s, s.getSlotId() == 0);
                return;
            }
            if ("create".equals(action)) {
                int id = dao.insert(s);
                new AuditDao().append(me.getUserId(), "CREATE", "LOCKERSLOT", id, s.getSlotCode());
                Web.flash(req.getSession(), "Slot " + s.getSlotCode() + " created", false);
            } else {
                dao.update(s);
                new AuditDao().append(me.getUserId(), "UPDATE", "LOCKERSLOT", s.getSlotId(), s.getSlotCode());
                Web.flash(req.getSession(), "Slot " + s.getSlotCode() + " saved", false);
            }
            res.sendRedirect("LockerSlotController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
