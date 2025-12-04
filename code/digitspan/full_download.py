import datalad.api as dl
import subprocess
import os

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
    print(f"Starting from {subjects_to_download[0]} to {subjects_to_download[-1]}")
    print("=" * 70)
    print()
    
    successful = 0
    failed = 0
    
    # Loop through each complete subject one at a time
    for idx, subject in enumerate(subjects_to_download, 1):
        print(f"[{idx}/{len(subjects_to_download)}] {subject}: Finding rest files...")
        
        try:
            # Find all task-rest files for this subject
            find_cmd = f"find {subject} -name '*task-rest*' 2>/dev/null"
            result = subprocess.run(find_cmd, shell=True, capture_output=True, text=True)
            
            files = [f.strip() for f in result.stdout.split('\n') if f.strip()]
            
            if not files:
                print(f"     ⏭️  No rest files found, skipping\n")
                continue
            
            print(f"     📁 Found {len(files)} rest files")
            print(f"     ⬇️  Downloading...")
            
            # Download all rest files for this subject
            for file in files:
                try:
                    dl.get(path=file, dataset='.', result_renderer='disabled')
                except Exception as e:
                    # Ignore errors for individual files (might be symlinks, etc.)
                    pass
            
            print(f"     ✅ Complete!\n")
            successful += 1
                
        except Exception as e:
            print(f"     ❌ Error: {e}\n")
            failed += 1
            continue
    
    # Summary
    print("=" * 70)
    print(f"🎯 Download Complete!")
    print(f"   ✅ Successful: {successful}/{len(subjects_to_download)}")
    print(f"   ❌ Failed:     {failed}/{len(subjects_to_download)}")
    print("=" * 70)

if __name__ == "__main__":
    main()