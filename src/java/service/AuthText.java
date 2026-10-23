package service;

import java.util.Map;

/**
 * The texts of the v2 device replies. OLED: ASCII without diacritics, at most 2 lines of 16 characters,
 * printed as they come. Phone page (/k): Vietnamese with diacritics.
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

    /** 14700 -> "14.700 đ" */
    public static String vnd(long amount) {
        return String.format(java.util.Locale.ROOT, "%,d", amount).replace(',', '.') + " đ";
    }

    private static String str(Map<String, Object> row, String key) {
        Object v = row.get(key);
        return v == null ? "" : v.toString();
    }

    /** Message of a Device_Authorize row for the OLED. */
    public static String oled(Map<String, Object> row) {
        String reason = str(row, "reason");
        if ("UNLOCK".equals(str(row, "result"))) {
            String slot = str(row, "slot_code");
            return ("PICKUP".equals(str(row, "phase")) ? "Moi lay do" : "Moi cat do") + "\nNgan " + slot;
        }
        switch (reason) {
            case "WRONG_CODE":
                return num(row, "attempts_left") > 0 ? "Sai ma\nCon " + num(row, "attempts_left") + " lan" : "Sai ma\nKhoa 2 phut";
            case "UNKNOWN_CARD":
                return num(row, "attempts_left") > 0 ? "The chua dang ky" : "The chua dang ky\nKhoa 2 phut";
            case "UNKNOWN_FINGER":
                return num(row, "attempts_left") > 0 ? "Van tay chua\ndang ky" : "Van tay chua DK\nKhoa 2 phut";
            case "LOCKED_OUT":
                return "Tam khoa\nCho " + num(row, "retry_after_sec") + " giay";
            case "NO_BOOKING":
                return "Khong co luot\ndat o hop nay";
            case "METHOD_MISMATCH":
                return "Sai cach mo\n" + oledMethod(str(row, "open_method"));
            case "CARD_BLOCKED":
                return "The da bi khoa";
            case "EXPIRED":
                return "Luot dat\nda het han";
            case "ACCOUNT_LOCKED":
                return "Tai khoan\ndang bi khoa";
            case "OVERDUE_UNPAID":
                return "Qua han tra tu\nNap tien de mo";
            default:
                return "Tu choi";
        }
    }

    private static String oledMethod(String method) {
        if ("CARD".equals(method)) {
            return "Hay quet the";
        }
        if ("FINGERPRINT".equals(method)) {
            return "Hay dung van tay";
        }
        return "Hay nhap ma PIN";
    }

    /** Message of a Device_Authorize row for the phone page. */
    public static String phone(Map<String, Object> row) {
        String reason = str(row, "reason");
        if ("UNLOCK".equals(str(row, "result"))) {
            String slot = str(row, "slot_code");
            return "PICKUP".equals(str(row, "phase"))
                    ? "Hộp sẽ mở trong vài giây. Mời lấy đồ ở ngăn " + slot + ", lượt gửi sẽ kết thúc."
                    : "Hộp sẽ mở trong vài giây. Mời cất đồ vào ngăn " + slot + ".";
        }
        switch (reason) {
            case "WRONG_CODE":
                return num(row, "attempts_left") > 0
                        ? "Sai mật mã. Còn " + num(row, "attempts_left") + " lần thử."
                        : "Sai mật mã. Trang này tạm khóa nhập trong 2 phút.";
            case "LOCKED_OUT":
                return "Trang này đang tạm khóa nhập. Thử lại sau " + num(row, "retry_after_sec") + " giây.";
            case "EXPIRED":
                return "Lượt đặt đã quá thời gian giữ chỗ.";
            case "ACCOUNT_LOCKED":
                return "Tài khoản đang bị khóa.";
            case "OVERDUE_UNPAID":
                return "Tủ đã quá hạn và đang bị khóa. Bạn còn nợ " + vnd(lng(row, "debt"))
                        + ". Hãy nạp tiền vào ví rồi mở lại.";
            case "DEVICE_OFFLINE":
                return "Hộp đang mất kết nối nên chưa mở được. Hãy nhập mật mã trên bàn phím của hộp.";
            case "METHOD_MISMATCH":
                return "Lượt đặt này không dùng mật mã.";
            default:
                return "Không mở được tủ.";
        }
    }

    /** Message of an Enroll_Start or Enroll_Finish row for the OLED. */
    public static String enroll(Map<String, Object> row, String type, boolean finish) {
        if ("OK".equals(str(row, "result"))) {
            if (finish) {
                return "Dang ky xong";
            }
            return "CARD".equals(type) ? "Quet the" : "Dat ngon tay\n2 lan";
        }
        switch (str(row, "reason")) {
            case "BAD_CODE":
                return num(row, "attempts_left") > 0 ? "Ma dang ky sai" : "Ma dang ky sai\nKhoa 2 phut";
            case "CODE_EXPIRED":
                return "Ma da het han";
            case "CARD_IN_USE":
                return "The da thuoc\nnguoi khac";
            case "SENSOR_FULL":
                return "Bo nho van tay\nda day";
            case "INSUFFICIENT_BALANCE":
                return "Khong du tien\ncoc 30000d";
            case "BAD_SLOT":
                return "Vi tri van tay\nkhong hop le";
            case "BAD_UID":
                return "Doc the loi";
            case "LOCKED_OUT":
                return "Tam khoa\nCho " + num(row, "retry_after_sec") + " giay";
            default:
                return "Loi dang ky";
        }
    }
}
