#!/bin/bash

# Documentation
# Script Name: replace_gt_with_sample.sh
# Description: This script takes a tab-delimited stream of data as input and replaces
#              non-"0/0" values in the specified genotype (GT) field with corresponding
#              values from a given sample file. "0/0" values are removed from the list.
# Usage: 
#    ./replace_gt_with_sample.sh <sample_file> <GT_field_number> 
# Parameters:
#    sample_file: The path to the file containing the sample values to use for replacement.
#    GT_field_number: The number of the field (column) in the input stream representing the GT values.
# Output:
#    The modified tab-delimited data is printed to the standard output, with the specified GT field
#    having been updated as described above.
# Example:
#    your_command | ./replace_gt_with_sample.sh path/to/samplefile.txt 14

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <sample_file> <GT_field_number>"
    exit 1
fi

# Step 1: Read the sample list into an array
mapfile -t samples < "$1"

# Step 2: Process the input stream with awk
awk -v FS='\t' -v OFS='\t' -v samples="${samples[*]}" -v GT_field="$2" '
BEGIN {
    # Split the samples into an array
    split(samples, sample_arr, ",");
}

{
    # Skip the header line
    if (NR == 1) {
        print;
        next;
    }

    # Process the GT field
    split($(GT_field), genotypes, ",");
    $(GT_field) = "";
    for (i = 1; i <= length(genotypes); i++) {
        if (genotypes[i] != "0/0") {
            genotypes[i] = sample_arr[i];
        }
    }
    
    # Remove "0/0" entries and build the new GT field
    first = 1;
    for (i = 1; i <= length(genotypes); i++) {
        if (genotypes[i] != "0/0") {
            if (first) {
                $(GT_field) = genotypes[i];
                first = 0;
            } else {
                $(GT_field) = $(GT_field) "," genotypes[i];
            }
        }
    }
    
    print;
}'
