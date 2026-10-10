package service;

import util.Todo;
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
        throw Todo.of("AlertService.evaluate: context -> rules -> model -> alert -> follow-up (command done, ticket opened)");
    }
}
