# SmartLocker — ICIIT 2027 Revision 2 log

Single revision log (audit, provenance, results, AI-use mapping). Started 2026-11-16 (UTC+7).
SHA-256 values recorded here establish integrity **from this audit onward only**; they do not prove the
original run date or historical immutability.

Status (2026-11-16 ~20:10 UTC+7): GATE 2 found simulator class leakage (§2.4.3). By default decision the manuscript
was finished in the "keep Study B, disclose the leak" direction and frozen as `docs/paper/smartlocker-10p.fallback.tex`
(§7). Phases 6–7 not done. Next work: §9 Handoff.

---

## 1. Phase 1 — read-only repository audit

| Item | Value |
|---|---|
| Branch | `main` (prompt expected `reconstruction/direction-b`; both point at the same commit) |
| HEAD | `fd05eb9f01bad4b005c5cdd11ea26b247b49a4cc` (= `reconstruction/direction-b`, `research/multisensor-simulation`, `origin/main`) |
| Working tree | one unstaged change, `docs/paper/smartlocker-10p.tex`: `\scopusfalse`→`\scopustrue` and `0.677 \pm 0.038`→`0.677\pm0.038` (pre-existing, not made by this revision) |
| Staged | none |
| `git ls-files -v` h/S entries | none |
| Objects present | `38037ed…` commit, `a2e51e8` commit, `1cc154a` commit, `da95f43` commit, `13ba35f` commit |
| Untracked/ignored at start | none untracked (porcelain `-uall` shows only the `.tex` change) |

Protected files at start — blob hash equals `38037ed` for all (`git hash-object` vs `git rev-parse 38037ed:<path>`):
RuleEngine.java `dc89934d…`, RiskScorer.java `ba96ae6d…`, AlertService.java `fd70a04b…`,
model/LockerSession.java `00d65acc…`, api/LockerSessionApi.java `dfc9733d…`, and all 13 files in `sql/`
(01_schema `f2fb9aec…`, 02_data_v1 `3f4feb2f…`, 03_v2_v3 `8fd9239a…`, 04_phone `fd5f12a1…`, 05_auto_checkin `e98cc609…`,
06_english_messages `6f3b30f6…`, build-order `440c74e2…`, demo_box `4d94bcaf…`, recreate_overdue_alert `17e443ae…`,
test_cleanup `986f535f…`, test_overdue `3ebce49d…`, test_setup `87712003…`, upgrade_main_2026-11 `4af8f375…`).
UI (`*.jsp *.js *.css *.html`): no diff vs `38037ed`.

Template: `\documentclass[journal,onecolumn]{IEEEtran}`, single column, inline `thebibliography` (the `.bib` files are
not used by `smartlocker-10p.tex`). Kept as is (Rule 4).

Build tools: **no TeX engine on this machine** (no latexmk/pdflatex/xelatex on PATH or in MiKTeX/TeX Live folders,
Docker daemon not running). Python 3.11.9 with numpy 2.4.6, pymupdf, pypdf; no scipy/sklearn. JDK 1.8.0_202 and
`web/WEB-INF/lib/weka.jar` (Weka 3.8.6) are present.

Other hygiene findings (not fixed, out of scope / protected-adjacent):
- `experiments/verify_hash_chain.py` and `experiments/fixtures.py` contain a hard-coded SQL `sa` password. Must not go
  into the submission package.
- `experiments/multi_seed_evaluation.py:76` hard-codes `"execution_time_ms": 48.98` (placeholder; not used by any paper number).
- `experiments/statistical_tests.py` labels `n01` as `"n01_b0_only_correct"` while `evaluate.py` defines n01 = B0 wrong,
  B1 right. χ² and exact p are symmetric, so values are unaffected; the key names are wrong.
- `experiments/evidence/scenarios.json` (sha `fd85b94c…`) does **not** match the current generator for seed 42
  (stale file from an earlier generator version). The evaluated run's `sessions.csv` does match (§2.4.1).

---

## 2. Phase 2 — lock the facts

### 2.1 Measurement provenance

Commit facts (from `git log`):
- `da95f43` — 2026-10-28T11:53+07:00 "update RFID flowwork…".
- `13ba35f` — 2026-11-14T15:45+07:00 "Firmware 4.3: sonar-aware auto-lock…".
- `1cc154a` — 2026-11-15T07:19+07:00 "docs: polish README English strings"; **changes only `README.md`** (4+/4−).
  It is an ancestor of HEAD. It is not evidence of any measurement.
- `62eca9c` — 2026-11-16T11:54+07:00, experiment reconstruction (generator/oracle/sensor_models/evaluate).

Do the 30-Oct measured paths differ from `1cc154a`? **Yes, substantially.** `git diff --stat da95f43 1cc154a` on
measured paths: DeviceAuthApi (46 lines), KioskApi (46), HealthApi (29), LockerSessionApi (51), DeviceAuthDao (136),
LockerSessionDao (247), SessionContextDao (14), RuleEngine (+14), AlertService (12), the ML model binary, and
`sql/` 03/04/05/06/upgrade. In addition, the 30-Oct logs themselves say the working tree differed from `da95f43`
(`code-stats.log` header: "working tree may differ"; README: the `resolveSlot` fix was deployed before Newman run 2
without a commit). `13ba35f..1cc154a` also changes 22 files under `src/java` (UI text, `RemoteCommandDao`, `Web.java`).
`1cc154a..HEAD` changes `sql/03,04,06,upgrade`, `sql/recreate_overdue_alert.sql` and `DbContext.java`.

Decision (rule 2.1.4, third branch): the paper must **not** say that `1cc154a` leaves the rule engine/risk scorer/device
API unchanged — that is false. Use a truthful per-measurement table. A re-run on one commit is possible only on the live
stack (owner action; optional).

| Measurement (paper location) | Code commit | Run timestamp (source) | Artifact (sha256 prefix) / procedure |
|---|---|---|---|
| Weka 4-classifier CV, 480 rows, Fig. 9, Table V rows 1–4, timings (VI.B, VI.C) | `da95f43` + uncommitted tree (`UNKNOWN` exact tree) | 2026-10-30T13:26:07Z (log header) | `docs/paper/evidence/ml.log` `44ede33b`; `harness/MlEvidence.java`, `new Random(42)`, 10-fold |
| Server latency, 30 req/endpoint (Table VIII) | `da95f43` + uncommitted tree | 2026-10-30T13:34:29Z (log header + per-response `server_time`) | `latency.log` `03560e3a`; `harness/latency.sh`, curl `time_total` |
| Lockout 5 wrong PINs, 125.5 s (VI.E) | same | 2026-10-30T13:34:56Z (log) | `latency.log` |
| Detection scenarios, Table VI | same | 2026-10-30T13:27:47Z (log) | `scenarios.log` `8338c6ae` |
| Postman 221 req / 472 assertions, 0 failures | same + `resolveSlot` fix deployed, uncommitted | run 2: 2026-10-30T16:16:56.932Z, 144.1 s; run 3: 16:39:33.877Z, 147.0 s (embedded newman `timings.started`) | `newman-2.json` `d12c27d5`, `newman-3.json` `cf986e75` |
| 83 TestNG tests, 83 pass, 0 skip, 2 m 10.5 s | `13ba35f` + uncommitted English-UI tree (log header), **not `1cc154a`** | 2026-11-14T14:56:18Z (log header) | `testng-4.log` `ee904e8d`; DB `SL_T9` |
| Code counts: 89 Java files, 11 765 lines, 22 JSP, 83 `@Test` in 14 classes | `1cc154a` (recount this audit via `git archive`; HEAD: 89 / 11 768 / 22 / 83) | 2026-11-16 (this audit) | `git archive 1cc154a src/java web test` + `find`/`wc` |
| 100-session simulation, seed 42 live (Table VII, VI.F) | `UNKNOWN` — run manifest records no commit; run (04:41:30Z) falls between `38037ed` (02:32Z) and `62eca9c` (04:54Z); B0/B1 code re-run at HEAD reproduces all 200 recorded labels | 2026-11-16T04:41:30–35Z (`run_manifest.json` `timestamp_utc`, per-row timestamps) | `experiments/runs/RUN_20261116_044130_SEED42_SL_SIM/sessions.csv` `9f7c6d7d`, `backend_responses.jsonl` `e8b2d4ed`, `run_manifest.json` `650b7437` |
| Five seeds 101/202/303/404 | HEAD code (offline, no backend) | regenerated 2026-11-16T12:50Z (this audit) | `docs/paper/scripts/results/R2_STUDYB_20261116T125052Z/study_b_results.json` `eece8f44` |
| Phone workflow 1.67 s (VI.E) | `UNKNOWN` | `UNKNOWN` | **No artifact.** `evidence/CHANGES.md:168` says "author measured and reported in chat; no log file". Must be removed or backed by a raw log. |
| "1315 consecutive audit blocks" | — | — | **Wrong number.** 1315 is the last `LockerSession.session_id` in `database_verification.json`, not an audit-chain count. Existing chain checks: 321 nodes (`final_audit_v1`), 532 nodes (`final_audit_v2/audit_chain_verification.json` `4367de88`), each with one single-field tamper test. |
| "re-verified on commit 62eca9c" (VI.D twice) | — | — | **No artifact.** No TestNG or Newman log exists for `62eca9c` or `1cc154a`. Newman-4/5 (14 Nov, `13ba35f`+uncommitted) ran a different collection (241 req / 514 assertions). |

Proposed VI.A sentence (facts only): "The Weka study, response times, replayed scenarios and Postman runs were measured
on 30 October 2026 on commit da95f43 with uncommitted changes in the working tree; the 83-test TestNG run was made on
14 November 2026 on commit 13ba35f with uncommitted changes; code counts refer to commit 1cc154a; and the 100-session
simulation was executed on 16 November 2026 (run RUN_20261116_044130_SEED42_SL_SIM). The device API, data-access layer
and rule engine changed between these commits (Table …/artifact list), so the measurements describe the code of their
own date."

### 2.2 Historical metric change (0.682/0.990 → 0.621/0.913; five-seed 0.733±0.041/0.998±0.004 → 0.677±0.038/0.917±0.005)

Cause (verified with `git log -S'0.682'` and `git show 38037ed:experiments/oracle.py`): commit `62eca9c` replaced the
ground-truth oracle. At `38037ed` the oracle derived the label **from the observed sensor values using thresholds that
mirror B1** (`oracle.py:124–151`: door>stay·60+5, IMU dropout, latency ≥5000 ms, vibration ≥ VIB_BREACH, shock ≥ SHOCK,
tilt ≥ TILT, |weight| > 50 g; and `predict_b1` calls `ProposedDetectorB1`), i.e. labels were circular with B1. `62eca9c`
assigns labels from a latent scenario action before observations are generated, adds sensor noise models, and adds
hand-placed near-threshold cases (generator indices: normal slams 4,14; jammed lock-pick 3,15; stealth drilling 2,8,16;
border faults 3,7). One Threats-to-Validity sentence is justified: the earlier figures came from labels derived with
B1's own thresholds.

### 2.3 The three evaluation paths

**A. Production Java (Tomcat + SQL Server).** `LockerSessionApi` → `AlertService` → `RuleEngine` (priority rules,
Table III) + `RiskScorer` (Weka IBk k=5 from `/ml/locker_model.bin`, `ML_THRESHOLD = 0.80`), context from
`SessionContextDao`. In the 100-session run the batch endpoint did run this path on every ingested session, but **its
verdicts/alerts were not exported**; the evaluation never reads them. Production Java is therefore **not evaluated** in
Study B.

**B. B0 comparator.** `experiments/detection.py:BaselineDetectorB0`, **Python**, host-side, called by `runner.py:364`.
Inputs: `auth_result` (live backend response for seed 42; `expected_auth_result` offline for other seeds),
`door_open_sec`, `weight_delta_g`, `rfid_ok`, `stay_min`, `card_blocked` (harness lookup of a hard-coded blocked-card
list). Rules reproduced from Java: sensor range (door/weight/stay, door > stay) — `B0_R1`; lost card — `R3`; forced open
(no valid credential and door>0) — `R4`; weight change with door 0 — `R6`; plus auth DENY → unauthorized.
Omitted Java rules: remote/phone command validation (STAFF_OPEN / SUSPECTED_SPOOF 2/2'), wrong-user (card owner vs
booking owner), item-left, overdue, calibration expiry, clock offset, replay via sequence (handled by the endpoint),
Tier-2 Weka risk score. Status: **PARTIAL_PARITY**. B0 receives door time and weight; the paper sentence "lacking door
and load telemetry" is false. True reason for misses: B0 has no IMU (vibration/tilt/shock), ultrasonic or network
inputs; 15/20 tamper sessions have no weight change (drill/tilt/hammer), and ultrasonic/IMU/network faults are outside
its inputs.
Table VII/text "Baseline B0 (Java rule engine and Weka model)" is **false** → must be "Python reference comparator with
partial parity".

**C. B1 / B1-P.** `ProposedDetectorB1`, Python, host-side, hand-written 6-tier rules, **no training, no Weka, not
integrated in Tomcat/SQL Server**. Extra inputs: ultrasonic, vibration, tilt, shock (all simulated), network latency
(generator constant), sequence stream (built by the harness only when the scenario has `seq_duplicate`; verified equal
to the backend `duplicates == 1` response for 100/100 seed-42 sessions).

### 2.4 Ground truth, mapping, leakage

1. **Scenario-first order** verified in `generator.py`: latent action → `ScenarioOracle.assign_ground_truth` (pure
   lookup, no detector import) → noisy observations → detectors. Labels do not depend on predictions. ✔
2. **6→5 mapping**: re-mapped `ground_truth_label` equals the recorded 5-class `category` for 100/100; supports 20 per
   class; B0 and B1 use the same 100 records and labels; B0/B1 re-run at HEAD on the recorded observations reproduce
   100/100 recorded labels each; backend `auth_result` equals expected outcome 100/100. ✔
3. **Simulator class leakage — GATE-2 blocker.** A learned model given only observable inputs (Weka J48, trained on
   the 400 sessions of seeds 101/202/303/404, tested on the 100 live seed-42 sessions) reaches **macro-F1 1.000**; the
   tree uses only `rfid_ok`, `auth_result` and `network_latency_ms`:
   `rfid_ok=F ∧ auth=DENY → Unauthorized; rfid_ok=F ∧ auth=NONE → Forced; rfid_ok=T ∧ auth=UNLOCK → Normal;
   rfid_ok=T ∧ auth=NONE ∧ latency≤0 → Tamper; latency>0 → Fault`.
   Causes in `generator.py`: `rfid_ok` and `expected_auth_result` are constants per category; `net_latency = 25.0` is the
   default for **every** fault session (line 447) and 0.0 for all other categories; fault `stay_min` is fixed (10.0 / 2.0).
   Ground truth is independent of predictions, but the observation design encodes the class in deterministic context
   fields (Arp P1 sampling bias / P3 data snooping). Consequences: (i) any gain of B1 over B0 is a property of hand-written
   thresholds on a designed simulator, measured only against a partial-parity comparator; (ii) Study B cannot show that
   multi-sensor fusion is needed — a context-only learner is perfect on this data; (iii) the near-threshold cases that
   limit B1 to 0.913 were placed by hand next to B1's own thresholds (slam 0.46–0.49 g vs 0.45 g; stealth drill
   0.40–0.44 g; jammed pick 0.35–0.43 g; border weight −196 g vs −200 g; door 124.6 s vs 125 s).
   B1 itself has no fitted parameters, so there is no train/test leakage *inside* B1; its thresholds were, however, set
   by the same author who wrote the generator (no held-out tuning) — data snooping by design.
4. **Study A (480 rows)**: `sql/02_data_v1.sql:713–737` inserts one row per index n=1..480 from deterministic formulas
   (class = n mod 6, features from n mod 7/9/80/90/300/200). There are no sessions or scenario instances, so no rows share
   a source and grouped CV has no grouping key; stratified 10-fold CV remains primary **on that written evidence**.
   Caveat (must be stated): the rows are a deterministic lattice, not random samples; WRONG_USER and NORMAL use identical
   formulas and differ only through the residues of n, so CV scores measure interpolation on the lattice. No
   preprocessing or feature selection outside Weka's own `buildClassifier` (IBk normalisation is fitted inside each
   training fold). Fig. 9b equals the IBk confusion matrix printed in `ml.log` (lines 35–42, identical in all 3 runs). ✔

### 2.5 Hardware boundary (firmware `firmware/SmartLocker_Online/SmartLocker_Online.ino`, `FIRMWARE = "4.3-esp32"`)

| Class | Items | Evidence |
|---|---|---|
| A. connected, used by firmware | ESP32, keypad 4×4, PN532, AS608, LCD 1602, 2 servos (bolt, pull-out door), ultrasonic "SRF05" (TRIG 5, ECHO 18 via divider) | firmware pin map and header comment |
| B. present, not validated as a sensor for detection | ultrasonic: used only for presence → backlight and auto-lock (20 s after leaving, ≤120 s; `SONAR_MAX_CM = 100`); no session upload (`/api/locker/batch` not called by firmware) | firmware lines 23–30, 71–80, 283–289 |
| C. simulated only | door switch/reed, load cell/HX711, MPU-6050 vibration/tilt/shock, ultrasonic distance values used by B1, network latency, sequence replay | `experiments/sensor_models.py`, `generator.py`; no HX711/MPU/reed code in firmware |
| D. planned | wiring door switch and load cell, IMU, porting B1 logic to Java, campus trial | paper Conclusion |

Ultrasonic module identity (Devantech SRF05 vs HY-SRF05 clone): **AUTHOR_CONFIRM** — firmware says only "SRF05" with a
5 V echo divider; the simulator cites an "HY-SRF05" sheet (2–450 cm, 0.3 cm). No datasheet spec may be attached until
the part is confirmed.

Security facts verified in source: `SameSite=Lax` in `web/META-INF/context.xml`, no CSRF token in `src/java`/`web`
(only Mapbox `token` matches); ESP32 `secure.setInsecure()` (line 424) and `secureClient.setInsecure()` (line 776);
device auth by `X-API-Key` (SHA-256 stored); 30-Oct log: Tomcat on HTTP 8080, no 8443, no `transport-guarantee`,
HTTPS only via Cloudflare tunnel.

Hash chain construction verified (`sql/01_schema.sql:335–356`): `CONCAT(id|ts126|actor|action|objType|objId|diff|prev)`,
SHA2_256 over NVARCHAR (UTF-16LE), genesis prev = 64 zeros, tail read with `UPDLOCK, HOLDLOCK`; chain stored in the same
database (no external anchor). Python verifier matches this construction.

---

## 3. Phase 3 — results on frozen artifacts (computed this audit)

Scripts (new): `docs/paper/scripts/study_b_analysis.py` `41a6c478`, `docs/paper/scripts/latency_recompute.py`
`313df54a`, `tools/tamper_campaign/tamper_campaign.py` `de1981ef`.
Outputs: `docs/paper/scripts/results/R2_STUDYB_20261116T125052Z/study_b_results.json` `eece8f44` (manifest inside:
input hashes, HEAD, git status, seeds, bootstrap seed 20261116, timestamps);
`.../R2_LATENCY_20261116T125153Z/latency.json` `2d8de8a9`.

### 3.1 Metric recomputation — seed-42 live run (n = 100, 20 per class)

| | Acc | Bal. acc | Macro P | Macro R | Macro F1 | Weighted F1 | Binary F1 (Anomaly +) |
|---|---|---|---|---|---|---|---|
| B0 | 0.6500 | 0.6500 | 0.80503 | 0.6500 | 0.62067 | 0.62067 | 0.72441 (TP46 FP1 FN34 TN19) |
| B1 | 0.9100 | 0.9100 | 0.92295 | 0.9100 | 0.91331 | 0.91331 | 0.94194 (TP73 FP2 FN7 TN18) |

With equal supports, balanced accuracy = macro recall = accuracy, and weighted = macro. Per-class values match
Table VII exactly. Table V "Transfer Check" columns are accuracy / **macro** P / macro R / macro F1 / binary acc /
binary F1 — the caption "(Weighted Averages)" is wrong for these rows (numerically equal only because supports are equal).

McNemar (binary correctness and 5-class correctness give the same table): n00 = 8, n01 = 27 (B0 wrong, B1 right),
n10 = 1, n11 = 64; χ²_cc = 22.3214; exact two-sided binomial p = 2.1607 × 10⁻⁷. Prompt sanity value verified (asserted).

Five seeds (seed changes the master RNG → per-session seeds → credentials, latent values and noise; the scenario
templates and hand-placed cases are fixed). Seed 42 = live run; 101–404 offline with `auth_result` = expected outcome.

| Seed | 42 | 101 | 202 | 303 | 404 | mean | SD (sample, n−1) | SD (population) |
|---|---|---|---|---|---|---|---|---|
| B0 macro-F1 | 0.6207 | 0.7169 | 0.6975 | 0.6935 | 0.6591 | 0.6776 | 0.0380 | 0.0340 |
| B1 macro-F1 | 0.9133 | 0.9133 | 0.9133 | 0.9226 | 0.9223 | 0.9170 | 0.0050 | 0.0045 |

### 3.2 Stratified paired bootstrap (session-level sampling uncertainty of the seed-42 run only)

Unit = session; same indices for B0 and B1; resampled within class (20 each); 10 000 resamples; seed 20261116;
percentile CI (linear interpolation). ΔMacro-F1 = 0.2926, 95 % CI [0.2198, 0.3722]; B0 [0.5444, 0.6908];
B1 [0.8571, 0.9607]. This is not run-to-run variability (that is the five-seed SD) and does not pool seeds.

### 3.3 Fairer baselines — leave-one-seed-out (train 400 sessions of the other four campaigns, test held-out 100)

Features: the 12 observable inputs (door, weight, rfid_ok, stay, auth_result, card_blocked, ultrasonic, vibration, tilt,
shock, network latency, replay flag); no ids, category, latent values, fault type or labels. Weka defaults; preprocessing
inside Weka on the training set only; no threshold tuning.

| Model | Macro-F1 seed 42 | mean ± SD (5 held-out seeds) | McNemar vs B1 (binary, seed 42) |
|---|---|---|---|
| J48 | 1.000 | 1.000 ± 0.000 | n01 = 0, n10 = 9 (learned better), p = 0.0039 |
| Logistic | 1.000 | 0.998 ± 0.004 | same |

Interpretation: the result shows the simulator leak (§2.4.3), **not** that a learned model is a better locker detector.

### 3.4 Retrained ablation (J48, leave-one-seed-out, drop one feature group and retrain)

| Removed group | mean macro-F1 | SD |
|---|---|---|
| none | 1.000 | 0.000 |
| door + load | 1.000 | 0.000 |
| IMU (vibration, tilt, shock) | 1.000 | 0.000 |
| ultrasonic | 1.000 | 0.000 |
| auth context (rfid_ok, auth_result, card_blocked) | 0.970 | 0.012 |
| network (latency, replay) | 1.000 | 0.000 |

The physical-sensor groups carry no information the learner needs on this simulator. An ablation of B1 itself
(rule-based, not trainable) was not run. Table VII must not be called "Ablation".

### 3.5 Tamper campaign — **BLOCKED** (needs an exported copy of AuditLog+HashChain from SQL Server; Rule 9)
Tool self-test on a synthetic 60-row chain (tool check only, not a result): modification 20/20, mid deletion 20/20,
adjacent reorder 20/20, insertion without rehash 20/20 detected; tail truncation 0/20 and privileged rewrite+rehash 0/20
detected, as expected for a plain hash chain.

### 3.6 Latency by scope (`latency.json`)

| Scope | n | median | min | max | mean | P95 (linear) |
|---|---|---|---|---|---|---|
| A. server processing `/api/health` (30 Oct) | 30 | 6.00 | 4.62 | 7.30 | 5.88 | 6.76 |
| A. `/api/device/auth` PIN ASK | 30 | 15.81 | 14.13 | 48.04 | 17.00 | 18.55 |
| A. `/api/kiosk/unlock` PIN ASK | 30 | 16.21 | 13.39 | 102.71 | 31.08 | 95.90 |
| B. client round trip `/api/device/auth` (16 Nov run) | 40 | 17.87 | 1.70 | 41.77 | 19.43 | 32.80 |
| B. client round trip `/api/locker/batch` | 100 | 16.07 | 2.01 | 39.49 | 16.90 | 29.75 |
| C. harness wall time per simulated session | 100 | 47.50 | 25.85 | 91.94 | 48.55 | 71.62 |

Table VIII medians/P95 used nearest-rank (15.7, 19.0, 96.0, 6.8). Scope C includes the harness's own SQL lockout checks
and DB read-back, so "end-to-end session latency 48.55 ms, median 47.38" is mis-scoped and its median is not
reproducible (true median 47.50). The abstract's "every device request within about 0.1 s" is false (phone endpoint max
102.7 ms). The 1.67 s phone workflow has no artifact.

---

## 4. Phase 4 — sensor simulation table (facts from `experiments/sensor_models.py`; code not changed)

| Channel | Observable | Model in code | Parameters | Provenance (audited) |
|---|---|---|---|---|
| Door (reed) | open time, s | 0 if latent ≤ 0; else round(Q_0.01(max(0.05, d + N(0, 0.15²))), 2) | σ 0.15 s, q 0.01 s | ASSUMED (no part number) |
| Load (HX711) | Δweight, g | Q_0.1(w + N(0, 3.5²) + U(−2, 2) + o), o ~ N(0, 25²) w.p. 0.02 | σ 3.5 g, drift ±2 g, q 0.1 g, outlier 2 %/25 g | all ASSUMED — code labels q 0.1 g "DATASHEET_SPEC", but no load-cell sensitivity/calibration exists, so a gram step is not a datasheet value |
| Ultrasonic | distance, cm | 0 if latent ≤ 0 or s+ε < 2; else Q_0.3(clip(s + N(0, 1.2²), 2, 450)) | σ 1.2 cm, range 2–450, q 0.3 | range/resolution are HY-SRF05 vendor claims; module AUTHOR_CONFIRM; σ ASSUMED |
| Vibration (MPU-6050) | RMS, g | sentinel if latent < 0; else Q_0.001(max(0, v + |N(0, 0.015²)| + N(0, 0.005²))) | σ 0.015 g, offset σ 0.005 g | ASSUMED; the 400 µg/√Hz PSD in the registry is **not used** by any equation |
| Tilt (MPU-6050) | deg | sentinel if < 0; else Q_0.1(max(0, θ + N(0, 0.25²) + U(−0.15, 0.15))) | σ 0.25°, drift ±0.15° | ASSUMED |
| Shock (MPU-6050) | peak, g | sentinel if ≤ 0.05; else Q_0.05(max(0.05, g + N(0, 0.35²))) | σ 0.35 g | ASSUMED; **no clipping at ±16 g**: 10/100 seed-42 sessions have 17.05–22.75 g, impossible for a ±16 g MPU-6050; B1's hammer rule (≥ 16 g) fires only on such values |
| Network | latency, ms | generator constant: 25 (faults), 6500 (timeouts), 0 (others) | — | ASSUMED; constant leaks the class (§2.4.3) |

Overlap check: heavy normal use vs mild tamper overlaps only through hand-placed cases (normal slam 0.46–0.49 g vs
stealth drill 0.40–0.44 g, threshold 0.45 g); elsewhere class ranges are disjoint. Separation is artificial. Any change
must follow Rule 12 (justification first, old evidence kept, freeze, rerun all seeds) and needs the author's decision.

---

## 5. GATE 2 status

- Provenance table: complete (with UNKNOWN / no-artifact entries stated).
- Paths A/B/C: explicit. B0 = Python PARTIAL_PARITY; production Java verdicts not evaluated.
- Leakage: Study A rows independent by construction (lattice caveat). Study B: **class identity leaks through
  deterministic context fields; physical channels are redundant on this simulator.** Prompt rule: report before
  continuing; results must be regenerated after a fix.

Pending (not started): tamper campaign on real export, ICIIT/ACM policy pages, DOI audit, manuscript edits, build,
number audit, submission package.

## 6. AI-use mapping (draft; author must confirm)

| Stage | Tool | Evidence | Status |
|---|---|---|---|
| Writing/editing, LaTeX, diagrams Fig. 1–9 | Claude (Anthropic) | current Acknowledgment text | AUTHOR_CONFIRM scope |
| Code: experiments/*.py, audit reports | AI agents (commit messages "Senior Research & Engineering Execution System", `experiments/audit/*.md`) | git history 15–16 Nov | AUTHOR_CONFIRM which tool |
| Evidence harness, logs of 30 Oct ("agent paper-editor-4", "agent reviewer-4", "agent retrain", "agent screens") | AI agents | log headers | AUTHOR_CONFIRM |
| This revision (audit, analysis scripts, log) | Claude Code (Opus 5.5) | this file | confirmed |
| Simulator v2 parameter proposal (P3, table 1.3) | Claude Code (Sonnet 5.5) | "Simulator v2 rationale" draft | proposed by Claude Code; the author reviews and approves each value (pending) |

Draft disclosure for author review (not yet in the paper). ACM policy pages returned HTTP 403 to automated access and the
ICIIT pages state no AI policy, so neither policy text was read; check https://www.acm.org/publications/policy-on-authorship
by hand:
> During this work the authors used generative AI assistants (Claude, Anthropic; AUTHOR_CONFIRM: other tools) to edit
> the English text, check the LaTeX source and draw Fig. 1–9, and AI coding agents to write parts of the simulation,
> evaluation and audit scripts and to run the evidence harness under the authors' supervision. The authors designed the
> system, reviewed every script and result, and take full responsibility for the content. The AI tools are not authors.

The current Acknowledgment says "The design, implementation, experiments and all reported measurements are the authors'
own." Log headers name AI agents as operators of several 30-Oct runs (table above), so that sentence needs the author's
decision before submission.

---

## 7. Fallback manuscript status (`docs/paper/smartlocker-10p.fallback.tex`)

Saved 2026-11-16 ~20:05 UTC+7 as a byte copy of `smartlocker-10p.tex`; SHA-256 of both:
`5e97ed0f2d989d62ccc8872a2725cc3bfd0296b8425dc4dd28577e5e713eeb55`. Diff vs HEAD: +169/−48 lines (includes the
author's pre-existing `\scopustrue` toggle). Words 9 314 → 10 337 (+11 %); the HEAD PDF had exactly 10 pages, so
**the fallback very likely exceeds 10 pages**. Not built yet.

Edits made (all values traced to §3 results or evidence logs; number audit 0 FAIL / 317 tokens,
`scripts/results/R2_NUMBER_AUDIT_20261116T130603Z/number_audit.json`):
- Abstract: removed "every device request within about 0.1 s"; now 83 tests, median 6–16 ms per endpoint (max
  102.7 ms), and the simulation is described as a pipeline check because context fields separate the classes.
- Table I contribution 3 adds the simulated study "whose limits are measured with paired statistics and a learned
  baseline". No "first" or state-of-the-art claims exist. There is no roadmap sentence to delete.
- Related work: the Arp et al. sentence now uses the wording verified in the PDF (30 papers, ten years, CCS/S&P/USENIX/
  NDSS, at least three of ten pitfalls in each paper, P1 90 %, P3 73 % at least partly present). The prompt's
  parenthetical "(counting pitfalls that were at least partly present)" is not stated in the paper, so it was left out.
  The bib entry is now USENIX Security 2022, "Dos and don'ts of machine learning in computer security", pp. 3971–3988
  (usenix.org page), key `arp2022dos`. "Haber and Stornetta hash chain" → "hash-chained audit log in the spirit of
  Haber and Stornetta".
- III.C Hardware: hardware-boundary paragraph (wired parts; ultrasonic only for presence/auto-lock; no door switch,
  load cell or accelerometer; firmware does not upload sessions; no physical validation claimed).
- IV.D: hash-chain limits (no external anchor; truncation, tail append and a DBA rewrite with rehash are not
  detectable; not a full time-stamping protocol). "altering or deleting a row breaks every later hash" corrected.
  III.B→III.A and IV.E→IV.D merges were already present at HEAD.
- V: "about 11 700 lines" → "about 11 800" (11 765 at `1cc154a`).
- VI.A: Study A independence/grid sentence; provenance sentence per §2.1 (no false "unchanged" claim).
- Table V: caption "Offline Weka Study (Weighted Averages) and 100-Session Simulation (Macro Averages)", rows
  "Simulation, B0 comparator" / "Simulation, B1-P", and a note explaining weighted vs macro. The note also says binary
  F1 is weighted for the Weka rows but anomaly-class F1 for the simulation rows; the two definitions were mixed in one
  column before.
- VI.C: removed the unverified "assigns r(s) = 0.00 to normal visits". The 1-of-400 (99.75 %) claim had no artifact
  and is now reproduced (`scripts/study_a_reproduce.py`, `results/R2_STUDYA_20261116T130410Z`); the reconstruction
  first reproduces ml.log's 480-row IBk confusion matrix exactly.
- VI.D: 83 tests attributed to 14 Nov, `13ba35f` + uncommitted tree; Postman 2 min 24 s and 2 min 27 s on 30 Oct; both
  "re-verified on commit 62eca9c" claims removed. Table VI header `\hline` → `\midrule\addlinespace[2pt]` (not yet
  checked visually).
- VI.F rewritten: harness description; B0 = Python comparator with partial parity (included and omitted rules); B1-P
  host-side; Java verdicts not evaluated. New table "Simulated Sensor Channels" (models exactly as in code, all
  parameters assumed, ultrasonic range = vendor claim). Table VII renamed "Comparative Evaluation of B0 and B1-P …".
  Results with McNemar, bootstrap CI and five-seed sample SD. A paragraph on the leak (J48 = 1.000 from context fields,
  ablation), the hand-placed cases (all 9 B1-P errors are hand-placed) and shock > 16 g. Removed the 48.55 ms session
  latency and "1315 audit blocks with 100 % tamper detection". "18 of the 20 tamper sessions leave the weight
  unchanged" (verified; an earlier draft said 15).
- VI.E + Table VIII: Median/Min/Max/Mean (true medians: auth 15.8, not 15.7); P95 dropped; the 1.67 s phone claim
  removed (no artifact); "within about 0.1 s" removed. Fig. 9a axis already starts at 0 (baseline `a2e51e8`).
- VI.G "Threats to Validity and Limitations": internal / external / construct-conclusion with Arp P1, P3, P6, P9 and
  mitigations; the historical 0.990 explained; security list; artifacts sentence.
- Conclusion rewritten without superiority, 0.1 s or 100 % claims. References: RFID locker vol. 2427 → 2605 (Crossref).
- Removed the now-unused macro `\codecommit`. Labels, cites and environments checked: no undefined ref or cite,
  environments balanced. Figures unchanged vs `a2e51e8` (images and TikZ).

Still missing in the fallback:
- Not built or visually inspected; page count unknown (likely > 10, so cuts are needed; the author decides what to cut).
- Tamper campaign BLOCKED (needs the export in §8); the paper therefore states no detection numbers for the chain.
- Acknowledgment / AI disclosure unchanged (author decision, §6).
- The artifacts sentence names the repository, but the new scripts, results and this log are **uncommitted**; the
  author must commit them (or drop the sentence) before submission.
- Venue template: ICIIT provides its own LaTeX template package (iciit.org/sub.html; proceedings by ACM) while the paper
  uses IEEEtran onecolumn. Kept per Rule 4; the author must decide or confirm acceptance.
- Venue facts (checked 2026-11-16): full-paper deadline 30/11/2026 on both iciit.org and date.html; minimum 8
  single-column pages including figures, tables and references; regular registration covers up to 10, extra pages charged.
- Section IV-B text ("r = 0.20", "τ = 0.80 requires four of five neighbours") lies outside the audited sections and was
  not re-verified.

Other checks done in Phase 5: DOI audit — 19 Crossref DOIs resolve (`api.crossref.org/works/<doi>`); John & Langley
`10.48550/arXiv.1302.4964` resolves via doi.org/DataCite; metadata matches except the AIP volume (fixed). The Arp CACM
DOI was removed with the switch to the USENIX version. Review fixes in the tools: the tamper tool now has `tail_append`
and `mid_chain_insertion`, and `rehash()` honours `diff_json`; study_b_analysis takes `JAVA` from the environment (rerun
`R2_STUDYB_20261116T125717Z` is identical to `…125052Z` except run id and manifest).

Script hashes after fixes: study_b_analysis.py `d8731dfc…`, latency_recompute.py `313df54a…`, number_audit.py
`c12337e0…`, study_a_reproduce.py `5310ef6d…`, tools/tamper_campaign/tamper_campaign.py `c58728f8…`.

Build tool installed (author approval 2026-11-16): tectonic 0.17.0 (stable, released 2026-07-27), official asset
`tectonic-0.17.0-x86_64-pc-windows-msvc.zip`, zip SHA-256 `f61ce51f…8030845f` matching the GitHub digest; a single file
`C:\Users\ADMIN\.local\bin\tectonic.exe` (SHA-256 `99ffcfdb…c8bf08d`), no installer, no system settings changed. The
first build downloads the TeX bundle from the network. Phase 6 build command:
`tectonic -X compile docs/paper/smartlocker-10p.tex --outdir <dir>` (XeTeX path → `fontspec` + TeX Gyre fonts branch).

---

## 8. Owner action: export AuditLog + HashChain for the tamper campaign

Read-only query. Run it in PowerShell from the repo root with SQL Server running. It uses Windows authentication; if the
instance only allows SQL logins, replace `-E` with your own `-U`/`-P` and do not paste the password anywhere. Pick the
database whose chain the paper describes (`SL_SIM` = simulation DB; the demo DB is `PRJ301_LOCKER`).

```powershell
New-Item -ItemType Directory -Force docs\paper\scripts\results\exports | Out-Null
sqlcmd -S localhost -E -d SL_SIM -y 0 -h -1 -f 65001 -o docs\paper\scripts\results\exports\auditchain_SL_SIM_raw.txt -Q "SET NOCOUNT ON; SELECT a.audit_id, CONVERT(NVARCHAR(33), a.ts, 126) AS ts_iso, a.actor_user_id, a.action, a.object_type, a.object_id, ISNULL(a.diff_json, N'') AS diff, a.row_hash, h.prev_hash, h.chain_hash, h.anchor_id FROM AuditLog a JOIN HashChain h ON h.audit_id = a.audit_id ORDER BY h.anchor_id FOR JSON PATH, INCLUDE_NULL_VALUES;"
python -I -c "import json,sys; t=''.join(l.rstrip('\r\n') for l in open(sys.argv[1], encoding='utf-8-sig')); d=json.loads(t); json.dump(d, open(sys.argv[2], 'w', encoding='utf-8')); print(len(d), 'rows')" docs\paper\scripts\results\exports\auditchain_SL_SIM_raw.txt docs\paper\scripts\results\exports\auditchain_SL_SIM.json
python -I experiments\verify_hash_chain.py --ledger-file docs\paper\scripts\results\exports\auditchain_SL_SIM.json --output docs\paper\scripts\results\exports\auditchain_SL_SIM_verify.json
Get-FileHash docs\paper\scripts\results\exports\auditchain_SL_SIM.json -Algorithm SHA256
```

Expected: the verify step prints `Verification Status: PASS`. Then, in session A:
`python -I tools/tamper_campaign/tamper_campaign.py --ledger docs/paper/scripts/results/exports/auditchain_SL_SIM.json --n 20 --seed 20261116`.

---

## 9. Handoff

- Manuscript: `smartlocker-10p.fallback.tex` is the frozen fallback (v1 Study B with the leak disclosed). Do not edit it;
  session B starts from it. `smartlocker-10p.tex` currently has identical bytes.
- Verified numbers and sources: §2.1 provenance table, §3 results, §7 edit list. Number audit:
  `python -I docs/paper/scripts/number_audit.py` (reads the newest R2_STUDYB / R2_LATENCY / R2_STUDYA result dirs; its
  CONTEXT list is hand-maintained and must be extended for new numbers, each with a source).
- Analysis tools: `study_b_analysis.py` (v1 only; session A adds `--variant v2`), `latency_recompute.py`,
  `study_a_reproduce.py`, `tools/tamper_campaign/tamper_campaign.py --selftest | --ledger <file>`.
- Blocked or pending: tamper campaign (export, §8); build, page check and visual inspection (tectonic installed); AI
  disclosure and Acknowledgment (author); template acceptance (author); commit of the new files (author); simulator v2,
  which requires a "## Simulator v2 rationale" section with `STATUS: APPROVED_BY_AUTHOR` and a filled parameter table
  (none exists yet).
- Do not package `experiments/verify_hash_chain.py` or `experiments/fixtures.py` (hard-coded `sa` password).

## AUTHOR_CONFIRM (to be filled by the author)
- Ultrasonic module actually fitted: Devantech SRF05 / HY-SRF05 / HC-SR04 / other: ____
- AI tools actually used (all stages, including non-Claude tools and the "agent" operators named in the 30-Oct logs): ____
- Acknowledgment sentence "experiments and all reported measurements are the authors' own": keep / change: ____
- Repository public at submission, and the commit that contains the scripts/results: ____
- Template: keep IEEEtran onecolumn or switch to the ICIIT/ACM package: ____

---

## Simulator v2 rationale

(Text supplied by the author in chat on 2026-11-16, copied verbatim. The blanks and unticked boxes were the author's and were
NOT filled by Claude: Rule 12 and the author's own plan forbid Claude from choosing parameter values.)

### 1.1 Vì sao sửa
Kiểm tra v1 cho thấy: (a) độ trễ mạng là hằng số theo lớp (25 ms cho lỗi, 0 cho lớp khác); (b) rfid_ok, auth_result và
stay_min cố định theo lớp, nên một bộ học chỉ cần các trường ngữ cảnh đã phân lớp hoàn hảo; (c) 10/100 phiên có xung kích
17–22,75 g, vượt thang đo MPU-6050 cấu hình ±16 g; (d) các ca sát ngưỡng được đặt tay cạnh ngưỡng của B1. Cả bốn là lỗi
thiết kế mô hình quan sát, không phải kết quả đo.

### 1.2 Nguyên tắc (cố định trước khi chạy v2)
- P1. Giới hạn vật lý. Xung kích bão hòa tại thang đo cấu hình ±16 g (thang lớn nhất có thể chọn của MPU-6050 theo
  datasheet). Giá trị mô phỏng vượt ngưỡng bị cắt về 16,0 g. Tác giả xác nhận: thang đo mô phỏng = ±16 g. [x]
- P2. Ngữ cảnh mạng không mang nhãn. Mọi phiên đều có độ trễ đo được, rút từ cùng một phân bố cơ sở của testbed, anchor
  bằng phép đo thật của lần chạy live 16/11 (client round trip: /api/device/auth median 17,87 ms, /api/locker/batch
  median 16,07 ms, trong latency.json). Chỉ lỗi mạng mới có đuôi dài/timeout; lỗi cảm biến giữ độ trễ bình thường.
  Tham số phân bố: lấy mẫu lại (empirical resample) từ 100 giá trị `/api/locker/batch` đo thật; see "P2 calibration
  result" below (nguồn: phép đo trên). [x]

  **P2 calibration result — CALIBRATED** (computed 2026-11-16 20:25 +0700 by `docs/paper/scripts/fit_latency_p2.py`
  `b3fd4725…`; output `docs/paper/scripts/results/R2_P2FIT_20261116T132459Z/p2_latency_fit.json` `b6d57066…`).
  - Source log: `experiments/runs/RUN_20261116_044130_SEED42_SL_SIM/backend_responses.jsonl` (SHA-256 `e8b2d4ed…`),
    field `elapsed_ms` = Python client round trip on localhost (includes server processing; no Wi-Fi, no real network).
    All points used; none removed or adjusted.
  - Samples: `/api/locker/batch` n = 100 (one per session), `/api/device/auth` n = 40 (credential sessions only).
  - Empirical, batch (ms): min 2.01, p25 14.48, median 16.07, p75 21.04, p95 29.75 (linear interpolation), max 39.49,
    mean 16.90. Auth: min 1.70, median 17.87, p95 32.80, max 41.77, mean 19.43.
  - Fit: log-normal by maximum likelihood on ln(ms) (mu = mean of ln x, sigma = population SD of ln x).
    Batch: mu = 2.7211, sigma = 0.5161 (median e^mu = 15.20 ms, model mean 17.36 ms).
    Auth: mu = 2.7894, sigma = 0.6922. Pooled (n = 140): mu = 2.7406, sigma = 0.5728.
  - Fit quality: **poor**. One-sample KS D = 0.221 (batch) and 0.257 (auth), above the approximate 5 % critical values
    0.136 and 0.215. Those critical values ignore that the parameters were estimated from the same data, which makes the
    rejection stronger, not weaker. Cause: the data are bimodal — 12/100 batch and 6/40 auth values lie below 8 ms
    (2.0–7.4 ms), separated from the main mass at about 14–21 ms; a one-mode log-normal cannot represent this.
  - Implication for the author's choice (not decided here): the log-normal parameters above are measured but misfit.
    The option that uses only the real data without a parametric assumption is to draw the baseline latency by
    resampling the 100 measured batch values (empirical distribution). Either choice must be stated in table 1.3 before
    FREEZE.
  - Scope caveat: this is localhost testbed latency, not a field network; it calibrates the simulator to this testbed only.
- P3. Trạng thái thẻ là thuộc tính kịch bản. Chỉ định nghĩa bắt buộc: NORMAL_AUTHORIZED có thẻ hợp lệ;
  UNAUTHORIZED_CREDENTIAL có thẻ không hợp lệ hoặc bị từ chối. Với LOAD_OR_TAMPER và SENSOR_OR_NETWORK_FAULT, trạng thái
  thẻ rút từ hỗn hợp có tài liệu: tamper bởi người có thẻ (nội bộ) 50%, không có thẻ 50%; lỗi xảy ra với người dùng hợp
  lệ 50%, không hợp lệ 50%. FORCED_DOOR_OPEN: không có mở khóa hợp lệ 100% (định nghĩa lớp). Lý do: không có dữ liệu về
  ai phá hoại hay khi nào xảy ra lỗi, nên dùng prior không thông tin 50/50. [x]
- P4. Chồng lấn từ phân bố liên tục. Mỗi đại lượng tiềm ẩn (thời gian mở cửa, độ lệch khối lượng, rung, nghiêng, xung
  kích) có phân bố liên tục theo lớp với miền hỗ trợ chồng lấn một phần, tham số chọn theo lập luận vật lý và ghi trong
  bảng 1.3. Không đặt ca nào tương đối với ngưỡng của bất kỳ detector nào, và không đọc ngưỡng của B1 khi chọn tham số. [x]
- P5. Đóng băng và chạy một lần. B0, B1, oracle (logic gán nhãn) và detection.py giữ nguyên (ghi hash trước và sau). File
  v2 là file mới; v1 và mọi kết quả cũ giữ nguyên làm bằng chứng lịch sử. Băm SHA-256 các file v2 và ghi FROZEN vào log
  trước lần chạy đánh giá đầu tiên. Không vòng lặp chỉnh tham số theo metric. Nếu phát hiện lỗi sau đó thì ghi như sửa
  lỗi (trước/sau) và chạy lại cả năm seed.
- P6. Cam kết báo cáo. Báo cáo B0, B1, learned baselines, ablation, kiểm tra "chỉ dùng ngữ cảnh" và v1 (như kết quả lịch
  sử có nêu rò rỉ) bất kể kết quả. Nếu B1 giảm, hoặc bộ học vẫn bão hòa, hoặc một lớp vẫn tách được hoàn toàn, báo cáo
  đúng như vậy.

### 1.3 Bảng tham số (tác giả điền)

| Kênh / đại lượng | Lớp | Phân bố (dạng, tham số) | Căn cứ (datasheet / phép đo / lập luận) | Nhãn |
|---|---|---|---|---|
| Rung (g RMS) | NORMAL | log-normal, median 0.05, σ_log 0.8 | ordinary use small; heavy right tail = hard door closes; no slam data found | ASSUMED_SIMULATION_PARAMETER |
| Rung (g RMS) | TAMPER (khoan, cạy) | log-normal, median 0.30, σ_log 0.7 | drill handle 0.22–1.62 g (2.2–15.9 m/s², Loughborough BS EN 60745 study), transmission factor ~0.2–1 assumed | ASSUMED_SIMULATION_PARAMETER |
| Rung (g RMS) | FORCED | log-normal, median 0.50, σ_log 0.7 | forcing a door assumed more violent than drilling the frame | ASSUMED_SIMULATION_PARAMETER |
| Xung kích (g) | NORMAL | 1 + log-normal(median 0.3, σ_log 0.9), cắt tại 16,0 | 1 g gravity + impulse; slam magnitude assumed | ASSUMED; clip DATASHEET_SPEC (MPU-6050 Rev 3.4 ±16 g) |
| Xung kích (g) | TAMPER (đập) và FORCED | 1 + log-normal(median 3, σ_log 1.0), cắt tại 16,0 | impact peak heavy tailed, saturates at range limit (P1) | ASSUMED; clip DATASHEET_SPEC |
| Nghiêng (độ) | NORMAL và tamper không nghiêng | lệch đều ±2.9°, báo cáo độ lớn | zero-g output ±50 mg X/Y (MPU-6050 Rev 3.4) ⇒ atan(0.05) ≈ 2.9° | bound DATASHEET_SPEC; shape ASSUMED |
| Nghiêng (độ) | TAMPER (nghiêng tủ) | log-normal, median 3°, σ_log 0.8 | assumed; partly overlaps mounting offset | ASSUMED_SIMULATION_PARAMETER |
| Độ lệch khối lượng (g) | NORMAL (cửa mở) | 85 %: dấu ± × log-normal(median 150, σ_log 1.0); 15 %: N(0, 5²) | assumed deposit/retrieval sizes; noise σ 5 g assumed (no HX711 sensitivity/calibration) | ASSUMED_SIMULATION_PARAMETER |
| Độ lệch khối lượng (g) | TAMPER (giả mạo, cửa đóng); tamper khác | dấu ± × log-normal(median 80, σ_log 0.8); tamper khác N(0, 5²) | assumed | ASSUMED_SIMULATION_PARAMETER |
| Thời gian mở cửa (s) | NORMAL | log-normal, median 8, σ_log 0.5 | assumed handling time | ASSUMED_SIMULATION_PARAMETER |
| Thời gian mở cửa (s) | FORCED | log-normal, median 6, σ_log 0.7 | assumed; overlaps NORMAL | ASSUMED_SIMULATION_PARAMETER |
| Độ trễ mạng (ms) | tất cả | lấy mẫu lại 100 giá trị `/api/locker/batch` đo thật (2.01–39.49 ms) | latency.json / R2_P2FIT (log-normal misfit, KS D 0.221) | CALIBRATED (testbed only) |
| Độ trễ mạng (ms) | NETWORK_FAULT (timeout) | độ trễ cơ sở + U(2 000, 15 000) ms; loại lỗi mạng khác giữ độ trễ cơ sở | assumed outage delay | ASSUMED_SIMULATION_PARAMETER |

Tamper modes (drill, pry, hammer, tilt, weight spoof): uniform mixture. Approved by the author without changes on
2026-11-17 00:01 +0700 ("duyệt" / "đã duyệt hết các bảng"), including the three items flagged in the independence check
(FORCED vibration median 0.50 g; shock clip 16.0 g = B1 threshold; timeout range containing 5 000 ms).

### 1.4 Đã biết là sẽ tốn công / rủi ro
B1 có thể giảm điểm; learned baseline có thể thắng B1; ablation có thể cho thấy một số nhóm cảm biến không quan trọng.
Đó là kết quả hợp lệ.

STATUS: APPROVED_BY_AUTHOR 2026-11-16 20:15 +0700 (instruction given by the author in chat; added to the log by Claude
at the author's request). NOTE: at this time P2, P3 and table 1.3 still contain blanks; the session-A precondition also
requires a filled table, so v2 will not be implemented until the author fills them.

STATUS: APPROVED_BY_AUTHOR 2026-11-17 00:01 +0700 — the author approved all tables ("duyệt phiên A", "đã duyệt hết các
bảng"); P1–P4 ticked; P3 and table 1.3 filled verbatim from the proposal below; P2 = empirical resample. Recorded by
Claude Code at the author's request.

### (APPROVED 2026-11-17 00:01; originally DRAFT_PENDING_AUTHOR_REVIEW) — proposal for P3 and table 1.3 (drafted by Claude Code, 2026-11-16 ~20:45 +0700)

At drafting time this was not a decision and the P1–P4 boxes were not yet ticked (they are ticked now). No detector or metric was run and no simulation file changed.
Values were chosen from datasheet, measurement or stated physical argument only; B1/oracle thresholds were NOT used to
choose them (they were compared afterwards, in the independence table). "Positive quantity" = log-normal(median, σ_log).

**Sources checked.** (a) MPU-6050 Product Specification Rev 3.4, InvenSense PS-MPU-6000A-00, 08/19/2013 (PDF read):
AFS_SEL=3 ±16 g, 16 bit, 2 048 LSB/g, initial calibration ±3 %, zero-g output X/Y ±50 mg, Z ±80 mg, cross-axis ±2 %.
The 400 µg/√Hz noise PSD figure was NOT found in the text extraction of this PDF (not verified here; search snippet from
a TDK page, revision unnamed). (b) Drill handle vibration 2.2–15.9 m/s² across modes of one tool (Loughborough University
study of BS EN 60745 test codes, found via web search; full text not read; handle emission, not frame response). (c) No
published peak-acceleration value for a slammed locker/cabinet door was found (searched 2026-11-16). (d)
`latency.json` / `R2_P2FIT_20261116T132459Z` for P2.

**P3 proposal (card state per class).** NORMAL_AUTHORIZED: valid card 100 %. UNAUTHORIZED_CREDENTIAL: invalid/denied 100 %.
FORCED_DOOR_OPEN: no valid unlock 100 % (class definition). LOAD_OR_TAMPER: holder of a valid card (insider) 50 %, no card
50 %. SENSOR_OR_NETWORK_FAULT: occurs for a valid user 50 %, invalid user 50 %. Reason: no data on who tampers or when faults
occur, so a non-informative 50/50 prior; the card state carries class information only where the class definition gives it.

**Table 1.3 proposal.**

| Channel | Class | Distribution (parameters) | Range | Basis | Label |
|---|---|---|---|---|---|
| Vibration (g RMS) | NORMAL | log-normal, median 0.05, σ_log 0.8 | >0 | ordinary use is small; heavy right tail represents hard door closes; no slam data found | ASSUMED_SIMULATION_PARAMETER |
| Vibration | TAMPER (drill/pry) | log-normal, median 0.30, σ_log 0.7 | >0 | drill handle 0.22–1.62 g (2.2–15.9 m/s²), scaled ~0.2–1 for transmission into a cabinet frame (scale factor assumed) | ASSUMED |
| Vibration | FORCED | log-normal, median 0.50, σ_log 0.7 | >0 | assumed: forcing a door is more violent than drilling the frame; no source | ASSUMED |
| Shock peak (g) | NORMAL | 1 + log-normal(median 0.3, σ_log 0.9), clip 16.0 | 1–16 | 1 g gravity baseline plus impulse; slam magnitude assumed | ASSUMED; clip = MPU-6050 ±16 g (DATASHEET_SPEC) |
| Shock peak | TAMPER (hammer) and FORCED | 1 + log-normal(median 3, σ_log 1.0), clip 16.0 | 1–16 | assumed; impact peak heavy tailed, saturates at range limit (P1) | ASSUMED; clip DATASHEET_SPEC |
| Tilt (deg) | NORMAL and non-tilt tamper | uniform offset ±2.9°, reported as magnitude | 0–2.9 | datasheet zero-g output ±50 mg X/Y ⇒ atan(0.05) ≈ 2.9° uncalibrated tilt error; uniform shape assumed | bound DATASHEET_SPEC; shape ASSUMED |
| Tilt | TAMPER (tilting the cabinet) | log-normal, median 3°, σ_log 0.8 | >0 | assumed; partly overlaps the mounting-offset range | ASSUMED |
| Weight change (g) | NORMAL, door opened | 85 %: sign ± × log-normal(median 150, σ_log 1.0); 15 %: N(0, 5²) (opened, nothing moved) | | assumed deposit/retrieval sizes; noise σ 5 g assumed (no HX711 sensitivity/calibration, so no datasheet gram value) | ASSUMED |
| Weight change | TAMPER (spoof, door closed) | sign ± × log-normal(median 80, σ_log 0.8); other tamper modes N(0, 5²) | | assumed | ASSUMED |
| Door open time (s) | NORMAL | log-normal, median 8, σ_log 0.5 | >0 | assumed human handling time; no measurement | ASSUMED |
| Door open time | FORCED | log-normal, median 6, σ_log 0.7 | >0 | assumed; overlaps NORMAL | ASSUMED |
| Network latency (ms) | all classes | resample the 100 measured `/api/locker/batch` values (empirical) | 2.01–39.49 | P2 fit, log-normal misfits (KS D 0.221), so empirical | CALIBRATED (testbed only) |
| Network latency | NETWORK_FAULT (timeout subtype) | base latency + extra delay U(2 000, 15 000) ms | | assumed outage delay; other network subtypes keep base latency | ASSUMED |

Tamper mode mix (drill, pry, hammer, tilt, weight spoof): uniform (no information). Overlap is argued physically: a hard
door slam and a light drilling session can give similar vibration; mounting offset and gentle tilting can give similar
angles; a large deposit and a weight spoof can give similar weight changes.

**Independence check (transparency only; not used to adjust anything).** B1/oracle thresholds known from the log:
vibration 0.45 / 0.60 g, shock 16 g, tilt 4°, weight 50 g, timeout 5 000 ms (±20 % bands 0.36–0.54, 0.48–0.72, 12.8–19.2,
3.2–4.8, 40–60, 4 000–6 000).

| Parameter | Value | Inside a ±20 % band? |
|---|---|---|
| Vibration NORMAL median / 95th pct | 0.05 / ≈0.19 | no |
| Vibration TAMPER median | 0.30 | no (just below 0.36) |
| Vibration FORCED median | 0.50 | **yes** (0.36–0.54) |
| Shock clip | 16.0 | **yes, identical to the 16 g threshold**, forced by P1 (sensor range = B1 hammer threshold) |
| Shock TAMPER median (1 + 3) | 4 | no |
| Tilt offset bound / TAMPER median | 2.9 / 3.0 | no (3.0 just below 3.2) |
| Weight TAMPER median / NORMAL median | 80 / 150 | no |
| Network timeout delay range | 2 000–15 000 | **range contains** the 4 000–6 000 band (a spread, not a point) |
| Door open times | 8 / 6 s | no threshold in band (stay-based rule not compared here) |

Author decides keep/change for the three flagged items.

Done 2026-11-17 00:01 +0700: the author accepted every row above without change, P2 = empirical resample, P1–P4 ticked
(see the STATUS line before this proposal).

---

## Session A status 2026-11-17 00:02 +07:00

**SUPERSEDED (2026-11-17 00:05 +0700):** this run read the log at ~00:00:40, before the author's approval was recorded at
00:01 (see `STATUS: APPROVED_BY_AUTHOR 2026-11-17 00:01 +0700` in "Simulator v2 rationale"; P1–P4 ticked, P3 and table 1.3
filled). The author asked to rerun session A. The A1/A2/step-7 results below remain valid; the line that follows no
longer applies.

~~SESSION A: v2 NOT APPROVED -> session B must use the fallback manuscript.~~
Reason: the "Simulator v2 rationale" section has `STATUS: APPROVED_BY_AUTHOR`, but table 1.3 still contains blank `____` cells,
P2/P3 and the `[ ]` boxes are unfilled, and the only values present are the Claude-drafted `DRAFT_PENDING_AUTHOR_REVIEW`
proposal (not a decision). Per the task, no parameter was filled by Claude; no v2 file was written, no v2 metric was
computed, no seed was generated or run; v1 files and results untouched; manuscript untouched; no git writes.
Not done because of this: steps 1-6 (v2 implementation, freeze, seeds, live seed-42 v2 run, v2 analysis).

**A1 services.** SQL Server (MSSQLSERVER) was already running -> left untouched. Tomcat was not running; started with the
repo's own `scripts/proof/test-stack.ps1 start -Database SL_SIM` (own CATALINA_BASE, port 8081, mail off, log check
"Due reminder e-mails off", 3 JDBC sessions on SL_SIM; no `-Build`, so it served the existing `build/web`, whose build
date was not checked). Health: `GET /api/health` is the database-pinging endpoint; `POST /api/health` answers
`401 BAD_API_KEY` without the device key (it is the authenticated heartbeat), so the POST check was not completed
(no key was used). Read-only SL_SIM query succeeded (AuditLog 1334 rows, HashChain 1334 at start; 1343 at export because the
Tomcat start wrote audit rows). Tomcat stopped afterwards with `test-stack.ps1 stop` (port 8081 closed). No password
was printed or written.

**A2 export.** The section-8 sqlcmd export corrupts long FOR JSON output (`-y 0` conflicts with `-h`; plain `-h -1`
duplicates text at chunk boundaries). Replacement: same SELECT run read-only via `System.Data.SqlClient` with Windows
authentication, chunks concatenated, then the section-8 python line. Output (database SL_SIM, 1343 rows):
`docs/paper/scripts/results/exports/auditchain_SL_SIM.json` SHA-256
`E8D47087032D130EF4920BC0989478E5114508C2890E02FEB37A50363F1B1B3E` (raw `…_raw.txt` `5EAF67CE…`).
`experiments/verify_hash_chain.py --ledger-file`: **PASS**, 1343 nodes, genesis prev = 64 zeros, tail chain hash
`99d6e5b2…510c`, chain intact; built-in single-field tamper test on audit_id 702 caught. Report `auditchain_SL_SIM_verify.json` `75F127D0…`.
Note: the export contains the 9 audit rows created at Tomcat start in addition to the 1334 earlier ones.

**Step 7 tamper campaign** (`tamper_campaign.py` `c58728f8…`, `--n 20 --seed 20261116`, ledger above; run
`R2_TAMPER_20261116T170211Z/tamper_campaign.json` `5264AACD…`). Deterministic integrity tests, not a detection rate:

| Category | Attempted | Detected | Limitation |
|---|---|---|---|
| Field modification | 20 | 20 | - |
| Mid-chain deletion | 20 | 20 | - |
| Reordering (adjacent swap) | 20 | 20 | - |
| Mid-chain insertion (no rehash) | 20 | 20 | - |
| Tail append | 20 | 0 | not detectable without an external head/checkpoint |
| Tail truncation | 20 | 0 | not detectable without an external head/checkpoint |
| Privileged rewrite + rehash | 20 | 0 | a DB administrator can rewrite history and recompute the chain absent external anchoring |

**Handoff for the manuscript session.**
- The leak is NOT fixed: no v2 exists. The fallback manuscript (v1 Study B with the leak disclosed, §7) stays the basis.
  Claims the data supports: B1-P beats the partial-parity Python comparator B0 on this designed simulator (with CI, McNemar,
  five-seed SD); the pipeline works end to end against the live backend. Claims to keep removed: any statement that
  Study B shows multi-sensor fusion is needed or that B1 beats a fair baseline (J48 = 1.000 from context fields).
- The tamper campaign (above) is now available for IV.D/VI: per-category results with the three non-detected limitations.
  The paper may cite it after the author accepts that the export includes rows written at Tomcat start.
- To unblock v2, the author must replace the `____` cells / fill P2, P3 and tick P1-P4 (or explicitly accept the
  DRAFT proposal value by value), then rerun session A. The export step in §8 should use the System.Data.SqlClient method above.

---

## Session A status 2026-11-17 00:14 +0700 (RERUN, simulator v2)

Precondition checked: `STATUS: APPROVED_BY_AUTHOR 2026-11-17 00:01 +0700` present; table 1.3 (13 rows) filled; P1-P4 ticked; P3 filled. OK.
A2 (export) and the tamper campaign are not repeated (see the 00:02 block above).

**v1 hashes BEFORE** (SHA-256): generator.py `c0cf42e46f5e7fd49c77443dbed7ed11644cd8efcfab9d693e93fff93983bc56`, sensor_models.py
`d25e6f0b6e9c47c57d4ffffcdbfa4aba1e335aeb5c75d991dbdd133ec21c8817`, oracle.py `a3a90820afe345064d64c583aea0beec109db516de98383660eb0ea5f836d5a8`,
detection.py `171c1a2ef797a24b03667b21967b7a4966e1a9b44e54e0a91f6fb4335ad28918`, runner.py `49a8fb47bed79e5200a9962e4a8ecf69655bcb8d287a8af356598e59ee6358e5`,
evaluate.py `3a5c63563e477869f8d7965b53843ea2c9f15faaedf97776425f313687b3b74f`.

**Implementation choices where the approved table is silent** (decided before any metric; no value was taken from B1; none tuned):
1. Rule: a channel of a class/mode that no table row names takes the NORMAL-class distribution of that channel. Consequences:
   vibration for tamper modes hammer/tilt/weight-spoof and for UNAUTHORIZED/FAULT = NORMAL; only drill and pry use the TAMPER row (0.30, 0.7).
   Shock for tamper modes other than hammer = NORMAL. Tilt for FORCED/UNAUTHORIZED/FAULT = NORMAL offset (uniform +-2.9 deg, magnitude).
   Weight for FORCED (door opened) and FAULT (non weight-fault) = NORMAL door-opened mixture (85 % +-logN(150,1.0), 15 % N(0,5^2)).
   Weight for UNAUTHORIZED (door never opened) = latent 0. Door time for FAULT (non door-fault) = NORMAL logN(8,0.5).
2. Tamper mode "pry" has no tamper latent action in the unchanged oracle; it uses TAMPER_DRILL_VIBRATION (same canonical label PHYSICAL_TAMPER).
3. Structural, class-independent quantities not in the table: stay_min ~ U(1,30) rounded to 0.1 min for every class; ultrasonic distance ~ U(20,50) cm
   (0 for the ultrasonic-stuck fault). Door-exceeds-stay fault: door = stay_min*60 + 120 s (excess ~ v1's 115 s). Weight-out-of-range fault: latent -350 or +24000 g
   (v1 signature values, no hand-placed border case). IMU dropout and ultrasonic-stuck use the v1 sentinels. Fault subtype counts unchanged (4/4/4/3/3/2).
4. Card state: tamper 50 % card holder (valid credential, expected UNLOCK, rfid_ok true) / 50 % no card (auth NONE, rfid_ok false);
   fault 50 % valid user (valid credential, UNLOCK, rfid_ok true) / 50 % invalid user (invalid credential, DENY, rfid_ok false);
   NORMAL valid 100 %, UNAUTHORIZED invalid 100 %, FORCED NONE/rfid false 100 % (class definition).
5. Sensor noise, drift, quantisation and outlier operators are the unchanged v1 functions (applied on top of the latent draw); observed shock is
   min(16.0, v1 shock operator) (P1). Hand-placed near-threshold cases are removed (P4).
6. Network latency: base = uniform draw from the 100 measured `/api/locker/batch` elapsed_ms values (source `backend_responses.jsonl` of RUN_20261116_044130, sha `e8b2d4ed...`);
   network-timeout subtype adds U(2000,15000) ms. Class-independent outside the timeout subtype (unit-checked).
7. Live harness: v2 mixes valid and invalid credentials inside a class, so a lockout would turn a valid credential into DENY. `runner_v2.py` clears a lockout whenever
   the harness finds one (v2 does not test lockout progression; v1 evidence of that is unchanged). Run directory and mirror are separate (no write to experiments/evidence or results).

**Unit checks** (`python -I experiments/v2/test_v2.py`, 5 seeds x 100 sessions, no metric): shock <= 16.0 g (observed and latent) PASS; supports 20/class and 6->5 mapping PASS;
latency of every non-timeout session is a member of the measured pool, timeout = pool value + [2000,15000] PASS; credential mixtures: NORMAL/UNAUTH/FORCED exactly 100 %,
tamper card holders 51/100, fault valid users 45/100 (binomial p=0.5 range check PASS); generator deterministic PASS. (One assertion bound in the test was wrong
(>=95; the true count is 85 non-timeout fault sessions) and was corrected before freezing; it is a test bug, not a generator or metric change.)

**FROZEN 2026-11-17 00:14 +0700** (no metric, detector run or evaluation has been computed on v2 data before this line):
- experiments/v2/__init__.py `e3b0c442...b855` (empty)
- experiments/v2/generator_v2.py `b4dfe408ede962258881b8669fe87d997a8adbaf93b8950a36d6c884f6877efa`
- experiments/v2/runner_v2.py `d61dac17ac6863ad4a0921817d972cfe299afc1a25e0c7c75b8e6f33edb6f713`
- experiments/v2/test_v2.py `6aad0ee4476780b46c1d7bfe532f8415523d30845f8458128dea197bd0ff7ff0`
- docs/paper/scripts/study_b_analysis.py (with `--variant v2`) `d8f7d3307d5c466d299626ef1925a4550bf367ee6658732af48f9de2395f1e03`
- Parameter table: the approved table 1.3 above (13 rows, unchanged) plus choices 1-7.

**Run 2026-11-17 00:15-00:16 +0700 (one shot; no tuning; no bug fix after FREEZE, so no rerun).**
- Offline v2 sessions (seeds 42, 101, 202, 303, 404; `experiments/v2/offline/v2_seed*_sessions.json`, SHA-256 seed42 `ae9a4210...`, 101 `f60ad852...`, 202 `0ee7172c...`, 303 `bf0087da...`, 404 `b13c3655...`).
- A1 services: SQL Server (MSSQLSERVER) was already running and was left untouched. Tomcat was down; started with `scripts/proof/test-stack.ps1 start -Database SL_SIM` (port 8081, SL_SIM only,
  existing `build/web`) and stopped by me afterwards with `... stop` (port 8081 closed). Health: an unauthenticated `GET /api/health` answered `BAD_API_KEY` (HTTP layer up, a device key is needed; I used no key);
  database health was shown by the harness itself: fixtures deployed on SL_SIM and 100/100 batch rows persisted (ingestion gate 100/100). No password was printed or stored.
- Live v2 run: `experiments/runs/RUN_20261116_171508_SEED42_V2_SL_SIM` (the UTC id equals 2026-11-17 00:15 +0700); sessions.csv `f3977a51...`, backend_responses.jsonl `ce4a6c9e...`, run_manifest.json `3dc38bb5...`.
  Gates: transport 99/100 (the one failure is a network-timeout session whose drawn extra delay was below 5 000 ms, an effect of the approved range 2 000-15 000 ms that contains 5 000), ingestion 100/100,
  auth 100/100 (actual = expected), end-to-end 99/100. B0 and B1 recorded labels reproduced by re-running the frozen detectors: 100/100 each; 6->5 mapping = category 100/100; supports 20 per class;
  backend duplicate flag = generator replay flag 100/100.
- Analysis: `docs/paper/scripts/results/R2_STUDYB_V2_20261116T171537Z/study_b_results.json` SHA-256 `44423ea7fb565fd07d93426f487a0bf6b34b816a3068339ca9c9198b988981d2`
  (`study_b_analysis.py --variant v2 --live-run RUN_20261116_171508_SEED42_V2_SL_SIM`; manifest inside; bootstrap seed 20261116, 10 000 resamples). The v1 behaviour of the script is unchanged (default variant).
- v1 hashes AFTER: all six identical to BEFORE. `git status`: no tracked file changed except the pre-existing `smartlocker-10p.tex`; no git writes by me.

### Results (v2, seed-42 live run, n = 100, 20 per class)
| | Acc | Macro P | Macro R (= bal. acc) | Macro F1 | Binary F1 (Anomaly +) |
|---|---|---|---|---|---|
| B0 | 0.690 | 0.790 | 0.690 | 0.6577 | 0.8227 |
| B1-P | 0.800 | 0.8682 | 0.800 | 0.7799 | 0.8707 |

Per-class F1 (B0 / B1-P): NORMAL 0.576 / 0.642; UNAUTHORIZED 0.889 / 1.000; FORCED 0.974 / 0.974; TAMPER 0.261 / 0.400; FAULT 0.588 / 0.884.
Per-class recall (B0 / B1-P): 0.85/0.85, 1.00/1.00, 0.95/0.95, 0.15/0.25, 0.50/0.95. Confusion matrices (sum 100) are in the JSON.
McNemar (binary): n00 19, n01 6, n10 0, n11 75; chi2_cc 4.1667; exact two-sided p 0.03125. Five-class: n01 11, n10 0; chi2_cc 9.0909; p 0.000977.
Stratified paired bootstrap (session level, seed-42 v2 run only): delta macro-F1 = 0.1222, 95 % CI [0.0621, 0.1899]; B0 [0.5771, 0.7335]; B1-P [0.7079, 0.8450].
Five seeds (sample SD, n-1; the seed changes credentials, latent draws, noise and latency draws; seeds 101-404 offline with auth = expected outcome):
B0 per seed 0.6577 / 0.6086 / 0.5684 / 0.6359 / 0.5772, mean 0.6096, SD 0.0379; B1-P 0.7799 / 0.7779 / 0.7189 / 0.7792 / 0.7070, mean 0.7526, SD 0.0364.
(v1 for comparison, historical and unchanged: B0 0.677 +- 0.038, B1 0.917 +- 0.005; v1 seed 42 0.621 / 0.913.)

Learned baselines, leave-one-seed-out (12 observable features, Weka defaults): J48 macro-F1 per held-out seed 0.980 / 0.990 / 0.990 / 0.970 / 0.970, mean 0.9799, SD 0.0100;
Logistic 1.000 / 1.000 / 0.969 / 0.980 / 1.000, mean 0.9898, SD 0.0145. McNemar vs B1-P (binary, seed 42): J48 learned-right-B1-wrong 19, learned-wrong-B1-right 2, p 2.2e-4; Logistic 19 / 0, p 3.8e-6.
Retrained J48 ablation (mean macro-F1 over 5 held-out seeds, SD): none 0.980 (0.010); door+load removed 0.777 (0.035); IMU removed 0.970 (0.007); ultrasonic removed 0.974 (0.018);
auth context (rfid_ok, auth_result, card_blocked) removed 0.881 (0.036); network (latency, replay) removed 0.956 (0.021).
**Context-only leakage check** (J48 on rfid_ok, auth_result, card_blocked, network latency and replay flag only): macro-F1 0.5456 / 0.5464 / 0.4968 / 0.5460 / 0.5487, mean 0.537 (SD 0.022);
seed-42 recall: NORMAL 1.0, UNAUTHORIZED 1.0, FORCED 1.0, TAMPER 0.0, FAULT 0.25. (v1: 1.000.)
Overlap diagnostics (pooled 500 sessions, best single-feature one-vs-rest threshold, balanced accuracy): NORMAL 0.880 (rfid_ok), UNAUTHORIZED 0.931 (auth = DENY), FORCED 0.939 (auth = NONE),
TAMPER 0.875 (door time), FAULT 0.795 (door time). **No class is perfectly separable by any single feature.** Quantiles per class and channel are in `v2_extra.overlap_diagnostics`.

### Interpretation (plain)
- Is the leak gone? The specific v1 leak is gone: a learner given only auth, credential and network context reaches macro-F1 0.54, not 1.000; network latency is class-independent; shock never exceeds 16 g.
- No class is separable from one channel, but classes are still largely separable by combinations: J48 on all observable features reaches 0.98 on held-out seeds. That is a property of this simulator
  (class-conditional distributions with partial overlap that the author approved and I implemented), not evidence about real lockers.
- Claims the data now supports: (a) on v2 the Python comparator B0 is clearly worse than B1-P (delta macro-F1 0.122, CI [0.062, 0.190], McNemar p 0.031 binary / 0.001 five-class;
  five-seed 0.610 vs 0.753); (b) B1-P is NOT near-perfect: v2 gives 0.78 (seed 42) and 0.75 (five-seed), and tamper recall is 0.25; (c) B1-P's hand-written thresholds are clearly below a learned baseline
  (0.98); (d) removing door + load telemetry and removing auth context hurt the learned baseline most (0.777, 0.881), while the IMU, ultrasonic and network groups cost about 1.0, 0.6 and 2.4 points (range 0.6-2.4) [corrected 2026-11-17 00:27 +0700 after audit; was "each about 1-2.5"];
  (e) the live pipeline ran end to end (auth 100/100, ingestion 100/100).
- Claims that must be removed or qualified: "B1-P reaches 0.913 / 0.990", any statement that B1 is the best or a sufficient detector, "multi-sensor fusion is necessary" (the ablation does not show it for IMU,
  ultrasonic or network individually), anything implying field performance, and any use of v1 numbers as current (v1 stays only as the historical, leak-disclosed result). The v1 leak paragraph can stay as history.
- B1-P was not changed to fit v2; the weak tamper recall (0.25) is a finding. On seed 42 most tamper sessions are missed whether or not the person holds a card; card-holder tamper is not invisible by construction (SIM-SESS-062, a card-holder weight spoof, is detected by both) [corrected 2026-11-17 00:27 +0700 after audit; the earlier wording said "looks like a normal unlock by construction"]. The rule "unnamed cells use the NORMAL distribution" (hammer, tilt and weight-spoof modes get NORMAL vibration; non-hammer tamper gets NORMAL shock) can contribute to the low tamper recall.

### Limitations
- All v2 channel distributions are ASSUMED_SIMULATION_PARAMETER except the shock clip and tilt bound (datasheet) and the network base latency (empirical, localhost testbed only; the log-normal fit was rejected,
  hence the empirical resample). The table was silent for several cells; choices 1-7 fill them and influence the results (for example hammer-mode vibration = NORMAL, FORCED weight = NORMAL mixture).
- Learned baselines train and test on the same simulator family; they measure separability inside v2, not generalisation to hardware.
- Seeds 101-404 use auth = expected outcome (offline); only seed 42 touched the live backend. B0 and B1-P are host-side Python; production Java verdicts are still not evaluated.
- v2 does not exercise lockout progression (the harness clears lockouts); the transport gate has 1/100 failure caused by the approved timeout range.
- n = 100 per run, 20 per class; the bootstrap CI is session-level sampling uncertainty of one run, the five-seed SD is run-to-run variability; they are not pooled.
- The live v2 run wrote 122 new AuditLog rows to SL_SIM (all between 17:15:08Z and 17:15:16Z, during the run; none at Tomcat start); the 1343-row export of the 00:02 block predates the run and the v2 audit rows are in no export [corrected 2026-11-17 00:27 +0700 after audit].

### Handoff for the manuscript session
- Use `smartlocker-10p.fallback.tex` as the base. Replace Study B numbers by the v2 results above (source: `R2_STUDYB_V2_20261116T171537Z/study_b_results.json`; live run id above); keep v1 as the
  historical result in Threats to Validity (leak and the 0.913 / 0.990 history, section 2.2 of this log).
- Extend the `number_audit.py` CONTEXT list for the new values before use. Rewrite the sensor table with the v2 distributions (table 1.3 plus choices 1-7; labels: ASSUMED, except shock clip and tilt bound
  DATASHEET_SPEC and latency CALIBRATED testbed-only). The tamper-campaign results of the 00:02 block are still valid.
- Do not claim: superiority of B1 over a fair baseline, necessity of IMU, ultrasonic or network, field validity. State plainly that a learned baseline outperforms the hand-written B1-P on v2.
- New files for the author to commit: `experiments/v2/` (with `offline/` and `test_v2.py`), `experiments/runs/RUN_20261116_171508_SEED42_V2_SL_SIM/`, `docs/paper/scripts/results/R2_STUDYB_V2_20261116T171537Z/`.
- Hygiene unchanged: do not package `experiments/fixtures.py` or `verify_hash_chain.py` (hard-coded `sa` password).

SESSION A: DONE 2026-11-17 00:17 +0700

---

## Audit of Session A (Opus)

Independent check by Claude Code (Opus 5.5), 2026-11-17 00:16–00:24 +0700. Read-only apart from this section and
`docs/paper/scripts/results/R2_AUDIT_A_20261116T172341Z.json` (SHA-256 `ff7d14f9395aaa0caaed82459b29a3bd9c4404c1cb1b1ba4547f99ea3ce4fe8a`).
The recomputation is a fresh rewrite (scratchpad script, sha in the JSON). It imports only the frozen v1 `experiments.detection`
to re-run B0/B1, and `generator_v2` only to check that the offline JSON files equal a fresh regeneration. It does not import `study_b_analysis.py`.
Weka was called with its own ARFF files.

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | FROZEN before first metric/run; v2 hashes | PASS | FROZEN = 00:14 +0700 (17:14Z). Last frozen file `study_b_analysis.py` mtime 17:14:17Z. First offline seed file 17:15:04Z. First live session `timestamp_utc` 17:15:08.65Z; run_manifest 17:15:15.56Z; analysis run id 17:15:37Z. All 5 logged v2 hashes equal the current files. The log line has no independent timestamp, but its block order and all artifact timestamps agree. Before freezing, `test_v2.py` generated sessions with no detector or metric run, as the log says. |
| 2 | Invariants | PASS | Six v1 files: current SHA-256 = logged BEFORE = AFTER. `git diff 38037ed` on the 5 protected Java files + `sql/` and on `*.jsp *.js *.css *.html`: empty. Branch `main`, HEAD `fd05eb9` (unchanged; reflog newest entry 2026-11-16 12:00). No commit. The only stash (2026-10-13) predates the revision. Tracked changes: only the pre-existing `smartlocker-10p.tex`. Untracked additions match the log, plus `experiments/v2/evidence_RUN_…/` (a second copy written by the runner's `output_dir`; not mentioned in the log) and `experiments/v2/__pycache__/`. |
| 3 | Generator = approved table 1.3 / P1–P4 | PASS with deviation D1 | Code read line by line: all 13 table rows, P2 (empirical resample of the 100 measured batch values) and P3 50/50 are implemented as written. Latent sample check (5 seeds pooled): door NORMAL median 8.0, FORCED 6.27; vibration NORMAL 0.064, drill/pry 0.256 (n 43), FORCED 0.536; shock-1 NORMAL 0.375, FORCED 3.77 (clipped); tilt offset max 2.86 ≤ 2.9; weight NORMAL small share 0.19 (15 % expected), large |w| median 158; spoof |w| median 75. Values are consistent with the table at these sample sizes. Shock max: observed 15.9, latent 16.0 (≤ 16.0). Non-timeout latency: 485/485 values are members of the v1 batch pool; class medians 16.0–16.6 ms. Timeout = pool + [3 230, 12 602] ms here (inside 2 000–15 000). Card state: tamper 51/100 card holders, fault 45/100 valid; NORMAL/UNAUTH/FORCED 100 % as defined. FORCED: auth NONE and rfid false 100/100. Supports 20/class in all seeds. 6→5 mapping = category 500/500 offline and 100/100 live. Labels come from `ScenarioOracle` (lookup on latent action) before observations; the label path imports no detector. The "unnamed cell" rule and choices 1–7 are written in the log before the FROZEN line. **D1**: choices 3–7 add values the approved table does not contain and the author did not approve: stay U(1,30), ultrasonic U(20,50), door fault = stay·60+120 s, weight fault −350/+24 000 g, lockout clearing. They are disclosed before freezing but contradict "every value comes from the approved table". |
| 4 | Leakage | PASS | Features are the 12 observables only (no id, category, latent, fault_type or label). LOSO train sets exclude the test seed. Per-session seeds overlap across master seeds 0 times, so no identical session sits in both train and test. Preprocessing happens only inside Weka on the training file. The latency pool comes from a v1 measurement, not from labels. The replay flag equals backend `duplicates==1` (100/100 live). |
| 5 | Recompute | PASS | Seed-42 confusion matrices identical to the log (B0 diag 17/20/19/3/10, B1 17/20/19/5/19). Macro-F1 B0 0.6577, B1 0.7799; per-class F1 identical. Re-run labels = recorded 100/100 each; auth = expected 100/100; live observations = offline seed-42 file 100/100. McNemar binary n01 6, n10 0, χ²cc 4.1667, p 0.03125; 5-class 11/0, 9.0909, p 9.77e-4. Bootstrap seed 20261116: Δ 0.1222, CI [0.0621, 0.1899] (identical); seed 777: [0.0626, 0.1905] (stable). Five seeds: B0 0.6096 ± 0.0379, B1 0.7526 ± 0.0364 (sample SD), identical. J48 0.9799 ± 0.0100, Logistic 0.9898 ± 0.0145, J48 vs B1 McNemar 2/19 p 2.2e-4, context-only J48 0.5367 ± 0.0223, ablation 0.777 / 0.970 / 0.974 / 0.881 / 0.956: all identical to the log. Single-feature balanced accuracy maxima 0.880 / 0.931 / 0.939 / 0.875 / 0.795 (identical; none = 1). |
| 6 | Live run | PASS for data, FAIL for manifest | SL_SIM: 98 LockerSession rows for the run's 98 distinct seqs, no duplicate rows. The 2 replay sessions were correctly not stored again (ingestion counts them via `duplicates==1`). Transport 1/100 failure = SIM-SESS-098, latency 3 269.98 ms < 5 000: the cause stated in the log is correct. 5 lockouts occurred and were cleared (lockout_after = 5), as disclosed. Manifest gaps: `run_manifest.json` has run id, timestamp, summary (counts, class distribution) and file hashes. Seed is only in `environment.json`. There is **no code commit/fingerprint and no output paths**. `reproduction_config.yaml` is the v1 template (B1 thresholds, `SENSOR_FAULT`) and contains no v2 parameters. The v2 provenance is only in the log and the analysis manifest. |
| 7 | Log claims | PASS with 3 corrections | (a) "IMU, ultrasonic and network groups each cost about 1–2.5 points": actual 1.0 / 0.6 / 2.4, so ultrasonic is 0.6 (overstated). (b) "A tamper session by a card holder looks like a normal unlock to B0 and B1 by construction" is too strong: card-holder weight-spoof SIM-SESS-062 (UNLOCK) is detected as tamper by both. On seed 42, card-holder tamper sessions are missed when no channel crosses a detector rule, and no-card sessions are missed just as often. (c) Limitation "Tomcat start writes audit rows": for this rerun all 122 new audit rows fall in 17:15:08–17:15:16Z (the live run), none at Tomcat start. All other "supported / must be removed" statements match the recomputed numbers. No claim of field performance was found; the J48 0.98 is correctly attributed to the simulator. |
| 8 | Side effects / secrets | PASS with 2 findings | Tomcat stopped: no Tomcat java process, ports 8081/8015 closed. MSSQLSERVER running (untouched). AuditLog 1343 → 1465 (+122), HashChain 1465 (consistent); LockerSession +98. No SQL password in the log, manifests or results. **Findings**: (i) the test device key the test device key is written in clear in `reproduction_config.yaml` and in every `X-API-Key` header of `backend_requests.jsonl`, in both the run dir and `experiments/v2/evidence_…`. It is already in HEAD (`runner.py`, v1 run config), so this is not a new disclosure, but it must stay out of a public package. (ii) The A1 health gate was not enforced: `curl /api/health` returned `BAD_API_KEY`, and the live run started in the same command without a separate read-only SL_SIM query. DB health was shown only after the fact (100/100 ingestion). |

**Discrepancies and proposed fixes (not applied):**
1. D1: before the paper uses v2, the author must ratify (or change and rerun all five seeds) choices 1–7, especially stay U(1,30), ultrasonic U(20,50), door fault +120 s, weight fault −350/24 000 g, and the vibration/shock rule for hammer, tilt and spoof modes.
2. Write a v2 run manifest (commit HEAD + dirty-tree note, v2 file hashes, seed, parameter table reference, output paths) next to the run; mark `reproduction_config.yaml` as the stale v1 template.
3. Correct the three log claims in row 7 in the manuscript wording ("0.6–2.4 points"; drop "by construction"; drop the Tomcat-start audit sentence for this run).
4. Exclude `reproduction_config.yaml`, `backend_requests.jsonl` and `experiments/v2/evidence_*` from any public package, or redact the key. Mention the duplicate evidence directory in the handoff.
5. Future live runs: run the health check as a separate gated step (authenticated heartbeat or read-only query) before the harness starts.

None of the discrepancies changes a number. Items 1–5 pass. The verdict is conditional on D1 being ratified by the author before submission.

AUDIT A: PASS 2026-11-17 00:24 +0700


---

## Post-audit amendments (2026-11-17 00:27 +0700)

APPROVED_BY_AUTHOR (7 choices, post-run, disclosed) 2026-11-17 00:26 +0700. The author accepted as they stand the seven implementation choices for the cells that table 1.3 leaves blank
(stay U(1,30) min; ultrasonic U(20,50) cm; door fault = stay + 120 s; weight fault -350 or +24 000 g; unnamed cells use the NORMAL distribution; lockout cleared during the live run;
card-state/auth encoding and the pry-to-drill latent action as listed in choices 1-7). Approval came after the run and was disclosed before the freeze; no v2 file or result was changed.

Done: (1) the three wrong sentences above were corrected in place (each carries a "[corrected ...]" marker). (2) New supplementary manifest
`docs/paper/scripts/results/R2_V2_RUN_MANIFEST_20261116T172700Z.json` (SHA-256 `56214ba30c390fe9724be69de3a972526a4e5d9562e492a8de8a96a11681a584`): code commit `fd05eb9` with the dirty-tree note,
fingerprint hashes of the v2 and v1 code, dataset hashes, latency-pool source, output paths, and a statement that `reproduction_config.yaml` is the unchanged runner's v1 template and does not apply to v2.
(3) The runner also wrote a second copy of the run evidence to `experiments/v2/evidence_RUN_20261116_171508_SEED42_V2_SL_SIM/` (same files, own manifest); it is evidence, not a new run.

### Added to the Handoff for the manuscript session (session B)
- Methods: declare the seven choices (the list above plus table 1.3) as simulator assumptions, author-approved after the run. Say that cells the table leaves silent use the NORMAL distribution of that channel.
- Threats to Validity: the same seven choices are assumptions that shape the result. The "NORMAL for unnamed cells" rule (hammer, tilt and weight-spoof modes get NORMAL vibration; non-hammer tamper gets NORMAL shock)
  may contribute to the low tamper recall (B0 0.15, B1-P 0.25); do not present that recall as a property of the detectors alone. Lockout progression was not tested in v2.
- Submission package: exclude the device API key and the files that contain it: `reproduction_config.yaml` and `backend_requests.jsonl` (in both `experiments/runs/RUN_20261116_171508_SEED42_V2_SL_SIM/` and
  `experiments/v2/evidence_RUN_20261116_171508_SEED42_V2_SL_SIM/`), plus the existing exclusions (`experiments/fixtures.py`, `verify_hash_chain.py`). Do not use `reproduction_config.yaml` as v2 documentation.
- Use the three corrected wordings above, not the original ones.

SESSION A: DONE 2026-11-17 00:26 +0700 (post-audit amendments; v2 files and results unchanged)

---

## Session B (manuscript, Phases 5–7), 2026-11-17 00:28–00:45 +0700

Step 0: the end of this log already contained `SESSION A: DONE 2026-11-17 00:17 +0700` and `... 00:26 +0700`,
both after 00:05. The log also contains `FROZEN 2026-11-17 00:14 +0700`, the v2 results and the live seed-42 v2 run
`RUN_20261116_171508_SEED42_V2_SL_SIM`. No wait was needed. Branch taken: **v2 FROZEN and evaluated, so Study B
primary = v2.** The run was interrupted once by the user (`/ponytail off`) and resumed on the user's "resume".
No services were started: the tamper-campaign export and its results were already in this log.

## Final report

**A. Verdict: NOT READY.** One gate fails. The PDF has **11 pages**; the limit is 10, and the 11th page is about
75 % full. Session B cut 36 pieces of non-essential wording (list in F). The remaining overflow is results, threats
to validity, conclusion, acknowledgment and references, so it was reported as a conflict instead of being cut
(`docs/paper/AUTHOR_REVIEW.md` item 1). Every other gate passes. The open author items are listed in H. The three
items below are non-blocking:
- The artifacts sentence needs a commit or a rewording: an author action, not a scientific gap.
- The AI disclosure needs author confirmation: the honest draft is already in the paper.
- The Fig. 2 font embedding: the figure is unchanged since baseline `a2e51e8`, and it is a publisher-check
  issue, not a content issue.

**B. Status**

| Phase | Status | Evidence |
|---|---|---|
| 5 Manuscript edits (v2 branch) | DONE (page budget conflict open) | `docs/paper/smartlocker-10p.tex` SHA-256 `cd79d971fec8933b7d4868edc2afe0881b327d0e10e8b210f4929008928e6a03`; fallback untouched `5e97ed0f…eb55` |
| 5.2 Instructor items | DONE: verified already present in the fallback (Fig. 9a axis 0, Table VI `\addlinespace`, III.B→III.A and IV.E→IV.D merged, Arp wording, no roadmap sentence, provenance wording, 1.67 s / "1315 blocks" / 48.55 ms absent) | rendered pages 2, 5, 6, 8, 9 |
| 5.3 References | DONE | `scripts/results/R2_DOI_AUDIT_20261117T0000Z_SESSIONB/doi_audit.json` `ff58fb87…` |
| 5.4 AI disclosure | DRAFTED in the paper; AUTHOR_CONFIRM | Acknowledgment; `docs/paper/AUTHOR_REVIEW.md` item 3 |
| 6 Build + inspect | DONE, 11 pages | `scripts/results/R2_BUILD_20261116T174010Z/` (pdf, log, `pages/page01–11.png`) |
| 7 Number audit | DONE, 0 FAIL / 371 tokens | `scripts/results/R2_NUMBER_AUDIT_20261116T174001Z/number_audit.json` `9b3df09d…` |
| 7 Integrity + git | DONE | below (G) |
| 7 Package | DONE | `submission_package/ICIIT2027/` |

**C. Provenance (final, as stated in VI.A and VI.E)**

| Measurement group | Code commit | Run date | Artifact |
|---|---|---|---|
| Weka study (Table V rows 1–4, Fig. 9), latency (Table IX), replayed scenarios (Table VI), Postman | `da95f43` + uncommitted tree | 30 Oct 2026 | ml.log, latency.log, scenarios.log, newman-2/3.json (§2.1) |
| TestNG 83 tests | `13ba35f` + uncommitted UI-text tree | 14 Nov 2026 | testng-4.log |
| Code counts | `1cc154a` | 15 Nov 2026 (commit) / recount 16 Nov | `git archive` |
| Study B primary (Tables V rows 5–6, VII, VIII, VI.E text) | `fd05eb9` + uncommitted `experiments/v2/` (frozen hashes above) | 2026-11-16T17:15Z (= 17 Nov 00:15 +0700); the paper says "16 November 2026 (UTC)" | `RUN_20261116_171508_SEED42_V2_SL_SIM`, `R2_STUDYB_V2_20261116T171537Z/study_b_results.json` `44423ea7…`, manifest `R2_V2_RUN_MANIFEST_20261116T172700Z.json` |
| Study B v1 (historical paragraph only) | UNKNOWN (between `38037ed` and `62eca9c`) | 2026-11-16T04:41Z | `RUN_20261116_044130_SEED42_SL_SIM`, `R2_STUDYB_20261116T125717Z` |
| Audit-chain integrity tests (VI.D) | export of SL_SIM, 1 343 rows (9 written at Tomcat start) | 2026-11-16T17:02Z | `R2_TAMPER_20261116T170211Z/tamper_campaign.json` `5264AACD…`, ledger `E8D47087…` |

The 30-Oct vs 15-Nov issue is resolved by the per-measurement wording in VI.A (no single-commit claim).

**D. Scientific corrections made by session B** (in addition to the fallback edits of §7)

| Issue | Evidence | Correction |
|---|---|---|
| Study B on the leaky v1 simulator | §2.4.3; v2 FROZEN + audit PASS | VI.E rewritten on v2; v1 kept as a one-paragraph historical pipeline check with its leak disclosed |
| Sensor table | approved table 1.3 + choices 1–7 | Table VII now lists v2 latent distributions per class with provenance (assumed; shock clip and tilt bound = datasheet [23]; latency = local testbed measurement); v1 noise operators stated in the note |
| Multi-sensor claims | J48 ablation (0.777 / 0.881 / 0.956 / 0.970 / 0.974) | Paper says door, load and credential data carry most information, and no single inertial, ultrasonic or network group is needed; no fusion-necessity claim |
| B1-P vs fair baseline | J48 0.980±0.010, Logistic 0.990±0.014, McNemar 19/2 p 2.2e-4 | "B1-P is not the best detector"; the learned tree outperforms it |
| Hash chain | tamper campaign 00:02 block | VI.D paragraph: 4 operations 20/20 detected, tail append / truncation / privileged rewrite 0/20, deterministic tests, not a rate; IV.D points to it |
| Threats to Validity (v2) | independence table; audit D1; post-audit handoff | Three parameters within ±20 % of B1-P thresholds stated, with "influence not ruled out" (P3); choices approved after the run; "NORMAL for unnamed cells" may lower tamper recall; lockout not simulated; latency = local testbed (P9); P1/P6 mapped |
| Abstract / Table I / Conclusion | v2 results | v2 numbers; no superiority, "100 %" or field-performance claims |
| Acknowledgment | §6; log headers | AI-use disclosure replaces "experiments and all reported measurements are the authors' own" (AUTHOR_CONFIRM) |
| Corrected log claims (audit row 7) | post-audit amendments | The paper uses "whether or not the person holds a card" (not "by construction"), groups 0.6–2.4 points as separate values, and says nothing about Tomcat-start rows for the v2 run |

**E. Final results in the paper (v2 primary)**
- Seed 42 (live): B0 macro-F1 0.658, B1-P 0.780; accuracy 0.69 / 0.80; binary acc 0.750 / 0.810, binary F1
  0.823 / 0.871; tamper recall 0.150 / 0.250; fault recall 0.500 / 0.950.
- McNemar binary: n01 6, n10 0, n00 19, n11 75, χ²cc 4.17, p 0.031. Five-class: 11 / 0, p 9.8e-4.
- Stratified paired bootstrap (seed 20261116, 10 000, seed-42 v2 run only): Δ 0.122, CI [0.062, 0.190].
- Five seeds (sample SD): B0 0.610 ± 0.038, B1-P 0.753 ± 0.036.
- Learned baselines (leave-one-seed-out): J48 0.980 ± 0.010, Logistic 0.990 ± 0.014. Context-only J48
  0.537 ± 0.022, tamper recall 0 in every seed. Best single-feature balanced accuracy 0.939.
- Ablation (J48 retrained): door + load removed 0.777, auth context 0.881, network 0.956, IMU 0.970, ultrasonic 0.974.
- Tamper campaign: per category as in the 00:02 block.
- Latency: unchanged (scope A; Table IX).
- Old → new: seed-42 macro-F1 for B0 / B1-P, 0.621 / 0.913 (v1) → 0.658 / 0.780 (v2). Five seeds, 0.678 / 0.917 →
  0.610 / 0.753. Cause: the v2 simulator removes the class-constant context fields, the hand-placed threshold cases
  and the shock values above 16 g (§2.4.3, "Simulator v2 rationale").

**F. Files changed or created by session B**
- Modified: `docs/paper/smartlocker-10p.tex` (CRLF kept); `docs/paper/scripts/number_audit.py`
  (`ce93ef92…`: reads the v2 result explicitly, the v1 historical file, the tamper campaign and the batch round-trip
  range; CONTEXT extended with sourced table-1.3 values); this log (appended only).
- Created: `docs/paper/AUTHOR_REVIEW.md` (`69577267…`); `docs/paper/scripts/results/R2_DOI_AUDIT_20261117T0000Z_SESSIONB/`;
  `.../R2_NUMBER_AUDIT_20261116T174001Z/`; `.../R2_BUILD_20261116T174010Z/` (pdf, log, stdout, `pages/`);
  `submission_package/ICIIT2027/` (pdf, tex, images ×3, abstract.txt, keywords.txt, AI_USE_DISCLOSURE.md,
  CHECKLIST.md, README.md). Two intermediate number-audit dirs written by this session were deleted (superseded
  by the final run).
- Not modified: `smartlocker-10p.fallback.tex`, all experiment code and results, protected Java/SQL, UI, figures.
- Manuscript content edits: VI.E (new text, Table VII, Table VIII, ablation and baselines, v1 paragraph);
  Table V rows 5–6 and note; VI.A provenance; VI.D audit-chain paragraph; IV.D pointer; Threats internal/external;
  Abstract; Table I row 3; Conclusion; Acknowledgment; reference [23] added; DOI of [20] removed.
- Wording cuts for the page budget (non-essential; content kept elsewhere or dropped as detail):
  C1 intro sentence repeating Table I; C2 biometric sentence (Related Work); C3 federated-schemes sentence;
  C4 RBAC filter + device-key sentences (repeated in III.D); C5 data-model alerts/commands sentence; C6 GPIO pin
  list (duplicates Table II); C7 rule 2'/3–8 explanation shortened; C8 UI language, map-tile fallback and
  env-var configuration; C9 booking-confirmation/alert-view sentence; C10 failed sign-in logging; C11 "listed in
  Table V" pointer; C12 alert-evidence-row sentence; C13 "HTTP checks verify" sentence; C14 detection-scenario
  adjustment narrative shortened (both adjustments kept); C15/C16 Fig. 7/8 captions shortened (figures unchanged);
  D1 parcel-locker review/user-survey sentences merged; D2 late-fee rounding example; D3 duplicate 60 s chain
  re-verify; D4 public-dataset sentence shortened; D5 offline-timeout restatement; D6 credential-mix sentence
  shortened; D7 lockout sentence in VI.E (kept in Threats); E1 "shared campus facility" sentence; E2 IoT anomaly
  survey sentence shortened; E3 simulator sentence in III.A (repeated in III.C / Fig. 2); E4 heartbeat sentence in
  III.C; E5 resent-session sentence in IV.A; E6 hourly/daily booking options; E7 Naive Bayes binary detail;
  F1 VI.B timing sentences condensed (RF timings dropped, IBk kept); F2 VI.C "design does not rest" condensed;
  F3 test coverage list condensed; F4 in-memory/DB split condensed (47/36 kept); F5 AMBIGUOUS_SLOT story
  condensed; F6 acknowledgment thanks condensed. Effect: 12 → 11 pages; the last page went from full to about
  75 % full.

**G. Verification**
- Build: `C:\Users\ADMIN\.local\bin\tectonic.exe -X compile docs/paper/smartlocker-10p.tex --outdir
  docs/paper/scripts/results/R2_BUILD_20261116T174010Z --keep-logs`, exit 0. 0 undefined references or
  citations, 0 overfull boxes. Font warning: IEEEtran requests `TU/ptm` once and falls back to `lmr`; no LM font
  appears in the PDF.
- PDF: 11 pages, US Letter 612×792 pt, 1 804 151 bytes, SHA-256
  `ea8366a9e8f757ecfdace7073d2ef5a7b247012970868c8f6e6ffaf4770756be`.
- Fonts: all text fonts embedded (TeX Gyre Termes/Cursor, CM). Helvetica and Helvetica-Bold are not embedded;
  they come from `images/workflow.pdf` (Fig. 2, unchanged since `a2e51e8`).
- Visual inspection: all 11 pages rendered at 100 dpi (`pages/page01–11.png`) and inspected one by one. No
  clipping or overlap. Table VI header spacing is correct. Fig. 9a axis runs 0–1.00. Tables VII/VIII/IX are
  readable. White space appears only at the bottom of page 2 (float placement). The references are complete in
  two columns.
- Package rebuild from `submission_package/ICIIT2027/` in a scratch copy: exit 0, 11 pages.
- Number audit `python -I docs/paper/scripts/number_audit.py`: 371 tokens, 0 FAIL.
- DOI audit (Crossref `api.crossref.org/works/<doi>`): 18 of 19 resolve, with metadata matching the
  bibliography. `10.48550/arXiv.1302.4964` returns HTTP 404 on Crossref (it is a DataCite DOI), so the DOI was
  removed and the reference kept. All 23 bibitems are cited and all citations are defined.
- Protected files: 5 Java files + 13 `sql/` files, `git hash-object` = blob at `38037ed` (18/18 OK);
  `git diff --stat 38037ed` on them is empty. UI (`*.jsp *.js *.css *.html`) diff vs `38037ed` is empty.
  Figures: `docs/paper/images` and `figs` have no diff vs `a2e51e8`. The 6 TikZ blocks and 3 `\includegraphics`
  lines are identical to `a2e51e8`.
- Git state (end): branch `main`, HEAD `fd05eb9f01bad4b005c5cdd11ea26b247b49a4cc` (unchanged). Staged: none.
  Unstaged: `M docs/paper/smartlocker-10p.tex` only. Untracked: `docs/paper/REVISION2_LOG.md`,
  `docs/paper/scripts/`, `docs/paper/smartlocker-10p.fallback.tex`,
  `experiments/runs/RUN_20261116_171508_SEED42_V2_SL_SIM/`, `experiments/v2/`, `tools/`, and from session B
  `docs/paper/AUTHOR_REVIEW.md` and `submission_package/`. `git ls-files -v`: no `h`/`S` entries. Stash: only
  the 2026-10-13 entry (pre-existing).
- Package secrets: grep over the package finds only prose mentions (BCrypt, "password scheme" reference,
  `X-API-Key` header name). No key, password, `.env` or dump is included.

**H. Remaining issues**
- Scientific blocker: none in the content.
- Page budget: 11 > 10 (`AUTHOR_REVIEW.md` item 1).
- Missing evidence: the Section IV-B/IV-C sentence ("r = 0.20", "τ = 0.80 requires four of five neighbours")
  was not re-verified, as in the fallback.
- Venue uncertainty: IEEEtran vs the ICIIT/ACM template; deadline 30 Nov 2026 (homepage) vs older date.html;
  ACM AI policy page not readable automatically.
- Author confirmation (`AUTHOR_REVIEW.md`):
  - AI tools and the "execute the scripted runs" wording;
  - commit/publish the scripts and v2 runs, or reword the artifacts sentence;
  - the 9 Tomcat-start rows in the export;
  - the ultrasonic module;
  - reference [23] format;
  - re-export Fig. 2 with embedded fonts if required.
- Physical-validation limitation: door switch, load cell and IMU are simulated. v2 distributions are assumed,
  except the shock clip and tilt bound (datasheet) and the base latency (local testbed). No field data exists.

**I. Owner actions**
1. Decide the page budget: accept 11 pages with the extra-page fee, or cut content (candidates in
   `AUTHOR_REVIEW.md` item 1).
2. Commit the new evidence (author only):
   - add: `docs/paper/scripts/`, `docs/paper/REVISION2_LOG.md`, `experiments/v2/` (excluding
     `evidence_*/reproduction_config.yaml` and `backend_requests.jsonl`, which contain the test device key),
     `experiments/runs/RUN_20261116_171508_SEED42_V2_SL_SIM/` (same exclusions), `tools/`;
   - or reword the artifacts sentence in VI.G.
3. Confirm the AI-use table and the Acknowledgment text; read the ACM policy page by hand.
4. Optional: re-export `docs/paper/images/workflow.pdf` with embedded fonts.
5. No live-stack or hardware command is required for the paper as written.

Confirmed: no commit, push, merge, branch switch, stash, remote sync, e-mail or external submission was
performed. No software was installed. No service was started or stopped. Acceptance is not claimed.

SESSION B: DONE 2026-11-17 00:45 +0700 (NOT READY: 11 pages > 10; see AUTHOR_REVIEW.md)

### Session B follow-up 2026-11-17 ~01:00 +0700 (user asked to try cutting one non-essential part)
- `docs/paper/smartlocker-10p.tex` had been changed on disk at 00:45:39 (after the build) by a stray `a` after `\usepackage{multicol}` (line 9) and LF line endings, which broke compilation. It was restored to the built version (SHA-256 `cd79d971...6a03`, identical except that character).
- Page-budget tests in scratch copies only (manuscript not changed). Height of the content on page 11, in pt:
  - current: 613
  - Table IV removed: 468
  - UI figures at 0.16 textheight: no change
  - also Section V condensed: 433
  - also VI.C, lockout/offline and construct-validity wording shortened: 325
  All variants remain 11 pages. One non-essential part cannot reach 10 pages; about 0.35 page more would have to come from Section VI-VII content. Decision left to the author (AUTHOR_REVIEW.md item 1).

### Session B follow-up 2: page budget (2026-11-17 ~01:20 +0700; the author chose "Cut into Section VI")

The cuts were tried step by step in scratch copies, and the first variant that reached 10 pages was applied.
- The previous 11-page `.tex` is kept as `scripts/results/R2_BUILD_20261116T174010Z/smartlocker-10p.tex` (`cd79d971…`).
- New `.tex`: SHA-256 `0972201e555736e91e1ca85dc02aa438f714e39a7f57ceb170613a0bc07d0cae`.
- Build: `tectonic -X compile docs/paper/smartlocker-10p.tex --outdir docs/paper/scripts/results/R2_BUILD_20261116T175744Z --keep-logs`.
  - **10 pages**, 1 797 707 bytes, PDF SHA-256 `efa0d883f20f515fc7c5cc05fd4a356ee92172a5ff81d0245f12014c7b522bba`.
  - No undefined references or citations; one overfull vbox of 0.58 pt (below 5 pt); the same 4 `TU/ptm` font
    fallback warnings as before.
- All 10 pages were rendered (`pages/page01–10.png`) and inspected: no clipping or overlap; all 23 references fit on
  page 10.
- Tables are renumbered automatically: IV Weka, V scenarios, VI sensor channels, VII B0/B1-P, VIII latency.

Cuts (P = removed, W = wording tightened with the same facts):
- Outside Section VI, tested earlier and needed to get there:
  - P: Table IV (prices by plan and size) and its reference.
  - W: Section V condensed into one paragraph. Kept: code size, libraries, stored procedures with UPDLOCK/HOLDLOCK,
    size factors and rounding, late fee 150 %, LockerMonitor periods, Fig. 7/8 references, demo devices, security
    measures. Dropped: the due-reminder e-mail thread.
- VI.A: P training/inference timing method; W TON_IoT sentence (citation kept).
- VI.B: P RF/IBk training and scoring times and the "< 0.2 % of 17.0 ms" sentence.
- VI.C:
  - W per-class discussion; P "because every abnormal class except WRONG_USER alters at least one feature"; per-class
    F1 1.000/0.994 not repeated (Fig. 9 shows it).
  - W "design does not rest on these scores" paragraph.
- VI.D:
  - P test-suite duration (about 2 min).
  - W API scenario list, and the two detection-scenario adjustments (both kept, causes shortened).
- VI.E:
  - W opening sentence.
  - P B0 fault-label counts (5 unauthorized / 5 normal), visible in the per-class results.
  - W offline-seeds clause and Java-verdict sentence.
  - P "the high score of the learned tree reflects the assumed distributions" (kept in Threats/Internal).
  - W the v1 historical paragraph (still names the run, 0.621/0.913, the fixed context fields, the 25 ms latency, the
    threshold-placed cases and the J48 result; the >16 g note dropped).
- VI.F: W scope sentence, PIN-request sentence and caveats; P median restatement (it is in the table), the
  97–98 s / 110 s offline-alert timings and the expected 90–105 s window (Table V keeps 104.6 s), "wrong PINs" wording
  tightened.
- VI.G Threats:
  - W Internal validity. All required items kept: P1, the three ±20 % parameters with "not ruled out" (P3), the open
    cells approved after the run and their effect on tamper recall, P6, the 0.990 history, mitigations.
  - W External validity (all items kept); W Construct/conclusion validity; W Security (all items kept); W Artifacts.
- VII Conclusion: W; P the feature-group ablation sentence and the five-seed numbers (both still in VI.E).
- Acknowledgment: W (same AI-use content).

Re-checks after applying:
- Number audit `R2_NUMBER_AUDIT_20261116T175821Z`: 341 tokens, 0 FAIL.
- 23/23 references cited.
- Protected files: 18/18 identical to `38037ed`; UI diff empty.
- Figures: 6 TikZ blocks and 3 graphics identical to `a2e51e8`.
- Git: HEAD `fd05eb9`, branch `main`, no commit.
- Package updated (`.tex`, `.pdf`, README, CHECKLIST, AI_USE_DISCLOSURE); it rebuilds on its own to 10 pages.
- AUTHOR_REVIEW item 1 marked resolved.

Updated verdict: **READY FOR OWNER REVIEW**. The page budget now passes. The remaining items need author
confirmation and are not content blockers: commit or reword the Artifacts line, confirm the AI-use wording, confirm
the template, and optionally embed the fonts of Fig. 2. They are listed in AUTHOR_REVIEW.md. No commit, push,
e-mail or submission was performed.

### Session B follow-up 3: TestNG run and final commit (2026-11-17 ~01:35 +0700, requested by the author)
- Instructor feedback checked against the paper and repo (answer given in chat). Gmail/ORCID were skipped at the author's request.
- Full TestNG run on `fd05eb9` (src, test, sql, web unchanged): database `SL_T10` built with `scripts/proof/build-db.ps1 -Repo . -Database SL_T10 -TestSetup`, then
  `DB_URL='jdbc:sqlserver://localhost:1433;databaseName=SL_T10;encrypt=false' sh scripts/test.sh`: **83 run, 83 passed, 0 failed, 0 skipped**.
  Log `docs/paper/evidence/testng-5.log`, SHA-256 `0d0df0527c46685c3712738292493bf10c95f870604bf700e3b32609d9d48317` (the file has a two-line header added by the run).
  Code counts at this commit: 89 Java files, 11 768 lines, 22 JSP, 83 `@Test` in 14 classes.
- Paper VI.A and VI.D now say the 83 tests ran on 17 November 2026 on commit `fd05eb9` (source unchanged by the final commit); `\revisioncommit` = `fd05eb9`.
  Rebuilt: 10 pages, PDF SHA-256 `746d2ba6e8d3941d4cc9535ab549cdb92614b7ce54aa4663f95c3fe1ae999ff2`, number audit 340 tokens, 0 FAIL (`R2_NUMBER_AUDIT_20261116T180401Z`).
- Commit and push authorized by the author. Files with the test device key (`backend_requests.jsonl`, `reproduction_config.yaml` of the two v2 run directories) are not added.
