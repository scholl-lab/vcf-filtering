#!/bin/bash

# Define a variable for the script's name
SCRIPT_NAME=$(basename "$0")

# Version information
SCRIPT_VERSION="0.12.0"
SCRIPT_DATE="2023-11-16"

# Default values
reference="GRCh38.mane.1.0.refseq"
add_chr=true
filters="(( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & ((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE'))"
fields_to_extract="CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC dbNSFP_clinvar_clnsig GEN[*].GT"
sample_file="samples.txt"
replace_script_location="./replace_gt_with_sample.sh"
replace_script_options="--append-genotype"
tsv_to_excel_location="./tsv_to_excel.R"  # Default excel conversion script location
tsv_to_excel_options=""  # Default is empty, meaning no extra options
use_replacement=true
output_file=""

# Documentation
# -------------
#
# Overview:
# Script Name: $SCRIPT_NAME, Version: $SCRIPT_VERSION $SCRIPT_DATE
# The $SCRIPT_NAME script is designed to process VCF files to filter and identify 
# rare genetic variants in genes of interest using a combination of tools like snpEff, 
# bcftools, and SnpSift. The script can also replace genotype information with samples, 
# apply various filters, and extract specific fields from the VCF.
#
# Requirements:
# - snpEff
# - bcftools
# - SnpSift
#
# Compatibility:
#    Tested with:
#    - GNU Awk 4.2.1, API: 2.0 (GNU MPFR 3.1.6-p2, GNU MP 6.1.2)
#    - GNU bash, version 4.4.20(1)-release (x86_64-redhat-linux-gnu)
#    - bcftools 1.17
#    - snpEff version SnpEff 5.1d (build 2022-04-19 15:49)
#    - SnpSift version 5.1d (build 2022-04-19 15:50)
#
# Usage:
# ./$SCRIPT_NAME [-c config_file] [-g gene_name] [-G gene_file] [-v vcf_file_location] [-r reference] [-a add_chr] [-f filters] [-e fields_to_extract] [-s sample_file] [-l replace_script_location] [-R use_replacement] [-o output_file]
#
# Detailed Options:
#    -c, --config config_file:           (Optional) The path to the configuration file containing default values for parameters.
#    -g, --gene_name gene_name:          The name of the gene of interest. Can be a comma-separated list of genes.
#    -G, --gene_file gene_file:          The path to the file containing gene names, one on each line.
#    -v, --vcf_file_location location:   The location of the VCF file.
#    -r, --reference reference:          (Optional, default: "GRCh38.mane.1.0.refseq") The reference to use.
#    -a, --add_chr true/false:           (Optional, default: true) Whether or not to add "chr" to the chromosome name.
#    -f, --filters filters:              (Optional, default: Filters for rare and moderate/high impact variants) The filters to apply.
#    -e, --fields_to_extract fields:     (Optional, default: Various fields including gene info, predictions, allele counts) The fields to extract.
#    -s, --sample_file file:             (Optional, default: "samples.txt") The path to the file containing the sample values to use for replacement.
#    -l, --replace_script_location loc:  (Optional, default: "./replace_gt_with_sample.sh") The location of the replace_gt_with_sample.sh script.
#    -R, --use_replacement true/false:   (Optional, default: true) Whether or not to use the replacement script.
#    -P, --replace_script_options opts:  (Optional) Additional options for the replace_gt_with_sample.sh script.
#    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
#    -x, --xlsx:                         (Optional) Convert the output to xlsx format.
#    -V, --version:                      Displays version information.
#    -h, --help:                         Displays help information.
#
# Example:
# Basic usage:
# ./$SCRIPT_NAME -g BICC1 -v my_vcf_file.vcf
# Advanced usage with multiple options:
# ./$SCRIPT_NAME -c config.cfg -G genes.txt -v my_vcf_file.vcf -r "GRCh38.mane.1.0.refseq" -o output.tsv

# Usage information
print_usage() {
    echo "Usage: $0 [-c config_file] [-g gene_name] [-v vcf_file_location] [-r reference] [-a add_chr] [-f filters] [-e fields_to_extract] [-s sample_file] [-l replace_script_location] [-P replace_script_options] [-R use_replacement] [-o output_file] [-x]"
    echo "Use -h for more information."
}

print_help() {
    cat << EOF
This script filters VCF files to identify rare genetic variants in genes of interest. The user can specify various parameters, including the gene of interest, the location of the VCF file, the reference to use, and filters to apply. The script then processes the VCF file, applying the specified filters and extracting the relevant fields. The resulting file is saved with the specified name.

Parameters:
    -c, --config config_file:           (Optional) The path to the configuration file containing default values for parameters.
    -g, --gene_name gene_name:          The name of the gene of interest. Can be a comma-separated list of genes.
    -G, --gene_file gene_file:          The path to the file containing gene names, one on each line.
    -v, --vcf_file_location location:   The location of the VCF file.
    -r, --reference reference:          (Optional, default: "GRCh38.mane.1.0.refseq") The reference to use.
    -a, --add_chr true/false:           (Optional, default: true) Whether or not to add "chr" to the chromosome name.
    -f, --filters filters:              (Optional, default: Filters for rare and moderate/high impact variants) The filters to apply.
    -e, --fields_to_extract fields:     (Optional, default: Various fields including gene info, predictions, allele counts) The fields to extract.
    -s, --sample_file file:             (Optional, default: "samples.txt") The path to the file containing the sample values to use for replacement.
    -l, --replace_script_location loc:  (Optional, default: "./replace_gt_with_sample.sh") The location of the replace_gt_with_sample.sh script.
    -R, --use_replacement true/false:   (Optional, default: true) Whether or not to use the replacement script.
    -P, --replace_script_options opts:  (Optional) Additional options for the replace_gt_with_sample.sh script.
    -T, --tsv-to-excel-location loc:   (Optional, default: "./tsv_to_excel.R") The path to the tsv_to_excel.R script.
    -X, --tsv-to-excel-options opts:   (Optional) Additional options for the tsv_to_excel.R script.
    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
    -x, --xlsx:                         (Optional) Convert the output to xlsx format.
    -V, --version:                      Displays version information.
    -h, --help:                         Displays help information.

Example:
    ./$SCRIPT_NAME -g BICC1 -v my_vcf_file.vcf -o output.tsv
EOF
}

# If no arguments are provided, print the help message and exit
if [ "$#" -eq 0 ]; then
    print_help
    exit 0
fi

# Check if required programs are installed and accessible.
command -v snpEff >/dev/null 2>&1 || { echo >&2 "snpEff is required but it's not installed. Aborting."; exit 1; }
command -v bcftools >/dev/null 2>&1 || { echo >&2 "bcftools is required but it's not installed. Aborting."; exit 1; }
command -v SnpSift >/dev/null 2>&1 || { echo >&2 "SnpSift is required but it's not installed. Aborting."; exit 1; }

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--config") set -- "$@" "-c" ;;
    "--gene_name") set -- "$@" "-g" ;;
    "--gene_file") set -- "$@" "-G" ;;
    "--vcf_file_location") set -- "$@" "-v" ;;
    "--reference") set -- "$@" "-r" ;;
    "--add_chr") set -- "$@" "-a" ;;
    "--filters") set -- "$@" "-f" ;;
    "--fields_to_extract") set -- "$@" "-e" ;;
    "--sample_file") set -- "$@" "-s" ;;
    "--replace_script_location") set -- "$@" "-l" ;;
    "--use_replacement") set -- "$@" "-R" ;;
    "--replace_script_options") set -- "$@" "-P" ;;
    "--tsv-to-excel-location") set -- "$@" "-T" ;;
    "--tsv-to-excel-options") set -- "$@" "-X" ;;
    "--output_file") set -- "$@" "-o" ;;
    "--xlsx") set -- "$@" "-x" ;;
    *) set -- "$@" "$arg"
  esac
done

# Parse command line arguments using getopts
# Create associative arrays to store command line arguments
declare -A args

while getopts ":c:g:G:v:r:a:f:e:s:l:P:R:o:x:T:X:hV" opt; do
    case $opt in
        c) args["config_file"]="$OPTARG" ;;
        g) args["gene_name"]="$OPTARG" ;;
        G) args["gene_file"]="$OPTARG" ;;
        v) args["vcf_file_location"]="$OPTARG" ;;
        r) args["reference"]="$OPTARG" ;;
        a) args["add_chr"]="$OPTARG" ;;
        f) args["filters"]="$OPTARG" ;;
        e) args["fields_to_extract"]="$OPTARG" ;;
        s) args["sample_file"]="$OPTARG" ;;
        l) args["replace_script_location"]="$OPTARG" ;;
        R) args["use_replacement"]="$OPTARG" ;;
        P) args["replace_script_options"]="$OPTARG" ;;
        T) tsv_to_excel_location="$OPTARG" ;;
        X) tsv_to_excel_options="$OPTARG" ;;
        o) args["output_file"]="$OPTARG" ;;
        x)
            args["xlsx"]=true
            ;;
        h) 
            print_help
            exit 0
            ;;
        V)
            echo "$SCRIPT_NAME version $SCRIPT_VERSION, Date $SCRIPT_DATE";
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

# Error checking for the configuration file sourcing.
if [ ! -z "${args["config_file"]}" ]; then
    source "${args["config_file"]}"
fi

# Override any settings with command line arguments:
for key in "${!args[@]}"; do
    if [ ! -z "${args[$key]}" ]; then
        declare $key="${args[$key]}"
    fi
done

# After parsing the arguments, check if both -g and -G are provided or neither:
if [ ! -z "$gene_name" ] && [ ! -z "$gene_file" ]; then
    echo "Error: You can provide either a gene name using -g or a gene file using -G, but not both." >&2
    exit 1
elif [ -z "$gene_name" ] && [ -z "$gene_file" ]; then
    echo "Error: You must provide either a gene name using -g or a gene file using -G." >&2
    exit 1
fi

# Check if use_replacement is set to true and sample_file is not provided, then compute the sample names from the VCF header.
if [ "$use_replacement" == "true" ] && [ -z "$sample_file" ]; then
    # Extract VCF header, then use grep and awk to parse the sample names
    sample_names=$(bcftools view -h "$vcf_file_location" | grep "#CHROM" | awk '{ for(i=10; i<=NF; i++) print $i }' | sed -e ':a' -e 'N' -e '$!ba' -e 's/[\n|\r]/\,/g')
    
    # Create a temporary file to store the sample names
    sample_file=$(mktemp)
    echo "$sample_names" > "$sample_file"
fi

# Check if the minimum number of arguments is provided
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

# If a gene file is provided, read its contents into gene_name and replace newlines with spaces
if [ ! -z "$gene_file" ]; then
    if [ ! -f "$gene_file" ]; then
        echo "Error: Gene file $gene_file not found." >&2
        exit 1
    fi
    # Handle both Unix and Windows newlines
    # based on https://stackoverflow.com/questions/1251999/how-can-i-replace-each-newline-n-with-a-space-using-sed
    gene_name=$(sed -e ':a' -e 'N' -e '$!ba' -e 's/[\n|\r]/ /g' "$gene_file" | sed 's/ $//')
fi

# If a gene name is provided, replace commas in gene_name with spaces
if [ ! -z "$gene_name" ]; then
    gene_name=$(echo "$gene_name" | tr ',' ' ')
fi

# Validate add_chr parameter
if [[ "$add_chr" != "true" && "$add_chr" != "false" ]]; then
    echo "Error: add_chr must be either 'true' or 'false'." >&2
    exit 1
fi

# Validation for provided files
declare -a files_to_check=("$vcf_file_location")

if [ ! -z "$gene_file" ]; then
    files_to_check+=("$gene_file")
fi
files_to_check+=("$sample_file")
if [ "$use_replacement" == "true" ]; then
    files_to_check+=("$replace_script_location")
fi

for file in "${files_to_check[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: File $file not found." >&2
        exit 1
    fi
done

# Create a temporary file for metadata
metadata_file=$(mktemp)

# Function to add metadata
add_metadata() {
    echo "$1" >> "$metadata_file"
}

# Adding metadata
add_metadata "Script Name: $SCRIPT_NAME"
add_metadata "Version: $SCRIPT_VERSION"
add_metadata "Date: $SCRIPT_DATE"
add_metadata "Gene Name: $gene_name"
add_metadata "VCF File Location: $vcf_file_location"
add_metadata "Reference: $reference"
add_metadata "Add Chr: $add_chr"
add_metadata "Filters: $filters"
add_metadata "Fields to Extract: $fields_to_extract"

# Informative echo statements
# Use >&2 to redirect echo to stderr
echo "---------------------------------------------------------" >&2
echo "$SCRIPT_NAME version $SCRIPT_VERSION, Date $SCRIPT_DATE" >&2

# Display version information of the scripts used
echo "  Using:" $($replace_script_location --version 2>&1 | head -n 1) >&2
echo "  Using:" $(./tsv_to_excel.R --version 2>&1 | head -n 1) >&2

# Display version information of the tools used
echo "  With: snpEff version:" $(snpEff -version 2>&1 | head -n 1) >&2
echo "  With: bcftools version:" $(bcftools --version | head -n 1) >&2

echo "Initiating the variant filtering process..." >&2
echo "Starting time: $(date)" >&2
echo "Target gene(s): $gene_name" >&2
echo "VCF source: $vcf_file_location" >&2
echo "---------------------------------------------------------" >&2

# Compute the GT_field_number from the position of "GEN[*].GT" in fields_to_extract
GT_field_number=$(echo "$fields_to_extract" | tr ' ' '\n' | grep -n -E '^GEN\[\*\]\.GT$' | cut -f1 -d:)

# Check if GT_field_number is found
if [ -z "$GT_field_number" ]; then
    echo "Error: GT_field_number could not be computed. Please ensure that \"GEN[*].GT\" is present in fields_to_extract." >&2
    exit 1
fi

# Create a temporary file for intermediate output if xlsx conversion is requested
if [ "${args["xlsx"]}" == "true" ]; then
    temp_output_file=$(mktemp)
    cmd_end=" > $temp_output_file"
else
    if [ ! -z "$output_file" ]; then
        cmd_end=" > $output_file"
    fi
fi

# Construct the command pipeline
cmd="snpEff genes2bed $reference $gene_name | sortBed"
if [ "$add_chr" == "true" ]; then
    cmd="$cmd | awk '{print \"chr\"\$0}'"
fi

cmd="$cmd | bcftools view \"$vcf_file_location\" -R - | SnpSift -Xmx8g filter \"$filters\" | SnpSift -Xmx4g extractFields -s \",\" -e \"NA\" - $fields_to_extract | sed -e '1s/ANN\[0\]\.//g; s/GEN\[\*\]\.//g'"

if [ "$use_replacement" == "true" ]; then
    cmd="$cmd | $replace_script_location $replace_script_options -s $sample_file -g $GT_field_number"
fi

cmd="$cmd $cmd_end"

# Execute the command pipeline
eval $cmd

# After the main processing, add the metadata to the Excel file
if [ "${args["xlsx"]}" == "true" ]; then
    # Convert the main output to Excel
    cmd_xlsx="$tsv_to_excel_location -i $temp_output_file -o $output_file -s 'Results' $tsv_to_excel_options"
    eval $cmd_xlsx

    # Add metadata to the Excel file in a new sheet
    cmd_xlsx_meta="$tsv_to_excel_location -i $metadata_file -o $output_file -s 'Metadata' -a"
    eval $cmd_xlsx_meta

    # Cleanup
    rm -f $temp_output_file
    rm -f $metadata_file
fi

# Informative echo statements
# Use >&2 to redirect echo to stderr
echo "---------------------------------------------------------" >&2
echo "Variant filtering process completed successfully!" >&2
echo "Filter command executed:" >&2
echo "$cmd" >&2
echo "Completion time: $(date)" >&2
if [[ -n "$output_file" && "$output_file" != "stdout" ]]; then
    echo "Output saved to: $output_file" >&2
fi
echo "---------------------------------------------------------" >&2