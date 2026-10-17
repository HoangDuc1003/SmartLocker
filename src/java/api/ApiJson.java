package api;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.IOException;
import java.util.Map;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/** The one JSON helper of the device and phone endpoints: read a body, write a reply, the shape of an error. */
final class ApiJson {

    /** Dates as UTC text, like the device sends them. Nulls are kept so the box always sees every key. */
    static final Gson GSON = new GsonBuilder().serializeNulls().setDateFormat("yyyy-MM-dd HH:mm:ss").create();

    private ApiJson() {
    }

    /** For lists copied into a reply where a null value is left out (the v1 keys of the heartbeat). */
    static final Gson COMPACT = new Gson();

    /** The body as a JSON object, or null when it is not one (the caller answers 400). */
    static JsonObject body(HttpServletRequest req) {
        JsonElement parsed = parse(req);
        return parsed != null && parsed.isJsonObject() ? parsed.getAsJsonObject() : null;
    }

    /** Like body(), but an empty body counts as {} (a heartbeat may send nothing). */
    static JsonObject bodyOrEmpty(HttpServletRequest req) {
        JsonElement parsed = parse(req);
        if (parsed != null && parsed.isJsonNull()) {
            return new JsonObject();
        }
        return parsed != null && parsed.isJsonObject() ? parsed.getAsJsonObject() : null;
    }

    /** The parsed body (JsonNull when empty), or null when it is not valid JSON. */
    private static JsonElement parse(HttpServletRequest req) {
        try {
            return JsonParser.parseReader(req.getReader());
        } catch (RuntimeException | IOException bad) {
            return null;
        }
    }

    /** A text field, trimmed, or null when absent or not a primitive. */
    static String text(JsonObject json, String key) {
        if (json == null || !json.has(key) || !json.get(key).isJsonPrimitive()) {
            return null;
        }
        String v = json.get(key).getAsString().trim();
        return v.isEmpty() ? null : v;
    }

    /** An integer field, or null when absent or not a whole number. */
    static Integer integer(JsonObject json, String key) {
        String v = text(json, key);
        try {
            return v == null ? null : Integer.valueOf(v);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    static void write(HttpServletResponse res, int status, Object reply) throws IOException {
        res.setStatus(status);
        res.setContentType("application/json;charset=UTF-8");
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write(reply instanceof JsonElement ? reply.toString() : GSON.toJson(reply));
    }

    /** {"result":"ERROR","reason":...,"message":...} with an HTTP status. */
    static void error(HttpServletResponse res, int status, String reason, String message) throws IOException {
        JsonObject reply = new JsonObject();
        reply.addProperty("result", "ERROR");
        reply.addProperty("reason", reason);
        reply.addProperty("message", message);
        write(res, status, reply);
    }

    /** Copies the numbers a reply needs from a procedure row (null stays out). */
    static void copyInt(Map<String, Object> row, String key, JsonObject reply) {
        Object v = row.get(key);
        if (v instanceof Number) {
            reply.addProperty(key, ((Number) v).longValue());
        }
    }
}
