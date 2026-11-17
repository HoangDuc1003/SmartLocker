"""
Sensitivity of the Study B conclusions to the assumed parameters of simulator v2 (separate analysis; the frozen
experiments/v2/generator_v2.py is not edited, its distribution functions are replaced in memory for each variant).

Variants (fixed before running, see REVISION2_LOG "Session B follow-up 8"): the class-separating medians of the
approved table 1.3 scaled one at a time by 0.7 and 1.3 (tamper vibration 0.30 g, forced vibration 0.50 g, hammer/forced
shock 3 g, tilt-tamper 3 deg, forced door time 6 s, weight-spoof 80 g), plus two joint variants that scale all six
together (0.7 = anomalies closer to normal use, 1.3 = further away). Not varied: the timeout delay (set inside the
generator class), card-state mixtures, noise operators.
For each variant: five seeds x 100 sessions; B0 and B1-P macro-F1 (mean and sample SD over seeds) and J48
leave-one-seed-out macro-F1 on the 12 observable inputs, exactly as in study_b_analysis.py.
Usage: python -I docs/paper/scripts/sensitivity_v2.py
"""
import datetime
import importlib
import json
import os
import statistics
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.argv = [sys.argv[0], "--variant", "v2", "--live-run", "RUN_20261116_171508_SEED42_V2_SL_SIM"]
sb = importlib.import_module("study_b_analysis")  # noqa: E402  (reads the v2 flags above)
import experiments.v2.generator_v2 as g  # noqa: E402

ORIG = {n: getattr(g, n) for n in ("vib_tamper", "vib_forced", "shock_heavy", "tilt_tamper", "door_forced", "weight_spoof")}
MAKE = {  # median m -> replacement function, same shape and log-SD as table 1.3
    "vib_tamper": lambda k: (lambda r: g.logn(r, 0.30 * k, 0.7)),
    "vib_forced": lambda k: (lambda r: g.logn(r, 0.50 * k, 0.7)),
    "shock_heavy": lambda k: (lambda r: min(g.SHOCK_CLIP_G, 1.0 + g.logn(r, 3.0 * k, 1.0))),
    "tilt_tamper": lambda k: (lambda r: g.logn(r, 3.0 * k, 0.8)),
    "door_forced": lambda k: (lambda r: g.logn(r, 6.0 * k, 0.7)),
    "weight_spoof": lambda k: (lambda r: r.choice([-1.0, 1.0]) * g.logn(r, 80.0 * k, 0.8)),
}


def run_variant(changes, workdir, tag):
    for n, f in ORIG.items():
        setattr(g, n, f)
    for n, k in changes.items():
        setattr(g, n, MAKE[n](k))
    rows = {}
    for s in sb.SEEDS:
        rs = sb.scenario_rows(s)
        for r in rs:
            r["card_blocked"] = r["credential"] in sb.BLOCKED
        rows[s] = rs
    b0, b1, j48 = [], [], []
    feats = [n for n, _ in sb.FEATURES]
    for s in sb.SEEDS:
        y = [sb.to5(r["gt6"]) for r in rows[s]]
        lab = sb.run_detectors(rows[s])
        b0.append(sb.macro_f1(y, [sb.to5(a) for a, _ in lab]))
        b1.append(sb.macro_f1(y, [sb.to5(b) for _, b in lab]))
        train = [r for t in sb.SEEDS if t != s for r in rows[t]]
        p = sb.weka_predict("weka.classifiers.trees.J48", train, rows[s], workdir, feats, "%s_s%d" % (tag, s))
        j48.append(sb.macro_f1(y, p))
    for n, f in ORIG.items():
        setattr(g, n, f)
    sm = lambda v: {"mean": statistics.mean(v), "sd": statistics.stdev(v), "per_seed": v}  # noqa: E731
    return {"changes": changes, "B0": sm(b0), "B1P": sm(b1), "J48": sm(j48)}


def main():
    variants = [("baseline", {})]
    for n in ORIG:
        for k in (0.7, 1.3):
            variants.append(("%s_x%.1f" % (n, k), {n: k}))
    variants += [("all_x0.7", {n: 0.7 for n in ORIG}), ("all_x1.3", {n: 1.3 for n in ORIG})]
    work = tempfile.mkdtemp(prefix="sens_")
    out = {"variants": {}, "seeds": sb.SEEDS, "generator_sha256": sb.sha256(g.__file__)}
    for name, ch in variants:
        res = run_variant(ch, work, name)
        out["variants"][name] = res
        print("%-18s B0 %.3f  B1P %.3f  J48 %.3f  (B1P-B0 %+.3f, J48-B1P %+.3f)" % (
            name, res["B0"]["mean"], res["B1P"]["mean"], res["J48"]["mean"],
            res["B1P"]["mean"] - res["B0"]["mean"], res["J48"]["mean"] - res["B1P"]["mean"]))
    base = out["variants"]["baseline"]
    # the baseline must reproduce the frozen Study B numbers
    assert abs(base["B0"]["mean"] - 0.6095657502572415) < 1e-9 and abs(base["B1P"]["mean"] - 0.7525684833830011) < 1e-9, base
    assert abs(base["J48"]["mean"] - 0.9799497801109887) < 1e-6, base["J48"]
    d = os.path.join(HERE, "results", "R2_SENS_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    os.makedirs(d)
    out["timestamp_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    json.dump(out, open(os.path.join(d, "sensitivity.json"), "w"), indent=1)
    print(d)


if __name__ == "__main__":
    main()
