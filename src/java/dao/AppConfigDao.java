package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import util.Pricing;

/**
 * v3: the business numbers (AppConfig) and the slot sizes (SlotSize) of sql/09_v3.sql, read for display.
 * The procedures read the same tables, so the page always shows the rule the database applies.
 * Both are kept for 60 seconds: they change only when an admin edits the tables.
 */
public class AppConfigDao {

    private static final long TTL_MS = 60_000L;

    /** One row of SlotSize plus the hour prices derived from the shortest plan on sale. */
    public static class SlotSize {
        public final String code;
        public final String sizeCm;
        public final int pricePct;
        public final List<String> items;
        public final long hourRate;      // one hour, for an extension
        public final long overdueRate;   // one late hour

        SlotSize(String code, String sizeCm, int pricePct, List<String> items, long hourRate, long overdueRate) {
            this.code = code;
            this.sizeCm = sizeCm;
            this.pricePct = pricePct;
            this.items = items;
            this.hourRate = hourRate;
            this.overdueRate = overdueRate;
        }

        // getters for JSP EL, which cannot read public fields
        public String getCode() { return code; }
        public String getSizeCm() { return sizeCm; }
        public int getPricePct() { return pricePct; }
        public List<String> getItems() { return items; }
        public long getHourRate() { return hourRate; }
        public long getOverdueRate() { return overdueRate; }
    }

    private static final class Cache {
        final Map<String, Long> config;
        final List<SlotSize> sizes;
        final long at = System.currentTimeMillis();

        Cache(Map<String, Long> config, List<SlotSize> sizes) {
            this.config = config;
            this.sizes = sizes;
        }
    }

    private static volatile Cache cache;

    private static Cache load() throws SQLException {
        Cache c = cache;
        if (c != null && System.currentTimeMillis() - c.at < TTL_MS) {
            return c;
        }
        Map<String, Long> config = new HashMap<>();
        List<SlotSize> sizes = new ArrayList<>();
        try (Connection conn = DbContext.getConnection()) {
            try (PreparedStatement ps = conn.prepareStatement("SELECT config_key, int_value FROM AppConfig");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    config.put(rs.getString(1), rs.getLong(2));
                }
            }
            long basePrice = 0;
            int baseMinutes = 0;
            try (PreparedStatement ps = conn.prepareStatement("SELECT TOP 1 price, duration_min FROM StoragePlan "
                    + "WHERE is_active = 1 AND price > 0 AND duration_min > 0 ORDER BY duration_min, plan_id");
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    basePrice = rs.getLong(1);
                    baseMinutes = rs.getInt(2);
                }
            }
            int feePct = (int) (long) config.getOrDefault("OVERDUE_FEE_PCT", (long) Pricing.OVERDUE_FEE_PCT);
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT size_code, size_cm, price_pct, items FROM SlotSize ORDER BY sort_no, size_code");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    List<String> items = new ArrayList<>();
                    for (String item : rs.getString(4).split(";")) {
                        if (!item.trim().isEmpty()) {
                            items.add(item.trim());
                        }
                    }
                    int pct = rs.getInt(3);
                    sizes.add(new SlotSize(rs.getString(1).trim(), rs.getString(2), pct, Collections.unmodifiableList(items),
                            Pricing.hourRate(basePrice, baseMinutes, pct),
                            Pricing.overdueRate(basePrice, baseMinutes, pct, feePct)));
                }
            }
        }
        c = new Cache(Collections.unmodifiableMap(config), Collections.unmodifiableList(sizes));
        cache = c;
        return c;
    }

    /** A number of AppConfig, or the fallback when the row is missing. */
    public long get(String key, long fallback) throws SQLException {
        Long v = load().config.get(key);
        return v == null ? fallback : v;
    }

    public int getInt(String key, int fallback) throws SQLException {
        return (int) get(key, fallback);
    }

    /** S, M, L in display order. */
    public List<SlotSize> sizes() throws SQLException {
        return load().sizes;
    }

    /** Forget the cached values (after an admin edit, and in tests). */
    public static void clear() {
        cache = null;
    }
}
