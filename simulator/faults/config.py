"""
Fault Injection Configuration Schema.
Defines parameters for deterministic pseudo-random seeding, network faults, and sensor faults.
"""

from dataclasses import dataclass, field
from typing import Dict, Optional


@dataclass
class NetworkFaultConfig:
    """Configuration for simulated transport and network layer anomalies."""

    enabled: bool = False
    packet_drop_rate: float = 0.0          # Drop probability [0.0, 1.0]
    delay_mean_ms: float = 0.0             # Mean transmission latency in ms
    delay_std_ms: float = 0.0              # Gaussian latency standard deviation in ms
    min_delay_ms: float = 0.0              # Minimum bounded latency in ms
    max_delay_ms: float = 0.0              # Maximum bounded latency in ms
    jitter_ms: float = 0.0                 # Jitter bound in ms
    timeout_threshold_ms: float = 5000.0   # HTTP timeout threshold in ms
    duplicate_seq_prob: float = 0.0        # Probability of replaying previous sequence number
    corrupt_payload_prob: float = 0.0      # Probability of mutating payload JSON
    corruption_mode: str = "FIELD_DROP"    # "SYNTAX", "FIELD_DROP", "TYPE_MUTATION", "INVALID_BANK", "BITFLIP"

    def validate(self) -> None:
        """Validate network fault configuration constraints."""
        if not (0.0 <= self.packet_drop_rate <= 1.0):
            raise ValueError(f"packet_drop_rate must be in [0.0, 1.0], got {self.packet_drop_rate}")
        if self.delay_mean_ms < 0 or self.delay_std_ms < 0:
            raise ValueError("Delays must be non-negative")
        if self.min_delay_ms < 0 or self.max_delay_ms < 0 or self.jitter_ms < 0:
            raise ValueError("Boundary delays and jitter must be non-negative")
        if self.min_delay_ms > self.max_delay_ms and self.max_delay_ms > 0:
            raise ValueError("min_delay_ms cannot exceed max_delay_ms")
        if not (0.0 <= self.duplicate_seq_prob <= 1.0):
            raise ValueError(f"duplicate_seq_prob must be in [0.0, 1.0], got {self.duplicate_seq_prob}")
        if not (0.0 <= self.corrupt_payload_prob <= 1.0):
            raise ValueError(f"corrupt_payload_prob must be in [0.0, 1.0], got {self.corrupt_payload_prob}")


@dataclass
class SensorFaultConfig:
    """Configuration for simulated sensor-level electrical and transducer anomalies."""

    enabled: bool = False
    sensor_name: str = ""                  # e.g. "load_cell", "reed_switch", "ultrasonic", "vibration_tilt"
    fault_type: str = "NONE"               # "OUT_OF_RANGE", "DRIFT", "STUCK", "JITTER", "NAN_INF"
    out_of_range_val: Optional[float] = None
    drift_rate_per_sec: float = 0.0        # Systematic additive drift per second
    stuck_value: Optional[float] = None    # Frozen static reading
    noise_stddev: float = 0.0              # Standard deviation of Gaussian jitter
    nan_inf_type: str = "NAN"              # "NAN", "INF", "-INF"


@dataclass
class FaultConfig:
    """Overall fault injector configuration with deterministic seed."""

    seed: int = 42
    network: NetworkFaultConfig = field(default_factory=NetworkFaultConfig)
    sensors: Dict[str, SensorFaultConfig] = field(default_factory=dict)

    def validate(self) -> None:
        """Validate all sub-configurations."""
        if not isinstance(self.seed, int):
            raise ValueError(f"seed must be an integer, got {type(self.seed)}")
        self.network.validate()
