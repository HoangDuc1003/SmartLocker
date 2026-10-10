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
        res.sendError(HttpServletResponse.SC_NOT_IMPLEMENTED, "TODO DashboardApi.doGet");
    }
}
