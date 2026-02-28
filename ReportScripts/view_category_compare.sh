#!/bin/bash
# Script: view_category_compare.sh
# Author: Chris Meudec
# Started: May 2025
# Category Reporting Flow Diagram: https://docs.google.com/drawings/d/1wsCvXsDvS5q7mXy-JMwdL5wQLjxB3pQzcYdrktbfE8Q/edit?usp=sharing 
# Description: Generates the HTML overall summary of all test runs for a category,
#              two runs and a Compare button that prints the ./compare_runs.sh command to run.

if [ -z "$1" ]; then
    echo "Usage: $0 <relative-path-to-category-folder>"
    echo "e.g. $0 /categories/chris"
    exit 1
fi

WORKSPACE_DIR=$(pwd)
BASE_DIR="$WORKSPACE_DIR/$1"
CATEGORY=$(basename "$BASE_DIR")
OUTPUT_HTML="$BASE_DIR/results_summary.html" #output HTML file

if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Directory '$BASE_DIR' does not exist."
    exit 1
fi

TEMP_DATA=$(mktemp)

# Collect test run results for each category run in "category_test_run_results.html"
find "$BASE_DIR" -type f -name "category_test_run_results.html" | while read -r file; do
    subfolder=$(basename "$(dirname "$file")")
    run_dir=$(dirname "$file")
    content=$(<"$file")

    date_stamp=$(echo "$content" | grep -oP '(?<=<h2>Timestamp: ).*(?=</h2>)')
    budget=$(echo "$content" | grep -oP '(?<=<h2>Budget: ).*(?=</h2>)' | sed 's/[^0-9.]//g')
    mode=$(echo "$content" | grep -oP '(?<=<h2>Mode: ).*(?=</h2>)')
    options=$(echo "$content" | grep -oP '(?<=<h2>Options: ).*(?=</h2>)')
    benchmarks=$(echo "$content" | grep -oP '(?<=<h2>Number of Benchmarks: ).*(?=</h2>)')
    score=$(echo "$content" | grep -oP '(?<=<h2>Overall Score Achieved: ).*(?=</h2>)')
    nb_tests=$(echo "$content" | grep -oP '(?<=<h2>Overall Tests Generated: ).*(?=</h2>)')
    duration=$(echo "$content" | grep -oP '(?<=<h2>Run time: ).*(?=</h2>)')
    overall_user_cpu_time=$(echo "$content" | grep -oP '(?<=<h2>Overall User CPU Time: ).*(?=</h2>)')
    score_per_billion_wakes=$(echo "$content" | grep -oP '(?<=<h2>Overall Score per Billion Wakes: ).*(?=</h2>)')
    score_per_cpu_hour=$(echo "$content" | grep -oP '(?<=<h2>Overall Score per CPU Hour: ).*(?=</h2>)')

    echo -e "$budget\t$mode\t\"$options\"\t$duration\t$date_stamp\t$file\t$benchmarks\t$score\t$nb_tests\t$overall_user_cpu_time\t$score_per_billion_wakes\t$score_per_cpu_hour" >> "$TEMP_DATA"
done

sorted_data=$(sort -t$'\t' -k5,5 "$TEMP_DATA")  #-kcol, col : sort by the col: adjust if inserting or removing a column

# Start HTML
cat <<EOF > "$OUTPUT_HTML"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>TestComp Category Run Results - $CATEGORY</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    table { border-collapse: collapse; width: auto; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    pre { background:#f4f4f4; padding:10px; border:1px solid #ccc; }
  </style>
</head>
<body>
<h1>Test Run Results - $CATEGORY</h1>
<p>Summary of all test runs for <strong>$CATEGORY</strong>.</p>
<p>To generate another run: <code>./SikrakenDevSpace/bin/test_category_sikraken.sh /home/chris/sv-benchmarks/c $CATEGORY 8 30 debug</code></p> 

<form id="compareForm">
<table>
  <thead>
    <tr>
      <th>Select</th>
      <th>Budget</th>
      <th>Mode</th>
      <th>Options</th>
      <th>Duration</th>
      <th>Date</th>
      <th>Link</th>
      <th>Benchmarks</th>
      <th>Score</th>
      <th>Nb Tests</th>
      <th>User CPU Times</th>
      <th>Score/Wake Count (Scaled)</th>
      <th>Score/User CPU Time (Scaled)</th>
    </tr>
  </thead>
  <tbody>
EOF

# Fill table rows
while IFS=$'\t' read -r budget mode options duration date_stamp file benchmarks score nb_tests overall_user_cpu_time score_per_billion_wakes score_per_cpu_hour; do
    cat <<EOF >> "$OUTPUT_HTML"
    <tr>
      <td><input type="checkbox" name="compare" value="$file"></td>
      <td>${budget:-N/A}</td>
      <td>${mode:-N/A}</td>
      <td>${options:-N/A}</td>
      <td>${duration:-N/A}</td>
      <td>$date_stamp</td>
      <td><a href="$file" target="_blank">View Results</a></td>
      <td>${benchmarks:-N/A}</td>
      <td>${score:-N/A}</td>
      <td>${nb_tests:-N/A}</td>
      <td>${overall_user_cpu_time:-N/A}</td>
      <td>${score_per_billion_wakes:-N/A}</td>
      <td>${score_per_cpu_hour:-N/A}</td>
    </tr>
EOF
done <<< "$sorted_data"

# Close HTML
cat <<EOF >> "$OUTPUT_HTML"
  </tbody>
</table>
<br>
<button type="button" onclick="makeCompareCommand()">Compare Selected</button>
</form>

<h3>Command to run:</h3>
<pre id="compareCommand"></pre>

<script>
function makeCompareCommand() {
    const checked = Array.from(document.querySelectorAll('input[name="compare"]:checked'));
    if (checked.length !== 2) {
        alert("Please select exactly 2 runs to compare.");
        return;
    }
    const file1 = checked[0].value;
    const file2 = checked[1].value;
    const cmd = \`./SikrakenDevSpace/bin/helper/compare_runs.sh "\${file1}" "\${file2}" compare_run.html\`;
    document.getElementById("compareCommand").textContent = cmd;
}
</script>

</body>
</html>
EOF

rm "$TEMP_DATA"
echo "HTML summary generated at: $OUTPUT_HTML"
