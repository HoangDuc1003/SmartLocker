package test;

import static org.testng.Assert.assertEquals;

import dao.DbContext;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import org.testng.SkipException;
import org.testng.annotations.Test;
import service.AuditVerifier;
import service.AuditVerifier.Row;

/**
 * The tamper-evident log: a chain that is intact verifies, a row that was edited is found.
 * The first two tests need no database. The last two run against PRJ301_LOCKER and are skipped when it is not there.
 */
public class AuditChainDatabaseIntegrationTest {

    private static final Charset UTF16LE = Charset.forName("UTF-16LE");

    private static String sha256(String text) throws Exception {
        StringBuilder sb = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(text.getBytes(UTF16LE))) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /** Builds a valid chain of n rows the way Audit_Append does. */
    private static List<Row> chainOf(int n) throws Exception {
        List<Row> rows = new ArrayList<Row>();
        String prev = AuditVerifier.ZERO_HASH;
        for (int i = 1; i <= n; i++) {
            String ts = "2026-10-09T10:00:0" + i + ".1234567";
            String text = i + "|" + ts + "|1|ACTION" + i + "|USER|" + i + "||" + prev;
            String hash = sha256(text);
            rows.add(new Row(i, ts, 1, "ACTION" + i, "USER", i, "", prev, hash));
            prev = hash;
        }
        return rows;
    }

    @Test
    public void anIntactChainVerifies() throws Exception {
        assertEquals(AuditVerifier.findFirstBroken(chainOf(5)), -1L);
    }

    @Test
    public void anEditedRowIsFoundAtTheRowThatWasEdited() throws Exception {
        List<Row> rows = chainOf(5);
        rows.get(2).action = "TAMPERED-BY-TESTNG";          // somebody edits row 3 in SSMS
        assertEquals(AuditVerifier.findFirstBroken(rows), 3L);
    }

    // ---- against the real database ----

    /** A SkipException marks the test as skipped, not failed, on a machine where the database is not installed. */
    private static void skipWithoutDatabase() {
        try (Connection conn = DbContext.getConnection()) {
            if (conn == null || conn.isClosed()) {
                throw new SkipException("No database connection");
            }
        } catch (SQLException e) {
            throw new SkipException("PRJ301_LOCKER is not available: " + e.getMessage());
        }
    }

    @Test
    public void theRealLogIsIntactBeforeAnyTampering() throws Exception {
        skipWithoutDatabase();
        assertEquals(AuditVerifier.findFirstBroken(), -1L);
    }

    @Test(dependsOnMethods = "theRealLogIsIntactBeforeAnyTampering")
    public void tamperingWithARealRowIsDetectedAndUndone() throws Exception {
        skipWithoutDatabase();
        List<Row> rows = AuditVerifier.loadRows();
        if (rows.isEmpty()) {
            throw new SkipException("The log is empty, sign in once first");
        }
        long target = rows.get(rows.size() - 1).auditId;
        String original = rows.get(rows.size() - 1).action;
        try {
            update(target, "TAMPERED-BY-TESTNG");
            assertEquals(AuditVerifier.findFirstBroken(), target);
        } finally {
            update(target, original);                       // always put it back
        }
        assertEquals(AuditVerifier.findFirstBroken(), -1L);
    }

    private static void update(long auditId, String action) throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("UPDATE AuditLog SET action = ? WHERE audit_id = ?")) {
            ps.setString(1, action);
            ps.setLong(2, auditId);
            ps.executeUpdate();
        }
    }
}
