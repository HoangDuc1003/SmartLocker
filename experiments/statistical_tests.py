"""
Statistical Analysis and Hypothesis Testing Module for SmartLocker Milestone 4.
Zero external dependencies: uses only Python standard library (math, json, random, typing).
"""

import math
import random
from typing import Any, Callable, Dict, List, Optional, Tuple


def wilson_score_interval(k: int, n: int, z: float = 1.95996) -> Tuple[float, float]:
    """
    Computes Wilson score 95% confidence interval for a binomial proportion k/n.
    Clamps bounds strictly within [0.0, 1.0].
    """
    if n <= 0 or k < 0:
        return 0.0, 0.0
    p = k / n
    z2 = z * z
    denom = 1.0 + z2 / n
    center = (p + z2 / (2.0 * n)) / denom
    spread = (z * math.sqrt(max(0.0, (p * (1.0 - p) / n) + (z2 / (4.0 * n * n))))) / denom
    lower = max(0.0, center - spread)
    upper = min(1.0, center + spread)
    return round(lower, 4), round(upper, 4)


def mcnemar_test(
    n00: int, n01: int, n10: int, n11: int
) -> Dict[str, Any]:
    """
    Computes McNemar's paired test with Edwards/Yates continuity correction.
    Returns chi2, asymptotic p-value (erfc), exact binomial p-value, and effect size.
    """
    discordant = n10 + n01
    if discordant == 0:
        return {
            "contingency_table": {
                "n00_both_incorrect": n00,
                "n01_b0_only_correct": n01,
                "n10_b1_only_correct": n10,
                "n11_both_correct": n11,
            },
            "total_discordant": 0,
            "chi2_statistic": 0.0,
            "degrees_of_freedom": 1,
            "p_value": 1.0,
            "p_value_formatted": "1.0",
            "p_value_exact_binomial": 1.0,
            "p_value_exact_formatted": "1.0",
            "cohens_g": 0.0,
            "effect_size_interpretation": "No discordant difference",
            "significant_p05": False,
            "significant_p01": False,
            "significant_p001": False,
        }

    # Edwards continuity-corrected Chi-Square
    chi2 = (abs(n10 - n01) - 1.0) ** 2 / discordant
    
    # Asymptotic p-value using complementary error function for df=1
    p_value = math.erfc(math.sqrt(chi2) / math.sqrt(2.0))
    
    # Exact two-sided binomial p-value: B ~ Binomial(discordant, 0.5)
    min_discordant = min(n10, n01)
    exact_tail = sum(math.comb(discordant, i) for i in range(min_discordant + 1)) * (0.5 ** discordant)
    exact_p_value = min(1.0, 2.0 * exact_tail)

    # Cohen's g effect size: |P - 0.5|
    cohens_g = abs((n10 / discordant) - 0.5)

    return {
        "contingency_table": {
            "n00_both_incorrect": n00,
            "n01_b0_only_correct": n01,
            "n10_b1_only_correct": n10,
            "n11_both_correct": n11,
        },
        "total_discordant": discordant,
        "chi2_statistic": round(chi2, 4),
        "degrees_of_freedom": 1,
        "p_value": p_value,
        "p_value_formatted": f"{p_value:.2e}" if p_value < 1e-4 else f"{round(p_value, 6)}",
        "p_value_exact_binomial": exact_p_value,
        "p_value_exact_formatted": f"{exact_p_value:.2e}" if exact_p_value < 1e-4 else f"{round(exact_p_value, 6)}",
        "cohens_g": round(cohens_g, 4),
        "effect_size_interpretation": "Large effect (g >= 0.25)" if cohens_g >= 0.25 else "Moderate/Small effect",
        "significant_p05": p_value < 0.05,
        "significant_p01": p_value < 0.01,
        "significant_p001": p_value < 0.001,
    }


def bootstrap_metric_ci(
    data: List[Any],
    metric_fn: Callable[[List[Any]], float],
    iterations: int = 2000,
    alpha: float = 0.05,
    seed: int = 42,
) -> Tuple[float, float]:
    """
    Computes empirical percentile bootstrap confidence interval for arbitrary metric.
    """
    n = len(data)
    if n == 0:
        return 0.0, 0.0
    rng = random.Random(seed)
    estimates = []
    for _ in range(iterations):
        sample = [data[rng.randint(0, n - 1)] for _ in range(n)]
        estimates.append(metric_fn(sample))
    estimates.sort()
    low_idx = int((alpha / 2.0) * iterations)
    high_idx = int((1.0 - alpha / 2.0) * iterations) - 1
    return round(estimates[low_idx], 4), round(estimates[high_idx], 4)


def latency_distribution_statistics(durations: List[float]) -> Dict[str, float]:
    """
    Computes complete empirical latency distribution statistics.
    """
    n = len(durations)
    if n == 0:
        return {}
    s = sorted(durations)
    mean_val = sum(s) / n
    var_pop = sum((x - mean_val) ** 2 for x in s) / n
    var_samp = sum((x - mean_val) ** 2 for x in s) / (n - 1) if n > 1 else 0.0

    def pct(p: float) -> float:
        idx = int(math.ceil(p * n)) - 1
        return s[max(0, min(n - 1, idx))]

    p25 = pct(0.25)
    p75 = pct(0.75)

    return {
        "count": n,
        "mean_ms": round(mean_val, 2),
        "sample_std_ms": round(math.sqrt(var_samp), 2),
        "pop_std_ms": round(math.sqrt(var_pop), 2),
        "min_ms": round(s[0], 2),
        "p25_ms": round(p25, 2),
        "median_p50_ms": round(pct(0.50), 2),
        "p75_ms": round(p75, 2),
        "iqr_ms": round(p75 - p25, 2),
        "p90_ms": round(pct(0.90), 2),
        "p95_ms": round(pct(0.95), 2),
        "p99_ms": round(pct(0.99), 2),
        "max_ms": round(s[-1], 2),
    }


def compute_confusion_matrix(
    y_true: List[str], y_pred: List[str], classes: List[str]
) -> Dict[str, Dict[str, int]]:
    """
    Computes confusion matrix mapping actual classes to predicted classes.
    """
    matrix: Dict[str, Dict[str, int]] = {c: {p: 0 for p in classes} for c in classes}
    for yt, yp in zip(y_true, y_pred):
        if yt in matrix:
            if yp in matrix[yt]:
                matrix[yt][yp] += 1
            else:
                # Unmapped or MISSED
                matrix[yt][yp] = matrix[yt].get(yp, 0) + 1
    return matrix


def compute_classification_metrics(
    y_true: List[str],
    y_pred: List[str],
    classes: List[str],
) -> Dict[str, Any]:
    """
    Computes comprehensive multi-class classification metrics:
    - Overall accuracy
    - Balanced accuracy
    - Macro / Micro / Weighted precision, recall, F1
    - Per-class precision, recall, F1 with Wilson score 95% CIs
    """
    n = len(y_true)
    if n == 0:
        return {}

    per_class = {}
    class_counts = {}
    for c in classes:
        class_counts[c] = sum(1 for yt in y_true if yt == c)

    total_tp = 0
    total_fp = 0
    total_fn = 0

    precisions = []
    recalls = []
    f1s = []
    weights = []

    for c in classes:
        tp = sum(1 for yt, yp in zip(y_true, y_pred) if yt == c and yp == c)
        fp = sum(1 for yt, yp in zip(y_true, y_pred) if yt != c and yp == c)
        fn = sum(1 for yt, yp in zip(y_true, y_pred) if yt == c and yp != c)
        support = class_counts[c]

        prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        rec = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (2.0 * prec * rec) / (prec + rec) if (prec + rec) > 0 else 0.0

        rec_ci_low, rec_ci_high = wilson_score_interval(tp, tp + fn)
        prec_ci_low, prec_ci_high = wilson_score_interval(tp, tp + fp) if (tp + fp) > 0 else (0.0, 0.0)
        # F1 binomial pseudo-trial analogue (2*TP successes out of 2*TP + FP + FN trials)
        f1_trials = 2 * tp + fp + fn
        f1_ci_low, f1_ci_high = wilson_score_interval(2 * tp, f1_trials) if f1_trials > 0 else (0.0, 0.0)

        per_class[c] = {
            "support": support,
            "tp": tp,
            "fp": fp,
            "fn": fn,
            "precision": round(prec, 4),
            "precision_ci_95": [prec_ci_low, prec_ci_high],
            "recall": round(rec, 4),
            "recall_ci_95": [rec_ci_low, rec_ci_high],
            "f1": round(f1, 4),
            "f1_ci_95": [f1_ci_low, f1_ci_high],
        }

        total_tp += tp
        total_fp += fp
        total_fn += fn

        precisions.append(prec)
        recalls.append(rec)
        f1s.append(f1)
        weights.append(support / n if n > 0 else 0.0)

    # Aggregations
    num_classes = len(classes)
    macro_prec = sum(precisions) / num_classes if num_classes > 0 else 0.0
    macro_rec = sum(recalls) / num_classes if num_classes > 0 else 0.0
    macro_f1 = sum(f1s) / num_classes if num_classes > 0 else 0.0

    weighted_prec = sum(p * w for p, w in zip(precisions, weights))
    weighted_rec = sum(r * w for r, w in zip(recalls, weights))
    weighted_f1 = sum(f * w for f, w in zip(f1s, weights))

    micro_prec = total_tp / (total_tp + total_fp) if (total_tp + total_fp) > 0 else 0.0
    micro_rec = total_tp / (total_tp + total_fn) if (total_tp + total_fn) > 0 else 0.0
    micro_f1 = (2.0 * micro_prec * micro_rec) / (micro_prec + micro_rec) if (micro_prec + micro_rec) > 0 else 0.0

    correct = sum(1 for yt, yp in zip(y_true, y_pred) if yt == yp)
    overall_acc = correct / n if n > 0 else 0.0
    acc_ci_low, acc_ci_high = wilson_score_interval(correct, n)

    balanced_acc = macro_rec

    return {
        "overall_accuracy": round(overall_acc, 4),
        "overall_accuracy_ci_95": [acc_ci_low, acc_ci_high],
        "balanced_accuracy": round(balanced_acc, 4),
        "macro_precision": round(macro_prec, 4),
        "macro_recall": round(macro_rec, 4),
        "macro_f1": round(macro_f1, 4),
        "micro_precision": round(micro_prec, 4),
        "micro_recall": round(micro_rec, 4),
        "micro_f1": round(micro_f1, 4),
        "weighted_precision": round(weighted_prec, 4),
        "weighted_recall": round(weighted_rec, 4),
        "weighted_f1": round(weighted_f1, 4),
        "per_class": per_class,
    }
