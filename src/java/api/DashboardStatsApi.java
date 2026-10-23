package api;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import dao.DashboardDao;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;

/**
 * GET /api/dashboard/stats : the numbers behind the usage charts of the dashboard (bookings per hour and weekday,
 * revenue per day, open alerts per type). They need aggregate queries, so they are not part of the
 * LockerMonitor snapshot behind /api/dashboard; the answer is cached here for one minute for every browser.
 * Revenue is only sent to ADMIN and OPERATOR.
 */
@WebServlet(name = "DashboardStatsApi", urlPatterns = {"/api/dashboard/stats"})
public class DashboardStatsApi extends HttpServlet {

    private static final long TTL_MS = 60_000L;
    private static final Gson GSON = new GsonBuilder().serializeNulls().disableHtmlEscaping().create();

    private static DashboardDao.UsageStats cached;
    private static long cachedAt;

    private static synchronized DashboardDao.UsageStats stats() throws SQLException {
        long now = System.currentTimeMillis();
        if (cached == null || now - cachedAt > TTL_MS) {
            cached = new DashboardDao().fetchUsageStats();
            cachedAt = now;
        }
        return cached;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        res.setContentType("application/json;charset=UTF-8");
        res.setHeader("Cache-Control", "no-store");
        try {
            JsonObject json = GSON.toJsonTree(stats()).getAsJsonObject();
            User me = util.Web.currentUser(req);
            String role = me == null ? "" : me.getRoleName();
            if (!"ADMIN".equals(role) && !"OPERATOR".equals(role)) {
                json.remove("revenue");
            }
            json.addProperty("generatedAt", cachedAt);
            res.getWriter().write(GSON.toJson(json));
        } catch (SQLException e) {
            log("Dashboard stats failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}
