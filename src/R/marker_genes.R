library(dplyr)

eset <- annonated_datasets[["gse65136_gpl10558"]]


data_path <- Sys.getenv("DATA_DIR")


reference_datasets_files <- list.files(file.path(data_path, "reference_datasets"), full.names = TRUE)
reference_datasets <- lapply(reference_datasets_files, readRDS)

names(reference_datasets) <- sapply(reference_datasets_files, function(x) {
  basename(x) %>%
    strsplit("\\.") %>%
    unlist() %>%
    .[[1]]
})

identify_cell_type_marker_genes <- function(eset) {
  # Filter out genes with p-values bigger than threshold
  anova_significant_threshold <- 0.0001
  tuxey_significant_threshold <- 10e-9

  expression_matrix <- Biobase::exprs(eset)

  # Log transform the expression matrix
  expression_matrix <- log2(expression_matrix + 1)
  rownames(expression_matrix) <- Biobase::fData(eset)$ensembl_id

  sample_group <- factor(eset[["cell ontology:ch1"]])

  print("Running ANOVA test...")
  anova_results <- apply(expression_matrix, 1, function(gene_expr) {
    model <- anova(aov(gene_expr ~ sample_group))
  })

  p_values <- lapply(anova_results, function(x) {
    x[["Pr(>F)"]][1]
  })

  adjusted_p_values <- p.adjust(p_values, method = "fdr")
  names(adjusted_p_values) <- rownames(expression_matrix)

  sig_p_values <- adjusted_p_values[adjusted_p_values < anova_significant_threshold]
  significant_genes <- names(adjusted_p_values)[adjusted_p_values < anova_significant_threshold] # Threshold can vary

  # Reduce the original expression matrix to only the significant genes
  expression_matrix <- expression_matrix[significant_genes, ]

  print("Running Tukey test...")
  tukey_results <- apply(expression_matrix, 1, function(gene_expr) {
    model <- aov(gene_expr ~ sample_group)
    TukeyHSD(model)
  })

  names(tukey_results) <- significant_genes


  print("Identifying cell types...")
  cell_types_gene_pairings <- lapply(tukey_results, function(res) {
    tukey_pvals <- res$sample_group[, 4]
    sig_comps <- res$sample_group[tukey_pvals < tuxey_significant_threshold, ]

    types <- lapply(rownames(sig_comps), function(row) {
      strsplit(row, "-")
    })

    # Count frequencies
    frequency_table <- table(unlist(types))

    # Identify the most frequent string
    most_frequent_string <- names(which.max(frequency_table))

    # Make sure that the most frequent string is not empty or NULL
    if (most_frequent_string == "" || is.null(most_frequent_string)) {
      return(NULL)
    }

    most_frequent_string

    # This should be recorded only if the most frequent string count is bigger than 1
    # and all the other strings counts are 1
    if (frequency_table[most_frequent_string] > 1 && all(frequency_table[-which(names(frequency_table) == most_frequent_string)]) == 1) {
      return(most_frequent_string)
    } else {
      return(NULL)
    }
  })

  # Filter out the NULL values
  cell_types_gene_pairings_filter <-
    cell_types_gene_pairings[!sapply(cell_types_gene_pairings, is.null)]

  know_cell_types <- unique(unlist(cell_types_gene_pairings))


  cell_type_marker_genes <- list()


  for (value in know_cell_types) {
    indices <- which(unlist(cell_types_gene_pairings_filter) == value)


    if (length(indices) == 0) {
      next
    }


    new_list <- names(cell_types_gene_pairings_filter[indices])


    cell_type_marker_genes[[value]] <- new_list
  }

  return(cell_type_marker_genes)
}

results <- lapply(seq_along(reference_datasets), function(i) {
  dataset <- reference_datasets[[i]]
  # Get the current key
  key <- names(reference_datasets)[i]

  print(paste("Processing... | Identifying cell type marker genes for", key))

  filename <- paste0(key, "_pairings.RData")
  filepath <- file.path(data_path, "reference_datasets_pairings", filename)

  # Check if the result is already saved
  if (file.exists(filepath)) {
    return(readRDS(filepath))
  } else {
    result <- identify_cell_type_marker_genes(dataset)

    # Save result to file for later use
    saveRDS(result, filepath)

    return(result)
  }
})
names(results) <- names(reference_datasets)

results[[2]]

saveRDS(results, "cell_type_marker_genes.RData")
results <- readRDS("cell_type_marker_genes.RData")

eset <- reference_datasets[[2]]

groups_list <- results[[2]]
gene_expression_matrix <- Biobase::exprs(eset)
gene_expression_matrix <- log2(gene_expression_matrix + 1)
rownames(gene_expression_matrix) <- Biobase::fData(eset)$ensembl_id

# Create a new column in the matrix indicating the group of each row (gene)
groups <- sapply(1:nrow(gene_expression_matrix), function(i) {
  # Find the group of the gene based on the cell type marker genes
  for (group in names(groups_list)) {
    if (rownames(gene_expression_matrix)[i] %in% groups_list[[group]]) {
      return(group)
    }
  }
})
names(groups) <- rownames(gene_expression_matrix)

# remove rows with missing group
groups <- unlist(groups)

# For each gene in gene_expression_matrix, if the gene is not in any group, remove it
gene_expression_matrix <- gene_expression_matrix[rownames(gene_expression_matrix) %in% names(groups), ]


# Create a data frame for plotting
df_ggplot <- data.frame(
  group = groups,
  ensembl_id = rownames(gene_expression_matrix),
  gene_expression_matrix
)

df <- data.frame(
  gene_expression_matrix
)
df_pheatmap <- data.frame(
  group = groups,
  gene_expression_matrix
)


# Sort the df by group
df_pheatmap <- df_pheatmap[order(df_pheatmap$group), ]

# Remove the group column
df_pheatmap <- df_pheatmap[, -1]

df_ggplot <- df_ggplot[order(df_ggplot$group), ]

# Remove the group column
df_ggplot <- df_ggplot[, -1]

library(pheatmap)


pheatmap(as.matrix(df), scale = "row", cluster_rows = FALSE, cluster_cols = FALSE, color = hcl.colors(50, "BluYl"))
pheatmap(as.matrix(df), scale = "row", color = hcl.colors(50, "BluYl"))
pheatmap(as.matrix(df_pheatmap), scale = "row", cluster_rows = FALSE, cluster_cols = FALSE, color = hcl.colors(50, "BluYl"))
pheatmap(as.matrix(df_pheatmap), scale = "row", cluster_cols = FALSE, color = hcl.colors(50, "BluYl"))
pheatmap(as.matrix(df_pheatmap), scale = "row", color = hcl.colors(50, "BluYl"))
