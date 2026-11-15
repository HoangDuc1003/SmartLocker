# Smart Locker Demo Deployment Guide (Option A)

This deployment uses a developer laptop running Tomcat and SQL Server exposed to the Internet via a Cloudflare Quick Tunnel. Because Quick Tunnels allocate dynamic URLs on each run, the repository's `gh-pages` branch provides **persistent URLs** that redirect traffic seamlessly to the active tunnel:

| Persistent URL (GitHub Pages) | Target Destination |
|---|---|
| `https://hoangduc1003.github.io/SmartLocker/` | `<tunnel>/SmartLocker/` (Evaluator & Instructor Entry) |
| `https://hoangduc1003.github.io/SmartLocker/k/LOCKER-01/` | `<tunnel>/SmartLocker/k/LOCKER-01` (QR Destination affixed to hardware box) |
| `https://hoangduc1003.github.io/SmartLocker/config.json` | `{"base_url":"<tunnel>/SmartLocker","updated_at":"..."}` (Dynamic endpoint for ESP32) |

The script `scripts/update-tunnel-link.ps1` regenerates these static redirection endpoints and commits them **strictly to the `gh-pages` branch** (via an isolated git worktree without touching `main` or local git configs) before asking for push confirmation.

The redirectors are lightweight static HTML documents without CDN dependencies. Redirection is handled via JavaScript and `<meta http-equiv="refresh">` tags, supplemented with a manual fallback hyperlink. Client scripts fetch fresh `config.json` with cache-busting headers, ensuring browsers transition immediately to the newest tunnel instance.

---

## 1. One-Time Setup

1. **Initialize `gh-pages` Branch**: Run the script as shown in Section 2, Step 4. If the branch does not exist, the script automatically initializes an orphan branch containing only: `index.html`, `k/LOCKER-01/index.html`, `config.json`, and `.nojekyll`.
2. **Enable GitHub Pages**: In repository `HoangDuc1003/SmartLocker` -> **Settings** -> **Pages** -> **Build and deployment**:
   - Source: **Deploy from a branch**
   - Branch: **`gh-pages`**, Directory: **`/ (root)`** -> **Save**.
   Within minutes, GitHub confirms: "Your site is live at `https://hoangduc1003.github.io/SmartLocker/`".
3. **Print QR Code**: Generate a QR code for `https://hoangduc1003.github.io/SmartLocker/k/LOCKER-01/` and affix it to the physical locker box. Because this persistent link never changes, **it only needs to be printed once**. Recommended offline generation methods:
   - **Chrome / Edge**: Navigate to the URL -> click Share in address bar -> **Create QR code for this page** -> **Download**.
   - **Offline Python**: `pip install segno` -> `python -c "import segno; segno.make('https://hoangduc1003.github.io/SmartLocker/k/LOCKER-01/', error='m').save('qr-locker-01.png', scale=12, border=4)"`.
   - Print at a minimum size of 3 x 3 cm. Test scanning with a smartphone before attaching.
   - Avoid public dynamic QR generator services that inject expiring third-party redirectors.
4. **(Optional) Pipe cloudflared Logs to File**: Enable automated URL extraction:
   `cloudflared tunnel --url http://localhost:8080 --logfile C:\temp\cloudflared.log`
5. **(Recommended) Enable GZIP Compression in Tomcat**: Boost mobile performance across cellular 4G. Open `conf/server.xml` and add compression attributes to `<Connector port="8080" ...>`:
   ```xml
   <Connector port="8080" protocol="HTTP/1.1" connectionTimeout="20000" redirectPort="8443" maxParameterCount="1000"
              compression="on" compressionMinSize="1024"
              compressibleMimeType="text/html,text/css,text/javascript,application/javascript,application/json,image/svg+xml"/>
   ```

---

## 2. Demo Day Checklist (Commence >= 20 min before presentation)

1. **SQL Server**: Confirm `MSSQLSERVER` service is running and `PRJ301_LOCKER` database is accessible.
2. **Tomcat**: Run `bin/startup.bat`. Open `http://localhost:8080/SmartLocker/` and verify authentication.
3. **Tunnel**: Open a dedicated PowerShell session and keep it open throughout the demo:
   `cloudflared tunnel --url http://localhost:8080 --logfile C:\temp\cloudflared.log`
   Copy the assigned `https://<random-subdomain>.trycloudflare.com` URL. Verify by opening `<tunnel-url>/SmartLocker/`.
4. **Update Persistent Redirection**: In the repo root, run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\update-tunnel-link.ps1 -TunnelUrl https://<random-subdomain>.trycloudflare.com
   ```
   Or allow the script to read the log automatically:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\update-tunnel-link.ps1 -LogFile C:\temp\cloudflared.log
   ```
5. **Verify Redirection**: In an Incognito window, open `https://hoangduc1003.github.io/SmartLocker/` to verify seamless redirection to the new tunnel endpoint.

---

## 3. Troubleshooting & Failure Recovery

| Symptom | Probable Cause | Action |
|---|---|---|
| QR scan redirects to previous tunnel | Browser cache retains stale redirect | Click the manual redirection hyperlink on the fallback page |
| Redirection hits tunnel but returns 404 | Deployed WAR missing kiosk mobile endpoints | Recompile and redeploy web docbase (`sh scripts/build-dev.sh`) |
| Tunnel responds with **502 Bad Gateway** | Tomcat process terminated or cloudflared desynced | Inspect local Tomcat service. Re-run tunnel and update GitHub Pages |

---

## 4. Technical Characteristics (Cloudflare & GitHub Pages)

- **Cloudflare Quick Tunnels**:
  - Max 200 in-flight concurrent requests (exceeding returns HTTP 429).
  - WebSockets supported; Server-Sent Events (SSE) unsupported. SmartLocker avoids SSE by utilizing client-side polling.
  - Ephemeral URLs generated per daemon startup.
- **GitHub Pages**:
  - Cache-Control header `max-age=600` (10 minutes). Redirection scripts mitigate cache delays by evaluating live `config.json` asynchronously.

---

## 5. Security & Device API Key Configuration

Because the physical locker box is accessible over the Internet during live demonstrations:
- Avoid utilizing the sample key `device-1-api-key`.
- Execute `powershell -ExecutionPolicy Bypass -File scripts/set-device-key.ps1 -New` to generate a cryptographically strong secret in `config/device-keys.local.properties` (ignored by git).
- Flash the corresponding key to the ESP32 firmware and configure environment parameters accordingly.
