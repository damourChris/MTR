# This file is to perfrom batch annoatation on a list of datasets.
# The datasets are read from a directory and then annotated using
# the biomart package. Configuration is done using a YAML file.
# The datasets are then saved to a new directory.
# For more information, refer to the wiki of the project.
library(biomaRt)
library(Biobase)
library(dplyr)
library(yaml)

# Input
data_path <- Sys.getenv("DATA_PATH")
raw_eset_dir <- file.path(data_path, "raw_esets")
dataset_descriptor_file <- file.path(data_path, "datasets.yaml")

# Output
output_dir <- file.path(data_path, "ensembl_mapped_esets  ")

mart_id <- "ensembl"
mart_dataset <- "hsapiens_gene_ensembl"

# R Utils
r_dir <- Sys.getenv("R_DIR")
r_utils_path <- file.path(r_dir, "utils.R")
source(r_utils_path)

## Input checks
# - Check if all the required directories and files exist
# - Check if the descriptor file exists
# - Create the required directories if they don't exist
if (!dir.exists(raw_eset_dir)) {
  stop("Raw esets directory not found.")
}
if (length(list.files(input_dir)) == 0) {
  warning("Warning: No raw esets found. Please download the datasets first.")
  stop("No esets found.")
}
if (!file.exists(dataset_descriptor_file)) {
  stop("Dataset descriptor file not found.")
}
if (!dir.exists(output_dir)) {
  print(paste0("Creating output directory: ", output_dir))
  dir.create(output_dir)
}


## Data setup
# Load the biomart dataset
mart <- biomaRt::useMart(mart_id, dataset = mart_dataset)

# Read the dataset dataset descriptor files to figure out the gene mapping
dataset_description <-
  read_yaml(dataset_descriptor_file)

raw_esets_content <- list.files(raw_eset_dir, full.names = TRUE)

# Create a data frame to store the gene mapping information
# from the dataset descriptor file
gene_mapping_info <- data.frame(
  id = character(),
  name = character(),
  gene_col = character(),
  genes_attribute = character(),
  stringsAsFactors = FALSE
)

# To map to ensembl, we read the information from the datasets descriptor
# file to get the gene column and the attribute that will be passed to biomart
for (i in seq_along(dataset_description)) {
  dataset_name <- names(dataset_description)[i]
  dataset <- dataset_description[[dataset_name]]

  for (series in dataset$series) {
    gene_mapping_info <- rbind(
      gene_mapping_info,
      data.frame(
        name = dataset_name,
        id = paste0(series$id, "-", series$platform),
        gene_col = series$mapping$gene_col,
        genes_attribute = series$mapping$genes_attribute
      )
    )
  }
}

# Load the datasets
datasets <- read_and_combine(gene_mapping_info, raw_esets_content)

# Annotate the datasets
for (i in seq_along(datasets)) {
  dataset <- datasets[[i]]
  dataset_id <- names(datasets)[i]

  annotated_eset_file <-
    file.path(preprocessed_esets_dir, paste0(dataset_id, "_annotated.rds"))

  # Check if the processed eset already exists
  if (file.exists(annotated_eset_file)) {
    print(paste0("Dataset: ", dataset_id, " already annotated Skipping..."))
    next
  }

  print(paste0("Annotating dataset: ", dataset_id))

  eset <- dataset$eset
  attribute <- dataset$genes_attribute
  gene_col <- dataset$gene_col

  # Annotate the dataset
  # $ Note all the function used here are defined in the utils.R file
  # $ in the R directory
  # The steps are:
  # 1. Remove empty genes
  # 2. Extract the first gene symbol
  # 3. Aggregate the expression for duplicated gene symbols
  # 4. Map the gene symbols to Ensembl ID
  # 5. Aggregate the expression for duplicated Ensembl genes
  preprocessed_eset <-
    remove_empty_genes(eset, gene_col = gene_col) %>%
    extract_first_gene_symbol(gene_col = gene_col) %>%
    aggregate_expression(gene_col = gene_col) %>%
    map_to_ensembl(
      gene_col = gene_col,
      attribute = attribute,
      mart = mart
    ) %>%
    aggregate_expression(gene_col = "ensembl_id")

  # Save the processed eset
  saveRDS(preprocessed_eset, preprocessed_eset_file)
}
