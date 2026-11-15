"""
Multi-Sensor Anomaly Detection Module (Proposed B1).
Evaluates multi-sensor fusion across:
- Reed switch door-contact sensor
- Load cell weight measurement
- IMU accelerometer/gyroscope (vibration intensity and tilt angle)
- Ultrasonic SRF05 distance sensor
- Multi-modal authentication states

Contrasts with Baseline B0, which relies solely on server-side batch rules
without real-time physical tamper or asynchronous door monitoring.
"""

from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class DetectionVerdict:
    label: str  # NORMAL, UNAUTHORIZED, FORCED_OPEN, TAMPER_ANOMALY, SENSOR_FAULT
    confidence: float
    trigger_rule: str
    evidence: Dict[str, Any]
    is_anomaly: bool


class BaselineDetectorB0:
    """
    Baseline B0: Existing SmartLocker detection model.
    Only evaluates batch session upload rules and auth endpoint response.
    Has NO knowledge of IMU vibration/tilt or real-time idle door-contact state.
    """

    def evaluate(
        self,
        auth_result: str,
        door_open_sec: float,
        weight_delta_g: float,
        rfid_ok: bool,
        stay_min: float,
        card_blocked: bool = False,
    ) -> DetectionVerdict:
        # 1. Range fault checks
        if door_open_sec < 0 or door_open_sec > 3600:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B0_R1_DOOR_RANGE", {"door_open_sec": door_open_sec}, True)
        if weight_delta_g < -200 or weight_delta_g > 20000:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B0_R1_WEIGHT_RANGE", {"weight_delta_g": weight_delta_g}, True)
        if stay_min < 0 or stay_min > 10080:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B0_R1_STAY_RANGE", {"stay_min": stay_min}, True)
        if door_open_sec > stay_min * 60 + 5:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B0_R1_DOOR_GT_STAY", {"door_open_sec": door_open_sec, "stay_min": stay_min}, True)

        # 2. Blocked card
        if card_blocked:
            return DetectionVerdict("UNAUTHORIZED", 1.0, "B0_R3_LOST_CARD", {"card_blocked": True}, True)

        # 3. Auth failure
        if auth_result == "DENY":
            return DetectionVerdict("UNAUTHORIZED", 0.95, "B0_AUTH_DENY", {"auth_result": "DENY"}, True)

        # 4. Forced open via batch
        if not rfid_ok and door_open_sec > 0:
            return DetectionVerdict("FORCED_OPEN", 0.98, "B0_R4_FORCED_OPEN", {"rfid_ok": False, "door_open_sec": door_open_sec}, True)

        # 5. Weight changed while door closed
        if door_open_sec == 0 and abs(weight_delta_g) > 50.0:
            return DetectionVerdict("TAMPER_ANOMALY", 0.90, "B0_R6_SPOOF_WEIGHT", {"weight_delta_g": weight_delta_g}, True)

        return DetectionVerdict("NORMAL", 0.95, "B0_NORMAL", {}, False)


class ProposedDetectorB1:
    """
    Proposed B1: Multi-Sensor Enhanced Detection Model.
    Evaluates multi-sensor fusion:
    1. Sensor validity and health (Load-cell, Reed switch, Ultrasonic, IMU)
    2. Authentication outcomes
    3. Asynchronous door-contact breach (Reed switch + IMU shock)
    4. Tamper vibration and tilt while locked (IMU)
    5. In-slot load discrepancy while locked (Load cell)
    6. Normal authorized access verification
    """

    # Thresholds
    VIB_TAMPER_THRESHOLD_G = 0.45
    VIB_BREACH_THRESHOLD_G = 0.60
    TILT_TAMPER_THRESHOLD_DEG = 4.0
    WEIGHT_SPOOF_THRESHOLD_G = 50.0
    ULTRASONIC_MIN_VALID_CM = 2.0
    ULTRASONIC_MAX_VALID_CM = 400.0

    def evaluate(
        self,
        auth_result: str,
        door_open_sec: float,
        weight_delta_g: float,
        rfid_ok: bool,
        stay_min: float,
        ultrasonic_dist_cm: float,
        vibration_intensity: float,
        tilt_deg: float,
        card_blocked: bool = False,
        fault_type: Optional[str] = None,
    ) -> DetectionVerdict:
        # Tier 1: Sensor Fault & Sanity Verification
        if fault_type is not None and "FAULT" in fault_type.upper():
            return DetectionVerdict("SENSOR_FAULT", 1.0, f"B1_FAULT_{fault_type}", {"fault_type": fault_type}, True)

        if door_open_sec < 0 or door_open_sec > 3600:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B1_DOOR_RANGE_FAULT", {"door_open_sec": door_open_sec}, True)
        if weight_delta_g < -200 or weight_delta_g > 20000:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B1_WEIGHT_RANGE_FAULT", {"weight_delta_g": weight_delta_g}, True)
        if stay_min < 0 or stay_min > 10080:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B1_STAY_RANGE_FAULT", {"stay_min": stay_min}, True)
        if door_open_sec > stay_min * 60 + 5:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B1_DOOR_GT_STAY_FAULT", {"door_open_sec": door_open_sec}, True)

        # IMU Sensor Dropout / Negative Reading Fault
        if vibration_intensity < 0.0 or tilt_deg < 0.0:
            return DetectionVerdict("SENSOR_FAULT", 1.0, "B1_IMU_DROPOUT_FAULT", {"vibration": vibration_intensity, "tilt": tilt_deg}, True)

        # Ultrasonic Sensor Stuck / Out of Range
        if ultrasonic_dist_cm < self.ULTRASONIC_MIN_VALID_CM or ultrasonic_dist_cm > self.ULTRASONIC_MAX_VALID_CM:
            return DetectionVerdict("SENSOR_FAULT", 0.98, "B1_SONAR_STUCK_FAULT", {"ultrasonic_dist_cm": ultrasonic_dist_cm}, True)

        # Tier 2: Credential & Access Control Verification
        if card_blocked:
            return DetectionVerdict("UNAUTHORIZED", 1.0, "B1_LOST_CARD_USED", {"card_blocked": True}, True)
        if auth_result == "DENY" and door_open_sec == 0:
            return DetectionVerdict("UNAUTHORIZED", 0.98, "B1_AUTH_DENIED", {"auth_result": "DENY"}, True)

        # Tier 3: Physical Breach / Forced Door Opening
        # Condition A: Door opened without valid RFID / Auth
        if not rfid_ok and door_open_sec > 0:
            return DetectionVerdict("FORCED_OPEN", 0.99, "B1_FORCED_DOOR_UNAUTHORIZED", {"door_open_sec": door_open_sec, "rfid_ok": False}, True)
        # Condition B: High vibration impact accompanied by door opening
        if door_open_sec > 0 and vibration_intensity >= self.VIB_BREACH_THRESHOLD_G:
            return DetectionVerdict("FORCED_OPEN", 0.99, "B1_FORCED_DOOR_IMPACT", {"vibration": vibration_intensity, "door_open_sec": door_open_sec}, True)

        # Tier 4: Physical Tampering While Locked
        if door_open_sec == 0:
            # Significant vibration (drilling / hammering)
            if vibration_intensity >= self.VIB_TAMPER_THRESHOLD_G:
                return DetectionVerdict("TAMPER_ANOMALY", 0.96, "B1_TAMPER_VIBRATION", {"vibration": vibration_intensity}, True)
            # Severe tilt (prying / displacement)
            if tilt_deg >= self.TILT_TAMPER_THRESHOLD_DEG:
                return DetectionVerdict("TAMPER_ANOMALY", 0.96, "B1_TAMPER_TILT", {"tilt_deg": tilt_deg}, True)
            # In-slot weight change while door reported closed
            if abs(weight_delta_g) > self.WEIGHT_SPOOF_THRESHOLD_G:
                return DetectionVerdict("TAMPER_ANOMALY", 0.95, "B1_TAMPER_WEIGHT_LOCKED", {"weight_delta_g": weight_delta_g}, True)

        # Tier 5: Normal Authorized Operation
        return DetectionVerdict("NORMAL", 0.98, "B1_NORMAL_OPERATION", {}, False)
