package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertNotEquals;
import static org.testng.Assert.assertNotNull;
import static org.testng.Assert.assertTrue;

import dao.DbContext;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.HashMap;
import java.util.Map;
import org.testng.SkipException;
import org.testng.annotations.Test;

/**
 * v7 phone tap and card (sql/04_phone.sql): Device_TapIssue, Device_Authorize with method PHONE or CARD, Enroll_Finish. Each test books a PHONE slot
 * for a user without an open booking, in one transaction that is rolled back. Skipped when the database or 04 is missing.
 */
public class PhoneTapDatabaseIntegrationTest {

    private static Connection open() {
        try {
            Connection conn = DbContext.getConnection();
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT OBJECT_ID('dbo.Device_TapIssue')")) {
                rs.next();
                if (rs.getObject(1) == null) {
                    conn.close();
                    throw new SkipException("sql/04_phone.sql has not been run");
                }
            }
            return conn;
        } catch (SQLException e) {
            throw new SkipException("The database is not available: " + e.getMessage());
        }
    }

    private static Integer intOrNull(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            return rs.next() ? rs.getInt(1) : null;
        }
    }

    /** The first result set of a procedure that runs EXEC inside (skips the update counts). */
    private static Map<String, Object> row(CallableStatement cs) throws SQLException {
        boolean isResult = cs.execute();
        while (!isResult && cs.getUpdateCount() != -1) {
            isResult = cs.getMoreResults();
        }
        Map<String, Object> row = new HashMap<>();
        if (isResult) {
            try (ResultSet rs = cs.getResultSet()) {
                if (rs.next()) {
                    ResultSetMetaData md = rs.getMetaData();
                    for (int i = 1; i <= md.getColumnCount(); i++) {
                        row.put(md.getColumnLabel(i), rs.getObject(i));
                    }
                }
            }
        }
        return row;
    }

    private static String issue(Connection conn, int device) throws SQLException {
        try (CallableStatement cs = conn.prepareCall("{call Device_TapIssue(?)}")) {
            cs.setInt(1, device);
            Object token = row(cs).get("token");
            assertNotNull(token, "Device_TapIssue gave no token");
            return token.toString().trim();
        }
    }

    private static Map<String, Object> tap(Connection conn, int device, int user, String token, String intent) throws SQLException {
        try (CallableStatement cs = conn.prepareCall("{call Device_Authorize(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}")) {
            cs.setInt(1, device);
            cs.setString(2, "PHONE");
            cs.setNull(3, Types.NVARCHAR);
            cs.setNull(4, Types.NVARCHAR);
            cs.setNull(5, Types.INTEGER);
            cs.setString(6, "PHONE");
            cs.setString(7, intent);
            cs.setNull(8, Types.CHAR);
            cs.setInt(9, user);
            cs.setString(10, token);
            return row(cs);
        }
    }

    private static void heartbeat(Connection conn, int device) throws SQLException {
        try (CallableStatement cs = conn.prepareCall("{call Device_Heartbeat(?)}")) {
            cs.setInt(1, device);
            cs.execute();
        }
    }

    private static int bookPhone(Connection conn, int device) throws SQLException {
        return book(conn, device, "PHONE");
    }

    /** A user with money, no open booking and no enrolled card; books a free slot of the device. Returns the user id. */
    private static int book(Connection conn, int device, String method) throws SQLException {
        Integer user = intOrNull(conn, "SELECT TOP 1 u.user_id FROM Users u JOIN UserRole ur ON ur.user_id = u.user_id "
                + "JOIN Roles r ON r.role_id = ur.role_id WHERE r.role_name = N'END_USER' AND u.balance >= 100000 "
                + "AND ISNULL(u.status, N'ACTIVE') = N'ACTIVE' "
                + "AND NOT EXISTS (SELECT 1 FROM Deposit d WHERE d.user_id = u.user_id AND d.status IN (N'RESERVED', N'ACTIVE')) "
                + "AND NOT EXISTS (SELECT 1 FROM UserCard c WHERE c.user_id = u.user_id AND c.registered_device_id IS NOT NULL) "
                + "AND (SELECT COUNT(*) FROM Deposit d WHERE d.user_id = u.user_id AND d.status = N'NO_SHOW' "
                + "     AND d.reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME())) < 3 ORDER BY u.user_id");
        Integer slot = intOrNull(conn, "SELECT TOP 1 s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "WHERE b.device_id = " + device + " AND s.status = N'AVAILABLE' ORDER BY s.locker_slot_id");
        Integer plan = intOrNull(conn, "SELECT TOP 1 plan_id FROM StoragePlan WHERE is_active = 1 AND price > 0 ORDER BY duration_min");
        if (user == null || slot == null || plan == null) {
            throw new SkipException("No user, free slot or plan for a booking on device " + device);
        }
        try (CallableStatement cs = conn.prepareCall("{call Deposit_Reserve(?, ?, ?, ?, ?)}")) {
            cs.setInt(1, user);
            cs.setInt(2, slot);
            cs.setInt(3, plan);
            cs.registerOutParameter(4, Types.BIGINT);
            cs.setString(5, method);
            cs.execute();
        }
        return user;
    }

    private static Integer realBox(Connection conn) throws SQLException {
        return intOrNull(conn, "SELECT TOP 1 v.device_id FROM Device v WHERE EXISTS (SELECT 1 FROM LockerBank b WHERE b.device_id = v.device_id) "
                + "AND NOT EXISTS (SELECT 1 FROM (SELECT TOP 1 p.params_json FROM OperatingProfile p WHERE p.device_id = v.device_id "
                + "ORDER BY p.profile_id DESC) p WHERE p.params_json LIKE N'%\"demo\":true%') ORDER BY v.device_id");
    }

    @Test
    public void aTokenOpensOnceAndANewOneFollows() throws SQLException {
        try (Connection conn = open()) {
            Integer dev = realBox(conn);
            if (dev == null) {
                throw new SkipException("No real (non-demo) box with a bank");
            }
            conn.setAutoCommit(false);
            try {
                heartbeat(conn, dev);
                int user = bookPhone(conn, dev);
                String t1 = issue(conn, dev);
                assertTrue(t1.matches("[A-Za-z0-9]{12}"), t1);
                assertEquals(issue(conn, dev), t1, "the same token within a minute while unused");

                Map<String, Object> bad = tap(conn, dev, user, "zzzzzzzzzzzz", "ASK");
                assertEquals(bad.get("reason"), "TAP_EXPIRED");
                assertEquals(((Number) bad.get("attempts_left")).intValue(), 5, "a stale tap is no guess");

                Map<String, Object> ok = tap(conn, dev, user, t1, "ASK");
                assertEquals(ok.get("result"), "UNLOCK");
                assertEquals(ok.get("phase"), "CHECK_IN");
                assertNotNull(ok.get("command_id"), "the phone open is a command for the heartbeat");
                assertEquals(intOrNull(conn, "SELECT COUNT(*) FROM AuthAttempt WHERE device_id = " + dev
                        + " AND method = N'TAP' AND ok = 1 AND at > DATEADD(MINUTE, -1, SYSUTCDATETIME())").intValue() >= 1, true);

                assertEquals(tap(conn, dev, user, t1, "ASK").get("reason"), "TAP_EXPIRED", "a used token");
                assertNotEquals(issue(conn, dev), t1, "a new token after the use");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    /** The card lives beside the phone: a first card enrolls at the box for free and then opens, a phone opens a CARD booking. */
    @Test
    public void aCardEnrollsWithoutADepositAndOpens() throws SQLException {
        try (Connection conn = open()) {
            Integer dev = realBox(conn);
            if (dev == null) {
                throw new SkipException("No real (non-demo) box with a bank");
            }
            conn.setAutoCommit(false);
            try {
                heartbeat(conn, dev);
                int user = book(conn, dev, "CARD");
                int balance = intOrNull(conn, "SELECT balance FROM Users WHERE user_id = " + user);
                String code;
                try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery(
                        "SELECT enroll_code FROM Deposit WHERE user_id = " + user + " AND status = N'RESERVED'")) {
                    rs.next();
                    code = rs.getString(1);
                }
                assertNotNull(code, "a first card needs an enroll code");
                String uid = "E2E" + Long.toHexString(System.nanoTime()).toUpperCase();
                uid = uid.length() > 20 ? uid.substring(0, 20) : uid;
                try (CallableStatement cs = conn.prepareCall("{call Enroll_Finish(?, ?, ?, ?, ?)}")) {
                    cs.setInt(1, dev);
                    cs.setString(2, "CARD");
                    cs.setString(3, code);
                    cs.setNull(4, Types.INTEGER);
                    cs.setString(5, uid);
                    assertEquals(row(cs).get("result"), "OK");
                }
                assertEquals(intOrNull(conn, "SELECT balance FROM Users WHERE user_id = " + user).intValue(), balance, "no card deposit");
                assertEquals(intOrNull(conn, "SELECT registered_device_id FROM UserCard WHERE card_uid = N'" + uid + "'"), dev);
                assertEquals(intOrNull(conn, "SELECT deposit_amount FROM UserCard WHERE card_uid = N'" + uid + "'").intValue(), 0);
                try (CallableStatement cs = conn.prepareCall("{call Device_Authorize(?, ?, ?, ?, ?, ?, ?)}")) {
                    cs.setInt(1, dev);
                    cs.setString(2, "CARD");
                    cs.setNull(3, Types.NVARCHAR);
                    cs.setString(4, uid);
                    cs.setNull(5, Types.INTEGER);
                    cs.setString(6, "DEVICE");
                    cs.setString(7, "ASK");
                    Map<String, Object> r = row(cs);
                    assertEquals(r.get("result"), "UNLOCK", String.valueOf(r.get("reason")));
                    assertEquals(r.get("phase"), "CHECK_IN");
                }
                Map<String, Object> tapped = tap(conn, dev, user, issue(conn, dev), "ASK");
                assertEquals(tapped.get("result"), "CHOOSE", "the owner's phone also opens a CARD booking");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void aTapIsNotBlockedByThePinLockoutOfThePhonePage() throws SQLException {
        try (Connection conn = open()) {
            Integer dev = realBox(conn);
            if (dev == null) {
                throw new SkipException("No real (non-demo) box with a bank");
            }
            conn.setAutoCommit(false);
            try {
                heartbeat(conn, dev);
                int user = bookPhone(conn, dev);
                try (Statement st = conn.createStatement()) {
                    st.executeUpdate("INSERT INTO AuthAttempt (device_id, at, method, ok, reason) "
                            + "VALUES (" + dev + ", SYSUTCDATETIME(), N'LOCK_PHONE', 0, N'LOCK_START')");
                }
                Map<String, Object> r = tap(conn, dev, user, issue(conn, dev), "ASK");
                assertEquals(r.get("result"), "UNLOCK", String.valueOf(r.get("reason")));
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void aUserWithoutABookingHereGetsNoBooking() throws SQLException {
        try (Connection conn = open()) {
            Integer dev = realBox(conn);
            Integer user = intOrNull(conn, "SELECT TOP 1 u.user_id FROM Users u WHERE NOT EXISTS (SELECT 1 FROM Deposit d "
                    + "WHERE d.user_id = u.user_id AND (d.status IN (N'RESERVED', N'ACTIVE') OR d.status = N'NO_SHOW')) ORDER BY u.user_id");
            if (dev == null || user == null) {
                throw new SkipException("No real box or no user without bookings");
            }
            conn.setAutoCommit(false);
            try {
                heartbeat(conn, dev);
                Map<String, Object> r = tap(conn, dev, user, issue(conn, dev), "ASK");
                assertEquals(r.get("reason"), "NO_BOOKING");
                assertEquals(intOrNull(conn, "SELECT COUNT(*) FROM DeviceTap WHERE device_id = " + dev
                        + " AND used_at IS NOT NULL AND used_at > DATEADD(SECOND, -5, SYSUTCDATETIME())").intValue(), 0,
                        "a refused tap does not use the token");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void aDemoBoxOpensWithoutAToken() throws SQLException {
        try (Connection conn = open()) {
            Integer dev = intOrNull(conn, "SELECT TOP 1 v.device_id FROM Device v WHERE EXISTS (SELECT 1 FROM LockerBank b "
                    + "JOIN LockerSlot s ON s.bank_id = b.bank_id WHERE b.device_id = v.device_id AND s.status = N'AVAILABLE') "
                    + "AND EXISTS (SELECT 1 FROM (SELECT TOP 1 p.params_json FROM OperatingProfile p WHERE p.device_id = v.device_id "
                    + "ORDER BY p.profile_id DESC) p WHERE p.params_json LIKE N'%\"demo\":true%') ORDER BY v.device_id");
            if (dev == null) {
                throw new SkipException("No demo box with a free slot");
            }
            conn.setAutoCommit(false);
            try {
                heartbeat(conn, dev);
                int user = bookPhone(conn, dev);
                Map<String, Object> r = tap(conn, dev, user, null, "ASK");
                assertEquals(r.get("result"), "UNLOCK", String.valueOf(r.get("reason")));
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }
}
