"""
Mobile Phone NFC / QR kiosk tap authentication emulator.
Parses dynamic tap tokens from heartbeat responses and formats kiosk unlock payloads.
"""

import re
import urllib.parse
from typing import Any, Dict
from .base import BaseAuthEmulator


class MobileTapAuthEmulator(BaseAuthEmulator):
    """Emulates a user tapping their smartphone on the locker's dynamic NFC/QR tag."""

    @property
    def name(self) -> str:
        return "PHONE"

    def validate(self, credential: Any) -> bool:
        """Validate token string has sufficient entropy (at least 8 alphanumeric chars)."""
        if not isinstance(credential, str):
            return False
        clean = credential.strip()
        return len(clean) >= 8 and bool(re.match(r"^[A-Za-z0-9_-]+$", clean))

    def extract_token_from_path(self, tap_path: str) -> str:
        """
        Extract token query parameter 'n' from a tap path like '/k/LOCKER-01?n=dgFgdbSaVCYc'.
        """
        if not tap_path:
            return ""
        parsed = urllib.parse.urlparse(tap_path)
        qs = urllib.parse.parse_qs(parsed.query)
        tokens = qs.get("n", [])
        if tokens:
            return tokens[0]
        # Fallback if raw token is passed directly
        return tap_path.strip()

    def format_payload(
        self, credential: Any, intent: str = "ASK", **kwargs
    ) -> Dict[str, Any]:
        """
        Format payload for /api/kiosk/unlock.
        kwargs may specify 'device_code' (defaults to 'LOCKER-01').
        """
        token = str(credential).strip()
        if "?" in token or "/" in token:
            token = self.extract_token_from_path(token)

        device_code = kwargs.get("device_code", "LOCKER-01")
        return {
            "device_code": device_code,
            "method": "PHONE",
            "tap": token,
            "intent": intent.upper(),
        }
