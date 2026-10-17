package api;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import service.LockerMonitor;

/**
 * GET /api/dashboard
 *
 * Returns the full dashboard payload as JSON. No DB query is made here:
 * the {@link LockerMonitor} scheduler refreshes the in-memory snapshot every
 * 2 seconds. This servlet just serialises it, so 50 concurrent browsers cost
 * zero database round-trips during the TTL window.
 *
 * <pre>
 * {
 *   "serverTime":    "2026-10-16T22:00:00",
 *   "kpis": {
 *     "totalSlots": 120, "occupiedSlots": 45, "availableSlots": 70,
 *     "maintenanceOrFaultSlots": 5, "overdueSessions": 3,
 *     "activeAlerts": 2, "offlineDevices": 1, "auditChainValid": true
 *   },
 *   "slotBreakdown": [ { "areaCode":"LIB", "areaName":"Library", "total":30,
 *                         "occupied":12, "available":17, "fault":1 }, … ],
 *   "recentAlerts":  [ { "alertId":99, "deviceCode":"D-001", "source":"RULE",
 *                         "label":"TAMPER_ALERT", "severity":"CRITICAL",
 *                         "riskScore":0.92, "status":"OPEN",
 *                         "createdAt":"2026-10-16 21:55:03" }, … ],
 *   "deviceHealth":  [ { "deviceCode":"D-001", "location":"Library A",
 *                         "firmware":"1.2", "status":"ACTIVE",
 *                         "health":"ONLINE", "lastSeenSec":8 }, … ]
 * }
 * </pre>
 *
 * GET /api/dashboard?device={id}  (legacy sparkline)
 * Returns the last 50 sessions of a device as [ {time, a, b}, … ].
 */
@WebServlet(name = "DashboardApi", urlPatterns = {"/api/dashboard"})
public class DashboardApi extends HttpServlet {

    /** Not ApiJson.GSON: the browser dashboard wants ISO dates with Z, the device API wants "yyyy-MM-dd HH:mm:ss". */
    private static final Gson GSON = new GsonBuilder()
            .serializeNulls()
            .disableHtmlEscaping()
            .setDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'")   // ISO; the DB stores UTC, the Z lets the browser show local time
            .create();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        res.setHeader("Cache-Control", "no-store");

        // ── Legacy sparkline endpoint (device param present) ─────────────────
        String deviceParam = req.getParameter("device");
        if (deviceParam != null) {
            serveSparkline(req, res, deviceParam);
            return;
        }

        // ── Full dashboard snapshot (no device param) ─────────────────────────
        LockerMonitor.Snapshot snap = LockerMonitor.getSnapshot();

        if (snap == null) {
            // Snapshot not yet ready (first 2 seconds after deploy) — return HTTP 503
            res.sendError(HttpServletResponse.SC_SERVICE_UNAVAILABLE, "Snapshot not ready");
            return;
        }

        String serverTime = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss").format(new Date());

        JsonObject payload = new JsonObject();
        payload.addProperty("serverTime",   serverTime);
        payload.add("kpis",          GSON.toJsonTree(snap.kpis));
        payload.add("slotBreakdown", GSON.toJsonTree(snap.slotBreakdown));
        payload.add("recentAlerts",  GSON.toJsonTree(snap.recentAlerts));
        payload.add("deviceHealth",  GSON.toJsonTree(snap.deviceHealth));
        payload.add("recentSessions", GSON.toJsonTree(snap.recentSessions));

        res.getWriter().write(GSON.toJson(payload));
    }

    /** Legacy: returns the last sessions of one device for the mini sparkline. */
    private void serveSparkline(HttpServletRequest req, HttpServletResponse res, String deviceParam) throws IOException {
        int deviceId;
        try {
            deviceId = Integer.parseInt(deviceParam.trim());
        } catch (NumberFormatException e) {
            res.sendError(HttpServletResponse.SC_BAD_REQUEST, "device must be an integer");
            return;
        }
        try {
            String json = GSON.toJson(new dao.DashboardDao().recentSessions(deviceId, 50));
            res.getWriter().write(json);
        } catch (java.sql.SQLException e) {
            log("Dashboard sparkline failed for device " + deviceId, e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}
