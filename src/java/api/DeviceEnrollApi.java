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
 * v2, spec 4.3: enrolling a card or a finger at the box with the 6-digit code shown on "Tủ của tôi".
 *
 * start:  {"type":"FINGERPRINT","enroll_code":"551204"}  ->  {"result":"OK","sensor_slot":7,"message":"Dat ngon tay\n2 lan"}
 * finish: {"type":"FINGERPRINT","enroll_code":"551204","sensor_slot":7}
 *         {"type":"CARD","enroll_code":"551204","card_uid":"04A1B2C3"}  ->  {"result":"OK","message":"Dang ky xong"}
 * Errors: {"result":"ERROR","reason":"BAD_CODE","message":"..."} with HTTP 200; 400 for a bad body.
 */
@WebServlet(name = "DeviceEnrollApi", urlPatterns = {"/api/device/enroll/start", "/api/device/enroll/finish"})
public class DeviceEnrollApi extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");
        boolean finish = req.getServletPath().endsWith("/finish");
        JsonObject body = ApiJson.body(req);
        String type = ApiJson.text(body, "type");
        String code = ApiJson.text(body, "enroll_code");
        if (!("CARD".equals(type) || "FINGERPRINT".equals(type)) || code == null || !code.matches(DeviceAuthApi.PIN_FORMAT)) {
            ApiJson.error(res, 400, "BAD_REQUEST", "Sai du lieu");
            return;
        }
        Integer sensorSlot = null;
        String uid = null;
        if (finish && "FINGERPRINT".equals(type)) {
            sensorSlot = ApiJson.integer(body, "sensor_slot");
            if (sensorSlot == null) {
                ApiJson.error(res, 400, "BAD_REQUEST", "Sai du lieu");
                return;
            }
        } else if (finish) {
            uid = ApiJson.text(body, "card_uid");
            uid = uid == null ? null : uid.toUpperCase();
            if (uid == null || !uid.matches(DeviceAuthApi.UID_FORMAT)) {
                ApiJson.error(res, 400, "BAD_REQUEST", "Sai du lieu");
                return;
            }
        }
        try {
            DeviceAuthDao dao = new DeviceAuthDao();
            Map<String, Object> row = finish
                    ? dao.enrollFinish(deviceId, type, code, sensorSlot, uid)
                    : dao.enrollStart(deviceId, type, code);
            JsonObject reply = new JsonObject();
            String result = String.valueOf(row.get("result"));
            reply.addProperty("result", result);
            if ("OK".equals(result)) {
                if (!finish && "FINGERPRINT".equals(type)) {
                    ApiJson.copyInt(row, "sensor_slot", reply);
                }
            } else {
                reply.addProperty("reason", (String) row.get("reason"));
                ApiJson.copyInt(row, "attempts_left", reply);
                ApiJson.copyInt(row, "retry_after_sec", reply);
            }
            reply.addProperty("message", AuthText.enroll(row, type, finish));
            ApiJson.write(res, 200, reply);
        } catch (SQLException e) {
            log("Enroll failed for device " + deviceId, e);
            ApiJson.error(res, 500, "SERVER_ERROR", "Loi may chu");
        }
    }
}
