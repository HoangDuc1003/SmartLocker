"""
Finite State Machine module for the SmartLocker Virtual ESP32 Device Simulator.
Implements device lifecycle states and validates transitions.
"""

from enum import Enum
from typing import Dict, List, Optional, Set


class DeviceState(Enum):
    """Operational states of the virtual ESP32 device."""

    BOOT = "BOOT"
    CONNECTING = "CONNECTING"
    IDLE = "IDLE"
    AUTHENTICATING = "AUTHENTICATING"
    CHOOSE_PROMPT = "CHOOSE_PROMPT"
    WAIT_DOOR = "WAIT_DOOR"
    RELOCKED = "RELOCKED"
    BATCH_INGEST = "BATCH_INGEST"
    ERROR = "ERROR"
    OFFLINE = "OFFLINE"


# Permitted state transition map
VALID_TRANSITIONS: Dict[str, List[str]] = {
    "BOOT": ["CONNECTING", "IDLE", "ERROR"],
    "CONNECTING": ["IDLE", "AUTHENTICATING", "ERROR", "OFFLINE"],
    "IDLE": ["CONNECTING", "AUTHENTICATING", "OFFLINE", "ERROR"],
    "AUTHENTICATING": ["WAIT_DOOR", "CHOOSE_PROMPT", "IDLE", "ERROR"],
    "CHOOSE_PROMPT": ["WAIT_DOOR", "IDLE", "ERROR"],
    "WAIT_DOOR": ["BATCH_INGEST", "RELOCKED", "IDLE", "ERROR"],
    "RELOCKED": ["BATCH_INGEST", "IDLE", "ERROR"],
    "BATCH_INGEST": ["IDLE", "OFFLINE", "ERROR"],
    "ERROR": ["IDLE", "CONNECTING", "OFFLINE"],
    "OFFLINE": ["CONNECTING", "IDLE", "ERROR"],
}


class InvalidStateTransitionError(ValueError):
    """Raised when an invalid state transition is attempted."""

    pass


class DeviceStateMachine:
    """Manages state transitions and lifecycle validation for a Virtual ESP32."""

    def __init__(self, initial_state: DeviceState = DeviceState.BOOT):
        self._current_state = initial_state
        self._previous_state: Optional[DeviceState] = None
        self._history: List[DeviceState] = [initial_state]

    @property
    def current_state(self) -> DeviceState:
        return self._current_state

    @property
    def state_name(self) -> str:
        return self._current_state.value

    @property
    def previous_state(self) -> Optional[DeviceState]:
        return self._previous_state

    @property
    def history(self) -> List[DeviceState]:
        return list(self._history)

    def can_transition_to(self, target: DeviceState) -> bool:
        """Check if transition from current state to target state is permissible."""
        curr_name = self._current_state.value
        allowed = VALID_TRANSITIONS.get(curr_name, [])
        return target.value in allowed

    def transition_to(self, target: DeviceState) -> None:
        """
        Transition to target state.
        Raises InvalidStateTransitionError if the transition is prohibited.
        """
        if not self.can_transition_to(target):
            raise InvalidStateTransitionError(
                f"Invalid state transition from {self._current_state.value} to {target.value}"
            )
        self._previous_state = self._current_state
        self._current_state = target
        self._history.append(target)

    def reset(self, state: DeviceState = DeviceState.BOOT) -> None:
        """Reset state machine to designated initial state."""
        self._current_state = state
        self._previous_state = None
        self._history = [state]
