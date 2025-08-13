@everywhere begin
    # data_path = ENV["DATA_DIR"]
    data_path = "/workspaces/MTR/experiments/v2/data"

    # Base Eset config 
    base_eset_id = "GSE22886"
    base_eset_file = "processed_esets/GSE22886-GPL96_processed.rds"

    ## Synthetic datasets configuration
    base_prefix = "SD" # synthetic dataset prefix
    run_prefix = "SR" # synthetic dataset run prefix

    # Numbers 
    num_datasets = 10 # number of datasets to generate
    samples = 1000 # number N of samples per dataset to generate

    # Proportions label format

    # The naming system is the following:
    # The base prefix represent the a set of datasets that were generated at the same time
    # The run prefix represents the specific dataset within the base prefix
    #   each run represents a new randomized mixture dataset with N samples 

    value_unit = "%" # the unit of the values 
    cell_separator = ";" # the separator for the cell types 
    value_separator = "=" # the separator for the cell type and the value 
    sample_id_prefix = "proportion_" # this is the sample id prefix
    decimals = 2 # number of decimals to use for the proportions
    expression_method = :mean # how to handle multiple sample for a given cell type 

    # Descriptor file options
    generate_datasets_descriptor_file = true
    datasets_descriptor_file = "datasets.yaml"

    # Phenotype data columns
    cell_type_column = "cell ontology:ch1"
    proportions_column = "cell type proportion"
    feature_id_column = "feature_names"

    eset_file = joinpath(data_path,
                         base_eset_file)
    output_dir = joinpath(data_path, "mixture_datasets")
end