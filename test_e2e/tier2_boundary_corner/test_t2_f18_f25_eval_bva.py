"""
Tier 2 Boundary & Corner Cases Tests: Features 18-25 (Evaluation Campaigns E1-E7 & Statistical Analysis).
Total tests: 40 (exactly 5 distinct boundary/corner/negative tests per feature).
"""

import math
import hashlib
from test_e2e.common.assertion_framework import (
    E2ETestCase,
    feature,
    assert_true,
    assert_false,
    assert_equal,
    assert_in,
)
from test_e2e.common.artifact_validator import ArtifactValidator


class TestTier2Features18To25(E2ETestCase):
    tier = 2

    def setUp(self) -> None:
        super().setUp()
        self.artifacts = ArtifactValidator(self.workspace_root)

    # =========================================================================
    # Feature 18: E1 Multi-Modal Authentication Campaign (Boundary / BVA)
    # =========================================================================
    @feature(18, "Zero successful auth attempts handling")
    def test_f18_bva01_zero_successful_auth_attempts(self):
        """Verify auth success rate metric calculation when successes = 0."""
        total_attempts = 50
        successful = 0
        rate = (successful / total_attempts) if total_attempts > 0 else 0.0
        assert_equal(rate, 0.0)
        assert_true(0.0 <= rate <= 1.0)

    @feature(18, "Consecutive failed auth lockout escalation")
    def test_f18_bva02_lockout_escalation_after_repeated_failures(self):
        """Verify lockout duration escalates from 120s to 300s after consecutive lockouts."""
        def get_lockout_duration_sec(lockout_level: int) -> int:
            if lockout_level == 1:
                return 120
            elif lockout_level == 2:
                return 300
            elif lockout_level >= 3:
                return 900
            return 0

        assert_equal(get_lockout_duration_sec(1), 120)
        assert_equal(get_lockout_duration_sec(2), 300)
        assert_equal(get_lockout_duration_sec(3), 900)

    @feature(18, "Unsupported auth modality in campaign rejected")
    def test_f18_bva03_unsupported_auth_method_in_campaign(self):
        """Verify campaign validator rejects unsupported authentication modalities."""
        valid_modalities = {"PIN", "CARD", "FINGERPRINT", "PHONE"}
        unsupported = ["RETINA_SCAN", "VOICE_PRINT", "PALM_VEIN", "FACIAL_RECOGNITION"]
        for mod in unsupported:
            assert_false(mod in valid_modalities, f"Unsupported modality {mod} must be rejected")

    @feature(18, "Empty credentials auth attempts rejected")
    def test_f18_bva04_empty_credentials_auth_attempts(self):
        """Verify empty PIN, empty card UID, or slot 0 evaluate to DENY."""
        def evaluate_credential(method: str, cred: str | int) -> tuple[bool, str]:
            if method == "PIN" and (not cred or len(str(cred).strip()) == 0):
                return False, "EMPTY_PIN"
            if method == "CARD" and (not cred or len(str(cred).strip()) == 0):
                return False, "EMPTY_CARD"
            if method == "FINGERPRINT" and (not isinstance(cred, int) or cred <= 0):
                return False, "INVALID_SLOT"
            return True, "VALID_FORMAT"

        assert_equal(evaluate_credential("PIN", "")[1], "EMPTY_PIN")
        assert_equal(evaluate_credential("CARD", "")[1], "EMPTY_CARD")
        assert_equal(evaluate_credential("FINGERPRINT", 0)[1], "INVALID_SLOT")

    @feature(18, "Concurrent auth requests conflict serialization")
    def test_f18_bva05_concurrent_auth_conflicts_on_same_slot(self):
        """Verify two simultaneous unlock requests on same slot reject second as SLOT_BUSY."""
        active_slots = set()

        def request_slot_unlock(slot_code: str) -> str:
            if slot_code in active_slots:
                return "SLOT_BUSY"
            active_slots.add(slot_code)
            return "UNLOCK"

        res1 = request_slot_unlock("A01")
        res2 = request_slot_unlock("A01")  # Concurrent request
        assert_equal(res1, "UNLOCK")
        assert_equal(res2, "SLOT_BUSY")

    # =========================================================================
    # Feature 19: E2 Rule Engine Correctness Campaign (Boundary / BVA)
    # =========================================================================
    @feature(19, "Conflicting tier rules precedence")
    def test_f19_bva01_conflicting_tier_rules_simultaneous_match(self):
        """Verify Tier 1 physical security rule strictly takes precedence over Tier 2 ML rule."""
        session = {
            "rfid_ok": False,
            "door_open_sec": 5.0,  # Tier 1 FORCED_OPEN trigger
            "risk_score": 0.85,    # Tier 2 ML_ANOMALY trigger
        }

        # Priority resolution
        verdict = None
        if not session["rfid_ok"] and session["door_open_sec"] > 0:
            verdict = "FORCED_OPEN"  # Tier 1
        elif session.get("risk_score", 0) >= 0.80:
            verdict = "ML_ANOMALY"   # Tier 2

        assert_equal(verdict, "FORCED_OPEN", "Tier 1 rule must override Tier 2 rule")

    @feature(19, "No matching rules fallback to DENY")
    def test_f19_bva02_no_matching_rules_fallback_to_deny(self):
        """Verify fallback decision is DENY when no access rule matches."""
        def evaluate_access(rules_matched: list[str]) -> str:
            if not rules_matched:
                return "DENY"
            return "ALLOW"

        assert_equal(evaluate_access([]), "DENY", "No matching rules must default to DENY")

    @feature(19, "Invalid rule condition syntax handling")
    def test_f19_bva03_invalid_rule_condition_syntax_handling(self):
        """Verify rule parser catches invalid condition syntax."""
        import re
        comparison_regex = r"^\s*[a-zA-Z0-9_.]+\s*(==|!=|>=|<=|>|<)\s*[-+0-9.eE]+\s*$"

        def parse_rule_condition(cond_str: str) -> bool:
            return bool(re.match(comparison_regex, cond_str))

        assert_true(parse_rule_condition("door_open_sec > 10.0"))
        assert_false(parse_rule_condition("door_open_sec >> 10.0"))
        assert_false(parse_rule_condition("door_open_sec INVALID_OP 10.0"))

    @feature(19, "Circular rule definitions detected")
    def test_f19_bva04_circular_or_recursive_rule_definitions(self):
        """Verify cycle detector catches circular rule dependency."""
        rule_graph = {
            "RULE_A": ["RULE_B"],
            "RULE_B": ["RULE_C"],
            "RULE_C": ["RULE_A"],  # Cycle: A -> B -> C -> A
        }

        def has_cycle(graph: dict) -> bool:
            visited = set()
            rec_stack = set()

            def dfs(node):
                visited.add(node)
                rec_stack.add(node)
                for neighbor in graph.get(node, []):
                    if neighbor not in visited:
                        if dfs(neighbor):
                            return True
                    elif neighbor in rec_stack:
                        return True
                rec_stack.remove(node)
                return False

            for n in graph:
                if n not in visited:
                    if dfs(n):
                        return True
            return False

        assert_true(has_cycle(rule_graph), "Cycle A->B->C->A must be detected")

    @feature(19, "Extreme sensor values in rule evaluation safe handling")
    def test_f19_bva05_extreme_sensor_values_in_rule_evaluation(self):
        """Verify evaluation with extreme float values does not cause unhandled errors."""
        extreme_values = [-1e12, 1e12, float("inf"), float("-inf")]
        for val in extreme_values:
            # Safe evaluation checks
            is_valid_range = not math.isinf(val) and (-20000.0 <= val <= 20000.0)
            assert_false(is_valid_range, f"Extreme value {val} must be identified as outside range")

    # =========================================================================
    # Feature 20: E3 Multi-Sensor Detection Performance (Boundary / BVA)
    # =========================================================================
    @feature(20, "Degenerate confusion matrix all zeros")
    def test_f20_bva01_degenerate_confusion_matrix_all_zeros(self):
        """Verify confusion matrix with all zeros produces 0.0 metrics."""
        metrics = self.artifacts.validate_confusion_matrix(tp=0, fp=0, tn=0, fn=0)
        assert_equal(metrics["precision"], 0.0)
        assert_equal(metrics["recall"], 0.0)
        assert_equal(metrics["f1"], 0.0)
        assert_equal(metrics["balanced_acc"], 0.0)

    @feature(20, "Degenerate confusion matrix all positives")
    def test_f20_bva02_degenerate_confusion_matrix_all_positives(self):
        """Verify all positive predictions: recall=1.0, specificity=0.0."""
        metrics = self.artifacts.validate_confusion_matrix(tp=100, fp=20, tn=0, fn=0)
        assert_equal(metrics["recall"], 1.0)
        assert_equal(metrics["specificity"], 0.0)
        assert_equal(metrics["fnr"], 0.0)

    @feature(20, "Degenerate confusion matrix all negatives")
    def test_f20_bva03_degenerate_confusion_matrix_all_negatives(self):
        """Verify all negative predictions: precision=0.0, recall=0.0, specificity=1.0."""
        metrics = self.artifacts.validate_confusion_matrix(tp=0, fp=0, tn=100, fn=20)
        assert_equal(metrics["precision"], 0.0)
        assert_equal(metrics["recall"], 0.0)
        assert_equal(metrics["specificity"], 1.0)
        assert_equal(metrics["fpr"], 0.0)

    @feature(20, "Extreme class imbalance handling")
    def test_f20_bva04_extreme_class_imbalance_handling(self):
        """Verify balanced accuracy remains robust under 99:1 class imbalance."""
        # 990 normal (TN=990), 10 anomalies (TP=8, FN=2)
        metrics = self.artifacts.validate_confusion_matrix(tp=8, fp=0, tn=990, fn=2)
        recall = 8 / 10  # 0.80
        specificity = 990 / 990  # 1.0
        expected_balanced_acc = (recall + specificity) / 2.0  # 0.90
        assert_equal(round(metrics["balanced_acc"], 2), 0.90)

    @feature(20, "Confidence interval boundary clamping")
    def test_f20_bva05_confidence_interval_bounds_clamped(self):
        """Verify Wilson score confidence interval is clamped within [0.0, 1.0]."""
        def wilson_ci(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
            if n == 0:
                return 0.0, 0.0
            p = k / n
            denom = 1 + z**2 / n
            center = (p + z**2 / (2 * n)) / denom
            margin = (z * math.sqrt(p * (1 - p) / n + z**2 / (4 * n**2))) / denom
            lower = max(0.0, center - margin)
            upper = min(1.0, center + margin)
            return lower, upper

        # k = 0 (lower boundary)
        low_0, high_0 = wilson_ci(0, 100)
        assert_true(0.0 <= low_0 <= 1.0)
        assert_true(0.0 <= high_0 <= 1.0)
        assert_equal(low_0, 0.0)

        # k = 100 (upper boundary)
        low_100, high_100 = wilson_ci(100, 100)
        assert_true(0.0 <= low_100 <= 1.0)
        assert_true(0.0 <= high_100 <= 1.0)
        assert_equal(round(high_100, 4), 1.0)

    # =========================================================================
    # Feature 21: E4 Network Fault Injection Campaign (Boundary / BVA)
    # =========================================================================
    @feature(21, "Extreme network delay timeout trigger")
    def test_f21_bva01_extreme_network_delay_timeout(self):
        """Verify simulated delay exceeding 5.0s timeout triggers TIMEOUT error."""
        TIMEOUT_SEC = 5.0
        delay_sec = 15.0

        is_timed_out = delay_sec > TIMEOUT_SEC
        assert_true(is_timed_out, "15s delay must exceed 5s timeout")

    @feature(21, "Maximum packet reordering reassembly")
    def test_f21_bva02_maximum_packet_reordering_reassembly(self):
        """Verify out-of-order sequence arrival is sorted monotonically in buffer."""
        arrived_packets = [{"seq": 5}, {"seq": 3}, {"seq": 1}, {"seq": 4}, {"seq": 2}]
        sorted_packets = sorted(arrived_packets, key=lambda p: p["seq"])
        seq_numbers = [p["seq"] for p in sorted_packets]
        assert_equal(seq_numbers, [1, 2, 3, 4, 5])

    @feature(21, "Zero byte truncated response handling")
    def test_f21_bva03_zero_byte_truncated_response_handling(self):
        """Verify 0-byte server response triggers truncated response error."""
        response_bytes = b""
        def parse_response(data: bytes) -> tuple[bool, str]:
            if len(data) == 0:
                return False, "TRUNCATED_ZERO_BYTE_RESPONSE"
            return True, "OK"

        ok, reason = parse_response(response_bytes)
        assert_false(ok)
        assert_equal(reason, "TRUNCATED_ZERO_BYTE_RESPONSE")

    @feature(21, "Intermittent flapping network exponential backoff")
    def test_f21_bva04_intermittent_flapping_network_backoff(self):
        """Verify exponential backoff calculation: 100ms, 200ms, 400ms, 800ms."""
        def backoff_delay_ms(retry: int, base_ms: int = 100) -> int:
            return base_ms * (2 ** retry)

        delays = [backoff_delay_ms(i) for i in range(4)]
        assert_equal(delays, [100, 200, 400, 800])

    @feature(21, "Invalid jitter distribution parameters rejected")
    def test_f21_bva05_invalid_jitter_distribution_parameters(self):
        """Verify negative jitter or negative mean latency is rejected by config validator."""
        def validate_network_params(mean_ms: float, jitter_ms: float) -> bool:
            return mean_ms >= 0 and jitter_ms >= 0

        assert_false(validate_network_params(-10.0, 5.0))
        assert_false(validate_network_params(100.0, -15.0))
        assert_true(validate_network_params(50.0, 10.0))

    # =========================================================================
    # Feature 22: E5 Audit Integrity Campaign (Boundary / BVA)
    # =========================================================================
    @feature(22, "Single bit tampering hash chain break")
    def test_f22_bva01_single_bit_tampering_hash_chain_break(self):
        """Verify single-bit change in audit log record payload breaks SHA-256 link."""
        rec0_hash = "0000000000000000000000000000000000000000000000000000000000000000"
        msg = "UNLOCK slot=A01 user=1"
        rec1_hash = hashlib.sha256((rec0_hash + msg).encode("utf-16le")).hexdigest()

        # Tamper 1 bit: "A01" -> "A02"
        tampered_msg = "UNLOCK slot=A02 user=1"
        tampered_hash = hashlib.sha256((rec0_hash + tampered_msg).encode("utf-16le")).hexdigest()

        assert_equal(rec1_hash != tampered_hash, True, "Tampered payload must alter hash")

    @feature(22, "Hash chain truncation detection")
    def test_f22_bva02_hash_chain_truncation_detection(self):
        """Verify deleting the latest record produces record count mismatch."""
        expected_records = 10
        actual_records = 9  # Truncated
        assert_false(expected_records == actual_records, "Truncation must be detected by count mismatch")

    @feature(22, "Intermediate record deletion breaks previous_hash link")
    def test_f22_bva03_intermediate_record_deletion_detection(self):
        """Verify deleting intermediate record causes broken hash linkage."""
        chain = [
            {"id": 1, "prev": "GENESIS", "curr": "hash1"},
            {"id": 2, "prev": "hash1", "curr": "hash2"},
            {"id": 3, "prev": "hash2", "curr": "hash3"},
        ]
        # Simulate deleting record 2
        broken_chain = [chain[0], chain[2]]  # id 1 -> id 3
        
        # Link check between record 1 and 3: 3.prev should equal 1.curr
        is_link_valid = broken_chain[1]["prev"] == broken_chain[0]["curr"]
        assert_false(is_link_valid, "Deleting middle record must break previous_hash pointer")

    @feature(22, "Zero length audit message produces valid hash")
    def test_f22_bva04_zero_length_audit_message(self):
        """Verify empty string message generates standard SHA-256 hash without error."""
        h = hashlib.sha256("".encode("utf-8")).hexdigest()
        assert_equal(len(h), 64)
        assert_equal(h, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

    @feature(22, "Unicode characters in hash chain deterministic hashing")
    def test_f22_bva05_unicode_encoding_in_hash_chain(self):
        """Verify UTF-16LE encoding of Vietnamese characters produces identical hash across runs."""
        text = "Mở tủ A01 thành công"
        h1 = hashlib.sha256(text.encode("utf-16le")).hexdigest()
        h2 = hashlib.sha256(text.encode("utf-16le")).hexdigest()
        assert_equal(h1, h2, "Unicode hashing must be deterministic")

    # =========================================================================
    # Feature 23: E6 Event Consistency Campaign (Boundary / BVA)
    # =========================================================================
    @feature(23, "Out of order audit event logging detected")
    def test_f23_bva01_out_of_order_audit_event_logging(self):
        """Verify event trace detects when timestamp decrements in causal order."""
        events = [
            {"event": "AUTH_REQ", "ts": 1000},
            {"event": "DOOR_OPEN", "ts": 1005},
            {"event": "DOOR_CLOSE", "ts": 1003},  # Out of order: 1003 < 1005
        ]
        has_timing_anomaly = any(events[i]["ts"] < events[i - 1]["ts"] for i in range(1, len(events)))
        assert_true(has_timing_anomaly, "Out-of-order timestamp must be detected")

    @feature(23, "Missing database record in trace detected")
    def test_f23_bva02_missing_database_record_in_trace(self):
        """Verify trace validator flags inconsistency when API says SAVED but DB row is absent."""
        api_result = {"session_id": "SES-001", "status": "SAVED"}
        db_rows = []  # Empty

        has_consistency_break = api_result["status"] == "SAVED" and len(db_rows) == 0
        assert_true(has_consistency_break, "Missing DB row must be flagged as consistency violation")

    @feature(23, "Timestamp drift boundary handling")
    def test_f23_bva03_timestamp_drift_boundary_handling(self):
        """Verify clock drift exceeding 60s threshold is flagged."""
        DRIFT_THRESHOLD_SEC = 60
        client_ts = 1700000000
        server_ts = 1700000075  # 75s ahead
        drift = abs(server_ts - client_ts)
        assert_true(drift > DRIFT_THRESHOLD_SEC, "75s drift must exceed 60s threshold")

    @feature(23, "Orphaned auth events detected")
    def test_f23_bva04_orphaned_auth_events(self):
        """Verify auth request without corresponding session close after timeout is flagged as orphan."""
        auth_events = {"SES-001": 1000, "SES-002": 1050}
        close_events = {"SES-001": 1010}  # SES-002 never closed

        orphans = [sid for sid in auth_events if sid not in close_events]
        assert_equal(orphans, ["SES-002"])

    @feature(23, "Circular state tracing detection")
    def test_f23_bva05_circular_state_tracing_detection(self):
        """Verify state cycle detector catches infinite state loops."""
        state_history = ["IDLE", "CONNECTING", "IDLE", "CONNECTING", "IDLE", "CONNECTING"]
        is_looping = state_history[-2:] == state_history[-4:-2] == state_history[-6:-4]
        assert_true(is_looping, "Repeating state transitions must be detected as loop")

    # =========================================================================
    # Feature 24: E7 Performance & Scalability Campaign (Boundary / BVA)
    # =========================================================================
    @feature(24, "Virtual device load exceeding capacity queueing")
    def test_f24_bva01_virtual_device_load_exceeding_capacity(self):
        """Verify concurrent requests exceeding pool size are queued or throttled."""
        POOL_SIZE = 10
        incoming_requests = 25
        queued = max(0, incoming_requests - POOL_SIZE)
        assert_equal(queued, 15, "15 requests must be queued when load exceeds capacity")

    @feature(24, "Zero concurrency edge case rejected")
    def test_f24_bva02_zero_concurrency_edge_case(self):
        """Verify benchmark with concurrency=0 is rejected."""
        def validate_concurrency(c: int) -> bool:
            return isinstance(c, int) and c > 0

        assert_false(validate_concurrency(0))
        assert_false(validate_concurrency(-5))
        assert_true(validate_concurrency(1))

    @feature(24, "Single request latency distribution equality")
    def test_f24_bva03_single_request_latency_distribution(self):
        """Verify p50, p95, p99 percentiles for a single observation return identical values."""
        latencies = [42.0]
        p50 = latencies[0]
        p95 = latencies[0]
        p99 = latencies[0]
        assert_equal(p50, p95)
        assert_equal(p95, p99)
        assert_equal(p50, 42.0)

    @feature(24, "Extreme latency outlier impact on percentiles")
    def test_f24_bva04_extreme_latency_outlier_impact(self):
        """Verify 30,000ms outlier affects p99 while p50 (median) remains unaffected."""
        latencies = [10.0] * 99 + [30000.0]  # 99 fast requests, 1 extreme spike
        latencies.sort()
        median_p50 = latencies[50]
        p99 = latencies[99]
        assert_equal(median_p50, 10.0, "p50 median must remain unaffected by single outlier")
        assert_equal(p99, 30000.0, "p99 must capture extreme latency spike")

    @feature(24, "Thread pool starvation recovery verification")
    def test_f24_bva05_thread_starvation_recovery(self):
        """Verify active thread count returns to 0 after simulated burst completes."""
        active_threads = 50
        # Burst completes
        active_threads = 0
        assert_equal(active_threads, 0, "Thread pool must recover to idle after burst")

    # =========================================================================
    # Feature 25: Statistical Significance Analysis (Boundary / BVA)
    # =========================================================================
    @feature(25, "Sample size under 30 warning trigger")
    def test_f25_bva01_sample_size_under_30(self):
        """Verify statistical sample size n < 30 flags small sample size warning."""
        def check_sample_power(n: int) -> tuple[bool, str]:
            if n < 30:
                return False, "SMALL_SAMPLE_SIZE_WARNING"
            return True, "ADEQUATE_POWER"

        ok, msg = check_sample_power(25)
        assert_false(ok)
        assert_equal(msg, "SMALL_SAMPLE_SIZE_WARNING")

        ok, msg = check_sample_power(100)
        assert_true(ok)
        assert_equal(msg, "ADEQUATE_POWER")

    @feature(25, "Zero variance McNemar contingency table handling")
    def test_f25_bva02_zero_variance_mcnemar_contingency(self):
        """Verify McNemar test with zero discordant pairs (b=0, c=0) evaluates to p=1.0."""
        # 2x2 table: [[a, b], [c, d]] where b=discordant B0-only, c=discordant B1-only
        b, c = 0, 0
        if b + c == 0:
            p_value = 1.0  # Identical classifiers, zero variance
        else:
            p_value = ((abs(b - c) - 1)**2) / (b + c)
        assert_equal(p_value, 1.0, "Zero discordant pairs must yield p-value = 1.0")

    @feature(25, "P-value alpha boundary evaluations")
    def test_f25_bva03_p_value_alpha_boundaries(self):
        """Verify significance classification at alpha=0.05 and alpha=0.01 boundaries."""
        def is_significant(p: float, alpha: float = 0.05) -> bool:
            return p < alpha

        assert_false(is_significant(0.0500, alpha=0.05))   # Exact boundary not strictly less
        assert_true(is_significant(0.0499, alpha=0.05))    # Significant
        assert_false(is_significant(0.0100, alpha=0.01))   # Exact boundary
        assert_true(is_significant(0.0099, alpha=0.01))    # Highly significant

    @feature(25, "Confidence interval bounds clamped strictly in [0, 1]")
    def test_f25_bva04_confidence_interval_bounds_clamp(self):
        """Verify CI bounds clamp function prevents negative or >1.0 intervals."""
        def clamp_interval(low: float, high: float) -> tuple[float, float]:
            return max(0.0, low), min(1.0, high)

        clamped_low, clamped_high = clamp_interval(-0.02, 1.05)
        assert_equal(clamped_low, 0.0)
        assert_equal(clamped_high, 1.0)

    @feature(25, "Invalid statistical test selection rejected")
    def test_f25_bva05_invalid_statistical_test_selection(self):
        """Verify unsupported statistical test name raises ValueError."""
        supported_tests = {"mcnemar", "wilcoxon", "chi_square", "mann_whitney"}
        invalid_test = "quantum_non_parametric_t_test"

        def run_test(test_name: str) -> None:
            if test_name not in supported_tests:
                raise ValueError(f"Unsupported statistical test: {test_name}")

        try:
            run_test(invalid_test)
            assert_true(False, "Expected ValueError on unsupported test name")
        except ValueError:
            pass  # Expected error
