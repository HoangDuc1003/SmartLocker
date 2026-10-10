package model;

/** A row of Users joined with its role. The password hash is never kept here. */
public class User {

    private int userId;
    private String username;
    private String fullName;
    private String status;   // ACTIVE, LOCKED or DISABLED
    private String roleName;   // highest role of the user
    private int roleRank;   // 1 = highest
    private String email;
    private String phone;
    private Integer areaId;   // null = no area
    private String areaCode;   // joined from LockerArea

    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getRoleName() { return roleName; }
    public void setRoleName(String roleName) { this.roleName = roleName; }
    public int getRoleRank() { return roleRank; }
    public void setRoleRank(int roleRank) { this.roleRank = roleRank; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public Integer getAreaId() { return areaId; }
    public void setAreaId(Integer areaId) { this.areaId = areaId; }
    public String getAreaCode() { return areaCode; }
    public void setAreaCode(String areaCode) { this.areaCode = areaCode; }

    public boolean isLocked() { return "LOCKED".equals(status); }
}
