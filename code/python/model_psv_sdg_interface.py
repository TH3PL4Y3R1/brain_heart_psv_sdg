"""
Python-facing interface spec for the MATLAB function `original_code/model_psv_sdg.m`.

This module defines a dataclass capturing all inputs, plus a validator that
checks shapes, monotonicity, and basic consistency. Use it to prepare and
sanity-check data before porting the algorithm to Python.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple
import numpy as np


@dataclass
class ModelInputs:
    """Container matching the MATLAB signature.

    Attributes
    ----------
    EEG_comp : np.ndarray, shape (n_channels, T)
        Time-varying band power per EEG channel. Columns must align to `time`.
        Non-negative, finite values expected.
    IBI : np.ndarray, shape (M,)
        Non-interpolated inter-beat intervals (seconds), IBI[k] = t_R[k+1]-t_R[k].
    t_IBI : np.ndarray, shape (M,)
        Timestamps (seconds) for each IBI value (commonly the time of the first
        R-peak of the interval). Must be strictly increasing.
    CSI : np.ndarray, shape (T,)
        Cardiac Sympathetic Index, sampled at `Fs`, aligned to `time`.
    CVI : np.ndarray, shape (T,)
        Cardiac Vagal Index, sampled at `Fs`, aligned to `time`.
    Fs : float
        Sampling rate (Hz) for `EEG_comp`, `CSI`, `CVI`, and `time`.
    time : np.ndarray, shape (T,)
        Time vector (seconds) corresponding to columns of `EEG_comp` and to
        samples of `CSI`/`CVI`.
    wind : float
        Window length in seconds (e.g., 15.0).
    """

    EEG_comp: np.ndarray
    IBI: np.ndarray
    t_IBI: np.ndarray
    CSI: np.ndarray
    CVI: np.ndarray
    Fs: float
    time: np.ndarray
    wind: float


class InputValidationError(ValueError):
    pass


def _is_strictly_increasing(x: np.ndarray) -> bool:
    return np.all(np.diff(x) > 0)


def validate_inputs(mi: ModelInputs) -> None:
    """Validate shapes, finiteness, and basic consistency of inputs.

    Raises
    ------
    InputValidationError
        If any requirement is violated.
    """
    # Types and finite values
    arrays = {
        'EEG_comp': mi.EEG_comp,
        'IBI': mi.IBI,
        't_IBI': mi.t_IBI,
        'CSI': mi.CSI,
        'CVI': mi.CVI,
        'time': mi.time,
    }
    for name, arr in arrays.items():
        if not isinstance(arr, np.ndarray):
            raise InputValidationError(f"{name} must be a numpy.ndarray")
        if arr.size == 0:
            raise InputValidationError(f"{name} must be non-empty")
        if not np.all(np.isfinite(arr)):
            raise InputValidationError(f"{name} contains NaN or Inf")

    if not np.isscalar(mi.Fs) or mi.Fs <= 0:
        raise InputValidationError("Fs must be a positive scalar")
    if not np.isscalar(mi.wind) or mi.wind <= 0:
        raise InputValidationError("wind must be a positive scalar (seconds)")

    # Shapes
    if mi.EEG_comp.ndim != 2:
        raise InputValidationError("EEG_comp must have shape (n_channels, T)")
    n_channels, T = mi.EEG_comp.shape

    if mi.CSI.ndim != 1 or mi.CSI.shape[0] != T:
        raise InputValidationError("CSI must be 1D with length T (columns of EEG_comp)")
    if mi.CVI.ndim != 1 or mi.CVI.shape[0] != T:
        raise InputValidationError("CVI must be 1D with length T (columns of EEG_comp)")
    if mi.time.ndim != 1 or mi.time.shape[0] != T:
        raise InputValidationError("time must be 1D with length T (columns of EEG_comp)")

    if mi.IBI.ndim != 1 or mi.t_IBI.ndim != 1 or mi.IBI.shape[0] != mi.t_IBI.shape[0]:
        raise InputValidationError("IBI and t_IBI must be 1D with the same length")

    # Monotonicity and positivity
    if not _is_strictly_increasing(mi.time):
        raise InputValidationError("time must be strictly increasing")
    if not _is_strictly_increasing(mi.t_IBI):
        raise InputValidationError("t_IBI must be strictly increasing")
    if np.any(mi.IBI <= 0):
        raise InputValidationError("IBI must be strictly positive (seconds)")

    # Derived window sizes
    Ws = int(round(mi.wind * mi.Fs))
    if Ws <= 0:
        raise InputValidationError("wind * Fs must be >= 1 sample")
    if T <= 2 * Ws:
        raise InputValidationError(
            "T must be greater than 2 * int(wind * Fs) for non-empty outputs")


def output_time_axes(mi: ModelInputs) -> Tuple[np.ndarray, np.ndarray]:
    """Compute expected output time axes to mirror MATLAB indexing.

    Returns
    -------
    tH2B : np.ndarray, shape (T - Ws,)
        Heart→Brain time axis (beginning of window).
    tB2H : np.ndarray, shape (T - 2*Ws,)
        Brain→Heart time axis (interior samples).
    """
    T = mi.EEG_comp.shape[1]
    Ws = int(round(mi.wind * mi.Fs))
    tH2B = mi.time[: T - Ws]
    tB2H = mi.time[Ws : T - Ws]
    return tH2B, tB2H
