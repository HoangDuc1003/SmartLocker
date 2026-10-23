package test;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import org.testng.Assert;
import org.testng.annotations.Test;
import service.MailTemplates;

/** The e-mail templates in config/mail-templates: every file renders, nothing is left unfilled, "?" lines work. */
public class MailTemplatesTest {

    private static final String[] KEYS = {"due_soon", "overdue", "overdue_escalated", "booking_confirmed",
        "reservation_expired", "verification_code", "welcome", "topup_approved", "topup_rejected"};

    private static Map<String, String> all() {
        Map<String, String> v = new HashMap<>();
        for (String k : new String[]{"name", "username", "slot_code", "bank_code", "area_name", "plan_name", "open_method",
            "amount", "balance", "due_at", "hold_until", "hold_min", "refund_pct", "refund_amount", "overdue_rate",
            "overdue_hours", "overdue_fee", "escalate_hours", "code", "expires_min", "reason", "my_locker_url", "map_url",
            "topup_url"}) {
            v.put(k, k.toUpperCase());
        }
        return v;
    }

    private static MailTemplates templates() {
        return new MailTemplates(new File("config/mail-templates"));
    }

    @Test
    public void everyTemplateRendersWithoutLeftovers() throws Exception {
        for (String key : KEYS) {
            MailTemplates.Message m = templates().render(key, all());
            Assert.assertFalse(m.subject.isEmpty(), key + " subject");
            Assert.assertFalse(m.subject.contains("{{") || m.body.contains("{{"), key + " has an unfilled placeholder");
            Assert.assertTrue(m.body.endsWith("\n"), key);
        }
    }

    @Test
    public void optionalLineIsDroppedWhenItsValueIsEmpty() throws Exception {
        Map<String, String> v = all();
        v.put("my_locker_url", "");
        MailTemplates.Message m = templates().render("due_soon", v);
        Assert.assertFalse(m.body.contains("Tủ của tôi:"), "the link line must go");
        v.put("my_locker_url", "https://x/y");
        Assert.assertTrue(templates().render("due_soon", v).body.contains("Tủ của tôi: https://x/y"));
    }

    @Test
    public void emptyNameBecomesBan() throws Exception {
        Map<String, String> v = all();
        v.put("name", "  ");
        Assert.assertTrue(templates().render("welcome", v).body.startsWith("Chào bạn,"));
    }

    @Test
    public void valuesCannotInjectNewLinesOrHeaders() throws Exception {
        Map<String, String> v = all();
        v.put("name", "An\r\nBcc: x@y.z");
        MailTemplates.Message m = templates().render("welcome", v);
        Assert.assertFalse(m.subject.contains("\n"));
        Assert.assertTrue(m.body.contains("Chào An Bcc: x@y.z,"));
    }

    @Test(expectedExceptions = java.io.IOException.class)
    public void badTemplateNameIsRefused() throws Exception {
        templates().render("../mail.local", all());
    }
}
