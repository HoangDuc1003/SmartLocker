"""
Load cell HX711 24-bit ADC weight sensor emulator.
Models strain-gauge resistance changes, tare calibration, and weight delta calculations.
"""

import math
from typing import Any, Dict, Optional
from .base import BaseSensor


class LoadCellSensor(BaseSensor):
    """
    Emulates an HX711 24-bit ADC load cell amplifier.
    Valid calibration range: [-200.0, 20000.0] grams.
    Maximum physical overload boundary: 50000.0 grams.
    Item left / suspected spoof threshold: 50.0 grams.
    """

    MIN_CALIBRATION_G = -200.0
    MAX_CALIBRATION_G = 20000.0
    OVERLOAD_LIMIT_G = 50000.0
    SPOOF_ITEM_THRESHOLD_G = 50.0

    def __init__(self, seed: Optional[int] = None):
        super().__init__(seed=seed)
        self._tare_offset_g: float = 0.0
        self._current_gross_g: float = 0.0
        self._pre_access_g: float = 0.0
        self._post_access_g: float = 0.0

    @property
    def name(self) -> str:
        return "load_cell"

    @property
    def unit(self) -> str:
        return "g"

    @property
    def min_valid(self) -> float:
        return self.MIN_CALIBRATION_G

    @property
    def max_valid(self) -> float:
        return self.MAX_CALIBRATION_G

    def is_in_valid_range(self, val: float) -> bool:
        if math.isnan(val) or math.isinf(val):
            return False
        return self.MIN_CALIBRATION_G <= val <= self.OVERLOAD_LIMIT_G

    def tare(self, baseline_gross_g: float = 0.0) -> None:
        """Calibrate zero point (tare)."""
        self._tare_offset_g = baseline_gross_g
        self._current_gross_g = baseline_gross_g

    def place_item(self, weight_g: float) -> None:
        """Simulate user placing an item into the locker slot."""
        self._current_gross_g += max(0.0, weight_g)

    def remove_item(self, weight_g: float) -> None:
        """Simulate user retrieving an item from the locker slot."""
        self._current_gross_g = max(0.0, self._current_gross_g - weight_g)

    def record_pre_access(self) -> float:
        """Capture steady-state weight before door opens."""
        self._pre_access_g = self.get_net_weight()
        return self._pre_access_g

    def record_post_access(self) -> float:
        """Capture steady-state weight after door closes and vibrations settle."""
        self._post_access_g = self.get_net_weight()
        return self._post_access_g

    def get_net_weight(self) -> float:
        """Return net weight reading after tare compensation."""
        return self._current_gross_g - self._tare_offset_g

    def compute_weight_delta(self) -> float:
        """Compute delta between post-access and pre-access readings."""
        delta = self._post_access_g - self._pre_access_g
        return round(delta, 2)

    def sample_delta(
        self,
        target_delta_g: Optional[float] = None,
        noise_stddev: float = 0.5,
    ) -> float:
        """
        Generate a simulated weight delta in grams.
        Adds small ADC jitter if noise_stddev > 0.
        """
        if target_delta_g is None:
            # Baseline normal cycle (no item deposited or zero change)
            delta = 0.0
        else:
            delta = float(target_delta_g)

        if noise_stddev > 0 and not (math.isnan(delta) or math.isinf(delta)):
            delta += self.rng.gauss(0.0, noise_stddev)

        if not (math.isnan(delta) or math.isinf(delta)):
            delta = round(delta, 2)
        return delta

    def sample(self, *args, **kwargs) -> Dict[str, Any]:
        """Sample current load cell status."""
        net = self.get_net_weight()
        return {
            "net_weight_g": round(net, 2),
            "tare_offset_g": round(self._tare_offset_g, 2),
            "last_delta_g": self.compute_weight_delta(),
        }
