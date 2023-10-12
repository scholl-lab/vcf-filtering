#!/bin/bash

# Documentation
# Script Name: replace_gt_with_sample.sh
# Description: This script takes a tab-delimited stream of data as input and replaces
#              non-"0/0" values in the specified genotype (GT) field with corresponding
#              values from a given sample file. If the --append-genotype flag is provided,
#              the genotype is appended in parentheses after the sample ID.
#              "0/0" genotypes are removed from the list.
# Usage: 
#    ./replace_gt_with_sample.sh [--append-genotype] <sample_file> <GT_field_number> 
# Parameters:
#    --append-genotype: (Optional) Flag to append the genotype in parentheses after the sample ID.
#    sample_file: The path to the file containing the sample values to use for replacement.
#    GT_field_number: The number of the field (column) in the input stream representing the GT values.
# Output:
#    The modified tab-delimited data is printed to the standard output, with the specified GT field
#    having been updated as described above.
# Example:
#    your_command | ./replace_gt_with_sample.sh --append-genotype path/to/samplefile.txt 14

APPEND_GENOTYPE=0

# Check for --append-genotype flag
if [ "$1" == "--append-genotype" ]; then
    APPEND_GENOTYPE=1
    shift
fi

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [--append-genotype] <sample_file> <GT_field_number>"
    exit 1
fi

# Step 1: Read the sample list into an array
mapfile -t samples < "$1"

# Step 2: Process the input stream with awk
awk -v FS='\t' -v OFS='\t' -v samples="${samples[*]}" -v GT_field="$2" -v APPEND="$APPEND_GENOTYPE" '
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
    for (i = 1; i <= length(genotypes); i++) {
        if (genotypes[i] != "0/0") {
            if (APPEND) {
                genotypes[i] = sample_arr[i] "(" genotypes[i] ")";
            } else {
                genotypes[i] = sample_arr[i];
            }
        } else {
            genotypes[i] = "";
        }
    }
    
    # Remove empty entries and build the new GT field
    first = 1;
    for (i = 1; i <= length(genotypes); i++) {
        if (genotypes[i] != "") {
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
