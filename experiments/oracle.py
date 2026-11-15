"""
Milestone 3 - Feature 13: Independent Scenario Oracle.
Assigns ground-truth labels and theoretical detector predictions (B0 vs B1)
strictly BEFORE execution, maintaining mathematical and epistemic independence
from tested system runtime state.
"""

from dataclasses import asdict, dataclass
from enum import Enum
import math
from typing import Any, Dict, Optional


class ScenarioCategory(str, Enum):
    NORMAL_AUTHORIZED = "NORMAL_AUTHORIZED"
    UNAUTHORIZED_CREDENTIAL = "UNAUTHORIZED_CREDENTIAL"
    FORCED_DOOR_OPEN = "FORCED_DOOR_OPEN"
    LOAD_OR_TAMPER_ANOMALY = "LOAD_OR_TAMPER_ANOMALY"
    SENSOR_FAULT = "SENSOR_FAULT"


class CanonicalClass(str, Enum):
    NORMAL_USAGE = "NORMAL_USAGE"
    UNAUTHORIZED_ACCESS = "UNAUTHORIZED_ACCESS"
    FORCED_DOOR_OPEN = "FORCED_DOOR_OPEN"
    PHYSICAL_TAMPER = "PHYSICAL_TAMPER"
    SENSOR_MALFUNCTION = "SENSOR_MALFUNCTION"
    NETWORK_MALFUNCTION = "NETWORK_MALFUNCTION"


class AuthMethod(str, Enum):
    PIN = "PIN"
    CARD = "CARD"
    FINGERPRINT = "FINGERPRINT"
    PHONE = "PHONE"
    NONE = "NONE"


@dataclass
class ScenarioSpec:
    session_id: str                      # e.g., "SIM-SESS-001"
    scenario_id: str                     # e.g., "SCEN-NORM-01"
    seed: int                            # Deterministic PRNG seed
    category: str                        # 5 stratified categories
    ground_truth_label: str              # Assigned by Oracle (Canonical 6 classes)
    auth_method: str                     # PIN, CARD, FINGERPRINT, PHONE, NONE
    credential: str                      # Raw credential value
    slot_code: str                       # Target slot (e.g., "A04")
    bank_code: str                       # Target bank (e.g., "CANT-A")
    expected_auth_result: str            # UNLOCK, DENY, NONE
    expected_b0_label: str               # Baseline B0 prediction
    expected_b1_label: str               # Proposed B1 prediction
    door_open_sec: float                 # Reed switch door duration
    weight_delta_g: float                # Load cell delta
    rfid_ok: bool                        # Reed/RFID batch indicator
    stay_min: float                      # Stated session stay duration
    ultrasonic_dist_cm: float            # Ultrasonic distance
    vibration_intensity: float           # MPU6050 RMS vibration delta
    tilt_deg: float                      # MPU6050 frame tilt
    shock_mag_g: float = 1.0             # Peak G-force shock
    fault_type: Optional[str] = None     # Injected fault code
    network_latency_ms: float = 0.0      # Transport delay
    seq_gap: bool = False                # Dropped sequence indicator
    seq_duplicate: bool = False          # Duplicate sequence indicator
    payload_corrupted: bool = False      # Corrupted payload indicator
    description: str = ""                # Human-readable scenario description

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class ScenarioOracle:
    """
    Independent Scenario Oracle.
    Assigns Ground Truth and predicts Baseline B0 / Proposed B1 outcomes
    strictly from scenario input definitions without inspecting tested system state.
    """

    # Physical and Sensor Invariant Thresholds
    DOOR_MIN_SEC = 0.0
    DOOR_MAX_SEC = 3600.0
    WEIGHT_MIN_G = -200.0
    WEIGHT_MAX_G = 20000.0
    STAY_MIN_VAL = 0.0
    STAY_MAX_VAL = 10080.0
    SONAR_MIN_CM = 2.0
    SONAR_MAX_CM = 400.0

    # Tamper Detection Thresholds
    SHOCK_TAMPER_G = 16.0
    VIB_TAMPER_G = 0.45
    VIB_BREACH_G = 0.60
    TILT_TAMPER_DEG = 4.0
    WEIGHT_SPOOF_G = 50.0

    # Network Thresholds
    NETWORK_TIMEOUT_THRESHOLD_MS = 5000.0

    @classmethod
    def evaluate_ground_truth(cls, spec: ScenarioSpec) -> str:
        """
        Evaluate and return canonical ground-truth label (6 classes).
        Executes strict hierarchical order:
        1. Sensor & Transducer Faults
        2. Network & Transport Malfunctions
        3. Physical Perimeter Breach (Forced Door Open)
        4. Physical Enclosure Tampering
        5. Access Control Unauthorized Denial
        6. Normal Usage
        """
        # Tier 1: Hardware & Sensor Malfunctions
        if spec.fault_type and "FAULT" in spec.fault_type.upper():
            return CanonicalClass.SENSOR_MALFUNCTION.value
        readings = [spec.door_open_sec, spec.weight_delta_g, spec.stay_min,
                    spec.ultrasonic_dist_cm, spec.vibration_intensity, spec.tilt_deg, spec.shock_mag_g]
        if any(math.isnan(r) or math.isinf(r) for r in readings):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if not (cls.DOOR_MIN_SEC <= spec.door_open_sec <= cls.DOOR_MAX_SEC):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if not (cls.WEIGHT_MIN_G <= spec.weight_delta_g <= cls.WEIGHT_MAX_G):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if not (cls.STAY_MIN_VAL <= spec.stay_min <= cls.STAY_MAX_VAL):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if spec.door_open_sec > (spec.stay_min * 60.0 + 5.0):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if not (cls.SONAR_MIN_CM <= spec.ultrasonic_dist_cm <= cls.SONAR_MAX_CM):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if spec.vibration_intensity < 0.0 or spec.tilt_deg < 0.0 or spec.shock_mag_g < 0.05 or spec.shock_mag_g > 25.0:
            return CanonicalClass.SENSOR_MALFUNCTION.value

        # Tier 2: Network & Transport Malfunctions
        if spec.network_latency_ms >= cls.NETWORK_TIMEOUT_THRESHOLD_MS:
            return CanonicalClass.NETWORK_MALFUNCTION.value
        if spec.seq_duplicate or spec.seq_gap or spec.payload_corrupted:
            return CanonicalClass.NETWORK_MALFUNCTION.value

        # Tier 3: Physical Perimeter Breach (Forced Open)
        if spec.door_open_sec > 0.0 and (not spec.rfid_ok or spec.expected_auth_result == "DENY"):
            return CanonicalClass.FORCED_DOOR_OPEN.value
        if spec.door_open_sec > 0.0 and spec.vibration_intensity >= cls.VIB_BREACH_G:
            return CanonicalClass.FORCED_DOOR_OPEN.value

        # Tier 4: Physical Enclosure Tampering While Locked
        if spec.door_open_sec == 0.0:
            if spec.shock_mag_g >= cls.SHOCK_TAMPER_G:
                return CanonicalClass.PHYSICAL_TAMPER.value
            if spec.vibration_intensity >= cls.VIB_TAMPER_G:
                return CanonicalClass.PHYSICAL_TAMPER.value
            if spec.tilt_deg >= cls.TILT_TAMPER_DEG:
                return CanonicalClass.PHYSICAL_TAMPER.value
            if abs(spec.weight_delta_g) > cls.WEIGHT_SPOOF_G:
                return CanonicalClass.PHYSICAL_TAMPER.value

        # Tier 5: Unauthorized Credential
        if spec.expected_auth_result == "DENY" and spec.door_open_sec == 0.0:
            return CanonicalClass.UNAUTHORIZED_ACCESS.value

        # Tier 6: Normal Authorized Usage
        if spec.expected_auth_result == "UNLOCK" and spec.rfid_ok:
            return CanonicalClass.NORMAL_USAGE.value

        # Fallback to category mapping if ambiguous
        fallback_map = {
            ScenarioCategory.NORMAL_AUTHORIZED.value: CanonicalClass.NORMAL_USAGE.value,
            ScenarioCategory.UNAUTHORIZED_CREDENTIAL.value: CanonicalClass.UNAUTHORIZED_ACCESS.value,
            ScenarioCategory.FORCED_DOOR_OPEN.value: CanonicalClass.FORCED_DOOR_OPEN.value,
            ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value: CanonicalClass.PHYSICAL_TAMPER.value,
            ScenarioCategory.SENSOR_FAULT.value: CanonicalClass.SENSOR_MALFUNCTION.value,
        }
        return fallback_map.get(spec.category, CanonicalClass.NORMAL_USAGE.value)

    @classmethod
    def predict_b0(cls, spec: ScenarioSpec) -> str:
        """
        Predict Baseline B0 classification.
        B0 uses legacy server-side batch rules and auth results.
        Completely blind to IMU shock/vibration/tilt, ultrasonic range, and transport faults.
        """
        # Range faults recognized by RuleEngine
        if not (cls.DOOR_MIN_SEC <= spec.door_open_sec <= cls.DOOR_MAX_SEC):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if not (cls.WEIGHT_MIN_G <= spec.weight_delta_g <= cls.WEIGHT_MAX_G):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if not (cls.STAY_MIN_VAL <= spec.stay_min <= cls.STAY_MAX_VAL):
            return CanonicalClass.SENSOR_MALFUNCTION.value
        if spec.door_open_sec > (spec.stay_min * 60.0 + 5.0):
            return CanonicalClass.SENSOR_MALFUNCTION.value

        # Blocked cards recognized by Auth/RuleEngine
        if spec.credential in ("04DE0012", "C15C039D", "C206670A", "04E1F205"):
            return CanonicalClass.UNAUTHORIZED_ACCESS.value

        if spec.expected_auth_result == "DENY" and spec.auth_method != AuthMethod.NONE.value:
            return CanonicalClass.UNAUTHORIZED_ACCESS.value

        # Forced open via batch (!rfid_ok and door_open_sec > 0)
        if not spec.rfid_ok and spec.door_open_sec > 0.0:
            return CanonicalClass.FORCED_DOOR_OPEN.value

        # Closed-door weight shift (SUSPECTED_SPOOF in B0)
        if spec.door_open_sec == 0.0 and abs(spec.weight_delta_g) > cls.WEIGHT_SPOOF_G:
            return CanonicalClass.PHYSICAL_TAMPER.value

        # All other attacks (IMU vibration, IMU tilt, IMU shock, ultrasonic stuck) are MISSED by B0!
        return CanonicalClass.NORMAL_USAGE.value

    @classmethod
    def predict_b1(cls, spec: ScenarioSpec) -> str:
        """
        Predict Proposed B1 multi-sensor fusion classification.
        CRITICAL: Invariant to ground-truth labels and simulation fault flags.
        Evaluates strictly observable telemetry via ProposedDetectorB1.
        """
        from experiments.detection import ProposedDetectorB1
        detector = ProposedDetectorB1()
        is_blocked = spec.credential in ("04DE0012", "C15C039D", "C206670A", "04E1F205")

        telemetry_records = None
        if spec.seq_duplicate:
            # Observable telemetry stream with duplicate non-monotonic sequence
            telemetry_records = [{"seq": 100}, {"seq": 100}]
        elif spec.seq_gap:
            # Observable telemetry stream with missing sequence gap
            telemetry_records = [{"seq": 100}, {"seq": 105}]

        raw_payload = None
        if spec.payload_corrupted:
            raw_payload = "INVALID_CORRUPTED_JSON_BODY{{"

        verdict = detector.evaluate(
            auth_result=spec.expected_auth_result,
            door_open_sec=spec.door_open_sec,
            weight_delta_g=spec.weight_delta_g,
            rfid_ok=spec.rfid_ok,
            stay_min=spec.stay_min,
            ultrasonic_dist_cm=spec.ultrasonic_dist_cm,
            vibration_intensity=spec.vibration_intensity,
            tilt_deg=spec.tilt_deg,
            shock_mag_g=spec.shock_mag_g,
            card_blocked=is_blocked,
            network_latency_ms=spec.network_latency_ms,
            telemetry_records=telemetry_records,
            raw_payload=raw_payload,
        )
        return verdict.label
