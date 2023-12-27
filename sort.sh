#!/bin/bash
readme_file="README.md"

# Find the line numbers for the start and end of the "Internships" section
internship_start_line=$(awk '/## Internships :necktie:/{found=1; next} found && /^\|/ {print NR; exit}' "$readme_file")
internship_end_line=$(awk -v start="$internship_start_line" '$1 ~ /^##/ && NR > start {print NR-1; exit}' "$readme_file")

# If the end line is still empty, set it to the last line of the file
[ -z "$internship_end_line" ] && internship_end_line=$(wc -l < "$readme_file")

# Extract the lines between the "Internships" header and the next header
internship_table=$(awk -v start="$internship_start_line" -v end="$internship_end_line" 'NR >= start && NR <= end' "$readme_file")

# Convert the markdown table to JSON using jq
json_data=$(echo "$internship_table" | awk -F '|' 'NR>1 {
    gsub(/^[ \t]+|[ \t]+$/, "", $2); 
    gsub(/^[ \t]+|[ \t]+$/, "", $3); 
    gsub(/^[ \t]+|[ \t]+$/, "", $4); 
    gsub(/^[ \t]+|[ \t]+$/, "", $5); 
    match($2, /\[([^\]]+)\]\(([^)]+)\)/, arr); 
    name = arr[1]; 
    url = arr[2];
    printf("{\"name\":\"%s\",\"url\":\"%s\",\"location\":\"%s\",\"role\":\"%s\",\"status\":\"%s\"},\n", name, url, $3, $4, $5)
}' | sed '1d; $s/.$//')

# Create the JSON file
echo "[$json_data]" | jq '.' > data.json

# Sort the JSON data based on the "status" field
sorted_json_data=$(jq 'sort_by(.status == "Closed")' data.json)

# Generate the new markdown table from the sorted JSON data
new_markdown_table=$(echo "$sorted_json_data" | jq -r 'map("|[\(.name)](\(.url)) | \(.location) | \(.role) | \(.status) |") | .[]' | sed ':a;N;$!ba;s/\n/\\n/g')

# Replace the existing internship content with the sorted one in the README.md
awk -v start="$internship_start_line" -v end="$internship_end_line" -v new_table="$new_markdown_table" 'NR==start+2, NR==end {if (NR==start) print; if (NR==end) print new_table; next} 1' "$readme_file" > tmp.md && mv tmp.md "$readme_file"

# Save the sorted JSON data to data.json without overwriting the original README.md
echo "$sorted_json_data" > data.json
