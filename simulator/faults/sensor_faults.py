"""
Sensor and electrical fault simulation module.
Implements out-of-range anomalies, drift, stuck readings, Gaussian jitter, and non-finite floats.
"""

import math
import random
import time
from typing import Dict, Optional
from .config import SensorFaultConfig


class SensorFaultInjector:
    """Manages transducer-level faults for simulated sensors."""

    def __init__(
        self,
        sensor_configs: Optional[Dict[str, SensorFaultConfig]] = None,
        rng: Optional[random.Random] = None,
    ):
        self.configs = sensor_configs or {}
        self.rng = rng or random.Random()
        self.drift_accumulators: Dict[str, float] = {}
        self.last_drift_timestamps: Dict[str, float] = {}

    def set_rng(self, rng: random.Random) -> None:
        self.rng = rng

    def reset(self) -> None:
        """Reset internal drift accumulation state."""
        self.drift_accumulators.clear()
        self.last_drift_timestamps.clear()

    def inject(
        self,
        sensor_name: str,
        true_value: float,
        timestamp_sec: Optional[float] = None,
    ) -> float:
        """
        Apply configured sensor fault to the ground-truth reading.
        Returns the corrupted reading.
        """
        cfg = self.configs.get(sensor_name)
        if not cfg or not cfg.enabled or cfg.fault_type == "NONE":
            return true_value

        now = timestamp_sec if timestamp_sec is not None else time.time()
        fault = cfg.fault_type.upper()

        if fault == "OUT_OF_RANGE":
            if cfg.out_of_range_val is not None:
                return cfg.out_of_range_val
            # Fallback: extreme 100x multiplication
            return true_value * 100.0 if true_value != 0 else 99999.0

        elif fault == "DRIFT":
            last_t = self.last_drift_timestamps.get(sensor_name, now)
            dt = max(0.0, now - last_t)
            self.last_drift_timestamps[sensor_name] = now
            acc = self.drift_accumulators.get(sensor_name, 0.0) + (
                cfg.drift_rate_per_sec * dt
            )
            self.drift_accumulators[sensor_name] = acc
            return true_value + acc

        elif fault == "STUCK":
            if cfg.stuck_value is not None:
                return cfg.stuck_value
            return true_value

        elif fault == "JITTER":
            if cfg.noise_stddev > 0:
                noise = self.rng.gauss(0.0, cfg.noise_stddev)
                return true_value + noise
            return true_value

        elif fault == "NAN_INF":
            inf_type = cfg.nan_inf_type.upper()
            if inf_type == "INF":
                return float("inf")
            elif inf_type == "-INF":
                return float("-inf")
            return float("nan")

        return true_value
