package service;

import util.Todo;
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

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: the character set and the hex helper

    /** The audit_id of the first broken row, or -1 when the whole chain is intact. Works on rows already loaded. */
    public static long findFirstBroken(List<Row> rows) {
        throw Todo.of("AuditVerifier.findFirstBroken: walk the chain in order: the link to the previous row, then the recomputed hash");
    }

    /** Reads the log from the database in chain order. */
    public static List<Row> loadRows() throws SQLException {
        throw Todo.of("AuditVerifier.loadRows: the query converts ts to text in SQL and turns NULL into an empty diff");
    }

    /** The audit_id of the first broken row, or -1 when intact. */
    public static long findFirstBroken() throws SQLException {
        throw Todo.of("AuditVerifier.findFirstBroken");
    }
}
