data_path <- Sys.getenv("DATA_DIR")
raw_series_files_dir <- file.path(data_path, "raw_series_files")
raw_eset_dir <- file.path(data_path, "raw_esets")
# Check if the required dirs exist and create them if not
if (!dir.exists(raw_series_files_dir)) {
    dir.create(raw_series_files_dir)
}
if (!dir.exists(raw_eset_dir)) {
    dir.create(raw_eset_dir)
}

# Download the datasets
gse65136 <- getGEO(
    "GSE65136",
    destdir = raw_series_files_dir
)

download_esets <- function(dataset_id, eset_files) {
    library(GEOquery)

    dataset <- getGEO(
        dataset_id,
        destdir = raw_series_files_dir
    )

    for (eset_file in eset_files) {
        eset <- dataset[[eset_file]]
        filename <- paste0(eset_file, ".RData")
        # Check if the file exit before saving
        if (file.exists(file.path(raw_eset_dir, filename))) {
            print(paste0(eset_files, " already exists. Skipping..."))
            next
        } else {
            saveRDS(eset, file.path(raw_eset_dir, filename))
        }
    }

    return(esets)
}
