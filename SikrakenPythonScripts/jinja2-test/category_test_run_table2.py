import os
import re
import json
import argparse  # Import argparse to handle command-line arguments
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

def generate_report(input_dir):
    category_test_run_input_log = os.path.join(input_dir, 'category_test_run.log') #Getting path of log, txt, and html file where the report will be written
    html_file = os.path.join(input_dir, 'category_test_run_results.html')
    benchmark_file_mapping = os.path.join(input_dir, 'benchmark_files.txt')
    
    if not os.path.isfile(benchmark_file_mapping): 
        return {
            print("File {benchmark_file_mapping} not found.")
        }
    if not os.path.isfile(category_test_run_input_log):
        return {
            print("File {category_test_run_input_log} not found.")
        }

    # Read category_test_run.log for the required values, using Regex to find them
    with open(category_test_run_input_log, 'r') as log_file:
        log_content = log_file.read()
        command_used = re.search(r'Command Used to Generate the Category Test run:\s*(\S+)', log_content, re.M) #Finds and character (whitespace or non-whitespace) across the log file and captures it
        timestamp = re.search(r'^Timestamp:\s*(.*)', log_content, re.M) #Finds any character after an expected whitespace
        category = re.search(r'^Category:\s*(.*)', log_content, re.M)
        mode = re.search(r'^Mode:\s*(.*)', log_content, re.M)
        options = re.search(r'^Options:\s*(.*)', log_content, re.M)
        budget = re.search(r'^Budget:\s*(.*)', log_content, re.M)
        cores = re.search(r'^Cores:\s*(.*)', log_content, re.M)
        duration = re.search(r'^Duration:\s*(.*)', log_content, re.M)
        no_testcov = re.search(r'no_testcov:\s*(\d)', log_content)
    
    if not command_used or not timestamp or not category or not mode or not options or not budget or not cores or not duration:
        return {
            print("Error: Missing required data in category_test_run.log.")
        }
    
    command_used = command_used.group(1) #Using the second matching result with .group as the first result is the entire string the pattern resides in  
    timestamp = timestamp.group(1)
    category = category.group(1)
    mode = mode.group(1)
    options = options.group(1)
    budget = budget.group(1)
    cores = cores.group(1)
    duration = duration.group(1)
    no_testcov = no_testcov.group(1) == "1"  # Converts to boolean for future use

    rows, benchmark_lines, total_tests, total_score_label = retrieve_benchmark_information(benchmark_file_mapping, no_testcov, input_dir)

    # Load Jinja2 template
    env = Environment(loader=FileSystemLoader(searchpath="./templates"))
    template = env.get_template("category_test_run_table.jinja")

    html_content = template.render(
        category=category,
        command_used=command_used,
        timestamp=timestamp,
        budget=budget,
        mode=mode,
        options=options,
        num_benchmarks=len(benchmark_lines),
        duration=duration,
        cores=cores,
        total_score_label=total_score_label,
        total_tests=total_tests,
        rows=rows
    )

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
    
def retrieve_benchmark_information(benchmark_file_mapping, no_testcov, input_dir):
    total_coverage = 0 
    total_tests = 0
    rows = []

    with open(benchmark_file_mapping, 'r') as file: #reading benchmark.txt file
        benchmark_lines = file.readlines()

    for line in benchmark_lines:
        file_path = line.strip()
        file_path = re.sub(r'\s+-\d+$', '', file_path) #Removing whitespace before hyphen, followed by digits at end of file path as -32 used to be printed out
        benchmark_name = os.path.basename(file_path) #Getting the final part of the file path (name of file and extension)
        benchmark_base = os.path.splitext(benchmark_name)[0] #Splitting name and extension from each other and getting just the name with [0]
        
        benchmark_dir = os.path.join(input_dir, benchmark_base) #joining input directory path and name to get the directory of the benchmark 
        
        plot_file = os.path.join(benchmark_dir, 'sikraken_plot.png') #Getting file paths of the png, html, and log files
        html_coverage = os.path.join(benchmark_dir, f"{benchmark_base}.html") 
        testcov_log_file = os.path.join(benchmark_dir, 'testcov_call.log')
        sikraken_log = os.path.join(benchmark_dir, 'sikraken.log')
        
        if not os.path.isdir(benchmark_dir): #Continuing even if not a real directory 
            continue
        
        sik_coverage = read_sikraken_coverage(sikraken_log) #Reading coverage metric from Sikraken log using Regex
        
        if no_testcov:
            total_coverage += sik_coverage
            tcv_coverage = "N/A"
            testcov_log_link = "N/A"
        else:
            tcv_coverage = read_testcov_coverage(testcov_log_file) #Reading testcov metric if available using Regex
            total_coverage += tcv_coverage
            testcov_log_link = f'<a href="file://{testcov_log_file}" target="_blank">TestCov Log</a>'
        
        sik_test_count = read_sikraken_test_count(sikraken_log) #Reading test count from sikraken log using Regex
        total_tests += sik_test_count
        stack_peak = read_stack_peak(sikraken_log) #Reading stack peak from sikraken log using Regex
        stack_peak_mb = stack_peak / 1048576
        
        rows.append({
        'row_class' : 'style="background-color: lightcoral;"' if sik_test_count == 0 or sik_test_count == "N/A" else "", #Setting sikkraken test count data cells and background color
        'code_link': f'<a href="file://{file_path}" target="_blank">{benchmark_name}</a>',
        'sikraken_log_link': f'<a href="file://{sikraken_log}" target="_blank">Sikraken Log</a>',
        'sik_test_count': sik_test_count,
        'html_coverage_link': f'<a href="file://{html_coverage}" target="_blank">{benchmark_base}.html</a>',
        'testcov_log_link': testcov_log_link,
        'plot_file': plot_file,
        'stack_peak_mb': stack_peak_mb,
        'sik_coverage': sik_coverage,
        'tcv_coverage': tcv_coverage
    })
        
    total_score = total_coverage / 100 #Calculating total score
    total_score_label = f"{total_score} (sik)" if no_testcov else f"{total_score}"

    return rows, benchmark_lines, total_tests, total_score_label

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
