package api;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonNull;
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
 *          optional "bank_code":"CANT-A" per session: needed only when the box manages two banks with the same slot code
 *          (a PHONE/REMOTE session is matched through its command_id instead).
 * Reply:   {"saved":1,"duplicates":0,"rejected":0,"errors":[]}   HTTP 500 when the database failed: the device keeps
 *          its buffer and retries. A malformed session, or one whose slot code fits two banks of the box, is skipped:
 *          it counts as rejected and is listed in errors as {"seq":101,"code":"BAD_SESSION"|"AMBIGUOUS_SLOT"}
 *          (resending it would fail the same way, so it must never turn into a 500).
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
        String bank = readString(json, "bank_code");
        s.setBankCode(bank == null || bank.trim().isEmpty() ? null : bank.trim());   // "" means "not sent"

        s.setCardUid(readString(json, "card_uid"));
        String source = readString(json, "open_source");
        s.setOpenSource(source == null ? "RFID" : source);
        s.setCommandId(json.has("command_id") && !json.get("command_id").isJsonNull() ? json.get("command_id").getAsLong() : null);
        return s;
    }

    /** One entry of the reply's errors list; seq is null when the session has none we can read. */
    private static JsonObject error(JsonElement element, String code) {
        JsonObject e = new JsonObject();
        JsonElement seq = element.isJsonObject() ? element.getAsJsonObject().get("seq") : null;
        if (seq != null && seq.isJsonPrimitive()) {
            e.add("seq", seq);
        } else {
            e.add("seq", JsonNull.INSTANCE);
        }
        e.addProperty("code", code);
        return e;
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
        JsonArray errors = new JsonArray();
        try {
            for (JsonElement element : sessions) {
                LockerSession s;
                try {
                    s = parse(element.getAsJsonObject(), deviceId);
                } catch (RuntimeException bad) {
                    rejected++;                                   // a malformed session is skipped, the others go on
                    errors.add(error(element, "BAD_SESSION"));
                    continue;
                }
                long id = dao.insert(s);
                // A rejected session still gets a 200 batch reply: the device clears its buffer only on 200, and
                // re-sending the same session can never fix it (the slot/bank data is wrong, not the transport),
                // so a non-200 would make it resend the whole buffer forever. The code in `errors` and the log
                // line tell the operator; LockerBankDao refuses bank assignments that would repeat a slot code.
                if (id == LockerSessionDao.UNKNOWN_BANK) {
                    rejected++;
                    errors.add(error(element, "UNKNOWN_BANK"));
                    log("Session seq " + s.getDeviceSeq() + " of device " + deviceId + ": bank_code "
                            + s.getBankCode() + " is not a bank of the device");
                    continue;
                }
                if (id == LockerSessionDao.AMBIGUOUS_SLOT) {
                    rejected++;
                    errors.add(error(element, "AMBIGUOUS_SLOT"));
                    log("Session seq " + s.getDeviceSeq() + " of device " + deviceId + ": slot " + s.getSlotCode()
                            + " is in more than one bank of the device; send bank_code");
                    continue;
                }
                if (id == LockerSessionDao.DUPLICATE) {
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
        reply.add("errors", errors);
        ApiJson.write(res, 200, reply);
    }
}
