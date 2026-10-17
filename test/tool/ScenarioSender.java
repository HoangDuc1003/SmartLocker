package tool;

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
    // LOCKER-01 has a secret key (scripts/set-device-key.ps1): -Dsmartlocker.apiKey=..., else the local key file
    private static final String API_KEY = DeviceKey.locker01();
    private static final String SCENARIO = "remote";   // heartbeat | remote | spoof | lostcard | checkin | sensor

    // a new range of numbers on every run, so UNIQUE(device_id, device_seq) never drops our sessions
    private static int seq = (int) (System.currentTimeMillis() / 1000);

    public static void main(String[] args) throws Exception {
        // one switch, one case per scenario
        String scenario = args.length > 0 ? args[0] : SCENARIO;
        switch (scenario) {
            case "heartbeat":   // case 1: 6 beats then stop, the device turns OFFLINE about 60 s later
                for (int i = 0; i < 6; i++) {
                    System.out.println(post("/health", heartbeat("A02", false)));
                    Thread.sleep(10000);
                }
                break;
            case "remote": {    // case 2: click Remote unlock on slot A01 in the web first
                JsonObject reply = JsonParser.parseString(post("/health", heartbeat("A01", true))).getAsJsonObject();
                JsonArray commands = reply.getAsJsonArray("commands");
                if (commands.size() == 0) {
                    System.out.println("No pending command, click Remote unlock first");
                    return;
                }
                JsonObject s = session("A01", null, false, 8, 0, 40);
                s.addProperty("open_source", "REMOTE");
                s.addProperty("command_id", commands.get(0).getAsJsonObject().get("command_id").getAsLong());
                System.out.println(postBatch(s));            // expected: STAFF_OPEN, no alert
                JsonObject replay = s.deepCopy();
                replay.addProperty("seq", ++seq);
                System.out.println(postBatch(replay));       // same command used twice: SUSPECTED_SPOOF
                break;
            }
            case "spoof": {     // case 2: REMOTE open with a command the server never issued
                JsonObject s = session("A01", null, false, 8, 0, 40);
                s.addProperty("open_source", "REMOTE");
                s.addProperty("command_id", 999999);
                System.out.println(postBatch(s));
                break;
            }
            case "lostcard":    // case 3: report card 04A1B2C3 lost in the web first
                System.out.println(post("/health", heartbeat("A01", false)));   // blocked_cards lists it now
                System.out.println(postBatch(session("A01", "04A1B2C3", true, 6, 2, 30)));
                break;
            case "checkin":     // case 4: reserve A04 in the web, then run this within the hold time
                System.out.println(post("/health", heartbeat("A04", true)));
                break;
            case "sensor":      // case 5: a weight no real slot can have
                System.out.println(postBatch(session("A01", "0499AABB", true, 6, -5000, 30)));
                break;
            default:
                System.out.println("Unknown scenario: " + scenario);
        }
    }

    private static JsonObject session(String slot, String card, boolean rfidOk,
                                      double doorSec, double weightG, double stayMin) {
        SimpleDateFormat utc = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        utc.setTimeZone(TimeZone.getTimeZone("UTC"));   // the server compares with SYSUTCDATETIME()
        JsonObject s = new JsonObject();
        s.addProperty("seq", ++seq);
        s.addProperty("measured_at", utc.format(new Date()));
        s.addProperty("door_open_sec", doorSec);
        s.addProperty("weight_delta_g", weightG);
        s.addProperty("unlock_count", 2);
        s.addProperty("rfid_ok", rfidOk);               // a real JSON boolean, never 1.0
        s.addProperty("stay_min", stayMin);
        s.addProperty("slot_code", slot);
        s.addProperty("card_uid", card);
        s.addProperty("open_source", "RFID");
        return s;
    }

    private static JsonObject heartbeat(String slot, boolean occupied) {
        JsonObject slotJson = new JsonObject();
        slotJson.addProperty("slot_code", slot);
        slotJson.addProperty("occupied", occupied);
        JsonArray slots = new JsonArray();
        slots.add(slotJson);
        JsonObject body = new JsonObject();
        body.addProperty("firmware", "sim-1.0");
        body.add("slots", slots);
        return body;
    }

    private static String postBatch(JsonObject session) throws Exception {
        JsonArray sessions = new JsonArray();
        sessions.add(session);
        JsonObject body = new JsonObject();
        body.addProperty("device_id", 1);
        body.add("sessions", sessions);
        return post("/locker/batch", body);
    }

    private static String post(String path, JsonObject body) throws Exception {
        HttpURLConnection conn = (HttpURLConnection) new URL(BASE_URL + path).openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
        conn.setRequestProperty("X-API-Key", API_KEY);
        try (OutputStream out = conn.getOutputStream()) {
            out.write(body.toString().getBytes("UTF-8"));
        }
        int code = conn.getResponseCode();
        InputStream in = code < 400 ? conn.getInputStream() : conn.getErrorStream();
        String text = "";
        if (in != null) {
            try (Scanner sc = new Scanner(in, "UTF-8").useDelimiter("\\A")) {
                text = sc.hasNext() ? sc.next() : "";
            }
        }
        System.out.println("POST " + path + " -> HTTP " + code);
        return text;
    }
}
