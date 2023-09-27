# vcf-filtering

This repository contains scripts and documentation for filtering variant call format (VCF) files to identify rare genetic variants in genes of interest.

## Overview

The main command sequence performs the following steps:

1. **Extract Genes of Interest**: Uses `snpEff genes2bed` to produce a BED file containing the genes of interest.
2. **Sort BED File**: Sorts the generated BED file.
3. **Modify BED File**: Adds "chr" prefix to the entries in the BED file.
4. **Extract Variants**: Uses `bcftools` to extract the variants in the BED file from the VCF.
5. **Filter for Rare Variants**: Uses `SnpSift` to filter for rare variants (gnomAD exomes AC <= 2).
6. **Extract Fields of Interest**: Uses `SnpSift` again to extract the fields of interest.
7. **Modify Header**: Removes the "ANN[0]" and "GEN[*]" prefixes from the header.
8. **Replace GT Values**: Uses `replace_gt_with_sample.sh` to replace the GT values with the sample names.
9. **Save Output**: Saves the output to a file.

## Main Command

```sh
# Replace the following placeholders with actual paths, field number, and desired output filename:
# /path/to/your_vcf.vcf.gz
# path/to/samplefile.txt
# field_number
# output_filename.tsv

snpEff genes2bed GRCh38.mane.1.0.refseq BICC1 | sortBed | awk '{print "chr"$0}' | bcftools view /path/to/your_vcf.vcf.gz -R - \
| SnpSift -Xmx8g filter \
" (( dbNSFP_gnomAD_exomes_AC[0] <= 2 ) | ( na dbNSFP_gnomAD_exomes_AC[0] )) & \
((ANN[ANY].IMPACT has 'HIGH') | (ANN[ANY].IMPACT has 'MODERATE')) " \
| SnpSift -Xmx4g extractFields -s "," -e "NA" - \
CHROM POS REF ALT ID QUAL AC ANN[0].GENE ANN[0].FEATUREID ANN[0].EFFECT ANN[0].IMPACT ANN[0].HGVS_C ANN[0].HGVS_P \
dbNSFP_SIFT_pred dbNSFP_Polyphen2_HDIV_pred dbNSFP_MutationTaster_pred dbNSFP_CADD_phred dbNSFP_gnomAD_exomes_AC dbNSFP_gnomAD_genomes_AC dbNSFP_ALFA_Total_AC \
GEN[*].GT \
| sed -e '1s/ANN\[0\]\.//g; s/GEN\[\*\]\.//g' \
| ./replace_gt_with_sample.sh path/to/samplefile.txt field_number > output_filename.tsv
```

## Generating the Sample File

To generate the sample file from a multi-sample VCF, you can use the following command:

```sh
bcftools view -h path/to/your_multi_sample.vcf.gz | awk -F'\t' '{ for (i=10; i<=NF; ++i) printf "%s%s", $i, (i==NF ? RS : ",") }' > path/to/samplefile.txt
```

## Helper Script: Replace Genotype with Sample

### Overview

The `replace_gt_with_sample.sh` script is used in the main command sequence to replace non-"0/0" genotype values in a specified field with corresponding sample names from a given sample file, and remove "0/0" values.

### Usage

```sh
./replace_gt_with_sample.sh <sample_file> <GT_field_number>
```

### Parameters

- `sample_file`: The path to the file containing the sample values to use for replacement.
- `GT_field_number`: The number of the field (column) in the input stream representing the genotype values.

## Requirements

- Bash
- AWK
- bcftools
- snpEff
- SnpSift
