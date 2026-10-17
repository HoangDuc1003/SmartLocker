package service;

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
        // 1 sensor fault, 2 remote open, 3 lost card, 4 the six behaviour labels
        // 1. SENSOR_FAULT: data we cannot trust, blame the sensor and not the user
        String fault = findSensorFault(s, ctx);
        if (fault != null) {
            return Verdict.alert("SENSOR_FAULT", "reason", fault).noMl();
        }
        // 2. Remote or phone open: a valid command means staff (or the phone page) opened it, otherwise someone faked the signal
        if ("REMOTE".equals(s.getOpenSource()) || "PHONE".equals(s.getOpenSource())) {
            if (s.getCommandId() != null && ctx.isCommandValid()) {
                return Verdict.staffOpen(s.getCommandId());
            }
            return Verdict.alert("SUSPECTED_SPOOF", "reason", "remote open without a valid command")
                    .with("command_id", String.valueOf(s.getCommandId()));
        }
        // 3. A card reported lost or blocked was used
        if (ctx.getCardStatus() != null && !"ACTIVE".equals(ctx.getCardStatus())) {
            return Verdict.alert("LOST_CARD_USED", "card_uid", s.getCardUid())
                    .with("card_status", ctx.getCardStatus())
                    .with("card_owner_id", String.valueOf(ctx.getCardOwnerId()));
        }
        // 4. The six behaviour labels
        if (!s.isRfidOk() && s.getDoorOpenSec() > 0) {
            return Verdict.alert("FORCED_OPEN", "door_open_sec", String.valueOf(s.getDoorOpenSec()))
                    .with("rfid_ok", "false");
        }
        if (s.isRfidOk() && ctx.getCardOwnerId() != null && ctx.getDepositOwnerId() != null
                && !ctx.getCardOwnerId().equals(ctx.getDepositOwnerId())) {
            return Verdict.alert("WRONG_USER", "card_owner_id", String.valueOf(ctx.getCardOwnerId()))
                    .with("deposit_owner_id", String.valueOf(ctx.getDepositOwnerId()));
        }
        if (s.getDoorOpenSec() == 0 && Math.abs(s.getWeightDeltaG()) > SPOOF_WEIGHT_G) {
            return Verdict.alert("SUSPECTED_SPOOF", "reason", "weight changed while the door sensor reported closed")
                    .with("weight_delta_g", String.valueOf(s.getWeightDeltaG()));
        }
        if (s.getWeightDeltaG() > ITEM_LEFT_G) {
            return Verdict.alert("ITEM_LEFT", "weight_delta_g", String.valueOf(s.getWeightDeltaG()));
        }
        if (ctx.getAllowedMin() > 0 && s.getStayMin() > ctx.getAllowedMin()) {
            return Verdict.alert("OVERDUE", "stay_min", String.valueOf(s.getStayMin()))
                    .with("allowed_min", String.valueOf(ctx.getAllowedMin()));
        }
        return Verdict.normal();   // AlertService may still raise ML_ANOMALY from the risk score
    }

    /** The reason the data cannot be trusted, or null when it looks sane. */
    private String findSensorFault(LockerSession s, SessionContext ctx) {
        // valid ranges, impossible numbers, device clock, expired calibration
        if (!ctx.inRange("DOOR", s.getDoorOpenSec())) {
            return "door_open_sec=" + s.getDoorOpenSec() + " is outside the valid range";
        }
        if (!ctx.inRange("WEIGHT", s.getWeightDeltaG())) {
            return "weight_delta_g=" + s.getWeightDeltaG() + " is outside the valid range";
        }
        if (!ctx.inRange("STAY", s.getStayMin())) {
            return "stay_min=" + s.getStayMin() + " is outside the valid range";
        }
        if (s.getDoorOpenSec() > s.getStayMin() * 60 + 5) {
            return "door was open longer than the whole session";
        }
        if (ctx.getUploadDelaySec() < -CLOCK_AHEAD_SEC) {
            return "device clock is " + (-ctx.getUploadDelaySec()) + " s ahead of the server, check NTP";
        }
        if (!ctx.isCalibrationValid()) {
            return "weight sensor calibration has expired";
        }
        return null;
    }
}
