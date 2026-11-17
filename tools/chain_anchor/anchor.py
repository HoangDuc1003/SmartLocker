"""
External anchoring for the audit hash chain (prototype tool, outside the web application; the application and the
SQL schema are unchanged).

record: reads the current head (audit_id, chain_hash) of HashChain, read-only, and appends one line to an anchor file
        kept OUTSIDE the database (e.g. another machine, a git repository or printed); run it periodically
        (Task Scheduler / cron), e.g. every minute.
check:  verifies an exported ledger against the anchor file: every anchored audit_id must still be present with the
        same chain_hash. Together with the plain chain verification this reveals truncation and privileged rewrites
        of anchored history; entries written after the last anchor remain unprotected.

Usage:
  python -I tools/chain_anchor/anchor.py record --db SL_SIM --out anchors.csv
  python -I tools/chain_anchor/anchor.py check --ledger export.json --anchors anchors.csv
"""
import argparse
import csv
import datetime
import json
import subprocess


def anchors_violated(rows, anchors):
    """anchors: iterable of (audit_id, chain_hash). True if any anchored entry is missing or has another hash."""
    by_id = {int(r["audit_id"]): r["chain_hash"] for r in rows}
    return any(by_id.get(int(a)) != h for a, h in anchors)


def record(db, out):
    q = "SET NOCOUNT ON; SELECT TOP 1 audit_id, chain_hash FROM HashChain ORDER BY anchor_id DESC"
    res = subprocess.run(["sqlcmd", "-S", "localhost", "-E", "-d", db, "-h", "-1", "-W", "-s", ",", "-Q", q],
                         capture_output=True, text=True, check=True).stdout
    audit_id, chain_hash = [x.strip() for x in res.strip().splitlines()[0].split(",")]
    with open(out, "a", newline="", encoding="utf-8") as f:
        csv.writer(f).writerow([datetime.datetime.now(datetime.timezone.utc).isoformat(), db, audit_id, chain_hash])
    print("anchored", db, audit_id, chain_hash)


def check(ledger, anchors_file):
    rows = json.load(open(ledger, encoding="utf-8"))
    anchors = [(r[2], r[3]) for r in csv.reader(open(anchors_file, encoding="utf-8")) if r]
    bad = anchors_violated(rows, anchors)
    print("ANCHORS VIOLATED" if bad else "anchors ok", "(%d anchors)" % len(anchors))
    return 1 if bad else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record")
    r.add_argument("--db", required=True)
    r.add_argument("--out", required=True)
    c = sub.add_parser("check")
    c.add_argument("--ledger", required=True)
    c.add_argument("--anchors", required=True)
    a = ap.parse_args()
    raise SystemExit(record(a.db, a.out) if a.cmd == "record" else check(a.ledger, a.anchors))
