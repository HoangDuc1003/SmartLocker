package service;

import dao.AlertDao;
import dao.AuditDao;
import dao.MaintenanceDao;
import dao.RemoteCommandDao;
import dao.SessionContextDao;
import java.sql.SQLException;
import java.util.Locale;
import model.LockerSession;

/**
 * Two tiers: the rules first, the model second.
 * A rule that matches wins, and the model score is kept as supporting evidence.
 * When no rule matches, a high enough risk score raises ML_ANOMALY.
 */
public class AlertService {

    public static final double ML_THRESHOLD = 0.80;

    private final RuleEngine ruleEngine = new RuleEngine();

    /** The session must already be stored: session.getSessionId() is used by the queries and by the alert. */
    public void evaluate(LockerSession session) throws SQLException {
        // context -> rules -> model -> alert -> follow-up (command done, ticket opened)
        SessionContext ctx = new SessionContextDao().load(session);
        Verdict verdict = ruleEngine.evaluate(session, ctx);

        Double risk = null;
        if (verdict.isMlEligible()) {                        // a staff open or a broken sensor is not user behaviour
            risk = RiskScorer.getInstance().score(session);  // 1 - P(NORMAL)
            if (!verdict.isAlert() && risk >= ML_THRESHOLD) {
                verdict = Verdict.alert("ML_ANOMALY", "risk_score", String.format(Locale.ROOT, "%.2f", risk));
            }
        }

        if ("STAFF_OPEN".equals(verdict.getLabel())) {       // case 2: the command is used up
            new RemoteCommandDao().markDone(session.getCommandId(), session.getSessionId());
            new AuditDao().append(AuditDao.SYSTEM_USER_ID, "COMMAND_DONE", "COMMAND", session.getCommandId(),
                    "session " + session.getSessionId());
        }

        if (verdict.isAlert()) {
            String source = "ML_ANOMALY".equals(verdict.getLabel()) ? "ML" : "RULE";
            int alertId = new AlertDao().create(session.getDeviceId(), session.getSessionId(), source,
                    verdict.getLabel(), risk, verdict.getEvidence());
            new AuditDao().append(AuditDao.SYSTEM_USER_ID, "CREATE", "ALERT", alertId, verdict.getLabel());
            if ("SENSOR_FAULT".equals(verdict.getLabel())) {  // case 5: a ticket and the slot out of service
                new MaintenanceDao().openForFault(session.getDeviceId(), alertId, session.getSessionId(),
                        verdict.getEvidence().get(0)[1]);
            }
        }
    }
}
