package controller;

import dao.DeviceAuthDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/**
 * v2, spec 4.5 / 5.4: GET /k/{device_code}, the public phone page behind the QR printed on the box.
 * No login for the PIN: the page only posts it to /api/kiosk/unlock (js/kiosk.js). An unknown box answers 404 with a short text.
 *
 * v7, the phone tap: the PN532 of the box emulates an NFC tag that holds /k/{device_code}?n={token}. A phone that taps
 * the box opens this page with the token; a signed-in owner of an open booking on the box sees "Mở tủ của tôi", which posts
 * the token with the session to /api/kiosk/unlock. A GET never opens anything (link scanners, prefetch). A visitor who is
 * not signed in gets a sign-in link that comes back here with the same token.
 */
@WebServlet(name = "KioskController", urlPatterns = {"/k/*"})
public class KioskController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/kiosk.jsp";
    /** The token of the NFC tag (Device_TapIssue): 12 letters and digits. */
    public static final String TAP_FORMAT = "[A-Za-z0-9]{12}";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String path = req.getPathInfo();                       // "/LOCKER-01" (a trailing slash is allowed)
        String code = path == null ? "" : path.replaceAll("^/+|/+$", "");
        String tap = req.getParameter("n");
        if (tap != null && !tap.matches(TAP_FORMAT)) {
            tap = null;
        }
        Map<String, Object> device = null;
        Map<String, Object> mine = null;
        User me = Web.currentUser(req);
        if (code.matches("[A-Za-z0-9_-]{1,40}")) {
            try {
                DeviceAuthDao dao = new DeviceAuthDao();
                device = dao.findDeviceByCode(code);
                if (device != null && me != null) {
                    mine = dao.openBookingAt(me.getUserId(), (Integer) device.get("device_id"));
                }
            } catch (SQLException e) {
                throw new ServletException(e);
            }
        }
        req.setAttribute("deviceCode", code);
        req.setAttribute("device", device);
        req.setAttribute("tap", tap);
        req.setAttribute("signedIn", me);
        req.setAttribute("mine", mine);
        if (device != null && me == null) {
            String back = "/k/" + code + (tap == null ? "" : "?n=" + tap);
            req.setAttribute("signInUrl", Web.signInUrl(req, "login", back));
        }
        if (device == null) {
            res.setStatus(HttpServletResponse.SC_NOT_FOUND);
        }
        res.setHeader("Cache-Control", "no-store");
        res.setHeader("Referrer-Policy", "no-referrer");   // the token must not leave in a Referer header
        req.getRequestDispatcher(VIEW).forward(req, res);
    }
}
