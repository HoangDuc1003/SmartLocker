# SmartLocker Multi-Sensor Detection Evaluation Report (Direction B)

**Evaluation Date**: 2026-11-16 04:03:25 UTC  
**Total Evaluated Sessions**: 100  
**Architecture**: Baseline B0 (Single-Telemetry) vs. Proposed B1 (Multi-Sensor Fusion)  
**Evaluation Protocol**: 5 Stratified Categories (20 sessions each)  

## 1. Classification Performance Overview

| Metric | Baseline B0 | Proposed B1 | Delta |
|---|---|---|---|
| **Macro F1** | 0.682 | 0.990 | +0.308 |
| **Macro Precision** | 0.882 | 0.990 | +0.108 |
| **Macro Recall** | 0.710 | 0.990 | +0.280 |
| **Overall Accuracy** | 0.710 | 0.990 | +0.280 |
| **Balanced Accuracy** | 0.710 | 0.990 | +0.280 |

## 2. Table V Transfer Check Rows (Synchronized)

| Metric | Multi Accuracy | Multi Prec | Multi Recall | Multi F1 | Binary Acc | Binary F1 |
|---|---|---|---|---|---|---|
| **Transfer Check (B0)** | 0.710 | 0.882 | 0.710 | 0.682 | 0.710 | 0.779 |
| **Transfer Check (B1)** | 0.990 | 0.990 | 0.990 | 0.990 | 0.990 | 0.994 |

## 3. Per-Class Performance Breakdown

### Baseline B0
| Category | Support | Precision | Recall | F1 | 95% Wilson CI (Rec) |
|---|---|---|---|---|---|
| Normal Authorized | 20 | 0.408 | 1.000 | 0.580 | [0.839, 1.000] |
| Unauthorized Credential | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |
| Forced Door Opening | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |
| Load / Tamper Anomaly | 20 | 1.000 | 0.150 | 0.261 | [0.052, 0.360] |
| Sensor or Network Fault | 20 | 1.000 | 0.400 | 0.571 | [0.219, 0.613] |

### Proposed B1 (Multi-Sensor Prototype)
| Category | Support | Precision | Recall | F1 | 95% Wilson CI (Rec) |
|---|---|---|---|---|---|
| Normal Authorized | 20 | 0.952 | 1.000 | 0.976 | [0.839, 1.000] |
| Unauthorized Credential | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |
| Forced Door Opening | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |
| Load / Tamper Anomaly | 20 | 1.000 | 0.950 | 0.974 | [0.764, 0.991] |
| Sensor or Network Fault | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |

## 4. Paired McNemar Test (Binary Normal vs Anomaly)

- **Contingency Table**:
  * n00 (both wrong): 1
  * n01 (B0 wrong, B1 right): 28
  * n10 (B0 right, B1 wrong): 0
  * n11 (both right): 71
- **Continuity-corrected Chi-Square**: 26.0357 (df = 1)
- **Exact Binomial p-value**: 7.4506e-09
- **Odds Ratio**: inf
- **Interpretation**: Proposed B1 significantly outperforms Baseline B0 (p < 0.001)

## 5. End-to-End Session Execution Latency

- **Mean**: 50.77 ms
- **Median (p50)**: 47.84 ms
- **95th Percentile**: 77.72 ms
- **99th Percentile**: 89.59 ms
- **Min / Max**: 29.08 ms / 91.59 ms
