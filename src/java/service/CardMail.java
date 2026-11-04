package service;

import dao.DeviceAuthDao;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.servlet.http.HttpServletRequest;

/**
 * The e-mails of a card scan: the link that opens the slot (card_confirm) and the warning that the booking is at another
 * box (wrong_place). Each goes out on its own short thread: the box waits at most 6 s for its reply and SMTP may take 15 s.
 * Only the SHA-256 of a link is stored (RemoteCommand.confirm_hash).
 */
public final class CardMail {

    private static final Logger LOG = Logger.getLogger(CardMail.class.getName());
    public static final int CONFIRM_MIN = 5;                     // the wait of Device_Authorize
    private static final long WRONG_PLACE_GAP_MS = 600_000;      // one warning per booking in 10 minutes, however often it is scanned
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Map<Long, Long> WARNED = new ConcurrentHashMap<>();

    private CardMail() {
    }

    /** 256 random bits as 64 hex digits: the secret of a link. */
    public static String newToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return hex(bytes);
    }

    public static String hash(String token) {
        try {
            return hex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.US_ASCII)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);   // every JVM has SHA-256
        }
    }

    private static String hex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /** app.base_url, or the address the box used to reach this server (enough on the same network). */
    public static String baseUrl(MailService mail, HttpServletRequest req) {
        if (!mail.baseUrl().isEmpty()) {
            return mail.baseUrl();
        }
        boolean plainPort = req.getServerPort() == 80 || req.getServerPort() == 443;
        return req.getScheme() + "://" + req.getServerName() + (plainPort ? "" : ":" + req.getServerPort()) + req.getContextPath();
    }

    private static String text(Map<String, Object> row, String key) {
        Object v = row.get(key);
        return v == null ? "" : v.toString();
    }

    /** A CONFIRM_EMAIL row of Device_Authorize with an address. After a failed message the next scan sends again. */
    public static void sendConfirm(MailService mail, Map<String, Object> row, String token, String base) {
        String to = text(row, "mail_to");
        long command = ((Number) row.get("command_id")).longValue();
        Map<String, String> v = new LinkedHashMap<>();
        v.put("name", text(row, "mail_name"));
        v.put("slot_code", text(row, "slot_code"));
        v.put("bank_code", text(row, "right_bank"));
        v.put("area_name", text(row, "right_area"));
        v.put("action", action(text(row, "phase")));
        v.put("expires_min", String.valueOf(CONFIRM_MIN));
        v.put("confirm_url", base + "/c/" + token);
        send(mail, "card_confirm", to, v, "command " + command, () -> {
            try {
                new DeviceAuthDao().mailFailed(command);
            } catch (SQLException e) {
                LOG.log(Level.WARNING, "Cannot mark the e-mail of command " + command + " as failed: " + e.getMessage());
            }
        });
    }

    /** A WRONG_PLACE row of Device_Authorize with an address. */
    public static void sendWrongPlace(MailService mail, Map<String, Object> row, String base) throws IOException {
        long deposit = ((Number) row.get("right_deposit")).longValue();
        long now = System.currentTimeMillis();
        WARNED.values().removeIf(at -> now - at >= WRONG_PLACE_GAP_MS);
        if (WARNED.putIfAbsent(deposit, now) != null) {
            return;
        }
        Map<String, String> v = new LinkedHashMap<>();
        v.put("name", text(row, "mail_name"));
        v.put("slot_code", text(row, "right_slot"));
        v.put("bank_code", text(row, "right_bank"));
        v.put("area_name", text(row, "right_area"));
        // login=1 opens the sign-in popup for a visitor; once signed in, the map shows the booking and its waves
        v.put("map_url", base + "/LockerMapController?area=" + URLEncoder.encode(text(row, "right_area_code"), "UTF-8") + "&login=1");
        send(mail, "wrong_place", text(row, "mail_to"), v, "deposit " + deposit, () -> WARNED.remove(deposit));
    }

    /** What a scan will do, for the e-mail and for the page behind the link. */
    public static String action(String phase) {
        if ("PICKUP".equals(phase)) {
            return "lấy đồ và trả tủ (lượt thuê kết thúc)";
        }
        return "ACCESS".equals(phase) ? "mở ngăn (lượt thuê vẫn tiếp tục)" : "cất đồ vào ngăn";
    }

    private static void send(MailService mail, String template, String to, Map<String, String> values, String what, Runnable onFail) {
        Thread t = new Thread(() -> {
            try {
                MailTemplates.Message msg = MailTemplates.of(mail).render(template, values);
                mail.send(to, msg.subject, msg.body);
            } catch (IOException | RuntimeException e) {
                // the address is not logged; the id is enough to find it
                LOG.log(Level.WARNING, "E-mail " + template + " for " + what + " failed: " + e.getMessage());
                onFail.run();
            }
        }, "card-mail");
        t.setDaemon(true);
        t.start();
    }
}
