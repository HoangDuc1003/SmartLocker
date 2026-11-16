# SmartLocker 100-Session Live Experimental Dataset

## Overview
This directory contains the complete raw evidence files for 100 independently pre-labeled experimental sessions executed against the live SmartLocker Java backend (Apache Tomcat 9 on port 8081 targeting Microsoft SQL Server database `SL_SIM`).

- **Run ID**: `RUN_20261116_010959_SEED20261115_SL_SIM`
- **Execution Timestamp**: `2026-11-16T01:10:03Z`
- **Master PRNG Seed**: `20261115`

## Five Granular Pass Gates
1. **Transport Pass**: 100/100 (100.0%)
2. **Database Ingestion Pass**: 100/100 (100.0%)
3. **Authentication Pass**: 100/100 (100.0%)
4. **Detector Classification**:
   - Baseline B0 Detection Pass: 73/100 (73.0%)
   - Proposed B1 Detection Pass: 100/100 (100.0%)
5. **End-to-End System Workflow Pass**: 100/100 (100.0%)

## Stratified Category Distribution (5 Categories, 20 each)
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
