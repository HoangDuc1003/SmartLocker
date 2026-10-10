package util;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import model.User;

/** Small helpers every controller uses, so the controllers stay short. */
public class Web {

    public static final String LOGIN_USER = "LOGIN_USER";   // session key of the signed-in user

    /** The request parameter, trimmed. An absent parameter gives an empty string, never null. */
    public static String trimmed(HttpServletRequest req, String name) {
        throw Todo.of("Web.trimmed");
    }

    /** The parameter as an int, or the default when it is absent or not a number. */
    public static int intParam(HttpServletRequest req, String name, int defaultValue) {
        throw Todo.of("Web.intParam");
    }

    /** The parameter as an Integer, or null when it is absent or not a number (used by filters). */
    public static Integer optionalInt(HttpServletRequest req, String name) {
        throw Todo.of("Web.optionalInt");
    }

    /** The signed-in user, or null. */
    public static User currentUser(HttpServletRequest req) {
        throw Todo.of("Web.currentUser");
    }

    /** One message for the next page; common/nav.jspf shows it once and removes it. */
    public static void flash(HttpSession session, String message, boolean bad) {
        throw Todo.of("Web.flash");
    }

    /** Number of pages for a total, at least 1. */
    public static int pages(int total, int pageSize) {
        throw Todo.of("Web.pages");
    }
}
