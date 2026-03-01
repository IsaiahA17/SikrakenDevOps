#!/usr/bin/env bash
set -euo pipefail

JOB_QUEUE="${1:-${JOB_QUEUE:-sikraken-test-comp-job-queue}}"
JOB_DEFINITION="${2:-${JOB_DEFINITION:-sikraken-test-comp-batch-job-def}}"
TASK_COUNT="${3:-${TASK_COUNT:-5}}"
CATEGORY="${4:-${CATEGORY:-chris}}"
BUDGET="${5:-${BUDGET:-10}}"
MODE="${6:-${MODE:-release}}"
TIMESTAMP=$(date -u +"%Y_%m_%d_%H_%M")

echo "Submitting AWS Batch array job..."
echo "Queue: $JOB_QUEUE"
echo "Definition: $JOB_DEFINITION"
echo "Array size: $TASK_COUNT"

OUT=$(aws batch submit-job \
  --job-name "sikraken-${CATEGORY}-${TIMESTAMP}" \
  --job-queue "$JOB_QUEUE" \
  --job-definition "$JOB_DEFINITION" \
  --array-properties size="$TASK_COUNT" \
  --container-overrides "environment=[
    {name=CATEGORY,value=$CATEGORY},
    {name=BUDGET,value=$BUDGET},
    {name=MODE,value=$MODE},
    {name=TIMESTAMP,value=$TIMESTAMP}
  ]"
)

JOB_ID=$(echo "$OUT" | jq -r '.jobId')

if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
  echo "Job submission failed"
  echo "$OUT"
  exit 1
fi

echo "Job submitted successfully"
echo "JOB_ID=$JOB_ID"