"""
Coordinator module for deterministic fault injection.
Encapsulates isolated pseudo-random generators to guarantee bit-for-bit reproducibility.
"""

import random
from typing import Any, Dict, Optional, Tuple
from .config import FaultConfig
from .network_faults import NetworkFaultInjector
from .sensor_faults import SensorFaultInjector


class FaultInjector:
    """Deterministic fault injector coordinating network and sensor fault generation."""

    def __init__(self, config: Optional[FaultConfig] = None):
        self.config = config or FaultConfig()
        self.net_injector = NetworkFaultInjector(self.config.network)
        self.sensor_injector = SensorFaultInjector(self.config.sensors)
        self.reseed(self.config.seed)

    def reseed(self, seed: int) -> None:
        """Deterministically reseed internal pseudo-random number generators."""
        self.config.seed = seed
        # Derive independent isolated PRNG streams
        self.net_rng = random.Random(seed ^ 0x5A5A5A5A)
        self.sensor_rng = random.Random(seed ^ 0xA5A5A5A5)

        self.net_injector.set_rng(self.net_rng)
        self.sensor_injector.set_rng(self.sensor_rng)
        self.sensor_injector.reset()

    # Network Faults Forwarding
    def should_drop_packet(self) -> bool:
        return self.net_injector.should_drop_packet()

    def get_transmission_delay_sec(self) -> float:
        return self.net_injector.get_transmission_delay_sec()

    def is_timeout(self, delay_sec: float) -> bool:
        return self.net_injector.is_timeout(delay_sec)

    def should_duplicate_seq(self) -> bool:
        return self.net_injector.should_duplicate_seq()

    def corrupt_payload(self, payload: Dict[str, Any]) -> Tuple[Any, bool]:
        return self.net_injector.corrupt_payload(payload)

    # Sensor Faults Forwarding
    def inject_sensor_reading(
        self,
        sensor_name: str,
        true_value: float,
        timestamp_sec: Optional[float] = None,
    ) -> float:
        return self.sensor_injector.inject(
            sensor_name, true_value, timestamp_sec=timestamp_sec
        )
