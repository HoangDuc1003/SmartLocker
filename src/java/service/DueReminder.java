package service;

import dao.DepositDao;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * v3 (D8): one e-mail per booking, DUE_REMINDER_MIN (15) minutes before its due time. Runs on its own thread
 * (LockerMonitor), so a slow SMTP server never delays the dashboard snapshot. A failed message is tried again on
 * the next run, until the due time has passed (Deposit_DueSoon stops listing it then).
 */
public class DueReminder implements Runnable {

    private static final Logger LOG = Logger.getLogger(DueReminder.class.getName());

    private final MailService mail;
    private final MailTemplates templates;
    private boolean warned;

    public DueReminder(MailService mail) {
        this.mail = mail;
        this.templates = MailTemplates.of(mail);
    }

    @Override
    public void run() {
        if (!mail.isEnabled()) {
            if (!warned) {
                LOG.info("Due reminder e-mails are off: no config/mail.local.properties");
                warned = true;
            }
            return;
        }
        List<Map<String, String>> due;
        try {
            due = new DepositDao().dueSoon();
        } catch (SQLException e) {
            LOG.log(Level.WARNING, "Due reminder query failed: " + e.getMessage());
            return;
        }
        for (Map<String, String> row : due) {
            long id = Long.parseLong(row.get("deposit_id"));
            try {
                MailTemplates.Message msg = templates.render("due_soon", values(row));
                mail.send(row.get("email"), msg.subject, msg.body);
                new DepositDao().markReminded(id, "e-mail sent");
            } catch (Exception e) {
                // the address is not logged; the booking id is enough to find it
                LOG.log(Level.WARNING, "Due reminder for deposit " + id + " failed: " + e.getMessage());
                String m = String.valueOf(e.getMessage());
                if (m.startsWith("bad recipient")) {
                    try {   // refused for good: do not log in again every 30 seconds until the due time
                        new DepositDao().markReminded(id, "e-mail refused: " + m);
                    } catch (SQLException ignored) {
                        // tried again on the next run
                    }
                }
            }
        }
    }

    /** The values of config/mail-templates/due_soon.txt; times in Vietnam time. */
    Map<String, String> values(Map<String, String> row) {
        long rate = row.get("overdue_rate") == null ? 0 : Long.parseLong(row.get("overdue_rate"));
        Map<String, String> v = new java.util.LinkedHashMap<>();
        v.put("name", row.get("full_name"));
        v.put("slot_code", row.get("slot_code"));
        v.put("bank_code", row.get("bank_code"));
        v.put("area_name", row.get("area_name"));
        v.put("due_at", MailTemplates.time(row.get("due_at")));
        v.put("overdue_rate", MailTemplates.money(rate));
        v.put("my_locker_url", MailTemplates.link(mail, "/MyLockerController"));
        return v;
    }
}
