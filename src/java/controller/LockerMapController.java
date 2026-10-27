package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Web;

/**
 * The locker map page. It has nothing to load: the page is an empty shell and its script fetches /api/locker-map
 * every 10 seconds. Users and visitors get the full-screen glass map (lockerMap.jsp, with "Tủ của tôi" and
 * "Nạp tiền" as popups over it); the staff roles keep the map with the sidebar (lockerMapStaff.jsp).
 */
@WebServlet(name = "LockerMapController", urlPatterns = {"/LockerMapController"})
public class LockerMapController extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // forward to the view, keeping the ?area=, ?slot= and ?panel= of the URL for the script
        String view = Web.isUserView(Web.currentUser(req)) ? "lockerMap.jsp" : "lockerMapStaff.jsp";
        req.getRequestDispatcher("/WEB-INF/views/" + view).forward(req, res);
    }
}
