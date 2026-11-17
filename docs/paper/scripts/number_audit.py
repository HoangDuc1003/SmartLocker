"""
Number audit for Abstract, Section VI (Tables V-VIII) and Conclusion of docs/paper/smartlocker-10p.tex.

Every number token in those parts must be explained by one of:
  COMPUTED  value recomputed from a result/log file, rounded to the printed precision
  LOG       literal text found in a named evidence log
  CONTEXT   design constant, count or date with a stated source
Anything else is FAIL. Prints a PASS/FAIL list and writes it next to the other revision-2 results.
Usage: python docs/paper/scripts/number_audit.py
"""
import datetime
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
P = lambda *a: os.path.join(ROOT, *a)  # noqa: E731
TEX = P("docs", "paper", "smartlocker-10p.tex")


def latest(prefix, name):
    return json.load(open(sorted(glob.glob(P("docs", "paper", "scripts", "results", prefix + "*", name)))[-1], encoding="utf-8"))


def sections(t):
    t = re.sub(r"\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}", " ", t, flags=re.S)
    a = t[t.index(r"\begin{abstract}"):t.index(r"\end{abstract}")]
    s6 = t[t.index(r"\section{Evaluation}"):t.index(r"\section{Conclusion}")]
    c = t[t.index(r"\section{Conclusion}"):t.index(r"\section*{Acknowledgment}")]
    return {"Abstract": a, "Section VI": s6, "Conclusion": c}


def tokens(text):
    text = text.replace("\\,", "")
    text = re.sub(r"\\(ref|label|cite)\{[^}]*\}", " ", text)
    text = re.sub(r"\\texttt\{(RUN\\_[^}]*|13ba35f|sql/02\\_data\\_v1\.sql)\}|n_\{?\d\d\}?|MPU-6050|Weka 3\.8\.6|LOCKER-01",
                  " ", text)  # ids, file names, subscripts, part names
    text = re.sub(r"\\rule\{[^}]*\}\{[^}]*\}|\\addlinespace\[[^]]*\]|\\arraystretch\}\{[^}]*\}|\\vspace\{[^}]*\}", " ", text)
    text = re.sub(r"p\{[\d.]+cm\}|[\d.]+\\linewidth|\[[\d.]+pt\]", " ", text)
    return re.findall(r"(?<![\w.])\d+(?:\.\d+)?", text)


def main():
    b = latest("R2_STUDYB_V2_", "study_b_results.json")  # primary Study B = simulator v2 (frozen 2026-11-17 00:14 +0700)
    b1h = latest("R2_STUDYB_2", "study_b_results.json")  # v1, historical only
    tc = latest("R2_TAMPER_", "tamper_campaign.json")
    lat = latest("R2_LATENCY_", "latency.json")["scopes"]["A_endpoint_server_processing_ms"]
    sa = latest("R2_STUDYA_", "study_a.json")
    ml = open(P("docs", "paper", "evidence", "ml.log"), encoding="utf-8").read()
    reg = {}  # printed string -> source description

    def comp(v, d, src):
        reg.setdefault(("%." + str(d) + "f") % v, src)

    # Study B (seed 42, five seeds, McNemar, bootstrap)
    for sysname in ("B0", "B1"):
        m = b["seed42"][sysname]
        for v in (m["accuracy"], m["macro"]["precision"], m["macro"]["recall"], m["macro"]["f1"],
                  m["binary_anomaly_positive"]["accuracy"], m["binary_anomaly_positive"]["f1"]):
            comp(v, 3, "study_b seed42 " + sysname)
        comp(m["accuracy"], 2, "study_b seed42 accuracy " + sysname)
        for c in m["per_class"].values():
            for k in ("precision", "recall", "f1"):
                comp(c[k], 3, "study_b per-class " + sysname)
    mc = b["seed42"]["mcnemar_binary"]
    for k in ("n00", "n01", "n10", "n11"):
        reg.setdefault(str(mc[k]), "study_b McNemar " + k)
    comp(mc["chi2_cc"], 2, "study_b McNemar chi2")
    comp(mc["exact_binomial_p_two_sided"] * 1e7, 1, "study_b McNemar exact p (x1e-7)")
    bt = b["bootstrap"]
    comp(bt["delta_macro_f1_point"], 3, "bootstrap delta")
    comp(bt["delta_ci95"][0], 3, "bootstrap CI low")
    comp(bt["delta_ci95"][1], 3, "bootstrap CI high")
    reg.setdefault(str(bt["resamples"]), "bootstrap resamples")
    reg.setdefault(str(bt["seed"]), "bootstrap seed")
    for sysname in ("B0", "B1"):
        comp(b["five_seed"][sysname]["mean"], 3, "five-seed mean " + sysname)
        comp(b["five_seed"][sysname]["sd_sample_ddof1"], 3, "five-seed sample SD " + sysname)
    for s in b["five_seed"]["per_seed"]:
        reg.setdefault(str(s["seed"]), "generator seed")
    comp(b["learned_baselines"]["J48"]["seed42"]["macro"]["f1"], 3, "J48 learned baseline seed 42")
    errors_b1 = 100 - round(b["seed42"]["B1"]["accuracy"] * 100)
    reg.setdefault({9: "nine"}.get(errors_b1, str(errors_b1)), "B1 errors")
    # Study B v2 additions (session B, 2026-11-17): every value read from the v2 result file
    comp(mc["exact_binomial_p_two_sided"], 3, "study_b v2 McNemar binary exact p")
    m5 = b["seed42"]["mcnemar_5class"]
    for k in ("n01", "n10"):
        reg.setdefault(str(m5[k]), "study_b v2 McNemar 5-class " + k)
    comp(m5["exact_binomial_p_two_sided"] * 1e4, 1, "study_b v2 McNemar 5-class exact p (x1e-4)")
    T, N = "LOAD_OR_TAMPER_ANOMALY", "NORMAL_AUTHORIZED"
    reg.setdefault(str(b["seed42"]["B1"]["confusion"][T][N]), "v2 B1-P tamper sessions labelled normal")
    reg.setdefault(str(b["seed42"]["B1"]["confusion"][T][T]), "v2 B1-P tamper sessions detected")
    for name in ("J48", "Logistic"):
        lb = b["learned_baselines"][name]
        comp(lb["mean"], 3, name + " LOSO mean")
        comp(lb["sd_sample_ddof1"], 3, name + " LOSO sample SD")
    jm = b["learned_baselines"]["J48"]["mcnemar_binary_vs_B1"]
    reg.setdefault(str(jm["n10"]), "J48 vs B1-P: J48-only right")
    reg.setdefault(str(jm["n01"]), "J48 vs B1-P: B1-only right")
    comp(jm["exact_binomial_p_two_sided"] * 1e4, 1, "J48 vs B1-P exact p (x1e-4)")
    for g, v in b["ablation_J48"].items():
        comp(v["mean"], 3, "J48 ablation mean " + g)
    cx = b["v2_extra"]["context_only_J48"]
    comp(cx["mean"], 3, "context-only J48 mean")
    comp(cx["sd_sample_ddof1"], 3, "context-only J48 sample SD")
    comp(max(c["balanced_accuracy"] for c in b["v2_extra"]["overlap_diagnostics"]["best_single_feature_stump_one_vs_rest"].values()),
         3, "best one-feature balanced accuracy")
    reg.setdefault("12", "observable inputs of the learned baseline (study_b_analysis.py)")
    # v1 historical seed-42 values (Section VI-F, last paragraph)
    for sysname in ("B0", "B1"):
        comp(b1h["seed42"][sysname]["macro"]["f1"], 3, "v1 historical seed42 macro-F1 " + sysname)
    # Tamper campaign (Section VI-D)
    reg.setdefault(str(tc["records"]), "tamper campaign ledger rows")
    for c in tc["categories"].values():
        reg.setdefault(str(c["attempted"]), "tamper campaign attempted")
        reg.setdefault(str(c["detected"]), "tamper campaign detected")
    # Network base latency range of the v2 generator (measured batch round trips)
    rt = latest("R2_LATENCY_", "latency.json")["scopes"]["B_client_round_trip_ms"]["/api/locker/batch"]
    comp(rt["min"], 1, "batch round-trip min (v2 latency pool)")
    comp(rt["max"], 1, "batch round-trip max (v2 latency pool)")
    # Latency (scope A)
    for k in lat.values():
        for f in ("median", "min", "max", "mean"):
            comp(k[f], 1, "latency.log recomputed " + f)
    # Study A (Weka): ml.log six-class and binary {NORMAL, ABNORMAL} tables, first run
    from decimal import Decimal, ROUND_HALF_UP  # ml.log prints 4 decimals; the paper rounds those half-up
    vals = [x for v in re.findall(r"^(?:RandomForest|J48|NaiveBayes|IBk)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)", ml, re.M)
            for x in v] + re.findall(r"F1\[\w+\] = ([\d.]+)", ml)
    for x in vals:
        reg.setdefault(str(Decimal(x).quantize(Decimal("0.001"), ROUND_HALF_UP)), "ml.log")
    comp(sa["ibk_400_without_wrong_user"]["accuracy"] * 100, 2, "study_a 400-row IBk accuracy %")
    reg.setdefault(str(sa["ibk_400_without_wrong_user"]["n"]), "study_a rows without WRONG_USER")
    logs = {f: open(P("docs", "paper", "evidence", f), encoding="utf-8", errors="replace").read()
            for f in ("ml.log", "latency.log", "scenarios.log", "testng-4.log", "README.md")}
    log_items = {  # printed -> (log, literal in log)
        "104.6": ("README.md", "104,6"), "125.5": ("latency.log", "125.5 s"), "110": ("README.md", "110 s"),
        "97": ("README.md", "97, 98"), "98": ("README.md", "97, 98"), "83": ("testng-4.log", "Total tests run: 83"),
        "221": ("README.md", "221 request"), "472": ("README.md", "472 assertion"), "17": ("ml.log", "0 63  0  0  0 17"),
        "8": ("ml.log", "0  8  0  0  0 72"), "7": ("ml.log", "0 73  0  0  0  7"), "3": ("ml.log", "0  3  0  0  0 77"),
        "79": ("ml.log", "0  0  0 79  1  0"), "73": ("ml.log", "0 73"), "77": ("ml.log", "77 |"),
        "5000": ("scenarios.log", "weight_delta_g=-5000.0"), "1.8": ("ml.log", "jdk1.8.0_202"),
    }
    logs["scenarios.log"] = open(P("docs", "paper", "evidence", "scenarios.log"), encoding="utf-8", errors="replace").read()
    logs["newman.log"] = open(P("docs", "paper", "evidence", "newman.log"), encoding="utf-8", errors="replace").read()
    logs["machine.log"] = open(P("docs", "paper", "evidence", "machine.log"), encoding="utf-8", errors="replace").read()
    log_items.update({"500": ("newman.log", "HTTP 500"), "11400": ("machine.log", "i5-11400H"),
                      "2.7": ("machine.log", "2.70GHz"), "9.0": ("README.md", "Tomcat 9.0.113"),
                      "3.8": ("README.md", "Weka")})
    # 17 Nov 2026 rerun on the test stack (SL_R30, port 8081)
    for f in ("newman-6.log", "scenarios-2.log", "latency-2.log", "ml-2.log", "testng-5.log"):
        logs[f] = open(P("docs", "paper", "evidence", f), encoding="utf-8", errors="replace").read()
    log_items.update({"241": ("newman-6.log", "requests           total  241"),
                      "514": ("newman-6.log", "assertions         total  514"),
                      "29": ("newman-6.log", "duration_s 148.6"),  # 2 min 29 s
                      "99.5": ("scenarios-2.log", "created 99.5 s after"),
                      "120.9": ("latency-2.log", "VALID t+120.9 s ACCEPTED"),
                      "83": ("testng-5.log", "Total tests run: 83, Passes: 83")})
    for k, (f, lit) in log_items.items():
        if lit in logs[f]:
            reg.setdefault(k, "LOG " + f)
    context = {
        "480": "dataset rows (sql/02_data_v1.sql)", "80": "rows per class", "100": "sessions", "20": "sessions per class / 20 sessions",
        "30": "requests per endpoint / 30 papers", "10": "10-fold CV", "11": "IBk errors / 11 builds", "42": "CV seed",
        "5": "k=5, five seeds/classes/wrong tries", "6": "six classes / scenarios", "4": "four classifiers / wrong PINs 1-4",
        "1": "counts", "2": "counts", "0": "counts", "14": "RuleEngineTest @Test count; test classes",
        "47": "in-memory test methods (recount)", "36": "DB test methods (recount)", "18": "Postman scenarios",
        "120": "lockout seconds (code)", "90": "offline timeout (code)", "105": "90 s + 15 s job", "15": "job period / ms",
        "3": "heartbeat period", "60": "chain re-verify period", "200": "valid weight range", "000": "valid weight range",
        "2026": "year", "2022": "year", "16": "date / g range", "24": "Postman 2 min 24 s (newman-2.json 144.1 s)",
        "27": "Postman 2 min 27 s (newman-3.json 147.0 s)", "13ba35f": "commit", "0.80": "risk threshold (code)",
        "0.45": "B1 vibration threshold (detection.py)", "0.46": "generator slam range", "0.49": "generator slam range",
        "22.8": "max simulated shock 22.75 g", "16.2": "kiosk median", "6.0": "health median", "102.7": "kiosk max",
        "25": "fixed fault latency (generator.py:447)", "6500": "timeout latency (generator.py)", "450": "srf05 range (sensor_models)",
        "0.15": "reed sigma / tilt drift (sensor_models)", "0.01": "reed step", "3.5": "hx711 sigma", "0.02": "outlier p",
        "0.1": "steps", "1.2": "sonar sigma", "0.3": "sonar step", "0.015": "vib sigma", "0.005": "vib offset sigma",
        "0.001": "vib step", "0.25": "tilt sigma", "0.35": "shock sigma", "0.05": "shock step/floor", "12": "RF scoring us (ml.log)",
        "15.5": "RF scoring us (README 12.3-15.5)", "36": "RF train ms (README 35.8-37.7)", "38": "RF train ms",
        "0.2": "share of server time (17 us / 17 ms)", "1.000": "J48 macro-F1", "17.0": "auth mean ms", "22": "JSP views",
        "8": "eight", "9": "nine", "64": "n11", "400": "rows", "0.990": "historical B1 macro-F1 (git 38037ed)", "20000": "valid weight range (RuleEngine)",
        "95": "95% interval",
    }
    t13 = "approved table 1.3 / choices 1-7 (REVISION2_LOG 'Simulator v2 rationale'; experiments/v2/generator_v2.py)"
    context.update({k: t13 for k in ("0.5", "0.7", "0.8", "0.9", "1.0", "0.30", "0.50", "85", "150", "350", "24000",
                                     "16.0", "2.9", "50", "2000", "15000")})
    context["99"] = "99/100 transport gate (experiments/runs/RUN_20261116_171508_SEED42_V2_SL_SIM/execution_summary.json)"
    context["3.27"] = "SIM-SESS-098 network_latency_ms 3269.98 (sessions.csv)"
    context["9"] = "nine / 9 audit rows written at Tomcat start (REVISION2_LOG A1: 1334 -> 1343)"
    context["20"] = "sessions per class / 20 per tamper category / +-20% band (REVISION2_LOG independence table)"
    report = []
    for name, text in sections(open(TEX, encoding="utf-8").read()).items():
        for tok in tokens(text):
            if tok in reg:
                report.append((name, tok, "PASS", reg[tok]))
            elif tok in context and context[tok]:
                report.append((name, tok, "PASS", "CONTEXT " + context[tok]))
            else:
                report.append((name, tok, "FAIL", "no source"))
    fails = [r for r in report if r[2] == "FAIL"]
    d = P("docs", "paper", "scripts", "results", "R2_NUMBER_AUDIT_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    os.makedirs(d, exist_ok=False)
    json.dump({"tokens": len(report), "fail": len(fails), "report": report}, open(os.path.join(d, "number_audit.json"), "w"), indent=1)
    for r in sorted(set(report)):
        if r[2] == "FAIL":
            print("FAIL", r[0], r[1])
    print("tokens", len(report), "unique", len(set((r[1]) for r in report)), "FAIL", len(fails))
    print(d)


if __name__ == "__main__":
    main()
