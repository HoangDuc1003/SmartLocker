package tool;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import dao.DbContext;
import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Random;
import java.util.TimeZone;

/**
 * Plays the public sessions (table PublicSession) to the server through the same API as a real device,
 * with a simulated network outage so the buffer logic is exercised. Run with Run File in NetBeans.
 * Tomcat must be running.
 */
public class DataReplayer {

    private static final String API_URL = "http://localhost:8080/SmartLocker/api/locker/batch";
    private static final String API_KEY = "device-1-api-key";
    private static final double DROP_RATE = 0.15;       // probability of a simulated outage on a row
    private static final int BATCH_LIMIT = 20;

    // a new range of numbers on every run, so UNIQUE(device_id, device_seq) never drops our sessions
    private static int seq = (int) (System.currentTimeMillis() / 1000);

    public static void main(String[] args) throws Exception {
        // read PublicSession, buffer rows, send a batch when the "network" is up
        SimpleDateFormat stamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        stamp.setTimeZone(TimeZone.getTimeZone("UTC"));      // the server works in UTC, not in your time zone
        Random random = new Random();
        JsonArray buffer = new JsonArray();
        try (Connection conn = DbContext.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min "
                     + "FROM PublicSession ORDER BY public_id")) {
            while (rs.next()) {
                JsonObject session = new JsonObject();
                session.addProperty("seq", ++seq);
                session.addProperty("measured_at", stamp.format(new Date()));
                session.addProperty("door_open_sec", rs.getDouble("door_open_sec"));
                session.addProperty("weight_delta_g", rs.getDouble("weight_delta_g"));
                session.addProperty("unlock_count", rs.getInt("unlock_count"));
                session.addProperty("rfid_ok", rs.getBoolean("rfid_ok"));   // a real boolean, not 1.0
                session.addProperty("stay_min", rs.getDouble("stay_min"));
                buffer.add(session);

                if (random.nextDouble() < DROP_RATE) {
                    System.out.println("network down, buffered sessions: " + buffer.size());
                    continue;                                 // keep the sessions in the buffer
                }
                if (buffer.size() >= BATCH_LIMIT || random.nextDouble() < 0.5) {
                    if (send(buffer)) {
                        buffer = new JsonArray();
                    }
                }
                Thread.sleep(200);
            }
            send(buffer);                                     // flush whatever is left
        }
    }

    /** true when the server answered 200, so the caller may forget the sessions. */
    private static boolean send(JsonArray sessions) throws IOException {
        // POST with the X-API-Key header; keep the buffer when the answer is not 200
        if (sessions.size() == 0) {
            return true;
        }
        JsonObject body = new JsonObject();
        body.add("sessions", sessions);                       // the device id comes from the API key
        HttpURLConnection conn = (HttpURLConnection) new URL(API_URL).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
        conn.setRequestProperty("X-API-Key", API_KEY);
        try (OutputStream out = conn.getOutputStream()) {
            out.write(body.toString().getBytes("UTF-8"));
        }
        int code = conn.getResponseCode();
        System.out.println("sent " + sessions.size() + " sessions, server replied " + code);
        conn.disconnect();
        return code == 200;
    }
}
