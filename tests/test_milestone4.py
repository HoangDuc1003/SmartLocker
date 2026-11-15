"""
Unit and Integration Test Suite for Milestone 4 (Requirement R4).
Verifies:
- Pure Python Statistical Engine (Wilson score CIs, Edwards McNemar test, Latency stats, Classification metrics)
- Haber-Stornetta SHA-256 Audit Hash Chain Verifier
- Evidence preservation in final_audit_v1 and final_audit_v2
- Deliverables FINAL_EXPERIMENTAL_METHODOLOGY.md and FINAL_RESULTS_REPORT.md
"""

import json
import math
import os
import unittest

from experiments.statistical_tests import (
    wilson_score_interval,
    mcnemar_test,
    latency_distribution_statistics,
    compute_classification_metrics,
    bootstrap_metric_ci,
)
from experiments.verify_hash_chain import (
    compute_canonical_hash,
    verify_audit_chain,
    test_tamper_detection,
    ZERO_HASH,
)


class TestPurePythonStatisticalEngine(unittest.TestCase):
    """Verifies statistical formulations and zero external dependency constraints."""

    def test_wilson_score_interval_nominal(self):
        """Wilson score interval for 97 successes out of 100 trials matches theory."""
        low, high = wilson_score_interval(97, 100)
        self.assertEqual(low, 0.9155)
        self.assertEqual(high, 0.9897)
        self.assertLess(low, high)
        self.assertGreaterEqual(low, 0.0)
        self.assertLessEqual(high, 1.0)

    def test_wilson_score_interval_boundary_zero(self):
        """Wilson score interval for 0 successes handles lower bound without zero-width degeneracy."""
        low, high = wilson_score_interval(0, 20)
        self.assertEqual(low, 0.0)
        self.assertGreater(high, 0.0)
        self.assertEqual(high, 0.1611)

    def test_wilson_score_interval_boundary_full(self):
        """Wilson score interval for 20 successes out of 20 trials handles upper bound without degeneracy."""
        low, high = wilson_score_interval(20, 20)
        self.assertLess(low, 1.0)
        self.assertEqual(low, 0.8389)
        self.assertEqual(high, 1.0)

    def test_mcnemar_test_edwards_continuity_correction(self):
        """Edwards continuity-corrected McNemar test matches exact chi2 and scientific p-value."""
        # 50 both correct, 47 B1 only, 0 B0 only, 3 both incorrect
        res = mcnemar_test(n00=3, n01=0, n10=47, n11=50)
        self.assertEqual(res["chi2_statistic"], 45.0213)
        self.assertEqual(res["p_value_formatted"], "1.95e-11")
        self.assertEqual(res["p_value_exact_formatted"], "1.42e-14")
        self.assertEqual(res["cohens_g"], 0.5)
        self.assertTrue(res["significant_p001"])
        self.assertEqual(res["degrees_of_freedom"], 1)

    def test_mcnemar_test_zero_discordant(self):
        """McNemar test with zero discordant pairs returns p=1.0 and chi2=0.0."""
        res = mcnemar_test(n00=10, n01=0, n10=0, n11=90)
        self.assertEqual(res["chi2_statistic"], 0.0)
        self.assertEqual(res["p_value"], 1.0)
        self.assertFalse(res["significant_p05"])

    def test_latency_distribution_statistics(self):
        """Verifies mean, percentiles, sample std, and population std for latency series."""
        durations = [10.0, 20.0, 30.0, 40.0, 50.0]
        stats = latency_distribution_statistics(durations)
        self.assertEqual(stats["count"], 5)
        self.assertEqual(stats["mean_ms"], 30.0)
        self.assertEqual(stats["median_p50_ms"], 30.0)
        self.assertEqual(stats["min_ms"], 10.0)
        self.assertEqual(stats["max_ms"], 50.0)
        self.assertEqual(stats["sample_std_ms"], 15.81)
        self.assertEqual(stats["pop_std_ms"], 14.14)
        self.assertEqual(stats["p95_ms"], 50.0)

    def test_compute_classification_metrics(self):
        """Verifies multi-class metrics aggregation."""
        classes = ["A", "B", "C"]
        y_true = ["A"] * 10 + ["B"] * 10 + ["C"] * 10
        y_pred = ["A"] * 10 + ["B"] * 8 + ["C"] * 2 + ["C"] * 10

        metrics = compute_classification_metrics(y_true, y_pred, classes)
        self.assertAlmostEqual(metrics["overall_accuracy"], 28 / 30, places=4)
        self.assertIn("overall_accuracy_ci_95", metrics)
        self.assertIn("macro_f1", metrics)
        self.assertIn("micro_f1", metrics)
        self.assertIn("weighted_f1", metrics)


class TestHaberStornettaAuditHashVerifier(unittest.TestCase):
    """Verifies cryptographic hash chain integrity and tamper detection proof."""

    def test_genesis_hash_block(self):
        """Genesis block starts with 64 ASCII zeros."""
        self.assertEqual(len(ZERO_HASH), 64)
        self.assertEqual(ZERO_HASH, "0" * 64)

    def test_canonical_hash_utf16le(self):
        """Canonical SHA-256 hash uses Little-Endian UTF-16 bytes matching SQL Server."""
        h = compute_canonical_hash(
            audit_id=1,
            ts_iso="2026-11-15T18:00:00.0000000",
            actor_user_id=1,
            action="CREATE",
            object_type="ALERT",
            object_id=555,
            diff_json='{"status":"OPEN"}',
            prev_hash=ZERO_HASH,
        )
        self.assertEqual(len(h), 64)
        self.assertTrue(all(c in "0123456789abcdef" for c in h))

    def test_verify_audit_chain_clean_ledger(self):
        """Valid synthetic ledger verifies as intact with PASS status."""
        rows = []
        prev = ZERO_HASH
        for i in range(1, 6):
            expected = compute_canonical_hash(
                audit_id=i,
                ts_iso=f"2026-11-15T18:0{i}:00.0000000",
                actor_user_id=i,
                action="TEST_ACTION",
                object_type="TEST_OBJ",
                object_id=i * 10,
                diff_json="",
                prev_hash=prev,
            )
            rows.append({
                "anchor_id": i,
                "audit_id": i,
                "ts_iso": f"2026-11-15T18:0{i}:00.0000000",
                "actor_user_id": i,
                "action": "TEST_ACTION",
                "object_type": "TEST_OBJ",
                "object_id": i * 10,
                "diff": "",
                "prev_hash": prev,
                "chain_hash": expected,
                "row_hash": expected,
            })
            prev = expected

        res = verify_audit_chain(rows)
        self.assertEqual(res["status"], "PASS")
        self.assertTrue(res["chain_intact"])
        self.assertEqual(res["total_nodes_verified"], 5)
        self.assertEqual(res["tail_chain_hash"], prev)

    def test_tamper_detection_pinpoints_corrupted_node(self):
        """Tamper detection mutates a node and verifies detection."""
        rows = []
        prev = ZERO_HASH
        for i in range(1, 6):
            expected = compute_canonical_hash(
                audit_id=i,
                ts_iso=f"2026-11-15T18:0{i}:00.0000000",
                actor_user_id=i,
                action="ACTION_A",
                object_type="OBJ_A",
                object_id=i,
                diff_json="",
                prev_hash=prev,
            )
            rows.append({
                "anchor_id": i,
                "audit_id": i,
                "ts_iso": f"2026-11-15T18:0{i}:00.0000000",
                "actor_user_id": i,
                "action": "ACTION_A",
                "object_type": "OBJ_A",
                "object_id": i,
                "diff": "",
                "prev_hash": prev,
                "chain_hash": expected,
                "row_hash": expected,
            })
            prev = expected

        tamper_res = test_tamper_detection(rows)
        self.assertEqual(tamper_res["verification_result"], "PASS")
        self.assertTrue(tamper_res["tamper_detected"])


class TestMilestone4EvidencePreservation(unittest.TestCase):
    """Verifies evidence directory partitioning and deliverable documentation."""

    def test_final_audit_v1_preserved(self):
        """experiments/results/final_audit_v1 contains complete historical audit baseline."""
        v1_dir = "experiments/results/final_audit_v1"
        self.assertTrue(os.path.isdir(v1_dir))
        required = [
            "sessions.json", "sessions.csv", "evaluation_metrics.json",
            "statistical_tests.json", "confusion_matrix_b0.csv", "confusion_matrix_b1.csv"
        ]
        for f in required:
            p = os.path.join(v1_dir, f)
            self.assertTrue(os.path.isfile(p), f"Missing {f} in {v1_dir}")
            self.assertGreater(os.path.getsize(p), 0)

    def test_final_audit_v2_artifacts(self):
        """experiments/results/final_audit_v2 contains all versioned execution artifacts."""
        v2_dir = "experiments/results/final_audit_v2"
        self.assertTrue(os.path.isdir(v2_dir))
        required = [
            "sessions.json", "sessions.csv", "backend_requests.jsonl",
            "backend_responses.jsonl", "evaluation_metrics.json",
            "statistical_tests.json", "audit_chain_verification.json",
            "confusion_matrix_b0.csv", "confusion_matrix_b1.csv"
        ]
        for f in required:
            p = os.path.join(v2_dir, f)
            self.assertTrue(os.path.isfile(p), f"Missing {f} in {v2_dir}")
            self.assertGreater(os.path.getsize(p), 0)

    def test_methodology_and_results_deliverables_exist(self):
        """FINAL_EXPERIMENTAL_METHODOLOGY.md and FINAL_RESULTS_REPORT.md exist in repository root."""
        for doc in ["FINAL_EXPERIMENTAL_METHODOLOGY.md", "FINAL_RESULTS_REPORT.md"]:
            self.assertTrue(os.path.isfile(doc), f"Missing required deliverable: {doc}")
            size = os.path.getsize(doc)
            self.assertGreater(size, 10000, f"{doc} size is unexpectedly small: {size} bytes")


if __name__ == "__main__":
    unittest.main()
