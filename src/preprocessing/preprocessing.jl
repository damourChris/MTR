module Preprocessing

using ..Utils: ExpressionSet, get_preprocessing_env, get_preprocessing_script,
               is_loosely_the_same, sampleNames, add_pheno_column!, pData, exprs

using RCall
using Plots
using OntologyLookup
using DataFrames
using YAML

@kwdef struct SeriesDescriptor
    id::String
    platform::String
    file::String
    mapping::Dict{String,String}
end

@kwdef struct DatasetDescriptor
    title::String
    id::String
    description::Union{String,Missing}
    series::Vector{SeriesDescriptor}
end

import Base.show # to extend the show function

function show(io::IO, series::SeriesDescriptor)
    println(io, "SeriesDescriptor: $(series.id)")
    println(io, "Platform: $(series.platform)")
    println(io, "File: $(series.file)")
    println(io, "Mapping: ")
    for (key, value) in series.mapping
        println(io, "  $key => $value")
    end
end

function show(io::IO, dataset::DatasetDescriptor)
    println(io, "DatasetDescriptor: $(dataset.title)")
    println(io, "Description: $(dataset.description)")
    return println(io, "Series: $(length(dataset.series)) series")
end

function run_r_preprocessing()
    # Run the R part of preprocessing
    cmd = get_preprocessing_env() * "bin/Rscript"
    script_path = get_preprocessing_script()

    return run(`$cmd $script_path`)
end

function download_dataset(dataset::DatasetDescriptor)::Nothing
    download_dataset_r_script = joinpath(ENV["R_DIR"], "download_esets.R")
    dataset_id = dataset.id
    eset_files = [series.file for series in dataset.series]

    R" source($download_dataset_r_script) "
    R" download_dataset($dataset_id, $eset_files) "

    return nothing
end

function read_datasets(esets_description_file::String; data_path=ENV["DATA_DIR"])
    datasets_yaml = YAML.load_file(joinpath(data_path, esets_description_file);)
    #   dicttype=Dict{Symbol,DatasetDescriptor}
    datasets = Dict{Symbol,DatasetDescriptor}()
    for (key, value) in datasets_yaml
        # @info key
        datasets[Symbol(key)] = DatasetDescriptor(; title=value["title"],
                                                  id=key,
                                                  description=get(value, "description",
                                                                  missing),
                                                  series=[SeriesDescriptor(;
                                                                           id=series["id"],
                                                                           platform=series["platform"],
                                                                           file=series["file"],
                                                                           mapping=series["mapping"])
                                                          for series in value["series"]])
    end
    return datasets
end

function get_cell_types(eset::ExpressionSet, pheno_col::String;
                        cell_seperator=";", value_seperator="=")
    proportions = eset.phenoData[!, pheno_col]
    splits = split.(proportions, cell_seperator)
    cell_types_raw = [split.(x, value_seperator) for x in splits]
    cell_types = unique([strip.(getindex.(x, 1)) for x in cell_types_raw])
    return [String.(cell) for cell in cell_types if cell != ["NA"]][1]
end

function format_cell_types(cell_types::Vector{String})
    # the ontology search is quite fragile in term of dealing with plurals
    # so naturally lets introduce a equally fragile function to deal with that
    replacements = ("cells" => "cell", "Naïve" => "naive", "Monocytes" => "monocyte",
                    "Macrophages" => "macrophage", "Neutrophils" => "neutrophil",
                    "CD8+" => "CD8", "CD4+" => "CD4", "Tregs" => "Treg")
    return [replace(cell, replacements...) for cell in cell_types]
end

function get_cell_ontology_mapping(cell_types::Vector{String}; field::Symbol=:short_form)
    search_result = search.(cell_types; ontology="CL", exact=true, rows=1)
    mapping = Dict()
    for (index, cell) in enumerate(cell_types)
        if !isempty(search_result[index])
            result = search_result[index]
            label = result[!, :label][1]

            # Notify if there is a mismatch between the cell type and the ontology
            if !is_loosely_the_same(cell, label)
                @warn "Mismatch between cell type and ontology: $cell != $label"
            end
            mapping[cell] = result[!, field][1]
        else
            mapping[cell] = missing
        end
    end
    return mapping
end

function get_cell_type_proportions(eset::ExpressionSet, pheno_col::String;
                                   cell_seperator=";", value_seperator="=")
    proportions = eset.phenoData[!, pheno_col]
    splits = split.(proportions, cell_seperator)
    cell_types_raw = [split.(x, value_seperator) for x in splits]

    cell_types = get_cell_types(eset, pheno_col)

    na_indices = findall(x -> x == [["NA"]], cell_types_raw)

    cell_types_raw = [cell_types_raw[i]
                      for i in eachindex(cell_types_raw) if i ∉ na_indices]

    cell_values = [getindex.(split, 2) for split in cell_types_raw]
    cell_values = [strip.(vals) for vals in cell_values]
    cell_values = [replace.(vals, "%" => "") for vals in cell_values]
    cell_values = [parse.(Float64, value) for value in cell_values]

    # Make a matrix
    cell_values = transpose(hcat(cell_values...))

    @show size(cell_values)
    @show size(cell_types)

    df = DataFrame(cell_values, cell_types)

    # Add sample ids  
    sample_names = sampleNames(eset)
    sample_names = [sample_names[i]
                    for i in eachindex(sample_names) if i ∉ na_indices]
    @show length(sample_names), size(df)
    df[!, :sample_id] = sample_names
    return df
end

function read_required_esets(eset_description_file::String)
    return YAML.load(joinpath(data_path, esets_description_file))
end

function __init__()
    # Check if the required environment variables are set
    required_envs_vars = ["CONDA_PREFIX", "R_DIR", "DATA_DIR"]

    for env in required_envs_vars
        if !haskey(ENV, env)
            throw(ErrorException("Environment variable $env is not set. Please read the README.md file for more information."))
        end
    end
end

end # module