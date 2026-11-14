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
 * GET (the old "My bookings" page) redirects to "My locker" (MyLockerController, spec v2 Q17).
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
                // v2: openMethod = PIN (default, keeps the old form working), CARD, PHONE (v7) or FINGERPRINT
                String method = Web.trimmed(req, "openMethod").toUpperCase();
                if (method.isEmpty()) {
                    method = "PIN";
                }
                if (!DepositDao.OPEN_METHODS.contains(method)) {
                    Web.flash(req.getSession(), "Invalid open method", true);
                } else {
                    // "Custom": customMin (whole hours or days) replaces planId; the procedure prices it, never the page
                    int customMin = Web.intParam(req, "customMin", 0);
                    long id = dao.reserve(me.getUserId(), Web.intParam(req, "slotId", 0), Web.intParam(req, "planId", 0), method,
                            customMin > 0 ? Integer.valueOf(customMin) : null);
                    int hold = new dao.AppConfigDao().getInt("HOLD_MIN", util.Pricing.HOLD_MIN);
                    Web.flash(req.getSession(), reservedMessage(dao.findById(id), hold), false);
                }
            } else if ("cancel".equals(action)) {
                // v3: 100% back in the first minutes, then a part until the hold ends; the flash says what came back
                long expected = Web.longParam(req, "expectedRefund", -1);
                dao.UserDao users = new dao.UserDao();
                long before = users.getBalance(me.getUserId());
                dao.cancel(Web.longParam(req, "depositId", 0), me.getUserId(), expected >= 0 ? Long.valueOf(expected) : null);
                long refund = users.getBalance(me.getUserId()) - before;
                Web.flash(req.getSession(), "Booking cancelled. " + service.AuthText.vnd(refund) + " refunded to your wallet.", false);
            } else if ("extend".equals(action)) {
                // v3: an extension is paid; the flash says what was taken (the procedure computes the same amount)
                long depositId = Web.longParam(req, "depositId", 0);
                int minutes = Web.intParam(req, "minutes", 60);
                model.Deposit before = dao.findById(depositId);
                dao.extend(depositId, minutes, me.getUserId());
                model.Deposit after = dao.findById(depositId);
                String text = "Extended by " + minutes + " min.";
                if (before != null && after != null) {
                    text += " " + service.AuthText.vnd(after.getPaidAmount() - before.getPaidAmount()) + " was taken from your wallet.";
                }
                Web.flash(req.getSession(), text, false);
            } else {
                Web.flash(req.getSession(), "Invalid action", true);
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

    /** What to do next at the box, by open method. The PIN itself stays on "My locker", not in the flash. */
    private static String reservedMessage(model.Deposit d, int hold) {
        String box = d == null || d.getDeviceCode() == null ? "the locker box" : "box " + d.getDeviceCode();
        if (d != null && d.getEnrollCode() != null) {
            return "Slot held. Go to " + box + " and enroll your "
                    + ("CARD".equals(d.getOpenMethod()) ? "card" : "fingerprint")
                    + " with code " + d.getEnrollCode() + " (valid 10 min), then open the locker within " + hold + " min.";
        }
        if (d != null && "PHONE".equals(d.getOpenMethod())) {
            return "Slot held. Tap your phone on the NFC reader of " + box + " within " + hold + " min.";
        }
        if (d != null && "CARD".equals(d.getOpenMethod())) {
            return "Slot held. Scan your card at " + box + " within " + hold + " min.";
        }
        if (d != null && "FINGERPRINT".equals(d.getOpenMethod())) {
            return "Slot held. Place your finger on the sensor of " + box + " within " + hold + " min.";
        }
        return "Slot held. See your PIN in My locker and open the locker at " + box + " within " + hold + " min.";
    }

    private static String backUrl(HttpServletRequest req) throws UnsupportedEncodingException {
        if ("list".equals(Web.trimmed(req, "back"))) {
            return "MyLockerController";
        }
        return "LockerMapController?area=" + URLEncoder.encode(Web.trimmed(req, "area"), "UTF-8")
                + "&slot=" + Web.intParam(req, "slot", 0);
    }
}
