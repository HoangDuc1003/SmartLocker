# Deploy SmartLocker: Render + Azure SQL Database

This guide explains how to deploy SmartLocker using **Render** (Free tier Web Service running the repository `Dockerfile`) and **Azure SQL Database** (Free tier offer). Once configured, every `git push` to `main` triggers automated rebuild and redeployment on Render.

| Component | Platform & Tier | Resource Limits |
|---|---|---|
| Tomcat 9 + Java 8 | Render Web Service (Free) | 512 MB RAM. **Idles to sleep after 15 minutes of inactivity**; initial wake-up takes ~1 minute |
| SQL Server | Azure SQL Database (Free offer) | 100,000 vCore-seconds and 32 GB storage per month. Pauses automatically if quota is exhausted |

Prerequisites: GitHub account, Render account (authenticated via GitHub), and Microsoft Azure account (Azure for Students recommended).

---

## Step 1. Provision Free Azure SQL Database

1. Navigate to <https://portal.azure.com> -> **Create a resource** -> **SQL Database** -> **Create**.
2. Locate the banner **"Want to try Azure SQL Database for free?"** and select **Apply offer**.
3. **Basics Tab**:
   - **Resource group**: Create new (e.g. `smartlocker-rg`).
   - **Database name**: `PRJ301_LOCKER`.
   - **Server**: Create new:
     - Server name: unique identifier (e.g. `smartlocker-<unique-id>.database.windows.net`).
     - Location: **(Asia Pacific) Southeast Asia** (minimizes latency to Render Singapore region).
     - Authentication method: **Use SQL authentication**. Configure **Server admin login** (e.g. `lockeradmin`) and a strong password.
   - **Behavior when free limit reached**: select **Auto-pause the database until next month** to guarantee zero billing surprises.
4. **Networking Tab**:
   - Connectivity method: **Public endpoint**.
   - **Add current client IP address**: **Yes** (permits seeding from local workstation in Step 2).
5. Click **Review + create** -> **Create**, and wait 3-5 minutes for deployment completion.
6. Open the newly provisioned SQL Server -> **Security** -> **Networking** -> **Firewall rules**:
   - Add outbound IP ranges provided by your Render service, or add an exploratory rule covering required egress.
   - Click **Save**.

---

## Step 2. Initialize and Seed the Azure Database

Azure SQL forbids cross-database commands like `USE` and `CREATE DATABASE`. Passing the `-Azure` flag instructs `run_demo_db.ps1` to bypass those commands and initialize objects directly in the connected database:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_demo_db.ps1 -Azure -Server smartlocker-<unique-id>.database.windows.net -User lockeradmin -Password "<AdminPassword>"
```

The script sequentially executes `01_schema.sql`, `02_data_v1.sql`, `03_v2_v3.sql`, `04_phone.sql`, `05_auto_checkin.sql`, and `06_english_messages.sql`.

**Create an Application-Specific User**: Never configure application containers with the full `lockeradmin` server admin credential. Create a dedicated contained user directly within `PRJ301_LOCKER`:

```sql
CREATE USER smartlocker_app WITH PASSWORD = N'YourStrongAppPassword#2026';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dbo TO smartlocker_app;
GO
```

---

## Step 3. Provision Web Service on Render

1. Navigate to <https://dashboard.render.com> -> **New** -> **Web Service** -> select repository `SmartLocker`.
2. Configure settings:
   - **Name**: e.g. `smartlocker`. Target URL will be `https://smartlocker.onrender.com`.
   - **Language**: **Docker** (Render detects repository `Dockerfile`).
   - **Branch**: `main`.
   - **Region**: **Singapore**.
   - **Instance Type**: **Free**.
3. **Environment Variables**: configure connection parameters:

   | Key | Value |
   |---|---|
   | `DB_URL` | `jdbc:sqlserver://smartlocker-<unique-id>.database.windows.net:1433;databaseName=PRJ301_LOCKER;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=60` |
   | `DB_USER` | `smartlocker_app` (dedicated user, not `lockeradmin`) |
   | `DB_PASSWORD` | `<YourStrongAppPassword#2026>` |

   *Note: `loginTimeout=60` is essential to allow cold-started Azure free databases sufficient time to spin up.*
4. Click **Deploy Web Service**. Follow the build logs until `Server startup in [...] milliseconds` appears.
5. Open `https://<service-name>.onrender.com/`. The service redirects automatically to `/SmartLocker/`.

---

## Step 4. Optional Configurations

- **Email Dispatching**: Under Render -> Service -> **Environment** -> **Secret Files**, add `mail.local.properties` with SMTP configurations.
- **Keep-Alive Pinging**: Because Render Free services idle after 15 minutes, external monitoring tools (e.g. UptimeRobot) can ping `https://<service-name>.onrender.com/SmartLocker/` every 10 minutes to maintain persistent device monitoring.
