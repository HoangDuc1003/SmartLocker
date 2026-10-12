package controller;

import dao.TopupDao;
import dao.UserCardDao;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.sql.SQLException;
import java.util.List;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.TopupRequest;
import model.User;
import model.UserCard;
import util.Web;

/**
 * Real Top-up flow:
 * 1. Customer clicks "Nạp thẻ" / selects amount -> Real VietQR code generated with transfer code.
 * 2. Admin reviews the request and clicks "Xác nhận & Nạp tiền" -> Real money added to user's balance.
 */
@WebServlet(name = "TopupController", urlPatterns = {"/TopupController"})
public class TopupController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/topup.jsp";
    private static final String BANK_ID = "MB";
    private static final String ACCOUNT_NO = "0981025559";
    private static final String ACCOUNT_NAME = "SMART LOCKER";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        TopupDao topupDao = new TopupDao();
        UserCardDao cardDao = new UserCardDao();
        boolean isStaff = "ADMIN".equals(me.getRoleName()) || "OPERATOR".equals(me.getRoleName());
        String status = Web.trimmed(req, "status");
        int viewId = Web.intParam(req, "id", 0);

        try {
            if (isStaff) {
                req.setAttribute("allRequests", topupDao.listAll(status));
            }
            List<TopupRequest> myRequests = topupDao.listByUser(me.getUserId());
            req.setAttribute("myRequests", myRequests);

            List<UserCard> cards = cardDao.listByUser(me.getUserId());
            req.setAttribute("cards", cards);

            TopupRequest currentQr = null;
            if (viewId > 0) {
                currentQr = topupDao.findById(viewId);
            } else if (!myRequests.isEmpty() && "PENDING".equals(myRequests.get(0).getStatus())) {
                currentQr = myRequests.get(0);
            }
            req.setAttribute("currentQr", currentQr);
            req.setAttribute("isStaff", isStaff);
            req.setAttribute("status", status);

            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        TopupDao topupDao = new TopupDao();
        boolean isStaff = "ADMIN".equals(me.getRoleName()) || "OPERATOR".equals(me.getRoleName());

        try {
            if ("create".equals(action)) {
                // User creates topup request
                long amount = Web.longParam(req, "amount", 0);
                Integer cardId = Web.optionalInt(req, "cardId");
                if (amount < 1000) {
                    Web.flash(req.getSession(), "Số tiền nạp tối thiểu là 1,000 VND", true);
                    res.sendRedirect("TopupController");
                    return;
                }

                // Generate short unique transfer code
                String code = "NAP_" + me.getUsername().toUpperCase() + "_" + (System.currentTimeMillis() % 10000);
                String qrUrl = generateVietQrUrl(amount, code);

                int reqId = topupDao.create(me.getUserId(), cardId, amount, code, qrUrl);
                Web.flash(req.getSession(), "Tạo yêu cầu nạp " + String.format("%,d", amount) + " VND thành công! Vui lòng quét mã QR bên dưới.", false);
                res.sendRedirect("TopupController?id=" + reqId);
                return;
            }

            if ("approve".equals(action)) {
                if (!isStaff) {
                    res.sendError(HttpServletResponse.SC_FORBIDDEN, "Only staff can approve topup");
                    return;
                }
                int reqId = Web.intParam(req, "id", 0);
                boolean ok = topupDao.approve(reqId, me.getUserId());
                if (ok) {
                    TopupRequest tr = topupDao.findById(reqId);
                    String userTarget = tr != null ? tr.getUsername() : ("#" + reqId);
                    Web.flash(req.getSession(), "✓ Đã xác nhận và nạp tiền thành công cho khách " + userTarget + "!", false);
                } else {
                    Web.flash(req.getSession(), "Không thể duyệt yêu cầu này (đã được xử lý hoặc không hợp lệ)", true);
                }
                res.sendRedirect("TopupController");
                return;
            }

            if ("reject".equals(action)) {
                if (!isStaff) {
                    res.sendError(HttpServletResponse.SC_FORBIDDEN, "Only staff can reject topup");
                    return;
                }
                int reqId = Web.intParam(req, "id", 0);
                String reason = Web.trimmed(req, "reason");
                if (reason.isEmpty()) reason = "Không nhận được giao dịch chuyển khoản";
                topupDao.reject(reqId, me.getUserId(), reason);
                Web.flash(req.getSession(), "Đã từ chối yêu cầu nạp tiền #" + reqId, false);
                res.sendRedirect("TopupController");
                return;
            }

            Web.flash(req.getSession(), "Hành động không hợp lệ", true);
            res.sendRedirect("TopupController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    private static String generateVietQrUrl(long amount, String transferCode) throws UnsupportedEncodingException {
        // https://img.vietqr.io/image/<BANK>-<ACC>-compact2.png?amount=<AMT>&addInfo=<INFO>&accountName=<NAME>
        return "https://img.vietqr.io/image/" + BANK_ID + "-" + ACCOUNT_NO + "-compact2.png"
                + "?amount=" + amount
                + "&addInfo=" + URLEncoder.encode(transferCode, "UTF-8")
                + "&accountName=" + URLEncoder.encode(ACCOUNT_NAME, "UTF-8");
    }
}
