#!/bin/bash
## replace_gt_with_sample.sh

# Define a variable for the script's name
SCRIPT_NAME="replace_gt_with_sample.sh"

# Version information
SCRIPT_VERSION="0.9.0"
SCRIPT_DATE="2024-07-13"

# Default values
APPEND_GENOTYPE=0
GT_FIELD_NUMBER=10
SAMPLE_LIST=""
PROBAND_LIST=""
CONTROL_LIST=""
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
#              The sample, proband, and control lists can be provided either as comma-separated lists
#              or as paths to files containing the lists. Files can contain either comma-separated lists
#              in one line or one sample ID per line.
#              If proband or control lists are not provided, all samples are considered probands by default.
#              Controls are computed as the difference between samples and probands if proband list is provided.
#
# Usage: 
#    ./replace_gt_with_sample.sh [options] | your_command
#    Options include appending genotypes, specifying sample/proband/control lists, 
#    defining a genotype field, listing samples, and more.
#
# Options:
#    -a, --append-genotype: (Optional) Append the genotype to the sample ID.
#    -g, --gt-field-number: Field number for the genotype.
#    -s, --sample-list: Comma-separated list of sample IDs or path to the sample file.
#    -p, --proband-list: (Optional) Comma-separated list of proband IDs or path to the proband file.
#    -c, --control-list: (Optional) Comma-separated list of control IDs or path to the control file.
#    -m, --list-samples: (Optional) Output a comma-separated list of unique samples with non-"0/0" genotypes.
#    -n, --include-nocalls: (Optional) Include no-call genotypes (./.) in proband_count.
#    -C, --count-genotypes: (Optional) Add proband_count, proband_variant_count, and proband_allele_count columns.
#    -h, --help: Display this help message.
#    -V, --version: Display version information.

# Examples: 
#    your_command | ./replace_gt_with_sample.sh -a --sample-list path/to/samplefile.txt --gt-field-number 14
#    your_command | ./replace_gt_with_sample.sh -m -s path/to/samplefile.txt --gt-field-number 14

# Usage information
print_usage() {
    echo "Usage: $0 [options] | your_command"
    echo "Options include -a (append genotype), -g (genotype field number),"
    echo "-s (sample list), -p (proband list), -c (control list),"
    echo "-m (list samples), -n (include ./.), -C (add count columns),"
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
    -g, --gt-field-number: Field number for the genotype.
    -s, --sample-list: Comma-separated list of sample IDs or path to the sample file.
    -p, --proband-list: (Optional) Comma-separated list of proband IDs or path to the proband file.
    -c, --control-list: (Optional) Comma-separated list of control IDs or path to the control file.
    -m, --list-samples: (Optional) Output a comma-separated list of unique samples with non-"0/0" genotypes.
    -n, --include-nocalls: (Optional) Include no-call genotypes (./.) in proband_count.
    -C, --count-genotypes: (Optional) Add proband_count, proband_variant_count, and proband_allele_count columns.
    -h, --help: Display this help message.
    -V, --version: Display version information.

Examples: 
    your_command | ./replace_gt_with_sample.sh -a --sample-list path/to/samplefile.txt --gt-field-number 14
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
    "--gt-field-number")  set -- "$@" "-g" ;;
    "--sample-list")      set -- "$@" "-s" ;;
    "--proband-list")     set -- "$@" "-p" ;;
    "--control-list")     set -- "$@" "-c" ;;
    "--list-samples")     set -- "$@" "-m" ;;
    "--include-nocalls")  set -- "$@" "-n" ;;
    "--count-genotypes")  set -- "$@" "-C" ;;
    "--help")             set -- "$@" "-h" ;;
    "--version")          set -- "$@" "-V" ;;
    *)                    set -- "$@" "$arg" ;;
  esac
done

# Process options
while getopts "ag:s:p:c:nChV" opt; do
    case ${opt} in
        a ) APPEND_GENOTYPE=1 ;;
        g ) GT_FIELD_NUMBER="$OPTARG" ;;
        s ) SAMPLE_LIST="$OPTARG" ;;
        p ) PROBAND_LIST="$OPTARG" ;;
        c ) CONTROL_LIST="$OPTARG" ;;
        n ) INCLUDE_NOCALLS=1 ;;
        C ) COUNT_GENOTYPES=1 ;;
        h ) print_help; exit 0 ;;
        V ) echo "$SCRIPT_NAME version $SCRIPT_VERSION, Date $SCRIPT_DATE"; exit 0 ;;
        \? ) print_usage; exit 1 ;;
    esac
done

# Function to read list from file or comma-separated string
read_list() {
    local input="$1"
    local -n output_array=$2
    if [[ -f "$input" ]]; then
        local content
        content=$(<"$input")
        if [[ "$content" == *","* ]]; then
            IFS=',' read -ra output_array <<< "$content"
        else
            while IFS= read -r line; do
                output_array+=("$line")
            done < "$input"
        fi
    else
        IFS=',' read -ra output_array <<< "$input"
    fi
}

# Read the sample list into an array
if [[ -n "$SAMPLE_LIST" ]]; then
    read_list "$SAMPLE_LIST" samples
else
    echo "Error: Sample list must be provided." >&2
    exit 1
fi

# Read proband and control lists into arrays
if [[ -n "$PROBAND_LIST" ]]; then
    read_list "$PROBAND_LIST" probands
else
    probands=("${samples[@]}")
fi

if [[ -n "$CONTROL_LIST" ]]; then
    read_list "$CONTROL_LIST" controls
else
    controls=()
    for sample in "${samples[@]}"; do
        if [[ ! " ${probands[*]} " =~ " ${sample} " ]]; then
            controls+=("$sample")
        fi
    done
fi

# Step 3: Process the input stream with awk
awk -v FS='\t' -v OFS='\t' -v samples="${samples[*]}" -v probands="${probands[*]}" -v controls="${controls[*]}" \
    -v GT_field="$GT_FIELD_NUMBER" -v APPEND="$APPEND_GENOTYPE" -v SEP="$SEPARATOR" \
    -v LIST="$LIST_SAMPLES" -v INCLUDE_NOCALLS="$INCLUDE_NOCALLS" -v COUNT_GENOTYPES="$COUNT_GENOTYPES" '
BEGIN {
    # Split the samples, probands, and controls into arrays
    split(samples, sample_arr, " ");
    split(probands, proband_arr, " ");
    split(controls, control_arr, " ");

    # Create associative arrays to mark probands and controls
    for (i in proband_arr) proband_map[proband_arr[i]] = 1;
    for (i in control_arr) control_map[control_arr[i]] = 1;

    # Initialize arrays for counting genotypes
    delete unique_samples;
    delete count_het;
    delete count_hom;
    delete count_total;
    delete count_variant;
    delete count_control_het;
    delete count_control_hom;
    delete count_control_variant;
}

{
    # Skip the header line
    if (NR == 1) {
        if (LIST == 0) {
            if (COUNT_GENOTYPES) {
                if (length(control_arr) > 0) {
                    print $0, "proband_count", "proband_variant_count", "proband_allele_count", \
                                "control_count", "control_variant_count", "control_allele_count"
                } else {
                    print $0, "proband_count", "proband_variant_count", "proband_allele_count"
                }
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
    total_count = length(proband_arr);

    control_het_count = 0;
    control_hom_count = 0;
    control_variant_count = 0;
    control_total_count = length(control_arr);

    # Process the GT field
    split($(GT_field), genotypes, ",");
    for (i = 1; i <= length(genotypes); i++) {
        sample = sample_arr[i];
        
        # Replace | with / in the genotype to handle phased genotypes
        gsub(/\|/, "/", genotypes[i]);

        # Detect non-1 GT fields and replace with 1
        if (genotypes[i] ~ /2|3|4|5|6|7|8|9/) {
            genotypes[i] = gensub(/2|3|4|5|6|7|8|9/, "1", "g", genotypes[i]);
            print "Warning: Non-1 GT field detected and replaced with 1 in sample " sample " for genotype " genotypes[i] > "/dev/stderr";
        }

        if (genotypes[i] != "0/0" || (INCLUDE_NOCALLS && genotypes[i] == "./.")) {
            if (genotypes[i] != "./.") {
                unique_samples[sample] = 1;  # Collect unique samples with non-"0/0" genotypes

                if (proband_map[sample]) {
                    if (genotypes[i] == "0/1" || genotypes[i] == "1/0") het_count++;
                    if (genotypes[i] == "1/1") hom_count++;
                    variant_count++;
                }

                if (control_map[sample]) {
                    if (genotypes[i] == "0/1" || genotypes[i] == "1/0") control_het_count++;
                    if (genotypes[i] == "1/1") control_hom_count++;
                    control_variant_count++;
                }
            }
        } else if (INCLUDE_NOCALLS && genotypes[i] == "./.") {
            if (proband_map[sample]) total_count++;
            if (control_map[sample]) control_total_count++;
        }

        if (genotypes[i] != "0/0" && genotypes[i] != "./.") {
            if (APPEND) {
                genotypes[i] = sample "(" genotypes[i] ")";
            } else {
                genotypes[i] = sample;
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
            if (length(control_arr) > 0) {
                print $0, total_count, variant_count, het_count + (2 * hom_count), \
                           control_total_count, control_variant_count, control_het_count + (2 * control_hom_count)
            } else {
                print $0, total_count, variant_count, het_count + (2 * hom_count);
            }
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
