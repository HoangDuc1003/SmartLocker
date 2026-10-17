# Handoff: backend (Smart Locker v2)

## Goal
Spec `docs/spec/smart-locker-v2.md` §3 (SQL), §4 (device API v2), pricing rules, §6.1 Postman, §6.2 run at API level.

## Done (all verified against the running Tomcat, 17/10/2026)
- `sql/06_demo_v2.sql` (UTF-8 BOM, re-runnable; ran twice without error):
  - `Deposit` + `open_method` (default PIN), `pin_code`, `enroll_code`, `enroll_expires`; filtered unique indexes on PIN and enroll code of open bookings.
  - New tables `Fingerprint`, `AuthAttempt`. `UserCard` + `deposit_amount`, `registered_device_id`.
  - `RemoteCommand.slot_id` now NULL-able, + `sensor_slot`, `source` (STAFF/PHONE/SYSTEM). `LockerSession.open_source` widened to 12 (FINGERPRINT).
  - "Demo 2 minutes" `is_active = 0`. operator1..4 ACTIVE on LIB, DOMA, CANT, GYM; the other 17 operators DISABLED (none deleted); `control_owner` of disabled operators cleared.
  - **LOCKER-01 is now the CANT-A box** (Q14): the seed had it on LIB-A, so device rows 1 and 5 swapped `device_code`, key hash and firmware. LOCKER-01 = device_id 5, key `device-1-api-key`; LOCKER-05 = device_id 1 (LIB-A), key `device-5-api-key`. LOCKER-01 profile `"demo":false` (no fake heartbeat).
  - Demo credentials on LOCKER-01: student1's card `04A1B2C3` marked registered; student3 fingerprint in sensor slot 1. Replace the UID / enroll template 1 on the real AS608 for a live demo.
  - Procedures: `fn_OpenPrice`, `Code_NewSix`, `Deposit_Reserve` (5th param `@open_method`, default PIN), `Deposit_ExpireNoShow` (90% back, CEILING 10% kept), `RemoteCommand_TakePending` (LEFT JOIN, sensor_slot, source), `Auth_LockCheck`, `Auth_Log`, `Device_Authorize`, `Enroll_Find`, `Enroll_Start`, `Enroll_Finish`, `Enroll_NewCode`, `Fingerprint_Delete`.
- Java: `api/DeviceAuthApi` (`/api/device/auth`), `api/DeviceEnrollApi` (`/api/device/enroll/start|finish`), `api/KioskApi` (`/api/kiosk/unlock`, public), `api/MyLockerApi` (`/api/my-locker`, BOOKING), `api/ApiJson`, `dao/DeviceAuthDao`, `service/AuthText` (OLED ASCII + Vietnamese phone texts), `util/Pricing`. Heartbeat v2 in `HealthApi` (interval_sec 3, commands with open_sec/message/sensor_slot, server_time, v1 keys kept, firmware saved). `LockerSessionApi` no longer completes bookings. `SecurityFilter`: device paths, public `/k`, `/k/*`, `/api/kiosk/unlock`, JSON 401. `RuleEngine`/`SessionContextDao`: PHONE opens need a valid command like REMOTE. `BookingController` reads `openMethod` (default PIN). `Web.sqlMessage`: Vietnamese for THROW 50041..50045.
- Postman: `docs/postman/SmartLocker-v2.postman_collection.json` (v2.1), local + tunnel environments, `docs/postman/README.md`. Test accounts: `sql/test_v2_setup.sql`.
- Newman run (installed globally with npm on this machine): **110 requests, 225 assertions, 0 failures**, ~2 min 17 s (scenario 5 waits 122 s).
- ScenarioSender remote, spoof, sensor still work (STAFF_OPEN, SUSPECTED_SPOOF, SENSOR_FAULT). Test noise cleaned (alerts 15-17 resolved, slot CANT-A A01 back to AVAILABLE).
- Smoke: all 18 controllers + `/api/dashboard`, `/api/locker-map`, `/api/health`, `/api/my-locker` return 200 as admin; end-user pages 200.

## For the web agent
- `GET /api/my-locker` (JSON): `balance`, `card_deposit_due`, `booking` {deposit_id, status, slot_code, bank_code, device_code, open_method, pin_code, enroll_code, enroll_expires, hold_until, due_at, paid_amount...}, `cards` [{card_id, card_uid, status, deposit_amount, registered_device, registered}], `fingerprints` [{fp_id, device_code, sensor_slot}], `plans` [{price_pin, price_card, price_fingerprint}], `history` (NO_SHOW rows have `refund`). POST `action=newEnrollCode&depositId=` and `action=deleteFingerprint&fpId=` (409 + Vietnamese message on a business error).
- Reserve form: add `openMethod` = PIN | CARD | FINGERPRINT to the existing BookingController POST.
- Java helpers: `DepositDao.findOpenByUser`, `DepositDao.newEnrollCode`, `DeviceAuthDao.findDeviceByCode` (for `/k/{device_code}`), `cardsOf`, `fingerprintsOf`, `hasRegisteredCard`, `deleteFingerprint`; `util.Pricing.priceFor`, `noShowRefund`, `CARD_DEPOSIT`.
- A `/k/*` servlet has servlet path `/k`; both `/k` and `/k/` are public in SecurityFilter.
- **LOCKER-01 is not faked any more**: without the ESP32 it goes OFFLINE after 90 s and CANT-A cannot be booked. Keep it alive while testing:
  `while true; do curl -s -H "X-API-Key: device-1-api-key" -H "Content-Type: application/json" -d '{"firmware":"2.0"}' http://localhost:8080/SmartLocker/api/health >/dev/null; sleep 3; done`

## Spec deviations (and why)
- PIN is generated only for PIN bookings; CARD/FINGERPRINT bookings get an enroll code when needed (§4.6 "mật mã hoặc mã đăng ký"; a PIN on a card booking would make METHOD_MISMATCH meaningless).
- Lockout counts only guesses (WRONG_CODE, UNKNOWN_CARD, UNKNOWN_FINGER, BAD_CODE), not CARD_BLOCKED/METHOD_MISMATCH/NO_BOOKING (valid credentials). The counter restarts when a lockout starts. The 5th wrong try answers WRONG_CODE with `attempts_left 0, retry_after_sec 120`; the 6th answers LOCKED_OUT. Enroll calls obey the same lockout.
- A card "counts" (no deposit due) only when enrolled at a box (`registered_device_id`) or with a deposit; old seeded cards do not. Reserving with CARD while the deposit is due needs price + 30,000 in the wallet (THROW 50041); the 30,000 is taken at `enroll/finish`.
- Extra reasons: `DEVICE_OFFLINE` (kiosk when the box is not ACTIVE), `BAD_SLOT`, `BAD_UID` (enroll), `BAD_REQUEST` (400), `BAD_API_KEY` (401), `UNKNOWN_DEVICE` (404 on kiosk).
- Kiosk changes the booking state at once (CHECK_IN/PICKUP) and queues the UNLOCK; it does not wait for the box.
- OLED text for a phone command is `Mo tu\n(dien thoai)` (spec example has 18 chars on one line).

## Open items
- `CANCEL_ENROLL`: the heartbeat delivers any queued action, but nothing queues CANCEL_ENROLL yet (server does not know when the box is in enroll mode).
- `sql/03_scenarios.sql` / `05` re-run would restore v1 `Deposit_Reserve` / `Deposit_ExpireNoShow`; run `06` after them.
- Booking flash says the PIN is on "Tủ của tôi", which the web agent still has to build.
- The tunnel environment has `REPLACE-ME` in `base_url` (deploy agent / script).

## How to verify
1. `sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -b -f 65001 -i sql/06_demo_v2.sql` (twice: no error).
2. Build/deploy as in `docs/handoff/orchestrator.md`.
3. `sqlcmd ... -i sql/test_v2_setup.sql`, then `newman run docs/postman/SmartLocker-v2.postman_collection.json -e docs/postman/SmartLocker-local.postman_environment.json` -> 0 failures.

Exact examples that pass (key `device-1-api-key`):
```
POST /api/health {"firmware":"2.0","uptime_sec":5}
 -> {"interval_sec":3,"commands":[],"server_time":"2026-10-17 09:03:51","blocked_cards":[...],"reserved":[]}
POST /api/device/auth {"method":"PIN","pin":"933821"}
 -> {"result":"UNLOCK","phase":"CHECK_IN","deposit_id":95,"slot_code":"A01","open_sec":8,"message":"Moi cat do\nNgan A01"}
 -> (again) {"result":"UNLOCK","phase":"PICKUP",...,"message":"Moi lay do\nNgan A01"}
POST /api/device/auth {"method":"CARD","card_uid":"<uid of v2card>"} on a PIN booking
 -> {"result":"DENY","reason":"METHOD_MISMATCH","attempts_left":4,"retry_after_sec":0,"message":"Sai cach mo\nHay nhap ma PIN"}
POST /api/device/enroll/start {"type":"FINGERPRINT","enroll_code":"854414"} -> {"result":"OK","sensor_slot":2,"message":"Dat ngon tay\n2 lan"}
POST /api/device/enroll/finish {"type":"CARD","enroll_code":"558718","card_uid":"34FF8687"} -> {"result":"OK","message":"Dang ky xong"}
POST /api/kiosk/unlock {"device_code":"LOCKER-01","pin":"512038"}
 -> {"result":"UNLOCK","phase":"CHECK_IN","deposit_id":96,"slot_code":"A01","open_sec":8,"message":"Tủ đang mở. Mời cất đồ vào ngăn A01.","command_id":10}
 then heartbeat -> "commands":[{"command_id":10,"action":"UNLOCK","slot_code":"A01","open_sec":8,"message":"Mo tu\n(dien thoai)"}]
6th wrong PIN -> {"result":"DENY","reason":"LOCKED_OUT","attempts_left":0,"retry_after_sec":120,"message":"Tam khoa\nCho 120 giay"}
Wrong key -> 401 {"result":"ERROR","reason":"BAD_API_KEY",...}; body not JSON -> 400 {"result":"ERROR","reason":"BAD_REQUEST",...}
```

## Files touched
New: `sql/06_demo_v2.sql`, `sql/test_v2_setup.sql`, `src/java/api/{ApiJson,DeviceAuthApi,DeviceEnrollApi,KioskApi,MyLockerApi}.java`, `src/java/dao/DeviceAuthDao.java`, `src/java/service/AuthText.java`, `src/java/util/Pricing.java`, `docs/postman/*`, this file.
Changed: `src/java/api/HealthApi.java`, `src/java/api/LockerSessionApi.java`, `src/java/controller/BookingController.java`, `src/java/dao/DepositDao.java`, `src/java/dao/DeviceDao.java` (setFirmware), `src/java/dao/RemoteCommandDao.java`, `src/java/dao/SessionContextDao.java`, `src/java/filter/SecurityFilter.java`, `src/java/model/Deposit.java`, `src/java/service/RuleEngine.java`, `src/java/util/Web.java`, `CLAUDE.md` (2 lessons).

## Review fixes (round 2)
All 8 are done. Build OK. `06_demo_v2.sql` re-ran twice with no error. Ran `test_v2_setup.sql` + newman twice in a row: run 1 had 3 failures, all in scenario 7, where the slot picked (A02) did not match the booking (A01). This was most likely the web agent using v2pin/CANT-A at the same moment. Run 2: 123 requests, 248 assertions, 0 failures. Smoke test: pages 200. `BookingController` and `MyCardController` answer 302, which is now the web agent's redirect.
1. Audit chain: `AuditVerifier` hashes a NULL actor or object_id as "", the same as SQL CONCAT. 06 no longer passes NULL (uses object id 0). `AuditController?action=verify` as admin: "Chuỗi băm toàn vẹn".
2. `test_v2_setup.sql` moves older v2noshow NO_SHOWs back 8 days before booking a new one. Two runs in a row both pass scenario 6.
3. LOCKER-01 key rotated by `scripts/set-device-key.ps1`. The key is in `config/device-keys.local.properties` (git-ignored, already created on this machine). The DB keeps only its SHA-256. Old key returns 401, new key 200. Postman environments have the placeholder `PASTE-LOCKER-01-KEY`; run newman with `--env-var api_key=<key>`. `ScenarioSender` reads `-Dsmartlocker.apiKey` or the file. **`DataReplayer.java` still hard-codes device-1-api-key (open).** `docs/deploy.md` has a short key section. **Spec change for the orchestrator:** a fresh 06 run sets the hash back to device-1-api-key; run the script afterwards.
4. **Spec change:** there are now two lockout counters per box. BOX covers keypad, card, finger and enroll; PHONE covers `/api/kiosk/unlock`. LOCK_START markers have method `LOCK` / `LOCK_PHONE`, and COUNTER_RESET clears both. Postman scenario 5 checks both counters.
5. A phone open refuses with DEVICE_OFFLINE unless the box was seen within the last 10 s. It only queues an UNLOCK (with `RemoteCommand.deposit_id` and `phase`). CHECK_IN or PICKUP happens in `RemoteCommand_TakePending` when the box takes the command. A stale command (booking cancelled or already opened at the keypad) is set EXPIRED instead of being sent. A repeated phone try reuses the pending command. Postman scenario 2 covers this. Phone texts now say "Hộp sẽ mở trong vài giây".
6. `Device_Authorize` reads Deposit WITH (UPDLOCK, HOLDLOCK), and TakePending takes the same per-device applock.
7. `Enroll_Finish` queues DELETE_FP for the replaced finger. Sensor slots with a pending DELETE_FP are not handed out again (applies to `Enroll_Start` and `Enroll_Finish`).
8. The outdated spec URL note is removed from `docs/deploy.md`.
Not tested by Postman: DEVICE_OFFLINE on the kiosk (needs more than 10 s without a heartbeat) and DELETE_FP after a re-enroll.
Postman collection generator (not in the repo): edit the JSON directly.
