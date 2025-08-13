# This script is for generating a arbitraty number of synthetic datasets from a base dataset
# The base dataset can be any dataset in the ExpressionSet format
# 
# The script will generate a number of synthetic datasets with the same number of samples
# as the base dataset, but with different mixtures of cell types
# 
# The config is set in the synthethic_mixutre_config file
# 
# TODO: Add a way to specify the number of samples for each cell type
# TODO: Add noise variable to the synthetic datasets
using ExpressionData
using Distributed
using RCall
using YAML

# add processes on the same machine
addprocs(4)

@everywhere begin
    using JLD2
    using ProgressMeter

    using DataFrames
    using Statistics
    using Random
    using ExpressionData
    using SyntheticExpressionMixtures

    # include("./mixtures_datasets_utils.jl")
end

include("./synthetic_mixutres_config.jl")
if !isdir(output_dir)
    mkpath(output_dir)
end

# Read eset from file
R"eset <- readRDS($eset_file)"
eset_R = @rget eset

base_eset = convert(ExpressionSet, eset_R)
names(phenotype_data(base_eset))
config = create_config(Dict("column" => Dict("cell_type" => "cell type:ch1")))
syd_est = generate_synthetic_expression_mixtures(base_eset, config)
phenotype_data(syd_est)[!, "cell_type"]

# Make the base eset available to all workers
@everywhere base_eset = $base_eset
@everywhere num_datasets = $num_datasets

ref_cell_type_indices = Dict{String,Vector{Int}}()

# Find all the samples indicces for the cell type 
for cell_type in unique(phenotype_data(base_eset)[!, cell_type_column])
    ref_cell_type_indices[cell_type] = findall(==(cell_type),
                                               phenotype_data(base_eset)[!,
                                                                         cell_type_column])
    if isempty(ref_cell_type_indices[cell_type])
        @warn "No samples found for cell type: $cell_type"
    end
end

cells_types = keys(ref_cell_type_indices)
classes = length(cells_types)

# Saving setup
# First we check for previous runs to determine the current run number
@everywhere begin
    base_pattern = Regex("$(base_prefix)[0-9][0-9][0-9]-$(run_prefix)[0-9][0-9][0-9][0-9].*jld2")
    existing_runs = readdir(output_dir)
    matching_files = filter(file -> occursin(base_pattern, file), existing_runs)

    dataset_number = let
        cur_max = 0
        max_run = [parse(Int,
                         match(Regex("$(base_prefix)\\d{3}"), file).match[(length(base_prefix) + 1):end])
                   for file in vec(matching_files)]

        if !isempty(max_run)
            cur_max = maximum(max_run) + 1
        else
            cur_max = 1
        end
    end

    new_files = ["$base_prefix$(lpad(dataset_number, 3, '0'))-$run_prefix$(lpad(run_number, 4, '0')).jld2"
                 for run_number in 1:num_datasets]
end

# We are gonna use distributed computing to generate the synthetic datasets
p = Progress(num_datasets;
             barglyphs=BarGlyphs("[=> ]"),
             desc="Computing sample mixtures...")

# generate on each worker since each call to 
# (save/generate)_synthetic_eset is independent
results = progress_map(1:num_datasets; progress=p,
                       mapfun=pmap) do run_number
    new_file = joinpath(output_dir, new_files[run_number])

    return saved = try
        save_synthetic_eset(generate_synthethic_mixture_eset(base_eset), new_file)
        true
    catch e
        @error "Error generating synthetic dataset: $new_file"
        @error e
        false
    end
end

# Check if all the datasets were generated
if all(results)
    @info "All synthetic datasets were generated"
else
    @warn "Some datasets were not generated"
end

# Generate the descriptor file
if generate_datasets_descriptor_file
    descriptor = generate_descriptor_file(samples, base_eset_id, base_prefix, run_prefix,
                                          dataset_number, num_datasets)
    descriptor_file = joinpath(output_dir, datasets_descriptor_file)
    YAML.write_file(descriptor_file, descriptor)
end

@info "Done generating synthetic datasets"
