#!/bin/bash

# Define a variable for the script's name
SCRIPT_NAME=$(basename "$0")

# Version information
SCRIPT_VERSION="0.4.0"
SCRIPT_DATE="2023-11-16"

# Documentation
# -------------
#
# Script Name: $SCRIPT_NAME, Version: $SCRIPT_VERSION, Date: $SCRIPT_DATE
# Description: This script takes a tab-delimited stream of data as input and replaces
#              non-"0/0" genotypes in the specified field with corresponding sample IDs.
#              If --append-genotype is set, genotypes are appended to the sample ID in parentheses.
#              "0/0" genotypes are removed from the output.
# Usage: 
#    ./$SCRIPT_NAME [options] | your_command
#
# Options:
#    -a, --append-genotype: (Optional) Append the genotype to the sample ID.
#    -s, --sample-file: (Optional) File with sample IDs, one per line.
#    -g, --gt-field-number: Field number for the genotype.
#    -l, --sample-list: (Optional) Comma-separated list of sample IDs.
#    -h, --help: Display this help message.
#    -V, --version: Display version information.
#
# Example: 
#    your_command | ./$SCRIPT_NAME -a --sample-file path/to/samplefile.txt --gt-field-number 14

# Usage information
print_usage() {
    echo "Usage: $0 [options] | your_command"
    echo "Use -h for more information."
}

# Help information
print_help() {
    cat << EOF
This script takes a tab-delimited stream of data as input and replaces non-"0/0" genotypes in a specified field with corresponding sample IDs. Genotypes can optionally be appended to the sample ID. "0/0" genotypes are removed from the output.

Options:
    -a, --append-genotype: (Optional) Append the genotype to the sample ID.
    -s, --sample-file: (Optional) File with sample IDs, one per line.
    -g, --gt-field-number: Field number for the genotype.
    -l, --sample-list: (Optional) Comma-separated list of sample IDs.
    -h, --help: Display this help message.
    -V, --version: Display version information.

Example: 
    your_command | ./$SCRIPT_NAME -a --sample-file path/to/samplefile.txt --gt-field-number 14

Version: $SCRIPT_VERSION, Date: $SCRIPT_DATE
EOF
}

# Check for no arguments
if [ "$#" -eq 0 ]; then
    print_help
    exit 0
fi

# Default values
APPEND_GENOTYPE=0
SAMPLE_FILE="samples.txt"
GT_FIELD_NUMBER=10
SAMPLE_LIST=""
SEPARATOR=";"  # Default separator

# Preprocess long options and add version/help handling
for arg in "$@"; do
  shift
  case "$arg" in
    "--append-genotype")  set -- "$@" "-a" ;;
    "--sample-file")      set -- "$@" "-s" ;;
    "--gt-field-number")  set -- "$@" "-g" ;;
    "--sample-list")      set -- "$@" "-l" ;;
    "--help")             set -- "$@" "-h" ;;
    "--version")          set -- "$@" "-V" ;;
    *)                    set -- "$@" "$arg" ;;
  esac
done

# Process options
while getopts "as:g:l:p:hV" opt; do
    case ${opt} in
        a ) APPEND_GENOTYPE=1 ;;
        s ) SAMPLE_FILE="$OPTARG" ;;
        g ) GT_FIELD_NUMBER="$OPTARG" ;;
        l ) SAMPLE_LIST="$OPTARG" ;;
        p ) SEPARATOR="$OPTARG" ;;  # Capture the custom separator
        h ) print_help; exit 0 ;;
        V ) echo "$SCRIPT_NAME version $SCRIPT_VERSION, Date $SCRIPT_DATE"; exit 0 ;;
        \? ) print_usage; exit 1 ;;
    esac
done

# Step 1: Read the sample list into an array
# Check sample source
if [[ -z "$SAMPLE_LIST" && ! -f "$SAMPLE_FILE" ]]; then
    echo "Error: Sample file $SAMPLE_FILE not found." >&2
    exit 1
elif [[ -n "$SAMPLE_LIST" && -n "$SAMPLE_FILE" ]]; then
    echo "Warning: Both sample file and sample list provided. Using sample list." >&2
fi

# Get samples
if [[ -z "$SAMPLE_LIST" ]]; then
    mapfile -t samples < "$SAMPLE_FILE"
else
    IFS=',' read -ra samples <<< "$SAMPLE_LIST"
fi

# Step 2: Process the input stream with awk
awk -v FS='\t' -v OFS='\t' -v samples="${samples[*]}" -v GT_field="$GT_FIELD_NUMBER" -v APPEND="$APPEND_GENOTYPE" -v SEP="$SEPARATOR" '
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
                $(GT_field) = $(GT_field) SEP genotypes[i];
            }
        }
    }
    
    print;
}' 
