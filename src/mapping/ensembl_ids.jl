using ExpressionData
using RCall

test_eset = load_eset("src/data/raw_esets/GSE1_series_matrix.rds");
mart_id = "ensembl"
mart_dataset = "hsapiens_gene_ensembl"

map_eset_to_ensembl_ids(test_eset; attribute="ensembl_id", gene_col="ID")

function map_eset_to_ensembl_ids(eset::ExpressionSet; attribute="gene_symbol",
                                 gene_col="gene_id")
    @rput eset attribute gene_col mart_id mart_dataset
    R"""
    library(dplyr)
    r_dir <- Sys.getenv("R_DIR")
    r_utils_path <- file.path(r_dir, "utils.R")
    source(r_utils_path)

    library(biomaRt)

    # Load the biomart dataset
    mart <- useMart(mart_id, dataset = mart_dataset)

    # Annotate the dataset
    # $ Note all the function used here are defined in the utils.R file
    # $ in the R directory
    # The steps are:
    # 1. Remove empty genes
    # 2. Extract the first gene symbol
    # 3. Aggregate the expression for duplicated gene symbols
    # 4. Map the gene symbols to Ensembl ID
    # 5. Aggregate the expression for duplicated Ensembl genes
    new_eset <-
        remove_empty_genes(eset, gene_col = gene_col) %>%
        extract_first_gene_symbol(gene_col = gene_col) %>%
        aggregate_expression(gene_col = gene_col) %>%
        map_to_ensembl(
        gene_col = gene_col,
        attribute = attribute,
        mart = mart
        ) %>%
        aggregate_expression(gene_col = "ensembl_id")
    """

    new_eset_R = @rget new_eset
    new_eset = convert(ExpressionSet, new_eset_R)

    return new_eset
end
