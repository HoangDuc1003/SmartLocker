package api;

import dao.LockerMapDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Set;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/** GET /api/locker-map?area=LIB : the JSON that js/locker-map.js draws. Refreshed by the page every 10 seconds. */
@WebServlet(name = "LockerMapApi", urlPatterns = {"/api/locker-map"})
public class LockerMapApi extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // the role decides how much the JSON tells; the filter has already checked MAP:READ
        User me = Web.currentUser(req);
        @SuppressWarnings("unchecked")
        Set<String> keys = (Set<String>) req.getAttribute("perms");   // put there by SecurityFilter
        boolean staff = keys != null && keys.contains("ALERT:READ");  // staff may see names, alerts and tickets
        try {
            com.google.gson.JsonObject map = new LockerMapDao().load(Web.trimmed(req, "area"), me.getUserId(), staff);
            map.addProperty("balance", me.getBalance());
            String json = map.toString();
            res.setContentType("application/json;charset=UTF-8");
            res.setHeader("Cache-Control", "no-store");
            res.getWriter().write(json);
        } catch (SQLException e) {
            log("Locker map failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}
