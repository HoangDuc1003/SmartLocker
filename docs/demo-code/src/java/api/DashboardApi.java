package api;

import com.google.gson.Gson;
import dao.DashboardDao;
import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Web;

/** GET /api/dashboard?device=1 : the last sessions of a device as JSON, drawn by the canvas chart. */
@WebServlet(name = "DashboardApi", urlPatterns = {"/api/dashboard"})
public class DashboardApi extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // a JSON array of {time, a, b}, a = door open seconds, b = weight change in grams
        int deviceId = Web.intParam(req, "device", 1);
        try {
            String json = new Gson().toJson(new DashboardDao().recentSessions(deviceId, 50));
            res.setContentType("application/json;charset=UTF-8");
            res.setHeader("Cache-Control", "no-store");
            res.getWriter().write(json);
        } catch (SQLException e) {
            log("Dashboard data failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}
