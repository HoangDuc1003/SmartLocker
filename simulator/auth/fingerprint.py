"""
AS608 optical fingerprint sensor authentication emulator.
Validates slot indices within [1, 160] capacity and formats authentication requests.
"""

import random
from typing import Any, Dict, Optional
from .base import BaseAuthEmulator


class FingerprintAuthEmulator(BaseAuthEmulator):
    """Emulates an AS608 optical fingerprint sensor over UART."""

    MIN_SLOT = 1
    MAX_SLOT = 160

    @property
    def name(self) -> str:
        return "FINGERPRINT"

    def validate(self, credential: Any) -> bool:
        """Validate that credential is an integer slot index in [1, 160]."""
        if isinstance(credential, bool):
            return False
        if not isinstance(credential, int):
            try:
                val = int(credential)
            except (ValueError, TypeError):
                return False
            if isinstance(credential, float):
                return False
            credential = val
        return self.MIN_SLOT <= credential <= self.MAX_SLOT

    def format_payload(
        self, credential: Any, intent: str = "ASK", **kwargs
    ) -> Dict[str, Any]:
        """Format REST payload for /api/device/auth."""
        slot = int(credential)
        return {
            "method": "FINGERPRINT",
            "sensor_slot": slot,
            "intent": intent.upper(),
        }

    def simulate_scan(
        self,
        slot: int,
        confidence_threshold: int = 50,
        rng: Optional[random.Random] = None,
    ) -> Dict[str, Any]:
        """Simulate physical finger touch and template matching confidence."""
        r = rng or random
        confidence = r.randint(40, 100)
        match_ok = (confidence >= confidence_threshold) and self.validate(slot)
        return {
            "slot": slot,
            "confidence": confidence,
            "match": match_ok,
        }

    @classmethod
    def generate_slot(cls, rng: Optional[random.Random] = None) -> int:
        """Generate a random valid sensor slot index."""
        r = rng or random
        return r.randint(cls.MIN_SLOT, cls.MAX_SLOT)
