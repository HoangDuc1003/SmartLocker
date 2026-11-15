# Milestone 3 — 100 Labeled Experimental Sessions Dataset

## Overview
This directory contains the complete raw evidence files for 100 independently pre-labeled experimental sessions executed against the live SmartLocker Java backend (Apache Tomcat 9 on port 8081 targeting Microsoft SQL Server database `SL_SIM`).

## Execution Summary
- **Total Sessions**: 100
- **Passed**: 100
- **Failed**: 0
- **Blocked**: 0
- **Pass Rate**: 100.0%
- **Total Duration**: 1.75 s
- **Mean Session Latency**: 17.45 ms
- **Min Latency**: 0.0 ms
- **Max Latency**: 51.0 ms

## Stratified Category Distribution (5 Categories, >=20 each)
- `NORMAL_AUTHORIZED`: 20 sessions
- `UNAUTHORIZED_CREDENTIAL`: 20 sessions
- `FORCED_DOOR_OPEN`: 20 sessions
- `LOAD_OR_TAMPER_ANOMALY`: 20 sessions
- `SENSOR_FAULT`: 20 sessions

## Canonical Ground Truth Distribution (6 Classes)
- `NORMAL_USAGE`: 20 sessions
- `UNAUTHORIZED_ACCESS`: 20 sessions
- `FORCED_DOOR_OPEN`: 20 sessions
- `PHYSICAL_TAMPER`: 20 sessions
- `SENSOR_MALFUNCTION`: 15 sessions
- `NETWORK_MALFUNCTION`: 5 sessions

## Preserved Evidence Files
1. `sessions.csv`: Complete tabular log of all 100 sessions (28 schema-compliant columns).
2. `sessions.json`: Full machine-readable array of all executed session records.
3. `sensor_readings.csv`: Multi-sensor telemetry time series (11 columns).
4. `backend_requests.jsonl`: Raw JSON-lines HTTP requests transmitted to `/api/device/auth` and `/api/locker/batch`.
5. `backend_responses.jsonl`: Raw JSON-lines HTTP responses returned by Tomcat.
6. `ground_truth_labels.csv`: Pre-execution ground-truth labels from `ScenarioOracle` (9 columns).
7. `execution_summary.json`: High-level metrics, timings, and distributions.
8. `failed_sessions.csv`: Audit log of any failed or blocked sessions (empty header on 100% pass).
9. `environment.json`: Host execution environment, Java, Tomcat, and SQL Server versions.
10. `reproduction_config.yaml`: Master PRNG seeds and detection thresholds for deterministic reproduction.
11. `README.md`: This reproduction documentation.

## How to Reproduce
1. Ensure Apache Tomcat 9 is running on port 8081 with database `SL_SIM`.
2. Run the generator: `python experiments/generator.py`
3. Execute against backend: `python experiments/runner.py`
4. Evaluate metrics: `python experiments/evaluate.py`
