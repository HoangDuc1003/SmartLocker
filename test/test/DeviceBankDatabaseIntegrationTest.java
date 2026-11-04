package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertNotNull;
import static org.testng.Assert.assertNull;

import dao.DbContext;
import dao.LockerBankDao;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import org.testng.SkipException;
import org.testng.annotations.Test;

/**
 * Device_Heartbeat, Deposit_Complete and the slot-code rule of LockerBankDao against PRJ301_LOCKER.
 * Skipped when the database is not there. Changes are made in one transaction and rolled back.
 */
public class DeviceBankDatabaseIntegrationTest {

    private static Connection open() {
        try {
            return DbContext.getConnection();
        } catch (SQLException e) {
            throw new SkipException("PRJ301_LOCKER is not available: " + e.getMessage());
        }
    }

    private static int intQuery(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            if (!rs.next()) {
                throw new SkipException("No data for: " + sql);
            }
            return rs.getInt(1);
        }
    }

    @Test
    public void heartbeatBringsAnOfflineDeviceBackAndResolvesItsAlert() throws SQLException {
        try (Connection conn = open()) {
            int dev = intQuery(conn, "SELECT TOP 1 device_id FROM Device ORDER BY device_id");
            conn.setAutoCommit(false);
            try {
                try (Statement st = conn.createStatement()) {
                    st.executeUpdate("UPDATE Device SET status = N'OFFLINE' WHERE device_id = " + dev);
                    st.executeUpdate("INSERT INTO Alert (device_id, session_id, source, label) VALUES ("
                            + dev + ", NULL, N'RULE', N'DEVICE_OFFLINE')");
                }
                try (CallableStatement cs = conn.prepareCall("{call Device_Heartbeat(?)}")) {
                    cs.setInt(1, dev);
                    cs.execute();
                }
                assertEquals(intQuery(conn, "SELECT CASE WHEN status = N'ACTIVE' THEN 1 ELSE 0 END FROM Device WHERE device_id = " + dev), 1);
                assertEquals(intQuery(conn, "SELECT COUNT(*) FROM Alert WHERE device_id = " + dev
                        + " AND label = N'DEVICE_OFFLINE' AND status = N'OPEN'"), 0);
                assertEquals(intQuery(conn, "SELECT @@TRANCOUNT"), 1);
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void completeWithoutABookingKeepsTheCallersTransaction() throws SQLException {
        try (Connection conn = open()) {
            int dev = intQuery(conn, "SELECT TOP 1 device_id FROM Device ORDER BY device_id");
            conn.setAutoCommit(false);
            try {
                try (CallableStatement cs = conn.prepareCall("{call Deposit_Complete(?, ?)}")) {
                    cs.setInt(1, dev);
                    cs.setString(2, "NO-SUCH-SLOT");
                    cs.execute();
                }
                // the early return must COMMIT its own BEGIN TRAN, or the caller's count is off (error 266)
                assertEquals(intQuery(conn, "SELECT @@TRANCOUNT"), 1);
            } finally {
                conn.rollback();
                conn.setAutoCommit(true);
            }
        }
    }

    @Test
    public void bankAssignmentThatRepeatsASlotCodeIsReported() throws SQLException {
        int bank, otherDevice, ownDevice;
        try (Connection conn = open();
             PreparedStatement ps = conn.prepareStatement(
                     "SELECT TOP 1 s.bank_id, ob.device_id, b.device_id FROM LockerSlot s "
                     + "JOIN LockerBank b ON b.bank_id = s.bank_id "
                     + "JOIN LockerSlot o ON o.slot_code = s.slot_code AND o.bank_id <> s.bank_id "
                     + "JOIN LockerBank ob ON ob.bank_id = o.bank_id "
                     + "WHERE ob.device_id IS NOT NULL AND b.device_id IS NOT NULL AND ob.device_id <> b.device_id");
             ResultSet rs = ps.executeQuery()) {
            if (!rs.next()) {
                throw new SkipException("No two banks of different devices share a slot code");
            }
            bank = rs.getInt(1);
            otherDevice = rs.getInt(2);
            ownDevice = rs.getInt(3);
        }
        LockerBankDao dao = new LockerBankDao();
        assertNotNull(dao.slotCodeClash(bank, otherDevice), "moving the bank to the other device repeats a code");
        assertNull(dao.slotCodeClash(0, otherDevice), "a new bank has no slots");
        assertNull(dao.slotCodeClash(bank, null), "a bank without a device has no clash");
        // the live data has no repeated codes per device (sql/demo_box.sql 50904); the current assignment is clean
        try (Connection conn = open()) {
            int dupes = intQuery(conn, "SELECT COUNT(*) FROM (SELECT b.device_id FROM LockerSlot s JOIN LockerBank b "
                    + "ON b.bank_id = s.bank_id WHERE b.device_id = " + ownDevice
                    + " GROUP BY b.device_id, s.slot_code HAVING COUNT(*) > 1) x");
            if (dupes == 0) {
                assertNull(dao.slotCodeClash(bank, ownDevice));
            }
        }
    }
}
