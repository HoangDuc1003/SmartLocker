package dao;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

/**
 * Builds the JSON of the locker map page: the areas for the menu, the banks and slots of one area.
 * Everything a role must not see (names of other users, alerts, tickets) is left out here, on the server.
 */
public class LockerMapDao {

    /** "2026-10-09 10:56:40.1234567" from a DATETIME2 column becomes "2026-10-09T10:56:40Z". */
    private static String iso(String sqlText) {
        return sqlText == null ? null : sqlText.substring(0, 19).replace(' ', 'T') + "Z";
    }

    private static void put(JsonObject o, String key, String value) {
        if (value == null) {
            o.add(key, com.google.gson.JsonNull.INSTANCE);
        } else {
            o.addProperty(key, value);
        }
    }

    /**
     * @param areaCode  the area to draw; empty or unknown means the first area that has slots
     * @param userId    the signed-in user, used for the "mine" flag
     * @param staff     true for roles that may see who uses a slot and its alerts
     */
    public JsonObject load(String areaCode, int userId, boolean staff) throws SQLException {
        // four queries: areas, plans, banks of the area, slots of the area; the JSON matches the frontend
        JsonObject root = new JsonObject();
        try (Connection conn = DbContext.getConnection()) {
            // Expired reservations are freed before rendering. Overdue bookings are never freed (v3):
            // LockerMonitor locks and charges them, the slot stays OCCUPIED until the owner picks up.
            try (java.sql.CallableStatement cs = conn.prepareCall("{call Deposit_ExpireNoShow}")) {
                cs.execute();
            } catch (SQLException ignored) {}

            // the menu: one row per area that has slots
            JsonArray areas = new JsonArray();
            String chosen = null;
            String areaSql = "SELECT a.area_code, a.name, a.location, a.latitude, a.longitude, COUNT(m.slot_id) AS slot_count, "
                    + "SUM(CASE WHEN m.display_status = N'AVAILABLE' THEN 1 ELSE 0 END) AS available, "
                    + "SUM(CASE WHEN m.display_status = N'ALERT' THEN 1 ELSE 0 END) AS alerts, "
                    + "SUM(CASE WHEN m.display_status = N'OFFLINE' THEN 1 ELSE 0 END) AS offline "
                    + "FROM LockerArea a LEFT JOIN v_LockerSlotMap m ON m.area_id = a.area_id "
                    + "WHERE a.is_active = 1 GROUP BY a.area_code, a.name, a.location, a.latitude, a.longitude "
                    + "HAVING COUNT(m.slot_id) > 0 ORDER BY a.area_code";
            try (PreparedStatement ps = conn.prepareStatement(areaSql); ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    JsonObject a = new JsonObject();
                    a.addProperty("area_code", rs.getString("area_code"));
                    a.addProperty("name", rs.getString("name"));
                    put(a, "location", rs.getString("location"));
                    // v3: fake coordinates until the real ones are entered (sql/03_v2_v3.sql); null when unknown
                    java.math.BigDecimal lat = rs.getBigDecimal("latitude");
                    java.math.BigDecimal lng = rs.getBigDecimal("longitude");
                    if (lat != null && lng != null) {
                        a.addProperty("latitude", lat.doubleValue());
                        a.addProperty("longitude", lng.doubleValue());
                    } else {
                        a.add("latitude", com.google.gson.JsonNull.INSTANCE);
                        a.add("longitude", com.google.gson.JsonNull.INSTANCE);
                    }
                    a.addProperty("slot_count", rs.getInt("slot_count"));
                    a.addProperty("available", rs.getInt("available"));
                    a.addProperty("offline", rs.getInt("offline"));
                    a.addProperty("alert", staff ? rs.getInt("alerts") : 0);
                    areas.add(a);
                    String code = rs.getString("area_code");
                    if (chosen == null || code.equalsIgnoreCase(areaCode)) {
                        chosen = code;   // the first area, unless the page asked for another one
                    }
                }
            }
            root.add("areas", areas);
            if (chosen == null) {
                root.add("banks", new JsonArray());
                return root;
            }
            for (int i = 0; i < areas.size(); i++) {
                JsonObject a = areas.get(i).getAsJsonObject();
                if (a.get("area_code").getAsString().equals(chosen)) {
                    JsonObject current = new JsonObject();
                    current.addProperty("area_code", chosen);
                    current.add("name", a.get("name"));
                    current.add("location", a.get("location"));
                    root.add("area", current);
                }
            }

            // the booking form needs the plans, priced for every size (v3: size factor, then the card 5% off)
            java.util.List<AppConfigDao.SlotSize> sizes = new AppConfigDao().sizes();
            JsonArray plans = new JsonArray();
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT plan_id, plan_name, duration_min, price FROM StoragePlan WHERE is_active = 1 ORDER BY duration_min");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    JsonObject p = new JsonObject();
                    p.addProperty("plan_id", rs.getInt(1));
                    p.addProperty("plan_name", rs.getString(2));
                    p.addProperty("duration_min", rs.getInt(3));
                    p.addProperty("price", rs.getInt(4));
                    p.addProperty("price_card", util.Pricing.priceFor(rs.getInt(4), "CARD"));   // v2: card 5% off
                    JsonObject prices = new JsonObject();
                    for (AppConfigDao.SlotSize z : sizes) {
                        JsonObject byMethod = new JsonObject();
                        for (String m : DepositDao.OPEN_METHODS) {
                            byMethod.addProperty(m, util.Pricing.slotPrice(rs.getInt(4), z.pricePct, m));
                        }
                        prices.add(z.code, byMethod);
                    }
                    p.add("prices", prices);
                    plans.add(p);
                }
            }
            root.add("plans", plans);

            // the banks of the chosen area
            JsonArray banks = new JsonArray();
            Map<Integer, JsonArray> slotsOfBank = new HashMap<>();
            String bankSql = "SELECT b.bank_id, b.bank_code, b.name, b.device_id, b.door_rows, v.status AS device_status, v.device_code "
                    + "FROM LockerBank b JOIN LockerArea a ON a.area_id = b.area_id LEFT JOIN Device v ON v.device_id = b.device_id "
                    + "WHERE a.area_code = ? AND b.status = N'ACTIVE' ORDER BY b.bank_code";
            try (PreparedStatement ps = conn.prepareStatement(bankSql)) {
                ps.setString(1, chosen);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        JsonObject b = new JsonObject();
                        b.addProperty("bank_id", rs.getInt("bank_id"));
                        b.addProperty("bank_code", rs.getString("bank_code"));
                        b.addProperty("name", rs.getString("name"));
                        int deviceId = rs.getInt("device_id");
                        if (rs.wasNull() || !staff) {          // an internal id, only the ADMIN reconnect form needs it
                            b.add("device_id", com.google.gson.JsonNull.INSTANCE);
                        } else {
                            b.addProperty("device_id", deviceId);
                        }
                        String devStatus = rs.getString("device_status");
                        put(b, "device_status", devStatus != null ? devStatus : "NONE");   // NONE: no box fitted yet
                        b.addProperty("rows", rs.getInt("door_rows"));
                        put(b, "device_code", rs.getString("device_code"));
                        JsonArray slots = new JsonArray();
                        b.add("slots", slots);
                        slotsOfBank.put(rs.getInt("bank_id"), slots);
                        banks.add(b);
                    }
                }
            }
            root.add("banks", banks);

            // the slots: status from the view, the booking on it, the open alert and ticket
            String slotSql = "SELECT m.slot_id, m.slot_code, m.size_code, m.size_cm, m.bank_id, m.display_status, "
                    + "m.is_locked, m.is_escalated, d.overdue_fee, d.overdue_hours, "
                    + "CONVERT(VARCHAR(27), d.reserved_at, 121) AS reserved_at, "
                    + "d.deposit_id, d.user_id, u.username, CONVERT(VARCHAR(27), d.hold_until, 121) AS hold_until, "
                    + "CONVERT(VARCHAR(27), d.due_at, 121) AS due_at, al.alert_id, al.label AS alert_label, tk.ticket_id "
                    + "FROM v_LockerSlotMap m "
                    + "JOIN LockerArea a ON a.area_id = m.area_id "
                    + "LEFT JOIN Deposit d ON d.slot_id = m.slot_id AND d.status IN (N'RESERVED', N'ACTIVE') "
                    + "LEFT JOIN Users u ON u.user_id = d.user_id "
                    + "OUTER APPLY (SELECT TOP 1 x.alert_id, x.label FROM Alert x JOIN LockerSession ls ON ls.session_id = x.session_id "
                    + "             WHERE ls.slot_id = m.slot_id AND x.status = N'OPEN' ORDER BY x.alert_id DESC) al "
                    + "OUTER APPLY (SELECT TOP 1 t.ticket_id FROM MaintenanceTicket t JOIN Alert x ON x.alert_id = t.alert_id "
                    + "             JOIN LockerSession ls ON ls.session_id = x.session_id "
                    + "             WHERE ls.slot_id = m.slot_id AND t.status = N'OPEN' ORDER BY t.ticket_id DESC) tk "
                    + "WHERE a.area_code = ? ORDER BY m.bank_code, m.slot_code";
            try (PreparedStatement ps = conn.prepareStatement(slotSql)) {
                ps.setString(1, chosen);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        JsonArray target = slotsOfBank.get(rs.getInt("bank_id"));
                        if (target == null) {
                            continue;   // a bank that is not ACTIVE
                        }
                        JsonObject s = new JsonObject();
                        s.addProperty("slot_id", rs.getInt("slot_id"));
                        s.addProperty("slot_code", rs.getString("slot_code"));
                        s.addProperty("size", rs.getString("size_code"));
                        put(s, "size_cm", rs.getString("size_cm"));
                        s.addProperty("status", rs.getString("display_status"));
                        int owner = rs.getInt("user_id");
                        boolean hasOwner = !rs.wasNull();
                        boolean mine = hasOwner && owner == userId;
                        s.addProperty("mine", mine);
                        put(s, "occupant", staff && hasOwner ? rs.getString("username") : null);
                        long depositId = rs.getLong("deposit_id");
                        boolean hasDeposit = !rs.wasNull();
                        if (hasDeposit && (mine || staff)) {
                            s.addProperty("deposit_id", depositId);
                        } else {
                            s.add("deposit_id", com.google.gson.JsonNull.INSTANCE);
                        }
                        put(s, "hold_until", iso(rs.getString("hold_until")));
                        // v3: the overdue lock is public (the door is closed for everyone); the money only for owner and staff
                        s.addProperty("locked", rs.getInt("is_locked") == 1);
                        s.addProperty("escalated", staff && rs.getInt("is_escalated") == 1);
                        if (hasDeposit && (mine || staff)) {
                            put(s, "reserved_at", iso(rs.getString("reserved_at")));
                            s.addProperty("overdue_fee", rs.getLong("overdue_fee"));
                            s.addProperty("overdue_hours", rs.getInt("overdue_hours"));
                        }
                        put(s, "due_at", iso(rs.getString("due_at")));
                        int alertId = rs.getInt("alert_id");
                        if (staff && !rs.wasNull()) {
                            JsonObject alert = new JsonObject();
                            alert.addProperty("alert_id", alertId);
                            alert.addProperty("label", rs.getString("alert_label"));
                            s.add("alert", alert);
                        } else {
                            s.add("alert", com.google.gson.JsonNull.INSTANCE);
                        }
                        int ticketId = rs.getInt("ticket_id");
                        if (staff && !rs.wasNull()) {
                            s.addProperty("ticket_id", ticketId);
                        } else {
                            s.add("ticket_id", com.google.gson.JsonNull.INSTANCE);
                        }
                        target.add(s);
                    }
                }
            }
        }
        return root;
    }
}
