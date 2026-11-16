"""
experiments/v2/generator_v2.py -- Simulator v2 (new file; v1 files are untouched).

Implements ONLY the approved parameter table 1.3 and principles P1-P4 of
docs/paper/REVISION2_LOG.md ("Simulator v2 rationale", approved 2026-11-17 00:01 +0700).
Scenario-first order is kept: latent action -> oracle label (pure lookup) -> latent values -> noisy observations.
B1 thresholds are never read here. Sensor noise/quantisation operators are the unchanged v1 ones.

Rule for cells the approved table leaves silent (chosen before FREEZE, listed in the log): a channel of a class/mode
that no table row names takes the NORMAL-class distribution of that channel ("nothing special seen"); structural
quantities that are not in the table (stay_min, ultrasonic distance, fault signature magnitudes) are class-independent.
"""
import json
import math
import os
import random
from typing import List

from experiments.generator import ScenarioGenerator as V1
from experiments.oracle import LatentPhysicalAction as L, ScenarioCategory as C, ScenarioOracle, ScenarioSpec
from experiments.sensor_models import (observe_load_cell, observe_reed_switch, observe_shock, observe_tilt,
                                       observe_ultrasonic, observe_vibration)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LATENCY_SOURCE = os.path.join(ROOT, "experiments", "runs", "RUN_20261116_044130_SEED42_SL_SIM", "backend_responses.jsonl")
SHOCK_CLIP_G = 16.0  # P1: MPU-6050 +-16 g
TILT_OFFSET_DEG = 2.9  # atan(0.05)


def load_latency_pool(path: str = LATENCY_SOURCE) -> List[float]:
    pool = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                j = json.loads(line)
                if j["endpoint"] == "/api/locker/batch":
                    pool.append(float(j["elapsed_ms"]))
    assert len(pool) == 100, len(pool)
    return pool


def logn(rng, median, sigma):
    return rng.lognormvariate(math.log(median), sigma)


# --- latent channel distributions (table 1.3) -------------------------------------------------
def vib_normal(r): return logn(r, 0.05, 0.8)
def vib_tamper(r): return logn(r, 0.30, 0.7)
def vib_forced(r): return logn(r, 0.50, 0.7)
def shock_normal(r): return min(SHOCK_CLIP_G, 1.0 + logn(r, 0.3, 0.9))
def shock_heavy(r): return min(SHOCK_CLIP_G, 1.0 + logn(r, 3.0, 1.0))
def tilt_offset(r): return abs(r.uniform(-TILT_OFFSET_DEG, TILT_OFFSET_DEG))
def tilt_tamper(r): return logn(r, 3.0, 0.8)
def door_normal(r): return logn(r, 8.0, 0.5)
def door_forced(r): return logn(r, 6.0, 0.7)


def weight_open(r):  # NORMAL, door opened (also used where the table is silent for an opened door)
    return r.choice([-1.0, 1.0]) * logn(r, 150.0, 1.0) if r.random() < 0.85 else r.gauss(0.0, 5.0)


def weight_spoof(r): return r.choice([-1.0, 1.0]) * logn(r, 80.0, 0.8)


class ScenarioGeneratorV2:
    def __init__(self, master_seed: int = 42, total_sessions: int = 100, latency_pool=None):
        if total_sessions < 100:
            raise ValueError("Total sessions must be >= 100")
        self.master_seed = master_seed
        self.per_category = total_sessions // 5
        self.master_rng = random.Random(master_seed)
        self.pool = latency_pool if latency_pool is not None else load_latency_pool()

    # -- credentials ---------------------------------------------------------------------------
    @staticmethod
    def _valid(rng):
        mode = rng.choice(["PIN", "PIN", "CARD", "CARD", "FINGERPRINT"])
        if mode == "PIN":
            cred, slot, bank = V1.VALID_PINS[0][0], V1.VALID_PINS[0][1], "CANT-A"
        elif mode == "CARD":
            cred = rng.choice(V1.VALID_CARDS); slot = V1.CARD_SLOT_MAP[cred]; bank = "CANT-A"
        else:
            cred = str(rng.choice(V1.VALID_FINGERPRINTS)); slot = V1.FP_SLOT_MAP[cred]; bank = "CANT-A"
        return mode, cred, slot, bank

    @staticmethod
    def _invalid(rng):
        var = rng.choice(["WRONG_PIN", "BLOCKED_CARD", "UNKNOWN_CARD", "INVALID_FP"])
        if var == "WRONG_PIN":
            return var, "PIN", rng.choice(V1.INVALID_PINS), L.UNAUTHORIZED_WRONG_PIN.value
        if var == "BLOCKED_CARD":
            return var, "CARD", rng.choice(V1.BLOCKED_CARDS), L.UNAUTHORIZED_BLOCKED_CARD.value
        if var == "UNKNOWN_CARD":
            return var, "CARD", rng.choice(V1.UNKNOWN_CARDS), L.UNAUTHORIZED_UNKNOWN_CARD.value
        return var, "FINGERPRINT", str(rng.choice(V1.INVALID_FINGERPRINTS)), L.UNAUTHORIZED_INVALID_FP.value

    def _base_latency(self, rng):
        return rng.choice(self.pool)  # P2: empirical resample, identical for every class

    @staticmethod
    def _auth(method, cred, slot, bank, expected, rfid_ok):
        return {"method": method, "cred": cred, "slot": slot, "bank": bank, "expected": expected, "rfid_ok": rfid_ok}

    @staticmethod
    def _neutral(rng):
        return {"rng": rng, "stay": round(rng.uniform(1.0, 30.0), 1), "dist": rng.uniform(20.0, 50.0)}

    def _build(self, idx, scen_id, seed, category, latent_act, auth, lat, desc, latency, fault=None, dup=False):
        rng = lat["rng"]
        s = ScenarioSpec(
            session_id=f"SIM-SESS-{idx:03d}", scenario_id=scen_id, seed=seed, latent_action=latent_act,
            category=category, ground_truth_label=ScenarioOracle.assign_ground_truth(latent_act),
            auth_method=auth["method"], credential=auth["cred"], slot_code=auth["slot"], bank_code=auth["bank"],
            expected_auth_result=auth["expected"], rfid_ok=auth["rfid_ok"], stay_min=lat["stay"],
            fault_type=fault, network_latency_ms=latency, seq_duplicate=dup, description=desc,
            latent_door_sec=round(lat["door"], 2), latent_weight_g=round(lat["weight"], 2),
            latent_dist_cm=round(lat["dist"], 1), latent_vib_g=round(lat["vib"], 3),
            latent_tilt_deg=round(lat["tilt"], 2), latent_shock_g=round(lat["shock"], 2))
        s.door_open_sec = observe_reed_switch(lat["door"], rng)
        s.weight_delta_g = observe_load_cell(lat["weight"], rng)
        s.ultrasonic_dist_cm = observe_ultrasonic(lat["dist"], rng)
        s.vibration_intensity = observe_vibration(lat["vib"], rng)
        s.tilt_deg = observe_tilt(lat["tilt"], rng)
        s.shock_mag_g = min(SHOCK_CLIP_G, observe_shock(lat["shock"], rng))  # P1: saturation at the configured range
        return s

    def generate_all(self) -> List[ScenarioSpec]:
        out, idx, n, mr = [], 1, self.per_category, self.master_rng
        # 1. NORMAL
        for i in range(n):
            seed = mr.randint(100000, 999999); rng = random.Random(seed)
            m, cred, slot, bank = self._valid(rng)
            act = rng.choice([L.NORMAL_DEPOSIT.value, L.NORMAL_RETRIEVAL.value])
            lat = self._neutral(rng)
            lat.update(door=door_normal(rng), weight=weight_open(rng), vib=vib_normal(rng), tilt=tilt_offset(rng), shock=shock_normal(rng))
            out.append(self._build(idx, f"SCEN-NORM-{i+1:02d}", seed, C.NORMAL_AUTHORIZED.value, act,
                                   self._auth(m, cred, slot, bank, "UNLOCK", True), lat,
                                   f"Normal authorized access using {m} {cred}", self._base_latency(rng)))
            idx += 1
        # 2. UNAUTHORIZED (door never opens)
        for i in range(n):
            seed = mr.randint(100000, 999999); rng = random.Random(seed)
            var, m, cred, act = self._invalid(rng)
            lat = self._neutral(rng)
            lat.update(door=0.0, weight=0.0, vib=vib_normal(rng), tilt=tilt_offset(rng), shock=shock_normal(rng))
            out.append(self._build(idx, f"SCEN-UNAUTH-{i+1:02d}", seed, C.UNAUTHORIZED_CREDENTIAL.value, act,
                                   self._auth(m, cred, "A04", "CANT-A", "DENY", False), lat,
                                   f"Unauthorized attempt: {var}", self._base_latency(rng)))
            idx += 1
        # 3. FORCED (no valid unlock, 100 %)
        for i in range(n):
            seed = mr.randint(100000, 999999); rng = random.Random(seed)
            mech, act = rng.choice([("CROWBAR_PRY", L.FORCED_CROWBAR_PRY.value), ("LOCK_PICK", L.FORCED_LOCK_PICK.value),
                                    ("DOOR_KICK", L.FORCED_KICK_BREACH.value)])
            lat = self._neutral(rng)
            lat.update(door=door_forced(rng), weight=weight_open(rng), vib=vib_forced(rng), tilt=tilt_offset(rng), shock=shock_heavy(rng))
            out.append(self._build(idx, f"SCEN-FORCE-{i+1:02d}", seed, C.FORCED_DOOR_OPEN.value, act,
                                   self._auth("NONE", "NONE", "A04", "CANT-A", "NONE", False), lat,
                                   f"Forced door open: {mech}", self._base_latency(rng)))
            idx += 1
        # 4. TAMPER (door closed; card holder 50 %, no card 50 %; five modes uniform)
        for i in range(n):
            seed = mr.randint(100000, 999999); rng = random.Random(seed)
            mode = rng.choice(["DRILL", "PRY", "HAMMER", "TILT", "WEIGHT_SPOOF"])
            insider = rng.random() < 0.5
            if insider:
                m, cred, slot, bank = self._valid(rng)
                auth = self._auth(m, cred, slot, bank, "UNLOCK", True)
            else:
                auth = self._auth("NONE", "NONE", "A04", "CANT-A", "NONE", False)
            act = {"DRILL": L.TAMPER_DRILL_VIBRATION, "PRY": L.TAMPER_DRILL_VIBRATION, "HAMMER": L.TAMPER_HAMMER_SHOCK,
                   "TILT": L.TAMPER_STRUCTURAL_TILT, "WEIGHT_SPOOF": L.TAMPER_WEIGHT_CLOSED}[mode].value
            lat = self._neutral(rng)
            lat.update(door=0.0,
                       weight=weight_spoof(rng) if mode == "WEIGHT_SPOOF" else rng.gauss(0.0, 5.0),
                       vib=vib_tamper(rng) if mode in ("DRILL", "PRY") else vib_normal(rng),
                       tilt=tilt_tamper(rng) if mode == "TILT" else tilt_offset(rng),
                       shock=shock_heavy(rng) if mode == "HAMMER" else shock_normal(rng))
            out.append(self._build(idx, f"SCEN-TAMPER-{i+1:02d}", seed, C.LOAD_OR_TAMPER_ANOMALY.value, act, auth, lat,
                                   f"Tamper {mode} ({'card holder' if insider else 'no card'})", self._base_latency(rng)))
            idx += 1
        # 5. FAULT (15 sensor + 5 network; valid user 50 %, invalid user 50 %)
        kinds = (["WEIGHT_OUT_OF_RANGE"] * 4 + ["DOOR_EXCEEDS_STAY"] * 4 + ["ULTRASONIC_STUCK"] * 4 + ["IMU_DROPOUT"] * 3
                 + ["NETWORK_TIMEOUT"] * 3 + ["NETWORK_DUPLICATE_REPLAY"] * 2)
        acts = {"WEIGHT_OUT_OF_RANGE": L.FAULT_WEIGHT_OUT_OF_RANGE, "DOOR_EXCEEDS_STAY": L.FAULT_DOOR_EXCEEDS_STAY,
                "ULTRASONIC_STUCK": L.FAULT_ULTRASONIC_STUCK, "IMU_DROPOUT": L.FAULT_IMU_DROPOUT,
                "NETWORK_TIMEOUT": L.FAULT_NETWORK_TIMEOUT, "NETWORK_DUPLICATE_REPLAY": L.FAULT_NETWORK_DUPLICATE_REPLAY}
        for i, kind in enumerate(kinds):
            seed = mr.randint(100000, 999999); rng = random.Random(seed)
            if rng.random() < 0.5:
                m, cred, slot, bank = self._valid(rng)
                auth = self._auth(m, cred, slot, bank, "UNLOCK", True)
            else:
                _, m, cred, _a = self._invalid(rng)
                auth = self._auth(m, cred, "A04", "CANT-A", "DENY", False)
            lat = self._neutral(rng)
            lat.update(door=door_normal(rng), weight=weight_open(rng), vib=vib_normal(rng), tilt=tilt_offset(rng), shock=shock_normal(rng))
            latency, dup = self._base_latency(rng), False
            if kind == "WEIGHT_OUT_OF_RANGE":
                lat["weight"] = rng.choice([-350.0, 24000.0])
            elif kind == "DOOR_EXCEEDS_STAY":
                lat["door"] = lat["stay"] * 60.0 + 120.0
            elif kind == "ULTRASONIC_STUCK":
                lat["dist"] = 0.0
            elif kind == "IMU_DROPOUT":
                lat.update(vib=-1.0, tilt=-1.0, shock=0.01)
            elif kind == "NETWORK_TIMEOUT":
                latency += rng.uniform(2000.0, 15000.0)
            else:
                dup = True
            out.append(self._build(idx, f"SCEN-FAULT-{i+1:02d}", seed, C.SENSOR_OR_NETWORK_FAULT.value, acts[kind].value,
                                   auth, lat, f"Fault {kind}", round(latency, 2), fault=kind, dup=dup))
            idx += 1
        return out
