/*
 * SmartLocker - online box LOCKER-01 (ESP32 DevKit, ESP32 core 3.x)
 * Hardware: LCD 1602 I2C, 2 servos (bolt + door), SRF05, keypad 4x4, PN532 (NFC), AS608.
 *
 * The box never decides on its own: every PIN, card and finger goes to the web (POST /api/device/auth), and the box
 * opens only on "UNLOCK". A heartbeat every 3 s (POST /api/health) keeps LOCKER-01 ONLINE and brings the commands queued
 * by the web: UNLOCK (phone tap, phone page, staff), DELETE_FP.
 *
 * v7, one PN532 (I2C mode, on the bus of the LCD) does two jobs in turns, one short slice per loop():
 *  - it reads RFID cards (readPassiveTargetID); a UID goes to /api/device/auth like before. A phone with an HCE wallet
 *    answers this poll with a random 4-byte UID starting 0x08: those are ignored silently, or a tap would count as an
 *    unknown card towards the 5-try lockout.
 *  - it emulates an NFC Type 4 tag holding one URL record: base URL + "tap_path" of the heartbeat reply, e.g.
 *    .../SmartLocker/k/LOCKER-01?n=Ab3dEf7hJk2m. The token changes every minute and after each use, so the tag is
 *    rewritten when the path changes. A phone that taps the box opens that page; the signed-in owner presses
 *    "Mo tu cua toi" and the UNLOCK comes with the next heartbeat. The box never sees who the phone belongs to.
 * No emulation while a PIN is typed or a card is being enrolled.
 *
 * Keypad:  0-9 PIN (6 digits)   # send   * clear / cancel
 *          B  enroll a card     C  enroll a finger   (then the 6-digit enroll code from "Tu cua toi", #)
 *          D  door closed: show IP / server status;  door open: lock now
 *          A / B after "A: Mo tu / B: Tra tu": open the rented slot / return it
 *
 * Open many times (v6): every auth goes with "intent":"ASK". A rented slot answers CHOOSE and the LCD shows
 * "A: Mo tu" / "B: Tra tu"; the box keeps the PIN / card UID / finger slot it just read and sends the same auth
 * again with "intent":"OPEN" (UNLOCK phase ACCESS, the rental goes on) or "CHECKOUT" (PICKUP, the rental ends).
 * '*' or CHOOSE_MS without a key cancels. An older server ignores the intent and answers PICKUP as before.
 *
 * One box serves every slot of the banks it manages, but only one compartment has the servos: an UNLOCK with
 * "physical":false (another slot, see sql/demo_box.sql) only shows "Ngan A07 OK" on the LCD. A reply without
 * "physical" (an older server) means every slot is the real one.
 *
 * After an unlock the bolt servo releases (and the door servo opens, if fitted). The user locks it with D;
 * a door left open locks by itself after DOOR_OPEN_MS. The SRF05 only drives the LCD backlight: on while
 * someone is near, off SCREEN_OFF_MS after the last person and the last input.
 *
 * Arduino IDE libraries: Keypad, Adafruit Fingerprint Sensor Library, ArduinoJson 7, LiquidCrystal I2C (Frank de
 * Brabander), and PN532-Arduino of Seeed-Studio (github.com/Seeed-Studio/PN532: PN532, PN532_I2C, EmulateTag). The NDEF
 * record of the tag is built here, so no NDEF library is needed. Servos use the ESP32 LEDC, no library.
 * Copy secrets.example.h to secrets.h first.
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

static const char FIRMWARE[] = "4.1-esp32";

// ---- Pin map of the box ----
// PN532 in I2C mode (switches I0=1, I1=0) on SDA 21 / SCL 22 next to the LCD; it answers at 0x24, the LCD at 0x27.
static constexpr bool USE_NFC = true;           // false: no cards and no tag; phones open only through the /k page (QR) or staff
static constexpr uint16_t NFC_LISTEN_MS = 5;    // an emulation slice waits this long for a phone. The library polls the PN532 over I2C
                                                // many times per timeout, so a turn really blocks the loop about 10x longer than this: keep it small
static constexpr uint16_t CARD_POLL_MS = 30;    // a card slice waits this long for a card
byte rowPins[4] = {13, 14, 25, 26};             // R1..R4
byte colPins[4] = {33, 19, 23, 27};             // C1..C4
static constexpr int FP_RX_PIN = 35;            // ESP32 <- AS608 TX
static constexpr int FP_TX_PIN = 15;            // ESP32 -> AS608 RX
static constexpr uint32_t FP_BAUD = 57600;
static constexpr bool USE_FINGERPRINT = true;   // false: skip the AS608 (e.g. while it is faulty)
static constexpr int I2C_SDA = 21;
static constexpr int I2C_SCL = 22;
static constexpr uint8_t LCD_ADDR = 0x27;       // some 1602 backpacks use 0x3F
static constexpr int SERVO_BOLT_PIN = 32;
static constexpr int SERVO_DOOR_PIN = 2;        // boot strap pin: keep the signal wire plugged in only after upload
static constexpr int BOLT_LOCKED_DEG = 0;
static constexpr int BOLT_UNLOCKED_DEG = 85;
static constexpr int DOOR_CLOSED_DEG = 0;
static constexpr int DOOR_OPEN_DEG = 180;
static constexpr bool USE_DOOR_SERVO = false;   // false: only the bolt servo moves, GPIO2 stays untouched (no door servo fitted)
static constexpr bool USE_SONAR = true;         // false: the backlight stays on (the SRF05 only drives the backlight)
static constexpr int SONAR_TRIG = 5;
static constexpr int SONAR_ECHO = 18;           // through the 1k / 2k divider (SRF05 echo is 5 V)

static constexpr int NEAR_CM = 50;              // someone in front of the box wakes the backlight
static constexpr uint32_t DOOR_OPEN_MS = 20000; // a door nobody locks with D locks by itself after this
static constexpr uint32_t SCREEN_OFF_MS = 60000;    // backlight off this long after the last person and input
static constexpr uint32_t ONLINE_MS = 10000;    // no good heartbeat for this long: "mat ket noi"
static constexpr uint32_t CHOOSE_MS = 15000;    // A / B after a CHOOSE reply; the server's choose_sec wins when sent
static constexpr uint16_t HTTP_TIMEOUT_MS = 6000;

char keys[4][4] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};

PN532_I2C pn532i2c(Wire);
PN532 reader(pn532i2c);       // the card role
EmulateTag nfc(pn532i2c);     // the tag role
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, 4, 4);
HardwareSerial FingerSerial(2);
Adafruit_Fingerprint finger(&FingerSerial);
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);

enum Mode { MODE_IDLE, MODE_ENROLL_CODE, MODE_ENROLL_CARD, MODE_CHOOSE };
Mode mode = MODE_IDLE;
JsonDocument chooseBody;    // the auth that answered CHOOSE, sent again with OPEN or CHECKOUT
String chooseSlot;
uint32_t chooseDeadline = 0;
String enrollType;          // "CARD" or "FINGERPRINT" while an enrollment runs
String enrollCode;
uint32_t enrollDeadline = 0;

String baseUrl;             // e.g. http://192.168.1.10:8080/SmartLocker
String pinBuffer;
bool fingerOk = false;
bool lcdOk = false;
uint32_t heartbeatEveryMs = 3000;
uint32_t lastHeartbeat = 0;
uint32_t lastGoodHeartbeat = 0;
uint8_t heartbeatFails = 0;
int lastHttpCode = 0;

bool doorOpen = false;
uint32_t holdUntil = 0;     // the door locks by itself at this time unless D locks it first
uint32_t lastDoorDraw = 0;
uint32_t messageUntil = 0;  // a result stays on screen until then, then the idle screen comes back
bool idleDrawn = false;

uint32_t lastFingerScan = 0;
uint32_t fingerQuietUntil = 0;
bool fingerWaitLift = true;   // read again only after the sensor saw no finger (a stuck or ghost image never repeats)
String lastCardUid;
uint32_t lastCardAt = 0;
bool nfcOk = false;
String tapPath;             // "/k/LOCKER-01?n=..." from the last heartbeat; empty: no tag is emulated
uint8_t ndefBuf[128];       // the encoded NDEF message (EmulateTag copies it; NDEF_MAX_LENGTH is 128 there too)

bool screenOn = true;
uint32_t lastActivity = 0;  // last key, card, finger, tap, message, or person seen by the SRF05
uint32_t lastSonar = 0;
long lastCm = -1;

// ---------------------------------------------------------------- screen (LCD 1602: 2 lines of 16)

bool isOnline() {
  return WiFi.status() == WL_CONNECTED && lastGoodHeartbeat != 0 && millis() - lastGoodHeartbeat < ONLINE_MS;
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

// '\n' starts the second line; each line is cut to 16 characters.
void show(const String& text, uint32_t holdMs = 0) {
  Serial.print(F("[LCD] ")); Serial.println(text);
  messageUntil = holdMs ? millis() + holdMs : 0;
  idleDrawn = false;
  if (!lcdOk) return;
  int nl = text.indexOf('\n');
  String l1 = nl < 0 ? text : text.substring(0, nl);
  String l2 = nl < 0 ? "" : text.substring(nl + 1);
  l1 = l1.substring(0, 16);
  l2 = l2.substring(0, 16);
  while (l1.length() < 16) l1 += ' ';       // overwrite the old text without lcd.clear() flicker
  while (l2.length() < 16) l2 += ' ';
  lcd.setCursor(0, 0);
  lcd.print(l1);
  lcd.setCursor(0, 1);
  lcd.print(l2);
}

void drawIdle() {
  if (mode == MODE_ENROLL_CODE) {
    show(String(enrollType == "CARD" ? "Ma DK the:" : "Ma DK van tay:") + "\n" + pinBuffer + "_");
  } else if (mode == MODE_ENROLL_CARD) {
    show(F("Quet the dang ky\n(* de huy)"));
  } else if (mode == MODE_CHOOSE) {
    show("A: Mo tu  * huy\nB: Tra tu " + chooseSlot);
  } else if (pinBuffer.length() > 0) {
    String stars;
    for (size_t i = 0; i < pinBuffer.length(); i++) stars += '*';
    show("PIN: " + stars + "\n# gui  * xoa");
  } else if (!isOnline()) {
    show(WiFi.status() == WL_CONNECTED ? F("Mat ket noi\nDang thu lai...") : F("Mat Wi-Fi\nDang noi lai..."));
  } else {
    show(F("PIN + # / van tay\nthe / cham NFC"));
  }
  idleDrawn = true;
}

// ---------------------------------------------------------------- PN532: cards and the NFC tag for the phone tap

void initNfc() {
  if (!USE_NFC) return;
  nfc.setTagWriteable(false);           // a phone may read the tag, never change it
  static uint8_t uid[3] = {0x53, 0x4C, 0x01};  // "SL", box 1; static: EmulateTag keeps the pointer and reads it later
  nfc.setUid(uid);
  nfcOk = nfc.init();
  if (nfcOk) reader.setPassiveActivationRetries(0x01);   // one try per slice, or a poll blocks the keypad
  Serial.println(nfcOk ? F("PN532 OK (cards + tag)") : F("PN532 not found: I2C switches, SDA 21 / SCL 22, 0x24"));
}

// Writes base URL + tapPath into the tag. Called when the heartbeat brings another path or the base URL moved.
void setTagUrl() {
  if (!nfcOk || tapPath.isEmpty()) return;
  String url = baseUrl + tapPath;
  // one NDEF short record: MB+ME+SR+well-known, type length 1, payload length, type "U", URI code 0 (no prefix), the URL
  int size = 5 + url.length();
  if (size > (int) sizeof(ndefBuf) - 2) {   // EmulateTag keeps 2 bytes of its 128 for the length
    Serial.printf("Tag URL too long (%d bytes): %s\n", size, url.c_str());
    return;
  }
  ndefBuf[0] = 0xD1;
  ndefBuf[1] = 1;
  ndefBuf[2] = url.length() + 1;
  ndefBuf[3] = 'U';
  ndefBuf[4] = 0x00;
  memcpy(ndefBuf + 5, url.c_str(), url.length());
  nfc.setNdefFile(ndefBuf, size);
  Serial.print(F("NFC tag: ")); Serial.println(url);
}

// True when this loop may give its slice to the tag: never while a PIN is typed or a card is being enrolled.
bool canEmulate() {
  return nfcOk && !tapPath.isEmpty() && mode == MODE_IDLE && pinBuffer.length() == 0;
}

// Lets a phone read the tag for NFC_LISTEN_MS. The phone opens the link itself; the box only shows that it was read.
void emulateSlice() {
  reader.SAMConfig();       // back from the reader role
  if (nfc.emulate(NFC_LISTEN_MS)) {
    wake();
    show(F("Da gui lien ket\nXem dien thoai"), 3000);
    Serial.println(F("NFC tag read by a phone"));
  }
}

// ---------------------------------------------------------------- sonar

long readDistanceCm() {
  digitalWrite(SONAR_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(SONAR_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(SONAR_TRIG, LOW);
  long us = pulseIn(SONAR_ECHO, HIGH, 25000);   // 25 ms ~ 4 m
  long cm = us / 58;
  return (us == 0 || cm < 2) ? -1 : cm;
}

void sampleSonar() {
  if (!USE_SONAR || millis() - lastSonar < 150) return;
  lastSonar = millis();
  lastCm = readDistanceCm();
}

bool personNear() {
  return USE_SONAR && lastCm > 0 && lastCm <= NEAR_CM;
}

// ---------------------------------------------------------------- bolt and door

void servoWrite(int pin, int deg) {
  // 50 Hz, 14-bit duty: 500 us (0 deg) .. 2400 us (180 deg) out of 20000 us
  uint32_t us = 500 + (uint32_t) deg * 1900 / 180;
  ledcWrite(pin, us * 16383 / 20000);
}

void openDoor(int seconds, const String& message) {
  wake();
  show(message, 3000);
  servoWrite(SERVO_BOLT_PIN, BOLT_UNLOCKED_DEG);   // release the bolt first, then push the door
  delay(1000);
  if (USE_DOOR_SERVO) {
    servoWrite(SERVO_DOOR_PIN, DOOR_OPEN_DEG);
    delay(500);
  }
  doorOpen = true;
  // the server's open_sec only makes the door stay open longer than DOOR_OPEN_MS, never shorter
  uint32_t openMs = seconds > 0 ? (uint32_t) seconds * 1000 : 0;
  holdUntil = millis() + (openMs > DOOR_OPEN_MS ? openMs : DOOR_OPEN_MS);
  lastDoorDraw = 0;
}

// A slot without a servo: the server already moved the booking on, the LCD only confirms it.
void showSlotOk(const String& slotCode, const String& second) {
  wake();
  show("Ngan " + slotCode + " OK\n" + second, 3000);
  Serial.printf("Slot %s OK (no servo)\n", slotCode.c_str());
}

void closeDoor() {
  if (USE_DOOR_SERVO) {
    servoWrite(SERVO_DOOR_PIN, DOOR_CLOSED_DEG);   // door first, then the bolt
    delay(1500);
  }
  servoWrite(SERVO_BOLT_PIN, BOLT_LOCKED_DEG);
  delay(500);
  doorOpen = false;
  if (USE_NFC) {            // a servo current dip can reset the PN532: start it again with the same tag
    initNfc();
    setTagUrl();
  }
  wake();
  show(F("Da khoa cua"), 1500);
  Serial.println(F("Door closed"));
}

// The door stays open until D locks it (handleKeypadDoorOpen) or the timeout locks it here.
void doorTick() {
  if (!doorOpen) return;
  uint32_t now = millis();
  if ((int32_t) (now - holdUntil) >= 0) {
    closeDoor();
    return;
  }
  if (messageUntil == 0 && now - lastDoorDraw >= 1000) {
    lastDoorDraw = now;
    long left = max(0L, (long) (int32_t) (holdUntil - now));
    show("Bam D de khoa\nTu khoa sau " + String((left + 999) / 1000) + "s");
  }
}

// ---------------------------------------------------------------- network

bool startsWithHttps(const String& url) {
  return url.startsWith("https://");
}

// POST {path} with the device key. Returns the HTTP code (<= 0: no connection) and fills reply.
int postJson(const char* path, const JsonDocument& body, JsonDocument& reply) {
  if (WiFi.status() != WL_CONNECTED || baseUrl.isEmpty()) return -1;
  String url = baseUrl + "/api" + path;
  String payload;
  serializeJson(body, payload);
  WiFiClient plain;
  WiFiClientSecure secure;
  secure.setInsecure();     // demo: the tunnel certificate is not pinned
  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.setConnectTimeout(HTTP_TIMEOUT_MS);
  if (!http.begin(startsWithHttps(url) ? (WiFiClient&) secure : plain, url)) return -1;
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", DEVICE_API_KEY);
  int code = http.POST(payload);
  if (code > 0) {
    String text = http.getString();
    reply.clear();
    deserializeJson(reply, text);
    if (code != 200) {
      Serial.printf("POST %s -> HTTP %d %s\n", path, code, text.c_str());
    }
  } else {
    Serial.printf("POST %s -> %s\n", path, http.errorToString(code).c_str());
  }
  http.end();
  lastHttpCode = code;
  return code;
}

// Mode 2: read base_url from CONFIG_URL (the fixed link on GitHub Pages points at the current tunnel).
void loadBaseUrl() {
  String configUrl = CONFIG_URL;
  if (configUrl.isEmpty()) {
    baseUrl = SERVER_BASE;
    return;
  }
  WiFiClientSecure secure;
  secure.setInsecure();
  HTTPClient http;
  http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
  http.setTimeout(HTTP_TIMEOUT_MS);
  // a query string skips the GitHub Pages cache after the tunnel moved
  if (http.begin(secure, configUrl + "?t=" + String(millis())) && http.GET() == 200) {
    JsonDocument doc;
    if (!deserializeJson(doc, http.getString()) && doc["base_url"].is<const char*>()) {
      baseUrl = doc["base_url"].as<String>();
      while (baseUrl.endsWith("/")) baseUrl.remove(baseUrl.length() - 1);
    }
  }
  http.end();
  if (baseUrl.isEmpty()) baseUrl = SERVER_BASE;
  Serial.print(F("Server: ")); Serial.println(baseUrl);
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
    Serial.print(F("Wi-Fi OK, IP ")); Serial.println(WiFi.localIP());
  }
}

void runCommands(JsonArray commands) {
  for (JsonObject cmd : commands) {
    String action = cmd["action"] | "";
    Serial.printf("Command %ld: %s\n", (long) (cmd["command_id"] | 0L), action.c_str());
    bool physical = cmd["physical"] | true;           // an old server sends no flag: every slot is the real one
    if (action == "UNLOCK" && (!doorOpen || !physical)) {
      // server text is "Mo tu\n(dien thoai)": line 1 gets the slot, line 2 keeps the source
      String m = cmd["message"] | "Mo tu";
      int nl = m.indexOf('\n');
      String second = nl >= 0 ? m.substring(nl + 1) : "";
      String slot = cmd["slot_code"] | "";
      // a phone ACCESS (v6) or CHECK_IN opens like a keypad one; PICKUP too, the server already ended the rental
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
  body["nfc"] = nfcOk;      // v7: the server answers "tap_path" only to a box with a working tag
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
      loadBaseUrl();        // the tunnel may have a new address
      setTagUrl();          // and the tag must point there
    }
  }
  if (wasOnline != isOnline() && mode == MODE_IDLE && messageUntil == 0) idleDrawn = false;
}

// ---------------------------------------------------------------- open and enroll

void showServerError(int code) {
  if (code == 401) show(F("Sai API key\n(xem secrets.h)"), 4000);
  else if (code <= 0) show(F("Khong goi duoc\nmay chu"), 3000);
  else show("Loi may chu\nHTTP " + String(code), 3000);
}

// One request decides: UNLOCK opens the door, CHOOSE asks A / B, DENY shows the reason the server wrote for the screen.
// body: {"method":"PIN","pin":"482913"} | {"method":"CARD","card_uid":"04A1B2C3"} | {"method":"FINGERPRINT","sensor_slot":7}
// A body without "intent" goes as ASK; the A / B keys send the kept body again with OPEN or CHECKOUT.
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
  String message = reply["message"] | "";
  String result = reply["result"] | "";
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
      openDoor(reply["open_sec"] | 8, message);   // CHECK_IN, ACCESS and PICKUP all release the bolt; D locks it again
    } else {   // the booking moved on at the server; this slot has no servo
      showSlotOk(reply["slot_code"] | "", phase == "PICKUP" ? "Da lay do" : phase == "ACCESS" ? "Da mo tu" : "Da gui do");
    }
  } else {
    Serial.print(F("DENY ")); Serial.println(reply["reason"] | "");
    show(message, 3000);
  }
}

// Returns the OK reply, or shows the error and returns false.
bool enrollCall(const char* path, JsonDocument& body, JsonDocument& reply) {
  int code = postJson(path, body, reply);
  if (code != 200) {
    showServerError(code);
    return false;
  }
  if (String(reply["result"] | "") != "OK") {
    show(reply["message"] | "Loi dang ky", 3000);
    return false;
  }
  return true;
}

// Waits for a finger image (want=true) or for the finger to leave (want=false); false on timeout or '*'.
bool waitFinger(bool want, uint32_t timeoutMs) {
  uint32_t start = millis();
  while (millis() - start < timeoutMs) {
    uint8_t r = finger.getImage();
    if (want ? r == FINGERPRINT_OK : r == FINGERPRINT_NOFINGER) return true;
    if (keypad.getKey() == '*') return false;
    delay(50);
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
    enrollDeadline = millis() + 30000;
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
  JsonDocument fin;
  fin["type"] = "FINGERPRINT";
  fin["enroll_code"] = enrollCode;
  fin["sensor_slot"] = slot;
  if (enrollCall("/device/enroll/finish", fin, reply)) {
    show(reply["message"] | "Dang ky xong", 3000);
  } else {
    finger.deleteModel(slot);
  }
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

// While the door is open only D works: lock now.
void handleKeypadDoorOpen() {
  char key = keypad.getKey();
  if (key != 'D') return;
  wake();
  closeDoor();
}

// A rented slot answered CHOOSE: A opens (the rental goes on), B returns the slot, * cancels. Other keys wait.
void endChoose() {
  mode = MODE_IDLE;
  chooseBody.clear();
  chooseSlot = "";
  idleDrawn = false;
}

void handleChooseKey(char key) {
  if (key == '*') {
    endChoose();
    show(F("Da huy"), 1500);
  } else if (key == 'A' || key == 'B') {
    JsonDocument body = chooseBody;
    body["intent"] = key == 'A' ? "OPEN" : "CHECKOUT";
    endChoose();
    authorize(body);
  }
}

void handleKeypad() {
  char key = keypad.getKey();
  if (!key) return;
  wake();
  messageUntil = 0;
  if (mode == MODE_CHOOSE) {
    handleChooseKey(key);
    return;
  }
  if (key == '*') {
    if (mode != MODE_IDLE) show(F("Da huy"), 1500);
    mode = MODE_IDLE;
    pinBuffer = "";
    idleDrawn = false;
    return;
  }
  if (key == 'B' || key == 'C') {
    mode = MODE_ENROLL_CODE;
    enrollType = key == 'B' ? "CARD" : "FINGERPRINT";
    pinBuffer = "";
    idleDrawn = false;
    return;
  }
  if (key == 'D') {
    show(WiFi.localIP().toString() + "\n" + (isOnline() ? "May chu OK" : "HTTP " + String(lastHttpCode)), 4000);
    return;
  }
  if (key == '#') {
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
    return;
  }
  if (key >= '0' && key <= '9' && pinBuffer.length() < 6 && mode != MODE_ENROLL_CARD) {
    pinBuffer += key;
    idleDrawn = false;
  }
}

String cardUidToString(const uint8_t* uid, uint8_t size) {
  String result;
  for (uint8_t i = 0; i < size; i++) {
    if (uid[i] < 0x10) result += '0';
    result += String(uid[i], HEX);
  }
  result.toUpperCase();
  return result;
}

// One short poll for a card. A UID goes to the enrollment that waits for it, or to the server as an open.
void cardSlice() {
  if (!nfcOk || (mode != MODE_IDLE && mode != MODE_ENROLL_CARD)) return;
  reader.SAMConfig();       // back from the tag role
  uint8_t uid[10];
  uint8_t size = 0;
  if (!reader.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &size, CARD_POLL_MS)) return;
  // ISO 14443: a 4-byte UID starting 0x08 is random, which is what a phone with an HCE wallet sends. It is no card:
  // nothing on screen, nothing to the server, or a phone tap counts as UNKNOWN_CARD towards the 5-try lockout.
  if (size == 4 && uid[0] == 0x08) return;
  String text = cardUidToString(uid, size);
  if (text == lastCardUid && millis() - lastCardAt < 1500) {   // the same card still on the reader
    lastCardAt = millis();
    return;
  }
  lastCardUid = text;
  lastCardAt = millis();
  Serial.print(F("Card UID: ")); Serial.println(text);
  wake();
  if (mode == MODE_ENROLL_CARD) {
    finishCardEnroll(text);
  } else {
    JsonDocument body;
    body["method"] = "CARD";
    body["card_uid"] = text;
    authorize(body);
  }
  lastCardAt = millis();    // the debounce counts from the end of the HTTP call, or a card still held is sent again
}

// One PN532 job per loop(), so the keypad stays responsive: the card poll and the tag take turns.
void nfcSlice() {
  static bool tagTurn = false;
  tagTurn = !tagTurn;
  if (tagTurn && canEmulate()) emulateSlice();
  else cardSlice();
}

void handleFingerprint() {
  if (!fingerOk || mode != MODE_IDLE) return;
  if (millis() - lastFingerScan < 250 || (int32_t) (millis() - fingerQuietUntil) < 0) return;
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
  if (personNear()) {
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
    FingerSerial.begin(FP_BAUD, SERIAL_8N1, FP_RX_PIN, FP_TX_PIN);
    finger.begin(FP_BAUD);
    delay(100);
    fingerOk = finger.verifyPassword();
  }
  Serial.println(fingerOk ? F("AS608 OK") : F("AS608 off or not found: check V+, VA, TX->35, RX->15"));

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
  if (mode == MODE_ENROLL_CARD && (int32_t) (millis() - enrollDeadline) >= 0) {
    mode = MODE_IDLE;
    show(F("Het thoi gian\nquet the"), 2000);
  }
  if (mode == MODE_CHOOSE && (int32_t) (millis() - chooseDeadline) >= 0) {
    endChoose();
    show(F("Het thoi gian\nchon, da huy"), 2000);
  }
  if (doorOpen) {
    handleKeypadDoorOpen();
  } else {
    handleKeypad();
    handleFingerprint();
    nfcSlice();
  }
  handleScreen();
  if (messageUntil && (int32_t) (millis() - messageUntil) >= 0) {
    messageUntil = 0;
    idleDrawn = false;
  }
  if (!idleDrawn && messageUntil == 0 && !doorOpen) drawIdle();
}
