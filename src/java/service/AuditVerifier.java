package service;

import dao.DbContext;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * Recomputes the whole hash chain of the audit log and finds the first row that does not match.
 * The text that is hashed must be built exactly as Audit_Append builds it in SQL.
 */
public class AuditVerifier {

    /** The columns Audit_Append hashed, as text, plus what is stored. */
    public static class Row {
        public long auditId;
        public String tsText;        // CONVERT(NVARCHAR(33), ts, 126) done by SQL, so the text is identical
        public int actor;
        public String action;
        public String objectType;
        public long objectId;
        public String diff;          // "" for NULL
        public String prevHash;
        public String chainHash;

        public Row(long auditId, String tsText, int actor, String action, String objectType, long objectId,
                   String diff, String prevHash, String chainHash) {
            this.auditId = auditId;
            this.tsText = tsText;
            this.actor = actor;
            this.action = action;
            this.objectType = objectType;
            this.objectId = objectId;
            this.diff = diff == null ? "" : diff;
            this.prevHash = prevHash;
            this.chainHash = chainHash;
        }
    }

    /** The prev_hash of the first row of the chain: 64 zeros. */
    public static final String ZERO_HASH = "0000000000000000000000000000000000000000000000000000000000000000";

    /** SQL Server hashes an NVARCHAR as UTF-16 little endian, so Java must hash the same bytes. */
    private static final Charset UTF16LE = Charset.forName("UTF-16LE");

    private static String toHex(byte[] bytes) {   // Java 8 has no HexFormat
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /** The audit_id of the first broken row, or -1 when the whole chain is intact. Works on rows already loaded. */
    public static long findFirstBroken(List<Row> rows) {
        // walk the chain in order: the link to the previous row, then the recomputed hash
        String prevHash = ZERO_HASH;
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (Row r : rows) {
                String text = r.auditId + "|" + r.tsText + "|" + r.actor + "|" + r.action + "|" + r.objectType + "|"
                        + r.objectId + "|" + r.diff + "|" + prevHash;
                String expected = toHex(digest.digest(text.getBytes(UTF16LE)));
                if (!prevHash.equals(r.prevHash) || !expected.equals(r.chainHash)) {
                    return r.auditId;
                }
                prevHash = expected;
            }
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
        return -1;
    }

    /** Reads the log from the database in chain order. */
    public static List<Row> loadRows() throws SQLException {
        // the query converts ts to text in SQL and turns NULL into an empty diff
        String sql = "SELECT a.audit_id, CONVERT(NVARCHAR(33), a.ts, 126), a.actor_user_id, a.action, a.object_type, "
                + "a.object_id, ISNULL(a.diff_json, N''), h.prev_hash, h.chain_hash "
                + "FROM AuditLog a JOIN HashChain h ON h.audit_id = a.audit_id ORDER BY h.anchor_id";
        List<Row> rows = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                rows.add(new Row(rs.getLong(1), rs.getString(2), rs.getInt(3), rs.getString(4), rs.getString(5),
                        rs.getLong(6), rs.getString(7), rs.getString(8), rs.getString(9)));
            }
        }
        return rows;
    }

    /** The audit_id of the first broken row, or -1 when intact. */
    public static long findFirstBroken() throws SQLException {
        return findFirstBroken(loadRows());
    }
}
