# SmartLocker Multi-Sensor Detection Evaluation Report (Direction B)

**Evaluation Date**: 2026-11-16 17:15:15 UTC  
**Total Evaluated Sessions**: 100  
**Architecture**: Baseline B0 (Single-Telemetry) vs. Proposed B1 (Multi-Sensor Fusion)  
**Evaluation Protocol**: 5 Stratified Categories (20 sessions each)  

## 1. Classification Performance Overview

| Metric | Baseline B0 | Proposed B1 | Delta |
|---|---|---|---|
| **Macro F1** | 0.658 | 0.780 | +0.122 |
| **Macro Precision** | 0.790 | 0.868 | +0.078 |
| **Macro Recall** | 0.690 | 0.800 | +0.110 |
| **Overall Accuracy** | 0.690 | 0.800 | +0.110 |
| **Balanced Accuracy** | 0.690 | 0.800 | +0.110 |

## 2. Table V Transfer Check Rows (Synchronized)

| Metric | Multi Accuracy | Multi Prec | Multi Recall | Multi F1 | Binary Acc | Binary F1 |
|---|---|---|---|---|---|---|
| **Transfer Check (B0)** | 0.690 | 0.790 | 0.690 | 0.658 | 0.750 | 0.823 |
| **Transfer Check (B1)** | 0.800 | 0.868 | 0.800 | 0.780 | 0.810 | 0.871 |

## 3. Per-Class Performance Breakdown

### Baseline B0
| Category | Support | Precision | Recall | F1 | 95% Wilson CI (Rec) |
|---|---|---|---|---|---|
| Normal Authorized | 20 | 0.436 | 0.850 | 0.576 | [0.640, 0.948] |
| Unauthorized Credential | 20 | 0.800 | 1.000 | 0.889 | [0.839, 1.000] |
| Forced Door Opening | 20 | 1.000 | 0.950 | 0.974 | [0.764, 0.991] |
| Load / Tamper Anomaly | 20 | 1.000 | 0.150 | 0.261 | [0.052, 0.360] |
| Sensor or Network Fault | 20 | 0.714 | 0.500 | 0.588 | [0.299, 0.701] |

### Proposed B1 (Multi-Sensor Prototype)
| Category | Support | Precision | Recall | F1 | 95% Wilson CI (Rec) |
|---|---|---|---|---|---|
| Normal Authorized | 20 | 0.515 | 0.850 | 0.642 | [0.640, 0.948] |
| Unauthorized Credential | 20 | 1.000 | 1.000 | 1.000 | [0.839, 1.000] |
| Forced Door Opening | 20 | 1.000 | 0.950 | 0.974 | [0.764, 0.991] |
| Load / Tamper Anomaly | 20 | 1.000 | 0.250 | 0.400 | [0.112, 0.469] |
| Sensor or Network Fault | 20 | 0.826 | 0.950 | 0.884 | [0.764, 0.991] |

## 4. Paired McNemar Test (Binary Normal vs Anomaly)

- **Contingency Table**:
  * n00 (both wrong): 19
  * n01 (B0 wrong, B1 right): 6
  * n10 (B0 right, B1 wrong): 0
  * n11 (both right): 75
- **Continuity-corrected Chi-Square**: 4.1667 (df = 1)
- **Exact Binomial p-value**: 3.1250e-02
- **Odds Ratio**: inf
- **Interpretation**: Difference not significant at p < 0.001

## 5. End-to-End Session Execution Latency

- **Mean**: 67.39 ms
- **Median (p50)**: 59.76 ms
- **95th Percentile**: 126.41 ms
- **99th Percentile**: 156.15 ms
- **Min / Max**: 32.0 ms / 249.72 ms
