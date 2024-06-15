getGEO <- GEOquery::getGEO # nolint: object_name_linter.

gse65136 <- getGEO("GSE65136")
gse65133 <- gse65136[["GSE65136-GPL10558_series_matrix.txt.gz"]]
gse65134 <- gse65136[["GSE65136-GPL96_series_matrix.txt.gz"]]
gse65135 <- gse65136[["GSE65136-GPL570_series_matrix.txt.gz"]]

gse22886 <- getGEO("GSE22886")
gse22886_gpl96 <- gse22886[["GSE22886-GPL96_series_matrix.txt.gz"]]
gse22886_gpl97 <- gse22886[["GSE22886-GPL97_series_matrix.txt.gz"]]

# Save the datasets to the RData file

datasets <- list(
  gse65133 = list(
    dataset = gse65133,
    genes_attribute = NULL,
    gene_mapping_function = get_ensembl_mapping_illumina
  ),
  gse65134 = list(
    dataset = gse65134,
    genes_attribute = "affy_hg_u133a_2",
    gene_mapping_function = get_ensembl_mapping_biomart
  ),
  gse65135 = list(
    dataset = gse65135,
    genes_attribute = "affy_hg_u133_plus_2",
    gene_mapping_function = get_ensembl_mapping_biomart
  ),
  gse22886_gpl96 = list(
    dataset = gse22886_gpl96,
    genes_attribute = "affy_hg_u133a_2",
    gene_mapping_function = get_ensembl_mapping_biomart
  ),
  gse22886_gpl97 = list(
    dataset = gse22886_gpl97,
    genes_attribute = "affy_hg_u133b",
    gene_mapping_function = get_ensembl_mapping_biomart
  )
)

saveRDS(datasets, "data/preprocessing/datasets.RData")
