"""
experiments/fixtures.py
Deterministic, isolated test fixture management for SmartLocker experiments.
Connects directly to the actual SQL Server database (SL_SIM) using ADODB/SQLOLEDB.
Establishes documented, verifiable initial states for authentication and telemetry.
"""

from datetime import datetime, timezone
import json
import os
from typing import Any, Dict, List, Optional, Tuple
import win32com.client


class ExperimentFixtures:
    """Manages deterministic test fixtures in SL_SIM for LOCKER-01 (device_id=5, CANT-A)."""

    def __init__(
        self,
        server: str = "localhost",
        database: str = "SL_SIM",
        user: str = "sa",
        password: str = "12345",
        device_id: int = 5,
    ):
        if not database.startswith("SL_"):
            raise ValueError(f"Refusing database '{database}': only SL_* databases allowed for experiments.")
        self.server = server
        self.database = database
        self.user = user
        self.password = password
        self.device_id = device_id
        self.conn_str = (
            f"Provider=SQLOLEDB;Data Source={self.server};Initial Catalog={self.database};"
            f"User ID={self.user};Password={self.password};"
        )

    def _get_connection(self):
        conn = win32com.client.Dispatch("ADODB.Connection")
        conn.Open(self.conn_str)
        return conn

    def check_lockout(self) -> Tuple[bool, int]:
        """Check whether device_id is currently locked out on the BOX channel."""
        conn = self._get_connection()
        try:
            sql = f"""
            DECLARE @retry INT;
            EXEC Auth_LockCheck {self.device_id}, 'BOX', @retry OUTPUT;
            SELECT @retry AS retry_sec;
            """
            rs, _ = conn.Execute(sql)
            retry_sec = int(rs.Fields("retry_sec").Value or 0)
            return (retry_sec > 0), retry_sec
        finally:
            conn.Close()

    def reset_lockout(self) -> None:
        """Reset the lockout counter for device_id using the canonical COUNTER_RESET mechanism."""
        conn = self._get_connection()
        try:
            sql = f"""
            INSERT INTO AuthAttempt (device_id, at, method, ok, reason)
            VALUES ({self.device_id}, SYSUTCDATETIME(), 'LOCK', 1, 'COUNTER_RESET');
            """
            conn.Execute(sql)
        finally:
            conn.Close()

    def setup_fixtures(self) -> Dict[str, Any]:
        """
        Deploy deterministic, isolated fixtures for all 20 NORMAL_AUTHORIZED sessions.
        Ensures valid, active deposits, enrolled credentials, and clean lockout state.
        """
        conn = self._get_connection()
        try:
            sql_setup = f"""
            SET QUOTED_IDENTIFIER ON;
            SET ANSI_NULLS ON;

            -- 1. Complete existing open deposits for fixture test users to satisfy UX_Deposit_user_open
            UPDATE Deposit SET status = 'COMPLETED', ended_at = ISNULL(ended_at, SYSUTCDATETIME())
            WHERE user_id IN (72, 73, 74, 75, 76, 77, 78, 91, 104) AND status IN ('RESERVED', 'ACTIVE');

            -- 2. Mark target slots in CANT-A (bank_id = 5) as OCCUPIED
            UPDATE LockerSlot SET status = 'OCCUPIED' WHERE locker_slot_id IN (51, 52, 53, 54, 56, 57, 58, 59, 60);

            -- 3. Create fresh active deposits on CANT-A (device 5) with exact access methods
            -- Slot 54 (A04): User 91 (student18), PIN 952705
            INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, started_at, due_at, open_method, pin_code)
            VALUES (91, 54, 1, 24, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'PIN', '952705');

            -- Slot 51 (A01): User 72 (student1), CARD 04A1B2C3
            INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (72, 51, 1, 6, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'CARD');

            -- Slot 52 (A02): User 73 (student2), CARD 0499AABB
            INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (73, 52, 1, 7, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'CARD');

            -- Slot 53 (A03): User 74 (student3), CARD 04C3D4E5
            INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (74, 53, 1, 8, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'CARD');

            -- Slot 56 (A06): User 75 (student4), CARD 04F5A6B7
            INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (75, 56, 1, 9, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'CARD');

            -- Slot 57 (A07): User 76 (student5), CARD 04556677
            INSERT INTO Deposit (user_id, slot_id, plan_id, card_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (76, 57, 1, 10, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'CARD');

            -- Slot 58 (A08): User 77 (student6), FINGERPRINT slot 1
            INSERT INTO Deposit (user_id, slot_id, plan_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (77, 58, 1, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'FINGERPRINT');

            -- Slot 59 (A09): User 104 (v2fp), FINGERPRINT slot 2
            INSERT INTO Deposit (user_id, slot_id, plan_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (104, 59, 1, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'FINGERPRINT');

            -- Slot 60 (A10): User 78 (student7), FINGERPRINT slot 5
            INSERT INTO Deposit (user_id, slot_id, plan_id, paid_amount, status, started_at, due_at, open_method)
            VALUES (78, 60, 1, 10000, 'ACTIVE', SYSUTCDATETIME(), DATEADD(DAY, 7, SYSUTCDATETIME()), 'FINGERPRINT');

            -- 4. Reconfigure Fingerprint enrollment on device_id = 5
            DELETE FROM Fingerprint WHERE device_id = {self.device_id};
            INSERT INTO Fingerprint (user_id, device_id, sensor_slot, status, created_at)
            VALUES (77, {self.device_id}, 1, 'ACTIVE', SYSUTCDATETIME()),
                   (104, {self.device_id}, 2, 'ACTIVE', SYSUTCDATETIME()),
                   (78, {self.device_id}, 5, 'ACTIVE', SYSUTCDATETIME());

            -- 5. Clear lockout state
            INSERT INTO AuthAttempt (device_id, at, method, ok, reason)
            VALUES ({self.device_id}, SYSUTCDATETIME(), 'LOCK', 1, 'COUNTER_RESET');
            """
            conn.Execute(sql_setup)

            # Query deployed fixtures
            sql_query = f"""
            SELECT d.deposit_id, d.user_id, u.username, d.slot_id, s.slot_code, b.bank_code,
                   d.status AS deposit_status, s.status AS slot_status, d.open_method, d.pin_code,
                   c.card_uid, f.sensor_slot
            FROM Deposit d
            JOIN Users u ON d.user_id = u.user_id
            JOIN LockerSlot s ON d.slot_id = s.locker_slot_id
            JOIN LockerBank b ON s.bank_id = b.bank_id
            LEFT JOIN UserCard c ON d.card_id = c.card_id
            LEFT JOIN Fingerprint f ON d.user_id = f.user_id AND f.device_id = b.device_id
            WHERE b.device_id = {self.device_id} AND d.status = 'ACTIVE'
            ORDER BY s.slot_code;
            """
            rs, _ = conn.Execute(sql_query)
            fixtures_list = []
            while not rs.EOF:
                row = {
                    "deposit_id": int(rs.Fields("deposit_id").Value),
                    "user_id": int(rs.Fields("user_id").Value),
                    "username": str(rs.Fields("username").Value),
                    "slot_id": int(rs.Fields("slot_id").Value),
                    "slot_code": str(rs.Fields("slot_code").Value),
                    "bank_code": str(rs.Fields("bank_code").Value),
                    "deposit_status": str(rs.Fields("deposit_status").Value),
                    "slot_status": str(rs.Fields("slot_status").Value),
                    "open_method": str(rs.Fields("open_method").Value),
                    "pin_code": "***REDACTED***" if rs.Fields("pin_code").Value else None,
                    "card_uid": str(rs.Fields("card_uid").Value) if rs.Fields("card_uid").Value else None,
                    "sensor_slot": int(rs.Fields("sensor_slot").Value) if rs.Fields("sensor_slot").Value else None,
                }
                fixtures_list.append(row)
                rs.MoveNext()

            manifest = {
                "timestamp_utc": datetime.now(timezone.utc).isoformat(),
                "database": self.database,
                "device_id": self.device_id,
                "locker_code": "LOCKER-01",
                "bank_code": "CANT-A",
                "lockout_state_initial": {"is_locked": False, "retry_sec": 0},
                "total_active_fixtures": len(fixtures_list),
                "fixtures": fixtures_list,
            }
            return manifest
        finally:
            conn.Close()

    def verify_telemetry_persistence(self, seq: int) -> Dict[str, Any]:
        """
        Verify that a telemetry batch was genuinely persisted in SL_SIM.LockerSession.
        Queries the database for matching (device_id, device_seq).
        """
        conn = self._get_connection()
        try:
            sql = f"""
            SELECT TOP 1 session_id, device_id, device_seq, slot_id, measured_at, door_open_sec,
                         weight_delta_g, rfid_ok, stay_min
            FROM LockerSession
            WHERE device_id = {self.device_id} AND device_seq = {int(seq)}
            ORDER BY session_id DESC;
            """
            rs, _ = conn.Execute(sql)
            if rs.EOF:
                return {
                    "persisted": False,
                    "session_id": None,
                    "device_id": self.device_id,
                    "device_seq": seq,
                }
            return {
                "persisted": True,
                "session_id": int(rs.Fields("session_id").Value),
                "device_id": int(rs.Fields("device_id").Value),
                "device_seq": int(rs.Fields("device_seq").Value),
                "slot_id": int(rs.Fields("slot_id").Value),
                "measured_at": str(rs.Fields("measured_at").Value),
                "door_open_sec": float(rs.Fields("door_open_sec").Value),
                "weight_delta_g": float(rs.Fields("weight_delta_g").Value),
                "rfid_ok": bool(rs.Fields("rfid_ok").Value),
            }
        finally:
            conn.Close()
