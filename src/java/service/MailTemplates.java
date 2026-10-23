package service;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TimeZone;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The text of every e-mail lives in config/mail-templates/KEY.txt (next to mail.local.properties), so it can be
 * reworded without a rebuild. A file is "Subject: ..." , an empty line, then the body with {{name}} style
 * placeholders. A body line that starts with "?" is optional: it is dropped when a placeholder in it is empty.
 * _footer.txt is appended to every message. Values are single-line and at most 300 characters.
 *
 * Preview or send a sample: sh scripts/mail-preview.sh KEY [address]   (see config/mail-templates/README.md).
 */
public final class MailTemplates {

    /** A finished message, ready for MailService.send. */
    public static final class Message {
        public final String subject;
        public final String body;

        Message(String subject, String body) {
            this.subject = subject;
            this.body = body;
        }
    }

    private static final Pattern KEY = Pattern.compile("[a-z_]{1,40}");
    private static final Pattern PLACEHOLDER = Pattern.compile("\\{\\{\\s*([a-z_]+)\\s*\\}\\}");
    private static final int MAX_VALUE = 300;

    private final File dir;

    public MailTemplates(File dir) {
        this.dir = dir;
    }

    /** The templates next to the mail settings; the folder of the project when mail is not configured. */
    public static MailTemplates of(MailService mail) {
        String source = mail.source();
        File base = source == null ? new File("config") : new File(source).getAbsoluteFile().getParentFile();
        return new MailTemplates(new File(base, "mail-templates"));
    }

    /** Fills the template KEY with the values; a placeholder without a value becomes empty. */
    public Message render(String key, Map<String, String> values) throws IOException {
        if (!KEY.matcher(key).matches()) {
            throw new IOException("bad template name");
        }
        Map<String, String> vars = clean(values);
        if (vars.get("name").isEmpty()) {
            vars.put("name", "bạn");   // a user without a name still gets "Chào bạn,"
        }
        String text = read(new File(dir, key + ".txt"));
        String footer = new File(dir, "_footer.txt").isFile() ? read(new File(dir, "_footer.txt")) : "";
        int cut = text.indexOf('\n');
        String first = cut < 0 ? text : text.substring(0, cut);
        if (!first.startsWith("Subject:")) {
            throw new IOException("template " + key + " must start with a Subject: line");
        }
        String subject = fill(first.substring("Subject:".length()).trim(), vars).replaceAll("\\s+", " ").trim();
        String body = cut < 0 ? "" : text.substring(cut + 1).replaceFirst("^\\n+", "");
        body = fill(body, vars).replaceAll("\\n{3,}", "\n\n").trim() + "\n";
        if (!footer.isEmpty()) {
            body += "\n" + footer.trim() + "\n";
        }
        return new Message(subject, body);
    }

    /** Package-visible for the unit test: placeholders and "?" lines, nothing else. */
    static String fill(String text, Map<String, String> vars) {
        StringBuilder out = new StringBuilder();
        for (String line : text.split("\n", -1)) {
            boolean optional = line.startsWith("?");
            String row = optional ? line.substring(1) : line;
            boolean missing = false;
            Matcher m = PLACEHOLDER.matcher(row);
            StringBuffer sb = new StringBuffer();
            while (m.find()) {
                String value = vars.get(m.group(1));
                if (value == null || value.isEmpty()) {
                    missing = true;
                    value = "";
                }
                m.appendReplacement(sb, Matcher.quoteReplacement(value));
            }
            m.appendTail(sb);
            if (optional && missing) {
                continue;
            }
            out.append(sb).append('\n');
        }
        return out.length() == 0 ? "" : out.substring(0, out.length() - 1);
    }

    private static Map<String, String> clean(Map<String, String> values) {
        Map<String, String> vars = new LinkedHashMap<>();
        for (Map.Entry<String, String> e : values.entrySet()) {
            String v = e.getValue() == null ? "" : e.getValue().replaceAll("[\\r\\n\\t]+", " ").trim();
            vars.put(e.getKey(), v.length() > MAX_VALUE ? v.substring(0, MAX_VALUE) : v);
        }
        if (!vars.containsKey("name")) {
            vars.put("name", "");
        }
        return vars;
    }

    private static String read(File f) throws IOException {
        if (!f.isFile()) {
            throw new IOException("mail template not found: " + f.getPath());
        }
        String text = new String(Files.readAllBytes(f.toPath()), StandardCharsets.UTF_8);
        if (text.startsWith("﻿")) {
            text = text.substring(1);
        }
        return text.replace("\r\n", "\n");
    }

    /* ---------- helpers for the values every sender needs ---------- */

    /** 14700 -> "14.700 đ" */
    public static String money(long amount) {
        return AuthText.vnd(amount);
    }

    /** "2026-10-23 09:00:00" (UTC, as stored) -> "16:00 23/10/2026" (Vietnam time). */
    public static String time(String utc) {
        try {
            SimpleDateFormat in = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
            in.setTimeZone(TimeZone.getTimeZone("UTC"));
            Date d = in.parse(utc);
            SimpleDateFormat out = new SimpleDateFormat("HH:mm dd/MM/yyyy");
            out.setTimeZone(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
            return out.format(d);
        } catch (ParseException | NullPointerException e) {
            return utc == null ? "" : utc;
        }
    }

    /** "https://x/SmartLocker" + "/MyLockerController" or "" when the address of the app is not configured. */
    public static String link(MailService mail, String path) {
        return mail.baseUrl().isEmpty() ? "" : mail.baseUrl() + path;
    }

    /* ---------- preview: sh scripts/mail-preview.sh KEY [address] ---------- */

    private static Map<String, String> sample(MailService mail) {
        Map<String, String> v = new LinkedHashMap<>();
        v.put("name", "Nguyễn Văn An");
        v.put("username", "student1");
        v.put("slot_code", "B01");
        v.put("bank_code", "CANT-B");
        v.put("area_name", "Căng tin KTX khu A");
        v.put("plan_name", "Trọn ngày");
        v.put("open_method", "Mật mã 6 số");
        v.put("amount", money(35000));
        v.put("balance", money(-12500));
        v.put("due_at", time("2026-10-23 09:00:00"));
        v.put("hold_until", time("2026-10-23 02:15:00"));
        v.put("hold_min", "15");
        v.put("refund_pct", "0");
        v.put("refund_amount", money(0));
        v.put("overdue_rate", money(5000));
        v.put("overdue_hours", "3");
        v.put("overdue_fee", money(15000));
        v.put("escalate_hours", "48");
        v.put("code", "482915");
        v.put("expires_min", "10");
        v.put("reason", "Không tìm thấy giao dịch khớp với mã chuyển khoản");
        v.put("my_locker_url", link(mail, "/MyLockerController"));
        v.put("map_url", link(mail, "/LockerMapController"));
        v.put("topup_url", link(mail, "/TopupController"));
        return v;
    }

    public static void main(String[] args) throws Exception {
        MailService mail = MailService.fromContext(null);
        MailTemplates templates = of(mail);
        if (args.length == 0 || "list".equals(args[0])) {
            String[] names = templates.dir.list();
            java.util.Arrays.sort(names);
            for (String n : names) {
                if (n.endsWith(".txt") && !n.startsWith("_")) {
                    System.out.println(n.substring(0, n.length() - 4));
                }
            }
            return;
        }
        Message m = templates.render(args[0], sample(mail));
        System.out.println("Subject: " + m.subject + "\n\n" + m.body);
        if (args.length > 1) {
            mail.send(args[1], m.subject, m.body);
            System.out.println("--> sent to " + args[1]);
        }
    }
}
