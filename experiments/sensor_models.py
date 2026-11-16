"""
experiments/sensor_models.py
SmartLocker Independent Sensor Observation Models with Provenance Tracking.

Implements mathematical observation models for all locker sensors:
  x_measured = Q_q(x_latent + epsilon + d + o)
where:
  x_latent : Ideal signal resulting from the latent physical action
  epsilon  : Measurement noise (Gaussian or sensor-specific distribution)
  d        : Bounded calibration drift
  o        : Occasional outlier / impulse term
  Q_q      : Sensor quantization operator with step size q: Q_q(x) = q * round(x / q)

Every parameter carries an explicit provenance category:
  - DATASHEET_SPEC: Explicitly supported by the correct sensor datasheet
  - CALIBRATED: Obtained from actual measurement or calibration
  - ASSUMED_SIMULATION_PARAMETER: A stated simulation assumption without physical calibration
"""

from dataclasses import dataclass
from enum import Enum
import math
import random
from typing import Any, Dict, List, Optional, Tuple


class ProvenanceCategory(str, Enum):
    DATASHEET_SPEC = "DATASHEET_SPEC"
    CALIBRATED = "CALIBRATED"
    ASSUMED_SIMULATION_PARAMETER = "ASSUMED_SIMULATION_PARAMETER"


@dataclass(frozen=True)
class SensorParameter:
    """Documented sensor specification or simulation parameter."""
    name: str
    value: Any
    unit: str
    provenance: ProvenanceCategory
    description: str
    reference: str


# =============================================================================
# DOCUMENTED PARAMETER REGISTRY
# =============================================================================

SENSOR_PARAMETERS: Dict[str, SensorParameter] = {
    # Reed Switch / Door Contact
    "reed_quantization_step": SensorParameter(
        name="reed_quantization_step",
        value=0.01,
        unit="s",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Firmware 10 ms timer tick quantization for door duration",
        reference="ESP32 timer tick configuration (simulation assumption)",
    ),
    "reed_timing_jitter_sigma": SensorParameter(
        name="reed_timing_jitter_sigma",
        value=0.15,
        unit="s",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Timing jitter and contact debounce uncertainty",
        reference="Mechanical reed contact debounce model (simulation assumption)",
    ),

    # HX711 Load Cell
    "hx711_quantization_step": SensorParameter(
        name="hx711_quantization_step",
        value=0.1,
        unit="g",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Effective load measurement resolution with 24-bit ADC and 20 kg cell",
        reference="Avia Semiconductor HX711 Datasheet Rev 1.0, 24-bit ADC, Section 1",
    ),
    "hx711_noise_sigma": SensorParameter(
        name="hx711_noise_sigma",
        value=3.5,
        unit="g",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Load-cell mechanical vibration and thermal noise standard deviation",
        reference="Cantilever strain gauge bench noise in indoor cabinet (simulation assumption)",
    ),
    "hx711_drift_bound": SensorParameter(
        name="hx711_drift_bound",
        value=2.0,
        unit="g",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Bounded thermal zero-drift interval [-2.0, +2.0] g",
        reference="Typical strain gauge temperature coefficient model (simulation assumption)",
    ),
    "hx711_outlier_prob": SensorParameter(
        name="hx711_outlier_prob",
        value=0.02,
        unit="probability",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Probability of mechanical shock or cable tug outlier",
        reference="Simulation assumption for transient mechanical disturbances",
    ),
    "hx711_outlier_sigma": SensorParameter(
        name="hx711_outlier_sigma",
        value=25.0,
        unit="g",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Magnitude standard deviation for load outliers",
        reference="Simulation assumption for transient mechanical disturbances",
    ),

    # HY-SRF05 Ultrasonic Distance
    "srf05_min_range": SensorParameter(
        name="srf05_min_range",
        value=2.0,
        unit="cm",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Minimum detection distance (acoustic cutoff threshold)",
        reference="HY-SRF05 Precision Ultrasonic Sensor Datasheet, Spec 2 cm - 450 cm",
    ),
    "srf05_max_range": SensorParameter(
        name="srf05_max_range",
        value=450.0,
        unit="cm",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Maximum reliable detection distance",
        reference="HY-SRF05 Precision Ultrasonic Sensor Datasheet, Spec 2 cm - 450 cm",
    ),
    "srf05_resolution": SensorParameter(
        name="srf05_resolution",
        value=0.3,
        unit="cm",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Transducer measurement resolution",
        reference="HY-SRF05 Precision Ultrasonic Sensor Datasheet, Resolution 0.3 cm",
    ),
    "srf05_noise_sigma": SensorParameter(
        name="srf05_noise_sigma",
        value=1.2,
        unit="cm",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Acoustic time-of-flight noise under air turbulence and clothing reflection",
        reference="Air turbulence and textile absorption acoustic dispersion (simulation assumption)",
    ),

    # MPU-6050 Vibration (Accelerometer RMS)
    "mpu6050_quantization_step": SensorParameter(
        name="mpu6050_quantization_step",
        value=0.001,
        unit="g",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Quantization step size at ±2g or ±16g with 16-bit ADC",
        reference="InvenSense MPU-6050 Product Specification Rev 3.4, Section 3.2",
    ),
    "mpu6050_noise_density": SensorParameter(
        name="mpu6050_noise_density",
        value=400.0,
        unit="ug/sqrt(Hz)",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Accelerometer output noise power spectral density",
        reference="InvenSense MPU-6050 Product Specification Rev 3.4, Section 3.2",
    ),
    "mpu6050_ambient_vibe_sigma": SensorParameter(
        name="mpu6050_ambient_vibe_sigma",
        value=0.015,
        unit="g",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Cabinet frame ambient mechanical vibration standard deviation",
        reference="Indoor structural ambient vibration baseline (simulation assumption)",
    ),

    # MPU-6050 Tilt Angle
    "mpu6050_tilt_quantization": SensorParameter(
        name="mpu6050_tilt_quantization",
        value=0.1,
        unit="deg",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Derived frame tilt angle quantization step size",
        reference="Inclinometer estimation algorithm quantization (simulation assumption)",
    ),
    "mpu6050_tilt_noise_sigma": SensorParameter(
        name="mpu6050_tilt_noise_sigma",
        value=0.25,
        unit="deg",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Derived tilt uncertainty from mounting alignment and vibration",
        reference="Accelerometer static angle estimation error (simulation assumption)",
    ),

    # MPU-6050 Shock (Peak Impact)
    "mpu6050_shock_full_scale": SensorParameter(
        name="mpu6050_shock_full_scale",
        value=16.0,
        unit="g",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Selectable full-scale acceleration range (±16 g)",
        reference="InvenSense MPU-6050 Product Specification Rev 3.4, Section 3.2",
    ),
    "mpu6050_shock_quantization": SensorParameter(
        name="mpu6050_shock_quantization",
        value=0.05,
        unit="g",
        provenance=ProvenanceCategory.DATASHEET_SPEC,
        description="Peak impact acceleration discretization step",
        reference="Peak shock detection binning (simulation assumption backed by 16-bit range)",
    ),
    "mpu6050_shock_noise_sigma": SensorParameter(
        name="mpu6050_shock_noise_sigma",
        value=0.35,
        unit="g",
        provenance=ProvenanceCategory.ASSUMED_SIMULATION_PARAMETER,
        description="Shock peak estimation uncertainty and frame resonance variance",
        reference="Structural impact propagation variance (simulation assumption)",
    ),
}


# =============================================================================
# MATHEMATICAL SENSOR OBSERVATION OPERATORS
# =============================================================================

def quantize(value: float, step: float) -> float:
    """Quantization operator Q_q(x) = q * round(x / q)."""
    if step <= 0.0:
        return value
    return round(value / step) * step


def observe_reed_switch(latent_door_sec: float, rng: random.Random) -> float:
    """
    Observe door opening duration from latent door state.
    d_obs = max(0.0, Q_q(d_latent + epsilon_door))
    If latent_door_sec is 0.0 (door never opened), remains 0.0 unless false contact occurs.
    """
    if latent_door_sec <= 0.0:
        return 0.0
    q = SENSOR_PARAMETERS["reed_quantization_step"].value
    sigma = SENSOR_PARAMETERS["reed_timing_jitter_sigma"].value
    jitter = rng.gauss(0.0, sigma)
    observed = max(0.05, latent_door_sec + jitter)
    return round(quantize(observed, q), 2)


def observe_load_cell(latent_weight_g: float, rng: random.Random) -> float:
    """
    Observe weight differential from latent weight delta.
    w_obs = Q_q(w_latent + epsilon_noise + drift + outlier)
    """
    q = SENSOR_PARAMETERS["hx711_quantization_step"].value
    sigma = SENSOR_PARAMETERS["hx711_noise_sigma"].value
    drift_bound = SENSOR_PARAMETERS["hx711_drift_bound"].value
    p_outlier = SENSOR_PARAMETERS["hx711_outlier_prob"].value
    outlier_sigma = SENSOR_PARAMETERS["hx711_outlier_sigma"].value

    noise = rng.gauss(0.0, sigma)
    drift = rng.uniform(-drift_bound, drift_bound)
    outlier = rng.gauss(0.0, outlier_sigma) if (rng.random() < p_outlier) else 0.0

    observed = latent_weight_g + noise + drift + outlier
    return round(quantize(observed, q), 2)


def observe_ultrasonic(latent_dist_cm: float, rng: random.Random) -> float:
    """
    Observe ultrasonic distance from latent occupant distance.
    s_obs = clip(Q_q(s_latent + epsilon_sonar), min_range, max_range)
    """
    q = SENSOR_PARAMETERS["srf05_resolution"].value
    sigma = SENSOR_PARAMETERS["srf05_noise_sigma"].value
    min_range = SENSOR_PARAMETERS["srf05_min_range"].value
    max_range = SENSOR_PARAMETERS["srf05_max_range"].value

    if latent_dist_cm <= 0.0:
        # Transducer stuck / acoustic cutoff fault
        return 0.0

    noise = rng.gauss(0.0, sigma)
    raw = latent_dist_cm + noise
    if raw < min_range:
        return 0.0  # Cutoff: closer than min range yields acoustic blindness
    observed = min(max_range, max(min_range, raw))
    return round(quantize(observed, q), 1)


def observe_vibration(latent_vib_g: float, rng: random.Random) -> float:
    """
    Observe vibration intensity in g (RMS).
    v_obs = max(0.0, Q_q(v_latent + epsilon_vib + offset))
    """
    q = SENSOR_PARAMETERS["mpu6050_quantization_step"].value
    sigma = SENSOR_PARAMETERS["mpu6050_ambient_vibe_sigma"].value

    if latent_vib_g < 0.0:
        # Hardware fault / bus disconnection returns invalid sentinel
        return latent_vib_g

    noise = abs(rng.gauss(0.0, sigma))
    offset = rng.gauss(0.0, 0.005)
    observed = max(0.0, latent_vib_g + noise + offset)
    return round(quantize(observed, q), 3)


def observe_tilt(latent_tilt_deg: float, rng: random.Random) -> float:
    """
    Observe structural tilt angle in degrees.
    theta_obs = max(0.0, Q_q(theta_latent + epsilon_tilt + drift))
    """
    q = SENSOR_PARAMETERS["mpu6050_tilt_quantization"].value
    sigma = SENSOR_PARAMETERS["mpu6050_tilt_noise_sigma"].value

    if latent_tilt_deg < 0.0:
        return latent_tilt_deg  # Bus disconnect sentinel

    noise = rng.gauss(0.0, sigma)
    drift = rng.uniform(-0.15, 0.15)
    observed = max(0.0, latent_tilt_deg + noise + drift)
    return round(quantize(observed, q), 2)


def observe_shock(latent_shock_g: float, rng: random.Random) -> float:
    """
    Observe peak impact shock in g.
    g_obs = max(0.05, Q_q(g_latent + epsilon_shock))
    """
    q = SENSOR_PARAMETERS["mpu6050_shock_quantization"].value
    sigma = SENSOR_PARAMETERS["mpu6050_shock_noise_sigma"].value

    if latent_shock_g <= 0.05:
        # Dropout sentinel
        return latent_shock_g

    noise = rng.gauss(0.0, sigma)
    observed = max(0.05, latent_shock_g + noise)
    return round(quantize(observed, q), 2)


def get_provenance_manifest() -> List[Dict[str, Any]]:
    """Return complete serializable provenance manifest of all sensor model parameters."""
    return [
        {
            "name": p.name,
            "value": p.value,
            "unit": p.unit,
            "provenance": p.provenance.value,
            "description": p.description,
            "reference": p.reference,
        }
        for p in SENSOR_PARAMETERS.values()
    ]
