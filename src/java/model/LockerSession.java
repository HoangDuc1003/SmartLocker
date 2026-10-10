package model;

/** One deposit as reported by the device, from card swipe to pick-up. */
public class LockerSession {

    private long sessionId;
    private int deviceId;
    private int deviceSeq;
    private java.sql.Timestamp measuredAt;   // UTC, taken on the device
    private double doorOpenSec;
    private double weightDeltaG;
    private int unlockCount;
    private boolean rfidOk;
    private double stayMin;
    private String slotCode;   // optional, A01
    private String cardUid;   // optional
    private String openSource;   // RFID or REMOTE
    private Long commandId;   // only for REMOTE

    public long getSessionId() { return sessionId; }
    public void setSessionId(long sessionId) { this.sessionId = sessionId; }
    public int getDeviceId() { return deviceId; }
    public void setDeviceId(int deviceId) { this.deviceId = deviceId; }
    public int getDeviceSeq() { return deviceSeq; }
    public void setDeviceSeq(int deviceSeq) { this.deviceSeq = deviceSeq; }
    public java.sql.Timestamp getMeasuredAt() { return measuredAt; }
    public void setMeasuredAt(java.sql.Timestamp measuredAt) { this.measuredAt = measuredAt; }
    public double getDoorOpenSec() { return doorOpenSec; }
    public void setDoorOpenSec(double doorOpenSec) { this.doorOpenSec = doorOpenSec; }
    public double getWeightDeltaG() { return weightDeltaG; }
    public void setWeightDeltaG(double weightDeltaG) { this.weightDeltaG = weightDeltaG; }
    public int getUnlockCount() { return unlockCount; }
    public void setUnlockCount(int unlockCount) { this.unlockCount = unlockCount; }
    public boolean isRfidOk() { return rfidOk; }
    public void setRfidOk(boolean rfidOk) { this.rfidOk = rfidOk; }
    public double getStayMin() { return stayMin; }
    public void setStayMin(double stayMin) { this.stayMin = stayMin; }
    public String getSlotCode() { return slotCode; }
    public void setSlotCode(String slotCode) { this.slotCode = slotCode; }
    public String getCardUid() { return cardUid; }
    public void setCardUid(String cardUid) { this.cardUid = cardUid; }
    public String getOpenSource() { return openSource; }
    public void setOpenSource(String openSource) { this.openSource = openSource; }
    public Long getCommandId() { return commandId; }
    public void setCommandId(Long commandId) { this.commandId = commandId; }
}
