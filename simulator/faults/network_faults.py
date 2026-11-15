"""
Network and transport layer fault simulation module.
Implements deterministic packet drop, artificial latency, socket timeouts, sequence replay, and payload corruption.
"""

import json
import random
from typing import Any, Dict, Optional, Tuple
from .config import NetworkFaultConfig


class NetworkFaultInjector:
    """Manages transport-level faults for simulated HTTP communications."""

    def __init__(
        self,
        config: Optional[NetworkFaultConfig] = None,
        rng: Optional[random.Random] = None,
    ):
        self.config = config or NetworkFaultConfig()
        self.rng = rng or random.Random()

    def set_rng(self, rng: random.Random) -> None:
        self.rng = rng

    def should_drop_packet(self) -> bool:
        """Evaluate if the outgoing packet should be dropped to simulate packet loss."""
        if not self.config.enabled or self.config.packet_drop_rate <= 0:
            return False
        return self.rng.random() < self.config.packet_drop_rate

    def get_transmission_delay_sec(self) -> float:
        """
        Calculate artificial transmission latency in seconds.
        Supports Gaussian delay (mean/std) or bounded delay (min/max/jitter).
        """
        if not self.config.enabled:
            return 0.0

        if self.config.max_delay_ms > 0:
            base = self.rng.uniform(
                self.config.min_delay_ms, self.config.max_delay_ms
            )
            if self.config.jitter_ms > 0:
                base += self.rng.uniform(
                    -self.config.jitter_ms, self.config.jitter_ms
                )
            return max(0.0, base / 1000.0)

        if self.config.delay_mean_ms > 0:
            if self.config.delay_std_ms > 0:
                delay_ms = self.rng.gauss(
                    self.config.delay_mean_ms, self.config.delay_std_ms
                )
            else:
                delay_ms = self.config.delay_mean_ms
            return max(0.0, delay_ms / 1000.0)

        return 0.0

    def is_timeout(self, delay_sec: float) -> bool:
        """Check if injected latency exceeds timeout threshold."""
        timeout_sec = self.config.timeout_threshold_ms / 1000.0
        return delay_sec >= timeout_sec

    def should_duplicate_seq(self) -> bool:
        """Evaluate if device should replay a previously transmitted sequence number."""
        if not self.config.enabled or self.config.duplicate_seq_prob <= 0:
            return False
        return self.rng.random() < self.config.duplicate_seq_prob

    def corrupt_payload(
        self, payload: Dict[str, Any]
    ) -> Tuple[Any, bool]:
        """
        Mutate outgoing JSON payload according to configured corruption mode.
        Returns (corrupted_payload_or_string, was_mutated_bool).
        """
        if not self.config.enabled or self.config.corrupt_payload_prob <= 0:
            return payload, False

        if self.rng.random() >= self.config.corrupt_payload_prob:
            return payload, False

        mode = self.config.corruption_mode.upper()
        # Create deep copy
        mutated = json.loads(json.dumps(payload))

        if mode == "SYNTAX":
            raw_str = json.dumps(mutated)
            return raw_str[:-2] + "!!!MALFORMED_JSON", True

        elif mode == "FIELD_DROP":
            if "sessions" in mutated and len(mutated["sessions"]) > 0:
                s = mutated["sessions"][0]
                s.pop("seq", None)
                s.pop("measured_at", None)
            return mutated, True

        elif mode == "TYPE_MUTATION":
            if "sessions" in mutated and len(mutated["sessions"]) > 0:
                mutated["sessions"][0]["door_open_sec"] = "NOT_A_NUMBER"
            return mutated, True

        elif mode == "INVALID_BANK":
            if "sessions" in mutated and len(mutated["sessions"]) > 0:
                mutated["sessions"][0]["bank_code"] = "UNKNOWN_NONEXISTENT_BANK"
            return mutated, True

        elif mode == "BITFLIP":
            raw_bytes = bytearray(json.dumps(mutated).encode("utf-8"))
            if len(raw_bytes) > 5:
                raw_bytes[5] ^= 0x01
            try:
                return json.loads(raw_bytes.decode("utf-8")), True
            except Exception:
                return raw_bytes.decode("latin1"), True

        return mutated, False
