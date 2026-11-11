package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertNull;
import static org.testng.Assert.assertTrue;

import controller.LoginController;
import dao.DbContext;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.ref.WeakReference;
import java.lang.reflect.Proxy;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Arrays;
import java.util.Iterator;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;
import service.AuditVerifier;
import service.AuditVerifier.Row;
import service.LockerMonitor;

/**
 * H1: a flood of failed logins must not fill the log with what strangers type, the chain check must not hold the
 * whole log in memory, and the dashboard snapshot must not walk the log itself.
 */
public class AuditFloodDatabaseIntegrationTest {

    /** Writes to the database, so it refuses anything but a throw-away one. */
    @BeforeClass
    public void onlyOnATestDatabase() throws SQLException {
        try (Connection conn = DbContext.getConnection(); Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT DB_NAME()")) {
            rs.next();
            assertTrue(rs.getString(1).startsWith("SL_"), "DB_URL must point to an SL_* database, got " + rs.getString(1));
        }
    }

    // ---- LoginController ----

    /** Opens the protected doPost, the real path a POST takes. */
    private static class Login extends LoginController {
        void post(String username, String password) throws Exception {
            HttpServletRequest req = (HttpServletRequest) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[] {HttpServletRequest.class}, (p, m, a) -> {
                        switch (m.getName()) {
                            case "getParameter": return "username".equals(a[0]) ? username : password;
                            case "getHeader":    return "Accept".equals(a[0]) ? "application/json" : null;
                            default:             throw new UnsupportedOperationException(m.getName());
                        }
                    });
            PrintWriter out = new PrintWriter(new StringWriter());
            HttpServletResponse res = (HttpServletResponse) Proxy.newProxyInstance(getClass().getClassLoader(),
                    new Class<?>[] {HttpServletResponse.class},
                    (p, m, a) -> "getWriter".equals(m.getName()) ? out : null);
            doPost(req, res);
        }
    }

    /** {action, diff_json} of the newest row, read after a login that must have added one. */
    private static String[] newestAudit() throws SQLException {
        try (Connection conn = DbContext.getConnection(); Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT TOP 1 action, diff_json FROM AuditLog ORDER BY audit_id DESC")) {
            rs.next();
            return new String[] {rs.getString(1), rs.getString(2)};
        }
    }

    @Test
    public void aStrangersUsernameIsNotStored() throws Exception {
        char[] junk = new char[2 * 1024 * 1024];     // Tomcat's default maxPostSize
        Arrays.fill(junk, 'x');
        new Login().post(new String(junk), "whatever");
        String[] row = newestAudit();
        assertEquals(row[0], "LOGIN_FAIL");
        assertNull(row[1], "an unknown username may be a password typed in the wrong box");
    }

    @Test
    public void aRealAccountIsStoredAsTheDatabaseSpellsIt() throws Exception {
        new Login().post("STUDENT1", "not-the-password");
        String[] row = newestAudit();
        assertEquals(row[0], "LOGIN_FAIL");
        assertEquals(row[1], "username=student1");
    }

    @Test
    public void theStoredNameIsCutAt100Characters() {
        char[] name = new char[300];
        Arrays.fill(name, 'n');
        assertEquals(LoginController.loginFailDiff(new String(name)).length(), "username=".length() + 100);
        assertNull(LoginController.loginFailDiff(null));
    }

    // ---- AuditVerifier ----

    private static String sha256(String text) throws Exception {
        StringBuilder sb = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(text.getBytes(Charset.forName("UTF-16LE")))) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /** Builds a valid chain lazily and remembers whether an old row could still be reached when the next was asked for. */
    private static class LazyChain implements Iterator<Row> {
        final int size;
        int brokenAt = -1;
        int made;
        String prev = AuditVerifier.ZERO_HASH;
        WeakReference<Row> last;
        WeakReference<Row> beforeLast;
        boolean retained;

        LazyChain(int size) {
            this.size = size;
        }

        @Override public boolean hasNext() {
            return made < size;
        }

        @Override public Row next() {
            // two rows back: the very last one may still sit in a dead local of the caller's frame
            System.gc();
            if (beforeLast != null && beforeLast.get() != null) {
                retained = true;
            }
            try {
                made++;
                String ts = "2026-10-09T10:00:00." + made;
                String hash = sha256(made + "|" + ts + "|1|A|USER|" + made + "||" + prev);
                Row r = new Row(made, ts, 1, made == brokenAt ? "TAMPERED" : "A", "USER", made, "", prev, hash);
                prev = hash;
                beforeLast = last;
                last = new WeakReference<>(r);
                return r;
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
        }
    }

    @Test
    public void thePassedRowsAreNotHeldInMemory() {
        LazyChain chain = new LazyChain(8);
        assertEquals(AuditVerifier.findFirstBroken(chain), -1L);
        assertEquals(chain.made, 8);
        assertFalse(chain.retained, "a row that was already checked must be collectable");
    }

    @Test
    public void aBrokenRowStopsTheWalkAtThatRow() {
        LazyChain chain = new LazyChain(8);
        chain.brokenAt = 3;
        assertEquals(AuditVerifier.findFirstBroken(chain), 3L);
        assertEquals(chain.made, 3, "rows after the first broken one are not read");
    }

    // ---- LockerMonitor ----

    private static void setAction(long id, String action) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("UPDATE AuditLog SET action = ? WHERE audit_id = ?")) {
            ps.setString(1, action);
            ps.setLong(2, id);
            ps.executeUpdate();
        }
    }

    /** The snapshot cache answers for 3 s; wait it out so getSnapshot really builds a new one. */
    private static boolean snapshotSaysValid() throws InterruptedException {
        Thread.sleep(3100);
        return LockerMonitor.getSnapshot().kpis.auditChainValid;
    }

    @Test
    public void theSnapshotReadsTheStoredResultAndOnlyTheScheduledCheckWalksTheLog() throws Exception {
        long id;
        String action;
        try (Connection conn = DbContext.getConnection(); Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT TOP 1 audit_id, action FROM AuditLog ORDER BY audit_id DESC")) {
            rs.next();
            id = rs.getLong(1);
            action = rs.getString(2);
        }
        LockerMonitor.checkAuditChain();
        assertTrue(snapshotSaysValid());
        try {
            setAction(id, "TAMPERED-BY-TESTNG");
            assertTrue(snapshotSaysValid(), "building a snapshot must not walk the log");
            LockerMonitor.checkAuditChain();
            assertFalse(snapshotSaysValid(), "the check stores its result for the snapshot");
        } finally {
            setAction(id, action);
        }
        LockerMonitor.checkAuditChain();
        assertTrue(snapshotSaysValid());
    }
}
