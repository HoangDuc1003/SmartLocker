"""
tests/test_leak_free_b1.py
Comprehensive Verification Suite for Milestone 3:
- Zero Oracle Ground-Truth Leakage Verification.
- AST Static Code Analysis of ProposedDetectorB1 and ScenarioOracle.
- Observable Telemetry Evaluation (Physical bounds, transport latency, sequence tracking).
- Authentication Denial Masking Fix Verification (DENY and ERROR handling).
- Statistical Evaluator Label Mapping Fix Verification.
"""

import ast
import copy
import inspect
import math
import os
import unittest
from typing import Any, Dict, List

from experiments.detection import (
    BaselineDetectorB0,
    ProposedDetectorB1,
    DetectionVerdict,
)
from experiments.oracle import (
    CanonicalClass,
    ScenarioCategory,
    ScenarioOracle,
    ScenarioSpec,
)
from experiments.evaluate import StatisticalEvaluator


class TestASTLeakageVerification(unittest.TestCase):
    """
    Static AST Code Analysis to formally prove zero ground-truth leakage
    in experiments/detection.py and experiments/oracle.py.
    """

    def setUp(self):
        self.detection_path = os.path.join("experiments", "detection.py")
        self.oracle_path = os.path.join("experiments", "oracle.py")
        with open(self.detection_path, "r", encoding="utf-8") as f:
            self.detection_tree = ast.parse(f.read(), filename=self.detection_path)
        with open(self.oracle_path, "r", encoding="utf-8") as f:
            self.oracle_tree = ast.parse(f.read(), filename=self.oracle_path)

    def test_proposed_detector_b1_evaluate_signature_leak_free(self):
        """
        Verify ProposedDetectorB1.evaluate() parameter signature has ZERO test harness
        or simulation ground-truth leakage parameters.
        """
        b1_class_node = None
        for node in ast.walk(self.detection_tree):
            if isinstance(node, ast.ClassDef) and node.name == "ProposedDetectorB1":
                b1_class_node = node
                break
        self.assertIsNotNone(b1_class_node, "ProposedDetectorB1 class not found in detection.py")

        eval_func_node = None
        for item in b1_class_node.body:
            if isinstance(item, ast.FunctionDef) and item.name == "evaluate":
                eval_func_node = item
                break
        self.assertIsNotNone(eval_func_node, "ProposedDetectorB1.evaluate() not found")

        arg_names = [arg.arg for arg in eval_func_node.args.args]
        forbidden_params = {
            "fault_type",
            "seq_gap",
            "seq_duplicate",
            "payload_corrupted",
            "spec",
            "ground_truth",
            "ground_truth_label",
            "label_expected",
            "category",
        }
        for forbidden in forbidden_params:
            self.assertNotIn(
                forbidden,
                arg_names,
                f"Ground-truth leakage parameter '{forbidden}' detected in ProposedDetectorB1.evaluate() signature: {arg_names}"
            )

    def test_proposed_detector_b1_body_ast_has_no_oracle_leakage(self):
        """
        Verify ProposedDetectorB1 body contains no AST attribute lookups or references
        to ground-truth simulation fields or Oracle ground-truth functions.
        """
        b1_class_node = None
        for node in ast.walk(self.detection_tree):
            if isinstance(node, ast.ClassDef) and node.name == "ProposedDetectorB1":
                b1_class_node = node
                break

        forbidden_attributes = {
            "ground_truth_label",
            "expected_b0_label",
            "expected_b1_label",
            "evaluate_ground_truth",
            "fault_type",
            "seq_gap",
            "seq_duplicate",
            "payload_corrupted",
        }

        found_violations = []
        for node in ast.walk(b1_class_node):
            if isinstance(node, ast.Attribute) and node.attr in forbidden_attributes:
                found_violations.append(f"Attribute access: {node.attr} at line {node.lineno}")
            elif isinstance(node, ast.Name) and node.id in forbidden_attributes:
                found_violations.append(f"Name reference: {node.id} at line {node.lineno}")

        self.assertEqual(
            found_violations,
            [],
            f"Ground-truth leakage violations discovered in ProposedDetectorB1 AST: {found_violations}"
        )

    def test_oracle_predict_b1_does_not_call_evaluate_ground_truth(self):
        """
        Verify ScenarioOracle.predict_b1() in experiments/oracle.py does NOT invoke
        evaluate_ground_truth or delegate directly to ground-truth assignment.
        """
        oracle_class_node = None
        for node in ast.walk(self.oracle_tree):
            if isinstance(node, ast.ClassDef) and node.name == "ScenarioOracle":
                oracle_class_node = node
                break
        self.assertIsNotNone(oracle_class_node, "ScenarioOracle class not found in oracle.py")

        predict_b1_node = None
        for item in oracle_class_node.body:
            if isinstance(item, ast.FunctionDef) and item.name == "predict_b1":
                predict_b1_node = item
                break
        self.assertIsNotNone(predict_b1_node, "ScenarioOracle.predict_b1() not found")

        # Verify no calls to evaluate_ground_truth
        calls_found = []
        for node in ast.walk(predict_b1_node):
            if isinstance(node, ast.Call):
                func = node.func
                if isinstance(func, ast.Name) and func.id == "evaluate_ground_truth":
                    calls_found.append(func.id)
                elif isinstance(func, ast.Attribute) and func.attr == "evaluate_ground_truth":
                    calls_found.append(func.attr)

        self.assertEqual(
            calls_found,
            [],
            f"ScenarioOracle.predict_b1() directly called evaluate_ground_truth: {calls_found}"
        )


class TestOracleB1EpistemicIndependence(unittest.TestCase):
    """
    Verifies that ScenarioOracle.predict_b1() executes independently of ground-truth
    spec fields and evaluates strictly observable features.
    """

    def setUp(self):
        self.base_spec = ScenarioSpec(
            session_id="SIM-TEST-LEAKFREE-001",
            scenario_id="SCEN-TEST-01",
            seed=12345,
            category=ScenarioCategory.NORMAL_AUTHORIZED.value,
            ground_truth_label="NORMAL_USAGE",
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
            description="Clean baseline spec",
        )

    def test_predict_b1_invariant_to_corrupted_ground_truth_label(self):
        """
        Mutating spec.ground_truth_label must NOT alter predict_b1 output.
        """
        spec = copy.deepcopy(self.base_spec)
        normal_pred = ScenarioOracle.predict_b1(spec)
        self.assertEqual(normal_pred, CanonicalClass.NORMAL_USAGE.value)

        # Mutate ground_truth_label to an invalid / adversarial class
        spec.ground_truth_label = "ADVERSARIAL_MUTATED_CLASS"
        pred_after_mutation = ScenarioOracle.predict_b1(spec)
        self.assertEqual(
            pred_after_mutation,
            CanonicalClass.NORMAL_USAGE.value,
            "predict_b1 output changed when spec.ground_truth_label was mutated!"
        )

    def test_predict_b1_invariant_to_corrupted_category(self):
        """
        Mutating spec.category must NOT alter predict_b1 output.
        """
        spec = copy.deepcopy(self.base_spec)
        spec.category = "COMPLETELY_FABRICATED_CATEGORY"
        pred = ScenarioOracle.predict_b1(spec)
        self.assertEqual(pred, CanonicalClass.NORMAL_USAGE.value)

    def test_predict_b1_evaluates_observable_transducer_signals(self):
        """
        predict_b1 correctly predicts SENSOR_MALFUNCTION based strictly on observable values.
        """
        spec = copy.deepcopy(self.base_spec)
        spec.weight_delta_g = -500.0  # Physical violation < -200g
        self.assertEqual(ScenarioOracle.predict_b1(spec), CanonicalClass.SENSOR_MALFUNCTION.value)

        spec2 = copy.deepcopy(self.base_spec)
        spec2.network_latency_ms = 6200.0  # Socket timeout >= 5000ms
        self.assertEqual(ScenarioOracle.predict_b1(spec2), CanonicalClass.NETWORK_MALFUNCTION.value)


class TestAuthFailureHandling(unittest.TestCase):
    """
    Verifies that authentication denial is never masked:
    - auth_result == 'DENY' triggers UNAUTHORIZED_ACCESS even when door_open_sec > 0.
    - auth_result == 'ERROR' triggers UNAUTHORIZED_ACCESS.
    - card_blocked triggers UNAUTHORIZED_ACCESS.
    """

    def setUp(self):
        self.b1 = ProposedDetectorB1()
        self.b0 = BaselineDetectorB0()

    def test_auth_deny_with_zero_door_duration(self):
        """DENY with closed door -> UNAUTHORIZED_ACCESS."""
        verdict = self.b1.evaluate(
            auth_result="DENY",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=False,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
        )
        self.assertEqual(verdict.label, "UNAUTHORIZED_ACCESS")
        self.assertTrue(verdict.is_anomaly)

    def test_auth_deny_not_masked_by_nonzero_door_duration(self):
        """
        CRITICAL BUG FIX VERIFICATION:
        In original implementation, 'door_open_sec == 0.0' masked DENY whenever door_open_sec > 0.
        The refactored detector must trigger UNAUTHORIZED_ACCESS (or FORCED_DOOR_OPEN if rfid_ok is False).
        """
        verdict = self.b1.evaluate(
            auth_result="DENY",
            door_open_sec=7.5,
            weight_delta_g=150.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
        )
        self.assertEqual(verdict.label, "UNAUTHORIZED_ACCESS")
        self.assertTrue(verdict.is_anomaly)
        self.assertEqual(verdict.trigger_rule, "B1_AUTH_DENIED")

    def test_auth_error_http_500_handled(self):
        """
        CRITICAL BUG FIX VERIFICATION:
        Fingerprint exception sessions returning 'ERROR' must trigger UNAUTHORIZED_ACCESS,
        not fall through to NORMAL_USAGE.
        """
        verdict_b1 = self.b1.evaluate(
            auth_result="ERROR",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=False,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
        )
        self.assertEqual(verdict_b1.label, "UNAUTHORIZED_ACCESS")
        self.assertTrue(verdict_b1.is_anomaly)

        verdict_b0 = self.b0.evaluate(
            auth_result="ERROR",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=False,
            stay_min=10.0,
        )
        self.assertEqual(verdict_b0.label, "UNAUTHORIZED_ACCESS")
        self.assertTrue(verdict_b0.is_anomaly)

    def test_card_blocked_triggers_unauthorized(self):
        """Blocked card -> UNAUTHORIZED_ACCESS."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
            card_blocked=True,
        )
        self.assertEqual(verdict.label, "UNAUTHORIZED_ACCESS")
        self.assertEqual(verdict.trigger_rule, "B1_LOST_CARD_USED")


class TestObservablePhysicalDetection(unittest.TestCase):
    """
    Verifies B1 multi-sensor physical detection across all operational categories.
    """

    def setUp(self):
        self.b1 = ProposedDetectorB1()

    def test_normal_authorized_operation(self):
        """Normal unlock session within all physical limits -> NORMAL_USAGE."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.2,
            weight_delta_g=120.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=28.5,
            vibration_intensity=0.02,
            tilt_deg=0.2,
            shock_mag_g=1.0,
        )
        self.assertEqual(verdict.label, "NORMAL_USAGE")
        self.assertFalse(verdict.is_anomaly)

    def test_forced_door_open_unauthorized_pry(self):
        """Door opened without valid RFID unlock -> FORCED_DOOR_OPEN."""
        verdict = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=6.0,
            weight_delta_g=0.0,
            rfid_ok=False,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.15,
            tilt_deg=0.5,
        )
        self.assertEqual(verdict.label, "FORCED_DOOR_OPEN")
        self.assertTrue(verdict.is_anomaly)
        self.assertEqual(verdict.trigger_rule, "B1_FORCED_DOOR_UNAUTHORIZED")

    def test_forced_door_open_mechanical_breach_impact(self):
        """Mechanical shock breach with door opening -> FORCED_DOOR_OPEN."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=4.0,
            weight_delta_g=100.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.85,  # >= 0.60G
            tilt_deg=0.5,
        )
        self.assertEqual(verdict.label, "FORCED_DOOR_OPEN")
        self.assertEqual(verdict.trigger_rule, "B1_FORCED_DOOR_IMPACT")

    def test_physical_tamper_sledgehammer_shock(self):
        """Heavy impact strike (>=16G) while door locked -> PHYSICAL_TAMPER."""
        verdict = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.20,
            tilt_deg=0.5,
            shock_mag_g=19.5,  # >= 16G
        )
        self.assertEqual(verdict.label, "PHYSICAL_TAMPER")
        self.assertEqual(verdict.trigger_rule, "B1_TAMPER_SHOCK_IMPACT")

    def test_physical_tamper_drilling_vibration(self):
        """Continuous drilling vibration (>=0.45G) while locked -> PHYSICAL_TAMPER."""
        verdict = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.65,  # >= 0.45G
            tilt_deg=0.2,
            shock_mag_g=1.0,
        )
        self.assertEqual(verdict.label, "PHYSICAL_TAMPER")
        self.assertEqual(verdict.trigger_rule, "B1_TAMPER_VIBRATION")

    def test_physical_tamper_structural_tilt(self):
        """Structural enclosure tilt (>=4.0 deg) while locked -> PHYSICAL_TAMPER."""
        verdict = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.05,
            tilt_deg=6.5,  # >= 4.0 deg
            shock_mag_g=1.0,
        )
        self.assertEqual(verdict.label, "PHYSICAL_TAMPER")
        self.assertEqual(verdict.trigger_rule, "B1_TAMPER_TILT")

    def test_physical_tamper_closed_door_weight_alteration(self):
        """In-slot load alteration (>50g) while door closed -> PHYSICAL_TAMPER."""
        verdict = self.b1.evaluate(
            auth_result="NONE",
            door_open_sec=0.0,
            weight_delta_g=85.0,  # > 50g
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.03,
            tilt_deg=0.1,
            shock_mag_g=1.0,
        )
        self.assertEqual(verdict.label, "PHYSICAL_TAMPER")
        self.assertEqual(verdict.trigger_rule, "B1_TAMPER_WEIGHT_LOCKED")

    def test_sensor_fault_non_finite_float(self):
        """NaN or Inf floating-point values -> SENSOR_MALFUNCTION."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=float("nan"),
            weight_delta_g=100.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
        )
        self.assertEqual(verdict.label, "SENSOR_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_NON_FINITE_FLOAT")

    def test_sensor_fault_load_cell_adc_rail_saturation(self):
        """Weight reading outside [-200g, 20000g] -> SENSOR_MALFUNCTION."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=25000.0,  # > 20000g
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
        )
        self.assertEqual(verdict.label, "SENSOR_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_WEIGHT_RANGE_FAULT")

    def test_sensor_fault_temporal_inconsistency(self):
        """Door duration exceeding stay_min * 60 + 5 -> SENSOR_MALFUNCTION."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=240.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=2.0,  # 2.0 * 60 + 5 = 125s
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
        )
        self.assertEqual(verdict.label, "SENSOR_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_DOOR_GT_STAY_FAULT")

    def test_sensor_fault_ultrasonic_acoustic_blindness(self):
        """Acoustic cutoff (< 2.0 cm or > 400.0 cm) -> SENSOR_MALFUNCTION."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=0.5,  # < 2.0 cm
            vibration_intensity=0.02,
            tilt_deg=0.1,
        )
        self.assertEqual(verdict.label, "SENSOR_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_SONAR_STUCK_FAULT")

    def test_sensor_fault_imu_bus_dropout(self):
        """Invalid negative IMU readings (I2C bus disconnect) -> SENSOR_MALFUNCTION."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=-1.0,  # Negative invalid
            tilt_deg=-1.0,
            shock_mag_g=0.01,
        )
        self.assertEqual(verdict.label, "SENSOR_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_IMU_DROPOUT_FAULT")


class TestObservableNetworkDetection(unittest.TestCase):
    """
    Verifies B1 network and transport anomaly detection through strictly observable signals.
    """

    def setUp(self):
        self.b1 = ProposedDetectorB1()

    def test_network_timeout_latency(self):
        """Socket delay >= 5000ms -> NETWORK_MALFUNCTION."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
            network_latency_ms=6500.0,  # >= 5000ms
        )
        self.assertEqual(verdict.label, "NETWORK_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_NET_TIMEOUT")

    def test_stream_duplicate_sequence_detection(self):
        """Non-monotonic duplicate packet sequence detected via observable tracking."""
        self.b1.reset_sequence(initial_seq=100)
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
            packet_seq=100,  # Duplicate <= last_seq (100)
        )
        self.assertEqual(verdict.label, "NETWORK_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_NET_DUPLICATE_REPLAY")

    def test_stream_sequence_gap_detection(self):
        """Packet loss / sequence gap detected via observable sequence tracking."""
        self.b1.reset_sequence(initial_seq=100)
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
            packet_seq=105,  # Gap > last_seq + 1 (101)
        )
        self.assertEqual(verdict.label, "NETWORK_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_NET_PACKET_LOSS_GAP")

    def test_batch_telemetry_records_duplicate_seq(self):
        """Observable batch records containing duplicate sequences detected."""
        detector = ProposedDetectorB1()
        records = [
            {"seq": 50, "measured_at": "2026-11-15 18:00:00"},
            {"seq": 50, "measured_at": "2026-11-15 18:00:01"},
        ]
        verdict = detector.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
            telemetry_records=records,
        )
        self.assertEqual(verdict.label, "NETWORK_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_NET_DUPLICATE_REPLAY")

    def test_payload_syntax_corruption_detection(self):
        """Malformed raw JSON payload detected as network malfunction."""
        verdict = self.b1.evaluate(
            auth_result="UNLOCK",
            door_open_sec=5.0,
            weight_delta_g=0.0,
            rfid_ok=True,
            stay_min=10.0,
            ultrasonic_dist_cm=30.0,
            vibration_intensity=0.02,
            tilt_deg=0.1,
            raw_payload="INVALID_JSON{{bad_body",
        )
        self.assertEqual(verdict.label, "NETWORK_MALFUNCTION")
        self.assertEqual(verdict.trigger_rule, "B1_NET_PAYLOAD_CORRUPT")


class TestEvaluateLabelMap(unittest.TestCase):
    """
    Verifies that StatisticalEvaluator maps both SENSOR_MALFUNCTION and NETWORK_MALFUNCTION
    to SENSOR_FAULT without dropping to MISSED.
    """

    def test_label_map_coverage(self):
        """Test label_map inside StatisticalEvaluator.evaluate_detection."""
        evaluator = StatisticalEvaluator()
        result = evaluator.evaluate_detection()

        cm_b1 = result["confusion_matrix_b1"]
        # Ensure that actual SENSOR_FAULT has 0 predictions mapped to MISSED
        missed_count = cm_b1["SENSOR_FAULT"].get("MISSED", 0)
        self.assertEqual(
            missed_count,
            0,
            f"Expected 0 SENSOR_FAULT predictions mapped to MISSED, but found {missed_count}"
        )
        # Ensure SENSOR_FAULT recall is 1.0 (all 20 caught)
        sensor_fault_recall = result["metrics_b1"]["per_class"]["SENSOR_FAULT"]["recall"]
        self.assertEqual(sensor_fault_recall, 1.0)
        # Macro F1 should be > 0.90 (0.9698)
        macro_f1 = result["metrics_b1"]["macro_f1"]
        self.assertGreater(macro_f1, 0.90)


if __name__ == "__main__":
    unittest.main()
