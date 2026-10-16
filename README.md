# Smart Locker

Java Web coursework for managing lockers and detecting unusual access from IoT device telemetry. The application follows the MVC2 structure in the assignment: JSP views, Servlet controllers and APIs, JDBC DAOs, SQL Server, and rule and Weka services.

## Requirements

- NetBeans 13, JDK 8, Apache Tomcat 9, SQL Server, and SSMS.
- The project uses Ant and the JAR files already included in lib/ and web/WEB-INF/lib/. No Maven setup is required.
- The database connection is configured in src/java/dao/DbContext.java. Set the host, database name, SQL Server user, and password for your local machine before running. Do not commit a personal database password.

## Run locally

1. Open the project in NetBeans 13 with JDK 8 and Tomcat 9 configured.
2. For a new database only, run sql/01_schema.sql in SSMS to create PRJ301_LOCKER and its sample data. This script deletes any existing PRJ301_LOCKER database.
3. Run sql/02_sample_data.sql to load the complete demo: 100 users, devices, bookings, wallet activity, telemetry, alerts, and special cases.
4. Run sql/03_scenarios.sql and sql/04_wallet_booking.sql in order to install the case procedures and compatibility migrations.
5. Set the local SQL Server connection in DbContext.java, then use **Run Project** in NetBeans. The default context path is /SmartLocker; use the port configured for your Tomcat server.

For an existing database, run sql/04_wallet_booking.sql, then sql/03_scenarios.sql. To add the expanded demo, also run sql/02_sample_data.sql. Do not run sql/01_schema.sql against an existing database you want to preserve. The demo seed runs once per database, records DEMO_DATA_V2 in the audit chain, and skips subsequent runs to preserve changes made during demonstrations.

The sample accounts created by 01_schema.sql use password 123456:

| Username | Role |
| --- | --- |
| admin | Administrator |
| operator1 | Locker operator |
| tech1 | Technician |
| auditor1 | Auditor |
| student1 | End user |

The system account is disabled and cannot sign in.

The `sql/` directory contains exactly four setup files. The former workshop,
full-data seed, and slot-permission scripts are consolidated into `02_sample_data.sql`.
For a fresh setup, run `01` through `04` in order. The demo contains 100 user
accounts plus the disabled system account, 90 slots, seven devices, six storage
plans, 70 historical bookings, live bookings, 50 top-ups, and 480 synthetic
training sessions. Sample passwords are `123456`; generated accounts are
`student9` through `student91`, with names, contact details, wallet balances,
and RFID cards. Existing extra accounts and history are retained.

Optional research data: run file `01`, import `Train_Test_IoT_Garage_Door.csv`
into `RawGarageDoor` with `door_state` and `label` columns, then run file `02`.
If `PublicSession` is empty, file `02` converts the imported rows into sessions;
otherwise it preserves the existing sessions. Without `RawGarageDoor`, it fills
synthetic examples for the demo. These examples are not research measurements.

| Demo case | Account or location |
| --- | --- |
| No money / insufficient money | `student88` / `student87` |
| Locked / disabled account | `student90` / `student89` |
| Three no-shows within seven days | `student10` |
| Maximum three extensions reached | `student11`, DOMA-A A05 |
| Lost card with replacement, old card reused | `student12`, DOMA-A A06 |
| Blocked card reused | `student13`, DOMA-A A07 |
| Another user's card accesses a booking | `student14`, DOMA-A A08 |
| Item left inside | `student15`, DOMA-A A09 |
| Online reservation without a linked card | `student16`, DOMA-A A10 |
| Overdue booking | `student9`, DOMA-A A04; `student19`, CANT-A A05 |
| Offline device; expired reservation waits for reconnect | LOCKER-07 / GYM-B; `student23`, B05 |
| Expired calibration; device under maintenance | LOCKER-04 / DOMA-B B04 |
| Forced opening / forged remote opening | LIB-B B01 / B04 |
| Device clock ahead / impossible weight | LIB-B B05 / B06 |
| Closed door with a weight change | CANT-A A06 |
| Simulated ML anomaly | GYM-A A06 |
| Remote command pending, sent, done, expired | Remote Commands page, GYM-A |
| Pending, approved, rejected top-ups; inactive plan | Top-ups and Storage Plans pages |

Reservations and pending remote commands can expire as time passes. Demo dates
are relative to the seed time in UTC. Audits are written through `Audit_Append`
so the hash chain remains valid.
Admin and technician accounts can use **Update status** on the Slots page.
Live bookings prevent conflicting status changes; each successful change is audited.

## Main flow

Users register or sign in, then see pages permitted by their role. End users can add funds to their account with VietQR, reserve an available slot with their balance, and extend a booking. An RFID card is not required for account funding or online reservation. Staff confirm top-ups before the balance changes. Paid reservations debit the account once; cancellation before check-in and an expired hold refund that payment. Operators manage lockers and confirm remote unlocks. Technicians handle faults. Auditors inspect the audit trail. Device APIs receive heartbeats and session batches; rules and the trained model create alerts with evidence.

The five practical cases are an offline locker, remote unlock, lost card, reservation without check-in, and a faulty sensor. Run src/java/tool/ScenarioSender.java from NetBeans with one of heartbeat, remote, spoof, lostcard, checkin, or sensor as its first argument. Its URL assumes Tomcat port 8080; change the constant when using another port. Some cases require the stated action in the web interface first.

## Telemetry, model, and tests

- Run src/java/tool/DataReplayer.java to send rows from PublicSession to the device API. Its URL also assumes port 8080.
- Run src/java/tool/ModelTrainer.java after importing the public data. It compares RandomForest, J48, NaiveBayes, and IBk with ten-fold cross-validation, then saves the selected model and its header in src/java/ml/.
- Use **Test Project** in NetBeans to run the TestNG cases in test/test/. The audit integration case requires a configured SQL Server database.

The measured model results belong in the technical report. Record the values printed by ModelTrainer and the cited TON_IoT Garage Door reference result in one table with accuracy, precision, recall, and F1. Results are intentionally not invented here; they depend on the imported data.

## Project layout

| Path | Purpose |
| --- | --- |
| src/java/controller/ and web/WEB-INF/views/ | Web pages and user actions |
| src/java/api/ | JSON endpoints for devices and the dashboard |
| src/java/dao/ and src/java/service/ | Database access, rules, and alerts |
| sql/ | Schema, public data preparation, and case procedures |
| test/ | TestNG cases |

This project is intended to run as a Tomcat application with SQL Server. The static Vercel preview in the repository is a separate demo and does not run the Java backend.
