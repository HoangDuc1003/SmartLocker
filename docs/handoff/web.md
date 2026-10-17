# Handoff: web (Smart Locker v2, spec §5)

Stopped at a safe point because of the 300k-token budget per agent. All code compiles and is deployed to `build/web`. Nothing is half-applied.

## Goal
Spec §5:
1. Booking with an open method and a confirmation popup.
2. "Tủ của tôi" page.
3. One menu item, with redirects from the old pages.
4. Public page `/k/{device_code}`.

Then run E2E §6.2 scenarios 1–9 in the browser (UI plus device side via curl), at 375px and in both themes, and smoke-test for 500s.

## Done
- **Booking (map slot panel, `web/js/locker-map.js`)**
  - Plan select plus 3 radio buttons (Mật mã / Thẻ từ / Vân tay), each with its price. Card shows the 5% price with the old price struck through. Card shows "Cọc 30.000 đ lần đầu" when `card_deposit_due`. Fingerprint says whether the user is already enrolled on that box.
  - Button text "Đặt ngăn · <total>", disabled when total > balance.
  - Submitting opens an accessible popup (native `<dialog>`, `SmartLocker.confirm` in `js/app.js`) showing: slot, plan, method, price, card deposit, total, and "Giữ chỗ 15 phút; không đến sẽ mất 10%."
  - Cancel and remote-unlock confirms on the map also use this popup now; the map has no `window.confirm` left.
  - Bug found and fixed: the 10-second refresh re-rendered the panel while the popup was open, so OK did nothing. `askFirst` now sets `panelDirty` and checks `form.isConnected`.
  - My RESERVED slot shows a "Xem cách mở ở Tủ của tôi" button.
- **Map JSON**
  - `LockerMapDao`: `plans[].price_card` (from `util.Pricing`) and `banks[].device_code`.
  - `LockerMapApi` (non-staff only): `card_deposit_due`, `card_deposit`, `hold_min`, `fp_devices`.
- **"Tủ của tôi"**: `controller/MyLockerController` (BOOKING permission, mapped in `SecurityFilter`), `views/myLocker.jsp`, `js/my-locker.js`.
  - Open bookings:
    - slot, box, plan, amount paid, method, hold countdown, due time with countdown;
    - PIN masked behind "Hiện mật mã" (`aria-pressed`), plus a link to `/k/<box>`;
    - enroll code with steps ("Bấm B/C trên hộp rồi nhập mã") and an expiry countdown; "Lấy mã mới" once expired (POST `action=newEnrollCode`);
    - cancel (popup) or extend.
  - Cards: UID, status, deposit, box, "Báo mất thẻ" (posts to `MyCardController`, popup).
  - Fingerprints: box, sensor slot, delete (POST `action=deleteFingerprint`, popup).
  - History: last 20 rows; NO_SHOW rows show the 90% refund.
- **Redirects and menu**
  - `BookingController` GET and `MyCardController` GET now redirect to `MyLockerController`. Their POSTs come back to it too (`back=list`, `#cards`).
  - `nav.jspf` has one item, "Tủ của tôi" (`BOOKING:READ`, `activeNav=mylocker`). No new permission was needed, so there is no `sql/07`.
  - `views/booking.jsp` and `views/myCard.jsp` were deleted (dead code).
- **Kiosk**: `controller/KioskController` (`/k/*`), `views/kiosk.jsp`, `js/kiosk.js`.
  - No menu. Includes `theme.js`, `app.css` and a theme button; no CDN.
  - One input: `inputmode=numeric`, `autocomplete=one-time-code`, 6 digits.
  - Uses fetch to POST `/api/kiosk/unlock` and shows the server message in a `role=status` box (ok / bad / wait styles).
  - `retry_after_sec` locks the input with a "Thử lại sau m:ss" countdown, kept in `sessionStorage` across reloads.
  - Unknown box → 404 with "Không tìm thấy hộp tủ" text.
- CSS: new token-only blocks in `app.css`: `.dlg`, `.method-pick` / `.method-opt`, `.ml-*`, `.kiosk*`.

## Verified (browser, as v2pin at http://127.0.0.1:8080, dark theme)
- Map panel prices: PIN 5.000 đ, card 4.800 đ with the 30.000 đ deposit → total 34.800 đ.
- The popup content and confirming it reserved A01. The map showed "Đã đặt · của bạn" and the success flash.
- `/BookingController` redirects to "Tủ của tôi". PIN show/hide and the hold countdown work.
- curl: `/k/LOCKER-01` 200, `/k/NOPE` 404, `/k/` 404.

## Open items (next agent)
1. **Not yet run**:
   - E2E scenarios 1–9 through the UI (device side via curl);
   - the 375px check (iframe trick) and the light theme;
   - the smoke test of all pages as admin and end user;
   - kiosk wrong PIN / lockout in the browser;
   - the enroll flow on "Tủ của tôi" (CARD / FINGERPRINT).
2. **Environment hazards**:
   - Another agent ran Newman with the `v2*` accounts at the same time, so deposits on CANT-A A01 got mixed (ids 119/120 are theirs, 125 is mine; v2pin balance 185.000).
   - Use your own test users, or wait until Newman is idle.
   - Log in at `127.0.0.1` rather than `localhost` (separate cookie jar; the localhost session was lost once).
3. **LOCKER-01 key was rotated** by the backend agent: the key is in `config/device-keys.local.properties` (never commit it); `device-1-api-key` now gets 401. Heartbeat loop: `K=$(sed -n 's/^LOCKER-01=//p' config/device-keys.local.properties)`, then curl `/api/health` with `X-API-Key: $K` every 3 s.
4. `sql/test_v2_setup.sql` failed at the end with 50031: v2noshow has 3 no-shows, so booking is blocked. That file is the backend agent's to fix. For scenario 6, book with another user and set `hold_until` in the past with SQL.
5. The backend is changing phone lockout and PICKUP. Re-check that `js/kiosk.js` still reads `result`, `message` and `retry_after_sec` from `/api/kiosk/unlock`.
6. Other JSPs still use `onsubmit="return confirm(...)"` (23 places, out of §5 scope). They can switch to `data-confirm="..."`, which `app.js` already handles with the popup.
7. Add a lesson to `CLAUDE.md`: "A popup over a panel that auto-refreshes must freeze the panel (`panelDirty`), or OK submits a detached form."

## Files touched
- New:
  - `src/java/controller/MyLockerController.java`, `src/java/controller/KioskController.java`
  - `web/WEB-INF/views/myLocker.jsp`, `web/WEB-INF/views/kiosk.jsp`
  - `web/js/my-locker.js`, `web/js/kiosk.js`
  - this file
- Changed:
  - `src/java/controller/BookingController.java`, `src/java/controller/MyCardController.java`
  - `src/java/filter/SecurityFilter.java` (one line: `/MyLockerController` → BOOKING)
  - `src/java/api/LockerMapApi.java`, `src/java/dao/LockerMapDao.java`
  - `web/js/locker-map.js`, `web/js/app.js`, `web/css/app.css`
  - `web/WEB-INF/views/common/nav.jspf`, `web/WEB-INF/views/lockerMap.jsp`
- Deleted: `web/WEB-INF/views/booking.jsp`, `web/WEB-INF/views/myCard.jsp` (also from `build/web`).

## How to verify
1. Build as in `docs/handoff/orchestrator.md`. The script I used is in the scratchpad: javac all of `src/java` → `build/web/WEB-INF/classes`, `cp -r web/. build/web/`, touch `SmartLocker.xml`.
2. Start the LOCKER-01 heartbeat loop (item 3). Log in at `http://127.0.0.1:8080/SmartLocker` as an END_USER (password `123456`). Go to Sơ đồ tủ → Canteen → a free CANT-A slot. Choose a method, then "Đặt ngăn": the popup appears. Confirm, then open Tủ của tôi.
3. Phone: `http://127.0.0.1:8080/SmartLocker/k/LOCKER-01` with the PIN from Tủ của tôi → "Tủ đang mở…". The next heartbeat returns the UNLOCK command.

---

# Round 2 (second web agent, 17/10/2026): E2E, 375px, themes, smoke

## Done
- **Browser E2E** (claude-in-chrome at `http://127.0.0.1:8080`; device side by curl with the local LOCKER-01 key and a 3 s heartbeat loop). Accounts v2pin, v2card, v2fp; after each step checked the map, "Tủ của tôi", the wallet and audit.
  1. PIN: booked A01 from the map popup, then `auth` PIN twice. Map went RESERVED, then "Đang dùng · của bạn", then free. Audit has RESERVE, CHECK_IN and COMPLETE; history shows the row. PASS.
  2. Phone: one wrong PIN on `/k/LOCKER-01` ("Còn 4 lần thử"), then the right PIN. The next heartbeat carried UNLOCK `Mo tu
(dien thoai)` and the booking went ACTIVE (CHECK_IN on take). The phone PICKUP completed it. PASS.
  3. Card: price 4.800 đ was taken at booking (195.200). enroll/start + finish took 30.000 once (165.200); a repeat finish gives BAD_CODE and no second charge. UID shown on "Tủ của tôi". `auth` CARD twice gave CHECK_IN, then PICKUP. PASS.
  4. Fingerprint: enroll gave sensor_slot 2, then `auth` twice. The second booking needed no enroll ("Bạn đã đăng ký vân tay trên hộp này"). Re-enroll queued DELETE_FP for the old slot in the next heartbeat. Deleting in the UI queued DELETE_FP too. "Lấy mã mới" after expiry works. Extend (+30 min, 1/3) works. PASS after fix 2.
  5. Box: 5 wrong → 6th LOCKED_OUT. Phone page: 5 wrong → "Thử lại sau m:ss" countdown, kept after reload, unlocks itself after 2 min. The box counter is not affected by phone tries. PASS.
  6. No-show: hold_until moved back with SQL; LockerMonitor gave NO_SHOW, +4.500 (90%), history "hoàn 4.500 đ (giữ 10%)". PASS.
  7. Ended PIN → WRONG_CODE. 8. Card reported lost in the UI (popup) → CARD_BLOCKED. 9. Card on a PIN booking → METHOD_MISMATCH. PASS.
  - Kiosk with the heartbeat stopped for more than 10 s: "Hộp đang mất kết nối…" (DEVICE_OFFLINE). Cancel booking: popup, full refund. Audit chain verify: "Chuỗi băm toàn vẹn".
- **375px** (iframes) in light and dark: map panel, reserve form, confirm popup, "Tủ của tôi", kiosk (error state). No page-level horizontal scroll (the area strip scrolls by design). Desktop light and dark checked too. No console errors.
- **Smoke** (curl, `smoke.sh` in the scratchpad): every controller plus edit/new actions, `/api/*` and `/k/*`, as admin, auditor1 and v2pin. No 500s. End user gets 403 on staff pages, 302 on the old BookingController/MyCardController.
- **DataReplayer**: new `tool/DeviceKey` (system property `smartlocker.apiKey`, else `config/device-keys.local.properties`). It is used by both `DataReplayer` and `ScenarioSender`; checked that it loads the 48-char local key.
- **Newman** after the changes: test_v2_setup + newman, 123 requests, 248 assertions, 0 failures.

## Fixed in this round
1. Confirm popup for a first card booking said "Đặt và trả 34.800 đ", but only 4.800 is taken at booking (the deposit is taken at enroll). The OK button now shows the amount taken now, plus a "Trả ngay" row (`web/js/locker-map.js`).
2. Deleting a fingerprint while a FINGERPRINT booking on that box is open left the user with no way to open the box. `Fingerprint_Delete` (in `sql/06_demo_v2.sql`, BOM kept, applied to the DB) now gives that booking a new 10-minute enroll code. Retested in the UI: the code appears straight after "Xóa".
3. Phone lockout text said "hộp tạm khóa"; it is the phone counter only. It now says "trang này" (`kiosk.jsp`, `kiosk.js`).

## Open items
- Seed data shown to users is English: plan names ("2 hours", "Day pass"), bank names ("Bank A"), area descriptions ("Next to the canteen entrance"). This is data, not code. The refactor / accounts step could translate it in a BOM SQL script.
- The other 23 `onsubmit="return confirm(...)"` in staff JSPs (round 1, item 6) are still open.
- Tool quirk, not an app bug: after a Tomcat reload the claude-in-chrome form submit of the login page sent no request. Logging in with fetch POST in the page worked; curl login works.
- The extend action has no popup (it is free; v1 behaviour).

## Files touched (this round)
- `web/js/locker-map.js`, `web/js/kiosk.js`, `web/WEB-INF/views/kiosk.jsp`
- `sql/06_demo_v2.sql` (`Fingerprint_Delete`)
- `src/java/tool/DeviceKey.java` (new), `src/java/tool/DataReplayer.java`, `src/java/tool/ScenarioSender.java`
- `CLAUDE.md` (2 lessons), this file

## How to verify
- Build/deploy as in the orchestrator handoff. Run `sql/test_v2_setup.sql`. Start a heartbeat loop with the key from `config/device-keys.local.properties`.
- Fix 2: log in as v2fp and book with Vân tay. Enroll at the box (`/api/device/enroll/start` + `finish`), then on "Tủ của tôi" press Xóa → a new "Mã đăng ký vân tay" appears and the next heartbeat carries DELETE_FP.
- Newman: `newman run docs/postman/SmartLocker-v2.postman_collection.json -e docs/postman/SmartLocker-local.postman_environment.json --env-var api_key=<key>` gives 0 failures. Stop any heartbeat loop first, because it would take the commands Postman expects.
