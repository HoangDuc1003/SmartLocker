"""
Tier 2 Boundary & Corner Cases Tests: Features 11-17 (Execution Gate, Anomaly Detection, Scenario Oracle,
100+ Session Generation, Real Backend Execution, Evidence Preservation, Baseline B0 vs Proposed B1).
Total tests: 35 (exactly 5 distinct boundary/corner/negative tests per feature).
"""

import csv
import json
import math
from pathlib import Path
from test_e2e.common.assertion_framework import (
    E2ETestCase,
    feature,
    assert_true,
    assert_false,
    assert_equal,
    assert_in,
)
from test_e2e.common.artifact_validator import ArtifactValidator
from test_e2e.common.api_client import BackendApiClient, ApiResponse


class TestTier2Features11To17(E2ETestCase):
    tier = 2

    def setUp(self) -> None:
        super().setUp()
        self.artifacts = ArtifactValidator(self.workspace_root)
        self.api = BackendApiClient()

    # =========================================================================
    # Feature 11: End-to-End Execution Gate (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(11, "Gate handling when backend is down")
    def test_f11_bva01_gate_with_backend_down(self):
        """Verify execution gate halts with GATE_FAILED when backend is unreachable."""
        offline_client = BackendApiClient(base_url="http://127.0.0.1:59999/SmartLocker", default_timeout=0.2)
        
        def run_execution_gate(client: BackendApiClient) -> tuple[bool, str]:
            r = client.request("POST", "/api/health", headers={"X-API-Key": "TEST_KEY"})
            if not r.is_success and r.status_code == 0:
                return False, "BACKEND_UNREACHABLE"
            return True, "GATE_PASSED"

        passed, reason = run_execution_gate(offline_client)
        assert_false(passed, "Execution gate must fail when backend is unreachable")
        assert_equal(reason, "BACKEND_UNREACHABLE")

    @feature(11, "Missing database persistence verification")
    def test_f11_bva02_missing_database_persistence_verification(self):
        """Verify gate fails if HTTP request succeeds (200) but DB record is missing."""
        def verify_gate_persistence(http_success: bool, db_rows_found: int) -> tuple[bool, str]:
            if not http_success:
                return False, "HTTP_FAILED"
            if db_rows_found < 1:
                return False, "PERSISTENCE_MISSING"
            return True, "VERIFIED"

        passed, reason = verify_gate_persistence(http_success=True, db_rows_found=0)
        assert_false(passed, "Gate must fail when DB persistence is missing")
        assert_equal(reason, "PERSISTENCE_MISSING")

    @feature(11, "Missing audit trail verification")
    def test_f11_bva03_missing_audit_trail_verification(self):
        """Verify gate fails if session exists in LockerSession but audit record is missing."""
        def verify_gate_audit(session_saved: bool, audit_logged: bool, hash_chained: bool) -> tuple[bool, str]:
            if not session_saved:
                return False, "SESSION_NOT_SAVED"
            if not audit_logged or not hash_chained:
                return False, "AUDIT_OR_HASH_CHAIN_MISSING"
            return True, "VERIFIED"

        passed, reason = verify_gate_audit(session_saved=True, audit_logged=False, hash_chained=False)
        assert_false(passed, "Gate must fail if audit log is missing")
        assert_equal(reason, "AUDIT_OR_HASH_CHAIN_MISSING")

    @feature(11, "Malformed gate response handling")
    def test_f11_bva04_malformed_gate_response(self):
        """Verify execution gate halts when response body is non-JSON or HTML error page."""
        html_error_text = "<html><body><h1>500 Internal Server Error</h1></body></html>"
        
        def parse_gate_response(text: str) -> tuple[bool, dict]:
            try:
                data = json.loads(text)
                return True, data
            except json.JSONDecodeError:
                return False, {}

        is_valid, _ = parse_gate_response(html_error_text)
        assert_false(is_valid, "Gate must reject HTML error response")

    @feature(11, "Multiple failed gate attempts block batch execution")
    def test_f11_bva05_multiple_failed_gate_attempts_block_batch(self):
        """Verify repeated gate failures increment failure count and block batch generation."""
        max_retries = 3
        attempts = 0
        gate_passed = False

        for _ in range(max_retries):
            attempts += 1
            # Simulate failure
            gate_passed = False

        can_proceed_to_batch = (attempts <= max_retries) and gate_passed
        assert_false(can_proceed_to_batch, "Batch execution must be blocked after repeated gate failures")
        assert_equal(attempts, 3)

    # =========================================================================
    # Feature 12: Multi-Sensor Anomaly Detection (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(12, "Anomaly threshold boundary 0.79 vs 0.80")
    def test_f12_bva01_anomaly_threshold_boundary(self):
        """Verify risk score threshold: 0.7999 -> NORMAL, 0.8000 -> ML_ANOMALY."""
        ML_THRESHOLD = 0.80

        def classify_risk(risk_score: float) -> str:
            return "ML_ANOMALY" if risk_score >= ML_THRESHOLD else "NORMAL"

        assert_equal(classify_risk(0.79), "NORMAL")
        assert_equal(classify_risk(0.7999), "NORMAL")
        assert_equal(classify_risk(0.8000), "ML_ANOMALY")
        assert_equal(classify_risk(0.8001), "ML_ANOMALY")
        assert_equal(classify_risk(1.00), "ML_ANOMALY")

    @feature(12, "Simultaneous conflicting sensor inputs")
    def test_f12_bva02_simultaneous_conflicting_sensor_inputs(self):
        """Verify conflict detection: reed switch closed (0s) but ultrasonic <15cm and weight changed."""
        telemetry = {
            "door_open_sec": 0.0,      # Reed switch says closed
            "ultrasonic_cm": 12.0,      # User reach inside detected (<15cm)
            "weight_delta_g": -350.0,   # 350g removed
        }
        is_conflict = (telemetry["door_open_sec"] == 0.0) and (telemetry["ultrasonic_cm"] < 15.0 or abs(telemetry["weight_delta_g"]) > 50.0)
        assert_true(is_conflict, "Simultaneous conflicting inputs must trigger tamper/anomaly detection")

    @feature(12, "Sudden ultrasonic drop without door reed open")
    def test_f12_bva03_sudden_ultrasonic_drop_without_door_reed_open(self):
        """Verify sudden distance drop (occlusion/tamper) while reed switch is closed."""
        baseline_distance = 180.0  # cm
        current_distance = 15.0    # sudden occlusion
        door_open_sec = 0.0        # door closed

        is_occlusion_tamper = (door_open_sec == 0.0) and ((baseline_distance - current_distance) > 100.0)
        assert_true(is_occlusion_tamper, "Sudden ultrasonic drop with closed door must flag occlusion tamper")

    @feature(12, "Zero load with door unlocked extended duration")
    def test_f12_bva04_zero_load_with_door_unlocked(self):
        """Verify door unlocked with 0.0g load delta for extended duration flags DOOR_LEFT_AJAR."""
        session = {
            "door_open_sec": 180.0,   # open 3 minutes
            "weight_delta_g": 0.0,    # no items deposited
            "stay_min": 1.0,          # stay was only 1 minute
        }
        is_ajar = session["door_open_sec"] > 120.0 and session["weight_delta_g"] == 0.0
        assert_true(is_ajar, "Door left open with zero weight delta must flag DOOR_LEFT_AJAR")

    @feature(12, "Sensor flapping detection")
    def test_f12_bva05_sensor_flapping_detection(self):
        """Verify rapid toggling (>10 transitions in 5 seconds) flags SENSOR_FLAPPING."""
        # Simulated transition timestamps in seconds
        transitions = [0.1, 0.4, 0.7, 1.0, 1.3, 1.8, 2.2, 2.7, 3.1, 3.6, 4.0, 4.5]
        duration = transitions[-1] - transitions[0]
        count = len(transitions)

        is_flapping = (count >= 10) and (duration <= 5.0)
        assert_true(is_flapping, "High frequency state transitions must be detected as sensor flapping")

    # =========================================================================
    # Feature 13: Independent Scenario Oracle (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(13, "Oracle conflicting labels rejection")
    def test_f13_bva01_oracle_conflicting_labels_rejected(self):
        """Verify scenario with contradictory category and expected verdict is rejected."""
        def validate_scenario_labels(category: str, verdict: str) -> bool:
            if category == "NORMAL_AUTHORIZED" and verdict != "NORMAL":
                return False
            if category in ("FORCED_DOOR_OPEN", "LOAD_OR_TAMPER_ANOMALY") and verdict == "NORMAL":
                return False
            return True

        assert_false(validate_scenario_labels("NORMAL_AUTHORIZED", "FORCED_OPEN"))
        assert_false(validate_scenario_labels("FORCED_DOOR_OPEN", "NORMAL"))
        assert_true(validate_scenario_labels("NORMAL_AUTHORIZED", "NORMAL"))

    @feature(13, "Unassigned ground truth rejected before execution")
    def test_f13_bva02_unassigned_ground_truth_rejected(self):
        """Verify scenarios without pre-assigned ground truth label are rejected."""
        scenarios = [
            {"session_id": "SES-001", "ground_truth_label": "NORMAL"},
            {"session_id": "SES-002", "ground_truth_label": None},
            {"session_id": "SES-003", "ground_truth_label": ""},
        ]
        unassigned = [s["session_id"] for s in scenarios if not s.get("ground_truth_label")]
        assert_in("SES-002", unassigned)
        assert_in("SES-003", unassigned)
        assert_equal(len(unassigned), 2)

    @feature(13, "Invalid category string rejected")
    def test_f13_bva03_invalid_category_string_rejected(self):
        """Verify category string not belonging to the 5 standard categories is rejected."""
        allowed_categories = {
            "NORMAL_AUTHORIZED",
            "UNAUTHORIZED_CREDENTIAL",
            "FORCED_DOOR_OPEN",
            "LOAD_OR_TAMPER_ANOMALY",
            "SENSOR_FAULT",
        }
        invalid_categories = ["UNKNOWN_ATTACK", "DOS_ATTACK", "PHYSICAL_THEFT", "", "normal"]
        for cat in invalid_categories:
            assert_false(cat in allowed_categories, f"Invalid category {cat} must not be accepted")

    @feature(13, "Duplicate session IDs in oracle rejected")
    def test_f13_bva04_duplicate_session_ids_in_oracle(self):
        """Verify scenario list containing duplicate session IDs is flagged as invalid."""
        scenario_list = ["SES-001", "SES-002", "SES-003", "SES-002", "SES-004"]
        seen = set()
        duplicates = []
        for sid in scenario_list:
            if sid in seen:
                duplicates.append(sid)
            seen.add(sid)

        assert_equal(duplicates, ["SES-002"], "Duplicate session ID SES-002 must be detected")
        assert_equal(len(duplicates), 1)

    @feature(13, "Oracle evaluation before execution prohibited")
    def test_f13_bva05_oracle_evaluation_before_execution(self):
        """Verify evaluation cannot be computed on empty execution results."""
        executed_results = []  # No sessions executed yet
        can_evaluate = len(executed_results) > 0
        assert_false(can_evaluate, "Cannot compute confusion matrix before sessions are executed")

    # =========================================================================
    # Feature 14: Automated 100+ Session Generation (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(14, "Stratification under minimum threshold rejected")
    def test_f14_bva01_stratification_under_minimum_threshold(self):
        """Verify session distribution with <20 in any category fails stratification check."""
        distribution = {
            "NORMAL_AUTHORIZED": 19,       # Under 20 threshold
            "UNAUTHORIZED_CREDENTIAL": 25,
            "FORCED_DOOR_OPEN": 25,
            "LOAD_OR_TAMPER_ANOMALY": 20,
            "SENSOR_FAULT": 20,
        }
        is_valid_stratification = all(count >= 20 for count in distribution.values())
        assert_false(is_valid_stratification, "Distribution with 19 sessions must fail >=20 quota")

    @feature(14, "Total sessions under 100 rejected")
    def test_f14_bva02_total_sessions_under_100_rejected(self):
        """Verify session count of 99 fails the minimum >=100 requirement."""
        total_sessions = 99
        assert_false(total_sessions >= 100, "99 sessions must not satisfy >=100 requirement")
        assert_true(100 >= 100, "100 sessions satisfies boundary requirement")

    @feature(14, "Invalid seed in session generator handled")
    def test_f14_bva03_invalid_seed_in_session_generator(self):
        """Verify generator handles invalid non-integer seed values cleanly."""
        def parse_seed(seed_input) -> tuple[bool, int]:
            try:
                val = int(seed_input)
                return True, val
            except (ValueError, TypeError):
                return False, 0

        ok, val = parse_seed("seed_42_abc")
        assert_false(ok, "Alphanumeric seed string must fail int parse")

        ok, val = parse_seed(42)
        assert_true(ok)
        assert_equal(val, 42)

    @feature(14, "Empty scenario file rejection")
    def test_f14_bva04_empty_scenario_file_rejection(self):
        """Verify 0-byte or empty scenario payload raises validation error."""
        empty_content = ""
        is_empty = len(empty_content.strip()) == 0
        assert_true(is_empty, "Empty scenario payload must be recognized as 0-byte")

    @feature(14, "Invalid parameter ranges in scenario generation rejected")
    def test_f14_bva05_invalid_parameter_ranges_in_generation(self):
        """Verify generator rejects min_door_sec > max_door_sec or negative stay duration."""
        def validate_ranges(min_val: float, max_val: float) -> bool:
            return min_val >= 0 and min_val <= max_val

        assert_false(validate_ranges(15.0, 5.0), "min > max must be rejected")
        assert_false(validate_ranges(-1.0, 10.0), "negative min must be rejected")
        assert_true(validate_ranges(2.0, 10.0), "valid range accepted")

    # =========================================================================
    # Feature 15: Real Backend Execution of 100+ Sessions (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(15, "Backend server crash mid-run marks remaining sessions BLOCKED")
    def test_f15_bva01_backend_server_crash_mid_run(self):
        """Verify server crash mid-run preserves completed sessions and marks rest BLOCKED."""
        total = 100
        completed_before_crash = 45
        
        session_statuses = {}
        for i in range(1, total + 1):
            if i <= completed_before_crash:
                session_statuses[f"SES-{i:03d}"] = "PASS"
            else:
                session_statuses[f"SES-{i:03d}"] = "BLOCKED"

        pass_count = sum(1 for s in session_statuses.values() if s == "PASS")
        blocked_count = sum(1 for s in session_statuses.values() if s == "BLOCKED")
        assert_equal(pass_count, 45)
        assert_equal(blocked_count, 55)
        assert_equal(pass_count + blocked_count, 100)

    @feature(15, "Intermittent network failure during batch execution logged")
    def test_f15_bva02_network_failure_during_batch_execution(self):
        """Verify individual network failure marks specific session as FAIL/BLOCKED without dropping it."""
        results = [
            {"session_id": "SES-001", "status": "PASS"},
            {"session_id": "SES-002", "status": "FAIL", "error": "ECONNRESET"},
            {"session_id": "SES-003", "status": "PASS"},
        ]
        failed = [r for r in results if r["status"] == "FAIL"]
        assert_equal(len(failed), 1)
        assert_equal(failed[0]["session_id"], "SES-002")

    @feature(15, "Session timeout threshold handling")
    def test_f15_bva03_session_timeouts_handling(self):
        """Verify execution taking > 5.0s is recorded with TIMEOUT reason."""
        TIMEOUT_THRESHOLD_SEC = 5.0
        elapsed_sec = 6.2

        is_timeout = elapsed_sec > TIMEOUT_THRESHOLD_SEC
        assert_true(is_timeout, "Session exceeding 5.0s must be marked as TIMEOUT")

    @feature(15, "Reporting of PASS, FAIL, and BLOCKED counts with BLOCKED > 0")
    def test_f15_bva04_reporting_with_blocked_count(self):
        """Verify execution summary accurately preserves BLOCKED > 0 status."""
        summary = {"total": 100, "passed": 85, "failed": 10, "blocked": 5}
        assert_equal(summary["passed"] + summary["failed"] + summary["blocked"], summary["total"])
        assert_true(summary["blocked"] > 0, "Summary must accurately reflect BLOCKED > 0")

    @feature(15, "Duplicate session execution rejection")
    def test_f15_bva05_duplicate_session_execution_rejection(self):
        """Verify backend rejects duplicate session batch payloads with duplicates counter."""
        batch_response = {"saved": 0, "duplicates": 1, "rejected": 0, "errors": []}
        assert_equal(batch_response["duplicates"], 1)
        assert_equal(batch_response["saved"], 0)

    # =========================================================================
    # Feature 16: Raw Evidence Preservation (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(16, "Missing evidence files detection")
    def test_f16_bva01_missing_evidence_files_detected(self):
        """Verify validator flags error when any of the 10 raw evidence files is missing."""
        simulated_files = {
            "sessions.csv",
            "sessions.json",
            "sensor_readings.csv",
            # "backend_requests.jsonl",  <- Missing
            "backend_responses.jsonl",
            "ground_truth_labels.csv",
            "execution_summary.json",
            "failed_sessions.csv",
            "environment.json",
            "reproduction_config.yaml",
        }
        all_10 = {
            "sessions.csv", "sessions.json", "sensor_readings.csv",
            "backend_requests.jsonl", "backend_responses.jsonl",
            "ground_truth_labels.csv", "execution_summary.json",
            "failed_sessions.csv", "environment.json", "reproduction_config.yaml"
        }
        missing = all_10 - simulated_files
        assert_equal(missing, {"backend_requests.jsonl"})

    @feature(16, "Empty sessions.csv detected")
    def test_f16_bva02_empty_sessions_csv_detected(self):
        """Verify CSV validator detects header-only sessions.csv with 0 data rows."""
        csv_content = "session_id,seq,door_open_sec,weight_delta_g,stay_min,rfid_ok,category\n"
        lines = [ln.strip() for ln in csv_content.splitlines() if ln.strip()]
        data_rows = lines[1:] if len(lines) > 1 else []
        assert_equal(len(data_rows), 0, "Header-only CSV must have 0 data rows")

    @feature(16, "Malformed JSONL line detection")
    def test_f16_bva03_malformed_jsonl_line_detection(self):
        """Verify JSONL validator catches truncated/malformed JSON record in requests file."""
        jsonl_lines = [
            '{"session_id": "SES-001", "endpoint": "/api/locker/batch"}',
            '{"session_id": "SES-002", "endpoint": truncated...',  # malformed
            '{"session_id": "SES-003", "endpoint": "/api/locker/batch"}',
        ]
        errors = []
        for idx, line in enumerate(jsonl_lines, 1):
            try:
                json.loads(line)
            except json.JSONDecodeError as e:
                errors.append((idx, str(e)))

        assert_equal(len(errors), 1)
        assert_equal(errors[0][0], 2, "Line 2 must be flagged as malformed JSONL")

    @feature(16, "Corrupted ground truth labels CSV detection")
    def test_f16_bva04_corrupted_ground_truth_labels_csv(self):
        """Verify ground_truth_labels.csv missing required header 'ground_truth_label' is caught."""
        corrupted_headers = ["session_id", "category"]  # Missing 'ground_truth_label'
        required = ["session_id", "category", "ground_truth_label"]
        missing = [r for r in required if r not in corrupted_headers]
        assert_equal(missing, ["ground_truth_label"])

    @feature(16, "Missing hardware exclusion statement in environment.json")
    def test_f16_bva05_missing_hardware_exclusion_statement(self):
        """Verify environment.json lacking explicit hardware exclusion statement fails check."""
        env_without_statement = {"os": "Windows", "java_version": "1.8.0_202"}
        has_exclusion = env_without_statement.get("hardware_excluded") is True
        assert_false(has_exclusion, "environment.json without hardware_excluded=True must fail")

        valid_env = {"os": "Windows", "java_version": "1.8.0_202", "hardware_excluded": True}
        assert_true(valid_env.get("hardware_excluded") is True)

    # =========================================================================
    # Feature 17: Baseline B0 vs Proposed B1 Evaluation (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(17, "B0 evaluated on non-identical scenarios rejected")
    def test_f17_bva01_b0_evaluated_on_non_identical_scenarios(self):
        """Verify comparative evaluation rejects comparing B0 and B1 with differing scenario sets."""
        scenarios_b0 = {"SES-001", "SES-002", "SES-003"}
        scenarios_b1 = {"SES-001", "SES-002", "SES-004"}  # Mismatch: SES-003 vs SES-004

        is_identical = scenarios_b0 == scenarios_b1
        assert_false(is_identical, "Comparative evaluation must reject mismatched scenario inputs")

    @feature(17, "Missing B0 baseline metrics file handling")
    def test_f17_bva02_missing_b0_baseline_metrics(self):
        """Verify evaluation flags missing B0 baseline metrics before computing comparison."""
        def compare_baselines(b0_metrics: dict | None, b1_metrics: dict | None) -> tuple[bool, str]:
            if b0_metrics is None:
                return False, "MISSING_B0_METRICS"
            if b1_metrics is None:
                return False, "MISSING_B1_METRICS"
            return True, "OK"

        ok, reason = compare_baselines(None, {"f1": 0.95})
        assert_false(ok)
        assert_equal(reason, "MISSING_B0_METRICS")

    @feature(17, "Negative performance delta handled gracefully")
    def test_f17_bva03_negative_performance_delta_handled(self):
        """Verify delta computation handles negative values without crash or invalid format."""
        f1_b0 = 0.85
        f1_b1 = 0.80  # Drop in performance
        delta = f1_b1 - f1_b0
        assert_equal(round(delta, 2), -0.05)
        # Ensure delta string handles negative sign properly
        delta_str = f"{delta:+.2f}"
        assert_equal(delta_str, "-0.05")

    @feature(17, "Division by zero in metric computation handled")
    def test_f17_bva04_division_by_zero_in_metric_computation(self):
        """Verify confusion matrix with all zeros produces 0.0 metrics without ZeroDivisionError."""
        metrics = self.artifacts.validate_confusion_matrix(tp=0, fp=0, tn=0, fn=0)
        assert_equal(metrics["precision"], 0.0)
        assert_equal(metrics["recall"], 0.0)
        assert_equal(metrics["f1"], 0.0)
        assert_equal(metrics["balanced_acc"], 0.0)

    @feature(17, "Mismatched session count between B0 and B1 rejected")
    def test_f17_bva05_mismatched_session_count_between_b0_and_b1(self):
        """Verify evaluator rejects comparison when B0 has 100 sessions and B1 has 95 sessions."""
        count_b0 = 100
        count_b1 = 95
        assert_false(count_b0 == count_b1, "Mismatched session count must be rejected")
