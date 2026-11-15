"""
experiments/detection.py
Multi-Sensor Anomaly & Tamper Detection Module (Features 12 & 17).

Provides:
- DetectionVerdict: Standardized structured classification result.
- BaselineDetectorB0: Legacy SmartLocker server-side rule engine model.
- ProposedDetectorB1: Enhanced Multi-Sensor Fusion detection engine.

Distinguishes 6 canonical classes:
1. NORMAL_USAGE
2. UNAUTHORIZED_ACCESS
3. FORCED_DOOR_OPEN
4. PHYSICAL_TAMPER
5. SENSOR_MALFUNCTION
6. NETWORK_MALFUNCTION
"""

from dataclasses import dataclass, field
import json
import math
from typing import Any, Dict, List, Optional


@dataclass
class DetectionVerdict:
    """Standardized detection decision."""
    label: str               # One of the 6 canonical classes
    confidence: float        # Decision confidence score in [0.0, 1.0]
    trigger_rule: str        # Formal rule identifier that generated verdict
    evidence: Dict[str, Any] = field(default_factory=dict)
    is_anomaly: bool = False # Binary anomaly indicator (True if label != NORMAL_USAGE)


class BaselineDetectorB0:
    """
    Baseline B0: Existing SmartLocker detection architecture.
    Evaluates only batch session telemetry and auth response.
    Completely blind to IMU vibration/shock/tilt, ultrasonic range, and transport faults.
    """

    LABEL_NORMAL = "NORMAL_USAGE"
    LABEL_UNAUTHORIZED = "UNAUTHORIZED_ACCESS"
    LABEL_FORCED_OPEN = "FORCED_DOOR_OPEN"
    LABEL_PHYSICAL_TAMPER = "PHYSICAL_TAMPER"
    LABEL_SENSOR_MALFUNCTION = "SENSOR_MALFUNCTION"

    def evaluate(
        self,
        auth_result: str,
        door_open_sec: float,
        weight_delta_g: float,
        rfid_ok: bool,
        stay_min: float,
        card_blocked: bool = False,
    ) -> DetectionVerdict:
        # 1. Valid range sanity check (RuleEngine findSensorFault)
        if door_open_sec < 0.0 or door_open_sec > 3600.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B0_R1_DOOR_RANGE",
                {"door_open_sec": door_open_sec}, True
            )
        if weight_delta_g < -200.0 or weight_delta_g > 20000.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B0_R1_WEIGHT_RANGE",
                {"weight_delta_g": weight_delta_g}, True
            )
        if stay_min < 0.0 or stay_min > 10080.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B0_R1_STAY_RANGE",
                {"stay_min": stay_min}, True
            )
        if door_open_sec > stay_min * 60.0 + 5.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B0_R1_DOOR_GT_STAY",
                {"door_open_sec": door_open_sec, "stay_min": stay_min}, True
            )

        # 2. Blocked card check
        if card_blocked:
            return DetectionVerdict(
                self.LABEL_UNAUTHORIZED, 1.0, "B0_R3_LOST_CARD",
                {"card_blocked": True}, True
            )

        # 3. Auth credential denial
        if auth_result in ("DENY", "ERROR"):
            return DetectionVerdict(
                self.LABEL_UNAUTHORIZED, 0.95, "B0_AUTH_DENY",
                {"auth_result": auth_result}, True
            )

        # 4. Forced door breach (batch indicator)
        if not rfid_ok and door_open_sec > 0.0:
            return DetectionVerdict(
                self.LABEL_FORCED_OPEN, 0.98, "B0_R4_FORCED_OPEN",
                {"rfid_ok": False, "door_open_sec": door_open_sec}, True
            )

        # 5. Closed-door weight shift (SUSPECTED_SPOOF in B0)
        if door_open_sec == 0.0 and abs(weight_delta_g) > 50.0:
            return DetectionVerdict(
                self.LABEL_PHYSICAL_TAMPER, 0.90, "B0_R6_SPOOF_WEIGHT",
                {"weight_delta_g": weight_delta_g}, True
            )

        # 6. Default Normal
        return DetectionVerdict(self.LABEL_NORMAL, 0.95, "B0_NORMAL", {}, False)


class ProposedDetectorB1:
    """
    Proposed B1: Enhanced Multi-Sensor Fusion Detection Architecture.
    Fuses Reed switch, Load cell, Ultrasonic SRF05, MPU6050 IMU, and Network telemetry.
    Executes 6-tier hierarchical priority resolution.
    Operates STRICTLY on observable features without ground-truth simulation leakage.
    """

    # Physical Threshold Constants
    SHOCK_THRESHOLD_G = 16.0              # Physical impact shock (156.96 m/s^2)
    VIB_TAMPER_THRESHOLD_G = 0.45         # Continuous drilling/sawing vibration
    VIB_BREACH_THRESHOLD_G = 0.60         # Forced entry mechanical shock
    TILT_TAMPER_THRESHOLD_DEG = 4.0       # Enclosure frame tilt / prying angle
    WEIGHT_SPOOF_THRESHOLD_G = 50.0       # In-slot load alteration threshold
    ULTRASONIC_MIN_VALID_CM = 2.0         # Acoustic cutoff lower boundary
    ULTRASONIC_MAX_VALID_CM = 400.0       # Acoustic cutoff upper boundary
    NETWORK_TIMEOUT_THRESHOLD_MS = 5000.0 # Transport socket timeout threshold

    # Canonical Labels
    LABEL_NORMAL = "NORMAL_USAGE"
    LABEL_UNAUTHORIZED = "UNAUTHORIZED_ACCESS"
    LABEL_FORCED_OPEN = "FORCED_DOOR_OPEN"
    LABEL_PHYSICAL_TAMPER = "PHYSICAL_TAMPER"
    LABEL_SENSOR_MALFUNCTION = "SENSOR_MALFUNCTION"
    LABEL_NETWORK_MALFUNCTION = "NETWORK_MALFUNCTION"

    def __init__(self) -> None:
        self._last_seq: Optional[int] = None

    def reset_sequence(self, initial_seq: Optional[int] = None) -> None:
        """Reset sequence tracker state for a new session or device stream."""
        self._last_seq = initial_seq

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
        shock_mag_g: float = 1.0,
        card_blocked: bool = False,
        network_latency_ms: float = 0.0,
        packet_seq: Optional[int] = None,
        telemetry_records: Optional[List[Dict[str, Any]]] = None,
        raw_payload: Optional[Any] = None,
    ) -> DetectionVerdict:
        """
        Evaluate full sensor telemetry and return unambiguous detection verdict.
        STRICTLY observable inputs only. No ground-truth or test-generator flags.
        """
        # =====================================================================
        # TIER 1: Hardware & Transducer Malfunction Check
        # =====================================================================
        # Non-finite floating point checks
        readings = [door_open_sec, weight_delta_g, stay_min, ultrasonic_dist_cm, vibration_intensity, tilt_deg, shock_mag_g]
        if any(math.isnan(r) or math.isinf(r) for r in readings):
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B1_NON_FINITE_FLOAT",
                {"readings": readings}, True
            )

        # Transducer physical bounds
        if door_open_sec < 0.0 or door_open_sec > 3600.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B1_DOOR_RANGE_FAULT",
                {"door_open_sec": door_open_sec}, True
            )
        if weight_delta_g < -200.0 or weight_delta_g > 20000.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B1_WEIGHT_RANGE_FAULT",
                {"weight_delta_g": weight_delta_g}, True
            )
        if stay_min < 0.0 or stay_min > 10080.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B1_STAY_RANGE_FAULT",
                {"stay_min": stay_min}, True
            )
        if door_open_sec > stay_min * 60.0 + 5.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B1_DOOR_GT_STAY_FAULT",
                {"door_open_sec": door_open_sec, "stay_min": stay_min}, True
            )

        # Ultrasonic cutoff / acoustic blindness
        if ultrasonic_dist_cm < self.ULTRASONIC_MIN_VALID_CM or ultrasonic_dist_cm > self.ULTRASONIC_MAX_VALID_CM:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 0.98, "B1_SONAR_STUCK_FAULT",
                {"ultrasonic_dist_cm": ultrasonic_dist_cm}, True
            )

        # IMU Bus dropout / rail clipping
        if vibration_intensity < 0.0 or tilt_deg < 0.0 or shock_mag_g < 0.05 or shock_mag_g > 25.0:
            return DetectionVerdict(
                self.LABEL_SENSOR_MALFUNCTION, 1.0, "B1_IMU_DROPOUT_FAULT",
                {"vibration": vibration_intensity, "tilt": tilt_deg, "shock": shock_mag_g}, True
            )

        # =====================================================================
        # TIER 2: Network & Transport Malfunction Check
        # =====================================================================
        # Observable transport delay check
        if network_latency_ms >= self.NETWORK_TIMEOUT_THRESHOLD_MS:
            return DetectionVerdict(
                self.LABEL_NETWORK_MALFUNCTION, 0.99, "B1_NET_TIMEOUT",
                {"network_latency_ms": network_latency_ms}, True
            )

        # Observable payload syntax / schema corruption check
        if raw_payload is not None:
            if isinstance(raw_payload, (bytes, bytearray)):
                try:
                    raw_str = raw_payload.decode("utf-8")
                    json.loads(raw_str)
                except Exception as ex:
                    return DetectionVerdict(
                        self.LABEL_NETWORK_MALFUNCTION, 1.0, "B1_NET_PAYLOAD_CORRUPT",
                        {"error": str(ex)}, True
                    )
            elif isinstance(raw_payload, str):
                try:
                    json.loads(raw_payload)
                except Exception as ex:
                    return DetectionVerdict(
                        self.LABEL_NETWORK_MALFUNCTION, 1.0, "B1_NET_PAYLOAD_CORRUPT",
                        {"error": str(ex)}, True
                    )

        # Observable sequence checking from telemetry records
        if telemetry_records is not None:
            prev_seq = self._last_seq
            for rec in telemetry_records:
                if not isinstance(rec, dict):
                    return DetectionVerdict(
                        self.LABEL_NETWORK_MALFUNCTION, 1.0, "B1_NET_PAYLOAD_CORRUPT",
                        {"record": str(rec)}, True
                    )
                if "seq" in rec and isinstance(rec["seq"], int):
                    current_seq = rec["seq"]
                    if prev_seq is not None:
                        if current_seq <= prev_seq:
                            return DetectionVerdict(
                                self.LABEL_NETWORK_MALFUNCTION, 0.99, "B1_NET_DUPLICATE_REPLAY",
                                {"seq": current_seq, "last_seq": prev_seq}, True
                            )
                        elif current_seq > prev_seq + 1:
                            return DetectionVerdict(
                                self.LABEL_NETWORK_MALFUNCTION, 0.95, "B1_NET_PACKET_LOSS_GAP",
                                {"seq": current_seq, "expected_seq": prev_seq + 1}, True
                            )
                    prev_seq = current_seq
            self._last_seq = prev_seq

        # Observable single packet sequence monotonicity check
        if packet_seq is not None and telemetry_records is None:
            if self._last_seq is not None:
                if packet_seq <= self._last_seq:
                    return DetectionVerdict(
                        self.LABEL_NETWORK_MALFUNCTION, 0.99, "B1_NET_DUPLICATE_REPLAY",
                        {"packet_seq": packet_seq, "last_seq": self._last_seq}, True
                    )
                elif packet_seq > self._last_seq + 1:
                    return DetectionVerdict(
                        self.LABEL_NETWORK_MALFUNCTION, 0.95, "B1_NET_PACKET_LOSS_GAP",
                        {"packet_seq": packet_seq, "expected_seq": self._last_seq + 1}, True
                    )
            self._last_seq = packet_seq

        # =====================================================================
        # TIER 3: Physical Perimeter Breach (FORCED_DOOR_OPEN)
        # =====================================================================
        # Condition A: Door opened without legitimate unlock auth
        if not rfid_ok and door_open_sec > 0.0:
            return DetectionVerdict(
                self.LABEL_FORCED_OPEN, 0.99, "B1_FORCED_DOOR_UNAUTHORIZED",
                {"door_open_sec": door_open_sec, "rfid_ok": False}, True
            )
        # Condition B: High mechanical shock accompanied by door opening
        if door_open_sec > 0.0 and vibration_intensity >= self.VIB_BREACH_THRESHOLD_G:
            return DetectionVerdict(
                self.LABEL_FORCED_OPEN, 0.99, "B1_FORCED_DOOR_IMPACT",
                {"vibration": vibration_intensity, "door_open_sec": door_open_sec}, True
            )

        # =====================================================================
        # TIER 4: Physical Enclosure Tampering While Locked
        # =====================================================================
        if door_open_sec == 0.0:
            # Extreme physical shock (hammer/crowbar strike)
            if shock_mag_g >= self.SHOCK_THRESHOLD_G:
                return DetectionVerdict(
                    self.LABEL_PHYSICAL_TAMPER, 0.99, "B1_TAMPER_SHOCK_IMPACT",
                    {"shock_mag_g": shock_mag_g}, True
                )
            # Continuous drilling/sawing vibration
            if vibration_intensity >= self.VIB_TAMPER_THRESHOLD_G:
                return DetectionVerdict(
                    self.LABEL_PHYSICAL_TAMPER, 0.96, "B1_TAMPER_VIBRATION",
                    {"vibration": vibration_intensity}, True
                )
            # Severe frame tilt / prying angle
            if tilt_deg >= self.TILT_TAMPER_THRESHOLD_DEG:
                return DetectionVerdict(
                    self.LABEL_PHYSICAL_TAMPER, 0.96, "B1_TAMPER_TILT",
                    {"tilt_deg": tilt_deg}, True
                )
            # In-slot weight change while door reported closed
            if abs(weight_delta_g) > self.WEIGHT_SPOOF_THRESHOLD_G:
                return DetectionVerdict(
                    self.LABEL_PHYSICAL_TAMPER, 0.95, "B1_TAMPER_WEIGHT_LOCKED",
                    {"weight_delta_g": weight_delta_g}, True
                )

        # =====================================================================
        # TIER 5: Access Control Authorization (UNAUTHORIZED_ACCESS)
        # =====================================================================
        if card_blocked:
            return DetectionVerdict(
                self.LABEL_UNAUTHORIZED, 1.0, "B1_LOST_CARD_USED",
                {"card_blocked": True}, True
            )
        if auth_result in ("DENY", "ERROR"):
            return DetectionVerdict(
                self.LABEL_UNAUTHORIZED, 0.98, "B1_AUTH_DENIED",
                {"auth_result": auth_result}, True
            )

        # =====================================================================
        # TIER 6: Normal Authorized Usage (NORMAL_USAGE)
        # =====================================================================
        return DetectionVerdict(self.LABEL_NORMAL, 0.98, "B1_NORMAL_OPERATION", {}, False)
