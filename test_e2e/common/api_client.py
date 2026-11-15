"""
Backend REST API Client for SmartLocker E2E Testing.
Provides opaque-box HTTP interaction with Tomcat 9 backend endpoints:
/api/health, /api/device/auth, /api/device/enroll/*, /api/locker/batch, /api/kiosk/unlock.
Built using standard library urllib with zero mandatory external dependencies.
"""

import time
import json
import urllib.request
import urllib.error
from typing import Any, Dict, List, Optional
from dataclasses import dataclass, field


@dataclass
class ApiResponse:
    """Encapsulation of an HTTP API response."""
    status_code: int
    headers: Dict[str, str] = field(default_factory=dict)
    text: str = ""
    data: Optional[Dict[str, Any]] = None
    latency_ms: float = 0.0
    error: Optional[str] = None

    @property
    def is_success(self) -> bool:
        return 200 <= self.status_code < 300

    def json(self) -> Dict[str, Any]:
        if self.data is not None:
            return self.data
        if self.text:
            return json.loads(self.text)
        return {}


class BackendApiClient:
    """Client for testing SmartLocker backend endpoints."""

    def __init__(
        self,
        base_url: str = "http://localhost:8081/SmartLocker",
        default_api_key: str = "DEVICE_KEY_LOCKER_01",
        default_timeout: float = 5.0,
    ):
        self.base_url = base_url.rstrip("/")
        self.default_api_key = default_api_key
        self.default_timeout = default_timeout

    def request(
        self,
        method: str,
        path: str,
        headers: Optional[Dict[str, str]] = None,
        json_body: Optional[Dict[str, Any]] = None,
        timeout: Optional[float] = None,
    ) -> ApiResponse:
        """Execute an HTTP request with error trapping and latency timing."""
        url = f"{self.base_url}/{path.lstrip('/')}"
        req_headers = {"User-Agent": "SmartLocker-E2E-Harness/1.0"}
        if headers:
            req_headers.update(headers)

        data_bytes = None
        if json_body is not None:
            data_bytes = json.dumps(json_body).encode("utf-8")
            if "Content-Type" not in req_headers:
                req_headers["Content-Type"] = "application/json; charset=UTF-8"

        req = urllib.request.Request(url, data=data_bytes, headers=req_headers, method=method.upper())
        timeout_val = timeout if timeout is not None else self.default_timeout

        start = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=timeout_val) as resp:
                elapsed_ms = (time.perf_counter() - start) * 1000.0
                body_bytes = resp.read()
                text = body_bytes.decode("utf-8", errors="replace")
                parsed_json = None
                try:
                    parsed_json = json.loads(text)
                except Exception:
                    pass
                return ApiResponse(
                    status_code=resp.status,
                    headers=dict(resp.headers),
                    text=text,
                    data=parsed_json,
                    latency_ms=elapsed_ms,
                )
        except urllib.error.HTTPError as he:
            elapsed_ms = (time.perf_counter() - start) * 1000.0
            err_body = he.read().decode("utf-8", errors="replace")
            parsed_json = None
            try:
                parsed_json = json.loads(err_body)
            except Exception:
                pass
            return ApiResponse(
                status_code=he.code,
                headers=dict(he.headers),
                text=err_body,
                data=parsed_json,
                latency_ms=elapsed_ms,
                error=f"HTTPError {he.code}: {he.reason}",
            )
        except urllib.error.URLError as ue:
            elapsed_ms = (time.perf_counter() - start) * 1000.0
            return ApiResponse(
                status_code=0,
                latency_ms=elapsed_ms,
                error=f"URLError: {ue.reason}",
            )
        except Exception as ex:
            elapsed_ms = (time.perf_counter() - start) * 1000.0
            return ApiResponse(
                status_code=0,
                latency_ms=elapsed_ms,
                error=f"Exception: {type(ex).__name__}: {str(ex)}",
            )

    def is_backend_online(self) -> bool:
        """Check if backend is reachable at /api/health."""
        resp = self.request("GET", "api/health", timeout=2.0)
        return resp.status_code in (200, 401)

    def get_health(self, api_key: Optional[str] = None) -> ApiResponse:
        """Admin or probe health check via GET /api/health."""
        headers = {}
        if api_key:
            headers["X-API-Key"] = api_key
        return self.request("GET", "api/health", headers=headers)

    def post_device_heartbeat(
        self,
        firmware: str = "4.3-esp32",
        uptime_sec: int = 120,
        nfc: bool = True,
        api_key: Optional[str] = None,
    ) -> ApiResponse:
        """Device periodic heartbeat via POST /api/health."""
        headers = {"X-API-Key": api_key or self.default_api_key}
        body = {"firmware": firmware, "uptime_sec": uptime_sec, "nfc": nfc}
        return self.request("POST", "api/health", headers=headers, json_body=body)

    def device_auth(
        self,
        method: str,
        pin: Optional[str] = None,
        card_uid: Optional[str] = None,
        sensor_slot: Optional[int] = None,
        intent: str = "ASK",
        api_key: Optional[str] = None,
    ) -> ApiResponse:
        """Device authentication attempt via POST /api/device/auth."""
        headers = {"X-API-Key": api_key or self.default_api_key}
        body: Dict[str, Any] = {"method": method, "intent": intent}
        if method == "PIN" and pin is not None:
            body["pin"] = pin
        elif method == "CARD" and card_uid is not None:
            body["card_uid"] = card_uid
        elif method == "FINGERPRINT" and sensor_slot is not None:
            body["sensor_slot"] = sensor_slot
        return self.request("POST", "api/device/auth", headers=headers, json_body=body)

    def batch_sessions(
        self,
        sessions: List[Dict[str, Any]],
        device_id: int = 1,
        api_key: Optional[str] = None,
    ) -> ApiResponse:
        """Batch session & telemetry ingestion via POST /api/locker/batch."""
        headers = {"X-API-Key": api_key or self.default_api_key}
        payload = {"device_id": device_id, "sessions": sessions}
        return self.request("POST", "api/locker/batch", headers=headers, json_body=payload)

    def kiosk_unlock(
        self,
        device_code: str = "LOCKER-01",
        pin: Optional[str] = None,
        method: Optional[str] = None,
        tap: Optional[str] = None,
        intent: str = "ASK",
    ) -> ApiResponse:
        """Public kiosk/phone unlock via POST /api/kiosk/unlock."""
        body: Dict[str, Any] = {"device_code": device_code, "intent": intent}
        if method == "PHONE" and tap is not None:
            body["method"] = "PHONE"
            body["tap"] = tap
        elif pin is not None:
            body["pin"] = pin
        return self.request("POST", "api/kiosk/unlock", json_body=body)
