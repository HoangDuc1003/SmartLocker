"""
Milestone 3 - Feature 14: Stratified Session Generator.
Generates >= 100 independent, reproducible, labeled experimental sessions
across 5 stratified categories (minimum 20 each) with variations in values,
timing, credentials, and faults using deterministic hierarchical seeds.
Pre-labels every session via ScenarioOracle before execution.
"""

import csv
import json
import os
import random
import sys
from typing import Any, Dict, List, Optional

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from experiments.oracle import (
    AuthMethod,
    CanonicalClass,
    ScenarioCategory,
    ScenarioOracle,
    ScenarioSpec,
)


class ScenarioGenerator:
    """
    Stratified Session Generator producing >= 100 reproducible sessions
    across 5 categories with bit-for-bit PRNG determinism.
    """

    # Valid Active Credentials in SL_SIM (CANT-A, device_id = 5)
    VALID_PINS = [
        ("952705", "A04", "CANT-A"),
        ("320357", "A15", "CANT-A"),
        ("632262", "A03", "CANT-A"),
    ]
    INVALID_PINS = ["000000", "111111", "999999", "123123", "888888", "456789"]

    VALID_CARDS = ["04A1B2C3", "0499AABB", "04C3D4E5", "04F5A6B7", "04556677"]
    BLOCKED_CARDS = ["04DE0012", "C15C039D", "C206670A", "04E1F205"]
    UNKNOWN_CARDS = ["04BAD001", "04BAD002", "04BAD003", "DEADBEEF"]

    VALID_FINGERPRINTS = [1, 2, 5]
    INVALID_FINGERPRINTS = [161, 200, 999]

    PHONE_TAP_TOKENS = ["inAAgAWaNq99", "B3P4eF7888DP", "NfcTokenDemo12"]

    def __init__(self, master_seed: int = 20261115, total_sessions: int = 100):
        if total_sessions < 100:
            raise ValueError(f"Total sessions must be >= 100, got {total_sessions}")
        self.master_seed = master_seed
        self.total_sessions = total_sessions
        self.per_category = total_sessions // 5
        self.master_rng = random.Random(master_seed)

    def generate_all(self) -> List[ScenarioSpec]:
        """Generate all stratified scenarios with pre-assigned ground truth."""
        scenarios: List[ScenarioSpec] = []
        idx = 1

        # -----------------------------------------------------------------
        # 1. NORMAL_AUTHORIZED (minimum 20 sessions)
        # -----------------------------------------------------------------
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            mode = rng.choice(["PIN", "PIN", "CARD", "CARD", "FINGERPRINT"])
            if mode == "PIN":
                pin_info = rng.choice(self.VALID_PINS)
                cred, slot, bank = pin_info[0], pin_info[1], pin_info[2]
            elif mode == "CARD":
                cred = rng.choice(self.VALID_CARDS)
                slot, bank = "A04", "CANT-A"
            else:
                cred = str(rng.choice(self.VALID_FINGERPRINTS))
                slot, bank = "A03", "CANT-A"

            door_sec = round(rng.uniform(4.5, 12.0), 2)
            weight_delta = round(rng.uniform(-150.0, 450.0), 2)
            stay_min = round(rng.uniform(5.0, 30.0), 1)
            sonar = round(rng.uniform(15.0, 45.0), 1)
            vib = round(rng.uniform(0.01, 0.08), 3)
            tilt = round(rng.uniform(0.1, 0.9), 2)
            shock = round(rng.uniform(0.95, 1.05), 2)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-NORM-{i+1:02d}",
                seed=seed,
                category=ScenarioCategory.NORMAL_AUTHORIZED.value,
                ground_truth_label="",
                auth_method=mode,
                credential=cred,
                slot_code=slot,
                bank_code=bank,
                expected_auth_result="UNLOCK",
                expected_b0_label="",
                expected_b1_label="",
                door_open_sec=door_sec,
                weight_delta_g=weight_delta,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=sonar,
                vibration_intensity=vib,
                tilt_deg=tilt,
                shock_mag_g=shock,
                fault_type=None,
                description=f"Normal authorized access using {mode} {cred}",
            )
            self._finalize_spec(spec)
            scenarios.append(spec)
            idx += 1

        # -----------------------------------------------------------------
        # 2. UNAUTHORIZED_CREDENTIAL (minimum 20 sessions)
        # -----------------------------------------------------------------
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            var = rng.choice(["WRONG_PIN", "BLOCKED_CARD", "UNKNOWN_CARD", "INVALID_FP"])
            if var == "WRONG_PIN":
                mode = "PIN"
                cred = rng.choice(self.INVALID_PINS)
                desc = "Unauthorized access attempt with wrong PIN"
            elif var == "BLOCKED_CARD":
                mode = "CARD"
                cred = rng.choice(self.BLOCKED_CARDS)
                desc = "Unauthorized access attempt with reported lost/blocked RFID card"
            elif var == "UNKNOWN_CARD":
                mode = "CARD"
                cred = rng.choice(self.UNKNOWN_CARDS)
                desc = "Unauthorized access attempt with unregistered RFID card"
            else:
                mode = "FINGERPRINT"
                cred = str(rng.choice(self.INVALID_FINGERPRINTS))
                desc = "Unauthorized access attempt with unregistered fingerprint"

            slot, bank = "A04", "CANT-A"
            stay_min = round(rng.uniform(5.0, 20.0), 1)
            sonar = round(rng.uniform(20.0, 50.0), 1)
            vib = round(rng.uniform(0.01, 0.05), 3)
            tilt = round(rng.uniform(0.1, 0.5), 2)
            shock = round(rng.uniform(0.98, 1.02), 2)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-UNAUTH-{i+1:02d}",
                seed=seed,
                category=ScenarioCategory.UNAUTHORIZED_CREDENTIAL.value,
                ground_truth_label="",
                auth_method=mode,
                credential=cred,
                slot_code=slot,
                bank_code=bank,
                expected_auth_result="DENY",
                expected_b0_label="",
                expected_b1_label="",
                door_open_sec=0.0,
                weight_delta_g=0.0,
                rfid_ok=False,
                stay_min=stay_min,
                ultrasonic_dist_cm=sonar,
                vibration_intensity=vib,
                tilt_deg=tilt,
                shock_mag_g=shock,
                fault_type=None,
                description=desc,
            )
            self._finalize_spec(spec)
            scenarios.append(spec)
            idx += 1

        # -----------------------------------------------------------------
        # 3. FORCED_DOOR_OPEN (minimum 20 sessions)
        # -----------------------------------------------------------------
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            mech = rng.choice(["CROWBAR_PRY", "LOCK_PICK", "DOOR_KICK"])
            door_sec = round(rng.uniform(3.0, 16.0), 2)
            weight_delta = round(rng.uniform(-150.0, 0.0), 2)
            stay_min = round(rng.uniform(10.0, 60.0), 1)
            sonar = round(rng.uniform(10.0, 40.0), 1)

            if mech == "CROWBAR_PRY":
                vib = round(rng.uniform(0.65, 1.85), 3)
                tilt = round(rng.uniform(3.5, 7.5), 2)
                shock = round(rng.uniform(12.0, 15.5), 2)
                desc = "Physical door prying with crowbar without valid unlock"
            elif mech == "DOOR_KICK":
                vib = round(rng.uniform(1.20, 2.50), 3)
                tilt = round(rng.uniform(4.0, 9.0), 2)
                shock = round(rng.uniform(14.0, 22.0), 2)
                desc = "Violent door breach with high-G mechanical impact shock"
            else:
                vib = round(rng.uniform(0.62, 1.10), 3)
                tilt = round(rng.uniform(1.0, 3.0), 2)
                shock = round(rng.uniform(4.0, 8.0), 2)
                desc = "Physical door forced open via lock picking without RFID/PIN authorization"

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-FORCE-{i+1:02d}",
                seed=seed,
                category=ScenarioCategory.FORCED_DOOR_OPEN.value,
                ground_truth_label="",
                auth_method=AuthMethod.NONE.value,
                credential="NONE",
                slot_code="A04",
                bank_code="CANT-A",
                expected_auth_result="NONE",
                expected_b0_label="",
                expected_b1_label="",
                door_open_sec=door_sec,
                weight_delta_g=weight_delta,
                rfid_ok=False,
                stay_min=stay_min,
                ultrasonic_dist_cm=sonar,
                vibration_intensity=vib,
                tilt_deg=tilt,
                shock_mag_g=shock,
                fault_type=None,
                description=desc,
            )
            self._finalize_spec(spec)
            scenarios.append(spec)
            idx += 1

        # -----------------------------------------------------------------
        # 4. LOAD_OR_TAMPER_ANOMALY (minimum 20 sessions)
        # -----------------------------------------------------------------
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            tamper_type = rng.choice(["DRILL_VIBRATION", "STRUCTURAL_TILT", "SPOOF_WEIGHT_CLOSED", "HAMMER_SHOCK"])
            stay_min = round(rng.uniform(15.0, 120.0), 1)
            sonar = round(rng.uniform(30.0, 80.0), 1)

            if tamper_type == "DRILL_VIBRATION":
                vib = round(rng.uniform(0.50, 1.40), 3)
                tilt = round(rng.uniform(0.5, 2.5), 2)
                shock = round(rng.uniform(2.0, 5.0), 2)
                weight_delta = 0.0
                desc = "Continuous power tool drilling vibration against locker frame while locked"
            elif tamper_type == "STRUCTURAL_TILT":
                vib = round(rng.uniform(0.15, 0.40), 3)
                tilt = round(rng.uniform(5.0, 14.0), 2)
                shock = round(rng.uniform(1.5, 3.5), 2)
                weight_delta = 0.0
                desc = "Locker cabinet displacement and tilt attack while door remains locked"
            elif tamper_type == "HAMMER_SHOCK":
                vib = round(rng.uniform(0.30, 0.80), 3)
                tilt = round(rng.uniform(1.0, 3.5), 2)
                shock = round(rng.uniform(16.5, 22.0), 2)
                weight_delta = 0.0
                desc = "Heavy sledgehammer shock strike (>16G) against locked locker door"
            else:  # SPOOF_WEIGHT_CLOSED
                vib = round(rng.uniform(0.02, 0.08), 3)
                tilt = round(rng.uniform(0.1, 0.5), 2)
                shock = round(rng.uniform(0.98, 1.05), 2)
                weight_delta = round(rng.choice([-1.0, 1.0]) * rng.uniform(75.0, 180.0), 2)
                desc = "Weight alteration detected in slot while door was closed (suspected spoofing)"

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-TAMPER-{i+1:02d}",
                seed=seed,
                category=ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value,
                ground_truth_label="",
                auth_method=AuthMethod.NONE.value,
                credential="NONE",
                slot_code="A04",
                bank_code="CANT-A",
                expected_auth_result="NONE",
                expected_b0_label="",
                expected_b1_label="",
                door_open_sec=0.0,
                weight_delta_g=weight_delta,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=sonar,
                vibration_intensity=vib,
                tilt_deg=tilt,
                shock_mag_g=shock,
                fault_type=None,
                description=desc,
            )
            self._finalize_spec(spec)
            scenarios.append(spec)
            idx += 1

        # -----------------------------------------------------------------
        # 5. SENSOR_FAULT (minimum 20 sessions: 15 Sensor Malfunctions + 5 Network Malfunctions)
        # -----------------------------------------------------------------
        fault_types_ordered = [
            "WEIGHT_OUT_OF_RANGE", "WEIGHT_OUT_OF_RANGE", "WEIGHT_OUT_OF_RANGE", "WEIGHT_OUT_OF_RANGE",
            "DOOR_EXCEEDS_STAY", "DOOR_EXCEEDS_STAY", "DOOR_EXCEEDS_STAY", "DOOR_EXCEEDS_STAY",
            "ULTRASONIC_STUCK", "ULTRASONIC_STUCK", "ULTRASONIC_STUCK", "ULTRASONIC_STUCK",
            "IMU_DROPOUT", "IMU_DROPOUT", "IMU_DROPOUT",
            "NETWORK_TIMEOUT", "NETWORK_TIMEOUT", "NETWORK_TIMEOUT",
            "NETWORK_DUPLICATE_REPLAY", "NETWORK_DUPLICATE_REPLAY",
        ]

        for i, fault_kind in enumerate(fault_types_ordered):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            door_sec = 5.0
            weight_delta = 0.0
            stay_min = 10.0
            sonar = 30.0
            vib = 0.03
            tilt = 0.3
            shock = 1.0
            net_latency = 25.0
            dup = False
            gap = False
            corrupt = False

            if fault_kind == "WEIGHT_OUT_OF_RANGE":
                weight_delta = round(rng.choice([-500.0, 25000.0]), 2)
                desc = "Sensor fault: Load cell ADC rail saturation out of valid physical range"
            elif fault_kind == "DOOR_EXCEEDS_STAY":
                door_sec = 240.0
                stay_min = 2.0  # door > stay * 60 + 5
                desc = "Sensor fault: Door duration exceeds total booking stay time"
            elif fault_kind == "ULTRASONIC_STUCK":
                sonar = 0.0  # acoustic cutoff < 2cm
                desc = "Sensor fault: Ultrasonic transducer hardware stuck at 0cm cutoff"
            elif fault_kind == "IMU_DROPOUT":
                vib = -1.0  # I2C disconnect invalid value
                tilt = -1.0
                shock = 0.01
                desc = "Sensor fault: IMU accelerometer I2C bus disconnection"
            elif fault_kind == "NETWORK_TIMEOUT":
                net_latency = 6500.0  # > 5000ms timeout
                desc = "Network fault: Telemetry transmission timeout (6.5s latency)"
            else:  # NETWORK_DUPLICATE_REPLAY
                dup = True
                desc = "Network fault: Replay attack with duplicate non-monotonic sequence"

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-FAULT-{i+1:02d}",
                seed=seed,
                category=ScenarioCategory.SENSOR_FAULT.value,
                ground_truth_label="",
                auth_method=AuthMethod.NONE.value,
                credential="NONE",
                slot_code="A04",
                bank_code="CANT-A",
                expected_auth_result="NONE",
                expected_b0_label="",
                expected_b1_label="",
                door_open_sec=door_sec,
                weight_delta_g=weight_delta,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=sonar,
                vibration_intensity=vib,
                tilt_deg=tilt,
                shock_mag_g=shock,
                fault_type=fault_kind,
                network_latency_ms=net_latency,
                seq_duplicate=dup,
                seq_gap=gap,
                payload_corrupted=corrupt,
                description=desc,
            )
            self._finalize_spec(spec)
            scenarios.append(spec)
            idx += 1

        return scenarios

    def _finalize_spec(self, spec: ScenarioSpec) -> None:
        """Assign ground-truth and expected theoretical classifications via ScenarioOracle."""
        spec.ground_truth_label = ScenarioOracle.evaluate_ground_truth(spec)
        spec.expected_b0_label = ScenarioOracle.predict_b0(spec)
        spec.expected_b1_label = ScenarioOracle.predict_b1(spec)

    def export_scenarios(self, output_dir: str = "experiments/evidence") -> List[ScenarioSpec]:
        """Generate scenarios and save scenarios.json and ground_truth_labels.csv."""
        os.makedirs(output_dir, exist_ok=True)
        scenarios = self.generate_all()

        # 1. scenarios.json
        json_path = os.path.join(output_dir, "scenarios.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump([s.to_dict() for s in scenarios], f, indent=2)

        # 2. ground_truth_labels.csv
        csv_path = os.path.join(output_dir, "ground_truth_labels.csv")
        fieldnames = [
            "session_id", "scenario_id", "category", "ground_truth_label",
            "expected_auth", "expected_b0", "expected_b1", "seed", "description"
        ]
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for s in scenarios:
                writer.writerow({
                    "session_id": s.session_id,
                    "scenario_id": s.scenario_id,
                    "category": s.category,
                    "ground_truth_label": s.ground_truth_label,
                    "expected_auth": s.expected_auth_result,
                    "expected_b0": s.expected_b0_label,
                    "expected_b1": s.expected_b1_label,
                    "seed": s.seed,
                    "description": s.description,
                })

        return scenarios


if __name__ == "__main__":
    gen = ScenarioGenerator()
    scs = gen.export_scenarios("experiments/evidence")
    print(f"[+] Generated {len(scs)} stratified scenarios with deterministic master seed {gen.master_seed}")
    from collections import Counter
    print("Categories:", Counter(s.category for s in scs))
    print("Ground truth:", Counter(s.ground_truth_label for s in scs))
