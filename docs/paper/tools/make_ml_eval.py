"""Draw the evaluation figure of the paper (images/ml-eval.pdf, vector, and ml-eval.png, a 200 dpi preview).

Usage: python -I docs/paper/tools/make_ml_eval.py

(a) weighted F1 of the four Weka classifiers, six classes and binary task side by side, value in bold on each bar;
(b) confusion matrix of IBk (k = 5) for the six classes.

Every number is read from docs/paper/evidence/ml.log (run 1; the CV metrics of the three runs are identical):
  - six classes:  section "== six classes (480 rows, 10-fold CV, new Random(42)) =="
  - binary task:  section "== binary NORMAL vs ABNORMAL, label order {NORMAL, ABNORMAL} ...", the order used for
                  Table IV of the paper (the other label order gives Random Forest 0.9406 instead of 0.9387)
  - matrix:       block "-- confusion matrix IBk --" of the six-class section
Nothing is typed in by hand; the script stops if a value is missing.
Palette: pastel fills with dark borders and black text, no purple and no gray (department figure rules).
"""
import os
import re
from decimal import Decimal, ROUND_HALF_UP

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "..", "evidence", "ml.log")
OUT = os.path.join(HERE, "..", "images")

INK = "#0F2338"            # dark navy for text, axes and borders
SIX = ("#BFDDF7", "#1F4E79")   # light blue fill, dark blue edge
BIN = ("#FFD7B5", "#8A4513")   # peach fill, dark brown edge
MODELS = [("IBk", "IBk\n($k$ = 5)"), ("RandomForest", "Random\nForest"), ("J48", "J48\n(C4.5)"),
          ("NaiveBayes", "Naive\nBayes")]
SHORT = {"FORCED_OPEN": "FORCED_OPEN", "WRONG_USER": "WRONG_USER", "OVERDUE": "OVERDUE",
         "ITEM_LEFT": "ITEM_LEFT", "SUSPECTED_SPOOF": "SUSP._SPOOF", "NORMAL": "NORMAL"}


def first_run(text):
    """The text of run 1 only."""
    start = text.index("######## run 1")
    end = text.index("######## run 2")
    return text[start:end]


def section(run, header_start):
    i = run.index(header_start)
    j = run.find("\n== ", i + 1)
    return run[i:j if j > 0 else len(run)]


def f1_table(sec):
    out = {}
    for line in sec.splitlines():
        m = re.match(r"^(RandomForest|J48|NaiveBayes|IBk)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s", line)
        if m:
            out[m.group(1)] = m.group(5)  # the logged string, rounded half-up for the labels (0.7775 -> 0.778)
    missing = [k for k, _ in MODELS if k not in out]
    if missing:
        raise SystemExit("F1 missing in ml.log for " + ", ".join(missing))
    return out


def confusion(sec, model):
    block = sec[sec.index("-- confusion matrix %s --" % model):]
    rows, names = [], []
    for line in block.splitlines()[2:]:
        m = re.match(r"^\s*([\d\s]+)\|\s+\w\s=\s(\w+)", line)
        if not m:
            break
        rows.append([int(v) for v in m.group(1).split()])
        names.append(m.group(2))
    if len(rows) != 6 or any(len(r) != 6 for r in rows):
        raise SystemExit("IBk confusion matrix not found in ml.log")
    return names, rows


def main():
    with open(LOG, encoding="utf-8") as fh:
        run = first_run(fh.read())
    six = f1_table(section(run, "== six classes"))
    binary = f1_table(section(run, "== binary NORMAL vs ABNORMAL, label order {NORMAL, ABNORMAL}"))
    names, cm = confusion(section(run, "== six classes"), "IBk")

    plt.rcParams.update({
        "font.family": ["Arial", "DejaVu Sans"], "font.size": 10, "text.color": INK, "axes.labelcolor": INK,
        "axes.edgecolor": INK, "xtick.color": INK, "ytick.color": INK, "pdf.fonttype": 42,
    })
    # 17 cm x 7.6 cm, placed at \linewidth (18.1 cm): fonts print at about 8 to 10.5 pt
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(17 / 2.54, 7.6 / 2.54),
                                   gridspec_kw={"width_ratios": [1.55, 1.0], "wspace": 0.55})

    # (a) grouped bars
    w = 0.40
    xs = range(len(MODELS))
    for k, (key, data, (fill, edge), label) in enumerate(
            [("six", six, SIX, "Six classes"), ("bin", binary, BIN, "Binary")]):
        off = (k - 0.5) * 0.46
        texts = [data[m] for m, _ in MODELS]
        vals = [float(t) for t in texts]
        ax1.bar([x + off for x in xs], vals, w * 0.94, color=fill, edgecolor=edge, linewidth=0.9, label=label,
                zorder=2)
        for x, v, t in zip(xs, vals, texts):
            # half-up on the logged decimal string, as in the table of the paper (a float "%.3f" gives 0.777)
            label_text = str(Decimal(t).quantize(Decimal("0.001"), ROUND_HALF_UP))
            ax1.text(x + off, v + 0.006, label_text, ha="center", va="bottom", fontsize=8.2, fontweight="bold",
                     color=INK, rotation=0)
    ax1.set_xticks(list(xs))
    ax1.set_xticklabels([lab for _, lab in MODELS], fontsize=9.5)
    ax1.set_ylim(0, 1.08)  # a bar chart starts at 0
    ax1.set_yticks([0, 0.2, 0.4, 0.6, 0.8, 1.0])
    ax1.set_ylabel("Weighted F1")
    ax1.yaxis.grid(True, color="#CFE3F5", linewidth=0.8, zorder=0)
    ax1.set_axisbelow(True)
    for s in ("top", "right"):
        ax1.spines[s].set_visible(False)
    ax1.legend(loc="upper right", frameon=False, fontsize=9, ncol=2, bbox_to_anchor=(1.0, 1.13),
               handlelength=1.2, columnspacing=1.0)
    ax1.set_title("(a) Weighted F1, 10-fold CV", fontsize=10, loc="left", pad=18, color=INK)

    # (b) confusion matrix of IBk: white to light blue for counts, the diagonal in mint, errors in coral
    cmap = LinearSegmentedColormap.from_list("pastel_blue", ["#FFFFFF", "#BFDDF7"])
    ax2.imshow([[0] * 6 for _ in range(6)], cmap=cmap, vmin=0, vmax=80, aspect="auto")
    for i in range(6):
        for j in range(6):
            v = cm[i][j]
            if i == j:
                face = "#CDEFD8"
            elif v > 0:
                face = "#FFC9C4"
            else:
                face = "#FFFFFF"
            ax2.add_patch(plt.Rectangle((j - 0.5, i - 0.5), 1, 1, facecolor=face, edgecolor="#9FC3E3",
                                        linewidth=0.6))
            ax2.text(j, i, str(v), ha="center", va="center", fontsize=9,
                     fontweight="bold" if (v and i != j) or i == j else "normal",
                     color="#9B2226" if (v and i != j) else INK)
    labels = [SHORT[n] for n in names]
    ax2.set_xticks(range(6))
    ax2.set_xticklabels(labels, rotation=45, ha="right", fontsize=7.8, rotation_mode="anchor")
    ax2.set_yticks(range(6))
    ax2.set_yticklabels(labels, fontsize=8.0)
    ax2.set_xlabel("Predicted class", fontsize=9.5)
    ax2.set_ylabel("Actual class", fontsize=9.5, labelpad=4)
    ax2.set_xlim(-0.5, 5.5)
    ax2.set_ylim(5.5, -0.5)
    for s in ax2.spines.values():
        s.set_color(INK)
        s.set_linewidth(0.8)
    ax2.tick_params(length=2)
    ax2.set_title("(b) IBk confusion matrix, six classes", fontsize=10, loc="right", pad=18, color=INK)

    # the rotated class names of (b) and its x label need about a third of the height below the axes
    fig.subplots_adjust(left=0.075, right=0.975, top=0.87, bottom=0.34)
    os.makedirs(OUT, exist_ok=True)
    # "tight" keeps every label inside the page (the right-aligned title of (b) and "Predicted class")
    fig.savefig(os.path.join(OUT, "ml-eval.pdf"), bbox_inches="tight", pad_inches=0.03)
    fig.savefig(os.path.join(OUT, "ml-eval.png"), dpi=200, bbox_inches="tight", pad_inches=0.03)
    print("six-class F1:", {k: six[k] for k, _ in MODELS})
    print("binary F1:   ", {k: binary[k] for k, _ in MODELS})
    print("IBk matrix rows", names)
    for r in cm:
        print("   ", r)
    print("wrote", os.path.normpath(os.path.join(OUT, "ml-eval.pdf")), "and ml-eval.png")


if __name__ == "__main__":
    main()
