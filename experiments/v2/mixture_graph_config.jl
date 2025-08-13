begin
    data_path = "/workspaces/MTR/experiments/v2/data"

    mixture_dataset_file = joinpath(data_path, "processed_esets",
                                    "GSE22886-GPL96_processed.rds")
    eset_variable = "eset"

    ref_graph_file = joinpath(data_path, "reference_graph.jld2")
    ref_graph_variable = "graph"

    proportions_column::String = "cell_type_proportion"
end