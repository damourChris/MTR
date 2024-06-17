# Read environment variables
r_dir <- Sys.getenv("R_DIR")
data_path <- Sys.getenv("DATA_PATH")

# Load the utils
r_utils_path <- file.path(r_dir, "utils.R")
source(r_utils_path)

# Load the datasets
raw_dataset_path <- file.path(data_path, "raw_datasets.RData")

# Check if the datasets are already downloaded
if (!file.exists(raw_dataset_path)) {
  # If not, download the datasets and save them
  dataset_loading_script_path <- file.path(r_dir, "datasets.R")
  source(dataset_loading_script_path)
} else {
  datasets <- readRDS(raw_dataset_path)
}

# Annotate the datasets
for (dataset in datasets) {
  dataset <- annotate_ensembl_ids(
    dataset$dataset,
    get_ensembl_gene_mapping_biomaRt,
    dataset$gene_col,
    dataset$genes_attribute
  )
}
