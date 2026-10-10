package model;

/** How long a deposit may last. */
public class StoragePlan {

    private int planId;
    private String planName;
    private int durationMin;
    private int graceMin;
    private int price;
    private boolean active;

    public int getPlanId() { return planId; }
    public void setPlanId(int planId) { this.planId = planId; }
    public String getPlanName() { return planName; }
    public void setPlanName(String planName) { this.planName = planName; }
    public int getDurationMin() { return durationMin; }
    public void setDurationMin(int durationMin) { this.durationMin = durationMin; }
    public int getGraceMin() { return graceMin; }
    public void setGraceMin(int graceMin) { this.graceMin = graceMin; }
    public int getPrice() { return price; }
    public void setPrice(int price) { this.price = price; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
}
