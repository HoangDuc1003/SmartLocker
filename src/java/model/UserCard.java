package model;

/** An RFID card owned by a user. */
public class UserCard {

    private int cardId;
    private String cardUid;   // hex uid read by the RC522
    private int userId;
    private String username;   // joined
    private String status;   // ACTIVE, LOST or BLOCKED
    private java.sql.Timestamp issuedAt;
    private java.sql.Timestamp lostAt;

    public int getCardId() { return cardId; }
    public void setCardId(int cardId) { this.cardId = cardId; }
    public String getCardUid() { return cardUid; }
    public void setCardUid(String cardUid) { this.cardUid = cardUid; }
    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public java.sql.Timestamp getIssuedAt() { return issuedAt; }
    public void setIssuedAt(java.sql.Timestamp issuedAt) { this.issuedAt = issuedAt; }
    public java.sql.Timestamp getLostAt() { return lostAt; }
    public void setLostAt(java.sql.Timestamp lostAt) { this.lostAt = lostAt; }
}
