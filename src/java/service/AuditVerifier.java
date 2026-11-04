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
import java.util.Iterator;
import java.util.List;

/**
 * Recomputes the whole hash chain of the audit log and finds the first row that does not match, one row at a time:
 * the log can be larger than the heap.
 * The text that is hashed must be built exactly as Audit_Append builds it in SQL.
 */
public class AuditVerifier {

    /** The columns Audit_Append hashed, as text, plus what is stored. */
    public static class Row {
        public long auditId;
        public String tsText;        // CONVERT(NVARCHAR(33), ts, 126) done by SQL, so the text is identical
        public String actor;         // "" for NULL, as CONCAT in Audit_Append writes it
        public String action;
        public String objectType;
        public String objectId;      // "" for NULL
        public String diff;          // "" for NULL
        public String prevHash;
        public String chainHash;

        public Row(long auditId, String tsText, int actor, String action, String objectType, long objectId,
                   String diff, String prevHash, String chainHash) {
            this(auditId, tsText, Integer.valueOf(actor), action, objectType, Long.valueOf(objectId), diff, prevHash, chainHash);
        }

        /** Nullable actor and object id: CONCAT turns NULL into an empty string, so must we. */
        public Row(long auditId, String tsText, Integer actor, String action, String objectType, Long objectId,
                   String diff, String prevHash, String chainHash) {
            this.auditId = auditId;
            this.tsText = tsText;
            this.actor = actor == null ? "" : actor.toString();
            this.action = action == null ? "" : action;
            this.objectType = objectType == null ? "" : objectType;
            this.objectId = objectId == null ? "" : objectId.toString();
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

    /** Walks the chain in order, holding only the hash of the row before: the link to it, then the recomputed hash. */
    private static final class Walker {
        private final MessageDigest digest;
        private String prevHash = ZERO_HASH;

        Walker() {
            try {
                digest = MessageDigest.getInstance("SHA-256");
            } catch (NoSuchAlgorithmException e) {
                throw new IllegalStateException(e);
            }
        }

        /** False when this row does not continue the chain. */
        boolean accept(Row r) {
            String text = r.auditId + "|" + r.tsText + "|" + r.actor + "|" + r.action + "|" + r.objectType + "|"
                    + r.objectId + "|" + r.diff + "|" + prevHash;
            String expected = toHex(digest.digest(text.getBytes(UTF16LE)));
            if (!prevHash.equals(r.prevHash) || !expected.equals(r.chainHash)) {
                return false;
            }
            prevHash = expected;
            return true;
        }
    }

    /** The audit_id of the first broken row, or -1 when the whole chain is intact. Works on rows already loaded. */
    public static long findFirstBroken(List<Row> rows) {
        return findFirstBroken(rows.iterator());
    }

    /** Same, keeping no row that was already checked. */
    public static long findFirstBroken(Iterator<Row> rows) {
        Walker walker = new Walker();
        while (rows.hasNext()) {
            Row r = rows.next();
            if (!walker.accept(r)) {
                return r.auditId;
            }
        }
        return -1;
    }

    // the query converts ts to text in SQL and turns NULL into an empty diff
    private static final String LOG_IN_CHAIN_ORDER =
            "SELECT a.audit_id, CONVERT(NVARCHAR(33), a.ts, 126), a.actor_user_id, a.action, a.object_type, "
            + "a.object_id, ISNULL(a.diff_json, N''), h.prev_hash, h.chain_hash "
            + "FROM AuditLog a JOIN HashChain h ON h.audit_id = a.audit_id ORDER BY h.anchor_id";

    private static Row rowAt(ResultSet rs) throws SQLException {
        int actor = rs.getInt(3);
        Integer actorOrNull = rs.wasNull() ? null : actor;
        long objectId = rs.getLong(6);
        Long objectOrNull = rs.wasNull() ? null : objectId;
        return new Row(rs.getLong(1), rs.getString(2), actorOrNull, rs.getString(4), rs.getString(5),
                objectOrNull, rs.getString(7), rs.getString(8), rs.getString(9));
    }

    /** The whole log in memory, for the tests only: production code walks it with {@link #findFirstBroken()}. */
    public static List<Row> loadRows() throws SQLException {
        List<Row> rows = new ArrayList<>();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(LOG_IN_CHAIN_ORDER)) {
            while (rs.next()) {
                rows.add(rowAt(rs));
            }
        }
        return rows;
    }

    /** The audit_id of the first broken row, or -1 when intact. Reads the log as a stream (forward-only, adaptive buffering). */
    public static long findFirstBroken() throws SQLException {
        Walker walker = new Walker();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement(ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY);
             ResultSet rs = st.executeQuery(LOG_IN_CHAIN_ORDER)) {
            while (rs.next()) {
                Row r = rowAt(rs);
                if (!walker.accept(r)) {
                    return r.auditId;
                }
            }
        }
        return -1;
    }
}
