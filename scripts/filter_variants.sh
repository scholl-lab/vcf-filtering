#!/bin/bash
## filter_variants.sh

# Define a variable for the script's name
SCRIPT_NAME=$(basename "$0")

# Version information
SCRIPT_VERSION="0.22.0"
SCRIPT_DATE="2024-07-14"
SCRIPT_AUTHOR="Bernt Popp, Berlin Institute of Health at Charité, Universitätsmedizin Berlin, Center of Functional Genomics, Berlin, Germany"
SCRIPT_EMAIL="bernt.popp.md@gmail.com"
SCRIPT_REPOSITORY="https://github.com/scholl-lab/vcf-filtering"
SCRIPT_DOCUMENTATION="https://github.com/scholl-lab/vcf-filtering"

# Default values
reference="GRCh38.mane.1.0.refseq"
add_chr=true
filters="(( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & ((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE'))"
fields_to_extract="CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC dbNSFP_clinvar_clnsig GEN[*].GT"
sample_file="samples.txt"
replace_script_location="./replace_gt_with_sample.sh"
replace_script_options=""
convert_to_excel_location="./convert_to_excel.R"            # Default excel conversion script location
convert_to_excel_options=""                                 # Default is empty, meaning no extra options
analyze_variants_location="./analyze_variants.R"            # Default analyze variants script location
phenotype_script_location="./filter_phenotypes.sh"          # Default location
phenotype_script_options=""                                 # Default options
use_phenotype_filtering=false                               # Default is false
use_replacement=true                                        # Default is true
output_file=""                                              # Default is stdout
use_temp_bed_files=true                                     # Default is true
temp_bed_dir="./temp_bed_files"                             # Default temporary directory for BED files
interval_expand=0                                           # Default expansion interval for gene regions
perform_gene_burden=false                                   # Default is false
stats_output_file=""                                        # Default statistics output file

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
# ./$SCRIPT_NAME [-c config_file] [-g gene_name] [-G gene_file] [-v vcf_file_location] [-r reference] [-a add_chr] [-f filters] [-e fields_to_extract] [-s sample_file] [-l replace_script_location] [-R use_replacement] [-o output_file] [-T temp_bed_dir] [-U use_temp_bed_files] [-d interval_expand] [-b gene_burden] [-S stats_output_file]
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
#    -T, --tsv-to-excel-location loc:    (Optional, default: "./convert_to_excel.R") The path to the convert_to_excel.R script.
#    -X, --tsv-to-excel-options opts     (Optional) Additional options for the convert_to_excel.R script.
#    -b, --phenotype-script-location loc:   (Optional, default: "./filter_phenotypes.sh") The path to the filter_phenotypes.sh script.
#    -j, --phenotype-script-options opts:   (Optional) Additional options for the filter_phenotypes.sh script.
#    -k, --use-phenotype-filtering true/false: (Optional, default: false) Whether or not to use phenotype filtering.
#    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
#    -x, --xlsx:                         (Optional) Convert the output to xlsx format.
#    -U, --use-temp-bed-files true/false: (Optional, default: true) Whether or not to use temporary BED files.
#    -T, --temp-bed-dir dir:             (Optional, default: "./temp_bed_files") The directory to store temporary BED files.
#    -d, --interval-expand num:          (Optional, default: 0) Number of bases to expand the gene interval upstream and downstream.
#    -b, --gene-burden:                  (Optional) Perform gene burden analysis.
#    -S, --stats-output-file file:       (Optional) The name of the statistics output file.
#    -V, --version:                      Displays version information.
#    -h, --help:                         Displays help information.

# Example:
# Basic usage:
# ./$SCRIPT_NAME -g BICC1 -v my_vcf_file.vcf
# Advanced usage with multiple options:
# ./$SCRIPT_NAME -c config.cfg -G genes.txt -v my_vcf_file.vcf -r "GRCh38.mane.1.0.refseq" -o output.tsv

# Define cleanup function
cleanup() {
    if [ "$PRINT_VERSION" != true ] && [ "$PRINT_HELP" != true ]; then
        echo "Cleaning up temporary files..."
        rm -f "$temp_output_file" "$phenotype_temp_file" "$filtered_vcf_temp_file" "$filtered_vcf_extracted_fields_temp_file" "$metadata_file"
        echo "Cleanup complete." >&2
    fi
}

# Set cleanup trap
trap cleanup EXIT

# Usage information
print_usage() {
    echo "Usage: $0 [-c config_file] [-g gene_name] [-v vcf_file_location] [-r reference] [-a add_chr] [-f filters] [-e fields_to_extract] [-s sample_file] [-l replace_script_location] [-P replace_script_options] [-R use_replacement] [-o output_file] [-x] [-b phenotype_script_location] [-j phenotype_script_options] [-k use_phenotype_filtering] [-U use_temp_bed_files] [-T temp_bed_dir] [-d interval_expand] [-b gene_burden] [-S stats_output_file]"
    echo "Use -h for more information."
}

print_help() {
    cat << EOF
This script filters VCF files to identify rare genetic variants in genes of interest. The user can specify various parameters, including the gene of interest, the location of the VCF file, the reference to use, and filters to apply. The script then processes the VCF file, applying the specified filters and extracting the relevant fields. The resulting file is saved with the specified name.

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
    -T, --tsv-to-excel-location loc:    (Optional, default: "./convert_to_excel.R") The path to the convert_to_excel.R script.
    -X, --tsv-to-excel-options opts     (Optional) Additional options for the convert_to_excel.R script.
    -b, --phenotype-script-location loc:   (Optional, default: "./filter_phenotypes.sh") The path to the filter_phenotypes.sh script.
    -j, --phenotype-script-options opts:   (Optional) Additional options for the filter_phenotypes.sh script.
    -k, --use-phenotype-filtering true/false: (Optional, default: false) Whether or not to use phenotype filtering.
    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
    -x, --xlsx:                         (Optional) Convert the output to xlsx format.
    -U, --use-temp-bed-files true/false: (Optional, default: true) Whether or not to use temporary BED files.
    -T, --temp-bed-dir dir:             (Optional, default: "./temp_bed_files") The directory to store temporary BED files.
    -d, --interval-expand num:          (Optional, default: 0) Number of bases to expand the gene interval upstream and downstream.
    -b, --gene-burden:                  (Optional) Perform gene burden analysis.
    -S, --stats-output-file file:       (Optional) The name of the statistics output file.
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
    "--phenotype-script-location") set -- "$@" "-b" ;;
    "--phenotype-script-options") set -- "$@" "-j" ;;
    "--use-phenotype-filtering") set -- "$@" "-k" ;;
    "--output_file") set -- "$@" "-o" ;;
    "--xlsx") set -- "$@" "-x" ;;
    "--use-temp-bed-files") set -- "$@" "-U" ;;
    "--temp-bed-dir") set -- "$@" "-T" ;;
    "--interval-expand") set -- "$@" "-d" ;;
    "--gene-burden") set -- "$@" "-b" ;;
    "--stats-output-file") set -- "$@" "-S" ;;
    *) set -- "$@" "$arg"
  esac
done

# Parse command line arguments using getopts
# Create associative arrays to store command line arguments
declare -A args

while getopts ":c:g:G:v:r:a:f:e:s:l:P:R:o:x:T:X:b:j:k:U:d:S:hV" opt; do
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
        T) args["convert_to_excel_location"]="$OPTARG" ;;
        X) args["convert_to_excel_options"]="$OPTARG" ;;
        b) args["phenotype_script_location"]="$OPTARG" ;;
        j) args["phenotype_script_options"]="$OPTARG" ;;
        k) args["use_phenotype_filtering"]="$OPTARG" ;;
        o) args["output_file"]="$OPTARG" ;;
        x)
            args["xlsx"]=true
            ;;
        U) args["use_temp_bed_files"]="$OPTARG" ;;
        T) args["temp_bed_dir"]="$OPTARG" ;;
        d) args["interval_expand"]="$OPTARG" ;;
        S) args["stats_output_file"]="$OPTARG" ;;
        h) 
            PRINT_HELP=true
            print_help
            exit 0
            ;;
        V)
            PRINT_VERSION=true
            echo "$SCRIPT_NAME version $SCRIPT_VERSION, Date $SCRIPT_DATE"
            echo "$SCRIPT_AUTHOR"
            echo "For more information, visit $SCRIPT_REPOSITORY"
            echo "Documentation: $SCRIPT_DOCUMENTATION"
            echo "Help email: $SCRIPT_EMAIL"
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
    gene_name=$(sed -e ':a' -e 'N' -e '$!ba' -e 's/[\n|\r]/ /g' "$gene_file" | sed 's/ $//')
fi

# If a gene name is provided, replace commas in gene_name with spaces
if [ ! -z "$gene_name" ];then
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

# Validate GT field format in VCF
validate_gt_format() {
    local gt_field="$1"
    local alt_field="$2"

    # Check if GT field is in the correct format (allowing both phased and unphased genotypes)
    if ! [[ "$gt_field" =~ ^[0-9][/|][0-9](|:[0-9/|]+)*$ ]]; then
        echo "Error: Invalid GT field format detected: $gt_field"
        exit 1
    fi

    # Handle edge case for GT field with multiple alleles per locus
    if [[ "$alt_field" =~ "," && "$gt_field" =~ [2-9] ]]; then
        echo "Warning: Edge case detected - GT field contains alleles greater or equal to 2 and ALT field has multiple alleles: $alt_field"
        echo "Handling this case gracefully. Recommend manual inspection and splitting multi-allelic sites."
    fi
}

# Validate the GT and ALT fields of filtered VCF rows
validate_filtered_vcf() {
    local vcf_file="$1"
    while IFS=$'\n' read -r line; do
        # Skip header lines
        if [[ "$line" =~ ^#.*$ ]]; then
            continue
        fi

        IFS=$'\t' read -r -a fields <<< "$line"

        alt_field="${fields[4]}"
        for sample_field in "${fields[@]:9}"; do
            gt_field="${sample_field%%:*}"
            validate_gt_format "$gt_field" "$alt_field"
        done
    done < "$vcf_file"
}

# Create a temporary file for metadata
metadata_file=$(mktemp)

# Function to add metadata
add_metadata() {
    echo "$1" >> "$metadata_file"
}

# Adding metadata
add_metadata "Script Name: $SCRIPT_NAME"
add_metadata "Script Version: $SCRIPT_VERSION"
add_metadata "Script Date: $SCRIPT_DATE"
add_metadata "Script Author: $SCRIPT_AUTHOR"
add_metadata "Script Email: $SCRIPT_EMAIL"
add_metadata "Script Repository: $SCRIPT_REPOSITORY"
add_metadata "Script Documentation: $SCRIPT_DOCUMENTATION"
add_metadata "Gene Name: $gene_name"
add_metadata "VCF File Location: $vcf_file_location"
add_metadata "Reference: $reference"
add_metadata "Add Chr: $add_chr"
add_metadata "Filters: $filters"
add_metadata "Fields to Extract: $fields_to_extract"
add_metadata "Starting time: $(date)"
add_metadata "Target gene(s): $gene_name"
add_metadata "VCF source: $vcf_file_location"

# Informative echo statements
# Use >&2 to redirect echo to stderr
echo "---------------------------------------------------------" >&2
echo "$SCRIPT_NAME version $SCRIPT_VERSION, Date $SCRIPT_DATE" >&2
echo "$SCRIPT_AUTHOR" >&2
echo "For more information, visit $SCRIPT_REPOSITORY" >&2
echo "Documentation: $SCRIPT_DOCUMENTATION" >&2
echo "Help email: $SCRIPT_EMAIL" >&2

# Display version information of the scripts used
echo "  Using:" $($replace_script_location --version 2>&1 | head -n 1) >&2
echo "  Using:" $($convert_to_excel_location --version 2>&1 | head -n 1) >&2
echo "  Using:" $($phenotype_script_location --version 2>&1 | head -n 1) >&2

# Display version information of the tools used
echo "  With: snpEff version:" $(snpEff -version 2>&1 | head -n 1) >&2
echo "  With: bcftools version:" $(bcftools --version | head -n 1) >&2
echo "  With: awk version:" $(awk --version | head -n 1) >&2
echo "  With: sed version:" $(sed --version | head -n 1) >&2
echo "  With: tee version:" $(tee --version | head -n 1) >&2
echo "  With: bash version:" $(bash --version | head -n 1) >&2

# Adding version information to metadata
add_metadata "replace_gt_with_sample.sh: $($replace_script_location --version 2>&1 | head -n 1)"
add_metadata "convert_to_excel.R: $($convert_to_excel_location --version 2>&1 | head -n 1)"
add_metadata "filter_phenotypes.sh: $($phenotype_script_location --version 2>&1 | head -n 1)"
add_metadata "snpEff: $(snpEff -version 2>&1 | head -n 1)"
add_metadata "bcftools: $(bcftools --version | head -n 1)"
add_metadata "awk: $(awk --version | head -n 1)"
add_metadata "sed: $(sed --version | head -n 1)"
add_metadata "tee: $(tee --version | head -n 1)"
add_metadata "bash: $(bash --version | head -n 1)"

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

# Create a temporary file for the filtered VCF output
filtered_vcf_temp_file=$(mktemp)

# Create a temporary file for the filtered VCF and extracted output before genotype replacement
filtered_vcf_extracted_fields_temp_file=$(mktemp)

# Create the temporary BED directory if it doesn't exist
mkdir -p "$temp_bed_dir"

# Generate a unique hash for the BED file based on the gene names and interval_expand value
bed_file_hash=$(echo -n "$gene_name-$interval_expand" | md5sum | cut -d' ' -f1)
gene_bed_file="$temp_bed_dir/$bed_file_hash.bed"

# Generate BED file and check for gene presence if not already existing
if [ ! -f "$gene_bed_file" ]; then
    snpEff -Xmx8g genes2bed $reference $gene_name -ud $interval_expand > "$gene_bed_file"
fi

# Extract found genes from the BED file
found_genes=$(awk -F'\t' '{print $NF}' "$gene_bed_file" | cut -d';' -f1 | sort | uniq)

# Convert gene_name to array
IFS=' ' read -r -a gene_name_array <<< "$gene_name"

# Check for missing genes
missing_genes=()
for gene in "${gene_name_array[@]}"; do
    if ! grep -q -w "$gene" <<< "$found_genes"; then
        missing_genes+=("$gene")
    fi
done

# Log missing genes and exit if any are not found
if [ ${#missing_genes[@]} -ne 0 ]; then
    echo "Error: The following gene(s) were not found in the reference: ${missing_genes[*]}" >&2
    exit 1
fi

# Sort the BED file if add_chr is true
if [ "$add_chr" == "true" ]; then
    sortBed < "$gene_bed_file" | awk '{print "chr"$0}' > "$gene_bed_file.sorted"
else
    sortBed < "$gene_bed_file" > "$gene_bed_file.sorted"
fi

# Construct the command pipeline
cmd="bcftools view \"$vcf_file_location\" -R $gene_bed_file.sorted | SnpSift -Xmx8g filter \"$filters\" | tee $filtered_vcf_temp_file | SnpSift -Xmx4g extractFields -s \"|\" -e \"NA\" - $fields_to_extract | sed -e '1s/ANN\[0\]\.//g; s/GEN\[\*\]\.//g' | tee $filtered_vcf_extracted_fields_temp_file"

if [ "$use_replacement" == "true" ]; then
    cmd="$cmd | $replace_script_location $replace_script_options -s $sample_file -g $GT_field_number"
fi

# Complete the command pipeline
cmd="$cmd $cmd_end"

# Execute the command pipeline
eval $cmd

# Validate the GT and ALT fields of filtered VCF rows
validate_filtered_vcf "$filtered_vcf_temp_file"

# Generate comma-separated sample list using 'replace_gt_with_sample.sh' with the '-m' option
if [ "$use_phenotype_filtering" == "true" ]; then
    # Create comma-separated sample list
    comma_separated_samples=$(cat "$filtered_vcf_extracted_fields_temp_file" | $replace_script_location -m -s $sample_file -g $GT_field_number)

    # Create temporary file for phenotype filtering result
    phenotype_temp_file=$(mktemp)

    # Call filter_phenotypes.sh with the comma-separated sample list
    eval "$phenotype_script_location -o $phenotype_temp_file -l \"$comma_separated_samples\" $phenotype_script_options"

    # Check for errors in phenotype filtering
    if [ $? -ne 0 ]; then
        echo "Error in phenotype filtering" >&2
        exit 1
    fi
fi

# Perform gene burden analysis if requested
if [ "$perform_gene_burden" == "true" ]; then
    # Check if required columns are present
    required_columns=("proband_count" "proband_variant_count" "proband_allele_count" "control_count" "control_variant_count" "control_allele_count")
    for col in "${required_columns[@]}"; do
        if ! grep -q "$col" "$filtered_vcf_extracted_fields_temp_file"; then
            echo "Error: Column $col is missing from the input file." >&2
            exit 1
        fi
    done

    # Create temporary file for gene burden analysis result
    burden_temp_file=$(mktemp)

    # Call analyze_variants.R with the input and output files
    eval "$analyze_variants_location -i $filtered_vcf_extracted_fields_temp_file -o $burden_temp_file"

    # Check for errors in gene burden analysis
    if [ $? -ne 0 ]; then
        echo "Error in gene burden analysis" >&2
        exit 1
    fi

    # Merge gene burden analysis results into main output file
    if [ "${args["xlsx"]}" == "true" ]; then
        # Convert the gene burden analysis results to Excel and append to the main output file
        cmd_xlsx_burden="$convert_to_excel_location -i $burden_temp_file -o $output_file -s 'Gene_Burden_Analysis' -a"
        eval $cmd_xlsx_burden
    else
        cat $burden_temp_file >> $output_file
    fi
fi

# After the main processing, add the metadata to the Excel file
if [ "${args["xlsx"]}" == "true" ]; then
    # Convert the main output to Excel
    cmd_xlsx="$convert_to_excel_location -i $temp_output_file -o $output_file -s 'Results' $convert_to_excel_options"
    eval $cmd_xlsx

    # Add metadata to the Excel file in a new sheet
    cmd_xlsx_meta="$convert_to_excel_location -i $metadata_file -o $output_file -s 'Metadata' -a"
    eval $cmd_xlsx_meta
fi

# After adding metadata to Excel file (if requested), add phenotype data to the Excel file (if requested)
if [ "$use_phenotype_filtering" == "true" ]; then
    # Add phenotype data to the Excel file in a new sheet
    cmd_xlsx_phenotype="$convert_to_excel_location -i $phenotype_temp_file -o $output_file -s 'Phenotypes' -a"
    eval $cmd_xlsx_phenotype

    # Cleanup phenotype temporary file
    rm -f $phenotype_temp_file
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
