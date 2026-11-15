"""
RFID Card UID authentication emulator.
Validates 4-20 hexadecimal character UIDs (RC522 / PN532 MIFARE).
"""

import re
import random
from typing import Any, Dict, Optional
from .base import BaseAuthEmulator


class RfidAuthEmulator(BaseAuthEmulator):
    """Emulates an RC522/PN532 RFID reader scanning MIFARE cards."""

    CARD_REGEX = re.compile(r"^[0-9A-Fa-f]{4,20}$")

    @property
    def name(self) -> str:
        return "CARD"

    def validate(self, credential: Any) -> bool:
        """Validate that credential is a valid hex UID between 4 and 20 chars."""
        if not isinstance(credential, str):
            return False
        return bool(self.CARD_REGEX.match(credential.strip()))

    def is_phone_hce_uid(self, card_uid: str) -> bool:
        """
        Check if card UID resembles an Android/iOS HCE randomized pseudo-UID
        (typically starts with 0x08 per NXP MIFARE specification).
        """
        clean = card_uid.strip().upper()
        return clean.startswith("08")

    def format_payload(
        self, credential: Any, intent: str = "ASK", **kwargs
    ) -> Dict[str, Any]:
        """Format REST payload for /api/device/auth."""
        uid_str = str(credential).strip().upper()
        return {
            "method": "CARD",
            "card_uid": uid_str,
            "intent": intent.upper(),
        }

    @staticmethod
    def generate_uid(
        rng: Optional[random.Random] = None, length: int = 8
    ) -> str:
        """Generate a random valid hex card UID."""
        r = rng or random
        length = max(4, min(20, length))
        hex_chars = "0123456789ABCDEF"
        return "".join(r.choice(hex_chars) for _ in range(length))
