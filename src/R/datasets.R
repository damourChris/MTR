# Set up
data_path <- Sys.getenv("DATA_DIR")
raw_series_files_dir <- file.path(data_path, "raw_series_files")
raw_eset_dir <- file.path(data_path, "raw_esets")

library(GEOquery)

# Check if the raw series files directory exists
if (!dir.exists(raw_series_files_dir)) {
  dir.create(raw_series_files_dir)
}

# Download the datasets
gse65136 <- getGEO(
  "GSE65136",
  destdir = raw_series_files_dir
)
gse22886 <- getGEO(
  "GSE22886",
  destdir = raw_series_files_dir
)

# Extract the datasets from the GEO objects
gse65136_gpl10558 <- gse65136[["GSE65136-GPL10558_series_matrix.txt.gz"]]
gse65136_gpl96 <- gse65136[["GSE65136-GPL96_series_matrix.txt.gz"]]
gse65136_gpl570 <- gse65136[["GSE65136-GPL570_series_matrix.txt.gz"]]

gse22886_gpl96 <- gse22886[["GSE22886-GPL96_series_matrix.txt.gz"]]
gse22886_gpl97 <- gse22886[["GSE22886-GPL97_series_matrix.txt.gz"]]

# Save the eset in the raw_esets directory
if (!dir.exists(raw_eset_dir)) {
  dir.create(raw_eset_dir)
}

for (dataset_name in names(datasets)) {
  eset <- datasets[[dataset_name]]$eset
  saveRDS(eset, file.path(raw_eset_dir, paste0(dataset_name, ".RData")))

  # Save other info in a separate file
  saveRDS(
    datasets[[dataset_name]][c("gene_col", "genes_attribute")],
    file.path(raw_eset_dir, paste0(dataset_name, "_attributes.RData"))
  )
}
