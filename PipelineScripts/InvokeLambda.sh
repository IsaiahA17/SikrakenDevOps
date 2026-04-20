LAMBDA_NAME="$1"
CATEGORY="$2"
S3_BUCKET_NAME="$3"

aws lambda invoke --function-name $LAMBDA_NAME --cli-binary-format raw-in-base64-out --payload '{ "Category": "$CATEGORY", "Bucket": "$S3_BUCKET_NAME" }' response.json

URL=$(jq -r '.body | fromjson | .url' response.json) #Using the jq JSON command line processor to isolate the value of the url key
RESULTS_SUMMARY_URL=$(jq -r '.body | fromjson | .results_summary_url' response.json)

echo "$URL" | awk -F '?' '{print $1}' #Using the text processor awk to try and remove the unnecessary parts of the html url
echo "$RESULTS_SUMMARY_URL"