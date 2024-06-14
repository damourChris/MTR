#' Annotates expression data with gene mapping information
#'
#' @description
#' Retrieves the dataset and gene IDs from GEO, gets a unique list of gene IDs,
#' and performs gene mapping using the specified gene mapping function.
#' The function then annotates the expression data with Ensembl gene IDs.
#'
#' @param dataset_id The ID of the dataset in GEO.
#' @param gene_mapping_function The function used for gene mapping.
#' @param genes_attribute (optional) The biomaRt attribute for mapping gene IDs.
#' @details The gene_mapping_function should take gene IDs
#' If using biomaRt, `genes_attribute` needs to be defined.
#' It should return a data frame cols: gene_id, ensembl_gene_id.
#'
#' The dataset should contain a single series matrix file with expression data.
#'
#' @return The expression data with Ensembl gene IDs.
#'
#' @examples
#' annotate_expression_data(
#'   "GSE65135",
#'   "affy_hg_u133_plus_2",
#'   get_ensembl_gene_mapping_biomaRt
#' )
annotate_expression_data <- function(
    dataset, gene_mapping_function, genes_attribute = NULL) {
  # Get unique list of gene ids
  gene_ids <- unique(unlist(dataset@featureData@data$ID))

  # Get gene mapping
  if (is.null(genes_attribute)) {
    gene_ids_map <- gene_mapping_function(gene_ids)
  } else {
    gene_ids_map <- gene_mapping_function(gene_ids, genes_attribute)
  }


  # Get expression data and map gene ids to ensembl gene ids
  expr_data <- dataset@assayData$exprs
  old_row_names <- rownames(expr_data)
  row_names_indices <- gene_ids_map$gene_id

  matched_rows <- match(old_row_names, row_names_indices)
  new_row_names <- gene_ids_map$ensembl_gene_id[matched_rows]

  # Create new expression data with ensembl gene ids
  rownames(expr_data) <- new_row_names

  return(expr_data)
}

#' Retrieve Ensembl mapping using BioMart
#'
#' This function retrieves the Ensembl mapping
#' for a given set of gene IDs using BioMart.
#'
#' @param gene_ids A character vector of gene IDs.
#' @param attribute The attribute to retrieve from BioMart.
#' @return A data frame with gene IDs and corresponding Ensembl gene IDs.
#' @examples
#' get_ensembl_mapping_biomart(
#'   c("1007_s_at", "1053_at", "117_at"), "affy_hg_u133a_2"
#' )
#'
#' @importFrom biomaRt useMart getBM
get_ensembl_mapping_biomart <- function(gene_ids, attribute) {
  ensembl <- biomaRt::useMart("ensembl", dataset = "hsapiens_gene_ensembl")

  gene_mapping <- biomaRt::getBM(
    attributes = c(attribute, "ensembl_gene_id"),
    values = gene_ids,
    mart = ensembl
  )

  res <- data.frame(
    gene_id = gene_mapping[[attribute]],
    ensembl_gene_id = gene_mapping$ensembl_gene_id
  )

  return(res)
}

#' Get Ensembl mapping for Illumina gene IDs
#'
#' Retrieves the Ensembl mapping for a given set of Illumina gene IDs.
#'
#' @param gene_ids A character vector of Illumina gene IDs.
#'
#' @return A data frame with gene IDs and corresponding Ensembl gene IDs.
#'
#' @examples
#' gene_ids <- c("ILMN_3311130", "ILMN_3310080")
#' get_ensembl_mapping_illumina(gene_ids)
#'
#' @importFrom illuminaHumanv4.db illuminaHumanv4ENSEMBL
#' @importFrom AnnotationDbi mappedkeys select
get_ensembl_mapping_illumina <- function(gene_ids) {
  # Get the entrez gene IDs that are mapped to an Ensembl ID
  base_map <- illuminaHumanv4.db::illuminaHumanv4ENSEMBL
  mapped_genes <- AnnotationDbi::mappedkeys(base_map)

  map <- as.list(base_map[mapped_genes])

  map_df <- list2DF(lapply(map, `length<-`, max(lengths(map))))
  map_df_t <- t(map_df)

  res <- data.frame(
    gene_id = rownames(map_df_t),
    ensembl_gene_id = map_df_t[, 1]
  )

  # Row names are not needed
  rownames(res) <- NULL

  return(res)
}
