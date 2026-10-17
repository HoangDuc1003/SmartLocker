# Orchestrator handoff: Smart Locker v2

Goal: implement `docs/spec/smart-locker-v2.md` (approved 17/10/2026). Read it and `CLAUDE.md` before any work.

## Workstreams

| Agent | Scope (spec section) | Depends on | Handoff file |
|---|---|---|---|
| backend | §3 SQL `sql/06_demo_v2.sql`; §4 APIs (`/api/device/auth`, `/api/device/enroll/start`, `/api/device/enroll/finish`, heartbeat v2, `/api/kiosk/unlock`, SecurityFilter); §6.1 Postman collection and environments in `docs/postman/`; run the 10 scenarios of §6.2 at API level | none | `docs/handoff/backend.md` |
| deploy | §7: `gh-pages` content (index.html, k/LOCKER-01/index.html, config.json) built by `scripts/update-tunnel-link.ps1`, `docs/deploy.md`. **Never push**: pushing to GitHub needs the user's approval; the script does the push when the user runs it. | none | `docs/handoff/deploy.md` |
| web | §5: booking method choice and confirm popup, "Tủ của tôi" (`MyLockerController`), redirects of the old pages, menu, public page `/k/{device_code}`; E2E in the browser of the 10 scenarios | backend | `docs/handoff/web.md` |
| reviewer | Cross-review every workstream against spec, `CLAUDE.md` rules and lessons; report findings only | each workstream | in its reply |

## Queue (user requests 17/10/2026), in this order
1. **Evaluation** against the reference project https://github.com/TrongBVD/Pouring-System (scored 10/10 in this course): read-only report `docs/review/evaluation-vs-reference.md`. Runs now, in parallel.
2. **Web E2E** from `docs/handoff/web.md` (after the backend review fixes are done).
3. **Refactor** the codebase for clarity (guided by the evaluation report), then a full end-to-end test: Postman/newman + browser check of every flow.
4. **Accounts, last step**: **delete** the extra accounts for real and replace them with new ones. Target counts: ADMIN 2, OPERATOR 4 (one per area), AUDITOR 3, TECHNICIAN 5, END_USER 100–150.
   - Deleting users means deleting or reassigning their rows (deposits, cards, sessions, top-ups, tickets, audit). The audit hash chain must then be **rebuilt** so `AuditController?action=verify` passes.
   - Do it in a re-runnable script `sql/08_accounts_v2.sql` (UTF-8 BOM). Keep `admin`, `system` and the Postman `v2*` test accounts.
   - Verify every page and the Postman collection afterwards.

## Rules for every agent
- Build: JDK 8 at `C:/Program Files/Java/jdk1.8.0_202/bin/javac`, classpath Tomcat `E:/apache-tomcat-9.0.113/lib/{servlet-api,jsp-api,el-api}.jar` + `lib/*.jar`, `-encoding UTF-8 -source 8 -target 8`; copy classes to `build/web/WEB-INF/classes`, copy `web/.` to `build/web/`, then `touch E:/apache-tomcat-9.0.113/conf/Catalina/localhost/SmartLocker.xml` to reload.
- DB: SQL Server `localhost:1433`, DB `PRJ301_LOCKER`, user `sa`, password `12345` (from `DbContext`). Run SQL with `sqlcmd` if it is on PATH; otherwise apply through a small JDBC tool and say so.
- SQL files keep the UTF-8 BOM; scripts must be re-runnable.
- DB stores UTC; show times with `<ui:dt>`. All visible text Vietnamese (OLED messages: ASCII without diacritics).
- Demo accounts: password `123456`. Device keys: `device-N-api-key` (seed).
- Do not commit. Do not push. Do not delete user data.
- At about 50k tokens of context left, write the handoff file (goal, done, open items, files touched, how to verify) and stop.
- Budget: each agent may use at most **300k tokens** in total. Before reaching it, write the handoff file and stop; the orchestrator starts a new agent from that handoff.
- Add a one-line lesson to the bottom of `CLAUDE.md` for every mistake that cost a retry.
