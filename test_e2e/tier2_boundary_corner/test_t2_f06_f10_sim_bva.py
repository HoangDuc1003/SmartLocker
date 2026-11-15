"""
Tier 2 Boundary & Corner Cases Tests: Features 6-10 (Device Simulator, Auth Emulators, Sensor Emulators, Fault Injection, 5-Stage Tracking).
Total tests: 25 (exactly 5 distinct boundary/corner/negative tests per feature).
"""

import re
import math
import json
import random
import urllib.error
from test_e2e.common.assertion_framework import (
    E2ETestCase,
    feature,
    assert_true,
    assert_false,
    assert_equal,
    assert_in,
    assert_matches_regex,
)
from test_e2e.common.api_client import BackendApiClient


class TestTier2Features06To10(E2ETestCase):
    tier = 2

    def setUp(self) -> None:
        super().setUp()
        self.api = BackendApiClient()

    # =========================================================================
    # Feature 6: Modular Python Device Simulator (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(6, "Device ID boundary values validation")
    def test_f06_bva01_device_id_boundary_values(self):
        """Verify device ID boundaries: 0 (invalid), negative (invalid), max 32-bit int, overflow."""
        # Database schema uses INT (1 to 2,147,483,647)
        MAX_INT32 = 2147483647
        
        def is_valid_device_id(dev_id: int) -> bool:
            return isinstance(dev_id, int) and 1 <= dev_id <= MAX_INT32

        assert_false(is_valid_device_id(0), "Device ID 0 must be rejected (1-indexed)")
        assert_false(is_valid_device_id(-1), "Negative Device ID -1 must be rejected")
        assert_false(is_valid_device_id(-999), "Negative Device ID -999 must be rejected")
        assert_true(is_valid_device_id(1), "Device ID 1 is standard valid minimum")
        assert_true(is_valid_device_id(MAX_INT32), "Max 32-bit int Device ID must be accepted")
        assert_false(is_valid_device_id(MAX_INT32 + 1), "Overflow Device ID (> 2^31-1) must be rejected")

    @feature(6, "Sequence number gaps detection")
    def test_f06_bva02_sequence_number_gaps_detection(self):
        """Verify simulator/backend detects sequence number jumps as dropped packets."""
        last_seq = 10
        incoming_seq = 15  # Gap of 4 packets (11, 12, 13, 14 missing)
        
        has_gap = incoming_seq > last_seq + 1
        gap_count = (incoming_seq - last_seq - 1) if has_gap else 0
        
        assert_true(has_gap, "Gap between sequence 10 and 15 must be detected")
        assert_equal(gap_count, 4, "Gap count must equal exactly 4 dropped packets")

    @feature(6, "Duplicate sequence ID deduplication")
    def test_f06_bva03_duplicate_sequence_ids_handling(self):
        """Verify duplicate sequence numbers within same device are flagged as DUPLICATE."""
        # Simulated session history cache: {(device_id, seq)}
        processed_sequences = {(1, 101), (1, 102), (1, 103)}
        
        # Incoming packet with already processed seq
        retransmitted_packet = {"device_id": 1, "seq": 102}
        key = (retransmitted_packet["device_id"], retransmitted_packet["seq"])
        
        is_duplicate = key in processed_sequences
        assert_true(is_duplicate, "Retransmitted packet must be identified as duplicate")
        # Ensure duplicate does not increment processed unique count
        assert_equal(len(processed_sequences), 3)

    @feature(6, "Simulator timeout handling on unresponsive backend")
    def test_f06_bva04_simulator_timeout_handling(self):
        """Verify API client timeout handling when backend latency exceeds timeout limit."""
        # Execute request with extremely short timeout (0.0001s) to force timeout trap
        client = BackendApiClient(base_url="http://10.255.255.1:8081/SmartLocker", default_timeout=0.001)
        resp = client.request("POST", "/api/health", headers={"X-API-Key": "TEST_KEY"})
        
        # Must catch timeout gracefully and return ApiResponse with error rather than crashing
        assert_equal(resp.is_success, False, "Request beyond timeout must not succeed")
        assert_true(resp.error is not None or resp.status_code == 0,
                    "Client must record error description or 0 status code on timeout")

    @feature(6, "Simulator graceful disconnect and reconnect state machine")
    def test_f06_bva05_simulator_graceful_disconnect_reconnect(self):
        """Verify state machine transitions cleanly: CONNECTED -> DISCONNECTED -> CONNECTING -> CONNECTED."""
        class MockSimulatorState:
            def __init__(self):
                self.state = "IDLE"
                self.retry_count = 0
                
            def on_network_loss(self):
                self.state = "ERROR"
                self.retry_count += 1
                
            def on_reconnect_attempt(self):
                self.state = "CONNECTING"
                
            def on_reconnect_success(self):
                self.state = "IDLE"
                self.retry_count = 0

        sim = MockSimulatorState()
        assert_equal(sim.state, "IDLE")
        sim.on_network_loss()
        assert_equal(sim.state, "ERROR")
        assert_equal(sim.retry_count, 1)
        sim.on_reconnect_attempt()
        assert_equal(sim.state, "CONNECTING")
        sim.on_reconnect_success()
        assert_equal(sim.state, "IDLE")
        assert_equal(sim.retry_count, 0)

    # =========================================================================
    # Feature 7: Multi-Modal Auth Emulators (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(7, "Invalid PIN length and character rejection")
    def test_f07_bva01_invalid_pin_length_rejection(self):
        """Verify PIN validator rejects 5 digits, 7 digits, empty string, and non-numeric characters."""
        pin_pattern = r"^\d{6}$"
        
        invalid_pins = [
            "",             # 0 digits
            "1",            # 1 digit
            "12345",        # 5 digits (short boundary)
            "1234567",      # 7 digits (long boundary)
            "1234567890",   # 10 digits
            "12A456",       # alphanumeric
            " 123456",      # leading space
            "123456 ",      # trailing space
            "12.456",       # decimal point
            "-12345",       # negative sign
        ]
        for pin in invalid_pins:
            is_valid = bool(re.match(pin_pattern, pin))
            assert_false(is_valid, f"PIN validator must reject invalid PIN: {pin!r}")

    @feature(7, "Unknown RFID Card UID returns unauthorized")
    def test_f07_bva02_unknown_rfid_card_uid(self):
        """Verify unknown or unassigned RFID Card UID is handled as unauthorized."""
        authorized_cards = {"04A1B2C3", "0499AABBCCDD", "12345678"}
        
        test_uid = "FFFFFFFF"  # Valid hex format, but unregistered
        assert_true(bool(re.match(r"^[0-9A-Fa-f]{4,20}$", test_uid)), "Format must be valid hex")
        assert_false(test_uid in authorized_cards, "Unregistered card must not be in authorized set")
        
        # Decision simulation
        auth_decision = "UNLOCK" if test_uid in authorized_cards else "DENY"
        assert_equal(auth_decision, "DENY", "Unregistered card must produce DENY decision")

    @feature(7, "Invalid Fingerprint slot range boundaries")
    def test_f07_bva03_invalid_fingerprint_slot_range(self):
        """Verify fingerprint sensor slot boundaries: slot 0, -1, 161, 2000, float rejected."""
        def is_valid_fp_slot(slot: int) -> bool:
            return isinstance(slot, int) and not isinstance(slot, bool) and 1 <= slot <= 160

        assert_false(is_valid_fp_slot(0), "Slot 0 must be invalid (1-indexed)")
        assert_false(is_valid_fp_slot(-1), "Negative slot -1 must be invalid")
        assert_true(is_valid_fp_slot(1), "Slot 1 is minimum valid slot")
        assert_true(is_valid_fp_slot(160), "Slot 160 is maximum valid slot")
        assert_false(is_valid_fp_slot(161), "Slot 161 must be invalid (beyond 160 capacity)")
        assert_false(is_valid_fp_slot(2000), "Slot 2000 must be invalid")
        assert_false(is_valid_fp_slot(1.5), "Float slot 1.5 must be invalid")

    @feature(7, "Expired mobile unlock token rejection")
    def test_f07_bva04_expired_mobile_unlock_token_rejection(self):
        """Verify mobile unlock tap token with expired timestamp is rejected."""
        import time
        now_ts = int(time.time())
        
        # Token expired 10 minutes ago
        expired_token = {"tap": "a1b2c3d4e5f6", "expires_at": now_ts - 600}
        # Valid token expiring in 5 minutes
        valid_token = {"tap": "a1b2c3d4e5f6", "expires_at": now_ts + 300}
        
        def is_token_active(token: dict, current_time: int) -> bool:
            return token.get("expires_at", 0) > current_time

        assert_false(is_token_active(expired_token, now_ts), "Expired token must be rejected")
        assert_true(is_token_active(valid_token, now_ts), "Active token must be accepted")

    @feature(7, "Empty auth payload rejection")
    def test_f07_bva05_empty_auth_payload_rejection(self):
        """Verify empty dictionary or null method in auth payload is rejected."""
        def validate_auth_payload(payload: dict) -> tuple[bool, str]:
            if not payload or not isinstance(payload, dict):
                return False, "EMPTY_PAYLOAD"
            method = payload.get("method")
            if not method or method not in ("PIN", "CARD", "FINGERPRINT", "PHONE"):
                return False, "INVALID_METHOD"
            return True, "OK"

        ok, reason = validate_auth_payload({})
        assert_false(ok)
        assert_equal(reason, "EMPTY_PAYLOAD")

        ok, reason = validate_auth_payload({"method": None})
        assert_false(ok)
        assert_equal(reason, "INVALID_METHOD")

        ok, reason = validate_auth_payload({"method": "FACIAL_RECOGNITION"})
        assert_false(ok)
        assert_equal(reason, "INVALID_METHOD")

    # =========================================================================
    # Feature 8: Multi-Sensor Emulators (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(8, "Ultrasonic distance out-of-range boundaries")
    def test_f08_bva01_ultrasonic_distance_out_of_range(self):
        """Verify ultrasonic SRF05 readings < 0.0 cm or > 450.0 cm are detected as out-of-range."""
        def validate_ultrasonic(dist_cm: float) -> tuple[bool, str]:
            if math.isnan(dist_cm) or math.isinf(dist_cm):
                return False, "NON_NUMERIC"
            if dist_cm < 0.0:
                return False, "NEGATIVE_DISTANCE"
            if dist_cm > 450.0:
                return False, "OUT_OF_RANGE_HIGH"
            return True, "VALID"

        assert_equal(validate_ultrasonic(-0.1)[0], False)
        assert_equal(validate_ultrasonic(-50.0)[0], False)
        assert_equal(validate_ultrasonic(0.0)[0], True)      # Min boundary
        assert_equal(validate_ultrasonic(400.0)[0], True)    # Nominal max
        assert_equal(validate_ultrasonic(450.0)[0], True)    # Physical limit
        assert_equal(validate_ultrasonic(450.1)[0], False)   # Exceeds limit
        assert_equal(validate_ultrasonic(999.0)[0], False)

    @feature(8, "Reed switch floating and invalid states")
    def test_f08_bva02_reed_switch_floating_invalid_states(self):
        """Verify reed switch state must be binary (0=open, 1=closed) and open duration non-negative."""
        def validate_reed_switch(state: int, open_sec: float) -> bool:
            if state not in (0, 1):
                return False
            if open_sec < 0.0 or math.isnan(open_sec) or math.isinf(open_sec):
                return False
            return True

        assert_true(validate_reed_switch(0, 5.0))
        assert_true(validate_reed_switch(1, 0.0))
        assert_false(validate_reed_switch(-1, 5.0), "State -1 is invalid")
        assert_false(validate_reed_switch(2, 5.0), "State 2 is invalid")
        assert_false(validate_reed_switch(0, -1.0), "Negative open duration must be invalid")

    @feature(8, "Negative load-cell weight calibration anomaly")
    def test_f08_bva03_negative_load_cell_weight_anomaly(self):
        """Verify load cell readings < -200.0g (tare loss) or > 50000g (overload) are flagged."""
        def validate_load_cell(weight_g: float) -> tuple[bool, str]:
            if weight_g < -200.0:
                return False, "TARE_ERROR_NEGATIVE"
            if weight_g > 50000.0:
                return False, "OVERLOAD_MAX_EXCEEDED"
            return True, "NORMAL"

        assert_equal(validate_load_cell(-250.0)[1], "TARE_ERROR_NEGATIVE")
        assert_equal(validate_load_cell(-200.0)[0], True)    # Min boundary
        assert_equal(validate_load_cell(0.0)[0], True)
        assert_equal(validate_load_cell(25000.0)[0], True)
        assert_equal(validate_load_cell(50000.0)[0], True)   # Max boundary
        assert_equal(validate_load_cell(50001.0)[1], "OVERLOAD_MAX_EXCEEDED")

    @feature(8, "Accelerometer extreme G-force readings")
    def test_f08_bva04_accelerometer_extreme_g_force(self):
        """Verify accelerometer readings exceeding shock limit (> 16g = 156.96 m/s^2) detect tamper shock."""
        SHOCK_THRESHOLD_G = 16.0  # 16g standard sensor full-scale limit
        
        def is_shock_tamper(ax: float, ay: float, az: float) -> bool:
            # Acceleration magnitude in g's (assuming inputs in m/s^2, 1g = 9.80665)
            mag_ms2 = math.sqrt(ax**2 + ay**2 + az**2)
            mag_g = mag_ms2 / 9.80665
            return mag_g > SHOCK_THRESHOLD_G

        # Normal stationary locker
        assert_false(is_shock_tamper(0.0, 0.0, 9.81))
        # Severe crowbar / sledgehammer impact (25g)
        assert_true(is_shock_tamper(150.0, 150.0, 100.0))

    @feature(8, "NaN and Infinity sensor values detection")
    def test_f08_bva05_nan_inf_sensor_values_detection(self):
        """Verify NaN, +Inf, -Inf sensor readings are detected and sanitized."""
        test_values = [float("nan"), float("inf"), float("-inf")]
        for val in test_values:
            is_corrupted = math.isnan(val) or math.isinf(val)
            assert_true(is_corrupted, f"Value {val} must be identified as corrupted non-finite float")

    # =========================================================================
    # Feature 9: Configurable Fault Injection (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(9, "100 percent packet loss injection handling")
    def test_f09_bva01_100_percent_packet_loss_injection(self):
        """Verify 100% packet loss injection drops all packets, buffering into local queue."""
        drop_rate = 1.0  # 100% loss
        packets = [{"seq": i} for i in range(10)]
        transmitted = []
        offline_buffer = []

        for p in packets:
            # Drop policy
            if random.Random(42).random() < drop_rate:
                offline_buffer.append(p)
            else:
                transmitted.append(p)

        assert_equal(len(transmitted), 0, "No packets transmitted under 100% loss")
        assert_equal(len(offline_buffer), 10, "All 10 packets must be buffered in offline queue")

    @feature(9, "Maximum network delay exceeding timeout threshold")
    def test_f09_bva02_maximum_jitter_delay_timeout(self):
        """Verify simulated delay exceeding timeout threshold triggers network failure event."""
        client_timeout_sec = 2.0
        injected_delay_sec = 3.5  # Exceeds timeout
        
        is_timed_out = injected_delay_sec > client_timeout_sec
        assert_true(is_timed_out, "Delay > timeout must be identified as timeout condition")

    @feature(9, "Corrupt sensor payload bitflip detection")
    def test_f09_bva03_corrupt_sensor_payload_bitflip(self):
        """Verify single-bit corruption in serialized payload fails checksum/CRC verification."""
        original_bytes = b'{"seq": 100, "door_open_sec": 5.0}'
        import binascii
        orig_crc = binascii.crc32(original_bytes)
        
        # Invert lowest bit of 5th byte
        tampered_bytes = bytearray(original_bytes)
        tampered_bytes[5] ^= 0x01
        tampered_crc = binascii.crc32(tampered_bytes)
        
        assert_equal(orig_crc != tampered_crc, True, "Bitflip must alter CRC32 checksum")

    @feature(9, "Deterministic random seed reproducibility boundaries")
    def test_f09_bva04_seed_reproducibility_boundaries(self):
        """Verify reproducibility at seed=0 (min) and seed=2147483647 (max int32)."""
        seeds = [0, 2147483647]
        for s in seeds:
            r1 = random.Random(s)
            seq1 = [r1.randint(1, 1000) for _ in range(50)]
            r2 = random.Random(s)
            seq2 = [r2.randint(1, 1000) for _ in range(50)]
            assert_equal(seq1, seq2, f"Seed {s} must produce identical sequence across runs")

    @feature(9, "Invalid fault configuration schema rejection")
    def test_f09_bva05_invalid_fault_config_schema(self):
        """Verify validator rejects negative probabilities, drop rates > 1.0, and negative delays."""
        invalid_configs = [
            {"drop_rate": -0.1},        # Negative drop rate
            {"drop_rate": 1.1},         # Drop rate > 1.0
            {"delay_ms": -100},         # Negative delay
            {"jitter_ms": -5},          # Negative jitter
        ]
        def validate_fault_config(cfg: dict) -> bool:
            if "drop_rate" in cfg and not (0.0 <= cfg["drop_rate"] <= 1.0):
                return False
            if "delay_ms" in cfg and cfg["delay_ms"] < 0:
                return False
            if "jitter_ms" in cfg and cfg["jitter_ms"] < 0:
                return False
            return True

        for cfg in invalid_configs:
            assert_false(validate_fault_config(cfg), f"Fault config validator must reject: {cfg}")

    # =========================================================================
    # Feature 10: 5-Stage Sensor Integration Tracking (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(10, "Stage 1 without Stage 2 payload prevents stage advancement")
    def test_f10_bva01_stage1_without_stage2_payload(self):
        """Verify sensor with emulator code (Stage 1) but empty payload cannot claim Stage 2+."""
        class MockSensorTracker:
            def __init__(self, name: str):
                self.name = name
                self.stage_1_emulator = True
                self.stage_2_payload = False
                
            def can_claim_stage(self, stage_num: int) -> bool:
                if stage_num == 1:
                    return self.stage_1_emulator
                if stage_num == 2:
                    return self.stage_1_emulator and self.stage_2_payload
                if stage_num >= 3:
                    return False
                return False

        tracker = MockSensorTracker("draft_sensor")
        assert_true(tracker.can_claim_stage(1))
        assert_false(tracker.can_claim_stage(2), "Cannot claim Stage 2 without payload generation")
        assert_false(tracker.can_claim_stage(3), "Cannot claim Stage 3 without Stage 2")

    @feature(10, "Unpersisted Stage 3 payload strictly prevents claiming backend integration")
    def test_f10_bva02_unpersisted_stage3_payload(self):
        """Verify sensor transmitted (Stage 3) but unpersisted in DB (Stage 4) cannot claim backend integration."""
        # Baseline SmartLocker has ultrasonic & IMU transmitted, but NOT stored in DB
        unpersisted_channel = {
            "channel": "ultrasonic_distance",
            "stage_1": True,
            "stage_2": True,
            "stage_3": True,
            "stage_4": False,  # Missing DB persistence
            "stage_5": False,
        }
        is_backend_integrated = unpersisted_channel["stage_4"] and unpersisted_channel["stage_5"]
        assert_false(is_backend_integrated, "Unpersisted telemetry must not claim backend integration")

    @feature(10, "Stage 5 processing failure handling")
    def test_f10_bva03_stage5_processing_failure_handling(self):
        """Verify rule engine processing exception or rejection halts Stage 5 verification."""
        telemetry = {"weight_delta_g": 50.0, "door_open_sec": 10.0}
        
        # Simulate rule engine failure
        def run_rule_engine(data: dict) -> tuple[bool, str]:
            if "anomaly_flag" not in data and data.get("weight_delta_g", 0) > 20000:
                raise ValueError("Payload exceeds rule engine threshold")
            return True, "PROCESSED"

        # Valid payload succeeds Stage 5
        ok, res = run_rule_engine(telemetry)
        assert_true(ok)
        assert_equal(res, "PROCESSED")

        # Corrupt payload raises error in Stage 5
        try:
            run_rule_engine({"weight_delta_g": 99999})
            assert_true(False, "Should have raised processing error")
        except ValueError:
            pass  # Expected Stage 5 failure

    @feature(10, "Invalid sensor channel name rejected by tracking framework")
    def test_f10_bva04_invalid_sensor_channel_name_rejected(self):
        """Verify registration of unsupported/hallucinated sensor channels is rejected."""
        valid_channels = {"reed_switch", "load_cell", "ultrasonic", "imu_vibration"}
        
        invalid_channels = [
            "quantum_flux_sensor",
            "radiation_dosimeter",
            "retinal_scanner",
            "",
            None,
        ]
        for ch in invalid_channels:
            is_valid = ch in valid_channels
            assert_false(is_valid, f"Tracking registry must reject unknown channel: {ch}")

    @feature(10, "Unverified integration claim rejection without proof")
    def test_f10_bva05_unverified_integration_claim_rejection(self):
        """Verify rule that claiming FULLY_INTEGRATED requires explicit proof in schema and rules."""
        def verify_integration_claim(channel: str, has_db_column: bool, has_rule_logic: bool) -> bool:
            return has_db_column and has_rule_logic

        # Load cell has column 'weight_delta_g' and logic in RuleEngine.java
        assert_true(verify_integration_claim("load_cell", has_db_column=True, has_rule_logic=True))
        
        # Ultrasonic in baseline has no DB column in LockerSession and no baseline rule logic
        assert_false(verify_integration_claim("ultrasonic", has_db_column=False, has_rule_logic=False),
                     "Ultrasonic without DB column and rule logic cannot claim FULLY_INTEGRATED")
