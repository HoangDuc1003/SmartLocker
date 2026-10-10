package service;

import java.util.ArrayList;
import java.util.List;

/** What the rules decided about one session: a label, whether to raise an alert, and the evidence. */
public class Verdict {

    private final String label;          // an alert label, or NORMAL / STAFF_OPEN when no alert is raised
    private final boolean alert;
    private boolean mlEligible = true;   // false: the session must not be given to the model
    private final List<String[]> evidence = new ArrayList<String[]>();

    private Verdict(String label, boolean alert) {
        this.label = label;
        this.alert = alert;
    }

    /** An alert with its first piece of evidence. Add more with with(). */
    public static Verdict alert(String label, String item, String value) {
        // new Verdict(label, true).with(item, value)
        return new Verdict(label, true).with(item, value);
    }

    public static Verdict normal() {
        return new Verdict("NORMAL", false);
    }

    /** A legitimate remote open by staff: no alert, and the model never sees this session. */
    public static Verdict staffOpen(long commandId) {
        return new Verdict("STAFF_OPEN", false).with("command_id", String.valueOf(commandId)).noMl();
    }

    public Verdict with(String item, String value) {
        // add one {item, value} pair and return this, so calls can be chained
        evidence.add(new String[]{item, value});
        return this;
    }

    public Verdict noMl() {
        mlEligible = false;
        return this;
    }

    public String getLabel() { return label; }
    public boolean isAlert() { return alert; }
    public boolean isMlEligible() { return mlEligible; }
    public List<String[]> getEvidence() { return evidence; }
}
