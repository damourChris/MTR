# This file is for defining the configuration variables for the reference graph script.
begin
    # Files 
    r_script_file = "reference_genes.r"
    base_eset_file = "GSE22886-GPL96_processed.rds"

    # Paths
    data_path = "/workspaces/MTR/experiments/v2/data"
    eset_file = joinpath(data_path, "processed_esets", base_eset_file)
    r_script_path = joinpath(@__DIR__, r_script_file)
end