# SmartLocker ICIIT 2027: items for author review

Written by session B (Claude Code, unattended scheduled run, 2026-11-17 ~00:45 +0700). Nothing here is in the
paper text. Each item is a decision only the author can make. Where the run had to choose, it took the
conservative option and says so below. Evidence for every item is in `docs/paper/REVISION2_LOG.md`.

## Blocking before submission

1. **Page budget: RESOLVED at 10 pages (2026-11-17 ~01:20, after the author chose "Cut into Section VI").**
   To fit, Table IV (prices) was removed and Section V was condensed into one paragraph. In Section VI, Threats to
   Validity and the Conclusion, the wording was tightened and some details were removed. Every cut is listed in
   REVISION2_LOG.md ("Session B follow-up 2: page budget"). Please read them, especially:
   - the removed price table;
   - the dropped details: classifier training and scoring times, test-suite duration, B0 fault-label counts, earlier
     offline-alert timings, the learned-tree caveat sentence in VI-E (the same point stays in Threats) and the
     conclusion's ablation sentence;
   - the Acknowledgment rewording.
   If you want something back, the 11-page version is `docs/paper/scripts/results/R2_BUILD_20261116T174010Z/`, built
   from the `.tex` with SHA-256 `cd79d971...6a03`.
2. **Artifacts sentence.** The paper's Artifacts line points to github.com/HoangDuc1003/SmartLocker for code, logs, runs and scripts.
   `docs/paper/scripts/`, `experiments/v2/`, `experiments/runs/RUN_20261116_171508_SEED42_V2_SL_SIM/`, `tools/`
   and the log are **uncommitted**. Before submission, either commit and push them or reword the sentence.
   Do not publish `reproduction_config.yaml` or `backend_requests.jsonl`: both contain the test device key.
3. **AI-use disclosure (Acknowledgment).** Session B replaced "The design, implementation, experiments and all
   reported measurements are the authors' own." The 30-Oct log headers name AI agents as operators of runs, so that
   sentence conflicts with the evidence. The new text discloses Claude for writing, LaTeX and figures, and AI coding
   agents (including Claude Code) for scripts, for executing scripted runs under supervision, and for drafting the
   simulator-v2 parameter proposal that the author approved value by value. Confirm or correct:
   - every AI tool actually used, including any non-Claude tools and the "agent" operators in the 30-Oct logs;
   - whether "execute the scripted runs" is accurate. The master prompt says "never claim AI ran experiments", but
     the logs show agents operated runs. Session B kept the disclosure honest instead of deleting it.
   - the ACM authorship/AI policy text, which could not be fetched automatically (HTTP 403):
     https://www.acm.org/publications/policy-on-authorship
4. **Simulator v2 choices 1–7** were approved after the run, and the paper says so. The independence table flags
   three parameters within ±20 % of B1-P thresholds. The paper states this as a limitation, and it is not resolved.

## Confirm (non-blocking)

5. Template: IEEEtran onecolumn was kept. ICIIT/ACM provide their own LaTeX package; confirm the venue accepts this
   template.
6. Ultrasonic module actually fitted (Devantech SRF05 / HY-SRF05 / other). The paper no longer quotes any
   ultrasonic datasheet value; v2 distance is U(20,50) cm, assumed.
7. The audit-chain export used for the integrity tests contains 9 rows written when Tomcat started (1 334 → 1 343).
   The paper states this; confirm that this is acceptable.
8. Reference [23] (MPU-6050 product specification Rev 3.4) was added for the shock clip and tilt bound. It has no
   DOI. Check the citation format.
9. Reference [20] (John & Langley): its arXiv DOI `10.48550/arXiv.1302.4964` resolves only through DataCite, not
   Crossref. Following the rule "remove DOIs that fail Crossref", the DOI was removed and the reference kept.
10. `images/workflow.pdf` (Fig. 2, unchanged since `a2e51e8`) uses non-embedded Helvetica and Helvetica-Bold.
    Re-export it with embedded fonts if the publisher's PDF check (e.g. IEEE PDF eXpress / ACM TAPS) requires it.
11. Section IV-B/IV-C wording ("r = 0.20", "τ = 0.80 requires four of five neighbours") was not re-verified in this
    revision. This is unchanged from the fallback.
12. Venue deadline: iciit.org shows 30 Nov 2026 for full papers; date.html shows an older schedule.
