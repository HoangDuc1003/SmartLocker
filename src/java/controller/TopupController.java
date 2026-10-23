package controller;

import dao.TopupDao;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.sql.SQLException;
import java.util.List;
import java.util.UUID;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.TopupRequest;
import model.User;
import util.Web;

/**
 * Account top-up flow:
 * 1. The user chooses an amount and receives a VietQR transfer code.
 * 2. Staff confirms the transfer and credits the user's account balance.
 */
@WebServlet(name = "TopupController", urlPatterns = {"/TopupController"})
public class TopupController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/topup.jsp";
    private static final String BANK_ID = "MB";
    private static final String BANK_NAME = "MBBank";
    private static final String ACCOUNT_NO = "0981025559";
    private static final String ACCOUNT_NAME = "SMART LOCKER";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        User me = Web.currentUser(req);
        TopupDao topupDao = new TopupDao();
        boolean isStaff = "ADMIN".equals(me.getRoleName()) || "OPERATOR".equals(me.getRoleName());
        String status = Web.trimmed(req, "status");
        int viewId = Web.intParam(req, "id", 0);

        try {
            if (isStaff) {
                // "ALL" in the filter of the review page means no status filter
                req.setAttribute("allRequests", topupDao.listAll("ALL".equals(status) ? null : status));
            }
            List<TopupRequest> myRequests = topupDao.listByUser(me.getUserId());
            req.setAttribute("myRequests", myRequests);

            TopupRequest currentQr = null;
            if (viewId > 0) {
                currentQr = topupDao.findById(viewId);
                if (currentQr == null || (!isStaff && currentQr.getUserId() != me.getUserId())) {
                    res.sendError(HttpServletResponse.SC_NOT_FOUND);
                    return;
                }
            } else if (!myRequests.isEmpty() && "PENDING".equals(myRequests.get(0).getStatus())) {
                currentQr = myRequests.get(0);
            }
            req.setAttribute("currentQr", currentQr);
            req.setAttribute("isStaff", isStaff);
            req.setAttribute("status", status);
            req.setAttribute("bankName", BANK_NAME);
            req.setAttribute("accountNumber", ACCOUNT_NO);
            req.setAttribute("accountName", ACCOUNT_NAME);

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
                if (amount < 1000) {
                    Web.flash(req.getSession(), "Số tiền nạp tối thiểu là 1.000 VND.", true);
                    res.sendRedirect("TopupController");
                    return;
                }

                // Generate short unique transfer code
                String code = "TOPUP_" + me.getUserId() + "_"
                        + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
                String qrUrl = generateVietQrUrl(amount, code);

                int reqId = topupDao.create(me.getUserId(), amount, code, qrUrl);
                Web.flash(req.getSession(), "Đã tạo yêu cầu nạp " + String.format("%,d", amount).replace(',', '.')
                        + " VND. Quét mã VietQR bên dưới để chuyển khoản.", false);
                res.sendRedirect("TopupController?id=" + reqId);
                return;
            }

            if ("approve".equals(action)) {
                if (!isStaff) {
                    res.sendError(HttpServletResponse.SC_FORBIDDEN, "Chỉ nhân viên mới được duyệt nạp tiền");
                    return;
                }
                int reqId = Web.intParam(req, "id", 0);
                TopupRequest own = topupDao.findById(reqId);
                if (own != null && own.getUserId() == me.getUserId()) {
                    Web.flash(req.getSession(), "Không tự duyệt yêu cầu nạp tiền của chính mình; nhờ nhân viên khác duyệt.", true);
                    res.sendRedirect(reviewPage(req));
                    return;
                }
                boolean ok = topupDao.approve(reqId, me.getUserId());
                if (ok) {
                    TopupRequest tr = topupDao.findById(reqId);
                    String userTarget = tr != null ? tr.getUsername() : ("#" + reqId);
                    Web.flash(req.getSession(), "Đã cộng tiền vào tài khoản " + userTarget + ".", false);
                } else {
                    Web.flash(req.getSession(), "Yêu cầu này đã được xử lý hoặc không hợp lệ.", true);
                }
                res.sendRedirect(reviewPage(req));
                return;
            }

            if ("reject".equals(action)) {
                if (!isStaff) {
                    res.sendError(HttpServletResponse.SC_FORBIDDEN, "Chỉ nhân viên mới được từ chối nạp tiền");
                    return;
                }
                int reqId = Web.intParam(req, "id", 0);
                String reason = Web.trimmed(req, "reason");
                if (reason.isEmpty()) reason = "Chưa nhận được chuyển khoản";
                boolean rejected = topupDao.reject(reqId, me.getUserId(), reason);
                Web.flash(req.getSession(), rejected
                        ? "Đã từ chối yêu cầu nạp tiền #" + reqId + "."
                        : "Yêu cầu này đã được xử lý hoặc không hợp lệ.", !rejected);
                res.sendRedirect(reviewPage(req));
                return;
            }

            Web.flash(req.getSession(), "Thao tác không hợp lệ.", true);
            res.sendRedirect("TopupController");
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    /** The review page of staff, keeping its status filter (only known values, so the redirect is safe). */
    private static String reviewPage(HttpServletRequest req) {
        String status = Web.trimmed(req, "status");
        if (!"ALL".equals(status) && !"PENDING".equals(status) && !"APPROVED".equals(status) && !"REJECTED".equals(status)) {
            status = "PENDING";
        }
        return "TopupController?status=" + status;
    }

    private static String generateVietQrUrl(long amount, String transferCode) throws UnsupportedEncodingException {
        // https://img.vietqr.io/image/<BANK>-<ACC>-compact2.png?amount=<AMT>&addInfo=<INFO>&accountName=<NAME>
        return "https://img.vietqr.io/image/" + BANK_ID + "-" + ACCOUNT_NO + "-compact2.png"
                + "?amount=" + amount
                + "&addInfo=" + URLEncoder.encode(transferCode, "UTF-8")
                + "&accountName=" + URLEncoder.encode(ACCOUNT_NAME, "UTF-8");
    }
}
