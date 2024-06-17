#' @title Annotates Expression Set with Ensembl Identifiers
#'
#' @method annotate_eset_ensembl
#'
#' @description
#' Retrieves the dataset and gene IDs from GEO, gets a unique list of gene IDs,
#' and performs gene mapping using biomaRt.
#' The function then annotates the Expression Set with Ensembl gene IDs.
#'
#' @param dataset The Expression Set to annotate.
#' @param attribute  The biomaRt attribute for mapping gene IDs.
#' @param col (optional) The col in Expression Set containing gene IDs.
#' @param id_overide (optional) Whether to override the IDs with Ensembl IDs.
#'
#' @return A new Expression set with Ensembl gene IDs as a col.
#'
#' @examples
#' eset <- GEOquery::getGEO("GSE65135")
#' annotate_eset_ensembl(
#'   eset,
#'   attribute = "affy_hg_u133_plus_2",
#' )
annotate_eset_ensembl <- function(
    dataset,
    col = "ID",
    attribute = NULL,
    id_overide = FALSE) {
  if (missing(dataset)) {
    stop("Dataset must be defined for gene mapping.")
  }
  # Check that datset is a ExpressionSet
  if (!is(dataset, "ExpressionSet")) {
    stop("Dataset must be an ExpressionSet.")
  }

  if (is.null(attribute)) {
    stop("Attribute must be defined for gene mapping.")
  }


  ids <- unique(unlist(dataset@featureData@data[col]))

  # Clone the dataset
  es <- dataset

  # Get gene mapping
  ids_map <- get_ensembl_mapping_biomart(ids, attribute)
  new_row_names <- ids_map$Ensembl_ID

  # Add the gene mapping to the dataset
  if (id_overide) {
    es@featureData@data$ID <- new_row_names
  } else {
    es@featureData@data$Ensembl_ID <- new_row_names
  }

  return(es)
}

#' Retrieve Ensembl mapping using BioMart
#'
#' @method get_ensembl_mapping_biomart
#'
#' @description
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
