"""
Revision-2 latency recomputation from raw logs, one scope per block (never merged):
  A. endpoint server processing  docs/paper/evidence/latency.log (curl time_total, localhost, 30 per endpoint, 30 Oct 2026)
  B. client round trip per call   experiments/runs/<LIVE_RUN>/backend_responses.jsonl (Python client, localhost, 16 Nov 2026)
  C. harness wall time / session  experiments/runs/<LIVE_RUN>/sessions.csv duration_ms (includes harness DB queries)
Median = mean of the two middle values; P95 = linear interpolation between order statistics (n is small: descriptive only).
Usage: python docs/paper/scripts/latency_recompute.py
"""
import csv
import datetime
import hashlib
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LIVE_RUN = "RUN_20261116_044130_SEED42_SL_SIM"
SRC = {
    "A": "docs/paper/evidence/latency.log",
    "B": "experiments/runs/%s/backend_responses.jsonl" % LIVE_RUN,
    "C": "experiments/runs/%s/sessions.csv" % LIVE_RUN,
}


def q(v, p):
    v = sorted(v)
    h = (len(v) - 1) * p
    lo = int(h)
    return v[lo] + (v[min(lo + 1, len(v) - 1)] - v[lo]) * (h - lo)


def desc(v):
    return {"n": len(v), "median": q(v, 0.5), "min": min(v), "max": max(v), "mean": sum(v) / len(v),
            "p95_linear": q(v, 0.95), "p95_nearest_rank": sorted(v)[max(0, -(-95 * len(v) // 100) - 1)]}


def main():
    out = {"scopes": {}}
    a = {}
    for line in open(os.path.join(ROOT, SRC["A"]), encoding="utf-8"):
        p = line.split()
        if len(p) >= 5 and p[0] == "RAW":
            assert p[3] == "200", line
            a.setdefault(p[1], []).append(float(p[4]) * 1000)
    out["scopes"]["A_endpoint_server_processing_ms"] = {k: desc(v) for k, v in a.items()}
    b = {}
    for line in open(os.path.join(ROOT, SRC["B"]), encoding="utf-8"):
        if line.strip():
            j = json.loads(line)
            b.setdefault(j["endpoint"], []).append(j["elapsed_ms"])
    out["scopes"]["B_client_round_trip_ms"] = {k: desc(v) for k, v in b.items()}
    c = [float(r["duration_ms"]) for r in csv.DictReader(open(os.path.join(ROOT, SRC["C"]), encoding="utf-8"))]
    out["scopes"]["C_harness_wall_time_per_session_ms"] = desc(c)
    assert all(len(v) == 30 for v in a.values()), {k: len(v) for k, v in a.items()}
    assert len(c) == 100
    out["manifest"] = {
        "script": "docs/paper/scripts/latency_recompute.py",
        "inputs": {p: hashlib.sha256(open(os.path.join(ROOT, p), "rb").read()).hexdigest() for p in SRC.values()},
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    run_id = "R2_LATENCY_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    d = os.path.join(ROOT, "docs", "paper", "scripts", "results", run_id)
    os.makedirs(d, exist_ok=False)
    json.dump(out, open(os.path.join(d, "latency.json"), "w", encoding="utf-8"), indent=1)
    print(json.dumps(out["scopes"], indent=1))
    print(d)


if __name__ == "__main__":
    main()
