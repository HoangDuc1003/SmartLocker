package model;

/** One cabinet of doors. */
public class LockerBank {

    private int bankId;
    private String bankCode;   // LIB-A
    private String name;   // display name, e.g. Dãy A
    private int areaId;
    private String areaCode;   // joined
    private Integer deviceId;   // null = illustration only
    private int doorRows;
    private String status;
    private int slotCount;   // computed

    public int getBankId() { return bankId; }
    public void setBankId(int bankId) { this.bankId = bankId; }
    public String getBankCode() { return bankCode; }
    public void setBankCode(String bankCode) { this.bankCode = bankCode; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public int getAreaId() { return areaId; }
    public void setAreaId(int areaId) { this.areaId = areaId; }
    public String getAreaCode() { return areaCode; }
    public void setAreaCode(String areaCode) { this.areaCode = areaCode; }
    public Integer getDeviceId() { return deviceId; }
    public void setDeviceId(Integer deviceId) { this.deviceId = deviceId; }
    public int getDoorRows() { return doorRows; }
    public void setDoorRows(int doorRows) { this.doorRows = doorRows; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public int getSlotCount() { return slotCount; }
    public void setSlotCount(int slotCount) { this.slotCount = slotCount; }

    // the box of the bank (sql/demo_box.sql): its code, demo or real, and the one slot with the servo
    private String deviceCode;
    private boolean demoDevice;
    private String physicalSlot;   // slot code, null = none configured (every slot of the box is real)
    private String physicalBank;   // bank of that slot, may be another bank of the same box

    public String getDeviceCode() { return deviceCode; }
    public void setDeviceCode(String deviceCode) { this.deviceCode = deviceCode; }
    public boolean isDemoDevice() { return demoDevice; }
    public void setDemoDevice(boolean demoDevice) { this.demoDevice = demoDevice; }
    public String getPhysicalSlot() { return physicalSlot; }
    public void setPhysicalSlot(String physicalSlot) { this.physicalSlot = physicalSlot; }
    public String getPhysicalBank() { return physicalBank; }
    public void setPhysicalBank(String physicalBank) { this.physicalBank = physicalBank; }
}
