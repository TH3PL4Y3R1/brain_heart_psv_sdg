# Brain–Heart Interplay via Poincaré Sympatho‑Vagal SDG (PSV‑SDG)

This repository contains MATLAB code to compute time‑varying brain–heart coupling using the Poincaré Sympatho‑Vagal Synthetic Data Generation (PSV‑SDG) model. The method estimates directional interactions between heart‑rate variability (HRV) indices and band‑limited EEG power.

Primary reference (included in this repo):

- Diego Candia‑Rivera (2023). Modeling brain‑heart interactions from Poincaré plot‑derived measures of sympathetic and vagal activity. MethodsX. PDF: `candia-rivera(2023).pdf`  |  Journal page: <https://www.sciencedirect.com/science/article/pii/S2215016123001176>

## Repository structure

- `code/`
  - Actively documented version of the pipeline with extensive inline comments.
  - See `code/README.md` for detailed usage, requirements, and a minimal example.
- `original_code/`
  - Upstream author’s original MATLAB functions and their `readme.md` (license and citation notes).
- `candia-rivera(2023).pdf`
  - The MethodsX article that describes the model and its rationale.

## What the code does (high level)

1) Derives inter‑beat intervals (IBI) from detected heartbeat times and computes time‑varying Poincaré descriptors (SD1, SD2).
2) Builds HRV indices inspired by sympathetic and vagal activity (CSI, CVI) over sliding windows and resamples them uniformly.
3) Computes time‑resolved EEG power using FieldTrip (time‑frequency analysis), then integrates within canonical bands (delta, theta, alpha, beta, gamma).
4) Estimates directional couplings (heart→brain and brain→heart) between CSI/CVI and band‑limited EEG power using ARX models and normalized indices (SDG model).

## Requirements

- MATLAB (R2019b or later recommended)
- System Identification Toolbox (for `iddata`, `arx`)
- FieldTrip toolbox (for `ft_freqanalysis`, `ft_selectdata`)
- Parallel Computing Toolbox (optional; speeds up channel‑wise fitting via `parfor`)
- A helper function `clean_artif` (optional). If not available, comment its call in `code/model_psv_sdg.m` or provide your own artifact cleaning routine.

## Quick start

For full instructions and a runnable example, see `code/README.md`.

Minimal outline:

1) Prepare a FieldTrip raw structure `data_eeg` with:
   - `data_eeg.trial{1}` — matrix (channels × time)
   - `data_eeg.time{1}` — vector (1 × time) in seconds
2) Provide heartbeat peak indices `pks_indx` that index into `data_eeg.time{1}` (e.g., R‑peaks).
3) Add FieldTrip and this repo’s `code/` folder to your MATLAB path and run:
   - `struct_sdg = compute_psv_sdg(data_eeg, pks_indx);`

The result `struct_sdg` contains CSI/CVI series, band‑limited EEG power, and directional coupling estimates per band.

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
