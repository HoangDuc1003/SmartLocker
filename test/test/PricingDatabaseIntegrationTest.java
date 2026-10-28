package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertNotNull;

import dao.DbContext;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import org.testng.SkipException;
import org.testng.annotations.Test;
import util.Pricing;

/**
 * util.Pricing must give the same numbers as the SQL of sql/03_v2_v3.sql. Runs against PRJ301_LOCKER and is skipped
 * when the database (or the v3 script) is not there. Every change is made in one transaction and rolled back.
 */
public class PricingDatabaseIntegrationTest {

    private static Connection open() {
        try {
            Connection conn = DbContext.getConnection();
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT OBJECT_ID('dbo.fn_SizePrice'), OBJECT_ID('dbo.SlotSize')")) {
                rs.next();
                if (rs.getObject(1) == null || rs.getObject(2) == null) {
                    conn.close();
                    throw new SkipException("sql/03_v2_v3.sql has not been run");
                }
            }
            return conn;
        } catch (SQLException e) {
            throw new SkipException("PRJ301_LOCKER is not available: " + e.getMessage());
        }
    }

    @Test
    public void slotPricesMatchForEveryPlanAndSize() throws SQLException {
        String sql = "SELECT p.price, z.size_code, z.price_pct, dbo.fn_SizePrice(p.price, z.price_pct) "
                + "FROM StoragePlan p CROSS JOIN SlotSize z";
        int rows = 0;
        try (Connection conn = open(); PreparedStatement ps = conn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                long expected = Pricing.sizePrice(rs.getLong(1), rs.getInt(3));
                assertEquals(rs.getLong(4), expected, rs.getLong(1) + " " + rs.getString(2));
                rows++;
            }
        }
        if (rows == 0) {
            throw new SkipException("No plans or sizes");
        }
    }

    @Test
    public void hourAndLateFeeMatchForEverySize() throws SQLException {
        try (Connection conn = open()) {
            long basePrice;
            int baseMin;
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT TOP 1 price, duration_min FROM StoragePlan "
                         + "WHERE is_active = 1 AND price > 0 AND duration_min > 0 ORDER BY duration_min, plan_id")) {
                if (!rs.next()) {
                    throw new SkipException("No plan on sale");
                }
                basePrice = rs.getLong(1);
                baseMin = rs.getInt(2);
            }
            int feePct;
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT dbo.fn_Config(N'OVERDUE_FEE_PCT')")) {
                rs.next();
                feePct = rs.getInt(1);
            }
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT size_code, price_pct, dbo.fn_HourRate(price_pct), "
                         + "dbo.fn_OverdueRate(price_pct) FROM SlotSize")) {
                while (rs.next()) {
                    int pct = rs.getInt(2);
                    assertEquals(rs.getLong(3), Pricing.hourRate(basePrice, baseMin, pct), "hour " + rs.getString(1));
                    assertEquals(rs.getLong(4), Pricing.overdueRate(basePrice, baseMin, pct, feePct), "late " + rs.getString(1));
                }
            }
        }
    }

    /** "Tự chọn": fn_CustomPrice and Pricing.customPrice agree for S/M/L, 1..23 hours, 1..7 days and refused minutes. */
    @Test
    public void customPricesMatchForEverySizeHoursAndDays() throws SQLException {
        try (Connection conn = open()) {
            if (scalarInt(conn, "SELECT 1 WHERE OBJECT_ID('dbo.fn_CustomPrice') IS NOT NULL") == null) {
                throw new SkipException("fn_CustomPrice is missing: run the custom duration part of sql/03_v2_v3.sql");
            }
            long dayPrice = scalarLong(conn, "SELECT TOP 1 price FROM StoragePlan "
                    + "WHERE is_active = 1 AND price > 0 AND duration_min = 1440 ORDER BY plan_id");
            if (dayPrice <= 0) {
                throw new SkipException("No day pass on sale");
            }
            int maxHours = (int) scalarLong(conn, "SELECT ISNULL(dbo.fn_Config(N'CUSTOM_MAX_HOURS'), 23)");
            int maxDays = (int) scalarLong(conn, "SELECT ISNULL(dbo.fn_Config(N'CUSTOM_MAX_DAYS'), 7)");
            int multiPct = (int) scalarLong(conn, "SELECT ISNULL(dbo.fn_Config(N'CUSTOM_MULTI_DAY_PCT'), 90)");
            int weekPct = (int) scalarLong(conn, "SELECT ISNULL(dbo.fn_Config(N'CUSTOM_WEEK_PCT'), 80)");
            java.util.List<Integer> minutes = new java.util.ArrayList<>();
            for (int h = 1; h <= 23; h++) {
                minutes.add(h * 60);
            }
            for (int d = 1; d <= 7; d++) {
                minutes.add(d * 1440);
            }
            minutes.add(90);            // not whole hours
            minutes.add(1440 * 8);      // longer than CUSTOM_MAX_DAYS
            int rows = 0;
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT size_code, price_pct, dbo.fn_HourRate(price_pct), dbo.fn_CustomPrice(price_pct, ?) FROM SlotSize")) {
                for (int m : minutes) {
                    ps.setInt(1, m);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            long sql = rs.getLong(4);
                            if (rs.wasNull()) {
                                sql = -1;
                            }
                            long java = Pricing.customPrice(rs.getLong(3), dayPrice, rs.getInt(2), m,
                                    maxHours, maxDays, multiPct, weekPct);
                            assertEquals(sql, java, rs.getString(1) + " " + m + " min");
                            rows++;
                        }
                    }
                }
            }
            if (rows == 0) {
                throw new SkipException("No sizes");
            }
        }
    }

    /** A custom booking of 3 days: priced by fn_CustomPrice, keeps the day pass and its minutes, old calls still work. */
    @Test
    public void customReserveChargesTheCustomPriceAndKeepsTheMinutes() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                Integer user = scalarInt(conn, "SELECT user_id FROM Users WHERE username = N'v2pin' AND NOT EXISTS "
                        + "(SELECT 1 FROM Deposit d WHERE d.user_id = Users.user_id AND d.status IN (N'RESERVED', N'ACTIVE'))");
                Integer slot = scalarInt(conn, "SELECT TOP 1 m.slot_id FROM v_LockerSlotMap m JOIN LockerSlot s "
                        + "ON s.locker_slot_id = m.slot_id WHERE s.status = N'AVAILABLE' AND m.display_status = N'AVAILABLE' "
                        + "AND m.size_code = 'L' ORDER BY m.slot_id");
                Integer dayPlan = scalarInt(conn, "SELECT TOP 1 plan_id FROM StoragePlan WHERE is_active = 1 AND price > 0 "
                        + "AND duration_min = 1440 ORDER BY plan_id");
                if (user == null || slot == null || dayPlan == null || scalarInt(conn,
                        "SELECT 1 WHERE OBJECT_ID('dbo.fn_CustomPrice') IS NOT NULL") == null) {
                    throw new SkipException("Run sql/test_setup.sql first (needs v2pin without an open booking, a free L slot)");
                }
                exec(conn, "UPDATE Users SET balance = 1000000 WHERE user_id = " + user);
                long expected = scalarLong(conn, "SELECT dbo.fn_CustomPrice(price_pct, 4320) FROM SlotSize WHERE size_code = 'L'");
                long id;
                try (CallableStatement cs = conn.prepareCall("{call Deposit_Reserve(?, ?, ?, ?, ?, ?)}")) {
                    cs.setInt(1, user);
                    cs.setInt(2, slot);
                    cs.setInt(3, 0);
                    cs.registerOutParameter(4, java.sql.Types.BIGINT);
                    cs.setString(5, "PIN");
                    cs.setInt(6, 4320);
                    cs.execute();
                    id = cs.getLong(4);
                }
                assertEquals(scalarLong(conn, "SELECT paid_amount FROM Deposit WHERE deposit_id = " + id), expected);
                assertEquals(scalarLong(conn, "SELECT custom_min FROM Deposit WHERE deposit_id = " + id), 4320L);
                assertEquals(scalarLong(conn, "SELECT plan_id FROM Deposit WHERE deposit_id = " + id), (long) dayPlan);
                assertEquals(scalarLong(conn, "SELECT balance FROM Users WHERE user_id = " + user), 1000000 - expected);
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    /** A booking 2 h 10 min late: charged 3 hours once, the wallet may go below zero, a second run adds nothing. */
    @Test
    public void lateFeeIsChargedOnceAndMayMakeADebt() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                Integer user = scalarInt(conn, "SELECT user_id FROM Users WHERE username = N'v2pin' AND NOT EXISTS "
                        + "(SELECT 1 FROM Deposit d WHERE d.user_id = Users.user_id AND d.status IN (N'RESERVED', N'ACTIVE'))");
                Integer slot = scalarInt(conn, "SELECT TOP 1 locker_slot_id FROM LockerSlot WHERE status = N'AVAILABLE' "
                        + "AND size_code = 'M' ORDER BY locker_slot_id");
                Integer plan = scalarInt(conn, "SELECT TOP 1 plan_id FROM StoragePlan WHERE duration_min = 120 ORDER BY plan_id");
                if (user == null || slot == null || plan == null) {
                    throw new SkipException("Run sql/test_setup.sql first (needs v2pin without an open booking)");
                }
                exec(conn, "UPDATE Users SET balance = 5000 WHERE user_id = " + user);
                exec(conn, "UPDATE LockerSlot SET status = N'OCCUPIED' WHERE locker_slot_id = " + slot);
                long id;
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO Deposit (user_id, slot_id, plan_id, paid_amount, status, started_at, due_at, size_pct, overdue_rate) "
                        + "VALUES (?, ?, ?, 6500, N'ACTIVE', DATEADD(MINUTE, -250, SYSUTCDATETIME()), "
                        + "DATEADD(MINUTE, -130, SYSUTCDATETIME()), 130, dbo.fn_OverdueRate(130))",
                        Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, user);
                    ps.setInt(2, slot);
                    ps.setInt(3, plan);
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        keys.next();
                        id = keys.getLong(1);
                    }
                }
                charge(conn, id);
                charge(conn, id);
                long rate = scalarLong(conn, "SELECT overdue_rate FROM Deposit WHERE deposit_id = " + id);
                assertEquals(scalarLong(conn, "SELECT overdue_hours FROM Deposit WHERE deposit_id = " + id), 3L);
                assertEquals(scalarLong(conn, "SELECT overdue_fee FROM Deposit WHERE deposit_id = " + id), 3 * rate);
                assertNotNull(scalarInt(conn, "SELECT 1 FROM Deposit WHERE locked_at IS NOT NULL AND deposit_id = " + id));
                assertEquals(scalarLong(conn, "SELECT balance FROM Users WHERE user_id = " + user), 5000 - 3 * rate);
                assertNotNull(scalarInt(conn, "SELECT 1 FROM Deposit WHERE status = N'ACTIVE' AND deposit_id = " + id),
                        "the booking stays ACTIVE, the slot is not released");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    /** A cancel 6 minutes after booking, inside the 15-minute hold: CANCEL_LATE_REFUND_PCT back, as Pricing computes it. */
    @Test
    public void lateCancelRefundsTheSameAsPricing() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                Integer user = scalarInt(conn, "SELECT user_id FROM Users WHERE username = N'v2pin' AND NOT EXISTS "
                        + "(SELECT 1 FROM Deposit d WHERE d.user_id = Users.user_id AND d.status IN (N'RESERVED', N'ACTIVE'))");
                Integer slot = scalarInt(conn, "SELECT TOP 1 locker_slot_id FROM LockerSlot WHERE status = N'AVAILABLE' "
                        + "AND size_code = 'M' ORDER BY locker_slot_id");
                Integer plan = scalarInt(conn, "SELECT TOP 1 plan_id FROM StoragePlan WHERE duration_min = 120 ORDER BY plan_id");
                if (user == null || slot == null || plan == null) {
                    throw new SkipException("Run sql/test_setup.sql first (needs v2pin without an open booking)");
                }
                int pct = (int) scalarLong(conn, "SELECT ISNULL(dbo.fn_Config(N'CANCEL_LATE_REFUND_PCT'), 50)");
                exec(conn, "UPDATE Users SET balance = 100000 WHERE user_id = " + user);
                exec(conn, "UPDATE LockerSlot SET status = N'RESERVED' WHERE locker_slot_id = " + slot);
                long id;
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO Deposit (user_id, slot_id, plan_id, paid_amount, status, reserved_at, hold_until, size_pct) "
                        + "VALUES (?, ?, ?, 6500, N'RESERVED', DATEADD(MINUTE, -6, SYSUTCDATETIME()), "
                        + "DATEADD(MINUTE, 9, SYSUTCDATETIME()), 130)",
                        Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, user);
                    ps.setInt(2, slot);
                    ps.setInt(3, plan);
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        keys.next();
                        id = keys.getLong(1);
                    }
                }
                try (CallableStatement cs = conn.prepareCall("{call Deposit_Cancel(?, ?, ?)}")) {
                    cs.setLong(1, id);
                    cs.setInt(2, user);
                    cs.setLong(3, Pricing.lateCancelRefund(6500, pct));
                    cs.execute();
                }
                assertEquals(scalarLong(conn, "SELECT balance FROM Users WHERE user_id = " + user),
                        100000 + Pricing.lateCancelRefund(6500, pct));
                assertNotNull(scalarInt(conn, "SELECT 1 FROM Deposit WHERE status = N'CANCELLED' AND deposit_id = " + id));
                assertNotNull(scalarInt(conn, "SELECT 1 FROM LockerSlot WHERE status = N'AVAILABLE' AND locker_slot_id = " + slot));
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    private static void charge(Connection conn, long id) throws SQLException {
        try (CallableStatement cs = conn.prepareCall("{call Deposit_ChargeOverdue(?)}")) {
            cs.setLong(1, id);
            cs.execute();
        }
    }

    private static void exec(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement()) {
            st.executeUpdate(sql);
        }
    }

    private static Integer scalarInt(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            return rs.next() ? rs.getInt(1) : null;
        }
    }

    /** The first column of the first row as a number, -1 when there is no row. */
    private static long scalarLong(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            return rs.next() ? rs.getLong(1) : -1;
        }
    }
}
