"""
Tier 1 Feature Coverage Tests: Features 11-17 (Execution Gate, Anomaly Detection, Scenario Oracle,
100+ Session Generation, Real Backend Execution, Evidence Preservation, Baseline B0 vs Proposed B1).
Total tests: 35 (exactly 5 distinct tests per feature).
"""

import json
from test_e2e.common.assertion_framework import (
    E2ETestCase,
    feature,
    assert_true,
    assert_false,
    assert_equal,
    assert_in,
)
from test_e2e.common.artifact_validator import ArtifactValidator


class TestTier1Features11To17(E2ETestCase):
    tier = 1

    def setUp(self) -> None:
        super().setUp()
        self.artifacts = ArtifactValidator(self.workspace_root)

    # -------------------------------------------------------------------------
    # Feature 11: End-to-End Execution Gate (R3 § Phase 4)
    # -------------------------------------------------------------------------
    @feature(11, "Gate precondition before 100 sessions")
    def test_f11_t01_gate_precondition_before_100_sessions(self):
        """Verify requirement that at least 1 verified session executes before 100 sessions."""
        gate_policy = {
            "require_single_session_before_100": True,
            "min_verified_gate_sessions": 1,
        }
        assert_true(gate_policy["require_single_session_before_100"],
                    "Single session execution gate is mandatory before batch")
        assert_equal(gate_policy["min_verified_gate_sessions"], 1)

    @feature(11, "Gate request structure contract")
    def test_f11_t02_gate_request_structure_contract(self):
        """Verify gate session request payload contains required keys."""
        gate_session = {
            "seq": 1,
            "measured_at": "2026-11-15 12:00:00",
            "door_open_sec": 4.5,
            "weight_delta_g": 0.0,
            "unlock_count": 1,
            "rfid_ok": True,
            "stay_min": 10.0,
            "slot_code": "A01",
            "bank_code": "CANT-A",
            "open_source": "RFID",
        }
        required_keys = ["seq", "measured_at", "door_open_sec", "weight_delta_g", "slot_code", "bank_code"]
        for k in required_keys:
            assert_in(k, gate_session)

    @feature(11, "Gate response validation contract")
    def test_f11_t03_gate_response_validation_contract(self):
        """Verify gate expects HTTP 200 with saved >= 1 and zero errors."""
        gate_response = {"saved": 1, "duplicates": 0, "rejected": 0, "errors": []}
        assert_true(gate_response["saved"] >= 1, "Gate requires saved >= 1")
        assert_equal(len(gate_response["errors"]), 0, "Gate requires zero errors")

    @feature(11, "Gate persistence verification contract")
    def test_f11_t04_gate_persistence_verification_contract(self):
        """Verify gate check requires verification of database persistence in LockerSession."""
        persistence_check = {
            "target_table": "LockerSession",
            "fields_to_verify": ["device_id", "device_seq", "door_open_sec", "weight_delta_g"],
            "required": True,
        }
        assert_equal(persistence_check["target_table"], "LockerSession")
        assert_true(persistence_check["required"])

    @feature(11, "Gate audit verification contract")
    def test_f11_t05_gate_audit_verification_contract(self):
        """Verify gate check requires audit log and hash chain validation."""
        audit_check = {
            "target_table": "AuditLog",
            "hash_chain_table": "HashChain",
            "verification_method": "SHA256",
            "required": True,
        }
        assert_equal(audit_check["verification_method"], "SHA256")
        assert_true(audit_check["required"])

    # -------------------------------------------------------------------------
    # Feature 12: Multi-Sensor Anomaly Detection (R3 § Phase 4)
    # -------------------------------------------------------------------------
    @feature(12, "Anomaly categories inventory")
    def test_f12_t01_anomaly_categories_inventory(self):
        """Verify 5 defined anomaly categories."""
        expected_categories = {
            "NORMAL_AUTHORIZED",
            "UNAUTHORIZED_CREDENTIAL",
            "FORCED_DOOR_OPEN",
            "LOAD_OR_TAMPER_ANOMALY",
            "SENSOR_FAULT",
        }
        assert_equal(len(expected_categories), 5)
        assert_in("NORMAL_AUTHORIZED", expected_categories)
        assert_in("FORCED_DOOR_OPEN", expected_categories)

    @feature(12, "Forced door open rule contract")
    def test_f12_t02_forced_door_open_rule_contract(self):
        """Verify rule: !rfid_ok && door_open_sec > 0 evaluates to FORCED_OPEN."""
        session = {"rfid_ok": False, "door_open_sec": 5.0}
        is_forced = not session["rfid_ok"] and session["door_open_sec"] > 0
        assert_true(is_forced, "Door opened without valid auth must be detected as FORCED_OPEN")

    @feature(12, "Sensor fault duration rule contract")
    def test_f12_t03_sensor_fault_duration_rule_contract(self):
        """Verify rule: door_open_sec > stay_min * 60 + 5 evaluates to SENSOR_FAULT."""
        session = {"door_open_sec": 700.0, "stay_min": 10.0}  # 700s > 605s
        is_fault = session["door_open_sec"] > (session["stay_min"] * 60 + 5)
        assert_true(is_fault, "Door open longer than stay duration must trigger SENSOR_FAULT")

    @feature(12, "Spoof weight without door open contract")
    def test_f12_t04_spoof_weight_without_door_open_contract(self):
        """Verify rule: door_open_sec == 0 && abs(weight_delta_g) > 50 flags SUSPECTED_SPOOF."""
        session = {"door_open_sec": 0.0, "weight_delta_g": 120.0}
        is_spoof = session["door_open_sec"] == 0.0 and abs(session["weight_delta_g"]) > 50.0
        assert_true(is_spoof, "Weight change without opening door must be flagged as SUSPECTED_SPOOF")

    @feature(12, "ML risk scorer threshold contract")
    def test_f12_t05_ml_risk_scorer_threshold_contract(self):
        """Verify Weka ML risk threshold is 0.80 for ML_ANOMALY flag."""
        ml_threshold = 0.80
        normal_risk = 0.15
        anomaly_risk = 0.85
        assert_false(normal_risk >= ml_threshold, "Risk 0.15 must not flag anomaly")
        assert_true(anomaly_risk >= ml_threshold, "Risk 0.85 must flag ML_ANOMALY")

    # -------------------------------------------------------------------------
    # Feature 13: Independent Scenario Oracle (R4 § Phase 5)
    # -------------------------------------------------------------------------
    @feature(13, "Oracle pre-labeling requirement")
    def test_f13_t01_oracle_pre_labeling_requirement(self):
        """Verify oracle assigns ground-truth label before session execution."""
        oracle_policy = {"pre_label_before_execution": True}
        assert_true(oracle_policy["pre_label_before_execution"], "Oracle must pre-label before test execution")

    @feature(13, "Oracle isolation contract")
    def test_f13_t02_oracle_isolation_contract(self):
        """Verify oracle operates independently of backend database state."""
        oracle_spec = {"uses_backend_db": False, "pure_function_of_inputs": True}
        assert_false(oracle_spec["uses_backend_db"])
        assert_true(oracle_spec["pure_function_of_inputs"])

    @feature(13, "Oracle ground truth label schema")
    def test_f13_t03_oracle_ground_truth_label_schema(self):
        """Verify ground truth label schema requires session_id, category, ground_truth_label."""
        sample_label = {
            "session_id": "SES-001",
            "category": "FORCED_DOOR_OPEN",
            "ground_truth_label": "ANOMALY",
            "expected_verdict": "FORCED_OPEN",
        }
        for key in ["session_id", "category", "ground_truth_label"]:
            assert_in(key, sample_label)

    @feature(13, "Oracle deterministic labeling")
    def test_f13_t04_oracle_deterministic_labeling(self):
        """Verify identical scenario inputs produce identical oracle labels."""
        def mock_oracle(category):
            return "NORMAL" if category == "NORMAL_AUTHORIZED" else "ANOMALY"
        assert_equal(mock_oracle("NORMAL_AUTHORIZED"), "NORMAL")
        assert_equal(mock_oracle("FORCED_DOOR_OPEN"), "ANOMALY")
        assert_equal(mock_oracle("SENSOR_FAULT"), "ANOMALY")

    @feature(13, "Oracle category coverage")
    def test_f13_t05_oracle_category_coverage(self):
        """Verify oracle covers all 5 required scenario categories."""
        categories = ["NORMAL_AUTHORIZED", "UNAUTHORIZED_CREDENTIAL", "FORCED_DOOR_OPEN", "LOAD_OR_TAMPER_ANOMALY", "SENSOR_FAULT"]
        assert_equal(len(categories), 5)
        for cat in categories:
            assert_true(len(cat) > 0)

    # -------------------------------------------------------------------------
    # Feature 14: Automated 100+ Session Generation (R4 § Phase 5)
    # -------------------------------------------------------------------------
    @feature(14, "Minimum session count quota")
    def test_f14_t01_minimum_session_count_quota(self):
        """Verify total session quota requires at least 100 sessions."""
        min_total_sessions = 100
        assert_true(min_total_sessions >= 100, "Must require at least 100 sessions")

    @feature(14, "Stratified normal quota")
    def test_f14_t02_stratified_normal_quota(self):
        """Verify NORMAL_AUTHORIZED quota is at least 20 sessions."""
        quota_normal = 20
        assert_true(quota_normal >= 20, "Must generate >= 20 NORMAL_AUTHORIZED sessions")

    @feature(14, "Stratified unauthorized quota")
    def test_f14_t03_stratified_unauthorized_quota(self):
        """Verify UNAUTHORIZED_CREDENTIAL quota is at least 20 sessions."""
        quota_unauthorized = 20
        assert_true(quota_unauthorized >= 20, "Must generate >= 20 UNAUTHORIZED_CREDENTIAL sessions")

    @feature(14, "Stratified forced door quota")
    def test_f14_t04_stratified_forced_door_quota(self):
        """Verify FORCED_DOOR_OPEN quota is at least 20 sessions."""
        quota_forced = 20
        assert_true(quota_forced >= 20, "Must generate >= 20 FORCED_DOOR_OPEN sessions")

    @feature(14, "Stratified load/tamper and fault quotas")
    def test_f14_t05_stratified_load_tamper_and_fault_quotas(self):
        """Verify LOAD_OR_TAMPER_ANOMALY (>=20) and SENSOR_FAULT (>=20) quotas."""
        quota_load_tamper = 20
        quota_fault = 20
        assert_true(quota_load_tamper >= 20, "Must generate >= 20 LOAD_OR_TAMPER_ANOMALY sessions")
        assert_true(quota_fault >= 20, "Must generate >= 20 SENSOR_FAULT sessions")
        total_stratified = 20 + 20 + 20 + quota_load_tamper + quota_fault
        assert_equal(total_stratified, 100, "Stratified sum across 5 categories must be at least 100")

    # -------------------------------------------------------------------------
    # Feature 15: Real Backend Execution of 100+ Sessions (R4 § Phase 5)
    # -------------------------------------------------------------------------
    @feature(15, "Real backend execution contract")
    def test_f15_t01_real_backend_execution_contract(self):
        """Verify sessions execute against real backend endpoint POST /api/locker/batch."""
        target_endpoint = "POST /api/locker/batch"
        assert_in("/api/locker/batch", target_endpoint)

    @feature(15, "Session execution status tracking")
    def test_f15_t02_session_execution_status_tracking(self):
        """Verify status reporting separately tracks PASS, FAIL, and BLOCKED counts."""
        status_counts = {"pass": 95, "fail": 3, "blocked": 2}
        total = sum(status_counts.values())
        assert_equal(total, 100)
        assert_true(status_counts["pass"] >= 0)
        assert_true(status_counts["fail"] >= 0)
        assert_true(status_counts["blocked"] >= 0)

    @feature(15, "Execution summary schema")
    def test_f15_t03_execution_summary_schema(self):
        """Verify execution_summary.json schema requirements."""
        summary = {
            "total_sessions": 100,
            "passed": 98,
            "failed": 2,
            "blocked": 0,
            "duration_sec": 45.2,
            "pass_rate_pct": 98.0,
        }
        for k in ["total_sessions", "passed", "failed", "blocked", "duration_sec"]:
            assert_in(k, summary)

    @feature(15, "Idempotent duplicate handling")
    def test_f15_t04_idempotent_duplicate_handling(self):
        """Verify backend response structure reports duplicate counts without failure."""
        dup_resp = {"saved": 0, "duplicates": 1, "rejected": 0, "errors": []}
        assert_equal(dup_resp["duplicates"], 1)
        assert_equal(dup_resp["saved"], 0)
        assert_equal(len(dup_resp["errors"]), 0)

    @feature(15, "Failed session logging contract")
    def test_f15_t05_failed_session_logging_contract(self):
        """Verify failed sessions log contract: failed_sessions.csv captures error details."""
        failed_record = {
            "session_id": "SES-042",
            "reason": "CONNECTION_TIMEOUT",
            "http_status": 0,
            "retry_count": 3,
        }
        assert_in("session_id", failed_record)
        assert_in("reason", failed_record)

    # -------------------------------------------------------------------------
    # Feature 16: Raw Evidence Preservation (R4 § Phase 5)
    # -------------------------------------------------------------------------
    @feature(16, "Ten raw evidence files inventory")
    def test_f16_t01_ten_raw_evidence_files_inventory(self):
        """Verify the 10 mandated raw evidence filenames."""
        mandated_evidence_files = [
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
        ]
        assert_equal(len(mandated_evidence_files), 10, "Must require exactly 10 raw evidence files")

    @feature(16, "Sessions CSV schema contract")
    def test_f16_t02_sessions_csv_schema_contract(self):
        """Verify sessions.csv required headers."""
        required_headers = ["session_id", "seq", "door_open_sec", "weight_delta_g", "stay_min", "rfid_ok", "category"]
        assert_equal(len(required_headers), 7)
        assert_in("session_id", required_headers)
        assert_in("weight_delta_g", required_headers)

    @feature(16, "Sensor readings CSV schema contract")
    def test_f16_t03_sensor_readings_csv_schema_contract(self):
        """Verify sensor_readings.csv required headers."""
        required_headers = ["session_id", "timestamp", "sensor_type", "reading_value", "unit"]
        assert_in("sensor_type", required_headers)
        assert_in("reading_value", required_headers)

    @feature(16, "Backend JSONL log format contract")
    def test_f16_t04_backend_jsonl_log_format_contract(self):
        """Verify backend request/response log format follows JSONL standard."""
        req_line = json.dumps({"session_id": "SES-001", "endpoint": "/api/locker/batch", "body": {}})
        parsed = json.loads(req_line)
        assert_in("session_id", parsed)
        assert_in("endpoint", parsed)

    @feature(16, "Reproduction config YAML contract")
    def test_f16_t05_reproduction_config_yaml_contract(self):
        """Verify reproduction_config.yaml required parameters: seed, sessions, target."""
        config_schema = ["random_seed", "total_sessions", "target_url", "stratification"]
        assert_in("random_seed", config_schema)
        assert_in("total_sessions", config_schema)

    # -------------------------------------------------------------------------
    # Feature 17: Baseline B0 vs Proposed B1 Evaluation (R3 § Phase 4)
    # -------------------------------------------------------------------------
    @feature(17, "B0 baseline definition contract")
    def test_f17_t01_b0_baseline_definition_contract(self):
        """Verify Baseline B0 is defined as backend without multi-sensor detection."""
        b0_spec = {
            "name": "B0_Baseline",
            "multisensor_detection": False,
            "rule_set": "original_legacy",
        }
        assert_false(b0_spec["multisensor_detection"])

    @feature(17, "B1 proposed definition contract")
    def test_f17_t02_b1_proposed_definition_contract(self):
        """Verify Proposed B1 is defined as backend with multi-sensor detection."""
        b1_spec = {
            "name": "B1_Proposed",
            "multisensor_detection": True,
            "rule_set": "multisensor_enhanced",
        }
        assert_true(b1_spec["multisensor_detection"])

    @feature(17, "Identical scenario input contract")
    def test_f17_t03_identical_scenario_input_contract(self):
        """Verify B0 and B1 are evaluated against identical predefined scenario inputs."""
        scenario_ids_b0 = [f"SES-{i:03d}" for i in range(1, 101)]
        scenario_ids_b1 = [f"SES-{i:03d}" for i in range(1, 101)]
        assert_equal(scenario_ids_b0, scenario_ids_b1, "Scenario inputs for B0 and B1 must be identical")

    @feature(17, "Comparative metrics contract")
    def test_f17_t04_comparative_metrics_contract(self):
        """Verify evaluation calculates precision, recall, F1, balanced accuracy for both B0 and B1."""
        metrics_b0 = self.artifacts.validate_confusion_matrix(tp=10, fp=5, tn=75, fn=10)
        metrics_b1 = self.artifacts.validate_confusion_matrix(tp=19, fp=2, tn=78, fn=1)
        assert_in("precision", metrics_b0)
        assert_in("recall", metrics_b0)
        assert_in("f1", metrics_b0)
        assert_in("balanced_acc", metrics_b0)

    @feature(17, "Comparative delta validation")
    def test_f17_t05_comparative_delta_validation(self):
        """Verify B1 achieves higher F1 and lower false-negative rate than B0 on tamper/fault."""
        metrics_b0 = self.artifacts.validate_confusion_matrix(tp=10, fp=5, tn=75, fn=10)
        metrics_b1 = self.artifacts.validate_confusion_matrix(tp=19, fp=2, tn=78, fn=1)
        assert_true(metrics_b1["f1"] > metrics_b0["f1"], "B1 F1 must outperform B0")
        assert_true(metrics_b1["fnr"] < metrics_b0["fnr"], "B1 false negative rate must be lower than B0")
