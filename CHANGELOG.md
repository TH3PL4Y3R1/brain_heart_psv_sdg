# Changelog

All notable changes to this repository in this session.

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
