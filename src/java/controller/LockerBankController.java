package controller;

import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/** Banks (cabinets) of an area. Add, view, edit, delete. */
@WebServlet(name = "LockerBankController", urlPatterns = {"/LockerBankController"})
public class LockerBankController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/lockerBank.jsp";

    private static final int PAGE_SIZE = 10;
    private static final java.util.regex.Pattern BANK_CODE = java.util.regex.Pattern.compile("^[A-Za-z0-9_-]{2,20}$");

    private final dao.LockerBankDao dao = new dao.LockerBankDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        String q = util.Web.trimmed(req, "q");
        Integer areaId = util.Web.optionalInt(req, "areaId");
        int total = dao.count(q, areaId);
        int pages = util.Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, util.Web.intParam(req, "page", 1)), pages);

        req.setAttribute("mode", "list");
        req.setAttribute("items", dao.search(q, areaId, page, PAGE_SIZE));
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("q", q);
        req.setAttribute("areaId", areaId);
        req.setAttribute("areas", new dao.LockerAreaDao().listAll());
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void showForm(HttpServletRequest req, HttpServletResponse res, model.LockerBank item, boolean isNew)
            throws SQLException, ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.setAttribute("areas", new dao.LockerAreaDao().listAll());
        req.setAttribute("devices", new dao.DeviceDao().listAvailableForBank(item.getDeviceId()));
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        String q = util.Web.trimmed(req, "q");
        Integer areaId = util.Web.optionalInt(req, "areaId");
        java.util.List<String[]> rows = new java.util.ArrayList<>();
        for (model.LockerBank b : dao.search(q, areaId, 1, Math.max(1, dao.count(q, areaId)))) {
            rows.add(new String[]{String.valueOf(b.getBankId()), b.getBankCode(), b.getName(),
                b.getAreaCode(), b.getDeviceId() == null ? "" : String.valueOf(b.getDeviceId()),
                String.valueOf(b.getDoorRows()), String.valueOf(b.getSlotCount()), b.getStatus()});
        }
        util.Csv.send(res, "banks.csv", new String[]{"bank_id", "bank_code", "name", "area", "device_id", "door_rows", "slots", "status"}, rows);
    }

    private String validate(model.LockerBank b) throws SQLException {
        if (!BANK_CODE.matcher(b.getBankCode()).matches()) {
            return "Mã dãy tủ gồm 2 đến 20 ký tự: chữ, số, - hoặc _";
        }
        if (b.getName().length() < 1 || b.getName().length() > 40) {
            return "Tên dãy tủ dài từ 1 đến 40 ký tự";
        }
        if (b.getAreaId() <= 0) {
            return "Hãy chọn khu vực";
        }
        if (b.getDoorRows() < 1 || b.getDoorRows() > 8) {
            return "Số hàng cửa phải từ 1 đến 8";
        }
        if (dao.codeExists(b.getBankCode(), b.getBankId())) {
            return "Mã dãy tủ " + b.getBankCode() + " đã tồn tại";
        }
        return null;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String action = util.Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                model.LockerBank blank = new model.LockerBank();
                blank.setDoorRows(4);
                blank.setStatus("ACTIVE");
                showForm(req, res, blank, true);
            } else if ("edit".equals(action)) {
                int id = util.Web.intParam(req, "id", 0);
                model.LockerBank item = dao.findById(id);
                if (item == null) {
                    util.Web.flash(req.getSession(), "Không tìm thấy dãy tủ", true);
                    res.sendRedirect("LockerBankController");
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
                model.LockerBank old = dao.findById(id);
                String reason = dao.delete(id);
                if (reason == null && old != null) {
                    auditDao.append(me.getUserId(), "DELETE", "LOCKERBANK", id, old.getBankCode());
                    util.Web.flash(req.getSession(), "Đã xóa dãy tủ " + old.getBankCode(), false);
                } else {
                    util.Web.flash(req.getSession(), reason == null ? "Không có gì bị xóa" : reason, true);
                }
                res.sendRedirect("LockerBankController");
                return;
            }

            model.LockerBank b = new model.LockerBank();
            b.setBankId(util.Web.intParam(req, "id", 0));
            b.setBankCode(util.Web.trimmed(req, "bankCode").toUpperCase());
            b.setName(util.Web.trimmed(req, "name"));
            b.setAreaId(util.Web.intParam(req, "areaId", 0));
            b.setDeviceId(util.Web.optionalInt(req, "deviceId"));
            b.setDoorRows(util.Web.intParam(req, "doorRows", 4));
            b.setStatus(util.Web.trimmed(req, "status"));
            if (b.getStatus().isEmpty()) {
                b.setStatus("ACTIVE");
            }

            String error = validate(b);
            if (error != null) {
                req.setAttribute("error", error);
                showForm(req, res, b, b.getBankId() == 0);
                return;
            }

            if ("create".equals(action) || b.getBankId() == 0) {
                int id = dao.insert(b);
                auditDao.append(me.getUserId(), "CREATE", "LOCKERBANK", id, b.getBankCode());
                util.Web.flash(req.getSession(), "Đã tạo dãy tủ " + b.getBankCode(), false);
            } else {
                dao.update(b);
                auditDao.append(me.getUserId(), "UPDATE", "LOCKERBANK", b.getBankId(), b.getBankCode());
                util.Web.flash(req.getSession(), "Đã lưu dãy tủ " + b.getBankCode(), false);
            }
            res.sendRedirect("LockerBankController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
