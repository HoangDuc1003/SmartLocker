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
        res.sendError(HttpServletResponse.SC_NOT_IMPLEMENTED, "TODO HealthApi.doPost");
    }
}
