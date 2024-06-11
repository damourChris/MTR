# Description: This script reads the CEL files from the GSE22886 dataset and combines them into a single matrix.

# Read the environment variables
data_dir <- Sys.getenv("DATA_DIR")
dataset <- Sys.getenv("DATASET_ID")
output_dir <- Sys.getenv("OUTPUT_DIR")
r_utils_dir <- Sys.getenv("R_UTILS_DIR")

dataset_dir <- file.path(data_dir, dataset)
output_file <- file.path(output_dir, "output.csv")


file_pattern <- "CEL"

# Load the combine_cel_files function from the cel_processing.R file
source(file.path(r_utils_dir, "cel_processing.R"))

# Get the list of all files in the directory and ilter for.cel files
all_files <- list.files(
  path = dataset_dir,
  full.names = TRUE,
  recursive = TRUE,
  pattern = NULL
)

cel_files <- all_files[grep(file_pattern, all_files)]

# Combine cell files into one big matrix
output <- combine_cel_files(cel_files[1:5])

# Save the output to the output directory
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

write.csv(output, file = output_file)
