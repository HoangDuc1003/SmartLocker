package service;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Base64;
import java.util.Date;
import java.util.Locale;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.net.ssl.SSLParameters;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import javax.servlet.ServletContext;

/**
 * v3: a small SMTP client in plain Java (no mail library): SSL on port 465, or STARTTLS on 587, AUTH LOGIN,
 * one plain-text UTF-8 message. Made for a Gmail account with an app password.
 *
 * Settings come from config/mail.local.properties (git ignores *.local.properties; see the .example file):
 *   mail.host, mail.port, mail.user, mail.password, mail.from, mail.from_name, app.base_url
 * Looked up in this order: -Dsmartlocker.mailConfig=FILE, the config/ folder of the project the app is deployed
 * from (build/web/../../config), then CATALINA_BASE/conf/smartlocker-mail.properties.
 * Without a file the service is disabled and the web app works as before, also offline.
 */
public final class MailService {

    private static final Logger LOG = Logger.getLogger(MailService.class.getName());
    private static final int TIMEOUT_MS = 15_000;

    private final Properties props;
    private final String source;

    private MailService(Properties props, String source) {
        this.props = props;
        this.source = source;
    }

    private static final String ATTRIBUTE = "smartlocker.mail";

    /** The service of this web app: read once, then kept in the servlet context. */
    public static MailService of(ServletContext ctx) {
        Object o = ctx.getAttribute(ATTRIBUTE);
        if (o instanceof MailService) {
            return (MailService) o;
        }
        MailService m = fromContext(ctx);
        ctx.setAttribute(ATTRIBUTE, m);
        return m;
    }

    /** Reads the settings; returns a disabled service when there is no usable file. */
    public static MailService fromContext(ServletContext ctx) {
        for (File f : candidates(ctx)) {
            if (f != null && f.isFile()) {
                Properties p = new Properties();
                try (InputStream in = new FileInputStream(f);
                     InputStreamReader reader = new InputStreamReader(in, StandardCharsets.UTF_8)) {
                    p.load(reader);
                    return new MailService(p, f.getAbsolutePath());
                } catch (IOException e) {
                    LOG.log(Level.WARNING, "Cannot read mail settings " + f + ": " + e.getMessage());
                }
            }
        }
        return new MailService(new Properties(), null);
    }

    private static File[] candidates(ServletContext ctx) {
        String explicit = System.getProperty("smartlocker.mailConfig");
        String root = ctx == null ? null : ctx.getRealPath("/");
        File project = root == null ? null : new File(root).getAbsoluteFile().getParentFile();
        project = project == null ? null : project.getParentFile();
        String catalina = System.getProperty("catalina.base");
        return new File[] {
            explicit == null ? null : new File(explicit),
            project == null ? null : new File(project, "config/mail.local.properties"),
            catalina == null ? null : new File(catalina, "conf/smartlocker-mail.properties")
        };
    }

    public boolean isEnabled() {
        return source != null && !get("mail.host").isEmpty() && !get("mail.user").isEmpty()
                && !get("mail.password").isEmpty();
    }

    /** Where the settings came from, for the log; null when disabled. */
    public String source() {
        return source;
    }

    public String get(String key) {
        return props.getProperty(key, "").trim();
    }

    /** The public address of the app for links in a message, e.g. https://.../SmartLocker; may be empty. */
    public String baseUrl() {
        String url = get("app.base_url");
        return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
    }

    /** Sends one plain-text message. Throws on any SMTP error; the caller retries later. */
    public void send(String to, String subject, String body) throws IOException {
        if (!isEnabled()) {
            throw new IOException("mail is not configured");
        }
        if (to == null || !to.matches("[^\\s<>@,;\"]+@[^\\s<>@,;\"]+\\.[^\\s<>@,;\"]+")) {
            throw new IOException("bad recipient address");      // also stops CR/LF header injection
        }
        String host = get("mail.host");
        int port = Integer.parseInt(get("mail.port").isEmpty() ? "465" : get("mail.port"));
        String from = get("mail.from").isEmpty() ? get("mail.user") : get("mail.from");
        Socket socket = null;
        try {
            if (port == 465) {
                socket = tls(new Socket(), host, port, true);
            } else {
                socket = new Socket();
                socket.connect(new InetSocketAddress(host, port), TIMEOUT_MS);
                socket.setSoTimeout(TIMEOUT_MS);
            }
            Smtp smtp = new Smtp(socket);
            smtp.expect(220);
            smtp.command("EHLO smartlocker", 250);
            if (port != 465) {
                smtp.command("STARTTLS", 220);
                socket = tls(socket, host, port, false);
                smtp = new Smtp(socket);
                smtp.command("EHLO smartlocker", 250);
            }
            smtp.command("AUTH LOGIN", 334);
            smtp.command(b64(get("mail.user")), 334);
            smtp.command(b64(get("mail.password")), 235);
            smtp.command("MAIL FROM:<" + from + ">", 250);
            try {
                smtp.command("RCPT TO:<" + to + ">", 250);
            } catch (IOException e) {
                throw String.valueOf(e.getMessage()).startsWith("SMTP 5")
                        ? new IOException("bad recipient: " + e.getMessage()) : e;
            }
            smtp.command("DATA", 354);
            smtp.raw(message(from, to, subject, body));
            smtp.command(".", 250);
            smtp.command("QUIT", 221);
        } finally {
            if (socket != null) {
                try {
                    socket.close();
                } catch (IOException ignored) {
                    // closing a broken connection
                }
            }
        }
    }

    /** A new TLS socket, or an upgrade of a connected one (STARTTLS); the host name is checked. */
    private static Socket tls(Socket plain, String host, int port, boolean connect) throws IOException {
        if (connect) {
            plain.connect(new InetSocketAddress(host, port), TIMEOUT_MS);
        }
        SSLSocket s = (SSLSocket) ((SSLSocketFactory) SSLSocketFactory.getDefault()).createSocket(plain, host, port, true);
        SSLParameters params = s.getSSLParameters();
        params.setEndpointIdentificationAlgorithm("HTTPS");
        s.setSSLParameters(params);
        s.setSoTimeout(TIMEOUT_MS);
        s.startHandshake();
        return s;
    }

    private String message(String from, String to, String subject, String body) {
        SimpleDateFormat date = new SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss Z", Locale.US);
        String name = get("mail.from_name").isEmpty() ? "Smart Locker" : get("mail.from_name");
        StringBuilder sb = new StringBuilder();
        sb.append("From: ").append(encodeWord(name)).append(" <").append(from).append(">\r\n");
        sb.append("To: <").append(to).append(">\r\n");
        sb.append("Subject: ").append(encodeWord(subject)).append("\r\n");
        sb.append("Date: ").append(date.format(new Date())).append("\r\n");
        sb.append("MIME-Version: 1.0\r\n");
        sb.append("Content-Type: text/plain; charset=UTF-8\r\n");
        sb.append("Content-Transfer-Encoding: base64\r\n\r\n");
        String encoded = b64(body.replace("\r\n", "\n").replace("\n", "\r\n"));
        for (int i = 0; i < encoded.length(); i += 76) {
            sb.append(encoded, i, Math.min(encoded.length(), i + 76)).append("\r\n");
        }
        return sb.toString();
    }

    private static String encodeWord(String text) {
        return "=?UTF-8?B?" + b64(text.replaceAll("[\\r\\n]", " ")) + "?=";
    }

    private static String b64(String text) {
        return Base64.getEncoder().encodeToString(text.getBytes(StandardCharsets.UTF_8));
    }

    /** Line protocol: a reply is one or more "NNN-text" lines ending with "NNN text". */
    private static final class Smtp {
        private final BufferedReader in;
        private final OutputStream out;

        Smtp(Socket socket) throws IOException {
            this.in = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.US_ASCII));
            this.out = socket.getOutputStream();
        }

        void raw(String text) throws IOException {
            out.write(text.getBytes(StandardCharsets.US_ASCII));
            out.flush();
        }

        void command(String line, int expected) throws IOException {
            raw(line + "\r\n");
            expect(expected);
        }

        void expect(int expected) throws IOException {
            String line;
            do {
                line = in.readLine();
                if (line == null || line.length() < 3) {
                    throw new IOException("SMTP connection closed");
                }
            } while (line.length() > 3 && line.charAt(3) == '-');
            int code;
            try {
                code = Integer.parseInt(line.substring(0, 3));
            } catch (NumberFormatException e) {
                throw new IOException("SMTP bad reply");
            }
            if (code != expected) {
                throw new IOException("SMTP " + code + " (expected " + expected + ")");
            }
        }
    }
}
