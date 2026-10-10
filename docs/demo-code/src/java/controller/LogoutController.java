package controller;

import java.io.IOException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

/** Ends the session. */
@WebServlet(name = "LogoutController", urlPatterns = {"/LogoutController"})
public class LogoutController extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        // session.invalidate() then back to the login page
        HttpSession session = req.getSession(false);
        if (session != null) {
            session.invalidate();   // drops the login state
        }
        res.sendRedirect(req.getContextPath() + "/LoginController");
    }
}
