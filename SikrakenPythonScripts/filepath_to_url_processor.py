import os
import re
import json
import argparse
from pathlib import Path

s3_url = 'https://testcov-results-bucket.s3.eu-west-1.amazonaws.com'

def replace_local_paths_with_s3(html_content):
    # Regex explanation:
    # href="  → match start of URL
    # [^"]*? → non-greedy match of anything until...
    # (\d{4}_\d{2}_\d{2}_\d{2}_\d{2}) → capture folder beginning with a YYYY_MM_DD_HH_MM pattern
    # /(.+?) → capture the rest of the path
    pattern = r'href="[^"]*?(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}/.+?)"'

    def repl(match):
        path = match.group(1)  
        return f'href="{s3_url}/{path}"'

    return re.sub(pattern, repl, html_content)


def process_html_file(input_dir):
    input_dir_path = Path(input_dir)
    html_file_name = 'category_test_run_results.html'
    html_full_path = os.path.join(input_dir_path, html_file_name)

    html_files = list(input_dir_path.glob(html_file_name))

    report_data = []

    try:
        with open(html_full_path, 'r') as file:
            html_content = file.read()

        converted_html = replace_local_paths_with_s3(html_content)

        report_data.append({
            "file": str(html_full_path),
            "content": converted_html
        })

    except Exception as e:
        return {"body": f"Error reading file {html_full_path}: {str(e)}"}
    
    with open(html_full_path, 'w') as f:
        f.write(converted_html) #Writing html content to a html file found previously

    return {"body": f"Processed {len(html_files)} HTML files.", "data": report_data}


def main():
    parser = argparse.ArgumentParser(description="Generate a report from test logs.")
    parser.add_argument('input_dir', type=str, help="Path to the input directory")
    args = parser.parse_args()

    result = process_html_file(args.input_dir)

    print(result['body'])
    if 'data' in result:
        print(json.dumps(result['data'], indent=4))

if __name__ == "__main__":
    main()
