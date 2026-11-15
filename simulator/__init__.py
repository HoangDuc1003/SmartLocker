"""
SmartLocker Modular Multi-Sensor Device Simulator package.
Provides Virtual ESP32 core client, multi-modal auth emulators, software sensor models,
deterministic fault injection, and 5-stage sensor integration tracking.
"""

from .config import DeviceConfig
from .state_machine import DeviceState, DeviceStateMachine, InvalidStateTransitionError
from .esp32 import VirtualESP32
from .auth import (
    BaseAuthEmulator,
    PinAuthEmulator,
    RfidAuthEmulator,
    FingerprintAuthEmulator,
    MobileTapAuthEmulator,
)
from .sensors import (
    BaseSensor,
    UltrasonicSensor,
    ReedSwitchSensor,
    LoadCellSensor,
    ImuSensor,
)
from .faults import (
    FaultConfig,
    NetworkFaultConfig,
    SensorFaultConfig,
    FaultInjector,
)
from .tracking import (
    ChannelStageStatus,
    SensorIntegrationTracker,
    generate_integration_matrix_content,
    write_integration_matrix_file,
)

__version__ = "2.0.0"

__all__ = [
    "DeviceConfig",
    "DeviceState",
    "DeviceStateMachine",
    "InvalidStateTransitionError",
    "VirtualESP32",
    "BaseAuthEmulator",
    "PinAuthEmulator",
    "RfidAuthEmulator",
    "FingerprintAuthEmulator",
    "MobileTapAuthEmulator",
    "BaseSensor",
    "UltrasonicSensor",
    "ReedSwitchSensor",
    "LoadCellSensor",
    "ImuSensor",
    "FaultConfig",
    "NetworkFaultConfig",
    "SensorFaultConfig",
    "FaultInjector",
    "ChannelStageStatus",
    "SensorIntegrationTracker",
    "generate_integration_matrix_content",
    "write_integration_matrix_file",
]
