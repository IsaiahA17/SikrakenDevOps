#!/usr/bin/env bash
set -euo pipefail

JOB_QUEUE="${1:-${JOB_QUEUE:-sikraken-test-comp-job-queue}}"
JOB_DEFINITION="${2:-${JOB_DEFINITION:-sikraken-test-comp-batch-job-def}}"
TASK_COUNT="${3:-${TASK_COUNT:-5}}"
CATEGORY="${4:-${CATEGORY:-chris}}"
BUDGET="${5:-${BUDGET:-10}}"
MODE="${6:-${MODE:-release}}"
STACK_SIZE_GB="${7:-${STACK_SIZE_GB:-3072}}"
TIMESTAMP=$(date -u +"%Y_%m_%d_%H_%M")

JOB_ID=$(aws batch submit-job \
  --job-name "sikraken-${CATEGORY}-${TIMESTAMP}" \
  --job-queue "$JOB_QUEUE" \
  --job-definition "$JOB_DEFINITION" \
  --array-properties size="$TASK_COUNT" \
  --retry-strategy '{
    "attempts": 5,
    "evaluateOnExit": [
      {
        "onStatusReason": "Host EC2*terminated*",
        "action": "RETRY"
      },
      {
        "onReason": "*",
        "action": "EXIT"
      }
    ]
  }' \
  --container-overrides "environment=[
    {name=CATEGORY,value=$CATEGORY},
    {name=BUDGET,value=$BUDGET},
    {name=MODE,value=$MODE},
    {name=TIMESTAMP,value=$TIMESTAMP},
    {name=STACK_SIZE_GB,value=$STACK_SIZE_GB}
  ]" \
  --query 'jobId' \
  --output text
)

echo "$JOB_ID"