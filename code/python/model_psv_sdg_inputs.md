# model_psv_sdg inputs and usage (MATLAB-oriented guide)

This document explains the inputs and outputs of the MATLAB function `original_code/model_psv_sdg.m` and how to prepare them in MATLAB terms. Use this as a reference to assemble the correct variables before calling the function.

Authoritative source: `original_code/model_psv_sdg.m`.

## Function signature

```matlab
[CSI2B, CVI2B, B2CSI, B2CVI, tH2B, tB2H] = model_psv_sdg(EEG_comp, IBI, t_IBI, CSI, CVI, Fs, time, wind)
```

## Purpose (one‑liner)

Estimate directional brain–heart coupling between EEG band‑power and cardiac indices (CSI/CVI) using sliding‑window ARX models (heart→brain) and normalized averages (brain→heart).

## Inputs (MATLAB variables)

- EEG_comp: double matrix, size [Nch × T]
  - Time‑varying EEG band‑power per channel, already band‑limited and smoothed.
  - Columns align with `time` (i.e., EEG_comp(:,k) corresponds to time(k)).
  - Units: arbitrary power (non‑negative expected).

- IBI: double vector, size [1 × M] or [M × 1]
  - Non‑interpolated inter‑beat intervals in seconds: IBI(i) = t_R(i+1) − t_R(i).
  - Derived from ECG R‑peak times.

- t_IBI: double vector, size [1 × M] or [M × 1]
  - Timestamp (s) for each IBI value; convention: time of the first R‑peak of the interval.
  - Strictly increasing; same length as IBI.

- CSI: double vector, size [1 × T] or [T × 1]
  - Cardiac Sympathetic Index sampled at `Fs` and aligned to `time`.

- CVI: double vector, size [1 × T] or [T × 1]
  - Cardiac Vagal Index sampled at `Fs` and aligned to `time`.

- Fs: scalar double
  - Sampling rate (Hz) corresponding to `EEG_comp`, `CSI`, `CVI`, and `time`.
  - Reference pipeline commonly uses Fs = 4.

- time: double vector, size [1 × T] or [T × 1]
  - Time in seconds for the columns of `EEG_comp` and samples of `CSI`/`CVI`.
  - Monotonically increasing; ideally uniformly sampled at 1/Fs.

- wind: scalar double
  - Sliding window length in seconds used inside the model (typical: 15).

## Outputs

Let `Ws = wind * Fs` (integer number of samples):

- CSI2B: double matrix, size [Nch × (T − Ws)]
  - Heart→Brain coupling coefficient from CSI (ARX B(2)) over time.
  - Time axis: `tH2B = time(1 : end − Ws)` (window aligned at its beginning).

- CVI2B: double matrix, size [Nch × (T − Ws)]
  - Heart→Brain coupling coefficient from CVI (ARX B(2)).
  - Time axis: same as `tH2B`.

- B2CSI: double matrix, size [Nch × (T − 2·Ws)]
  - Brain→Heart index toward CSI, normalized by local EEG power.
  - Time axis: `tB2H = time(Ws+1 : end − Ws)` (interior samples).

- B2CVI: double matrix, size [Nch × (T − 2·Ws)]
  - Brain→Heart index toward CVI, normalized by local EEG power.
  - Time axis: same as `tB2H`.

- tH2B: double vector, size [1 × (T − Ws)]
- tB2H: double vector, size [1 × (T − 2·Ws)]

## Internal processing (what the function does inside)

1) HRV sub‑model (Poincaré‑based) per sliding window:
   - Fixed LF/HF refs: f_lf = 0.1 Hz, f_hf = 0.25 Hz; w = 2·π·f.
   - For each window [t1,t2] on `time`, select IBI samples with `t_IBI ∈ [t1,t2]`.
   - Compute local mean IBI (µ_ibi) and heart rate µ_hr = 1/µ_ibi.
   - Build matrix M and gain G from µ_hr and LF/HF; compute
     L = max(IBI_win) − min(IBI_win),  W = √2·max|ΔIBI_win|.
   - Cs, Cp = (1/G)·M·[L; W]; associate each pair to a central time TM(i).

2) Interpolation and alignment:
   - Define an overlapping time range `time2 = time(time ≥ TM(1) & time ≤ TM(end))`.
   - Interpolate Cs, Cp, CSI, CVI, and each row of EEG_comp onto `time2` (spline),
     avoiding edge extrapolation.
   - Optional artifact cleaning: `EEG_comp = clean_artif(EEG_comp)` (no‑op by default).

3) Directional estimates per channel (parfor over channels):
   - Heart→Brain: ARX with orders [1 1 1] on iddata([EEG_window], [CSI or CVI]).
     Store B(2) at each step for CSI2B/CVI2B.
   - Brain→Heart: compute running means of Cs/Cp normalized by mean EEG power
     in the window.

4) Time axes:
   - `tH2B = time(1 : end − Ws)`
   - `tB2H = time(Ws+1 : end − Ws)`

Toolbox note: Heart→Brain uses System Identification Toolbox (`iddata`, `arx`).

## Preparing inputs in MATLAB

- From ECG to IBI / t_IBI:
  - Detect R‑peaks (e.g., bandpass ECG ~5–25 Hz, `findpeaks`).
  - `t_R = sample_indices / Fs_raw;  IBI = diff(t_R);  t_IBI = t_R(1:end-1);`

- From EEG to EEG_comp (band power):
  - Choose a band (e.g., alpha = [8 13] Hz). For each channel `x`:
    1. Band‑limit (e.g., `bandpass(x, band, Fs_raw)`).
    2. Envelope power: `env2 = abs(hilbert(xb)).^2`.
    3. Smooth in time (e.g., `movmean(env2, round(2*Fs_raw))`).
    4. Interpolate/synchronize to the modeling grid `time` at Fs (e.g., 4 Hz):
       `EEG_comp(i,:) = interp1(t_raw, smooth_power, time, 'linear', 'extrap');`

- CSI, CVI on the same grid:
  - Provide scaled indices sampled at Fs and aligned to `time`.
  - Often derived from IBI dynamics (e.g., using your own function or
    `compute_CSI_CVI` if available).

- Choose Fs and time:
  - Define a uniformly sampled `time` at Fs covering your analysis interval.
  - Ensure `length(time) = T` equals `size(EEG_comp,2)` and lengths of CSI/CVI.

- Window length:
  - `wind = 15;  Ws = wind * Fs;`  Require `T > 2*Ws` for non‑empty B2H outputs.

## Minimal MATLAB example

```matlab
% Dummy shapes just to illustrate calling convention
Fs   = 4;      % modeling grid (Hz)
T    = 1000;   % time samples (ensure T > 2*wind*Fs)
wind = 15;     % seconds
time = (0:T-1)/Fs;

Nch = 2; 
EEG_comp = abs(randn(Nch,T));     % pretend band power
CSI = randn(1,T); 
CVI = randn(1,T);

% Fake IBI / t_IBI (strictly positive and increasing)
t_R = cumsum(0.8 + 0.1*rand(1,1200)); % seconds
IBI = diff(t_R);
t_IBI = t_R(1:end-1);

[CSI2B, CVI2B, B2CSI, B2CVI, tH2B, tB2H] = model_psv_sdg( ...
    EEG_comp, IBI, t_IBI, CSI, CVI, Fs, time, wind);
```

## Assumptions and constraints

- `time` strictly increasing and approximately uniform at 1/Fs seconds.
- `size(EEG_comp,2) = length(time) = length(CSI) = length(CVI) = T`.
- `t_IBI` strictly increasing; `IBI` strictly positive.
- Sufficient data: `T > 2 * (wind*Fs)`.
- No NaNs/Infs in the inputs used by the model.

## Interpreting outputs

- Heart→Brain (CSI2B/CVI2B): ARX B(2) coefficients over time — larger magnitude
  indicates stronger predictive influence from CSI/CVI to band power within the window.
- Brain→Heart (B2CSI/B2CVI): normalized Cs/Cp averages relative to local EEG power.


