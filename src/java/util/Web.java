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

    public static Integer optionalInt(HttpServletRequest req, String name) {
        try {
            return Integer.valueOf(trimmed(req, name));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** The parameter as a long, or the default when it is absent or not a number. */
    public static long longParam(HttpServletRequest req, String name, long defaultValue) {
        try {
            return Long.parseLong(trimmed(req, name));
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    /** True when the caller is the page script (fetch) and wants JSON instead of a redirect or a page. */
    public static boolean wantsJson(HttpServletRequest req) {
        String accept = req.getHeader("Accept");
        return accept != null && accept.contains("application/json");
    }

    /** {"ok":true} or {"ok":false,"error":"..."} for the login and sign-up popup. */
    public static void writeJson(javax.servlet.http.HttpServletResponse res, int status, String error) throws java.io.IOException {
        res.setStatus(status);
        res.setContentType("application/json;charset=UTF-8");
        res.setHeader("Cache-Control", "no-store");
        com.google.gson.JsonObject o = new com.google.gson.JsonObject();
        o.addProperty("ok", error == null);
        if (error != null) {
            o.addProperty("error", error);
        }
        res.getWriter().write(o.toString());
    }

    /** The signed-in user, or null. */
    public static User currentUser(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        return session == null ? null : (User) session.getAttribute(LOGIN_USER);
    }

    /**
     * There is no login page: signing in and signing up happen in the popup of the map page (js/auth-modal.js).
     * This is the map address that opens the popup on the "login" or "register" tab; next is the path to go back
     * to after a sign-in (null: stay on the map).
     */
    public static String signInUrl(HttpServletRequest req, String tab, String next) {
        StringBuilder url = new StringBuilder(req.getContextPath()).append("/LockerMapController?")
                .append("register".equals(tab) ? "register" : "login").append("=1");
        if (next != null && next.startsWith("/") && !next.startsWith("//")) {
            try {
                url.append("&next=").append(java.net.URLEncoder.encode(next, "UTF-8"));
            } catch (java.io.UnsupportedEncodingException e) {
                throw new IllegalStateException(e);   // UTF-8 is always there
            }
        }
        return url.toString();
    }

    /**
     * The glass interface (full-screen map, "My locker" and "Top up" as popups) is for the users and the visitors;
     * the staff roles keep the pages with the sidebar.
     */
    public static boolean isUserView(User me) {
        return me == null || "END_USER".equals(me.getRoleName());
    }

    /** One message for the next page; common/nav.jspf shows it once and removes it. */
    public static void flash(HttpSession session, String message, boolean bad) {
        session.setAttribute("flash", message);
        session.setAttribute("flashBad", bad);
    }

    /** The text shown to users for the business errors the stored procedures THROW (50000+); other errors keep their own text. */
    private static final java.util.Map<String, String> SQL_MESSAGES = new java.util.HashMap<>();
    static {
        String[][] pairs = {
            {"This slot has no device", "This slot has no locker box attached."},
            {"Device is not online, the command cannot be delivered", "The box is offline, so the command cannot be sent."},
            {"Another operator is controlling this device", "Another staff member is controlling this box."},
            {"A reason of at least 5 characters is required", "Enter a reason of at least 5 characters."},
            {"Card not found, not yours, or already reported", "Card not found, not yours, or already reported lost."},
            {"Only a lost or blocked card can be replaced", "Only a card reported lost or blocked can be replaced."},
            {"Insufficient balance. Add funds before booking.", "Insufficient balance. Top up your wallet before booking."},
            {"Booking is blocked: 3 no-shows in the last 7 days", "Booking is paused for you: 3 no-shows in the last 7 days."},
            {"You already have a booking in progress", "You already have a booking that has not ended."},
            {"This slot is no longer available", "This slot is no longer available."},
            {"This storage plan is not available", "This storage plan is no longer offered."},
            {"The locker is offline, booking is paused", "The locker is offline, booking is paused."},
            {"Nothing to cancel: not your reservation, or it already started", "Cannot cancel: not your booking, or it has already started."},
            {"You can add between 15 and 240 minutes", "You can extend by 15 to 240 minutes only."},
            {"Nothing to extend: not your active booking", "Cannot extend: this is not your active booking."},
            {"A booking can be extended 3 times at most", "A booking can be extended 3 times at most."},
            {"The storage plan has an invalid price", "The storage plan has an invalid price."},
            {"Ticket not found or already closed", "Ticket not found or already closed."},
            {"Alert not found or already resolved", "Alert not found or already resolved."},
            // v2 (sql/03_v2_v3.sql)
            {"Choose how to open the locker: PIN, card, phone or fingerprint", "Choose how to open the locker: PIN, card, phone or fingerprint."},
            {"Could not create a unique code, try again", "Could not create a code, please try again."},
            {"This booking has nothing to enroll", "This booking does not need a card or fingerprint enrollment."},
            {"Fingerprint not found or not yours", "Fingerprint not found or not yours."},
            // v3 (sql/03_v2_v3.sql)
            {"After booking at least 10,000 VND must stay in the wallet", "After booking, at least 10,000 VND must stay in your wallet to cover late fees. Please top up."},
            {"The hold is over, the booking can no longer be cancelled", "The hold time is over, so the booking can no longer be cancelled."},
            {"The free cancel time just ended, the refund is lower now", "The full-refund cancel time just ended, so the refund is lower now. The booking was not cancelled; check the amount and cancel again."},
            {"The booking is overdue and locked, it cannot be extended", "The booking is overdue and the locker is locked, so it cannot be extended. Top up and come to pick up your things."},
            {"Insufficient balance to extend", "Insufficient balance to extend. Please top up."},
            // "Custom" duration
            {"Choose whole hours or whole days within the limits", "Invalid custom duration: choose whole hours or whole days within the limits."},
            {"Custom duration is not available now", "A custom duration cannot be booked now (there is no day pass plan). Please choose one of the plans."},
        };
        for (String[] p : pairs) {
            SQL_MESSAGES.put(p[0], p[1]);
        }
    }

    public static String sqlMessage(java.sql.SQLException e) {
        String text = e.getMessage() == null ? "" : e.getMessage().trim();
        String shown = SQL_MESSAGES.get(text);
        return shown != null ? shown : text;
    }

    /** v3: an optional e-mail address: empty, or one plain address of at most 150 characters. */
    public static boolean isEmail(String email) {
        return email != null && email.length() <= 150
                && email.matches("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    }

    /** Number of pages for a total, at least 1. */
    public static int pages(int total, int pageSize) {
        return Math.max(1, (total + pageSize - 1) / pageSize);
    }
}
