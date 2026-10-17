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
- T-SQL `EXEC proc` arguments must be variables or constants, never expressions such as `CASE` (06_demo_v2.sql failed once).
- Every failed guess at a box (WRONG_CODE, UNKNOWN_CARD, UNKNOWN_FINGER, BAD_CODE) counts toward its 5-try lockout; run `sql/test_v2_setup.sql` before Postman, and do not add guessing steps before scenario 5.
- An auto-refreshing panel (locker map, 10 s) replaced the form behind an open popup, so its OK did nothing; freeze the refresh while a popup is open.
- Removing a credential (finger, card) must re-offer enrollment to the open booking that uses it, or the user is locked out of their own slot.
- A confirm button must show the amount taken now, not a total that includes money taken later (card deposit is charged at the box).
- From Git Bash, `sqlcmd -i /tmp/x.sql` fails with "Access is denied"; put the file in the scratchpad (or the repo) and pass that path.
- After touching `SmartLocker.xml`, wait about 15 s before smoke tests; requests during the reload return 404 and look like broken pages.
- Look plans up by `duration_min`, not by `plan_name`: `07_vietnamese_data.sql` renames the seed plans.
