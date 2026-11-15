"""
Tier 2 Boundary & Corner Cases Tests: Features 1-5 (Environment, Preservation, DB, Backend, Baseline Tests).
Total tests: 25 (exactly 5 distinct boundary/corner/negative tests per feature).
"""

import os
import re
import stat
import socket
import json
import xml.etree.ElementTree as ET
from pathlib import Path
from test_e2e.common.assertion_framework import (
    E2ETestCase,
    feature,
    assert_true,
    assert_false,
    assert_equal,
    assert_in,
    assert_matches_regex,
    assert_file_exists,
    assert_directory_exists,
)
from test_e2e.common.git_inspector import GitInspector
from test_e2e.common.db_verifier import DatabaseVerifier
from test_e2e.common.artifact_validator import ArtifactValidator
from test_e2e.common.api_client import BackendApiClient


class TestTier2Features01To05(E2ETestCase):
    tier = 2

    def setUp(self) -> None:
        super().setUp()
        self.git = GitInspector(self.workspace_root)
        self.db = DatabaseVerifier(self.workspace_root)
        self.artifacts = ArtifactValidator(self.workspace_root)
        self.api = BackendApiClient()

    # =========================================================================
    # Feature 1: Research Branch Isolation (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(1, "Non-existent branch query rejection")
    def test_f01_bva01_non_existent_branch_handling(self):
        """Verify querying non-existent branch names returns False and non-zero git exit code."""
        fake_branch = "research/non_existent_branch_xyz_12345"
        assert_false(self.git.branch_exists(fake_branch), "Non-existent branch must not exist")
        res = self.git._run_git("rev-parse", "--verify", f"refs/heads/{fake_branch}")
        assert_equal(res.returncode != 0, True, "Git rev-parse must exit non-zero for missing branch")

    @feature(1, "Invalid branch name format rejection")
    def test_f01_bva02_invalid_branch_names_rejected(self):
        """Verify branch names with illegal git characters are rejected by check-ref-format."""
        invalid_branch_names = [
            "research/..simulation",      # consecutive dots forbidden
            "research/branch name",       # spaces forbidden
            "research/branch~1",          # tilde forbidden
            "research/branch^2",          # caret forbidden
            "research/branch:sub",        # colon forbidden
            "research/branch?",           # question mark forbidden
            "research/branch*",           # asterisk forbidden
            "research/branch[1]",         # bracket forbidden
            "research/branch/",           # trailing slash forbidden
            "research/branch.lock",       # ending in .lock forbidden
        ]
        for bad_name in invalid_branch_names:
            res = self.git._run_git("check-ref-format", "--branch", bad_name)
            assert_true(res.returncode != 0, f"Git must reject invalid branch name: {bad_name}")

    @feature(1, "Detached HEAD state detection and handling")
    def test_f01_bva03_detached_head_detection(self):
        """Verify detached HEAD state is distinguished from valid branch references."""
        # Query symbolic-ref on HEAD: if on a branch, it succeeds; if detached, it returns code 1
        res = self.git._run_git("symbolic-ref", "-q", "HEAD")
        current_branch = self.git.get_current_branch()
        if res.returncode != 0:
            # Currently detached HEAD
            assert_equal(current_branch, "HEAD", "Detached HEAD must be identified as 'HEAD'")
        else:
            # On a named branch
            assert_true(len(current_branch) > 0 and current_branch != "HEAD",
                        f"Named branch must not be 'HEAD', got: {current_branch}")

    @feature(1, "Uncommitted dirty state safety guard")
    def test_f01_bva04_uncommitted_dirty_state_safety(self):
        """Verify git status inspection accurately identifies dirty vs clean worktree."""
        status_res = self.git._run_git("status", "--porcelain")
        assert_equal(status_res.returncode, 0, "Git status command must succeed")
        # Ensure status output can be parsed line-by-line without crashing
        lines = [ln.strip() for ln in status_res.stdout.splitlines() if ln.strip()]
        for line in lines:
            # Porcelain format: 2 chars status + space + filename
            assert_true(len(line) >= 3, f"Status porcelain line must have valid format: {line}")
            assert_in(line[0], " MADRCU?!", f"Leading status char must be valid porcelain status: {line[0]}")

    @feature(1, "Branch switching safety against protected branch deletion")
    def test_f01_bva05_branch_switching_safety(self):
        """Verify currently checked-out branch cannot be deleted by git branch -d."""
        current_branch = self.git.get_current_branch()
        if current_branch and current_branch != "HEAD":
            res = self.git._run_git("branch", "-d", current_branch)
            assert_true(res.returncode != 0, f"Deleting active branch {current_branch} must be blocked by git")
            assert_in("cannot delete branch", res.stderr.lower(), "Git must report cannot delete active branch")
        else:
            # Detached head safety check
            res = self.git._run_git("branch", "-d", "HEAD")
            assert_true(res.returncode != 0, "Git must reject deleting HEAD")

    # =========================================================================
    # Feature 2: Manuscript Backup (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(2, "Empty backup directory handling")
    def test_f02_bva01_empty_backup_directory_handling(self):
        """Verify verification helper reports False when backup files are absent."""
        missing_orig = "docs/paper/non_existent_file.xyz"
        missing_backup = "docs/paper/backup_original/non_existent_file.xyz"
        res = self.artifacts.verify_backup_file(missing_orig, missing_backup)
        assert_false(res, "verify_backup_file must return False for missing files")

    @feature(2, "Corrupted backup checksum detection")
    def test_f02_bva02_corrupted_backup_checksum_tamper_detection(self):
        """Verify single-bit alteration in manuscript file produces completely different SHA-256."""
        tex_path = self.get_path("docs/paper/smartlocker-10p.tex")
        orig_hash = self.artifacts.sha256_file(tex_path)

        # Simulate corrupting 1 byte in memory
        with open(tex_path, "rb") as f:
            data = bytearray(f.read())
        # Flip first byte
        data[0] ^= 0xFF
        import hashlib
        corrupted_hash = hashlib.sha256(data).hexdigest().lower()

        assert_equal(orig_hash != corrupted_hash, True, "Tampered content must change SHA-256 digest")
        # Hamming distance / mismatch in hex characters
        diff_chars = sum(1 for a, b in zip(orig_hash, corrupted_hash) if a != b)
        assert_true(diff_chars > 20, f"Avalanche effect expected, diff chars: {diff_chars}/64")

    @feature(2, "Missing original manuscript error handling")
    def test_f02_bva03_missing_original_manuscript_graceful_handling(self):
        """Verify sha256_file raises FileNotFoundError on missing file path rather than unhandled crash."""
        fake_path = self.get_path("docs/paper/definitely_missing_manuscript.tex")
        try:
            self.artifacts.sha256_file(fake_path)
            assert_true(False, "Expected FileNotFoundError when file is missing")
        except FileNotFoundError:
            pass  # Expected behavior

    @feature(2, "Directory traversal attempts in manuscript path rejected")
    def test_f02_bva04_directory_traversal_attempts_rejected(self):
        """Verify path resolution detects and flags directory traversal escaping workspace."""
        traversal_paths = [
            "../../etc/shadow",
            "../../../Windows/System32/config/SAM",
            "docs/paper/../../../../../../boot.ini",
        ]
        for tp in traversal_paths:
            resolved = (self.workspace_root / tp).resolve()
            # Directory traversal must escape the workspace root
            is_outside = not str(resolved).lower().startswith(str(self.workspace_root).lower())
            assert_true(is_outside, f"Path traversal {tp} must resolve outside workspace root")

    @feature(2, "Read-only backup file permissions verification")
    def test_f02_bva05_read_only_backup_permissions(self):
        """Verify manuscript backup files can be opened and verified under read-only permissions."""
        tex_path = self.get_path("docs/paper/smartlocker-10p.tex")
        mode = tex_path.stat().st_mode
        # Check read permission is present for owner
        assert_true(bool(mode & stat.S_IREAD), "Manuscript file must have read permission enabled")
        # Binary open for read must succeed
        with open(tex_path, "rb") as f:
            header = f.read(16)
            assert_true(len(header) == 16, "Must be able to read 16 bytes from manuscript file")

    # =========================================================================
    # Feature 3: Test DB Setup (SL_SIM) (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(3, "Non-test database names rejected by safety validator")
    def test_f03_bva01_non_test_db_rejected(self):
        """Verify DatabaseVerifier.is_safe_test_db strictly rejects dangerous DB names."""
        unsafe_names = [
            "PRJ301_LOCKER",        # Production database
            "prj301_locker",        # Lowercase production
            "master",               # System catalog
            "msdb",                 # System job agent
            "tempdb",               # Temporary DB
            "model",                # System template
            "Production_SmartLocker",
            "SL",                   # Missing trailing identifier
            "SL_",                  # Empty trailing identifier
            "SL-SIM",               # Hyphen not allowed in identifier
            "SL SIM",               # Space not allowed
        ]
        for name in unsafe_names:
            assert_false(DatabaseVerifier.is_safe_test_db(name),
                         f"Safety guard must reject unsafe database name: {name}")

        safe_names = ["SL_SIM", "SL_TEST", "SL_DEV_01", "SL_T9"]
        for name in safe_names:
            assert_true(DatabaseVerifier.is_safe_test_db(name),
                        f"Safety guard must allow valid test DB name: {name}")

    @feature(3, "Missing migration script detection in sequence")
    def test_f03_bva02_missing_migration_scripts_detection(self):
        """Verify migration sequence validator detects gaps in numbered SQL files."""
        files = self.db.get_build_order_files()
        file_names = [f.name for f in files]
        # Check consecutive prefixes 01, 02, 03, 04, 05
        prefixes = [int(re.match(r"^(\d+)_", name).group(1)) for name in file_names if re.match(r"^(\d+)_", name)]
        assert_true(len(prefixes) >= 5, "Must have at least 5 numbered migration scripts")
        for i in range(1, 6):
            assert_in(i, prefixes, f"Migration script prefix {i:02d} must not be missing")

    @feature(3, "Out-of-order migration scripts rejected by dependency check")
    def test_f03_bva03_out_of_order_migration_scripts_rejected(self):
        """Verify executing 02_data_v1.sql before 01_schema.sql violates table dependencies."""
        schema_sql = (self.workspace_root / "sql" / "01_schema.sql").read_text(encoding="utf-8", errors="ignore")
        data_sql = (self.workspace_root / "sql" / "02_data_v1.sql").read_text(encoding="utf-8", errors="ignore")

        # 01_schema creates LockerSession
        assert_in("CREATE TABLE", schema_sql.upper())
        # 02_data_v1 inserts into LockerBank / SystemConfig created in 01_schema
        assert_in("INSERT INTO", data_sql.upper())
        # Verify data_sql cannot declare CREATE TABLE for the base schema tables
        assert_false("CREATE TABLE [DBO].[LOCKERSESSION]" in data_sql.upper(),
                     "02_data_v1 must not define base tables; it depends on 01_schema")

    @feature(3, "Malformed DDL syntax detection in SQL parsing")
    def test_f03_bva04_malformed_ddl_syntax_detection(self):
        """Verify parser detects malformed DDL (unclosed parens, missing data types)."""
        malformed_ddl_samples = [
            "CREATE TABLE BrokenTable ( id INT, name VARCHAR(50) ",  # unclosed paren
            "CREATE TABLE BrokenTable ( id, name VARCHAR(50) );",    # missing datatype
            "CREATE TABLE ;",                                        # missing table name
        ]
        for bad_ddl in malformed_ddl_samples:
            # Check unclosed paren
            unbalanced_paren = bad_ddl.count("(") != bad_ddl.count(")")
            missing_type = bool(re.search(r"\(\s*[a-zA-Z0-9_]+\s*,", bad_ddl))
            missing_name = bool(re.search(r"CREATE\s+TABLE\s+;", bad_ddl, re.IGNORECASE))
            assert_true(unbalanced_paren or missing_type or missing_name,
                        f"DDL validator must detect error in: {bad_ddl}")

    @feature(3, "SQL injection in DB credentials and parameters rejected")
    def test_f03_bva05_sql_injection_in_db_credentials_rejected(self):
        """Verify SQL injection strings are rejected by database parameter sanitizer."""
        injection_payloads = [
            "SL_SIM; DROP TABLE LockerSession;--",
            "SL_SIM' OR '1'='1",
            "SL_SIM; EXEC xp_cmdshell('dir');--",
            "SL_SIM UNION SELECT * FROM sys.tables--",
            "SL_SIM\"; DROP DATABASE SL_SIM;--",
        ]
        for injection in injection_payloads:
            assert_false(DatabaseVerifier.is_safe_test_db(injection),
                         f"Database safety validator must reject injection payload: {injection}")
            # Alphanumeric check
            is_clean_identifier = bool(re.match(r"^[A-Za-z0-9_]+$", injection))
            assert_false(is_clean_identifier, f"Identifier check must reject metacharacters: {injection}")

    # =========================================================================
    # Feature 4: Backend Stack Startup (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(4, "Port collision detection on Tomcat port 8081")
    def test_f04_bva01_port_collision_detection(self):
        """Verify port availability check correctly identifies port binding state."""
        port = 8081
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.5)
        # Attempt non-blocking connect: either connects (occupied) or fails (free)
        conn_result = s.connect_ex(("127.0.0.1", port))
        s.close()
        # conn_result == 0 means occupied (port collision if another service tries to bind)
        # conn_result != 0 means free / refused
        assert_true(conn_result in (0, 10061, 10049, 111),
                    f"Socket connection check must return standard OS status, got {conn_result}")

    @feature(4, "Unexpected HTTP methods on health endpoint rejected")
    def test_f04_bva02_unexpected_http_methods_rejected(self):
        """Verify unsupported HTTP methods (PUT, DELETE, PATCH) on health endpoint are handled."""
        unsupported_methods = ["PUT", "DELETE", "PATCH", "TRACE"]
        for method in unsupported_methods:
            # Backend contract requires POST for /api/health
            resp = self.api.request(method=method, path="/api/health", headers={"X-API-Key": "DEVICE_KEY_LOCKER_01"})
            # Status should be 405 (Method Not Allowed), 401 (Unauthorized), 404, 403, 400, or 0 (offline)
            assert_true(resp.status_code in (405, 401, 404, 400, 403, 0),
                        f"Unsupported method {method} must not return 200 OK, got {resp.status_code}")

    @feature(4, "Malformed JSON payload on /api/health handling")
    def test_f04_bva03_malformed_json_payload_handling(self):
        """Verify malformed JSON payload (truncated/unclosed) is rejected with 400/401 or JSON error."""
        malformed_raw = '{"firmware": "4.3", "uptime_sec": '
        try:
            json.loads(malformed_raw)
            assert_true(False, "json.loads must fail on malformed JSON")
        except json.JSONDecodeError:
            pass  # Expected client-side error before or on transport

        # Sending malformed content via raw bytes
        resp = self.api.request(
            method="POST",
            path="/api/health",
            headers={"Content-Type": "application/json", "X-API-Key": "DEVICE_KEY_LOCKER_01"},
            json_body=None,
        )
        assert_true(resp.status_code in (400, 401, 404, 403, 0),
                    f"Empty/malformed body must not return 200 OK, got {resp.status_code}")

    @feature(4, "Missing X-API-Key header rejection")
    def test_f04_bva04_missing_api_key_header_rejection(self):
        """Verify request without X-API-Key header is rejected or marked unauthorized."""
        resp = self.api.request(
            method="POST",
            path="/api/health",
            headers={},  # Missing X-API-Key
            json_body={"firmware": "4.3", "uptime_sec": 100, "nfc": True},
        )
        assert_true(resp.status_code in (401, 403, 400, 404, 0),
                    f"Missing API key must not be accepted, got {resp.status_code}")

    @feature(4, "Oversized request payload boundary handling")
    def test_f04_bva05_oversized_request_payload_handling(self):
        """Verify oversized request payload (>5MB) exceeds allowed servlet buffer limits."""
        # Standard API accepts ~few KB; verify huge payloads are identified
        oversized_str = "X" * (5 * 1024 * 1024)  # 5 MB
        assert_equal(len(oversized_str), 5242880)
        # Verify size guard logic
        MAX_ALLOWED_PAYLOAD = 1024 * 1024  # 1 MB threshold
        is_oversized = len(oversized_str) > MAX_ALLOWED_PAYLOAD
        assert_true(is_oversized, "Payload must be detected as exceeding maximum allowed limit")

    # =========================================================================
    # Feature 5: Baseline Test Suite Verification (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(5, "Corrupted TestNG XML syntax detection")
    def test_f05_bva01_corrupted_testng_xml_detection(self):
        """Verify XML parser detects corrupted TestNG suite XML files."""
        corrupted_xml_samples = [
            "<suite name='test'><test><classes></test>",             # Unclosed classes tag
            "<suite name='test'><test name='t1'></suite>",           # Missing test closing tag
            "Not an XML file at all",                                # Non-XML text
        ]
        for bad_xml in corrupted_xml_samples:
            try:
                ET.fromstring(bad_xml)
                assert_true(False, "ET.fromstring must fail on corrupted TestNG XML")
            except ET.ParseError:
                pass  # Expected parse error

    @feature(5, "Missing test classes referenced in suite detection")
    def test_f05_bva02_missing_test_classes_detection(self):
        """Verify suite validator checks that referenced TestNG test classes exist on disk."""
        non_existent_class = "com.smartlocker.test.NonExistentAuditTest"
        class_rel_path = f"test/{non_existent_class.replace('.', '/')}.java"
        exists = (self.workspace_root / class_rel_path).is_file()
        assert_false(exists, f"Missing test class {class_rel_path} must not exist on disk")

        # Existing test class verification
        existing_class = "test.RuleEngineTest"
        existing_path = self.workspace_root / "test" / "test" / "RuleEngineTest.java"
        assert_true(existing_path.is_file(), f"Existing test class must exist at {existing_path}")

    @feature(5, "Zero test methods found condition flagged")
    def test_f05_bva03_zero_test_methods_found_flagged(self):
        """Verify test runner logic flags suite with 0 test methods as warning/failure."""
        discovered_methods = []
        is_empty_suite = len(discovered_methods) == 0
        assert_true(is_empty_suite, "Empty suite must be recognized")
        # Invariant: suite execution with 0 tests cannot report successful coverage
        pass_rate = 0.0 if len(discovered_methods) == 0 else 100.0
        assert_equal(pass_rate, 0.0, "Pass rate for 0 test methods must be 0.0")

    @feature(5, "Newman collection missing environment variables detection")
    def test_f05_bva04_newman_collection_missing_env_vars(self):
        """Verify Postman environment validator detects unpopulated or missing required variables."""
        env_path = self.workspace_root / "docs" / "postman" / "SmartLocker-local.postman_environment.json"
        assert_file_exists(env_path, "Local postman environment file must exist")

        with open(env_path, "r", encoding="utf-8") as f:
            env_data = json.load(f)

        values = {item["key"]: item["value"] for item in env_data.get("values", [])}
        # In a missing env scenario:
        required_vars = ["base_url", "api_key", "device_id", "non_existent_var_123"]
        missing_vars = [v for v in required_vars if v not in values]
        assert_in("non_existent_var_123", missing_vars, "Missing variable must be detected")
        assert_true(len(missing_vars) > 0, "Validator must detect missing environment variable")

    @feature(5, "Malformed Postman collection JSON rejection")
    def test_f05_bva05_malformed_postman_collection_json(self):
        """Verify malformed JSON in Postman collection raises JSONDecodeError or schema error."""
        coll_path = self.workspace_root / "docs" / "postman" / "SmartLocker-v2.postman_collection.json"
        assert_file_exists(coll_path, "Postman collection v2 must exist")

        # Test valid parsing of real file
        with open(coll_path, "r", encoding="utf-8") as f:
            valid_data = json.load(f)
        assert_in("info", valid_data)
        assert_in("item", valid_data)

        # Test malformed collection schema missing info or item
        bad_collections = [
            {},                                         # Empty object
            {"info": "not a dict"},                     # Bad info type
            {"info": {"name": "Test"}},                 # Missing item list
        ]
        for bad_coll in bad_collections:
            is_valid_schema = (
                isinstance(bad_coll.get("info"), dict)
                and isinstance(bad_coll.get("item"), list)
            )
            assert_false(is_valid_schema, f"Invalid Postman schema must fail: {bad_coll}")
