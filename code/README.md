# SDG Brain–Heart Coupling: Code Usage

This folder contains implementations to compute time‑varying brain–heart coupling using a Sympathovagal Dynamics (SDG) model based on Poincaré‑derived HRV indices and band‑limited EEG power.

Subfolders:

- `matlab/` — MATLAB implementation
  - Core model files that work on plain MATLAB arrays (no FieldTrip required):
    - `model_psv_sdg.m`, `compute_CSI_CVI.m`
  - Optional FieldTrip‑based convenience pipeline:
    - `compute_psv_sdg.m` (uses FieldTrip to compute EEG power, then runs the model)
- `python/` — documentation and interface stubs for a future Python port (no algorithmic code yet)

The code is derived from the article in the repository’s main folder. Please refer to that article for the physiological rationale, definitions of CSI/CVI, and interpretation guidance.

## Files (MATLAB)

- `matlab/compute_CSI_CVI.m` — Builds time‑varying CSI and CVI from non‑interpolated inter‑beat intervals (IBI) using sliding Poincaré descriptors (SD1, SD2) and returns uniformly sampled series.
- `matlab/compute_psv_sdg.m` — End‑to‑end pipeline: constructs IBI from detected heartbeats, computes CSI/CVI, extracts band‑limited EEG power via FieldTrip, and runs the SDG coupling model per band. Requires FieldTrip.
- `matlab/model_psv_sdg.m` — Core model that estimates directional couplings between EEG band power and CSI/CVI in both directions (heart→brain and brain→heart) using ARX modeling and normalized indices. No FieldTrip required.

## Requirements

- MATLAB (R2019b or later recommended)
- System Identification Toolbox (for `iddata`, `arx`) — required by the core model
- Parallel Computing Toolbox — optional; accelerates channel‑wise loops via `parfor`
- FieldTrip toolbox — optional; only required if you use `matlab/compute_psv_sdg.m` to compute EEG power inside MATLAB
- A helper function `clean_artif` (optional). If you don’t have it, either provide your own artifact‑cleaning routine or comment out the corresponding line in `matlab/model_psv_sdg.m`.

## Inputs and data format

Two ways to use the code:

Core model (no FieldTrip):

- EEG_comp — matrix (channels × time) of band‑limited EEG power you computed elsewhere
- IBI — vector of non‑interpolated inter‑beat intervals (seconds)
- t_IBI — timestamps for IBI (seconds)
- CSI, CVI — time‑aligned HRV indices (scaled)
- Fs — sampling rate of EEG_comp/time (Hz)
- time — time vector for EEG_comp (seconds)
- wind — window length in seconds (e.g., 15)

Convenience pipeline (with FieldTrip):

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
% Option A: Core model without FieldTrip (you computed band power elsewhere)
addpath('/absolute/path/to/repo/code/matlab');

% Provide your arrays: EEG_comp, IBI, t_IBI, CSI, CVI, Fs, time, wind
[CSI2B, CVI2B, B2CSI, B2CVI, tH2B, tB2H] = model_psv_sdg(EEG_comp, IBI, t_IBI, CSI, CVI, Fs, time, wind);

% Option B: FieldTrip‑based pipeline
addpath('/path/to/fieldtrip'); ft_defaults;
addpath('/absolute/path/to/repo/code/matlab');

% data_eeg: FieldTrip raw structure with .trial{1} and .time{1}
% pks_indx: indices into data_eeg.time{1}
struct_sdg = compute_psv_sdg(data_eeg, pks_indx);

% Example: inspect delta‑band couplings (first channel)
figure;
plot(struct_sdg.time(1:end-15), struct_sdg.bhi_CSI_delta(1,:)); hold on;
plot(struct_sdg.time(1:end-15), struct_sdg.bhi_CVI_delta(1,:));
legend('CSI→delta','CVI→delta'); xlabel('Time (s)'); ylabel('Coupling');
```

Notes:

- If you see “Undefined function or variable 'clean_artif'”, comment out the corresponding line in `model_psv_sdg.m` or supply your own artifact cleaning.
- If you see “Undefined function 'ft_freqanalysis'”, you’re using the convenience pipeline — make sure FieldTrip is installed and `ft_defaults` has been run.
- If you lack Parallel Computing Toolbox, replace `parfor` with `for` in `model_psv_sdg.m`.

## Key parameters

- Window for CSI/CVI: `wind = 15` seconds (in `compute_psv_sdg.m` → `compute_CSI_CVI`)
- Time‑frequency analysis: 2‑s windows, 50% overlap, 0–45 Hz, 0.5‑Hz steps
- SDG model time base: typically `Fs = 4` Hz for the model grid in `sample.m`; the FieldTrip pipeline may align as needed.

## Sample runner (no FieldTrip, BIDS + EEGLAB)

`sample.m` demonstrates a minimal end‑to‑end run using an EEGLAB `.set` exported from BIDS:

- Auto‑discovers `.set` files under `data/` or uses the `BRAIN_HEART_DATA_DIR` environment variable as a BIDS root.
- Derives the matching `channels.tsv` to locate the ECG channel; falls back to common labels (ECG/EKG/...).
- Computes IBI → CSI/CVI → band‑power (alpha) → runs `model_psv_sdg` and plots heart→brain coupling for channel 1.

Run from the repo root in MATLAB:

```matlab
addpath(fullfile(pwd,'code','matlab'));
% Optional: add EEGLAB to path if not already
% addpath('/path/to/eeglab'); eeglab('nogui');

sample
```

## Outputs (selected fields of `struct_sdg`)

- `time` — common analysis time vector
- `CSI`, `CVI` — time‑varying indices (scaled) derived from Poincaré plot
- `freq_delta/theta/alpha/beta/gamma` — band‑limited EEG power time series (FieldTrip‑style structures with `trial{1}` = channels × time)
- `bhi_CSI_*`, `bhi_CVI_*` — heart→brain couplings per band
- `bhi_*_CSI`, `bhi_*_CVI` — brain→heart couplings per band

## Reference

Please consult the article in the repository’s main folder for the theoretical background, parameter choices, and interpretation of CSI/CVI and SDG couplings.
