"""
experiments/generator.py
Stratified Scenario & Imperfect Sensor Observation Generator (Direction B).

Generates >= 100 independent, reproducible, labeled experimental sessions
across 5 stratified categories (20 sessions each) using deterministic hierarchical seeds.

Methodology:
1. Defines latent physical action and operational intent FIRST.
2. Freezes canonical ground truth via ScenarioOracle BEFORE sensor observations are generated.
3. Generates observed signals using independent mathematical sensor models (sensor_models.py):
   - Measurement noise (Gaussian and sensor-specific)
   - Quantization (ADC step sizes)
   - Calibration drift
   - Transient outliers
   - Class-conditional distribution overlap
4. Zero detector leakage: Detector receives only observed values.
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
    LatentPhysicalAction,
    ScenarioCategory,
    ScenarioOracle,
    ScenarioSpec,
)
from experiments.sensor_models import (
    observe_load_cell,
    observe_reed_switch,
    observe_shock,
    observe_tilt,
    observe_ultrasonic,
    observe_vibration,
)


class ScenarioGenerator:
    """
    Stratified Scenario Generator producing reproducible sessions with
    independent ground truth and realistic, noisy sensor observation models.
    """

    # Valid Active Credentials in SL_SIM (CANT-A, device_id = 5)
    VALID_PINS = [
        ("952705", "A04", "CANT-A"),
    ]
    INVALID_PINS = ["000000", "111111", "999999", "123123", "888888", "456789"]

    VALID_CARDS = ["04A1B2C3", "0499AABB", "04C3D4E5", "04F5A6B7", "04556677"]
    CARD_SLOT_MAP = {
        "04A1B2C3": "A01",
        "0499AABB": "A02",
        "04C3D4E5": "A03",
        "04F5A6B7": "A06",
        "04556677": "A07",
    }
    BLOCKED_CARDS = ["04DE0012", "C15C039D", "C206670A", "04E1F205"]
    UNKNOWN_CARDS = ["04BAD001", "04BAD002", "04BAD003", "DEADBEEF"]

    VALID_FINGERPRINTS = [1, 2, 5]
    FP_SLOT_MAP = {
        "1": "A08",
        "2": "A09",
        "5": "A10",
    }
    INVALID_FINGERPRINTS = [3, 4, 7, 8, 9, 11]

    def __init__(self, master_seed: int = 42, total_sessions: int = 100):
        if total_sessions < 100:
            raise ValueError(f"Total sessions must be >= 100, got {total_sessions}")
        self.master_seed = master_seed
        self.total_sessions = total_sessions
        self.per_category = total_sessions // 5
        self.master_rng = random.Random(master_seed)

    def generate_all(self) -> List[ScenarioSpec]:
        """Generate all stratified scenarios with pre-assigned ground truth and noisy observations."""
        scenarios: List[ScenarioSpec] = []
        idx = 1

        # =====================================================================
        # 1. NORMAL_AUTHORIZED (20 sessions)
        # =====================================================================
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            mode = rng.choice(["PIN", "PIN", "CARD", "CARD", "FINGERPRINT"])
            if mode == "PIN":
                pin_info = rng.choice(self.VALID_PINS)
                cred, slot, bank = pin_info[0], pin_info[1], pin_info[2]
            elif mode == "CARD":
                cred = rng.choice(self.VALID_CARDS)
                slot = self.CARD_SLOT_MAP.get(cred, "A04")
                bank = "CANT-A"
            else:
                cred = str(rng.choice(self.VALID_FINGERPRINTS))
                slot = self.FP_SLOT_MAP.get(cred, "A03")
                bank = "CANT-A"

            latent_act = rng.choice([LatentPhysicalAction.NORMAL_DEPOSIT.value, LatentPhysicalAction.NORMAL_RETRIEVAL.value])
            gt_label = ScenarioOracle.assign_ground_truth(latent_act)

            # Latent physical signals
            latent_door = rng.uniform(4.0, 12.0)
            latent_weight = rng.uniform(-120.0, 400.0)
            stay_min = round(rng.uniform(5.0, 30.0), 1)
            latent_dist = rng.uniform(20.0, 45.0)

            # Realistic user behavior: ordinary usage produces 0.02 - 0.08g vibration,
            # but ~10% (e.g., indices 4 and 14) experience brisk door slam or bag drop
            # where door bounces shut and transient vibration is near the threshold
            is_slam = (i in (4, 14))
            if is_slam:
                latent_vib = rng.uniform(0.46, 0.49)
                latent_shock = rng.uniform(2.2, 3.8)
                latent_door = 0.0  # door bounced shut
            else:
                latent_vib = rng.uniform(0.02, 0.08)
                latent_shock = rng.uniform(0.95, 1.15)
            latent_tilt = rng.uniform(0.1, 0.8)

            # Imperfect sensor observations
            obs_door = observe_reed_switch(latent_door, rng)
            obs_weight = observe_load_cell(latent_weight, rng)
            obs_sonar = observe_ultrasonic(latent_dist, rng)
            obs_vib = observe_vibration(latent_vib, rng)
            obs_tilt = observe_tilt(latent_tilt, rng)
            obs_shock = observe_shock(latent_shock, rng)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-NORM-{i+1:02d}",
                seed=seed,
                latent_action=latent_act,
                category=ScenarioCategory.NORMAL_AUTHORIZED.value,
                ground_truth_label=gt_label,
                auth_method=mode,
                credential=cred,
                slot_code=slot,
                bank_code=bank,
                expected_auth_result="UNLOCK",
                door_open_sec=obs_door,
                weight_delta_g=obs_weight,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=obs_sonar,
                vibration_intensity=obs_vib,
                tilt_deg=obs_tilt,
                shock_mag_g=obs_shock,
                fault_type=None,
                description=f"Normal authorized access using {mode} {cred}",
                latent_door_sec=round(latent_door, 2),
                latent_weight_g=round(latent_weight, 2),
                latent_dist_cm=round(latent_dist, 1),
                latent_vib_g=round(latent_vib, 3),
                latent_tilt_deg=round(latent_tilt, 2),
                latent_shock_g=round(latent_shock, 2),
            )
            scenarios.append(spec)
            idx += 1

        # =====================================================================
        # 2. UNAUTHORIZED_CREDENTIAL (20 sessions)
        # =====================================================================
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            var = rng.choice(["WRONG_PIN", "BLOCKED_CARD", "UNKNOWN_CARD", "INVALID_FP"])
            if var == "WRONG_PIN":
                mode = "PIN"
                cred = rng.choice(self.INVALID_PINS)
                latent_act = LatentPhysicalAction.UNAUTHORIZED_WRONG_PIN.value
                desc = "Unauthorized access attempt with wrong PIN"
            elif var == "BLOCKED_CARD":
                mode = "CARD"
                cred = rng.choice(self.BLOCKED_CARDS)
                latent_act = LatentPhysicalAction.UNAUTHORIZED_BLOCKED_CARD.value
                desc = "Unauthorized access attempt with reported lost/blocked RFID card"
            elif var == "UNKNOWN_CARD":
                mode = "CARD"
                cred = rng.choice(self.UNKNOWN_CARDS)
                latent_act = LatentPhysicalAction.UNAUTHORIZED_UNKNOWN_CARD.value
                desc = "Unauthorized access attempt with unregistered RFID card"
            else:
                mode = "FINGERPRINT"
                cred = str(rng.choice(self.INVALID_FINGERPRINTS))
                latent_act = LatentPhysicalAction.UNAUTHORIZED_INVALID_FP.value
                desc = "Unauthorized access attempt with unregistered fingerprint"

            gt_label = ScenarioOracle.assign_ground_truth(latent_act)

            # In unauthorized attempt, door never opened -> latent door = 0.0, latent weight = 0.0
            latent_door = 0.0
            latent_weight = 0.0
            stay_min = round(rng.uniform(5.0, 20.0), 1)
            latent_dist = rng.uniform(20.0, 50.0)
            latent_vib = rng.uniform(0.01, 0.04)
            latent_tilt = rng.uniform(0.1, 0.4)
            latent_shock = rng.uniform(0.98, 1.02)

            obs_door = observe_reed_switch(latent_door, rng)
            obs_weight = observe_load_cell(latent_weight, rng)  # May have minor load-cell drift around 0g
            obs_sonar = observe_ultrasonic(latent_dist, rng)
            obs_vib = observe_vibration(latent_vib, rng)
            obs_tilt = observe_tilt(latent_tilt, rng)
            obs_shock = observe_shock(latent_shock, rng)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-UNAUTH-{i+1:02d}",
                seed=seed,
                latent_action=latent_act,
                category=ScenarioCategory.UNAUTHORIZED_CREDENTIAL.value,
                ground_truth_label=gt_label,
                auth_method=mode,
                credential=cred,
                slot_code="A04",
                bank_code="CANT-A",
                expected_auth_result="DENY",
                door_open_sec=obs_door,
                weight_delta_g=obs_weight,
                rfid_ok=False,
                stay_min=stay_min,
                ultrasonic_dist_cm=obs_sonar,
                vibration_intensity=obs_vib,
                tilt_deg=obs_tilt,
                shock_mag_g=obs_shock,
                fault_type=None,
                description=desc,
                latent_door_sec=0.0,
                latent_weight_g=0.0,
                latent_dist_cm=round(latent_dist, 1),
                latent_vib_g=round(latent_vib, 3),
                latent_tilt_deg=round(latent_tilt, 2),
                latent_shock_g=round(latent_shock, 2),
            )
            scenarios.append(spec)
            idx += 1

        # =====================================================================
        # 3. FORCED_DOOR_OPEN (20 sessions)
        # =====================================================================
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            mech = rng.choice(["CROWBAR_PRY", "LOCK_PICK", "DOOR_KICK"])
            stay_min = round(rng.uniform(10.0, 60.0), 1)
            latent_dist = rng.uniform(15.0, 45.0)

            # Realistic breach variation:
            # Subtle lock picking / jammed latch (indices 3 and 15) where door does not open
            is_jammed = (i in (3, 15))
            if is_jammed:
                latent_door = 0.0
                latent_weight = 0.0
                latent_act = LatentPhysicalAction.FORCED_LOCK_PICK.value
                latent_vib = rng.uniform(0.35, 0.43)
                latent_tilt = rng.uniform(0.5, 1.5)
                latent_shock = rng.uniform(1.2, 2.5)
                desc = "Physical lock pick attempt with stuck latch; door unbreached"
            elif mech == "CROWBAR_PRY":
                latent_door = rng.uniform(3.0, 16.0)
                latent_weight = rng.uniform(-150.0, 0.0)
                latent_act = LatentPhysicalAction.FORCED_CROWBAR_PRY.value
                latent_vib = rng.uniform(0.65, 1.80)
                latent_tilt = rng.uniform(3.5, 7.5)
                latent_shock = rng.uniform(11.0, 15.5)
                desc = "Physical door prying with crowbar without valid unlock"
            elif mech == "DOOR_KICK":
                latent_door = rng.uniform(3.0, 16.0)
                latent_weight = rng.uniform(-150.0, 0.0)
                latent_act = LatentPhysicalAction.FORCED_KICK_BREACH.value
                latent_vib = rng.uniform(1.10, 2.40)
                latent_tilt = rng.uniform(4.0, 8.5)
                latent_shock = rng.uniform(14.0, 22.0)
                desc = "Violent door breach with high-G mechanical impact shock"
            else:  # LOCK_PICK
                latent_door = rng.uniform(3.0, 16.0)
                latent_weight = rng.uniform(-150.0, 0.0)
                latent_act = LatentPhysicalAction.FORCED_LOCK_PICK.value
                latent_vib = rng.uniform(0.55, 0.95)
                latent_tilt = rng.uniform(0.8, 2.5)
                latent_shock = rng.uniform(3.5, 7.5)
                desc = "Physical door forced open via lock picking without authorization"

            gt_label = ScenarioOracle.assign_ground_truth(latent_act)

            obs_door = observe_reed_switch(latent_door, rng)
            obs_weight = observe_load_cell(latent_weight, rng)
            obs_sonar = observe_ultrasonic(latent_dist, rng)
            obs_vib = observe_vibration(latent_vib, rng)
            obs_tilt = observe_tilt(latent_tilt, rng)
            obs_shock = observe_shock(latent_shock, rng)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-FORCE-{i+1:02d}",
                seed=seed,
                latent_action=latent_act,
                category=ScenarioCategory.FORCED_DOOR_OPEN.value,
                ground_truth_label=gt_label,
                auth_method=AuthMethod.NONE.value,
                credential="NONE",
                slot_code="A04",
                bank_code="CANT-A",
                expected_auth_result="NONE",
                door_open_sec=obs_door,
                weight_delta_g=obs_weight,
                rfid_ok=False,
                stay_min=stay_min,
                ultrasonic_dist_cm=obs_sonar,
                vibration_intensity=obs_vib,
                tilt_deg=obs_tilt,
                shock_mag_g=obs_shock,
                fault_type=None,
                description=desc,
                latent_door_sec=round(latent_door, 2),
                latent_weight_g=round(latent_weight, 2),
                latent_dist_cm=round(latent_dist, 1),
                latent_vib_g=round(latent_vib, 3),
                latent_tilt_deg=round(latent_tilt, 2),
                latent_shock_g=round(latent_shock, 2),
            )
            scenarios.append(spec)
            idx += 1

        # =====================================================================
        # 4. LOAD_OR_TAMPER_ANOMALY (20 sessions)
        # =====================================================================
        for i in range(self.per_category):
            seed = self.master_rng.randint(100000, 999999)
            rng = random.Random(seed)

            tamper_type = rng.choice(["DRILL_VIBRATION", "STRUCTURAL_TILT", "SPOOF_WEIGHT_CLOSED", "HAMMER_SHOCK"])
            stay_min = round(rng.uniform(15.0, 120.0), 1)
            latent_dist = rng.uniform(30.0, 80.0)

            # In tampering while locked, door remains closed -> latent_door = 0.0
            latent_door = 0.0
            is_stealth = (i in (2, 8, 16))
            if is_stealth or tamper_type == "DRILL_VIBRATION":
                latent_act = LatentPhysicalAction.TAMPER_DRILL_VIBRATION.value
                latent_vib = rng.uniform(0.40, 0.44) if is_stealth else rng.uniform(0.55, 1.25)
                latent_tilt = rng.uniform(0.4, 2.2)
                latent_shock = rng.uniform(1.8, 4.8)
                latent_weight = 0.0
                desc = "Stealth low-RPM drilling near vibration threshold" if is_stealth else "Continuous power tool drilling vibration against locker frame while locked"
            elif tamper_type == "STRUCTURAL_TILT":
                latent_act = LatentPhysicalAction.TAMPER_STRUCTURAL_TILT.value
                latent_vib = rng.uniform(0.12, 0.38)
                latent_tilt = rng.uniform(4.5, 11.5)
                latent_shock = rng.uniform(1.2, 3.2)
                latent_weight = 0.0
                desc = "Locker cabinet displacement and tilt attack while door remains locked"
            elif tamper_type == "HAMMER_SHOCK":
                latent_act = LatentPhysicalAction.TAMPER_HAMMER_SHOCK.value
                latent_vib = rng.uniform(0.28, 0.75)
                latent_tilt = rng.uniform(0.8, 3.2)
                latent_shock = rng.uniform(17.0, 22.5)
                latent_weight = 0.0
                desc = "Heavy sledgehammer shock strike against locked locker door"
            else:  # SPOOF_WEIGHT_CLOSED
                latent_act = LatentPhysicalAction.TAMPER_WEIGHT_CLOSED.value
                latent_vib = rng.uniform(0.02, 0.08)
                latent_tilt = rng.uniform(0.1, 0.5)
                latent_shock = rng.uniform(0.98, 1.05)
                latent_weight = rng.choice([-1.0, 1.0]) * rng.uniform(55.0, 140.0)
                desc = "Weight alteration detected in slot while door was closed (suspected spoofing)"

            gt_label = ScenarioOracle.assign_ground_truth(latent_act)

            obs_door = observe_reed_switch(latent_door, rng)
            obs_weight = observe_load_cell(latent_weight, rng)
            obs_sonar = observe_ultrasonic(latent_dist, rng)
            obs_vib = observe_vibration(latent_vib, rng)
            obs_tilt = observe_tilt(latent_tilt, rng)
            obs_shock = observe_shock(latent_shock, rng)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-TAMPER-{i+1:02d}",
                seed=seed,
                latent_action=latent_act,
                category=ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value,
                ground_truth_label=gt_label,
                auth_method=AuthMethod.NONE.value,
                credential="NONE",
                slot_code="A04",
                bank_code="CANT-A",
                expected_auth_result="NONE",
                door_open_sec=obs_door,
                weight_delta_g=obs_weight,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=obs_sonar,
                vibration_intensity=obs_vib,
                tilt_deg=obs_tilt,
                shock_mag_g=obs_shock,
                fault_type=None,
                description=desc,
                latent_door_sec=0.0,
                latent_weight_g=round(latent_weight, 2),
                latent_dist_cm=round(latent_dist, 1),
                latent_vib_g=round(latent_vib, 3),
                latent_tilt_deg=round(latent_tilt, 2),
                latent_shock_g=round(latent_shock, 2),
            )
            scenarios.append(spec)
            idx += 1

        # =====================================================================
        # 5. SENSOR_OR_NETWORK_FAULT (20 sessions: 15 Sensor + 5 Network)
        # =====================================================================
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

            latent_door = 5.0
            latent_weight = 0.0
            stay_min = 10.0
            latent_dist = 30.0
            latent_vib = 0.03
            latent_tilt = 0.3
            latent_shock = 1.0
            net_latency = 25.0
            dup = False
            gap = False
            corrupt = False

            is_border = (i in (3, 7))
            if fault_kind == "WEIGHT_OUT_OF_RANGE":
                latent_act = LatentPhysicalAction.FAULT_WEIGHT_OUT_OF_RANGE.value
                latent_weight = -196.0 if is_border else rng.choice([-350.0, 24000.0])
                desc = "Sensor fault: Load cell thermal drift near ADC boundary" if is_border else "Sensor fault: Load cell ADC rail saturation out of valid physical range"
            elif fault_kind == "DOOR_EXCEEDS_STAY":
                latent_act = LatentPhysicalAction.FAULT_DOOR_EXCEEDS_STAY.value
                latent_door = 124.6 if is_border else 240.0
                stay_min = 2.0  # door boundary stay * 60 + 5 = 125s
                desc = "Sensor fault: Door duration near stay threshold boundary" if is_border else "Sensor fault: Door duration exceeds total booking stay time"
            elif fault_kind == "ULTRASONIC_STUCK":
                latent_act = LatentPhysicalAction.FAULT_ULTRASONIC_STUCK.value
                latent_dist = 0.0  # acoustic cutoff < 2cm
                desc = "Sensor fault: Ultrasonic transducer hardware stuck at 0cm cutoff"
            elif fault_kind == "IMU_DROPOUT":
                latent_act = LatentPhysicalAction.FAULT_IMU_DROPOUT.value
                latent_vib = -1.0  # I2C disconnect sentinel
                latent_tilt = -1.0
                latent_shock = 0.01
                desc = "Sensor fault: IMU accelerometer I2C bus disconnection"
            elif fault_kind == "NETWORK_TIMEOUT":
                latent_act = LatentPhysicalAction.FAULT_NETWORK_TIMEOUT.value
                net_latency = 6500.0  # > 5000ms timeout
                desc = "Network fault: Telemetry transmission timeout (6.5s latency)"
            else:  # NETWORK_DUPLICATE_REPLAY
                latent_act = LatentPhysicalAction.FAULT_NETWORK_DUPLICATE_REPLAY.value
                dup = True
                desc = "Network fault: Replay attack with duplicate non-monotonic sequence"

            gt_label = ScenarioOracle.assign_ground_truth(latent_act)

            obs_door = observe_reed_switch(latent_door, rng)
            obs_weight = observe_load_cell(latent_weight, rng)
            obs_sonar = observe_ultrasonic(latent_dist, rng)
            obs_vib = observe_vibration(latent_vib, rng)
            obs_tilt = observe_tilt(latent_tilt, rng)
            obs_shock = observe_shock(latent_shock, rng)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-FAULT-{i+1:02d}",
                seed=seed,
                latent_action=latent_act,
                category=ScenarioCategory.SENSOR_OR_NETWORK_FAULT.value,
                ground_truth_label=gt_label,
                auth_method=AuthMethod.NONE.value,
                credential="NONE",
                slot_code="A04",
                bank_code="CANT-A",
                expected_auth_result="NONE",
                door_open_sec=obs_door,
                weight_delta_g=obs_weight,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=obs_sonar,
                vibration_intensity=obs_vib,
                tilt_deg=obs_tilt,
                shock_mag_g=obs_shock,
                fault_type=fault_kind,
                network_latency_ms=net_latency,
                seq_duplicate=dup,
                seq_gap=gap,
                payload_corrupted=corrupt,
                description=desc,
                latent_door_sec=round(latent_door, 2),
                latent_weight_g=round(latent_weight, 2),
                latent_dist_cm=round(latent_dist, 1),
                latent_vib_g=round(latent_vib, 3),
                latent_tilt_deg=round(latent_tilt, 2),
                latent_shock_g=round(latent_shock, 2),
            )
            scenarios.append(spec)
            idx += 1

        return scenarios

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
            "session_id", "scenario_id", "category", "latent_action",
            "ground_truth_label", "expected_auth", "seed", "description"
        ]
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for s in scenarios:
                writer.writerow({
                    "session_id": s.session_id,
                    "scenario_id": s.scenario_id,
                    "category": s.category,
                    "latent_action": s.latent_action,
                    "ground_truth_label": s.ground_truth_label,
                    "expected_auth": s.expected_auth_result,
                    "seed": s.seed,
                    "description": s.description,
                })

        return scenarios


if __name__ == "__main__":
    gen = ScenarioGenerator(master_seed=42)
    scs = gen.export_scenarios("experiments/evidence")
    print(f"[+] Generated {len(scs)} stratified scenarios with master seed {gen.master_seed}")
    from collections import Counter
    print("Categories:", Counter(s.category for s in scs))
    print("Ground truth:", Counter(s.ground_truth_label for s in scs))
