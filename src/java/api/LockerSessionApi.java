package api;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonPrimitive;
import dao.DepositDao;
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

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: JSON readers: a boolean may arrive as true or as 1.0, and one bad session must not drop the batch

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // insert each session, evaluate it, then free the slot; count saved, duplicate and rejected
        res.sendError(HttpServletResponse.SC_NOT_IMPLEMENTED, "TODO LockerSessionApi.doPost");
    }
}
