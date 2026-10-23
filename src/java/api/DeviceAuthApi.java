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
 * v2, spec 4.2: a code, a card or a finger at the box. The server decides "open" or "not open"; the box has one latch.
 *
 * Request: {"method":"PIN","pin":"482913"} | {"method":"CARD","card_uid":"04A1B2C3"} | {"method":"FINGERPRINT","sensor_slot":7}
 * Reply:   {"result":"UNLOCK","phase":"CHECK_IN","deposit_id":120,"slot_code":"A04","open_sec":8,"message":"Moi cat do\nNgan A04"}
 *          {"result":"DENY","reason":"WRONG_CODE","attempts_left":3,"retry_after_sec":0,"message":"Sai ma\nCon 3 lan"}
 *          v3: {"result":"DENY","reason":"OVERDUE_UNPAID","deposit_id":120,"debt":9700,"overdue_fee":14700,...}
 * HTTP 200 for every decision, 400 for a bad body, 401 for a bad key (SecurityFilter), 500 when the database failed.
 */
@WebServlet(name = "DeviceAuthApi", urlPatterns = {"/api/device/auth"})
public class DeviceAuthApi extends HttpServlet {

    static final String PIN_FORMAT = "\\d{6}";
    static final String UID_FORMAT = "[0-9A-F]{4,20}";

    /** The JSON reply of a Device_Authorize row; message is for the OLED or the phone. */
    static JsonObject reply(Map<String, Object> row, String message) {
        JsonObject reply = new JsonObject();
        String result = String.valueOf(row.get("result"));
        reply.addProperty("result", result);
        if ("UNLOCK".equals(result)) {
            reply.addProperty("phase", (String) row.get("phase"));
            ApiJson.copyInt(row, "deposit_id", reply);
            reply.addProperty("slot_code", (String) row.get("slot_code"));
            reply.addProperty("open_sec", AuthText.OPEN_SEC);
            if ("PICKUP".equals(row.get("phase"))) {
                ApiJson.copyInt(row, "overdue_fee", reply);     // v3: the late fee of the booking, 0 when on time
            }
        } else {
            reply.addProperty("reason", (String) row.get("reason"));
            ApiJson.copyInt(row, "attempts_left", reply);
            ApiJson.copyInt(row, "retry_after_sec", reply);
            if ("OVERDUE_UNPAID".equals(row.get("reason"))) {  // v3: what the owner still owes
                ApiJson.copyInt(row, "deposit_id", reply);
                ApiJson.copyInt(row, "debt", reply);
                ApiJson.copyInt(row, "overdue_fee", reply);
            }
        }
        reply.addProperty("message", message);
        return reply;
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // check the shape, then one procedure call decides and counts
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");   // from the API key, never from the body
        JsonObject body = ApiJson.body(req);
        String method = ApiJson.text(body, "method");
        String pin = null, uid = null;
        Integer sensorSlot = null;
        if ("PIN".equals(method)) {
            pin = ApiJson.text(body, "pin");
            if (pin == null || !pin.matches(PIN_FORMAT)) {
                ApiJson.error(res, 400, "BAD_REQUEST", "Sai du lieu");
                return;
            }
        } else if ("CARD".equals(method)) {
            uid = ApiJson.text(body, "card_uid");
            uid = uid == null ? null : uid.toUpperCase();
            if (uid == null || !uid.matches(UID_FORMAT)) {
                ApiJson.error(res, 400, "BAD_REQUEST", "Sai du lieu");
                return;
            }
        } else if ("FINGERPRINT".equals(method)) {
            sensorSlot = ApiJson.integer(body, "sensor_slot");
            if (sensorSlot == null || sensorSlot < 1 || sensorSlot > 160) {
                ApiJson.error(res, 400, "BAD_REQUEST", "Sai du lieu");
                return;
            }
        } else {
            ApiJson.error(res, 400, "BAD_REQUEST", "Sai du lieu");
            return;
        }
        try {
            Map<String, Object> row = new DeviceAuthDao().authorize(deviceId, method, pin, uid, sensorSlot, "DEVICE");
            ApiJson.write(res, 200, reply(row, AuthText.oled(row)));
        } catch (SQLException e) {
            log("Device auth failed for device " + deviceId, e);
            ApiJson.error(res, 500, "SERVER_ERROR", "Loi may chu");
        }
    }
}
