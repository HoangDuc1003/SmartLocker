# SmartLocker: ICIIT 2027 submission package (local only, not submitted)

Built 2026-11-17 by an unattended session B run. Nothing was uploaded, e-mailed or submitted.

| File | Content |
|---|---|
| `smartlocker-10p.pdf` | Manuscript, 10 pages. SHA-256 `8658775e3284aef962d58fabe7b7fa7dd1374f7f37bb9970e661c079d23cac59` |
| `smartlocker-10p.tex` | LaTeX source (IEEEtran journal, onecolumn; bibliography inline, so there is no `.bib` file) |
| `images/` | `workflow.pdf` (Fig. 2), `ui-user.png` (Fig. 7), `ui-staff.png` (Fig. 8); Figs. 1, 3–6 and 9 are TikZ inside the `.tex` |
| `abstract.txt`, `keywords.txt` | Plain-text abstract and index terms copied from the `.tex` |
| `AI_USE_DISCLOSURE.md` | AI-use table and draft disclosure (needs author confirmation) |
| `CHECKLIST.md` | Submission checklist with open items |

Build: `tectonic -X compile smartlocker-10p.tex` (tectonic 0.17.0, XeTeX path, TeX Gyre fonts).

Not included on purpose: experiment code, run directories, database exports, `experiments/fixtures.py` and
`experiments/verify_hash_chain.py` (hard-coded database password), `reproduction_config.yaml` and
`backend_requests.jsonl` (test device API key).
