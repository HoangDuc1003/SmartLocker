"""
Deterministic hash-chain tamper campaign on an EXPORTED COPY of AuditLog + HashChain (never the live DB).

Hash construction verified against sql/01_schema.sql (Audit_Append):
  row = CONCAT(audit_id,'|',CONVERT(NVARCHAR(33),ts,126),'|',actor,'|',action,'|',object_type,'|',object_id,'|',
               ISNULL(diff,''),'|',prev);  hash = lower(hex(SHA2_256(UTF-16LE row)));  genesis prev = '0'*64
The verifier is experiments/verify_hash_chain.verify_audit_chain (imported, not copied).

Each category is a set of integrity test cases, not an estimate of a general detection rate.

Usage:
  python tools/tamper_campaign/tamper_campaign.py --ledger <export.json> [--n 20] [--seed 20261116] [--anchor-every K]
  --anchor-every K: also check external anchors (tools/chain_anchor) taken from the original chain at every K-th entry
  python tools/tamper_campaign/tamper_campaign.py --selftest      # synthetic chain, checks this tool only
Export (author, read-only query on a copy):  see docs/paper/REVISION2_LOG.md, "Owner actions".
"""
import argparse
import copy
import datetime
import hashlib
import json
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from experiments.verify_hash_chain import ZERO_HASH, compute_canonical_hash, verify_audit_chain  # noqa: E402
sys.path.insert(0, os.path.join(ROOT, "tools", "chain_anchor"))
from anchor import anchors_violated  # noqa: E402

FIELDS = ["action", "object_type", "diff", "actor_user_id"]


def rehash(rows, start=0):
    """Recompute prev/chain/row hashes from `start` on: what a privileged writer could do."""
    prev = rows[start - 1]["chain_hash"] if start else ZERO_HASH
    for r in rows[start:]:
        h = compute_canonical_hash(r["audit_id"], r["ts_iso"], r.get("actor_user_id"), r["action"],
                                   r["object_type"], r.get("object_id"), r.get("diff", r.get("diff_json", "")), prev)
        r["prev_hash"], r["chain_hash"], r["row_hash"] = prev, h, h
        prev = h
    return rows


def detected(rows, anchors=()):
    return (not verify_audit_chain(rows)["chain_intact"]) or anchors_violated(rows, anchors)


def campaign(rows, n, seed, anchor_every=0):
    assert verify_audit_chain(rows)["status"] == "PASS", "export does not verify; fix the export first"
    rng = random.Random(seed)
    L = len(rows)
    assert L >= 4
    cases = {}
    anchors = [(r["audit_id"], r["chain_hash"]) for r in rows[anchor_every - 1::anchor_every]] if anchor_every else []

    def run(name, mutate, limitation=""):
        hits = 0
        for _ in range(n):
            t = copy.deepcopy(rows)
            t = mutate(t)
            hits += detected(t, anchors)
        cases[name] = {"attempted": n, "detected": hits, "limitation": limitation}

    def modify(t):
        i, f = rng.randrange(L), rng.choice(FIELDS)
        t[i][f] = (str(t[i].get(f)) + "X") if f != "actor_user_id" else (t[i].get(f) or 0) + 1
        return t

    def delete_mid(t):
        del t[rng.randrange(1, L - 1)]
        return t

    def reorder(t):
        i = rng.randrange(0, L - 1)
        t[i], t[i + 1] = t[i + 1], t[i]
        return t

    def forge_at(t, i):
        forged = dict(t[i - 1], audit_id=10 ** 9 + rng.randrange(10 ** 6), action="FORGED")
        t.insert(i, forged)
        return rehash(t[: i + 1], i) + t[i + 1:]  # forged row correctly linked, later rows untouched

    def insert(t):
        return forge_at(t, rng.randrange(1, L))

    def append_tail(t):
        return forge_at(t, L)

    def truncate(t):
        return t[: L - rng.randrange(1, min(L - 1, 50) + 1)]

    def privileged_rewrite(t):
        i = rng.randrange(L)
        t[i]["action"] = str(t[i]["action"]) + "X"
        return rehash(t, i)

    run("field_modification", modify)
    run("mid_chain_deletion", delete_mid)
    run("reordering_adjacent_swap", reorder)
    run("mid_chain_insertion", insert)
    run("tail_append", append_tail, "an anchor cannot tell a forged new entry from a genuine one" if anchors
        else "not detectable without an external head/checkpoint")
    after = "only entries written after the newest anchor are unprotected"
    run("tail_truncation", truncate, after if anchors else "not detectable without an external head/checkpoint")
    run("privileged_rewrite_and_rehash", privileged_rewrite, after if anchors else
        "a DB administrator can rewrite history and recompute the chain absent external anchoring")
    return cases


def synthetic(L=60):
    rows = []
    for i in range(1, L + 1):
        rows.append({"audit_id": i, "ts_iso": "2026-11-16T00:00:%02d.0000000" % (i % 60), "actor_user_id": i % 5 or None,
                     "action": "CREATE", "object_type": "Deposit", "object_id": i * 7, "diff": '{"k":%d}' % i})
    return rehash(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger")
    ap.add_argument("--n", type=int, default=20)
    ap.add_argument("--seed", type=int, default=20261116)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--anchor-every", type=int, default=0)
    a = ap.parse_args()
    if a.selftest:
        c = campaign(synthetic(), a.n, a.seed)
        expect = {"field_modification": a.n, "mid_chain_deletion": a.n, "reordering_adjacent_swap": a.n,
                  "mid_chain_insertion": a.n, "tail_append": 0, "tail_truncation": 0,
                  "privileged_rewrite_and_rehash": 0}
        assert {k: v["detected"] for k, v in c.items()} == expect, c
        c1 = campaign(synthetic(), a.n, a.seed, anchor_every=1)  # an anchor on every entry
        assert {k: v["detected"] for k, v in c1.items()} == dict(expect, tail_truncation=a.n,
                                                                privileged_rewrite_and_rehash=a.n), c1
        print("SELFTEST PASS (synthetic chain; not a reportable result)")
        print(json.dumps(c, indent=1))
        return
    rows = json.load(open(a.ledger, encoding="utf-8"))
    res = {"ledger": a.ledger, "ledger_sha256": hashlib.sha256(open(a.ledger, "rb").read()).hexdigest(),
           "records": len(rows), "n_per_category": a.n, "seed": a.seed, "anchor_every": a.anchor_every,
           "baseline_verification": verify_audit_chain(rows), "categories": campaign(rows, a.n, a.seed, a.anchor_every),
           "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    run_id = "R2_TAMPER_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    d = os.path.join(ROOT, "docs", "paper", "scripts", "results", run_id)
    os.makedirs(d, exist_ok=False)
    json.dump(res, open(os.path.join(d, "tamper_campaign.json"), "w", encoding="utf-8"), indent=1)
    print(json.dumps(res["categories"], indent=1))
    print(d)


if __name__ == "__main__":
    main()
