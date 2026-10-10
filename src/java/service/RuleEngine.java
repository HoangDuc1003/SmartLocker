package service;

import util.Todo;
import model.LockerSession;

/**
 * The rules, in priority order; the first one that matches wins. The order matters:
 * a broken sensor or a staff remote open must never be reported as FORCED_OPEN.
 * No database access here: SessionContextDao brings the facts, this class only decides.
 */
public class RuleEngine {

    public static final double ITEM_LEFT_G = 50;      // grams still in the slot after pick-up
    public static final double SPOOF_WEIGHT_G = 50;   // weight moved although the door sensor says it never opened
    public static final long CLOCK_AHEAD_SEC = 300;   // measured_at more than 5 minutes in the future

    public Verdict evaluate(LockerSession s, SessionContext ctx) {
        throw Todo.of("RuleEngine.evaluate: 1 sensor fault, 2 remote open, 3 lost card, 4 the six labels of the assignment");
    }

    /** The reason the data cannot be trusted, or null when it looks sane. */
    private String findSensorFault(LockerSession s, SessionContext ctx) {
        throw Todo.of("RuleEngine.findSensorFault: valid ranges, impossible numbers, device clock, expired calibration");
    }
}
