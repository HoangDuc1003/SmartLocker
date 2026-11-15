"""
Abstract base class for software sensor emulators.
Models physical transduction, operating bounds, and deterministic PRNG noise.
"""

from abc import ABC, abstractmethod
import math
import random
from typing import Any, Optional


class BaseSensor(ABC):
    """Abstract interface for all hardware-free software sensor models."""

    def __init__(self, seed: Optional[int] = None):
        self.seed = seed
        self.rng = random.Random(seed)

    def reseed(self, seed: int) -> None:
        """Reseed internal PRNG deterministically."""
        self.seed = seed
        self.rng = random.Random(seed)

    @property
    @abstractmethod
    def name(self) -> str:
        """Name of the sensor model."""
        pass

    @property
    @abstractmethod
    def unit(self) -> str:
        """Unit of measurement (e.g. cm, s, g, m/s^2)."""
        pass

    @property
    @abstractmethod
    def min_valid(self) -> float:
        """Minimum valid operating calibration limit."""
        pass

    @property
    @abstractmethod
    def max_valid(self) -> float:
        """Maximum valid operating calibration limit."""
        pass

    def is_in_valid_range(self, val: float) -> bool:
        """Check if reading is within calibrated operating boundaries and finite."""
        if math.isnan(val) or math.isinf(val):
            return False
        return self.min_valid <= val <= self.max_valid

    @abstractmethod
    def sample(self, *args, **kwargs) -> Any:
        """Sample a simulated sensor reading."""
        pass
