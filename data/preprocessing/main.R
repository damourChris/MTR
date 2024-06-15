source("/workspaces/MTR/data/setup/utils.R")

# Check if the datasets are already downloaded
if (!file.exists("data/preprocessing/datasets.RData")) {
  # Load the datasets
  source("/workspaces/MTR/data/preprocessing/datasets.R")
} else {
  readRDS("data/preprocessing/datasets.RData")
}

expr_data <- lapply(
  datasets,
  function(dataset) {
    annotate_expression_data(
      dataset$dataset, dataset$gene_mapping_function, dataset$genes_attribute
    )
  }
)

save_list_to_hdf5 <- function(list_data, file_path) {
  # Create a new HDF5 file if it doesn't exist
  hdf5::hdf5_create_file(file_path)

  # Open the HDF5 file
  h5file <- hdf5::H5File(file_path, "w")

  # Iterate over the list items and save them to the HDF5 file
  for (i in seq_along(list_data)) {
    item_name <- paste0("item_", i)
    hdf5::h5write(item_name, h5file, list_data[[i]])
  }

  # Close the HDF5 file
  hdf5::h5close(h5file)
}
