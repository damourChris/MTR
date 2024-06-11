# This file is used to unify the preprocessing steps for all datasets.
# Reading CEL Files is done in R and the output is saved as a CSV file.

# Path: data/preprocessing/main.jl
using Pkg
Pkg.activate(@__DIR__)
# Load the necessary packages
pkgs = ["CSV", "RCall", "DataFrames", "DotEnv", "Suppressor"]

for pkg in pkgs
    Pkg.add(pkg)
end

cd(@__DIR__)

using DotEnv
DotEnv.load!()

@assert haskey(ENV, "DATA_DIR") "DATA_DIR is not set in .env file"
ENV["R_UTILS_DIR"] = joinpath(@__DIR__, "r_utils")

@enum VerbosityLevel LevelOff = 0 LevelInfo = 1 LevelDebug = 2
verbosity_level = LevelInfo

# Read the data directory and list all the dataset to preprocessing
datasets = readdir(ENV["DATA_DIR"])


# Utils module
include("utils.jl")

for dataset in datasets
    if verbosity_level >= LevelInfo
        println("Running preprocessing for $dataset...")
    end

    ENV["OUTPUT_DIR"] = joinpath(@__DIR__, dataset, "output")
    ENV["DATASET_ID"] = dataset
    ENV["CONDA_ENV"] = "pre_$(dataset)"

    try
        Utils.run_preprocessing(dataset)
        cd(@__DIR__)
    catch e
        println("Error in preprocessing $dataset: $(e)")
        cd(@__DIR__)
    end
end
