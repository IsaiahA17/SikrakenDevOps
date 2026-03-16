#!/usr/bin/env bash
set -euo pipefail

PARENT_JOB_ID="$1"
REGION="eu-west-1"

echo "Fetching instance info for parent job: $PARENT_JOB_ID"

ARRAY_SIZE=$(aws batch describe-jobs \
  --jobs "$PARENT_JOB_ID" \
  --query 'jobs[0].arrayProperties.size' \
  --output text \
  --region "$REGION")

echo "Array size: $ARRAY_SIZE"
echo ""
printf "%-10s %-20s %-15s %-10s %-10s\n" "INDEX" "INSTANCE_TYPE" "AZ" "SPOT_PRICE" "DURATION"
echo "----------------------------------------------------------------------"

JOB_QUEUE=$(aws batch describe-jobs \
  --jobs "$PARENT_JOB_ID" \
  --query 'jobs[0].jobQueue' \
  --output text \
  --region "$REGION")

COMPUTE_ENV=$(aws batch describe-job-queues \
  --job-queues "$JOB_QUEUE" \
  --query 'jobQueues[0].computeEnvironmentOrder[0].computeEnvironment' \
  --output text \
  --region "$REGION")

ECS_CLUSTER=$(aws batch describe-compute-environments \
  --compute-environments "$COMPUTE_ENV" \
  --query 'computeEnvironments[0].ecsClusterArn' \
  --output text \
  --region "$REGION")

for i in $(seq 0 $((ARRAY_SIZE - 1))); do
  CHILD_JOB_ID="${PARENT_JOB_ID}:${i}"

  read -r STATUS START_TS STOP_TS LOG_STREAM < <(
    aws batch describe-jobs \
      --jobs "$CHILD_JOB_ID" \
      --query 'jobs[0].[status, startedAt, stoppedAt, container.logStreamName]' \
      --output text \
      --region "$REGION"
  )

  if [[ "$STATUS" != "SUCCEEDED" && "$STATUS" != "FAILED" ]]; then
    echo "[$i] Skipping — status: $STATUS"
    continue
  fi

  if [[ -z "$START_TS" || "$START_TS" == "None" || -z "$STOP_TS" || "$STOP_TS" == "None" ]]; then
    echo "[$i] Skipping — missing timestamps"
    continue
  fi

  DURATION_SEC=$(( (STOP_TS - START_TS) / 1000 ))
  ECS_TASK_ID=$(echo "$LOG_STREAM" | awk -F'/' '{print $NF}')

  CONTAINER_INSTANCE_ARN=$(aws ecs describe-tasks \
    --cluster "$ECS_CLUSTER" \
    --tasks "$ECS_TASK_ID" \
    --query 'tasks[0].containerInstanceArn' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "None")

  if [[ "$CONTAINER_INSTANCE_ARN" == "None" || -z "$CONTAINER_INSTANCE_ARN" ]]; then
    printf "%-10s %-20s %-15s %-10s %-10s\n" "[$i]" "UNKNOWN" "UNKNOWN" "N/A" "${DURATION_SEC}s"
    continue
  fi

  EC2_INSTANCE_ID=$(aws ecs describe-container-instances \
    --cluster "$ECS_CLUSTER" \
    --container-instances "$CONTAINER_INSTANCE_ARN" \
    --query 'containerInstances[0].ec2InstanceId' \
    --output text \
    --region "$REGION")

  read -r INSTANCE_TYPE AZ < <(aws ec2 describe-instances \
    --instance-ids "$EC2_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].[InstanceType, Placement.AvailabilityZone]' \
    --output text \
    --region "$REGION")

  START_ISO=$(date -d "@$((START_TS / 1000))" --utc +%Y-%m-%dT%H:%M:%S)
  STOP_ISO=$(date -d  "@$((STOP_TS  / 1000))" --utc +%Y-%m-%dT%H:%M:%S)

  SPOT_PRICE=$(aws ec2 describe-spot-price-history \
    --instance-types "$INSTANCE_TYPE" \
    --product-descriptions "Linux/UNIX" \
    --availability-zone "$AZ" \
    --start-time "$START_ISO" \
    --end-time "$STOP_ISO" \
    --query 'sort_by(SpotPriceHistory, &Timestamp)[-1].SpotPrice' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "N/A")

  printf "%-10s %-20s %-15s %-10s %-10s\n" "[$i]" "$INSTANCE_TYPE" "$AZ" "\$$SPOT_PRICE/hr" "${DURATION_SEC}s"
done
