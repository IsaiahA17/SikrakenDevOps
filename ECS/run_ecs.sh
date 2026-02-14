#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${1:-${CLUSTER:-sikraken-cluster}}"
TASK_DEF="${2:-${TASK_DEF:-sikraken-benchmarks-task-def}}"
TASK_COUNT="${3:-${TASK_COUNT:-5}}"
CATEGORY="${4:-${CATEGORY:-chris}}"
BUDGET="${5:-${BUDGET:-10}}"
MODE="${6:-${MODE:-release}}"

SUBNET_ARRAY=(subnet-00575f764f10645c4 subnet-0d48c3c69206076d1 subnet-0a693be6424dd272a)
SG="sg-0b94b75a72c6f0356"

TASK_ARNS=()

launch_shard() {
    local TASK_INDEX=$1
    local SUBNET=${SUBNET_ARRAY[$((TASK_INDEX % ${#SUBNET_ARRAY[@]}))]}

    OUT=$(aws ecs run-task \
        --cluster "$CLUSTER" \
        --task-definition "$TASK_DEF" \
        --launch-type FARGATE \
        --count 1 \
        --overrides "{
          \"containerOverrides\": [
            {
              \"name\": \"sikraken-container\",
              \"environment\": [
                {\"name\": \"CATEGORY\", \"value\": \"$CATEGORY\"},
                {\"name\": \"BUDGET\", \"value\": \"$BUDGET\"},
                {\"name\": \"MODE\", \"value\": \"$MODE\"},
                {\"name\": \"TASK_INDEX\", \"value\": \"$TASK_INDEX\"},
                {\"name\": \"TASK_COUNT\", \"value\": \"$TASK_COUNT\"}
              ]
            }
          ]
        }" \
        --network-configuration "awsvpcConfiguration={
          subnets=[$SUBNET],
          securityGroups=[$SG],
          assignPublicIp=ENABLED
        }")

    TASK_ARN=$(echo "$OUT" | jq -r '.tasks[0].taskArn // empty')

    if [[ -n "$TASK_ARN" ]]; then
        echo "shard $TASK_INDEX Accepted: $TASK_ARN"
        TASK_ARNS+=("$TASK_ARN")
        return 0
    else
        echo "shard $TASK_INDEX Rejected: $(echo "$OUT" | jq -r '.failures')"
        return 1
    fi
}

echo "Starting launch of $TASK_COUNT shards..."

for ((i=0; i<TASK_COUNT; i++)); do
    while true; do
        if launch_shard "$i"; then
            break
        else
            echo "Retrying shard $i in 1s..."
            sleep 1
        fi
    done
    sleep 0.2
done

echo "All shards submitted successfully!"

echo "TASK_ARNS=${TASK_ARNS[*]}"
