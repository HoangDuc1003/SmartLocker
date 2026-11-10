package api;

import com.google.gson.JsonObject;
import controller.KioskController;
import dao.DeviceAuthDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Map;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import service.AuthText;
import util.Web;

/**
 * v2, spec 4.5: the phone page behind the QR on the box. Public, no API key.
 *
 * PIN:    {"device_code":"LOCKER-01","pin":"482913","intent":"ASK"}   no login: the PIN is the secret, and the same
 *         5-tries lockout of the box protects it.
 * v7 tap: {"device_code":"LOCKER-01","method":"PHONE","tap":"Ab3dEf7hJk2m","intent":"ASK"}   needs the signed-in owner
 *         (session cookie, SameSite=Lax so another site cannot post it) and the token of the box's NFC tag, which proves
 *         the phone is at the box. A demo box has no reader and takes no token. Opens any open booking of the user there.
 * Reply:  as /api/device/auth, plus "command_id", with a Vietnamese message. A good try queues an UNLOCK the box takes
 *         with its heartbeat.
 * v6: "intent" works as at the box: ASK answers CHOOSE for a rented slot, then the page posts again with
 * OPEN (phase ACCESS, the booking stays) or CHECKOUT (PICKUP). No intent keeps the old PICKUP.
 */
@WebServlet(name = "KioskApi", urlPatterns = {"/api/kiosk/unlock"})
public class KioskApi extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        JsonObject body = ApiJson.body(req);
        String deviceCode = ApiJson.text(body, "device_code");
        String intent = DeviceAuthApi.intent(body);
        boolean phone = "PHONE".equals(ApiJson.text(body, "method"));
        String pin = ApiJson.text(body, "pin");
        String tap = ApiJson.text(body, "tap");
        if (deviceCode == null || "".equals(intent)) {
            ApiJson.error(res, 400, "BAD_REQUEST", "Sai dữ liệu.");
            return;
        }
        if (!phone && (pin == null || !pin.matches(DeviceAuthApi.PIN_FORMAT))) {
            ApiJson.error(res, 400, "BAD_REQUEST", "Mật mã gồm 6 chữ số.");
            return;
        }
        if (phone && tap != null && !tap.matches(KioskController.TAP_FORMAT)) {
            tap = null;                                    // a bad token is an expired one: Device_Authorize says TAP_EXPIRED
        }
        User me = Web.currentUser(req);
        if (phone && me == null) {
            ApiJson.error(res, 401, "NOT_SIGNED_IN", "Hãy đăng nhập để mở tủ bằng điện thoại.");
            return;
        }
        try {
            DeviceAuthDao dao = new DeviceAuthDao();
            Map<String, Object> device = dao.findDeviceByCode(deviceCode);
            if (device == null) {
                ApiJson.error(res, 404, "UNKNOWN_DEVICE", "Không tìm thấy hộp tủ này.");
                return;
            }
            int deviceId = (Integer) device.get("device_id");
            Map<String, Object> row = phone
                    ? dao.authorizeTap(deviceId, me.getUserId(), tap, intent)
                    : dao.authorize(deviceId, "PIN", pin, null, "PHONE", intent);
            JsonObject reply = DeviceAuthApi.reply(row, AuthText.phone(row));
            ApiJson.copyInt(row, "command_id", reply);
            ApiJson.write(res, 200, reply);
        } catch (SQLException e) {
            log("Kiosk unlock failed for " + deviceCode, e);
            ApiJson.error(res, 500, "SERVER_ERROR", "Lỗi máy chủ, hãy thử lại.");
        }
    }
}
