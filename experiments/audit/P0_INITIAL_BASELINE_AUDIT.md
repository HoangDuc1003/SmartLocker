# P0 Initial Baseline Audit Report — SmartLocker Scientific Integrity & Evidence Audit

**Audit Date**: 2026-11-16  
**Auditor**: Senior Research & Engineering Execution System  
**Target Repository**: `https://github.com/HoangDuc1003/SmartLocker`  
**Starting Commit Reference**: `e95f7c6` (`feat(audit-scopus): comprehensive research audit, evidence validation, and 10-page Scopus paper revision`)  
**Target Branches**: `main` (current HEAD: `e95f7c6`), `research/multisensor-simulation` (HEAD: `a2e51e8`)

---

## 1. Initial Branch & Git Working Tree Status

- **Current Active Branch**: `main`
- **Current HEAD Commit**: `e95f7c6c62f52ee2f6e88bb27e47bcaac7158b58`
- **Upstream Tracking**: `origin/main` (up to date)
- **Working Tree**: Clean (0 uncommitted changes prior to audit report generation).
- **Target Branch Status**:
  - `main`: contains commit `e95f7c6` on top of `a2e51e8`.
  - `research/multisensor-simulation`: currently at `a2e51e8` (`docs(report): apply table top struts, 0.00 Fig 9a axis, full Fig 2 width, and export instructor & scopus PDFs`).
  - Ancestry: `main` is 1 commit ahead of `research/multisensor-simulation`.

---

## 2. Environment & Dependency Verification Status

- **Operating System**: Windows 11 Enterprise (64-bit)
- **Python**: 3.11.9 (`C:\Users\ADMIN\AppData\Local\Programs\Python\Python311\python.exe`)
- **Java Runtime**: OpenJDK 21.0.12.1 LTS (system path) & JDK 1.8.0_202 (`C:\Program Files\Java\jdk1.8.0_202` configured for Tomcat 9)
- **Database Server**: Microsoft SQL Server 2022 (`MSSQLSERVER` running on localhost:1433)
- **Target Experimental Database**: `SL_SIM` verified present in SQL Server instance.
- **Application Server**: Apache Tomcat 9.0.113 (`E:\apache-tomcat-9.0.113`, CATALINA_BASE: `C:\sl-wt\tomcat-8081`)
- **Port 8081 Status**: Currently STOPPED / NOT LISTENING (will be started via `scripts/proof/test-stack.ps1 start -Database SL_SIM`).
- **LaTeX Engine (Tectonic)**: Tectonic 0.17.0 located at `C:\Users\ADMIN\.gemini\antigravity\scratch\teamwork\tectonic\tectonic.exe`. Verified operational.

---

## 3. Current Test Counts & Baseline Execution

- **Unit/Integration Test Suite** (`tests/`):
  - Total tests collected: 101 tests across 5 test modules (`test_leak_free_b1.py`, `test_milestone3.py`, `test_milestone4.py`, `test_simulator.py`, `verify_m2_backend_matrix.py`).
  - Offline/unit tests passing: 96 tests PASSED.
  - Live backend connection tests failing prior to Tomcat startup: 5 tests in `test_simulator.py` (expected failure due to Tomcat port 8081 inactive).
- **Total Experimental Sessions**: 100 pre-labeled scenarios across 5 categories.

---

## 4. Critical Scientific Integrity Findings & Root Cause Analysis

### 4.1 The 20 Authorization Inconsistencies (`NORMAL_AUTHORIZED` returning `DENY`)

Inspection of historical artifacts (`experiments/evidence/backend_responses.jsonl`, `experiments/results/final_audit_v1/backend_responses.jsonl`, `experiments/results/final_audit_v2/backend_responses.jsonl`, and `sessions.csv`) reveals an alarming scientific integrity defect:

All 20 `NORMAL_AUTHORIZED` sessions (SIM-SESS-001 through SIM-SESS-020) received `DENY` from the live backend `/api/device/auth` endpoint:
- `SIM-SESS-001` .. `SIM-SESS-003`: `{"result": "DENY", "reason": "WRONG_CODE", "attempts_left": 4..2}`
- `SIM-SESS-004`: `{"result": "DENY", "reason": "WRONG_PLACE", "right_bank": "LIB-A"}`
- `SIM-SESS-005`: `{"result": "DENY", "reason": "WRONG_PLACE", "right_bank": "DOMA-A"}`
- `SIM-SESS-006`: `{"result": "DENY", "reason": "WRONG_PLACE", "right_bank": "DOMA-B"}`
- `SIM-SESS-007`: `{"result": "DENY", "reason": "WRONG_PLACE", "right_bank": "GYM-A"}`
- `SIM-SESS-008`: `{"result": "DENY", "reason": "UNKNOWN_FINGER"}`
- `SIM-SESS-009`: `{"result": "DENY", "reason": "METHOD_MISMATCH"}`
- `SIM-SESS-010`: `{"result": "DENY", "reason": "WRONG_PLACE", "right_bank": "LIB-A"}`
- `SIM-SESS-011`: `{"result": "DENY", "reason": "WRONG_CODE", "attempts_left": 0, "retry_after_sec": 120}`
- `SIM-SESS-012` .. `SIM-SESS-020`: `{"result": "DENY", "reason": "LOCKED_OUT", "attempts_left": 0, "retry_after_sec": 120}`

### 4.2 Detailed Root Cause Analysis

Tracing the actual backend stored procedure `Device_Authorize` and database `SL_SIM` identified two compounding root causes:

1. **Root Cause A — Lockout Contamination**:
   In `Auth_Log`, 5 consecutive failed credential attempts within 5 minutes trigger a 120-second lockout (`LOCK_START` row in `AuthAttempt`), locking the device channel. Because `experiments/runner.py` did not isolate scenarios or reset the lockout counter at scenario boundaries, once SIM-SESS-011 failed, every subsequent attempt on `LOCKER-01` (device 5) was rejected with `LOCKED_OUT`.

2. **Root Cause B — Database Fixture Invalidation & Credential Disconnect**:
   - For PINs: Deposit 90 (PIN `952705`) and Deposit 95 (PIN `320357`) had `ended_at` set (COMPLETED status), and Slot 54 (`A04` in `CANT-A`) was marked `MAINTENANCE`. `Device_Authorize` queries `status IN ('RESERVED', 'ACTIVE') AND b.device_id = @device_id`. Because the deposits were already ended, `Device_Authorize` rejected the PIN with `WRONG_CODE`.
   - For RFID Cards: Cards `04A1B2C3`, `0499AABB`, `04556677`, `04F5A6B7` belonged to users whose active bookings were assigned to `LIB-A`, `DOMA-A`, `DOMA-B`, and `GYM-A`, respectively. When presented to device 5 (`CANT-A`), `Device_Authorize` correctly replied `WRONG_PLACE`.
   - For Fingerprints: In table `Fingerprint`, only sensor slots 1 and 2 existed (slot 5 did not exist -> `UNKNOWN_FINGER`), and neither slot 1 nor slot 2 had an active booking at `CANT-A`.
   - For Method Mismatch: Where an active booking existed for a user, `open_method` was set to `PIN`, so presenting a card triggered `METHOD_MISMATCH`.

3. **Flawed Execution Gate in Runner**:
   In `experiments/runner.py`, `test_status` was marked `PASS` solely if batch telemetry ingestion `/api/locker/batch` returned HTTP 200 without error (`batch_resp.get("status") != "ERROR"`). The authentication result was completely ignored when evaluating `test_status`. Consequently, the previous reports claimed "100% execution pass rate (100 PASS, 0 FAIL)" despite 100% of the authorized sessions failing authorization.

---

## 5. Existing Conflicting Metrics Across Repository Artifacts

A systematic scan of existing documentation reveals multiple conflicting metric sets:

1. **Set 1 (Historical draft)**:
   - Baseline B0 Macro-F1: `0.436` (0.4360)
   - Proposed B1 Macro-F1: `0.876` (0.8760)
   - McNemar: $\chi^2 = 23.04, p = 2.0 \times 10^{-6}$
   - Found in: `EVIDENCE_MATRIX.md`, `FINAL_TEACHER_COMPLIANCE_MATRIX.md`, `docs/paper/SUPERVISOR_RESPONSE_R2.md`.

2. **Set 2 (Audited v1)**:
   - Baseline B0 Macro-F1: `0.5136` (Accuracy: 50.0%, Balanced Accuracy: 0.5000, Normal Prec/Rec/F1: 0.000)
   - Proposed B1 Macro-F1: `0.9698` (Accuracy: 97.0%, Balanced Accuracy: 0.9700)
   - McNemar: $\chi^2 = 45.0213$, reported $p = 0.0$ or $1.95 \times 10^{-11}$
   - Found in: `experiments/results/evaluation_metrics.json`, `docs/paper/smartlocker-10p.tex` Table VII, `FINAL_RESULTS_REPORT.md`.

3. **Set 3 (Audited v2)**:
   - Baseline B0 Macro-F1: `0.5782`
   - Proposed B1 Macro-F1: `0.8255` (Accuracy: 85.0%)
   - McNemar: $p = 5.62 \times 10^{-7}$
   - Found in: `FINAL_AUDIT_LEAKAGE_RECONCILIATION.md`, `docs/paper/smartlocker-10p.tex` Abstract.

This audit confirms that neither Set 1, Set 2, nor Set 3 is scientifically valid because all were computed against contaminated runs where `NORMAL_AUTHORIZED` sessions received `DENY`.

---

## 6. Detector Implementations & Feature Channels

- **Baseline Detector B0** (`BaselineDetectorB0` in `experiments/detection.py`):
  - Observable channels: `door_open_sec`, `weight_delta_g`, `stay_min`, `auth_result`, `rfid_ok`, `card_blocked`.
  - Blind to: IMU vibration intensity, IMU structural tilt, IMU shock magnitude, ultrasonic distance, transport latency, packet sequence monotonicity.
- **Proposed Detector B1** (`ProposedDetectorB1` in `experiments/detection.py`):
  - Observable channels: All B0 channels PLUS `ultrasonic_dist_cm`, `vibration_intensity`, `tilt_deg`, `shock_mag_g`, `network_latency_ms`, `packet_seq`, `telemetry_records`, `raw_payload`.
  - Architecture: 6-tier deterministic priority evaluation (Hardware faults -> Transport faults -> Forced door breach -> Enclosure tamper -> Credential denial -> Normal).
  - Status: Leak-free, operates purely on observable sensor inputs.

---

## 7. Exact Files Requiring Modification

1. `experiments/fixtures.py` (New):
   - Deterministic fixture management: sets up valid `RESERVED`/`ACTIVE` bookings, deposits, and credentials for `LOCKER-01` (`CANT-A`), clears lockout state at scenario boundaries via `COUNTER_RESET`.
2. `experiments/generator.py`:
   - Align valid credentials and slots with the isolated fixtures in `SL_SIM`.
3. `experiments/runner.py`:
   - Implement the 5 granular pass gates: `transport_pass`, `ingestion_pass`, `auth_pass`, `detection_pass` (`b0_detection_pass`, `b1_detection_pass`), and `end_to_end_pass`.
   - Add database persistence verification for `/api/locker/batch`.
   - Prevent lockout contamination across scenarios while preserving intra-scenario lockout testing.
4. `experiments/evaluate.py` & `experiments/statistical_tests.py`:
   - Compute metrics directly from fresh predictions.
   - Enforce exact paired McNemar test using binomial distribution, preserving small p-values in scientific notation without rounding to 0.0.
5. `docs/paper/smartlocker-10p.tex`:
   - Update Abstract, Table V, Section VI.D/E, Table VII, and Conclusion with verified numbers.
   - Ensure clear distinction between prototype hardware, simulation framework, and backend processing.
6. Documentation files:
   - `README.md`, `FINAL_RESULTS_REPORT.md`, `FINAL_EVIDENCE_MATRIX.md`, `FINAL_AUDIT_LEAKAGE_RECONCILIATION.md`, `EVIDENCE_MATRIX.md`.

---

## 8. Conclusion

The repository is currently at `main` (`e95f7c6`), with SQL Server running `SL_SIM`. Tectonic and Python 3.11 are operational. The root cause of the authorization failures and conflicting metrics has been definitively identified and documented. Execution proceeds immediately to Step 1: Database Fixture and Lockout Correction.
