import json
import boto3

# Initialize S3 client
s3 = boto3.client('s3')
def retrieve_benchmarks(prefix, bucket_name):
    resp = s3.list_objects_v2(
        Bucket=bucket_name,
        Prefix=prefix,
        Delimiter="/"
    )
    return [p["Prefix"] for p in resp.get("CommonPrefixes", [])]

def get_latest_timestamp(category, bucket_name):
    prefixes = retrieve_benchmarks(f"{category}/", bucket_name)
    timestamp_filepaths = [p.rstrip("/").split("/")[-1] for p in prefixes]
    timestamp_filepaths.sort(reverse=True)
    return timestamp_filepaths[0]

def build_full_filepath(category, most_recent_folder):
    return f"{category}/{most_recent_folder}"

def build_report_url(bucket_name, file_obj):
    return f"https://{bucket_name}.s3.amazonaws.com/{file_obj['Key']}"

def build_summary_url(bucket_name, category):
    return f"https://{bucket_name}.s3.amazonaws.com/{category}/results_summary.html"
    
def lambda_handler(event, context):
    bucket_name = event["Bucket"]
    object_key = 'category_test_run_results.html'  # File to search for
    category = event["Category"]

    most_recent_folder = get_latest_timestamp(category, bucket_name)

    full_path = build_full_filepath(category, most_recent_folder)
    #Listing the contents of the most recent folder found to find the HTML file
    folder_contents_response = s3.list_objects_v2(
        Bucket=bucket_name,
        Prefix=full_path
    )

    #Check if 'Contents' is present in the folder's response
    if 'Contents' not in folder_contents_response:
        return {
            'statusCode': 404,
            'body': json.dumps(f'No contents found in folder {most_recent_folder}.')
        }

    # Checking for object with the name of report generated 
    html_report = [obj for obj in folder_contents_response['Contents'] if obj['Key'].endswith(object_key)]
    results_summary_url = build_summary_url(bucket_name, category)

    if html_report:
        file_obj = html_report[0] #Getting first S3 object found that has the correct key name as a list is returned
        url = build_report_url(bucket_name, file_obj)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f"Found the HTML file: {file_obj['Key']}",
                'url': url,  #.html file url from S3 bucket that can be viewed by anyone with the link
                'results_summary_url': results_summary_url  
            })
        }
    else:
        return {
            'statusCode': 404, # Error message in the case that 
            'body': json.dumps(f'{object_key} not found in folder {most_recent_folder}.')
        }