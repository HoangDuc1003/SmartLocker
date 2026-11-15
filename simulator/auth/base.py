"""
Abstract base class for multi-modal authentication outcome emulators.
"""

from abc import ABC, abstractmethod
from typing import Any, Dict


class BaseAuthEmulator(ABC):
    """Abstract interface for all authentication emulators."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Name of the authentication method (e.g. PIN, CARD, FINGERPRINT, PHONE)."""
        pass

    @abstractmethod
    def validate(self, credential: Any) -> bool:
        """Validate format and boundary constraints of the credential."""
        pass

    @abstractmethod
    def format_payload(
        self, credential: Any, intent: str = "ASK", **kwargs
    ) -> Dict[str, Any]:
        """Format REST JSON payload for backend authentication."""
        pass
