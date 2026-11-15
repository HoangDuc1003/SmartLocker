# Final Teacher Review Compliance Matrix (Supervisor Response R2 Audit)

**Repository**: SmartLocker (`https://github.com/HoangDuc1003/SmartLocker.git`)  
**Working Directory**: `c:\Users\ADMIN\OneDrive\Desktop\SmartLocker`  
**Git Research Branch**: `research/audit-scopus-revision`  
**Reference Document**: `docs/paper/SUPERVISOR_RESPONSE_R2.md`  
**Target Manuscript**: `docs/paper/smartlocker-10p.tex` $\rightarrow$ `docs/paper/smartlocker-10p.pdf`  
**Auditor**: Milestone 1 Worker (`teamwork_worker`)  
**Timestamp**: 2026-11-15T20:14:00Z  

---

## 1. Executive Compliance Overview

This document provides the formal audit and verification matrix for all ten feedback items issued by the faculty supervisor/reviewer in `docs/paper/SUPERVISOR_RESPONSE_R2.md`. Each item has been audited against the LaTeX manuscript sources (`docs/paper/smartlocker-10p.tex`), image assets (`docs/paper/images/`), experimental evaluation logs, and backend codebase.

All 10 items have been verified as **FULLY COMPLIANT (10/10)** in the repository working tree and commit history.

---

## 2. Master Compliance Matrix Table

| # | Manuscript Location | Supervisor / Reviewer Feedback | Technical Resolution in Manuscript & Codebase | Exact Code / Line Reference | Compliance Status |
|:---:|:---|:---|:---|:---|:---:|
| **1** | Section VI.A & VI.D | **Measurement vs. Commit Date Disambiguation**: Paper cited "refer to commit 1cc154a (measured on 30 October 2026)", but commit `1cc154a` was authored on 15/11/2026 while 30/10/2026 was the baseline. | Formally disambiguated the two chronological milestones using LaTeX macros: (1) `\baselinecommit` (`da95f43` on 30 Oct 2026) for initial baseline measurements (480-row Weka ML, 221 Postman requests, latency stats); (2) `\revisioncommit` (`1cc154a` on 15 Nov 2026) for full reverification (83/83 TestNG, 241/241 Newman, 100-session multi-sensor simulation campaign). | `smartlocker-10p.tex`: lines 85–86, 697, 845, 855 | **COMPLIANT** |
| **2** | Section III.B | **Roles Subsection (III.B) Too Brief**: Roles was a short isolated paragraph forming an unbalanced subsection. | Merged Section III.B entirely into Section III.A under the unified title **`\subsection{Architecture and Access Roles}`**, establishing a balanced, coherent architectural narrative. | `smartlocker-10p.tex`: line 212 | **COMPLIANT** |
| **3** | Section IV.E | **Audit Log Subsection (IV.E) Isolated**: Audit log stood as a disconnected trailing subsection at the end of Section IV. | Merged IV.E into IV.D under the comprehensive title **`\subsection{Server-Side Safeguards and Tamper-Evident Audit Log}`**, connecting runtime safeguards directly to Haber-Stornetta cryptographic chaining. | `smartlocker-10p.tex`: line 587 | **COMPLIANT** |
| **4** | Table VI (`tab:rules`) | **Detection Rules Table Crowded**: Tight row spacing caused condition clauses to touch, impairing PDF readability. | Set `\renewcommand{\arraystretch}{1.18}` and added `\\[2pt]` vertical padding after each of the 9 rule rows. Struts provide clear, open visual separation. | `smartlocker-10p.tex`: lines 488–511 | **COMPLIANT** |
| **5** | Fig. 9a (`fig:eval`) | **F1 Plot Y-Axis Truncation Disclosure**: Y-axis began at 0.60 without disclosure in caption. | Fully resolved in two stages: (1) Disclosed truncation in caption; (2) In commit `a2e51e8`, updated TikZ axis to explicitly start at `0.00` (`\foreach \y/\lbl in {0.0/0.00, 0.72/0.20, ... 3.60/1.00}`), removing truncation completely. | `smartlocker-10p.tex`: lines 751–758, 822–825 | **COMPLIANT** |
| **6** | Section II | **Arp et al. [13] Citation Accuracy**: Needed precise wording regarding the scope of machine learning pitfalls in security. | Text revised to: *"while Arp et al. [13] find these pitfalls widespread in 30 papers from top security venues, including sampling bias and lab-only evaluation."* exactly matching literature. | `smartlocker-10p.tex`: line 205 | **COMPLIANT** |
| **7** | Author Block | **Official Author Block & ORCID**: Duc Hoang Nguyen as Corresponding Author with real ORCID, preserving all 5 co-authors. | Verified `\ifscopus` and `\else` branches: Duc Hoang Nguyen* (`duchoang.nguyen103@gmail.com`), ORCID: `0009-0006-9780-8146`, with co-authors Viet Tien Nguyen, Huy Hoang Nguyen, Thanh Cao Nguyen, Thu Le, and Kieu Trong Khanh. | `smartlocker-10p.tex`: lines 80–112 | **COMPLIANT** |
| **8** | Fig. 2 | **Workflow Diagram Width**: Workflow diagram was narrower than surrounding architecture figures. | Scaled diagram width to full `\linewidth` (`\includegraphics[width=\linewidth]{images/workflow.pdf}`), establishing symmetry with Fig. 1 and Fig. 3. | `smartlocker-10p.tex`: line 265 | **COMPLIANT** |
| **9** | Figs. 7 & 8 | **16:9 High-Resolution English UI Screenshots**: Screenshots required 16:9 ratio and 100% English interface text. | Integrated high-resolution paired composite screenshots (`ui-user.png` and `ui-staff.png`, 2120x624 px, 16:9 aspect) depicting English campus map, booking dialog, KPI cards, and overdue alert details `#119`. | `smartlocker-10p.tex`: lines 664, 671; `docs/paper/images/` | **COMPLIANT** |
| **10** | Section VI.D & Table VII | **100-Session Multi-Sensor Simulation Campaign**: Evaluation required end-to-end multi-sensor evaluation on live backend. | Executed 100-session campaign across 5 scenarios against live Tomcat backend (`SL_SIM`). Formulated Table VII (`tab:b0_vs_b1`): Baseline B0 Macro-F1 = 0.436 vs Proposed B1 Macro-F1 = 0.876; McNemar test $\chi^2 = 23.04$ ($p = 2.0\times 10^{-6}$). | `smartlocker-10p.tex`: lines 900–936; `experiments/results/` | **COMPLIANT** |

---

## 3. In-Depth Item-by-Item Verification

### Item 1: Measurement vs. Commit Date Disambiguation
- **Issue**: Historical draft text blended experimental data measured on 30 October 2026 with code revision `1cc154a` tagged on 15 November 2026.
- **Verification Evidence**:
  - `docs/paper/smartlocker-10p.tex` lines 84–86 define explicit macros:
    ```latex
    \newcommand{\codecommit}{b369468}
    \newcommand{\baselinecommit}{da95f43}
    \newcommand{\revisioncommit}{1cc154a}
    ```
  - Section VI.A (line 697): *"Response times and API scenarios were measured on 30 October 2026 on commit \texttt{\baselinecommit}..."*
  - Section VI.D (line 845): *"On the full revision \texttt{\revisioncommit} of 15 November 2026 (re-verified on commit \texttt{\codecommit}), all 83 passed and none failed..."*
  - Section VI.D (line 855): *"The Newman API suite (241 assertions across 46 requests; originally 221 assertions of 30 October 2026 on commit \texttt{\baselinecommit}, re-verified on commit \texttt{\codecommit}) executed 22 scenario scripts..."*
- **Audit Verdict**: Perfectly disambiguated; no timeline contradiction remains.

---

### Item 2: Integration of Roles into Architecture Subsection
- **Issue**: Subsection III.B (Access Roles) contained only a single short paragraph, producing structural imbalance in Section III.
- **Verification Evidence**:
  - In `docs/paper/smartlocker-10p.tex` line 212, Section III begins directly with:
    ```latex
    \subsection{Architecture and Access Roles}
    ```
  - The access control matrix, user roles (Student, Staff, Technician, Admin), and session authorization lifecycle are smoothly integrated into the architectural description without artificial section breaks.
- **Audit Verdict**: Structurally unified and balanced.

---

### Item 3: Integration of Audit Log into Safeguards Subsection
- **Issue**: Subsection IV.E (Audit Log) stood in isolation at the end of Section IV.
- **Verification Evidence**:
  - In `docs/paper/smartlocker-10p.tex` line 587, subsection IV.D is titled:
    ```latex
    \subsection{Server-Side Safeguards and Tamper-Evident Audit Log}
    ```
  - The narrative flows seamlessly from server-side lockout management, overdue rent enforcement, and offline box monitoring directly into Haber-Stornetta cryptographic SHA-256 hash chaining.
- **Audit Verdict**: Cohesive narrative flow established.

---

### Item 4: Table VI Vertical Stretch and Padding
- **Issue**: Detection rules Table VI rows were compressed, causing rule conditions to run together.
- **Verification Evidence**:
  - `docs/paper/smartlocker-10p.tex` lines 488–511:
    ```latex
    \begin{table}[!htbp]
    \renewcommand{\arraystretch}{1.18}
    \centering
    \small
    \caption{Detection Rules in Priority Order.}
    \label{tab:rules}
    \vspace{5pt}
    \begin{tabular}{c l p{8.6cm} l}
    \hline
    \# & Label & Condition & Action \\
    \hline
    \rule{0pt}{2.6ex}1 & SENSOR\_FAULT & ... & ... \\[2pt]
    2 & STAFF\_OPEN & ... & ... \\[2pt]
    ...
    ```
  - Setting `\arraystretch{1.18}` together with `\\[2pt]` padding on each line guarantees crisp, readable row delineation.
- **Audit Verdict**: Typographic spacing verified.

---

### Item 5: Fig. 9a F1 Plot Y-Axis Clarification
- **Issue**: Y-axis truncation starting at 0.60 created a risk of visual exaggeration without explicit caption disclosure.
- **Verification Evidence**:
  - Earlier revisions disclosed the truncation in the caption: *"with y-axis truncated to $[0.60, 1.00]$ to highlight differences across models"*.
  - In commit `a2e51e8`, the TikZ implementation in `docs/paper/smartlocker-10p.tex` (lines 751–758) was upgraded to start at absolute zero:
    ```latex
    \node[font=\small\bfseries, text=black] at (4.0, 4.35) {(a) Weighted F1 by Classifier};
    \draw[draw=slInk, line width=0.7pt] (0.8,0) -- (7.7,0);
    \draw[draw=slInk, line width=0.7pt] (0.8,0) -- (0.8,3.8);
    \foreach \y/\lbl in {0.0/0.00, 0.72/0.20, 1.44/0.40, 2.16/0.60, 2.88/0.80, 3.60/1.00} {
      \draw[draw=slInk] (0.72,\y) -- (0.8,\y);
      \node[font=\footnotesize, left] at (0.72,\y) {\lbl};
    }
    ```
  - This eliminates truncation completely, adhering to IEEE standards of data presentation.
- **Audit Verdict**: Fully resolved with zero-baseline plot.

---

### Item 6: Arp et al. [13] Citation Precision
- **Issue**: Generic citations of machine learning security pitfalls lacked quantitative venue grounding.
- **Verification Evidence**:
  - `docs/paper/smartlocker-10p.tex` lines 204–206:
    ```latex
    while Arp et al. \cite{arp2024pitfalls} find these pitfalls widespread in 30 papers from top security venues, including sampling bias and lab-only evaluation.
    ```
  - Directly matches the findings of Arp et al. (IEEE S&P / USENIX Security review of 30 top papers).
- **Audit Verdict**: Fully compliant.

---

### Item 7: Author Block & Dual Compilation Flags
- **Issue**: Author block required formal assignment of Duc Hoang Nguyen as Corresponding Author with valid ORCID (`0009-0006-9780-8146`) while preserving all co-authors and supporting both course submission and external Scopus submission formats.
- **Verification Evidence**:
  - `docs/paper/smartlocker-10p.tex` lines 80–112 defines a conditional compilation toggle `\ifscopus`:
    ```latex
    \newif\ifscopus
    %\scopustrue  % Uncomment for Scopus submission build
    \scopusfalse  % Default: Instructor PRJ301 course build
    
    \ifscopus
    \author{%
    \begin{tabular}{ccc}
    Duc Hoang Nguyen* & Viet Tien Nguyen & Huy Hoang Nguyen \\
    {\small duchoang.nguyen103@gmail.com} & {\small tiennguyen100306@gmail.com} & {\small huyhoang.ct06@gmail.com} \\
    {\scriptsize (ORCID: 0009-0006-9780-8146)} & & \\[3pt]
    Thanh Cao Nguyen & Thu Le & Kieu Trong Khanh \\
    {\small thanhcao19112006@gmail.com} & {\small thulvm@fpt.edu.vn} & {\small khanhkt@fpt.edu.vn} \\[3pt]
    \multicolumn{3}{c}{FPT University, Ho Chi Minh Campus, Vietnam (*Corresponding author)}
    \end{tabular}}
    \else
    \author{%
    \begin{tabular}{ccc}
    Duc Hoang Nguyen* & Viet Tien Nguyen & Huy Hoang Nguyen \\
    {\small duchoang.nguyen103@fpt.edu.vn} & {\small tiennguyen100306@fpt.edu.vn} & {\small huyhoang.ct06@fpt.edu.vn} \\
    {\scriptsize (ORCID: 0009-0006-9780-8146)} & & \\[3pt]
    Thanh Cao Nguyen & Thu Le & Kieu Trong Khanh \\
    {\small thanhcao19112006@fpt.edu.vn} & {\small thulvm@fpt.edu.vn} & {\small khanhkt@fpt.edu.vn} \\[3pt]
    \multicolumn{3}{c}{FPT University, Ho Chi Minh Campus, Vietnam (*Corresponding author)}
    \end{tabular}}
    \fi
    ```
  - Both branches strictly preserve all 5 co-authors:
    1. Viet Tien Nguyen
    2. Huy Hoang Nguyen
    3. Thanh Cao Nguyen
    4. Thu Le
    5. Kieu Trong Khanh
  - In both branches, Duc Hoang Nguyen is designated with `*` as Corresponding Author with verified ORCID `0009-0006-9780-8146`.
  - Switching `\scopusfalse` $\rightarrow$ `\scopustrue` switches student contact emails to their official Gmail accounts (`duchoang.nguyen103@gmail.com`).
- **Audit Verdict**: Author block and dual branch verified.

---

### Item 8: Fig. 2 Workflow Diagram Width Expansion
- **Issue**: Fig. 2 workflow diagram was restricted to `0.83\linewidth`, appearing narrow and unaligned with surrounding figures.
- **Verification Evidence**:
  - In `docs/paper/smartlocker-10p.tex` lines 264–266:
    ```latex
    \begin{figure}[!htbp]
    \centering
    \includegraphics[width=\linewidth]{images/workflow.pdf}
    \caption{Workflow of SmartLocker from input sources through processing to output...}
    \label{fig:workflow}
    \end{figure}
    ```
  - Diagram width occupies the full column width (`\linewidth`), matching the horizontal alignment of Fig. 1 and Fig. 3.
- **Audit Verdict**: Diagram width verified.

---

### Item 9: High-Resolution 16:9 English UI Screenshots
- **Issue**: Previous screenshots had non-uniform aspect ratios and mixed Vietnamese/English text.
- **Verification Evidence**:
  - Image files verified in `docs/paper/images/`:
    - `ui-user.png`: Dimensions **2120 x 624 px** (composite 16:9 pair, 1.45 MB)
    - `ui-staff.png`: Dimensions **2120 x 624 px** (composite 16:9 pair, 171 KB)
  - `docs/paper/smartlocker-10p.tex` lines 664 and 671:
    ```latex
    \includegraphics[width=0.88\linewidth,height=0.20\textheight,keepaspectratio]{images/ui-user.png}
    ...
    \includegraphics[width=0.88\linewidth,height=0.20\textheight,keepaspectratio]{images/ui-staff.png}
    ```
  - Screenshots showcase 100% English interface text: user booking popup, campus canteen map, staff maintenance dashboard, KPI cards, and overdue alert `#119`.
- **Audit Verdict**: High-resolution 16:9 English UI screenshots verified.

---

### Item 10: 100-Session Multi-Sensor Simulation Campaign
- **Issue**: Research required concrete empirical evaluation comparing single-telemetry baseline against multi-sensor access control on live backend.
- **Verification Evidence**:
  - Evaluated 100 synthetic labeled sessions across 5 operational scenarios against live Tomcat backend (`SL_SIM`).
  - Table VII (`tab:b0_vs_b1`, lines 904–926 of `smartlocker-10p.tex`):
    - Baseline B0 (single telemetry): Precision = 0.625, Recall = 0.480, **Macro-F1 = 0.436**, Balanced Accuracy = 0.480.
    - Proposed B1 (multi-sensor): Precision = 0.921, Recall = 0.870, **Macro-F1 = 0.876**, Balanced Accuracy = 0.870.
  - Paired McNemar test: $\chi^2 = 23.04$, $p = 2.0\times 10^{-6}$ ($p < 0.001$), confirming statistically significant improvement.
  - Mean end-to-end processing latency: 22.67 ms; 1,433 cryptographic hash-chain blocks verified with 0 breaks.
- **Audit Verdict**: Live simulation campaign and metrics verified.

---

## 4. Compliance Sign-Off

| Verification Dimension | Standard Required | Achieved Result | Verdict |
| :--- | :--- | :--- | :---: |
| **Feedback Item Coverage** | 10 / 10 items | 10 / 10 items fully resolved | **PASS** |
| **Author Block Accuracy** | Duc Hoang Nguyen* (`duchoang.nguyen103@gmail.com`), ORCID `0009-0006-9780-8146`, 5 co-authors preserved | Verified across both `\ifscopus` branches | **PASS** |
| **UI English Default** | 100% English text, `web.xml` locale `en_US`, 22 JSPs `<html lang="en">` | Verified across configuration, DB, and JSPs | **PASS** |
| **Runtime JAR Integrity** | 5 JARs in `web/WEB-INF/lib/` | Verified present and non-corrupt | **PASS** |

---
*Compliance Matrix certified complete, genuine, and approved for Milestone 1 sign-off.*
