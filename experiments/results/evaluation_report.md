# SmartLocker Multi-Sensor Detection Evaluation Report

**Evaluation Date**: 2026-11-16 01:10:22 UTC  
**Total Evaluated Sessions**: 100  
**Architecture**: Baseline B0 (Single-Telemetry) vs. Proposed B1 (Multi-Sensor Fusion)  

## 1. Executive Performance Summary

| Metric | Baseline B0 | Proposed B1 | Delta (B1 - B0) | Relative Improvement |
|---|:---:|:---:|:---:|:---:|
| **Macro-F1 Score** | 0.7137 | **1.0000** | +0.2863 | +40.1% |
| **Balanced Accuracy** | 0.7300 | **1.0000** | +0.2700 | +37.0% |
| **Overall Accuracy** | 0.7300 | **1.0000** | +0.2700 | +37.0% |
| **Macro Precision** | 0.8851 | **1.0000** | +0.1149 | +13.0% |
| **Macro Recall** | 0.7300 | **1.0000** | +0.2700 | +37.0% |

## 2. Per-Category Performance Breakdown

| Category | Nominal N | B0 Prec | B0 Rec | B0 F1 | B1 Prec | B1 Rec | B1 F1 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| NORMAL_AUTHORIZED | 20 | 0.425 | 1.000 | 0.597 | **1.000** | **1.000** | **1.000** |
| UNAUTHORIZED_CREDENTIAL | 20 | 1.000 | 1.000 | 1.000 | **1.000** | **1.000** | **1.000** |
| FORCED_DOOR_OPEN | 20 | 1.000 | 1.000 | 1.000 | **1.000** | **1.000** | **1.000** |
| LOAD_OR_TAMPER_ANOMALY | 20 | 1.000 | 0.250 | 0.400 | **1.000** | **1.000** | **1.000** |
| SENSOR_FAULT | 20 | 1.000 | 0.400 | 0.571 | **1.000** | **1.000** | **1.000** |
| **Macro Average** | **100** | **0.885** | **0.730** | **0.714** | **1.000** | **1.000** | **1.000** |

## 3. Paired McNemar Statistical Significance Test

Binary Anomaly Detection Classification (Normal vs. Anomaly):

| | B1 Incorrect | B1 Correct | Total |
|---|:---:|:---:|:---:|
| **B0 Incorrect** | 0 (n00) | 27 (n01) | 27 |
| **B0 Correct** | 0 (n10) | 73 (n11) | 73 |
| **Total** | 0 | 100 | **100** |

- **Discordant Pairs**: 27 (B0 only correct: 0, B1 only correct: 27)
- **Chi-Squared Statistic ($\\chi^2$)**: 25.0370 (df=1, Edwards continuity correction)
- **Exact Two-Sided p-value**: `1.49e-08`
- **Statistical Method**: Exact two-sided binomial McNemar test with Edwards continuity correction
- **Null Hypothesis**: The marginal probabilities of correct detection for Baseline B0 and Proposed B1 are identical (P(B0 correct) = P(B1 correct)).
- **Alternative Hypothesis**: The marginal probabilities of correct detection for Baseline B0 and Proposed B1 are significantly different (two-sided).
- **Effect Size (Cohen's g)**: 0.5000 (Large effect (g >= 0.25))
- **Statistically Significant ($p < 0.05$)**: True
- **Statistically Significant ($p < 0.01$)**: True
- **Statistically Significant ($p < 0.001$)**: True

## 4. End-to-End Latency Profile

- **Mean Processing Time**: 43.63 ms
- **Median (p50)**: 42.61 ms
- **95th Percentile (p95)**: 67.78 ms
- **99th Percentile (p99)**: 74.82 ms
- **Minimum Latency**: 15.88 ms
- **Maximum Latency**: 78.02 ms

## 5. Confusion Matrices

### Baseline B0 Confusion Matrix:
```
{
  "NORMAL_AUTHORIZED": {
    "NORMAL_AUTHORIZED": 20,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "UNAUTHORIZED_CREDENTIAL": {
    "NORMAL_AUTHORIZED": 0,
    "UNAUTHORIZED_CREDENTIAL": 20,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "FORCED_DOOR_OPEN": {
    "NORMAL_AUTHORIZED": 0,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 20,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "LOAD_OR_TAMPER_ANOMALY": {
    "NORMAL_AUTHORIZED": 15,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 5,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "SENSOR_FAULT": {
    "NORMAL_AUTHORIZED": 12,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 8,
    "MISSED": 0
  }
}
```

### Proposed B1 Confusion Matrix:
```
{
  "NORMAL_AUTHORIZED": {
    "NORMAL_AUTHORIZED": 20,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "UNAUTHORIZED_CREDENTIAL": {
    "NORMAL_AUTHORIZED": 0,
    "UNAUTHORIZED_CREDENTIAL": 20,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "FORCED_DOOR_OPEN": {
    "NORMAL_AUTHORIZED": 0,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 20,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "LOAD_OR_TAMPER_ANOMALY": {
    "NORMAL_AUTHORIZED": 0,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 20,
    "SENSOR_FAULT": 0,
    "MISSED": 0
  },
  "SENSOR_FAULT": {
    "NORMAL_AUTHORIZED": 0,
    "UNAUTHORIZED_CREDENTIAL": 0,
    "FORCED_DOOR_OPEN": 0,
    "LOAD_OR_TAMPER_ANOMALY": 0,
    "SENSOR_FAULT": 20,
    "MISSED": 0
  }
}
```
