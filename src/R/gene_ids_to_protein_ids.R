library(biomaRt)

mart <- useMart("ensembl", dataset = "hsapiens_gene_ensembl")

convert_gene_ids_to_protein_ids <- function(ids) {
    attributes <- c("ensembl_gene_id", "ensembl_peptide_id", "hgnc_symbol")
    filters <- "ensembl_gene_id"
    getBM(attributes = attributes, filters = filters, values = ids, mart = mart)
}
