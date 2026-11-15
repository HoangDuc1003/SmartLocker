"""
Configuration module for the SmartLocker Virtual ESP32 Device Simulator.
Defines connection settings, hardware simulation parameters, and default credentials.
"""

from dataclasses import dataclass, field
import os
from typing import Optional


@dataclass
class DeviceConfig:
    """Configuration container for a simulated ESP32 smart locker device."""

    base_url: str = field(
        default_factory=lambda: os.getenv(
            "SMARTLOCKER_BASE_URL", "http://localhost:8081/SmartLocker/api"
        ).rstrip("/")
    )
    device_code: str = "LOCKER-01"
    device_id: int = 1
    api_key: str = "device-1-api-key"
    firmware: str = "4.3-esp32"
    heartbeat_interval_sec: float = 3.0
    http_timeout_sec: float = 6.0
    doorway_clearance_cm: float = 50.0
    door_open_max_sec: float = 120.0
    door_open_default_sec: float = 20.0
    nfc_enabled: bool = True
    fingerprint_enabled: bool = True
    sonar_enabled: bool = True
    door_servo_enabled: bool = True
    load_cell_enabled: bool = True
    imu_enabled: bool = True

    def validate(self) -> None:
        """Validate device configuration parameters."""
        if not self.base_url.startswith(("http://", "https://")):
            raise ValueError(f"Invalid base_url: {self.base_url}")
        if not (1 <= self.device_id <= 2147483647):
            raise ValueError(
                f"device_id {self.device_id} must be in range [1, 2147483647]"
            )
        if not self.api_key:
            raise ValueError("api_key cannot be empty")
        if self.heartbeat_interval_sec <= 0:
            raise ValueError("heartbeat_interval_sec must be positive")
        if self.http_timeout_sec <= 0:
            raise ValueError("http_timeout_sec must be positive")
        if self.doorway_clearance_cm <= 0:
            raise ValueError("doorway_clearance_cm must be positive")

    @classmethod
    def from_properties_file(
        cls,
        properties_path: str,
        device_code: str = "LOCKER-01",
        base_url: Optional[str] = None,
    ) -> "DeviceConfig":
        """Load API key and configuration from Java properties file if present."""
        cfg = cls(device_code=device_code)
        if base_url:
            cfg.base_url = base_url.rstrip("/")
        if os.path.isfile(properties_path):
            with open(properties_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        k, v = line.split("=", 1)
                        if k.strip() == device_code:
                            cfg.api_key = v.strip()
        return cfg
