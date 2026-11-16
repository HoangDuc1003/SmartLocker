# SmartLocker Multi-Sensor Detection Evaluation Report (Direction B)

**Evaluation Date**: 2026-11-16 04:41:35 UTC  
**Total Evaluated Sessions**: 100  
**Architecture**: Baseline B0 (Single-Telemetry) vs. Proposed B1 (Multi-Sensor Fusion)  
**Evaluation Protocol**: 5 Stratified Categories (20 sessions each)  

## 1. Classification Performance Overview

| Metric | Baseline B0 | Proposed B1 | Delta |
|---|---|---|---|
| **Macro F1** | 0.621 | 0.913 | +0.292 |
| **Macro Precision** | 0.805 | 0.923 | +0.118 |
| **Macro Recall** | 0.650 | 0.910 | +0.260 |
| **Overall Accuracy** | 0.650 | 0.910 | +0.260 |
| **Balanced Accuracy** | 0.650 | 0.910 | +0.260 |

## 2. Table V Transfer Check Rows (Synchronized)

| Metric | Multi Accuracy | Multi Prec | Multi Recall | Multi F1 | Binary Acc | Binary F1 |
|---|---|---|---|---|---|---|
| **Transfer Check (B0)** | 0.650 | 0.805 | 0.650 | 0.621 | 0.650 | 0.724 |
| **Transfer Check (B1)** | 0.910 | 0.923 | 0.910 | 0.913 | 0.910 | 0.942 |

## 3. Per-Class Performance Breakdown

### Baseline B0
| Category | Support | Precision | Recall | F1 | 95% Wilson CI (Rec) |
|---|---|---|---|---|---|
| Normal Authorized | 20 | 0.358 | 0.950 | 0.521 | [0.764, 0.991] |
| Unauthorized Credential | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |
| Forced Door Opening | 20 | 1.000 | 0.900 | 0.947 | [0.699, 0.972] |
| Load / Tamper Anomaly | 20 | 0.667 | 0.100 | 0.174 | [0.028, 0.301] |
| Sensor or Network Fault | 20 | 1.000 | 0.300 | 0.462 | [0.145, 0.519] |

### Proposed B1 (Multi-Sensor Prototype)
| Category | Support | Precision | Recall | F1 | 95% Wilson CI (Rec) |
|---|---|---|---|---|---|
| Normal Authorized | 20 | 0.720 | 0.900 | 0.800 | [0.699, 0.972] |
| Unauthorized Credential | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |
| Forced Door Opening | 20 | 1.000 | 0.900 | 0.947 | [0.699, 0.972] |
| Load / Tamper Anomaly | 20 | 0.895 | 0.850 | 0.872 | [0.640, 0.948] |
| Sensor or Network Fault | 20 | 1.000 | 0.900 | 0.947 | [0.699, 0.972] |

## 4. Paired McNemar Test (Binary Normal vs Anomaly)

- **Contingency Table**:
  * n00 (both wrong): 8
  * n01 (B0 wrong, B1 right): 27
  * n10 (B0 right, B1 wrong): 1
  * n11 (both right): 64
- **Continuity-corrected Chi-Square**: 22.3214 (df = 1)
- **Exact Binomial p-value**: 2.1607e-07
- **Odds Ratio**: 27.0
- **Interpretation**: Proposed B1 significantly outperforms Baseline B0 (p < 0.001)

## 5. End-to-End Session Execution Latency

- **Mean**: 48.55 ms
- **Median (p50)**: 47.38 ms
- **95th Percentile**: 71.54 ms
- **99th Percentile**: 80.33 ms
- **Min / Max**: 25.85 ms / 91.94 ms
