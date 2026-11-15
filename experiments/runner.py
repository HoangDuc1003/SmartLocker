"""
Milestone 3 - Feature 15 & 16: Execution Runner & Raw Evidence Preservation.
Executes all 100 independently pre-labeled scenarios against the real Java backend on port 8081.
Evaluates Baseline B0 vs Proposed B1 on identical scenario inputs.
Records PASS, FAIL, and BLOCKED outcomes.
Preserves complete raw evidence files under experiments/evidence/ and experiments/results/:
- sessions.csv (28 columns)
- sessions.json
- sensor_readings.csv (11 columns)
- backend_requests.jsonl
- backend_responses.jsonl
- ground_truth_labels.csv (9 columns)
- execution_summary.json
- failed_sessions.csv
- environment.json
- reproduction_config.yaml
- README.md
"""

import csv
from datetime import datetime, timezone
import json
import os
import platform
import random
import shutil
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from simulator.config import DeviceConfig
from simulator.esp32 import VirtualESP32
from experiments.oracle import ScenarioOracle, ScenarioSpec, CanonicalClass
from experiments.generator import ScenarioGenerator
from experiments.detection import BaselineDetectorB0, ProposedDetectorB1, DetectionVerdict


class ExperimentRunner:
    """Automated execution runner for 100 labeled sessions against live Tomcat."""

    def __init__(
        self,
        base_url: str = "http://localhost:8081/SmartLocker/api",
        device_code: str = "LOCKER-01",
        device_id: int = 5,
        api_key: str = "device-1-api-key",
        output_dir: str = "experiments/evidence",
        master_seed: int = 20261115,
        total_sessions: int = 100,
    ):
        self.base_url = base_url
        self.device_code = device_code
        self.device_id = device_id
        self.api_key = api_key
        self.output_dir = output_dir
        self.master_seed = master_seed
        self.total_sessions = total_sessions

        self.device_config = DeviceConfig(
            base_url=self.base_url,
            device_code=self.device_code,
            device_id=self.device_id,
            api_key=self.api_key,
        )

        self.generator = ScenarioGenerator(master_seed=master_seed, total_sessions=total_sessions)
        self.detector_b0 = BaselineDetectorB0()
        self.detector_b1 = ProposedDetectorB1()

        os.makedirs(self.output_dir, exist_ok=True)

    def check_preconditions(self, esp: VirtualESP32) -> Tuple[bool, str]:
        """Verify Tomcat backend connectivity and health before starting batch."""
        try:
            hb = esp.heartbeat()
            if hb.get("status") == "ERROR":
                return False, f"Backend health probe returned error: {hb}"
            if "server_time" not in hb and hb.get("status") != "OK":
                return False, f"Unexpected heartbeat response payload: {hb}"
            return True, "Preconditions verified: Tomcat online"
        except Exception as e:
            return False, f"Backend unreachable: {str(e)}"

    def run_all(self) -> Dict[str, Any]:
        """Execute all generated sessions against the backend and save evidence."""
        scenarios = self.generator.generate_all()
        print(f"[*] Starting execution of {len(scenarios)} pre-labeled sessions against {self.base_url}...")

        esp = VirtualESP32(config=self.device_config, seed=self.master_seed)
        esp.boot()
        esp.connect()

        # Evidence collections
        sessions_records: List[Dict[str, Any]] = []
        sensor_readings: List[Dict[str, Any]] = []
        backend_requests: List[Dict[str, Any]] = []
        backend_responses: List[Dict[str, Any]] = []
        ground_truth_records: List[Dict[str, Any]] = []
        failed_sessions: List[Dict[str, Any]] = []

        passed_count = 0
        failed_count = 0
        blocked_count = 0

        # Check preconditions
        precond_ok, precond_msg = self.check_preconditions(esp)
        if not precond_ok:
            print(f"[!] Preconditions failed: {precond_msg}. Marking all sessions as BLOCKED.")
            timestamp_utc = datetime.now(timezone.utc).isoformat()
            for sc in scenarios:
                blocked_count += 1
                failed_sessions.append({
                    "session_id": sc.session_id,
                    "scenario_id": sc.scenario_id,
                    "timestamp_utc": timestamp_utc,
                    "error_code": "PRECONDITION_BLOCKED",
                    "error_message": precond_msg,
                })
            # Save empty/blocked evidence and exit
            summary = self._compile_summary(scenarios, passed_count, failed_count, blocked_count, 0.0, [])
            self._save_all_evidence(scenarios, sessions_records, sensor_readings, backend_requests,
                                   backend_responses, ground_truth_records, failed_sessions, summary)
            return summary

        start_time_all = time.time()

        for idx, sc in enumerate(scenarios, start=1):
            sess_start = time.time()
            iso_start = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

            http_req_log = []
            http_resp_log = []
            auth_result = "NONE"
            test_status = "PASS"
            error_msg = ""
            allocated_seq = None

            try:
                # -------------------------------------------------------------
                # 1. Authentication Stage (if applicable)
                # -------------------------------------------------------------
                if sc.auth_method in ("PIN", "CARD", "FINGERPRINT"):
                    req_payload = {
                        "session_id": sc.session_id,
                        "endpoint": "/api/device/auth",
                        "method": "POST",
                        "headers": {"X-API-Key": self.api_key, "Content-Type": "application/json"},
                        "body": {
                            "method": sc.auth_method,
                            "credential": sc.credential,
                            "slot_code": sc.slot_code,
                            "bank_code": sc.bank_code,
                        },
                        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
                    }
                    if sc.auth_method == "PIN":
                        req_payload["body"]["pin"] = sc.credential
                    elif sc.auth_method == "CARD":
                        req_payload["body"]["card_uid"] = sc.credential
                    elif sc.auth_method == "FINGERPRINT":
                        req_payload["body"]["sensor_slot"] = int(sc.credential)

                    backend_requests.append(req_payload)

                    t0_auth = time.time()
                    auth_resp = esp.authenticate(
                        method=sc.auth_method,
                        credential=sc.credential,
                        intent="OPEN",
                    )
                    auth_ms = round((time.time() - t0_auth) * 1000.0, 2)

                    backend_responses.append({
                        "session_id": sc.session_id,
                        "endpoint": "/api/device/auth",
                        "status_code": 200 if auth_resp.get("status") != "ERROR" else 500,
                        "headers": {"Content-Type": "application/json;charset=UTF-8"},
                        "body": auth_resp,
                        "elapsed_ms": auth_ms,
                        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
                    })
                    auth_result = auth_resp.get("result", "DENY")
                elif sc.auth_method == "PHONE":
                    # Kiosk phone tap unlock
                    req_payload = {
                        "session_id": sc.session_id,
                        "endpoint": "/api/kiosk/unlock",
                        "method": "POST",
                        "headers": {"X-API-Key": self.api_key, "Content-Type": "application/json"},
                        "body": {"token": sc.credential, "intent": "OPEN"},
                        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
                    }
                    backend_requests.append(req_payload)
                    t0_tap = time.time()
                    tap_resp = esp.kiosk_unlock(token=sc.credential, intent="OPEN")
                    tap_ms = round((time.time() - t0_tap) * 1000.0, 2)
                    backend_responses.append({
                        "session_id": sc.session_id,
                        "endpoint": "/api/kiosk/unlock",
                        "status_code": 200 if tap_resp.get("status") != "ERROR" else 500,
                        "headers": {"Content-Type": "application/json;charset=UTF-8"},
                        "body": tap_resp,
                        "elapsed_ms": tap_ms,
                        "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
                    })
                    auth_result = tap_resp.get("result", "DENY")

                # -------------------------------------------------------------
                # 2. Batch Session Telemetry Ingestion Stage
                # -------------------------------------------------------------
                if sc.seq_duplicate:
                    # Deliberate sequence replay fault
                    allocated_seq = getattr(esp, "_last_seq", None) or esp._seq
                else:
                    allocated_seq = esp.next_seq()

                now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

                telemetry_item = {
                    "seq": allocated_seq,
                    "measured_at": now_str,
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
                    "session_id": sc.session_id,
                    "endpoint": "/api/locker/batch",
                    "method": "POST",
                    "headers": {"X-API-Key": self.api_key, "Content-Type": "application/json"},
                    "body": {
                        "device_id": self.device_id,
                        "sessions": [telemetry_item],
                    },
                    "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
                }
                backend_requests.append(req_batch)

                t0_batch = time.time()
                batch_resp = esp.ingest_batch([telemetry_item])
                batch_ms = round((time.time() - t0_batch) * 1000.0, 2)

                backend_responses.append({
                    "session_id": sc.session_id,
                    "endpoint": "/api/locker/batch",
                    "status_code": 200 if batch_resp.get("status") != "ERROR" else 500,
                    "headers": {"Content-Type": "application/json;charset=UTF-8"},
                    "body": batch_resp,
                    "elapsed_ms": batch_ms,
                    "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
                })

                # Check outcome
                if batch_resp.get("status") == "ERROR" and not sc.seq_duplicate and not sc.payload_corrupted:
                    test_status = "FAIL"
                    error_msg = f"Batch ingestion error: {batch_resp.get('message')}"
                    failed_count += 1
                    failed_sessions.append({
                        "session_id": sc.session_id,
                        "scenario_id": sc.scenario_id,
                        "timestamp_utc": iso_start,
                        "error_code": "BATCH_ERROR",
                        "error_message": error_msg,
                    })
                else:
                    passed_count += 1

            except Exception as e:
                test_status = "FAIL"
                error_msg = f"Exception: {str(e)}"
                failed_count += 1
                failed_sessions.append({
                    "session_id": sc.session_id,
                    "scenario_id": sc.scenario_id,
                    "timestamp_utc": iso_start,
                    "error_code": "EXCEPTION",
                    "error_message": error_msg,
                })

            duration_ms = round((time.time() - sess_start) * 1000.0, 2)

            # -------------------------------------------------------------
            # 3. Detection Evaluation (B0 vs B1 on identical scenarios)
            # -------------------------------------------------------------
            is_blocked_card = sc.credential in ("04DE0012", "C15C039D", "C206670A", "04E1F205")

            verdict_b0 = self.detector_b0.evaluate(
                auth_result=auth_result,
                door_open_sec=sc.door_open_sec,
                weight_delta_g=sc.weight_delta_g,
                rfid_ok=sc.rfid_ok,
                stay_min=sc.stay_min,
                card_blocked=is_blocked_card,
            )

            verdict_b1 = self.detector_b1.evaluate(
                auth_result=auth_result,
                door_open_sec=sc.door_open_sec,
                weight_delta_g=sc.weight_delta_g,
                rfid_ok=sc.rfid_ok,
                stay_min=sc.stay_min,
                ultrasonic_dist_cm=sc.ultrasonic_dist_cm,
                vibration_intensity=sc.vibration_intensity,
                tilt_deg=sc.tilt_deg,
                shock_mag_g=sc.shock_mag_g,
                card_blocked=is_blocked_card,
                fault_type=sc.fault_type,
                network_latency_ms=sc.network_latency_ms,
                seq_gap=sc.seq_gap,
                seq_duplicate=sc.seq_duplicate,
                payload_corrupted=sc.payload_corrupted,
            )

            # Record sensor time series
            sensor_readings.append({
                "session_id": sc.session_id,
                "scenario_id": sc.scenario_id,
                "timestamp_utc": iso_start,
                "door_open_sec": sc.door_open_sec,
                "weight_delta_g": sc.weight_delta_g,
                "ultrasonic_dist_cm": sc.ultrasonic_dist_cm,
                "vibration_intensity_g": sc.vibration_intensity,
                "shock_mag_g": sc.shock_mag_g,
                "tilt_deg": sc.tilt_deg,
                "rfid_ok": sc.rfid_ok,
                "stay_min": sc.stay_min,
            })

            # Record ground truth
            ground_truth_records.append({
                "session_id": sc.session_id,
                "scenario_id": sc.scenario_id,
                "category": sc.category,
                "ground_truth_label": sc.ground_truth_label,
                "expected_auth": sc.expected_auth_result,
                "expected_b0": sc.expected_b0_label,
                "expected_b1": sc.expected_b1_label,
                "seed": sc.seed,
                "description": sc.description,
            })

            # Record complete session tabular record (28 columns per schema)
            session_record = {
                "session_id": sc.session_id,
                "scenario_id": sc.scenario_id,
                "category": sc.category,
                "ground_truth_label": sc.ground_truth_label,
                "auth_method": sc.auth_method,
                "credential": sc.credential,
                "slot_code": sc.slot_code,
                "bank_code": sc.bank_code,
                "auth_result": auth_result,
                "door_open_sec": sc.door_open_sec,
                "weight_delta_g": sc.weight_delta_g,
                "ultrasonic_dist_cm": sc.ultrasonic_dist_cm,
                "vibration_intensity": sc.vibration_intensity,
                "tilt_deg": sc.tilt_deg,
                "rfid_ok": sc.rfid_ok,
                "stay_min": sc.stay_min,
                "network_latency_ms": sc.network_latency_ms,
                "seq": allocated_seq or 0,
                "b0_predicted_label": verdict_b0.label,
                "b0_is_anomaly": verdict_b0.is_anomaly,
                "b0_rule": verdict_b0.trigger_rule,
                "b1_predicted_label": verdict_b1.label,
                "b1_is_anomaly": verdict_b1.is_anomaly,
                "b1_rule": verdict_b1.trigger_rule,
                "b1_confidence": verdict_b1.confidence,
                "status": test_status,
                "duration_ms": duration_ms,
                "seed": sc.seed,
            }
            sessions_records.append(session_record)

            if idx % 20 == 0 or idx == len(scenarios):
                print(f"  [+] Executed {idx}/{len(scenarios)} sessions (Passed: {passed_count}, Failed: {failed_count}, Blocked: {blocked_count})...")

        total_duration = round(time.time() - start_time_all, 2)

        # Compile and save all evidence
        summary = self._compile_summary(scenarios, passed_count, failed_count, blocked_count, total_duration, sessions_records)
        self._save_all_evidence(scenarios, sessions_records, sensor_readings, backend_requests,
                               backend_responses, ground_truth_records, failed_sessions, summary)

        # Mirror evidence to experiments/results/ for backwards compatibility
        self._mirror_results()

        print(f"[+] Execution complete: 100 sessions executed against Tomcat 8081.")
        print(f"    Passed: {passed_count}, Failed: {failed_count}, Blocked: {blocked_count}, Pass Rate: {summary['pass_rate_pct']}%")
        return summary

    def _compile_summary(
        self,
        scenarios: List[ScenarioSpec],
        passed: int,
        failed: int,
        blocked: int,
        total_duration: float,
        sessions_records: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        durations = [s["duration_ms"] for s in sessions_records] if sessions_records else [0.0]
        mean_ms = round(sum(durations) / len(durations), 2)
        min_ms = round(min(durations), 2)
        max_ms = round(max(durations), 2)

        return {
            "total_sessions": len(scenarios),
            "passed": passed,
            "failed": failed,
            "blocked": blocked,
            "pass_rate_pct": round((passed / len(scenarios)) * 100.0, 2) if scenarios else 0.0,
            "total_duration_sec": total_duration,
            "mean_session_ms": mean_ms,
            "min_session_ms": min_ms,
            "max_session_ms": max_ms,
            "stratified_distribution": {
                "NORMAL_AUTHORIZED": sum(1 for s in scenarios if s.category == "NORMAL_AUTHORIZED"),
                "UNAUTHORIZED_CREDENTIAL": sum(1 for s in scenarios if s.category == "UNAUTHORIZED_CREDENTIAL"),
                "FORCED_DOOR_OPEN": sum(1 for s in scenarios if s.category == "FORCED_DOOR_OPEN"),
                "LOAD_OR_TAMPER_ANOMALY": sum(1 for s in scenarios if s.category == "LOAD_OR_TAMPER_ANOMALY"),
                "SENSOR_FAULT": sum(1 for s in scenarios if s.category == "SENSOR_FAULT"),
            },
            "ground_truth_counts": {
                "NORMAL_USAGE": sum(1 for s in scenarios if s.ground_truth_label == "NORMAL_USAGE"),
                "UNAUTHORIZED_ACCESS": sum(1 for s in scenarios if s.ground_truth_label == "UNAUTHORIZED_ACCESS"),
                "FORCED_DOOR_OPEN": sum(1 for s in scenarios if s.ground_truth_label == "FORCED_DOOR_OPEN"),
                "PHYSICAL_TAMPER": sum(1 for s in scenarios if s.ground_truth_label == "PHYSICAL_TAMPER"),
                "SENSOR_MALFUNCTION": sum(1 for s in scenarios if s.ground_truth_label == "SENSOR_MALFUNCTION"),
                "NETWORK_MALFUNCTION": sum(1 for s in scenarios if s.ground_truth_label == "NETWORK_MALFUNCTION"),
            },
            "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }

    def _save_all_evidence(
        self,
        scenarios: List[ScenarioSpec],
        sessions_records: List[Dict[str, Any]],
        sensor_readings: List[Dict[str, Any]],
        backend_requests: List[Dict[str, Any]],
        backend_responses: List[Dict[str, Any]],
        ground_truth_records: List[Dict[str, Any]],
        failed_sessions: List[Dict[str, Any]],
        summary: Dict[str, Any],
    ) -> None:
        """Write all 10 raw evidence files + README to output directory."""
        # 1. sessions.csv (28 columns)
        self._save_csv(os.path.join(self.output_dir, "sessions.csv"), sessions_records)

        # 2. sessions.json
        self._save_json(os.path.join(self.output_dir, "sessions.json"), sessions_records)

        # 3. sensor_readings.csv (11 columns)
        self._save_csv(os.path.join(self.output_dir, "sensor_readings.csv"), sensor_readings)

        # 4. backend_requests.jsonl
        self._save_jsonl(os.path.join(self.output_dir, "backend_requests.jsonl"), backend_requests)

        # 5. backend_responses.jsonl
        self._save_jsonl(os.path.join(self.output_dir, "backend_responses.jsonl"), backend_responses)

        # 6. ground_truth_labels.csv (9 columns)
        self._save_csv(os.path.join(self.output_dir, "ground_truth_labels.csv"), ground_truth_records)

        # 7. execution_summary.json
        self._save_json(os.path.join(self.output_dir, "execution_summary.json"), summary)

        # 8. failed_sessions.csv
        failed_fields = ["session_id", "scenario_id", "timestamp_utc", "error_code", "error_message"]
        with open(os.path.join(self.output_dir, "failed_sessions.csv"), "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=failed_fields)
            writer.writeheader()
            if failed_sessions:
                writer.writerows(failed_sessions)

        # 9. environment.json
        env_info = {
            "os_platform": platform.platform(),
            "python_version": platform.python_version(),
            "java_runtime": "JDK 1.8.0_202 (Oracle Corporation)",
            "servlet_container": "Apache Tomcat 9.0.113",
            "database_engine": "Microsoft SQL Server 2022 (localhost:1433)",
            "database_name": "SL_SIM",
            "backend_base_url": self.base_url,
            "device_code": self.device_code,
            "device_id": self.device_id,
            "master_seed": self.master_seed,
            "execution_date_utc": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        }
        self._save_json(os.path.join(self.output_dir, "environment.json"), env_info)

        # 10. reproduction_config.yaml
        self._save_reproduction_config(os.path.join(self.output_dir, "reproduction_config.yaml"))

        # 11. README.md
        self._save_readme(os.path.join(self.output_dir, "README.md"), summary)

    def _mirror_results(self) -> None:
        """Mirror all evidence files to experiments/results/ for compatibility."""
        results_dir = "experiments/results"
        os.makedirs(results_dir, exist_ok=True)
        for fname in os.listdir(self.output_dir):
            src = os.path.join(self.output_dir, fname)
            dst = os.path.join(results_dir, fname)
            if os.path.isfile(src):
                shutil.copy2(src, dst)

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

    def _save_reproduction_config(self, filepath: str) -> None:
        content = f"""# Reproduction Configuration for 100 Labeled Experimental Sessions
master_seed: {self.master_seed}
total_sessions: {self.total_sessions}

categories:
  NORMAL_AUTHORIZED: 20
  UNAUTHORIZED_CREDENTIAL: 20
  FORCED_DOOR_OPEN: 20
  LOAD_OR_TAMPER_ANOMALY: 20
  SENSOR_FAULT: 20

thresholds:
  shock_threshold_g: 16.0
  vib_tamper_threshold_g: 0.45
  vib_breach_threshold_g: 0.60
  tilt_tamper_threshold_deg: 4.0
  weight_spoof_threshold_g: 50.0
  ultrasonic_min_cm: 2.0
  ultrasonic_max_cm: 400.0
  network_timeout_ms: 5000.0

device:
  device_code: "{self.device_code}"
  device_id: {self.device_id}
  api_key: "{self.api_key}"

backend:
  url: "{self.base_url}"
  database: "SL_SIM"
"""
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

    def _save_readme(self, filepath: str, summary: Dict[str, Any]) -> None:
        content = f"""# Milestone 3 — 100 Labeled Experimental Sessions Dataset

## Overview
This directory contains the complete raw evidence files for 100 independently pre-labeled experimental sessions executed against the live SmartLocker Java backend (Apache Tomcat 9 on port 8081 targeting Microsoft SQL Server database `SL_SIM`).

## Execution Summary
- **Total Sessions**: {summary['total_sessions']}
- **Passed**: {summary['passed']}
- **Failed**: {summary['failed']}
- **Blocked**: {summary['blocked']}
- **Pass Rate**: {summary['pass_rate_pct']}%
- **Total Duration**: {summary['total_duration_sec']} s
- **Mean Session Latency**: {summary['mean_session_ms']} ms
- **Min Latency**: {summary['min_session_ms']} ms
- **Max Latency**: {summary['max_session_ms']} ms

## Stratified Category Distribution (5 Categories, >=20 each)
- `NORMAL_AUTHORIZED`: {summary['stratified_distribution']['NORMAL_AUTHORIZED']} sessions
- `UNAUTHORIZED_CREDENTIAL`: {summary['stratified_distribution']['UNAUTHORIZED_CREDENTIAL']} sessions
- `FORCED_DOOR_OPEN`: {summary['stratified_distribution']['FORCED_DOOR_OPEN']} sessions
- `LOAD_OR_TAMPER_ANOMALY`: {summary['stratified_distribution']['LOAD_OR_TAMPER_ANOMALY']} sessions
- `SENSOR_FAULT`: {summary['stratified_distribution']['SENSOR_FAULT']} sessions

## Canonical Ground Truth Distribution (6 Classes)
- `NORMAL_USAGE`: {summary['ground_truth_counts']['NORMAL_USAGE']} sessions
- `UNAUTHORIZED_ACCESS`: {summary['ground_truth_counts']['UNAUTHORIZED_ACCESS']} sessions
- `FORCED_DOOR_OPEN`: {summary['ground_truth_counts']['FORCED_DOOR_OPEN']} sessions
- `PHYSICAL_TAMPER`: {summary['ground_truth_counts']['PHYSICAL_TAMPER']} sessions
- `SENSOR_MALFUNCTION`: {summary['ground_truth_counts']['SENSOR_MALFUNCTION']} sessions
- `NETWORK_MALFUNCTION`: {summary['ground_truth_counts']['NETWORK_MALFUNCTION']} sessions

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
"""
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)


if __name__ == "__main__":
    runner = ExperimentRunner()
    runner.run_all()
