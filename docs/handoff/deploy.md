# Handoff: deploy (spec §7)

## Goal
Keep a fixed GitHub Pages link (`https://hoangduc1003.github.io/SmartLocker/`) that points at the current Cloudflare quick tunnel: a redirect for the web app, a redirect for the QR target `k/LOCKER-01/`, and `config.json` for the ESP32. The script commits to `gh-pages` only. It pushes only after the user confirms.

## Done
- `scripts/update-tunnel-link.ps1` (PowerShell 5.1, saved as UTF-8 with BOM so PS 5.1 reads the Vietnamese text correctly). It does the following:
  - takes `-TunnelUrl` or `-LogFile` (picks the last `*.trycloudflare.com` and skips `api.`), or prompts for the address;
  - validates `^https://[a-z0-9-]+\.trycloudflare\.com$` and strips any pasted path;
  - warns if the tunnel does not answer (`-SkipCheck` turns this off);
  - fetches `origin/gh-pages` if it exists and fast-forwards the local branch when possible; otherwise it creates an orphan `gh-pages` in a temp worktree under `%TEMP%`;
  - writes `index.html`, `k/<device>/index.html`, `config.json` and `.nojekyll` as UTF-8 without BOM, with LF line endings;
  - commits, removes the worktree in `finally`, then asks with `Read-Host` before `git push origin gh-pages`. It also has `-DryRun`, `-NoPush` and `-DeviceCode`.
  - The redirect pages are plain HTML. They use meta refresh (3 s) and JS: the JS reads `config.json?t=<now>` first, so a stale cached page still goes to the newest tunnel. After 2.5 s it falls back to the URL baked into the page. Each page also has a visible Vietnamese fallback link.
- `docs/deploy.md` (Vietnamese) covers one-time setup (enable Pages, QR via the built-in Chrome/Edge generator or offline `segno`), the demo-day checklist, ESP32 notes with an Arduino snippet, troubleshooting, script parameters, and the verified facts with their sources.

## Tests run (17/10/2026)
- `-DryRun` with a fake URL printed all 4 files correctly. The invalid URLs (`http://`, a non-Cloudflare host, `api.trycloudflare.com`, `*.trycloudflare.com.evil.com`) were rejected with exit code 1. A log file with several URLs gave the last one. A missing log file failed cleanly.
- Real run with `-NoPush`: it created an orphan `gh-pages` with exactly 4 files and committed as the user's own identity. `main`'s HEAD, working tree and index were unchanged, and no worktree or temp directory was left.
- Second run, with the branch already existing, answering `khong` at the prompt: it added a second commit and did not push. `git ls-remote` still showed only `main`.
- Browser test: I served the generated pages on `127.0.0.1:8765`. `k/LOCKER-01/` followed the `base_url` from `config.json`. With `config.json` deleted, `/` fell back to the baked URL.
- Cleanup: I deleted the local test branch `gh-pages` (it held only the fake URLs), so the user's first real run creates it fresh.
- Fact check: Cloudflare's page confirms the 200 in-flight requests limit with 429 beyond it, no SSE, and no uptime guarantee. `curl -I` on a github.io site shows `Cache-Control: max-age=600`.

## Open items
- Spec §7 item 4 still says `https://<user>.github.io/smartlocker-link/config.json`. The correct URL is `https://hoangduc1003.github.io/SmartLocker/config.json`; the correction is noted in `docs/deploy.md` §3. The spec owner should fix §7.
- User actions:
  - run the script for real and type `co` at the push prompt;
  - enable Pages (`gh-pages` branch, `/ (root)`);
  - print the QR code;
  - test over 4G.
- The ESP32 HTTPS call (`WiFiClientSecure`) has not been tested on hardware.
- `/SmartLocker/k/LOCKER-01` belongs to the web agent. Until it exists, the QR redirect lands on a 404.

## Files touched
- `scripts/update-tunnel-link.ps1` (new)
- `docs/deploy.md` (new)
- `docs/handoff/deploy.md` (new)

## How to verify
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-tunnel-link.ps1 -TunnelUrl https://fake-demo.trycloudflare.com -DryRun
powershell -ExecutionPolicy Bypass -File .\scripts\update-tunnel-link.ps1 -TunnelUrl https://fake-demo.trycloudflare.com -NoPush -SkipCheck
git ls-tree -r --name-only gh-pages; git show gh-pages:config.json; git worktree list
git branch -D gh-pages   # remove the fake test branch afterwards
```
