#!/bin/bash
#
# Script: create_category_test_run_table.sh
# Author: Chris Meudec
# Started: May 2025
# Category Reporting Flow Diagram: https://docs.google.com/drawings/d/1wsCvXsDvS5q7mXy-JMwdL5wQLjxB3pQzcYdrktbfE8Q/edit?usp=sharing
# Description: Generates a detailed HTML report for all the benchmarks in a single category.
# It processes Testcomp benchmark results previously generated, including coverage and stack peak data. 
# The report includes a summary of the test run, including the number of benchmarks,
# overall score achieved, and a detailed table of results for each benchmark.
# It also provides links to the Sikraken log, TestCov log, and a plot of the results.
# The script takes three arguments: the path to the benchmark directory
# It generates an HTML file named "category_test_run_results.html" in the specified directory.
# Usage: ./create_category_test_run_table.sh <relative_or_absolute_path_to_timestamp_directory> 
# Example: ./create_category_test_run_table.sh /home/chris/Sikraken/SikrakenDevSpace/categories/ECA/2025_10_23_18_40

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" 
SIKRAKEN_INSTALL_DIR="$SCRIPT_DIR/../../../"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <relative_or_absolute_path_to_timestamp_directory>"
    exit 1
fi

# Convert relative path to absolute path
input_dir=$(realpath "$1")
category_test_run_input_log="${input_dir}/category_test_run.log"    #input log file to pass data to this script
html_file="${input_dir}/category_test_run_results.html"             #output HTML file
benchmark_file_mapping="${input_dir}/benchmark_files.txt"           #input list of benchmarks for the category
script_name=$(basename "$0")

if [ ! -f "$benchmark_file_mapping" ]; then
    echo "$script_name Error: File $benchmark_file_mapping not found. Exiting."
    exit 1
fi
if [ ! -f "$category_test_run_input_log" ]; then
    echo "$script_name Error: File $category_test_run_input_log not found. Exiting."
    exit 1
fi
timestamp=$(grep -oP '^Timestamp: \K.*' "$category_test_run_input_log")
category=$(grep -oP '^Category: \K.*' "$category_test_run_input_log")
mode=$(grep -oP '^Mode: \K.*' "$category_test_run_input_log")
options=$(grep -oP '^Options: \K.*' "$category_test_run_input_log")
budget=$(grep -oP '^Budget: \K.*' "$category_test_run_input_log")
cores=$(grep -oP '^Cores: \K.*' "$category_test_run_input_log")
duration=$(grep -oP '^Duration: \K.*' "$category_test_run_input_log")
no_testcov=$(grep -oP 'no_testcov:\s*\K[01]' "$category_test_run_input_log" | tr -d '[:space:]')

total_coverage=0.0
total_tests=0
total_cpu_time=0
total_wake_count=0
rows=""

# Process benchmarks in the order listed in benchmark_files.txt
while IFS= read -r line; do
    # Extract file path and benchmark name
    file_path=$(echo "$line" | awk '{print $1}')  # Extract full path
    benchmark_name=$(basename "$file_path")       # Extract filename with extension
    benchmark_base=$(basename "$file_path" .c)   # Strip .c extension (if any)
    benchmark_base=$(basename "$benchmark_base" .i) # Strip .i extension (if any)

    benchmark_dir="${input_dir}/${benchmark_base}"
    
    plot_file="${benchmark_dir}/sikraken_plot.png"
    html_coverage="${benchmark_dir}/$benchmark_base.html"
    testcov_log_file="${benchmark_dir}/testcov_call.log"
    sikraken_log="${benchmark_dir}/sikraken.log"

    # Ensure benchmark directory exists
    if [ ! -d "$benchmark_dir" ]; then
        echo "Directory for benchmark $benchmark_base not found, skipping."
        continue
    fi

    sik_coverage=$(grep -oP "Coverage:\s+\K\d+\.\d+(?=%)" "$sikraken_log" 2>/dev/null | tail -n 1)  #only get the last one in case the log contains several coverage reports by mistake
    sik_coverage=${sik_coverage:-"-1"}      #default value is -1
    if [ "$sik_coverage" = "-1" ]; then
        echo "Primary coverage value not found. Attempting to read 'Inter-cov' fallback..."
    
        # 3. Read the LAST occurrence of 'Inter-cov' using tac (the reverse of cat) and extract the percentage value
        fallback_coverage=$(tac "$sikraken_log" | grep -m 1 "Inter-cov:" | grep -oP "Inter-cov:\K\d+\.\d+(?=%)" 2>/dev/null)

        # 4. Check if the fallback attempt was successful
        if [ -n "$fallback_coverage" ]; then
            sik_coverage="$fallback_coverage"
            echo "Successfully set coverage from 'Inter-cov': $sik_coverage%"
        else
            # If the fallback also failed, sik_coverage remains -1
            echo "Fallback 'Inter-cov' value not found either."
        fi
    fi

    if [[ $no_testcov == "1" ]]; then
        total_coverage=$(bc <<< "$total_coverage + $sik_coverage")  # use sik_coverage
        # echo "Debug: adding sik_coverage $sik_coverage, cumulative coverage is $total_coverage"
        tcv_coverage="N/A"
        testcov_log_link="N/A"
    else
        if [ ! -f "$testcov_log_file" ]; then
            echo "Log file not found: $testcov_log_file"
            tcv_coverage="Missing"
            testcov_log_link="Missing"
        else
            tcv_coverage=$(grep -oP "Coverage:\s+\K[\d.]+(?=%)" "${testcov_log_file}" 2>/dev/null || echo "0")    
            total_coverage=$(bc <<< "$total_coverage + $tcv_coverage")  # Sum coverage for the total
            testcov_log_link="<a href=\"file://${testcov_log_file}\" target=\"_blank\">TestCov Log</a>"
        fi
    fi
    sik_test_count=$(tac "${sikraken_log}" | grep -m 1 -oP "Generated:\s+\K\d+" || echo "N/A")  
    math_sik_test_count=$(echo "$sik_test_count" | grep -E '^[0-9]+$' || echo 0)
    total_tests=$(bc <<< "$total_tests + $math_sik_test_count")  # Sum the number of tests generated using 0 when N/A 
    
    user_cpu_time=$(tac "${sikraken_log}" | grep -oP 'times:\s*\[\K[0-9.]+' | head -n 1 || echo "0")
    numeric_user_cpu_time=$(echo "$user_cpu_time" | grep -E '^[0-9]+(\.[0-9]+)?$' || echo 0)
    
    row_user_cpu_time=${user_cpu_time:-N/A}
    total_cpu_time=$(bc <<< "${total_cpu_time:-0} + $numeric_user_cpu_time")

    wake_count=$(tac "${sikraken_log}" | grep -m 1 "wake_count:" | grep -oP "wake_count:\s*\K\d+" || echo "0")
    row_wake_count=${wake_count:-N/A}
    numeric_wake_count=$(echo "$wake_count" | grep -E '^[0-9]+$' || echo 0)
    total_wake_count=$(bc <<< "$total_wake_count + $numeric_wake_count")

    stack_peak=$(grep -oP "global_stack_peak:\s+\K\d+" "$sikraken_log" 2>/dev/null || echo "0")
    stack_peak_mb=$(bc <<< "scale=2; $stack_peak / 1000000")    #bytes converted to MB

    # Highlight rows with 0 tests in light red
    if [ "$sik_test_count" == "0" ]; then
        row_class="style='background-color: lightcoral;'"
    elif [ "$sik_test_count" == "N/A" ]; then
        row_class="style='background-color: darkred;'"
    else
        row_class=""
    fi

    # Add link to code
    code_link="<a href=\"file://${SIKRAKEN_INSTALL_DIR}/sikraken_output/${benchmark_base}/${benchmark_base}.i\" target=\"_blank\">${benchmark_base}.i</a>"
    sikraken_log_link="<a href=\"file://${sikraken_log}\" target=\"_blank\">Sikraken Log</a>"
    html_coverage_link="<a href=\"file://${html_coverage}\" target=\"_blank\">${benchmark_base}.html</a>"

    # Add row to table
    rows+="<tr $row_class>
        <td>${code_link}</td>
        <td>${sikraken_log_link}</td>
        <td>${sik_test_count}</td>
        <td>${html_coverage_link}</td>
        <td>${sik_coverage}%</td>
        <td>${tcv_coverage}%</td>
        <td>${testcov_log_link}</td>
        <td><a href=\"${plot_file}\" target=\"_blank\"><img src=\"${plot_file}\" style=\"max-width: 150px; max-height: 100px;\"></a></td>
        <td>${stack_peak_mb}</td>
        <td>${row_user_cpu_time}</td>
        <td>${row_wake_count}</td>
    </tr>"
done < "$benchmark_file_mapping"

# Calculate total coverage
total_score=$(bc <<< "scale=2; $total_coverage / 100")
if (( no_testcov == 1 )); then
    total_score_label="${total_score} (sik)"
else
    total_score_label="${total_score}"
fi

#Scaling by multiplying by a billion to make it easier to read as the number for the overall number will be tiny
score_per_wake=$(bc -l <<< "$total_score / $total_wake_count")
score_per_billion_wakes=$(printf "%.4f" "$(bc -l <<< "($total_score / $total_wake_count) * 1000000000")")

#Scaling by multiplying by 3600, cpu time is in seconds therefore dividing by it will make a tiny number as it would be coverage score per second, so I use the score per hour instead
score_per_cpu_sec=$(bc -l <<< "$total_score / $total_cpu_time")
score_per_cpu_hour=$(printf "%.4f" "$(bc -l <<< "($total_score / $total_cpu_time) * 3600")")

# Generate HTML
cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${category} Test Run Results</title>
    <style>
        table {
            width: 100%;
            border-collapse: collapse;
        }
        table, th, td {
            border: 1px solid black;
        }
        th, td {
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
    </style>
</head>
<body>
    <h1>TestComp Category: ${category} category</h1>
    <h2>Timestamp: ${timestamp}</h2>
    <h2>Budget: ${budget}</h2>
    <h2>Mode: ${mode}</h2>
    <h2>Options: ${options}</h2>
    <h2>Number of Benchmarks: $(wc -l < "$benchmark_file_mapping")</h2>
    <h2>Run time: ${duration}</h2>
    <h2>Cores: ${cores}</h2>
    <h2>Overall Score Achieved: ${total_score_label}</h2>
    <h2>Overall Tests Generated: ${total_tests}</h2>
    <h2>Overall User CPU Time: ${total_cpu_time}</h2>
    <h2>Overall Score per Billion Wakes: ${score_per_billion_wakes}</h2>
    <h2>Overall Score per CPU Hour: ${score_per_cpu_hour}</h2>
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
                <th>User CPU Times</th>
                <th>Wake Count</th>
            </tr>
        </thead>
        <tbody>
            ${rows}
        </tbody>
    </table>
</body>
</html>
EOF

echo "HTML report generated: $html_file"