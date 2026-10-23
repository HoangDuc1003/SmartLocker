package controller;

import dao.DepositDao;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/**
 * Case 4. The Locker User reserves, cancels and extends a booking.
 * The forms are in the slot panel of the locker map, so every POST goes back to the map.
 * GET (the old "My bookings" page) redirects to "Tủ của tôi" (MyLockerController, spec v2 Q17).
 */
@WebServlet(name = "BookingController", urlPatterns = {"/BookingController"})
public class BookingController extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        res.sendRedirect(req.getContextPath() + "/MyLockerController");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // action = reserve | cancel | extend; the procedure checks the rules and writes the audit row
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        DepositDao dao = new DepositDao();
        try {
            if ("reserve".equals(action)) {
                // v2: openMethod = PIN (default, keeps the old form working), CARD or FINGERPRINT
                String method = Web.trimmed(req, "openMethod").toUpperCase();
                if (method.isEmpty()) {
                    method = "PIN";
                }
                if (!DepositDao.OPEN_METHODS.contains(method)) {
                    Web.flash(req.getSession(), "Cách mở tủ không hợp lệ", true);
                } else {
                    long id = dao.reserve(me.getUserId(), Web.intParam(req, "slotId", 0), Web.intParam(req, "planId", 0), method);
                    int hold = new dao.AppConfigDao().getInt("HOLD_MIN", util.Pricing.HOLD_MIN);
                    Web.flash(req.getSession(), reservedMessage(dao.findById(id), hold), false);
                }
            } else if ("cancel".equals(action)) {
                dao.cancel(Web.longParam(req, "depositId", 0), me.getUserId());
                Web.flash(req.getSession(), "Đã hủy lượt đặt. Toàn bộ số tiền đã trả được hoàn vào ví.", false);
            } else if ("extend".equals(action)) {
                // v3: an extension is paid; the flash says what was taken (the procedure computes the same amount)
                long depositId = Web.longParam(req, "depositId", 0);
                int minutes = Web.intParam(req, "minutes", 60);
                model.Deposit before = dao.findById(depositId);
                dao.extend(depositId, minutes, me.getUserId());
                model.Deposit after = dao.findById(depositId);
                String text = "Đã gia hạn thêm " + minutes + " phút.";
                if (before != null && after != null) {
                    text += " Đã trừ " + service.AuthText.vnd(after.getPaidAmount() - before.getPaidAmount()) + " vào ví.";
                }
                Web.flash(req.getSession(), text, false);
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
        res.sendRedirect(backUrl(req));
    }

    /** What to do next at the box, by open method. The PIN itself stays on "Tủ của tôi", not in the flash. */
    private static String reservedMessage(model.Deposit d, int hold) {
        String box = d == null || d.getDeviceCode() == null ? "hộp tủ" : "hộp " + d.getDeviceCode();
        if (d != null && d.getEnrollCode() != null) {
            return "Đã giữ ngăn. Hãy tới " + box + " đăng ký "
                    + ("CARD".equals(d.getOpenMethod()) ? "thẻ từ" : "vân tay")
                    + " bằng mã " + d.getEnrollCode() + " (hạn 10 phút), rồi mở tủ trong vòng " + hold + " phút.";
        }
        if (d != null && "CARD".equals(d.getOpenMethod())) {
            return "Đã giữ ngăn. Hãy quẹt thẻ tại " + box + " trong vòng " + hold + " phút.";
        }
        if (d != null && "FINGERPRINT".equals(d.getOpenMethod())) {
            return "Đã giữ ngăn. Hãy đặt vân tay tại " + box + " trong vòng " + hold + " phút.";
        }
        return "Đã giữ ngăn. Xem mật mã ở mục Tủ của tôi và mở tủ tại " + box + " trong vòng " + hold + " phút.";
    }

    private static String backUrl(HttpServletRequest req) throws UnsupportedEncodingException {
        if ("list".equals(Web.trimmed(req, "back"))) {
            return "MyLockerController";
        }
        return "LockerMapController?area=" + URLEncoder.encode(Web.trimmed(req, "area"), "UTF-8")
                + "&slot=" + Web.intParam(req, "slot", 0);
    }
}
