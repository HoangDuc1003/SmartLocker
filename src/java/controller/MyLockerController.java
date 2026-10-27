package controller;

import dao.AppConfigDao;
import dao.DepositDao;
import dao.DeviceAuthDao;
import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.Deposit;
import model.User;
import util.Pricing;
import util.Web;

/**
 * v2 "Tủ của tôi" (spec 5.2): the open booking with its PIN or enroll code, the cards, the fingerprints and
 * the history. It replaces "Lượt đặt của tôi" (BookingController GET) and "Thẻ của tôi" (MyCardController GET).
 * Cancel and extend post to BookingController, report lost to MyCardController; both come back here.
 */
@WebServlet(name = "MyLockerController", urlPatterns = {"/MyLockerController"})
public class MyLockerController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/myLocker.jsp";
    private static final int HISTORY_MAX = 20;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        if (Web.isUserView(me) && !"1".equals(req.getParameter("panel"))) {
            // a user sees this page as a glass popup over the map (js/glass-panel.js asks for ?panel=1)
            res.sendRedirect(req.getContextPath() + "/LockerMapController?panel=mylocker");
            return;
        }
        try {
            DeviceAuthDao auth = new DeviceAuthDao();
            List<Deposit> open = new ArrayList<>();
            List<Deposit> history = new ArrayList<>();
            DepositDao deposits = new DepositDao();
            Map<Long, Long> refunds = deposits.noShowRefunds(me.getUserId());   // NO_SHOW rows: what came back
            for (Deposit d : deposits.listByUser(me.getUserId())) {
                if ("RESERVED".equals(d.getStatus()) || "ACTIVE".equals(d.getStatus())) {
                    open.add(d);
                } else if (history.size() < HISTORY_MAX) {
                    history.add(d);
                }
            }
            req.setAttribute("open", open);
            req.setAttribute("history", history);
            req.setAttribute("refunds", refunds);
            req.setAttribute("cards", auth.cardsOf(me.getUserId()));
            req.setAttribute("fingerprints", auth.fingerprintsOf(me.getUserId()));
            req.setAttribute("cardDepositDue", !auth.hasRegisteredCard(me.getUserId()));
            // v3: the rules the page counts down (cancel 5 minutes, hold 15), the wallet that may be in debt,
            // and the size of the open booking (measures, late fee of one hour)
            AppConfigDao config = new AppConfigDao();
            req.setAttribute("cardDeposit", config.get("CARD_DEPOSIT", Pricing.CARD_DEPOSIT));
            req.setAttribute("cancelMin", config.getInt("CANCEL_FREE_MIN", Pricing.CANCEL_FREE_MIN));
            req.setAttribute("holdMin", config.getInt("HOLD_MIN", Pricing.HOLD_MIN));
            req.setAttribute("escalateHours", config.getInt("ESCALATE_HOURS", Pricing.ESCALATE_HOURS));
            UserDao users = new UserDao();
            req.setAttribute("balance", users.getBalance(me.getUserId()));
            req.setAttribute("email", users.getEmail(me.getUserId()));
            req.setAttribute("mailEnabled", service.MailService.of(getServletContext()).isEnabled());
            Map<String, AppConfigDao.SlotSize> sizes = new HashMap<>();
            for (AppConfigDao.SlotSize z : config.sizes()) {
                sizes.put(z.code, z);
            }
            req.setAttribute("sizes", sizes);
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        String anchor = "";
        try {
            if ("newEnrollCode".equals(action)) {
                String code = new DepositDao().newEnrollCode(Web.longParam(req, "depositId", 0), me.getUserId());
                Web.flash(req.getSession(), "Đã tạo mã đăng ký mới " + code + ", có hạn 10 phút.", false);
            } else if ("deleteFingerprint".equals(action)) {
                new DeviceAuthDao().deleteFingerprint(Web.intParam(req, "fpId", 0), me.getUserId());
                Web.flash(req.getSession(), "Đã xóa vân tay. Hộp sẽ xóa mẫu trong lần kết nối tới.", false);
                anchor = "#fingerprints";
            } else if ("setEmail".equals(action)) {
                // v3: the address for the due reminders, saved as typed (the user's choice); empty turns them off
                String email = Web.trimmed(req, "email");
                anchor = "#reminder";
                if (!email.isEmpty() && !Web.isEmail(email)) {
                    Web.flash(req.getSession(), "Email không hợp lệ", true);
                } else {
                    try {
                        new UserDao().setEmail(me.getUserId(), email);
                        Web.flash(req.getSession(), email.isEmpty() ? "Đã tắt email nhắc hạn."
                                : "Đã lưu email nhận nhắc hạn: " + email, false);
                    } catch (SQLException dup) {
                        if (dup.getErrorCode() != 2601 && dup.getErrorCode() != 2627) {
                            throw dup;
                        }
                        Web.flash(req.getSession(), "Email này đã được một tài khoản khác dùng", true);
                    }
                }
            } else {
                Web.flash(req.getSession(), "Thao tác không hợp lệ", true);
            }
        } catch (SQLException e) {
            if (e.getErrorCode() >= 50000) {                 // our own THROW: the text is written for the user
                Web.flash(req.getSession(), Web.sqlMessage(e), true);
            } else {
                throw new ServletException(e);
            }
        }
        res.sendRedirect("MyLockerController" + anchor);
    }
}
