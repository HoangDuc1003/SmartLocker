/*
 * SmartLocker - local hardware proof of concept (ESP32)
 *
 * Opens no network connection. A valid PIN, allowed RFID UID, or any
 * fingerprint template stored in the sensor prints CHECK-IN to Serial.
 * Verify the wiring and module voltage before powering the circuit.
 *
 * Arduino IDE libraries:
 *   - MFRC522 by GithubCommunity
 *   - Keypad by Mark Stanley / Alexander Brevig
 *   - Adafruit Fingerprint Sensor Library
 * Board package: esp32 by Espressif Systems
 */

#include <SPI.h>
#include <MFRC522.h>
#include <Keypad.h>
#include <Adafruit_Fingerprint.h>

// ---- ESP32 DevKit V1 sample pin map; change to match your board/wiring ----
// RC522 uses ESP32 VSPI: SCK=18, MISO=19, MOSI=23.
static constexpr uint8_t RFID_SS_PIN  = 21;
static constexpr uint8_t RFID_RST_PIN = 22;

// Keypad 4x4: four row wires, then four column wires.
byte rowPins[4] = {13, 14, 25, 26};
byte colPins[4] = {27, 32, 33, 4};
char keys[4][4] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};

// Fingerprint sensor UART. ESP32 RX2 (GPIO16) <- sensor TX;
// ESP32 TX2 (GPIO17) -> sensor RX.
static constexpr int FP_RX_PIN = 16;
static constexpr int FP_TX_PIN = 17;
static constexpr uint32_t FP_BAUD = 57600;

// Local demo PIN. Press # to submit, * to clear.
const char LOCAL_PIN[] = "1234";

// Replace with the UID printed in Serial Monitor when you scan your card.
// Hex digits only, uppercase/lowercase accepted. Example: "04A1B2C3".
const char* ALLOWED_CARD_UIDS[] = {"04A1B2C3"};
static constexpr size_t ALLOWED_CARD_COUNT = sizeof(ALLOWED_CARD_UIDS) / sizeof(ALLOWED_CARD_UIDS[0]);

MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, 4, 4);
HardwareSerial FingerSerial(2);
Adafruit_Fingerprint finger(&FingerSerial);

String pinBuffer;
uint32_t lastFingerScan = 0;
static constexpr uint32_t FINGER_SCAN_INTERVAL_MS = 250;

String cardUidToString(const MFRC522::Uid& uid) {
  String result;
  result.reserve(uid.size * 2);
  for (byte i = 0; i < uid.size; i++) {
    if (uid.uidByte[i] < 0x10) result += '0';
    result += String(uid.uidByte[i], HEX);
  }
  result.toUpperCase();
  return result;
}

bool cardIsAllowed(const String& uid) {
  for (size_t i = 0; i < ALLOWED_CARD_COUNT; i++) {
    String allowed = ALLOWED_CARD_UIDS[i];
    allowed.trim();
    allowed.toUpperCase();
    if (uid == allowed) return true;
  }
  return false;
}

void checkIn(const char* method, const String& identity) {
  Serial.println();
  Serial.println(F("===== CHECK-IN LOCAL: OK ====="));
  Serial.print(F("Phuong thuc: ")); Serial.println(method);
  Serial.print(F("Ma/ID: ")); Serial.println(identity);
  Serial.println(F("=============================="));
}

void deny(const char* method, const String& identity) {
  Serial.println();
  Serial.println(F("===== TU CHOI ====="));
  Serial.print(F("Phuong thuc: ")); Serial.println(method);
  Serial.print(F("Ma/ID: ")); Serial.println(identity);
  Serial.println(F("==================="));
}

void handleKeypad() {
  const char key = keypad.getKey();
  if (!key) return;

  if (key == '*') {
    pinBuffer = "";
    Serial.println(F("PIN da xoa."));
    return;
  }
  if (key == '#') {
    if (pinBuffer.length() == 0) {
      Serial.println(F("Nhap PIN truoc, sau do bam #."));
    } else if (pinBuffer == LOCAL_PIN) {
      checkIn("KEYPAD/PIN", pinBuffer);
    } else {
      deny("KEYPAD/PIN", pinBuffer);
    }
    pinBuffer = "";
    return;
  }
  if (key == 'A' || key == 'B' || key == 'C' || key == 'D') return;

  if (pinBuffer.length() < 8) {
    pinBuffer += key;
    Serial.print('*'); // Hide digits as they are entered.
  }
}

void handleRfid() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;

  const String uid = cardUidToString(rfid.uid);
  Serial.print(F("RFID UID: ")); Serial.println(uid);
  if (cardIsAllowed(uid)) checkIn("RFID", uid);
  else deny("RFID", uid);

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

void handleFingerprint() {
  if (millis() - lastFingerScan < FINGER_SCAN_INTERVAL_MS) return;
  lastFingerScan = millis();

  uint8_t result = finger.getImage();
  if (result == FINGERPRINT_NOFINGER) return;
  if (result != FINGERPRINT_OK) return;

  result = finger.image2Tz();
  if (result != FINGERPRINT_OK) {
    Serial.println(F("Van tay: khong doc duoc anh, thu lai."));
    return;
  }

  result = finger.fingerFastSearch();
  if (result == FINGERPRINT_OK) {
    const String id = String(finger.fingerID);
    checkIn("FINGERPRINT", id);
    Serial.print(F("Do khop: ")); Serial.println(finger.confidence);
  } else if (result == FINGERPRINT_NOTFOUND) {
    deny("FINGERPRINT", F("khong co mau da dang ky"));
  } else {
    Serial.println(F("Loi khi tim mau van tay."));
  }
}

void setup() {
  Serial.begin(9600);
  delay(500);
  Serial.println();
  Serial.println(F("SmartLocker LOCAL test - ESP32"));
  Serial.println(F("PIN demo: 1234, nhap tren keypad va bam #; bam * de xoa."));
  Serial.println(F("Quet the de xem UID; sua ALLOWED_CARD_UIDS de cho phep the."));

  SPI.begin(18, 19, 23, RFID_SS_PIN);
  rfid.PCD_Init();
  Serial.println(F("RC522 da khoi tao."));

  FingerSerial.begin(FP_BAUD, SERIAL_8N1, FP_RX_PIN, FP_TX_PIN);
  finger.begin(FP_BAUD);
  if (finger.verifyPassword()) {
    Serial.println(F("Cam bien van tay da ket noi."));
    if (finger.getTemplateCount() == FINGERPRINT_OK) {
      Serial.print(F("So mau van tay da luu trong cam bien: "));
      Serial.println(finger.templateCount);
    }
  } else {
    Serial.println(F("Khong thay cam bien van tay. Kiem tra nguon, TX/RX va baud."));
  }

  Serial.println(F("San sang. Mo Serial Monitor 9600 baud."));
}

void loop() {
  handleKeypad();
  handleRfid();
  handleFingerprint();
}
