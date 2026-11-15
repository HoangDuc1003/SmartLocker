# FINAL_EXPERIMENTAL_METHODOLOGY.md: SmartLocker Software-Based Reproducible Multi-Sensor Evaluation Methodology

**Document Version**: 2.0 (Milestone 4 — Requirement R4)  
**Standard**: Forensic Audit & Scopus Scientific Publication Readiness  
**Target Specifications**: User Request R4 & R7, Feature Inventory Items 13, 14, 15  
**Repository**: `HoangDuc1003/SmartLocker`  
**Git Branch**: `research/audit-scopus-revision`  
**Date**: 2026-11-15T22:45:00Z  

---

## Table of Contents
1. [Executive Summary & Scientific Paradigm](#1-executive-summary--scientific-paradigm)
2. [Experimental System Architecture & Infrastructure](#2-experimental-system-architecture--infrastructure)
3. [5-Stage Sensor Integration & Boundary Separation](#3-5-stage-sensor-integration--boundary-separation)
4. [Stratified Experimental Scenarios & Workload Composition](#4-stratified-experimental-scenarios--workload-composition)
5. [Simulation Mechanics, PRNG Seeds & Stochastic Distributions](#5-simulation-mechanics-prng-seeds--stochastic-distributions)
6. [Physical Transducer Boundaries & Detection Invariants](#6-physical-transducer-boundaries--detection-invariants)
7. [Baseline & Multi-Sensor Detector Specifications](#7-baseline--multi-sensor-detector-specifications)
8. [Haber-Stornetta Cryptographic Audit Hash-Chaining Protocol](#8-haber-stornetta-cryptographic-audit-hash-chaining-protocol)
9. [Evidence Preservation & Directory Layout Architecture](#9-evidence-preservation--directory-layout-architecture)
10. [Step-by-Step Reproducibility & Execution Protocol](#10-step-by-step-reproducibility--execution-protocol)
11. [Statistical & Validation Quality Assurance Framework](#11-statistical--validation-quality-assurance-framework)

---

## 1. Executive Summary & Scientific Paradigm

### 1.1 Repositioning the Research
This research paper evaluates context-aware multi-sensor access control and anomaly detection for IoT smart locker banks. Prior versions of the manuscript conflated physical hardware bench evaluations with software-based evaluations. Under Requirement R4 of the comprehensive research audit, the scientific paradigm of the repository is formally repositioned:
1. **Physical Prototype Constraints**: The physical ESP32 prototype (`firmware/4.3-esp32`) implements edge-level presence sensing using an HC-SR04/SRF05 ultrasonic transducer (GPIO 5 TRIG / GPIO 18 ECHO) strictly for local display backlight control and power-saving auto-lock countdown delays. It does not stream multi-sensor batch telemetry across the network.
2. **Software-Based Reproducible Evaluation Testbed**: To conduct exhaustive, statistically robust evaluations across multi-modal access attempts, structural tampering, forced physical breaches, and environmental sensor dropouts, the repository employs a validated Python simulation framework (`simulator/`, `experiments/`). This testbed transmits genuine HTTP REST API payloads to the live Java Servlet backend (Apache Tomcat 9 on port 8081) backed by Microsoft SQL Server 2022 (`SL_SIM`).
3. **Absolute Epistemic Independence**: As proven and enforced in Milestone 3, all baseline and proposed detectors operate with **zero ground-truth leakage**. Detector B1 inspects strictly observable runtime parameters (payload timestamps, electrical bounds, sequence numbers, network latencies, and server-issued authentication responses) without access to oracle metadata (`fault_type`, `seq_gap`, `seq_duplicate`, or ground-truth class labels).

---

## 2. Experimental System Architecture & Infrastructure

### 2.1 Component Topology
The experimental evaluation infrastructure consists of three interacting subsystems:

```
+-----------------------------------------------------------------------------------+
|                           EXPERIMENTAL TESTBED TOPOLOGY                           |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  +---------------------------+              +----------------------------------+  |
|  |     Simulated Device      |              |        Java Web Backend          |  |
|  |   (`simulator/esp32.py`)  |              |    (Apache Tomcat 9.0.113)       |  |
|  |                           |              |                                  |  |
|  | - VirtualESP32 FSM        |  HTTP POST   | - Port 8081 / SmartLocker        |  |
|  | - Transducer Generators   | ------------>| - SecurityFilter & API Auth      |  |
|  | - Hierarchical PRNG Seeds |              | - DeviceAuthApi & LockerSessionApi|  |
|  | - Batch Telemetry Buffers |              | - RuleEngine & RiskScorer (Weka) |  |
|  +---------------------------+              +----------------------------------+  |
|                |                                              |                   |
|                | Raw Traces                                   | SQL (Port 1433)   |
|                v                                              v                   |
|  +---------------------------+              +----------------------------------+  |
|  |    Evidence Vault         |              |       Relational Database        |  |
|  | (`experiments/results/`)  |<-------------|   (Microsoft SQL Server 2022)    |  |
|  |                           |  Query Log   |                                  |  |
|  | - sessions.json / csv     |              | - Database: SL_SIM               |  |
|  | - backend_requests.jsonl  |              | - LockerSession (Append-Only)    |  |
|  | - backend_responses.jsonl |              | - AuditLog & HashChain (SHA-256) |  |
|  | - evaluation_metrics.json |              | - Trigger: trg_LockerSession     |  |
|  +---------------------------+              +----------------------------------+  |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

### 2.2 Host Environment Specifications
- **Operating System**: Microsoft Windows 11 Enterprise / Server x86_64
- **Java Runtime**: Oracle JDK 1.8.0_202 / OpenJDK 17.0.9
- **Servlet Container**: Apache Tomcat 9.0.113 (`C:\sl-wt\tomcat-8081`) listening on HTTP `8081`, shutdown `8015`
- **Database Engine**: Microsoft SQL Server 2022 Enterprise (`MSSQLSERVER` on port 1433), database `SL_SIM`
- **Python Environment**: Python 3.11.9 with standard library (`math`, `hashlib`, `json`, `csv`, `urllib`, `random`)

### 2.3 API Interface Contracts
The simulated edge client interacts with the Java backend via four strict JSON API endpoints:
1. `POST /api/health`
   - Headers: `X-API-Key: device-1-api-key`, `Content-Type: application/json`
   - Payload: `{"firmware": "4.3-esp32", "uptime_sec": int, "nfc": bool}`
   - Response: `{"status": "OK", "interval_sec": 3, "server_time": "YYYY-MM-DD HH:MM:SS", "blocked_cards": [...], "reserved": [...]}` (HTTP 200)
2. `POST /api/device/auth`
   - Headers: `X-API-Key: device-1-api-key`, `Content-Type: application/json`
   - Payload: `{"method": "PIN"|"CARD"|"FINGERPRINT", "credential": str, "slot_code": str, "bank_code": str, "intent": "OPEN"}`
   - Response: `{"result": "UNLOCK"|"DENY", "phase": "ACCESS"|"PICKUP", "deposit_id": int, "slot_code": str, "message": str}` (HTTP 200 or 401/403/500)
3. `POST /api/locker/batch`
   - Headers: `X-API-Key: device-1-api-key`, `Content-Type: application/json`
   - Payload: `{"device_id": 5, "sessions": [{"seq": int, "measured_at": str, "door_open_sec": float, "weight_delta_g": float, "unlock_count": int, "rfid_ok": bool, "stay_min": float, "slot_code": str, "bank_code": str, "card_uid": str|null, "open_source": str, "command_id": null}]}`
   - Response: `{"status": "OK", "ingested": int, "duplicates": int}` (HTTP 200)
4. `POST /api/kiosk/unlock`
   - Headers: `X-API-Key: device-1-api-key`, `Content-Type: application/json`
   - Payload: `{"token": str, "intent": "OPEN"}`
   - Response: `{"result": "UNLOCK"|"DENY", "slot_code": str}` (HTTP 200)

---

## 3. 5-Stage Sensor Integration & Boundary Separation

To ensure absolute scientific transparency, each sensor channel is formally evaluated against the 5 engineering integration stages:
1. **Stage 1 (Hardware Sourced)**: Physical sensor transducer circuit connected to microcontroller GPIO/ADC.
2. **Stage 2 (Firmware Payload)**: Firmware reads transducer, constructs data structure or runs edge logic.
3. **Stage 3 (Network Transmitted)**: Edge device serializes telemetry into HTTP JSON payload and transmits over network.
4. **Stage 4 (Database Persisted)**: Backend servlets parse payload and insert rows into relational database table.
5. **Stage 5 (Backend Processed)**: Backend inference engine (`RuleEngine`, `RiskScorer`) executes anomaly rules on stored features.

### Table I: 5-Stage Sensor Integration Matrix
| Sensor Channel | Stage 1: Hardware | Stage 2: Firmware | Stage 3: Network | Stage 4: Persisted | Stage 5: Processed | Overall System Status | Scientific Evaluation Mode |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **Door Reed Switch** | PASS | PASS | PASS | PASS | PASS | Fully Integrated (5/5) | Live Backend & Physical ESP32 |
| **HX711 Load Cell** | PASS | PASS | PASS | PASS | PASS | Fully Integrated (5/5) | Live Backend & Physical ESP32 |
| **SRF05 Ultrasonic** | PASS | PASS | FAIL | FAIL | FAIL | Edge-Only Presence (2/5) | Evaluated via Simulation Testbed |
| **MPU6050 IMU (Vib/Tilt)**| PASS | PASS | FAIL | FAIL | FAIL | Edge-Only Prototype (2/5) | Evaluated via Simulation Testbed |

**Boundary Disclosure**:
The physical ESP32 firmware 4.3 uses the SRF05 ultrasonic sensor strictly at the edge to detect human approach ($\le 50\text{ cm}$) to trigger the LCD backlight and pause auto-lock timers. Multi-sensor cross-validation (ultrasonic acoustic cutoffs, structural tilt, mechanical shock) is evaluated through the reproducible simulation testbed.

---

## 4. Stratified Experimental Scenarios & Workload Composition

The benchmark suite consists of exactly 100 sessions stratified across 5 operational categories ($N = 20$ each), pre-labeled by `ScenarioOracle`:

```
+------------------------------------------------------------------------------------+
|               100 STRATIFIED EXPERIMENTAL EVALUATION SESSIONS                      |
+------------------------------------------------------------------------------------+
| [Cat 1] NORMAL_AUTHORIZED       (Sessions  1 - 20):  20 Authorized access events   |
| [Cat 2] UNAUTHORIZED_CREDENTIAL (Sessions 21 - 40):  20 Credential attack attempts |
| [Cat 3] FORCED_DOOR_OPEN        (Sessions 41 - 60):  20 Physical breach attempts   |
| [Cat 4] LOAD_OR_TAMPER_ANOMALY  (Sessions 61 - 80):  20 Structural tamper events   |
| [Cat 5] SENSOR_FAULT            (Sessions 81 - 100): 15 Sensor + 5 Network faults  |
+------------------------------------------------------------------------------------+
```

### 4.1 Detailed Category Workload Specifications

#### Category 1: `NORMAL_AUTHORIZED` (Sessions `SIM-SESS-001` to `020`)
- **Operational Objective**: Baseline legitimate parcel deposit and pickup operations.
- **Access Modes**: PIN (60%), RFID Mifare Card (25%), Optical Fingerprint (15%).
- **Credential Universe**: Active PINs `952705`, `320357`, `632262`; User Cards `04A1B2C3`, `0499AABB`, `04C3D4E5`; Fingerprint slots `1, 2, 5`.
- **Physical Dynamics**:
  - `door_open_sec` $\sim \mathcal{U}(4.5, 12.0)$ s
  - `weight_delta_g` $\sim \mathcal{U}(-150.0, 450.0)$ g
  - `stay_min` $\sim \mathcal{U}(5.0, 30.0)$ min
  - `ultrasonic_dist_cm` $\sim \mathcal{U}(15.0, 45.0)$ cm
  - `vibration_intensity` $\sim \mathcal{U}(0.01, 0.08)$ G
  - `tilt_deg` $\sim \mathcal{U}(0.1, 0.9)^\circ$
  - `shock_mag_g` $\sim \mathcal{U}(0.95, 1.05)$ G
  - `rfid_ok` = `True`
- **Expected Outcome**: `auth_result = "UNLOCK"`, Ground Truth = `NORMAL_USAGE`.

#### Category 2: `UNAUTHORIZED_CREDENTIAL` (Sessions `SIM-SESS-021` to `040`)
- **Operational Objective**: Evaluate defense against brute-force attacks, stolen cards, and unauthorized biometric attempts.
- **Variations**:
  - `WRONG_PIN` (Sessions 21–25): PINs `000000`, `111111`, `999999`.
  - `BLOCKED_CARD` (Sessions 26–30): Stolen/lost cards `04DE0012`, `C15C039D`.
  - `UNKNOWN_CARD` (Sessions 31–35): Unregistered cards `04BAD001`, `DEADBEEF`.
  - `INVALID_FP` (Sessions 36–40): Unregistered fingerprint slots `161`, `200`, `999`.
- **Physical Invariants**: `door_open_sec = 0.0` s, `weight_delta_g = 0.0` g, `rfid_ok = False`.
- **Expected Outcome**: `auth_result = "DENY"`, Ground Truth = `UNAUTHORIZED_ACCESS`.

#### Category 3: `FORCED_DOOR_OPEN` (Sessions `SIM-SESS-041` to `060`)
- **Operational Objective**: Detect violent perimeter breaches where the door is forced open without electronic unlock authorization.
- **Breach Mechanisms**:
  - `CROWBAR_PRY` (Sessions 41–48): Vibration $0.65 - 1.85\text{ G}$, Tilt $3.5 - 7.5^\circ$, Shock $12.0 - 15.5\text{ G}$, Door open $3.0 - 14.0\text{ s}$.
  - `DOOR_KICK` (Sessions 49–54): Vibration $1.20 - 2.50\text{ G}$, Tilt $4.0 - 9.0^\circ$, Shock $14.0 - 22.0\text{ G}$, Door open $5.0 - 16.0\text{ s}$.
  - `LOCK_PICK` (Sessions 55–60): Vibration $0.62 - 1.10\text{ G}$, Tilt $1.0 - 3.0^\circ$, Shock $4.0 - 8.0\text{ G}$, Door open $4.0 - 12.0\text{ s}$.
- **Physical Invariants**: `door_open_sec > 0.0` s, `rfid_ok = False`, `auth_method = "NONE"`.
- **Expected Outcome**: `auth_result = "DENY"`, Ground Truth = `FORCED_DOOR_OPEN`.

#### Category 4: `LOAD_OR_TAMPER_ANOMALY` (Sessions `SIM-SESS-061` to `080`)
- **Operational Objective**: Detect physical tampering while the locker door remains structurally closed and electronically locked.
- **Tamper Mechanisms**:
  - `DRILL_VIBRATION` (Sessions 61–65): High frequency continuous drill vibration $0.50 - 1.40\text{ G}$, Tilt $0.2 - 1.5^\circ$.
  - `STRUCTURAL_TILT` (Sessions 66–70): Cabinet displacement / prying tilt $5.0 - 14.0^\circ$, Vibration $0.15 - 0.40\text{ G}$.
  - `HAMMER_SHOCK` (Sessions 71–75): Extreme impulse shock impact $16.5 - 22.0\text{ G}$, Tilt $1.0 - 3.5^\circ$.
  - `SPOOF_WEIGHT_CLOSED` (Sessions 76–80): Closed-door weight substitution through rear panel $\Delta w \in [-180, -75]\text{ g} \cup [75, 180]\text{ g}$.
- **Physical Invariants**: `door_open_sec = 0.0` s (door locked throughout attack).
- **Expected Outcome**: `auth_result = "NONE"`, Ground Truth = `PHYSICAL_TAMPER`.

#### Category 5: `SENSOR_FAULT` (Sessions `SIM-SESS-081` to `100`)
- **Operational Objective**: Evaluate transducer failure detection, network latency timeouts, and packet replay prevention.
- **Sensor Malfunctions (15 sessions)**:
  - `WEIGHT_OUT_OF_RANGE` (Sessions 81–84): Load cell ADC rail saturation ($\Delta w = -500\text{ g}$ or $+25000\text{ g}$).
  - `DOOR_EXCEEDS_STAY` (Sessions 85–88): Door open duration exceeds total booking stay ($240\text{ s} > 2\text{ min} \times 60 + 5$).
  - `ULTRASONIC_STUCK` (Sessions 89–92): SRF05 stuck in acoustic blind zone ($d = 0.0\text{ cm} < 2.0\text{ cm}$).
  - `IMU_DROPOUT` (Sessions 93–95): MPU6050 I2C bus freeze ($-1.0\text{ G}$, $-1.0^\circ$, $0.01\text{ G}$).
- **Network Malfunctions (5 sessions)**:
  - `NETWORK_TIMEOUT` (Sessions 96–98): Delayed transmission latency $\tau = 6500.0\text{ ms} \ge 5000.0\text{ ms}$.
  - `NETWORK_DUPLICATE_REPLAY` (Sessions 99–100): Sequence replay attack injecting duplicate non-monotonic sequence numbers.
- **Expected Outcome**: Ground Truth = 15 `SENSOR_MALFUNCTION` + 5 `NETWORK_MALFUNCTION`.

---

## 5. Simulation Mechanics, PRNG Seeds & Stochastic Distributions

### 5.1 Deterministic Hierarchical PRNG Seeding
To ensure 100% bit-for-bit reproducibility across independent evaluation platforms, random numbers are generated using a 2-level hierarchical seed architecture:
1. **Master PRNG Seed**: $S_{\text{master}} = 20261115$ initialized in `ScenarioGenerator(master_seed=20261115)`.
2. **Session-Specific Derived Seeds**: For each session $i \in [1, 100]$, a unique deterministic integer seed is derived:
   $$S_i = \text{master\_rng}.\text{randint}(100000, 999999)$$
3. **Isolated Session Generator**: Telemetry dynamics for session $i$ are generated exclusively using $\text{Random}(S_i)$.

### Table II: Simulation Parameter Distributions
| Transducer / Parameter | Distribution Type | Parametric Range / Values | Units | Target Scenario Family |
|---|---|:---:|:---:|---|
| **Door Contact Duration** | Uniform $\mathcal{U}(a, b)$ | $[4.5, 12.0]$ | s | Normal Authorized |
| **Door Breach Duration** | Uniform $\mathcal{U}(a, b)$ | $[3.0, 16.0]$ | s | Forced Door Opening |
| **Door Locked Duration** | Constant | $0.0$ | s | Tamper / Unauthorized |
| **Parcel Weight Delta** | Uniform $\mathcal{U}(a, b)$ | $[-150.0, 450.0]$ | g | Normal Authorized |
| **Weight Spoofing** | Uniform $\mathcal{U}(a, b)$ | $[-180, -75] \cup [75, 180]$ | g | Closed-Door Tamper |
| **Ultrasonic Normal** | Uniform $\mathcal{U}(a, b)$ | $[15.0, 45.0]$ | cm | Normal Authorized |
| **Ultrasonic Blind Zone**| Constant | $0.0$ | cm | Sensor Malfunction |
| **Ambient Vibration** | Uniform $\mathcal{U}(a, b)$ | $[0.01, 0.08]$ | G | Normal Authorized |
| **Drill Vibration** | Uniform $\mathcal{U}(a, b)$ | $[0.50, 1.40]$ | G | Physical Tamper |
| **Pry Vibration** | Uniform $\mathcal{U}(a, b)$ | $[0.65, 1.85]$ | G | Forced Door Opening |
| **Structural Frame Tilt**| Uniform $\mathcal{U}(a, b)$ | $[5.0, 14.0]$ | deg ($^\circ$) | Physical Tamper |
| **Hammer Impulse Shock** | Uniform $\mathcal{U}(a, b)$ | $[16.5, 22.0]$ | G | Physical Tamper |
| **Network Latency** | Uniform $\mathcal{U}(a, b)$ | $[0.0, 250.0]$ | ms | Normal Transmission |
| **Network Outage** | Uniform $\mathcal{U}(a, b)$ | $[5500.0, 7500.0]$ | ms | Network Malfunction |

---

## 6. Physical Transducer Boundaries & Detection Invariants

### Table III: Transducer Boundary Thresholds and Physical Invariants
| Subsystem | Transducer | Valid Physical Range | Anomaly / Fault Invariant | Physical Failure / Attack Mechanism |
|---|---|:---:|:---:|---|
| **Perimeter** | Reed Switch | $0.0 \le t \le 3600.0\text{ s}$ | $t > \text{stay\_min} \times 60 + 5$ | Door sensor stuck open / latch drift |
| **Perimeter** | Reed + Lock | $t = 0.0\text{ s}$ if locked | $t > 0.0\text{ s} \land \neg\text{rfid\_ok}$ | Violent crowbar door breach |
| **Load** | HX711 Load Cell | $-200.0 \le \Delta w \le 20000.0\text{ g}$ | $\Delta w < -200\text{ g} \lor \Delta w > 20000\text{ g}$ | ADC rail saturation / wire disconnection |
| **Load** | HX711 + Reed | $|\Delta w| \le 50\text{ g}$ if $t = 0$ | $|\Delta w| > 50.0\text{ g} \land t = 0.0\text{ s}$ | In-slot parcel spoofing through panel |
| **Proximity** | SRF05 Sonar | $2.0 \le d \le 400.0\text{ cm}$ | $d < 2.0\text{ cm} \lor d > 400.0\text{ cm}$ | Transducer blind-zone acoustic dropout |
| **Vibration** | MPU6050 Vib | $0.0 \le v \le 5.0\text{ G}$ | $v \ge 0.45\text{ G}$ (locked) | Power tool drilling / mechanical saw |
| **Vibration** | MPU6050 Vib | $0.0 \le v \le 5.0\text{ G}$ | $v \ge 0.60\text{ G} \land t > 0\text{ s}$ | Door pry impact during breach |
| **Tilt** | MPU6050 Tilt | $0.0 \le \theta \le 90.0^\circ$ | $\theta \ge 4.0^\circ$ | Structural cabinet tilt / anchor pry |
| **Shock** | MPU6050 Shock | $0.05 \le a \le 25.0\text{ G}$ | $a \ge 16.0\text{ G}$ | Sledgehammer / heavy impact attack |
| **Transport** | TCP/HTTP Batch | $0.0 \le \tau < 5000.0\text{ ms}$ | $\tau \ge 5000.0\text{ ms}$ | Network timeout / buffer exhaustion |
| **Transport** | Sequence Monotonicity | $\text{seq}_{i+1} > \text{seq}_i$ | $\text{seq}_{i+1} \le \text{seq}_i$ | Packet duplicate / replay attack |

---

## 7. Baseline & Multi-Sensor Detector Specifications

### 7.1 Baseline Detector B0 (Single-Telemetry Threshold)
The existing baseline detector B0 implements threshold rules evaluating solely door duration, load, and server auth:
```python
class BaselineDetectorB0:
    def evaluate(self, auth_result, door_open_sec, weight_delta_g, rfid_ok, stay_min, card_blocked=False):
        if card_blocked:
            return DetectionVerdict("UNAUTHORIZED_ACCESS", 1.0, "B0_LOST_CARD", is_anomaly=True)
        if auth_result in ("DENY", "ERROR"):
            return DetectionVerdict("UNAUTHORIZED_ACCESS", 0.95, "B0_AUTH_DENY", is_anomaly=True)
        if door_open_sec > 15.0:
            return DetectionVerdict("FORCED_DOOR_OPEN", 0.95, "B0_DOOR_OVERTIME", is_anomaly=True)
        if weight_delta_g < -500.0 or weight_delta_g > 20000.0:
            return DetectionVerdict("SENSOR_MALFUNCTION", 0.90, "B0_WEIGHT_OUT_OF_RANGE", is_anomaly=True)
        if door_open_sec > stay_min * 60 + 5:
            return DetectionVerdict("SENSOR_MALFUNCTION", 0.90, "B0_DOOR_EXCEEDS_STAY", is_anomaly=True)
        if not rfid_ok and door_open_sec > 0:
            return DetectionVerdict("FORCED_DOOR_OPEN", 0.95, "B0_FORCED_DOOR_UNAUTHORIZED", is_anomaly=True)
        if door_open_sec == 0.0 and abs(weight_delta_g) > 50.0:
            return DetectionVerdict("PHYSICAL_TAMPER", 0.90, "B0_TAMPER_WEIGHT_LOCKED", is_anomaly=True)
        return DetectionVerdict("NORMAL_USAGE", 0.95, "B0_NORMAL_OPERATION", is_anomaly=False)
```
**B0 Limitations**: Completely blind to ultrasonic acoustic cutoffs, IMU frame tilt, continuous drill vibration, sledgehammer shock impacts, network transport timeouts, and sequence replay attacks.

### 7.2 Proposed Detector B1 (Leak-Free Multi-Sensor Hierarchical Fusion)
Proposed Detector B1 evaluates 14 observable features across 6 prioritized tiers:
1. **Tier 1: Transducer Malfunctions**: Ultrasonic out-of-bounds ($<2\text{ cm}$ or $>400\text{ cm}$), IMU bus freeze ($-1\text{ G}$ or $-1^\circ$), Load cell ADC rail ($<-200\text{ g}$ or $>20000\text{ g}$), Reed switch drift ($t > \text{stay} \times 60 + 5$).
2. **Tier 2: Network Transport Faults**: Transport latency $\tau \ge 5000\text{ ms}$, Sequence non-monotonicity ($\text{seq}_{i+1} \le \text{seq}_i$ or gap $>1$).
3. **Tier 3: Physical Perimeter Breach**: Forced door opening ($\neg\text{rfid\_ok} \land t > 0$) or Door opening accompanied by breach vibration ($v \ge 0.60\text{ G}$).
4. **Tier 4: Structural Enclosure Tampering**: Sledgehammer shock ($a \ge 16.0\text{ G}$), Continuous drill vibration ($v \ge 0.45\text{ G}$), Frame pry tilt ($\theta \ge 4.0^\circ$), Closed-door weight shift ($|\Delta w| > 50\text{ g} \land t = 0$).
5. **Tier 5: Access Control Authorization**: Lost/blocked card, Server authorization denial (`auth_result in ("DENY", "ERROR")`).
6. **Tier 6: Normal Authorized Usage**: Legitimate unlock with physical dynamics within calibrated bounds.

### 7.3 Model M1 (Server ML RiskScorer)
Model M1 operates inside the Java backend (`src/java/service/RiskScorer.java` and `RuleEngine.java`). It evaluates sessions that pass deterministic Tier 1 checks using a Weka machine-learning classifier (J48/RandomForest) trained on 5 persistent features:
$$\mathbf{x} = [\text{door\_open\_sec}, \Delta\text{weight\_g}, \text{unauth\_attempts}, \text{session\_duration\_sec}, \text{tamper\_flag}]$$
If RiskScore $\ge 0.80$, an elevated risk alert is dispatched to `AlertService`. Because the baseline database schema (`LockerSession`) does not store sonar or IMU columns, M1 relies on B1's edge fusion layer to intercept structural and acoustic anomalies.

---

## 8. Haber-Stornetta Cryptographic Audit Hash-Chaining Protocol

### 8.1 Mathematical Specification
To guarantee complete tamper-evidence and immutability for all security-critical events (authorization attempts, alert dispatches, door breaches), the system implements a Haber-Stornetta forward-linked cryptographic hash chain:

$$H_0 = 0^{64} = \text{"0000000000000000000000000000000000000000000000000000000000000000"}$$
$$H_i = \text{SHA-256}_{\text{UTF-16LE}}\left(\text{audit\_id}_i \parallel \text{"|"} \parallel \text{ts}_i \parallel \text{"|"} \parallel \text{actor}_i \parallel \text{"|"} \parallel \text{action}_i \parallel \text{"|"} \parallel \text{type}_i \parallel \text{"|"} \parallel \text{id}_i \parallel \text{"|"} \parallel \text{diff}_i \parallel \text{"|"} \parallel H_{i-1}\right)$$

### 8.2 Canonical Serialization & Character Encoding Alignment
- **Encoding**: Strict `UTF-16LE` (Little Endian). Aligns bit-for-bit with Microsoft SQL Server's `HASHBYTES('SHA2_256', NVARCHAR)` and Java's `MessageDigest.getInstance("SHA-256")`.
- **Null Serialization**: Nullable columns (`actor_user_id`, `object_id`, `diff_json`) are strictly converted to empty strings `""` matching SQL Server `CONCAT` semantics.

### 8.3 Concurrency Control & Forward-Only Streaming
- **Tail Locking**: Stored procedure `Audit_Append` locks the chain tail using `SELECT TOP 1 chain_hash FROM HashChain WITH (UPDLOCK, HOLDLOCK) ORDER BY anchor_id DESC`.
- **$O(1)$ Memory Verification**: `AuditVerifier.java` walks the ledger using a streaming forward-only JDBC cursor (`ResultSet.TYPE_FORWARD_ONLY, ResultSet.CONCUR_READ_ONLY`), preventing JVM heap exhaustion regardless of table size.

---

## 9. Evidence Preservation & Directory Layout Architecture

### 9.1 Directory Layout Architecture
To prevent inadvertent corruption of historical baselines, experimental results are strictly partitioned:
```
experiments/
├── evidence/                       # Historical baseline evidence (11 raw files)
├── results/
│   ├── final_audit_v1/             # Preserved frozen historical audit baseline
│   │   ├── sessions.json / csv
│   │   ├── evaluation_metrics.json
│   │   ├── statistical_tests.json
│   │   ├── confusion_matrix_b0.csv
│   │   ├── confusion_matrix_b1.csv
│   │   ├── audit_chain_verification.json
│   │   ├── table_detection_comparison.tex
│   │   └── table_latency_distribution.tex
│   └── final_audit_v2/             # Versioned new experimental campaign execution
│       ├── sessions.json / csv
│       ├── backend_requests.jsonl
│       ├── backend_responses.jsonl
│       ├── sensor_readings.csv
│       ├── execution_summary.json
│       ├── failed_sessions.csv
│       ├── ground_truth_labels.csv
│       ├── reproduction_config.yaml
│       ├── README.md
│       ├── evaluation_metrics.json
│       ├── statistical_tests.json
│       ├── confusion_matrix_b0.csv
│       ├── confusion_matrix_b1.csv
│       └── audit_chain_verification.json
```

---

## 10. Step-by-Step Reproducibility & Execution Protocol

### Step 1: Initialize Database & Verify Schema
```powershell
sqlcmd -S localhost -U sa -P 12345 -d SL_SIM -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE';"
```

### Step 2: Launch Apache Tomcat Test Stack on Port 8081
```cmd
cmd.exe /c scripts\proof\start-tomcat-daemon.bat
```
Verify health:
```powershell
python -c "import urllib.request; resp = urllib.request.urlopen('http://localhost:8081/SmartLocker/api/health', timeout=5); print(resp.status)"
```

### Step 3: Execute Controlled Experimental Campaign
```powershell
python experiments/runner.py --output-dir experiments/results/final_audit_v2 --total-sessions 100 --seed 20261115
```

### Step 4: Run Pure Python Statistical Evaluation Engine
```powershell
python experiments/evaluate.py --results-dir experiments/results/final_audit_v2 --output-dir experiments/results/final_audit_v2
```

### Step 5: Verify Cryptographic Audit Hash Chain
```powershell
python experiments/verify_hash_chain.py --db SL_SIM --output experiments/results/final_audit_v2/audit_chain_verification.json
```

### Step 6: Execute Full Unit & Regression Test Suite
```powershell
python -m unittest tests/test_leak_free_b1.py tests/test_milestone3.py
```

---

## 11. Statistical & Validation Quality Assurance Framework

### 11.1 Inferential Statistics
1. **Wilson Score 95% Confidence Intervals**: Inverts the binomial score test $|\hat{p} - p_0| \le z \sqrt{p_0(1-p_0)/n}$ at $z = 1.95996$, eliminating degenerate zero-width intervals at $\hat{p} = 0.0$ and $\hat{p} = 1.0$.
2. **McNemar's Paired Test with Edwards Continuity Correction**:
   $$\chi^2 = \frac{(|n_{10} - n_{01}| - 1)^2}{n_{10} + n_{01}}$$
   Where $n_{10}$ is B1 correct / B0 incorrect, and $n_{01}$ is B0 correct / B1 incorrect. The asymptotic $p$-value is evaluated via Python's `math.erfc(\sqrt{\chi^2 / 2})$.
3. **Exact Binomial Verification**: Evaluates exact two-tailed tail probability under $H_0 \sim \text{Binomial}(n_{10} + n_{01}, 0.5)$.
4. **Effect Size**: Cohen's $g = |P - 0.5|$ and Odds Ratio with Haldane-Anscombe correction $\psi = \frac{n_{10} + 0.5}{n_{01} + 0.5}$.

---
*End of FINAL_EXPERIMENTAL_METHODOLOGY.md*
