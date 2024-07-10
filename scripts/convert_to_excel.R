#!/usr/bin/env Rscript

# convert_to_excel.R
# This script reads a TSV formatted file (or input from stdin) and writes it to an Excel file.
# Author: Bernt Popp
# Date: 2023-11-16

# Version Information
SCRIPT_VERSION <- "0.5.0"
SCRIPT_DATE <- "2023-11-20"

# Load necessary libraries
library(readr)
library(writexl)
library(openxlsx)

# Function to display usage instructions
usage <- function() {
  cat("Usage:\n")
  cat(paste0("  ", script_name, " -i /path/to/input_file [-o /path/to/output_file.xlsx] [-d delimiter] [-s sheet_name] [-a append]\n"))
  cat("  Delimiter options: 'csv', 'tsv', ',', '\\t'. Defaults based on file extension or comma if unspecified.\n")
  cat("  Or, to read from stdin:\n")
  cat(paste0("  cat /path/to/input_file | ", script_name, " -i - [-o /path/to/output_file.xlsx] [-d delimiter] [-s sheet_name] [-a append]\n"))
  cat("Flags:\n")
  cat("  -h, --help: Display this help message\n")
  cat("  -v, --version: Display script version\n")
  cat("  -i, --input: Specify the input file or '-' for stdin\n")
  cat("  -o, --output: Specify the output Excel file (optional)\n")
  cat("  -d, --delimiter: Specify the delimiter (optional)\n")
  cat("  -s, --sheet: Specify the sheet name in the Excel file (optional, defaults to 'data')\n")
  cat("  -a, --append: Append to an existing Excel file without overwriting (optional)\n")
}

# Logging function with levels
log_message <- function(message, level = "INFO") {
  cat(sprintf("[%s] %s\n", level, message))
}

# Fetch command line arguments
script_args <- commandArgs(trailingOnly = FALSE)

# Find the argument that contains '--file=' and extract the script name
script_file_arg <- grep("--file=", script_args, value = TRUE)
if (length(script_file_arg) > 0) {
  script_name <- basename(sub("--file=", "", script_file_arg))
} else {
  script_name <- "Unknown"  # Fallback if the script name cannot be determined
}

# Initialize variables
input_file <- NULL
output_file <- NULL
sheet_name <- "data"
input_delimiter <- NULL
append_to_file <- FALSE
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
         '-i' = {i <- i + 1; if(i <= length(script_args)) {input_file <- script_args[i]} else {log_message("Missing value for -i flag.", "ERROR"); quit(save="no", status=1)}},
         '--input' = {i <- i + 1; if(i <= length(script_args)) {input_file <- script_args[i]} else {log_message("Missing value for --input flag.", "ERROR"); quit(save="no", status=1)}},
         '-o' = {i <- i + 1; output_file <- script_args[i]},
         '--output' = {i <- i + 1; output_file <- script_args[i]},
         '-s' = {i <- i + 1; sheet_name <- script_args[i]},
         '--sheet' = {i <- i + 1; sheet_name <- script_args[i]},
         '-d' = {i <- i + 1; input_delimiter <- script_args[i]},
         '--delimiter' = {i <- i + 1; input_delimiter <- script_args[i]},
         '-a' = {append_to_file <- TRUE},
         '--append' = {append_to_file <- TRUE}
  )
  i <- i + 1
}

# Function to determine delimiter based on file extension
determine_delimiter <- function(file_name, specified_delimiter) {
  if (!is.null(specified_delimiter)) {
    return(specified_delimiter)
  }
  if (file_name == "-") {  # Handle stdin
    log_message("Defaulting to tab as delimiter for stdin.", "INFO")
    return("\t")
  }
  if (grepl("\\.csv$", file_name, ignore.case = TRUE)) {
    return(",")
  } else if (grepl("\\.tsv$", file_name, ignore.case = TRUE)) {
    return("\t")
  } else {
    log_message("Warning: Unable to determine the file format based on extension. Defaulting to tab as delimiter.", "WARNING")
    return("\t")
  }
}

# Function to validate the specified delimiter
validate_delimiter <- function(delimiter) {
  valid_delimiters <- c(",", "\t", "csv", "tsv")
  if (!delimiter %in% valid_delimiters) {
    stop(paste("Error: Invalid delimiter specified. Valid options are", paste(valid_delimiters, collapse = ", "), "."))
  }
  if (delimiter == "csv") {
    return(",")
  } else if (delimiter == "tsv") {
    return("\t")
  }
  return(delimiter)
}

delimiter_to_word <- function(delimiter) {
  if (delimiter == ",") {
    return("comma")
  } else if (delimiter == "\t") {
    return("tab")
  } else {
    return("custom")
  }
}

# Function to find a unique sheet name
find_unique_sheet_name <- function(existing_sheets, base_name) {
  sheet_name <- base_name
  counter <- 1
  while(sheet_name %in% existing_sheets) {
    sheet_name <- paste0(base_name, "_", counter)
    counter <- counter + 1
  }
  return(sheet_name)
}

# Display version if the version flag is set
if (display_version) {
  cat(paste0(script_name, " version ", SCRIPT_VERSION, ", ", SCRIPT_DATE, "\n"))
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

# Determine the input delimiter
input_delimiter <- determine_delimiter(input_file, input_delimiter)
input_delimiter <- validate_delimiter(input_delimiter)

# log the delimiter
log_message(paste("Using delimiter:", delimiter_to_word(input_delimiter)))

# Decide source of data: stdin or a file
if (input_file == "-") {
  # Read from stdin
  con <- file("stdin")

  # Check if stdin is empty
  if (isTRUE(interactive()) && !isOpen(con)) {
    stop("Error: No data provided in stdin or stdin is not open.")
  }

  # Read the data
  log_message("Reading data from stdin...")
  data <- read_delim(con, delim = input_delimiter, col_types = cols())

  # Set output file name. If provided, use that. Otherwise, default to "output.xlsx"
  output_file <- ifelse(!is.null(output_file), output_file, "output.xlsx")
} else {
  # Check if the file exists
  if (!file.exists(input_file)) {
    stop(paste("Error: File", input_file, "does not exist."))
  }
  # Read from the given file path
  log_message(paste("Reading data from", input_file, "..."))
  data <- read_delim(input_file, delim = input_delimiter, col_types = cols())
  # Set output file name. If provided, use that. Otherwise, derive from input file name
  output_file <- ifelse(!is.null(output_file), output_file, gsub("\\.tsv$", ".xlsx", input_file))
}

# Write data to an Excel file with the specified sheet name
if (append_to_file && file.exists(output_file)) {
  # Load existing workbook
  wb <- loadWorkbook(output_file)

  # get existing sheet names
  existing_sheets <- getSheetNames(output_file)

  # Find a unique sheet name if it already exists
  if (sheet_name %in% existing_sheets) {
    sheet_name <- find_unique_sheet_name(existing_sheets, sheet_name)
  }

  # Add data to the new sheet
  addWorksheet(wb, sheet_name)
  writeData(wb, sheet_name, data)
  saveWorkbook(wb, output_file, overwrite = TRUE)
  log_message(paste("Appended data to", output_file, "in sheet", sheet_name))
} else {
  # Create new workbook or overwrite existing file
  output_list <- setNames(list(data), sheet_name)
  write_xlsx(output_list, output_file)
  log_message(paste("Written data to", output_file, "in sheet", sheet_name))
}

quit(save = "no", status = 0)
