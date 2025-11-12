import os
import re
import json
import argparse  # Import argparse to handle command-line arguments
from pathlib import Path

# Define the function to generate the report (same as your existing code)
def generate_report(input_dir):
    category_test_run_input_log = os.path.join(input_dir, 'category_test_run.log')
    html_file = os.path.join(input_dir, 'category_test_run_results.html')
    benchmark_file_mapping = os.path.join(input_dir, 'benchmark_files.txt')
    
    if not os.path.isfile(benchmark_file_mapping):
        return {
            'statusCode': 404,
            'body': json.dumps(f"File {benchmark_file_mapping} not found.")
        }
    if not os.path.isfile(category_test_run_input_log):
        return {
            'statusCode': 404,
            'body': json.dumps(f"File {category_test_run_input_log} not found.")
        }

    # Read category_test_run.log for the required values
    with open(category_test_run_input_log, 'r') as log_file:
        log_content = log_file.read()
        command_used = re.search(r'Command Used to Generate the Category Test run:\s*(\S+)', log_content, re.M)
        timestamp = re.search(r'^Timestamp:\s*(.*)', log_content, re.M)
        category = re.search(r'^Category:\s*(.*)', log_content, re.M)
        mode = re.search(r'^Mode:\s*(.*)', log_content, re.M)
        options = re.search(r'^Options:\s*(.*)', log_content, re.M)
        budget = re.search(r'^Budget:\s*(.*)', log_content, re.M)
        cores = re.search(r'^Cores:\s*(.*)', log_content, re.M)
        duration = re.search(r'^Duration:\s*(.*)', log_content, re.M)
        no_testcov = re.search(r'no_testcov:\s*(\d)', log_content)
    
    if not command_used or not timestamp or not category or not mode or not options or not budget or not cores or not duration:
        return {
            'statusCode': 400,
            'body': json.dumps("Error: Missing required data in category_test_run.log.")
        }
    
    command_used = command_used.group(1)
    timestamp = timestamp.group(1)
    category = category.group(1)
    mode = mode.group(1)
    options = options.group(1)
    budget = budget.group(1)
    cores = cores.group(1)
    duration = duration.group(1)
    no_testcov = no_testcov.group(1) == "1"  # Convert to boolean

    total_coverage = 0
    total_tests = 0
    rows = []

    # Read benchmark files
    with open(benchmark_file_mapping, 'r') as file:
        benchmark_lines = file.readlines()

    for line in benchmark_lines:
        file_path = line.strip()
        benchmark_name = os.path.basename(file_path)
        benchmark_base = os.path.splitext(benchmark_name)[0]
        
        benchmark_dir = os.path.join(input_dir, benchmark_base)
        
        plot_file = os.path.join(benchmark_dir, 'sikraken_plot.png')
        html_coverage = os.path.join(benchmark_dir, f"{benchmark_base}.html")
        testcov_log_file = os.path.join(benchmark_dir, 'testcov_call.log')
        sikraken_log = os.path.join(benchmark_dir, 'sikraken.log')
        
        if not os.path.isdir(benchmark_dir):
            continue
        
        sik_coverage = read_sikraken_coverage(sikraken_log)
        
        if no_testcov:
            total_coverage += sik_coverage
            tcv_coverage = "N/A"
            testcov_log_link = "N/A"
        else:
            tcv_coverage = read_testcov_coverage(testcov_log_file)
            total_coverage += tcv_coverage
            testcov_log_link = f'<a href="file://{testcov_log_file}" target="_blank">TestCov Log</a>'
        
        sik_test_count = read_sikraken_test_count(sikraken_log)
        total_tests += sik_test_count
        stack_peak = read_stack_peak(sikraken_log)
        stack_peak_mb = stack_peak / 1048576
        
        row_class = 'style="background-color: lightcoral;"' if sik_test_count == 0 or sik_test_count == "N/A" else ""
        
        code_link = f'<a href="file://{file_path}" target="_blank">{benchmark_name}</a>'
        sikraken_log_link = f'<a href="file://{sikraken_log}" target="_blank">Sikraken Log</a>'
        html_coverage_link = f'<a href="file://{html_coverage}" target="_blank">{benchmark_base}.html</a>'
        
        rows.append(f"""
        <tr {row_class}>
            <td>{code_link}</td>
            <td>{sikraken_log_link}</td>
            <td>{sik_test_count}</td>
            <td>{html_coverage_link}</td>
            <td>{sik_coverage}%</td>
            <td>{tcv_coverage}%</td>
            <td>{testcov_log_link}</td>
            <td><a href="{plot_file}" target="_blank"><img src="{plot_file}" style="max-width: 150px; max-height: 100px;"></a></td>
            <td>{stack_peak_mb}</td>
        </tr>
        """)

    # Calculate total coverage
    total_score = total_coverage / 100
    total_score_label = f"{total_score} (sik)" if no_testcov else f"{total_score}"

    # Generate HTML
    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{category} Test Run Results</title>
        <style>
            table {{
                width: 100%;
                border-collapse: collapse;
            }}
            table, th, td {{
                border: 1px solid black;
            }}
            th, td {{
                padding: 8px;
                text-align: left;
            }}
            th {{
                background-color: #f2f2f2;
            }}
        </style>
    </head>
    <body>
        <h1>TestComp Category: {category} category</h1>
        <h2>Command Used: {command_used}</h2>
        <h2>Timestamp: {timestamp}</h2>
        <h2>Budget: {budget}</h2>
        <h2>Mode: {mode}</h2>
        <h2>Options: {options}</h2>
        <h2>Number of Benchmarks: {len(benchmark_lines)}</h2>
        <h2>Run time: {duration}</h2>
        <h2>Cores: {cores}</h2>
        <h2>Overall Score Achieved: {total_score_label}</h2>
        <h2>Overall Tests Generated: {total_tests}</h2>
        <table>
            <thead>
                <tr>
                    <th>Benchmark</th>
                    <th>Sikraken Log</th>
                    <th>Sikraken Number of Tests</th>
                    <th>Highlighted Coverage</th>
                    <th>Sikraken Coverage</th>
                    <th>TestCov Coverage</th>
                    <th>TestCov Log</th>
                    <th>Graph</th>
                    <th>Peak Global Stack (MB)</th>
                </tr>
            </thead>
            <tbody>
                {''.join(rows)}
            </tbody>
        </table>
    </body>
    </html>
    """

    with open(html_file, 'w') as f:
        f.write(html_content)

    return {
        'statusCode': 200,
        'body': json.dumps(f"HTML report generated: {html_file}")
    }

def read_sikraken_coverage(sikraken_log):
    try:
        with open(sikraken_log, 'r') as f:
            content = f.read()
            match = re.search(r'Coverage:\s*(\d+\.\d+)%', content)
            if match:
                return float(match.group(1))
            else:
                return -1
    except FileNotFoundError:
        return -1

def read_testcov_coverage(testcov_log_file):
    try:
        with open(testcov_log_file, 'r') as f:
            content = f.read()
            match = re.search(r'Coverage:\s*(\d+\.\d+)%', content)
            if match:
                return float(match.group(1))
            else:
                return 0  # If no match, return 0 coverage
    except FileNotFoundError:
        # Handle case where the file is not found
        return 0  # Return 0 if the file is missing
    except Exception as e:
        # Handle any other exceptions that may occur
        print(f"An error occurred: {e}")
        return 0  # Return 0 if an error occurs

def read_sikraken_test_count(sikraken_log):
    try:
        with open(sikraken_log, 'r') as f:
            content = f.read()
            # Assuming test count is represented by 'Generated: <number>' in the log
            match = re.search(r'Generated:\s*(\d+)', content)
            if match:
                return int(match.group(1))
            else:
                return 0  # Return 0 if the test count isn't found
    except FileNotFoundError:
        # Handle case where the log file is missing
        return 0  # Return 0 if file not found
    except Exception as e:
        print(f"An error occurred while reading {sikraken_log}: {e}")
        return 0  # Return 0 in case of other errors

def read_stack_peak(sikraken_log):
    try:
        with open(sikraken_log, 'r') as f:
            content = f.read()
            # Assuming stack peak is represented by 'global_stack_peak: <value>' in the log
            match = re.search(r'global_stack_peak:\s*(\d+)', content)
            if match:
                return int(match.group(1))
            else:
                return 0  # Return 0 if no stack peak value is found
    except FileNotFoundError:
        # Handle case where the log file is missing
        return 0  # Return 0 if file not found
    except Exception as e:
        print(f"An error occurred while reading {sikraken_log}: {e}")
        return 0  # Return 0 in case of other errors

def main():
    # Set up argparse to parse the command-line argument for the input directory
    parser = argparse.ArgumentParser(description="Generate a report from test logs.")
    parser.add_argument('input_dir', type=str, help="Path to the input directory")
    args = parser.parse_args()

    # Call the function with the user-provided input directory
    result = generate_report(args.input_dir)
    
    # Print the result
    print(result['body'])

if __name__ == "__main__":
    main()
