# Simple python script to fix urls in S3 as the full path rather than relative is placed inside.
# Need to add a way to make an API Gateway call as well to the results summary script 

import sys
import re

def fix_s3_paths(input_path: str, output_path: str) -> None:
    PREFIX = "/app/category_results/"

    with open(input_path, "r", encoding="utf-8") as f:
        content = f.read()

    fixed_content = content.replace(PREFIX, "/")

    print(f"Output written to: {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_s3_paths.py <input_file> [output_file]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else input_file  # overwrite if no output specified

    fix_s3_paths(input_file, output_file)