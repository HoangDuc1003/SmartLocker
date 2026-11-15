# Changelog — SmartLocker Research Upgrade & Paper Consistency

All notable changes to the SmartLocker repository and research manuscript are documented in this file.

---

## [Unreleased / Research Upgrade] — 2026-11-16

### Added
- **Multi-Sensor Python Device Simulator (`simulator/`)**:
  - Implemented modular ESP32 device emulator (`simulator/esp32.py`) with cryptographic API key signing (`X-API-Key`) and heartbeat protocol.
  - Implemented state machine (`simulator/state_machine.py`) governing states: `IDLE`, `AUTHENTICATING`, `DOOR_OPEN`, `CLOSING`, `FAULT`, `LOCKOUT`.
  - Implemented dedicated sensor models in `simulator/sensors/`:
    - `ultrasonic.py`: SRF05 distance telemetry, human presence detection, LCD backlight trigger, and auto-lock delay.
    - `reed_switch.py`: Magnetic door reed switch with contact bounce emulation.
    - `load_cell.py`: HX711 strain gauge weight telemetry with thermal drift, tare, and item weight differential.
    - `accelerometer.py`: 3-axis accelerometer and vibration sensor for physical pry and tamper detection.
  - Implemented synthetic anomaly and fault injector in `simulator/faults/injector.py`.
  - Implemented 5-stage sensor integration tracking framework documented in `simulator/integration_matrix.md`.
  - Created 35 unit and integration tests in `tests/test_simulator.py` (100% pass rate).
- **End-to-End Simulation Testing Suite (`test_e2e/`)**:
  - Implemented 4-tier test runner (`test_e2e/runner.py`) executing 381 automated test assertions across device initialization, authentication flows, multi-sensor batch telemetry, and fault injection.
  - Published test certification report in `TEST_READY.md`.
- **100 Labeled Experimental Sessions Campaign (`experiments/`)**:
  - Built independent scenario oracle (`experiments/oracle.py`) generating 100 pre-labeled sessions across 5 stratified categories (20 sessions each): `NORMAL_AUTHORIZED`, `UNAUTHORIZED_CREDENTIAL`, `FORCED_DOOR_OPEN`, `LOAD_OR_TAMPER_ANOMALY`, `SENSOR_FAULT`.
  - Built live API execution engine (`experiments/runner.py`) executing all 100 sessions directly against the Apache Tomcat 9 backend on port 8081 with test database `SL_SIM`. Achieved 100% execution success (100 PASS, 0 FAIL, 0 BLOCKED) in 2.27 s.
  - Built multi-sensor anomaly detector for Proposed B1 and Baseline B0 in `experiments/detection_b1.py`.
  - Built statistical evaluation pipeline in `experiments/evaluate.py`:
    - Confusion matrices for B0 and B1.
    - Precision, recall, F1-score, balanced accuracy with 95% Wilson score confidence intervals.
    - Paired McNemar's test with continuity correction ($\chi^2 = 23.04, p = 2.0\times 10^{-6}$).
    - Execution latency distribution (Mean: 22.67 ms, Median: 16.10 ms, p95: 47.54 ms).
  - Exported LaTeX tables (`table_detection_comparison.tex`, `table_latency_distribution.tex`).
  - Saved raw empirical datasets in `experiments/results/` (`sessions.csv`, `sessions.json`, `sensor_readings.csv`, `backend_requests.jsonl`, `backend_responses.jsonl`, `ground_truth_labels.csv`, `evaluation_metrics.json`).
- **Scopus Conference Analysis & Reviewer Simulation (`docs/paper/`)**:
  - Comprehensive analysis of 15 Scopus-indexed conferences in IoT / Cybersecurity / Applied Computing.
  - 3-Reviewer Independent Simulation Report (IoT Systems, Security, Methodology) with readiness assessment.

### Changed
- **Manuscript Revisions (`docs/paper/smartlocker-10p.tex`)**:
  - **Author Block**: Identified **Duc Hoang Nguyen\*** (`duchoang.nguyen103@gmail.com`) as Corresponding Author with confirmed ORCID `0009-0006-9780-8146`. Preserved official student Gmails without alteration.
  - **Commit Provenance**: Cleanly separated baseline measurements (30 October 2026 commit `da95f43`) from revision verification and multi-sensor simulation (15 November 2026 commit `1cc154a`).
  - **Structure Simplification**:
    - Merged Section III.B (Roles) into Section III.A (`\subsection{Architecture and Access Roles}`).
    - Merged Section IV.E (Audit Log) into Section IV.D (`\subsection{Server-Side Safeguards and Tamper-Evident Audit Log}`).
  - **Table Layout Optimization**:
    - Applied `\renewcommand{\arraystretch}{1.18}` and vertical spacing `\\[2pt]` between rows in Table V (`tab:rules`) to eliminate cramped text.
    - Integrated Table VII (`tab:b0_vs_b1`) detailing comparative metrics between Baseline B0 and Proposed B1.
  - **Figure Enhancements**:
    - Expanded Fig. 2 (workflow diagram) to `width=0.98\linewidth` for horizontal balance.
    - Updated Fig. 9a caption to disclose truncated y-axis ($[0.60, 1.00]$).
    - Integrated English UI screenshots into `ui-user.png` and `ui-staff.png` at native 2120x624 resolution.
  - **Literature Citation**: Updated Arp et al. [13] text to: *"while Arp et al. [13] find these pitfalls widespread in 30 papers from top security venues, including sampling bias and lab-only evaluation."*
  - **Page Budget**: Enforced strictly **10 pages** in compiled PDF (`docs/paper/smartlocker-10p.pdf`) with 0 undefined references (`??`).

### Fixed
- Fixed slot lookup ambiguity in multi-bank configurations (`AMBIGUOUS_SLOT`).
- Fixed clock skew edge case in remote unlock validation (allowed up to 60 s clock lag).
- Removed all legacy agent files (`.claude/`, `CLAUDE.md`, draft notes) from root directory.
