r_dir <- Sys.getenv("R_DIR")

# Check if the datasets are already in workspace, else load them
stopifnot(exists("datasets"))

if (!exists("annotate_eset_ensembl")) {
  source(file.path(r_dir, "utils.R"))
}

# Annotate the datasets
annonated_datasets <- lapply(
  datasets,
  function(dataset) {
    annotate_eset_ensembl(
      dataset$dataset, dataset$gene_col, dataset$genes_attribute
    )
  }
)

# Save the datasets
saveRDS(annonated_datasets, file.path(data_path, "annonated_datasets.RData"))
