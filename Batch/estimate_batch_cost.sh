#!/usr/bin/env bash
set -euo pipefail

PARENT_JOB_ID="$1"
REGION="eu-west-1"

echo "Calculating AWS Batch cost for parent job: $PARENT_JOB_ID"

JOB_IDS=$(aws batch list-jobs \
  --array-job-id "$PARENT_JOB_ID" \
  --query 'jobSummaryList[*].jobId' \
  --output text \
  --region "$REGION")

TOTAL_COST=0

for JOB_ID in $JOB_IDS; do
  DETAILS=$(aws batch describe-jobs --jobs "$JOB_ID" --query 'jobs[0].[container.instanceType, startedAt, stoppedAt, container.vcpus, container.memory]' --output text --region "$REGION")
  INSTANCE_TYPE=$(echo "$DETAILS" | awk '{print $1}')
  START_TS=$(echo "$DETAILS" | awk '{print $2}')
  STOP_TS=$(echo "$DETAILS" | awk '{print $3}')
  VCPUS=$(echo "$DETAILS" | awk '{print $4}')

  DURATION_SEC=$(( (STOP_TS - START_TS)/1000 ))  

  SPOT_PRICE=$(aws ec2 describe-spot-price-history \
    --instance-types "$INSTANCE_TYPE" \
    --product-description "Linux/UNIX" \
    --start-time $(date -d @"$((START_TS/1000))" --utc +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -d @"$((STOP_TS/1000))" --utc +%Y-%m-%dT%H:%M:%S) \
    --query 'SpotPriceHistory[0].SpotPrice' \
    --output text \
    --region "$REGION")

  COST=$(echo "$SPOT_PRICE * $DURATION_SEC / 3600" | bc -l)
  TOTAL_COST=$(echo "$TOTAL_COST + $COST" | bc -l)
done

echo "Estimated total cost for parent job $PARENT_JOB_ID: €$TOTAL_COST"