# This script is to create a mixture graph from a reference graph and a mixture dataset.
# Assumptions: 
# - The reference graph is already created and saved as a OntologyTree object. (This is the output of the reference_graph.jl script)
# - The mixture dataset is already created and saved as a JLD2 file. (This is the output of the generate_mixture_datasets_combinations.jl script)
#  - The mixture dataset has the following columns: cell ontology:ch1, cell type proportion, feature_names
#  - Note that synthetic mixture dataset can be generated using the generate_mixture_datasets_combinations.jl script
using Distributed

const MAX_PROCESSES = 4

# add process up to MAX_PROCESSES
if nprocs() > MAX_PROCESSES
    procs_to_remove = nprocs():(nprocs() - MAX_PROCESSES)
else
    # note that this will fail if machine has less available processes
    while nprocs() < MAX_PROCESSES
        addprocs(1)
    end
end

# Load the necessary packages
@everywhere begin
    using ProgressMeter
    using DataFrames
    using Statistics
    using Random
    using JLD2
    using OntologyTrees
    using ExpressionData: ExpressionSet, load_eset
end

# Load 
@everywhere begin
    # include("../../src/utils/graph.jl")
    include("./mixture_graph_config.jl")
    # include("./mixture_graph_utils.jl")
end

begin
    mixture_dataset::ExpressionSet = load_eset(mixture_dataset_file)
    ref_graph = load(ref_graph_file)[ref_graph_variable]
end

mix_trees = create_mixture_graph(ref_graph, mixture_dataset)

function create_mixture_graph(ref_graph::OntologyTree,
                              mixture_dataset::ExpressionSet)
    @info "Getting cell proportions"
    cell_proportions = get_cell_type_proportions(mixture_dataset,
                                                 proportions_column)

    # Make a dictionary of each sample id and the corresponding cell proportions
    sample_ids_index_in_cell = Dict{String,Int}()
    sample_ids = sampleNames(mixture_dataset)

    for sample_id in sample_ids
        index = findfirst(x -> x == sample_id,
                          cell_proportions[!,
                                           "sample_id"])
        if isnothing(index)
            continue
        end
        sample_ids_index_in_cell[sample_id] = index
    end

    @info "Getting gene expression"
    gx = get_gene_expression(mixture_dataset, ref_graph)

    @info "Creating mixture graphs..."

    n_tasks = length(sampleNames(mixture_dataset))

    p = Progress(n_tasks;
                 barglyphs=BarGlyphs("[=> ]"),
                 desc="Computing sample mixtures...")

    # Prepare the data
    data = [(sample_id,
             cell_proportions[sample_ids_index_in_cell[sample_id], Not(:sample_id)],
             gx[:, Cols(:feature_names, sample_id)]) for sample_id in sample_ids]

    # Perform distributed computation with pmap() and update progress
    results = progress_map(data; progress=p,
                           mapfun=pmap) do (sample_id, sample_proportions_row,
                                            gx_sample_with_id)
        # Save the mixture tree
        mix_tree_file = joinpath(data_path, "mixture_graphs",
                                 "$sample_id.jld2")

        # Skip if file already exists
        if isfile(mix_tree_file)
            return
        end

        # Transform dataframe row into a vector of tuples
        sample_proportion = [(replace(cell, "_" => ":"), proportion)
                             for (cell, proportion) in zip(names(sample_proportions_row),
                                                           sample_proportions_row)]
        gx_sample = [(gene, value)
                     for (gene, value) in
                         zip(gx_sample_with_id[!, :feature_names],
                             gx_sample_with_id[!, sample_id])]
        mix_tree = create_mixture_graph_for_sample(ref_graph, sample_proportion,
                                                   gx_sample)

        return save(mix_tree_file, "graph", mix_tree)
    end

    finish!(p)  # Finish the progress bar

    return results
end
