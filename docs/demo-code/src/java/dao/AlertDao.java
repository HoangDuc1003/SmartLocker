package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.List;
import model.Alert;
import util.Todo;

/** Alerts and their evidence. Every alert carries the reason it was raised. */
public class AlertDao {

    /** Stores an alert and its evidence in one transaction. Returns the alert id. risk is null for rules that have no score. */
    public int create(int deviceId, long sessionId, String source, String label, Double risk, List<String[]> evidence)
            throws SQLException {
        // one transaction: INSERT Alert, then one INSERT AlertEvidence per item
        try (Connection conn = DbContext.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int alertId;
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO Alert (device_id, session_id, source, label, risk_score) VALUES (?, ?, ?, ?, ?)",
                        Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, deviceId);
                    ps.setLong(2, sessionId);
                    ps.setString(3, source);
                    ps.setString(4, label);
                    if (risk == null) {
                        ps.setNull(5, Types.FLOAT);
                    } else {
                        ps.setDouble(5, risk);
                    }
                    ps.executeUpdate();
                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        keys.next();
                        alertId = keys.getInt(1);
                    }
                }
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO AlertEvidence (alert_id, item, value_text) VALUES (?, ?, ?)")) {
                    for (String[] pair : evidence) {
                        ps.setInt(1, alertId);
                        ps.setString(2, pair[0]);
                        ps.setString(3, pair[1]);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                }
                conn.commit();
                return alertId;
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    /** Staff marks an alert as handled, audited by the procedure. */
    public void resolve(int alertId, int actorId) throws SQLException {
        // {call Alert_Resolve(?, ?)}
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Alert_Resolve(?, ?)}")) {
            cs.setInt(1, alertId);
            cs.setInt(2, actorId);
            cs.execute();
        }
    }

    /** One page, newest first. status and label are "" for all. */
    public List<Alert> search(String status, String label, int page, int size) throws SQLException {
        throw Todo.of("Alert with optional status and label filters, ORDER BY alert_id DESC, OFFSET/FETCH");
    }

    public int count(String status, String label) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filters");
    }

    /** One alert with its evidence filled in: the page you reach by clicking an alert. */
    public Alert findById(int alertId) throws SQLException {
        throw Todo.of("SELECT the alert, then SELECT item, value_text FROM AlertEvidence WHERE alert_id = ?");
    }

    /** Number of OPEN alerts, the red dot in the menu and a card of the dashboard. */
    public int countOpen() throws SQLException {
        throw Todo.of("SELECT COUNT(*) FROM Alert WHERE status = 'OPEN'");
    }
}
