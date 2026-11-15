"""
Comprehensive Unit and Integration Test Suite for the SmartLocker Virtual Device Simulator.
Tests VirtualESP32, Auth Emulators, Sensor Emulators, Fault Injection,
5-Stage Sensor Integration Tracking, and Live Backend HTTP Communication.
"""

import math
import os
import random
import time
import unittest
from datetime import datetime, timezone
import urllib.error
import urllib.request

from simulator.config import DeviceConfig
from simulator.state_machine import (
    DeviceState,
    DeviceStateMachine,
    InvalidStateTransitionError,
    VALID_TRANSITIONS,
)
from simulator.esp32 import VirtualESP32
from simulator.auth.pin import PinAuthEmulator
from simulator.auth.rfid import RfidAuthEmulator
from simulator.auth.fingerprint import FingerprintAuthEmulator
from simulator.auth.mobile_tap import MobileTapAuthEmulator
from simulator.sensors.ultrasonic import UltrasonicSensor
from simulator.sensors.reed_switch import ReedSwitchSensor
from simulator.sensors.load_cell import LoadCellSensor
from simulator.sensors.imu_vibration import ImuSensor
from simulator.faults.config import (
    FaultConfig,
    NetworkFaultConfig,
    SensorFaultConfig,
)
from simulator.faults.injector import FaultInjector
from simulator.tracking.stage_tracker import (
    ChannelStageStatus,
    SensorIntegrationTracker,
)
from simulator.tracking.matrix import (
    generate_integration_matrix_content,
    write_integration_matrix_file,
)


class TestDeviceConfig(unittest.TestCase):
    """Test device configuration models and validation."""

    def test_default_config(self):
        cfg = DeviceConfig()
        cfg.validate()
        self.assertEqual(cfg.device_code, "LOCKER-01")
        self.assertEqual(cfg.device_id, 1)
        self.assertEqual(cfg.api_key, "device-1-api-key")
        self.assertTrue(cfg.base_url.startswith("http"))

    def test_invalid_device_id(self):
        cfg = DeviceConfig(device_id=0)
        with self.assertRaises(ValueError):
            cfg.validate()

        cfg2 = DeviceConfig(device_id=-5)
        with self.assertRaises(ValueError):
            cfg2.validate()

    def test_invalid_api_key(self):
        cfg = DeviceConfig(api_key="")
        with self.assertRaises(ValueError):
            cfg.validate()

    def test_from_properties_file(self):
        prop_path = os.path.join("config", "device-keys.local.properties")
        cfg = DeviceConfig.from_properties_file(prop_path, device_code="LOCKER-01")
        self.assertIsNotNone(cfg.api_key)


class TestDeviceStateMachine(unittest.TestCase):
    """Test state machine lifecycle states and valid/invalid transitions."""

    def setUp(self):
        self.fsm = DeviceStateMachine(initial_state=DeviceState.BOOT)

    def test_operational_states_count(self):
        states = set(DeviceState)
        self.assertGreaterEqual(len(states), 5)
        expected_names = {
            "IDLE",
            "CONNECTING",
            "AUTHENTICATING",
            "WAIT_DOOR",
            "BATCH_INGEST",
            "ERROR",
        }
        actual_names = {s.value for s in states}
        for name in expected_names:
            self.assertIn(name, actual_names)

    def test_valid_access_lifecycle_transitions(self):
        self.fsm.transition_to(DeviceState.CONNECTING)
        self.fsm.transition_to(DeviceState.IDLE)
        self.fsm.transition_to(DeviceState.AUTHENTICATING)
        self.fsm.transition_to(DeviceState.WAIT_DOOR)
        self.fsm.transition_to(DeviceState.RELOCKED)
        self.fsm.transition_to(DeviceState.BATCH_INGEST)
        self.fsm.transition_to(DeviceState.IDLE)
        self.assertEqual(self.fsm.current_state, DeviceState.IDLE)

    def test_choose_prompt_flow(self):
        self.fsm.transition_to(DeviceState.CONNECTING)
        self.fsm.transition_to(DeviceState.IDLE)
        self.fsm.transition_to(DeviceState.AUTHENTICATING)
        self.fsm.transition_to(DeviceState.CHOOSE_PROMPT)
        self.fsm.transition_to(DeviceState.WAIT_DOOR)
        self.assertEqual(self.fsm.current_state, DeviceState.WAIT_DOOR)

    def test_error_and_recovery_flow(self):
        self.fsm.transition_to(DeviceState.CONNECTING)
        self.fsm.transition_to(DeviceState.ERROR)
        self.fsm.transition_to(DeviceState.CONNECTING)
        self.fsm.transition_to(DeviceState.IDLE)
        self.assertEqual(self.fsm.current_state, DeviceState.IDLE)

    def test_offline_transitions(self):
        self.fsm.transition_to(DeviceState.CONNECTING)
        self.fsm.transition_to(DeviceState.IDLE)
        self.fsm.transition_to(DeviceState.OFFLINE)
        self.fsm.transition_to(DeviceState.CONNECTING)
        self.fsm.transition_to(DeviceState.IDLE)
        self.assertEqual(self.fsm.current_state, DeviceState.IDLE)

    def test_invalid_transition_raises_error(self):
        # Direct jump from BOOT to WAIT_DOOR is prohibited
        with self.assertRaises(InvalidStateTransitionError):
            self.fsm.transition_to(DeviceState.WAIT_DOOR)

    def test_transition_map_contains_e2e_contract_paths(self):
        self.assertIn("WAIT_DOOR", VALID_TRANSITIONS["AUTHENTICATING"])
        self.assertIn("BATCH_INGEST", VALID_TRANSITIONS["WAIT_DOOR"])
        self.assertIn("IDLE", VALID_TRANSITIONS["BATCH_INGEST"])


class TestAuthEmulators(unittest.TestCase):
    """Test all 4 multi-modal authentication outcome emulators."""

    def test_pin_valid_and_invalid(self):
        pin_emu = PinAuthEmulator()
        self.assertTrue(pin_emu.validate("123456"))
        self.assertTrue(pin_emu.validate("000000"))
        self.assertTrue(pin_emu.validate("999999"))

        self.assertFalse(pin_emu.validate("12345"))     # 5 digits
        self.assertFalse(pin_emu.validate("1234567"))   # 7 digits
        self.assertFalse(pin_emu.validate("12A456"))    # Non-decimal
        self.assertFalse(pin_emu.validate(""))          # Empty
        self.assertFalse(pin_emu.validate(123456))      # Non-string

        payload = pin_emu.format_payload("654321", intent="OPEN")
        self.assertEqual(payload["method"], "PIN")
        self.assertEqual(payload["pin"], "654321")
        self.assertEqual(payload["intent"], "OPEN")

    def test_pin_keypad_simulation(self):
        pin_emu = PinAuthEmulator()
        pin_emu.input_digit("1")
        pin_emu.input_digit("2")
        pin_emu.input_digit("3")
        pin_emu.press_backspace()
        pin_emu.input_digit("9")
        pin_emu.input_digit("8")
        pin_emu.input_digit("7")
        pin_emu.input_digit("6")
        res = pin_emu.press_submit()
        self.assertEqual(res["pin"], "129876")

    def test_rfid_valid_and_invalid(self):
        rfid_emu = RfidAuthEmulator()
        self.assertTrue(rfid_emu.validate("04A1B2C3"))
        self.assertTrue(rfid_emu.validate("0499AABBCCDD"))
        self.assertTrue(rfid_emu.validate("12345678"))

        self.assertFalse(rfid_emu.validate("04A"))       # Too short (<4)
        self.assertFalse(rfid_emu.validate("04Z1B2C3"))   # Non-hex character
        self.assertFalse(rfid_emu.validate("04A1B2C3" * 5))  # Too long (>20)

        self.assertTrue(rfid_emu.is_phone_hce_uid("08ABCDEF"))
        self.assertFalse(rfid_emu.is_phone_hce_uid("04ABCDEF"))

        payload = rfid_emu.format_payload("04a1b2c3", intent="CHECKOUT")
        self.assertEqual(payload["method"], "CARD")
        self.assertEqual(payload["card_uid"], "04A1B2C3")
        self.assertEqual(payload["intent"], "CHECKOUT")

    def test_fingerprint_valid_and_invalid(self):
        fp_emu = FingerprintAuthEmulator()
        self.assertTrue(fp_emu.validate(1))
        self.assertTrue(fp_emu.validate(50))
        self.assertTrue(fp_emu.validate(160))

        self.assertFalse(fp_emu.validate(0))       # Slot 0 invalid (1-indexed)
        self.assertFalse(fp_emu.validate(-1))      # Negative
        self.assertFalse(fp_emu.validate(161))     # Exceeds max 160
        self.assertFalse(fp_emu.validate(1.5))     # Float
        self.assertFalse(fp_emu.validate(True))    # Boolean

        payload = fp_emu.format_payload(7, intent="ASK")
        self.assertEqual(payload["method"], "FINGERPRINT")
        self.assertEqual(payload["sensor_slot"], 7)

    def test_mobile_tap_token(self):
        mobile_emu = MobileTapAuthEmulator()
        self.assertTrue(mobile_emu.validate("dgFgdbSaVCYc"))
        self.assertFalse(mobile_emu.validate("short"))

        extracted = mobile_emu.extract_token_from_path("/k/LOCKER-01?n=token12345")
        self.assertEqual(extracted, "token12345")

        payload = mobile_emu.format_payload("token12345", device_code="LOCKER-01")
        self.assertEqual(payload["device_code"], "LOCKER-01")
        self.assertEqual(payload["method"], "PHONE")
        self.assertEqual(payload["tap"], "token12345")


class TestSensorEmulators(unittest.TestCase):
    """Test all 4 software-based sensor emulators."""

    def test_ultrasonic_ranges_and_presence(self):
        sonar = UltrasonicSensor(seed=42)
        self.assertEqual(sonar.name, "ultrasonic")
        self.assertEqual(sonar.unit, "cm")
        self.assertEqual(sonar.min_valid, 0.0)
        self.assertEqual(sonar.max_valid, 400.0)

        self.assertTrue(sonar.is_in_valid_range(0.0))
        self.assertTrue(sonar.is_in_valid_range(400.0))
        self.assertTrue(sonar.is_in_valid_range(450.0))
        self.assertFalse(sonar.is_in_valid_range(-0.1))
        self.assertFalse(sonar.is_in_valid_range(450.1))
        self.assertFalse(sonar.is_in_valid_range(float("nan")))
        self.assertFalse(sonar.is_in_valid_range(float("inf")))

        # Presence detection
        near_reading = sonar.sample(distance_cm=20.0, noise_stddev=0.0)
        self.assertTrue(near_reading["presence"])
        self.assertFalse(near_reading["doorway_clear"])

        far_reading = sonar.sample(distance_cm=100.0, noise_stddev=0.0)
        self.assertFalse(far_reading["presence"])
        self.assertTrue(far_reading["doorway_clear"])

    def test_ultrasonic_door_clearance_countdown(self):
        sonar = UltrasonicSensor(seed=42)
        # Normal clearance when user steps away after 5 seconds
        res = sonar.simulate_door_clearance(
            user_stay_duration_sec=5.0, door_open_limit_sec=10.0
        )
        self.assertFalse(res["closed_by_override"])
        self.assertAlmostEqual(res["total_door_open_sec"], 15.0, delta=1.0)

        # Forced safety override when user obstructs doorway for >120s
        res_blocked = sonar.simulate_door_clearance(
            user_stay_duration_sec=200.0, door_open_max_sec=120.0
        )
        self.assertTrue(res_blocked["closed_by_override"])
        self.assertEqual(res_blocked["total_door_open_sec"], 120.0)

    def test_reed_switch_door_contact(self):
        reed = ReedSwitchSensor(seed=42)
        self.assertEqual(reed.name, "reed_switch")
        self.assertEqual(reed.unit, "s")
        self.assertEqual(reed.min_valid, 0.0)
        self.assertEqual(reed.max_valid, 3600.0)

        self.assertTrue(reed.is_in_valid_range(0.0))
        self.assertTrue(reed.is_in_valid_range(5.5))
        self.assertTrue(reed.is_in_valid_range(3600.0))
        self.assertFalse(reed.is_in_valid_range(-1.0))
        self.assertFalse(reed.is_in_valid_range(float("nan")))

        # Open/close state cycle
        t0 = 1000.0
        reed.open_door(timestamp=t0)
        self.assertTrue(reed.is_door_open)
        duration = reed.close_door(timestamp=t0 + 6.5)
        self.assertTrue(reed.is_door_closed)
        self.assertAlmostEqual(duration, 6.5, delta=0.01)

    def test_load_cell_hx711(self):
        load_cell = LoadCellSensor(seed=42)
        self.assertEqual(load_cell.name, "load_cell")
        self.assertEqual(load_cell.unit, "g")
        self.assertEqual(load_cell.min_valid, -200.0)
        self.assertEqual(load_cell.max_valid, 20000.0)

        self.assertTrue(load_cell.is_in_valid_range(-200.0))
        self.assertTrue(load_cell.is_in_valid_range(0.0))
        self.assertTrue(load_cell.is_in_valid_range(20000.0))
        self.assertTrue(load_cell.is_in_valid_range(50000.0))
        self.assertFalse(load_cell.is_in_valid_range(-250.0))
        self.assertFalse(load_cell.is_in_valid_range(50001.0))

        # Tare and item weight tracking
        load_cell.tare(baseline_gross_g=500.0)
        load_cell.record_pre_access()
        load_cell.place_item(250.0)
        load_cell.record_post_access()
        delta = load_cell.compute_weight_delta()
        self.assertAlmostEqual(delta, 250.0, delta=0.01)

    def test_imu_vibration_and_shock(self):
        imu = ImuSensor(seed=42)
        self.assertEqual(imu.name, "vibration_tilt")

        # Stationary resting locker under 1g gravity
        stationary = imu.sample_stationary(noise_stddev=0.0)
        self.assertAlmostEqual(stationary["mag_ms2"], 9.807, delta=0.01)
        self.assertAlmostEqual(stationary["mag_g"], 1.0, delta=0.01)
        self.assertFalse(stationary["is_shock_tamper"])

        # Severe tamper shock (20g impact)
        shock = imu.sample_shock(g_force=20.0)
        self.assertGreater(shock["mag_g"], 16.0)
        self.assertTrue(shock["is_shock_tamper"])


class TestFaultInjectorDeterminism(unittest.TestCase):
    """Test deterministic PRNG seeding and reproducible fault injection."""

    def test_reproducible_seeding(self):
        cfg1 = FaultConfig(seed=42)
        cfg1.network.enabled = True
        cfg1.network.delay_mean_ms = 100.0
        cfg1.network.delay_std_ms = 15.0

        inj1 = FaultInjector(cfg1)
        delays1 = [inj1.get_transmission_delay_sec() for _ in range(50)]

        inj2 = FaultInjector(cfg1)
        delays2 = [inj2.get_transmission_delay_sec() for _ in range(50)]

        self.assertEqual(delays1, delays2, "Identical seeds must produce bit-for-bit identical delay sequences")

    def test_divergent_seeds(self):
        cfg1 = FaultConfig(seed=42)
        cfg1.network.enabled = True
        cfg1.network.delay_mean_ms = 100.0
        cfg1.network.delay_std_ms = 15.0

        cfg2 = FaultConfig(seed=999)
        cfg2.network.enabled = True
        cfg2.network.delay_mean_ms = 100.0
        cfg2.network.delay_std_ms = 15.0

        inj1 = FaultInjector(cfg1)
        inj2 = FaultInjector(cfg2)

        delays1 = [inj1.get_transmission_delay_sec() for _ in range(20)]
        delays2 = [inj2.get_transmission_delay_sec() for _ in range(20)]
        self.assertNotEqual(delays1, delays2, "Different seeds must produce divergent delay sequences")

    def test_packet_drop_rate(self):
        cfg = FaultConfig(seed=123)
        cfg.network.enabled = True
        cfg.network.packet_drop_rate = 0.35

        inj = FaultInjector(cfg)
        samples = [inj.should_drop_packet() for _ in range(1000)]
        measured_rate = sum(samples) / len(samples)
        self.assertAlmostEqual(measured_rate, 0.35, delta=0.05)

    def test_payload_corruption_modes(self):
        # 1. Syntax corruption
        cfg = FaultConfig(seed=42)
        cfg.network.enabled = True
        cfg.network.corrupt_payload_prob = 1.0
        cfg.network.corruption_mode = "SYNTAX"
        inj = FaultInjector(cfg)
        corrupted, mutated = inj.corrupt_payload({"device_id": 1, "sessions": []})
        self.assertTrue(mutated)
        self.assertIn("MALFORMED_JSON", corrupted)

        # 2. Field drop corruption
        cfg.network.corruption_mode = "FIELD_DROP"
        inj = FaultInjector(cfg)
        original = {"device_id": 1, "sessions": [{"seq": 101, "measured_at": "2026-11-15 12:00:00"}]}
        corrupted, mutated = inj.corrupt_payload(original)
        self.assertTrue(mutated)
        self.assertNotIn("seq", corrupted["sessions"][0])

    def test_sensor_fault_injection(self):
        cfg = FaultConfig(seed=42)
        cfg.sensors["load_cell"] = SensorFaultConfig(
            enabled=True,
            sensor_name="load_cell",
            fault_type="OUT_OF_RANGE",
            out_of_range_val=-5000.0,
        )
        inj = FaultInjector(cfg)
        val = inj.inject_sensor_reading("load_cell", 10.0)
        self.assertEqual(val, -5000.0)

        # Drift accumulation
        cfg.sensors["load_cell"] = SensorFaultConfig(
            enabled=True,
            sensor_name="load_cell",
            fault_type="DRIFT",
            drift_rate_per_sec=2.0,
        )
        inj = FaultInjector(cfg)
        t0 = 1000.0
        v1 = inj.inject_sensor_reading("load_cell", 10.0, timestamp_sec=t0)
        self.assertEqual(v1, 10.0)
        v2 = inj.inject_sensor_reading("load_cell", 10.0, timestamp_sec=t0 + 5.0)
        self.assertEqual(v2, 20.0, "Drift of 2.0g/s for 5s adds 10.0g")


class Test5StageSensorTracking(unittest.TestCase):
    """Test 5-stage tracking matrix and Baseline B0 vs Proposed B1 compliance."""

    def test_baseline_b0_matrix(self):
        tracker = SensorIntegrationTracker(mode="B0")

        # Reed Switch: Fully integrated
        reed = tracker.get_channel_status("reed_switch")
        self.assertTrue(reed.fully_integrated)

        # Load Cell: Fully integrated
        load = tracker.get_channel_status("load_cell")
        self.assertTrue(load.fully_integrated)

        # Ultrasonic: Stages 1-3 PASS, Stages 4-5 FAIL in B0
        sonar = tracker.get_channel_status("ultrasonic")
        self.assertTrue(sonar.stage1_emulator_implemented)
        self.assertTrue(sonar.stage2_payload_generated)
        self.assertTrue(sonar.stage3_payload_transmitted)
        self.assertFalse(sonar.stage4_backend_persisted)
        self.assertFalse(sonar.stage5_backend_processed)
        self.assertFalse(sonar.fully_integrated)

        # Vibration/Tilt: Stages 1-3 PASS, Stages 4-5 FAIL in B0
        imu = tracker.get_channel_status("vibration_tilt")
        self.assertFalse(imu.fully_integrated)

        # Verify markdown report contents
        report = tracker.generate_markdown_report()
        self.assertIn("| reed_switch | PASS | PASS | PASS | PASS | PASS | **INTEGRATED** |", report)
        self.assertIn("| ultrasonic | PASS | PASS | PASS | FAIL | FAIL | *NOT INTEGRATED* |", report)

    def test_reject_unregistered_channel_name(self):
        tracker = SensorIntegrationTracker(mode="B0")
        with self.assertRaises(ValueError):
            tracker.get_channel_status("quantum_flux_sensor")
        with self.assertRaises(ValueError):
            tracker.get_channel_status("")

    def test_matrix_file_generation(self):
        tmp_path = os.path.join("simulator", "test_matrix_temp.md")
        try:
            write_integration_matrix_file(file_path=tmp_path, mode="B0")
            self.assertTrue(os.path.isfile(tmp_path))
            with open(tmp_path, "r", encoding="utf-8") as f:
                content = f.read()
                self.assertIn("SmartLocker Multi-Sensor 5-Stage Integration Matrix", content)
        finally:
            if os.path.isfile(tmp_path):
                os.remove(tmp_path)


class TestVirtualESP32LiveBackend(unittest.TestCase):
    """Test Virtual ESP32 communicating with live Java backend on port 8081."""

    @classmethod
    def setUpClass(cls):
        cls.config = DeviceConfig()
        cls.sim = VirtualESP32(config=cls.config, seed=42)

    def test_monotonic_sequence_generation(self):
        seqs = [self.sim.next_seq() for _ in range(10)]
        self.assertEqual(len(seqs), 10)
        for i in range(len(seqs) - 1):
            self.assertLess(seqs[i], seqs[i + 1], "Sequence numbers must strictly increase")

    def test_live_heartbeat_success(self):
        resp = self.sim.heartbeat()
        self.assertIn("interval_sec", resp)
        self.assertIn("server_time", resp)
        self.assertIn("tap_path", resp)
        self.assertGreaterEqual(resp["interval_sec"], 1)

    def test_live_heartbeat_bad_key(self):
        bad_config = DeviceConfig(api_key="invalid-api-key")
        bad_sim = VirtualESP32(config=bad_config)
        resp = bad_sim.heartbeat()
        self.assertEqual(resp.get("status"), "ERROR")
        self.assertEqual(resp.get("code"), 401)

    def test_live_device_auth_pin(self):
        # PIN format test (unregistered pin generates DENY)
        resp = self.sim.authenticate("PIN", "987654", intent="ASK")
        self.assertIn("result", resp)
        self.assertIn(resp["result"], ["UNLOCK", "CHOOSE", "DENY"])

    def test_live_batch_ingestion_and_deduplication(self):
        # 1. Ingest unique session
        seq = self.sim.next_seq()
        measured_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        session_obj = {
            "seq": seq,
            "measured_at": measured_time,
            "door_open_sec": 5.0,
            "weight_delta_g": 10.0,
            "unlock_count": 1,
            "rfid_ok": True,
            "stay_min": 10.0,
            "slot_code": "A01",
            "open_source": "RFID",
            "command_id": None,
        }

        resp1 = self.sim.ingest_batch([session_obj])
        self.assertEqual(resp1.get("saved"), 1)
        self.assertEqual(resp1.get("duplicates"), 0)

        # 2. Replay duplicate session
        resp2 = self.sim.ingest_batch([session_obj])
        self.assertEqual(resp2.get("saved"), 0)
        self.assertEqual(resp2.get("duplicates"), 1)

    def test_offline_queue_buffering_and_flush(self):
        # Simulate network drop
        cfg_drop = FaultConfig(seed=42)
        cfg_drop.network.enabled = True
        cfg_drop.network.packet_drop_rate = 1.0  # 100% loss

        sim_offline = VirtualESP32(config=self.config, fault_config=cfg_drop)
        seq = sim_offline.next_seq()
        s = {
            "seq": seq,
            "measured_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
            "door_open_sec": 4.0,
            "weight_delta_g": 0.0,
            "unlock_count": 1,
            "rfid_ok": True,
            "stay_min": 10.0,
            "slot_code": "A01",
            "open_source": "RFID",
        }

        res = sim_offline.ingest_batch([s])
        self.assertEqual(res.get("buffered_offline"), 1)
        self.assertEqual(len(sim_offline.offline_queue), 1)

        # Disable fault and flush
        sim_offline.fault_injector.config.network.enabled = False
        flushed = sim_offline.flush_offline_queue()
        self.assertEqual(flushed, 1)
        self.assertEqual(len(sim_offline.offline_queue), 0)


if __name__ == "__main__":
    unittest.main()
