#!/bin/bash
set -euo pipefail

category="$1"
cores="$2"
budget="$3"
mode="$4"
testcov_switch="$5"
stack_size="$6"

SIKRAKEN_DEVSPACE="/home/ubuntu/Sikraken/SikrakenDevSpace" 
SIKRAKEN_OUTPUT_PATH="/home/ubuntu/Sikraken/sikraken_output"
CATEGORY_END_LOCATION="/home/ubuntu/SikrakenDevSpace/categories/ECA" #Location where all ECA test runs will be stored to prevent them
PYTHON_SCRIPTS="/home/ubuntu/Sikraken/SikrakenDevOps/SikrakenPythonScripts"

echo "Running Sikraken test..." #Running test_category_sikraken
"$SIKRAKEN_DEVSPACE/bin/test_category_sikraken.sh" \ 
    "/home/ubuntu/Sikraken/sv-benchmarks/c" \
    "$category" "$cores" "$budget" "$mode" "$testcov_switch" "$stack_size"

#Function for finding the latest ECA folder
locate_latest_ECA_folder(){
	echo "Locating generated ECA run folder in SSM sandbox..."

	SSM_BASE="/var/snap/amazon-ssm-agent" #Starting path for ECA folder results as the ECA folders will be stored within the snap environment
	SSM_CATEGORIES="$SSM_BASE/*/SikrakenDevSpace/categories/ECA" #Using globbing to collect all folders matching the format (The * matches with anything and is used as IDs are generated within the file path by the snap environment when a new one is created)

	# Find the most recent timestamped folder using Regex and then sort and tail to get the most recent folder. The ".*/" will match with the file path found before.
	# mindepth 1 and maxdepth 1 ensures that only the children (The timestamped folders are processed) and -type d only matches directories
	FOUND_ECA_DIR=$(find $SSM_CATEGORIES -mindepth 1 -maxdepth 1 -type d \ 
	    -regextype posix-extended \
	    -regex ".*/[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}" \ 
	    | sort | tail -n1)

	if [[ -z "$FOUND_ECA_DIR" ]]; then
	    echo "ERROR: Could not find the timestamped ECA folder"
	    exit 1
	fi

	RUN_FOLDER=$(basename "$FOUND_ECA_DIR") #Folder for Python script to process .html report
	TARGET_BASE="$FOUND_ECA_DIR" 

	echo "Found timestamped ECA folder: $TARGET_BASE"
	echo "Run folder name: $RUN_FOLDER"

	# The Sikraken log file exists inside this folder
	LOG_FILE="$TARGET_BASE/sikraken.log"
	if [[ -f "$LOG_FILE" ]]; then
	    echo "Using log file inside the timestamp folder: $LOG_FILE"
	fi
}

locate_latest_ECA_folder

retrieve_latest_ECA_folder(){
	mkdir -p "$CATEGORY_END_LOCATION" #Creating new ECA folder if it doesn't exist and then moving the ECA folder created to this folder

	if [[ "$TARGET_BASE" != "$CATEGORY_END_LOCATION/$RUN_FOLDER" ]]; then
	    echo "Moving ECA folder to final location..."
	    sudo mv "$TARGET_BASE" "$CATEGORY_END_LOCATION/"
	fi

	sudo chown -R ubuntu:ubuntu "$CATEGORY_END_LOCATION/$RUN_FOLDER" #Using chown for ubuntu as it belongs to root otherwise

	TARGET_BASE="$CATEGORY_END_LOCATION/$RUN_FOLDER"
	}
retrieve_latest_ECA_folder

copy_i_files_to_corresponding_folders(){
	echo "Copying .i files..."
	for d in "$TARGET_BASE"/*/; do
	    name=$(basename "$d")
	    src_file="$SIKRAKEN_OUTPUT_PATH/$name/$name.i"
	    if [[ -f "$src_file" ]]; then
		cp "$src_file" "$d"
		echo "Copied $src_file → $d"
	    else
		echo "Missing: $src_file"
	    fi
	done
}
copy_i_files_to_corresponding_folders

echo "Processing $TARGET_BASE for S3..."
python3 "$PYTHON_SCRIPTS/filepath_to_url_processor.py" "$TARGET_BASE" --run_folder "$RUN_FOLDER"

upload_folder_to_S3(){
# Uploading ECA files excluding .i and .log to S3. 
echo "Syncing non-text files to S3..."
aws s3 sync "$TARGET_BASE" "s3://temp-bucket-sikraken/$RUN_FOLDER" \
  --exclude "*.i" \
  --exclude "*.log"

# Uploading ECA files including .i and .log to S3. The content-type is applied to all files being uploaded requiring seperate uploads. Changing the content type allows the files to be viewable in browser.
echo "Syncing .i files as text/plain..."
aws s3 sync "$TARGET_BASE" "s3://temp-bucket-sikraken/$RUN_FOLDER" \
  --exclude "*" \
  --include "*.i" \
  --include "*.log" \
  --content-type text/plain
}
upload_folder_to_S3

echo "Pipeline completed successfully!"
