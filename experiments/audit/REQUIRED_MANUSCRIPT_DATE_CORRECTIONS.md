# Required Manuscript Date and Provenance Corrections

**Audit Date**: 2026-11-16  
**Auditor**: Senior Research & Engineering Execution System  

---

## 1. Scope of Required Reconciliations

This document specifies the exact updates required across the LaTeX manuscript (`docs/paper/smartlocker-10p.tex`), documentation, and audit matrices to achieve 100% scientific consistency.

### 1.1 Inconsistent Metric Values to Be Replaced

| Item | Old Reported Value(s) | Verified Value (Run `RUN_20261116_010959_SEED20261115_SL_SIM`) | Action |
|---|---|---|---|
| **Baseline B0 Macro-F1** | `0.436`, `0.5136`, `0.5782` | **`0.7137`** (0.714) | Update Abstract, Table VII, Section VI.E |
| **Proposed B1 Macro-F1** | `0.876`, `0.9698`, `0.8255` | **`1.0000`** (1.000) | Update Abstract, Table VII, Section VI.E |
| **Baseline B0 Balanced Acc** | `0.480`, `0.5000`, `0.580` | **`0.7300`** (0.730) | Update Table VII |
| **Proposed B1 Balanced Acc** | `0.876`, `0.9700`, `0.850` | **`1.0000`** (1.000) | Update Table VII |
| **Baseline B0 Normal F1** | `0.000` | **`0.597`** (Prec 0.425, Rec 1.000) | Update Table VII |
| **McNemar Chi-Square** | `23.04`, `45.0213` | **`25.04`** ($\chi^2 = 25.0370$) | Update Section VI.E |
| **McNemar p-value** | `2.0e-6`, `0.0`, `1.95e-11`, `5.62e-7` | **`5.62e-7`** (exact binomial `1.49e-8`) | Update Abstract, Section VI.E |
| **Mean Server Latency** | `34.8 ms`, `< 35 ms` | **`43.63 ms`** (p95: 67.78 ms) | Update Abstract, Section VI.D |
| **Pass Rate Claim** | "100% pass rate" without gate breakdown | **100% End-to-End, Transport, Ingestion, Auth Pass** with 5 explicit gates | Update Section VI.E |
| **Code Commit Citation** | Historical SHAs (`b369468`, `e95f7c6`) | Exact `EXPERIMENT_COMMIT` SHA | Update `\newcommand{\codecommit}` |

---

## 2. Table VII (`tab:b0_vs_b1`) Required Structure

```latex
\begin{table}[!htbp]
\renewcommand{\arraystretch}{1.02}
\centering
\small
\caption{Comparative Evaluation: Baseline B0 vs. Proposed Multi-Sensor B1 (100 Sessions).}
\label{tab:b0_vs_b1}
\vspace{4pt}
\begin{tabular}{l c c c c c c}
\hline
Category & \multicolumn{3}{c}{Baseline B0 (Existing)} & \multicolumn{3}{c}{Proposed B1 (Multi-Sensor)} \\
 & Prec. & Rec. & F1 & Prec. & Rec. & F1 \\
\hline
\rule{0pt}{2.4ex}Normal Authorized & 0.425 & 1.000 & 0.597 & 1.000 & 1.000 & 1.000 \\
Unauthorized Credential & 1.000 & 1.000 & 1.000 & 1.000 & 1.000 & 1.000 \\
Forced Door Opening & 1.000 & 1.000 & 1.000 & 1.000 & 1.000 & 1.000 \\
Load / Tamper Anomaly & 1.000 & 0.250 & 0.400 & 1.000 & 1.000 & 1.000 \\
Sensor Fault / Dropout & 1.000 & 0.400 & 0.571 & 1.000 & 1.000 & 1.000 \\
\hline
\rule{0pt}{2.4ex}Overall / Macro & 0.885 & 0.730 & 0.714 & 1.000 & 1.000 & \textbf{1.000} \\
Balanced Accuracy & \multicolumn{3}{c}{0.730} & \multicolumn{3}{c}{\textbf{1.000}} \\
\hline
\end{tabular}
\end{table}
```
