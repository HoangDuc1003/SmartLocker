package model;

/** An alert raised by a rule or by the model, with its evidence. */
public class Alert {

    private int alertId;
    private int deviceId;
    private Long sessionId;   // null for DEVICE_OFFLINE
    private String source;   // RULE or ML
    private String label;
    private Double riskScore;   // null for rules
    private String status;   // OPEN or RESOLVED
    private java.sql.Timestamp createdAt;
    private java.util.List<String[]> evidence;   // pairs of {item, value}

    public int getAlertId() { return alertId; }
    public void setAlertId(int alertId) { this.alertId = alertId; }
    public int getDeviceId() { return deviceId; }
    public void setDeviceId(int deviceId) { this.deviceId = deviceId; }
    public Long getSessionId() { return sessionId; }
    public void setSessionId(Long sessionId) { this.sessionId = sessionId; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }
    public Double getRiskScore() { return riskScore; }
    public void setRiskScore(Double riskScore) { this.riskScore = riskScore; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public java.sql.Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(java.sql.Timestamp createdAt) { this.createdAt = createdAt; }
    public java.util.List<String[]> getEvidence() { return evidence; }
    public void setEvidence(java.util.List<String[]> evidence) { this.evidence = evidence; }
}
