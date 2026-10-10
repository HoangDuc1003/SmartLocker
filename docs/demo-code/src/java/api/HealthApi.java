package api;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import dao.DepositDao;
import dao.DeviceDao;
import dao.RemoteCommandDao;
import dao.UserCardDao;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 * The heartbeat. The device calls it every 10 seconds, the reply is the only way the server talks to the device:
 * pending unlock commands, cards that must be refused, reservations. The server never calls the device,
 * so it needs no IP address and works the same with ScenarioSender.
 *
 * Request:  {"firmware":"1.2","slots":[{"slot_code":"A01","occupied":true}]}
 * Reply:    {"commands":[{"command_id":15,"slot_code":"A01","action":"UNLOCK"}],
 *            "blocked_cards":["04A1B2C3"], "reserved":[{"slot_code":"A02","card_uid":"0499AABB"}]}
 */
@WebServlet(name = "HealthApi", urlPatterns = {"/api/health"})
public class HealthApi extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // heartbeat, check-in of occupied slots, then the reply for cases 2, 3 and 4
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");   // set by SecurityFilter from the API key
        JsonElement parsed = JsonParser.parseReader(req.getReader());
        JsonObject body = parsed.isJsonObject() ? parsed.getAsJsonObject() : new JsonObject();
        JsonObject reply = new JsonObject();
        Gson gson = new Gson();
        try {
            new DeviceDao().heartbeat(deviceId);                                                    // case 1
            DepositDao deposits = new DepositDao();
            if (body.has("slots")) {
                for (JsonElement element : body.getAsJsonArray("slots")) {
                    JsonObject slot = element.getAsJsonObject();
                    if (slot.get("occupied").getAsBoolean()) {
                        deposits.checkIn(deviceId, slot.get("slot_code").getAsString());            // case 4
                    }
                }
            }
            reply.add("commands", gson.toJsonTree(new RemoteCommandDao().takePending(deviceId)));   // case 2
            reply.add("blocked_cards", gson.toJsonTree(new UserCardDao().blockedUids()));          // case 3
            reply.add("reserved", gson.toJsonTree(deposits.reservedFor(deviceId)));                 // case 4
        } catch (SQLException e) {
            log("Heartbeat failed for device " + deviceId, e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            return;
        } catch (RuntimeException bad) {                     // wrong JSON shape: the device's mistake, not ours
            res.sendError(HttpServletResponse.SC_BAD_REQUEST, "Bad heartbeat body");
            return;
        }
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write(reply.toString());
    }
}
