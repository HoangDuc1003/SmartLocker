package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/**
 * The locker map page. It has nothing to load: the page is an empty shell and js/locker-map.js
 * fetches /api/locker-map every 10 seconds. So the controller only forwards.
 */
@WebServlet(name = "LockerMapController", urlPatterns = {"/LockerMapController"})
public class LockerMapController extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // forward to the view, keeping the ?area= and ?slot= of the URL for the script
        req.getRequestDispatcher("/WEB-INF/views/lockerMap.jsp").forward(req, res);
    }
}
