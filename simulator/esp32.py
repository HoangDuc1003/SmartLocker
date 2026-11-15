"""
Virtual ESP32 Core Device Client.
Implements the software-based multi-sensor device simulator communicating with the live Java backend.
"""

from datetime import datetime, timezone
import json
import math
import os
import random
import time
from typing import Any, Dict, List, Optional, Set, Tuple
import urllib.error
import urllib.parse
import urllib.request

from .config import DeviceConfig
from .state_machine import DeviceState, DeviceStateMachine
from .auth.pin import PinAuthEmulator
from .auth.rfid import RfidAuthEmulator
from .auth.fingerprint import FingerprintAuthEmulator
from .auth.mobile_tap import MobileTapAuthEmulator
from .sensors.ultrasonic import UltrasonicSensor
from .sensors.reed_switch import ReedSwitchSensor
from .sensors.load_cell import LoadCellSensor
from .sensors.imu_vibration import ImuSensor
from .faults.injector import FaultInjector
from .faults.config import FaultConfig
from .tracking.stage_tracker import SensorIntegrationTracker


class VirtualESP32:
    """
    Virtual ESP32 client simulating a physical SmartLocker controller node.
    Completely software-based with zero hardware dependencies.
    """

    def __init__(
        self,
        config: Optional[DeviceConfig] = None,
        seed: Optional[int] = None,
        fault_config: Optional[FaultConfig] = None,
    ):
        self.config = config or DeviceConfig()
        self.config.validate()

        self.seed = seed if seed is not None else 42
        self.rng = random.Random(self.seed)

        # State Machine
        self.fsm = DeviceStateMachine(initial_state=DeviceState.BOOT)

        # Strictly monotonic device sequence generator (1 to 2^31-1)
        # Seeded from current epoch to avoid collisions across runs
        self._seq = (int(time.time()) % 1000000) * 1000 + 1
        self._last_seq = self._seq

        # Runtime telemetry and health status
        self.boot_time = time.time()
        self.last_heartbeat_time: float = 0.0
        self.heartbeat_interval_sec: float = self.config.heartbeat_interval_sec
        self.server_time: str = ""
        self.tap_path: str = ""
        self.current_tap_token: str = ""
        self.blocked_cards: Set[str] = set()
        self.pending_commands: List[Dict[str, Any]] = []

        # Offline session queue buffer for network drop recovery
        self.offline_queue: List[Dict[str, Any]] = []

        # Multi-Modal Authentication Emulators
        self.auth_pin = PinAuthEmulator()
        self.auth_rfid = RfidAuthEmulator()
        self.auth_fingerprint = FingerprintAuthEmulator()
        self.auth_mobile = MobileTapAuthEmulator()

        # Software Sensor Emulators (independent PRNG seeds)
        self.sensor_ultrasonic = UltrasonicSensor(
            seed=self.rng.randint(0, 2**31 - 1),
            presence_threshold_cm=self.config.doorway_clearance_cm,
        )
        self.sensor_reed = ReedSwitchSensor(
            seed=self.rng.randint(0, 2**31 - 1)
        )
        self.sensor_load_cell = LoadCellSensor(
            seed=self.rng.randint(0, 2**31 - 1)
        )
        self.sensor_imu = ImuSensor(
            seed=self.rng.randint(0, 2**31 - 1)
        )

        # Fault Injection Coordinator
        fcfg = fault_config or FaultConfig(seed=self.rng.randint(0, 2**31 - 1))
        self.fault_injector = FaultInjector(fcfg)

        # 5-Stage Sensor Integration Tracker
        self.stage_tracker = SensorIntegrationTracker(mode="B0")

    @property
    def state(self) -> DeviceState:
        """Current FSM state."""
        return self.fsm.current_state

    @property
    def uptime_sec(self) -> int:
        """Elapsed uptime in seconds."""
        return int(time.time() - self.boot_time)

    def next_seq(self) -> int:
        """
        Generate strictly monotonically increasing sequence number:
        seq_{i+1} > seq_i.
        """
        if self.fault_injector.should_duplicate_seq() and self._last_seq > 0:
            return self._last_seq

        self._seq += 1
        self._last_seq = self._seq
        return self._seq

    # -------------------------------------------------------------------------
    # Lifecycle & Connection State Management
    # -------------------------------------------------------------------------

    def boot(self) -> bool:
        """Power on device and transition from BOOT to CONNECTING."""
        self.fsm.reset(DeviceState.BOOT)
        self.fsm.transition_to(DeviceState.CONNECTING)
        return True

    def connect(self) -> bool:
        """Perform initial handshake and transition from CONNECTING to IDLE."""
        if self.fsm.current_state != DeviceState.CONNECTING:
            if self.fsm.can_transition_to(DeviceState.CONNECTING):
                self.fsm.transition_to(DeviceState.CONNECTING)
            elif self.fsm.current_state == DeviceState.OFFLINE:
                self.fsm.transition_to(DeviceState.CONNECTING)

        # Heartbeat handshake
        hb_resp = self.heartbeat()
        if hb_resp.get("status") == "OK" or "interval_sec" in hb_resp:
            self.fsm.transition_to(DeviceState.IDLE)
            return True
        else:
            self.fsm.transition_to(DeviceState.ERROR)
            return False

    def disconnect(self) -> None:
        """Simulate unexpected network disconnection or offline drop."""
        if self.fsm.can_transition_to(DeviceState.OFFLINE):
            self.fsm.transition_to(DeviceState.OFFLINE)
        else:
            self.fsm.transition_to(DeviceState.ERROR)

    def recover(self) -> bool:
        """Attempt reconnection from ERROR or OFFLINE state."""
        if self.fsm.current_state in (DeviceState.ERROR, DeviceState.OFFLINE):
            self.fsm.transition_to(DeviceState.CONNECTING)
            return self.connect()
        return True

    # -------------------------------------------------------------------------
    # HTTP REST Communication Core (Standard Library urllib)
    # -------------------------------------------------------------------------

    def _http_request(
        self,
        endpoint: str,
        method: str = "POST",
        payload: Optional[Dict[str, Any]] = None,
        include_api_key: bool = True,
        custom_headers: Optional[Dict[str, str]] = None,
        timeout: Optional[float] = None,
    ) -> Tuple[int, Dict[str, Any], Optional[str]]:
        """
        Execute an HTTP request against the backend with fault injection support.
        Returns (status_code, response_json_or_dict, raw_body_str).
        """
        # Inject network drop fault
        if self.fault_injector.should_drop_packet():
            return 0, {"error": "SIMULATED_PACKET_DROP"}, "Simulated packet drop"

        # Inject transmission latency fault
        delay_sec = self.fault_injector.get_transmission_delay_sec()
        effective_timeout = timeout or self.config.http_timeout_sec

        if self.fault_injector.is_timeout(delay_sec):
            return 0, {"error": "SIMULATED_TIMEOUT"}, "Simulated socket timeout"

        if delay_sec > 0:
            time.sleep(delay_sec)

        # Inject payload corruption fault
        post_data = None
        if payload is not None:
            corrupted_payload, is_mutated = self.fault_injector.corrupt_payload(payload)
            if isinstance(corrupted_payload, str):
                post_data = corrupted_payload.encode("utf-8")
            else:
                post_data = json.dumps(corrupted_payload).encode("utf-8")

        url = f"{self.config.base_url}/{endpoint.lstrip('/')}"
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        if include_api_key:
            headers["X-API-Key"] = self.config.api_key
        if custom_headers:
            headers.update(custom_headers)

        req = urllib.request.Request(
            url=url, data=post_data, headers=headers, method=method
        )

        try:
            with urllib.request.urlopen(req, timeout=effective_timeout) as resp:
                status_code = resp.getcode()
                raw_bytes = resp.read()
                raw_str = raw_bytes.decode("utf-8")
                try:
                    data = json.loads(raw_str)
                except Exception:
                    data = {"raw": raw_str}
                return status_code, data, raw_str

        except urllib.error.HTTPError as e:
            raw_bytes = e.read()
            raw_str = raw_bytes.decode("utf-8")
            try:
                data = json.loads(raw_str)
            except Exception:
                data = {"raw": raw_str, "reason": e.reason}
            return e.code, data, raw_str

        except (urllib.error.URLError, TimeoutError, OSError) as e:
            return 0, {"error": "CONNECTION_FAILED", "details": str(e)}, str(e)

    # -------------------------------------------------------------------------
    # Core Device Operations
    # -------------------------------------------------------------------------

    def heartbeat(self) -> Dict[str, Any]:
        """
        Poll /api/health to report liveness and retrieve queued commands.
        Header: X-API-Key: <DEVICE_API_KEY>.
        """
        payload = {
            "firmware": self.config.firmware,
            "uptime_sec": self.uptime_sec,
            "nfc": self.config.nfc_enabled,
        }

        code, resp, _ = self._http_request("health", method="POST", payload=payload)
        self.last_heartbeat_time = time.time()

        if code == 200:
            self.heartbeat_interval_sec = float(resp.get("interval_sec", 3.0))
            self.server_time = resp.get("server_time", "")
            self.blocked_cards = set(resp.get("blocked_cards", []))
            self.pending_commands = resp.get("commands", [])

            if "tap_path" in resp:
                self.tap_path = resp["tap_path"]
                self.current_tap_token = self.auth_mobile.extract_token_from_path(
                    self.tap_path
                )

            # Flush queued offline sessions if any exist
            if self.offline_queue:
                self.flush_offline_queue()

            return resp
        else:
            return {"status": "ERROR", "code": code, "response": resp}

    def authenticate(
        self,
        method: str,
        credential: Any,
        intent: str = "ASK",
    ) -> Dict[str, Any]:
        """
        Submit user credential to /api/device/auth.
        Methods: PIN, CARD, FINGERPRINT.
        Intent: ASK, OPEN, CHECKOUT.
        """
        method_upper = method.upper()

        if method_upper == "PIN":
            payload = self.auth_pin.format_payload(credential, intent=intent)
        elif method_upper == "CARD":
            payload = self.auth_rfid.format_payload(credential, intent=intent)
        elif method_upper == "FINGERPRINT":
            payload = self.auth_fingerprint.format_payload(credential, intent=intent)
        else:
            raise ValueError(f"Unsupported authentication method: {method}")

        # Transition state machine to AUTHENTICATING
        if self.fsm.can_transition_to(DeviceState.AUTHENTICATING):
            self.fsm.transition_to(DeviceState.AUTHENTICATING)

        code, resp, _ = self._http_request(
            "device/auth", method="POST", payload=payload
        )

        result = resp.get("result", "ERROR")

        if result == "UNLOCK":
            if self.fsm.can_transition_to(DeviceState.WAIT_DOOR):
                self.fsm.transition_to(DeviceState.WAIT_DOOR)
        elif result == "CHOOSE":
            if self.fsm.can_transition_to(DeviceState.CHOOSE_PROMPT):
                self.fsm.transition_to(DeviceState.CHOOSE_PROMPT)
        elif result in ("DENY", "CONFIRM_EMAIL"):
            if self.fsm.can_transition_to(DeviceState.IDLE):
                self.fsm.transition_to(DeviceState.IDLE)
        else:
            if self.fsm.can_transition_to(DeviceState.ERROR):
                self.fsm.transition_to(DeviceState.ERROR)

        return resp

    def kiosk_unlock(
        self,
        token: Optional[str] = None,
        pin: Optional[str] = None,
        intent: str = "ASK",
    ) -> Dict[str, Any]:
        """
        Trigger mobile kiosk unlock via /api/kiosk/unlock (public endpoint).
        Supports phone tap token or web PIN entry.
        """
        payload: Dict[str, Any] = {
            "device_code": self.config.device_code,
            "intent": intent.upper(),
        }

        if token:
            payload["method"] = "PHONE"
            payload["tap"] = token
        elif pin:
            payload["pin"] = pin
        elif self.current_tap_token:
            payload["method"] = "PHONE"
            payload["tap"] = self.current_tap_token
        else:
            raise ValueError("Must provide either a tap token or a PIN for kiosk unlock")

        code, resp, _ = self._http_request(
            "kiosk/unlock",
            method="POST",
            payload=payload,
            include_api_key=False,
        )
        return resp

    def ingest_batch(
        self, sessions: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """
        Send batch telemetry sessions to /api/locker/batch.
        If network fails or is offline, buffers sessions into offline_queue.
        """
        if sessions is None:
            sessions = []

        if not sessions:
            return {"saved": 0, "duplicates": 0, "rejected": 0, "errors": []}

        # Transition to BATCH_INGEST if possible
        if self.fsm.can_transition_to(DeviceState.BATCH_INGEST):
            self.fsm.transition_to(DeviceState.BATCH_INGEST)

        payload = {
            "device_id": self.config.device_id,
            "sessions": sessions,
        }

        code, resp, _ = self._http_request(
            "locker/batch", method="POST", payload=payload
        )

        if code == 200 and resp.get("saved", 0) + resp.get("duplicates", 0) > 0:
            if self.fsm.can_transition_to(DeviceState.IDLE):
                self.fsm.transition_to(DeviceState.IDLE)
            return resp
        elif code == 200:
            # Backend accepted request but might have rejected all items
            if self.fsm.can_transition_to(DeviceState.IDLE):
                self.fsm.transition_to(DeviceState.IDLE)
            return resp
        else:
            # Buffer sessions into offline queue on network/transport failure
            self.offline_queue.extend(sessions)
            if self.fsm.can_transition_to(DeviceState.OFFLINE):
                self.fsm.transition_to(DeviceState.OFFLINE)
            elif self.fsm.can_transition_to(DeviceState.ERROR):
                self.fsm.transition_to(DeviceState.ERROR)
            return {
                "saved": 0,
                "buffered_offline": len(sessions),
                "total_buffered": len(self.offline_queue),
                "error": resp,
            }

    def flush_offline_queue(self) -> int:
        """Transmit all sessions currently buffered in the offline queue."""
        if not self.offline_queue:
            return 0

        pending = list(self.offline_queue)
        self.offline_queue.clear()

        payload = {
            "device_id": self.config.device_id,
            "sessions": pending,
        }

        code, resp, _ = self._http_request(
            "locker/batch", method="POST", payload=payload
        )

        if code == 200:
            saved = resp.get("saved", 0) + resp.get("duplicates", 0)
            return saved
        else:
            # Re-enqueue on failure
            self.offline_queue.extend(pending)
            return 0

    # -------------------------------------------------------------------------
    # High-Level Full Cycle Simulation
    # -------------------------------------------------------------------------

    def simulate_access_cycle(
        self,
        method: str,
        credential: Any,
        slot_code: str = "A01",
        bank_code: str = "CANT-A",
        card_uid: Optional[str] = None,
        duration_sec: float = 6.5,
        weight_delta_g: float = 0.0,
        rfid_ok: bool = True,
        stay_min: float = 10.0,
        intent: str = "OPEN",
    ) -> Dict[str, Any]:
        """
        Execute a complete end-to-end access cycle:
        1. Authenticate credential.
        2. Door opens (solenoid + servo).
        3. Ultrasonic samples user presence and clearance.
        4. Door closes, reed switch computes duration.
        5. Load cell computes weight delta.
        6. Package session telemetry and transmit via /api/locker/batch.
        """
        # Ensure device is in IDLE before starting
        if self.fsm.current_state != DeviceState.IDLE:
            if self.fsm.can_transition_to(DeviceState.IDLE):
                self.fsm.transition_to(DeviceState.IDLE)
            else:
                self.fsm.reset(DeviceState.IDLE)

        # 1. Authenticate
        auth_resp = self.authenticate(method, credential, intent=intent)
        result = auth_resp.get("result", "DENY")

        if result == "CHOOSE":
            # Re-submit with designated intent
            auth_resp = self.authenticate(method, credential, intent=intent)
            result = auth_resp.get("result", "DENY")

        if result != "UNLOCK":
            return {
                "cycle_status": "DENIED",
                "auth_response": auth_resp,
                "session_ingested": False,
            }

        # 2. Door clearance simulation (SRF05 Ultrasonic)
        sonar_res = self.sensor_ultrasonic.simulate_door_clearance(
            user_stay_duration_sec=duration_sec,
            door_open_limit_sec=20.0,
        )

        # 3. Door open/close duration (Reed switch)
        actual_door_sec = self.sensor_reed.sample_duration(target_sec=duration_sec)
        # Apply fault injection if configured
        actual_door_sec = self.fault_injector.inject_sensor_reading(
            "reed_switch", actual_door_sec
        )

        # 4. Weight delta (Load cell)
        actual_weight_delta = self.sensor_load_cell.sample_delta(
            target_delta_g=weight_delta_g
        )
        # Apply fault injection if configured
        actual_weight_delta = self.fault_injector.inject_sensor_reading(
            "load_cell", actual_weight_delta
        )

        # Transition to RELOCKED
        if self.fsm.can_transition_to(DeviceState.RELOCKED):
            self.fsm.transition_to(DeviceState.RELOCKED)

        # 5. Build session telemetry
        seq = self.next_seq()
        measured_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

        session_obj = {
            "seq": seq,
            "measured_at": measured_time,
            "door_open_sec": actual_door_sec,
            "weight_delta_g": actual_weight_delta,
            "unlock_count": 1,
            "rfid_ok": rfid_ok,
            "stay_min": stay_min,
            "slot_code": slot_code,
            "bank_code": bank_code,
            "card_uid": card_uid or (credential if method.upper() == "CARD" else None),
            "open_source": method.upper(),
            "command_id": None,
        }

        # 6. Ingest batch telemetry
        ingest_resp = self.ingest_batch([session_obj])

        return {
            "cycle_status": "COMPLETED",
            "auth_response": auth_resp,
            "session": session_obj,
            "batch_response": ingest_resp,
            "sonar_clearance": sonar_res,
        }
