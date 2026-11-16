"""
Reproduce the offline Weka study (Study A) without SQL Server.

Rows are rebuilt from the formulas of sql/02_data_v1.sql (section 9, n = 1..480, one row per n) in id order, with
class values in order of appearance, as test/tool/ModelTrainer.build does. Weka CLI `-x 10 -s 42` runs
crossValidateModel(model, data, 10, new Random(42)), the call used by ModelTrainer and harness/MlEvidence.

Check 1: the 480-row IBk(k=5) result must equal docs/paper/evidence/ml.log (accuracy 0.9771, same confusion matrix);
only then is the reconstruction trusted.  Check 2: the 400-row run without WRONG_USER (paper, Section VI-C).
Usage: python docs/paper/scripts/study_a_reproduce.py
"""
import datetime
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
JAVA = os.environ.get("JAVA", r"C:/Program Files/Java/jdk1.8.0_202/bin/java")
WEKA = os.path.join(ROOT, "web", "WEB-INF", "lib", "weka.jar")
NAMES = {0: "NORMAL", 1: "FORCED_OPEN", 2: "WRONG_USER", 3: "OVERDUE", 4: "ITEM_LEFT", 5: "SUSPECTED_SPOOF"}


def rows():
    out = []
    for n in range(1, 481):
        k = n % 6
        door = 25.0 + n % 9 if k == 1 else 0.0 if k == 5 else 3.0 + n % 7
        weight = 150.0 + n % 300 if k == 4 else 100.0 + n % 200 if k == 5 else -10.0 - n % 80
        unlock = 4 if k == 1 else 1
        rfid = 0 if k == 1 else 1
        stay = 180.0 + n % 90 if k == 3 else 10.0 + n % 90
        out.append(([door, weight, unlock, rfid, stay], NAMES[k]))
    return out


def run(data, path):
    labels = []
    for _, lab in data:
        if lab not in labels:
            labels.append(lab)
    with open(path, "w", encoding="utf-8") as f:
        f.write("@relation PublicSession\n")
        for a in ["door_open_sec", "weight_delta_g", "unlock_count", "rfid_ok", "stay_min"]:
            f.write("@attribute %s numeric\n" % a)
        f.write("@attribute label {%s}\n@data\n" % ",".join(labels))
        for v, lab in data:
            f.write(",".join(repr(x) for x in v) + "," + lab + "\n")
    out = subprocess.run([JAVA, "-cp", WEKA, "weka.classifiers.lazy.IBk", "-K", "5", "-t", path,
                          "-x", "10", "-s", "42", "-o"], capture_output=True, text=True, check=True).stdout
    cv = out[out.index("Stratified cross-validation"):]
    correct = int(re.search(r"Correctly Classified Instances\s+(\d+)", cv).group(1))
    cm = [ln for ln in cv[cv.index("Confusion Matrix"):].splitlines() if " | " in ln][:len(labels)]
    matrix = [[int(x) for x in line.split("|")[0].split()] for line in cm]
    return {"n": len(data), "labels": labels, "correct": correct, "accuracy": correct / len(data), "confusion": matrix}


def main():
    run_id = "R2_STUDYA_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    d = os.path.join(ROOT, "docs", "paper", "scripts", "results", run_id)
    os.makedirs(d, exist_ok=False)
    data = rows()
    full = run(data, os.path.join(d, "study_a_480.arff"))
    # ml.log lines 35-42, class order FORCED_OPEN, WRONG_USER, OVERDUE, ITEM_LEFT, SUSPECTED_SPOOF, NORMAL
    assert full["labels"] == ["FORCED_OPEN", "WRONG_USER", "OVERDUE", "ITEM_LEFT", "SUSPECTED_SPOOF", "NORMAL"]
    assert full["confusion"] == [[80, 0, 0, 0, 0, 0], [0, 73, 0, 0, 0, 7], [0, 0, 80, 0, 0, 0],
                                 [0, 0, 0, 79, 1, 0], [0, 0, 0, 0, 80, 0], [0, 3, 0, 0, 0, 77]], full["confusion"]
    no_wu = run([r for r in data if r[1] != "WRONG_USER"], os.path.join(d, "study_a_400.arff"))
    res = {"run_id": run_id, "reconstruction_matches_ml_log": True, "ibk_480": full, "ibk_400_without_wrong_user": no_wu,
           "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "java": JAVA}
    json.dump(res, open(os.path.join(d, "study_a.json"), "w", encoding="utf-8"), indent=1)
    print(json.dumps({"480": full["correct"], "400": no_wu}, indent=1))
    print(d)


if __name__ == "__main__":
    main()
