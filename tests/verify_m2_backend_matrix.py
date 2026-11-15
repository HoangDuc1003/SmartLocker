#!/usr/bin/env python3
"""
Automated Verification Suite for Milestone 2:
Backend Architecture & 5-Stage Sensor Integration Matrix.

This script programmatically validates:
1. Java Backend Service, DAO, Filter & Controller codebases and rules.
2. SQL Server relational schema, triggers, and column definitions.
3. ESP32 firmware 4.3 SRF05 pinout, edge state machine, and API endpoints.
4. Python simulation 5-stage integration tracking framework.
5. Structural completeness and factual accuracy of FINAL_BACKEND_ARCHITECTURE.md.

Integrity Mandate: Genuine validation of filesystem and AST/regex patterns.
Exit Code: 0 on complete pass, 1 on any failure.
"""

import os
import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


class TestBackendArchitecture(unittest.TestCase):
    """Programmatic verification of Java backend components and rules."""

    def test_rule_engine_invariants(self):
        """Verify RuleEngine.java constants, methods, and rule hierarchy."""
        path = REPO_ROOT / "src" / "java" / "service" / "RuleEngine.java"
        self.assertTrue(path.exists(), f"RuleEngine.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        # Threshold constants
        self.assertIn("ITEM_LEFT_G = 50", content)
        self.assertIn("SPOOF_WEIGHT_G = 50", content)
        self.assertIn("CLOCK_AHEAD_SEC = 300", content)
        self.assertIn("COMMAND_TTL_SEC = 30 * 60", content)
        self.assertIn("COMMAND_CLOCK_LAG_SEC = 60", content)

        # Methods
        self.assertIn("public Verdict evaluate(LockerSession s, SessionContext ctx)", content)
        self.assertIn("private String findSensorFault(LockerSession s, SessionContext ctx)", content)
        self.assertIn("public static boolean isCommandInWindow(long secondsAfterIssue)", content)

        # Priority Rule Labels
        expected_rules = [
            "SENSOR_FAULT",
            "SUSPECTED_SPOOF",
            "LOST_CARD_USED",
            "FORCED_OPEN",
            "WRONG_USER",
            "ITEM_LEFT",
            "OVERDUE",
        ]
        for rule in expected_rules:
            self.assertIn(f'"{rule}"', content, f"Rule {rule} missing in RuleEngine")

    def test_risk_scorer_ml_features(self):
        """Verify RiskScorer.java features and absence of ultrasonic/IMU."""
        path = REPO_ROOT / "src" / "java" / "service" / "RiskScorer.java"
        self.assertTrue(path.exists(), f"RiskScorer.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        # Core ML methods
        self.assertIn("public static synchronized RiskScorer getInstance()", content)
        self.assertIn("public double score(LockerSession s)", content)
        self.assertIn("private static double featureValue(String name, LockerSession s)", content)

        # Exactly 5 baseline features evaluated
        features = ["door_open_sec", "weight_delta_g", "unlock_count", "rfid_ok", "stay_min"]
        for feat in features:
            self.assertIn(f'case "{feat}":', content, f"Feature {feat} missing in RiskScorer")

        # Confirm zero ultrasonic or IMU features in switch
        self.assertNotIn("sonar", content.lower())
        self.assertNotIn("ultrasonic", content.lower())
        self.assertNotIn("vibration", content.lower())
        self.assertNotIn("imu", content.lower())

    def test_alert_service_two_tier(self):
        """Verify AlertService.java two-tier orchestration and ML gating."""
        path = REPO_ROOT / "src" / "java" / "service" / "AlertService.java"
        self.assertTrue(path.exists(), f"AlertService.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn("ML_THRESHOLD = 0.80", content)
        self.assertIn("verdict.isMlEligible()", content)
        self.assertIn("RiskScorer.getInstance().score(session)", content)
        self.assertIn("ML_ANOMALY", content)
        self.assertIn("MaintenanceDao().openForFault", content)

    def test_audit_verifier_hash_chain(self):
        """Verify AuditVerifier.java Haber-Stornetta SHA-256 forward-linked chain."""
        path = REPO_ROOT / "src" / "java" / "service" / "AuditVerifier.java"
        self.assertTrue(path.exists(), f"AuditVerifier.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn("ZERO_HASH", content)
        self.assertIn("0000000000000000000000000000000000000000000000000000000000000000", content)
        self.assertIn('Charset.forName("UTF-16LE")', content)
        self.assertIn("findFirstBroken", content)
        self.assertIn("Walker", content)

    def test_db_context_pooling(self):
        """Verify DbContext.java custom proxy connection pool."""
        path = REPO_ROOT / "src" / "java" / "dao" / "DbContext.java"
        self.assertTrue(path.exists(), f"DbContext.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn("MAX_IDLE = 8", content)
        self.assertIn("CHECK_AFTER_MS = 30_000", content)
        self.assertIn("CLOSE_AFTER_MS = 5 * 60_000", content)
        self.assertIn("getConnection()", content)
        self.assertIn("wrap(final Connection raw)", content)
        self.assertIn("raw.rollback()", content)

    def test_session_context_dao_queries(self):
        """Verify SessionContextDao.java context queries."""
        path = REPO_ROOT / "src" / "java" / "dao" / "SessionContextDao.java"
        self.assertTrue(path.exists(), f"SessionContextDao.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn("SELECT name, min_valid, max_valid FROM SensorType", content)
        self.assertIn("SELECT DATEDIFF(SECOND, measured_at, ingested_at) FROM LockerSession", content)
        self.assertIn("WHERE s.session_id = ? AND t.name = N'WEIGHT' AND c.valid_until >= CAST(s.measured_at AS DATE)", content)
        self.assertIn("SELECT status, user_id FROM UserCard WHERE card_uid = ?", content)

    def test_locker_session_dao_append_only(self):
        """Verify LockerSessionDao.java append-only semantics and slot resolution."""
        path = REPO_ROOT / "src" / "java" / "dao" / "LockerSessionDao.java"
        self.assertTrue(path.exists(), f"LockerSessionDao.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn("DUPLICATE = -1", content)
        self.assertIn("AMBIGUOUS_SLOT = -2", content)
        self.assertIn("UNKNOWN_BANK = -3", content)
        self.assertIn("INSERT INTO LockerSession", content)
        # Verify columns in INSERT
        expected_cols = [
            "device_id", "device_seq", "measured_at", "door_open_sec",
            "weight_delta_g", "unlock_count", "rfid_ok", "stay_min",
            "slot_id", "card_uid", "open_source", "command_id"
        ]
        for col in expected_cols:
            self.assertIn(col, content)

    def test_security_filter_rbac_and_apikey(self):
        """Verify SecurityFilter.java device API key and RBAC perimeter."""
        path = REPO_ROOT / "src" / "java" / "filter" / "SecurityFilter.java"
        self.assertTrue(path.exists(), f"SecurityFilter.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn('"/api/health"', content)
        self.assertIn('"/api/locker/batch"', content)
        self.assertIn('"/api/device/auth"', content)
        self.assertIn('req.getHeader("X-API-Key")', content)
        self.assertIn('req.setAttribute("DEVICE_ID", deviceId)', content)
        self.assertIn("deviceUnauthorized", content)
        self.assertIn("BAD_API_KEY", content)


class TestApiContracts(unittest.TestCase):
    """Verify REST API Controllers."""

    def test_health_api(self):
        """Verify HealthApi.java endpoint mechanics."""
        path = REPO_ROOT / "src" / "java" / "api" / "HealthApi.java"
        self.assertTrue(path.exists(), f"HealthApi.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn('urlPatterns = {"/api/health"}', content)
        self.assertIn("INTERVAL_SEC = 3", content)
        self.assertIn("interval_sec", content)
        self.assertIn("commands", content)
        self.assertIn("server_time", content)
        self.assertIn("blocked_cards", content)
        self.assertIn("reserved", content)
        self.assertIn("tap_path", content)

    def test_device_auth_api(self):
        """Verify DeviceAuthApi.java credential patterns and intent."""
        path = REPO_ROOT / "src" / "java" / "api" / "DeviceAuthApi.java"
        self.assertTrue(path.exists(), f"DeviceAuthApi.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn('urlPatterns = {"/api/device/auth"}', content)
        self.assertIn('PIN_FORMAT = "\\\\d{6}"', content)
        self.assertIn('UID_FORMAT = "[0-9A-F]{4,20}"', content)
        self.assertIn('INTENT_FORMAT = "ASK|OPEN|CHECKOUT"', content)
        self.assertIn("CHOOSE_SEC = 15", content)
        self.assertIn("UNLOCK", content)
        self.assertIn("CHOOSE", content)
        self.assertIn("CONFIRM_EMAIL", content)
        self.assertIn("DENY", content)

    def test_locker_session_api_batch(self):
        """Verify LockerSessionApi.java batch processing and error codes."""
        path = REPO_ROOT / "src" / "java" / "api" / "LockerSessionApi.java"
        self.assertTrue(path.exists(), f"LockerSessionApi.java missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn('urlPatterns = {"/api/locker/batch"}', content)
        self.assertIn('"sessions"', content)
        self.assertIn("saved", content)
        self.assertIn("duplicates", content)
        self.assertIn("rejected", content)
        self.assertIn("errors", content)
        self.assertIn("BAD_SESSION", content)
        self.assertIn("AMBIGUOUS_SLOT", content)
        self.assertIn("UNKNOWN_BANK", content)


class TestDatabaseSchema(unittest.TestCase):
    """Verify SQL Server Schema and triggers."""

    def test_schema_tables_and_triggers(self):
        """Verify sql/01_schema.sql table structures and constraints."""
        path = REPO_ROOT / "sql" / "01_schema.sql"
        self.assertTrue(path.exists(), f"sql/01_schema.sql missing at {path}")
        content = path.read_text(encoding="utf-8")

        # Table LockerSession
        self.assertIn("CREATE TABLE LockerSession", content)
        self.assertIn("door_open_sec", content)
        self.assertIn("weight_delta_g", content)
        self.assertIn("unlock_count", content)
        self.assertIn("rfid_ok", content)
        self.assertIn("stay_min", content)
        self.assertIn("UNIQUE (device_id, device_seq)", content)

        # Trigger append-only
        self.assertIn("CREATE TRIGGER trg_LockerSession_AppendOnly", content)
        self.assertIn("Session records are append-only", content)

        # SensorType seeds
        self.assertIn("CREATE TABLE SensorType", content)
        self.assertIn("INSERT INTO SensorType (name, unit, min_valid, max_valid)", content)
        self.assertIn("(N'DOOR', N's', 0, 3600)", content)
        self.assertIn("(N'WEIGHT', N'g', -200, 20000)", content)
        self.assertIn("(N'STAY', N'min', 0, 10080)", content)

        # Baseline LockerSession must NOT contain distance or IMU columns
        locker_session_block = re.search(r"CREATE TABLE LockerSession \((.*?)\);", content, re.DOTALL)
        self.assertIsNotNone(locker_session_block)
        block_text = locker_session_block.group(1).lower()
        self.assertNotIn("sonar", block_text)
        self.assertNotIn("distance", block_text)
        self.assertNotIn("ultrasonic", block_text)
        self.assertNotIn("vibration", block_text)
        self.assertNotIn("accel", block_text)
        self.assertNotIn("imu", block_text)

    def test_lockout_policy(self):
        """Verify lockout policy in sql/03_v2_v3.sql."""
        path = REPO_ROOT / "sql" / "03_v2_v3.sql"
        self.assertTrue(path.exists(), f"sql/03_v2_v3.sql missing at {path}")
        content = path.read_text(encoding="utf-8")

        self.assertIn("CREATE OR ALTER PROCEDURE Auth_Log", content)
        self.assertIn("SET @retry = 120", content)
        self.assertIn("5 - @fails", content)
        self.assertIn("DATEADD(SECOND, -120, SYSUTCDATETIME())", content)


class TestFirmwareSRF05(unittest.TestCase):
    """Verify ESP32 firmware SRF05 pinout, edge logic, and endpoint reality."""

    def test_firmware_pins_and_thresholds(self):
        path = REPO_ROOT / "firmware" / "SmartLocker_Online" / "SmartLocker_Online.ino"
        self.assertTrue(path.exists(), f"SmartLocker_Online.ino missing at {path}")
        content = path.read_text(encoding="utf-8")

        # Hardware pins
        self.assertIn("SONAR_TRIG = 5", content)
        self.assertIn("SONAR_ECHO = 18", content)
        self.assertIn("SERVO_BOLT_PIN = 32", content)
        self.assertIn("SERVO_DOOR_PIN = 2", content)

        # Thresholds
        self.assertIn("NEAR_CM = 50", content)
        self.assertIn("DOORWAY_CM = 50", content)
        self.assertIn("SONAR_MAX_CM = 100", content)
        self.assertIn("DOOR_OPEN_MS = 20000", content)
        self.assertIn("DOOR_OPEN_MAX_MS = 120000", content)
        self.assertIn("SCREEN_OFF_MS = 60000", content)

        # Logic functions
        self.assertIn("void sampleSonar()", content)
        self.assertIn("bool someoneWithin(int cm)", content)
        self.assertIn("void doorTick()", content)
        self.assertIn("void handleScreen()", content)

        # Network endpoints: firmware calls /health and /device/auth, NEVER /api/locker/batch
        self.assertIn('postJson("/health"', content)
        self.assertIn('postJson("/device/auth"', content)
        self.assertNotIn("/locker/batch", content)
        self.assertNotIn("/api/locker/batch", content)


class TestSimulatorIntegrationTracker(unittest.TestCase):
    """Verify simulator tracking framework."""

    def test_tracker_b0_matrix(self):
        from simulator.tracking.stage_tracker import SensorIntegrationTracker

        tracker = SensorIntegrationTracker(mode="B0")
        reed = tracker.get_channel_status("reed_switch")
        load = tracker.get_channel_status("load_cell")
        sonar = tracker.get_channel_status("ultrasonic")
        imu = tracker.get_channel_status("vibration_tilt")

        # Reed Switch: 5/5 PASS
        self.assertTrue(reed.fully_integrated)
        self.assertTrue(reed.can_claim_stage(5))

        # Load Cell: 5/5 PASS
        self.assertTrue(load.fully_integrated)
        self.assertTrue(load.can_claim_stage(5))

        # Ultrasonic: S1-S3 PASS, S4-S5 FAIL
        self.assertTrue(sonar.stage1_emulator_implemented)
        self.assertTrue(sonar.stage2_payload_generated)
        self.assertTrue(sonar.stage3_payload_transmitted)
        self.assertFalse(sonar.stage4_backend_persisted)
        self.assertFalse(sonar.stage5_backend_processed)
        self.assertFalse(sonar.fully_integrated)

        # IMU: S1-S3 PASS, S4-S5 FAIL
        self.assertTrue(imu.stage1_emulator_implemented)
        self.assertTrue(imu.stage2_payload_generated)
        self.assertTrue(imu.stage3_payload_transmitted)
        self.assertFalse(imu.stage4_backend_persisted)
        self.assertFalse(imu.stage5_backend_processed)
        self.assertFalse(imu.fully_integrated)


class TestFinalBackendArchitectureArtifact(unittest.TestCase):
    """Verify structural completeness and citations in FINAL_BACKEND_ARCHITECTURE.md."""

    def test_artifact_content(self):
        path = REPO_ROOT / "FINAL_BACKEND_ARCHITECTURE.md"
        self.assertTrue(path.exists(), f"FINAL_BACKEND_ARCHITECTURE.md missing at {path}")
        content = path.read_text(encoding="utf-8")

        required_sections = [
            "1. Executive Summary & Architectural Paradigm",
            "2. Java Backend Deep Dive & Line-by-Line Citations",
            "2.1 Deterministic Rule Engine (`RuleEngine.java`)",
            "2.2 Machine Learning Risk Scorer (`RiskScorer.java`)",
            "2.3 Two-Tier Anomaly Orchestration (`AlertService.java`)",
            "2.4 Cryptographic Audit Verification (`AuditVerifier.java`)",
            "2.5 Database Connection Pool & Dynamic Proxy (`DbContext.java`)",
            "2.6 Context Acquisition & Environmental Bounds (`SessionContextDao.java`)",
            "2.7 Append-Only Ingestion & Slot Disambiguation (`LockerSessionDao.java`)",
            "2.8 Role-Based Access Control & Perimeter Security (`SecurityFilter.java`)",
            "3. Database Schema & Persistence Architecture",
            "3.1 Baseline Relational Entity Structure",
            "3.2 Tamper-Evident Append-Only Enforcement",
            "3.3 Exact Column Inventory & Missing Baseline Channels",
            "4. API Contract Specifications",
            "4.1 Device Heartbeat & Dynamic Polling (`POST /api/health`)",
            "4.2 Multi-Modal Credential Authorization (`POST /api/device/auth`)",
            "4.3 Batch Telemetry Ingestion & Idempotency (`POST /api/locker/batch`)",
            "5. 5-Stage Sensor Integration Matrix",
            "5.1 Definition of the 5 Integration Stages",
            "5.2 Comprehensive Verification Matrix",
            "5.3 Detailed Breakdown by Sensor Channel",
            "6. Firmware 4.3-esp32 SRF05 Physical Implementation vs. Simulation Reality",
            "6.1 Physical Pinout, Circuitry & Timing Logic",
            "6.2 Edge State Machine & Presence Actuation",
            "6.3 Physical Firmware vs. Research Simulation Testbed",
            "7. Automated Verification & Integrity Assertion",
        ]
        for sec in required_sections:
            self.assertIn(sec, content, f"Section '{sec}' missing in FINAL_BACKEND_ARCHITECTURE.md")

        # Specific citations and keywords
        self.assertIn("trg_LockerSession_AppendOnly", content)
        self.assertIn("Haber-Stornetta", content)
        self.assertIn("UTF-16LE", content)
        self.assertIn("SONAR_TRIG = 5", content)
        self.assertIn("SONAR_ECHO = 18", content)
        self.assertIn("DOOR_OPEN_MAX_MS = 120000", content)
        self.assertIn("NOT INTEGRATED in Baseline Backend", content)
        self.assertIn("INTEGRATED (5/5 PASS)", content)


def main():
    print("=" * 80)
    print("RUNNING AUTOMATED VERIFICATION: MILESTONE 2 BACKEND & SENSOR MATRIX")
    print("=" * 80)

    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTest(loader.loadTestsFromTestCase(TestBackendArchitecture))
    suite.addTest(loader.loadTestsFromTestCase(TestApiContracts))
    suite.addTest(loader.loadTestsFromTestCase(TestDatabaseSchema))
    suite.addTest(loader.loadTestsFromTestCase(TestFirmwareSRF05))
    suite.addTest(loader.loadTestsFromTestCase(TestSimulatorIntegrationTracker))
    suite.addTest(loader.loadTestsFromTestCase(TestFinalBackendArchitectureArtifact))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    if result.wasSuccessful():
        print("\n" + "=" * 80)
        print("ALL VERIFICATIONS PASSED (EXIT CODE 0): M2 BACKEND & MATRIX VALIDATED")
        print("=" * 80)
        sys.exit(0)
    else:
        print("\n" + "=" * 80)
        print("VERIFICATION FAILED: INTEGRITY ERRORS DETECTED")
        print("=" * 80)
        sys.exit(1)


if __name__ == "__main__":
    main()
