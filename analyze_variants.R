#!/usr/bin/env Rscript

# analyze_variants.R
# This script reads a TSV formatted file, calculates basic statistics, performs gene burden analysis with Fisher's exact test, and writes the results to an output file.
# Author: Bernt Popp
# Date: 2024-07-13

# Version Information
SCRIPT_VERSION <- "0.5.0"
SCRIPT_DATE <- "2024-07-13"

# Load necessary libraries
library(dplyr)
library(readr)
library(tidyr)
library(stats)

# Function to display usage instructions
usage <- function() {
  cat("Usage:\n")
  cat("  analyze_variants.R -i /path/to/input_file -o /path/to/output_file [-s stats_file] [-g] [-h] [-v]\n")
  cat("Flags:\n")
  cat("  -h, --help: Display this help message\n")
  cat("  -v, --version: Display script version\n")
  cat("  -i, --input: Specify the input file\n")
  cat("  -o, --output: Specify the output file\n")
  cat("  -s, --stats: Specify the statistics output file (optional)\n")
  cat("  -g, --gene-burden: Perform gene burden analysis (optional)\n")
}

# Logging function with levels
log_message <- function(message, level = "INFO") {
  cat(sprintf("[%s] %s\n", level, message))
}

# Function to perform gene burden analysis
perform_gene_burden_analysis <- function(data) {
  data %>%
    group_by(GENE) %>%
    summarise(
      proband_alleles = sum(proband_allele_count),
      control_alleles = sum(control_allele_count),
      max_proband_count = max(proband_count),
      max_control_count = max(control_count),
      proband_ref_alleles = sum(max_proband_count * 2 - proband_allele_count),
      control_ref_alleles = sum(max_control_count * 2 - control_allele_count),
      fisher_p_value = {
        table <- matrix(c(proband_alleles, control_alleles, proband_ref_alleles, control_ref_alleles), nrow = 2)
        fisher.test(table)$p.value
      }
    )
}

# Fetch command line arguments
script_args <- commandArgs(trailingOnly = TRUE)

# Initialize variables
input_file <- NULL
output_file <- NULL
stats_file <- NULL
perform_gene_burden <- FALSE
display_help <- FALSE
display_version <- FALSE

# Parse the command line arguments for flags and values
i <- 1
while (i <= length(script_args)) {
  arg <- script_args[i]
  switch(arg,
         '-h' = {display_help <- TRUE},
         '--help' = {display_help <- TRUE},
         '-v' = {display_version <- TRUE},
         '--version' = {display_version <- TRUE},
         '-i' = {i <- i + 1; input_file <- script_args[i]},
         '--input' = {i <- i + 1; input_file <- script_args[i]},
         '-o' = {i <- i + 1; output_file <- script_args[i]},
         '--output' = {i <- i + 1; output_file <- script_args[i]},
         '-s' = {i <- i + 1; stats_file <- script_args[i]},
         '--stats' = {i <- i + 1; stats_file <- script_args[i]},
         '-g' = {perform_gene_burden <- TRUE},
         '--gene-burden' = {perform_gene_burden <- TRUE}
  )
  i <- i + 1
}

# Display version if the version flag is set
if (display_version) {
  cat(sprintf("analyze_variants.R version %s, Date %s\n", SCRIPT_VERSION, SCRIPT_DATE))
  quit(save = "no", status = 0)
}

# Display usage if the help flag is set or no input file is provided
if (display_help || is.null(input_file) || is.null(output_file)) {
  usage()
  quit(save = "no", status = 0)
}

# Check input file before reading
if (!file.exists(input_file)) {
  log_message(sprintf("Error reading file: %s. Ensure it exists and is readable.", input_file), "ERROR")
  quit(save = "no", status = 1)
}

# Read the input file
log_message(sprintf("Reading data from %s...", input_file))
data <- read_tsv(input_file, col_types = cols())

# Check for required columns
required_columns <- c("CHROM", "POS", "REF", "ALT", "GENE", "GT", "proband_count", "proband_allele_count", "control_count", "control_allele_count")
missing_columns <- setdiff(required_columns, colnames(data))

if (length(missing_columns) > 0) {
  log_message(sprintf("Missing required columns: %s", paste(missing_columns, collapse = ", ")), "ERROR")
  quit(save = "no", status = 1)
}

# Calculate basic statistics
log_message("Calculating basic statistics...")
num_variants <- nrow(data)
num_samples <- length(unique(unlist(strsplit(data$GT, ";"))))
num_genes <- length(unique(data$GENE))
het_counts <- sum(grepl("0/1", data$GT, fixed = TRUE))
hom_counts <- sum(grepl("1/1", data$GT, fixed = TRUE))
variant_types <- data %>% count(EFFECT)
impact_types <- data %>% count(IMPACT)

# Print statistics
cat(sprintf("Number of variants: %d\n", num_variants))
cat(sprintf("Number of samples: %d\n", num_samples))
cat(sprintf("Number of genes: %d\n", num_genes))
cat(sprintf("Het counts: %d\n", het_counts))
cat(sprintf("Hom counts: %d\n", hom_counts))
cat("Variant types:\n")
print(variant_types)
cat("Impact types:\n")
print(impact_types)

# Perform gene burden analysis if flag is set
if (perform_gene_burden) {
  log_message("Performing gene burden analysis with Fisher's exact test...")
  burden_analysis <- perform_gene_burden_analysis(data)

  # Write results to output file
  log_message(sprintf("Writing gene burden analysis results to %s...", output_file))
  write_tsv(burden_analysis, output_file)
} else {
  log_message("Skipping gene burden analysis...")
}

# Optionally, write statistics to a separate file
if (!is.null(stats_file)) {
  log_message(sprintf("Writing statistics to %s...", stats_file))
  stats <- data.frame(
    metric = c("Number of variants", "Number of samples", "Number of genes", "Het counts", "Hom counts"),
    value = c(num_variants, num_samples, num_genes, het_counts, hom_counts)
  )
  write_tsv(stats, stats_file, col_names = FALSE)

  # Add variant and impact types to the statistics file
  write_tsv(variant_types, file = stats_file, append = TRUE)
  write_tsv(impact_types, file = stats_file, append = TRUE)
}

log_message("Analysis complete.")
