#!/usr/bin/env bash
set -euo pipefail

JOB_QUEUE="${1:-${JOB_QUEUE:-sikraken-test-comp-job-queue}}"
SIKRAKEN_JOB_DEFINITION="${2:-${SIKRAKEN_JOB_DEFINITION:-sikraken-test-comp-batch-job-def}}"
JOB_COUNT="${3:-${JOB_COUNT:-5}}"
CATEGORY="${4:-${CATEGORY:-chris}}"
BUDGET="${5:-${BUDGET:-10}}"
MODE="${6:-${MODE:-release}}"
STACK_SIZE_GB="${7:-${STACK_SIZE_GB:-3}}"
S3_BUCKET_NAME="${8:-${S3_BUCKET_NAME:-ecs-benchmarks-output}}"
TESTCOMP_S3_BUCKET_NAME="${9:-${TESTCOMP_S3_BUCKET_NAME:-testcomp-benchmarks}}"
REPORT_JOB_DEFINITION="${10:-${REPORT_JOB_DEFINITION:-generate-report}}"
TIMESTAMP=$(date -u +"%Y_%m_%d_%H_%M")

JOB_ID=$(aws batch submit-job \
  --job-name "sikraken-${CATEGORY}-${TIMESTAMP}" \
  --job-queue "$JOB_QUEUE" \
  --job-definition "$SIKRAKEN_JOB_DEFINITION" \
  --array-properties size="$JOB_COUNT" \
  --retry-strategy '{"attempts": 5}' \
  --container-overrides "resourceRequirements=[
    {type=MEMORY,value=$(($STACK_SIZE_GB * 1024))}
  ],environment=[
    {name=CATEGORY,value=$CATEGORY},
    {name=BUDGET,value=$BUDGET},
    {name=MODE,value=$MODE},
    {name=TIMESTAMP,value=$TIMESTAMP},
    {name=STACK_SIZE_GB,value=$STACK_SIZE_GB},
    {name=JOB_COUNT,value=$JOB_COUNT},
    {name=S3_BUCKET_NAME,value=$S3_BUCKET_NAME},
    {name=TESTCOMP_S3_BUCKET_NAME,value=$TESTCOMP_S3_BUCKET_NAME}
  ]" \
  --query 'jobId' \
  --output text
)

JOB_ID2=$(aws batch submit-job \
  --job-name "generate-report-${CATEGORY}-${TIMESTAMP}" \
  --job-queue "$JOB_QUEUE" \
  --job-definition "$REPORT_JOB_DEFINITION" \
  --depends-on "[{\"jobId\": \"$JOB_ID\", \"type\": \"SEQUENTIAL\"}]" \
  --retry-strategy '{"attempts": 5}' \
  --container-overrides "environment=[
    {name=CATEGORY,value=$CATEGORY},
    {name=S3_BUCKET_NAME,value=$S3_BUCKET_NAME}
  ]" \
  --query 'jobId' \
  --output text
)

echo "$JOB_ID2"
