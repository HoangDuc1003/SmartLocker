package api;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import dao.DepositDao;
import dao.DeviceAuthDao;
import dao.StoragePlanDao;
import dao.UserDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.List;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.Deposit;
import model.StoragePlan;
import model.User;
import util.Pricing;
import util.Web;

/**
 * "Tủ của tôi" as JSON for the signed-in user (BOOKING resource): the open booking with its PIN or enroll code,
 * cards, fingerprints, prices by open method and the recent history. The Postman collection reads it to chain steps.
 *
 * GET  -> {"username","balance","card_deposit_due","booking":{...}|null,"cards":[...],"fingerprints":[...],"plans":[...],"history":[...]}
 * POST action=newEnrollCode&depositId=..  -> {"ok":true,"enroll_code":"123456"}
 * POST action=deleteFingerprint&fpId=..   -> {"ok":true}
 */
@WebServlet(name = "MyLockerApi", urlPatterns = {"/api/my-locker"})
public class MyLockerApi extends HttpServlet {

    private static JsonObject booking(Deposit d) {
        JsonObject b = new JsonObject();
        b.addProperty("deposit_id", d.getDepositId());
        b.addProperty("status", d.getStatus());
        b.addProperty("slot_id", d.getSlotId());
        b.addProperty("slot_code", d.getSlotCode());
        b.addProperty("bank_code", d.getBankCode());
        b.addProperty("device_code", d.getDeviceCode());
        b.addProperty("plan_name", d.getPlanName());
        b.addProperty("paid_amount", d.getPaidAmount());
        b.addProperty("open_method", d.getOpenMethod());
        b.addProperty("pin_code", d.getPinCode());
        b.addProperty("enroll_code", d.getEnrollCode());
        b.add("enroll_expires", ApiJson.GSON.toJsonTree(d.getEnrollExpires()));
        b.add("reserved_at", ApiJson.GSON.toJsonTree(d.getReservedAt()));
        b.add("hold_until", ApiJson.GSON.toJsonTree(d.getHoldUntil()));
        b.add("started_at", ApiJson.GSON.toJsonTree(d.getStartedAt()));
        b.add("due_at", ApiJson.GSON.toJsonTree(d.getDueAt()));
        b.add("ended_at", ApiJson.GSON.toJsonTree(d.getEndedAt()));
        // v3: size, the overdue lock and the late fee
        b.addProperty("size_code", d.getSizeCode());
        b.addProperty("size_cm", d.getSizeCm());
        b.addProperty("extend_count", d.getExtendCount());
        b.addProperty("locked", d.isLocked());
        b.addProperty("escalated", d.getEscalatedAt() != null);
        b.addProperty("overdue_hours", d.getOverdueHours());
        b.addProperty("overdue_fee", d.getOverdueFee());
        if (d.getOverdueRate() == null) {
            b.add("overdue_rate", com.google.gson.JsonNull.INSTANCE);
        } else {
            b.addProperty("overdue_rate", d.getOverdueRate());
        }
        return b;
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws IOException {
        User me = Web.currentUser(req);
        try {
            DeviceAuthDao auth = new DeviceAuthDao();
            DepositDao deposits = new DepositDao();
            boolean hasCard = auth.hasRegisteredCard(me.getUserId());
            JsonObject reply = new JsonObject();
            reply.addProperty("user_id", me.getUserId());
            reply.addProperty("username", me.getUsername());
            long balance = new UserDao().getBalance(me.getUserId());
            reply.addProperty("balance", balance);
            reply.addProperty("debt", balance < 0 ? -balance : 0);   // v3: a late fee may put the wallet below zero
            reply.addProperty("card_deposit_due", !hasCard);
            dao.AppConfigDao config = new dao.AppConfigDao();
            reply.addProperty("card_deposit", config.get("CARD_DEPOSIT", Pricing.CARD_DEPOSIT));
            reply.addProperty("cancel_min", config.getInt("CANCEL_FREE_MIN", Pricing.CANCEL_FREE_MIN));
            reply.addProperty("hold_min", config.getInt("HOLD_MIN", Pricing.HOLD_MIN));
            Deposit open = deposits.findOpenByUser(me.getUserId());
            reply.add("booking", open == null ? com.google.gson.JsonNull.INSTANCE : booking(open));
            reply.add("cards", ApiJson.GSON.toJsonTree(auth.cardsOf(me.getUserId())));
            reply.add("fingerprints", ApiJson.GSON.toJsonTree(auth.fingerprintsOf(me.getUserId())));
            JsonArray plans = new JsonArray();
            java.util.List<dao.AppConfigDao.SlotSize> sizes = config.sizes();
            for (StoragePlan p : new StoragePlanDao().listAll(true)) {
                JsonObject o = new JsonObject();
                o.addProperty("plan_id", p.getPlanId());
                o.addProperty("plan_name", p.getPlanName());
                o.addProperty("duration_min", p.getDurationMin());
                o.addProperty("price", p.getPrice());
                JsonObject prices = new JsonObject();                     // by size, the same for every open method
                for (dao.AppConfigDao.SlotSize z : sizes) {
                    prices.addProperty(z.code, Pricing.sizePrice(p.getPrice(), z.pricePct));
                }
                o.add("prices", prices);
                plans.add(o);
            }
            reply.add("plans", plans);
            JsonArray history = new JsonArray();
            List<Deposit> all = deposits.listByUser(me.getUserId());
            java.util.Map<Long, Long> refunds = deposits.noShowRefunds(me.getUserId());
            for (int i = 0; i < all.size() && history.size() < 10; i++) {
                JsonObject h = booking(all.get(i));
                h.remove("pin_code");                       // a finished booking does not show its code again
                h.remove("enroll_code");
                if ("NO_SHOW".equals(all.get(i).getStatus())) {
                    Long refund = refunds.get(all.get(i).getDepositId());
                    h.addProperty("refund", refund == null ? 0 : refund);
                }
                history.add(h);
            }
            reply.add("history", history);
            ApiJson.write(res, 200, reply);
        } catch (SQLException e) {
            log("My locker failed for user " + me.getUserId(), e);
            ApiJson.error(res, 500, "SERVER_ERROR", "Lỗi máy chủ, hãy thử lại.");
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws IOException {
        User me = Web.currentUser(req);
        String action = Web.trimmed(req, "action");
        JsonObject reply = new JsonObject();
        try {
            if ("newEnrollCode".equals(action)) {
                String code = new DepositDao().newEnrollCode(Web.longParam(req, "depositId", 0), me.getUserId());
                reply.addProperty("ok", true);
                reply.addProperty("enroll_code", code);
            } else if ("deleteFingerprint".equals(action)) {
                new DeviceAuthDao().deleteFingerprint(Web.intParam(req, "fpId", 0), me.getUserId());
                reply.addProperty("ok", true);
            } else {
                ApiJson.error(res, 400, "BAD_REQUEST", "Thao tác không hợp lệ");
                return;
            }
            ApiJson.write(res, 200, reply);
        } catch (SQLException e) {
            if (e.getErrorCode() >= 50000) {                   // our own THROW: the text is written for the user
                ApiJson.error(res, 409, "REFUSED", Web.sqlMessage(e));
                return;
            }
            log("My locker action failed", e);
            ApiJson.error(res, 500, "SERVER_ERROR", "Lỗi máy chủ, hãy thử lại.");
        }
    }
}
