package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import model.LockerSession;
import service.RuleEngine;
import service.SessionContext;

/**
 * Loads everything the rules need besides the session itself: valid ranges, calibration,
 * clock difference, the remote command and the booking.
 * Call it after the session is stored, because some queries read the stored row by session_id.
 */
public class SessionContextDao {

    public SessionContext load(LockerSession s) throws SQLException {
        // six short queries, one per field of the context
        SessionContext ctx = new SessionContext();
        try (Connection conn = DbContext.getConnection()) {

            // 1. valid ranges of the sensors (DOOR, WEIGHT, STAY)
            try (PreparedStatement ps = conn.prepareStatement("SELECT name, min_valid, max_valid FROM SensorType");
                 ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ctx.setRange(rs.getString(1), rs.getDouble(2), rs.getDouble(3));
                }
            }

            // 2. how late the upload was; negative means the device clock is ahead of the server (done in SQL, no time zones)
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT DATEDIFF(SECOND, measured_at, ingested_at) FROM LockerSession WHERE session_id = ?")) {
                ps.setLong(1, s.getSessionId());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        ctx.setUploadDelaySec(rs.getLong(1));
                    }
                }
            }

            // 3. a WEIGHT calibration that was still valid on the day of the session
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM Calibration c JOIN SensorType t ON t.sensor_type_id = c.sensor_type_id "
                    + "JOIN LockerSession s ON s.device_id = c.device_id "
                    + "WHERE s.session_id = ? AND t.name = N'WEIGHT' AND c.valid_until >= CAST(s.measured_at AS DATE)")) {
                ps.setLong(1, s.getSessionId());
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    ctx.setCalibrationValid(rs.getInt(1) > 0);
                }
            }

            // 4. a remote open is genuine only for a SENT command of this device and slot, used within its window
            //    (RuleEngine.isCommandInWindow: up to 30 minutes after it was issued, with a small clock-lag tolerance)
            if (("REMOTE".equals(s.getOpenSource()) || "PHONE".equals(s.getOpenSource())) && s.getCommandId() != null) {
                try (PreparedStatement ps = conn.prepareStatement(
                        // a day either side is far outside the window; the CASE keeps DATEDIFF from overflowing on a wild clock
                        "SELECT CASE WHEN s.measured_at BETWEEN DATEADD(DAY, -1, c.created_at) AND DATEADD(DAY, 1, c.created_at) "
                        + "THEN DATEDIFF(SECOND, c.created_at, s.measured_at) ELSE 86400 END FROM RemoteCommand c "
                        + "JOIN LockerSession s ON s.session_id = ? "
                        + "WHERE c.command_id = s.command_id AND c.device_id = s.device_id AND c.slot_id = s.slot_id "
                        + "AND c.status = N'SENT'")) {
                    ps.setLong(1, s.getSessionId());
                    try (ResultSet rs = ps.executeQuery()) {
                        ctx.setCommandValid(rs.next() && RuleEngine.isCommandInWindow(rs.getLong(1)));
                    }
                }
            }

            // 6. the booking of the slot: its owner, and how long it may last (plan + extensions + grace)
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT TOP 1 d.user_id, DATEDIFF(MINUTE, d.started_at, d.due_at) + p.grace_min "
                    + "FROM Deposit d JOIN StoragePlan p ON p.plan_id = d.plan_id "
                    + "JOIN LockerSession s ON s.slot_id = d.slot_id "
                    + "WHERE s.session_id = ? AND d.status = N'ACTIVE' ORDER BY d.started_at DESC")) {
                ps.setLong(1, s.getSessionId());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        ctx.setDepositOwnerId(rs.getInt(1));
                        ctx.setAllowedMin(rs.getDouble(2));
                    }
                }
            }
        }
        return ctx;
    }
}
