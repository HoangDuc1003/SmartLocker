package util;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import model.User;

/** Small helpers every controller uses, so the controllers stay short. */
public class Web {

    public static final String LOGIN_USER = "LOGIN_USER";   // session key of the signed-in user

    /** The request parameter, trimmed. An absent parameter gives an empty string, never null. */
    public static String trimmed(HttpServletRequest req, String name) {
        String value = req.getParameter(name);
        return value == null ? "" : value.trim();
    }

    /** The parameter as an int, or the default when it is absent or not a number. */
    public static int intParam(HttpServletRequest req, String name, int defaultValue) {
        try {
            return Integer.parseInt(trimmed(req, name));
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    /** The parameter as an Integer, or null when it is absent or not a number (used by filters). */
    public static Integer optionalInt(HttpServletRequest req, String name) {
        try {
            return Integer.valueOf(trimmed(req, name));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** The signed-in user, or null. */
    public static User currentUser(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        return session == null ? null : (User) session.getAttribute(LOGIN_USER);
    }

    /** One message for the next page; common/nav.jspf shows it once and removes it. */
    public static void flash(HttpSession session, String message, boolean bad) {
        session.setAttribute("flash", message);
        session.setAttribute("flashBad", bad);
    }

    /** Number of pages for a total, at least 1. */
    public static int pages(int total, int pageSize) {
        return Math.max(1, (total + pageSize - 1) / pageSize);
    }
}
