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
 * GET shows "My bookings".
 */
@WebServlet(name = "BookingController", urlPatterns = {"/BookingController"})
public class BookingController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/booking.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        try {
            User me = Web.currentUser(req);
            req.setAttribute("items", new DepositDao().listByUser(me.getUserId()));
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // action = reserve | cancel | extend; the procedure checks the rules and writes the audit row
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        DepositDao dao = new DepositDao();
        try {
            if ("reserve".equals(action)) {
                dao.reserve(me.getUserId(), Web.intParam(req, "slotId", 0), Web.intParam(req, "planId", 0));
                Web.flash(req.getSession(), "Slot reserved. Check in within 15 minutes.", false);
            } else if ("cancel".equals(action)) {
                dao.cancel(Web.intParam(req, "depositId", 0), me.getUserId());
                Web.flash(req.getSession(), "Reservation cancelled. Any payment has been refunded.", false);
            } else if ("extend".equals(action)) {
                dao.extend(Web.intParam(req, "depositId", 0), Web.intParam(req, "minutes", 60), me.getUserId());
                Web.flash(req.getSession(), "Your time was extended.", false);
            } else {
                Web.flash(req.getSession(), "Unknown action", true);
            }
        } catch (SQLException e) {
            if (e.getErrorCode() >= 50000) {                 // our own THROW: the text is written for the user
                Web.flash(req.getSession(), e.getMessage(), true);
            } else {
                throw new ServletException(e);
            }
        }
        res.sendRedirect(backUrl(req));
    }

    private static String backUrl(HttpServletRequest req) throws UnsupportedEncodingException {
        if ("list".equals(Web.trimmed(req, "back"))) {
            return "BookingController";
        }
        return "LockerMapController?area=" + URLEncoder.encode(Web.trimmed(req, "area"), "UTF-8")
                + "&slot=" + Web.intParam(req, "slot", 0);
    }
}
