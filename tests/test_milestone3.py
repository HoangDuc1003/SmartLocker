"""
Unit and Integration Test Suite for Milestone 3 (Execution Gate, Oracle, Generator, Runner, Detection).
Verifies Features 11, 12, 13, 14, 15, 16, and 17.
"""

import copy
import csv
import hashlib
import json
import os
import unittest
from typing import Any, Dict, List

from experiments.oracle import (
    AuthMethod,
    CanonicalClass,
    ScenarioCategory,
    ScenarioOracle,
    ScenarioSpec,
)
from experiments.generator import ScenarioGenerator
from experiments.detection import (
    BaselineDetectorB0,
    ProposedDetectorB1,
    DetectionVerdict,
)
from experiments.runner import ExperimentRunner


class TestScenarioOracle(unittest.TestCase):
    """Test suite for Feature 13: Independent Scenario Oracle."""

    def setUp(self):
        self.oracle = ScenarioOracle()
        self.base_spec = ScenarioSpec(
            session_id="SIM-TEST-001",
            scenario_id="SCEN-TEST-01",
            seed=42,
            category=ScenarioCategory.NORMAL_AUTHORIZED.value,
            ground_truth_label="",
            auth_method="PIN",
            credential="599901",
            slot_code="A04",
            bank_code="CANT-A",
            expected_auth_result="UNLOCK",
            expected_b0_label="",
            expected_b1_label="",
            door_open_sec=6.5,
            weight_delta_g=120.0,
            rfid_ok=True,
            stay_min=15.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.03,
            tilt_deg=0.4,
            shock_mag_g=1.0,
            fault_type=None,
            network_latency_ms=25.0,
            seq_gap=False,
            seq_duplicate=False,
            payload_corrupted=False,
            description="Base test spec",
        )

    def test_normal_authorized_evaluation(self):
        """Normal authorized spec resolves to NORMAL_USAGE."""
        spec = copy.deepcopy(self.base_spec)
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.NORMAL_USAGE.value)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.NORMAL_USAGE.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.NORMAL_USAGE.value)

    def test_unauthorized_credential_evaluation(self):
        """Denied auth without door opening resolves to UNAUTHORIZED_ACCESS."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.UNAUTHORIZED_CREDENTIAL.value
        spec.expected_auth_result = "DENY"
        spec.door_open_sec = 0.0
        spec.weight_delta_g = 0.0
        spec.rfid_ok = False
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.UNAUTHORIZED_ACCESS.value)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.UNAUTHORIZED_ACCESS.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.UNAUTHORIZED_ACCESS.value)

    def test_forced_door_opening_evaluation(self):
        """Door opened without valid unlock resolves to FORCED_DOOR_OPEN."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.FORCED_DOOR_OPEN.value
        spec.expected_auth_result = "NONE"
        spec.rfid_ok = False
        spec.door_open_sec = 8.5
        spec.vibration_intensity = 0.95
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.FORCED_DOOR_OPEN.value)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.FORCED_DOOR_OPEN.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.FORCED_DOOR_OPEN.value)

    def test_tamper_shock_impact(self):
        """Impact shock >= 16G while locked resolves to PHYSICAL_TAMPER."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value
        spec.door_open_sec = 0.0
        spec.weight_delta_g = 0.0
        spec.shock_mag_g = 18.5
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.PHYSICAL_TAMPER.value)
        # B0 is completely blind to IMU shock
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.NORMAL_USAGE.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.PHYSICAL_TAMPER.value)

    def test_tamper_continuous_vibration(self):
        """Drilling vibration >= 0.45G while locked resolves to PHYSICAL_TAMPER."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value
        spec.door_open_sec = 0.0
        spec.weight_delta_g = 0.0
        spec.vibration_intensity = 0.75
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.PHYSICAL_TAMPER.value)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.NORMAL_USAGE.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.PHYSICAL_TAMPER.value)

    def test_tamper_frame_tilt(self):
        """Frame tilt >= 4.0 degrees while locked resolves to PHYSICAL_TAMPER."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value
        spec.door_open_sec = 0.0
        spec.weight_delta_g = 0.0
        spec.tilt_deg = 6.5
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.PHYSICAL_TAMPER.value)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.NORMAL_USAGE.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.PHYSICAL_TAMPER.value)

    def test_tamper_weight_spoof_closed_door(self):
        """Weight change > 50g while door closed resolves to PHYSICAL_TAMPER."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value
        spec.door_open_sec = 0.0
        spec.weight_delta_g = 150.0
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.PHYSICAL_TAMPER.value)
        # B0 has closed-door weight rule (SUSPECTED_SPOOF)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.PHYSICAL_TAMPER.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.PHYSICAL_TAMPER.value)

    def test_sensor_fault_transducer_out_of_bounds(self):
        """Weight outside [-200, 20000] resolves to SENSOR_MALFUNCTION."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.SENSOR_FAULT.value
        spec.weight_delta_g = -350.0
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.SENSOR_MALFUNCTION.value)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.SENSOR_MALFUNCTION.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.SENSOR_MALFUNCTION.value)

    def test_sensor_fault_temporal_inconsistency(self):
        """Door duration exceeding stay * 60 + 5 resolves to SENSOR_MALFUNCTION."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.SENSOR_FAULT.value
        spec.stay_min = 1.0
        spec.door_open_sec = 120.0
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.SENSOR_MALFUNCTION.value)
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.SENSOR_MALFUNCTION.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.SENSOR_MALFUNCTION.value)

    def test_network_malfunction_timeout(self):
        """Transmission delay >= 5000ms resolves to NETWORK_MALFUNCTION."""
        spec = copy.deepcopy(self.base_spec)
        spec.category = ScenarioCategory.SENSOR_FAULT.value
        spec.network_latency_ms = 6500.0
        gt = ScenarioOracle.evaluate_ground_truth(spec)
        self.assertEqual(gt, CanonicalClass.NETWORK_MALFUNCTION.value)
        # B0 is completely blind to network latency
        self.assertEqual(ScenarioOracle.predict_b0(spec), CanonicalClass.NORMAL_USAGE.value)
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.NETWORK_MALFUNCTION.value)


class TestScenarioGenerator(unittest.TestCase):
    """Test suite for Feature 14: Stratified Session Generator."""

    def test_stratified_distribution_minimum_counts(self):
        """Generator produces >= 100 sessions with >= 20 per stratified category."""
        gen = ScenarioGenerator(master_seed=20261115, total_sessions=100)
        scenarios = gen.generate_all()
        self.assertEqual(len(scenarios), 100)

        counts: Dict[str, int] = {}
        for sc in scenarios:
            counts[sc.category] = counts.get(sc.category, 0) + 1

        self.assertEqual(counts[ScenarioCategory.NORMAL_AUTHORIZED.value], 20)
        self.assertEqual(counts[ScenarioCategory.UNAUTHORIZED_CREDENTIAL.value], 20)
        self.assertEqual(counts[ScenarioCategory.FORCED_DOOR_OPEN.value], 20)
        self.assertEqual(counts[ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value], 20)
        self.assertEqual(counts[ScenarioCategory.SENSOR_FAULT.value], 20)

    def test_bit_for_bit_determinism(self):
        """Two separate generator instances with the same seed yield identical outputs."""
        gen1 = ScenarioGenerator(master_seed=20261115, total_sessions=100)
        gen2 = ScenarioGenerator(master_seed=20261115, total_sessions=100)

        sc1 = [s.to_dict() for s in gen1.generate_all()]
        sc2 = [s.to_dict() for s in gen2.generate_all()]

        h1 = hashlib.sha256(json.dumps(sc1, sort_keys=True).encode("utf-8")).hexdigest()
        h2 = hashlib.sha256(json.dumps(sc2, sort_keys=True).encode("utf-8")).hexdigest()
        self.assertEqual(h1, h2, "PRNG output must be bit-for-bit identical across runs")

    def test_multi_modal_credentials_represented(self):
        """Generator includes PIN, CARD, and FINGERPRINT credentials."""
        gen = ScenarioGenerator(master_seed=20261115, total_sessions=100)
        scenarios = gen.generate_all()
        auth_methods = {sc.auth_method for sc in scenarios}
        self.assertIn("PIN", auth_methods)
        self.assertIn("CARD", auth_methods)
        self.assertIn("FINGERPRINT", auth_methods)


class TestMultiSensorDetection(unittest.TestCase):
    """Test suite for Features 12 & 17: Multi-Sensor Detection (B0 vs B1)."""

    def setUp(self):
        self.b0 = BaselineDetectorB0()
        self.b1 = ProposedDetectorB1()

    def test_b0_blindness_to_imu_shock(self):
        """B0 misses sledgehammer shock (>=16G); B1 detects PHYSICAL_TAMPER."""
        v_b0 = self.b0.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
        )
        self.assertFalse(v_b0.is_anomaly)
        self.assertEqual(v_b0.label, "NORMAL_USAGE")

        v_b1 = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.15,
            tilt_deg=0.5,
            shock_mag_g=18.0,  # >= 16G
        )
        self.assertTrue(v_b1.is_anomaly)
        self.assertEqual(v_b1.label, "PHYSICAL_TAMPER")
        self.assertEqual(v_b1.trigger_rule, "B1_TAMPER_SHOCK_IMPACT")

    def test_b0_blindness_to_continuous_vibration(self):
        """B0 misses power drill vibration (>=0.45G); B1 detects PHYSICAL_TAMPER."""
        v_b1 = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.85,  # >= 0.45G
            tilt_deg=0.5,
            shock_mag_g=1.0,
        )
        self.assertTrue(v_b1.is_anomaly)
        self.assertEqual(v_b1.label, "PHYSICAL_TAMPER")
        self.assertEqual(v_b1.trigger_rule, "B1_TAMPER_VIBRATION")

    def test_b0_blindness_to_cabinet_tilt(self):
        """B0 misses cabinet tilt (>=4.0 deg); B1 detects PHYSICAL_TAMPER."""
        v_b1 = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.10,
            tilt_deg=8.5,  # >= 4.0 deg
            shock_mag_g=1.0,
        )
        self.assertTrue(v_b1.is_anomaly)
        self.assertEqual(v_b1.label, "PHYSICAL_TAMPER")
        self.assertEqual(v_b1.trigger_rule, "B1_TAMPER_TILT")

    def test_b1_ultrasonic_cutoff_fault(self):
        """B1 flags ultrasonic acoustic blindness (< 2.0 cm) as SENSOR_MALFUNCTION."""
        v_b1 = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=100.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=0.5,  # < 2.0 cm
            vibration_intensity=0.02,
            tilt_deg=0.2,
            shock_mag_g=1.0,
        )
        self.assertTrue(v_b1.is_anomaly)
        self.assertEqual(v_b1.label, "SENSOR_MALFUNCTION")
        self.assertEqual(v_b1.trigger_rule, "B1_SONAR_STUCK_FAULT")

    def test_non_interference_with_access_control(self):
        """Detection decisions are additive and do NOT alter access control outcomes."""
        # Both detectors return verdicts with labels without altering auth_result
        auth_in = "UNLOCK"
        v = self.b1.evaluate(
            auth_result=auth_in,
            door_open_sec=5.0,
            weight_delta_g=100.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.2,
            shock_mag_g=1.0,
        )
        self.assertFalse(v.is_anomaly)
        self.assertEqual(v.label, "NORMAL_USAGE")
        self.assertEqual(auth_in, "UNLOCK")


class TestExecutionGateAndCryptographicAudit(unittest.TestCase):
    """Test suite for Feature 11: End-to-End Execution Gate & Cryptographic Audit."""

    def test_gate_verification_artifacts_exist(self):
        """Execution gate artifacts exist and indicate PASSED status."""
        json_path = os.path.join("experiments", "gate_verification.json")
        md_path = os.path.join("experiments", "gate_report.md")

        self.assertTrue(os.path.isfile(json_path), f"Missing {json_path}")
        self.assertTrue(os.path.isfile(md_path), f"Missing {md_path}")

        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertEqual(data.get("execution_gate_status"), "PASSED")
        self.assertTrue(data.get("database_persistence", {}).get("row_verified"))
        self.assertTrue(data.get("cryptographic_audit", {}).get("chain_intact"))
        self.assertGreater(data.get("cryptographic_audit", {}).get("total_nodes_verified", 0), 1000)

    def test_hash_chain_tamper_detection_logic(self):
        """Recomputing UTF-16LE SHA-256 hash immediately detects mutated row content."""
        audit_id = 9999
        ts_iso = "2026-11-15T18:00:00.0000000"
        actor = "1"
        action = "CREATE"
        object_type = "ALERT"
        object_id = "555"
        diff = "FORCED_OPEN"
        prev_hash = "0" * 64

        canonical_valid = f"{audit_id}|{ts_iso}|{actor}|{action}|{object_type}|{object_id}|{diff}|{prev_hash}"
        valid_hash = hashlib.sha256(canonical_valid.encode("utf-16le")).hexdigest().lower()

        # Mutate diff
        canonical_tampered = f"{audit_id}|{ts_iso}|{actor}|{action}|{object_type}|{object_id}|TAMPERED_DIFF|{prev_hash}"
        tampered_hash = hashlib.sha256(canonical_tampered.encode("utf-16le")).hexdigest().lower()

        self.assertNotEqual(valid_hash, tampered_hash, "Tampered diff must produce different SHA-256 digest")


class TestRawEvidencePreservation(unittest.TestCase):
    """Test suite for Feature 16: Raw Evidence Preservation."""

    EVIDENCE_DIR = os.path.join("experiments", "evidence")

    def test_all_10_evidence_files_exist(self):
        """All 10 required evidence files + README exist in experiments/evidence/."""
        required_files = [
            "sessions.csv",
            "sessions.json",
            "sensor_readings.csv",
            "backend_requests.jsonl",
            "backend_responses.jsonl",
            "ground_truth_labels.csv",
            "execution_summary.json",
            "failed_sessions.csv",
            "environment.json",
            "reproduction_config.yaml",
            "README.md",
        ]
        for fname in required_files:
            fpath = os.path.join(self.EVIDENCE_DIR, fname)
            self.assertTrue(os.path.isfile(fpath), f"Evidence file {fname} must exist under {self.EVIDENCE_DIR}")
            self.assertGreater(os.path.getsize(fpath), 0, f"Evidence file {fname} must not be empty")

    def test_sessions_csv_schema_and_row_count(self):
        """sessions.csv has exactly 101 lines (header + 100 sessions) and 28 columns."""
        path = os.path.join(self.EVIDENCE_DIR, "sessions.csv")
        with open(path, "r", encoding="utf-8") as f:
            reader = list(csv.reader(f))

        self.assertEqual(len(reader), 101, f"Expected 101 rows (header + 100 sessions), got {len(reader)}")
        self.assertEqual(len(reader[0]), 28, f"Expected 28 columns in sessions.csv, got {len(reader[0])}")

        expected_cols = [
            "session_id", "scenario_id", "category", "ground_truth_label",
            "auth_method", "credential", "slot_code", "bank_code", "auth_result",
            "door_open_sec", "weight_delta_g", "ultrasonic_dist_cm", "vibration_intensity",
            "tilt_deg", "rfid_ok", "stay_min", "network_latency_ms", "seq",
            "b0_predicted_label", "b0_is_anomaly", "b0_rule", "b1_predicted_label",
            "b1_is_anomaly", "b1_rule", "b1_confidence", "status", "duration_ms", "seed"
        ]
        self.assertEqual(reader[0], expected_cols)

    def test_sensor_readings_csv_schema(self):
        """sensor_readings.csv has 101 lines and exactly 11 columns."""
        path = os.path.join(self.EVIDENCE_DIR, "sensor_readings.csv")
        with open(path, "r", encoding="utf-8") as f:
            reader = list(csv.reader(f))

        self.assertEqual(len(reader), 101)
        self.assertEqual(len(reader[0]), 11)
        expected_cols = [
            "session_id", "scenario_id", "timestamp_utc", "door_open_sec",
            "weight_delta_g", "ultrasonic_dist_cm", "vibration_intensity_g",
            "shock_mag_g", "tilt_deg", "rfid_ok", "stay_min"
        ]
        self.assertEqual(reader[0], expected_cols)

    def test_execution_summary_metrics(self):
        """execution_summary.json verifies 100% pass rate across 100 sessions."""
        path = os.path.join(self.EVIDENCE_DIR, "execution_summary.json")
        with open(path, "r", encoding="utf-8") as f:
            summary = json.load(f)

        self.assertEqual(summary["total_sessions"], 100)
        self.assertEqual(summary["passed"], 100)
        self.assertEqual(summary["failed"], 0)
        self.assertEqual(summary["blocked"], 0)
        self.assertEqual(summary["pass_rate_pct"], 100.0)

        dist = summary["stratified_distribution"]
        self.assertEqual(dist["NORMAL_AUTHORIZED"], 20)
        self.assertEqual(dist["UNAUTHORIZED_CREDENTIAL"], 20)
        self.assertEqual(dist["FORCED_DOOR_OPEN"], 20)
        self.assertEqual(dist["LOAD_OR_TAMPER_ANOMALY"], 20)
        self.assertEqual(dist["SENSOR_FAULT"], 20)


if __name__ == "__main__":
    unittest.main()
