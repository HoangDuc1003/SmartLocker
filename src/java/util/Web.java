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
     * The glass interface (full-screen map, "Tủ của tôi" and "Nạp tiền" as popups) is for the users and the visitors;
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

    /** Vietnamese text of the business errors the stored procedures THROW (50000+); other errors keep their own text. */
    private static final java.util.Map<String, String> SQL_MESSAGES = new java.util.HashMap<>();
    static {
        String[][] pairs = {
            {"This slot has no device", "Ngăn tủ này chưa gắn thiết bị"},
            {"Device is not online, the command cannot be delivered", "Thiết bị đang mất kết nối, không gửi được lệnh"},
            {"Another operator is controlling this device", "Một nhân viên khác đang điều khiển thiết bị này"},
            {"A reason of at least 5 characters is required", "Cần nhập lý do ít nhất 5 ký tự"},
            {"Card not found, not yours, or already reported", "Không tìm thấy thẻ, thẻ không phải của bạn hoặc đã báo mất"},
            {"Only a lost or blocked card can be replaced", "Chỉ đổi được thẻ đã báo mất hoặc bị khóa"},
            {"Insufficient balance. Add funds before booking.", "Số dư không đủ. Hãy nạp tiền trước khi đặt tủ."},
            {"Booking is blocked: 3 no-shows in the last 7 days", "Bạn bị tạm khóa đặt tủ: 3 lần không đến trong 7 ngày qua"},
            {"You already have a booking in progress", "Bạn đang có một lượt đặt chưa kết thúc"},
            {"This slot is no longer available", "Ngăn tủ này không còn trống"},
            {"This storage plan is not available", "Gói gửi đồ này không còn áp dụng"},
            {"The locker is offline, booking is paused", "Tủ đang mất kết nối, tạm ngừng nhận đặt"},
            {"Nothing to cancel: not your reservation, or it already started", "Không hủy được: không phải lượt đặt của bạn hoặc đã bắt đầu"},
            {"You can add between 15 and 240 minutes", "Chỉ gia hạn được từ 15 đến 240 phút"},
            {"Nothing to extend: not your active booking", "Không gia hạn được: không phải lượt gửi đang dùng của bạn"},
            {"A booking can be extended 3 times at most", "Mỗi lượt gửi chỉ gia hạn tối đa 3 lần"},
            {"The storage plan has an invalid price", "Gói gửi đồ có giá không hợp lệ"},
            {"Ticket not found or already closed", "Không tìm thấy phiếu hoặc phiếu đã đóng"},
            {"Alert not found or already resolved", "Không tìm thấy cảnh báo hoặc cảnh báo đã xử lý"},
            // v2 (sql/03_v2_v3.sql)
            {"Insufficient balance for the price and the card deposit", "Số dư không đủ cho giá gói và tiền cọc thẻ. Hãy nạp thêm tiền."},
            {"Choose how to open the locker: PIN, card or fingerprint", "Hãy chọn cách mở tủ: mật mã, thẻ từ hoặc vân tay"},
            {"Could not create a unique code, try again", "Không tạo được mã, hãy thử lại"},
            {"This booking has nothing to enroll", "Lượt đặt này không cần đăng ký thẻ hoặc vân tay"},
            {"Fingerprint not found or not yours", "Không tìm thấy vân tay hoặc vân tay không phải của bạn"},
            // v3 (sql/03_v2_v3.sql)
            {"After booking at least 10,000 VND must stay in the wallet", "Sau khi đặt, ví phải còn ít nhất 10.000 đ để dự phòng phụ phí quá hạn. Hãy nạp thêm tiền."},
            {"The 5 minutes to cancel are over", "Đã quá 5 phút kể từ lúc đặt nên không hủy được nữa."},
            {"The booking is overdue and locked, it cannot be extended", "Lượt gửi đã quá hạn và tủ đang bị khóa nên không gia hạn được. Hãy nạp tiền và tới lấy đồ."},
            {"Insufficient balance to extend", "Số dư không đủ để gia hạn. Hãy nạp thêm tiền."},
            // "Tự chọn" (custom duration)
            {"Choose whole hours or whole days within the limits", "Thời gian tự chọn không hợp lệ: chọn số giờ hoặc số ngày trong giới hạn cho phép."},
            {"Custom duration is not available now", "Hiện chưa đặt được thời gian tự chọn (chưa có gói trọn ngày). Hãy chọn một gói có sẵn."},
        };
        for (String[] p : pairs) {
            SQL_MESSAGES.put(p[0], p[1]);
        }
    }

    public static String sqlMessage(java.sql.SQLException e) {
        String text = e.getMessage() == null ? "" : e.getMessage().trim();
        String vi = SQL_MESSAGES.get(text);
        return vi != null ? vi : text;
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
