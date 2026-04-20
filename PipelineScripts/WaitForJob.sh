JOB_ID="$1"
while true; do
STATUS=$(aws batch describe-jobs --jobs "$JOB_ID" | jq -r '.jobs[0].status')
echo "Current status: $STATUS"
if [[ "$STATUS" == "SUCCEEDED" ]]; then
    echo "Job completed successfully!"
    break
elif [[ "$STATUS" == "FAILED" ]]; then
    echo "Job failed!"
    exit 1
fi
sleep 60
done