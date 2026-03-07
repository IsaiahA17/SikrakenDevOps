#!/usr/bin/env bash
set -euo pipefail

JOB_QUEUE="${1:-${JOB_QUEUE:-sikraken-test-comp-job-queue}}"
SIKRAKEN_JOB_DEFINITION="${2:-${SIKRAKEN_JOB_DEFINITION:-sikraken-test-comp-batch-job-def}}"
TASK_COUNT="${3:-${TASK_COUNT:-5}}"
CATEGORY="${4:-${CATEGORY:-chris}}"
BUDGET="${5:-${BUDGET:-10}}"
MODE="${6:-${MODE:-release}}"
STACK_SIZE_GB="${7:-${STACK_SIZE_GB:-3072}}"
S3_BUCKET_NAME="${8:-${S3_BUCKET_NAME:-ecs-benchmarks-output}}"
REPORT_JOB_DEFINITION="${9:-${REPORT_JOB_DEFINITION:-generate-report}}"
TIMESTAMP=$(date -u +"%Y_%m_%d_%H_%M")

JOB_ID=$(aws batch submit-job \
  --job-name "sikraken-${CATEGORY}-${TIMESTAMP}" \
  --job-queue "$JOB_QUEUE" \
  --job-definition "$SIKRAKEN_JOB_DEFINITION" \
  --array-properties size="$TASK_COUNT" \
  --retry-strategy '{"attempts": 5}' \
  --container-overrides "environment=[
    {name=CATEGORY,value=$CATEGORY},
    {name=BUDGET,value=$BUDGET},
    {name=MODE,value=$MODE},
    {name=TIMESTAMP,value=$TIMESTAMP},
    {name=STACK_SIZE_GB,value=$STACK_SIZE_GB},
    {name=TASK_COUNT,value=$TASK_COUNT}
  ]" \
  --query 'jobId' \
  --output text
)

JOB_ID2=$(aws batch submit-job \
  --job-name "generate-report-${CATEGORY}-${TIMESTAMP}" \
  --job-queue "$JOB_QUEUE" \
  --job-definition "$REPORT_JOB_DEFINITION" \
  --depends-on "[{jobId: $JOB_ID}]" \
  --array-properties size="1" \
  --retry-strategy '{"attempts": 5}' \
  --container-overrides "environment=[
    {name=CATEGORY,value=$CATEGORY},
    {name=S3_BUCKET_NAME,value=$S3_BUCKET_NAME}
  ]" \
  --query 'jobId' \
  --output text
)

echo "$JOB_ID"
