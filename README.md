# Brain–Heart Interplay via Poincaré Sympatho‑Vagal SDG (PSV‑SDG)

This repository contains MATLAB code to compute time‑varying brain–heart coupling using the Poincaré Sympatho‑Vagal Synthetic Data Generation (PSV‑SDG) model. The method estimates directional interactions between heart‑rate variability (HRV) indices and band‑limited EEG power.

Primary reference (included in this repo):

- Diego Candia‑Rivera (2023). Modeling brain‑heart interactions from Poincaré plot‑derived measures of sympathetic and vagal activity. MethodsX. PDF: `candia-rivera(2023).pdf`  |  Journal page: <https://www.sciencedirect.com/science/article/pii/S2215016123001176>

## Repository structure

- `code/`
  - `matlab/` — actively documented MATLAB implementation.
    - Core model files that do not require FieldTrip: `model_psv_sdg.m`, `compute_CSI_CVI.m`
    - Optional convenience pipeline that uses FieldTrip for EEG time–frequency power: `compute_psv_sdg.m`
  - `python/` — documentation and interface stubs for a future Python port (no algorithmic code yet).
  - See `code/README.md` for detailed usage and examples.
- `original_code/`
  - Upstream author’s original MATLAB functions and their `readme.md` (license and citation notes). These original functions operate on plain MATLAB arrays and do not depend on FieldTrip.
- `candia-rivera(2023).pdf`
  - The MethodsX article that describes the model and its rationale.
- (Optional) `data/`
  - Place large raw EEG/ECG datasets here locally. This folder is intentionally **not tracked**; add `data/` to `.gitignore` to avoid committing sensitive or heavy files. See "Data folder & ignoring" section below.

## What the code does (high level)

1) Derives inter‑beat intervals (IBI) from detected heartbeat times and computes time‑varying Poincaré descriptors (SD1, SD2).
2) Builds HRV indices inspired by sympathetic and vagal activity (CSI, CVI) over sliding windows and resamples them uniformly.
3) Computes time‑resolved EEG power using FieldTrip (time‑frequency analysis), then integrates within canonical bands (delta, theta, alpha, beta, gamma). Alternatively, you can provide your own precomputed band‑power as `EEG_comp`.
4) Estimates directional couplings (heart→brain and brain→heart) between CSI/CVI and band‑limited EEG power using ARX models and normalized indices (SDG model).

## Requirements

- MATLAB (R2019b or later recommended)
- System Identification Toolbox (for `iddata`, `arx`) — required by the core model
- Parallel Computing Toolbox — optional; speeds up channel‑wise fitting via `parfor`
- FieldTrip toolbox — optional; only needed if you use the convenience pipeline that computes EEG band power inside MATLAB (`code/matlab/compute_psv_sdg.m`). The core model (`model_psv_sdg.m`) and HRV index builder (`compute_CSI_CVI.m`) work with regular MATLAB arrays and do not require FieldTrip.
- A helper function `clean_artif` (optional). If not available, comment its call in `code/matlab/model_psv_sdg.m` or provide your own artifact cleaning routine.

## Quick start

For detailed instructions and examples, see `code/README.md`. Two common entry points:

Option A — Use the core model without FieldTrip (you provide arrays):

- Inputs needed as plain MATLAB arrays: EEG band‑power matrix (channels × time), IBI and their timestamps, CSI and CVI time series, sampling rate and time vector.
- Call `code/matlab/model_psv_sdg.m` directly.
- See the MATLAB‑oriented inputs guide: `code/python/model_psv_sdg_inputs.md` (MATLAB terms, shapes, units, example call).

Option B — Use the FieldTrip‑based convenience pipeline:

- If your EEG data are in a FieldTrip raw structure and you prefer MATLAB to compute band‑limited power, call `code/matlab/compute_psv_sdg.m` (requires FieldTrip). It will compute band power and run the model per band.

### Quick run with `sample.m` (no FieldTrip)

There is a minimal runner `sample.m` that demonstrates loading a BIDS EEGLAB `.set`, finding the ECG channel, computing IBI → CSI/CVI → band‑power (alpha) and running the model.

Data location options:

- Place your dataset under `data/` anywhere beneath the repo root, or
- Set environment variable `BRAIN_HEART_DATA_DIR` to your BIDS root.

Then, in MATLAB:

```matlab
addpath(fullfile(pwd,'code','matlab'));
% Optional: add EEGLAB to path; sample.m will try to initialize it
% addpath('/path/to/eeglab'); eeglab('nogui');

sample  % runs end-to-end and plots heart→brain couplings for ch1
```

## Data folder & ignoring

Create a local `data/` directory for raw or intermediate files (BIDS datasets, exported band power, large MAT files). To keep the repository lightweight and prevent accidental commits of sensitive data, ensure `data/` is ignored by Git. If a `.gitignore` does not yet exist, create one at the repo root containing:

```gitignore
data/
```

Rationale:

- Avoid pushing large binaries that bloat history.
- Protect potentially identifiable physiological recordings.
- Keep version control focused on source code and lightweight metadata.

You can set `BRAIN_HEART_DATA_DIR` to point elsewhere if you prefer not to use `data/`.

## Notes on CSI/CVI

- CSI/CVI are derived from Poincaré plot measures (SD2, SD1). Classic definitions in the literature often use `CVI = SD1 * SD2` and `CSI = SD2 / SD1`.
- In this implementation (see `code/compute_CSI_CVI.m`), SD1 and SD2 are re‑centered to global baselines and scaled for numerical stability in ARX modeling. The code comments document both approaches.

## Citing

If you use this code in research or a derived software package, please cite:

- Diego Candia‑Rivera. Modeling brain‑heart interactions from Poincaré plot‑derived measures of sympathetic and vagal activity. MethodsX (2023). <https://www.sciencedirect.com/science/article/pii/S2215016123001176>

Also see `original_code/readme.md` for the author’s licensing and citation notice.

## License

- The upstream `original_code/` carries a GNU General Public License notice in its `readme.md`. If you distribute or modify derivatives, ensure your usage complies with that license and any institutional or project requirements.
- If you plan to add a specific license for the adapted code in `code/`, include a top‑level `LICENSE` file accordingly. If unsure, default to the original license terms or consult your institution.

## Support

- For method questions, consult the MethodsX paper (`candia-rivera(2023).pdf`).
- For code usage in this repo, start with `code/README.md`. If you need help wiring in your data or plotting results, open an issue or share an example dataset structure and I can help script it.
