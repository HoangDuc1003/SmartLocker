package tool;

import util.Todo;
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
        throw Todo.of("DataReplayer.main: read PublicSession, buffer rows, send a batch when the 'network' is up");
    }

    /** true when the server answered 200, so the caller may forget the sessions. */
    private static boolean send(JsonArray sessions) throws IOException {
        throw Todo.of("DataReplayer.send: POST with the X-API-Key header; keep the buffer when the answer is not 200");
    }
}
