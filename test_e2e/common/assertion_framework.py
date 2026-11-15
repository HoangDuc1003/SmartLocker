"""
Assertion Framework and Test Recording Helpers for SmartLocker E2E Harness.
Supports structured test execution, precise invariant assertion, and report generation.
"""

import os
import re
import time
import json
import unittest
from typing import Any, Callable, Dict, List, Optional
from dataclasses import dataclass, field, asdict
from pathlib import Path


@dataclass
class TestRecord:
    """Record of a single test case execution."""
    test_id: str
    feature_id: int
    tier: int
    name: str
    doc: str
    status: str  # "PASS", "FAIL", "BLOCKED"
    duration_ms: float
    error_message: Optional[str] = None
    stack_trace: Optional[str] = None
    details: Dict[str, Any] = field(default_factory=dict)


@dataclass
class TestReport:
    """Collection of test records and summary statistics."""
    suite_name: str
    timestamp: str
    duration_sec: float
    total: int = 0
    passed: int = 0
    failed: int = 0
    blocked: int = 0
    records: List[TestRecord] = field(default_factory=list)

    def add_record(self, record: TestRecord) -> None:
        self.records.append(record)
        self.total += 1
        if record.status == "PASS":
            self.passed += 1
        elif record.status == "FAIL":
            self.failed += 1
        elif record.status == "BLOCKED":
            self.blocked += 1

    def to_dict(self) -> Dict[str, Any]:
        return {
            "suite_name": self.suite_name,
            "timestamp": self.timestamp,
            "duration_sec": round(self.duration_sec, 3),
            "summary": {
                "total": self.total,
                "passed": self.passed,
                "failed": self.failed,
                "blocked": self.blocked,
                "pass_rate_pct": round((self.passed / self.total * 100) if self.total > 0 else 0.0, 2),
            },
            "records": [asdict(r) for r in self.records],
        }

    def save_json(self, path: str) -> None:
        out_path = Path(path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f, indent=2)


def feature(feature_id: int, name: str = ""):
    """Decorator to attach feature metadata to a test method or class."""
    def decorator(fn_or_cls: Callable) -> Callable:
        setattr(fn_or_cls, "_feature_id", feature_id)
        setattr(fn_or_cls, "_feature_name", name)
        return fn_or_cls
    return decorator


def get_workspace_root() -> Path:
    """Locate the workspace root directory (where src, sql, docs exist)."""
    current = Path(__file__).resolve()
    for parent in [current] + list(current.parents):
        if (parent / "sql").is_dir() and (parent / "src").is_dir():
            return parent
    return Path.cwd()


def assert_true(condition: bool, message: str = "") -> None:
    if not condition:
        raise AssertionError(message or "Expected condition to be True, got False")


def assert_false(condition: bool, message: str = "") -> None:
    if condition:
        raise AssertionError(message or "Expected condition to be False, got True")


def assert_equal(actual: Any, expected: Any, message: str = "") -> None:
    if actual != expected:
        msg = f"Assertion failed: expected {expected!r}, got {actual!r}"
        if message:
            msg = f"{message} - {msg}"
        raise AssertionError(msg)


def assert_in(item: Any, container: Any, message: str = "") -> None:
    if item not in container:
        msg = f"Assertion failed: expected {item!r} to be in {container!r}"
        if message:
            msg = f"{message} - {msg}"
        raise AssertionError(msg)


def assert_matches_regex(pattern: str, text: str, message: str = "") -> None:
    if not re.search(pattern, text):
        msg = f"Assertion failed: text does not match pattern {pattern!r}. Text: {text[:100]!r}"
        if message:
            msg = f"{message} - {msg}"
        raise AssertionError(msg)


def assert_file_exists(path: str | Path, message: str = "") -> None:
    p = Path(path)
    if not p.is_file():
        msg = f"Assertion failed: expected file does not exist: {p}"
        if message:
            msg = f"{message} - {msg}"
        raise AssertionError(msg)


def assert_directory_exists(path: str | Path, message: str = "") -> None:
    p = Path(path)
    if not p.is_dir():
        msg = f"Assertion failed: expected directory does not exist: {p}"
        if message:
            msg = f"{message} - {msg}"
        raise AssertionError(msg)


class E2ETestCase(unittest.TestCase):
    """
    Base test case for SmartLocker E2E tests.
    Provides standard path discovery, assertion helpers, and feature attribution.
    """
    workspace_root: Path = get_workspace_root()
    feature_id: int = 0
    tier: int = 1

    def setUp(self) -> None:
        super().setUp()
        self.start_time = time.time()
        # Derive feature_id from method or class if present
        method = getattr(self, self._testMethodName)
        if hasattr(method, "_feature_id"):
            self.feature_id = getattr(method, "_feature_id")
        elif hasattr(self.__class__, "feature_id"):
            self.feature_id = self.__class__.feature_id

    def get_path(self, *parts: str) -> Path:
        """Resolve a path relative to the SmartLocker repository root."""
        return self.workspace_root.joinpath(*parts)

    def assert_file_present(self, rel_path: str, msg: str = "") -> Path:
        path = self.get_path(rel_path)
        assert_file_exists(path, msg or f"Missing required file: {rel_path}")
        return path

    def assert_dir_present(self, rel_path: str, msg: str = "") -> Path:
        path = self.get_path(rel_path)
        assert_directory_exists(path, msg or f"Missing required directory: {rel_path}")
        return path

    def assert_regex_in_file(self, rel_path: str, pattern: str, msg: str = "") -> str:
        path = self.assert_file_present(rel_path)
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
        assert_matches_regex(pattern, content, msg or f"Pattern {pattern} not found in {rel_path}")
        return content
