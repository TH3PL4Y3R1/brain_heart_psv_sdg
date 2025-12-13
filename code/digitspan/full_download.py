import datalad.api as dl
import pathlib

# Subjects to skip entirely
excluded_subjects = {
    'sub-013', 'sub-014', 'sub-015', 'sub-016', 'sub-017', 'sub-018',
    'sub-019', 'sub-020', 'sub-021', 'sub-022', 'sub-023', 'sub-024',
    'sub-025', 'sub-026', 'sub-027', 'sub-028', 'sub-029', 'sub-030',
    'sub-031', 'sub-037', 'sub-066', 'sub-094'
}

def get_subjects(dataset_root: pathlib.Path):
    subs = [p.name for p in dataset_root.glob("sub-*") if p.is_dir()]
    return sorted(s for s in subs if s not in excluded_subjects)

def main(dataset_dir="data/ds003838"):
    ds_path = pathlib.Path(dataset_dir).resolve()
    subjects = get_subjects(ds_path)

    print(f"Dataset: {ds_path}")
    print(f"Eligible subjects: {len(subjects)}")
    print("=" * 70)

    successes, failures = 0, 0

    for idx, sub in enumerate(subjects, 1):
        ecg_dir = ds_path / sub / "ecg"
        print(f"[{idx}/{len(subjects)}] {sub}")

        if not ecg_dir.exists():
            print("   ⚠️  No ECG directory, skipping\n")
            failures += 1
            continue

        try:
            dl.get(path=str(ecg_dir), dataset=str(ds_path), recursive=True, result_renderer="disabled")
            print("   ✅ Downloaded ECG\n")
            successes += 1
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
            failures += 1

    print("=" * 70)
    print(f"Finished. Success: {successes} | Failed/Skipped: {failures}")

if __name__ == "__main__":
    main()
