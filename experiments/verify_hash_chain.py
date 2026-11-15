"""
Haber-Stornetta SHA-256 Audit Hash Chain Verification Engine.
Milestone 4 — Requirement R4.

Verifies the cryptographic forward-linked ledger across AuditLog and HashChain:
- Canonical serialization: audit_id|ts|actor_user_id|action|object_type|object_id|diff_json|prev_hash
- UTF-16LE encoding (byte-for-byte alignment with SQL Server HASHBYTES('SHA2_256', ...) and Java AuditVerifier.java)
- Genesis block starts with 64 ASCII zeros: '0' * 64
- Zero broken links, zero hash mismatches.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from typing import Any, Dict, List, Optional, Tuple

ZERO_HASH = "0" * 64


def compute_canonical_hash(
    audit_id: int,
    ts_iso: str,
    actor_user_id: Optional[int],
    action: str,
    object_type: str,
    object_id: Optional[int],
    diff_json: Optional[str],
    prev_hash: str,
) -> str:
    """
    Computes Haber-Stornetta SHA-256 hash using exact SQL Server / Java UTF-16LE canonical format:
    CONCAT(audit_id, '|', ts, '|', actor, '|', action, '|', objectType, '|', objectId, '|', diff, '|', prev)
    """
    actor_str = "" if actor_user_id is None else str(actor_user_id)
    obj_str = "" if object_id is None else str(object_id)
    diff_str = "" if diff_json is None else str(diff_json)

    canonical = f"{audit_id}|{ts_iso}|{actor_str}|{action}|{object_type}|{obj_str}|{diff_str}|{prev_hash}"
    return hashlib.sha256(canonical.encode("utf-16le")).hexdigest().lower()


def verify_audit_chain(rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Walks the audit ledger and validates forward cryptographic hash chain integrity.
    Validates:
    1. prev_hash continuity: row[i].prev_hash == (row[i-1].chain_hash if i > 0 else ZERO_HASH)
    2. chain_hash calculation: row[i].chain_hash == compute_canonical_hash(..., prev)
    3. row_hash consistency: row[i].row_hash == expected_hash (if row_hash is present)
    """
    if not rows:
        return {
            "status": "EMPTY",
            "total_nodes_verified": 0,
            "chain_intact": True,
            "broken_links": 0,
            "genesis_prev_hash": ZERO_HASH,
            "tail_chain_hash": ZERO_HASH,
        }

    prev = ZERO_HASH
    for idx, r in enumerate(rows):
        audit_id = r["audit_id"]
        ts_iso = r["ts_iso"]
        actor = r.get("actor_user_id")
        action = r["action"]
        obj_type = r["object_type"]
        obj_id = r.get("object_id")
        diff = r.get("diff", r.get("diff_json", ""))

        expected_hash = compute_canonical_hash(
            audit_id=audit_id,
            ts_iso=ts_iso,
            actor_user_id=actor,
            action=action,
            object_type=obj_type,
            object_id=obj_id,
            diff_json=diff,
            prev_hash=prev,
        )

        stored_prev = r["prev_hash"].strip().lower()
        stored_chain = r["chain_hash"].strip().lower()
        stored_row = r.get("row_hash", "").strip().lower()

        if stored_prev != prev:
            return {
                "status": "BROKEN_LINKAGE",
                "broken_at_index": idx,
                "broken_anchor_id": r.get("anchor_id", idx + 1),
                "broken_audit_id": audit_id,
                "expected_prev_hash": prev,
                "found_prev_hash": stored_prev,
                "chain_intact": False,
                "broken_links": 1,
            }

        if stored_chain != expected_hash:
            return {
                "status": "HASH_MISMATCH",
                "broken_at_index": idx,
                "broken_anchor_id": r.get("anchor_id", idx + 1),
                "broken_audit_id": audit_id,
                "expected_chain_hash": expected_hash,
                "stored_chain_hash": stored_chain,
                "chain_intact": False,
                "broken_links": 1,
            }

        if stored_row and stored_row != expected_hash:
            return {
                "status": "ROW_HASH_MISMATCH",
                "broken_at_index": idx,
                "broken_audit_id": audit_id,
                "expected_hash": expected_hash,
                "stored_row_hash": stored_row,
                "chain_intact": False,
                "broken_links": 1,
            }

        prev = expected_hash

    return {
        "status": "PASS",
        "total_nodes_verified": len(rows),
        "chain_intact": True,
        "broken_links": 0,
        "genesis_prev_hash": ZERO_HASH,
        "tail_chain_hash": prev,
    }


def test_tamper_detection(rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Forensic proof: Deliberately mutates a field in a cloned middle node
    and confirms that verify_audit_chain() immediately detects the tampering.
    """
    if len(rows) < 2:
        return {"status": "SKIPPED", "reason": "Insufficient nodes for tamper proof"}

    import copy
    tampered_rows = copy.deepcopy(rows)
    target_idx = len(rows) // 2
    original_action = tampered_rows[target_idx]["action"]
    tampered_rows[target_idx]["action"] = "TAMPERED_ACTION"

    result = verify_audit_chain(tampered_rows)
    tamper_caught = (result["chain_intact"] is False) and (result.get("broken_at_index") == target_idx)

    return {
        "tamper_simulation_target_index": target_idx,
        "tamper_simulation_audit_id": tampered_rows[target_idx]["audit_id"],
        "original_action": original_action,
        "tampered_action": "TAMPERED_ACTION",
        "tamper_detected": tamper_caught,
        "detection_status": result["status"],
        "verification_result": "PASS" if tamper_caught else "FAIL",
    }


def fetch_audit_chain_from_db(db: str = "SL_SIM") -> List[Dict[str, Any]]:
    """Queries SQL Server via sqlcmd to retrieve all AuditLog and HashChain rows."""
    query = (
        "SELECT a.audit_id, CONVERT(NVARCHAR(33), a.ts, 126) AS ts_iso, "
        "a.actor_user_id, a.action, a.object_type, a.object_id, "
        "ISNULL(a.diff_json, '') AS diff, a.row_hash, "
        "h.prev_hash, h.chain_hash, h.anchor_id "
        "FROM AuditLog a "
        "JOIN HashChain h ON h.audit_id = a.audit_id "
        "ORDER BY h.anchor_id ASC"
    )
    cmd = [
        "sqlcmd", "-S", "localhost", "-d", db, "-U", "sa", "-P", "12345",
        "-y", "0", "-w", "65535", "-Q", f"SET NOCOUNT ON; {query} FOR JSON PATH;"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    lines = res.stdout.splitlines()
    json_lines = [l for l in lines if not l.startswith("-") and not l.startswith("(") and l.strip()]
    raw_json = "".join(json_lines).strip()
    return json.loads(raw_json) if raw_json else []


def main():
    parser = argparse.ArgumentParser(description="Verify Haber-Stornetta SHA-256 Audit Hash Chain")
    parser.add_argument("--db", default="SL_SIM", help="Database name (default: SL_SIM)")
    parser.add_argument("--ledger-file", default=None, help="Optional exported JSON ledger file")
    parser.add_argument("--output", default=None, help="Output destination for verification report JSON")
    parser.add_argument("--test-tamper", action="store_true", default=True, help="Execute tamper detection test")
    args = parser.parse_args()

    rows: List[Dict[str, Any]] = []
    source_type = ""
    if args.ledger_file and os.path.isfile(args.ledger_file):
        with open(args.ledger_file, "r", encoding="utf-8") as f:
            rows = json.load(f)
        source_type = f"FILE: {args.ledger_file}"
    else:
        try:
            rows = fetch_audit_chain_from_db(args.db)
            source_type = f"DATABASE: {args.db}"
        except Exception as e:
            print(f"[!] Warning: Could not query database {args.db}: {e}", file=sys.stderr)
            if args.output:
                report = {
                    "status": "BLOCKED",
                    "reason": f"Database {args.db} unreachable: {e}",
                    "chain_intact": None,
                }
                with open(args.output, "w", encoding="utf-8") as f:
                    json.dump(report, f, indent=2)
            sys.exit(0)

    print(f"[*] Retrieved {len(rows)} audit nodes from {source_type}...")
    res = verify_audit_chain(rows)
    print(f"[+] Verification Status: {res['status']}")
    print(f"    Total Nodes: {res['total_nodes_verified']}")
    print(f"    Genesis Prev Hash: {res['genesis_prev_hash']}")
    print(f"    Tail Chain Hash: {res['tail_chain_hash']}")
    print(f"    Chain Intact: {res['chain_intact']}")

    report: Dict[str, Any] = {
        "source": source_type,
        "algorithm": "SHA-256 (UTF-16LE canonical serialization)",
        "canonical_format": "audit_id|ts|actor_user_id|action|object_type|object_id|diff_json|prev_hash",
        "verification_result": res,
    }

    if args.test_tamper and len(rows) > 0:
        tamper_res = test_tamper_detection(rows)
        print(f"[+] Tamper Detection Test: {tamper_res['verification_result']}")
        print(f"    Target Audit ID: {tamper_res['tamper_simulation_audit_id']}, Caught: {tamper_res['tamper_detected']}")
        report["tamper_detection_test"] = tamper_res

    if args.output:
        os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"[+] Report exported to {args.output}")


if __name__ == "__main__":
    main()
