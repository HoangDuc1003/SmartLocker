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
        res.sendError(HttpServletResponse.SC_NOT_IMPLEMENTED, "TODO LockerMapApi.doGet");
    }
}
