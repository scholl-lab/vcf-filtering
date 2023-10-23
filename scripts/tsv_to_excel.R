#!/usr/bin/env Rscript

# tsv_to_excel.R
# This script reads a TSV formatted file (or input from stdin) and writes it to an Excel file.
# Author: Bernt Popp
# Date: 2023-10-23

# Version Information
SCRIPT_VERSION <- "0.2.0"
SCRIPT_DATE <- "2023-10-23"

# Load necessary libraries
library(readr)
library(writexl)

# Function to display usage instructions
usage <- function() {
  cat("Usage:\n")
  cat("  ./tsv_to_excel.R -i /path/to/input_file.tsv [-o /path/to/output_file.xlsx] [-s sheet_name]\n")
  cat("  Or, to read from stdin:\n")
  cat("  cat /path/to/input_file.tsv | ./tsv_to_excel.R -i - [-o /path/to/output_file.xlsx] [-s sheet_name]\n")
  cat("Flags:\n")
  cat("  -h, --help: Display this help message\n")
  cat("  -v, --version: Display script version\n")
  cat("  -i, --input: Specify the input TSV file or '-' for stdin\n")
  cat("  -o, --output: Specify the output Excel file (optional)\n")
  cat("  -s, --sheet: Specify the sheet name in the Excel file (optional, defaults to 'data')\n")
}

# Logging function with levels
log_message <- function(message, level = "INFO") {
  cat(sprintf("[%s]: %s\n", level, message))
}

# Fetch command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Initialize variables
input_file <- NULL
output_file <- NULL
sheet_name <- "data"
display_help <- FALSE
display_version <- FALSE

# Parse the command line arguments for flags and values
i <- 1
while (i <= length(args)) {
  arg <- args[i]
  switch(arg,
         '-h' = {display_help <- TRUE},
         '--help' = {display_help <- TRUE},
         '-v' = {display_version <- TRUE},
         '--version' = {display_version <- TRUE},
         '-i' = {i <- i + 1; if(i <= length(args)) {input_file <- args[i]} else {log_message("Missing value for -i flag.", "ERROR"); quit(save="no", status=1)}},
         '--input' = {i <- i + 1; if(i <= length(args)) {input_file <- args[i]} else {log_message("Missing value for --input flag.", "ERROR"); quit(save="no", status=1)}},
         '-o' = {i <- i + 1; output_file <- args[i]},
         '--output' = {i <- i + 1; output_file <- args[i]},
         '-s' = {i <- i + 1; sheet_name <- args[i]},
         '--sheet' = {i <- i + 1; sheet_name <- args[i]}
  )
  i <- i + 1
}

# Display version if the version flag is set
if (display_version) {
  cat(paste("tsv_to_excel.R Version:", SCRIPT_VERSION, "-", SCRIPT_DATE, "\n"))
  quit(save = "no", status = 0)
}

# Display usage if the help flag is set or no input file is provided
if (display_help || is.null(input_file)) {
  usage()
  quit(save = "no", status = 0)
}

# Check input file before reading
if (input_file != "-" && (!file.exists(input_file) || !file.access(input_file, mode = 4) == 0)) {
  log_message(paste("Error reading file:", input_file, ". Ensure it exists and is readable."), "ERROR")
  quit(save="no", status=1)
}

# Check output file before writing
if (!is.null(output_file) && file.exists(output_file) && !file.access(output_file, mode = 2) == 0) {
  log_message(paste("Error writing to file:", output_file, ". It exists but is not writable."), "ERROR")
  quit(save = "no", status = 1)
}

# Decide source of data: stdin or a file
if (input_file == "-") {
  # Read from stdin
  con <- file("stdin")
  # Check if stdin is empty
  if (length(readLines(con, n = 1)) == 0) {
    stop("Error: No data provided in stdin.")
  }
  seek(con, where = 0)
  # Read the data
  log_message("Reading data from stdin...")
  data <- read_tsv(con, col_types = cols())
  close(con)
  # Set output file name. If provided, use that. Otherwise, default to "output.xlsx"
  output_file <- ifelse(!is.null(output_file), output_file, "output.xlsx")
} else {
  # Check if the file exists
  if (!file.exists(input_file)) {
    stop(paste("Error: File", input_file, "does not exist."))
  }
  # Read from the given file path
  log_message(paste("Reading data from", input_file, "..."))
  data <- read_tsv(input_file, col_types = cols())
  # Set output file name. If provided, use that. Otherwise, derive from input file name
  output_file <- ifelse(!is.null(output_file), output_file, gsub("\\.tsv$", ".xlsx", input_file))
}

# Write data to an Excel file with the specified sheet name
log_message(paste("Writing data to", output_file, "in sheet", sheet_name, "..."))
output_list <- setNames(list(data), sheet_name)
write_xlsx(output_list, output_file)
log_message("Operation completed successfully!")
