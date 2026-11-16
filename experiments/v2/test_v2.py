"""Unit checks for Simulator v2 (no metric is computed). Run: python -I -m experiments.v2.test_v2 (from repo root)."""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from experiments.oracle import CANONICAL_TO_EVALUATION_MAP  # noqa: E402
from experiments.v2.generator_v2 import ScenarioGeneratorV2, load_latency_pool  # noqa: E402

SEEDS = [42, 101, 202, 303, 404]
POOL = load_latency_pool()
rows = {s: ScenarioGeneratorV2(master_seed=s).generate_all() for s in SEEDS}
allr = [x for s in SEEDS for x in rows[s]]

# 1. shock <= 16.0 g always (observed and latent)
assert max(x.shock_mag_g for x in allr) <= 16.0 and max(x.latent_shock_g for x in allr) <= 16.0
# 2. supports and 6->5 mapping unchanged
for s in SEEDS:
    assert collections.Counter(x.category for x in rows[s]) == {c: 20 for c in set(CANONICAL_TO_EVALUATION_MAP.values())}
    assert all(CANONICAL_TO_EVALUATION_MAP[x.ground_truth_label] == x.category for x in rows[s])
# 3. latency: outside timeout subtype every value is a member of the measured pool; timeout = pool value + [2000, 15000]
for x in allr:
    if x.fault_type == "NETWORK_TIMEOUT":
        assert any(2000.0 <= x.network_latency_ms - b <= 15000.0 + 0.01 for b in POOL)
    else:
        assert x.network_latency_ms in POOL, x.network_latency_ms
non_timeout = collections.defaultdict(list)
for x in allr:
    if x.fault_type != "NETWORK_TIMEOUT":
        non_timeout[x.category].append(x.network_latency_ms)
assert all(len(v) >= 85 for v in non_timeout.values())
# 4. credential mixtures (counts over 5 seeds = 100 per class; the table fixes probabilities, not counts)
def frac(cat, pred, only=None):
    v = [x for x in allr if x.category == cat and (only is None or only(x))]
    return sum(1 for x in v if pred(x)) / len(v), len(v)
print("tamper card holder", frac("LOAD_OR_TAMPER_ANOMALY", lambda x: x.rfid_ok))
print("fault valid user", frac("SENSOR_OR_NETWORK_FAULT", lambda x: x.rfid_ok))
assert frac("NORMAL_AUTHORIZED", lambda x: x.rfid_ok)[0] == 1.0
assert frac("UNAUTHORIZED_CREDENTIAL", lambda x: not x.rfid_ok)[0] == 1.0
assert frac("FORCED_DOOR_OPEN", lambda x: x.expected_auth_result == "NONE" and not x.rfid_ok)[0] == 1.0
for cat in ("LOAD_OR_TAMPER_ANOMALY", "SENSOR_OR_NETWORK_FAULT"):
    assert 0.35 < frac(cat, lambda x: x.rfid_ok)[0] < 0.65  # 500 draws of p=0.5
# 5. determinism
a = [x.to_dict() for x in ScenarioGeneratorV2(master_seed=42).generate_all()]
assert a == [x.to_dict() for x in rows[42]]
print("v2 unit checks PASS; n =", len(allr))
