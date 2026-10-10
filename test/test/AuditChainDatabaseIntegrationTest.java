package test;

import static org.testng.Assert.assertEquals;

import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import org.testng.annotations.Test;
import service.AuditVerifier;
import service.AuditVerifier.Row;

/**
 * SKELETON. Explained in docs/HUONG_DAN_TUNG_FILE.md, section "test/AuditChainDatabaseIntegrationTest.java".
 * The tamper-evident log: a chain that is intact verifies, a row that was edited is found.
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

    // TODO anEditedRowIsFoundAtTheRowThatWasEdited   (change rows.get(2).action, expect the audit_id 3)
    // TODO theRealLogIsIntactBeforeAnyTampering      (needs the database: throw new SkipException when there is none)
    // TODO tamperingWithARealRowIsDetectedAndUndone  (UPDATE AuditLog SET action = ... on the last row, verify, then put it back in finally)
}
