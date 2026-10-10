package model;

/** One ESP32 locker controller. */
public class Device {

    private int deviceId;
    private String deviceCode;
    private String location;
    private String firmware;
    private String status;   // ACTIVE, MAINTENANCE or OFFLINE
    private java.sql.Timestamp lastSeen;   // UTC
    private Integer lastSeenSec;   // seconds since the last heartbeat

    public int getDeviceId() { return deviceId; }
    public void setDeviceId(int deviceId) { this.deviceId = deviceId; }
    public String getDeviceCode() { return deviceCode; }
    public void setDeviceCode(String deviceCode) { this.deviceCode = deviceCode; }
    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }
    public String getFirmware() { return firmware; }
    public void setFirmware(String firmware) { this.firmware = firmware; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public java.sql.Timestamp getLastSeen() { return lastSeen; }
    public void setLastSeen(java.sql.Timestamp lastSeen) { this.lastSeen = lastSeen; }
    public Integer getLastSeenSec() { return lastSeenSec; }
    public void setLastSeenSec(Integer lastSeenSec) { this.lastSeenSec = lastSeenSec; }
}
