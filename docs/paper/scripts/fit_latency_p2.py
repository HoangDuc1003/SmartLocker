"""
P2 calibration: fit the testbed's baseline latency from the real client round trips of the live run
RUN_20261116_044130_SEED42_SL_SIM (backend_responses.jsonl, field elapsed_ms). No point is removed or adjusted.

Model: log-normal, maximum likelihood (mu = mean(ln x), sigma = population SD of ln x). Fit quality: one-sample
Kolmogorov-Smirnov statistic D against the fitted CDF (descriptive only; parameters estimated from the same data).
Usage: python docs/paper/scripts/fit_latency_p2.py
"""
import datetime
import hashlib
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = "experiments/runs/RUN_20261116_044130_SEED42_SL_SIM/backend_responses.jsonl"


def q(v, p):
    v = sorted(v)
    h = (len(v) - 1) * p
    lo = int(h)
    return v[lo] + (v[min(lo + 1, len(v) - 1)] - v[lo]) * (h - lo)


def fit(x):
    assert x and min(x) > 0
    lx = [math.log(v) for v in x]
    mu = sum(lx) / len(lx)
    sigma = math.sqrt(sum((v - mu) ** 2 for v in lx) / len(lx))
    cdf = lambda v: 0.5 * (1 + math.erf((math.log(v) - mu) / (sigma * math.sqrt(2))))  # noqa: E731
    s = sorted(x)
    n = len(s)
    d = max(max((i + 1) / n - cdf(v), cdf(v) - i / n) for i, v in enumerate(s))
    return {"n": n, "mu_log_ms": mu, "sigma_log": sigma, "median_ms_exp_mu": math.exp(mu),
            "mean_ms_model": math.exp(mu + sigma ** 2 / 2), "ks_D": d, "ks_D_crit_0.05_approx": 1.36 / math.sqrt(n),
            "empirical_ms": {"min": s[0], "p25": q(s, .25), "median": q(s, .5), "p75": q(s, .75),
                             "p95": q(s, .95), "max": s[-1], "mean": sum(s) / n}}


def main():
    by = {}
    with open(os.path.join(ROOT, SRC), encoding="utf-8") as f:
        for line in f:
            if line.strip():
                j = json.loads(line)
                by.setdefault(j["endpoint"], []).append(float(j["elapsed_ms"]))
    res = {"source": SRC, "source_sha256": hashlib.sha256(open(os.path.join(ROOT, SRC), "rb").read()).hexdigest(),
           "model": "log-normal, MLE on ln(elapsed_ms)",
           "fits": {k: fit(v) for k, v in by.items()},
           "fit_pooled": fit([v for vs in by.values() for v in vs]),
           "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    assert res["fits"]["/api/locker/batch"]["n"] == 100 and res["fits"]["/api/device/auth"]["n"] == 40
    d = os.path.join(ROOT, "docs", "paper", "scripts", "results",
                     "R2_P2FIT_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    os.makedirs(d, exist_ok=False)
    json.dump(res, open(os.path.join(d, "p2_latency_fit.json"), "w", encoding="utf-8"), indent=1)
    print(json.dumps(res, indent=1))
    print(d)


if __name__ == "__main__":
    main()
