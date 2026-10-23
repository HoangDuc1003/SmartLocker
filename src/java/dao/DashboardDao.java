package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Data Access Object for Dashboard KPIs.
 *
 * <p>Design rule: one Connection per public method, minimum round-trips.
 * All slot stats (total / occupied / available / maintenance+fault / overdue)
 * are fetched with a single SUM(CASE …) aggregation instead of six
 * separate SELECT COUNT(*) queries, so the snapshot stays cheap even when
 * 50 browsers poll every two seconds.
 */
public class DashboardDao {

    // ─── Inner DTOs (serialised to JSON by Gson) ──────────────────────────────

    /** Flat KPI numbers for the top-level "kpis" field. */
    public static class KpiSnapshot {
        public int  totalSlots;
        public int  occupiedSlots;
        public int  availableSlots;
        public int  maintenanceOrFaultSlots;
        public int  overdueSessions;
        public int  activeAlerts;
        public int  offlineDevices;
        public boolean auditChainValid;   // filled by LockerMonitor cache

        public int getTotalSlots() { return totalSlots; }
        public int getOccupiedSlots() { return occupiedSlots; }
        public int getAvailableSlots() { return availableSlots; }
        public int getMaintenanceOrFaultSlots() { return maintenanceOrFaultSlots; }
        public int getOverdueSessions() { return overdueSessions; }
        public int getActiveAlerts() { return activeAlerts; }
        public int getOfflineDevices() { return offlineDevices; }
        public boolean isAuditChainValid() { return auditChainValid; }
    }

    /** Per-area slot breakdown for the "slotBreakdown" array. */
    public static class AreaBreakdown {
        public String areaCode;
        public String areaName;
        public int    total;
        public int    occupied;
        public int    available;
        public int    fault;

        public String getAreaCode() { return areaCode; }
        public String getAreaName() { return areaName; }
        public int getTotal() { return total; }
        public int getOccupied() { return occupied; }
        public int getAvailable() { return available; }
        public int getFault() { return fault; }
    }

    /** Recent alert row for the "recentAlerts" array. */
    public static class AlertRow {
        public int     alertId;
        public int     deviceId;
        public String  deviceCode;
        public String  source;
        public String  label;
        public String  severity;       // CRITICAL / WARNING / INFO — derived from risk_score
        public Double  riskScore;
        public String  status;
        public String  createdAt;

        public int getAlertId() { return alertId; }
        public int getDeviceId() { return deviceId; }
        public String getDeviceCode() { return deviceCode; }
        public String getSource() { return source; }
        public String getLabel() { return label; }
        public String getSeverity() { return severity; }
        public Double getRiskScore() { return riskScore; }
        public String getStatus() { return status; }
        public String getCreatedAt() { return createdAt; }
    }

    /** Device health row for the "deviceHealth" array. */
    public static class DeviceHealth {
        public int     deviceId;
        public String  deviceCode;
        public String  location;
        public String  firmware;
        public String  status;         // ACTIVE / MAINTENANCE / OFFLINE
        public String  health;         // ONLINE / DEGRADED / OFFLINE — derived from last_seen_sec
        public Integer lastSeenSec;

        public int getDeviceId() { return deviceId; }
        public String getDeviceCode() { return deviceCode; }
        public String getLocation() { return location; }
        public String getFirmware() { return firmware; }
        public String getStatus() { return status; }
        public String getHealth() { return health; }
        public Integer getLastSeenSec() { return lastSeenSec; }
    }


    // ─── Usage statistics for the charts (served by api.DashboardStatsApi, cached there) ──────────

    /** Booking counts per hour and weekday, revenue per day and open alerts per type. Times are Vietnam time (UTC+7). */
    public static class UsageStats {
        public int[]   hourlyToday     = new int[24];
        public int[]   hourlyYesterday = new int[24];
        public int[][] heat            = new int[7][24];   // [Monday..Sunday][hour], the last 28 days
        public List<Map<String, Object>> revenue = new ArrayList<>();      // {date, amount}, the last 7 days
        public List<Map<String, Object>> alertsOpen = new ArrayList<>();   // {label, count}
        public int bookingsToday;
        public int bookingsYesterday;
    }

    private static final java.time.ZoneOffset VN = java.time.ZoneOffset.ofHours(7);

    /** Three small aggregations plus the open alerts; the caller caches the result for a minute. */
    public UsageStats fetchUsageStats() throws SQLException {
        final String vn = "DATEADD(hour, 7, reserved_at)";
        final String sqlHourly =
            "SELECT CAST(" + vn + " AS date) AS d, DATEPART(hour, " + vn + ") AS h, COUNT(*) AS n " +
            "FROM Deposit WHERE reserved_at >= DATEADD(day, -3, SYSUTCDATETIME()) " +
            "GROUP BY CAST(" + vn + " AS date), DATEPART(hour, " + vn + ")";
        // 1900-01-01 was a Monday, so the remainder is 0 for Monday; it does not depend on SET DATEFIRST
        final String sqlHeat =
            "SELECT DATEDIFF(day, '19000101', CAST(" + vn + " AS date)) % 7 AS dow, " +
            "  DATEPART(hour, " + vn + ") AS h, COUNT(*) AS n " +
            "FROM Deposit WHERE reserved_at >= DATEADD(day, -28, SYSUTCDATETIME()) " +
            "GROUP BY DATEDIFF(day, '19000101', CAST(" + vn + " AS date)) % 7, DATEPART(hour, " + vn + ")";
        final String sqlRevenue =
            "SELECT CAST(DATEADD(hour, 7, started_at) AS date) AS d, SUM(paid_amount + overdue_fee) AS amount " +
            "FROM Deposit WHERE status IN ('ACTIVE', 'COMPLETED') AND started_at >= DATEADD(day, -8, SYSUTCDATETIME()) " +
            "GROUP BY CAST(DATEADD(hour, 7, started_at) AS date)";
        final String sqlAlerts =
            "SELECT ISNULL(label, N'UNKNOWN') AS label, COUNT(*) AS n FROM Alert WHERE status = 'OPEN' " +
            "GROUP BY label ORDER BY COUNT(*) DESC";

        UsageStats st = new UsageStats();
        java.time.LocalDate today = java.time.LocalDate.now(VN);
        java.time.LocalDate yesterday = today.minusDays(1);
        try (Connection conn = DbContext.getConnection()) {
            try (PreparedStatement ps = conn.prepareStatement(sqlHourly); ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    java.time.LocalDate d = rs.getDate("d").toLocalDate();
                    int h = rs.getInt("h");
                    int n = rs.getInt("n");
                    if (d.equals(today)) {
                        st.hourlyToday[h] += n;
                        st.bookingsToday += n;
                    } else if (d.equals(yesterday)) {
                        st.hourlyYesterday[h] += n;
                        st.bookingsYesterday += n;
                    }
                }
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlHeat); ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    st.heat[rs.getInt("dow")][rs.getInt("h")] = rs.getInt("n");
                }
            }
            Map<java.time.LocalDate, Long> byDay = new LinkedHashMap<>();
            try (PreparedStatement ps = conn.prepareStatement(sqlRevenue); ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    byDay.put(rs.getDate("d").toLocalDate(), rs.getLong("amount"));
                }
            }
            for (int back = 6; back >= 0; back--) {   // always seven bars, a day without income is 0
                java.time.LocalDate d = today.minusDays(back);
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("date", d.toString());
                row.put("amount", byDay.containsKey(d) ? byDay.get(d) : 0L);
                st.revenue.add(row);
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlAlerts); ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("label", rs.getString("label"));
                    row.put("count", rs.getInt("n"));
                    st.alertsOpen.add(row);
                }
            }
        }
        return st;
    }

    // ─── Queries ──────────────────────────────────────────────────────────────

    /**
     * Single-query KPI aggregation: total, occupied, available, maintenance+fault, overdue.
     * Uses the existing view {@code v_LockerSlotMap}; one pass through the view.
     */
    public KpiSnapshot fetchKpis() throws SQLException {
        // All slot counts in one aggregation — no full-table scans repeated per metric
        final String sqlSlots =
            "SELECT " +
            "  COUNT(*)                                              AS total, " +
            "  SUM(CASE WHEN display_status = 'AVAILABLE'  THEN 1 ELSE 0 END) AS avail, " +
            "  SUM(CASE WHEN display_status IN ('OCCUPIED','RESERVED','OVERDUE') THEN 1 ELSE 0 END) AS occ, " +
            "  SUM(CASE WHEN display_status IN ('MAINTENANCE','FAULT')  THEN 1 ELSE 0 END) AS maint, " +
            "  SUM(CASE WHEN display_status = 'OVERDUE'    THEN 1 ELSE 0 END) AS overdue " +
            "FROM v_LockerSlotMap";

        final String sqlAlerts  = "SELECT COUNT(*) FROM Alert  WHERE status = 'OPEN'";
        final String sqlDevices = "SELECT COUNT(*) FROM Device WHERE status = 'OFFLINE'";

        KpiSnapshot s = new KpiSnapshot();
        try (Connection conn = DbContext.getConnection()) {
            try (PreparedStatement ps = conn.prepareStatement(sqlSlots);
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    s.totalSlots              = rs.getInt("total");
                    s.availableSlots          = rs.getInt("avail");
                    s.occupiedSlots           = rs.getInt("occ");
                    s.maintenanceOrFaultSlots = rs.getInt("maint");
                    s.overdueSessions         = rs.getInt("overdue");
                }
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlAlerts);
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) s.activeAlerts = rs.getInt(1);
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlDevices);
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) s.offlineDevices = rs.getInt(1);
            }
        }
        return s;
    }

    /**
     * Backward-compatible counts for legacy code and controllers:
     * free, inUse, overdue, openAlerts, offlineDevices.
     */
    public Map<String, Integer> lockerCounts() throws SQLException {
        KpiSnapshot s = fetchKpis();
        Map<String, Integer> counts = new LinkedHashMap<>();
        counts.put("free", s.availableSlots);
        counts.put("inUse", s.occupiedSlots);
        counts.put("overdue", s.overdueSessions);
        counts.put("openAlerts", s.activeAlerts);
        counts.put("offlineDevices", s.offlineDevices);
        return counts;
    }

    /**
     * Slot breakdown grouped by LockerArea — one aggregation join.
     */
    public List<AreaBreakdown> fetchAreaBreakdown() throws SQLException {
        final String sql =
            "SELECT a.area_code, a.name AS area_name, " +
            "  COUNT(*)                                                  AS total, " +
            "  SUM(CASE WHEN v.display_status IN ('OCCUPIED','RESERVED','OVERDUE') THEN 1 ELSE 0 END) AS occupied, " +
            "  SUM(CASE WHEN v.display_status = 'AVAILABLE' THEN 1 ELSE 0 END) AS available, " +
            "  SUM(CASE WHEN v.display_status IN ('MAINTENANCE','FAULT') THEN 1 ELSE 0 END) AS fault " +
            "FROM v_LockerSlotMap v " +
            "JOIN LockerBank  b ON b.bank_id  = v.bank_id " +
            "JOIN LockerArea  a ON a.area_id  = b.area_id " +
            "GROUP BY a.area_code, a.name " +
            "ORDER BY a.area_code";

        List<AreaBreakdown> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                AreaBreakdown row = new AreaBreakdown();
                row.areaCode  = rs.getString("area_code");
                row.areaName  = rs.getString("area_name");
                row.total     = rs.getInt("total");
                row.occupied  = rs.getInt("occupied");
                row.available = rs.getInt("available");
                row.fault     = rs.getInt("fault");
                list.add(row);
            }
        }
        return list;
    }

    /**
     * Up to {@code limit} most-recent alerts with device code, for the live feed.
     */
    public List<AlertRow> fetchRecentAlerts(int limit) throws SQLException {
        final String sql =
            "SELECT TOP (?) a.alert_id, a.device_id, d.device_code, a.source, a.label, " +
            "  a.risk_score, a.status, " +
            "  CONVERT(VARCHAR(19), a.created_at, 120) AS created_at_txt " +
            "FROM Alert a " +
            "LEFT JOIN Device d ON d.device_id = a.device_id " +
            "ORDER BY a.alert_id DESC";

        List<AlertRow> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    AlertRow row = new AlertRow();
                    row.alertId    = rs.getInt("alert_id");
                    row.deviceId   = rs.getInt("device_id");
                    row.deviceCode = rs.getString("device_code");
                    row.source     = rs.getString("source");
                    row.label      = rs.getString("label");
                    row.status     = rs.getString("status");
                    row.createdAt  = rs.getString("created_at_txt");
                    double risk    = rs.getDouble("risk_score");
                    row.riskScore  = rs.wasNull() ? null : risk;
                    row.severity   = deriveSeverity(row.label, row.riskScore);
                    list.add(row);
                }
            }
        }
        return list;
    }

    /**
     * All devices with health classification derived from last_seen_sec.
     * <ul>
     *   <li>ONLINE   — last_seen &lt; 30 s</li>
     *   <li>DEGRADED — last_seen 30–300 s</li>
     *   <li>OFFLINE  — last_seen &gt; 300 s or NULL, or status = OFFLINE</li>
     * </ul>
     */
    public List<DeviceHealth> fetchDeviceHealth() throws SQLException {
        final String sql =
            "SELECT device_id, device_code, location, firmware, status, " +
            "  DATEDIFF(SECOND, last_seen, SYSUTCDATETIME()) AS last_seen_sec " +
            "FROM Device ORDER BY device_code";

        List<DeviceHealth> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                DeviceHealth row = new DeviceHealth();
                row.deviceId   = rs.getInt("device_id");
                row.deviceCode = rs.getString("device_code");
                row.location   = rs.getString("location");
                row.firmware   = rs.getString("firmware");
                row.status     = rs.getString("status");
                int sec        = rs.getInt("last_seen_sec");
                row.lastSeenSec = rs.wasNull() ? null : sec;
                row.health     = deriveHealth(row.status, row.lastSeenSec);
                list.add(row);
            }
        }
        return list;
    }

    /**
     * The last {@code limit} sessions of one device for the mini sparkline chart.
     * Keys: time (ISO string), a (door_open_sec), b (weight_delta_g).
     */
    public List<Map<String, Object>> recentSessions(int deviceId, int limit) throws SQLException {
        final String sql =
            "SELECT TOP (?) CONVERT(VARCHAR(19), measured_at, 120) AS t, " +
            "  door_open_sec, weight_delta_g " +
            "FROM LockerSession WHERE device_id = ? ORDER BY measured_at DESC";

        List<Map<String, Object>> points = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            ps.setInt(2, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> p = new LinkedHashMap<>();
                    p.put("time", rs.getString("t"));
                    p.put("a",    rs.getDouble("door_open_sec"));
                    p.put("b",    rs.getDouble("weight_delta_g"));
                    points.add(0, p);   // reverse so oldest is first
                }
            }
        }
        return points;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static String deriveSeverity(String label, Double riskScore) {
        if (label != null && (label.contains("TAMPER") || label.contains("FORCED"))) {
            return "CRITICAL";
        }
        if (riskScore != null && riskScore >= 0.7) return "CRITICAL";
        if (riskScore != null && riskScore >= 0.4) return "WARNING";
        return "INFO";
    }

    private static String deriveHealth(String status, Integer lastSeenSec) {
        if ("OFFLINE".equals(status))       return "OFFLINE";
        if (lastSeenSec == null)            return "OFFLINE";
        if (lastSeenSec < 30)              return "ONLINE";
        if (lastSeenSec < 300)             return "DEGRADED";
        return "OFFLINE";
    }
}
