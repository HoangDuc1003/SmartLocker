# Handoff: refactor (queue item 3)

## Goal
Clean and consistent codebase for grading (list in `docs/review/evaluation-vs-reference.md` §5), without changing behaviour
or the v2 device API contract, then prove nothing broke. Nothing committed.

## Done
1. **DB build path**: `run_demo_db.ps1` runs 01→07 and prints the `scripts/set-device-key.ps1` reminder; README documents the order.
2. **Dead material deleted** (grep showed no references): `docs/demo-code/`, `web/demo/` (+ `build/web/demo`), root `index.html`
   (redirected to the mock; gh-pages builds its own), `vercel.json`, `util/Todo.java`, `"/demo/"` public prefix in `SecurityFilter`,
   the mock mode and `window.LockerMap` preview hook in `locker-map.js`, `data-source` on `lockerMap.jsp`.
   Skeleton/assignment comments removed or reworded (SecurityUtils, DbContext, RuleEngine, TransferCheck, 13 "hint" lines that
   repeated the code, "Write it like LockerSlotDao" in 3 DAOs). `web/index.html` kept (welcome file → LoginController).
3. **Duplicates**: one `esc()` (`window.SmartLocker.esc` in `app.js`; `dashboard.js`, `locker-map.js` reuse it).
   `ApiJson` is the one JSON helper: `bodyOrEmpty()` + `COMPACT` used by `HealthApi`; `LockerSessionApi` uses `ApiJson.body/error/write`
   (400/500 now JSON `{"result":"ERROR","reason":"BAD_REQUEST"|"SERVER_ERROR",...}`, same status codes; a body without `sessions` was a 500, now 400).
   `DbContext.ping()` replaces the JDBC code in `HealthApi.doGet`. `DashboardApi` keeps its own Gson (ISO dates for the browser), commented.
4. **20 `confirm()` → `data-confirm`** (+ `data-confirm-danger` for delete/block/lock/reject/offline), same texts.
   `app.js` now also honours `data-confirm` on a single submit button (alert.jsp OFFLINE, remoteCommand.jsp).
   (The "23" in the web handoff included the 3 forms that already used `data-confirm`.)
5. **`sql/07_vietnamese_data.sql`** (BOM, re-runnable, only rewrites rows still holding the English seed text): plans, area names
   and locations, device locations, "Bank A/B" → "Dãy A/B", system account name, one ticket note. Applied. Plan lookups by
   name changed to `duration_min` in `02_sample_data.sql` and `06_demo_v2.sql`.
6. **SQL**: guarded duplicate `CREATE TABLE TopupRequest` removed from `04` (01 creates it); 04 header fixed. Run order in README.
   Procedures not rewritten.
7. **Tools** moved `src/java/tool/*` → `test/tool/*` (test source root: not in the WAR; NetBeans Run File still works).
   Old classes removed from `build/web/WEB-INF/classes/tool`. Command-line run documented in README.
8. **README.md, docs/SYSTEM_FLOWS.md** rewritten in Vietnamese, no emoji, no pool/LIVE/80% claims, current accounts, links to spec, deploy, postman.
   CLAUDE.md: 2 UI rules (data-confirm/esc, comment language) and 3 lessons.

## Verified
- Build + deploy after each group; smoke (`smoke.sh`) as admin, auditor1, v2pin: no 500 (only `k/NOPE` 404 by design).
- `sql/04`, `06`, `07` re-run without error, then `set-device-key.ps1`.
- `test_v2_setup.sql` + newman full collection: 123 requests, 248 assertions, 0 failures.
- Browser (127.0.0.1, own tab): map booking popup (shows "2 giờ") → booked CANT-A A02; "Tủ của tôi" shows it; kiosk PIN → CHECK_IN,
  then PICKUP; StoragePlan "Xóa" popup + Quay lại posts nothing; alert OFFLINE button popup; dashboard polls, no console errors.

## Open items
- Evaluation items not done (out of this scope): CHECK constraints (#7), full SQL consolidation (#6), `Web.sqlMessage` split (#9),
  `LockerMonitor`/`AuditVerifier` JDBC into DAOs (#12), pool/config (#13), `UserDao` split (#14), CSRF (#15), inline styles (#17).
- `01_schema.sql` still seeds English names (07 converts them); README account table must be updated by the accounts step (08).
- Git index: deletions are working-tree only (`git rm` not run); `test/tool/` is untracked.

## Files touched
`run_demo_db.ps1`, `README.md`, `docs/SYSTEM_FLOWS.md`, `CLAUDE.md`, `sql/02_sample_data.sql`, `sql/04_wallet_booking.sql`, `sql/06_demo_v2.sql`,
`sql/01_schema.sql` (one comment), new `sql/07_vietnamese_data.sql`; `src/java/api/{ApiJson,HealthApi,LockerSessionApi,DashboardApi}.java`,
`dao/{DbContext,AuditDao,DeviceDao,LockerAreaDao,LockerBankDao,LockerSlotDao,RemoteCommandDao,StoragePlanDao,UserDao}.java`,
`controller/LogoutController.java`, `filter/SecurityFilter.java`, `model/LockerBank.java`, `service/{RuleEngine,RiskScorer,Verdict}.java`,
`util/SecurityUtils.java`; `web/js/{app,dashboard,locker-map}.js`, `web/WEB-INF/views/{alert,calibration,deposit,lockerArea,lockerBank,lockerMap,lockerSlot,maintenance,remoteCommand,storagePlan,topup,user,userCard}.jsp`;
moved `src/java/tool/*` → `test/tool/*`; deleted `docs/demo-code/`, `web/demo/`, `index.html`, `vercel.json`, `src/java/util/Todo.java`.

## How to verify
Build as in `docs/handoff/orchestrator.md`, wait 15 s, run the scratchpad `smoke.sh` per user, then `sql/test_v2_setup.sql` and
`newman run docs/postman/SmartLocker-v2.postman_collection.json -e docs/postman/SmartLocker-local.postman_environment.json --env-var api_key=<LOCKER-01 key>`
(no heartbeat loop running).
