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
    private String status;   // RESERVED, ACTIVE, COMPLETED, NO_SHOW or CANCELLED
    private java.sql.Timestamp reservedAt;
    private java.sql.Timestamp holdUntil;
    private java.sql.Timestamp startedAt;
    private java.sql.Timestamp dueAt;
    private java.sql.Timestamp endedAt;
    private int extendCount;

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
}
