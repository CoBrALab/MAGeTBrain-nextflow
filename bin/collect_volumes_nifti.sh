#!/bin/bash
# Script to collect volumes in parallel, and use names from a csv if available
# Modified to work with NIFTI files and use LabelGeometryMeasures
# CSV Format
# 1,name
# 2,name
# etc

set -euo pipefail

firstarg=${1:-}
if ! [[  ( $firstarg = *csv ) ||  ( $firstarg = *nii ) || ( $firstarg = *nii.gz ) ]]; then
    echo "usage: $0 [ label-mapping.csv ] input.nii.gz [ input2.nii.gz ... inputN.nii.gz ]"
    exit 1
fi

output_file="collected_volumes.tsv"
label_csv=""

if [[ "$1" == *csv ]]; then
    label_csv="$1"
    shift
fi

temp_dir=$(mktemp -d)
echo "Using temporary directory: $temp_dir"
# rm on exit
trap 'rm -rf "$temp_dir"' EXIT

for file in "$@"; do
    # strip suffix
    file_basename=$(basename "$file")
    result_file="$temp_dir/${file_basename}.out"
    
    echo "Processing $file..."
    
    LabelGeometryMeasures 3 "$file" "none" > "$result_file"
    
    awk -v file="$file" 'NR==1 {print "Subject\t" $0; next} {print file "\t" $0}' "$result_file" > "${result_file}.with_subject"
    
    # If we have a label CSV, merge it with the output based on label number
    if [ -n "$label_csv" ] && [ -f "$label_csv" ]; then
        # Create a temporary file with the label mappings
        awk -F, '{print $1 "," $2}' "$label_csv" > "$temp_dir/label_map.csv"
        
        # Merge the label information with the LabelGeometryMeasures output
        awk -v label_file="$temp_dir/label_map.csv" '
        BEGIN {
            # Read the label mapping file
            while ((getline line < label_file) > 0) {
                split(line, parts, ",");
                label_num = parts[1];
                label_name = parts[2];
                labels[label_num] = label_name;
            }
            close(label_file);
            
            # Add header for label number and name
            OFS = "\t";
        }
        NR == 1 {
            print "LabelNumber", "LabelName", $0;
            next;
        }
        {
            # Extract the label number from the second column
            label_num = $2;
            if (label_num in labels) {
                label_text = labels[label_num];
            } else {
                label_text = "Unknown";
            }
            print label_num, label_text, $0;
        }' "${result_file}.with_subject" > "${result_file}.final"
    else
        # No label CSV, just add empty columns
        awk 'NR==1 {print "LabelNumber\tLabelName\t" $0; next} {print $2 "\tUnknown\t" $0}' "${result_file}.with_subject" > "${result_file}.final"
    fi
    
    if [ ! -f "$output_file" ]; then
        cat "${result_file}.final" > "$output_file"
    else
        tail -n +2 "${result_file}.final" >> "$output_file"
    fi
done

echo "Processing complete. Results saved to $output_file"
