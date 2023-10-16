#!/bin/bash

# Documentation
# -------------
#
# Overview:
# Script Name: filter_variants.sh
# The filter_variants script is designed to process VCF files to filter and identify 
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
# ./filter_variants.sh [-c config_file] [-g gene_name] [-G gene_file] [-v vcf_file_location] [-r reference] [-a add_chr] [-f filters] [-e fields_to_extract] [-s sample_file] [-l replace_script_location] [-R use_replacement] [-o output_file]
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
#    -R, --use_replacement true/false:     (Optional, default: true) Whether or not to use the replacement script.
#    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
#    -h, --help:                         Displays help information.
#
# Example:
# Basic usage:
# ./filter_variants.sh -g BICC1 -v my_vcf_file.vcf
# Advanced usage with multiple options:
# ./filter_variants.sh -c config.cfg -G genes.txt -v my_vcf_file.vcf -r "GRCh38.mane.1.0.refseq" -o output.tsv

# Usage information
print_usage() {
    echo "Usage: $0 [-c config_file] [-g gene_name] [-v vcf_file_location] [-r reference] [-a add_chr] [-f filters] [-e fields_to_extract] [-s sample_file] [-l replace_script_location] [-o output_file]"
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
    -R, --use_replacement true/false:     (Optional, default: true) Whether or not to use the replacement script.
    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
    -h, --help:                         Displays help information.

Example:
    ./filter_variants.sh -g BICC1 -v my_vcf_file.vcf -o output.tsv
EOF
}

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
    "--output_file") set -- "$@" "-o" ;;
    *) set -- "$@" "$arg"
  esac
done

# Parse command line arguments using getopts
while getopts ":c:g:G:v:r:a:f:e:s:l:R:o:h" opt; do
    case $opt in
        c)
            config_file="$OPTARG"
            ;;
        g)
            gene_name="$OPTARG"
            ;;
        G)
            gene_file="$OPTARG"
            ;;
        v)
            vcf_file_location="$OPTARG"
            ;;
        r)
            reference="$OPTARG"
            ;;
        a)
            add_chr="$OPTARG"
            ;;
        f)
            filters="$OPTARG"
            ;;
        e)
            fields_to_extract="$OPTARG"
            ;;
        s)
            sample_file="$OPTARG"
            ;;
        l)
            replace_script_location="$OPTARG"
            ;;
        R)
            use_replacement="$OPTARG"
            ;;
        o)
            output_file="$OPTARG"
            ;;
        h)
            print_help
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
if [ ! -z "$config_file" ]; then
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file $config_file not found."
        exit 1
    fi
    # Try to source it and catch potential errors
    source "$config_file" 2>/dev/null || { echo "Error: Failed to source the configuration file $config_file. Check its contents."; exit 1; }
fi

# After parsing the arguments, check if both -g and -G are provided or neither:
if [ ! -z "$gene_name" ] && [ ! -z "$gene_file" ]; then
    echo "Error: You can provide either a gene name using -g or a gene file using -G, but not both." >&2
    exit 1
elif [ -z "$gene_name" ] && [ -z "$gene_file" ]; then
    echo "Error: You must provide either a gene name using -g or a gene file using -G." >&2
    exit 1
fi

# Assign default values if not set
gene_name="${gene_name:-$1}"
vcf_file_location="${vcf_file_location:-$2}"
reference="${reference:-${3:-"GRCh38.mane.1.0.refseq"}}"
add_chr="${add_chr:-${4:-true}}"
filters="${filters:-${5:-"(( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & ((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE'))"}}"
fields_to_extract="${fields_to_extract:-${6:-"CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC GEN[*].GT"}}"
sample_file="${sample_file:-${7:-"samples.txt"}}"
# By default, use the replacement script
replace_script_location="${replace_script_location:-${"./replace_gt_with_sample.sh"}}"
use_replacement="${use_replacement:-true}"

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

# Informative echo statements
# Use >&2 to redirect echo to stderr
echo "---------------------------------------------------------" >&2
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

# Modify the cmd to direct output appropriately
cmd_end=" | tee /dev/stdout"
if [ ! -z "$output_file" ]; then
    cmd_end=" > $output_file"
fi

# Construct the command pipeline
cmd="snpEff genes2bed $reference $gene_name | sortBed"
if [ "$add_chr" == "true" ]; then
    cmd="$cmd | awk '{print \"chr\"\$0}'"
fi

cmd="$cmd | bcftools view \"$vcf_file_location\" -R - | SnpSift -Xmx8g filter \"$filters\" | SnpSift -Xmx4g extractFields -s \",\" -e \"NA\" - $fields_to_extract | sed -e '1s/ANN\[0\]\.//g; s/GEN\[\*\]\.//g'"

if [ "$use_replacement" == "true" ]; then
    cmd="$cmd | $replace_script_location $replace_script_options $sample_file $GT_field_number"
fi

cmd="$cmd $cmd_end"

# Execute the command pipeline
eval $cmd

# Informative echo statements
# Use >&2 to redirect echo to stderr
echo "---------------------------------------------------------" >&2
echo "Variant filtering process completed successfully!" >&2
echo "Completion time: $(date)" >&2
if [[ -n "$output_file" && "$output_file" != "stdout" ]]; then
    echo "Output saved to: $output_file" >&2
fi
echo "---------------------------------------------------------" >&2