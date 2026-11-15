"""
Magnetic door contact reed switch emulator.
Models binary open/closed circuit contact and calculates physical door open duration.
"""

import math
import time
from typing import Any, Dict, Optional
from .base import BaseSensor


class ReedSwitchSensor(BaseSensor):
    """
    Emulates a magnetic reed switch detecting physical door open/close events.
    Binary state: 0 = OPEN, 1 = CLOSED.
    Valid door open duration range: [0.0, 3600.0] seconds.
    """

    STATE_OPEN = 0
    STATE_CLOSED = 1

    def __init__(self, seed: Optional[int] = None):
        super().__init__(seed=seed)
        self._state: int = self.STATE_CLOSED
        self._opened_at: Optional[float] = None
        self._last_duration: float = 0.0

    @property
    def name(self) -> str:
        return "reed_switch"

    @property
    def unit(self) -> str:
        return "s"

    @property
    def min_valid(self) -> float:
        return 0.0

    @property
    def max_valid(self) -> float:
        return 3600.0

    @property
    def state(self) -> int:
        return self._state

    @property
    def is_door_open(self) -> bool:
        return self._state == self.STATE_OPEN

    @property
    def is_door_closed(self) -> bool:
        return self._state == self.STATE_CLOSED

    def open_door(self, timestamp: Optional[float] = None) -> None:
        """Record door opened event."""
        self._state = self.STATE_OPEN
        self._opened_at = timestamp if timestamp is not None else time.time()

    def close_door(self, timestamp: Optional[float] = None) -> float:
        """Record door closed event and calculate elapsed open duration in seconds."""
        now = timestamp if timestamp is not None else time.time()
        if self._opened_at is not None:
            duration = max(0.0, now - self._opened_at)
        else:
            duration = 0.0
        self._state = self.STATE_CLOSED
        self._opened_at = None
        self._last_duration = round(duration, 2)
        return self._last_duration

    def sample_duration(
        self,
        target_sec: Optional[float] = None,
        noise_stddev: float = 0.2,
    ) -> float:
        """
        Generate a realistic simulated door open duration.
        Defaults to Gaussian distribution (mean 6.5s, std 1.5s).
        """
        if target_sec is None:
            mean_sec = 6.5
            std_sec = 1.5
            duration = max(0.5, self.rng.gauss(mean_sec, std_sec))
        else:
            duration = float(target_sec)
            if noise_stddev > 0 and not (math.isnan(duration) or math.isinf(duration)):
                duration = max(0.0, duration + self.rng.gauss(0.0, noise_stddev))

        if not (math.isnan(duration) or math.isinf(duration)):
            duration = round(duration, 2)
        return duration

    def sample(self, *args, **kwargs) -> Dict[str, Any]:
        """Sample current state dictionary."""
        return {
            "state": self._state,
            "door_open": self.is_door_open,
            "door_open_sec": self._last_duration,
        }
