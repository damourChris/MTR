# Purpose: Download raw esets from GEO using GEOquery package
library(GEOquery)
library(yaml)

### Setup
data_path <- Sys.getenv("DATA_DIR")

# Input
raw_series_files_dir <- file.path(data_path, "raw_series_files")
dataset_descriptor_file <- file.path(data_path, "datasets.yaml")

# Output
output_dir <- file.path(data_path, "raw_esets")

## Input checks
# - Check if all the required directories and files exist
# - Check if the raw_eset_dir is empty, if so, download the datasets
# - Check if the descriptor file exists
# - Create the required directories if they don't exist
if (!dir.exists(data_path)) {
  stop("Data directory not found.")
}
if (!file.exists(dataset_descriptor_file)) {
  stop("Dataset descriptor file not found.")
}
if (!dir.exists(raw_series_files_dir)) {
  print(paste0("Creating raw series files directory: ", raw_series_files_dir))
  dir.create(raw_series_files_dir)
}
if (!dir.exists(raw_eset_dir)) {
  print(paste0("Creating raw esets directory: ", raw_eset_dir))
  dir.create(raw_eset_dir)
}


# Read the dataset descriptor file
datasets <- read_yaml(dataset_descriptor_file)
datasets_ids_raw <- names(sapply(datasets, function(x) x$id))

# Filter out the dataset that do not have GSE as the prefix
datasets_ids <- datasets_ids[grep("^GSE", datasets_ids_raw)]

# Then download the datasets
for (dataset_id in datasets_ids) {
  print(paste0("Downloading dataset ID: ", dataset_id))

  dataset <- GEOquery::getGEO(
    dataset_id,
    destdir = raw_series_files_dir
  )

  for (eset_file in names(dataset)) {
    eset <- dataset[[eset_file]]

    # Strip the eset_file name to remove any file extensions
    eset_file <- gsub("\\..*", "", eset_file)
    filename <- paste0(eset_file, ".rds")

    # Check if the file exit before saving
    if (file.exists(file.path(raw_eset_dir, filename))) {
      print(paste0(eset_files, " already exists. Skipping..."))
      next
    } else {
      saveRDS(eset, file.path(raw_eset_dir, filename))
    }
  }
}
