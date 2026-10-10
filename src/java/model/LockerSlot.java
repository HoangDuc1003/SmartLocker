package model;

/** One door of a bank. */
public class LockerSlot {

    private int slotId;
    private String slotCode;   // A01
    private int bankId;
    private String bankCode;   // joined
    private String sizeCm;   // 30x30x45
    private String sizeCode;   // S, M or L
    private String status;   // AVAILABLE, RESERVED, OCCUPIED or MAINTENANCE

    public int getSlotId() { return slotId; }
    public void setSlotId(int slotId) { this.slotId = slotId; }
    public String getSlotCode() { return slotCode; }
    public void setSlotCode(String slotCode) { this.slotCode = slotCode; }
    public int getBankId() { return bankId; }
    public void setBankId(int bankId) { this.bankId = bankId; }
    public String getBankCode() { return bankCode; }
    public void setBankCode(String bankCode) { this.bankCode = bankCode; }
    public String getSizeCm() { return sizeCm; }
    public void setSizeCm(String sizeCm) { this.sizeCm = sizeCm; }
    public String getSizeCode() { return sizeCode; }
    public void setSizeCode(String sizeCode) { this.sizeCode = sizeCode; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}
