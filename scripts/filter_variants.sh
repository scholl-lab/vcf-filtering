#!/bin/bash

# Documentation
# Script Name: filter_variants.sh
# Description: This script filters VCF files to identify rare genetic variants in genes of interest.
# Usage: 
#    ./filter_variants.sh [--config config_file] <gene_name> <vcf_file_location> [reference] [add_chr] [filters] [fields_to_extract] [sample_file] [replace_script_location] [output_file]
# Parameters:
#    --config config_file: (Optional) The path to the configuration file containing default values for parameters.
#    gene_name: The name of the gene of interest, e.g., "BICC1".
#    vcf_file_location: The location of the VCF file.
#    reference: (Optional, default: "GRCh38.mane.1.0.refseq") The reference to use.
#    add_chr: (Optional, default: true) Whether or not to add "chr" to the chromosome name. Use "true" or "false".
#    filters: (Optional, default: Filters for rare and moderate/high impact variants) The filters to apply.
#    fields_to_extract: (Optional, default: Various fields including gene info, predictions, allele counts) The fields to extract.
#    sample_file: (Optional, default: "samples.txt") The path to the file containing the sample values to use for replacement.
#    replace_script_location: (Optional, default: "./replace_gt_with_sample.sh") The location of the replace_gt_with_sample.sh script.
#    output_file: (Optional, default: "variants.tsv") The name of the output file.

# Usage information
print_usage() {
    echo "Usage: $0 [--config config_file] <gene_name> <vcf_file_location> [reference] [add_chr] [filters] [fields_to_extract] [sample_file] [replace_script_location] [output_file]"
    echo "Use --help for more information."
}

print_help() {
    cat << EOF
This script filters VCF files to identify rare genetic variants in genes of interest. The user can specify various parameters, including the gene of interest, the location of the VCF file, the reference to use, and filters to apply. The script then processes the VCF file, applying the specified filters and extracting the relevant fields. The resulting file is saved with the specified name.

Parameters:
    --config config_file: (Optional) The path to the configuration file containing default values for parameters.
    gene_name: The name of the gene of interest, e.g., "BICC1".
    vcf_file_location: The location of the VCF file.
    reference: (Optional, default: "GRCh38.mane.1.0.refseq") The reference to use.
    add_chr: (Optional, default: true) Whether or not to add "chr" to the chromosome name. Use "true" or "false".
    filters: (Optional, default: Filters for rare and moderate/high impact variants) The filters to apply.
    fields_to_extract: (Optional, default: Various fields including gene info, predictions, allele counts) The fields to extract.
    sample_file: (Optional, default: "samples.txt") The path to the file containing the sample values to use for replacement.
    replace_script_location: (Optional, default: "./replace_gt_with_sample.sh") The location of the replace_gt_with_sample.sh script.
    output_file: (Optional, default: "variants.tsv") The name of the output file.

Example:
    ./filter_variants.sh --config my_config.conf BICC1 my_vcf_file.vcf
EOF
}

# Check for --help option
if [[ "$1" == "--help" ]]; then
    print_help
    exit 0
fi

# Check if a configuration file is provided
if [ "$1" == "--config" ]; then
    if [ -z "$2" ]; then
        echo "Error: Configuration file not specified."
        exit 1
    fi
    if [ ! -f "$2" ]; then
        echo "Error: Configuration file $2 not found."
        exit 1
    fi
    
    # Load the configuration file
    source "$2"
    
    # Shift the positional parameters to get the rest of the command line arguments
    shift 2
fi

# Check if the minimum number of arguments is provided
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

# Validate add_chr parameter
if [[ "$4" != "true" && "$4" != "false" ]]; then
    echo "Error: add_chr must be either 'true' or 'false'."
    exit 1
fi

# Validate file existence
for file in "$2" "${7:-$sample_file}" "${8:-$replace_script_location}"; do
    if [ ! -f "$file" ]; then
        echo "Error: File $file not found."
        exit 1
    fi
done

# Assign variables with default values
gene_name="$1"
vcf_file_location="$2"
reference="${3:-${reference:-"GRCh38.mane.1.0.refseq"}}"
add_chr="${4:-${add_chr:-true}}"
filters="${5:-${filters:-"(( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & ((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE'))"}}"
fields_to_extract="${6:-${fields_to_extract:-"CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC GEN[*].GT"}}"
sample_file="${7:-${sample_file:-"samples.txt"}}"
replace_script_location="${8:-${replace_script_location:-"./replace_gt_with_sample.sh"}}"
output_file="${9:-${output_file:-"variants.tsv"}}"

# Informative echo statements
echo "Starting the filtering process for gene: $gene_name"
echo "Using VCF file located at: $vcf_file_location"
# Add more echo statements as needed for each step

# Compute the GT_field_number from the position of "GEN[*].GT" in fields_to_extract
GT_field_number=$(echo "$fields_to_extract" | tr ' ' '\n' | grep -n -E '^GEN\[\*\]\.GT$' | cut -f1 -d:)

# Check if GT_field_number is found
if [ -z "$GT_field_number" ]; then
    echo "Error: GT_field_number could not be computed. Please ensure that \"GEN[*].GT\" is present in fields_to_extract."
    exit 1
fi

# Construct the command pipeline
cmd="snpEff genes2bed \"$reference\" \"$gene_name\" | sortBed"
if [ "$add_chr" == "true" ]; then
    cmd="$cmd | awk '{print \"chr\"\$0}'"
fi
cmd="$cmd | bcftools view \"$vcf_file_location\" -R - | SnpSift -Xmx8g filter \"$filters\" | SnpSift -Xmx4g extractFields -s \",\" -e \"NA\" - \"$fields_to_extract\" | sed -e '1s/ANN\[0\]\.//g; s/GEN\[\*\]\.//g' | \"$replace_script_location\" \"$sample_file\" $GT_field_number > \"$output_file\""

# Execute the command pipeline
eval $cmd
