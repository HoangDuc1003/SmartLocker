"""
Scores the verdicts of the production Java path (RuleEngine + RiskScorer via AlertService) on the 100 sessions of the
live simulator-v2 run, read back read-only from database SL_SIM.

Verdict of one session (decided before scoring, see REVISION2_LOG "Session B follow-up 8"):
  1. the alert the backend stored for the session's row, mapped with the evaluation's existing
     experiments/evaluate.py StatisticalEvaluator.map_prediction (labels with no category, e.g. ITEM_LEFT,
     ML_ANOMALY, WRONG_USER, become MISSED = wrong for every class);
  2. no alert and the credential was denied by /api/device/auth -> UNAUTHORIZED_CREDENTIAL;
  3. otherwise NORMAL_AUTHORIZED.
"Tier 1" ignores ML_ANOMALY alerts (rules only); "Tier 1+2" keeps them.
Replayed sessions are rejected by the backend as duplicates of an earlier row and get no verdict of their own:
counted as NORMAL_AUTHORIZED (no alert), the conservative choice.
Usage: python -I docs/paper/scripts/java_verdicts.py
"""
import csv
import datetime
import hashlib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, ROOT)
from experiments.evaluate import StatisticalEvaluator as ExperimentEvaluator  # noqa: E402  existing mapping, unchanged

RUN = "RUN_20261116_171508_SEED42_V2_SL_SIM"
SESSIONS = os.path.join(ROOT, "experiments", "runs", RUN, "sessions.csv")
STUDY_B = os.path.join(ROOT, "docs", "paper", "scripts", "results", "R2_STUDYB_V2_20261116T171537Z", "study_b_results.json")
CATS = ["NORMAL_AUTHORIZED", "UNAUTHORIZED_CREDENTIAL", "FORCED_DOOR_OPEN", "LOAD_OR_TAMPER_ANOMALY", "SENSOR_OR_NETWORK_FAULT"]


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def alerts(ids):
    q = ("SET NOCOUNT ON; SELECT a.session_id, a.source, a.label, a.alert_id FROM Alert a WHERE a.session_id IN (%s) "
         "ORDER BY a.session_id, a.alert_id" % ",".join(str(int(i)) for i in ids))
    out = subprocess.run(["sqlcmd", "-S", "localhost", "-E", "-d", "SL_SIM", "-h", "-1", "-W", "-s", ",", "-Q", q],
                         capture_output=True, text=True, check=True).stdout
    res = {}
    for line in out.splitlines():
        p = [x.strip() for x in line.split(",")]
        if len(p) == 4 and p[0].isdigit():
            res.setdefault(int(p[0]), []).append({"source": p[1], "label": p[2], "alert_id": int(p[3])})
    return res


def verdict(r, al, tier2, seen):
    sid = int(r["db_session_id"])
    if sid in seen:                       # replay: rejected as duplicate, no verdict of its own
        return "NORMAL_AUTHORIZED", "DUPLICATE_REJECTED"
    seen.add(sid)
    for a in al.get(sid, []):
        if a["label"] == "ML_ANOMALY" and not tier2:
            continue
        return ExperimentEvaluator.map_prediction(a["label"]), a["label"]
    if r["actual_auth_result"] == "DENY":
        return "UNAUTHORIZED_CREDENTIAL", "AUTH_DENY"
    return "NORMAL_AUTHORIZED", "NO_ALERT"


def metrics(y, p):
    per = {}
    for c in CATS:
        tp = sum(1 for a, b in zip(y, p) if a == c and b == c)
        pr = sum(1 for b in p if b == c)
        su = sum(1 for a in y if a == c)
        prec = tp / pr if pr else 0.0
        rec = tp / su if su else 0.0
        per[c] = {"precision": prec, "recall": rec, "f1": 2 * prec * rec / (prec + rec) if prec + rec else 0.0}
    acc = sum(1 for a, b in zip(y, p) if a == b) / len(y)
    yb = [a != "NORMAL_AUTHORIZED" for a in y]
    pb = [b != "NORMAL_AUTHORIZED" for b in p]
    tp = sum(1 for a, b in zip(yb, pb) if a and b)
    fp = sum(1 for a, b in zip(yb, pb) if not a and b)
    fn = sum(1 for a, b in zip(yb, pb) if a and not b)
    bprec, brec = tp / (tp + fp), tp / (tp + fn)
    return {"accuracy": acc, "macro": {k: sum(per[c][k] for c in CATS) / 5 for k in ("precision", "recall", "f1")},
            "per_class": per, "binary_anomaly_positive": {"accuracy": sum(1 for a, b in zip(yb, pb) if a == b) / len(y),
                                                          "precision": bprec, "recall": brec,
                                                          "f1": 2 * bprec * brec / (bprec + brec), "tp": tp, "fp": fp, "fn": fn},
            "confusion": {c: {d: sum(1 for a, b in zip(y, p) if a == c and b == d) for d in CATS} for c in CATS}}


def mcnemar(y, p1, p2):
    from math import comb
    yb = [a != "NORMAL_AUTHORIZED" for a in y]
    c1 = [a == (b != "NORMAL_AUTHORIZED") for a, b in zip(yb, p1)]
    c2 = [a == (b != "NORMAL_AUTHORIZED") for a, b in zip(yb, p2)]
    n01 = sum(1 for a, b in zip(c1, c2) if not a and b)   # first wrong, second right
    n10 = sum(1 for a, b in zip(c1, c2) if a and not b)
    n = n01 + n10
    p = min(1.0, 2 * sum(comb(n, k) for k in range(0, min(n01, n10) + 1)) / 2 ** n) if n else 1.0
    return {"n01_first_wrong_second_right": n01, "n10_first_right_second_wrong": n10, "exact_two_sided_p": p}


def main():
    rows = list(csv.DictReader(open(SESSIONS, encoding="utf-8")))
    assert len(rows) == 100
    al = alerts(sorted({int(r["db_session_id"]) for r in rows}))
    y = [r["category"] for r in rows]
    out = {"run": RUN, "inputs": {"sessions.csv": sha(SESSIONS)}, "per_session": []}
    preds = {}
    for name, tier2 in (("tier1", False), ("tier1_2", True)):
        seen, p, why = set(), [], []
        for r in rows:
            v, w = verdict(r, al, tier2, seen)
            p.append(v)
            why.append(w)
        preds[name] = p
        out[name] = metrics(y, p)
        out[name]["verdict_sources"] = {k: why.count(k) for k in sorted(set(why))}
    b = json.load(open(STUDY_B, encoding="utf-8"))
    b1 = [r["b1_predicted_label"] for r in rows]
    b1 = [ExperimentEvaluator.map_prediction(x) for x in b1]
    assert abs(metrics(y, b1)["macro"]["f1"] - b["seed42"]["B1"]["macro"]["f1"]) < 1e-9, "B1-P mapping differs from study_b"
    out["mcnemar_binary_java_tier1_2_vs_b1p"] = mcnemar(y, preds["tier1_2"], b1)
    out["mcnemar_binary_java_tier1_vs_b1p"] = mcnemar(y, preds["tier1"], b1)
    for i, r in enumerate(rows):
        out["per_session"].append({"session_id": r["session_id"], "category": y[i], "db_session_id": int(r["db_session_id"]),
                                   "alerts": al.get(int(r["db_session_id"]), []), "auth": r["actual_auth_result"],
                                   "tier1": preds["tier1"][i], "tier1_2": preds["tier1_2"][i]})
    out["timestamp_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    d = os.path.join(ROOT, "docs", "paper", "scripts", "results",
                     "R2_JAVA_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    os.makedirs(d)
    json.dump(out, open(os.path.join(d, "java_verdicts.json"), "w"), indent=1)
    for name in ("tier1", "tier1_2"):
        m = out[name]
        print(name, "acc %.3f macroF1 %.4f binaryF1 %.4f" % (m["accuracy"], m["macro"]["f1"], m["binary_anomaly_positive"]["f1"]),
              {c[:6]: round(m["per_class"][c]["recall"], 2) for c in CATS}, m["verdict_sources"])
    print(out["mcnemar_binary_java_tier1_2_vs_b1p"], out["mcnemar_binary_java_tier1_vs_b1p"])
    print(d)


if __name__ == "__main__":
    main()
