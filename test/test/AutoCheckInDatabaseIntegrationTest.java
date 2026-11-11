package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertNotNull;
import static org.testng.Assert.assertNotEquals;
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
 * v7.1 (sql/05_auto_checkin.sql): a reservation nobody checked in starts by itself at hold_until, the owner may open the
 * slot any time until it is due, nothing is refunded; a booking that was never opened simply ends at due_at + grace.
 * Each test books a slot in one transaction that is rolled back. Skipped when the database or script 05 is missing.
 */
public class AutoCheckInDatabaseIntegrationTest {

    private static Connection open() {
        try {
            Connection conn = DbContext.getConnection();
            try (Statement st = conn.createStatement();
                 ResultSet rs = st.executeQuery("SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.Deposit_ExpireNoShow')) "
                         + "LIKE N'%AUTO_CHECK_IN%' THEN 1 ELSE 0 END")) {
                rs.next();
                if (rs.getInt(1) == 0) {
                    conn.close();
                    throw new SkipException("sql/05_auto_checkin.sql has not been run");
                }
            }
            return conn;
        } catch (SQLException e) {
            throw new SkipException("The database is not available: " + e.getMessage());
        }
    }

    private static String text(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            return rs.next() ? rs.getString(1) : null;
        }
    }

    private static void exec(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement()) {
            st.execute(sql);
        }
    }

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

    /** Books a free slot of an ACTIVE box with a PIN for a user who may book; returns {deposit_id, user_id, slot_id}. */
    private static long[] book(Connection conn) throws SQLException {
        String user = text(conn, "SELECT TOP 1 u.user_id FROM Users u JOIN UserRole ur ON ur.user_id = u.user_id "
                + "JOIN Roles r ON r.role_id = ur.role_id WHERE r.role_name = N'END_USER' AND u.balance >= 100000 "
                + "AND ISNULL(u.status, N'ACTIVE') = N'ACTIVE' "
                + "AND NOT EXISTS (SELECT 1 FROM Deposit d WHERE d.user_id = u.user_id AND d.status IN (N'RESERVED', N'ACTIVE')) "
                + "AND (SELECT COUNT(*) FROM Deposit d WHERE d.user_id = u.user_id AND d.status = N'NO_SHOW' "
                + "     AND d.reserved_at > DATEADD(DAY, -7, SYSUTCDATETIME())) < 3 ORDER BY u.user_id");
        String slot = text(conn, "SELECT TOP 1 s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "JOIN Device v ON v.device_id = b.device_id WHERE s.status = N'AVAILABLE' AND v.status = N'ACTIVE' "
                + "ORDER BY s.locker_slot_id");
        String plan = text(conn, "SELECT TOP 1 plan_id FROM StoragePlan WHERE is_active = 1 AND price > 0 AND duration_min = 120");
        if (user == null || slot == null || plan == null) {
            throw new SkipException("No user, free slot or 2-hour plan");
        }
        try (CallableStatement cs = conn.prepareCall("{call Deposit_Reserve(?, ?, ?, ?, ?)}")) {
            cs.setInt(1, Integer.parseInt(user));
            cs.setInt(2, Integer.parseInt(slot));
            cs.setInt(3, Integer.parseInt(plan));
            cs.registerOutParameter(4, Types.BIGINT);
            cs.setString(5, "PIN");
            cs.execute();
            return new long[] {cs.getLong(4), Long.parseLong(user), Long.parseLong(slot)};
        }
    }

    private static void holdEnded(Connection conn, long deposit) throws SQLException {
        exec(conn, "UPDATE Deposit SET hold_until = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE deposit_id = " + deposit);
    }

    @Test
    public void aReservationNobodyCheckedInStartsByItself() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                long[] b = book(conn);
                holdEnded(conn, b[0]);
                int balance = Integer.parseInt(text(conn, "SELECT balance FROM Users WHERE user_id = " + b[1]));
                exec(conn, "EXEC Deposit_ExpireNoShow");
                assertEquals(text(conn, "SELECT status FROM Deposit WHERE deposit_id = " + b[0]), "ACTIVE");
                assertEquals(text(conn, "SELECT status FROM LockerSlot WHERE locker_slot_id = " + b[2]), "OCCUPIED");
                assertEquals(text(conn, "SELECT DATEDIFF(MINUTE, started_at, due_at) FROM Deposit WHERE deposit_id = " + b[0]), "120",
                        "the paid time starts at the auto check-in");
                assertEquals(text(conn, "SELECT CASE WHEN started_at = hold_until THEN 1 ELSE 0 END FROM Deposit WHERE deposit_id = " + b[0]), "1");
                assertEquals(text(conn, "SELECT COUNT(*) FROM AuditLog WHERE object_type = N'DEPOSIT' AND object_id = " + b[0]
                        + " AND action = N'AUTO_CHECK_IN'"), "1");
                assertEquals(Integer.parseInt(text(conn, "SELECT balance FROM Users WHERE user_id = " + b[1])), balance, "no refund, no extra charge");
                exec(conn, "EXEC Deposit_ExpireNoShow");     // a second run changes nothing
                assertEquals(text(conn, "SELECT COUNT(*) FROM AuditLog WHERE object_type = N'DEPOSIT' AND object_id = " + b[0]
                        + " AND action = N'AUTO_CHECK_IN'"), "1");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void anExpiredHoldStillOpensAtTheBoxAsACheckIn() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                long[] b = book(conn);
                String pin = text(conn, "SELECT pin_code FROM Deposit WHERE deposit_id = " + b[0]);
                String device = text(conn, "SELECT b.device_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id WHERE s.locker_slot_id = " + b[2]);
                holdEnded(conn, b[0]);                        // the job has not run yet
                try (CallableStatement cs = conn.prepareCall("{call Device_Authorize(?, ?, ?, ?, ?, ?, ?, ?)}")) {
                    cs.setInt(1, Integer.parseInt(device));
                    cs.setString(2, "PIN");
                    cs.setString(3, pin);
                    cs.setNull(4, Types.NVARCHAR);
                    cs.setNull(5, Types.INTEGER);
                    cs.setString(6, "DEVICE");
                    cs.setString(7, "ASK");
                    cs.setNull(8, Types.CHAR);
                    Map<String, Object> r = row(cs);
                    assertEquals(r.get("result"), "UNLOCK", String.valueOf(r.get("reason")));
                    assertEquals(r.get("phase"), "CHECK_IN");
                }
                assertEquals(text(conn, "SELECT status FROM Deposit WHERE deposit_id = " + b[0]), "ACTIVE");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void aBookingNeverOpenedEndsWithoutALateFee() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                long[] b = book(conn);
                holdEnded(conn, b[0]);
                exec(conn, "EXEC Deposit_ExpireNoShow");
                exec(conn, "UPDATE Deposit SET started_at = DATEADD(HOUR, -5, SYSUTCDATETIME()), due_at = DATEADD(HOUR, -3, SYSUTCDATETIME()) "
                        + "WHERE deposit_id = " + b[0]);
                int balance = Integer.parseInt(text(conn, "SELECT balance FROM Users WHERE user_id = " + b[1]));
                exec(conn, "EXEC Deposit_ExpireOverdue");
                assertEquals(text(conn, "SELECT status FROM Deposit WHERE deposit_id = " + b[0]), "NO_SHOW");
                assertEquals(text(conn, "SELECT status FROM LockerSlot WHERE locker_slot_id = " + b[2]), "AVAILABLE");
                assertEquals(Integer.parseInt(text(conn, "SELECT balance FROM Users WHERE user_id = " + b[1])), balance, "no late fee for an empty slot");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void aBookingThatWasOpenedStillLocksWhenOverdue() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                long[] b = book(conn);
                holdEnded(conn, b[0]);
                exec(conn, "EXEC Deposit_ExpireNoShow");
                exec(conn, "DECLARE @s INT = (SELECT user_id FROM Users WHERE username = N'system'); "
                        + "EXEC Audit_Append @s, N'ACCESS', N'DEPOSIT', " + b[0] + ", N'{\"method\":\"PIN\"}'");
                exec(conn, "UPDATE Deposit SET started_at = DATEADD(HOUR, -5, SYSUTCDATETIME()), due_at = DATEADD(HOUR, -3, SYSUTCDATETIME()) "
                        + "WHERE deposit_id = " + b[0]);
                exec(conn, "EXEC Deposit_ExpireOverdue");
                assertEquals(text(conn, "SELECT status FROM Deposit WHERE deposit_id = " + b[0]), "ACTIVE", "the things inside are kept");
                assertNotNull(text(conn, "SELECT locked_at FROM Deposit WHERE deposit_id = " + b[0]), "locked and charged as before");
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void afterTheHoldTheBookingCannotBeCancelled() throws SQLException {
        try (Connection conn = open()) {
            conn.setAutoCommit(false);
            try {
                long[] b = book(conn);
                holdEnded(conn, b[0]);
                exec(conn, "EXEC Deposit_ExpireNoShow");
                boolean refused = false;
                try (CallableStatement cs = conn.prepareCall("{call Deposit_Cancel(?, ?, ?)}")) {
                    cs.setLong(1, b[0]);
                    cs.setInt(2, (int) b[1]);
                    cs.setNull(3, Types.BIGINT);
                    cs.execute();
                } catch (SQLException e) {
                    refused = e.getErrorCode() == 50036;
                    conn.rollback();     // XACT_ABORT ended the transaction: nothing left to roll back
                    assertTrue(refused, "error " + e.getErrorCode() + " " + e.getMessage());
                    return;
                }
                assertTrue(refused, "a started booking must not be cancellable");
            } finally {
                try {
                    conn.rollback();
                } catch (SQLException ignored) {
                    // the transaction was already ended by the refused call
                }
                conn.setAutoCommit(true);
            }
        }
    }
}
