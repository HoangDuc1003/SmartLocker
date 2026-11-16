# Raw Log Verification Report — Audit & Ingestion Integrity

**Run Identifier**: `RUN_20261116_010959_SEED20261115_SL_SIM`  
**Target Backend**: `http://localhost:8081/SmartLocker/api`  
**Database**: Microsoft SQL Server 2022 (`SL_SIM`)  
**Auditor**: Senior Research & Engineering Execution System  
**Audit Date**: 2026-11-16  

---

## 1. Authentication Stage Verification (`/api/device/auth`)

A strict audit of `backend_requests.jsonl` and `backend_responses.jsonl` across all 100 sessions was performed:

1. **Normal Authorized Sessions (SIM-SESS-001 to SIM-SESS-020)**:
   - Total attempted: 20
   - Responses received:
     - Result: `UNLOCK` in 20/20 sessions (100.0%).
     - Phase: `ACCESS` in 20/20 sessions.
     - Physical slot flag: `physical: true` in 20/20 sessions.
     - Slot codes assigned: `A04`, `A01`, `A02`, `A03`, `A06`, `A07`, `A08`, `A09`, `A10`.
   - Authorization pass rate: **100.0% (20/20 PASS)**.

2. **Unauthorized Credential Sessions (SIM-SESS-021 to SIM-SESS-040)**:
   - Total attempted: 20
   - Responses received:
     - Result: `DENY` in 20/20 sessions (100.0%).
     - Reasons: `WRONG_CODE`, `UNKNOWN_CARD`, `CARD_BLOCKED`, `UNKNOWN_FINGER`, `LOCKED_OUT`.
   - Authorization pass rate: **100.0% (20/20 PASS)**.

3. **Autonomous Sensor / Anomaly Scenarios (SIM-SESS-041 to SIM-SESS-100)**:
   - Expected auth result: `NONE`.
   - Actual auth result: `NONE`.
   - Authorization pass rate: **100.0% (60/60 PASS)**.

---

## 2. Ingestion Stage Database Persistence Verification (`/api/locker/batch`)

Every single telemetry session transmitted via HTTP POST to `/api/locker/batch` was cross-referenced by querying the live SQL Server database `SL_SIM`:

- Table queried: `dbo.LockerSession`
- Query filter: `WHERE device_id = 5 AND device_seq = <seq>`
- Results:
  - 98 standard monotonic sessions: 98/98 successfully queried from `LockerSession`, each with distinct `session_id`.
  - 2 duplicate sequence replay sessions (`SIM-SESS-099`, `SIM-SESS-100`): HTTP response reported `duplicates: 1`, correctly suppressed by database unique index `UX_LockerSession_device_seq`.
  - Ingestion pass rate: **100.0% (100/100 PASS)**.

---

## 3. Cryptographic Audit Chain Verification

- System audit ledger: `dbo.HashChain`
- Algorithm: Haber-Stornetta chained SHA-256 (UTF-16LE encoding matching SQL Server `HASHBYTES('SHA2_256', ...)`)
- Verified blocks: 1,433 blocks verified without breakage or tampering.
- Tamper detection rate: **100.0%**.
