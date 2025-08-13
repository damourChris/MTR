include("../../src/MTR.jl")

# TODO: # ADD Sink node to represent unmapped cell types
using .MTR
using .MTR.Preprocessing: get_cell_types, format_cell_types, get_cell_ontology_mapping,
                          get_cell_type_proportions, add_pheno_column!, read_datasets
using .MTR.Utils
using RCall
using JLD2
using DataFrames

data_path = joinpath(@__DIR__, "data")

esets_description_file = joinpath(data_path, "datasets.yaml")
reference_pheno_col = "cell type:ch1"
mixture_pheno_col = "flow cytometry cell subset proportions:ch1"
ontology_fcol_name = "cell ontology:ch1"

# preprocessed_esets_dir = joinpath(data_path, "preprocessed_esets")
# # If the directory is empty, then we need to preprocess the datasets
# if isempty(readdir(preprocessed_esets_dir))
#     @error "The preprocessed datasets have not been found. Please preprocess the datasets first."
#     @info "There is a R script that can be run to preprocess the datasets in the 'scripts' folder"
# end

processed_esets_dir = joinpath(data_path, "processed_esets")
processed_esets_dir_contents = readdir(processed_esets_dir)
# Create the directory if it does not exist
if !isdir(processed_esets_dir)
    mkdir(processed_esets_dir)
end

mixtures_eset_dir = joinpath(data_path, "mixture_datasets")
mixtures_eset_dir_contents = readdir(mixtures_eset_dir)

# This script will behave depending on the information in the dataset descriptor file (datasets.yaml) 
# The file will tell us the reference, mixtures and synthetic datasets
# Read the docs for more information on the structure of the file
datasets_desc = read_datasets(esets_description_file)
datasets_desc[:SD001]
## REFERENCE DATASETS
#
# For the reference datasets, we assume that each sample represent a single 
# cell type. The processing involves mapping the annotation with 
# the cell ontology and then adding the phenotype column
references_esets_desc = [series
                         for dataset in values(datasets_desc)
                         for series in dataset.series
                         if series.type == "reference"]
references_esets_ids = [join([series.id, series.platform], "-")
                        for series in references_esets_desc]

# Load the datasets
preprocessed_ref_esets_files = Dict([id => joinpath(preprocessed_esets_dir,
                                                    "$(id)_preprocessed.rds")
                                     for id in references_esets_ids])
preprocessed_ref_esets = Dict{String,ExpressionSet}()
for (id, file) in preprocessed_ref_esets_files
    if !isfile(file)
        @error "The file $file does not exist. Please preprocess the datasets first."
        break
    end

    R"eset <- readRDS($file)"
    eset = @rget eset
    preprocessed_ref_esets[id] = convert(ExpressionSet, eset)
end

processed_ref_esets_files = Dict([id => joinpath(processed_esets_dir,
                                                 "$(id)_processed.rds")
                                  focell_types_raw = pData(eset)[!, reference_pheno_col]
                                  cell_types = format_cell_types(cell_types_raw)
                                  mapping = get_cell_ontology_mapping(cell_types)
                                  add_pheno_column!(eset, ontology_fcol_name,
                                                    [mapping[cell] for cell in cell_types])

                                  # Save the eset to a file
                                  save_eset(eset, ref_eset_id, ref_eset_file)r id in references_esets_ids])

for (ref_eset_id, ref_eset) in preprocessed_ref_esets
    ref_eset_file = processed_ref_esets_files[ref_eset_id]

    # Check if the dataset has already been preprocessed
    if isfile(ref_eset_file)
        @info "Reference dataset $ref_eset_id has already been processed. Skipping..."
        # ref_eset = load(ref_eset_file)
        continue
    end

    @info "Processing reference eset $ref_eset_id"
    eset = deepcopy(ref_eset)

    cell_types_raw = pData(eset)[!, reference_pheno_col]
    cell_types = format_cell_types(cell_types_raw)
    mapping = get_cell_ontology_mapping(cell_types)

    add_pheno_column!(eset, ontology_fcol_name, [mapping[cell] for cell in cell_types])

    # Save the eset to a file
    save_eset(eset, ref_eset_id, ref_eset_file)
end

## MIXTURE DATASETS
#
# For the mixtures, we assume that the samples are mixtures of the
# cell types. The processing is similiar as for reference but 
# requires a bit more parsing
mixtures_esets_desc = [series for dataset in values(datasets_desc)
                       for series in dataset.series if series.type == "mixture"]

mixtures_esets_ids = [join([dataset.id, series.id], '-')
                      for dataset in values(datasets_desc)
                      for series in dataset.series if series.type == "mixture"]

processed_mix_esets_files = Dict([id => joinpath(mixtures_eset_dir,
                                                 "$(id).jld2")
                                  for id in mixtures_esets_ids])

record_cell_proportions = Dict{String,Any}()

temp_cell_proportions = Dict{String,Any}()
temp_mapping = Dict{String,Any}()

for (mix_eset_id, mix_eset) in preprocessed_mix_esets
    mix_eset_file = processed_mix_esets_files[mix_eset_id]

    # Check if the dataset has already been processed
    if isfile(mix_eset_file)
        @info "Mixture dataset $mix_eset_id has already been processed. Skipping..."
        continue
    end

    @info "Processing mixture eset $mix_eset_id"
    eset = deepcopy(mix_eset)

    cell_proportions = get_cell_type_proportions(eset, mixture_pheno_col)
    record_cell_proportions[mix_eset_id] = deepcopy(cell_proportions)

    cell_types_raw = names(cell_proportions)

    for (cell_type) in cell_types_raw
        if cell_type == "sample_id"
            continue
        end

        formated_cell_type = format_cell_types([cell_type])
        mapping = get_cell_ontology_mapping(formated_cell_type)

        if (ismissing(mapping[first(formated_cell_type)]))
            @warn "The cell type $(first(formated_cell_type)) has not been mapped to the cell ontology"
            continue
        end

        # Rename the col with the cell ontology
        # Fist check if the col already exist, and if so combine them by adding the values
        if haskey(temp_cell_proportions, mix_eset_id)
            # @info first(formated_cell_type), names(temp_cell_proportions[mix_eset_id])
            if mapping[first(formated_cell_type)] in
               names(temp_cell_proportions[mix_eset_id])
                @info "Combining cell types $(first(formated_cell_type)) and $(mapping[first(formated_cell_type)])"
                temp_cell_proportions[mix_eset_id][!, mapping[first(formated_cell_type)]] += cell_proportions[!,
                                                                                                              cell_type]
                # Remove the cols that have been combined
                select!(temp_cell_proportions[mix_eset_id], Not(cell_type))
            else
                rename!(cell_proportions,
                        cell_type => mapping[first(formated_cell_type)])
            end
        else
            rename!(cell_proportions,
                    cell_type => mapping[first(formated_cell_type)])
            temp_cell_proportions[mix_eset_id] = cell_proportions
        end

        temp_mapping[first(formated_cell_type)] = mapping[first(formated_cell_type)]
    end

    # Save the updated dataset
    save_eset(eset, mix_eset_id, mix_eset_file)

    # Save the cell proportions
    save(split(mix_eset_file, ".")[1] * "_cell_proportions.jld2", "cell_proportions",
         temp_cell_proportions[mix_eset_id])
end

### Graph construction
onto_trees = Dict{Symbol,OntologyTree}()
function create_reference_graph(pairings::Dict{Symbol,Vector{String}}; onto="cl",
                                base_term_iri="http://purl.obolibrary.org/obo/CL_0000988")::OntologyTree
    base_term = onto_term(onto, base_term_iri)
    required_terms_ids = collect(keys(pairings))

    required_terms = Term[]
    for term_id in sort(required_terms_ids)
        terms = onto_terms(onto; id=String(term_id))
        if length(terms) == 0
            @warn "No terms found for id: $term_id"
            continue
        end

        term = first(terms)
        push!(required_terms, term[2])
        # Add the term to the pairings object
        pairings[term[2]] = ref_eset_pairings[term_id]
    end

    onto_tree = OntologyTree(base_term, required_terms; max_parent_limit=20)

    populate!(onto_tree)

    for (_, genes) in pairings[key]
        add_genes!(onto_tree, genes)
    end

    connect_term_genes!(onto_tree, pairings[key])

    return onto_tree
end

# Check if the reference graphs have already been constructed
# If not, then we need to construct them
onto_trees_dir = joinpath(data_path, "onto_trees")
if !isdir(onto_trees_dir)
    mkdir(onto_trees_dir)
end
onto_trees_files = readdir(onto_trees_dir)

if !isempty(onto_trees_files)
    @info "The ontology trees have already been constructed. Skipping..."
    return
end

preprocessed_ref_esets_pairings_files = Dict([id => joinpath(processed_esets_dir,
                                                             "$(id)_processed_pairings.rds")
                                              for id in references_esets_ids])

R"ref_eset_pairings <- lapply($preprocessed_ref_esets_pairings_files, function(x) readRDS(x))"
ref_eset_pairings_R = @rget ref_eset_pairings

ref_eset_pairings = Dict{Symbol,Dict{Symbol,Vector{String}}}()

# Convert to Dict{Symbol, String}
for (index, pairing_tuple) in enumerate(ref_eset_pairings_R)
    key, pairing = pairing_tuple
    ref_eset_pairings[key] = Dict{Symbol,Vector{String}}(pairing)
end

using OntologyLookup
include("../../src/graphs/ontology_tree.jl")

onto = "cl"
base_term_iri = "http://purl.obolibrary.org/obo/CL_0000988"  # Hematopoietic cell
base_term = onto_term(onto, base_term_iri)

pairings = Dict{Symbol,Dict{Term,Vector{String}}}()

onto_trees = Dict{Symbol,OntologyTree}()

# Get the required terms from the keys of the pairings
for (key, pairing) in ref_eset_pairings
    pairings[key] = Dict{Term,Vector{String}}()
    required_terms_ids = collect(keys(ref_eset_pairings[key]))

    required_terms = Term[]
    for term_id in sort(required_terms_ids)
        terms = onto_terms(onto; id=String(term_id))
        if length(terms) == 0
            @warn "No terms found for id: $term_id"
            continue
        end

        term = first(terms)
        push!(required_terms, term[2])

        # Add the term to the pairings object
        pairings[key][term[2]] = ref_eset_pairings[key][term_id]
    end

    onto_trees[key] = OntologyTree(base_term, required_terms; max_parent_limit=20)
end

for (key, onto_tree) in onto_trees
    populate!(onto_tree)

    for (term, genes) in pairings[key]
        add_genes!(onto_tree, genes)
    end

    connect_term_genes!(onto_tree, pairings[key])
end

using LightXML

## Now that we have  reference graphs we can construct a graph for the mixtures
## Note that for each mixtures datasets, the graph will be the same but the following attributes will be different
## - The gene expression for each gene -> this the observation
## - The cell type proportions  -> this is the label to predict

## For the IDs, they will be construct by combining the following:
## - The reference dataset ID
## - The mixture dataset ID
## - The sample ID

# ------------------------------------------------------------------
eset = preprocessed_mix_esets["GSE65136-GPL10558"]
onto_tree = deepcopy(onto_trees[Symbol("GSE22886-GPL97")])

gx = get_gene_expression(preprocessed_mix_esets["GSE65136-GPL10558"],
                         onto_trees[Symbol("GSE22886-GPL97")])

sample_id = "GSM1587800"
gx_sample = gx[!, sample_id]
gx_sample_with_id::Vector{Tuple{String,Float64}} = [(id, gx)
                                                    for (gx, id) in zip(gx_sample,
                                                                        gx[!, "feature_names"])]
add_gene_expression!(onto_tree, gx_sample_with_id)

sample_id_index_in_cell_proportions = findfirst(x -> x == sample_id,
                                                processed_mix_cell_proportions["GSE65136-GPL10558"][!,
                                                                                                    "sample_id"])
cp_raw = processed_mix_cell_proportions["GSE65136-GPL10558"][sample_id_index_in_cell_proportions,
                                                             :]
cp = [(cell, proportion)
      for (cell, proportion) in zip(names(cp_raw), cp_raw) if cell != "sample_id"]
cp_post = [(replace(cell, "_" => ":"), gx) for (cell, gx) in cp]

add_cell_proportions!(onto_tree, cp_post)

get_vertex_number_by_term_id(onto_tree.graph, "CL_0000576")

vertex_with_term_prop = [v_index
                         for (v_index, v_props) in onto_tree.graph.vprops
                         if haskey(v_props, :term)]
[get_prop(onto_tree.graph, v, :term).obo_id for v in vertex_with_term_prop]

mixtures_graphs[mix_eset_id] = mix_graphs

sample_onto_trees_dir = joinpath(data_path, "sample_onto_trees")
if !isdir(sample_onto_trees_dir)
    mkdir(sample_onto_trees_dir)
end

for (key, onto_tree) in mixtures_graphs
    save(joinpath(sample_onto_trees_dir, "$(key)_onto_tree.jld2"), "onto_tree", onto_tree)
end
