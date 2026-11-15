"""
MPU6050 3-axis accelerometer and vibration/tilt sensor emulator.
Models static gravitational acceleration, dynamic shock waves, and angular orientation.
"""

import math
from typing import Any, Dict, Optional
from .base import BaseSensor


class ImuSensor(BaseSensor):
    """
    Emulates an MPU6050 6-DOF IMU (accelerometer & gyroscope).
    Standard gravitational acceleration: g0 = 9.80665 m/s^2.
    Full-scale tamper shock threshold: 16.0g (156.96 m/s^2).
    """

    G0 = 9.80665
    SHOCK_THRESHOLD_G = 16.0

    @property
    def name(self) -> str:
        return "vibration_tilt"

    @property
    def unit(self) -> str:
        return "m/s^2"

    @property
    def min_valid(self) -> float:
        return -200.0

    @property
    def max_valid(self) -> float:
        return 200.0

    def sample_stationary(self, noise_stddev: float = 0.05) -> Dict[str, Any]:
        """
        Sample stationary locker resting vertically under Earth gravity:
        ax ~= 0.0, ay ~= 0.0, az ~= 9.81 m/s^2.
        """
        ax = self.rng.gauss(0.0, noise_stddev) if noise_stddev > 0 else 0.0
        ay = self.rng.gauss(0.0, noise_stddev) if noise_stddev > 0 else 0.0
        az = (
            self.G0 + self.rng.gauss(0.0, noise_stddev)
            if noise_stddev > 0
            else self.G0
        )
        return self._format_reading(ax, ay, az)

    def sample_shock(self, g_force: float = 20.0) -> Dict[str, Any]:
        """
        Simulate a physical crowbar or hammer impact shock exceeding threshold.
        """
        accel_mag = g_force * self.G0
        # Distribute shock across axes with heavy horizontal impulse
        ax = accel_mag * 0.707
        ay = accel_mag * 0.707
        az = self.G0 + (accel_mag * 0.1)
        return self._format_reading(ax, ay, az)

    def sample_tilt(self, pitch_deg: float, roll_deg: float) -> Dict[str, Any]:
        """
        Simulate steady-state tilt angle under tilted locker frame.
        """
        pitch_rad = math.radians(pitch_deg)
        roll_rad = math.radians(roll_deg)

        ax = self.G0 * math.sin(pitch_rad)
        ay = self.G0 * math.sin(roll_rad)
        az = self.G0 * math.cos(pitch_rad) * math.cos(roll_rad)
        return self._format_reading(ax, ay, az)

    def _format_reading(self, ax: float, ay: float, az: float) -> Dict[str, Any]:
        """Compute magnitude, g-force, pitch, roll, and tamper shock flag."""
        mag_ms2 = math.sqrt(ax**2 + ay**2 + az**2)
        mag_g = mag_ms2 / self.G0

        pitch_deg = math.degrees(math.atan2(ax, math.sqrt(ay**2 + az**2)))
        roll_deg = math.degrees(math.atan2(ay, math.sqrt(ax**2 + az**2)))

        is_tamper = mag_g > self.SHOCK_THRESHOLD_G

        return {
            "ax": round(ax, 3),
            "ay": round(ay, 3),
            "az": round(az, 3),
            "mag_ms2": round(mag_ms2, 3),
            "mag_g": round(mag_g, 3),
            "pitch_deg": round(pitch_deg, 2),
            "roll_deg": round(roll_deg, 2),
            "is_shock_tamper": is_tamper,
        }

    def sample(self, *args, **kwargs) -> Dict[str, Any]:
        """Default sample returns stationary reading."""
        return self.sample_stationary()

    @classmethod
    def is_shock_tamper(
        cls,
        ax: float,
        ay: float,
        az: float,
        threshold_g: float = SHOCK_THRESHOLD_G,
    ) -> bool:
        """Helper to determine whether acceleration vector exceeds shock limit."""
        mag = math.sqrt(ax**2 + ay**2 + az**2)
        return (mag / cls.G0) > threshold_g
