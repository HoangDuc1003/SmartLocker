# Commit-to-Experiment Traceability Report

**Audit Subject**: SmartLocker Reproducible 100-Session Experiment  
**Auditor**: Senior Research & Engineering Execution System  
**Audit Date**: 2026-11-16  

---

## 1. Traceability Chain Overview

This document formalizes the two-stage cryptographic commit provenance linking the live experiment execution to the final manuscript and PDF deliverables.

```
+-----------------------------------------------------------------------------------+
| Stage 1: Verified Code & Live Experiment Execution                                |
| - Tomcat 9 (port 8081) on database SL_SIM                                         |
| - Execution Run ID: RUN_20261116_010959_SEED20261115_SL_SIM                       |
| - 100 sessions executed, five pass gates evaluated, metrics recomputed            |
| - Commit SHA: EXPERIMENT_COMMIT                                                    |
+-----------------------------------------------------------------------------------+
                                          |
                                          v (Cited in smartlocker-10p.tex)
+-----------------------------------------------------------------------------------+
| Stage 2: Manuscript Synchronization & PDF Compilation                             |
| - docs/paper/smartlocker-10p.tex citing EXPERIMENT_COMMIT                         |
| - Tectonic 0.17.0 compilation of Instructor & Scopus PDFs                         |
| - Synchronized documentation (README, FINAL_*.md)                                 |
| - Commit SHA: MANUSCRIPT_COMMIT                                                    |
+-----------------------------------------------------------------------------------+
```

---

## 2. Execution Configuration & Artifact Mapping

- **Run ID**: `RUN_20261116_010959_SEED20261115_SL_SIM`
- **Master PRNG Seed**: 20261115
- **Servlet Backend Container**: Apache Tomcat 9.0.113 listening on HTTP 8081, shutdown 8015
- **Process PID**: 15508
- **Database Engine**: Microsoft SQL Server 2022 (RTM) - 16.0.1000.6 (X64)
- **Database Instance**: `localhost:1433` -> Catalog: `SL_SIM`
- **Target Device**: `LOCKER-01` (device_id: 5, bank: `CANT-A`, area: `Canteen KTX A`)

---

## 3. Verified Performance Metrics Traceability

All metrics published in the final manuscript and reports trace directly to the fresh evaluation output in `experiments/runs/RUN_20261116_010959_SEED20261115_SL_SIM/`:

| Dimension | Baseline B0 | Proposed B1 | Delta | Significance |
|---|:---:|:---:|:---:|---|
| **Macro-F1 Score** | 0.7137 | **1.0000** | +0.2863 (+40.1%) | McNemar $\chi^2 = 25.0370$ |
| **Balanced Accuracy** | 0.7300 | **1.0000** | +0.2700 (+37.0%) | Exact $p = 1.49 \times 10^{-8}$ |
| **Overall Accuracy** | 73.0% (73/100) | **100.0% (100/100)**| +27.0% | Continuity-corrected $p = 5.62 \times 10^{-7}$ |
| **Normal Authorized F1**| 0.5970 | **1.0000** | +0.4030 | B0 Prec: 0.4255, Rec: 1.0000 |
| **Unauthorized Access F1**| 1.0000 | **1.0000** | 0.0000 | Both 100% Prec, 100% Rec |
| **Forced Door F1** | 1.0000 | **1.0000** | 0.0000 | Both 100% Prec, 100% Rec |
| **Load/Tamper F1** | 0.4000 | **1.0000** | +0.6000 | B0 blind to IMU tilt/vibration/shock |
| **Sensor Fault F1** | 0.5714 | **1.0000** | +0.4286 | B0 blind to sonar stuck & transport |
| **Mean Server Latency** | — | — | — | 43.63 ms (p95: 67.78 ms) |
