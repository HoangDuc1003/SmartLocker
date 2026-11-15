"""
SmartLocker Unified E2E Test Runner.
Executes opaque-box test suites across 4 tiers (Feature Coverage, Boundary/BVA,
Pairwise Cross-Feature, and Real-World Scenarios) with feature filtering and JSON reporting.
"""

import os
import sys
import re
import time
import argparse
import unittest
import importlib
from pathlib import Path
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

# Ensure workspace root is in sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_ROOT = SCRIPT_DIR.parent
if str(WORKSPACE_ROOT) not in sys.path:
    sys.path.insert(0, str(WORKSPACE_ROOT))

from test_e2e.common.assertion_framework import TestRecord, TestReport, E2ETestCase


class E2ETestResult(unittest.TestResult):
    """Custom TestResult to capture execution records and timing."""

    def __init__(self, verbose: bool = False):
        super().__init__()
        self.verbose = verbose
        self.records: List[TestRecord] = []
        self._test_start: float = 0.0

    def startTest(self, test: unittest.TestCase) -> None:
        super().startTest(test)
        self._test_start = time.perf_counter()

    def addSuccess(self, test: unittest.TestCase) -> None:
        super().addSuccess(test)
        elapsed_ms = (time.perf_counter() - self._test_start) * 1000.0
        self._record(test, "PASS", elapsed_ms)
        if self.verbose:
            print(f"  [PASS] {test.id()} ({elapsed_ms:.1f}ms)")

    def addFailure(self, test: unittest.TestCase, err: Tuple) -> None:
        super().addFailure(test, err)
        elapsed_ms = (time.perf_counter() - self._test_start) * 1000.0
        msg = str(err[1]) if len(err) > 1 else ""
        self._record(test, "FAIL", elapsed_ms, error_message=msg)
        if self.verbose:
            print(f"  [FAIL] {test.id()} ({elapsed_ms:.1f}ms): {msg}")

    def addError(self, test: unittest.TestCase, err: Tuple) -> None:
        super().addError(test, err)
        elapsed_ms = (time.perf_counter() - self._test_start) * 1000.0
        msg = str(err[1]) if len(err) > 1 else ""
        self._record(test, "BLOCKED", elapsed_ms, error_message=msg)
        if self.verbose:
            print(f"  [BLOCKED] {test.id()} ({elapsed_ms:.1f}ms): {msg}")

    def _record(
        self,
        test: unittest.TestCase,
        status: str,
        duration_ms: float,
        error_message: Optional[str] = None,
    ) -> None:
        feat_id = getattr(test, "feature_id", 0)
        method = getattr(test, test._testMethodName, None)
        if method and hasattr(method, "_feature_id"):
            feat_id = getattr(method, "_feature_id")
        tier = getattr(test, "tier", 1)
        doc = (getattr(test, "_testMethodDoc") or "").strip()

        rec = TestRecord(
            test_id=test.id(),
            feature_id=feat_id,
            tier=tier,
            name=test._testMethodName,
            doc=doc,
            status=status,
            duration_ms=round(duration_ms, 2),
            error_message=error_message,
        )
        self.records.append(rec)


def discover_suite(
    tier: Optional[str] = "all",
    feature_filter: Optional[int] = None,
    scenario_filter: Optional[int] = None,
) -> unittest.TestSuite:
    """Discover and filter test cases based on tier and feature flags."""
    suite = unittest.TestSuite()
    test_e2e_dir = WORKSPACE_ROOT / "test_e2e"

    tier_dirs = []
    if tier in ("1", "all"):
        tier_dirs.append(test_e2e_dir / "tier1_feature_coverage")
    if tier in ("2", "all"):
        tier_dirs.append(test_e2e_dir / "tier2_boundary_corner")
    if tier in ("3", "all"):
        tier_dirs.append(test_e2e_dir / "tier3_cross_feature")
    if tier in ("4", "all"):
        tier_dirs.append(test_e2e_dir / "tier4_real_world")

    loader = unittest.TestLoader()

    for tdir in tier_dirs:
        if not tdir.is_dir():
            continue
        discovered = loader.discover(start_dir=str(tdir), pattern="test_*.py", top_level_dir=str(WORKSPACE_ROOT))
        for test in _flatten_suite(discovered):
            # Apply feature filter
            if feature_filter is not None:
                feat_id = None
                method = getattr(test, test._testMethodName, None)
                if method and hasattr(method, "_feature_id"):
                    feat_id = getattr(method, "_feature_id")
                elif hasattr(test, "feature_id") and test.feature_id > 0:
                    feat_id = test.feature_id

                name = test._testMethodName.lower()
                prefix_match = bool(re.search(rf"^test_f0?{feature_filter}_", name))

                if feat_id is not None:
                    if feat_id != feature_filter:
                        continue
                elif not prefix_match:
                    continue

            # Apply scenario filter
            if scenario_filter is not None:
                name = test._testMethodName.lower()
                scen_match = f"s{scenario_filter:02d}" in name or f"s{scenario_filter}_" in name
                if not scen_match:
                    continue

            suite.addTest(test)

    return suite


def _flatten_suite(suite: unittest.TestSuite) -> List[unittest.TestCase]:
    """Recursively flatten test suites to individual test cases."""
    tests = []
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            tests.extend(_flatten_suite(item))
        elif isinstance(item, unittest.TestCase):
            tests.append(item)
    return tests


def main() -> int:
    parser = argparse.ArgumentParser(description="SmartLocker E2E Test Harness")
    parser.add_argument("--tier", choices=["1", "2", "3", "4", "all"], default="all", help="Target test tier")
    parser.add_argument("--feature", type=int, choices=range(1, 34), help="Filter by feature ID (1-33)")
    parser.add_argument("--scenario", type=int, choices=range(1, 19), help="Filter by scenario ID (1-18)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose test execution output")
    parser.add_argument("--report", type=str, help="Output path for JSON test report")

    args = parser.parse_args()

    tier_label = f"Tier {args.tier}" if args.tier != "all" else "All Tiers"
    filter_label = f" (Feature {args.feature})" if args.feature else ""
    if args.scenario:
        filter_label += f" (Scenario {args.scenario})"

    print("=" * 70)
    print(f" SMARTLOCKER E2E TEST RUNNER - {tier_label}{filter_label}")
    print(f" Timestamp: {datetime.now(timezone.utc).isoformat()}")
    print("=" * 70)

    suite = discover_suite(tier=args.tier, feature_filter=args.feature, scenario_filter=args.scenario)
    total_discovered = suite.countTestCases()
    print(f"Discovered {total_discovered} test cases matching criteria.\n")

    start_time = time.perf_counter()
    runner_result = E2ETestResult(verbose=args.verbose)
    suite.run(runner_result)
    total_duration = time.perf_counter() - start_time

    # Build report
    report = TestReport(
        suite_name=f"SmartLocker E2E ({tier_label}{filter_label})",
        timestamp=datetime.now(timezone.utc).isoformat(),
        duration_sec=total_duration,
    )
    for rec in runner_result.records:
        report.add_record(rec)

    # Print summary
    print("\n" + "=" * 70)
    print(" EXECUTION SUMMARY")
    print("=" * 70)
    print(f" Total Tests : {report.total}")
    print(f" Passed      : {report.passed}")
    print(f" Failed      : {report.failed}")
    print(f" Blocked     : {report.blocked}")
    print(f" Pass Rate   : {report.to_dict()['summary']['pass_rate_pct']:.1f}%")
    print(f" Duration    : {total_duration:.2f} seconds")
    print("=" * 70)

    if report.failed > 0:
        print("\nFAILURES:")
        for rec in report.records:
            if rec.status == "FAIL":
                print(f"  - {rec.test_id}: {rec.error_message}")

    if report.blocked > 0:
        print("\nBLOCKED / ERRORS:")
        for rec in report.records:
            if rec.status == "BLOCKED":
                print(f"  - {rec.test_id}: {rec.error_message}")

    if args.report:
        report.save_json(args.report)
        print(f"\nJSON report written to: {args.report}")

    # Return code: 0 if all tests passed and total > 0, 1 otherwise
    if report.failed > 0 or report.blocked > 0:
        return 1
    if report.total == 0:
        print("Warning: Zero tests executed.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
