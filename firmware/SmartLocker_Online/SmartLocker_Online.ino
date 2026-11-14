/*
 * SmartLocker - online box LOCKER-01 (ESP32 DevKit, ESP32 core 3.x)
 * Hardware: LCD 1602 I2C, 2 servos (bolt + pull-out door), SRF05, keypad 4x4, PN532 (NFC), AS608.
 *
 * The box never decides: every PIN, card and finger goes to the web (POST /api/device/auth) and the box opens only on
 * "UNLOCK". A heartbeat every 3 s (POST /api/health) keeps LOCKER-01 ONLINE and brings the queued commands: UNLOCK
 * (phone tap, phone page, staff) and DELETE_FP.
 *
 * One PN532 (I2C, shared with the LCD) takes turns, one short slice per loop():
 *  - card reader: a UID goes to /api/device/auth. A 4-byte UID starting 0x08 is random (a phone HCE wallet): ignored,
 *    or a phone tap would count as an unknown card towards the 5-try lockout.
 *  - NFC tag: one URL record, base URL + "tap_path" of the heartbeat (/k/LOCKER-01?n=<token>). The token changes every
 *    minute and after each use, so the tag is rewritten when it changes. The phone opens the page, the signed-in owner
 *    presses "Mo tu cua toi", the UNLOCK comes with the next heartbeat. No tag while a PIN is typed or a card enrolled.
 *
 * Keypad: 0-9 PIN (6 digits), # send, * clear / cancel. B enroll a card, C enroll a finger (then the 6-digit code from
 * "Tu cua toi", #). D: door closed = IP / server status, door open = lock now. Every auth goes first with intent ASK;
 * a rented slot answers CHOOSE ("A: Mo tu / B: Tra tu"): A sends it again with OPEN (the rental goes on), B with
 * CHECKOUT (the rental ends), * or CHOOSE_MS cancels. An older server ignores the intent and answers PICKUP.
 *
 * Only one compartment has the servos: an UNLOCK with "physical":false only shows "Ngan B08 OK" (sql/demo_box.sql);
 * no "physical" (an older server) means every slot is the real one. Opening releases the bolt, then turns the door
 * servo. D locks at once. Otherwise: while the SRF05 sees someone within DOORWAY_CM nothing counts; once nobody is
 * there a DOOR_OPEN_MS countdown runs and locks the door (someone coming back stops it, leaving starts it again from
 * the top). DOOR_OPEN_MAX_MS after opening it locks anyway, so a blocked sensor cannot leave the slot open.
 * The SRF05 also drives the LCD backlight: on while someone is near, off SCREEN_OFF_MS after the last person and input.
 *
 * Speed (4.3): one kept-alive HTTP(S) connection (no TCP/TLS handshake per request), the LCD is written only when its
 * text changes (the I2C bus is shared with the PN532), the PN532 is reconfigured only when it changes role, and the
 * sonar waits for an echo of at most SONAR_MAX_CM.
 *
 * Libraries: Keypad, Adafruit Fingerprint Sensor Library, ArduinoJson 7, LiquidCrystal I2C (Frank de Brabander) and
 * PN532-Arduino of Seeed-Studio (PN532, PN532_I2C, EmulateTag). No NDEF library: the record is built here. Servos use
 * the ESP32 LEDC. Copy secrets.example.h to secrets.h first.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <PN532_I2C.h>
#include <PN532.h>
#include <emulatetag.h>
#include <Keypad.h>
#include <Adafruit_Fingerprint.h>
#include <LiquidCrystal_I2C.h>

#if __has_include("secrets.h")
#include "secrets.h"
#else
#error "Copy secrets.example.h to secrets.h and fill in Wi-Fi, server and API key"
#endif

static const char FIRMWARE[] = "4.3-esp32";

// ---- Switches and pins ----
// PN532 in I2C mode (switches I0=1, I1=0) on SDA 21 / SCL 22 with the LCD: the PN532 answers at 0x24, the LCD at 0x27.
static constexpr bool USE_NFC = true;              // false: no cards and no tag (phones open through the /k page or staff)
static constexpr bool USE_FINGERPRINT = true;      // false: skip the AS608
static constexpr bool USE_DOOR_SERVO = true;       // false: only the bolt moves, GPIO2 stays untouched
static constexpr bool USE_SONAR = true;            // false: backlight always on, the door locks right at DOOR_OPEN_MS
static constexpr int I2C_SDA = 21, I2C_SCL = 22;
static constexpr uint8_t LCD_ADDR = 0x27;          // some 1602 backpacks use 0x3F
static constexpr int FP_RX_PIN = 35, FP_TX_PIN = 15;   // ESP32 RX <- AS608 TX, ESP32 TX -> AS608 RX
static constexpr uint32_t FP_BAUD = 57600;
static constexpr int SERVO_BOLT_PIN = 32;
static constexpr int SERVO_DOOR_PIN = 2;           // GPIO2 is a boot strap pin: plug the signal wire in after the upload
static constexpr int BOLT_LOCKED_DEG = 0, BOLT_UNLOCKED_DEG = 85;
static constexpr int DOOR_CLOSED_DEG = 0, DOOR_OPEN_DEG = 180;   // 180: the largest angle servoWrite() sends (2400 us)
static constexpr int SONAR_TRIG = 5, SONAR_ECHO = 18;  // ECHO through the 1k / 2k divider (the SRF05 echo is 5 V)
byte rowPins[4] = {13, 14, 25, 26};                // R1..R4
byte colPins[4] = {33, 19, 23, 27};                // C1..C4

// ---- Timing ----
static constexpr uint16_t NFC_LISTEN_MS = 5;       // a tag slice; the library polls I2C many times per timeout: keep it small
static constexpr uint16_t CARD_POLL_MS = 30;       // a card slice
static constexpr int NEAR_CM = 50;                 // someone this close wakes the backlight
static constexpr int DOORWAY_CM = 50;              // someone this close still uses the open box: the lock countdown waits
static constexpr int SONAR_MAX_CM = 100;           // farther, or no echo, is nobody; it bounds the pulseIn() wait (~7 ms)
static constexpr uint32_t DOOR_OPEN_MS = 20000;    // the automatic lock comes this long after the last person left...
static constexpr uint32_t DOOR_OPEN_MAX_MS = 120000;  // ...and never later than this after opening (a blocked sensor)
static constexpr uint32_t SCREEN_OFF_MS = 60000;   // backlight off this long after the last person and input
static constexpr uint32_t ONLINE_MS = 10000;       // no good heartbeat for this long: "mat ket noi"
static constexpr uint32_t CHOOSE_MS = 15000;       // A / B after a CHOOSE reply; the server's choose_sec wins when sent
static constexpr uint32_t CARD_ENROLL_MS = 30000;  // time to scan the card being enrolled
static constexpr uint32_t CARD_REPEAT_MS = 1500;   // the same card still on the reader is not sent again
static constexpr uint16_t HTTP_TIMEOUT_MS = 6000;
static constexpr uint32_t IDLE_SOCKET_MS = 15000;  // a kept-alive socket idle longer is not trusted (Tomcat drops it at 20 s)

char keys[4][4] = {{'1', '2', '3', 'A'}, {'4', '5', '6', 'B'}, {'7', '8', '9', 'C'}, {'*', '0', '#', 'D'}};

PN532_I2C pn532i2c(Wire);
PN532 reader(pn532i2c);        // the card role
EmulateTag tag(pn532i2c);      // the tag role
Keypad keypad(makeKeymap(keys), rowPins, colPins, 4, 4);
HardwareSerial fingerSerial(2);
Adafruit_Fingerprint finger(&fingerSerial);
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);
WiFiClient plainClient;        // all three kept between requests: HTTP keep-alive (a local HTTPClient
WiFiClientSecure secureClient; // would close the socket in its destructor)
HTTPClient server;

enum Mode { MODE_IDLE, MODE_ENROLL_CODE, MODE_ENROLL_CARD, MODE_CHOOSE };
enum NfcRole { ROLE_NONE, ROLE_READER, ROLE_TAG };
Mode mode = MODE_IDLE;
NfcRole nfcRole = ROLE_NONE;
JsonDocument chooseBody;       // the auth that answered CHOOSE, sent again with OPEN or CHECKOUT
String chooseSlot, enrollType, enrollCode, pinBuffer, baseUrl, tapPath, lastCardUid, shown1, shown2;
uint32_t chooseDeadline, enrollDeadline, lastHeartbeat, lastGoodHeartbeat, holdMs, openedAt, clearSince,
    lastDoorDraw, messageUntil, lastFingerScan, fingerQuietUntil, lastCardAt, lastActivity, lastSonar, lastHttpMs;
uint32_t heartbeatEveryMs = 3000;
uint8_t heartbeatFails = 0;
int lastHttpCode = 0;
long lastCm = -1;              // last SRF05 distance; -1: nobody within SONAR_MAX_CM
bool fingerOk, lcdOk, nfcOk, doorOpen, idleDrawn;
bool screenOn = true;
bool fingerWaitLift = true;    // read again only after the sensor saw no finger (a stuck or ghost image never repeats)
uint8_t ndefBuf[128];          // the NDEF message of the tag (EmulateTag's NDEF_MAX_LENGTH is 128 too)

// A millis() deadline that survives the 49-day wrap.
static bool reached(uint32_t t) { return (int32_t) (millis() - t) >= 0; }

// ---------------------------------------------------------------- screen (LCD 1602: 2 lines of 16)

bool isOnline() {
  return WiFi.status() == WL_CONNECTED && lastGoodHeartbeat && millis() - lastGoodHeartbeat < ONLINE_MS;
}

void setScreen(bool on) {
  if (!lcdOk || on == screenOn) return;
  if (on) lcd.backlight(); else lcd.noBacklight();
  screenOn = on;
}

void wake() {
  lastActivity = millis();
  setScreen(true);
}

// One line padded to 16 characters (no lcd.clear() flicker), written only when it changed. True when it changed.
bool lcdLine(uint8_t row, String text, String& shown) {
  text = text.substring(0, 16);
  while (text.length() < 16) text += ' ';
  if (text == shown) return false;
  shown = text;
  if (lcdOk) {
    lcd.setCursor(0, row);
    lcd.print(text);
  }
  return true;
}

// '\n' starts the second line. holdMs > 0 keeps the text that long, then the idle screen comes back.
void show(const String& text, uint32_t holdMs = 0) {
  messageUntil = holdMs ? millis() + holdMs : 0;
  idleDrawn = false;
  int nl = text.indexOf('\n');
  bool changed = lcdLine(0, nl < 0 ? text : text.substring(0, nl), shown1);
  changed |= lcdLine(1, nl < 0 ? String() : text.substring(nl + 1), shown2);
  if (changed) {
    Serial.print(F("[LCD] "));
    Serial.println(text);
  }
}

// A servo current dip can garble the LCD: forget what it shows, so the next show() writes every character again.
void redrawLcd() {
  shown1 = shown2 = String();
}

void drawIdle() {
  if (mode == MODE_ENROLL_CODE) show(String(enrollType == "CARD" ? "Ma DK the:" : "Ma DK van tay:") + "\n" + pinBuffer + "_");
  else if (mode == MODE_ENROLL_CARD) show(F("Quet the dang ky\n(* de huy)"));
  else if (mode == MODE_CHOOSE) show("A: Mo tu  * huy\nB: Tra tu " + chooseSlot);
  else if (pinBuffer.length()) show("PIN: " + String("******").substring(0, pinBuffer.length()) + "\n# gui  * xoa");
  else if (!isOnline()) show(WiFi.status() == WL_CONNECTED ? F("Mat ket noi\nDang thu lai...") : F("Mat Wi-Fi\nDang noi lai..."));
  else show(F("PIN + # / van tay\nthe / cham NFC"));
  idleDrawn = true;
}

// ---------------------------------------------------------------- PN532: cards and the NFC tag for the phone tap

void initNfc() {
  if (!USE_NFC) return;
  static uint8_t uid[3] = {0x53, 0x4C, 0x01};    // "SL", box 1; static: EmulateTag keeps the pointer and reads it later
  tag.setTagWriteable(false);                    // a phone may read the tag, never change it
  tag.setUid(uid);
  nfcOk = tag.init();
  nfcRole = ROLE_NONE;
  if (nfcOk) reader.setPassiveActivationRetries(0x01);   // one try per slice, or a poll blocks the keypad
  Serial.println(nfcOk ? F("PN532 OK (cards + tag)") : F("PN532 not found: I2C switches, SDA 21 / SCL 22, 0x24"));
}

// Writes base URL + tapPath into the tag: when the heartbeat brings another path or the base URL moved.
void setTagUrl() {
  if (!nfcOk || tapPath.isEmpty()) return;
  String url = baseUrl + tapPath;
  int size = 5 + url.length();               // one NDEF short record: header, type length, payload length, 'U', 0x00
  if (size > (int) sizeof(ndefBuf) - 2) {    // EmulateTag keeps 2 bytes of its 128 for the length
    Serial.printf("Tag URL too long (%d bytes): %s\n", size, url.c_str());
    return;
  }
  ndefBuf[0] = 0xD1;                         // MB + ME + SR + well-known type
  ndefBuf[1] = 1;                            // type length
  ndefBuf[2] = url.length() + 1;             // payload: URI code + URL
  ndefBuf[3] = 'U';                          // type: URI
  ndefBuf[4] = 0x00;                         // URI code 0: the URL is written in full
  memcpy(ndefBuf + 5, url.c_str(), url.length());
  tag.setNdefFile(ndefBuf, size);
  Serial.print(F("NFC tag: "));
  Serial.println(url);
}

// The PN532 needs SAMConfig when it changes between the reader and the tag role; staying in one role needs nothing.
void nfcRoleTo(NfcRole role) {
  if (nfcRole == role) return;
  if (reader.SAMConfig()) nfcRole = role;   // on a failure (a PN532 brownout) the next slice tries again
}

String hexUid(const uint8_t* uid, uint8_t size) {
  String text;
  char b[3];
  for (uint8_t i = 0; i < size; i++) {
    snprintf(b, sizeof b, "%02X", uid[i]);
    text += b;
  }
  return text;
}

void authorize(JsonDocument& body);
void finishCardEnroll(const String& uid);

// One short poll for a card. A UID goes to the enrollment that waits for it, or to the server as an open.
void cardSlice() {
  nfcRoleTo(ROLE_READER);
  uint8_t uid[10];
  uint8_t size = 0;
  if (!reader.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &size, CARD_POLL_MS)) return;
  if (size == 4 && uid[0] == 0x08) return;   // a random UID: a phone with an HCE wallet, no card (see the header)
  String text = hexUid(uid, size);
  if (text == lastCardUid && millis() - lastCardAt < CARD_REPEAT_MS) {   // the same card still on the reader
    lastCardAt = millis();
    return;
  }
  lastCardUid = text;
  Serial.print(F("Card UID: "));
  Serial.println(text);
  wake();
  if (mode == MODE_ENROLL_CARD) {
    finishCardEnroll(text);
  } else {
    JsonDocument body;
    body["method"] = "CARD";
    body["card_uid"] = text;
    authorize(body);
  }
  lastCardAt = millis();    // counted from the end of the HTTP call, or a card still held is sent again
}

// One PN532 job per loop(), so the keypad stays responsive: the card poll and the tag take turns.
void nfcSlice() {
  if (!nfcOk) return;
  static bool tagTurn = false;
  tagTurn = !tagTurn;
  if (tagTurn && !tapPath.isEmpty() && mode == MODE_IDLE && pinBuffer.isEmpty()) {
    nfcRoleTo(ROLE_TAG);
    if (tag.emulate(NFC_LISTEN_MS)) {          // the phone opens the link itself; the box only says it was read
      wake();
      show(F("Da gui lien ket\nXem dien thoai"), 3000);
      Serial.println(F("NFC tag read by a phone"));
    }
  } else if (mode == MODE_IDLE || mode == MODE_ENROLL_CARD) {
    cardSlice();
  }
}

// ---------------------------------------------------------------- sonar

void sampleSonar() {
  if (!USE_SONAR || millis() - lastSonar < 150) return;
  lastSonar = millis();
  digitalWrite(SONAR_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(SONAR_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(SONAR_TRIG, LOW);
  // 58 us per cm, plus the SRF05's delay before the echo starts (the timeout counts from the call); farther: nobody
  long us = pulseIn(SONAR_ECHO, HIGH, SONAR_MAX_CM * 58UL + 2500);
  long cm = us / 58;
  lastCm = (us == 0 || cm < 2) ? -1 : cm;
}

bool someoneWithin(int cm) {
  return USE_SONAR && lastCm > 0 && lastCm <= cm;
}

// ---------------------------------------------------------------- bolt and door

void servoWrite(int pin, int deg) {   // 50 Hz, 14-bit duty: 500 us (0 deg) .. 2400 us (180 deg) of 20000 us
  ledcWrite(pin, (500 + (uint32_t) deg * 1900 / 180) * 16383 / 20000);
}

void openDoor(int seconds, const String& message) {
  wake();
  show(message, 3000);
  servoWrite(SERVO_BOLT_PIN, BOLT_UNLOCKED_DEG);   // release the bolt first, then turn the door
  delay(1000);
  if (USE_DOOR_SERVO) {
    servoWrite(SERVO_DOOR_PIN, DOOR_OPEN_DEG);
    delay(500);
  }
  doorOpen = true;
  openedAt = millis();
  uint32_t ms = seconds > 0 ? (uint32_t) seconds * 1000 : 0;   // the server's open_sec only makes the countdown longer
  holdMs = ms > DOOR_OPEN_MS ? ms : DOOR_OPEN_MS;
  clearSince = 0;
  lastDoorDraw = 0;
  redrawLcd();
}

// A slot without a servo: the server already moved the booking on, the LCD only confirms it.
void showSlotOk(const String& slotCode, const String& second) {
  wake();
  show("Ngan " + slotCode + " OK\n" + second, 3000);
  Serial.printf("Slot %s OK (no servo)\n", slotCode.c_str());
}

void closeDoor() {
  if (USE_DOOR_SERVO) {
    servoWrite(SERVO_DOOR_PIN, DOOR_CLOSED_DEG);   // the door first, then the bolt
    delay(1500);
  }
  servoWrite(SERVO_BOLT_PIN, BOLT_LOCKED_DEG);
  delay(500);
  doorOpen = false;
  if (USE_NFC) {            // a servo current dip can reset the PN532: start it again with the same tag
    initNfc();
    setTagUrl();
  }
  redrawLcd();
  wake();
  show(F("Da khoa cua"), 1500);
  Serial.println(F("Door closed"));
}

// The door stays open until D locks it (loop) or the countdown locks it here. The countdown runs only while nobody is
// within DOORWAY_CM: someone there stops it, and it starts again from holdMs when they leave. Without the sonar nobody
// is ever seen, so it simply locks holdMs after opening. DOOR_OPEN_MAX_MS after opening it locks whatever the sonar says.
void doorTick() {
  if (!doorOpen) return;
  uint32_t now = millis();
  if (someoneWithin(DOORWAY_CM)) clearSince = 0;
  else if (!clearSince) clearSince = now;
  if ((clearSince && now - clearSince >= holdMs) || now - openedAt >= DOOR_OPEN_MAX_MS) {
    closeDoor();
    return;
  }
  if (messageUntil || now - lastDoorDraw < 1000) return;
  lastDoorDraw = now;
  if (!clearSince) {
    show(F("Bam D de khoa\nCo nguoi, cho..."));
    return;
  }
  uint32_t left = holdMs - (now - clearSince);
  show("Bam D de khoa\nTu khoa sau " + String((left + 999) / 1000) + "s");
}

// ---------------------------------------------------------------- network

// Closes the kept-alive sockets: on a new base URL (they still point at the old address) or after an error.
void dropConnection() {
  plainClient.stop();
  secureClient.stop();
}

int postOnce(const String& url, const String& payload, JsonDocument& reply) {
  if (!server.begin(url.startsWith("https://") ? (WiFiClient&) secureClient : plainClient, url)) return -1;
  server.addHeader("Content-Type", "application/json");
  server.addHeader("X-API-Key", DEVICE_API_KEY);
  int code = server.POST(payload);
  if (code > 0) {
    String text = server.getString();
    reply.clear();
    deserializeJson(reply, text);
    if (code != 200) Serial.printf("POST %s -> HTTP %d %s\n", url.c_str(), code, text.c_str());
  }
  server.end();             // keeps the socket open when the server allows keep-alive
  return code;
}

// POST {path} with the device key. Returns the HTTP code (<= 0: no connection) and fills reply.
int postJson(const char* path, const JsonDocument& body, JsonDocument& reply) {
  if (WiFi.status() != WL_CONNECTED || baseUrl.isEmpty()) return -1;
  String url = baseUrl + "/api" + path, payload;
  serializeJson(body, payload);
  // Tomcat closes an idle kept-alive socket after 20 s, and this core still reports it connected (a finger enrollment
  // blocks the loop up to 50 s): after 15 s of silence, start on a new connection.
  if (millis() - lastHttpMs > IDLE_SOCKET_MS) dropConnection();
  int code = postOnce(url, payload, reply);
  // The server closed the kept-alive socket before the request went out: send it once more on a new connection.
  // Never after a read error: the server may have acted on it already (a check-in, a counted PIN).
  if (code == HTTPC_ERROR_SEND_HEADER_FAILED || code == HTTPC_ERROR_SEND_PAYLOAD_FAILED || code == HTTPC_ERROR_NOT_CONNECTED) {
    dropConnection();
    code = postOnce(url, payload, reply);
  }
  if (code <= 0) {
    Serial.printf("POST %s -> %s\n", path, HTTPClient::errorToString(code).c_str());
    dropConnection();
  }
  lastHttpMs = millis();
  lastHttpCode = code;
  return code;
}

// Mode 2: read base_url from CONFIG_URL (the fixed link on GitHub Pages points at the current tunnel).
void loadBaseUrl() {
  dropConnection();          // the address may change, and only one TLS session at a time (heap)
  String configUrl = CONFIG_URL;
  if (configUrl.isEmpty()) {
    baseUrl = SERVER_BASE;
  } else {
    WiFiClientSecure secure;   // GitHub Pages, not the app server: a short connection of its own
    secure.setInsecure();
    HTTPClient http;
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
    http.setTimeout(HTTP_TIMEOUT_MS);
    if (http.begin(secure, configUrl + "?t=" + String(millis())) && http.GET() == 200) {   // ?t= skips the Pages cache
      JsonDocument doc;
      if (!deserializeJson(doc, http.getString()) && doc["base_url"].is<const char*>()) {
        baseUrl = doc["base_url"].as<String>();
        while (baseUrl.endsWith("/")) baseUrl.remove(baseUrl.length() - 1);
      }
    }
    http.end();
    if (baseUrl.isEmpty()) baseUrl = SERVER_BASE;
    Serial.print(F("Server: "));
    Serial.println(baseUrl);
  }
}

void connectWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  show(F("Noi Wi-Fi..."));
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) delay(250);
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print(F("Wi-Fi OK, IP "));
    Serial.println(WiFi.localIP());
  }
}

void runCommands(JsonArray commands) {
  for (JsonObject cmd : commands) {
    String action = cmd["action"] | "";
    Serial.printf("Command %ld: %s\n", (long) (cmd["command_id"] | 0L), action.c_str());
    if (action == "UNLOCK") {
      bool physical = cmd["physical"] | true;   // an old server sends no flag: every slot is the real one
      if (doorOpen && physical) continue;       // already open
      String message = cmd["message"] | "Mo tu", slot = cmd["slot_code"] | "";
      int nl = message.indexOf('\n');           // "Mo tu\n(dien thoai)": line 1 gets the slot, line 2 keeps the source
      String second = nl >= 0 ? message.substring(nl + 1) : "";
      Serial.printf("  phase %s, physical %d\n", (const char*) (cmd["phase"] | "-"), physical);
      if (physical) openDoor(cmd["open_sec"] | 8, "Mo tu ngan " + slot + "\n" + second);
      else showSlotOk(slot, second);
    } else if (action == "DELETE_FP" && fingerOk) {
      int slot = cmd["sensor_slot"] | 0;
      if (slot > 0) Serial.printf("Delete finger %d -> %d\n", slot, finger.deleteModel(slot));
    } else if (action == "CANCEL_ENROLL" && mode != MODE_IDLE) {
      mode = MODE_IDLE;
      pinBuffer = "";
      show(F("Da huy dang ky"), 2000);
    }
  }
}

void heartbeatIfDue() {
  if (millis() - lastHeartbeat < heartbeatEveryMs) return;
  lastHeartbeat = millis();
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    return;
  }
  JsonDocument body, reply;
  body["firmware"] = FIRMWARE;
  body["uptime_sec"] = millis() / 1000;
  body["nfc"] = nfcOk;      // the server answers "tap_path" only to a box with a working tag
  bool wasOnline = isOnline();
  int code = postJson("/health", body, reply);
  if (code == 200) {
    lastGoodHeartbeat = millis();
    heartbeatFails = 0;
    heartbeatEveryMs = (uint32_t) (reply["interval_sec"] | 3) * 1000;
    runCommands(reply["commands"].as<JsonArray>());
    String path = reply["tap_path"] | "";
    if (path != tapPath) {
      tapPath = path;
      setTagUrl();
    }
  } else {
    if (code == 401) Serial.println(F("HTTP 401: DEVICE_API_KEY is wrong"));
    if (++heartbeatFails >= 5 && String(CONFIG_URL).length() > 0) {
      heartbeatFails = 0;
      loadBaseUrl();        // the tunnel may have a new address...
      setTagUrl();          // ...and the tag must point there
    }
  }
  if (wasOnline != isOnline() && mode == MODE_IDLE && !messageUntil) idleDrawn = false;
}

// ---------------------------------------------------------------- open and enroll

void showServerError(int code) {
  if (code == 401) show(F("Sai API key\n(xem secrets.h)"), 4000);
  else if (code <= 0) show(F("Khong goi duoc\nmay chu"), 3000);
  else show("Loi may chu\nHTTP " + String(code), 3000);
}

// One request decides: UNLOCK opens, CHOOSE asks A / B, CONFIRM_EMAIL waits for the e-mail, DENY shows the server's text.
// body: {"method":"PIN","pin":"482913"} | {"method":"CARD","card_uid":"04A1B2C3"} | {"method":"FINGERPRINT","sensor_slot":7}
void authorize(JsonDocument& body) {
  wake();
  if (!body["intent"].is<const char*>()) body["intent"] = "ASK";
  show(F("Dang kiem tra..."));
  JsonDocument reply;
  int code = postJson("/device/auth", body, reply);
  if (code != 200) {
    showServerError(code);
    return;
  }
  String message = reply["message"] | "", result = reply["result"] | "";
  if (result == "CHOOSE") {
    chooseBody = body;
    chooseSlot = reply["slot_code"] | "";
    int sec = reply["choose_sec"] | 0;
    chooseDeadline = millis() + (sec > 0 ? (uint32_t) sec * 1000 : CHOOSE_MS);
    mode = MODE_CHOOSE;
    pinBuffer = "";
    idleDrawn = false;      // drawIdle shows "A: Mo tu / B: Tra tu"
    Serial.printf("CHOOSE slot %s\n", chooseSlot.c_str());
  } else if (result == "CONFIRM_EMAIL") {
    // nothing opens now: the owner confirms from the e-mail, the UNLOCK then comes with a heartbeat like a phone open
    Serial.printf("CONFIRM_EMAIL slot %s\n", (const char*) (reply["slot_code"] | ""));
    show(message, 5000);
  } else if (result == "UNLOCK") {
    String phase = reply["phase"] | "";
    if (reply["physical"] | true) {
      openDoor(reply["open_sec"] | 8, message);   // CHECK_IN, ACCESS and PICKUP all release the bolt
    } else {                                      // the booking moved on at the server; this slot has no servo
      showSlotOk(reply["slot_code"] | "", phase == "PICKUP" ? "Da lay do" : phase == "ACCESS" ? "Da mo tu" : "Da gui do");
    }
  } else {
    Serial.print(F("DENY "));
    Serial.println(reply["reason"] | "");
    show(message, 3000);
  }
}

// The OK reply of an enroll call, or false after showing the error.
bool enrollCall(const char* path, JsonDocument& body, JsonDocument& reply) {
  int code = postJson(path, body, reply);
  if (code != 200) {
    showServerError(code);
    return false;
  }
  if (String(reply["result"] | "") == "OK") return true;
  show(reply["message"] | "Loi dang ky", 3000);
  return false;
}

// Waits for a finger image (want=true) or for the finger to leave (want=false); false on timeout or '*'.
bool waitFinger(bool want, uint32_t timeoutMs) {
  for (uint32_t start = millis(); millis() - start < timeoutMs; delay(50)) {
    uint8_t r = finger.getImage();
    if (want ? r == FINGERPRINT_OK : r == FINGERPRINT_NOFINGER) return true;
    if (keypad.getKey() == '*') return false;
  }
  return false;
}

// AS608 enroll into the sensor slot the server chose: two images -> one model -> stored.
bool captureFinger(int slot) {
  for (int pass = 1; pass <= 2; pass++) {
    show(pass == 1 ? F("Dat ngon tay\nlen cam bien") : F("Dat lai\ncung ngon tay"));
    if (!waitFinger(true, 15000) || finger.image2Tz(pass) != FINGERPRINT_OK) return false;
    show(F("Nhac ngon tay ra"));
    if (!waitFinger(false, 10000)) return false;
  }
  return finger.createModel() == FINGERPRINT_OK && finger.storeModel(slot) == FINGERPRINT_OK;
}

void startEnroll() {
  JsonDocument body, reply;
  body["type"] = enrollType;
  body["enroll_code"] = enrollCode;
  mode = MODE_IDLE;
  show(F("Kiem tra ma..."));
  if (!enrollCall("/device/enroll/start", body, reply)) return;
  if (enrollType == "CARD") {
    mode = MODE_ENROLL_CARD;
    enrollDeadline = millis() + CARD_ENROLL_MS;
    idleDrawn = false;
    return;
  }
  if (!fingerOk) {
    show(F("Khong thay AS608"), 3000);
    return;
  }
  int slot = reply["sensor_slot"] | 0;
  finger.deleteModel(slot);  // a slot the server hands out is free; clear what an old test left there
  if (!captureFinger(slot)) {
    show(F("Lay van tay loi\nBam C lam lai"), 3000);
    return;
  }
  body["sensor_slot"] = slot;   // the same type and code, plus the slot
  if (enrollCall("/device/enroll/finish", body, reply)) show(reply["message"] | "Dang ky xong", 3000);
  else finger.deleteModel(slot);
}

void finishCardEnroll(const String& uid) {
  mode = MODE_IDLE;
  JsonDocument body, reply;
  body["type"] = "CARD";
  body["enroll_code"] = enrollCode;
  body["card_uid"] = uid;
  if (enrollCall("/device/enroll/finish", body, reply)) show(reply["message"] | "Dang ky xong", 3000);
}

// ---------------------------------------------------------------- inputs

void endChoose() {
  mode = MODE_IDLE;
  chooseBody.clear();
  chooseSlot = "";
  idleDrawn = false;
}

void handleKeypad() {
  char key = keypad.getKey();
  if (!key) return;
  wake();
  messageUntil = 0;
  if (mode == MODE_CHOOSE) {   // A opens (the rental goes on), B returns the slot, * cancels; other keys wait
    if (key == '*') {
      endChoose();
      show(F("Da huy"), 1500);
    } else if (key == 'A' || key == 'B') {
      JsonDocument body = chooseBody;
      body["intent"] = key == 'A' ? "OPEN" : "CHECKOUT";
      endChoose();
      authorize(body);
    }
    return;
  }
  if (key == '*') {
    if (mode != MODE_IDLE) show(F("Da huy"), 1500);
    mode = MODE_IDLE;
    pinBuffer = "";
    idleDrawn = false;
  } else if (key == 'B' || key == 'C') {
    mode = MODE_ENROLL_CODE;
    enrollType = key == 'B' ? "CARD" : "FINGERPRINT";
    pinBuffer = "";
    idleDrawn = false;
  } else if (key == 'D') {
    show(WiFi.localIP().toString() + "\n" + (isOnline() ? "May chu OK" : "HTTP " + String(lastHttpCode)), 4000);
  } else if (key == '#') {
    if (pinBuffer.length() != 6) {
      show(F("Can du 6 so"), 1500);
    } else if (mode == MODE_ENROLL_CODE) {
      enrollCode = pinBuffer;
      pinBuffer = "";
      startEnroll();
    } else if (mode == MODE_IDLE) {
      JsonDocument body;
      body["method"] = "PIN";
      body["pin"] = pinBuffer;
      pinBuffer = "";
      authorize(body);
    }
  } else if (key >= '0' && key <= '9' && pinBuffer.length() < 6 && mode != MODE_ENROLL_CARD) {
    pinBuffer += key;
    idleDrawn = false;
  }
}

void handleFingerprint() {
  if (!fingerOk || mode != MODE_IDLE) return;
  if (millis() - lastFingerScan < 250 || !reached(fingerQuietUntil)) return;
  lastFingerScan = millis();
  uint8_t img = finger.getImage();
  if (fingerWaitLift) {
    if (img == FINGERPRINT_NOFINGER) fingerWaitLift = false;
    return;
  }
  if (img != FINGERPRINT_OK) return;
  fingerWaitLift = true;
  wake();
  fingerQuietUntil = millis() + 2500;
  if (finger.image2Tz() != FINGERPRINT_OK) {
    show(F("Khong doc duoc\nvan tay, thu lai"), 2000);
    return;
  }
  uint8_t r = finger.fingerFastSearch();
  if (r == FINGERPRINT_OK) {
    Serial.printf("Finger #%d (confidence %d)\n", finger.fingerID, finger.confidence);
    JsonDocument body;
    body["method"] = "FINGERPRINT";
    body["sensor_slot"] = finger.fingerID;
    authorize(body);
  } else if (r == FINGERPRINT_NOTFOUND) {
    show(F("Van tay chua\ndang ky"), 2500);   // read fine, but not on this sensor: nothing to send to the server
  } else {
    Serial.printf("Finger search error 0x%02X (ignored)\n", r);   // a sensor or wiring hiccup is not "unregistered"
    drawIdle();
  }
}

// Backlight on while someone is near; off SCREEN_OFF_MS after the last person and the last input.
void handleScreen() {
  if (!USE_SONAR) return;
  if (someoneWithin(NEAR_CM)) {
    lastActivity = millis();
    if (!screenOn) {
      setScreen(true);
      idleDrawn = false;
    }
  }
  bool busy = doorOpen || mode != MODE_IDLE || pinBuffer.length() > 0;
  if (screenOn && !busy && millis() - lastActivity >= SCREEN_OFF_MS) setScreen(false);
}

// ---------------------------------------------------------------- main

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println(F("\nSmartLocker online - LOCKER-01"));
  if (USE_SONAR) {
    pinMode(SONAR_TRIG, OUTPUT);
    pinMode(SONAR_ECHO, INPUT);
    digitalWrite(SONAR_TRIG, LOW);
  }
  ledcAttach(SERVO_BOLT_PIN, 50, 14);
  if (USE_DOOR_SERVO) {
    ledcAttach(SERVO_DOOR_PIN, 50, 14);
    servoWrite(SERVO_DOOR_PIN, DOOR_CLOSED_DEG);
    delay(350);
  }
  servoWrite(SERVO_BOLT_PIN, BOLT_LOCKED_DEG);
  delay(350);

  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.beginTransmission(LCD_ADDR);
  lcdOk = Wire.endTransmission() == 0;
  if (lcdOk) {
    lcd.init();
    lcd.backlight();
  } else {
    Serial.printf("LCD not found at 0x%02X: check SDA/SCL, or try 0x3F\n", LCD_ADDR);
  }
  show(F("SmartLocker\nKhoi dong..."));

  initNfc();
  if (USE_FINGERPRINT) {
    fingerSerial.begin(FP_BAUD, SERIAL_8N1, FP_RX_PIN, FP_TX_PIN);
    finger.begin(FP_BAUD);
    delay(100);
    fingerOk = finger.verifyPassword();
  }
  Serial.println(fingerOk ? F("AS608 OK") : F("AS608 off or not found: check V+, VA, TX->35, RX->15"));

  secureClient.setInsecure();   // demo: the tunnel certificate is not pinned
  server.setReuse(true);
  server.setTimeout(HTTP_TIMEOUT_MS);
  server.setConnectTimeout(HTTP_TIMEOUT_MS);
  connectWifi();
  loadBaseUrl();
  lastHeartbeat = millis() - heartbeatEveryMs;   // first heartbeat right away
  fingerQuietUntil = millis() + 3000;            // the first frames after power-up are noise, not a finger
  wake();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED && millis() - lastHeartbeat > 10000) connectWifi();
  heartbeatIfDue();
  sampleSonar();
  doorTick();
  if (mode == MODE_ENROLL_CARD && reached(enrollDeadline)) {
    mode = MODE_IDLE;
    show(F("Het thoi gian\nquet the"), 2000);
  }
  if (mode == MODE_CHOOSE && reached(chooseDeadline)) {
    endChoose();
    show(F("Het thoi gian\nchon, da huy"), 2000);
  }
  if (doorOpen) {
    if (keypad.getKey() == 'D') {   // while the door is open only D works: lock now
      wake();
      closeDoor();
    }
  } else {
    handleKeypad();
    handleFingerprint();
    nfcSlice();
  }
  handleScreen();
  if (messageUntil && reached(messageUntil)) {
    messageUntil = 0;
    idleDrawn = false;
  }
  if (!idleDrawn && !messageUntil && !doorOpen) drawIdle();
}
