package model;

/** Offset and scale of one sensor on one device. */
public class Calibration {

    private int calibId;
    private int deviceId;
    private String deviceCode;   // joined
    private int sensorTypeId;
    private String sensorName;   // joined
    private double offsetVal;
    private double scaleVal;
    private int version;
    private java.sql.Date validUntil;
    private int createdBy;

    public int getCalibId() { return calibId; }
    public void setCalibId(int calibId) { this.calibId = calibId; }
    public int getDeviceId() { return deviceId; }
    public void setDeviceId(int deviceId) { this.deviceId = deviceId; }
    public String getDeviceCode() { return deviceCode; }
    public void setDeviceCode(String deviceCode) { this.deviceCode = deviceCode; }
    public int getSensorTypeId() { return sensorTypeId; }
    public void setSensorTypeId(int sensorTypeId) { this.sensorTypeId = sensorTypeId; }
    public String getSensorName() { return sensorName; }
    public void setSensorName(String sensorName) { this.sensorName = sensorName; }
    public double getOffsetVal() { return offsetVal; }
    public void setOffsetVal(double offsetVal) { this.offsetVal = offsetVal; }
    public double getScaleVal() { return scaleVal; }
    public void setScaleVal(double scaleVal) { this.scaleVal = scaleVal; }
    public int getVersion() { return version; }
    public void setVersion(int version) { this.version = version; }
    public java.sql.Date getValidUntil() { return validUntil; }
    public void setValidUntil(java.sql.Date validUntil) { this.validUntil = validUntil; }
    public int getCreatedBy() { return createdBy; }
    public void setCreatedBy(int createdBy) { this.createdBy = createdBy; }
}
