#!/bin/bash

# Documentation
# Script Name: filter_variants.sh
# Description: This script filters VCF files to identify rare genetic variants in genes of interest.
# Usage: 
#    ./filter_variants.sh [-c config_file] [-g gene_name] [-v vcf_file_location] [-r reference] [-a add_chr] [-f filters] [-e fields_to_extract] [-s sample_file] [-l replace_script_location] [-o output_file]
# Parameters:
#    -c, --config config_file:           (Optional) The path to the configuration file containing default values for parameters.
#    -g, --gene_name gene_name:          The name of the gene of interest. Can be a comma-separated list of genes.
#    -v, --vcf_file_location location:   The location of the VCF file.
#    -r, --reference reference:          (Optional, default: "GRCh38.mane.1.0.refseq") The reference to use.
#    -a, --add_chr true/false:           (Optional, default: true) Whether or not to add "chr" to the chromosome name.
#    -f, --filters filters:              (Optional, default: Filters for rare and moderate/high impact variants) The filters to apply.
#    -e, --fields_to_extract fields:     (Optional, default: Various fields including gene info, predictions, allele counts) The fields to extract.
#    -s, --sample_file file:             (Optional, default: "samples.txt") The path to the file containing the sample values to use for replacement.
#    -l, --replace_script_location loc:  (Optional, default: "./replace_gt_with_sample.sh") The location of the replace_gt_with_sample.sh script.
#    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
#    -h, --help:                         Displays help information.

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
    -v, --vcf_file_location location:   The location of the VCF file.
    -r, --reference reference:          (Optional, default: "GRCh38.mane.1.0.refseq") The reference to use.
    -a, --add_chr true/false:           (Optional, default: true) Whether or not to add "chr" to the chromosome name.
    -f, --filters filters:              (Optional, default: Filters for rare and moderate/high impact variants) The filters to apply.
    -e, --fields_to_extract fields:     (Optional, default: Various fields including gene info, predictions, allele counts) The fields to extract.
    -s, --sample_file file:             (Optional, default: "samples.txt") The path to the file containing the sample values to use for replacement.
    -l, --replace_script_location loc:  (Optional, default: "./replace_gt_with_sample.sh") The location of the replace_gt_with_sample.sh script.
    -o, --output_file name:             (Optional, default: stdout if not set) The name of the output file.
    -h, --help:                         Displays help information.

Example:
    ./filter_variants.sh -g BICC1 -v my_vcf_file.vcf -o output.tsv
EOF
}

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--config") set -- "$@" "-c" ;;
    "--gene_name") set -- "$@" "-g" ;;
    "--vcf_file_location") set -- "$@" "-v" ;;
    "--reference") set -- "$@" "-r" ;;
    "--add_chr") set -- "$@" "-a" ;;
    "--filters") set -- "$@" "-f" ;;
    "--fields_to_extract") set -- "$@" "-e" ;;
    "--sample_file") set -- "$@" "-s" ;;
    "--replace_script_location") set -- "$@" "-l" ;;
    "--output_file") set -- "$@" "-o" ;;
    *) set -- "$@" "$arg"
  esac
done

# Parse command line arguments using getopts
while getopts ":c:g:v:r:a:f:e:s:l:o:h" opt; do
    case $opt in
        c)
            config_file="$OPTARG"
            ;;
        g)
            gene_name="$OPTARG"
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

# If a config file is provided, load it
if [ ! -z "$config_file" ]; then
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file $config_file not found."
        exit 1
    fi
    source "$config_file"
fi

# Assign default values if not set
gene_name="${gene_name:-$1}"
vcf_file_location="${vcf_file_location:-$2}"
reference="${reference:-${3:-"GRCh38.mane.1.0.refseq"}}"
add_chr="${add_chr:-${4:-true}}"
filters="${filters:-${5:-"(( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & ((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE'))"}}"
fields_to_extract="${fields_to_extract:-${6:-"CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC GEN[*].GT"}}"
sample_file="${sample_file:-${7:-"samples.txt"}}"
replace_script_location="${replace_script_location:-${8:-"./replace_gt_with_sample.sh"}}"

# Check if the minimum number of arguments is provided
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

# Replace commas in gene_name with spaces
gene_name=$(echo "$gene_name" | tr ',' ' ')

# Validate add_chr parameter
if [[ "$add_chr" != "true" && "$add_chr" != "false" ]]; then
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
cmd="$cmd | bcftools view \"$vcf_file_location\" -R - | SnpSift -Xmx8g filter \"$filters\" | SnpSift -Xmx4g extractFields -s \",\" -e \"NA\" - $fields_to_extract | sed -e '1s/ANN\[0\]\.//g; s/GEN\[\*\]\.//g' | $replace_script_location $replace_script_options $sample_file $GT_field_number $cmd_end"
# Execute the command pipeline
eval $cmd
