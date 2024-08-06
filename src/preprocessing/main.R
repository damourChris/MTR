# Read environment variables
# Note this will stop the program if the environment variables are
# not set, empty or in an incorrect format.
r_dir <- load_env_variable("R_DIR")
data_path <- load_env_variable("DATA_DIR")
required_esets <- load_env_variable("REQUIRED_ESETS") %>%
  strsplit(",") %>%
  unlist()

# Extra check for the required esets
if (length(required_esets) == 0) {
  stop("No required esets specified or in an incorrect format.")
}

# Load the utils
r_utils_path <- file.path(r_dir, "utils.R")
source(r_utils_path)


# Load the datasets
raw_datasets_dir <- file.path(data_path, "raw_datasets")
annonated_dataset_dir <- file.path(data_path, "annonated_datasets")

# Check if the datasets are already downloaded
if (!file.exists(raw_dataset_path)) {
  print("Downloading datasets...")
  # If not, download the datasets and save them
  dataset_loading_script_path <- file.path(r_dir, "datasets.R")
  source(dataset_loading_script_path)
} else {
  print("Datasets already downloaded.")
}

# Annotate the datasets
if (!file.exists(annonated_dataset_path)) {
  print("Annotating datasets...")
  annotations_script_path <- file.path(r_dir, "annotations.R")
  source(annotations_script_path)
} else {
  print("Datasets already annotated.")
}
