using Pkg
Pkg.activate(@__DIR__)

using SimpleContainerGenerator: SimpleContainerGenerator

mkpath("gnn_proportion_base")
cd("gnn_proportion_base")

pkgs = [(name="CSV",),
        (name="CategoricalArrays",),
        (name="Comonicon",),
        (name="DataFrames",),
        (name="DotEnv",),
        (name="EnumX",),
        (name="ExpressionData",),
        (name="Flux",),
        (name="GraphNeuralNetworks",),
        (name="GraphRecipes",),
        (name="Graphs",),
        (name="HTTP",),
        (name="JLD2",),
        (name="JSON",),
        (name="LightXML",),
        (name="MLUtils",),
        (name="MetaGraphs",),
        (name="OntologyLookup",),
        (name="OpenSSL",),
        (name="Plots",),
        (name="Preferences",),
        (name="ProgressMeter",),
        (name="RCall",),
        (name="RDatasets",),
        (name="Requires",),
        (name="STRINGdb",),
        (name="TSne",),
        (name="YAML",)]

julia_version = v"1.10.0"
parent_image = "ubuntu:latest"

SimpleContainerGenerator.create_dockerfile(pkgs;
                                           julia_version=julia_version,
                                           output_directory=pwd(),
                                           parent_image=parent_image)

run(`docker build -t damourc/gnn_proportion_base .`)