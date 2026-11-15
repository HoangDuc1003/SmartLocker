"""
experiments/detection_b1.py
Backward compatibility alias module forwarding to experiments.detection.
"""

from experiments.detection import (
    DetectionVerdict,
    BaselineDetectorB0,
    ProposedDetectorB1,
)

__all__ = ["DetectionVerdict", "BaselineDetectorB0", "ProposedDetectorB1"]
