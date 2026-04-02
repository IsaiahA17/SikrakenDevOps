#!/bin/bash

s3_bucket="${1:-${S3_BUCKET_NAME:-ecs-benchmarks-output}}"
CATEGORY="${2:-${CATEGORY:-ECA}}"

find_latest_benchmark(){
    aws s3 cp s3://$s3_bucket/$CATEGORY/ category_results/$CATEGORY --recursive
    TIMESTAMP_DIR=$(find category_results/$CATEGORY -mindepth 1 -maxdepth 1 -type d -regextype posix-extended -regex ".*/[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}" | sort | tail -n1)
}
find_latest_benchmark()

combine_benchmark_files(){
    touch $TIMESTAMP_DIR/benchmark_files.txt
    cat $TIMESTAMP_DIR/benchmark_files/* > $TIMESTAMP_DIR/benchmark_files.txt
}
combine_benchmark_files()

generate_and_upload_reports(){
    /app/ReportScripts/create_category_test_run_table.sh "$TIMESTAMP_DIR"

    TIMESTAMP_NAME=$(basename "$TIMESTAMP_DIR")
    python3 /app/SikrakenPythonScripts/filepath_to_url_processor.py "$TIMESTAMP_DIR" --run_folder "$TIMESTAMP_NAME" --s3_bucket "$s3_bucket" --category "$CATEGORY"
    aws s3 cp "$TIMESTAMP_DIR/category_test_run_results.html" "s3://$s3_bucket/$CATEGORY/$TIMESTAMP_NAME/category_test_run_results.html" --content-type text/html

    /app/ReportScripts/view_category_compare.sh category_results/$CATEGORY
    python3 /app/SikrakenPythonScripts/container_results_summary_processor.py /app/category_results/$CATEGORY/results_summary.html
    aws s3 cp "/app/category_results/$CATEGORY/results_summary.html" "s3://$s3_bucket/$CATEGORY/results_summary.html" --content-type text/html
}
generate_and_upload_reports()