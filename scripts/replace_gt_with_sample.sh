#!/bin/bash
## replace_gt_with_sample.sh

# Define a variable for the script's name
SCRIPT_NAME="replace_gt_with_sample.sh"

# Version information
SCRIPT_VERSION="0.7.0"
SCRIPT_DATE="2024-07-10"

# Default values
APPEND_GENOTYPE=0
SAMPLE_FILE="samples.txt"
GT_FIELD_NUMBER=10
SAMPLE_LIST=""
SEPARATOR=";"  # Default separator
LIST_SAMPLES=0
INCLUDE_NOCALLS=0  # Default to not include no-calls in proband_count
COUNT_GENOTYPES=1  # Default to add count columns

# Documentation
# -------------
#
# Script Name: $SCRIPT_NAME, Version: $SCRIPT_VERSION, Date: $SCRIPT_DATE
# Description: This script processes a tab-delimited stream of data, replacing
#              non-"0/0" genotypes in a specified field with corresponding sample IDs.
#              If --append-genotype is set, genotypes are appended to the sample ID in parentheses.
#              "0/0" genotypes are removed from the output. Optionally, it can generate a 
#              list of unique samples with non-"0/0" genotypes and adds count columns.
# Usage: 
#    ./replace_gt_with_sample.sh [options] | your_command
#    Options include appending genotypes, specifying a sample file, 
#    defining a genotype field, listing samples, and more.
#
# Options:
#    -a, --append-genotype: (Optional) Append the genotype to the sample ID.
#    -s, --sample-file: (Optional) File with sample IDs, one per line.
#    -g, --gt-field-number: Field number for the genotype.
#    -l, --sample-list: (Optional) Comma-separated list of sample IDs.
#    -m, --list-samples: (Optional) Output a comma-separated list of unique samples with non-"0/0" genotypes.
#    -n, --include-nocalls: (Optional) Include no-call genotypes (./.) in proband_count.
#    -c, --count-genotypes: (Optional) Add proband_count, proband_variant_count, and proband_allele_count columns.
#    -h, --help: Display this help message.
#    -V, --version: Display version information.

# Examples: 
#    your_command | ./replace_gt_with_sample.sh -a --sample-file path/to/samplefile.txt --gt-field-number 14
#    your_command | ./replace_gt_with_sample.sh -m -s path/to/samplefile.txt --gt-field-number 14

# Usage information
print_usage() {
    echo "Usage: $0 [options] | your_command"
    echo "Options include -a (append genotype), -s (sample file),"
    echo "-g (genotype field number), -l (sample list), -m (list samples),"
    echo "-n (include ./.), -c (add count columns),"
    echo "-h (help), and -V (version)."
    echo "Use -h for more information."
}

# Help information
print_help() {
    cat << EOF
This script takes a tab-delimited stream of data as input and performs two main functions:
1. Replaces non-"0/0" genotypes in a specified field with corresponding sample IDs, 
   optionally appending genotypes.
2. Optionally generates a list of unique samples with non-"0/0" genotypes and adds count columns.

Options:
    -a, --append-genotype: (Optional) Append the genotype to the sample ID.
    -s, --sample-file: (Optional) File with sample IDs, one per line.
    -g, --gt-field-number: Field number for the genotype.
    -l, --sample-list: (Optional) Comma-separated list of sample IDs.
    -m, --list-samples: (Optional) Output a comma-separated list of unique samples with non-"0/0" genotypes.
    -n, --include-nocalls: (Optional) Include no-call genotypes (./.) in proband_count.
    -c, --count-genotypes: (Optional) Add proband_count, proband_variant_count, and proband_allele_count columns.
    -h, --help: Display this help message.
    -V, --version: Display version information.

Examples: 
    your_command | ./replace_gt_with_sample.sh -a --sample-file path/to/samplefile.txt --gt-field-number 14
    your_command | ./replace_gt_with_sample.sh -m -s path/to/samplefile.txt --gt-field-number 14

Version: $SCRIPT_VERSION, Date: $SCRIPT_DATE
EOF
}

# Check for no arguments
if [ "$#" -eq 0 ]; then
    print_help
    exit 0
fi

# Preprocess long options and add version/help handling
for arg in "$@"; do
  shift
  case "$arg" in
    "--append-genotype")  set -- "$@" "-a" ;;
    "--sample-file")      set -- "$@" "-s" ;;
    "--gt-field-number")  set -- "$@" "-g" ;;
    "--sample-list")      set -- "$@" "-l" ;;
    "--list-samples")     set -- "$@" "-m" ;;
    "--include-nocalls")  set -- "$@" "-n" ;;
    "--count-genotypes")  set -- "$@" "-c" ;;
    "--help")             set -- "$@" "-h" ;;
    "--version")          set -- "$@" "-V" ;;
    *)                    set -- "$@" "$arg" ;;
  esac
done

# Process options
while getopts "as:g:l:nchp:hV" opt; do
    case ${opt} in
        a ) APPEND_GENOTYPE=1 ;;
        s ) SAMPLE_FILE="$OPTARG" ;;
        g ) GT_FIELD_NUMBER="$OPTARG" ;;
        l ) SAMPLE_LIST="$OPTARG" ;;
        n ) INCLUDE_NOCALLS=1 ;;
        c ) COUNT_GENOTYPES=1 ;;
        p ) SEPARATOR="$OPTARG" ;;  # Capture the custom separator
        m ) LIST_SAMPLES=1 ;;
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
awk -v FS='\t' -v OFS='\t' -v samples="${samples[*]}" -v GT_field="$GT_FIELD_NUMBER" \
    -v APPEND="$APPEND_GENOTYPE" -v SEP="$SEPARATOR" -v LIST="$LIST_SAMPLES" \
    -v INCLUDE_NOCALLS="$INCLUDE_NOCALLS" -v COUNT_GENOTYPES="$COUNT_GENOTYPES" '
BEGIN {
    # Split the samples into an array
    split(samples, sample_arr, ",");
    # Initialize the array for collecting unique samples and counting genotypes
    delete unique_samples;
    delete count_het;
    delete count_hom;
    delete count_total;
    delete count_variant;
}

{
    # Skip the header line
    if (NR == 1) {
        if (LIST == 0) {
            if (COUNT_GENOTYPES) {
                print $0, "proband_count", "proband_variant_count", "proband_allele_count"
            } else {
                print $0
            }
        }
        next;
    }

    # Initialize counters
    het_count = 0;
    hom_count = 0;
    variant_count = 0;
    total_count = length(sample_arr);

    # Process the GT field
    split($(GT_field), genotypes, ",");
    for (i = 1; i <= length(genotypes); i++) {
        if (genotypes[i] != "0/0") {
            if (genotypes[i] != "./.") {
                unique_samples[sample_arr[i]] = 1;  # Collect unique samples with non-"0/0" genotypes
                if (genotypes[i] == "0/1") het_count++;
                if (genotypes[i] == "1/1") hom_count++;
                variant_count++;
            }
        } else if (INCLUDE_NOCALLS && genotypes[i] == "./.") {
            total_count++;
        }

        if (genotypes[i] != "0/0" && genotypes[i] != "./.") {
            if (APPEND) {
                genotypes[i] = sample_arr[i] "(" genotypes[i] ")";
            } else {
                genotypes[i] = sample_arr[i];
            }
        } else {
            genotypes[i] = "";
        }
    }

    # Build the new GT field for non-list mode and append counts
    if (LIST == 0) {
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
        if (COUNT_GENOTYPES) {
            print $0, total_count, variant_count, het_count + (2 * hom_count);
        } else {
            print $0;
        }
    }
}

# After processing all input lines
END {
    if (LIST == 1) {
        # Print the collected unique samples
        first = 1;
        for (sample in unique_samples) {
            printf "%s%s", (first ? "" : ","), sample;
            first = 0;
        }
        printf "\n";
    }
}'
