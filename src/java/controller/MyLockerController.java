package controller;

import dao.DepositDao;
import dao.DeviceAuthDao;
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
        try {
            DeviceAuthDao auth = new DeviceAuthDao();
            List<Deposit> open = new ArrayList<>();
            List<Deposit> history = new ArrayList<>();
            Map<Long, Long> refunds = new HashMap<>();          // NO_SHOW rows: what came back to the wallet (90%)
            for (Deposit d : new DepositDao().listByUser(me.getUserId())) {
                if ("RESERVED".equals(d.getStatus()) || "ACTIVE".equals(d.getStatus())) {
                    open.add(d);
                } else if (history.size() < HISTORY_MAX) {
                    history.add(d);
                    if ("NO_SHOW".equals(d.getStatus())) {
                        refunds.put(d.getDepositId(), Pricing.noShowRefund(d.getPaidAmount()));
                    }
                }
            }
            req.setAttribute("open", open);
            req.setAttribute("history", history);
            req.setAttribute("refunds", refunds);
            req.setAttribute("cards", auth.cardsOf(me.getUserId()));
            req.setAttribute("fingerprints", auth.fingerprintsOf(me.getUserId()));
            req.setAttribute("cardDepositDue", !auth.hasRegisteredCard(me.getUserId()));
            req.setAttribute("cardDeposit", Pricing.CARD_DEPOSIT);
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
