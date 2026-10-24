package model;

/** One booking of a slot, from reservation to pick-up. */
public class Deposit {

    private long depositId;
    private int userId;
    private String username;   // joined
    private int slotId;
    private String slotCode;   // joined
    private String bankCode;   // joined
    private int planId;
    private String planName;   // joined
    private Integer cardId;
    private long paidAmount;
    private String status;   // RESERVED, ACTIVE, COMPLETED, NO_SHOW or CANCELLED
    private java.sql.Timestamp reservedAt;
    private java.sql.Timestamp holdUntil;
    private java.sql.Timestamp startedAt;
    private java.sql.Timestamp dueAt;
    private java.sql.Timestamp endedAt;
    private int extendCount;
    private String openMethod;   // PIN, CARD or FINGERPRINT
    private String pinCode;      // 6 digits, only for PIN; shown to the owner only
    private String enrollCode;   // 6 digits while a card or finger still has to be enrolled at the box
    private java.sql.Timestamp enrollExpires;
    private String deviceCode;   // joined: the box of the slot
    // v3 (sql/03_v2_v3.sql)
    private String sizeCode;     // joined: S, M or L
    private String sizeCm;       // joined: 20x20x20 ...
    private int graceMin;        // joined from the plan: the slot locks after due_at + grace
    private Long overdueRate;    // late fee of one hour, fixed at booking time
    private int overdueHours;    // late hours already charged
    private long overdueFee;     // late fee already charged
    private java.sql.Timestamp lockedAt;     // past due_at + grace: opening needs a balance of 0 or more
    private java.sql.Timestamp escalatedAt;  // 48 hours late: handed to the staff

    public long getDepositId() { return depositId; }
    public void setDepositId(long depositId) { this.depositId = depositId; }
    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public int getSlotId() { return slotId; }
    public void setSlotId(int slotId) { this.slotId = slotId; }
    public String getSlotCode() { return slotCode; }
    public void setSlotCode(String slotCode) { this.slotCode = slotCode; }
    public String getBankCode() { return bankCode; }
    public void setBankCode(String bankCode) { this.bankCode = bankCode; }
    public int getPlanId() { return planId; }
    public void setPlanId(int planId) { this.planId = planId; }
    public String getPlanName() { return planName; }
    public void setPlanName(String planName) { this.planName = planName; }
    public Integer getCardId() { return cardId; }
    public void setCardId(Integer cardId) { this.cardId = cardId; }
    public long getPaidAmount() { return paidAmount; }
    public void setPaidAmount(long paidAmount) { this.paidAmount = paidAmount; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public java.sql.Timestamp getReservedAt() { return reservedAt; }
    public void setReservedAt(java.sql.Timestamp reservedAt) { this.reservedAt = reservedAt; }
    public java.sql.Timestamp getHoldUntil() { return holdUntil; }
    public void setHoldUntil(java.sql.Timestamp holdUntil) { this.holdUntil = holdUntil; }
    public java.sql.Timestamp getStartedAt() { return startedAt; }
    public void setStartedAt(java.sql.Timestamp startedAt) { this.startedAt = startedAt; }
    public java.sql.Timestamp getDueAt() { return dueAt; }
    public void setDueAt(java.sql.Timestamp dueAt) { this.dueAt = dueAt; }
    public java.sql.Timestamp getEndedAt() { return endedAt; }
    public void setEndedAt(java.sql.Timestamp endedAt) { this.endedAt = endedAt; }
    public int getExtendCount() { return extendCount; }
    public void setExtendCount(int extendCount) { this.extendCount = extendCount; }
    public String getOpenMethod() { return openMethod; }
    public void setOpenMethod(String openMethod) { this.openMethod = openMethod; }
    public String getPinCode() { return pinCode; }
    public void setPinCode(String pinCode) { this.pinCode = pinCode; }
    public String getEnrollCode() { return enrollCode; }
    public void setEnrollCode(String enrollCode) { this.enrollCode = enrollCode; }
    public java.sql.Timestamp getEnrollExpires() { return enrollExpires; }
    public void setEnrollExpires(java.sql.Timestamp enrollExpires) { this.enrollExpires = enrollExpires; }
    public String getDeviceCode() { return deviceCode; }
    public void setDeviceCode(String deviceCode) { this.deviceCode = deviceCode; }
    public String getSizeCode() { return sizeCode; }
    public void setSizeCode(String sizeCode) { this.sizeCode = sizeCode; }
    public String getSizeCm() { return sizeCm; }
    public void setSizeCm(String sizeCm) { this.sizeCm = sizeCm; }
    public int getGraceMin() { return graceMin; }
    public void setGraceMin(int graceMin) { this.graceMin = graceMin; }
    public Long getOverdueRate() { return overdueRate; }
    public void setOverdueRate(Long overdueRate) { this.overdueRate = overdueRate; }
    public int getOverdueHours() { return overdueHours; }
    public void setOverdueHours(int overdueHours) { this.overdueHours = overdueHours; }
    public long getOverdueFee() { return overdueFee; }
    public void setOverdueFee(long overdueFee) { this.overdueFee = overdueFee; }
    public java.sql.Timestamp getLockedAt() { return lockedAt; }
    public void setLockedAt(java.sql.Timestamp lockedAt) { this.lockedAt = lockedAt; }
    public java.sql.Timestamp getEscalatedAt() { return escalatedAt; }
    public void setEscalatedAt(java.sql.Timestamp escalatedAt) { this.escalatedAt = escalatedAt; }
    public boolean isLocked() { return lockedAt != null; }
}
