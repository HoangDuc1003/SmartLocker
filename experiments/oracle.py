"""
experiments/oracle.py
Independent Scenario Oracle & Latent Physical Action Ground-Truth Specification.

Assigns canonical ground-truth labels strictly BEFORE execution and BEFORE
sensor observation generation, maintaining mathematical and epistemic independence
from tested system runtime state, sensor thresholds, and detector logic.

Strictly adheres to Direction B requirements:
1. No detector imports or calls.
2. Ground truth assigned directly from latent physical action, not measured sensor values.
3. No shared classification thresholds with ProposedDetectorB1.
4. Mathematical mapping from 6 canonical classes to 5 evaluation categories.
"""

from dataclasses import asdict, dataclass
from enum import Enum
from typing import Any, Dict, Optional


class ScenarioCategory(str, Enum):
    """Five stratified evaluation categories for the 100-session campaign."""
    NORMAL_AUTHORIZED = "NORMAL_AUTHORIZED"
    UNAUTHORIZED_CREDENTIAL = "UNAUTHORIZED_CREDENTIAL"
    FORCED_DOOR_OPEN = "FORCED_DOOR_OPEN"
    LOAD_OR_TAMPER_ANOMALY = "LOAD_OR_TAMPER_ANOMALY"
    SENSOR_OR_NETWORK_FAULT = "SENSOR_OR_NETWORK_FAULT"
    SENSOR_FAULT = "SENSOR_OR_NETWORK_FAULT"  # Backward-compatible alias


class CanonicalClass(str, Enum):
    """Six canonical ground-truth action classes."""
    NORMAL_USAGE = "NORMAL_USAGE"
    UNAUTHORIZED_ACCESS = "UNAUTHORIZED_ACCESS"
    FORCED_DOOR_OPEN = "FORCED_DOOR_OPEN"
    PHYSICAL_TAMPER = "PHYSICAL_TAMPER"
    SENSOR_MALFUNCTION = "SENSOR_MALFUNCTION"
    NETWORK_MALFUNCTION = "NETWORK_MALFUNCTION"


class LatentPhysicalAction(str, Enum):
    """Underlying latent physical action in the real world."""
    NORMAL_DEPOSIT = "NORMAL_DEPOSIT"
    NORMAL_RETRIEVAL = "NORMAL_RETRIEVAL"
    UNAUTHORIZED_WRONG_PIN = "UNAUTHORIZED_WRONG_PIN"
    UNAUTHORIZED_BLOCKED_CARD = "UNAUTHORIZED_BLOCKED_CARD"
    UNAUTHORIZED_UNKNOWN_CARD = "UNAUTHORIZED_UNKNOWN_CARD"
    UNAUTHORIZED_INVALID_FP = "UNAUTHORIZED_INVALID_FP"
    FORCED_CROWBAR_PRY = "FORCED_CROWBAR_PRY"
    FORCED_KICK_BREACH = "FORCED_KICK_BREACH"
    FORCED_LOCK_PICK = "FORCED_LOCK_PICK"
    TAMPER_DRILL_VIBRATION = "TAMPER_DRILL_VIBRATION"
    TAMPER_STRUCTURAL_TILT = "TAMPER_STRUCTURAL_TILT"
    TAMPER_HAMMER_SHOCK = "TAMPER_HAMMER_SHOCK"
    TAMPER_WEIGHT_CLOSED = "TAMPER_WEIGHT_CLOSED"
    FAULT_WEIGHT_OUT_OF_RANGE = "FAULT_WEIGHT_OUT_OF_RANGE"
    FAULT_DOOR_EXCEEDS_STAY = "FAULT_DOOR_EXCEEDS_STAY"
    FAULT_ULTRASONIC_STUCK = "FAULT_ULTRASONIC_STUCK"
    FAULT_IMU_DROPOUT = "FAULT_IMU_DROPOUT"
    FAULT_NETWORK_TIMEOUT = "FAULT_NETWORK_TIMEOUT"
    FAULT_NETWORK_DUPLICATE_REPLAY = "FAULT_NETWORK_DUPLICATE_REPLAY"
    FAULT_NETWORK_PACKET_LOSS = "FAULT_NETWORK_PACKET_LOSS"
    FAULT_NETWORK_PAYLOAD_CORRUPT = "FAULT_NETWORK_PAYLOAD_CORRUPT"


class AuthMethod(str, Enum):
    PIN = "PIN"
    CARD = "CARD"
    FINGERPRINT = "FINGERPRINT"
    PHONE = "PHONE"
    NONE = "NONE"


# Explicit, reproducible mapping from Canonical Ground Truth to 5 Evaluation Categories
CANONICAL_TO_EVALUATION_MAP: Dict[str, str] = {
    CanonicalClass.NORMAL_USAGE.value: ScenarioCategory.NORMAL_AUTHORIZED.value,
    CanonicalClass.UNAUTHORIZED_ACCESS.value: ScenarioCategory.UNAUTHORIZED_CREDENTIAL.value,
    CanonicalClass.FORCED_DOOR_OPEN.value: ScenarioCategory.FORCED_DOOR_OPEN.value,
    CanonicalClass.PHYSICAL_TAMPER.value: ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value,
    CanonicalClass.SENSOR_MALFUNCTION.value: ScenarioCategory.SENSOR_OR_NETWORK_FAULT.value,
    CanonicalClass.NETWORK_MALFUNCTION.value: ScenarioCategory.SENSOR_OR_NETWORK_FAULT.value,
}


@dataclass
class ScenarioSpec:
    """Complete specification of an experimental session."""
    session_id: str                      # e.g., "SIM-SESS-001"
    scenario_id: str                     # e.g., "SCEN-NORM-01"
    seed: int                            # Deterministic PRNG seed
    latent_action: str = ""              # One of LatentPhysicalAction
    category: str = ""                   # 5 stratified evaluation categories
    ground_truth_label: str = ""         # Assigned by Oracle (Canonical 6 classes)
    auth_method: str = "NONE"            # PIN, CARD, FINGERPRINT, PHONE, NONE
    credential: str = "NONE"             # Raw credential value
    slot_code: str = "A04"               # Target slot (e.g., "A04")
    bank_code: str = "CANT-A"            # Target bank (e.g., "CANT-A")
    expected_auth_result: str = "NONE"   # UNLOCK, DENY, NONE
    expected_b0_label: str = ""          # Legacy test harness compatibility
    expected_b1_label: str = ""          # Legacy test harness compatibility
    door_open_sec: float = 0.0           # Observed reed switch door duration
    weight_delta_g: float = 0.0          # Observed load cell delta
    rfid_ok: bool = True                 # Reed/RFID batch indicator
    stay_min: float = 10.0               # Stated session stay duration
    ultrasonic_dist_cm: float = 30.0     # Observed ultrasonic distance
    vibration_intensity: float = 0.02    # Observed MPU6050 RMS vibration delta
    tilt_deg: float = 0.2                # Observed MPU6050 frame tilt
    shock_mag_g: float = 1.0             # Observed peak G-force shock
    fault_type: Optional[str] = None     # Fault code if simulated
    network_latency_ms: float = 0.0      # Transport delay
    seq_gap: bool = False                # Dropped sequence indicator
    seq_duplicate: bool = False          # Duplicate sequence indicator
    payload_corrupted: bool = False      # Corrupted payload indicator
    description: str = ""                # Human-readable scenario description

    # Latent (un-noised) physical states for scientific traceability
    latent_door_sec: float = 0.0
    latent_weight_g: float = 0.0
    latent_dist_cm: float = 30.0
    latent_vib_g: float = 0.02
    latent_tilt_deg: float = 0.2
    latent_shock_g: float = 1.0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class ScenarioOracle:
    """
    Independent Scenario Oracle.
    Assigns Ground Truth strictly from the Latent Physical Action.
    Maintains zero knowledge of detector implementation, thresholds, or predictions.
    """

    LATENT_TO_CANONICAL: Dict[str, CanonicalClass] = {
        LatentPhysicalAction.NORMAL_DEPOSIT.value: CanonicalClass.NORMAL_USAGE,
        LatentPhysicalAction.NORMAL_RETRIEVAL.value: CanonicalClass.NORMAL_USAGE,
        LatentPhysicalAction.UNAUTHORIZED_WRONG_PIN.value: CanonicalClass.UNAUTHORIZED_ACCESS,
        LatentPhysicalAction.UNAUTHORIZED_BLOCKED_CARD.value: CanonicalClass.UNAUTHORIZED_ACCESS,
        LatentPhysicalAction.UNAUTHORIZED_UNKNOWN_CARD.value: CanonicalClass.UNAUTHORIZED_ACCESS,
        LatentPhysicalAction.UNAUTHORIZED_INVALID_FP.value: CanonicalClass.UNAUTHORIZED_ACCESS,
        LatentPhysicalAction.FORCED_CROWBAR_PRY.value: CanonicalClass.FORCED_DOOR_OPEN,
        LatentPhysicalAction.FORCED_KICK_BREACH.value: CanonicalClass.FORCED_DOOR_OPEN,
        LatentPhysicalAction.FORCED_LOCK_PICK.value: CanonicalClass.FORCED_DOOR_OPEN,
        LatentPhysicalAction.TAMPER_DRILL_VIBRATION.value: CanonicalClass.PHYSICAL_TAMPER,
        LatentPhysicalAction.TAMPER_STRUCTURAL_TILT.value: CanonicalClass.PHYSICAL_TAMPER,
        LatentPhysicalAction.TAMPER_HAMMER_SHOCK.value: CanonicalClass.PHYSICAL_TAMPER,
        LatentPhysicalAction.TAMPER_WEIGHT_CLOSED.value: CanonicalClass.PHYSICAL_TAMPER,
        LatentPhysicalAction.FAULT_WEIGHT_OUT_OF_RANGE.value: CanonicalClass.SENSOR_MALFUNCTION,
        LatentPhysicalAction.FAULT_DOOR_EXCEEDS_STAY.value: CanonicalClass.SENSOR_MALFUNCTION,
        LatentPhysicalAction.FAULT_ULTRASONIC_STUCK.value: CanonicalClass.SENSOR_MALFUNCTION,
        LatentPhysicalAction.FAULT_IMU_DROPOUT.value: CanonicalClass.SENSOR_MALFUNCTION,
        LatentPhysicalAction.FAULT_NETWORK_TIMEOUT.value: CanonicalClass.NETWORK_MALFUNCTION,
        LatentPhysicalAction.FAULT_NETWORK_DUPLICATE_REPLAY.value: CanonicalClass.NETWORK_MALFUNCTION,
        LatentPhysicalAction.FAULT_NETWORK_PACKET_LOSS.value: CanonicalClass.NETWORK_MALFUNCTION,
        LatentPhysicalAction.FAULT_NETWORK_PAYLOAD_CORRUPT.value: CanonicalClass.NETWORK_MALFUNCTION,
    }

    @classmethod
    def assign_ground_truth(cls, latent_action: str) -> str:
        """
        Assign canonical ground-truth label strictly from latent physical action.
        No detector thresholds, no sensor readings, no circular logic.
        """
        canonical = cls.LATENT_TO_CANONICAL.get(latent_action)
        if canonical is None:
            raise ValueError(f"Unknown latent physical action: {latent_action}")
        return canonical.value

    @classmethod
    def evaluate_ground_truth(cls, spec: ScenarioSpec) -> str:
        """
        Wrapper for assigning ground truth from latent_action.
        Fallback to category mapping if latent_action is not specified.
        """
        if getattr(spec, "latent_action", None):
            return cls.assign_ground_truth(spec.latent_action)
        fallback = {
            ScenarioCategory.NORMAL_AUTHORIZED.value: CanonicalClass.NORMAL_USAGE.value,
            ScenarioCategory.UNAUTHORIZED_CREDENTIAL.value: CanonicalClass.UNAUTHORIZED_ACCESS.value,
            ScenarioCategory.FORCED_DOOR_OPEN.value: CanonicalClass.FORCED_DOOR_OPEN.value,
            ScenarioCategory.LOAD_OR_TAMPER_ANOMALY.value: CanonicalClass.PHYSICAL_TAMPER.value,
            ScenarioCategory.SENSOR_OR_NETWORK_FAULT.value: CanonicalClass.SENSOR_MALFUNCTION.value,
            "SENSOR_FAULT": CanonicalClass.SENSOR_MALFUNCTION.value,
        }
        return fallback.get(spec.category, CanonicalClass.NORMAL_USAGE.value)

    @classmethod
    def map_to_evaluation_category(cls, canonical_label: str) -> str:
        """Map canonical 6-class label to 5-class evaluation category."""
        category = CANONICAL_TO_EVALUATION_MAP.get(canonical_label)
        if category is None:
            raise ValueError(f"Unknown canonical label: {canonical_label}")
        return category
