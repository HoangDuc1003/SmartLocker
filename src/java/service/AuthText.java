package service;

import java.util.Map;

/**
 * The texts of the v2 device replies. OLED: plain ASCII, at most 2 lines of 16 characters,
 * printed as they come. Phone page (/k): full English sentences.
 */
public final class AuthText {

    public static final int OPEN_SEC = 8;   // the latch closes by itself after 8 seconds

    private AuthText() {
    }

    private static int num(Map<String, Object> row, String key) {
        Object v = row.get(key);
        return v instanceof Number ? ((Number) v).intValue() : 0;
    }

    private static long lng(Map<String, Object> row, String key) {
        Object v = row.get(key);
        return v instanceof Number ? ((Number) v).longValue() : 0;
    }

    /** 14700 -> "14,700 VND" */
    public static String vnd(long amount) {
        return String.format(java.util.Locale.US, "%,d VND", amount);
    }

    /** "1 try left" / "3 tries left" (fits the 16 characters of the OLED). */
    private static String tries(int n) {
        return n + (n == 1 ? " try left" : " tries left");
    }

    private static String str(Map<String, Object> row, String key) {
        Object v = row.get(key);
        return v == null ? "" : v.toString();
    }

    /** Message of a Device_Authorize row for the OLED. */
    public static String oled(Map<String, Object> row) {
        String reason = str(row, "reason");
        if ("CHOOSE".equals(str(row, "result"))) {
            return "A: Open * cancel\nB: Checkout " + str(row, "slot_code");
        }
        if ("CONFIRM_EMAIL".equals(str(row, "result"))) {
            return "Confirm in your\ne-mail or web";
        }
        if ("UNLOCK".equals(str(row, "result"))) {
            String slot = str(row, "slot_code");
            String phase = str(row, "phase");
            String first ="PICKUP".equals(phase) ? "Take your items" : "ACCESS".equals(phase) ? "Open the door" : "Store your items";
            return first + "\nSlot " + slot;
        }
        switch (reason) {
            case "WRONG_CODE":
                return num(row, "attempts_left") > 0 ? "Wrong PIN\n" + tries(num(row, "attempts_left")) : "Wrong PIN\nLocked 2 min";
            case "UNKNOWN_CARD":
                return num(row, "attempts_left") > 0 ? "Unknown card" : "Unknown card\nLocked 2 min";
            case "UNKNOWN_FINGER":
                return num(row, "attempts_left") > 0 ? "Unknown\nfingerprint" : "Unknown finger\nLocked 2 min";
            case "LOCKED_OUT":
                return "Locked\nWait " + num(row, "retry_after_sec") + " s";
            case "NO_BOOKING":
                return "No booking at\nthis box";
            case "WRONG_PLACE":
                return "Wrong box! Go to\n" + str(row, "right_bank");
            case "METHOD_MISMATCH":
                return "Wrong method\n" + oledMethod(str(row, "open_method"));
            case "CARD_BLOCKED":
                return "Card is blocked";
            case "EXPIRED":
                return "Booking\nexpired";
            case "ACCOUNT_LOCKED":
                return "Account\nis locked";
            case "OVERDUE_UNPAID":
                return "Overdue\nTop up to open";
            default:
                return "Denied";
        }
    }

    private static String oledMethod(String method) {
        if ("CARD".equals(method)) {
            return "Scan your card";
        }
        if ("PHONE".equals(method)) {
            return "Tap your phone";
        }
        if ("FINGERPRINT".equals(method)) {
            return "Use fingerprint";
        }
        return "Enter your PIN";
    }

    /** Message of a Device_Authorize row for the phone page. */
    public static String phone(Map<String, Object> row) {
        String reason = str(row, "reason");
        if ("CHOOSE".equals(str(row, "result"))) {
            return "Slot " + str(row, "slot_code") + " is in your booking. Choose Open to take or store things, "
                    + "or Check out to take everything and end the booking.";
        }
        if ("UNLOCK".equals(str(row, "result"))) {
            String slot = str(row, "slot_code");
            String phase = str(row, "phase");
            if ("ACCESS".equals(phase)) {
                return "The box opens in a few seconds. Slot " + slot + " is still yours; close the door and the booking goes on.";
            }
            return "PICKUP".equals(phase)
                    ? "The box opens in a few seconds. Take your things from slot " + slot + "; the booking will end."
                    : "The box opens in a few seconds. Put your things in slot " + slot + ".";
        }
        switch (reason) {
            case "WRONG_CODE":
                return num(row, "attempts_left") > 0
                        ? "Wrong PIN. " + tries(num(row, "attempts_left")) + "."
                        : "Wrong PIN. This page is locked for 2 minutes.";
            case "LOCKED_OUT":
                return "This page is locked for now. Try again in " + num(row, "retry_after_sec") + " seconds.";
            case "EXPIRED":
                return "The hold time of this booking is over.";
            case "ACCOUNT_LOCKED":
                return "Your account is locked.";
            case "OVERDUE_UNPAID":
                return "The locker is overdue and locked. You owe " + vnd(lng(row, "debt"))
                        + ". Top up your wallet, then open it again.";
            case "DEVICE_OFFLINE":
                return "The box is offline, so it cannot open now. Try again in a few minutes or ask the staff.";
            case "METHOD_MISMATCH":
                return "This booking does not use a PIN. Use the open method you chose, or sign in and tap your phone on the box.";
            case "TAP_EXPIRED":
                return "The tap link has expired or was already used. Tap your phone on the NFC reader of the box again.";
            case "NOT_SIGNED_IN":
                return "Sign in to open the locker with your phone.";
            case "NO_BOOKING":
                return "You have no open booking at this box.";
            case "WRONG_PLACE":
                return "Your locker is not at this box: it is slot " + str(row, "right_slot") + ", bank " + str(row, "right_bank")
                        + " (" + str(row, "right_area") + ").";
            default:
                return "The locker could not be opened.";
        }
    }

    /** Message of an Enroll_Start or Enroll_Finish row for the OLED. */
    public static String enroll(Map<String, Object> row, String type, boolean finish) {
        if ("OK".equals(str(row, "result"))) {
            if (finish) {
                return "Enrolled";
            }
            return "CARD".equals(type) ? "Scan the card" : "Place finger\ntwice";
        }
        switch (str(row, "reason")) {
            case "BAD_CODE":
                return num(row, "attempts_left") > 0 ? "Bad enroll code" : "Bad enroll code\nLocked 2 min";
            case "CODE_EXPIRED":
                return "Code expired";
            case "CARD_IN_USE":
                return "Card belongs to\nsomeone else";
            case "SENSOR_FULL":
                return "Fingerprint\nmemory full";
            case "BAD_SLOT":
                return "Bad fingerprint\nslot";
            case "BAD_UID":
                return "Card read error";
            case "LOCKED_OUT":
                return "Locked\nWait " + num(row, "retry_after_sec") + " s";
            default:
                return "Enroll failed";
        }
    }
}
