"""
Ultrasonic SRF05 distance and presence sensor emulator.
Models acoustic time-of-flight, doorway presence detection, and clearance holding logic.
"""

import math
from typing import Any, Dict, Optional
from .base import BaseSensor


class UltrasonicSensor(BaseSensor):
    """
    Emulates an ultrasonic range finder (SRF05 / HC-SR04).
    Operating range: 0 to 400 cm. Presence threshold: <= 50 cm.
    """

    DEFAULT_PRESENCE_THRESHOLD_CM = 50.0
    NOMINAL_MAX_CM = 400.0
    PHYSICAL_MAX_CM = 450.0

    def __init__(
        self,
        seed: Optional[int] = None,
        presence_threshold_cm: float = DEFAULT_PRESENCE_THRESHOLD_CM,
    ):
        super().__init__(seed=seed)
        self.presence_threshold_cm = presence_threshold_cm

    @property
    def name(self) -> str:
        return "ultrasonic"

    @property
    def unit(self) -> str:
        return "cm"

    @property
    def min_valid(self) -> float:
        return 0.0

    @property
    def max_valid(self) -> float:
        return self.NOMINAL_MAX_CM

    def is_in_valid_range(self, val: float) -> bool:
        if math.isnan(val) or math.isinf(val):
            return False
        return 0.0 <= val <= self.PHYSICAL_MAX_CM

    def sample(
        self,
        distance_cm: Optional[float] = None,
        noise_stddev: float = 0.5,
    ) -> Dict[str, Any]:
        """
        Sample a distance measurement.
        If distance_cm is omitted, generates a random distance in [10.0, 150.0].
        Adds Gaussian noise if noise_stddev > 0.
        """
        if distance_cm is None:
            raw_dist = self.rng.uniform(10.0, 150.0)
        else:
            raw_dist = float(distance_cm)

        if noise_stddev > 0 and not (math.isnan(raw_dist) or math.isinf(raw_dist)):
            dist = raw_dist + self.rng.gauss(0.0, noise_stddev)
        else:
            dist = raw_dist

        if not (math.isnan(dist) or math.isinf(dist)):
            dist = max(0.0, round(dist, 1))

        is_present = (
            not (math.isnan(dist) or math.isinf(dist))
            and 0.0 <= dist <= self.presence_threshold_cm
        )

        return {
            "distance_cm": dist,
            "presence": is_present,
            "doorway_clear": not is_present,
        }

    def simulate_door_clearance(
        self,
        user_stay_duration_sec: float,
        door_open_limit_sec: float = 20.0,
        door_open_max_sec: float = 120.0,
        time_step_sec: float = 0.5,
    ) -> Dict[str, Any]:
        """
        Simulate the firmware door auto-lock loop with sonar clearance:
        - While user is near (<= 50cm), door clearance timer pauses.
        - Once user steps back (> 50cm), door counts down door_open_limit_sec.
        - If total open time exceeds door_open_max_sec, safety override closes door immediately.
        """
        elapsed = 0.0
        clear_since: Optional[float] = None
        closed_by_override = False

        while elapsed < door_open_max_sec:
            if elapsed < user_stay_duration_sec:
                # User is standing at the locker depositing/retrieving items
                reading = self.sample(distance_cm=25.0)
                clear_since = None
            else:
                # User has stepped away
                reading = self.sample(distance_cm=120.0)
                if clear_since is None:
                    clear_since = elapsed
                elif elapsed - clear_since >= door_open_limit_sec:
                    # Door countdown completed
                    return {
                        "total_door_open_sec": round(elapsed, 2),
                        "closed_by_override": False,
                        "clear_duration_sec": round(elapsed - clear_since, 2),
                    }

            elapsed += time_step_sec

        # Forced close by safety override
        return {
            "total_door_open_sec": round(door_open_max_sec, 2),
            "closed_by_override": True,
            "clear_duration_sec": 0.0,
        }
