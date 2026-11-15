"""
Keypad PIN authentication emulator.
Validates 6-digit decimal PIN and formats backend authentication payload.
"""

import re
import random
from typing import Any, Dict, Optional
from .base import BaseAuthEmulator


class PinAuthEmulator(BaseAuthEmulator):
    """Emulates a 4x4 matrix keypad accepting a 6-digit numeric PIN."""

    PIN_REGEX = re.compile(r"^\d{6}$")

    def __init__(self):
        self._buffer: str = ""

    @property
    def name(self) -> str:
        return "PIN"

    def validate(self, credential: Any) -> bool:
        """Validate that credential is a string matching exactly 6 decimal digits."""
        if not isinstance(credential, str):
            return False
        return bool(self.PIN_REGEX.match(credential))

    def format_payload(
        self, credential: Any, intent: str = "ASK", **kwargs
    ) -> Dict[str, Any]:
        """Format REST payload for /api/device/auth."""
        pin_str = str(credential).strip()
        payload = {
            "method": "PIN",
            "pin": pin_str,
            "intent": intent.upper(),
        }
        return payload

    # Keypad buffer interactive simulation methods
    def input_digit(self, digit: str) -> str:
        """Append a digit character (0-9) to keypad buffer."""
        if digit in "0123456789" and len(self._buffer) < 6:
            self._buffer += digit
        return self._buffer

    def press_cancel(self) -> None:
        """Emulate '*' key press to clear buffer."""
        self._buffer = ""

    def press_backspace(self) -> str:
        """Remove last entered digit."""
        self._buffer = self._buffer[:-1]
        return self._buffer

    def press_submit(self, intent: str = "ASK") -> Dict[str, Any]:
        """Emulate '#' key press to submit current PIN."""
        submitted = self._buffer
        self._buffer = ""
        return self.format_payload(submitted, intent=intent)

    @staticmethod
    def generate_pin(rng: Optional[random.Random] = None) -> str:
        """Generate a random valid 6-digit PIN string."""
        r = rng or random
        return f"{r.randint(0, 999999):06d}"
