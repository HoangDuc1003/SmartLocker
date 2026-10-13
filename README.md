# Smart Locker

Java Web coursework for managing lockers and detecting unusual access from IoT device telemetry. The application follows the MVC2 structure in the assignment: JSP views, Servlet controllers and APIs, JDBC DAOs, SQL Server, and rule and Weka services.

## Requirements

- NetBeans 13, JDK 8, Apache Tomcat 9, SQL Server, and SSMS.
- The project uses Ant and the JAR files already included in lib/ and web/WEB-INF/lib/. No Maven setup is required.
- The database connection is configured in src/java/dao/DbContext.java. Set the host, database name, SQL Server user, and password for your local machine before running. Do not commit a personal database password.

## Run locally

1. Open the project in NetBeans 13 with JDK 8 and Tomcat 9 configured.
2. For a new database only, run sql/01_schema.sql in SSMS to create PRJ301_LOCKER and its sample data. This script deletes any existing PRJ301_LOCKER database.
3. For public telemetry data, run part 1 of sql/02_workshop2.sql, import Train_Test_IoT_Garage_Door.csv into a table named RawGarageDoor, then run part 2. Check the imported column names as described in that SQL file.
4. Run sql/03_scenarios.sql to create the procedures for the five practical cases.
5. Set the local SQL Server connection in DbContext.java, then use **Run Project** in NetBeans. The default context path is /SmartLocker; use the port configured for your Tomcat server.

For an existing database, keep its data: run sql/04_wallet_booking.sql, then run sql/03_scenarios.sql again. Do not run sql/01_schema.sql against an existing database you want to preserve.

The sample accounts created by 01_schema.sql use password 123456:

| Username | Role |
| --- | --- |
| admin | Administrator |
| operator1 | Locker operator |
| tech1 | Technician |
| auditor1 | Auditor |
| student1 | End user |

The system account is disabled and cannot sign in.

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
