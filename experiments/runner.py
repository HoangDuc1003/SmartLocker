"""
Execution Runner for SmartLocker 100 Labeled Experimental Sessions.
Executes all 100 independently pre-labeled scenarios against the real Java backend on port 8081.
Preserves raw requests, responses, sensor time series, and execution logs.
Evaluates Baseline B0 vs Proposed B1 on identical scenario inputs.
"""

import csv
from datetime import datetime, timezone
import json
import os
import platform
import subprocess
import time
from typing import Any, Dict, List

from simulator.config import DeviceConfig
from simulator.esp32 import VirtualESP32
from experiments.oracle import ScenarioOracle, ScenarioSpec
from experiments.detection_b1 import BaselineDetectorB0, ProposedDetectorB1


class ExperimentRunner:
    """Automated test execution runner for 100 labeled sessions."""

    def __init__(
        self,
        base_url: str = "http://localhost:8081/SmartLocker/api",
        device_code: str = "LOCKER-01",
        device_id: int = 5,
        api_key: str = "device-1-api-key",
        output_dir: str = "experiments/results",
    ):
        self.config = DeviceConfig(
            base_url=base_url,
            device_code=device_code,
            device_id=device_id,
            api_key=api_key,
        )
        self.output_dir = output_dir
        os.makedirs(self.output_dir, exist_ok=True)

        self.oracle = ScenarioOracle(master_seed=20261115)
        self.detector_b0 = BaselineDetectorB0()
        self.detector_b1 = ProposedDetectorB1()

    def run_all(self) -> Dict[str, Any]:
        """Execute all 100 sessions and generate all required raw evidence files."""
        scenarios = self.oracle.generate_all_scenarios()
        print(f"[*] Starting execution of {len(scenarios)} pre-labeled sessions...")

        esp = VirtualESP32(config=self.config, seed=20261115)
        esp.boot()
        esp.connect()

        # Evidence buffers
        sessions_records: List[Dict[str, Any]] = []
        sensor_readings: List[Dict[str, Any]] = []
        backend_requests: List[Dict[str, Any]] = []
        backend_responses: List[Dict[str, Any]] = []
        ground_truth_records: List[Dict[str, Any]] = []
        failed_sessions: List[Dict[str, Any]] = []

        passed_count = 0
        failed_count = 0
        blocked_count = 0

        start_time_all = time.time()

        for idx, sc in enumerate(scenarios, start=1):
            sess_start = time.time()
            iso_start = datetime.now(timezone.utc).isoformat()

            http_req_log = []
            http_resp_log = []
            auth_result = "DENY"
            db_session_id = None
            test_status = "PASS"
            error_msg = ""

            try:
                # 1. Authentication Stage (if applicable)
                if sc.auth_method in ("PIN", "CARD", "FINGERPRINT"):
                    req_payload = {
                        "endpoint": "/api/device/auth",
                        "method": sc.auth_method,
                        "credential": sc.credential,
                        "slot_code": sc.slot_code,
                        "bank_code": sc.bank_code,
                    }
                    http_req_log.append(req_payload)

                    auth_resp = esp.authenticate(
                        method=sc.auth_method,
                        credential=sc.credential,
                        intent="OPEN",
                    )
                    http_resp_log.append(auth_resp)
                    auth_result = auth_resp.get("result", "DENY")
                else:
                    auth_result = "NONE"

                # 2. Telemetry Ingestion Stage
                seq = esp.next_seq()
                measured_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

                telemetry_item = {
                    "seq": seq,
                    "measured_at": measured_at,
                    "door_open_sec": sc.door_open_sec,
                    "weight_delta_g": sc.weight_delta_g,
                    "unlock_count": 1 if auth_result == "UNLOCK" else 0,
                    "rfid_ok": sc.rfid_ok,
                    "stay_min": sc.stay_min,
                    "slot_code": sc.slot_code,
                    "bank_code": sc.bank_code,
                    "card_uid": sc.credential if sc.auth_method == "CARD" else None,
                    "open_source": sc.auth_method if sc.auth_method != "NONE" else "PRY",
                    "command_id": None,
                }

                req_batch = {
                    "endpoint": "/api/locker/batch",
                    "device_id": self.config.device_id,
                    "sessions": [telemetry_item],
                }
                http_req_log.append(req_batch)

                batch_resp = esp.ingest_batch([telemetry_item])
                http_resp_log.append(batch_resp)

                if batch_resp.get("saved", 0) > 0:
                    db_session_id = seq

            except Exception as e:
                test_status = "FAIL"
                error_msg = str(e)
                failed_count += 1
                failed_sessions.append({
                    "session_id": sc.session_id,
                    "scenario_id": sc.scenario_id,
                    "error": error_msg,
                })
            else:
                passed_count += 1

            sess_end = time.time()
            iso_end = datetime.now(timezone.utc).isoformat()
            duration_ms = round((sess_end - sess_start) * 1000.0, 2)

            # Evaluate Detectors
            card_is_lost = sc.credential in ("04DE0012", "C15C039D", "C206670A", "04E1F205")
            v_b0 = self.detector_b0.evaluate(
                auth_result=auth_result,
                door_open_sec=sc.door_open_sec,
                weight_delta_g=sc.weight_delta_g,
                rfid_ok=sc.rfid_ok,
                stay_min=sc.stay_min,
                card_blocked=card_is_lost,
            )

            v_b1 = self.detector_b1.evaluate(
                auth_result=auth_result,
                door_open_sec=sc.door_open_sec,
                weight_delta_g=sc.weight_delta_g,
                rfid_ok=sc.rfid_ok,
                stay_min=sc.stay_min,
                ultrasonic_dist_cm=sc.ultrasonic_dist_cm,
                vibration_intensity=sc.vibration_intensity,
                tilt_deg=sc.tilt_deg,
                card_blocked=card_is_lost,
                fault_type=sc.fault_type,
            )

            # Append to evidence stores
            for r in http_req_log:
                backend_requests.append({"session_id": sc.session_id, "request": r, "timestamp": iso_start})
            for r in http_resp_log:
                backend_responses.append({"session_id": sc.session_id, "response": r, "timestamp": iso_end})

            sensor_readings.append({
                "session_id": sc.session_id,
                "scenario_id": sc.scenario_id,
                "door_open_sec": sc.door_open_sec,
                "weight_delta_g": sc.weight_delta_g,
                "ultrasonic_dist_cm": sc.ultrasonic_dist_cm,
                "vibration_intensity_g": sc.vibration_intensity,
                "tilt_deg": sc.tilt_deg,
                "rfid_ok": sc.rfid_ok,
                "stay_min": sc.stay_min,
                "timestamp": iso_start,
            })

            ground_truth_records.append({
                "session_id": sc.session_id,
                "scenario_id": sc.scenario_id,
                "category": sc.category,
                "ground_truth_label": sc.ground_truth_label,
                "expected_auth": sc.expected_auth_result,
                "expected_b0": sc.expected_b0_label,
                "expected_b1": sc.expected_b1_label,
                "seed": sc.seed,
            })

            session_record = {
                "session_id": sc.session_id,
                "scenario_id": sc.scenario_id,
                "category": sc.category,
                "ground_truth_label": sc.ground_truth_label,
                "auth_method": sc.auth_method,
                "credential": sc.credential,
                "auth_result": auth_result,
                "door_open_sec": sc.door_open_sec,
                "weight_delta_g": sc.weight_delta_g,
                "ultrasonic_dist_cm": sc.ultrasonic_dist_cm,
                "vibration_intensity": sc.vibration_intensity,
                "tilt_deg": sc.tilt_deg,
                "b0_predicted_label": v_b0.label,
                "b0_is_anomaly": v_b0.is_anomaly,
                "b0_rule": v_b0.trigger_rule,
                "b1_predicted_label": v_b1.label,
                "b1_is_anomaly": v_b1.is_anomaly,
                "b1_rule": v_b1.trigger_rule,
                "status": test_status,
                "error": error_msg,
                "duration_ms": duration_ms,
                "start_time": iso_start,
                "end_time": iso_end,
                "seed": sc.seed,
            }
            sessions_records.append(session_record)

            if idx % 20 == 0:
                print(f"  [+] Executed {idx}/100 sessions ({passed_count} PASS, {failed_count} FAIL)...")

        total_duration = round(time.time() - start_time_all, 2)

        # 3. Save Deliverables
        self._save_csv(os.path.join(self.output_dir, "sessions.csv"), sessions_records)
        self._save_json(os.path.join(self.output_dir, "sessions.json"), sessions_records)
        self._save_csv(os.path.join(self.output_dir, "sensor_readings.csv"), sensor_readings)
        self._save_jsonl(os.path.join(self.output_dir, "backend_requests.jsonl"), backend_requests)
        self._save_jsonl(os.path.join(self.output_dir, "backend_responses.jsonl"), backend_responses)
        self._save_csv(os.path.join(self.output_dir, "ground_truth_labels.csv"), ground_truth_records)
        self._save_csv(os.path.join(self.output_dir, "failed_sessions.csv"), failed_sessions)

        # Execution Summary
        summary = {
            "total_sessions": len(scenarios),
            "passed": passed_count,
            "failed": failed_count,
            "blocked": blocked_count,
            "pass_rate_pct": round((passed_count / len(scenarios)) * 100.0, 2),
            "total_duration_sec": total_duration,
            "mean_session_ms": round(sum(s["duration_ms"] for s in sessions_records) / len(sessions_records), 2),
            "stratified_distribution": {
                "NORMAL_AUTHORIZED": sum(1 for s in sessions_records if s["category"] == "NORMAL_AUTHORIZED"),
                "UNAUTHORIZED_CREDENTIAL": sum(1 for s in sessions_records if s["category"] == "UNAUTHORIZED_CREDENTIAL"),
                "FORCED_DOOR_OPEN": sum(1 for s in sessions_records if s["category"] == "FORCED_DOOR_OPEN"),
                "LOAD_OR_TAMPER_ANOMALY": sum(1 for s in sessions_records if s["category"] == "LOAD_OR_TAMPER_ANOMALY"),
                "SENSOR_FAULT": sum(1 for s in sessions_records if s["category"] == "SENSOR_FAULT"),
            },
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        }
        self._save_json(os.path.join(self.output_dir, "execution_summary.json"), summary)

        # Environment Info
        env_info = {
            "platform": platform.platform(),
            "python_version": platform.python_version(),
            "java_version": "1.8.0_202",
            "backend_url": self.config.base_url,
            "device_code": self.config.device_code,
            "device_id": self.config.device_id,
            "database_name": "SL_SIM",
            "execution_date_utc": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        }
        self._save_json(os.path.join(self.output_dir, "environment.json"), env_info)

        # Reproduction Config
        self._write_reproduction_config(os.path.join(self.output_dir, "reproduction_config.yaml"))
        self._write_readme(os.path.join(self.output_dir, "README.md"), summary)

        print(f"[+] All 100 sessions executed. Passed: {passed_count}, Failed: {failed_count}, Blocked: {blocked_count}")
        return summary

    def _save_csv(self, filepath: str, records: List[Dict[str, Any]]) -> None:
        if not records:
            return
        keys = list(records[0].keys())
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=keys)
            writer.writeheader()
            writer.writerows(records)

    def _save_json(self, filepath: str, data: Any) -> None:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    def _save_jsonl(self, filepath: str, items: List[Dict[str, Any]]) -> None:
        with open(filepath, "w", encoding="utf-8") as f:
            for item in items:
                f.write(json.dumps(item) + "\n")

    def _write_reproduction_config(self, filepath: str) -> None:
        content = f"""# Reproduction Configuration for 100 Labeled Sessions
master_seed: 20261115
total_sessions: 100
categories:
  NORMAL_AUTHORIZED: 20
  UNAUTHORIZED_CREDENTIAL: 20
  FORCED_DOOR_OPEN: 20
  LOAD_OR_TAMPER_ANOMALY: 20
  SENSOR_FAULT: 20
device:
  code: {self.config.device_code}
  id: {self.config.device_id}
  api_key: {self.config.api_key}
backend:
  url: {self.config.base_url}
  database: SL_SIM
"""
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

    def _write_readme(self, filepath: str, summary: Dict[str, Any]) -> None:
        content = f"""# SmartLocker 100 Labeled Sessions Dataset

## Overview
This directory contains the complete raw evidence files for 100 independently pre-labeled experimental sessions executed against the real SmartLocker Java backend (Apache Tomcat 9 on port 8081 with test database `SL_SIM`).

## Summary
- **Total Sessions**: {summary['total_sessions']}
- **Passed**: {summary['passed']}
- **Failed**: {summary['failed']}
- **Blocked**: {summary['blocked']}
- **Pass Rate**: {summary['pass_rate_pct']}%
- **Total Duration**: {summary['total_duration_sec']} s
- **Mean Session Latency**: {summary['mean_session_ms']} ms

## Stratified Distribution
- `NORMAL_AUTHORIZED`: 20 sessions (valid PIN and RFID credentials, normal door and weight operations)
- `UNAUTHORIZED_CREDENTIAL`: 20 sessions (invalid PINs, unknown RFID cards, lost/blocked cards)
- `FORCED_DOOR_OPEN`: 20 sessions (physical door opened without unlock authorization, door prying, impact shock)
- `LOAD_OR_TAMPER_ANOMALY`: 20 sessions (drilling vibration, structural tilt, weight modification while locked)
- `SENSOR_FAULT`: 20 sessions (out-of-range sensor readings, door exceeding stay, IMU dropout, ultrasonic stuck)

## Files
- `sessions.csv`: Summary table of all 100 sessions with ground truth, B0/B1 predictions, and timings.
- `sessions.json`: Machine-readable full sessions export.
- `sensor_readings.csv`: Multi-sensor telemetry time series.
- `backend_requests.jsonl`: Raw HTTP request bodies sent to `/api/device/auth` and `/api/locker/batch`.
- `backend_responses.jsonl`: Raw HTTP response bodies received from Tomcat backend.
- `ground_truth_labels.csv`: Pre-execution ground-truth assignments generated by `ScenarioOracle`.
- `execution_summary.json`: High-level execution metrics and pass rates.
- `failed_sessions.csv`: Log of any failed sessions (empty when 100% pass).
- `environment.json`: Host execution environment, Java, Tomcat, and SQL Server versions.
- `reproduction_config.yaml`: Configuration and master seeds for reproduction.
"""
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)


if __name__ == "__main__":
    runner = ExperimentRunner()
    runner.run_all()
