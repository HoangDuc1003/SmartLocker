package controller;

import dao.DepositDao;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Todo;
import util.Web;

/**
 * Case 4. The Locker User reserves, cancels and extends a booking.
 * The forms are in the slot panel of the locker map, so every POST goes back to the map.
 * GET shows "My bookings".
 */
@WebServlet(name = "BookingController", urlPatterns = {"/BookingController"})
public class BookingController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/booking.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // action = reserve | cancel | extend; the procedure checks the rules and writes the audit row
        throw Todo.of("BookingController.doPost: reserve, cancel, extend, then redirect back to the map");
    }

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: back to the slot the user was looking at
}
