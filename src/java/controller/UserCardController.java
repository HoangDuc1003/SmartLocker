package controller;

import dao.AuditDao;
import dao.UserCardDao;
import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import model.UserCard;
import util.Csv;
import util.Web;

/** Cards for the operator: issue, block, replace a lost card (case 3). */
@WebServlet(name = "UserCardController", urlPatterns = {"/UserCardController"})
public class UserCardController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/userCard.jsp";
    private static final int PAGE_SIZE = 10;
    private static final Pattern HEX_UID = Pattern.compile("^[0-9A-Fa-f]{4,32}$");

    private final UserCardDao dao = new UserCardDao();

    private void showList(HttpServletRequest req, HttpServletResponse res) throws SQLException, ServletException, IOException {
        String q = Web.trimmed(req, "q");
        String status = Web.trimmed(req, "status");
        int total = dao.count(q, status);
        int pages = Web.pages(total, PAGE_SIZE);
        int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);

        req.setAttribute("mode", "list");
        req.setAttribute("items", dao.search(q, status, page, PAGE_SIZE));
        req.setAttribute("total", total);
        req.setAttribute("page", page);
        req.setAttribute("pages", pages);
        req.setAttribute("q", q);
        req.setAttribute("status", status);
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void showForm(HttpServletRequest req, HttpServletResponse res, UserCard item, boolean isNew)
            throws SQLException, ServletException, IOException {
        req.setAttribute("mode", "form");
        req.setAttribute("item", item);
        req.setAttribute("isNew", isNew);
        req.setAttribute("users", new UserDao().search(null, null, "ACTIVE", 1, 1000));
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res) throws SQLException, IOException {
        String q = Web.trimmed(req, "q");
        String status = Web.trimmed(req, "status");
        List<String[]> rows = new ArrayList<>();
        for (UserCard c : dao.search(q, status, 1, Math.max(1, dao.count(q, status)))) {
            rows.add(new String[]{
                String.valueOf(c.getCardId()),
                c.getCardUid(),
                c.getUsername(),
                c.getStatus(),
                c.getIssuedAt() != null ? c.getIssuedAt().toString() : "",
                c.getLostAt() != null ? c.getLostAt().toString() : ""
            });
        }
        Csv.send(res, "cards.csv", new String[]{"card_id", "card_uid", "user", "status", "issued_at", "lost_at"}, rows);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String action = Web.trimmed(req, "action");
        try {
            if ("new".equals(action)) {
                UserCard blank = new UserCard();
                blank.setStatus("ACTIVE");
                showForm(req, res, blank, true);
            } else if ("export".equals(action)) {
                export(req, res);
            } else {
                showList(req, res);
            }
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        try {
            if ("issue".equals(action)) {
                String cardUid = Web.trimmed(req, "cardUid").toUpperCase();
                int userId = Web.intParam(req, "userId", 0);
                if (!HEX_UID.matcher(cardUid).matches()) {
                    req.setAttribute("error", "Mã UID thẻ gồm 4 đến 32 ký tự hexa");
                    UserCard c = new UserCard();
                    c.setCardUid(cardUid);
                    c.setUserId(userId);
                    showForm(req, res, c, true);
                    return;
                }
                if (userId <= 0) {
                    req.setAttribute("error", "Hãy chọn người dùng");
                    UserCard c = new UserCard();
                    c.setCardUid(cardUid);
                    showForm(req, res, c, true);
                    return;
                }
                try {
                    UserCard c = new UserCard();
                    c.setCardUid(cardUid);
                    c.setUserId(userId);
                    c.setStatus("ACTIVE");
                    int cardId = dao.insert(c);
                    new AuditDao().append(me.getUserId(), "CREATE", "USERCARD", cardId, cardUid);
                    Web.flash(req.getSession(), "Đã cấp thẻ " + cardUid, false);
                } catch (SQLException e) {
                    if (e.getErrorCode() == 2627) {
                        req.setAttribute("error", "Mã UID " + cardUid + " đã được đăng ký");
                        UserCard c = new UserCard();
                        c.setCardUid(cardUid);
                        c.setUserId(userId);
                        showForm(req, res, c, true);
                        return;
                    }
                    throw e;
                }
            } else if ("block".equals(action)) {
                int cardId = Web.intParam(req, "id", 0);
                UserCard c = dao.findById(cardId);
                if (c != null) {
                    dao.setStatus(cardId, "BLOCKED");
                    new AuditDao().append(me.getUserId(), "BLOCK", "USERCARD", cardId, c.getCardUid());
                    Web.flash(req.getSession(), "Đã khóa thẻ " + c.getCardUid(), false);
                }
            } else if ("unblock".equals(action)) {
                int cardId = Web.intParam(req, "id", 0);
                UserCard c = dao.findById(cardId);
                if (c != null) {
                    dao.setStatus(cardId, "ACTIVE");
                    new AuditDao().append(me.getUserId(), "UNBLOCK", "USERCARD", cardId, c.getCardUid());
                    Web.flash(req.getSession(), "Đã mở khóa thẻ " + c.getCardUid(), false);
                }
            } else if ("replace".equals(action)) {
                int cardId = Web.intParam(req, "id", 0);
                String newUid = Web.trimmed(req, "newUid").toUpperCase();
                if (!HEX_UID.matcher(newUid).matches()) {
                    Web.flash(req.getSession(), "Mã UID thẻ mới gồm 4 đến 32 ký tự hexa", true);
                } else {
                    try {
                        int newCardId = dao.replace(cardId, newUid, me.getUserId());
                        Web.flash(req.getSession(), "Đã đổi thẻ. Mã thẻ mới: #" + newCardId, false);
                    } catch (SQLException e) {
                        if (e.getErrorCode() == 2627) {
                            Web.flash(req.getSession(), "Mã UID " + newUid + " đã được đăng ký", true);
                        } else if (e.getErrorCode() >= 50000) {
                            Web.flash(req.getSession(), Web.sqlMessage(e), true);
                        } else {
                            throw e;
                        }
                    }
                }
            } else {
                Web.flash(req.getSession(), "Thao tác không hợp lệ", true);
            }
            res.sendRedirect("UserCardController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
