# FINAL_BACKEND_ARCHITECTURE.md: SmartLocker Backend Architecture & 5-Stage Sensor Integration Matrix

**Repository**: `HoangDuc1003/SmartLocker`  
**Milestone**: Milestone 2 (Backend Architecture & 5-Stage Sensor Integration Matrix)  
**Standard**: Academic & Forensic Audit Grade, Scopus Publication Readiness  
**Target Specification**: User Request R2 & R5, Feature Inventory Items 5, 6, 7, 8  
**Date**: November 2026  

---

## Table of Contents
1. [Executive Summary & Architectural Paradigm](#1-executive-summary--architectural-paradigm)
2. [Java Backend Deep Dive & Line-by-Line Citations](#2-java-backend-deep-dive--line-by-line-citations)
   - [2.1 Deterministic Rule Engine (`RuleEngine.java`)](#21-deterministic-rule-engine-ruleenginejava)
   - [2.2 Machine Learning Risk Scorer (`RiskScorer.java`)](#22-machine-learning-risk-scorer-riskscorerjava)
   - [2.3 Two-Tier Anomaly Orchestration (`AlertService.java`)](#23-two-tier-anomaly-orchestration-alertservicejava)
   - [2.4 Cryptographic Audit Verification (`AuditVerifier.java`)](#24-cryptographic-audit-verification-auditverifierjava)
   - [2.5 Database Connection Pool & Dynamic Proxy (`DbContext.java`)](#25-database-connection-pool--dynamic-proxy-dbcontextjava)
   - [2.6 Context Acquisition & Environmental Bounds (`SessionContextDao.java`)](#26-context-acquisition--environmental-bounds-sessioncontextdaojava)
   - [2.7 Append-Only Ingestion & Slot Disambiguation (`LockerSessionDao.java`)](#27-append-only-ingestion--slot-disambiguation-lockersessiondaojava)
   - [2.8 Role-Based Access Control & Perimeter Security (`SecurityFilter.java`)](#28-role-based-access-control--perimeter-security-securityfilterjava)
3. [Database Schema & Persistence Architecture](#3-database-schema--persistence-architecture)
   - [3.1 Baseline Relational Entity Structure](#31-baseline-relational-entity-structure)
   - [3.2 Tamper-Evident Append-Only Enforcement](#32-tamper-evident-append-only-enforcement)
   - [3.3 Exact Column Inventory & Missing Baseline Channels](#33-exact-column-inventory--missing-baseline-channels)
4. [API Contract Specifications](#4-api-contract-specifications)
   - [4.1 Device Heartbeat & Dynamic Polling (`POST /api/health`)](#41-device-heartbeat--dynamic-polling-post-apihealth)
   - [4.2 Multi-Modal Credential Authorization (`POST /api/device/auth`)](#42-multi-modal-credential-authorization-post-apideviceauth)
   - [4.3 Batch Telemetry Ingestion & Idempotency (`POST /api/locker/batch`)](#43-batch-telemetry-ingestion--idempotency-post-apilockerbatch)
5. [5-Stage Sensor Integration Matrix](#5-5-stage-sensor-integration-matrix)
   - [5.1 Definition of the 5 Integration Stages](#51-definition-of-the-5-integration-stages)
   - [5.2 Comprehensive Verification Matrix](#52-comprehensive-verification-matrix)
   - [5.3 Detailed Breakdown by Sensor Channel](#53-detailed-breakdown-by-sensor-channel)
6. [Firmware 4.3-esp32 SRF05 Physical Implementation vs. Simulation Reality](#6-firmware-43-esp32-srf05-physical-implementation-vs-simulation-reality)
   - [6.1 Physical Pinout, Circuitry & Timing Logic](#61-physical-pinout-circuitry--timing-logic)
   - [6.2 Edge State Machine & Presence Actuation](#62-edge-state-machine--presence-actuation)
   - [6.3 Physical Firmware vs. Research Simulation Testbed](#63-physical-firmware-vs-research-simulation-testbed)
7. [Automated Verification & Integrity Assertion](#7-automated-verification--integrity-assertion)

---

## 1. Executive Summary & Architectural Paradigm

The SmartLocker platform implements a secure, context-aware access control and multi-sensor anomaly detection system for Internet-of-Things (IoT) parcel and storage lockers. The architecture decouples physical edge operations from server-side policy enforcement, ensuring that edge IoT devices remain stateless and unprivileged while centralizing security invariants, audit tracking, and machine-learning anomaly detection on the Java Enterprise backend.

```
+-----------------------------------------------------------------------------------+
|                              EDGE / CLIENT TIER                                   |
|                                                                                   |
|  +-------------------------------------+   +------------------------------------+  |
|  |  ESP32 Firmware 4.3 (Physical Box)  |   |    Python Multi-Sensor Simulator   |  |
|  |  - Keypad, AS608 FP, PN532 RFID/NFC |   |    - 4 Sensor Channels             |  |
|  |  - SRF05 Sonar (Local Edge Only)    |   |    - Batch Telemetry Generator     |  |
|  |  - Endpoints: /health, /device/auth |   |    - Ingestion: /locker/batch      |  |
|  +-------------------------------------+   +------------------------------------+  |
+------------------------------------------+----------------------------------------+
                                           | HTTP REST (X-API-Key)
                                           v
+-----------------------------------------------------------------------------------+
|                           SECURITY FILTER PERIMETER                               |
|   `SecurityFilter.java`: API Key Auth, Device Identification, RBAC Enforcement   |
+------------------------------------------+----------------------------------------+
                                           |
                                           v
+-----------------------------------------------------------------------------------+
|                           JAVA BACKEND SERVICE LAYER                              |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  |                       AlertService Orchestration                            |  |
|  |                                                                             |  |
|  |   [Step 1] Context Loading       SessionContextDao.load(session)            |  |
|  |                                                |                            |  |
|  |   [Step 2] Tier 1: Deterministic Rules         v                            |  |
|  |            RuleEngine.evaluate()  ---------> Verdict (Alert / Normal)       |  |
|  |                                                | (If Normal & ML-Eligible)  |  |
|  |   [Step 3] Tier 2: Statistical ML Scoring      v                            |  |
|  |            RiskScorer.score()     ---------> Risk Score >= 0.80 ?           |  |
|  |                                                |                            |  |
|  |   [Step 4] Actions & Audit                     v                            |  |
|  |            AlertDao, AuditDao, MaintenanceDao, RemoteCommandDao             |  |
|  +-----------------------------------------------------------------------------+  |
+------------------------------------------+----------------------------------------+
                                           | JDBC (Custom Pooled Connections)
                                           v
+-----------------------------------------------------------------------------------+
|                        MICROSOFT SQL SERVER PERSISTENCE                           |
|  - LockerSession (Append-Only Trigger: trg_LockerSession_AppendOnly)              |
|  - AuditLog & HashChain (Haber-Stornetta SHA-256 Forward-Linked Tamper-Evident)   |
|  - SensorType (DOOR, WEIGHT, STAY baseline bounds)                                |
|  - Stored Procedures with sp_getapplock (Concurrency & Anti-Race Guarantees)      |
+-----------------------------------------------------------------------------------+
```

### Key Architectural Pillars:
1. **Two-Tier Anomaly Detection Pipeline**:
   - **Tier 1 (Deterministic Invariants)**: `RuleEngine.java` prioritizes hard physical and procedural violations: hardware sensor faults, unauthorized remote activations, blocked/lost credential usage, forced door breach, user substitution, physical tampering/spoofing, item abandonment, and duration expiry.
   - **Tier 2 (Statistical ML Evaluation)**: `RiskScorer.java` evaluates sessions that pass all Tier 1 deterministic rules using a pre-trained Weka classifier. The ML evaluation is strictly gated on rule-normal sessions to eliminate false classifications caused by hardware faults or administrative actions.
2. **Lightweight Custom Connection Pooling**:
   - `DbContext.java` eliminates third-party connection pool bloat through a high-performance dynamic proxy pool (`java.lang.reflect.Proxy`) with strict auto-rollback, auto-commit resets, and idle liveness checks.
3. **Cryptographic Tamper-Evident Audit Logging**:
   - Every system mutation and alert triggers Haber-Stornetta SHA-256 forward-linked cryptographic chaining (`AuditVerifier.java`), allowing mathematical proof of log integrity or exact detection of tampered records.
4. **Append-Only Telemetry Ingestion**:
   - Table `LockerSession` is fortified by an `INSTEAD OF UPDATE, DELETE` database trigger (`trg_LockerSession_AppendOnly`), preventing historical revision of sensor records.
5. **Strict Delineation of Edge vs. Simulation**:
   - Physical firmware (v4.3-esp32) executes ultrasonic presence sensing strictly at the edge for local LCD power management and auto-locking countdown delays; it never streams batch multi-sensor telemetry over the network. Multi-sensor batch evaluations are driven exclusively by the software simulation testbed (`simulator/`, `experiments/`).

---

## 2. Java Backend Deep Dive & Line-by-Line Citations

### 2.1 Deterministic Rule Engine (`RuleEngine.java`)
- **File Location**: `src/java/service/RuleEngine.java` (98 lines)
- **Role**: Pure deterministic decision module decoupled from database access. It accepts a `LockerSession` model and a pre-loaded `SessionContext` and evaluates security rules in strict, immutable priority order (lines 30–73).

```java
// src/java/service/RuleEngine.java, lines 12–28
public static final double ITEM_LEFT_G = 50;      // grams still in the slot after pick-up
public static final double SPOOF_WEIGHT_G = 50;   // weight moved although the door sensor says it never opened
public static final long CLOCK_AHEAD_SEC = 300;   // measured_at more than 5 minutes in the future
public static final long COMMAND_TTL_SEC = 30 * 60;   // a remote/phone command must be used within 30 minutes
public static final long COMMAND_CLOCK_LAG_SEC = 60;  // box RTC clock lag buffer
```

#### Rule Evaluation Order (Priority Hierarchy):
1. **Priority 1: Sensor Fault Detection (`findSensorFault`)** (lines 33–36, 76–96):
   - Sensor data integrity takes absolute precedence: a malfunctioning sensor must never be blamed on the user.
   - *Physical Bounds*: Validates `door_open_sec`, `weight_delta_g`, and `stay_min` against dynamic ranges configured in `SensorType` via `ctx.inRange()` (lines 78–86).
   - *Temporal Impossibility*: Checks if door open time exceeds total session stay: `door_open_sec > stay_min * 60 + 5` (lines 87–89).
   - *Clock Drift*: Rejects sessions where the device clock is over 300 seconds ahead of the server: `ctx.getUploadDelaySec() < -CLOCK_AHEAD_SEC` (lines 90–92).
   - *Calibration Expiry*: Checks `!ctx.isCalibrationValid()` (lines 93–95).
   - *Outcome*: Returns `Verdict.alert("SENSOR_FAULT", "reason", fault).noMl()`. The `.noMl()` flag explicitly disqualifies the session from Tier 2 machine learning scoring.
2. **Priority 2: Remote/Phone Command Authorization** (lines 38–44):
   - For open sources `"REMOTE"` or `"PHONE"`, checks if `commandId != null && ctx.isCommandValid()`.
   - If valid, returns `Verdict.staffOpen(commandId)`.
   - If missing or invalid, flags `Verdict.alert("SUSPECTED_SPOOF", "reason", "remote open without a valid command")`.
3. **Priority 3: Lost or Blocked Card Verification** (lines 46–50):
   - Inspects `ctx.getCardStatus()`. If card status is non-null and not `"ACTIVE"` (e.g., `"LOST"`, `"BLOCKED"`), returns `Verdict.alert("LOST_CARD_USED", "card_uid", s.getCardUid())`.
4. **Priority 4: Physical Behavioral Violations** (lines 52–71):
   - *Forced Entry (`FORCED_OPEN`)* (lines 52–55): Door opened without successful authentication: `!s.isRfidOk() && s.getDoorOpenSec() > 0`.
   - *User Substitution (`WRONG_USER`)* (lines 56–60): Successful card tap by an unauthorized party: `s.isRfidOk() && cardOwner != depositOwner`.
   - *Sensor Tamper / Spoof (`SUSPECTED_SPOOF`)* (lines 61–64): Weight displacement occurred without door opening: `s.getDoorOpenSec() == 0 && Math.abs(s.getWeightDeltaG()) > SPOOF_WEIGHT_G` (50g).
   - *Item Left Behind (`ITEM_LEFT`)* (lines 65–67): Parcel remains in slot after pickup checkout: `s.getWeightDeltaG() > ITEM_LEFT_G` (50g).
   - *Overstay / Overdue (`OVERDUE`)* (lines 68–71): Session stay exceeds allowable booking duration plus grace period: `ctx.getAllowedMin() > 0 && s.getStayMin() > ctx.getAllowedMin()`.
5. **Fallback: Normal Session** (line 72):
   - If no rules match, returns `Verdict.normal()`. The verdict remains ML-eligible for Tier 2 evaluation.

---

### 2.2 Machine Learning Risk Scorer (`RiskScorer.java`)
- **File Location**: `src/java/service/RiskScorer.java` (99 lines)
- **Role**: Singleton ML inference engine evaluating statistical access risk using a serialized Weka model (`/ml/locker_model.bin` and `/ml/locker_header.arff`).

```java
// src/java/service/RiskScorer.java, lines 53–73
public double score(LockerSession s) {
    if (model == null || normalIndex < 0) {
        return 0.0;
    }
    try {
        double[] values = new double[header.numAttributes()];
        for (int i = 0; i < header.numAttributes(); i++) {
            if (i != header.classIndex()) {
                values[i] = featureValue(header.attribute(i).name(), s);
            }
        }
        Instance row = new DenseInstance(1.0, values);
        row.setDataset(header);
        double[] distribution = model.distributionForInstance(row);
        return Math.min(1.0, Math.max(0.0, 1.0 - distribution[normalIndex]));
    } catch (Exception e) {
        LOG.warning("Scoring failed, answering 0: " + e.getMessage());
        return 0.0;
    }
}
```

#### Feature Vector Extraction (lines 89–98):
The model evaluates an input feature vector containing exactly 5 observable attributes:
1. `door_open_sec`: Door open duration in seconds (`s.getDoorOpenSec()`).
2. `weight_delta_g`: Weight delta in grams (`s.getWeightDeltaG()`).
3. `unlock_count`: Number of unlock actuations (`s.getUnlockCount()`).
4. `rfid_ok`: Binary authentication indicator, 1 if authenticated, 0 otherwise (`s.isRfidOk() ? 1 : 0`).
5. `stay_min`: Total stay duration in minutes (`s.getStayMin()`).

```java
// src/java/service/RiskScorer.java, lines 89–98
private static double featureValue(String name, LockerSession s) {
    switch (name) {
        case "door_open_sec":  return s.getDoorOpenSec();
        case "weight_delta_g": return s.getWeightDeltaG();
        case "unlock_count":   return s.getUnlockCount();
        case "rfid_ok":        return s.isRfidOk() ? 1 : 0;
        case "stay_min":       return s.getStayMin();
        default: throw new IllegalArgumentException("Unknown feature " + name);
    }
}
```

*Forensic Audit Finding*: `RiskScorer.java` contains **no ultrasonic distance attribute** and **no IMU vibration/tilt attribute**. If any unmapped feature name is requested, line 96 throws an `IllegalArgumentException`.

---

### 2.3 Two-Tier Anomaly Orchestration (`AlertService.java`)
- **File Location**: `src/java/service/AlertService.java` (60 lines)
- **Role**: Coordinates the two-tier anomaly detection pipeline, gates ML evaluation, handles side-effects, updates command states, and triggers operational workflows.

```java
// src/java/service/AlertService.java, lines 24–59
public void evaluate(LockerSession session) throws SQLException {
    SessionContext ctx = new SessionContextDao().load(session);
    Verdict verdict = ruleEngine.evaluate(session, ctx);

    Double risk = null;
    if (verdict.isMlEligible()) {                        // staff open or broken sensor is not user behaviour
        risk = RiskScorer.getInstance().score(session);  // 1 - P(NORMAL)
        if (!verdict.isAlert() && risk >= ML_THRESHOLD) {
            verdict = Verdict.alert("ML_ANOMALY", "risk_score", String.format(Locale.ROOT, "%.2f", risk));
        }
    }

    if ("STAFF_OPEN".equals(verdict.getLabel())) {
        if (new RemoteCommandDao().markDone(session.getCommandId(), session.getSessionId())) {
            new AuditDao().append(AuditDao.SYSTEM_USER_ID, "COMMAND_DONE", "COMMAND", session.getCommandId(),
                    "session " + session.getSessionId());
        } else {
            verdict = Verdict.alert("SUSPECTED_SPOOF", "reason", "remote command already used")
                    .with("command_id", String.valueOf(session.getCommandId()));
        }
    }

    if (verdict.isAlert()) {
        String source = "ML_ANOMALY".equals(verdict.getLabel()) ? "ML" : "RULE";
        int alertId = new AlertDao().create(session.getDeviceId(), session.getSessionId(), source,
                verdict.getLabel(), risk, verdict.getEvidence());
        new AuditDao().append(AuditDao.SYSTEM_USER_ID, "CREATE", "ALERT", alertId, verdict.getLabel());
        if ("SENSOR_FAULT".equals(verdict.getLabel())) {
            new MaintenanceDao().openForFault(session.getDeviceId(), alertId, session.getSessionId(),
                    verdict.getEvidence().get(0)[1]);
        }
    }
}
```

#### Pipeline Invariants & Edge Handling:
- **ML Gating**: Line 30 checks `verdict.isMlEligible()`. If a session is identified as `SENSOR_FAULT` or `STAFF_OPEN`, it is never scored by ML.
- **ML Anomaly Escalation**: Line 32 defines `ML_THRESHOLD = 0.80`. If `risk >= 0.80` on an otherwise rule-normal session, the verdict is escalated to `ML_ANOMALY`.
- **Command Single-Use Protection**: Lines 37–47 guarantee that remote unlock commands cannot be replayed. `RemoteCommandDao.markDone()` conditionally transitions status `SENT -> DONE`. If another session already claimed the command, the session is branded `SUSPECTED_SPOOF`.
- **Automated Remediation**: Lines 54–57 detect `SENSOR_FAULT` alerts, automatically opening an urgent maintenance ticket via `MaintenanceDao.openForFault()` and taking the corresponding slot out of service (`MAINTENANCE`).

---

### 2.4 Cryptographic Audit Verification (`AuditVerifier.java`)
- **File Location**: `src/java/service/AuditVerifier.java` (154 lines)
- **Role**: Implements Haber-Stornetta forward-linked SHA-256 tamper-evident cryptographic hash chaining over system audit records.

```java
// src/java/service/AuditVerifier.java, lines 54–92
public static final String ZERO_HASH = "0000000000000000000000000000000000000000000000000000000000000000";
private static final Charset UTF16LE = Charset.forName("UTF-16LE");

private static final class Walker {
    private final MessageDigest digest;
    private String prevHash = ZERO_HASH;

    boolean accept(Row r) {
        String text = r.auditId + "|" + r.tsText + "|" + r.actor + "|" + r.action + "|" + r.objectType + "|"
                + r.objectId + "|" + r.diff + "|" + prevHash;
        String expected = toHex(digest.digest(text.getBytes(UTF16LE)));
        if (!prevHash.equals(r.prevHash) || !expected.equals(r.chainHash)) {
            return false;
        }
        prevHash = expected;
        return true;
    }
}
```

#### Cryptographic Specification:
- **Genesis Block**: Anchor ID 1 starts with `prev_hash` set to 64 ASCII hex zeros (`ZERO_HASH`, line 55).
- **Encoding Alignment**: Hashing uses `UTF-16LE` (UTF-16 Little Endian, line 58) because Microsoft SQL Server's internal `HASHBYTES('SHA2_256', @nvarchar)` processes `NVARCHAR` strings in UTF-16LE. This ensures byte-level cross-platform identity between SQL Server triggers/procedures and Java verifiers.
- **Payload Serialization**: The hashed message string follows the strict pipe-delimited schema:
  $$\text{Payload} = \text{audit\_id} \parallel \text{"|"} \parallel \text{tsText} \parallel \text{"|"} \parallel \text{actor} \parallel \text{"|"} \parallel \text{action} \parallel \text{"|"} \parallel \text{objectType} \parallel \text{"|"} \parallel \text{objectId} \parallel \text{"|"} \parallel \text{diff} \parallel \text{"|"} \parallel \text{prevHash}$$
- **Verification Streaming**: `findFirstBroken()` (lines 140–153) uses a forward-only, read-only cursor (`ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY`) to verify infinite-length audit logs without risking Java `OutOfMemoryError`.

---

### 2.5 Database Connection Pool & Dynamic Proxy (`DbContext.java`)
- **File Location**: `src/java/dao/DbContext.java` (191 lines)
- **Role**: Centralized database connection manager implementing custom proxy-based pooling without heavy external frameworks.

```java
// src/java/dao/DbContext.java, lines 23–32
private static final String URL = env("DB_URL",
        "jdbc:sqlserver://localhost:1433;databaseName=PRJ301_LOCKER;encrypt=false");
private static final String USER = env("DB_USER", "sa");
private static final String PASSWORD = env("DB_PASSWORD", "12345");

private static final int MAX_IDLE = 8;                    // pool capacity
private static final long CHECK_AFTER_MS = 30_000;        // liveness ping threshold
private static final long CLOSE_AFTER_MS = 5 * 60_000;    // stale eviction threshold
```

#### Pooling Mechanics & Proxy Interception:
- **Connection Borrowing (`borrowIdle`, lines 69–88)**: LIFO deque (`IDLE.pollFirst()`) minimizes active connection count. Connections idle for $>30\text{ s}$ undergo an active validation check (`raw.isValid(2)`). Connections idle for $>5\text{ min}$ are quietly evicted and closed.
- **Dynamic Proxy Wrapper (`wrap`, lines 138–167)**: Wraps physical connections in `java.lang.reflect.Proxy`. Intercepts calls to `.close()`, returning the raw connection to `IDLE` instead of closing the physical TCP socket to SQL Server.
- **Safety Invariant Reset (`giveBack`, lines 90–125)**: When a borrower returns a connection, `DbContext` automatically checks `raw.getAutoCommit()`. If an uncommitted transaction is pending, it executes `raw.rollback()` and resets `autoCommit = true`, preventing connection pollution across distinct HTTP requests.
- **Driver Drain on Outage**: If a returned connection is detected as dead/broken (`raw.isClosed()`), the pool calls `drain()` (lines 127–136) to purge all idle sockets, protecting against cascading socket errors during database restarts.

---

### 2.6 Context Acquisition & Environmental Bounds (`SessionContextDao.java`)
- **File Location**: `src/java/dao/SessionContextDao.java` (101 lines)
- **Role**: Populates the operational context (`SessionContext`) required by `RuleEngine.java` via 6 atomic SQL queries (lines 23–98):
  1. *Sensor Bounds*: Retrieves `min_valid` and `max_valid` thresholds from table `SensorType` (lines 24–29).
  2. *Clock Skew & Delay*: Computes upload latency in seconds: `SELECT DATEDIFF(SECOND, measured_at, ingested_at) FROM LockerSession WHERE session_id = ?` (lines 32–40). Negative values denote edge clock running ahead of the server.
  3. *Calibration Liveness*: Validates weight sensor calibration date against session measurement timestamp: `t.name = N'WEIGHT' AND c.valid_until >= CAST(s.measured_at AS DATE)` (lines 43–52).
  4. *Remote Command Validation*: Verifies that remote unlock commands (`PHONE` or `REMOTE`) were issued to the exact device and slot within the allowable time window: `c.command_id = s.command_id AND c.device_id = s.device_id AND c.slot_id = s.slot_id AND c.status = N'SENT'` (lines 56–69).
  5. *Card Ownership & Status*: Queries `UserCard` for card status and owner user ID: `SELECT status, user_id FROM UserCard WHERE card_uid = ?` (lines 72–82).
  6. *Deposit & Plan Allotment*: Queries `Deposit` and `StoragePlan` for active booking owner and allowed duration plus grace period: `DATEDIFF(MINUTE, d.started_at, d.due_at) + p.grace_min` (lines 85–97).

---

### 2.7 Append-Only Ingestion & Slot Disambiguation (`LockerSessionDao.java`)
- **File Location**: `src/java/dao/LockerSessionDao.java` (346 lines)
- **Role**: Handles persistence and querying of locker sessions. Contains strictly append-only operations (`insert()`, `search()`, `list()`, `count()`, `findById()`) with zero `UPDATE` or `DELETE` statements.

```java
// src/java/dao/LockerSessionDao.java, lines 88–129
public long insert(LockerSession s) throws SQLException {
    String sql = "INSERT INTO LockerSession (device_id, device_seq, measured_at, door_open_sec, weight_delta_g, "
            + "unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source, command_id) "
            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    ...
}
```

#### Slot Disambiguation & Idempotency Rules:
- **Slot Ambiguity Resolution (`resolveSlot`, lines 36–82)**: When a physical device manages multiple cabinet banks with overlapping slot codes (e.g., Slot `A01` in Bank 1 and Bank 2), `resolveSlot()` executes deterministic tie-breaking:
  1. Checks `bank_code` if provided in session telemetry. If `bank_code` does not belong to the device, returns `UNKNOWN_BANK` (`-3`).
  2. Matches command slot if `command_id` is present.
  3. If multiple physical slots still match, returns `AMBIGUOUS_SLOT` (`-2`). The backend rejects ambiguous sessions to prevent attributing anomalies to the wrong deposit.
- **Idempotency via Unique Key**: Table `LockerSession` enforces `UNIQUE(device_id, device_seq)`. If a device retransmits buffered sessions, the insert throws SQL Server error `2627` or `2601`, which `insert()` intercepts and returns as `DUPLICATE` (`-1`) without crashing or duplicating data (lines 124–126).

---

### 2.8 Role-Based Access Control & Perimeter Security (`SecurityFilter.java`)
- **File Location**: `src/java/filter/SecurityFilter.java` (226 lines)
- **Role**: Intercepts all incoming HTTP traffic (`/*`) at the servlet container perimeter.

```java
// src/java/filter/SecurityFilter.java, lines 44–48
private static final Set<String> DEVICE_API_PATHS = new HashSet<>(Arrays.asList(
        "/api/health", "/api/locker/batch",
        "/api/device/auth", "/api/device/enroll/start", "/api/device/enroll/finish"));
```

#### Perimeter Enforcement Tiers:
1. **Public Resources** (lines 36–43): Assets (`/css/`, `/js/`, `/img/`), favicon, auth pages (`/LoginController`, `/RegisterController`, `/LogoutController`), and consumer kiosks (`/k`, `/c`).
2. **Device API Key Gating** (lines 147–170): All IoT paths (`/api/health`, `/api/locker/batch`, `/api/device/auth`, `/api/device/enroll/*`) require an `X-API-Key` HTTP header.
   - The key is looked up in the `Device` table via `DeviceDao.findIdByApiKey(apiKey)` (line 150).
   - If missing or invalid, immediately halts request processing and returns HTTP 401 Unauthorized with JSON payload: `{"result":"ERROR","reason":"BAD_API_KEY","message":"Wrong device key"}` (lines 92–96).
   - *Security Invariant*: On valid authentication, the trusted `device_id` is bound to the request attribute (`req.setAttribute("DEVICE_ID", deviceId)`, line 155). The device ID is **never trusted from the JSON request body**.
   - *Admin Bypass*: An authenticated administrator holding web session role `ADMIN` may issue `GET /api/health` without an API key to inspect database ping status (lines 160–166).
3. **Web User RBAC** (lines 172–220): Web controllers require an authenticated session (`Web.currentUser(req)`). Enforces fine-grained permission keys (`READ` for GET, `WRITE` for POST/PUT) mapped via `RESOURCE_BY_PATH` (lines 50–77) against user roles in table `Permissions`.

---

## 3. Database Schema & Persistence Architecture

### 3.1 Baseline Relational Entity Structure
The baseline database schema is established in `sql/01_schema.sql` and updated in `sql/03_v2_v3.sql`. The core tables governing sensor telemetry, access authorization, and audit logs are defined below:

```sql
-- sql/01_schema.sql, lines 70–75
CREATE TABLE SensorType (
    sensor_type_id INT IDENTITY PRIMARY KEY,
    name           NVARCHAR(40),
    unit           NVARCHAR(20),
    min_valid      FLOAT,
    max_valid      FLOAT
);

-- sql/01_schema.sql, lines 120–135
CREATE TABLE AuditLog (
    audit_id      BIGINT IDENTITY PRIMARY KEY,
    actor_user_id INT,
    action        NVARCHAR(50),
    object_type   NVARCHAR(50),
    object_id     BIGINT,
    diff_json     NVARCHAR(MAX),
    ts            DATETIME2(7) DEFAULT SYSUTCDATETIME(),
    row_hash      CHAR(64) NULL
);

CREATE TABLE HashChain (
    anchor_id  BIGINT IDENTITY PRIMARY KEY,
    audit_id   BIGINT REFERENCES AuditLog,
    prev_hash  CHAR(64),
    chain_hash CHAR(64)
);

-- sql/01_schema.sql, lines 138–150; sql/01_schema.sql, lines 228–233
CREATE TABLE LockerSession (
    session_id     BIGINT IDENTITY PRIMARY KEY,
    device_id      INT NOT NULL REFERENCES Device,
    device_seq     INT NOT NULL,                      -- sequence counter from device
    measured_at    DATETIME2 NOT NULL,                -- edge measurement timestamp
    ingested_at    DATETIME2 DEFAULT SYSUTCDATETIME(),-- server arrival timestamp
    door_open_sec  FLOAT,                             -- door contact reed switch duration
    weight_delta_g FLOAT,                             -- HX711 load cell weight delta
    unlock_count   INT,                               -- number of unlocks in session
    rfid_ok        BIT,                               -- credential verification flag
    stay_min       FLOAT,                             -- total stay duration in minutes
    slot_id        INT NULL REFERENCES LockerSlot(locker_slot_id),
    card_uid       NVARCHAR(32) NULL,
    open_source    NVARCHAR(10) NULL,                 -- PIN, RFID, PHONE, REMOTE, FINGERPRINT
    command_id     BIGINT NULL,                       -- associated RemoteCommand
    UNIQUE (device_id, device_seq)
);
```

### 3.2 Tamper-Evident Append-Only Enforcement
To prevent malicious alteration or erasure of telemetry history by insiders or compromised web services, `LockerSession` is protected by an explicit SQL Server trigger enforcing append-only semantics:

```sql
-- sql/01_schema.sql, lines 174–178
CREATE TRIGGER trg_LockerSession_AppendOnly ON LockerSession INSTEAD OF UPDATE, DELETE AS
BEGIN
    RAISERROR(N'Session records are append-only', 16, 1);
END;
```
Any execution of `UPDATE LockerSession` or `DELETE FROM LockerSession` immediately raises SQL Server error level 16, state 1, and terminates the query.

### 3.3 Exact Column Inventory & Missing Baseline Channels
The baseline `SensorType` table is seeded with exactly three sensor configurations:

```sql
-- sql/01_schema.sql, lines 500–501
INSERT INTO SensorType (name, unit, min_valid, max_valid) VALUES
    (N'DOOR', N's', 0, 3600),
    (N'WEIGHT', N'g', -200, 20000),
    (N'STAY', N'min', 0, 10080);
```

| Sensor Name | Measurement Unit | Minimum Valid | Maximum Valid | Purpose |
|---|---|---|---|---|
| `DOOR` | seconds (`s`) | `0.0` | `3600.0` (1 hr) | Door contact open duration |
| `WEIGHT` | grams (`g`) | `-200.0` | `20000.0` (20 kg) | HX711 load cell weight delta |
| `STAY` | minutes (`min`) | `0.0` | `10080.0` (7 days) | Total locker booking stay |

#### Rigorous Baseline Persistence Audit:
1. **SRF05 Ultrasonic Sensor**:
   - `LockerSession` contains **zero columns** for ultrasonic distance, clearance hold time, or presence status (no `sonar_distance_cm`, `presence_detected`, etc.).
   - `SensorType` contains **zero rows** for ultrasonic sensors.
2. **IMU Vibration / Tilt Sensor**:
   - `LockerSession` contains **zero columns** for acceleration, vibration, shock count, or tilt angles (no `imu_vibration`, `accel_x`, `tilt_deg`, etc.).
   - `SensorType` contains **zero rows** for IMU sensors.
3. **Generic Reading Table (`LockerSessionReading`)**:
   - While `sql/01_schema.sql` (lines 157–163) declares an auxiliary table `LockerSessionReading (reading_id, session_id, sensor_type_id, measured_at, value)`, direct code analysis confirms that **no Java class, DAO, or controller in the entire codebase reads, writes, or references `LockerSessionReading`**. It remains completely dormant in baseline.

---

## 4. API Contract Specifications

### 4.1 Device Heartbeat & Dynamic Polling (`POST /api/health`)
- **Controller**: `src/java/api/HealthApi.java`
- **Cadence**: Called periodically every 3 seconds (`INTERVAL_SEC = 3`, line 51) by physical firmware and simulators.
- **Protocol**: Unidirectional command queue polling; the server never initiates inbound connections to edge boxes.

#### Headers:
- `Content-Type: application/json`
- `X-API-Key: <DEVICE_API_KEY>` (Mandatory, verified by `SecurityFilter`)

#### Request JSON Schema:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "firmware": { "type": "string", "example": "4.3" },
    "uptime_sec": { "type": "integer", "minimum": 0, "example": 1234 },
    "nfc": { "type": "boolean", "example": true }
  },
  "required": ["firmware", "uptime_sec"]
}
```

#### Response JSON Schema (HTTP 200 OK):
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "interval_sec": { "type": "integer", "enum": [3] },
    "commands": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "command_id": { "type": "integer" },
          "action": { "type": "string", "enum": ["UNLOCK", "DELETE_FP", "CANCEL_ENROLL"] },
          "slot_code": { "type": "string", "example": "A04" },
          "open_sec": { "type": "integer", "example": 8 },
          "phase": { "type": "string", "enum": ["CHECK_IN", "ACCESS", "PICKUP"] },
          "message": { "type": "string", "example": "Open\n(phone)" },
          "physical": { "type": "boolean" },
          "sensor_slot": { "type": "integer", "minimum": 1, "maximum": 160 }
        },
        "required": ["command_id", "action"]
      }
    },
    "server_time": { "type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$" },
    "blocked_cards": { "type": "array", "items": { "type": "string" } },
    "reserved": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "slot_code": { "type": "string" },
          "card_uid": { "type": "string" }
        },
        "required": ["slot_code", "card_uid"]
      }
    },
    "tap_path": { "type": "string", "example": "/k/LOCKER-01?n=Ab3dEf7hJk2m" }
  },
  "required": ["interval_sec", "commands", "server_time", "blocked_cards", "reserved"]
}
```

#### HTTP Status Codes & Error Payloads:
- `200 OK`: Successful heartbeat and command retrieval.
- `400 Bad Request`: Payload missing or malformed JSON body (`{"result":"ERROR","reason":"BAD_REQUEST","message":"Bad request data"}`).
- `401 Unauthorized`: Missing or unmapped `X-API-Key` (`{"result":"ERROR","reason":"BAD_API_KEY","message":"Wrong device key"}`).
- `500 Internal Server Error`: SQL Server execution exception during command queue processing (`{"result":"ERROR","reason":"SERVER_ERROR","message":"Server error"}`).

---

### 4.2 Multi-Modal Credential Authorization (`POST /api/device/auth`)
- **Controller**: `src/java/api/DeviceAuthApi.java`
- **Role**: Centralized server-side credential verification for physical keypad PINs, RFID cards, and AS608 optical fingerprint templates.

#### Headers:
- `Content-Type: application/json`
- `X-API-Key: <DEVICE_API_KEY>` (Mandatory)

#### Request JSON Schema (Multi-Modal Discriminated Union):
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "method": { "type": "string", "enum": ["PIN", "CARD", "FINGERPRINT"] },
    "pin": { "type": "string", "pattern": "^\\d{6}$" },
    "card_uid": { "type": "string", "pattern": "^[0-9A-F]{4,20}$" },
    "sensor_slot": { "type": "integer", "minimum": 1, "maximum": 160 },
    "intent": { "type": "string", "enum": ["ASK", "OPEN", "CHECKOUT"] }
  },
  "required": ["method"]
}
```

#### Response Decisions (HTTP 200 OK):
1. **Decision: `UNLOCK`** (Actuate Servo / Release Latch):
   ```json
   {
     "result": "UNLOCK",
     "phase": "CHECK_IN", // or "ACCESS" or "PICKUP"
     "deposit_id": 120,
     "slot_code": "A04",
     "open_sec": 8,
     "overdue_fee": 0,
     "physical": true,
     "message": "Store your items\nSlot A04"
   }
   ```
2. **Decision: `CHOOSE`** (Active Multi-Access Dialogue):
   Returned when `intent = "ASK"` on an active booking, prompting user to choose intermediate access or final checkout.
   ```json
   {
     "result": "CHOOSE",
     "deposit_id": 120,
     "slot_code": "A04",
     "choose_sec": 15,
     "options": ["OPEN", "CHECKOUT"],
     "message": "A: Open * cancel\nB: Checkout A04"
   }
   ```
3. **Decision: `CONFIRM_EMAIL`** (Two-Factor Stepped Verification):
   Returned for card taps requiring two-factor email verification.
   ```json
   {
     "result": "CONFIRM_EMAIL",
     "phase": "PICKUP",
     "deposit_id": 120,
     "slot_code": "A04",
     "confirm_sec": 300,
     "message": "Confirm in your\ne-mail or web"
   }
   ```
4. **Decision: `DENY`** (Rejection & Rate Limiting):
   ```json
   {
     "result": "DENY",
     "reason": "WRONG_CODE", // or "LOCKED_OUT", "OVERDUE_UNPAID", "WRONG_PLACE"
     "attempts_left": 3,
     "retry_after_sec": 0,
     "message": "Wrong PIN\n3 tries left"
   }
   ```

#### Rate Limiting & Lockout Policy:
- Governed by stored procedure `Auth_Log` and `Auth_LockCheck` (`sql/03_v2_v3.sql`, lines 369–414).
- **Threshold**: Exactly **5 consecutive failed attempts** within a rolling 5-minute window (`ok = 0 AND reason IN ('WRONG_CODE', 'UNKNOWN_CARD', 'UNKNOWN_FINGER', 'BAD_CODE')`).
- **Lockout Action**: Transitions channel to `LOCK_START`, enforcing a **120-second lockout timer** (`SET @retry = 120`). During lockout, all credentials immediately return `{"result":"DENY","reason":"LOCKED_OUT","retry_after_sec":<remaining_seconds>}`.

---

### 4.3 Batch Telemetry Ingestion & Idempotency (`POST /api/locker/batch`)
- **Controller**: `src/java/api/LockerSessionApi.java`
- **Role**: High-throughput batch telemetry ingestion for offline-buffered locker sessions.

#### Headers:
- `Content-Type: application/json`
- `X-API-Key: <DEVICE_API_KEY>` (Mandatory)

#### Request JSON Schema:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "device_id": { "type": "integer" },
    "sessions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "seq": { "type": "integer" },
          "measured_at": { "type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$" },
          "door_open_sec": { "type": "number" },
          "weight_delta_g": { "type": "number" },
          "unlock_count": { "type": "integer" },
          "rfid_ok": { "type": ["boolean", "number"] },
          "stay_min": { "type": "number" },
          "slot_code": { "type": "string" },
          "bank_code": { "type": "string" },
          "card_uid": { "type": "string" },
          "open_source": { "type": "string", "enum": ["PIN", "PHONE", "CARD", "FINGERPRINT", "REMOTE", "RFID"] },
          "command_id": { "type": ["integer", "null"] }
        },
        "required": ["seq", "measured_at", "door_open_sec", "weight_delta_g", "unlock_count", "rfid_ok", "stay_min"]
      }
    }
  },
  "required": ["sessions"]
}
```

#### Response JSON Schema (HTTP 200 OK):
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "saved": { "type": "integer", "minimum": 0 },
    "duplicates": { "type": "integer", "minimum": 0 },
    "rejected": { "type": "integer", "minimum": 0 },
    "errors": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "seq": { "type": ["integer", "null"] },
          "code": { "type": "string", "enum": ["BAD_SESSION", "AMBIGUOUS_SLOT", "UNKNOWN_BANK"] }
        },
        "required": ["seq", "code"]
      }
    }
  },
  "required": ["saved", "duplicates", "rejected", "errors"]
}
```

#### Deduplication & Error Codes:
1. **Deduplication (`duplicates`)**: Sessions sharing an existing `(device_id, device_seq)` encounter SQL Server unique key collisions (error 2627/2601) in `LockerSessionDao.insert()`. The controller catches this, increments `duplicates`, and continues processing without throwing HTTP 500.
2. **Error `BAD_SESSION`**: Malformed JSON types or unparseable timestamps increment `rejected` and append `{"seq": <seq>, "code": "BAD_SESSION"}`.
3. **Error `AMBIGUOUS_SLOT`**: If `slot_code` exists in multiple banks under the device and no `bank_code` or `command_id` disambiguates it, `resolveSlot()` returns `AMBIGUOUS_SLOT` (`-2`), incrementing `rejected`.
4. **Error `UNKNOWN_BANK`**: If `bank_code` does not exist on the device, returns `UNKNOWN_BANK` (`-3`), incrementing `rejected`.

---

## 5. 5-Stage Sensor Integration Matrix

### 5.1 Definition of the 5 Integration Stages
To rigorously establish sensor integration compliance across physical hardware, simulation modules, network serialization, database storage, and anomaly evaluation, we establish 5 distinct engineering stages:

1. **Stage 1 (Client/Firmware Implemented)**: Physical sensor hardware interface, ADC transduction, or software noise/transduction emulator implemented (`firmware/` or `simulator/sensors/`).
2. **Stage 2 (Payload Generated)**: Telemetry captured, encoded, and serialized into batch session JSON objects.
3. **Stage 3 (Transmitted over Network)**: Telemetry successfully transported via HTTP POST REST API (`/api/locker/batch`) to the Java backend.
4. **Stage 4 (Persisted in DB)**: Java backend parses telemetry and commits values to physical relational columns in SQL Server table `LockerSession`.
5. **Stage 5 (Evaluated by Engines)**: Persisted measurements are actively parsed and evaluated by `RuleEngine.java` (deterministic security invariants) or `RiskScorer.java` (Weka ML anomaly scoring).

---

### 5.2 Comprehensive Verification Matrix

The baseline architecture (Baseline B0) reflects the actual capabilities of the Java backend, SQL Server schema, and firmware:

| Sensor Channel | Physical / Simulated Mechanism | S1: Client / Firmware | S2: Payload Gen | S3: Network Tx | S4: DB Persist (`LockerSession`) | S5: Engine Eval (`RuleEngine` / `RiskScorer`) | Overall Integration Status |
|---|---|:---:|:---:|:---:|:---:|:---:|---|
| **Door Reed Switch** | Magnetic door contact (`door_open_sec`) | **PASS** | **PASS** | **PASS** | **PASS** | **PASS** | **INTEGRATED (5/5 PASS)** |
| **HX711 Load Cell** | Strain gauge scale (`weight_delta_g`) | **PASS** | **PASS** | **PASS** | **PASS** | **PASS** | **INTEGRATED (5/5 PASS)** |
| **SRF05 Ultrasonic** | 40 kHz sonar transceiver (`sonar_distance_cm`) | **PASS** | **PASS** | **PASS** | **FAIL** | **FAIL** | **NOT INTEGRATED in Baseline Backend (3/5 PASS, S4/S5 FAIL)** |
| **MPU6050 IMU** | 3-axis accelerometer / gyro (`imu_vibration`) | **PASS** | **PASS** | **PASS** | **FAIL** | **FAIL** | **NOT INTEGRATED in Baseline Backend (3/5 PASS, S4/S5 FAIL)** |

---

### 5.3 Detailed Breakdown by Sensor Channel

#### 1. Door Reed Switch (`door_open_sec`)
- **Stage 1 (PASS)**: Physical edge detection via interrupt pin and simulated in `simulator/sensors/reed_switch.py`.
- **Stage 2 (PASS)**: Serialized as `door_open_sec` float in batch JSON.
- **Stage 3 (PASS)**: Ingested via `POST /api/locker/batch`.
- **Stage 4 (PASS)**: Persisted to `LockerSession.door_open_sec` (`FLOAT`, line 144 in `sql/01_schema.sql`).
- **Stage 5 (PASS)**: Evaluated by `RuleEngine.java`:
  - `FORCED_OPEN` (line 52): `!s.isRfidOk() && s.getDoorOpenSec() > 0`
  - `SUSPECTED_SPOOF` (line 61): `s.getDoorOpenSec() == 0 && Math.abs(s.getWeightDeltaG()) > 50`
  - `findSensorFault` (line 78): `!ctx.inRange("DOOR", s.getDoorOpenSec())`
  - Evaluated in `RiskScorer.java` (line 91).

#### 2. HX711 Load Cell (`weight_delta_g`)
- **Stage 1 (PASS)**: Simulated via `simulator/sensors/load_cell.py`.
- **Stage 2 (PASS)**: Serialized as `weight_delta_g` float in batch JSON.
- **Stage 3 (PASS)**: Ingested via `POST /api/locker/batch`.
- **Stage 4 (PASS)**: Persisted to `LockerSession.weight_delta_g` (`FLOAT`, line 145 in `sql/01_schema.sql`).
- **Stage 5 (PASS)**: Evaluated by `RuleEngine.java`:
  - `ITEM_LEFT` (line 65): `s.getWeightDeltaG() > 50.0`
  - `SUSPECTED_SPOOF` (line 61): `s.getDoorOpenSec() == 0 && Math.abs(s.getWeightDeltaG()) > 50`
  - `findSensorFault` (line 81): `!ctx.inRange("WEIGHT", s.getWeightDeltaG())`
  - Evaluated in `RiskScorer.java` (line 92).

#### 3. SRF05 Ultrasonic Sensor (`sonar_distance_cm`)
- **Stage 1 (PASS)**: Implemented in physical ESP32 firmware (`SONAR_TRIG = 5`, `SONAR_ECHO = 18`) and simulated in `simulator/sensors/ultrasonic.py`.
- **Stage 2 (PASS)**: Generated and serialized in simulation batch payloads.
- **Stage 3 (PASS)**: Transmitted over network in simulated test payloads.
- **Stage 4 (FAIL)**: **Not persisted in baseline backend**. Table `LockerSession` possesses no column for sonar distance or clearance status. `LockerSessionApi.java` (lines 48–67) parses only baseline fields and completely ignores sonar fields.
- **Stage 5 (FAIL)**: **Not evaluated in baseline engines**. Neither `RuleEngine.java` nor `RiskScorer.java` contains any logic, branch, or feature mapping for ultrasonic telemetry.

#### 4. MPU6050 IMU Vibration / Tilt Sensor (`imu_vibration`)
- **Stage 1 (PASS)**: Implemented in simulation (`simulator/sensors/imu_vibration.py`). Absent on physical ESP32 board.
- **Stage 2 (PASS)**: Generated and serialized in simulation batch payloads.
- **Stage 3 (PASS)**: Transmitted over network in simulated test payloads.
- **Stage 4 (FAIL)**: **Not persisted in baseline backend**. Table `LockerSession` possesses no columns for vibration, shock, or tilt.
- **Stage 5 (FAIL)**: **Not evaluated in baseline engines**. Neither `RuleEngine.java` nor `RiskScorer.java` evaluates IMU vibration or shock.

---

## 6. Firmware 4.3-esp32 SRF05 Physical Implementation vs. Simulation Reality

### 6.1 Physical Pinout, Circuitry & Timing Logic
The physical edge firmware implementation is located in `firmware/SmartLocker_Online/SmartLocker_Online.ino`.

```cpp
// firmware/SmartLocker_Online/SmartLocker_Online.ino, lines 71–85
static constexpr int SONAR_TRIG = 5, SONAR_ECHO = 18;  // ECHO through the 1k / 2k divider (the SRF05 echo is 5 V)
static constexpr int NEAR_CM = 50;                     // someone this close wakes the backlight
static constexpr int DOORWAY_CM = 50;                  // someone this close still uses the open box: lock countdown waits
static constexpr int SONAR_MAX_CM = 100;               // farther, or no echo, is nobody; bounds pulseIn() wait (~7 ms)
static constexpr uint32_t DOOR_OPEN_MS = 20000;        // automatic lock countdown (20 s) after user leaves doorway
static constexpr uint32_t DOOR_OPEN_MAX_MS = 120000;   // failsafe absolute close timeout (120 s)
static constexpr uint32_t SCREEN_OFF_MS = 60000;       // LCD backlight sleep timeout (60 s idle)
```

#### Hardware Electrical Interfacing:
- **Trigger Pin**: `GPIO 5` (Output). Driven HIGH for $10\ \mu\text{s}$ to trigger ultrasonic burst (lines 285–287).
- **Echo Pin**: `GPIO 18` (Input). Connected through an external $1\text{ k}\Omega / 2\text{ k}\Omega$ resistor voltage divider. Because the SRF05 operates at $5\text{ V}\ V_{CC}$, its ECHO pin outputs a $5\text{ V}$ pulse. The resistive divider scales the ECHO voltage:
  $$V_{GPIO18} = 5\text{ V} \times \frac{2\text{ k}\Omega}{1\text{ k}\Omega + 2\text{ k}\Omega} = 3.33\text{ V}$$
  This safely matches the ESP32 $3.3\text{ V}$ maximum GPIO tolerance without risking silicon degradation.
- **Acoustic Calculation & Timeout**:
  ```cpp
  // lines 289–291
  long us = pulseIn(SONAR_ECHO, HIGH, SONAR_MAX_CM * 58UL + 2500);
  long cm = us / 58;
  lastCm = (us == 0 || cm < 2) ? -1 : cm;
  ```
  Based on the speed of sound in air ($343\text{ m/s} \approx 29.1\ \mu\text{s/cm}$ round-trip $\times 2 = 58.2\ \mu\text{s/cm}$), pulse duration is divided by 58. Sampling occurs every $150\text{ ms}$ (`millis() - lastSonar < 150`, line 281).

---

### 6.2 Edge State Machine & Presence Actuation

The physical firmware couples ultrasonic presence readings directly to two edge automation state machines:

```
                      +-----------------------------+
                      |   LCD Backlight Off (Sleep) |
                      +--------------+--------------+
                                     |
               someoneWithin(50 cm)  |  millis() - lastActivity >= 60000 ms
               [NEAR_CM = 50]        |  [SCREEN_OFF_MS = 60000]
                                     v
                      +-----------------------------+
                      |   LCD Backlight On (Active) |
                      +-----------------------------+

                      +-----------------------------+
                      |      Door Open Actuated     |
                      |  Servo Bolt: 85 deg         |
                      |  Servo Door: 180 deg        |
                      +--------------+--------------+
                                     |
                                     +<-----------------------------+
                                     |                              |
               someoneWithin(50 cm)  |                              | User steps away
               [DOORWAY_CM = 50]     v                              | (clearSince = now)
                      +-----------------------------+               |
                      | Auto-Lock Countdown PAUSED  |               |
                      | clearSince = 0              |               |
                      | LCD: "Someone near..."      |               |
                      +--------------+--------------+               |
                                     |                              |
                                     +------------------------------+
                                     |
               User cleared for 20 s | or Absolute Failsafe Elapsed
               (now - clearSince >= 20000 ms) | (now - openedAt >= 120000 ms)
                                     v
                      +-----------------------------+
                      |     closeDoor() Actuated    |
                      |  Servo Door: 0 deg          |
                      |  Servo Bolt: 0 deg          |
                      |  LCD: "Door locked"         |
                      +-----------------------------+
```

1. **LCD Display Power Management (`handleScreen()`, lines 723–734)**:
   - When a user enters proximity $\le 50\text{ cm}$ (`someoneWithin(NEAR_CM)`), the LCD backlight illuminates (`setScreen(true)`).
   - If the locker remains idle with no user present and no keypad input for 60 seconds (`SCREEN_OFF_MS = 60000`), the backlight turns off to conserve power.
2. **Context-Aware Smart Auto-Locking (`doorTick()`, lines 350–367)**:
   - Upon unlocking, the servo latch releases (`SERVO_BOLT_PIN = 85^\circ`) and sweeps open (`SERVO_DOOR_PIN = 180^\circ`).
   - If the user is loading or unloading parcels within $50\text{ cm}$ (`someoneWithin(DOORWAY_CM)`), the lock countdown is paused (`clearSince = 0`), and the LCD displays: `Press D to lock\nSomeone near...`.
   - Once the user steps back ($>50\text{ cm}$), a 20-second auto-lock countdown begins (`DOOR_OPEN_MS = 20000`), showing: `Press D to lock\nLocks in ..s`.
   - **Absolute Failsafe Safety Invariant**: If a sensor is blocked, disconnected, or vandalized, an absolute failsafe timer triggers closure at exactly 120 seconds (`DOOR_OPEN_MAX_MS = 120000`), forcing door closure regardless of sonar readings.

---

### 6.3 Physical Firmware vs. Research Simulation Testbed

#### Mandatory Integrity Disclosure:
A rigorous forensic audit of the physical ESP32 firmware source code (`firmware/SmartLocker_Online/SmartLocker_Online.ino`) reveals the following architectural reality:

1. **Firmware Network Surface**:
   - The ESP32 firmware invokes only three server endpoints:
     - `POST /health` (via `postJson("/health", ...)` at line 492)
     - `POST /device/auth` (via `postJson("/device/auth", ...)` at line 529)
     - `POST /device/enroll/*` (via `postJson(path, ...)` at line 564)
   - **The firmware NEVER calls `/api/locker/batch`**.
   - **The firmware NEVER transmits ultrasonic distance telemetry (`sonar_distance_cm`) or load telemetry over the network**.
2. **Origin of Multi-Sensor Batch Telemetry**:
   - All multi-sensor batch sessions evaluated in experimental research campaigns originate exclusively from the **software simulation testbed** (`simulator/`, `experiments/`).
   - The simulation testbed generates multi-sensor batches adhering to the empirical distributions, noise profiles, and failure modes observed in physical locker deployments.
3. **Publication Integrity Mandate**:
   - Research manuscripts, technical documentation, and compliance matrices must **explicitly state** that multi-sensor access control evaluations are conducted on a validated, reproducible software simulation framework. Under no circumstances should simulation data be presented as physical hardware measurements.

---

## 7. Automated Verification & Integrity Assertion

To guarantee that the backend architecture, database schema, API contracts, and integration matrix remain strictly synchronized with the codebase, an automated verification script is provided at `tests/verify_m2_backend_matrix.py`.

The script programmatically parses:
- Source code structures and line citations across Java backend files (`RuleEngine.java`, `RiskScorer.java`, `AlertService.java`, `AuditVerifier.java`, `DbContext.java`, `SessionContextDao.java`, `LockerSessionDao.java`, `SecurityFilter.java`, `HealthApi.java`, `DeviceAuthApi.java`, `LockerSessionApi.java`).
- Database schema and trigger definitions in `sql/01_schema.sql` and `sql/03_v2_v3.sql`.
- Firmware hardware pins, ultrasonic logic, and timing thresholds in `firmware/SmartLocker_Online/SmartLocker_Online.ino`.
- 5-stage tracking logic in `simulator/tracking/matrix.py` and `simulator/tracking/stage_tracker.py`.
- Complete structure, tables, and claims within this document (`FINAL_BACKEND_ARCHITECTURE.md`).

Execution Command:
```powershell
python tests/verify_m2_backend_matrix.py
```
A clean exit code `0` confirms complete architectural compliance without hardcoded facades or integrity discrepancies.
