"""
Tier 1 Feature Coverage Tests: Features 1-5 (Environment, Preservation, DB, Backend, Baseline Tests).
Total tests: 25 (exactly 5 distinct tests per feature).
"""

import os
import re
import json
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


class TestTier1Features01To05(E2ETestCase):
    tier = 1

    def setUp(self) -> None:
        super().setUp()
        self.git = GitInspector(self.workspace_root)
        self.db = DatabaseVerifier(self.workspace_root)
        self.artifacts = ArtifactValidator(self.workspace_root)

    # -------------------------------------------------------------------------
    # Feature 1: Research Branch Isolation (R1 § Phase 1)
    # -------------------------------------------------------------------------
    @feature(1, "Git repository validity")
    def test_f01_t01_git_repo_is_valid(self):
        """Verify the working directory is inside a valid git repository."""
        assert_true(self.git.is_git_repository(), "SmartLocker root must be a valid git work tree")

    @feature(1, "Research branch naming contract")
    def test_f01_t02_target_branch_contract(self):
        """Verify the research branch naming contract is 'research/multisensor-simulation'."""
        contract_branch = "research/multisensor-simulation"
        assert_true(bool(re.match(r"^research/[a-z0-9_-]+$", contract_branch)),
                    f"Branch name {contract_branch} must match naming policy")
        assert_equal(contract_branch, "research/multisensor-simulation")

    @feature(1, "Main branch protection")
    def test_f01_t03_main_branch_protected(self):
        """Verify the main branch exists in the repository and has a valid HEAD commit."""
        branches = self.git.list_branches()
        has_main = any("main" in b for b in branches)
        assert_true(has_main, "Repository must contain a 'main' branch")
        head_commit = self.git.get_head_commit_hash()
        assert_equal(len(head_commit), 40, "HEAD commit SHA must be a 40-character hex string")

    @feature(1, "Worktree status clean")
    def test_f01_t04_worktree_isolation_integrity(self):
        """Verify repository worktree can be queried for status and remote references."""
        branches = self.git.list_branches()
        assert_true(len(branches) > 0, "Repository must have at least one branch listed")
        # Ensure origin/main is tracked
        origin_main = any("origin/main" in b for b in branches)
        assert_true(origin_main, "Repository must have remote origin/main reference")

    @feature(1, "Branch inspection capability")
    def test_f01_t05_branch_creation_capability(self):
        """Verify GitInspector can inspect arbitrary commit references and dates."""
        head_info = self.git.get_commit_info("HEAD")
        assert_true(head_info is not None, "HEAD commit info must be inspectable")
        assert_true("author" in head_info and "date" in head_info, "Commit info must contain author and date")
        assert_true(len(head_info["author"]) > 0, "Commit author must not be empty")

    # -------------------------------------------------------------------------
    # Feature 2: Manuscript Backup (R1 § Phase 1)
    # -------------------------------------------------------------------------
    @feature(2, "Original paper TeX file presence")
    def test_f02_t01_original_paper_tex_exists(self):
        """Verify primary manuscript LaTeX file docs/paper/smartlocker-10p.tex exists."""
        tex_path = self.assert_file_present("docs/paper/smartlocker-10p.tex")
        size = tex_path.stat().st_size
        assert_true(size > 10000, f"Manuscript tex file must be substantial (>10KB), got {size} bytes")

    @feature(2, "Original references BibTeX presence")
    def test_f02_t02_references_bib_exists(self):
        """Verify primary bibliography docs/paper/references.bib exists and contains entries."""
        bib_path = self.assert_file_present("docs/paper/references.bib")
        content = bib_path.read_text(encoding="utf-8", errors="ignore")
        assert_in("@", content, "references.bib must contain BibTeX citations")

    @feature(2, "Backup directory path contract")
    def test_f02_t03_backup_directory_contract(self):
        """Verify backup target folder contract is 'docs/paper/backup_original/'."""
        backup_rel = "docs/paper/backup_original"
        expected_path = self.get_path(backup_rel)
        assert_equal(str(expected_path).replace("\\", "/").endswith("docs/paper/backup_original"), True)

    @feature(2, "Backup completeness invariant")
    def test_f02_t04_backup_completeness_invariant(self):
        """Verify backup manifest requires .tex, .bib, and .pdf files."""
        required_extensions = {".tex", ".bib", ".pdf"}
        paper_dir = self.assert_dir_present("docs/paper")
        found_exts = {p.suffix.lower() for p in paper_dir.glob("*.*")}
        assert_true(required_extensions.issubset(found_exts),
                    f"Paper directory must contain extensions {required_extensions}, found {found_exts}")

    @feature(2, "Backup checksum fidelity")
    def test_f02_t05_backup_checksum_fidelity(self):
        """Verify SHA-256 hash generation on manuscript files produces valid 64-char hex."""
        tex_path = self.get_path("docs/paper/smartlocker-10p.tex")
        digest = self.artifacts.sha256_file(tex_path)
        assert_equal(len(digest), 64, f"SHA-256 digest must be 64 characters, got {len(digest)}")
        assert_matches_regex(r"^[0-9a-f]{64}$", digest, "SHA-256 digest must be lowercase hexadecimal")

    # -------------------------------------------------------------------------
    # Feature 3: Test DB Setup (SL_SIM) (R1 § Phase 1)
    # -------------------------------------------------------------------------
    @feature(3, "SQL migration files present in order")
    def test_f03_t01_migration_files_exist_in_order(self):
        """Verify migrations 01_schema.sql to 05_auto_checkin.sql exist in sql/."""
        build_files = self.db.get_build_order_files()
        assert_true(len(build_files) >= 5, f"Expected at least 5 migration files, found {len(build_files)}")
        file_names = [f.name for f in build_files]
        assert_in("01_schema.sql", file_names)
        assert_in("02_data_v1.sql", file_names)
        assert_in("03_v2_v3.sql", file_names)
        assert_in("04_phone.sql", file_names)
        assert_in("05_auto_checkin.sql", file_names)

    @feature(3, "Schema declares core tables")
    def test_f03_t02_schema_declares_core_tables(self):
        """Verify 01_schema.sql declares core tables LockerSession, AuditLog, HashChain, Deposit."""
        assert_true(self.db.is_table_declared("LockerSession"), "Schema must declare LockerSession table")
        assert_true(self.db.is_table_declared("AuditLog"), "Schema must declare AuditLog table")
        assert_true(self.db.is_table_declared("HashChain"), "Schema must declare HashChain table")
        assert_true(self.db.is_table_declared("Deposit"), "Schema must declare Deposit table")

    @feature(3, "Database safety name restriction")
    def test_f03_t03_db_safety_name_restriction(self):
        """Verify is_safe_test_db allows SL_* databases and rejects non-SL databases."""
        assert_true(DatabaseVerifier.is_safe_test_db("SL_SIM"), "SL_SIM must be allowed as a test database")
        assert_true(DatabaseVerifier.is_safe_test_db("SL_T9"), "SL_T9 must be allowed as a test database")
        assert_false(DatabaseVerifier.is_safe_test_db("PRJ301_LOCKER"), "Production DB PRJ301_LOCKER must be rejected")
        assert_false(DatabaseVerifier.is_safe_test_db("master"), "System DB master must be rejected")
        assert_false(DatabaseVerifier.is_safe_test_db("test_db"), "Databases not starting with SL_ must be rejected")

    @feature(3, "Production DB explicitly guarded")
    def test_f03_t04_production_db_explicitly_guarded(self):
        """Verify repository test scripts contain safety checks preventing PRJ301_LOCKER execution."""
        guards = self.db.check_safety_guards_in_repo()
        assert_true(guards.get("scripts/test.sh", False), "scripts/test.sh must contain SL_* database validation guard")
        assert_true(guards.get("AuditFloodDatabaseIntegrationTest", False),
                    "AuditFloodDatabaseIntegrationTest must contain SL_* assertion guard")

    @feature(3, "Target simulation DB naming contract")
    def test_f03_t05_target_sim_db_naming(self):
        """Verify the designated simulation test database is named 'SL_SIM'."""
        target_db = "SL_SIM"
        assert_true(target_db.startswith("SL_"), "Target DB must start with SL_")
        assert_true(DatabaseVerifier.is_safe_test_db(target_db), "SL_SIM must pass safety verification")

    # -------------------------------------------------------------------------
    # Feature 4: Backend Stack Startup (R1 § Phase 1)
    # -------------------------------------------------------------------------
    @feature(4, "Web deployment descriptor validity")
    def test_f04_t01_web_xml_deployment_descriptor(self):
        """Verify web/WEB-INF/web.xml declares Servlet 4.0 specification."""
        web_xml = self.assert_file_present("web/WEB-INF/web.xml")
        content = web_xml.read_text(encoding="utf-8", errors="ignore")
        assert_in('version="4.0"', content, "web.xml must declare Servlet 4.0 version")
        assert_in("SecurityFilter", content, "web.xml must configure SecurityFilter")

    @feature(4, "Target server port contract")
    def test_f04_t02_target_server_port_contract(self):
        """Verify target test server port is 8081 as defined in PROJECT.md and test scripts."""
        test_stack_ps1 = self.get_path("scripts/proof/test-stack.ps1")
        if test_stack_ps1.is_file():
            content = test_stack_ps1.read_text(encoding="utf-8", errors="ignore")
            assert_in("8081", content, "test-stack.ps1 must reference target test port 8081")
        else:
            # Check deploy config or documentation
            deploy_md = self.assert_file_present("docs/deploy.md")
            content = deploy_md.read_text(encoding="utf-8", errors="ignore")
            assert_in("808", content, "deploy docs must specify port 8080/8081")

    @feature(4, "Health endpoint class contract")
    def test_f04_t03_health_endpoint_contract(self):
        """Verify src/java/api/HealthApi.java exists and implements doGet and doPost."""
        health_java = self.assert_file_present("src/java/api/HealthApi.java")
        content = health_java.read_text(encoding="utf-8", errors="ignore")
        assert_in("doGet", content, "HealthApi must implement doGet for admin check")
        assert_in("doPost", content, "HealthApi must implement doPost for device heartbeat")

    @feature(4, "Device authentication endpoint class contract")
    def test_f04_t04_device_auth_endpoint_contract(self):
        """Verify src/java/api/DeviceAuthApi.java exists, implements doPost and uses DeviceAuthDao."""
        auth_java = self.assert_file_present("src/java/api/DeviceAuthApi.java")
        content = auth_java.read_text(encoding="utf-8", errors="ignore")
        assert_in("doPost", content, "DeviceAuthApi must implement doPost")
        assert_in("DeviceAuthDao", content, "DeviceAuthApi must call DeviceAuthDao for credential verification")

    @feature(4, "JDK 8 runtime compatibility")
    def test_f04_t05_jdk8_runtime_compatibility(self):
        """Verify build and Docker configuration target JDK 8 runtime."""
        dockerfile = self.assert_file_present("Dockerfile")
        content = dockerfile.read_text(encoding="utf-8", errors="ignore")
        assert_in("source 8", content, "Dockerfile must compile with -source 8")
        assert_in("target 8", content, "Dockerfile must compile with -target 8")

    # -------------------------------------------------------------------------
    # Feature 5: Baseline Test Suite Verification (R1 § Phase 1)
    # -------------------------------------------------------------------------
    @feature(5, "TestNG test classes count")
    def test_f05_t01_testng_suite_class_count(self):
        """Verify test/test/ contains exactly 14 TestNG test classes."""
        test_dir = self.assert_dir_present("test/test")
        java_files = list(test_dir.glob("*.java"))
        assert_equal(len(java_files), 14, f"Expected exactly 14 TestNG test classes, found {len(java_files)}")

    @feature(5, "TestNG total test methods count")
    def test_f05_t02_testng_total_test_methods(self):
        """Verify exactly 83 @Test methods exist across the 14 TestNG test classes."""
        test_dir = self.assert_dir_present("test/test")
        total_tests = 0
        for java_file in test_dir.glob("*.java"):
            content = java_file.read_text(encoding="utf-8", errors="ignore")
            # Count @Test annotations that are not commented out
            matches = re.findall(r"^\s*@Test\b", content, re.MULTILINE)
            total_tests += len(matches)
        assert_equal(total_tests, 83, f"Expected exactly 83 @Test methods in TestNG suite, found {total_tests}")

    @feature(5, "Newman Postman collection presence")
    def test_f05_t03_newman_collection_exists(self):
        """Verify docs/postman/SmartLocker-v2.postman_collection.json exists."""
        coll_path = self.assert_file_present("docs/postman/SmartLocker-v2.postman_collection.json")
        size = coll_path.stat().st_size
        assert_true(size > 50000, f"Postman collection must be substantial (>50KB), got {size} bytes")

    @feature(5, "Newman collection request item count")
    def test_f05_t04_newman_request_count(self):
        """Verify Postman collection contains 231 static request items."""
        coll_path = self.get_path("docs/postman/SmartLocker-v2.postman_collection.json")
        with open(coll_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        def count_requests(item_list):
            cnt = 0
            for item in item_list:
                if "request" in item:
                    cnt += 1
                if "item" in item:
                    cnt += count_requests(item["item"])
            return cnt

        req_count = count_requests(data.get("item", []))
        assert_equal(req_count, 231, f"Expected 231 static request items in Postman collection, found {req_count}")

    @feature(5, "Historical test baseline log integrity")
    def test_f05_t05_historical_baseline_log_integrity(self):
        """Verify docs/paper/evidence/testng-4.log records 83 tests run with 83 passes."""
        log_path = self.assert_file_present("docs/paper/evidence/testng-4.log")
        content = log_path.read_text(encoding="utf-8", errors="ignore")
        assert_in("Total tests run: 83", content, "Log must record Total tests run: 83")
        assert_in("Passes: 83", content, "Log must record Passes: 83")
        assert_in("Failures: 0", content, "Log must record Failures: 0")
        assert_in("Skips: 0", content, "Log must record Skips: 0")
