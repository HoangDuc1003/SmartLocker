# Final P0 Scientific Audit Report — SmartLocker Live Backend Reproduction & Scientific Verification

**Audit Date**: 2026-11-16  
**Auditor**: Senior Research & Engineering Execution System  
**Repository**: `https://github.com/HoangDuc1003/SmartLocker`  
**Starting Commit Reference**: `e95f7c6`  
**Target Branches**: `research/multisensor-simulation`, `main`  
**Experiment Run ID**: `RUN_20261116_010959_SEED20261115_SL_SIM`  
**Status Verdict**: **READY**  

---

## 1. Executive Summary

A comprehensive scientific audit and live reproduction of the 100-session SmartLocker multi-sensor experimental campaign was executed against the actual Apache Tomcat 9.0.113 backend (port 8081) backed by Microsoft SQL Server 2022 database `SL_SIM`. 

All P0 scientific integrity findings—specifically the total failure of historical `NORMAL_AUTHORIZED` sessions (receiving `WRONG_CODE`, `WRONG_PLACE`, `UNKNOWN_FINGER`, and `LOCKED_OUT`) and flawed pass-gate evaluations—were investigated down to the backend stored procedures (`Device_Authorize`, `Auth_Log`, `Auth_LockCheck`) and resolved with deterministic, isolated database fixtures and clean boundary lockout management.

The live experiment was re-run end-to-end without mocks, generating fresh telemetry, authentic access decisions, and verified database persistence. Five granular execution pass gates were enforced:
- **Gate 1 Transport Pass**: 100/100 (100.0%)
- **Gate 2 Database Ingestion Pass**: 100/100 (100.0%)
- **Gate 3 Authentication Pass**: 100/100 (100.0%) — All 20 normal sessions returned `UNLOCK`; all 20 unauthorized sessions returned `DENY`.
- **Gate 4a Baseline B0 Detection Pass**: 73/100 (73.0%)
- **Gate 4b Proposed B1 Detection Pass**: 100/100 (100.0%)
- **Gate 5 End-to-End Workflow Pass**: 100/100 (100.0%)

Baseline B0 and Proposed B1 detection performance was recomputed strictly from fresh predictions:
- **Baseline B0**: Macro-F1 = **0.7137** (0.714), Balanced Accuracy = **0.7300**, Overall Accuracy = 73.0%.
- **Proposed B1**: Macro-F1 = **1.0000** (1.000), Balanced Accuracy = **1.0000**, Overall Accuracy = 100.0%.
- **Paired McNemar Test**: $\chi^2 = 25.0370$, asymptotic $p = 5.62 \times 10^{-7}$, exact two-sided binomial $p = 1.49 \times 10^{-8}$ (large effect size, Cohen's $g = 0.5000$).

All manuscript files, tables, documentation, and both Scopus and Instructor PDFs were fully synchronized.

---

## 2. Initial P0 Findings

1. **Authorization Contamination & Rejection**:
   In previous experiment artifacts (`sessions.csv`, `backend_responses.jsonl`), all 20 `NORMAL_AUTHORIZED` sessions received `DENY` from the live `/api/device/auth` endpoint due to:
   - Stale/completed deposit records in `SL_SIM` for PINs.
   - Bank mismatches (`WRONG_PLACE`) for RFID cards whose owners' active deposits were at other locker banks (`LIB-A`, `DOMA-A`, `DOMA-B`, `GYM-A`).
   - Unenrolled fingerprint slot indices (`UNKNOWN_FINGER`).
   - Unchecked 120-second device lockout triggered by repeated negative attempts contaminating subsequent sessions.
2. **False Claims of 100% Pass Rate**:
   The previous `runner.py` marked sessions `PASS` solely if `/api/locker/batch` returned HTTP 200 without error, ignoring authentication failure.
3. **Metric Inconsistencies Across Documents**:
   The repository contained three conflicting sets of numbers:
   - Historical draft: B0 F1 0.436 / B1 F1 0.876
   - Audited v1: B0 F1 0.5136 / B1 F1 0.9698 (Normal F1 = 0.000)
   - Audited v2: B0 F1 0.5782 / B1 F1 0.8255

---

## 3. Root Cause Analysis

1. **Root Cause A (Lockout Contamination)**:
   Stored procedure `Auth_Log` records failed credential guesses (`WRONG_CODE`, `UNKNOWN_CARD`, `UNKNOWN_FINGER`, `BAD_CODE`). When 5 failures accumulate within 5 minutes, a `LOCK_START` record locks the device for 120 seconds. The previous runner did not isolate scenarios or reset the lockout counter at scenario boundaries, causing all attempts after session 11 to fail with `LOCKED_OUT`.
2. **Root Cause B (Database Fixture Disconnect)**:
   Stored procedure `Device_Authorize` enforces that:
   - PINs match an active/reserved deposit on the target device (`device_id = 5`).
   - Cards match active `UserCard` rows whose user has an active deposit on `device_id = 5` and `open_method = 'CARD'`.
   - Fingerprints match active `Fingerprint` rows on `device_id = 5` whose user has an active deposit on `device_id = 5` and `open_method = 'FINGERPRINT'`.
   - Unique filtered index `UX_Deposit_user_open` restricts each user to at most ONE open deposit across the entire system.
   Previous test runs did not clear historical deposits for test users, resulting in `WRONG_PLACE` rejections and duplicate key violations.
3. **Root Cause C (Hardware Boundary Bug for Invalid Fingerprints)**:
   In `generator.py`, invalid fingerprints were defined as `[161, 200, 999]`. However, AS608 optical sensor template capacity is bounded at $[1, 160]$ in `DeviceAuthApi.java`. Numbers $> 160$ trigger HTTP 400 `BAD_REQUEST` (`ERROR`) before reaching `Device_Authorize`. Valid unenrolled slots $[1, 160]$ correctly produce `DENY` (`UNKNOWN_FINGER`).

---

## 4. Code Changes

1. **`experiments/fixtures.py`**:
   Implemented `ExperimentFixtures` class to manage database fixtures in `SL_SIM` via native ADODB. Automatically resets lockout state via `COUNTER_RESET`, deploys 9 distinct active fixtures on `CANT-A` (device 5), and verifies row persistence in table `dbo.LockerSession`.
2. **`experiments/generator.py`**:
   - Added `CARD_SLOT_MAP` and `FP_SLOT_MAP` aligning generated scenario credentials with their active fixture slots (`A01`–`A10`).
   - Updated `INVALID_FINGERPRINTS` to valid unenrolled sensor slots in $[1, 160]$ (`[3, 4, 7, 8, 9, 11]`).
3. **`experiments/runner.py`**:
   - Implemented 5 granular pass gates: `transport_pass`, `ingestion_pass`, `auth_pass`, `b0_detection_pass`, `b1_detection_pass`, `end_to_end_pass`.
   - Integrated live database persistence read-back verification against `dbo.LockerSession`.
   - Added lockout boundary management and logging (`lockout_before`, `lockout_after`).
   - Created immutable run directory `experiments/runs/<RUN_ID>/` and deterministic evidence synchronization.
4. **`experiments/statistical_tests.py` & `experiments/evaluate.py`**:
   - Added exact two-sided binomial McNemar test with scientific notation formatting.
   - Enforced standard contingency table indexing ($n_{00}, n_{01}, n_{10}, n_{11}$).
   - Added programmatic generation of `confusion_matrices.json`, `mcnemar_results.json`, and `evaluation_report.md`.

---

## 5. Database Fixture Changes

The following deterministic fixtures were established in `SL_SIM` for `LOCKER-01` (`CANT-A`, `device_id = 5`):

| Slot Code | Slot ID | Open Method | Credential | User ID | Username | Deposit ID | Status |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `A01` | 51 | `CARD` | `04A1B2C3` | 72 | `student1` | 133 | `ACTIVE` |
| `A02` | 52 | `CARD` | `0499AABB` | 73 | `student2` | 134 | `ACTIVE` |
| `A03` | 53 | `CARD` | `04C3D4E5` | 74 | `student3` | 135 | `ACTIVE` |
| `A04` | 54 | `PIN` | `952705` | 91 | `student18` | 132 | `ACTIVE` |
| `A06` | 56 | `CARD` | `04F5A6B7` | 75 | `student4` | 136 | `ACTIVE` |
| `A07` | 57 | `CARD` | `04556677` | 76 | `student5` | 137 | `ACTIVE` |
| `A08` | 58 | `FINGERPRINT` | Slot 1 | 77 | `student6` | 138 | `ACTIVE` |
| `A09` | 59 | `FINGERPRINT` | Slot 2 | 104 | `v2fp` | 139 | `ACTIVE` |
| `A10` | 60 | `FINGERPRINT` | Slot 5 | 78 | `student7` | 140 | `ACTIVE` |

Lockout state on device 5 was cleared via `COUNTER_RESET`.

---

## 6. Live Backend Verification

- **Servlet Container**: Apache Tomcat 9.0.113 (`C:\sl-wt\tomcat-8081`, PID: 15508)
- **Port**: 8081 (`http://localhost:8081/SmartLocker/api`)
- **Database**: Microsoft SQL Server 2022 on port 1433 (`SL_SIM`)
- **Health Probe**: Verified HTTP 200 on `/api/health` and `/api/locker-map`.
- **Unit/Integration Test Suite**: 101/101 tests PASSED in 0.158s.

---

## 7. Five Granular Pass Gates Results

| Gate | Description | Verified Count | Pass Percentage |
|:---:|---|:---:|:---:|
| **Gate 1** | `transport_pass` (HTTP transport success / expected fault) | 100 / 100 | **100.0%** |
| **Gate 2** | `ingestion_pass` (DB persistence in `LockerSession`) | 100 / 100 | **100.0%** |
| **Gate 3** | `auth_pass` (Actual auth matches expected outcome) | 100 / 100 | **100.0%** |
| **Gate 4a**| `b0_detection_pass` (Baseline B0 classification accuracy) | 73 / 100 | **73.0%** |
| **Gate 4b**| `b1_detection_pass` (Proposed B1 classification accuracy) | 100 / 100 | **100.0%** |
| **Gate 5** | `end_to_end_pass` (G1 AND G2 AND G3) | 100 / 100 | **100.0%** |

---

## 8. Detector Confusion Matrices & Per-Class Performance

### 8.1 Confusion Matrices (Nominal 20 Sessions per Category)

**Baseline B0**:
```
Actual \ Predicted       NORMAL  UNAUTH  FORCED  TAMPER  FAULT  MISSED
NORMAL_AUTHORIZED          20       0       0       0      0       0
UNAUTHORIZED_CREDENTIAL     0      20       0       0      0       0
FORCED_DOOR_OPEN            0       0      20       0      0       0
LOAD_OR_TAMPER_ANOMALY     15       0       0       5      0       0
SENSOR_FAULT               12       0       0       0      8       0
```

**Proposed B1**:
```
Actual \ Predicted       NORMAL  UNAUTH  FORCED  TAMPER  FAULT  MISSED
NORMAL_AUTHORIZED          20       0       0       0      0       0
UNAUTHORIZED_CREDENTIAL     0      20       0       0      0       0
FORCED_DOOR_OPEN            0       0      20       0      0       0
LOAD_OR_TAMPER_ANOMALY      0       0       0      20      0       0
SENSOR_FAULT                0       0       0       0     20       0
```

### 8.2 Per-Class Precision, Recall, and F1 Metrics

| Category | Nominal Support | Baseline B0 Prec | Baseline B0 Rec | Baseline B0 F1 | Proposed B1 Prec | Proposed B1 Rec | Proposed B1 F1 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `NORMAL_AUTHORIZED` | 20 | 0.4255 | 1.0000 | 0.5970 | **1.0000** | **1.0000** | **1.0000** |
| `UNAUTHORIZED_CREDENTIAL` | 20 | 1.0000 | 1.0000 | 1.0000 | **1.0000** | **1.0000** | **1.0000** |
| `FORCED_DOOR_OPEN` | 20 | 1.0000 | 1.0000 | 1.0000 | **1.0000** | **1.0000** | **1.0000** |
| `LOAD_OR_TAMPER_ANOMALY` | 20 | 1.0000 | 0.2500 | 0.4000 | **1.0000** | **1.0000** | **1.0000** |
| `SENSOR_FAULT` | 20 | 1.0000 | 0.4000 | 0.5714 | **1.0000** | **1.0000** | **1.0000** |
| **Macro Average** | **100** | **0.8851** | **0.7300** | **0.7137** | **1.0000** | **1.0000** | **1.0000** |

- **Macro-F1 Score**: B0 = **0.7137** (0.714) vs. B1 = **1.0000** (1.000) [+40.1% rel.]
- **Balanced Accuracy**: B0 = **0.7300** (0.730) vs. B1 = **1.0000** (1.000) [+37.0% rel.]
- **Overall Accuracy**: B0 = **73.0%** (73/100) vs. B1 = **100.0%** (100/100) [+27.0%]

---

## 9. Paired McNemar Test Statistics

- Binary anomaly collapse: `NORMAL` (20 sessions) vs. `ANOMALY` (80 sessions).
- Contingency table:
  - $n_{00}$ (both incorrect): 0
  - $n_{01}$ (B0 incorrect, B1 correct): 27
  - $n_{10}$ (B0 correct, B1 incorrect): 0
  - $n_{11}$ (both correct): 73
  - Verification: $n_{00} + n_{01} + n_{10} + n_{11} = 0 + 27 + 0 + 73 = 100$.
- Discordant pairs: 27
- Chi-squared statistic ($\chi^2$): **25.0370** ($df = 1$, Edwards continuity correction: $(|27 - 0| - 1)^2 / 27 = 676 / 27$).
- Asymptotic p-value: **$5.62 \times 10^{-7}$**.
- Exact two-sided binomial p-value: **$1.49 \times 10^{-8}$** ($2 \times 0.5^{27}$).
- Effect size (Cohen's $g$): **0.5000** (Large effect, $g \ge 0.25$).
- Significance: Overwhelming statistical significance ($p < 0.001$).

---

## 10. B0 vs. B1 Channel Scope Comparison

| Telemetry / Sensor Channel | Baseline B0 (Existing) | Proposed B1 (Multi-Sensor) | Physical Principle & Role |
|---|:---:|:---:|---|
| Door Reed Switch Duration | Observable | Observable | Magnetic reed switch door opening duration (sec) |
| Slot Load Cell Delta | Observable | Observable | Strain-gauge ADC delta (grams) |
| Stated Stay Duration | Observable | Observable | Booking duration from SQL context (min) |
| Access Control Auth Result | Observable | Observable | `UNLOCK`, `CHOOSE`, `DENY` decision from `/api/device/auth` |
| Blocked RFID Card Check | Observable | Observable | Check against reported lost/blocked card database |
| Batch RFID OK Flag | Observable | Observable | Edge indicator of valid card swipe prior to door opening |
| **MPU6050 Vibration Intensity** | **BLIND** | **OBSERVABLE** | RMS vibration acceleration delta ($g$) detecting drilling/cutting |
| **MPU6050 Frame Tilt Angle** | **BLIND** | **OBSERVABLE** | Accelerometer frame displacement angle ($^\circ$) detecting prying |
| **MPU6050 Impact Shock** | **BLIND** | **OBSERVABLE** | Peak G-force ($g$) detecting sledgehammer/kick breach |
| **SRF05 Ultrasonic Distance** | **BLIND** | **OBSERVABLE** | Acoustic time-of-flight distance (cm) detecting transducer freeze |
| **Transport Network Latency** | **BLIND** | **OBSERVABLE** | Socket request-response latency (ms) detecting DDoS/timeouts |
| **Packet Sequence Tracker** | **BLIND** | **OBSERVABLE** | Strict monotonic sequence index detecting replay attacks & gaps |

---

## 11. Artifact Hashes & Immutability Traceability

All evidence is immutably archived under `experiments/runs/RUN_20261116_010959_SEED20261115_SL_SIM/` and mirrored to `experiments/evidence/` and `experiments/results/`. Cryptographic SHA-256 hashes are recorded in `raw_evidence_hashes.json`.

---

## 12. Final Verdict

**READY** — All critical backend, database, execution, detector, statistical, and document requirements have been verified without mocks or fabrications.
