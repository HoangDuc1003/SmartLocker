# SmartLocker — notes for agents

Java 8 Servlet/JSP (MVC2) on Tomcat 9 + SQL Server. NetBeans project, no build tool on PATH.
Dev server: Tomcat at `E:/apache-tomcat-9.0.113`, app at `http://localhost:8080/SmartLocker`
(deployed from `build/web`). Demo accounts use password `123456` (see README).

## UI rules
- One stylesheet: `web/css/app.css` (light + dark tokens). Pages must work offline: no CDN scripts
  (Tailwind, Google Fonts...) and no inline color styles; use the classes/tokens in `app.css`.
- Every page includes `js/theme.js` in `<head>` (sets the theme before paint) and `common/nav.jspf`
  right after `<body>`.
- All visible text is Vietnamese; technical codes (slot code, RFID UID, status enum) stay as is.
- No emoji as icons; inline SVG only. No fake "LIVE"/status indicators that are not backed by data.
- Confirm before a POST with `data-confirm="..."` (on the form, or on one submit button) handled by `js/app.js`; never `confirm()`.
  Pages build HTML with `window.SmartLocker.esc` from `app.js` (load `app.js` first); no local copies.
- Code comments in English; UI text and submitted docs (README, SYSTEM_FLOWS) in Vietnamese.

## Working process
- Test end-to-end in the user's browser (claude-in-chrome): every button, component and backend API it calls; loop fix → retest until it passes.
- After a change, other agents cross-review it and feed findings back; loop until the reviews pass.
- When about 50k tokens of context are left, each agent writes a handoff to `docs/handoff/<agent>.md`
  (goal, done, open items, files touched, how to verify) and the orchestrator starts one new session per handoff.

## Lessons — mistakes agents made here (one line each, add new ones at the bottom)
- A form must post exactly the parameter names its controller reads (the emergency modal sent `deviceCode`, the controller reads `slotId`).
- Always close JDBC connections with try-with-resources; `DbContext` has no pool (`HealthApi.doGet` leaked one per poll).
- Never fake device heartbeats for all devices in `LockerMonitor`; it disables offline detection.
- SQL seed files with Vietnamese text must keep the UTF-8 BOM (SSMS reads them as ANSI otherwise).
- Do not query the DB inside `/api/dashboard`; it is served from the `LockerMonitor` snapshot cache.
- Print user/device data in JSP with `<c:out>`; in JS build HTML only through `esc()`.
- A global dark theme in `nav.jspf` broke every light page; change the theme through `app.css` tokens only.
- Tomcat's DefaultServlet reads static files with the Windows charset and re-encodes them to UTF-8 (mojibake in `js/*.js`); keep `fileEncoding=UTF-8` in `web.xml`.
- The DB stores UTC (`SYSUTCDATETIME`); print times with `<ui:dt>` and parse zone-less API strings as UTC in JS, never raw `${x.createdAt}`.
- A stale browser cache hid a CSS/JS redeploy; verify UI changes after a hard reload (Ctrl+Shift+R).
- T-SQL `EXEC proc` arguments must be variables or constants, never expressions such as `CASE` (03_v2_v3.sql failed once).
- Every failed guess at a box (WRONG_CODE, UNKNOWN_CARD, UNKNOWN_FINGER, BAD_CODE) counts toward its 5-try lockout; run `sql/test_setup.sql` before Postman, and do not add guessing steps before scenario 5.
- An auto-refreshing panel (locker map, 10 s) replaced the form behind an open popup, so its OK did nothing; freeze the refresh while a popup is open.
- Removing a credential (finger, card) must re-offer enrollment to the open booking that uses it, or the user is locked out of their own slot.
- A confirm button must show the amount taken now, not a total that includes money taken later (card deposit is charged at the box).
- From Git Bash, `sqlcmd -i /tmp/x.sql` fails with "Access is denied"; put the file in the scratchpad (or the repo) and pass that path.
- After touching `SmartLocker.xml`, wait about 15 s before smoke tests; requests during the reload return 404 and look like broken pages.
- Look plans up by `duration_min`, not by `plan_name`: `03_v2_v3.sql` renames the seed plans.
- Every money/time rule of v3 lives in `AppConfig`/`SlotSize` (sql/03_v2_v3.sql) and `util.Pricing` mirrors the SQL; change both and run `PricingDatabaseIntegrationTest`.
- An overdue booking stays `ACTIVE` with `locked_at`; never free or complete it from a clock job (the slot still holds the user's things).
- A procedure that checks a row and then changes it must read it `WITH (UPDLOCK, HOLDLOCK)` inside the transaction (Deposit_Extend was checked outside and could charge twice).
- `XACT_ABORT ON` + `THROW` rolls back the caller's transaction too; never wrap a test that expects an error in an outer `BEGIN TRAN ... ROLLBACK`.
- Always run `sqlcmd -I` (filtered indexes need QUOTED_IDENTIFIER ON).
- JSTL `fmt` follows the browser's Accept-Language; the locale is fixed to `vi_VN` in web.xml, do not remove it.
- A popup must freeze every redraw of the form it confirms, including a fetch that started before it opened and a countdown that would remove the form.
- A user-supplied address (e-mail) is saved only after a code sent to it comes back; JSESSIONID is SameSite=Lax, keep it in both context files.
- Long-running Tomcat started from a Claude background shell can be killed for low memory; start it in its own window (`startup.bat`).
- Postman steps that pick a free slot must pick size S: prices depend on the size now.
- Leaflet is vendored in `web/js/vendor/leaflet` (no CDN); OpenStreetMap tiles need the Internet, so the map must still show the pins over a plain grid and a note when they fail.
- Tomcat reloads the context when a class changes and the session is lost: log in again before the next browser test.
- Aggregate numbers for charts (per hour, per day, revenue) go to `/api/dashboard/stats` (cached 60 s), never into `/api/dashboard`; send revenue to ADMIN and OPERATOR only.
- A donut drawn with `r` + half the stroke wider than the viewBox is clipped; keep `r + stroke/2 <= viewBox/2`.
- The map page and `/api/locker-map` are open to visitors (GET only, `SecurityFilter.GUEST_PATHS`, perms = `MAP:READ`, role `GUEST` in the page); every POST and every other page stays behind the login. The login/sign-up popup asks for JSON (`Accept: application/json`) and the page swaps the menu without a reload.
- A bank without a device (`device_id NULL`, e.g. DOMB) is OFFLINE in `v_LockerSlotMap` and `Deposit_Reserve` refuses it; the map JSON sends `device_status: "NONE"`, never a default `ACTIVE`.
- Staff edits of a booking (`DepositDao.update/insert`) must keep the slot consistent: walk-ins only on an AVAILABLE slot, closing frees the slot, a closed booking is never reopened; an admin slot override never cancels an ACTIVE booking.
- `SecurityFilter` reloads the session user on every request (status, role, balance); a LOCKED account is signed out at once.
- Browser autofill pre-fills the login popup with `admin`: select the field (triple-click) before typing in E2E tests.
- Run the TestNG suite with `sh scripts/test.sh`; `testng`/`jcommander`/`slf4j` are test-only and stay out of `WEB-INF/lib`.
- Python `open(path, 'w')` on some repo files fails with `Errno 22` (OneDrive); write in place with `open(path, 'r+')` + `truncate()`.
