"""
Independent Scenario Oracle for SmartLocker Experimental Evaluation.
Generates 100 reproducible, independently pre-labeled sessions across 5 stratified categories:
- NORMAL_AUTHORIZED (20)
- UNAUTHORIZED_CREDENTIAL (20)
- FORCED_DOOR_OPEN (20)
- LOAD_OR_TAMPER_ANOMALY (20)
- SENSOR_FAULT (20)

Labels and expected outcomes are determined BEFORE execution by this oracle,
preventing any data leakage or circular labeling.
"""

from dataclasses import asdict, dataclass
import json
import random
from typing import Any, Dict, List, Optional


@dataclass
class ScenarioSpec:
    session_id: str
    scenario_id: str
    seed: int
    category: str  # NORMAL_AUTHORIZED, UNAUTHORIZED_CREDENTIAL, FORCED_DOOR_OPEN, LOAD_OR_TAMPER_ANOMALY, SENSOR_FAULT
    ground_truth_label: str
    auth_method: str  # PIN, CARD, FINGERPRINT, MOBILE
    credential: str
    slot_code: str
    bank_code: str
    expected_auth_result: str  # UNLOCK, DENY
    expected_b0_label: str  # NORMAL, UNAUTHORIZED, FORCED_OPEN, SUSPECTED_SPOOF, SENSOR_FAULT, MISSED
    expected_b1_label: str  # NORMAL, UNAUTHORIZED, FORCED_OPEN, TAMPER_ANOMALY, SENSOR_FAULT
    # Sensor telemetry parameters
    door_open_sec: float
    weight_delta_g: float
    rfid_ok: bool
    stay_min: float
    ultrasonic_dist_cm: float
    vibration_intensity: float
    tilt_deg: float
    fault_type: Optional[str] = None
    description: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class ScenarioOracle:
    """Independent oracle generating stratified scenarios with deterministic seeds."""

    VALID_PINS = [
        ("599901", "A01", "CANT-A"),
        ("918704", "A05", "CANT-A"),
        ("952705", "A04", "CANT-A"),
        ("320357", "A15", "CANT-A"),
        ("632262", "A03", "CANT-A"),
    ]

    INVALID_PINS = ["000000", "111111", "999999", "123123", "888888", "456789"]

    VALID_CARDS = ["04A1B2C3", "0499AABB", "04C3D4E5", "04F5A6B7", "04556677"]
    LOST_CARDS = ["04DE0012", "C15C039D", "C206670A", "04E1F205"]
    UNKNOWN_CARDS = ["04BAD001", "04BAD002", "04BAD003", "DEADBEEF"]

    def __init__(self, master_seed: int = 20261115):
        self.master_seed = master_seed
        self.rng = random.Random(master_seed)

    def generate_all_scenarios(self) -> List[ScenarioSpec]:
        """Generate exactly 100 stratified scenarios (20 per category)."""
        scenarios: List[ScenarioSpec] = []
        idx = 1

        # 1. NORMAL_AUTHORIZED (20 sessions: S001 - S020)
        for i in range(20):
            seed = self.rng.randint(100000, 999999)
            sub_rng = random.Random(seed)
            pin_info = sub_rng.choice(self.VALID_PINS)
            method = sub_rng.choice(["PIN", "CARD", "PIN"])
            cred = pin_info[0] if method == "PIN" else sub_rng.choice(self.VALID_CARDS)

            door_sec = round(sub_rng.uniform(4.5, 12.0), 2)
            weight_delta = round(sub_rng.uniform(-450.0, 450.0), 2)
            stay_min = round(sub_rng.uniform(5.0, 30.0), 1)

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-NORM-{i+1:02d}",
                seed=seed,
                category="NORMAL_AUTHORIZED",
                ground_truth_label="NORMAL_AUTHORIZED",
                auth_method=method,
                credential=cred,
                slot_code=pin_info[1],
                bank_code=pin_info[2],
                expected_auth_result="UNLOCK",
                expected_b0_label="NORMAL",
                expected_b1_label="NORMAL",
                door_open_sec=door_sec,
                weight_delta_g=weight_delta,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=round(sub_rng.uniform(15.0, 40.0), 1),
                vibration_intensity=round(sub_rng.uniform(0.01, 0.05), 3),
                tilt_deg=round(sub_rng.uniform(0.1, 0.8), 2),
                description=f"Normal authorized access using {method} on slot {pin_info[1]}",
            )
            scenarios.append(spec)
            idx += 1

        # 2. UNAUTHORIZED_CREDENTIAL (20 sessions: S021 - S040)
        for i in range(20):
            seed = self.rng.randint(100000, 999999)
            sub_rng = random.Random(seed)
            auth_type = sub_rng.choice(["WRONG_PIN", "LOST_CARD", "UNKNOWN_CARD"])

            if auth_type == "WRONG_PIN":
                method = "PIN"
                cred = sub_rng.choice(self.INVALID_PINS)
                desc = "Unauthorized access attempt with invalid 6-digit PIN"
            elif auth_type == "LOST_CARD":
                method = "CARD"
                cred = sub_rng.choice(self.LOST_CARDS)
                desc = "Unauthorized access attempt with reported LOST/BLOCKED card"
            else:
                method = "CARD"
                cred = sub_rng.choice(self.UNKNOWN_CARDS)
                desc = "Unauthorized access attempt with unknown/unregistered RFID card"

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-UNAUTH-{i+1:02d}",
                seed=seed,
                category="UNAUTHORIZED_CREDENTIAL",
                ground_truth_label="UNAUTHORIZED_CREDENTIAL",
                auth_method=method,
                credential=cred,
                slot_code="A01",
                bank_code="CANT-A",
                expected_auth_result="DENY",
                expected_b0_label="UNAUTHORIZED",
                expected_b1_label="UNAUTHORIZED",
                door_open_sec=0.0,
                weight_delta_g=0.0,
                rfid_ok=False,
                stay_min=0.0,
                ultrasonic_dist_cm=round(sub_rng.uniform(20.0, 50.0), 1),
                vibration_intensity=round(sub_rng.uniform(0.02, 0.08), 3),
                tilt_deg=round(sub_rng.uniform(0.1, 0.5), 2),
                description=desc,
            )
            scenarios.append(spec)
            idx += 1

        # 3. FORCED_DOOR_OPEN (20 sessions: S041 - S060)
        for i in range(20):
            seed = self.rng.randint(100000, 999999)
            sub_rng = random.Random(seed)
            forced_mechanism = sub_rng.choice(["PRY_DOOR", "RFID_BYPASS", "MECHANICAL_PICK"])

            door_sec = round(sub_rng.uniform(3.0, 15.0), 2)
            weight_delta = round(sub_rng.uniform(-300.0, 100.0), 2)
            vib = round(sub_rng.uniform(0.65, 2.2), 3)  # Heavy physical impact
            tilt = round(sub_rng.uniform(2.5, 8.0), 2)   # Physical door forced

            # Baseline B0 expects MISSED if pried without RFID; or FORCED_OPEN if rfid_ok=False in batch
            expected_b0 = "FORCED_OPEN" if forced_mechanism == "RFID_BYPASS" else "MISSED"

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-FORCE-{i+1:02d}",
                seed=seed,
                category="FORCED_DOOR_OPEN",
                ground_truth_label="FORCED_DOOR_OPEN",
                auth_method="PIN" if forced_mechanism != "RFID_BYPASS" else "CARD",
                credential="NO_AUTH" if forced_mechanism != "RFID_BYPASS" else "04BAD001",
                slot_code=f"A{sub_rng.randint(1, 15):02d}",
                bank_code="CANT-A",
                expected_auth_result="DENY",
                expected_b0_label=expected_b0,
                expected_b1_label="FORCED_OPEN",
                door_open_sec=door_sec,
                weight_delta_g=weight_delta,
                rfid_ok=False,
                stay_min=10.0,
                ultrasonic_dist_cm=round(sub_rng.uniform(10.0, 30.0), 1),
                vibration_intensity=vib,
                tilt_deg=tilt,
                description=f"Physical forced door opening via {forced_mechanism}",
            )
            scenarios.append(spec)
            idx += 1

        # 4. LOAD_OR_TAMPER_ANOMALY (20 sessions: S061 - S080)
        for i in range(20):
            seed = self.rng.randint(100000, 999999)
            sub_rng = random.Random(seed)
            tamper_type = sub_rng.choice(["WEIGHT_WHILE_LOCKED", "VIBRATION_DRILL", "TILT_ATTACK"])

            if tamper_type == "WEIGHT_WHILE_LOCKED":
                door_sec = 0.0
                weight_delta = round(sub_rng.choice([-600.0, -1200.0, 850.0, 1500.0]), 2)
                vib = round(sub_rng.uniform(0.08, 0.18), 3)
                tilt = round(sub_rng.uniform(0.2, 1.2), 2)
                expected_b0 = "SUSPECTED_SPOOF"  # B0 rule: door_open_sec==0 & weight > 50g -> SPOOF
                desc = "Weight changed while locker reported closed/locked"
            elif tamper_type == "VIBRATION_DRILL":
                door_sec = 0.0
                weight_delta = 0.0
                vib = round(sub_rng.uniform(0.55, 1.8), 3)  # Heavy drilling/hammering
                tilt = round(sub_rng.uniform(0.5, 2.0), 2)
                expected_b0 = "MISSED"  # B0 has no IMU sensor
                desc = "Tamper vibration/impact detected while locked"
            else:  # TILT_ATTACK
                door_sec = 0.0
                weight_delta = 0.0
                vib = round(sub_rng.uniform(0.3, 0.9), 3)
                tilt = round(sub_rng.uniform(5.5, 15.0), 2)  # Severe physical tilt
                expected_b0 = "MISSED"  # B0 has no IMU sensor
                desc = "Locker bank subjected to physical tilting/movement"

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-TAMPER-{i+1:02d}",
                seed=seed,
                category="LOAD_OR_TAMPER_ANOMALY",
                ground_truth_label="LOAD_OR_TAMPER_ANOMALY",
                auth_method="NONE",
                credential="NONE",
                slot_code=f"A{sub_rng.randint(1, 15):02d}",
                bank_code="CANT-A",
                expected_auth_result="DENY",
                expected_b0_label=expected_b0,
                expected_b1_label="TAMPER_ANOMALY",
                door_open_sec=door_sec,
                weight_delta_g=weight_delta,
                rfid_ok=True,
                stay_min=20.0,
                ultrasonic_dist_cm=round(sub_rng.uniform(40.0, 100.0), 1),
                vibration_intensity=vib,
                tilt_deg=tilt,
                description=desc,
            )
            scenarios.append(spec)
            idx += 1

        # 5. SENSOR_FAULT (20 sessions: S081 - S100)
        for i in range(20):
            seed = self.rng.randint(100000, 999999)
            sub_rng = random.Random(seed)
            fault_kind = sub_rng.choice([
                "WEIGHT_OUT_OF_RANGE",
                "DOOR_EXCEEDS_STAY",
                "ULTRASONIC_STUCK",
                "IMU_DROPOUT"
            ])

            if fault_kind == "WEIGHT_OUT_OF_RANGE":
                door_sec = 6.0
                weight_delta = sub_rng.choice([-5000.0, -9999.0, 35000.0])  # Beyond [-200, 20000]
                stay_min = 15.0
                expected_b0 = "SENSOR_FAULT"
                desc = f"Load-cell measurement out of valid range ({weight_delta} g)"
            elif fault_kind == "DOOR_EXCEEDS_STAY":
                stay_min = 1.0  # 60s
                door_sec = 180.0  # door open > stay_min * 60 + 5
                weight_delta = 0.0
                expected_b0 = "SENSOR_FAULT"
                desc = "Door open duration exceeds total session stay duration"
            elif fault_kind == "ULTRASONIC_STUCK":
                door_sec = 6.0
                weight_delta = 100.0
                stay_min = 10.0
                expected_b0 = "NORMAL"  # B0 does not consume ultrasonic sensor for fault classification
                desc = "Ultrasonic sensor stuck at 0.0 cm constant"
            else:  # IMU_DROPOUT
                door_sec = 5.0
                weight_delta = 50.0
                stay_min = 10.0
                expected_b0 = "NORMAL"  # B0 has no IMU
                desc = "IMU accelerometer sensor communication failure / NaN readings"

            spec = ScenarioSpec(
                session_id=f"SIM-SESS-{idx:03d}",
                scenario_id=f"SCEN-FAULT-{i+1:02d}",
                seed=seed,
                category="SENSOR_FAULT",
                ground_truth_label="SENSOR_FAULT",
                auth_method="PIN",
                credential="599901",
                slot_code="A01",
                bank_code="CANT-A",
                expected_auth_result="UNLOCK",
                expected_b0_label=expected_b0,
                expected_b1_label="SENSOR_FAULT",
                door_open_sec=door_sec,
                weight_delta_g=weight_delta,
                rfid_ok=True,
                stay_min=stay_min,
                ultrasonic_dist_cm=0.0 if fault_kind == "ULTRASONIC_STUCK" else 30.0,
                vibration_intensity=-1.0 if fault_kind == "IMU_DROPOUT" else 0.03,
                tilt_deg=-1.0 if fault_kind == "IMU_DROPOUT" else 0.4,
                fault_type=fault_kind,
                description=desc,
            )
            scenarios.append(spec)
            idx += 1

        return scenarios


if __name__ == "__main__":
    oracle = ScenarioOracle()
    scens = oracle.generate_all_scenarios()
    print(f"Generated {len(scens)} scenarios:")
    counts = {}
    for s in scens:
        counts[s.category] = counts.get(s.category, 0) + 1
    for cat, count in counts.items():
        print(f"  {cat}: {count}")
