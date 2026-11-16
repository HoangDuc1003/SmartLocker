# Experiment Provenance Matrix — SmartLocker Live Backend Reproduction

**Run ID**: `RUN_20261116_010959_SEED20261115_SL_SIM`  
**Execution Timestamp**: `2026-11-16T08:09:59Z`  
**Operating System**: Windows 11 Enterprise (64-bit)  
**Database**: Microsoft SQL Server 2022 (localhost:1433) — Database: `SL_SIM`  
**Application Server**: Apache Tomcat 9.0.113 on port 8081 (CATALINA_BASE: `C:\sl-wt\tomcat-8081`, PID: 15508)  
**Java Runtime**: JDK 1.8.0_202 (`C:\Program Files\Java\jdk1.8.0_202`)  
**Target Device**: `LOCKER-01` (device_id: 5, bank: `CANT-A`)  
**Master PRNG Seed**: 20261115  

---

## 1. Five Granular Pass Gates Provenance

| Gate ID | Gate Name | Target Requirement | Evaluation Basis | Observed Success Rate | Status |
|:---:|---|---|---|:---:|:---:|
| **G1** | `transport_pass` | Authentic HTTP REST communication | Status 200 on batch (or timeout verification for `NETWORK_TIMEOUT`) | 100/100 (100.0%) | **PASS** |
| **G2** | `ingestion_pass` | Genuine telemetry persistence | Independent SQL query verification on `SL_SIM.dbo.LockerSession` table | 100/100 (100.0%) | **PASS** |
| **G3** | `auth_pass` | Authentic credential access decision | Exact match against `expected_auth_result` (`UNLOCK` for Normal, `DENY` for Unauthorized) | 100/100 (100.0%) | **PASS** |
| **G4a**| `b0_detection_pass` | Baseline B0 detection accuracy | Match against pre-declared ground truth | 73/100 (73.0%) | **PASS** |
| **G4b**| `b1_detection_pass` | Proposed B1 detection accuracy | Match against pre-declared ground truth | 100/100 (100.0%) | **PASS** |
| **G5** | `end_to_end_pass` | System workflow execution | `transport_pass AND ingestion_pass AND auth_pass` | 100/100 (100.0%) | **PASS** |

---

## 2. Category Stratification & Verification Matrix (20 Sessions Each)

| Category | Nominal N | Gate 1 Transport | Gate 2 Ingestion | Gate 3 Auth | Gate 5 E2E | B0 Accuracy | B1 Accuracy |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `NORMAL_AUTHORIZED` | 20 | 20/20 (100%) | 20/20 (100%) | 20/20 (100% UNLOCK) | 20/20 (100%) | 20/20 (100%) | 20/20 (100%) |
| `UNAUTHORIZED_CREDENTIAL` | 20 | 20/20 (100%) | 20/20 (100%) | 20/20 (100% DENY) | 20/20 (100%) | 20/20 (100%) | 20/20 (100%) |
| `FORCED_DOOR_OPEN` | 20 | 20/20 (100%) | 20/20 (100%) | 20/20 (100% NONE) | 20/20 (100%) | 20/20 (100%) | 20/20 (100%) |
| `LOAD_OR_TAMPER_ANOMALY` | 20 | 20/20 (100%) | 20/20 (100%) | 20/20 (100% NONE) | 20/20 (100%) | 5/20 (25%) | 20/20 (100%) |
| `SENSOR_FAULT` | 20 | 20/20 (100%) | 20/20 (100%) | 20/20 (100% NONE) | 20/20 (100%) | 8/20 (40%) | 20/20 (100%) |
| **Total / Summary** | **100** | **100/100 (100%)** | **100/100 (100%)** | **100/100 (100%)** | **100/100 (100%)** | **73/100 (73%)** | **100/100 (100%)** |

---

## 3. Cryptographic Hashes of Evidence Artifacts

| Artifact Name | Path | SHA-256 Digest |
|---|---|---|
| `sessions.csv` | `experiments/evidence/sessions.csv` | Recorded in `raw_evidence_hashes.json` |
| `sessions.json` | `experiments/evidence/sessions.json` | Recorded in `raw_evidence_hashes.json` |
| `backend_requests.jsonl` | `experiments/evidence/backend_requests.jsonl` | Recorded in `raw_evidence_hashes.json` |
| `backend_responses.jsonl` | `experiments/evidence/backend_responses.jsonl` | Recorded in `raw_evidence_hashes.json` |
| `sensor_readings.csv` | `experiments/evidence/sensor_readings.csv` | Recorded in `raw_evidence_hashes.json` |
| `ground_truth_labels.csv` | `experiments/evidence/ground_truth_labels.csv` | Recorded in `raw_evidence_hashes.json` |
| `execution_summary.json` | `experiments/evidence/execution_summary.json` | Recorded in `raw_evidence_hashes.json` |
| `database_verification.json` | `experiments/evidence/database_verification.json` | Recorded in `raw_evidence_hashes.json` |
| `fixture_manifest.json` | `experiments/evidence/fixture_manifest.json` | Recorded in `raw_evidence_hashes.json` |
