"""
Matrix generator module for 5-Stage Sensor Integration Tracking.
Exports Markdown and JSON matrices and provides verification utilities.
"""

import json
import os
from typing import Optional
from .stage_tracker import SensorIntegrationTracker


def generate_integration_matrix_content(mode: str = "B0") -> str:
    """Generate comprehensive documentation markdown for sensor integration."""
    tracker = SensorIntegrationTracker(mode=mode)
    md_table = tracker.generate_markdown_report()

    header = f"""# SmartLocker Multi-Sensor 5-Stage Integration Matrix

**Evaluation Mode**: Baseline {mode}  
**Specification Reference**: R2 (Phases 2, 3, 8), Features 6–10  
**Compliance Standard**: Acceptance Criteria § Multi-Sensor Integration Tracking  

---

## 1. Executive Summary

This matrix documents the verification status of all 4 software-emulated sensor channels across the 5 distinct integration stages defined in R2:

1. **Stage 1 (Emulator Implemented)**: Physical transduction and noise models implemented in Python (`simulator/sensors/`).
2. **Stage 2 (Payload Generated)**: Telemetry sampled, encoded, and serialized into batch session JSON.
3. **Stage 3 (Payload Transmitted)**: Telemetry transmitted via HTTP REST to the Java backend on port 8081.
4. **Stage 4 (Backend Persisted)**: Backend parses and writes sensor measurements to SQL Server (`LockerSession`).
5. **Stage 5 (Detection / Processed)**: Backend rule engine (`RuleEngine.java`) or anomaly detection evaluates persisted measurements.

---

## 2. 5-Stage Verification Table

{md_table}

---

## 3. Engineering Reality & Architectural Distinction

### 3.1 Fully Integrated Channels (Baseline B0)
- **Door Reed Switch**: Measures `door_open_sec` float. Persisted in `LockerSession.door_open_sec`. Evaluated in `RuleEngine` for `FORCED_OPEN` and `SUSPECTED_SPOOF`.
- **Load Cell (HX711)**: Measures `weight_delta_g` float. Persisted in `LockerSession.weight_delta_g`. Evaluated in `RuleEngine` for `ITEM_LEFT`, `SUSPECTED_SPOOF`, and Weka `RiskScorer`.

### 3.2 Stage 1–3 Only Channels (Baseline B0)
- **Ultrasonic (SRF05)**: Fully simulated in Python (`simulator/sensors/ultrasonic.py`), models user presence (<= 50 cm) and door clearance holding. Transmitted in firmware/payload. **NOT INTEGRATED** in Baseline B0 backend because `LockerSession` has no distance column and `RuleEngine` lacks distance rules.
- **IMU Vibration / Tilt (MPU6050)**: Fully simulated in Python (`simulator/sensors/imu_vibration.py`), models 3-axis acceleration and shock thresholds (> 16g). Transmitted in firmware/payload. **NOT INTEGRATED** in Baseline B0 backend because `LockerSession` has no acceleration/tilt columns and `RuleEngine` lacks vibration rules.

---

## 4. Proposed B1 Extension Pathway (Milestone 3)

In Milestone 3 (Proposed B1), an additive detection module captures Ultrasonic distance and IMU vibration into `LockerSessionReading` and evaluates physical tamper/tampering rules without modifying baseline database tables.
"""
    return header


def write_integration_matrix_file(
    file_path: Optional[str] = None, mode: str = "B0"
) -> str:
    """Write integration matrix markdown to file."""
    if file_path is None:
        file_path = os.path.join(
            os.path.dirname(os.path.dirname(__file__)), "integration_matrix.md"
        )
    content = generate_integration_matrix_content(mode=mode)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    return file_path
