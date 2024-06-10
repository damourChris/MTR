if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
BiocManager::install("affy")

# Function to read multiple CEL files and combine them into a matrix
combine_cel_files <- function(cel_file_paths) {
  library(affy)

  cel_data_list <- list()

  for (i in seq_along(cel_file_paths)) {
    cel_data <- ReadAffy(filenames = cel_file_paths[i])
    intensities <- exprs(cel_data)
    cel_data_list[[i]] <- intensities
  }

  combined_matrix <- do.call(cbind, cel_data_list)

  return(combined_matrix)
}
