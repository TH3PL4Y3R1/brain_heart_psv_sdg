# Changelog

All notable changes to this repository in this session.

## 2025-11-09

- Notebooks & Analysis
  - Added `code/python/brain_heart_coupling_study.ipynb` providing an end‑to‑end, commented exploratory pipeline (synthetic data → sliding Poincaré → directional coupling plots).
  - Fixed sliding‑window CSI/CVI implementation (previous draft could stall); now uses a clear 1 s stride loop with correct SD1/SD2 formulas.
  - Corrected time‑base alignment and interpolation for coupling model to eliminate length mismatch errors.
  - Added plots for Heart→Brain ARX coefficients (CSI/CVI) and Brain→Heart normalized Cs/Cp indices.
- MATLAB Enhancements
  - Added `code/matlab/synthetic_test_brain_heart.m` to generate synthetic RR intervals, compute CSI/CVI, synthesize EEG band power, and invoke `model_psv_sdg.m` for quick verification.
- Coupling Model Adjustments (Python translation)
  - Implemented ARX b‑coefficient least‑squares estimator (`arx_b_coefficient`) inside the study notebook.
  - Added `compute_csi_cvi` corrected function for robust sliding‑window HRV index generation.
- Environment & Compatibility
  - Documented minimal dependency approach (preferring custom HRV computations over heavy external libraries).
  - Added Python compatibility shim (sitecustomize pattern) guidance for legacy `collections` ABC imports under Python 3.12.
- Documentation
  - Expanded inline comments across new notebook cells for mathematical rationale and processing steps.
  - Listed next steps (surrogate significance testing, real data integration, packaging) inside the study notebook.
- Quality & Stability
  - Resolved interpolation length mismatch that previously raised a ValueError in coupling pipeline.
  - Ensured no extrapolation beyond overlapping time ranges when resampling CSI/CVI and Cs/Cp series.

## 2025-11-02

- Docs
  - Clarified that FieldTrip is optional and only needed for the convenience pipeline.
  - Added MATLAB-first inputs/usage guide for `model_psv_sdg.m` (see `code/python/model_psv_sdg_inputs.md`).
  - Added a Python-oriented inputs interface stub (`code/python/model_psv_sdg_interface.py`) to document shapes and validation for a future port.
- Repository structure
  - Kept `original_code/` intact (author’s originals, unchanged).
  - Added `code/matlab/` with commented equivalents and helper stubs.
  - Added `code/python/` for documentation and future translation work.
- MATLAB files
  - Commented and documented: `code/matlab/compute_CSI_CVI.m`, `code/matlab/model_psv_sdg.m`, `code/matlab/compute_psv_sdg.m` (behavior unchanged).
  - Added `code/matlab/clean_artif.m` as a no‑op placeholder to avoid undefined function errors.
  - Added `sample.m` runner to load a BIDS EEGLAB `.set`, auto‑detect ECG channel, compute IBI→CSI/CVI→band power (without FieldTrip), and run the model.
  - Enhanced `sample.m` to:
    - auto‑discover `.set` files under `data/` (or via `BRAIN_HEART_DATA_DIR`),
    - derive the accompanying `channels.tsv`,
    - initialize EEGLAB if available.
- Readmes
  - Updated top‑level and `code/README.md` to reflect the new structure and usage, and to link to the MATLAB inputs guide.
