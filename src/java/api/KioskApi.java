package api;

import com.google.gson.JsonObject;
import dao.DeviceAuthDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Map;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import service.AuthText;

/**
 * v2, spec 4.5: the phone page behind the QR on the box. Public, no login and no API key: the PIN is the secret,
 * and the same 5-tries lockout of the box protects it. A good PIN queues an UNLOCK the box takes with its heartbeat.
 *
 * Request: {"device_code":"LOCKER-01","pin":"482913","intent":"ASK"}
 * Reply:   as /api/device/auth, plus "command_id", with a Vietnamese message.
 * v6: "intent" works as at the box: ASK answers CHOOSE for a rented slot, then the page posts the PIN again with
 * OPEN (phase ACCESS, the booking stays) or CHECKOUT (PICKUP). No intent keeps the old PICKUP.
 */
@WebServlet(name = "KioskApi", urlPatterns = {"/api/kiosk/unlock"})
public class KioskApi extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        JsonObject body = ApiJson.body(req);
        String deviceCode = ApiJson.text(body, "device_code");
        String pin = ApiJson.text(body, "pin");
        String intent = DeviceAuthApi.intent(body);
        if (deviceCode == null || pin == null || !pin.matches(DeviceAuthApi.PIN_FORMAT) || "".equals(intent)) {
            ApiJson.error(res, 400, "BAD_REQUEST", "Mật mã gồm 6 chữ số.");
            return;
        }
        try {
            DeviceAuthDao dao = new DeviceAuthDao();
            Map<String, Object> device = dao.findDeviceByCode(deviceCode);
            if (device == null) {
                ApiJson.error(res, 404, "UNKNOWN_DEVICE", "Không tìm thấy hộp tủ này.");
                return;
            }
            Map<String, Object> row = dao.authorize((Integer) device.get("device_id"), "PIN", pin, null, null, "PHONE", intent);
            JsonObject reply = DeviceAuthApi.reply(row, AuthText.phone(row));
            ApiJson.copyInt(row, "command_id", reply);
            ApiJson.write(res, 200, reply);
        } catch (SQLException e) {
            log("Kiosk unlock failed for " + deviceCode, e);
            ApiJson.error(res, 500, "SERVER_ERROR", "Lỗi máy chủ, hãy thử lại.");
        }
    }
}
