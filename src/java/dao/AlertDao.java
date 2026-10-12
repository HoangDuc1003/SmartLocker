package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import model.Alert;

/** Alerts and their evidence. Every alert carries the reason it was raised. */
public class AlertDao {

    private static Alert map(ResultSet rs) throws SQLException {
        Alert a = new Alert();
        a.setAlertId(rs.getInt("alert_id"));
        a.setDeviceId(rs.getInt("device_id"));
        long sess = rs.getLong("session_id");
        a.setSessionId(rs.wasNull() ? null : sess);
        a.setSource(rs.getString("source"));
        a.setLabel(rs.getString("label"));
        double risk = rs.getDouble("risk_score");
        a.setRiskScore(rs.wasNull() ? null : risk);
        a.setStatus(rs.getString("status"));
        a.setCreatedAt(rs.getTimestamp("created_at"));
        return a;
    }

    /** Stores an alert and its evidence in one transaction. Returns the alert id. risk is null for rules that have no score. */
    public int create(int deviceId, long sessionId, String source, String label, Double risk, List<String[]> evidence)
            throws SQLException {
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
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Alert_Resolve(?, ?)}")) {
            cs.setInt(1, alertId);
            cs.setInt(2, actorId);
            cs.execute();
        }
    }

    /** One page, newest first. status and label are "" for all. */
    public List<Alert> search(String status, String label, int page, int size) throws SQLException {
        StringBuilder sb = new StringBuilder("SELECT alert_id, device_id, session_id, source, label, risk_score, status, created_at FROM Alert WHERE 1=1");
        List<Object> params = new ArrayList<>();
        if (status != null && !status.trim().isEmpty()) {
            sb.append(" AND status = ?");
            params.add(status.trim());
        }
        if (label != null && !label.trim().isEmpty()) {
            sb.append(" AND label = ?");
            params.add(label.trim());
        }
        sb.append(" ORDER BY alert_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY");
        params.add((page - 1) * size);
        params.add(size);
        List<Alert> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sb.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    public int count(String status, String label) throws SQLException {
        StringBuilder sb = new StringBuilder("SELECT COUNT(*) FROM Alert WHERE 1=1");
        List<Object> params = new ArrayList<>();
        if (status != null && !status.trim().isEmpty()) {
            sb.append(" AND status = ?");
            params.add(status.trim());
        }
        if (label != null && !label.trim().isEmpty()) {
            sb.append(" AND label = ?");
            params.add(label.trim());
        }
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sb.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /** One alert with its evidence filled in: the page you reach by clicking an alert. */
    public Alert findById(int alertId) throws SQLException {
        String sqlAlert = "SELECT alert_id, device_id, session_id, source, label, risk_score, status, created_at FROM Alert WHERE alert_id = ?";
        String sqlEvidence = "SELECT item, value_text FROM AlertEvidence WHERE alert_id = ? ORDER BY evidence_id";
        try (Connection conn = DbContext.getConnection()) {
            Alert a = null;
            try (PreparedStatement ps = conn.prepareStatement(sqlAlert)) {
                ps.setInt(1, alertId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        a = map(rs);
                    }
                }
            }
            if (a == null) return null;
            List<String[]> ev = new ArrayList<>();
            try (PreparedStatement ps = conn.prepareStatement(sqlEvidence)) {
                ps.setInt(1, alertId);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        ev.add(new String[]{rs.getString("item"), rs.getString("value_text")});
                    }
                }
            }
            a.setEvidence(ev);
            return a;
        }
    }

    /** Number of OPEN alerts, the red dot in the menu and a card of the dashboard. */
    public int countOpen() throws SQLException {
        try (Connection conn = DbContext.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM Alert WHERE status = 'OPEN'");
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }
}
