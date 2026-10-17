package api;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;
import dao.DeviceDao;
import dao.LockerSessionDao;
import java.io.IOException;
import java.sql.SQLException;
import java.sql.Timestamp;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.LockerSession;
import service.AlertService;

/**
 * v2: open_source is PIN, PHONE, CARD, FINGERPRINT or REMOTE; command_id comes with PHONE and REMOTE opens.
 * Receives sessions in batches: the device sends everything it buffered while the network was down.
 * Safe to send twice: a session with the same (device, seq) is ignored by the UNIQUE constraint.
 *
 * Request: {"device_id":1,"sessions":[{"seq":101,"measured_at":"2026-10-15 03:15:20","door_open_sec":6.5,
 *           "weight_delta_g":2.0,"unlock_count":2,"rfid_ok":true,"stay_min":42.0,
 *           "slot_code":"A01","card_uid":"04A1B2C3","open_source":"RFID","command_id":null}]}
 * Reply:   {"saved":1,"duplicates":0,"rejected":0}   HTTP 500 when the database failed: the device keeps its buffer and retries.
 */
@WebServlet(name = "LockerSessionApi", urlPatterns = {"/api/locker/batch"})
public class LockerSessionApi extends HttpServlet {

    /** getAsBoolean() turns the number 1.0 into FALSE, so accept both forms. */
    private static boolean readBool(JsonObject json, String key) {
        JsonPrimitive p = json.getAsJsonPrimitive(key);
        return p.isBoolean() ? p.getAsBoolean() : p.getAsDouble() != 0;
    }

    private static String readString(JsonObject json, String key) {
        return json.has(key) && !json.get(key).isJsonNull() ? json.get(key).getAsString() : null;
    }

    private static LockerSession parse(JsonObject json, int deviceId) {
        LockerSession s = new LockerSession();
        s.setDeviceId(deviceId);                                  // from the API key, never from the body
        s.setDeviceSeq(json.get("seq").getAsInt());
        s.setMeasuredAt(Timestamp.valueOf(json.get("measured_at").getAsString()));   // "yyyy-MM-dd HH:mm:ss", UTC
        s.setDoorOpenSec(json.get("door_open_sec").getAsDouble());
        s.setWeightDeltaG(json.get("weight_delta_g").getAsDouble());
        s.setUnlockCount(json.get("unlock_count").getAsInt());
        s.setRfidOk(readBool(json, "rfid_ok"));
        s.setStayMin(json.get("stay_min").getAsDouble());
        s.setSlotCode(readString(json, "slot_code"));
        s.setCardUid(readString(json, "card_uid"));
        String source = readString(json, "open_source");
        s.setOpenSource(source == null ? "RFID" : source);
        s.setCommandId(json.has("command_id") && !json.get("command_id").isJsonNull() ? json.get("command_id").getAsLong() : null);
        return s;
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // insert each session and evaluate it; count saved, duplicate and rejected
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");
        JsonObject body = ApiJson.body(req);
        JsonArray sessions = body != null && body.has("sessions") && body.get("sessions").isJsonArray()
                ? body.getAsJsonArray("sessions") : null;
        if (sessions == null) {
            ApiJson.error(res, HttpServletResponse.SC_BAD_REQUEST, "BAD_REQUEST", "Sai du lieu");   // body must be {"sessions":[...]}
            return;
        }
        LockerSessionDao dao = new LockerSessionDao();
        int saved = 0, duplicates = 0, rejected = 0;
        try {
            for (JsonElement element : sessions) {
                LockerSession s;
                try {
                    s = parse(element.getAsJsonObject(), deviceId);
                } catch (RuntimeException bad) {
                    rejected++;                                   // a malformed session is skipped, the others go on
                    continue;
                }
                long id = dao.insert(s);
                if (id < 0) {
                    duplicates++;
                    continue;
                }
                s.setSessionId(id);
                saved++;
                try {
                    new AlertService().evaluate(s);
                } catch (SQLException e) {
                    log("Alert evaluation failed for session " + id, e);   // the session is stored; do not make the device resend it
                }
                // v2: the booking ends at /api/device/auth (phase PICKUP), a batch only keeps the history
            }
            new DeviceDao().heartbeat(deviceId);                  // a batch also proves the device is alive
        } catch (SQLException e) {
            log("Batch insert failed", e);
            ApiJson.error(res, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "SERVER_ERROR", "Loi may chu");
            return;
        }
        JsonObject reply = new JsonObject();
        reply.addProperty("saved", saved);
        reply.addProperty("duplicates", duplicates);
        reply.addProperty("rejected", rejected);
        ApiJson.write(res, 200, reply);
    }
}
