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
 * util.Pricing must give the same numbers as the SQL of sql/09_v3.sql. Runs against PRJ301_LOCKER and is skipped
 * when the database (or the v3 script) is not there. Every change is made in one transaction and rolled back.
 */
public class PricingDatabaseIntegrationTest {

    private static Connection open() {
        try {
            Connection conn = DbContext.getConnection();
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT OBJECT_ID('dbo.fn_SlotPrice'), OBJECT_ID('dbo.SlotSize')")) {
                rs.next();
                if (rs.getObject(1) == null || rs.getObject(2) == null) {
                    conn.close();
                    throw new SkipException("sql/09_v3.sql has not been run");
                }
            }
            return conn;
        } catch (SQLException e) {
            throw new SkipException("PRJ301_LOCKER is not available: " + e.getMessage());
        }
    }

    @Test
    public void slotPricesMatchForEveryPlanSizeAndMethod() throws SQLException {
        String sql = "SELECT p.price, z.size_code, z.price_pct, m.method, dbo.fn_SlotPrice(p.price, z.price_pct, m.method) "
                + "FROM StoragePlan p CROSS JOIN SlotSize z "
                + "CROSS JOIN (VALUES (N'PIN'), (N'CARD'), (N'FINGERPRINT')) m(method)";
        int rows = 0;
        try (Connection conn = open(); PreparedStatement ps = conn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                long expected = Pricing.slotPrice(rs.getLong(1), rs.getInt(3), rs.getString(4));
                assertEquals(rs.getLong(5), expected, rs.getLong(1) + " " + rs.getString(2) + " " + rs.getString(4));
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
                    throw new SkipException("Run sql/test_v2_setup.sql first (needs v2pin without an open booking)");
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
