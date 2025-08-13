#!/usr/bin/env Rscript
# This file is to perform a mapping of gene symbols to Ensembl IDs.
library(biomaRt)
library(Biobase)
library(dplyr)

source("scripts/utils.R")

args <- commandArgs(trailingOnly = TRUE)

# Parse the arguments 
eset_file <- args[1]
gene_col <- args[2]
attribute <- args[3]

map_to_ensembl_ids(eset_file, gene_col, attribute, mart_id = "ensembl", mart_dataset = "hsapiens_gene_ensembl")




