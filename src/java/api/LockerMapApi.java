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
        User me = Web.currentUser(req);
        @SuppressWarnings("unchecked")
        Set<String> keys = (Set<String>) req.getAttribute("perms");   // put there by SecurityFilter
        boolean staff = keys != null && keys.contains("ALERT:READ");  // staff may see names, alerts and tickets
        try {
            boolean guest = me == null;   // v4: not signed in; sees the map and the prices, nothing about people
            com.google.gson.JsonObject map = new LockerMapDao().load(Web.trimmed(req, "area"), guest ? 0 : me.getUserId(), staff);
            map.addProperty("guest", guest);
            if (!guest) {
                map.addProperty("balance", new dao.UserDao().getBalance(me.getUserId()));   // fresh: a late fee may have changed it
            }
            // v3: the sizes (measures, items, hour prices, picture) and the rules the popup states
            dao.AppConfigDao config = new dao.AppConfigDao();
            com.google.gson.JsonArray sizes = new com.google.gson.JsonArray();
            for (dao.AppConfigDao.SlotSize z : config.sizes()) {
                com.google.gson.JsonObject o = new com.google.gson.JsonObject();
                o.addProperty("code", z.code);
                o.addProperty("size_cm", z.sizeCm);
                o.addProperty("price_pct", z.pricePct);
                o.addProperty("hour_rate", z.hourRate);
                o.addProperty("overdue_rate", z.overdueRate);
                o.add("items", api.ApiJson.GSON.toJsonTree(z.items));
                String img = util.SlotImages.find(getServletContext(), z.code);
                if (img == null) {
                    o.add("img", com.google.gson.JsonNull.INSTANCE);
                } else {
                    o.addProperty("img", img);
                }
                sizes.add(o);
            }
            map.add("sizes", sizes);
            com.google.gson.JsonObject rules = new com.google.gson.JsonObject();
            rules.addProperty("hold_min", config.getInt("HOLD_MIN", util.Pricing.HOLD_MIN));
            rules.addProperty("cancel_min", config.getInt("CANCEL_FREE_MIN", util.Pricing.CANCEL_FREE_MIN));
            rules.addProperty("booking_buffer", config.get("BOOKING_BUFFER", util.Pricing.BOOKING_BUFFER));
            rules.addProperty("card_deposit", config.get("CARD_DEPOSIT", util.Pricing.CARD_DEPOSIT));
            rules.addProperty("no_show_refund_pct", config.getInt("NO_SHOW_REFUND_PCT", util.Pricing.NO_SHOW_REFUND_PCT));
            map.add("rules", rules);
            if (!staff && !guest) {
                // v2 booking form: the first card deposit (AppConfig CARD_DEPOSIT), and the boxes where the user's finger is enrolled
                dao.DeviceAuthDao auth = new dao.DeviceAuthDao();
                map.addProperty("card_deposit_due", !auth.hasRegisteredCard(me.getUserId()));
                map.addProperty("card_deposit", config.get("CARD_DEPOSIT", util.Pricing.CARD_DEPOSIT));
                map.addProperty("hold_min", config.getInt("HOLD_MIN", util.Pricing.HOLD_MIN));
                com.google.gson.JsonArray fp = new com.google.gson.JsonArray();
                for (java.util.Map<String, Object> f : auth.fingerprintsOf(me.getUserId())) {
                    fp.add(String.valueOf(f.get("device_code")));
                }
                map.add("fp_devices", fp);
            }
            String json = map.toString();
            res.setContentType("application/json;charset=UTF-8");
            res.setHeader("Cache-Control", "no-store");
            res.getWriter().write(json);
        } catch (SQLException e) {
            log("Locker map failed", e);
            res.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}
