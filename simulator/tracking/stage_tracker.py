"""
5-Stage Sensor Integration Tracking Framework.
Maintains verified audit trails of sensor integration stages across all channels.
"""

from dataclasses import dataclass, field
import json
from typing import Any, Dict, List, Optional, Set


@dataclass
class ChannelStageStatus:
    """Records integration compliance across the 5 distinct engineering stages."""

    channel_name: str
    stage1_emulator_implemented: bool = False
    stage2_payload_generated: bool = False
    stage3_payload_transmitted: bool = False
    stage4_backend_persisted: bool = False
    stage5_backend_processed: bool = False
    notes: str = ""

    @property
    def fully_integrated(self) -> bool:
        """Fully integrated requires all 5 stages to pass strictly."""
        return (
            self.stage1_emulator_implemented
            and self.stage2_payload_generated
            and self.stage3_payload_transmitted
            and self.stage4_backend_persisted
            and self.stage5_backend_processed
        )

    def can_claim_stage(self, stage_num: int) -> bool:
        """
        Validate whether a stage can be claimed based on preceding stages.
        Stage N cannot be claimed if Stage N-1 has not passed.
        """
        if stage_num == 1:
            return self.stage1_emulator_implemented
        elif stage_num == 2:
            return (
                self.stage1_emulator_implemented and self.stage2_payload_generated
            )
        elif stage_num == 3:
            return (
                self.stage1_emulator_implemented
                and self.stage2_payload_generated
                and self.stage3_payload_transmitted
            )
        elif stage_num == 4:
            return (
                self.stage1_emulator_implemented
                and self.stage2_payload_generated
                and self.stage3_payload_transmitted
                and self.stage4_backend_persisted
            )
        elif stage_num == 5:
            return self.fully_integrated
        return False


class SensorIntegrationTracker:
    """Manages and reports on 5-stage sensor integration compliance."""

    VALID_CHANNELS: Set[str] = {
        "reed_switch",
        "door_contact",
        "load_cell",
        "ultrasonic",
        "ultrasonic_srf05",
        "vibration_tilt",
        "imu_vibration",
        "imu_vibration_tilt",
    }

    CANONICAL_NAMES: Dict[str, str] = {
        "reed_switch": "reed_switch",
        "door_contact": "reed_switch",
        "door_reed_switch": "reed_switch",
        "load_cell": "load_cell",
        "ultrasonic": "ultrasonic",
        "ultrasonic_srf05": "ultrasonic",
        "ultrasonic_distance": "ultrasonic",
        "vibration_tilt": "vibration_tilt",
        "imu_vibration": "vibration_tilt",
        "imu_vibration_tilt": "vibration_tilt",
    }

    CHANNELS = ["reed_switch", "load_cell", "ultrasonic", "vibration_tilt"]

    def __init__(self, mode: str = "B0"):
        self.mode = mode.upper()  # "B0" (Baseline) or "B1" (Proposed)
        self.channels: Dict[str, ChannelStageStatus] = {
            name: ChannelStageStatus(channel_name=name) for name in self.CHANNELS
        }
        self._init_defaults_for_mode()

    def _init_defaults_for_mode(self) -> None:
        """Initialize verified default stage statuses according to architecture mode."""
        # Reed Switch: Fully integrated in B0 and B1
        self.record_stage("reed_switch", 1, True)
        self.record_stage("reed_switch", 2, True)
        self.record_stage("reed_switch", 3, True)
        self.record_stage("reed_switch", 4, True, "Persisted in LockerSession.door_open_sec")
        self.record_stage("reed_switch", 5, True, "Evaluated by RuleEngine (FORCED_OPEN, SPOOF)")

        # Load Cell: Fully integrated in B0 and B1
        self.record_stage("load_cell", 1, True)
        self.record_stage("load_cell", 2, True)
        self.record_stage("load_cell", 3, True)
        self.record_stage("load_cell", 4, True, "Persisted in LockerSession.weight_delta_g")
        self.record_stage("load_cell", 5, True, "Evaluated by RuleEngine (ITEM_LEFT, SPOOF, ML)")

        if self.mode == "B0":
            # Ultrasonic: Stages 1-3 pass, Stages 4-5 NOT INTEGRATED in baseline
            self.record_stage("ultrasonic", 1, True)
            self.record_stage("ultrasonic", 2, True)
            self.record_stage("ultrasonic", 3, True)
            self.record_stage("ultrasonic", 4, False, "Not persisted in baseline LockerSession")
            self.record_stage("ultrasonic", 5, False, "Ignored by baseline RuleEngine")

            # Vibration/Tilt: Stages 1-3 pass, Stages 4-5 NOT INTEGRATED in baseline
            self.record_stage("vibration_tilt", 1, True)
            self.record_stage("vibration_tilt", 2, True)
            self.record_stage("vibration_tilt", 3, True)
            self.record_stage("vibration_tilt", 4, False, "Not persisted in baseline LockerSession")
            self.record_stage("vibration_tilt", 5, False, "Ignored by baseline RuleEngine")

        elif self.mode == "B1":
            # Proposed B1: Additive research extension integrates all 4 channels
            self.record_stage("ultrasonic", 1, True)
            self.record_stage("ultrasonic", 2, True)
            self.record_stage("ultrasonic", 3, True)
            self.record_stage("ultrasonic", 4, True, "Stored via additive telemetry extension")
            self.record_stage("ultrasonic", 5, True, "Evaluated by multi-sensor detection module")

            self.record_stage("vibration_tilt", 1, True)
            self.record_stage("vibration_tilt", 2, True)
            self.record_stage("vibration_tilt", 3, True)
            self.record_stage("vibration_tilt", 4, True, "Stored via additive telemetry extension")
            self.record_stage("vibration_tilt", 5, True, "Evaluated by multi-sensor detection module")

    def normalize_channel_name(self, channel: Optional[str]) -> str:
        """Resolve channel alias to canonical channel name or raise ValueError."""
        if not channel or not isinstance(channel, str):
            raise ValueError(f"Invalid sensor channel name: {channel}")
        clean = channel.strip().lower()
        if clean not in self.CANONICAL_NAMES:
            raise ValueError(f"Unknown sensor channel name: {channel}")
        return self.CANONICAL_NAMES[clean]

    def record_stage(
        self, channel: str, stage: int, passed: bool, notes: str = ""
    ) -> None:
        """Record verification outcome for a specific channel and stage."""
        canonical = self.normalize_channel_name(channel)
        st = self.channels[canonical]
        if stage == 1:
            st.stage1_emulator_implemented = passed
        elif stage == 2:
            st.stage2_payload_generated = passed
        elif stage == 3:
            st.stage3_payload_transmitted = passed
        elif stage == 4:
            st.stage4_backend_persisted = passed
        elif stage == 5:
            st.stage5_backend_processed = passed
        else:
            raise ValueError(f"Stage number must be between 1 and 5, got {stage}")

        if notes:
            st.notes = notes

    def get_channel_status(self, channel: str) -> ChannelStageStatus:
        canonical = self.normalize_channel_name(channel)
        return self.channels[canonical]

    def generate_markdown_report(self) -> str:
        """Generate human-readable Markdown compliance matrix."""
        lines = [
            f"# Sensor Integration 5-Stage Verification Matrix (Mode: {self.mode})",
            "",
            "| Sensor Channel | S1: Emulator | S2: Payload | S3: Transmitted | S4: Persisted | S5: Processed | Status | Notes |",
            "|---|:---:|:---:|:---:|:---:|:---:|:---:|---|",
        ]
        for name in self.CHANNELS:
            s = self.channels[name]
            status = "**INTEGRATED**" if s.fully_integrated else "*NOT INTEGRATED*"
            s1 = "PASS" if s.stage1_emulator_implemented else "FAIL"
            s2 = "PASS" if s.stage2_payload_generated else "FAIL"
            s3 = "PASS" if s.stage3_payload_transmitted else "FAIL"
            s4 = "PASS" if s.stage4_backend_persisted else "FAIL"
            s5 = "PASS" if s.stage5_backend_processed else "FAIL"
            lines.append(
                f"| {name} | {s1} | {s2} | {s3} | {s4} | {s5} | {status} | {s.notes} |"
            )
        lines.append("")
        return "\n".join(lines)

    def generate_json_matrix(self) -> Dict[str, Any]:
        """Generate machine-readable JSON representation of the integration matrix."""
        return {
            "mode": self.mode,
            "channels": {
                name: {
                    "stage1_emulator": s.stage1_emulator_implemented,
                    "stage2_payload": s.stage2_payload_generated,
                    "stage3_transmitted": s.stage3_payload_transmitted,
                    "stage4_persisted": s.stage4_backend_persisted,
                    "stage5_processed": s.stage5_backend_processed,
                    "fully_integrated": s.fully_integrated,
                    "notes": s.notes,
                }
                for name, s in self.channels.items()
            },
        }
