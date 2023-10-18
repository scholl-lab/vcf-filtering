# vcf-filtering

This repository contains scripts and documentation for filtering variant call format (VCF) files to identify rare genetic variants in genes of interest using a streamlined bash script, `filter_variants.sh`.

## Overview

The `filter_variants.sh` script performs the following steps:

1. **Extract Genes of Interest**: Uses `snpEff genes2bed` to produce a BED file containing the genes of interest.
2. **Sort BED File**: Sorts the generated BED file.
3. **Modify BED File**: Adds "chr" prefix to the entries in the BED file if `add_chr` is set to true.
4. **Extract Variants**: Uses `bcftools` to extract the variants in the BED file from the VCF.
5. **Filter for Rare Variants**: Uses `SnpSift` to filter for rare variants based on the provided filter string.
6. **Extract Fields of Interest**: Uses `SnpSift` again to extract the specified fields of interest.
7. **Modify Header**: Removes the "ANN[0]" and "GEN[*]" prefixes from the header.
8. **Replace GT Values**: Uses `replace_gt_with_sample.sh` to replace the GT values with the sample names.
9. **Save Output**: Saves the output to a specified file.

Example of the shell pipeline the script is composing:
```sh
snpEff genes2bed GRCh38.mane.1.0.refseq OFD1 | sortBed | awk '{print "chr"$0}' | bcftools view ann.dbnsfp.vcf.gz -R - \
| SnpSift -Xmx8g filter \
" (( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & \
((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE')) " \
| SnpSift -Xmx4g extractFields -s "," -e "NA" - \
CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P \
dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC \
GEN[*].GT \
| sed -e '1s/ANN\[0\]\.//g; s/GEN\[\*\]\.//g' \
| ./replace_gt_with_sample.sh samples.txt 21 > OFD1_rare_variants.GCKD.tsv
```

## Usage of filter_variants.sh

```sh
./filter_variants.sh [--config config_file] <gene_name> <vcf_file_location> [reference] [add_chr] [filters] [fields_to_extract] [sample_file] [replace_script_location] [output_file]
```

### Parameters:

- `--config config_file`: (Optional) The path to the configuration file containing default values for parameters.
- `gene_name`: The name of the gene of interest, e.g., "BICC1".
- `vcf_file_location`: The location of the VCF file.
- `reference`: (Optional, default: "GRCh38.mane.1.0.refseq") The reference to use.
- `add_chr`: (Optional, default: true) Whether or not to add "chr" to the chromosome name. Use "true" or "false".
- `filters`: (Optional, default: Filters for rare and moderate/high impact variants) The filters to apply.
- `fields_to_extract`: (Optional, default: Various fields including gene info, predictions, allele counts) The fields to extract.
- `sample_file`: (Optional, default: "samples.txt") The path to the file containing the sample values to use for replacement.
- `replace_script_location`: (Optional, default: "./replace_gt_with_sample.sh") The location of the `replace_gt_with_sample.sh` script.
- `replace_script_options`: (Optional) Additional options to pass to the `replace_gt_with_sample.sh` script. This can be used to append genotype values to sample names for non-"0/0" genotypes.
- `output_file`: (Optional, default: "variants.tsv") The name of the output file.

## Configuration File

The script allows users to provide a configuration file containing default values for parameters. The configuration file is sourced if provided, and the values specified in it are used as defaults.

Example of a configuration file:
```sh
reference=GRCh38.mane.1.0.refseq
add_chr=true
filters=(( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & ((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE'))
fields_to_extract=CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC GEN[*].GT
sample_file=samples.txt
replace_script_location=./replace_gt_with_sample.sh
replace_script_options="--append-genotype"
output_file=variants.tsv
```

## Generating the Sample File

To generate the sample file from a multi-sample VCF, you can use the following command:

```sh
bcftools view -h /path/to/your_multi_sample.vcf.gz | awk -F'\t' '{ for (i=10; i<=NF; ++i) printf "%s%s", $i, (i==NF ? RS : ",") }' > /path/to/samplefile.txt
```

## Helper Script: Replace Genotype with Sample

### Overview

The `replace_gt_with_sample.sh` script is utilized by `filter_variants.sh` to replace non-"0/0" genotype values in a specified field with corresponding sample names from a given sample file, and remove "0/0" values.

### Usage

```sh
./replace_gt_with_sample.sh <sample_file> <GT_field_number>
```

### Parameters

- `sample_file`: The path to the file containing the sample values to use for replacement.
- `GT_field_number`: The number of the field (column) in the input stream representing the genotype values.

## Requirements

- GNU Awk 4.2.1, API: 2.0 (GNU MPFR 3.1.6-p2, GNU MP 6.1.2)
- GNU bash, version 4.4.20(1)-release (x86_64-redhat-linux-gnu)
- bcftools 1.17
- snpEff version SnpEff 5.1d (build 2022-04-19 15:49)
- SnpSift version 5.1d (build 2022-04-19 15:50)

# TODO
- [ ] help message should be printed first if no arguments are provided
- [ ] command line arguments should always override config file values
- [ ] add option to filter by position or for specific variants instead of gene name, for variants check the reference allele
- [ ] update README and usage description with examples