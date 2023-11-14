#!/bin/bash

# Version information
SCRIPT_VERSION="0.1.0"
SCRIPT_DATE="2023-11-13"

# Documentation
# -------------
#
# Overview:
# Script Name: filter_phenotypes.sh, Version: $SCRIPT_VERSION $SCRIPT_DATE
# This script is designed to filter CSV/TSV files based on specified sample IDs.
#
# Requirements:
# - GNU Awk
# - GNU bash
#
# Usage:
# ./filter_phenotypes.sh [-f input_file] [-o output_file] [-d output_delimiter] [-s sample_file] [-l sample_list] [-c column_name]
#
# Detailed Options:
#    -f, --input-file:         Path to the CSV/TSV file to be filtered.
#    -o, --output-file:        (Optional) Path to save the filtered CSV/TSV. If not provided, outputs to stdout.
#    -d, --output-delimiter:   (Optional) Delimiter for the output format ('csv' or 'tsv').
#    -s, --sample-file:        (Optional) File with sample IDs, one per line.
#    -l, --sample-list:        (Optional) Comma-separated list of sample IDs.
#    -c, --column-name:        Name of the column containing sample IDs.
#    -h, --help:               Displays this help information.
#    -V, --version:            Displays version information.
#
# Example:
#    ./filter_phenotypes.sh -f input.csv -o output.tsv -l "329991,327338" -c "CGRSequenceID"

# Function to display help information
print_help() {
    cat << EOF
Usage: $0 [OPTIONS]
Options:
    -f, --input-file FILE         Path to the CSV/TSV file to be filtered.
    -o, --output-file FILE        (Optional) Path to save the filtered file. If not provided, outputs to stdout.
    -d, --output-delimiter DELIM  (Optional) Delimiter for the output format. Options: 'csv', 'tsv'. Default based on file extension.
    -s, --sample-file FILE        (Optional) File with sample IDs, one per line.
    -l, --sample-list IDS         (Optional) Comma-separated list of sample IDs.
    -c, --column-name NAME        Column name containing sample IDs.
    -h, --help                    Display this help information and exit.
    -V, --version                 Display script version information and exit.

Example:
    $0 -f input.csv -o output.tsv -l "329991,327338" -c "CGRSequenceID"
EOF
}

# Check if no arguments were provided and display help
if [ "$#" -eq 0 ]; then
    print_help
    exit 0
fi

# Handle the version argument
if [ "$1" == "-V" ]; then
    echo "filter_phenotypes.sh version $SCRIPT_VERSION $SCRIPT_DATE"
    exit 0
fi

# Handle the help argument
if [ "$1" == "-h" ]; then
    print_help
    exit 0
fi

# Default values
INPUT_FILE=""
OUTPUT_FILE=""
OUTPUT_DELIMITER=""
SAMPLE_FILE=""
SAMPLE_LIST=""
COLUMN_NAME=""

# Preprocess long options
for arg in "$@"; do
  shift
  case "$arg" in
    "--input-file") set -- "$@" "-f" ;;
    "--output-file") set -- "$@" "-o" ;;
    "--output-delimiter") set -- "$@" "-d" ;;
    "--sample-file") set -- "$@" "-s" ;;
    "--sample-list") set -- "$@" "-l" ;;
    "--column-name") set -- "$@" "-c" ;;
    *) set -- "$@" "$arg" ;;
  esac
done

# Process options
while getopts ":f:o:d:s:l:c:" opt; do
    case ${opt} in
        f ) INPUT_FILE="$OPTARG" ;;
        o ) OUTPUT_FILE="$OPTARG" ;;
        d ) 
            case "$OPTARG" in
                "csv") OUTPUT_DELIMITER="," ;;
                "tsv") OUTPUT_DELIMITER="\t" ;;
                *) echo "Invalid output delimiter: $OPTARG. Valid options are 'csv' or 'tsv'."; exit 1 ;;
            esac
            ;;
        s ) SAMPLE_FILE="$OPTARG" ;;
        l ) SAMPLE_LIST="$OPTARG" ;;
        c ) COLUMN_NAME="$OPTARG" ;;
        \? ) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found."
    exit 1
fi

# Determine the delimiter based on the input file extension
case "$INPUT_FILE" in
    *.csv) INPUT_DELIMITER="," ;;
    *.tsv) INPUT_DELIMITER="\t" ;;
    *) echo "Error: Input file must have either .csv or .tsv extension."; exit 1 ;;
esac

# Determine the output delimiter based on the output file extension, if provided
if [ ! -z "$OUTPUT_DELIMITER" ]; then
    # Output delimiter explicitly set by -d option, do nothing as it's already set
    :
elif [ ! -z "$OUTPUT_FILE" ]; then
    case "$OUTPUT_FILE" in
        *.csv) OUTPUT_DELIMITER="," ;;
        *.tsv) OUTPUT_DELIMITER="\t" ;;
        *) echo "Error: Output file must have either .csv or .tsv extension."; exit 1 ;;
    esac
else
    # If no output file is provided and no delimiter is specified, use the input delimiter for stdout
    OUTPUT_DELIMITER="$INPUT_DELIMITER"
fi

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

# Step 2: Filter the input file based on sample IDs
{
    # Print header with appropriate delimiter
    head -n 1 "$INPUT_FILE" | tr "$INPUT_DELIMITER" "$OUTPUT_DELIMITER"

    # Find the column number for the specified column name
    column_number=$(head -n 1 "$INPUT_FILE" | tr "$INPUT_DELIMITER" '\n' | grep -n "^$COLUMN_NAME$" | cut -d: -f1)

    # Check for column name existence
    if [ -z "$COLUMN_NAME" ]; then
        echo "Error: Column name is required."
        exit 1
    fi

    if [ -z "$column_number" ]; then
        echo "Error: Column '$COLUMN_NAME' not found in input file."
        exit 1
    fi

    # Filter records
    for sample_id in "${samples[@]}"; do
        awk -v col="$column_number" -v sample_id="$sample_id" -F"$INPUT_DELIMITER" -v IGNORECASE=1 -v OFS="$OUTPUT_DELIMITER" 'NR > 1 && $col == sample_id { $1=$1; print $0 }' "$INPUT_FILE"
    done
} > "${OUTPUT_FILE:-/dev/stdout}"

if [ -z "$OUTPUT_FILE" ]; then
    echo "Filtering completed. Output sent to stdout."
else
    echo "Filtering completed. Output saved to $OUTPUT_FILE"
fi
