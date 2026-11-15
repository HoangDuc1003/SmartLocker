# SmartLocker Demo Script

Approximately 20 minutes, following the full lifecycle of a locker rental and then transitioning to staff administration. Each scene specifies **Action**, **Script / Narration**, and **Expected Result**.
Default password for all demo accounts: `123456`.

## 0. Preparation (Before Demo)

| Item | Command / Procedure |
|---|---|
| Clean DB Initialization | `powershell -ExecutionPolicy Bypass -File .\run_demo_db.ps1` or `run_demo_db.bat` |
| Link Physical Box to Bank | Edit top 4 variables in `sql/demo_box.sql` (default bank `LIB-A`, servo slot `A01`) and execute |
| Build & Run Web App | `sh scripts/build-dev.sh`, wait 15 s, open `http://localhost:8080/SmartLocker/` |
| ESP32 Hardware Box | Power on, press `D` on keypad: LCD displays server connection OK. On Locker Banks page, `LOCKER-01` shows ACTIVE |
| Web Browsers | Open 2 windows: Normal window (User) and Incognito window (Staff). Hard reload once with `Ctrl+Shift+R` |
| Mobile Phone | On same Wi-Fi network or via tunnel (`docs/deploy.md`), logged in as `student10` |
| Wallet Balance (`student10`) | At least 20,000 VND (if depleted: perform Scene 5 first) |

During the live demo, avoid re-running `build-dev.sh` and modifying `SmartLocker.xml`, as Tomcat context reloads will terminate active user sessions.

## Scene 1. Visitor Explores Campus Map (1 min)

- **Action:** Open homepage while unauthenticated, click "Find lockers near me", zoom into a campus area, select a locker bank.
- **Script:** The map is the main entry point; visitors can explore availability without creating an account. Covers 5 campus zones across VNU-HCM, auto-refreshing every 10 seconds. Leaflet assets are bundled locally in the repository, maintaining full map and grid functionality even if external Internet is offline.
- **Expected Result:** Available, occupied, and overdue slots are color-coded; banks managed by offline boxes are clearly disabled for new bookings.

## Scene 2. Seamless In-Place Authentication (30 s)

- **Action:** Click "Book slot" while unauthenticated; a modal dialog appears; log in as `student10`.
- **Script:** No jarring page redirects—the user stays right in their booking context, and navigation updates asynchronously without reloading the page.

## Scene 3. Booking a Slot (2 min)

- **Action:** Select an available Size S slot in the bank where the physical box is deployed. Review options: 2 hours / 4 hours / Day pass / Custom; switch to sizes M and L to display size-adjusted rates. Select 2-hour plan, choose **PIN** access method, and click Book.
- **Script:** Modal displays upfront charge, projected balance, and cancellation refund policy. A 10,000 VND buffer is preserved for potential late fees. Pricing calculations are executed atomically in database stored procedures, preventing race conditions via `UPDLOCK, HOLDLOCK`.
- **Expected Result:** "My Locker" displays the 6-digit PIN, a 15-minute hold countdown, and a Cancel button with refund percentage (100% within the first 5 minutes).

## Scene 4. Hardware Unlocking at the ESP32 Box (3 min)

1. Enter PIN + `#` on keypad -> solenoid opens, LCD displays CHECK_IN. On the web, booking transitions to ACTIVE and the usage timer starts.
2. Enter PIN again -> LCD prompts `A: Open slot / B: Check out`. Press `A` -> door opens, booking stays ACTIVE, access count increments.
3. Save key `B` for the conclusion of Scene 6.

- **Script:** The ESP32 device makes no local authorization decisions; it relays raw credentials to `/api/device/auth` with a unique box HMAC key. The server stores only SHA-256 hashes of device keys.
- **Optional Extensions:**
  - RFID Card: `student1` holds a pre-registered card on `LOCKER-01`.
  - Optical Fingerprint: `student3` has enrolled fingerprint stored at sensor slot 1.
  - Brute-force lockout: 5 consecutive failed attempts lock that channel for 120 seconds.

**Phone NFC Tap / QR Code:** On a logged-in smartphone, scan the box QR code or tap the NFC tag -> navigates to `/k/LOCKER-01` -> tap "Open my locker". Ephemeral tap tokens refresh every 60 seconds and are strictly single-use.

## Scene 5. Wallet Top-Up and Staff Approval (2 min)

- **Action (User):** Top-up -> enter amount -> VietQR payment code displays, request remains in PENDING status.
- **Action (Incognito Window, `operator1`):** Top-up Requests -> click Approve.
- **Expected Result:** `student10`'s balance updates on the next navigation or balance poll.

## Scene 6. Extensions, Overdue Storage, and Debt Settlement (3 min)

1. Under My Locker, click **Extend** for 1 hour (up to 3 times, priced at standard hourly rate for the slot size).
2. Simulate overdue without waiting: edit `sql/test_overdue.sql` (`@username = N'student10'`, `@minutes_late = 130`, `@balance = 5000`) and execute:
   ```cmd
   sqlcmd -S localhost -U sa -P 12345 -I -b -f 65001 -i sql\test_overdue.sql
   ```
3. Within 15 seconds: slot locks, late fee assessed for 3 hours, wallet reflects negative balance. My Locker indicates overdue status and outstanding debt.
4. Entering PIN at the box is rejected with `OVERDUE_UNPAID`, and LCD shows the debt amount.
5. Top up and approve to restore positive balance; enter PIN and press `B` -> PICKUP event, booking marked COMPLETED, slot returns to AVAILABLE.

- **Script:** Overdue slots are not automatically freed because personal belongings remain stored inside. The background monitoring daemon locks the slot and manages fee escalation.
- **Variant:** `@minutes_late = 2890` (>48 hours) triggers an `OVERDUE_ESCALATED` alert for staff intervention.

## Scene 7. Operator Dashboard and Anomaly Alerts (3 min, `admin`)

- **Action:** Dashboard: view slot occupancy, zone utilization, device health, hourly rental trends, and 7-day revenue.
- Inject simulated sensor telemetry with faults and spoofing indicators:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts\send-demo.ps1 -Count 5 -Fault -Bad
  ```
- **Expected Result:**
  - Sensor Telemetry: view incoming sessions with sorting and filtering.
  - Alerts: `SENSOR_FAULT`, `SUSPECTED_SPOOF` populated with cryptographic evidence.
- **Script:** Priority-ordered `RuleEngine` handles primary threat detection; Weka ML classifier assigns secondary risk scores. `/api/dashboard` queries an in-memory snapshot updated every 2 seconds to eliminate database polling bottlenecks.

## Scene 8. Device Offline Detection (1 min)

- **Action:** Disconnect power from the ESP32 box, wait ~90 seconds.
- **Expected Result:** `LOCKER-01` status switches to OFFLINE, `DEVICE_OFFLINE` alert triggers, and its locker bank is disabled on the map. Reconnecting power restores ACTIVE status.

## Scene 9. Staff Operations & Maintenance (2 min)

- **`operator1`:** Remote unlock solenoid slot (`A01` per `demo_box.sql`; box executes command on next heartbeat, solenoid fires); view Sessions; report lost RFID card.
- **`tech1`:** Open alert -> generate Maintenance Ticket; Calibration management.
- **Script:** Role-based access control is enforced by `SecurityFilter` on the server, not merely hidden in client-side HTML.

## Scene 10. Cryptographic Audit Chain & Permissions (1 min)

- **`auditor1`:** Audit Log -> verify SHA-256 hash chain integrity: valid. Every action from earlier scenes is permanently recorded.
- **`admin`:** Roles & Permissions: toggle granular permissions per role.
- **`locked1`:** Login rejected (account suspended).

## Conclusion & Verification Summary

- **Automated Tests:** TestNG 83/83 passing tests across 14 classes.
- **API Tests:** Postman / Newman 241 requests, 514 assertions, 0 failures.
- **Browser Compatibility:** Verified across desktop and mobile browsers.

## Troubleshooting Reference

| Issue | Resolution |
|---|---|
| Hardware box disconnected | Select an emulation bank (e.g. `CANT-B`) and unlock via mobile interface `/k/...` using PIN |
| Offline map tiles | Local grid fallback is enabled automatically; proceed with pinned slots |
| 404 immediately after build | Tomcat is reloading application context; wait 15 seconds and refresh |
| Login popup autofills `admin` | Triple-click input field to select all, then enter desired username |
| `test_overdue.sql` reports no ACTIVE booking | Perform initial check-in first (Scene 4, Step 1) |
| Post-demo cleanup | Run `sql/test_cleanup.sql` or re-initialize via `run_demo_db.bat` |
