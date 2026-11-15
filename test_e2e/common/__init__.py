"""
SmartLocker E2E Test Suite - Common Infrastructure Utilities.
Provides reusable opaque-box testing tools, assertions, API client,
DB verifier, Git inspector, and artifact validators.
"""

from .assertion_framework import (
    E2ETestCase,
    TestRecord,
    TestReport,
    feature,
    assert_true,
    assert_false,
    assert_equal,
    assert_in,
    assert_matches_regex,
    assert_file_exists,
    assert_directory_exists,
)
from .api_client import BackendApiClient
from .db_verifier import DatabaseVerifier
from .git_inspector import GitInspector
from .artifact_validator import ArtifactValidator

__all__ = [
    "E2ETestCase",
    "TestRecord",
    "TestReport",
    "feature",
    "assert_true",
    "assert_false",
    "assert_equal",
    "assert_in",
    "assert_matches_regex",
    "assert_file_exists",
    "assert_directory_exists",
    "BackendApiClient",
    "DatabaseVerifier",
    "GitInspector",
    "ArtifactValidator",
]
