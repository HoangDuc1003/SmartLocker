package service;

import java.util.HashMap;
import java.util.Map;

/**
 * Everything the rules need besides the session itself, loaded by SessionContextDao.
 * A plain object with no database access, so RuleEngine can be tested with a few lines.
 */
public class SessionContext {

    private final Map<String, double[]> ranges = new HashMap<String, double[]>();
    private boolean calibrationValid = true;
    private long uploadDelaySec;          // ingested_at minus measured_at, negative = the device clock is ahead
    private boolean commandValid;         // a REMOTE open matches a SENT command for this slot
    private String cardStatus;            // ACTIVE, LOST, BLOCKED, or null when the card is unknown
    private Integer cardOwnerId;
    private Integer depositOwnerId;
    private double allowedMin;            // plan + extensions + grace of the active booking, 0 = no booking

    public void setRange(String sensor, double min, double max) {
        ranges.put(sensor, new double[]{min, max});
    }

    /** true when the value is inside the valid range of the sensor, or when no range is known. */
    public boolean inRange(String sensor, double value) {
        double[] r = ranges.get(sensor);
        return r == null || (value >= r[0] && value <= r[1]);
    }

    public boolean isCalibrationValid() { return calibrationValid; }
    public void setCalibrationValid(boolean calibrationValid) { this.calibrationValid = calibrationValid; }
    public long getUploadDelaySec() { return uploadDelaySec; }
    public void setUploadDelaySec(long uploadDelaySec) { this.uploadDelaySec = uploadDelaySec; }
    public boolean isCommandValid() { return commandValid; }
    public void setCommandValid(boolean commandValid) { this.commandValid = commandValid; }
    public String getCardStatus() { return cardStatus; }
    public void setCardStatus(String cardStatus) { this.cardStatus = cardStatus; }
    public Integer getCardOwnerId() { return cardOwnerId; }
    public void setCardOwnerId(Integer cardOwnerId) { this.cardOwnerId = cardOwnerId; }
    public Integer getDepositOwnerId() { return depositOwnerId; }
    public void setDepositOwnerId(Integer depositOwnerId) { this.depositOwnerId = depositOwnerId; }
    public double getAllowedMin() { return allowedMin; }
    public void setAllowedMin(double allowedMin) { this.allowedMin = allowedMin; }
}
