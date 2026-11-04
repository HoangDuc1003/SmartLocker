package controller;

import dao.DeviceAuthDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import service.CardMail;

/**
 * /c/{token}: the page behind the link of the card e-mail. Public, the token is the secret (256 random bits, 5 minutes,
 * one use). GET only shows what waits, so a mail scanner that opens the link opens no locker; the owner's POST decides.
 */
@WebServlet(name = "CardConfirmController", urlPatterns = {"/c/*"})
public class CardConfirmController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/cardConfirm.jsp";

    private static String hashOf(HttpServletRequest req) {
        String path = req.getPathInfo();
        String token = path == null ? "" : path.substring(1);
        return token.matches("[0-9a-f]{64}") ? CardMail.hash(token) : null;
    }

    private void show(HttpServletRequest req, HttpServletResponse res, String hash, String outcome)
            throws ServletException, IOException, SQLException {
        // the token is in the address: keep it out of caches and of the Referer of any link
        res.setHeader("Cache-Control", "no-store");
        res.setHeader("Referrer-Policy", "no-referrer");
        Map<String, Object> row = hash == null ? null : new DeviceAuthDao().confirmFind(hash);
        if (row == null || row.isEmpty()) {
            res.setStatus(HttpServletResponse.SC_NOT_FOUND);
            outcome = "NOT_FOUND";
        } else {
            req.setAttribute("cmd", row);
            req.setAttribute("action", CardMail.action((String) row.get("phase")));
            if (outcome == null) {
                boolean waiting = "AWAITING_EMAIL".equals(row.get("status")) && ((Number) row.get("left_sec")).intValue() > 0;
                outcome = waiting ? "ASK" : "EXPIRED".equals(row.get("status")) || "AWAITING_EMAIL".equals(row.get("status"))
                        ? "EXPIRED" : "DONE_BEFORE";
            }
        }
        req.setAttribute("outcome", outcome);
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        try {
            show(req, res, hashOf(req), null);
        } catch (SQLException e) {
            log("Card confirm page failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String hash = hashOf(req);
        try {
            String decision = req.getParameter("decision");
            String outcome = null;
            if (hash != null && ("approve".equals(decision) || "reject".equals(decision))) {
                outcome = new DeviceAuthDao().confirmDecide(hash, "approve".equals(decision));
            }
            show(req, res, hash, outcome);
        } catch (SQLException e) {
            log("Card confirm failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}
