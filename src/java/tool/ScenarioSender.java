package tool;

import util.Todo;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Scanner;
import java.util.TimeZone;

/**
 * Plays the ESP32 before the real device is ready: same URLs, same header, same JSON.
 * Set SCENARIO (or pass it as the first argument) and use Run File in NetBeans. Tomcat must be running.
 *   heartbeat  case 1: 6 beats, then silence; the device turns OFFLINE about 60 s later
 *   remote     case 2: click Remote unlock on slot A01 in the web first
 *   spoof      case 2: a REMOTE open with a command the server never issued
 *   lostcard   case 3: report card 04A1B2C3 lost in the web first
 *   checkin    case 4: reserve A04 in the web, then run this within 15 minutes
 *   sensor     case 5: a weight no real slot can have
 */
public class ScenarioSender {

    private static final String BASE_URL = "http://localhost:8080/SmartLocker/api";
    private static final String API_KEY = "device-1-api-key";
    private static final String SCENARIO = "remote";   // heartbeat | remote | spoof | lostcard | checkin | sensor

    // a new range of numbers on every run, so UNIQUE(device_id, device_seq) never drops our sessions
    private static int seq = (int) (System.currentTimeMillis() / 1000);

    public static void main(String[] args) throws Exception {
        throw Todo.of("ScenarioSender.main: one switch, one case per scenario");
    }

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: the JSON of a session, of a heartbeat, and the HTTP call
}
