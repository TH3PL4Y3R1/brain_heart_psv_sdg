# SDG Brain–Heart Coupling: Code Usage

This folder contains the MATLAB implementation to compute time‑varying brain–heart coupling using a Sympathovagal Dynamics (SDG) model based on Poincaré‑derived HRV indices and band‑limited EEG power.

The code is derived from the article located in the repository’s main folder. Please refer to that article for the physiological rationale, definitions of CSI/CVI, and interpretation guidance.

## Files

- `compute_CSI_CVI.m` — Builds time‑varying CSI and CVI from non‑interpolated inter‑beat intervals (IBI) using sliding Poincaré descriptors (SD1, SD2) and returns uniformly sampled series.
- `compute_psv_sdg.m` — End‑to‑end pipeline: constructs IBI from detected heartbeats, computes CSI/CVI, extracts band‑limited EEG power via FieldTrip, and runs the SDG coupling model per band.
- `model_psv_sdg.m` — Core model that estimates directional couplings between EEG band power and CSI/CVI in both directions (heart→brain and brain→heart) using ARX modeling and normalized indices.

## Requirements

- MATLAB (R2019b or later recommended)
- System Identification Toolbox (for `iddata`, `arx`)
- FieldTrip toolbox (for `ft_freqanalysis`, `ft_selectdata`)
- Parallel Computing Toolbox (optional; accelerates channel‑wise loops via `parfor`)
- A helper function `clean_artif` (optional). If you don’t have it, either provide your own artifact‑cleaning routine or comment out the corresponding line in `model_psv_sdg.m`.

## Inputs and data format

- EEG data: a FieldTrip raw data structure, minimally containing
  - `data_eeg.trial{1}` — matrix (channels × time)
  - `data_eeg.time{1}` — vector (1 × time) in seconds
- Heartbeat detections: indices of peaks (e.g., R‑peaks) into `data_eeg.time{1}`. From these, the code derives
  - `t_heartbeats = data_eeg.time{1}(pks_indx)`
  - `IBI = diff(t_heartbeats)` and `t_IBI` aligned accordingly

## What the pipeline does

1) Compute time‑varying HRV indices
   - `compute_CSI_CVI` slides a 15‑second window over RR (IBI) and computes Poincaré SD1/SD2.
   - It recenters them to the global baseline and scales them for numerical stability; outputs are sampled uniformly at 4 Hz.
   - Notes: classic definitions sometimes use `CVI = SD1*SD2`, `CSI = SD2/SD1`. The current implementation scales SD1/SD2 by 10 for stability in the ARX model; see comments in the file.

2) Compute band‑limited EEG power
   - With FieldTrip’s `ft_freqanalysis` (method `mtmconvol`, Hanning taper, 2‑s windows with 50% overlap), obtain time‑resolved power from 0–45 Hz in 0.5‑Hz steps.
   - Integrate power within canonical bands using trapezoidal rule:
     - delta (1–4 Hz), theta (4–8 Hz), alpha (8–12 Hz), beta (12–30 Hz), gamma (30–45 Hz).

3) Estimate directional couplings (SDG model)
   - `model_psv_sdg` aligns EEG band power and CSI/CVI on a common time support, computes intermediate indices (Cs, Cp) from Poincaré‑based HRV model, and runs channel‑wise ARX fits.
   - Outputs include heart→brain couplings (`CSI2B`, `CVI2B`) and brain→heart couplings (`B2CSI`, `B2CVI`) with their corresponding time vectors.

## How to run (minimal example)

```matlab
% Add FieldTrip and this code folder to your MATLAB path
addpath('/path/to/fieldtrip'); ft_defaults;
addpath('/home/martin/RESEARCH/thesis/brain_heart_psv_sdg/code');

% data_eeg: FieldTrip raw structure with .trial{1} and .time{1}
% pks_indx: indices into data_eeg.time{1} for detected heartbeats (e.g., R‑peaks)

struct_sdg = compute_psv_sdg(data_eeg, pks_indx);

% Example: inspect delta‑band couplings (first channel)
figure;
plot(struct_sdg.time(1:end-15), struct_sdg.bhi_CSI_delta(1,:)); hold on;
plot(struct_sdg.time(1:end-15), struct_sdg.bhi_CVI_delta(1,:));
legend('CSI→delta','CVI→delta'); xlabel('Time (s)'); ylabel('Coupling');
```

Notes:
- If you see “Undefined function or variable 'clean_artif'”, comment out the corresponding line in `model_psv_sdg.m` or supply your own artifact cleaning.
- If you see “Undefined function 'ft_freqanalysis'”, make sure FieldTrip is installed and `ft_defaults` has been run.
- If you lack Parallel Computing Toolbox, replace `parfor` with `for` in `model_psv_sdg.m`.

## Key parameters

- Window for CSI/CVI: `wind = 15` seconds (in `compute_psv_sdg.m` → `compute_CSI_CVI`)
- Time‑frequency analysis: 2‑s windows, 50% overlap, 0–45 Hz, 0.5‑Hz steps
- SDG model time base: `Fs = 1` Hz resampling for alignment

## Outputs (selected fields of `struct_sdg`)

- `time` — common analysis time vector
- `CSI`, `CVI` — time‑varying indices (scaled) derived from Poincaré plot
- `freq_delta/theta/alpha/beta/gamma` — band‑limited EEG power time series (FieldTrip‑style structures with `trial{1}` = channels × time)
- `bhi_CSI_*`, `bhi_CVI_*` — heart→brain couplings per band
- `bhi_*_CSI`, `bhi_*_CVI` — brain→heart couplings per band

## Reference

Please consult the article in the repository’s main folder for the theoretical background, parameter choices, and interpretation of CSI/CVI and SDG couplings.
