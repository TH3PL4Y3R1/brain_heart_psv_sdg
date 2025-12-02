import datalad.api as dl

def get_complete_subjects():
    # 1. Define the full range of subjects found in the repo (13 to 98)
    all_ids = set(range(13, 99))

    # 2. Define Exclusion Lists (based on dataset description)
    # "sub-013...sub-031, sub-037, sub-066 have no EEG data"
    missing_eeg = set(range(13, 32)) | {37, 66}
    
    # "sub-017, sub-037, sub-066 have no ECG and PPG data"
    missing_ecg = {17, 37, 66}
    
    # "sub-017, sub-094 have no pupillometry data"
    missing_pupil = {17, 94}

    # 3. Combine all exclusions
    excluded_ids = missing_eeg | missing_ecg | missing_pupil

    # 4. Filter and format the valid subjects
    valid_ids = sorted(list(all_ids - excluded_ids))
    formatted_subs = [f"sub-{x:03d}" for x in valid_ids]
    
    return formatted_subs

def main():
    subjects_to_download = get_complete_subjects()
    
    print(f"Found {len(subjects_to_download)} complete subjects.")
    print(f"Downloading: {subjects_to_download}")
    
    # 5. Execute DataLad Get
    # dataset='.' assumes you run this script from inside the dataset folder
    dl.get(path=subjects_to_download, dataset='.', recursive=True)
    
    print("Download complete.")

if __name__ == "__main__":
    main()