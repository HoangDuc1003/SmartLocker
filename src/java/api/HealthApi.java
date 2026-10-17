package api;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import dao.DepositDao;
import dao.DeviceDao;
import dao.RemoteCommandDao;
import dao.UserCardDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Map;
import service.AuthText;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 * The heartbeat. The box calls it every 3 seconds, the reply is the only way the server talks to the box:
 * pending commands (UNLOCK from the phone page or from staff, DELETE_FP, CANCEL_ENROLL). The server never calls
 * the box, so it needs no IP address and works the same with ScenarioSender.
 *
 * Request:  {"firmware":"2.0","uptime_sec":1234}
 * Reply:    {"interval_sec":3,
 *            "commands":[{"command_id":15,"action":"UNLOCK","slot_code":"A04","open_sec":8,"message":"Mo tu\n(dien thoai)"},
 *                        {"command_id":16,"action":"DELETE_FP","sensor_slot":7}],
 *            "server_time":"2026-10-17 07:03:00",
 *            "blocked_cards":["04A1B2C3"], "reserved":[{"slot_code":"A02","card_uid":"0499AABB"}]}   (v1 keys, kept for ScenarioSender)
 * v2 checks in through /api/device/auth, so "slots" of the v1 body is ignored.
 */
@WebServlet(name = "HealthApi", urlPatterns = {"/api/health"})
public class HealthApi extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        res.setHeader("Cache-Control", "no-store");
        JsonObject reply = new JsonObject();
        reply.addProperty("status", "ONLINE");
        reply.addProperty("gateway", "UP");
        reply.addProperty("service", "SmartLocker IoT Gateway");
        reply.addProperty("timestamp", System.currentTimeMillis());
        reply.addProperty("database", dao.DbContext.ping());
        res.getWriter().write(reply.toString());
    }

    /** Seconds between two heartbeats of the box. */
    static final int INTERVAL_SEC = 3;

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // heartbeat, then the reply: commands for the box, plus the v1 keys
        int deviceId = (Integer) req.getAttribute("DEVICE_ID");   // set by SecurityFilter from the API key
        JsonObject body = ApiJson.bodyOrEmpty(req);
        if (body == null) {                                  // wrong JSON shape: the device's mistake, not ours
            ApiJson.error(res, HttpServletResponse.SC_BAD_REQUEST, "BAD_REQUEST", "Sai du lieu");
            return;
        }
        JsonObject reply = new JsonObject();
        try {
            DeviceDao devices = new DeviceDao();
            devices.heartbeat(deviceId);                                                            // case 1
            String firmware = ApiJson.text(body, "firmware");
            if (firmware != null) {
                devices.setFirmware(deviceId, firmware);
            }
            JsonArray commands = new JsonArray();
            for (Map<String, Object> cmd : new RemoteCommandDao().takePending(deviceId)) {          // case 2
                JsonObject c = new JsonObject();
                String action = (String) cmd.get("action");
                c.addProperty("command_id", (Long) cmd.get("command_id"));
                c.addProperty("action", action);
                if ("UNLOCK".equals(action)) {
                    c.addProperty("slot_code", (String) cmd.get("slot_code"));
                    c.addProperty("open_sec", AuthText.OPEN_SEC);
                    c.addProperty("message", "PHONE".equals(cmd.get("source")) ? "Mo tu\n(dien thoai)" : "Mo tu\n(tu xa)");
                } else if ("DELETE_FP".equals(action)) {
                    c.addProperty("sensor_slot", (Integer) cmd.get("sensor_slot"));
                }
                commands.add(c);
            }
            reply.addProperty("interval_sec", INTERVAL_SEC);
            reply.add("commands", commands);
            reply.addProperty("server_time", serverTime());
            reply.add("blocked_cards", ApiJson.COMPACT.toJsonTree(new UserCardDao().blockedUids()));          // case 3, v1
            reply.add("reserved", ApiJson.COMPACT.toJsonTree(new DepositDao().reservedFor(deviceId)));         // case 4, v1
        } catch (SQLException e) {
            log("Heartbeat failed for device " + deviceId, e);
            ApiJson.error(res, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "SERVER_ERROR", "Loi may chu");
            return;
        }
        ApiJson.write(res, 200, reply);
    }

    /** UTC now as "yyyy-MM-dd HH:mm:ss", the format the box sends its times in. */
    private static String serverTime() {
        java.text.SimpleDateFormat f = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        f.setTimeZone(java.util.TimeZone.getTimeZone("UTC"));
        return f.format(new java.util.Date());
    }
}
