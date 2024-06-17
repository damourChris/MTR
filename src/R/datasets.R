# Download the datasets
gse65136 <- GEOquery::getGEO("GSE65136")
gse22886 <- GEOquery::getGEO("GSE22886")

# Extract the datasets from the GEO objects
gse65136_gpl10558 <- gse65136[["GSE65136-GPL10558_series_matrix.txt.gz"]]
gse65136_gpl96 <- gse65136[["GSE65136-GPL96_series_matrix.txt.gz"]]
gse65136_gpl570 <- gse65136[["GSE65136-GPL570_series_matrix.txt.gz"]]

gse22886_gpl96 <- gse22886[["GSE22886-GPL96_series_matrix.txt.gz"]]
gse22886_gpl97 <- gse22886[["GSE22886-GPL97_series_matrix.txt.gz"]]

# Save the datasets to the RData file
datasets <- list(
  gse65136_gpl10558 = list(
    dataset = gse65136_gpl10558,
    gene_col = "Entrez_Gene_ID",
    genes_attribute = "entrezgene_id"
  ),
  gse65136_gpl96 = list(
    dataset = gse65136_gpl96,
    gene_col = "ID",
    genes_attribute = "affy_hg_u133a_2"
  ),
  gse65136_gpl570 = list(
    dataset = gse65136_gpl570,
    gene_col = "ID",
    genes_attribute = "affy_hg_u133_plus_2"
  ),
  gse22886_gpl96 = list(
    dataset = gse22886_gpl96,
    gene_col = "ID",
    genes_attribute = "affy_hg_u133a_2"
  ),
  gse22886_gpl97 = list(
    dataset = gse22886_gpl97,
    gene_col = "ID",
    genes_attribute = "affy_hg_u133b"
  )
)

data_path <- Sys.getenv("DATA_PATH")
saveRDS(datasets, file.path(data_path, "raw_datasets.RData"))
