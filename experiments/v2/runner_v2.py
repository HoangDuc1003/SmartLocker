"""
experiments/v2/runner_v2.py -- live harness for Simulator v2. Reuses ExperimentRunner unchanged; only swaps the generator,
writes to its own run directory (no mirror into experiments/evidence or experiments/results) and clears a lockout
whenever the harness finds one (v2 mixes invalid and valid credentials inside one class, so a lockout would turn a
valid credential into DENY; v2 therefore does not test lockout progression).
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from experiments.runner import ExperimentRunner  # noqa: E402
from experiments.v2.generator_v2 import ScenarioGeneratorV2  # noqa: E402


class ExperimentRunnerV2(ExperimentRunner):
    def __init__(self, **kw):
        kw["mirror_results"] = False
        super().__init__(**kw)
        self.generator = ScenarioGeneratorV2(master_seed=self.master_seed, total_sessions=self.total_sessions)
        orig = self.fixtures.check_lockout

        def check_and_clear():
            locked, retry = orig()
            if locked:
                self.fixtures.reset_lockout()
            return locked, retry
        self.fixtures.check_lockout = check_and_clear


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default="http://localhost:8081/SmartLocker/api")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--run-id", required=True)
    a = ap.parse_args()
    ExperimentRunnerV2(base_url=a.base_url, master_seed=a.seed, run_id=a.run_id,
                       output_dir=os.path.join("experiments", "v2", "evidence_" + a.run_id)).run_all()
